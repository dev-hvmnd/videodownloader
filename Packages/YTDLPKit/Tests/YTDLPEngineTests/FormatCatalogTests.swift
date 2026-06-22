import Testing
import Foundation
@testable import YTDLPEngine

@Suite struct FormatCatalogTests {
    /// A typical YouTube format set: H.264/mp4 caps at 1080p30, while 60 fps exists only as VP9/webm.
    private let sample: [Format] = [
        Format(id: "137", ext: "mp4",  height: 1080, fps: 30, vcodec: "avc1.640028", tbr: 4500),
        Format(id: "248", ext: "webm", height: 1080, fps: 30, vcodec: "vp9",          tbr: 4000),
        Format(id: "303", ext: "webm", height: 1080, fps: 60, vcodec: "vp9",          tbr: 5500),
        Format(id: "136", ext: "mp4",  height: 720,  fps: 30, vcodec: "avc1.4d401f",  tbr: 2500),
        Format(id: "18",  ext: "mp4",  height: 360,  fps: 30, vcodec: "avc1", acodec: "mp4a"),  // progressive
        Format(id: "140", ext: "m4a",  acodec: "mp4a.40.2", abr: 128),
        Format(id: "251", ext: "webm", acodec: "opus",       abr: 160),
        Format(id: "sb0", ext: "mhtml", height: 90),                                   // storyboard-ish, no codecs
    ]

    @Test func groupsByResolutionAndFPS() {
        let q = FormatCatalog.videoQualities(from: sample)
        // 1080p60, 1080p30, 720p30, 360p30 — distinct resolution/fps pairs, best first.
        #expect(q.map(\.id) == ["1080-60", "1080-30", "720-30", "360-30"])
        #expect(q.allSatisfy { $0.fps != nil })   // every fps option is selectable
    }

    @Test func prefersMP4StreamWhenCollapsingDuplicates() {
        let q = FormatCatalog.videoQualities(from: sample)
        // 1080p30 exists as both avc1/mp4 (137) and vp9/webm (248) → must prefer the mp4 stream.
        let p1080p30 = try! #require(q.first { $0.id == "1080-30" })
        #expect(p1080p30.formatSelector == "137+ba[ext=m4a]/137+ba/137")
    }

    @Test func keepsWebMOnlyFrameRates() {
        let q = FormatCatalog.videoQualities(from: sample)
        // 1080p60 is only available as VP9/webm — it must still be offered (will be remuxed to mp4).
        let p1080p60 = try! #require(q.first { $0.id == "1080-60" })
        #expect(p1080p60.formatSelector == "303+ba[ext=m4a]/303+ba/303")
    }

    @Test func progressiveStreamNeedsNoMergedAudio() {
        let q = FormatCatalog.videoQualities(from: sample)
        let p360 = try! #require(q.first { $0.id == "360-30" })
        #expect(p360.formatSelector == "18")   // already carries audio
    }

    @Test func audioTracksExcludeWebM() {
        let tracks = FormatCatalog.audioTracks(from: sample)
        #expect(tracks.map(\.id) == ["140"])   // m4a only; opus/webm (251) hidden
    }

    @Test func fpsIsRoundedIntoBuckets() {
        let formats = [
            Format(id: "a", ext: "mp4", height: 1080, fps: 59.94, vcodec: "avc1"),
            Format(id: "b", ext: "mp4", height: 1080, fps: 29.97, vcodec: "avc1"),
        ]
        let q = FormatCatalog.videoQualities(from: formats)
        #expect(q.map(\.fps) == [60, 30])
    }
}
