import Testing
import Foundation
@testable import YTDLPEngine

@Suite struct MediaInfoDecoderTests {
    let decoder = MediaInfoDecoder()

    let videoJSON = """
    {
      "id": "abc123",
      "title": "Test Video",
      "uploader": "Test Channel",
      "duration": 213.0,
      "thumbnail": "https://x/t.jpg",
      "webpage_url": "https://x/watch?v=abc123",
      "_type": "video",
      "formats": [
        {"format_id":"sb0","ext":"mhtml","vcodec":"none","acodec":"none"},
        {"format_id":"140","ext":"m4a","vcodec":"none","acodec":"mp4a.40.2","abr":129.0,"filesize":3456789},
        {"format_id":"137","ext":"mp4","vcodec":"avc1.640028","acodec":"none","height":1080,"width":1920,"fps":30.0,"filesize":12345678,"tbr":2500.0},
        {"format_id":"18","ext":"mp4","vcodec":"avc1.42001E","acodec":"mp4a.40.2","height":360,"width":640,"fps":25.0,"filesize_approx":5000000}
      ]
    }
    """

    @Test func decodesVideoWithFormats() throws {
        let media = try decoder.decode(Data(videoJSON.utf8))
        #expect(media.title == "Test Video")
        #expect(media.uploader == "Test Channel")
        #expect(media.duration == 213.0)
        // mhtml storyboard filtered out → 3 formats
        #expect(media.formats.count == 3)

        let f137 = try #require(media.formats.first { $0.id == "137" })
        #expect(f137.height == 1080)
        #expect(f137.hasVideo)
        #expect(!f137.hasAudio)

        let f140 = try #require(media.formats.first { $0.id == "140" })
        #expect(!f140.hasVideo)
        #expect(f140.hasAudio)
    }

    @Test func detectsPlaylist() {
        let playlist = #"{"_type":"playlist","entries":[{"id":"a"}]}"#
        #expect(decoder.isPlaylist(Data(playlist.utf8)))
        #expect(!decoder.isPlaylist(Data(videoJSON.utf8)))
    }
}
