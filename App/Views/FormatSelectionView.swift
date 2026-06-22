import SwiftUI
import YTDLPEngine

/// Selection of a format after the probe (`-J`). Shown as a sheet.
struct FormatSelectionView: View {
    let media: MediaInfo
    let onSelect: (DownloadOptions.Mode) -> Void
    let onCancel: () -> Void

    private var videoFormats: [Format] {
        media.formats.filter(\.hasVideo)
            .sorted { ($0.height ?? 0, $0.tbr ?? 0) > ($1.height ?? 0, $1.tbr ?? 0) }
    }
    private var audioFormats: [Format] {
        media.formats.filter { !$0.hasVideo && $0.hasAudio }
            .sorted { ($0.abr ?? $0.tbr ?? 0) > ($1.abr ?? $1.tbr ?? 0) }
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
                    Button { onSelect(.video(formatID: nil)) } label: {
                        Label("Best quality (video + audio)", systemImage: "star.fill")
                    }
                }
                if !videoFormats.isEmpty {
                    Section("Video") {
                        ForEach(videoFormats) { format in
                            formatButton(format, mode: .video(formatID: formatString(for: format)))
                        }
                    }
                }
                Section("Extract audio") {
                    Button { onSelect(.audioOnly(.mp3)) } label: {
                        Label("As MP3 (convert)", systemImage: "music.note")
                    }
                    Button { onSelect(.audioOnly(.m4a)) } label: {
                        Label("As M4A (convert)", systemImage: "music.note")
                    }
                }
                if !audioFormats.isEmpty {
                    Section("Audio track (original format)") {
                        ForEach(audioFormats) { format in
                            formatButton(format, mode: .video(formatID: format.id))
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

    private func formatButton(_ format: Format, mode: DownloadOptions.Mode) -> some View {
        Button { onSelect(mode) } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label(for: format))
                    Text(detail(for: format)).font(.caption).foregroundStyle(.secondary)
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

    /// Video-only formats need the best audio added (yt-dlp merges via ffmpeg).
    private func formatString(for format: Format) -> String {
        (format.hasVideo && !format.hasAudio) ? "\(format.id)+bestaudio/\(format.id)" : format.id
    }

    private func label(for format: Format) -> String {
        if format.hasVideo {
            var text = format.resolutionLabel
            if let fps = format.fps, fps > 0 { text += " · \(Int(fps)) fps" }
            return text
        }
        if let abr = format.abr, abr > 0 { return String(localized: "Audio · \(Int(abr)) kbit/s") }
        return String(localized: "Audio")
    }

    private func detail(for format: Format) -> String {
        var parts: [String] = []
        if let ext = format.ext { parts.append(ext) }
        if format.hasVideo, let vcodec = format.vcodec { parts.append(vcodec) }
        if format.hasAudio, let acodec = format.acodec { parts.append(acodec) }
        if let note = format.formatNote, !note.isEmpty { parts.append(note) }
        return parts.joined(separator: " · ")
    }
}
