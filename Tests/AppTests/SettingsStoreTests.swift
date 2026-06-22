import Testing
import Foundation
@testable import VideoDownloader
import YTDLPEngine

@MainActor
@Suite struct SettingsStoreTests {
    @Test func persistsAcrossInstances() {
        let name = "test.\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: name)!
        defer { suite.removePersistentDomain(forName: name) }

        let first = SettingsStore(defaults: suite)
        first.maxConcurrentDownloads = 4
        first.audioOnly = true
        first.audioFormatRaw = "m4a"
        first.subtitleLanguagesText = "fr,es"
        first.embedThumbnail = true
        first.autoUpdateYTDLP = true
        let dir = URL(fileURLWithPath: "/tmp/vd-test-out")
        first.outputDirectory = dir

        let second = SettingsStore(defaults: suite)
        #expect(second.maxConcurrentDownloads == 4)
        #expect(second.audioOnly)
        #expect(second.audioFormatRaw == "m4a")
        #expect(second.subtitleLanguagesText == "fr,es")
        #expect(second.embedThumbnail)
        #expect(second.autoUpdateYTDLP)
        #expect(second.outputDirectory.path == dir.path)
    }

    @Test func appliesPreferencesToOptions() {
        let suite = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        let settings = SettingsStore(defaults: suite)
        settings.audioOnly = true
        settings.audioFormatRaw = "mp3"
        settings.writeSubtitles = true
        settings.subtitleLanguagesText = "de, en"
        settings.embedThumbnail = true

        var options = DownloadOptions(url: "u", outputDirectory: URL(fileURLWithPath: "/tmp"))
        settings.applyDownloadPreferences(to: &options)

        #expect(options.mode == .audioOnly(.mp3))
        #expect(options.mergeContainer == nil)   // audio-only must not force a video remux
        #expect(options.writeSubtitles)
        #expect(options.subtitleLanguages == ["de", "en"])
        #expect(options.embedThumbnail)
    }
}
