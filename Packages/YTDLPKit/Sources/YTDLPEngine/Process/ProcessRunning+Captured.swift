import Foundation

public struct CapturedOutput: Sendable, Equatable {
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String
    public var succeeded: Bool { exitCode == 0 }
}

public extension ProcessRunning {
    /// Runs a process to completion and collects stdout/stderr + exit code.
    /// For commands where live streaming is not needed (codesign, tar, pip, --version …).
    ///
    /// `maxLines` bounds memory for noisy commands by keeping only the last N lines of each stream
    /// (the tail, where errors appear). Pass `nil` (default) for callers that need the full output,
    /// e.g. the `-J` probe whose stdout is the JSON payload.
    func runCaptured(
        executable: URL,
        arguments: [String],
        environment: [String: String] = [:],
        currentDirectory: URL? = nil,
        maxLines: Int? = nil
    ) async throws -> CapturedOutput {
        var out: [String] = []
        var err: [String] = []
        var code: Int32 = -1

        func append(_ line: String, to buffer: inout [String]) {
            buffer.append(line)
            if let maxLines, buffer.count > maxLines { buffer.removeFirst() }
        }

        for try await event in run(
            executable: executable,
            arguments: arguments,
            environment: environment,
            currentDirectory: currentDirectory
        ) {
            switch event {
            case .stdout(let line): append(line, to: &out)
            case .stderr(let line): append(line, to: &err)
            case .exited(let c): code = c
            }
        }
        return CapturedOutput(
            exitCode: code,
            stdout: out.joined(separator: "\n"),
            stderr: err.joined(separator: "\n")
        )
    }
}
