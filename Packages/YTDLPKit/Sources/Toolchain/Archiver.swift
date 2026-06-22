import Foundation
import YTDLPEngine

/// Extracts archives via the base-OS tools `tar` (for .tar.gz) and `ditto` (for .zip).
public struct Archiver: Sendable {
    private let runner: any ProcessRunning

    public init(runner: any ProcessRunning) {
        self.runner = runner
    }

    private static let tar = URL(fileURLWithPath: "/usr/bin/tar")
    private static let ditto = URL(fileURLWithPath: "/usr/bin/ditto")
    private static let unzip = URL(fileURLWithPath: "/usr/bin/unzip")

    public func extractTarGz(_ archive: URL, into destinationDir: URL) async throws {
        try FileManager.default.createDirectory(at: destinationDir, withIntermediateDirectories: true)
        let result = try await runner.runCaptured(
            executable: Self.tar,
            arguments: ["-xzf", archive.path, "-C", destinationDir.path],
            maxLines: 200
        )
        guard result.succeeded else {
            throw ToolchainError.extractionFailed(component: archive.lastPathComponent, detail: result.stderr)
        }
    }

    public func extractZip(_ archive: URL, into destinationDir: URL) async throws {
        try await validateZipSafety(archive)   // reject path traversal / symlinks before extracting
        try FileManager.default.createDirectory(at: destinationDir, withIntermediateDirectories: true)
        let result = try await runner.runCaptured(
            executable: Self.ditto,
            arguments: ["-x", "-k", archive.path, destinationDir.path],
            maxLines: 200
        )
        guard result.succeeded else {
            throw ToolchainError.extractionFailed(component: archive.lastPathComponent, detail: result.stderr)
        }
    }

    /// Rejects archives whose entries could escape the destination (absolute paths or `..`
    /// traversal) or introduce symlinks (whose extraction could redirect later writes).
    private func validateZipSafety(_ archive: URL) async throws {
        func fail(_ reason: String) -> ToolchainError {
            .extractionFailed(component: archive.lastPathComponent, detail: "unsafe archive: \(reason)")
        }
        // The listing MUST be validated in full — never truncated — otherwise a malicious entry could
        // hide outside the inspected window and still be extracted. We therefore stream the listing
        // (constant memory) and fail closed if the entry count exceeds a sane cap (tool zips have a
        // handful of entries).
        let maxEntries = 100_000

        // Entry names via `unzip -Z1`, checked line by line.
        var nameExit: Int32 = -1
        var count = 0
        for try await event in runner.run(executable: Self.unzip, arguments: ["-Z1", archive.path]) {
            switch event {
            case .stdout(let name):
                count += 1
                if count > maxEntries { throw fail("too many entries (> \(maxEntries))") }
                if name.hasPrefix("/") { throw fail("absolute path “\(name)”") }
                let components = name.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
                if components.contains("..") { throw fail("parent traversal “\(name)”") }
            case .stderr:
                break
            case .exited(let code):
                nameExit = code
            }
        }
        guard nameExit == 0 else { throw fail("cannot list entries") }

        // Symlinks: in the zipinfo long listing a symlink entry's mode begins with 'l'.
        var modeExit: Int32 = -1
        count = 0
        for try await event in runner.run(executable: Self.unzip, arguments: ["-Z", archive.path]) {
            switch event {
            case .stdout(let line):
                count += 1
                if count > maxEntries { throw fail("too many entries (> \(maxEntries))") }
                if line.first == "l", line.dropFirst().prefix(9).allSatisfy({ "rwxsStT-".contains($0) }) {
                    throw fail("contains a symlink")
                }
            case .stderr:
                break
            case .exited(let code):
                modeExit = code
            }
        }
        guard modeExit == 0 else { throw fail("cannot inspect entries") }
    }
}
