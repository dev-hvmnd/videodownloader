import Testing
import Foundation
@testable import YTDLPEngine

@Suite struct PlaylistDecoderTests {
    let json = """
    {
      "_type": "playlist",
      "id": "PL123",
      "title": "Meine Playlist",
      "webpage_url": "https://x/playlist?list=PL123",
      "entries": [
        {"id":"aaa","title":"Erstes Video","url":"https://x/watch?v=aaa","duration":100.0},
        {"id":"bbb","title":"Zweites Video","url":"https://x/watch?v=bbb","duration":200.0},
        {"id":"ccc","url":"https://x/watch?v=ccc"}
      ]
    }
    """

    @Test func decodesPlaylistEntries() throws {
        let info = try PlaylistDecoder().decode(Data(json.utf8))
        #expect(info.title == "Meine Playlist")
        #expect(info.entries.count == 3)
        #expect(info.entries[0].title == "Erstes Video")
        #expect(info.entries[0].index == 1)
        #expect(info.entries[2].index == 3)
        // entry without a title → fallback
        #expect(info.entries[2].title == "ccc")
        #expect(info.entries[1].url == "https://x/watch?v=bbb")
    }
}
