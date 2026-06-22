import Foundation

/// One selectable video quality, identified by resolution + frame rate. The underlying codec and
/// container are deliberately hidden: the user picks "1080p · 60 fps", not "vp9/webm". The download
/// is normalised to mp4 by the `ArgumentBuilder` (merge + remux).
public struct VideoQuality: Sendable, Identifiable, Equatable {
    public let height: Int
    /// Frame rate rounded to a whole number, or nil if yt-dlp did not report one.
    public let fps: Int?
    /// yt-dlp `-f` expression for this quality (prefers an mp4-friendly audio track).
    public let formatSelector: String
    /// Largest known size among the streams in this group (for display only).
    public let approximateFilesize: Int64?

    public var id: String { "\(height)-\(fps ?? 0)" }

    public init(height: Int, fps: Int?, formatSelector: String, approximateFilesize: Int64?) {
        self.height = height
        self.fps = fps
        self.formatSelector = formatSelector
        self.approximateFilesize = approximateFilesize
    }
}

/// Turns the raw `[Format]` from a probe into the user-facing selection lists. Pure → unit-testable.
public enum FormatCatalog {
    /// Distinct video qualities (one per resolution + fps), best first. WebM is never shown as a
    /// separate choice: where both an mp4 and a webm stream exist at the same resolution/fps they
    /// collapse into a single entry whose selector prefers the mp4 stream.
    public static func videoQualities(from formats: [Format]) -> [VideoQuality] {
        let videos = formats.filter { $0.hasVideo && $0.height != nil }

        var groups: [String: [Format]] = [:]
        for format in videos {
            let key = "\(format.height ?? 0)|\(format.roundedFPS ?? 0)"
            groups[key, default: []].append(format)
        }

        let qualities = groups.values.map { group -> VideoQuality in
            // Representative stream: prefer an mp4-native one (most compatible), then highest bitrate.
            let representative = group.sorted { lhs, rhs in
                if lhs.isMP4Native != rhs.isMP4Native { return lhs.isMP4Native }
                return (lhs.tbr ?? 0) > (rhs.tbr ?? 0)
            }.first!
            return VideoQuality(
                height: representative.height ?? 0,
                fps: representative.roundedFPS,
                formatSelector: selector(for: representative),
                approximateFilesize: group.compactMap(\.bestKnownFilesize).max()
            )
        }

        return qualities.sorted { ($0.height, $0.fps ?? 0) > ($1.height, $1.fps ?? 0) }
    }

    /// Audio-only tracks for the "original format" section, best first. WebM/Opus is excluded so that
    /// nothing webm is selectable (MP3/M4A conversion is offered separately).
    public static func audioTracks(from formats: [Format]) -> [Format] {
        formats
            .filter { !$0.hasVideo && $0.hasAudio && !$0.isWebM }
            .sorted { ($0.abr ?? $0.tbr ?? 0) > ($1.abr ?? $1.tbr ?? 0) }
    }

    /// `-f` expression for a chosen video stream. Progressive streams already carry audio; video-only
    /// streams get the best audio added, preferring m4a so the merged file stays mp4-friendly.
    private static func selector(for video: Format) -> String {
        if video.hasAudio { return video.id }
        return "\(video.id)+ba[ext=m4a]/\(video.id)+ba/\(video.id)"
    }
}
