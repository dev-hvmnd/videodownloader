import SwiftUI
import AppKit

/// History of completed downloads (as a sheet).
struct HistoryView: View {
    let history: HistoryStore
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("History").font(.headline)
                Spacer()
                Button("Close", action: onClose).keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            if history.entries.isEmpty {
                ContentUnavailableView("No history", systemImage: "clock",
                                       description: Text("Completed downloads appear here."))
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
                                    .help("Show in Finder")
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            Divider()
            HStack {
                Button("Clear history", role: .destructive) { history.clear() }
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
