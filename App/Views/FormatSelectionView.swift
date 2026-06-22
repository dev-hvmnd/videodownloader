import SwiftUI
import YTDLPEngine

/// Selection of a format after the probe (`-J`). Shown as a sheet.
///
/// Video is offered by resolution + frame rate (codec/container hidden); every download is delivered
/// as mp4. WebM is never a separate choice. `onSelect` carries the target container — `.mp4` for
/// video, `nil` for raw-audio picks (where remuxing would be wrong).
struct FormatSelectionView: View {
    let media: MediaInfo
    let onSelect: (DownloadOptions.Mode, DownloadOptions.Container?) -> Void
    let onCancel: () -> Void

    private var videoQualities: [VideoQuality] {
        FormatCatalog.videoQualities(from: media.formats)
    }
    private var audioTracks: [Format] {
        FormatCatalog.audioTracks(from: media.formats)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(media.title).font(.headline).lineLimit(2)
                if let uploader = media.uploader {
                    Text(uploader).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .padding()

            Divider()

            List {
                Section {
                    Button { onSelect(.video(formatID: nil), .mp4) } label: {
                        Label("Best quality (video + audio)", systemImage: "star.fill")
                    }
                }
                if !videoQualities.isEmpty {
                    Section("Video (MP4)") {
                        ForEach(videoQualities) { quality in
                            qualityButton(quality)
                        }
                    }
                }
                Section("Extract audio") {
                    Button { onSelect(.audioOnly(.mp3), nil) } label: {
                        Label("As MP3 (convert)", systemImage: "music.note")
                    }
                    Button { onSelect(.audioOnly(.m4a), nil) } label: {
                        Label("As M4A (convert)", systemImage: "music.note")
                    }
                }
                if !audioTracks.isEmpty {
                    Section("Audio track (original format)") {
                        ForEach(audioTracks) { format in
                            audioButton(format)
                        }
                    }
                }
            }

            Divider()
            HStack {
                Spacer()
                Button("Cancel", role: .cancel, action: onCancel)
                    .keyboardShortcut(.cancelAction)
            }
            .padding()
        }
        .frame(width: 540, height: 520)
    }

    private func qualityButton(_ quality: VideoQuality) -> some View {
        Button { onSelect(.video(formatID: quality.formatSelector), .mp4) } label: {
            HStack {
                Text(label(for: quality))
                Spacer()
                if let size = Fmt.bytes(quality.approximateFilesize) {
                    Text(size).font(.caption).foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func audioButton(_ format: Format) -> some View {
        Button { onSelect(.video(formatID: format.id), nil) } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    if let abr = format.abr, abr > 0 {
                        Text(String(localized: "Audio · \(Int(abr)) kbit/s"))
                    } else {
                        Text(String(localized: "Audio"))
                    }
                    Text(audioDetail(for: format)).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if let size = Fmt.bytes(format.bestKnownFilesize) {
                    Text(size).font(.caption).foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func label(for quality: VideoQuality) -> String {
        var text = "\(quality.height)p"
        if let fps = quality.fps { text += " · \(fps) fps" }
        return text
    }

    private func audioDetail(for format: Format) -> String {
        var parts: [String] = []
        if let ext = format.ext { parts.append(ext) }
        if let acodec = format.acodec { parts.append(acodec) }
        return parts.joined(separator: " · ")
    }
}
