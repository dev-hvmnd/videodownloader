import Foundation

/// Result of a single-URL probe (`yt-dlp -J`).
public struct MediaInfo: Sendable, Identifiable, Equatable {
    public let id: String            // video id
    public let title: String
    public let uploader: String?
    public let duration: Double?     // seconds
    public let thumbnailURL: String?
    public let webpageURL: String?
    public let formats: [Format]

    public init(
        id: String,
        title: String,
        uploader: String? = nil,
        duration: Double? = nil,
        thumbnailURL: String? = nil,
        webpageURL: String? = nil,
        formats: [Format] = []
    ) {
        self.id = id
        self.title = title
        self.uploader = uploader
        self.duration = duration
        self.thumbnailURL = thumbnailURL
        self.webpageURL = webpageURL
        self.formats = formats
    }
}
