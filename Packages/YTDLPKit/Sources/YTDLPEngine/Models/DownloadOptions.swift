import Foundation

/// Complete description of a download job. Translated by the `ArgumentBuilder` into yt-dlp argv.
public struct DownloadOptions: Sendable, Equatable {
    public enum Mode: Sendable, Equatable {
        /// Video; `formatID == nil` ⇒ best combination (`bv*+ba/b`).
        case video(formatID: String?)
        /// Audio only, with a target format.
        case audioOnly(AudioFormat)
    }

    public enum AudioFormat: String, Sendable, CaseIterable, Equatable {
        case mp3, m4a, opus, best
    }

    public enum Container: String, Sendable, CaseIterable, Equatable {
        case mp4, mkv
    }

    public var url: String
    public var mode: Mode
    public var outputDirectory: URL
    public var outputTemplate: String
    /// Target container for video downloads (default `.mp4`). nil ⇒ leave the container untouched
    /// (used when downloading a single raw audio stream, where remuxing would be wrong).
    public var mergeContainer: Container?

    // Subtitles
    public var writeSubtitles: Bool
    public var autoSubtitles: Bool
    public var embedSubtitles: Bool
    public var subtitleLanguages: [String]

    // Thumbnails / metadata
    public var writeThumbnail: Bool
    public var embedThumbnail: Bool
    public var embedMetadata: Bool

    // Playlist
    /// e.g. "1,3,5-8"; nil ⇒ single video (`--no-playlist`).
    public var playlistItems: String?
    public var downloadPlaylist: Bool

    public init(
        url: String,
        mode: Mode = .video(formatID: nil),
        outputDirectory: URL,
        outputTemplate: String = "%(title)s [%(id)s].%(ext)s",
        mergeContainer: Container? = .mp4,
        writeSubtitles: Bool = false,
        autoSubtitles: Bool = false,
        embedSubtitles: Bool = false,
        subtitleLanguages: [String] = ["en"],
        writeThumbnail: Bool = false,
        embedThumbnail: Bool = false,
        embedMetadata: Bool = false,
        playlistItems: String? = nil,
        downloadPlaylist: Bool = false
    ) {
        self.url = url
        self.mode = mode
        self.outputDirectory = outputDirectory
        self.outputTemplate = outputTemplate
        self.mergeContainer = mergeContainer
        self.writeSubtitles = writeSubtitles
        self.autoSubtitles = autoSubtitles
        self.embedSubtitles = embedSubtitles
        self.subtitleLanguages = subtitleLanguages
        self.writeThumbnail = writeThumbnail
        self.embedThumbnail = embedThumbnail
        self.embedMetadata = embedMetadata
        self.playlistItems = playlistItems
        self.downloadPlaylist = downloadPlaylist
    }
}
