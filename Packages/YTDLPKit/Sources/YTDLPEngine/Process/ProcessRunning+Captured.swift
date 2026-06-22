import Foundation

public struct CapturedOutput: Sendable, Equatable {
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String
    public var succeeded: Bool { exitCode == 0 }
}

public extension ProcessRunning {
    /// Runs a process to completion and collects stdout/stderr + exit code.
    /// For commands that do not need live streaming (codesign, tar, pip, --version …).
    func runCaptured(
        executable: URL,
        arguments: [String],
        environment: [String: String] = [:],
        currentDirectory: URL? = nil
    ) async throws -> CapturedOutput {
        var out: [String] = []
        var err: [String] = []
        var code: Int32 = -1
        for try await event in run(
            executable: executable,
            arguments: arguments,
            environment: environment,
            currentDirectory: currentDirectory
        ) {
            switch event {
            case .stdout(let line): out.append(line)
            case .stderr(let line): err.append(line)
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
