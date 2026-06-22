import Foundation
import YTDLPEngine

/// Extracts archives via the base-OS tools `tar` (for .tar.gz) and `ditto` (for .zip).
public struct Archiver: Sendable {
    private let runner: any ProcessRunning

    public init(runner: any ProcessRunning) {
        self.runner = runner
    }

    public func extractTarGz(_ archive: URL, into destinationDir: URL) async throws {
        try FileManager.default.createDirectory(at: destinationDir, withIntermediateDirectories: true)
        let result = try await runner.runCaptured(
            executable: URL(fileURLWithPath: "/usr/bin/tar"),
            arguments: ["-xzf", archive.path, "-C", destinationDir.path]
        )
        guard result.succeeded else {
            throw ToolchainError.extractionFailed(component: archive.lastPathComponent, detail: result.stderr)
        }
    }

    public func extractZip(_ archive: URL, into destinationDir: URL) async throws {
        try FileManager.default.createDirectory(at: destinationDir, withIntermediateDirectories: true)
        let result = try await runner.runCaptured(
            executable: URL(fileURLWithPath: "/usr/bin/ditto"),
            arguments: ["-x", "-k", archive.path, destinationDir.path]
        )
        guard result.succeeded else {
            throw ToolchainError.extractionFailed(component: archive.lastPathComponent, detail: result.stderr)
        }
    }
}
