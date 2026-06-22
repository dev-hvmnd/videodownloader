import Foundation

/// Fixed on-disk layout of the downloaded tools under Application Support.
///
/// ```
/// <root>/
/// ├─ toolchain/python/bin/python3
/// ├─ toolchain/ffmpeg/bin/{ffmpeg,ffprobe}
/// ├─ toolchain/ytdlp/                (pip --target)
/// ├─ state/installed.json
/// ├─ downloads/                      (*.partial)
/// └─ logs/
/// ```
public struct ToolchainPaths: Sendable, Equatable {
    public let root: URL

    public init(root: URL) { self.root = root }

    public var toolchain: URL { root.appendingPathComponent("toolchain", isDirectory: true) }

    public var pythonDir: URL { toolchain.appendingPathComponent("python", isDirectory: true) }
    public var pythonExecutable: URL { pythonDir.appendingPathComponent("bin/python3") }

    public var ffmpegDir: URL { toolchain.appendingPathComponent("ffmpeg/bin", isDirectory: true) }
    public var ffmpegExecutable: URL { ffmpegDir.appendingPathComponent("ffmpeg") }
    public var ffprobeExecutable: URL { ffmpegDir.appendingPathComponent("ffprobe") }

    /// `pip install --target` directory for yt-dlp + dependencies.
    public var ytdlpDir: URL { toolchain.appendingPathComponent("ytdlp", isDirectory: true) }

    public var stateDir: URL { root.appendingPathComponent("state", isDirectory: true) }
    public var stateFile: URL { stateDir.appendingPathComponent("installed.json") }
    public var downloadsDir: URL { root.appendingPathComponent("downloads", isDirectory: true) }
    public var logsDir: URL { root.appendingPathComponent("logs", isDirectory: true) }
}
