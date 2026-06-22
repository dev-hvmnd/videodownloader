import Testing
import Foundation
@testable import YTDLPEngine

@Suite struct ArgumentBuilderTests {
    let builder = ArgumentBuilder()
    let ffmpeg = URL(fileURLWithPath: "/tmp/ff/bin")
    let outDir = URL(fileURLWithPath: "/tmp/out")
    let template = ProgressParser.downloadTemplate

    private func args(_ options: DownloadOptions) -> [String] {
        builder.downloadArguments(for: options, ffmpegDirectory: ffmpeg, progressTemplate: template)
    }

    @Test func videoBestDefaults() {
        let a = args(DownloadOptions(url: "https://x/v", outputDirectory: outDir))
        #expect(a.contains("--ignore-config"))
        #expect(a.contains("--newline"))
        #expect(a.firstIndex(of: "-f").map { a[$0 + 1] } == "bv*+ba/b")
        #expect(a.contains("--no-playlist"))
        #expect(a.firstIndex(of: "--ffmpeg-location").map { a[$0 + 1] } == "/tmp/ff/bin")
        #expect(a.firstIndex(of: "-P").map { a[$0 + 1] } == "/tmp/out")
        #expect(a.last == "https://x/v")        // URL always last
    }

    @Test func specificFormatAndContainer() {
        var o = DownloadOptions(url: "u", mode: .video(formatID: "137+140"), outputDirectory: outDir)
        o.mergeContainer = .mp4
        let a = args(o)
        #expect(a.firstIndex(of: "-f").map { a[$0 + 1] } == "137+140")
        #expect(a.firstIndex(of: "--merge-output-format").map { a[$0 + 1] } == "mp4")
    }

    @Test func audioExtraction() {
        let o = DownloadOptions(url: "u", mode: .audioOnly(.mp3), outputDirectory: outDir)
        let a = args(o)
        #expect(a.contains("-x"))
        #expect(a.firstIndex(of: "--audio-format").map { a[$0 + 1] } == "mp3")
        #expect(!a.contains("-f"))
    }

    @Test func subtitlesAndThumbnails() {
        var o = DownloadOptions(url: "u", outputDirectory: outDir)
        o.writeSubtitles = true
        o.autoSubtitles = true
        o.embedSubtitles = true
        o.subtitleLanguages = ["de", "en"]
        o.embedThumbnail = true
        o.embedMetadata = true
        let a = args(o)
        #expect(a.contains("--write-subs"))
        #expect(a.contains("--write-auto-subs"))
        #expect(a.contains("--embed-subs"))
        #expect(a.firstIndex(of: "--sub-langs").map { a[$0 + 1] } == "de,en")
        #expect(a.contains("--embed-thumbnail"))
        #expect(a.contains("--embed-metadata"))
    }

    @Test func playlistSelection() {
        var o = DownloadOptions(url: "u", outputDirectory: outDir)
        o.downloadPlaylist = true
        o.playlistItems = "1,3,5-8"
        let a = args(o)
        #expect(a.firstIndex(of: "--playlist-items").map { a[$0 + 1] } == "1,3,5-8")
        #expect(a.contains("--yes-playlist"))
        #expect(!a.contains("--no-playlist"))
    }
}
