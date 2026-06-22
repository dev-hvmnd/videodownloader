import Foundation

/// Abstraction over starting a subprocess. Behind this protocol currently sits
/// `FoundationProcessRunner` (based on `Foundation.Process`). A later switch to
/// Apple's `Subprocess` package thus stays a single file swap.
///
/// The returned `AsyncThrowingStream` delivers stdout/stderr line by line and `.exited(code:)`
/// at the end. **Cancellation:** if the consuming `Task` is cancelled, the implementation
/// terminates the subprocess (see `onTermination`).
public protocol ProcessRunning: Sendable {
    func run(
        executable: URL,
        arguments: [String],
        environment: [String: String],
        currentDirectory: URL?
    ) -> AsyncThrowingStream<ProcessEvent, Error>
}

public extension ProcessRunning {
    func run(
        executable: URL,
        arguments: [String],
        environment: [String: String] = [:],
        currentDirectory: URL? = nil
    ) -> AsyncThrowingStream<ProcessEvent, Error> {
        run(executable: executable, arguments: arguments, environment: environment, currentDirectory: currentDirectory)
    }
}
