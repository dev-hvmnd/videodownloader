import Foundation

/// Persisted installation state (`state/installed.json`).
public struct ToolchainState: Codable, Sendable, Equatable {
    public var schemaVersion: Int
    public var arch: String
    public var python: ComponentState?
    public var ffmpeg: FFmpegState?
    public var ytdlp: YTDLPState?
    public var setupComplete: Bool

    public struct ComponentState: Codable, Sendable, Equatable {
        public var version: String
        public var installedAt: Date
        public init(version: String, installedAt: Date) {
            self.version = version
            self.installedAt = installedAt
        }
    }

    /// ffmpeg/ffprobe state. The SHA-256 values are of the **installed (re-signed)** binaries, so the
    /// status check can detect later tampering. The manifest's pinned hashes are verified at install
    /// time, before re-signing. `version` mirrors the manifest pin so manifest upgrades are detected.
    public struct FFmpegState: Codable, Sendable, Equatable {
        public var version: String
        public var ffmpegSHA256: String
        public var ffprobeSHA256: String
        public var installedAt: Date
        public init(version: String, ffmpegSHA256: String, ffprobeSHA256: String, installedAt: Date) {
            self.version = version
            self.ffmpegSHA256 = ffmpegSHA256
            self.ffprobeSHA256 = ffprobeSHA256
            self.installedAt = installedAt
        }
    }

    public struct YTDLPState: Codable, Sendable, Equatable {
        public var version: String
        public var installedAt: Date
        public var lastUpdateCheck: Date?
        public init(version: String, installedAt: Date, lastUpdateCheck: Date? = nil) {
            self.version = version
            self.installedAt = installedAt
            self.lastUpdateCheck = lastUpdateCheck
        }
    }

    public static let currentSchemaVersion = 1

    public init(arch: String) {
        self.schemaVersion = Self.currentSchemaVersion
        self.arch = arch
        self.setupComplete = false
    }

    public static func load(from url: URL) -> ToolchainState? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(ToolchainState.self, from: data)
    }

    public func save(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: .atomic)
    }
}
