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

    /// Clean environment, not inherited from the user (deterministic).
    public func environment() -> [String: String] {
        [
            "PATH": "\(ffmpegDirectory.path):/usr/bin:/bin",
            "HOME": NSHomeDirectory(),
            "TMPDIR": NSTemporaryDirectory(),
            "PYTHONPATH": modulePath.path,
            "PYTHONDONTWRITEBYTECODE": "1",
            "PYTHONUTF8": "1",
        ]
    }
}
