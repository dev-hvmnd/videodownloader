import Foundation

/// An entry of a playlist/channel (`yt-dlp --flat-playlist -J`).
public struct PlaylistEntry: Sendable, Identifiable, Equatable {
    public let id: String
    public let title: String
    public let url: String?
    public let duration: Double?
    /// 1-based index within the playlist (for `--playlist-items`).
    public let index: Int

    public init(
        id: String,
        title: String,
        url: String? = nil,
        duration: Double? = nil,
        index: Int
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.duration = duration
        self.index = index
    }
}

/// Result of a playlist probe.
public struct PlaylistInfo: Sendable, Identifiable, Equatable {
    public let id: String
    public let title: String
    public let webpageURL: String?
    public let entries: [PlaylistEntry]

    public init(id: String, title: String, webpageURL: String? = nil, entries: [PlaylistEntry]) {
        self.id = id
        self.title = title
        self.webpageURL = webpageURL
        self.entries = entries
    }
}
