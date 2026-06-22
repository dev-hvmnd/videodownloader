import SwiftUI
import YTDLPEngine

/// Selection of individual playlist/channel entries (as a sheet). Confirming enqueues one download per entry.
struct PlaylistSelectionView: View {
    let playlist: PlaylistInfo
    let onConfirm: ([PlaylistEntry]) -> Void
    let onCancel: () -> Void

    @State private var selected: Set<String>

    init(playlist: PlaylistInfo, onConfirm: @escaping ([PlaylistEntry]) -> Void, onCancel: @escaping () -> Void) {
        self.playlist = playlist
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        // by default, all downloadable entries are pre-selected
        _selected = State(initialValue: Set(playlist.entries.filter { $0.url != nil }.map(\.id)))
    }

    private var selectableIDs: Set<String> { Set(playlist.entries.filter { $0.url != nil }.map(\.id)) }
    private var allSelected: Bool { !selectableIDs.isEmpty && selected == selectableIDs }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.title).font(.headline).lineLimit(2)
                Text("\(playlist.entries.count) Einträge").font(.subheadline).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()

            Divider()

            HStack {
                Button(allSelected ? "Auswahl aufheben" : "Alle auswählen") { toggleAll() }
                    .disabled(selectableIDs.isEmpty)
                Spacer()
                Text("\(selected.count) ausgewählt").foregroundStyle(.secondary).font(.callout)
            }
            .padding(.horizontal).padding(.vertical, 8)

            List {
                ForEach(playlist.entries) { entry in
                    Toggle(isOn: binding(for: entry)) {
                        HStack {
                            Text("\(entry.index). \(entry.title)").lineLimit(1).truncationMode(.middle)
                            Spacer()
                            if let duration = Fmt.duration(entry.duration) {
                                Text(duration).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .toggleStyle(.checkbox)
                    .disabled(entry.url == nil)
                }
            }

            Divider()
            HStack {
                Button("Abbrechen", role: .cancel, action: onCancel).keyboardShortcut(.cancelAction)
                Spacer()
                Button("\(selected.count) herunterladen") { confirm() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(selected.isEmpty)
            }
            .padding()
        }
        .frame(width: 560, height: 560)
    }

    private func binding(for entry: PlaylistEntry) -> Binding<Bool> {
        Binding(
            get: { selected.contains(entry.id) },
            set: { isOn in
                if isOn { selected.insert(entry.id) } else { selected.remove(entry.id) }
            }
        )
    }

    private func toggleAll() {
        selected = allSelected ? [] : selectableIDs
    }

    private func confirm() {
        let chosen = playlist.entries.filter { selected.contains($0.id) }
        onConfirm(chosen)
    }
}
