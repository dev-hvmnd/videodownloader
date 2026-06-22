import Testing
import Foundation
@testable import YTDLPEngine

@Suite struct ModelTests {
    @Test func downloadProgressDefaults() {
        let p = DownloadProgress()
        #expect(p.phase == .queued)
        #expect(p.fractionCompleted == nil)
    }

    @Test func formatVideoOnlyFlags() {
        let f = Format(id: "137", ext: "mp4", height: 1080, vcodec: "avc1.640028", acodec: "none")
        #expect(f.hasVideo)
        #expect(!f.hasAudio)
        #expect(f.resolutionLabel == "1080p")
    }

    @Test func formatAudioOnlyLabel() {
        let f = Format(id: "140", ext: "m4a", vcodec: "none", acodec: "mp4a.40.2", abr: 128)
        #expect(!f.hasVideo)
        #expect(f.hasAudio)
        #expect(f.resolutionLabel == "nur Audio")
    }

    @Test func downloadOptionsDefaults() {
        let opts = DownloadOptions(url: "https://example.com/x", outputDirectory: URL(fileURLWithPath: "/tmp"))
        #expect(opts.mode == .video(formatID: nil))
        #expect(opts.outputTemplate == "%(title)s [%(id)s].%(ext)s")
        #expect(opts.playlistItems == nil)
    }
}
