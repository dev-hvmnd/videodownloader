import Foundation

/// Runtime context for executing yt-dlp: the embedded Python, the yt-dlp module directory
/// (PYTHONPATH), and the ffmpeg directory. Built by the app from the toolchain paths so that
/// `YTDLPEngine` stays independent of the `Toolchain` module.
public struct YTDLPRuntime: Sendable, Equatable {
    public let pythonExecutable: URL
    public let modulePath: URL        // PYTHONPATH → pip --target directory
    public let ffmpegDirectory: URL

    public init(pythonExecutable: URL, modulePath: URL, ffmpegDirectory: URL) {
        self.pythonExecutable = pythonExecutable
        self.modulePath = modulePath
        self.ffmpegDirectory = ffmpegDirectory
    }

    /// Clean, deterministic environment (not inherited from the user) — except for proxy
    /// configuration, which is forwarded so downloads work behind a corporate proxy.
    public func environment() -> [String: String] {
        var env: [String: String] = [
            "PATH": "\(ffmpegDirectory.path):/usr/bin:/bin",
            "HOME": NSHomeDirectory(),
            "TMPDIR": NSTemporaryDirectory(),
            "PYTHONPATH": modulePath.path,
            "PYTHONDONTWRITEBYTECODE": "1",
            "PYTHONUTF8": "1",
        ]
        let inherited = ProcessInfo.processInfo.environment
        for key in ["HTTP_PROXY", "HTTPS_PROXY", "NO_PROXY", "http_proxy", "https_proxy", "no_proxy", "ALL_PROXY", "all_proxy"] {
            if let value = inherited[key] { env[key] = value }
        }
        return env
    }
}
