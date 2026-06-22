import Foundation

/// Decodes the JSON output of `yt-dlp -J --flat-playlist` (playlist/channel) into `PlaylistInfo`.
public struct PlaylistDecoder: Sendable {
    public init() {}

    public func decode(_ data: Data) throws -> PlaylistInfo {
        let raw: RawPlaylist
        do { raw = try JSONDecoder().decode(RawPlaylist.self, from: data) }
        catch { throw YTDLPError.parsingFailed(String(describing: error)) }

        let entries: [PlaylistEntry] = (raw.entries ?? []).enumerated().compactMap { index, entry in
            guard let id = entry.id ?? entry.url else { return nil }
            return PlaylistEntry(
                id: id,
                title: entry.title ?? entry.id ?? "Eintrag \(index + 1)",
                url: entry.url ?? entry.webpage_url,
                duration: entry.duration,
                index: index + 1
            )
        }

        return PlaylistInfo(
            id: raw.id ?? raw.webpage_url ?? "playlist",
            title: raw.title ?? "Playlist",
            webpageURL: raw.webpage_url,
            entries: entries
        )
    }
}

private struct RawPlaylist: Decodable {
    let id: String?
    let title: String?
    let webpage_url: String?
    let entries: [RawEntry]?
}

private struct RawEntry: Decodable {
    let id: String?
    let title: String?
    let url: String?
    let webpage_url: String?
    let duration: Double?
}
