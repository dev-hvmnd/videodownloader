import Foundation

/// Pinned versions + SHA256 of the tools (bundled as `Toolchain.json`).
public struct ToolchainManifest: Decodable, Sendable {
    public let schemaVersion: Int
    public let python: PythonSpec
    public let ffmpeg: FFmpegSpec
    public let ytdlp: YTDLPSpec

    public struct Asset: Decodable, Sendable {
        public let url: String
        public let sha256: String
    }

    public struct PythonSpec: Decodable, Sendable {
        public let version: String
        public let arm64: Asset
        public let x86_64: Asset
        public func asset(for arch: Architecture) -> Asset { arch == .arm64 ? arm64 : x86_64 }
    }

    public struct FFmpegArchSpec: Decodable, Sendable {
        public let ffmpegURL: String
        public let ffmpegSHA256: String
        public let ffprobeURL: String
        public let ffprobeSHA256: String
    }

    public struct FFmpegSpec: Decodable, Sendable {
        public let version: String
        public let arm64: FFmpegArchSpec
        public let x86_64: FFmpegArchSpec
        public func spec(for arch: Architecture) -> FFmpegArchSpec { arch == .arm64 ? arm64 : x86_64 }
    }

    public struct YTDLPSpec: Decodable, Sendable {
        public let channel: String
        public let minVersion: String?
    }

    public static func load(from url: URL) throws -> ToolchainManifest {
        let data: Data
        do { data = try Data(contentsOf: url) }
        catch { throw ToolchainError.manifestInvalid("nicht lesbar: \(error.localizedDescription)") }
        do { return try JSONDecoder().decode(ToolchainManifest.self, from: data) }
        catch { throw ToolchainError.manifestInvalid(String(describing: error)) }
    }
}
