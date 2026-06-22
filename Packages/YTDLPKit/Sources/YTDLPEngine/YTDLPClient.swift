import Foundation

/// Result of a probe: single video (with formats) or playlist/channel (with entries).
public enum ProbeResult: Sendable {
    case video(MediaInfo)
    case playlist(PlaylistInfo)
}

/// Events of a running download.
public enum DownloadEvent: Sendable, Equatable {
    case destination(String)    // detected destination path
    case progress(DownloadProgress)
    case completed
}

/// Runs yt-dlp as a subprocess (`python3 -m yt_dlp …`) and delivers progress/completion as a stream.
public struct YTDLPClient: Sendable {
    private let runtime: YTDLPRuntime
    private let runner: any ProcessRunning
    private let arguments = ArgumentBuilder()
    private let parser = ProgressParser()

    public init(runtime: YTDLPRuntime, runner: any ProcessRunning = FoundationProcessRunner()) {
        self.runtime = runtime
        self.runner = runner
    }

    /// Starts a download. Cancelling the consuming task terminates the yt-dlp process.
    public func download(_ options: DownloadOptions) -> AsyncThrowingStream<DownloadEvent, Error> {
        let ytArgs = arguments.downloadArguments(
            for: options,
            ffmpegDirectory: runtime.ffmpegDirectory,
            progressTemplate: ProgressParser.downloadTemplate
        )
        let argv = ["-m", "yt_dlp"] + ytArgs
        let runtime = self.runtime
        let runner = self.runner
        let parser = self.parser

        return AsyncThrowingStream { continuation in
            let task = Task {
                var tailStderr: [String] = []
                do {
                    for try await event in runner.run(
                        executable: runtime.pythonExecutable,
                        arguments: argv,
                        environment: runtime.environment(),
                        currentDirectory: options.outputDirectory
                    ) {
                        switch event {
                        case .stdout(let line):
                            if let progress = parser.parse(line: line) {
                                continuation.yield(.progress(progress))
                            }
                            // Check independently: [ExtractAudio]/[Merger] lines are both
                            // postprocessing progress AND contain the final destination path.
                            if let path = parser.parseDestination(line: line) {
                                continuation.yield(.destination(path))
                            }
                        case .stderr(let line):
                            if let progress = parser.parse(line: line) {
                                continuation.yield(.progress(progress))
                            }
                            // Check independently: [ExtractAudio]/[Merger] lines are both
                            // postprocessing progress AND contain the final destination path.
                            if let path = parser.parseDestination(line: line) {
                                continuation.yield(.destination(path))
                            }
                            tailStderr.append(line)
                            if tailStderr.count > 40 { tailStderr.removeFirst() }
                        case .exited(let code):
                            if code == 0 {
                                continuation.yield(.completed)
                                continuation.finish()
                            } else {
                                continuation.finish(throwing: YTDLPError.processFailed(
                                    exitCode: code,
                                    stderr: tailStderr.joined(separator: "\n")
                                ))
                            }
                            return
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Probes a URL. A single call covers both cases: single video (`-J` returns formats) and
    /// playlist/channel (`--flat-playlist` lists entries).
    public func probe(url: String) async throws -> ProbeResult {
        let argv = ["-m", "yt_dlp"] + arguments.probeArguments(url: url, flat: true, noPlaylist: false)
        let result = try await runner.runCaptured(
            executable: runtime.pythonExecutable,
            arguments: argv,
            environment: runtime.environment()
        )
        guard result.succeeded else {
            throw YTDLPError.processFailed(exitCode: result.exitCode, stderr: result.stderr)
        }
        guard let data = result.stdout.data(using: .utf8), !data.isEmpty else {
            throw YTDLPError.parsingFailed("leere Antwort von yt-dlp")
        }
        if MediaInfoDecoder().isPlaylist(data) {
            return .playlist(try PlaylistDecoder().decode(data))
        }
        return .video(try MediaInfoDecoder().decode(data))
    }

    /// Returns the yt-dlp version.
    public func version() async throws -> String {
        let result = try await runner.runCaptured(
            executable: runtime.pythonExecutable,
            arguments: ["-m", "yt_dlp", "--version"],
            environment: runtime.environment()
        )
        guard result.succeeded else {
            throw YTDLPError.processFailed(exitCode: result.exitCode, stderr: result.stderr)
        }
        return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
