import Foundation

/// Default `ProcessRunning` based on `Foundation.Process`.
///
/// Delivers stdout/stderr line by line as `ProcessEvent` and `.exited(code:)` at the end.
/// If the consuming `Task` is cancelled, `onTermination` terminates the subprocess.
public struct FoundationProcessRunner: ProcessRunning {
    public init() {}

    public func run(
        executable: URL,
        arguments: [String],
        environment: [String: String],
        currentDirectory: URL?
    ) -> AsyncThrowingStream<ProcessEvent, Error> {
        AsyncThrowingStream { continuation in
            let process = Process()
            process.executableURL = executable
            process.arguments = arguments
            if !environment.isEmpty { process.environment = environment }
            if let currentDirectory { process.currentDirectoryURL = currentDirectory }

            let outPipe = Pipe()
            let errPipe = Pipe()
            process.standardOutput = outPipe
            process.standardError = errPipe

            let outBuffer = LineBuffer { continuation.yield(.stdout($0)) }
            let errBuffer = LineBuffer { continuation.yield(.stderr($0)) }
            let box = ProcessBox(process)

            outPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty { outBuffer.append(data) }
            }
            errPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty { errBuffer.append(data) }
            }

            process.terminationHandler = { proc in
                outPipe.fileHandleForReading.readabilityHandler = nil
                errPipe.fileHandleForReading.readabilityHandler = nil
                let restOut = (try? outPipe.fileHandleForReading.readToEnd()) ?? nil
                if let restOut, !restOut.isEmpty { outBuffer.append(restOut) }
                let restErr = (try? errPipe.fileHandleForReading.readToEnd()) ?? nil
                if let restErr, !restErr.isEmpty { errBuffer.append(restErr) }
                outBuffer.flush()
                errBuffer.flush()
                continuation.yield(.exited(code: proc.terminationStatus))
                continuation.finish()
            }

            continuation.onTermination = { reason in
                if case .cancelled = reason {
                    box.terminate()
                }
            }

            do {
                try process.run()
            } catch {
                continuation.finish(throwing: error)
            }
        }
    }
}

/// Sendable wrapper so that `onTermination` (a `@Sendable` closure) is allowed to terminate the process.
private final class ProcessBox: @unchecked Sendable {
    private let process: Process
    init(_ process: Process) { self.process = process }
    func terminate() {
        if process.isRunning { process.terminate() }
    }
}

/// Collects byte chunks and emits complete lines (separated by `\n`). Thread-safe.
private final class LineBuffer: @unchecked Sendable {
    private var buffer = Data()
    private let emit: @Sendable (String) -> Void
    private let lock = NSLock()

    init(emit: @escaping @Sendable (String) -> Void) { self.emit = emit }

    func append(_ data: Data) {
        lock.lock(); defer { lock.unlock() }
        buffer.append(data)
        while let newline = buffer.firstIndex(of: 0x0A) {
            let lineData = buffer[buffer.startIndex..<newline]
            buffer.removeSubrange(buffer.startIndex...newline)
            emitLine(lineData)
        }
    }

    func flush() {
        lock.lock(); defer { lock.unlock() }
        guard !buffer.isEmpty else { return }
        emitLine(buffer[...])
        buffer.removeAll()
    }

    private func emitLine(_ data: Data.SubSequence) {
        // Also strip a trailing \r at the end of the line (CRLF / yt-dlp).
        var slice = data
        if slice.last == 0x0D { slice = slice.dropLast() }
        if let line = String(data: Data(slice), encoding: .utf8) {
            emit(line)
        }
    }
}
