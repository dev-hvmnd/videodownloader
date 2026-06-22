import SwiftUI
import AppKit
import YTDLPEngine

struct DownloadRowView: View {
    let item: DownloadItem
    let onCancel: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            statusIcon
                .font(.title3)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 5) {
                Text(item.title)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if item.state.isActive {
                    if let fraction = item.progress.fractionCompleted {
                        ProgressView(value: fraction).progressViewStyle(.linear)
                    } else {
                        ProgressView().progressViewStyle(.linear)   // indeterminate
                    }
                }

                Text(subline)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            HStack(spacing: 2) {
                if item.state == .completed, let path = item.outputPath {
                    Button { revealInFinder(path) } label: {
                        Image(systemName: "magnifyingglass.circle")
                    }
                    .buttonStyle(.borderless)
                    .help("Im Finder zeigen")
                }
                actionButton
            }
        }
        .padding(.vertical, 4)
    }

    private func revealInFinder(_ path: String) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    @ViewBuilder private var statusIcon: some View {
        switch item.state {
        case .waiting:   Image(systemName: "clock").foregroundStyle(.secondary)
        case .running:   Image(systemName: "arrow.down.circle").foregroundStyle(.tint)
        case .completed: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed:    Image(systemName: "xmark.octagon.fill").foregroundStyle(.red)
        case .cancelled: Image(systemName: "minus.circle").foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var actionButton: some View {
        switch item.state {
        case .waiting, .running:
            Button(role: .cancel, action: onCancel) {
                Image(systemName: "stop.circle")
            }
            .buttonStyle(.borderless)
            .help("Abbrechen")
        default:
            Button(action: onRemove) {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .help("Aus Liste entfernen")
        }
    }

    private var subline: String {
        switch item.state {
        case .waiting:
            return "Wartet …"
        case .running:
            switch item.progress.phase {
            case .postProcessing(let label):
                return "Nachbearbeitung: \(label) …"
            case .finished:
                return "Wird abgeschlossen …"
            default:
                var parts: [String] = []
                if let pct = item.progress.fractionCompleted { parts.append("\(Int(pct * 100)) %") }
                if let speed = Fmt.speed(item.progress.speedBytesPerSecond) { parts.append(speed) }
                if let eta = Fmt.eta(item.progress.etaSeconds) { parts.append(eta) }
                if parts.isEmpty { parts.append("Wird geladen …") }
                return parts.joined(separator: " · ")
            }
        case .completed:
            return "Fertig"
        case .failed(let message):
            return message
        case .cancelled:
            return "Abgebrochen"
        }
    }
}
