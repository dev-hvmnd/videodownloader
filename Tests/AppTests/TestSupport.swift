import Foundation
import YTDLPEngine

/// A controllable `ProcessRunning` stub for queue tests.
/// `.complete` finishes immediately; `.block` stays "running" until the consuming task is cancelled.
final class StubRunner: ProcessRunning, @unchecked Sendable {
    enum Mode { case complete, block }

    let mode: Mode
    let destinationName: String
    private let lock = NSLock()
    private var _started = 0

    init(mode: Mode, destinationName: String = "download.mp4") {
        self.mode = mode
        self.destinationName = destinationName
    }

    /// Number of run() invocations that have begun (used to observe queue scheduling).
    var started: Int { lock.lock(); defer { lock.unlock() }; return _started }
    private func markStarted() { lock.lock(); _started += 1; lock.unlock() }

    func run(
        executable: URL,
        arguments: [String],
        environment: [String: String],
        currentDirectory: URL?
    ) -> AsyncThrowingStream<ProcessEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                continuation.yield(.stdout("[download] Destination: /tmp/\(self.destinationName)"))
                continuation.yield(.stdout("DLP|downloading|500|1000|1000|1000|1"))
                self.markStarted()
                switch self.mode {
                case .complete:
                    continuation.yield(.exited(code: 0))
                    continuation.finish()
                case .block:
                    while !Task.isCancelled { try? await Task.sleep(nanoseconds: 5_000_000) }
                    continuation.finish()
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

struct WaitTimeout: Error { let what: String }

/// Polls a main-actor condition until it is true or a timeout elapses.
@MainActor
func waitUntil(_ what: String = "condition", timeoutMillis: Int = 3000, _ condition: () -> Bool) async throws {
    var elapsed = 0
    while !condition() {
        if elapsed >= timeoutMillis { throw WaitTimeout(what: what) }
        try await Task.sleep(nanoseconds: 20_000_000)
        elapsed += 20
    }
}
