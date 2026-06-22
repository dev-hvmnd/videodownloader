import SwiftUI
import AppKit
import YTDLPEngine

/// Main view: paste a URL → download directly (best quality) or choose a format; list with progress.
struct MainView: View {
    @Environment(AppModel.self) private var model
    @State private var urlText = ""
    @State private var probing = false
    @State private var probedMedia: MediaInfo?
    @State private var probedPlaylist: PlaylistInfo?
    @State private var pendingURL = ""
    @State private var errorMessage: String?
    @State private var showHistory = false
    @State private var showOptions = false

    var body: some View {
        VStack(spacing: 0) {
            inputBar
            Divider()
            downloadList
            Divider()
            footer
        }
        .toolbar { toolbarContent }
        .navigationTitle("Video Downloader")
        .dropDestination(for: URL.self) { urls, _ in
            var added = false
            for url in urls where model.downloads.add(url: url.absoluteString) { added = true }
            return added
        }
        .sheet(item: $probedMedia) { media in
            FormatSelectionView(
                media: media,
                onSelect: { mode in
                    model.downloads.add(url: pendingURL) { $0.mode = mode }
                    probedMedia = nil
                    urlText = ""
                },
                onCancel: { probedMedia = nil }
            )
        }
        .sheet(item: $probedPlaylist) { playlist in
            PlaylistSelectionView(
                playlist: playlist,
                onConfirm: { entries in
                    for entry in entries {
                        if let url = entry.url { model.downloads.add(url: url) }
                    }
                    probedPlaylist = nil
                    urlText = ""
                },
                onCancel: { probedPlaylist = nil }
            )
        }
        .sheet(isPresented: $showHistory) {
            HistoryView(history: model.history) { showHistory = false }
        }
        .alert("Fehler", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .alert("yt-dlp", isPresented: Binding(
            get: { model.toolchain.lastMessage != nil },
            set: { if !$0 { model.toolchain.dismissMessage() } }
        )) {
            Button("OK", role: .cancel) { model.toolchain.dismissMessage() }
        } message: {
            Text(model.toolchain.lastMessage ?? "")
        }
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "link").foregroundStyle(.secondary)
            TextField("Video-URL einfügen …", text: $urlText)
                .textFieldStyle(.plain)
                .onSubmit(quickDownload)
                .disabled(probing)

            if probing {
                ProgressView().controlSize(.small)
            }

            Button {
                showOptions.toggle()
            } label: {
                Label("Optionen", systemImage: "gearshape")
            }
            .help("Audio-Extraktion, Untertitel, Thumbnails & Metadaten")
            .popover(isPresented: $showOptions, arrowEdge: .bottom) { optionsPopover }

            Button {
                probeAndChoose()
            } label: {
                Label("Auswählen …", systemImage: "slider.horizontal.3")
            }
            .help("Sondieren: Format wählen (Video) bzw. Einträge wählen (Playlist/Kanal)")
            .disabled(probing || isURLEmpty)

            Button(action: quickDownload) {
                Label("Laden", systemImage: "arrow.down.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(probing || isURLEmpty)
        }
        .padding(12)
    }

    @ViewBuilder private var downloadList: some View {
        if model.downloads.items.isEmpty {
            ContentUnavailableView(
                "Keine Downloads",
                systemImage: "tray.and.arrow.down",
                description: Text("Füge oben eine Video-URL ein – „Laden“ für beste Qualität oder „Format wählen“.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(model.downloads.items) { item in
                    DownloadRowView(
                        item: item,
                        onCancel: { model.downloads.cancel(item) },
                        onRemove: { model.downloads.remove(item) }
                    )
                }
            }
            .listStyle(.inset)
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Image(systemName: "folder")
            Text(model.settings.outputDirectory.path(percentEncoded: false))
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(.secondary)
            Spacer()
            if model.toolchain.isBusy {
                ProgressView().controlSize(.small)
                Text("yt-dlp wird aktualisiert …").foregroundStyle(.secondary)
            } else {
                Button("Ordner ändern …", action: chooseFolder)
                    .buttonStyle(.link)
            }
        }
        .font(.callout)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder private var optionsPopover: some View {
        @Bindable var settings = model.settings
        Form {
            Section("Format") {
                Toggle("Nur Audio (extrahieren)", isOn: $settings.audioOnly)
                if settings.audioOnly {
                    Picker("Audioformat", selection: $settings.audioFormatRaw) {
                        Text("MP3").tag("mp3")
                        Text("M4A").tag("m4a")
                        Text("Opus").tag("opus")
                        Text("Beste").tag("best")
                    }
                }
            }
            Section("Untertitel") {
                Toggle("Untertitel laden", isOn: $settings.writeSubtitles)
                Toggle("Auto-Untertitel", isOn: $settings.autoSubtitles)
                Toggle("In Datei einbetten", isOn: $settings.embedSubtitles)
                TextField("Sprachen (z. B. de,en)", text: $settings.subtitleLanguagesText)
            }
            Section("Extras") {
                Toggle("Thumbnail einbetten", isOn: $settings.embedThumbnail)
                Toggle("Metadaten einbetten", isOn: $settings.embedMetadata)
            }
        }
        .formStyle(.grouped)
        .frame(width: 320, height: 420)
    }

    @ToolbarContentBuilder private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button { showHistory = true } label: {
                Label("Verlauf", systemImage: "clock.arrow.circlepath")
            }
            .help("Verlauf anzeigen")
        }
        ToolbarItem(placement: .primaryAction) {
            Menu {
                if let version = model.toolchain.versions?.ytdlp {
                    Text("yt-dlp \(version)")
                    Divider()
                }
                Button("yt-dlp aktualisieren") {
                    Task { await model.toolchain.updateYTDLP() }
                }
                .disabled(model.toolchain.isBusy)
                Button("Abgeschlossene entfernen") {
                    model.downloads.clearFinished()
                }
                Divider()
                Button("Werkzeuge zurücksetzen …", role: .destructive) {
                    Task { await model.toolchain.reset() }
                }
            } label: {
                Label("Mehr", systemImage: "ellipsis.circle")
            }
        }
    }

    private var isURLEmpty: Bool {
        urlText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func quickDownload() {
        guard !isURLEmpty else { return }
        if model.downloads.add(url: urlText) {
            urlText = ""
        }
    }

    private func probeAndChoose() {
        let url = urlText.trimmingCharacters(in: .whitespaces)
        guard !url.isEmpty else { return }
        probing = true
        Task {
            do {
                let result = try await model.downloads.probe(url: url)
                pendingURL = url
                switch result {
                case .video(let media): probedMedia = media
                case .playlist(let playlist): probedPlaylist = playlist
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            probing = false
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = model.settings.outputDirectory
        if panel.runModal() == .OK, let url = panel.url {
            model.settings.outputDirectory = url
        }
    }
}
