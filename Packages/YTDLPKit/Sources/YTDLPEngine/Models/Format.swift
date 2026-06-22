import Foundation

/// A single format reported by yt-dlp (from `-J`).
public struct Format: Sendable, Identifiable, Equatable {
    public let id: String            // format_id
    public let ext: String?
    public let height: Int?
    public let width: Int?
    public let fps: Double?
    public let vcodec: String?
    public let acodec: String?
    public let filesize: Int64?
    public let filesizeApprox: Int64?
    public let tbr: Double?           // total bitrate (kbit/s)
    public let abr: Double?           // audio bitrate (kbit/s)
    public let formatNote: String?

    public init(
        id: String,
        ext: String? = nil,
        height: Int? = nil,
        width: Int? = nil,
        fps: Double? = nil,
        vcodec: String? = nil,
        acodec: String? = nil,
        filesize: Int64? = nil,
        filesizeApprox: Int64? = nil,
        tbr: Double? = nil,
        abr: Double? = nil,
        formatNote: String? = nil
    ) {
        self.id = id
        self.ext = ext
        self.height = height
        self.width = width
        self.fps = fps
        self.vcodec = vcodec
        self.acodec = acodec
        self.filesize = filesize
        self.filesizeApprox = filesizeApprox
        self.tbr = tbr
        self.abr = abr
        self.formatNote = formatNote
    }

    public var hasVideo: Bool { vcodec != nil && vcodec != "none" }
    public var hasAudio: Bool { acodec != nil && acodec != "none" }
    public var bestKnownFilesize: Int64? { filesize ?? filesizeApprox }

    /// WebM container (VP8/VP9 video or Opus/Vorbis audio). Such streams force an mkv merge and are
    /// hidden from the selection in favour of an mp4-compatible alternative.
    public var isWebM: Bool { ext == "webm" }

    /// True if this stream lives natively in an mp4 container (H.264/AVC video or AAC/m4a audio),
    /// i.e. it can be merged into an mp4 without remuxing.
    public var isMP4Native: Bool {
        if ext == "mp4" || ext == "m4a" { return true }
        if let v = vcodec, v.hasPrefix("avc1") || v.hasPrefix("h264") { return true }
        return false
    }

    /// fps rounded to a whole number (e.g. 59.94 → 60), or nil if unknown.
    public var roundedFPS: Int? {
        guard let fps, fps > 0 else { return nil }
        return Int(fps.rounded())
    }

    /// Human-readable resolution, e.g. "1920×1080" or "audio only".
    public var resolutionLabel: String {
        if !hasVideo, hasAudio { return String(localized: "Audio only", bundle: .module) }
        if let w = width, let h = height { return "\(w)×\(h)" }
        if let h = height { return "\(h)p" }
        return "—"
    }
}
