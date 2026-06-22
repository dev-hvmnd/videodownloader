import Foundation

/// Decodes the JSON output of `yt-dlp -J` (single video) into `MediaInfo`.
public struct MediaInfoDecoder: Sendable {
    public init() {}

    public func decode(_ data: Data) throws -> MediaInfo {
        let raw: RawMediaInfo
        do { raw = try JSONDecoder().decode(RawMediaInfo.self, from: data) }
        catch { throw YTDLPError.parsingFailed(String(describing: error)) }

        let formats = (raw.formats ?? [])
            .filter { $0.ext != "mhtml" }                       // filter out storyboards
            .map { $0.toFormat() }
            .filter { $0.hasVideo || $0.hasAudio }

        return MediaInfo(
            id: raw.id ?? "",
            title: raw.title ?? raw.id ?? "Unbenannt",
            uploader: raw.uploader ?? raw.channel,
            duration: raw.duration,
            thumbnailURL: raw.thumbnail,
            webpageURL: raw.webpage_url,
            formats: formats
        )
    }

    /// True if the JSON describes a playlist/channel (rather than a single video).
    public func isPlaylist(_ data: Data) -> Bool {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }
        return (obj["_type"] as? String) == "playlist" || obj["entries"] != nil
    }
}

// MARK: - Raw structures (snake_case like yt-dlp)

private struct RawMediaInfo: Decodable {
    let id: String?
    let title: String?
    let uploader: String?
    let channel: String?
    let duration: Double?
    let thumbnail: String?
    let webpage_url: String?
    let formats: [RawFormat]?
    let _type: String?
}

private struct RawFormat: Decodable {
    let format_id: String
    let ext: String?
    let height: Int?
    let width: Int?
    let fps: Double?
    let vcodec: String?
    let acodec: String?
    let filesize: Int64?
    let filesize_approx: Int64?
    let tbr: Double?
    let abr: Double?
    let format_note: String?

    func toFormat() -> Format {
        Format(
            id: format_id,
            ext: ext,
            height: height,
            width: width,
            fps: fps,
            vcodec: vcodec,
            acodec: acodec,
            filesize: filesize,
            filesizeApprox: filesize_approx,
            tbr: tbr,
            abr: abr,
            formatNote: format_note
        )
    }
}
