import Foundation

/// Translates `DownloadOptions` into the yt-dlp argument list. Pure function -> testable with golden-file tests.
/// Produces the arguments AFTER `-m yt_dlp` (prepending those is handled by `YTDLPClient`).
public struct ArgumentBuilder: Sendable {
    public init() {}

    /// Global flags set on every invocation.
    public static func globalFlags() -> [String] {
        ["--ignore-config", "--no-color", "--no-warnings"]
    }

    /// Arguments for a probe (`-J`). `flat` ⇒ `--flat-playlist` (for playlists/channels).
    public func probeArguments(url: String, flat: Bool, noPlaylist: Bool) -> [String] {
        var args = Self.globalFlags()
        args.append("-J")
        if flat { args.append("--flat-playlist") }
        if noPlaylist { args.append("--no-playlist") }
        args.append(url)
        return args
    }

    /// Arguments for a download.
    public func downloadArguments(
        for options: DownloadOptions,
        ffmpegDirectory: URL,
        progressTemplate: String
    ) -> [String] {
        var args = Self.globalFlags()

        // Machine-readable progress
        args += ["--newline", "--progress-template", progressTemplate]
        args += ["--ffmpeg-location", ffmpegDirectory.path]
        args += ["--no-mtime"]

        // Format / mode
        switch options.mode {
        case .video(let formatID):
            args += ["-f", formatID ?? "bv*+ba/b"]
            if let container = options.mergeContainer {
                args += ["--merge-output-format", container.rawValue]
            }
        case .audioOnly(let audioFormat):
            args += ["-x", "--audio-format", audioFormat.rawValue, "--audio-quality", "0"]
        }

        // Subtitles
        if options.writeSubtitles { args.append("--write-subs") }
        if options.autoSubtitles { args.append("--write-auto-subs") }
        if (options.writeSubtitles || options.autoSubtitles), !options.subtitleLanguages.isEmpty {
            args += ["--sub-langs", options.subtitleLanguages.joined(separator: ",")]
        }
        if options.embedSubtitles { args.append("--embed-subs") }

        // Thumbnail / metadata
        if options.writeThumbnail { args.append("--write-thumbnail") }
        if options.embedThumbnail { args.append("--embed-thumbnail") }
        if options.embedMetadata { args.append("--embed-metadata") }

        // Playlist
        if let items = options.playlistItems { args += ["--playlist-items", items] }
        args.append(options.downloadPlaylist ? "--yes-playlist" : "--no-playlist")

        // Output
        args += ["-P", options.outputDirectory.path, "-o", options.outputTemplate]

        // URL last
        args.append(options.url)
        return args
    }
}
