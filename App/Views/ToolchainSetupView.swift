import SwiftUI
import Toolchain

/// First-time setup: downloads Python/ffmpeg/yt-dlp and shows the progress.
struct ToolchainSetupView: View {
    let store: ToolchainStore

    var body: some View {
        VStack(spacing: 22) {
            Image(systemName: "arrow.down.app.fill")
                .font(.system(size: 52))
                .foregroundStyle(.tint)

            Text("Erstes Einrichten")
                .font(.title.bold())

            Text("Beim ersten Start lädt die App ihre Werkzeuge (Python, ffmpeg, yt-dlp – zusammen ca. 80 MB) nach „Application Support“. Danach ist sie offline einsatzbereit.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 480)

            content
                .frame(maxWidth: 420)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder private var content: some View {
        switch store.status {
        case .installing(let progress):
            VStack(spacing: 8) {
                ProgressView(value: progress.fractionCompleted ?? 0) {
                    Text(label(for: progress))
                        .font(.callout)
                }
                .progressViewStyle(.linear)
                if progress.fractionCompleted == nil {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text("Bitte warten …").foregroundStyle(.secondary).font(.caption)
                    }
                }
            }

        case .failed(let message):
            VStack(spacing: 12) {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .font(.callout)
                Button {
                    Task { await store.runSetup() }
                } label: {
                    Label("Erneut versuchen", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
            }

        default:
            Button {
                Task { await store.runSetup() }
            } label: {
                Label("Werkzeuge installieren", systemImage: "arrow.down.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(store.isBusy)
        }
    }

    private func label(for progress: ToolchainProgress) -> String {
        let component: String
        switch progress.component {
        case .python: component = "Python-Laufzeit"
        case .ffmpeg: component = "ffmpeg / ffprobe"
        case .ytdlp:  component = "yt-dlp"
        }
        let step: String
        switch progress.step {
        case .downloading: step = "wird geladen"
        case .verifying:   step = "wird geprüft"
        case .installing:  step = "wird installiert"
        case .signing:     step = "wird signiert"
        case .finalizing:  step = "wird abgeschlossen"
        }
        if let frac = progress.fractionCompleted, progress.step == .downloading {
            return "\(component) · \(step) … \(Int(frac * 100)) %"
        }
        return "\(component) · \(step) …"
    }
}
