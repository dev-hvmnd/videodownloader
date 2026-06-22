import SwiftUI
import AppKit

/// Settings (via the "Video Downloader › Settings…" menu, or ⌘,).
struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var settings = model.settings
        Form {
            Section("Download") {
                LabeledContent("Zielordner") {
                    HStack {
                        Text(settings.outputDirectory.path(percentEncoded: false))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundStyle(.secondary)
                        Button("Ändern …", action: chooseFolder)
                    }
                }
                Picker("Gleichzeitige Downloads", selection: $settings.maxConcurrentDownloads) {
                    ForEach(1...5, id: \.self) { count in
                        Text(count == 1 ? "1 (nacheinander)" : "\(count)").tag(count)
                    }
                }
                .pickerStyle(.menu)
            }

            Section("yt-dlp") {
                if let version = model.toolchain.versions?.ytdlp {
                    LabeledContent("Installierte Version", value: version)
                }
                Toggle("Beim Start automatisch aktualisieren", isOn: $settings.autoUpdateYTDLP)
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
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
