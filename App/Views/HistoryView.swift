import SwiftUI
import AppKit

/// History of completed downloads (as a sheet).
struct HistoryView: View {
    let history: HistoryStore
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Verlauf").font(.headline)
                Spacer()
                Button("Schließen", action: onClose).keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            if history.entries.isEmpty {
                ContentUnavailableView("Kein Verlauf", systemImage: "clock",
                                       description: Text("Abgeschlossene Downloads erscheinen hier."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(history.entries) { entry in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.title).lineLimit(1).truncationMode(.middle)
                                Text(entry.finishedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if let path = entry.path, FileManager.default.fileExists(atPath: path) {
                                Button { reveal(path) } label: { Image(systemName: "magnifyingglass.circle") }
                                    .buttonStyle(.borderless)
                                    .help("Im Finder zeigen")
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            Divider()
            HStack {
                Button("Verlauf leeren", role: .destructive) { history.clear() }
                    .disabled(history.entries.isEmpty)
                Spacer()
            }
            .padding()
        }
        .frame(width: 540, height: 480)
    }

    private func reveal(_ path: String) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }
}
