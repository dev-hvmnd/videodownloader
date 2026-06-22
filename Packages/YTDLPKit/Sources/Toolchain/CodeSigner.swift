import Foundation
import YTDLPEngine

/// Makes downloaded Mach-O files executable on Apple Silicon:
///  1. Removes `com.apple.provenance` + `com.apple.quarantine` (otherwise SIGKILL on launch, cf. astral-sh/uv#16726).
///  2. Ad-hoc signature via `/usr/bin/codesign --force --sign -`.
///
/// Important: `/usr/bin/codesign` is part of the base OS (no Xcode/CLT required) - invoke it directly, NOT via `xcrun`.
public struct CodeSigner: Sendable {
    private let runner: any ProcessRunning

    public init(runner: any ProcessRunning) {
        self.runner = runner
    }

    private static let codesign = URL(fileURLWithPath: "/usr/bin/codesign")
    private static let xattr = URL(fileURLWithPath: "/usr/bin/xattr")

    /// Cleans + signs all Mach-O files under `directory` (libraries first, main binaries last).
    public func prepareTree(at directory: URL) async throws {
        await stripXattrs(at: directory, recursive: true)
        let machOs = Self.machOFiles(under: directory)
        for file in machOs {
            try await sign(file)
        }
    }

    /// Cleans + signs a single file (e.g. ffmpeg/ffprobe).
    public func prepareFile(at file: URL) async throws {
        await stripXattrs(at: file, recursive: false)
        try await sign(file)
    }

    private func stripXattrs(at url: URL, recursive: Bool) async {
        for attr in ["com.apple.provenance", "com.apple.quarantine"] {
            let args = (recursive ? ["-r", "-d", attr] : ["-d", attr]) + [url.path]
            _ = try? await runner.runCaptured(executable: Self.xattr, arguments: args)
        }
    }

    private func sign(_ file: URL) async throws {
        let result = try await runner.runCaptured(
            executable: Self.codesign,
            arguments: ["--force", "--sign", "-", "--timestamp=none", file.path]
        )
        guard result.succeeded else {
            throw ToolchainError.commandFailed(
                command: "codesign \(file.lastPathComponent)",
                exitCode: result.exitCode,
                output: result.stderr
            )
        }
    }

    // MARK: - Mach-O detection

    /// All regular Mach-O files under `directory`, deepest paths first (leaf-first).
    static func machOFiles(under directory: URL) -> [URL] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var result: [URL] = []
        for case let url as URL in enumerator {
            let isRegular = (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile ?? false
            guard isRegular, isMachO(url) else { continue }
            result.append(url)
        }
        return result.sorted { $0.pathComponents.count > $1.pathComponents.count }
    }

    static func isMachO(_ url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: 4), data.count == 4 else { return false }
        let magic = data.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }
        // Mach-O (32/64 thin) + Fat/Universal, both endiannesses each.
        let magics: Set<UInt32> = [0xFEEDFACE, 0xFEEDFACF, 0xCAFEBABE]
        return magics.contains(magic) || magics.contains(magic.byteSwapped)
    }
}
