import Foundation
import Observation
import YTDLPEngine

/// Persistent settings + download preferences (UserDefaults).
@MainActor
@Observable
final class SettingsStore {
    var outputDirectory: URL { didSet { defaults.set(outputDirectory.path, forKey: Keys.outputDirectory) } }
    /// 1 = sequential, >1 = parallel.
    var maxConcurrentDownloads: Int { didSet { defaults.set(maxConcurrentDownloads, forKey: Keys.maxConcurrent) } }

    // Download preferences
    var audioOnly: Bool { didSet { defaults.set(audioOnly, forKey: Keys.audioOnly) } }
    var audioFormatRaw: String { didSet { defaults.set(audioFormatRaw, forKey: Keys.audioFormat) } }
    var writeSubtitles: Bool { didSet { defaults.set(writeSubtitles, forKey: Keys.writeSubs) } }
    var autoSubtitles: Bool { didSet { defaults.set(autoSubtitles, forKey: Keys.autoSubs) } }
    var embedSubtitles: Bool { didSet { defaults.set(embedSubtitles, forKey: Keys.embedSubs) } }
    var subtitleLanguagesText: String { didSet { defaults.set(subtitleLanguagesText, forKey: Keys.subLangs) } }
    var embedThumbnail: Bool { didSet { defaults.set(embedThumbnail, forKey: Keys.embedThumb) } }
    var embedMetadata: Bool { didSet { defaults.set(embedMetadata, forKey: Keys.embedMeta) } }

    /// Automatically update yt-dlp at launch.
    var autoUpdateYTDLP: Bool { didSet { defaults.set(autoUpdateYTDLP, forKey: Keys.autoUpdate) } }

    private let defaults = UserDefaults.standard
    private enum Keys {
        static let outputDirectory = "outputDirectory"
        static let maxConcurrent = "maxConcurrentDownloads"
        static let audioOnly = "pref.audioOnly"
        static let audioFormat = "pref.audioFormat"
        static let writeSubs = "pref.writeSubtitles"
        static let autoSubs = "pref.autoSubtitles"
        static let embedSubs = "pref.embedSubtitles"
        static let subLangs = "pref.subtitleLanguages"
        static let embedThumb = "pref.embedThumbnail"
        static let embedMeta = "pref.embedMetadata"
        static let autoUpdate = "pref.autoUpdateYTDLP"
    }

    init() {
        let defaults = UserDefaults.standard
        if let path = defaults.string(forKey: Keys.outputDirectory) {
            outputDirectory = URL(fileURLWithPath: path)
        } else {
            outputDirectory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
                ?? FileManager.default.homeDirectoryForCurrentUser
        }
        let stored = defaults.integer(forKey: Keys.maxConcurrent)
        maxConcurrentDownloads = stored == 0 ? 2 : min(max(stored, 1), 5)

        audioOnly = defaults.bool(forKey: Keys.audioOnly)
        audioFormatRaw = defaults.string(forKey: Keys.audioFormat) ?? DownloadOptions.AudioFormat.mp3.rawValue
        writeSubtitles = defaults.bool(forKey: Keys.writeSubs)
        autoSubtitles = defaults.bool(forKey: Keys.autoSubs)
        embedSubtitles = defaults.bool(forKey: Keys.embedSubs)
        subtitleLanguagesText = defaults.string(forKey: Keys.subLangs) ?? "de,en"
        embedThumbnail = defaults.bool(forKey: Keys.embedThumb)
        embedMetadata = defaults.bool(forKey: Keys.embedMeta)
        autoUpdateYTDLP = defaults.bool(forKey: Keys.autoUpdate)
    }

    /// Applies the persistent preferences to a download job.
    func applyDownloadPreferences(to options: inout DownloadOptions) {
        if audioOnly {
            options.mode = .audioOnly(DownloadOptions.AudioFormat(rawValue: audioFormatRaw) ?? .mp3)
        }
        options.writeSubtitles = writeSubtitles
        options.autoSubtitles = autoSubtitles
        options.embedSubtitles = embedSubtitles
        let languages = subtitleLanguagesText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        if !languages.isEmpty { options.subtitleLanguages = languages }
        options.embedThumbnail = embedThumbnail
        options.embedMetadata = embedMetadata
    }
}
