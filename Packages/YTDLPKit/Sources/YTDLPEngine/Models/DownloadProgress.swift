import Foundation

/// Machine-readable progress of a yt-dlp download, parsed from its output.
public struct DownloadProgress: Sendable, Equatable {
    public enum Phase: Sendable, Equatable {
        case queued
        case downloading
        /// Postprocessing by yt-dlp/ffmpeg (e.g. "ExtractAudio", "Merger", "EmbedSubtitle").
        case postProcessing(String)
        case finished
    }

    public var phase: Phase
    /// 0…1, if known.
    public var fractionCompleted: Double?
    public var downloadedBytes: Int64?
    public var totalBytes: Int64?
    public var speedBytesPerSecond: Double?
    public var etaSeconds: Int?
    /// Original line (for logging/debug).
    public var rawLine: String?

    public init(
        phase: Phase = .queued,
        fractionCompleted: Double? = nil,
        downloadedBytes: Int64? = nil,
        totalBytes: Int64? = nil,
        speedBytesPerSecond: Double? = nil,
        etaSeconds: Int? = nil,
        rawLine: String? = nil
    ) {
        self.phase = phase
        self.fractionCompleted = fractionCompleted
        self.downloadedBytes = downloadedBytes
        self.totalBytes = totalBytes
        self.speedBytesPerSecond = speedBytesPerSecond
        self.etaSeconds = etaSeconds
        self.rawLine = rawLine
    }
}
