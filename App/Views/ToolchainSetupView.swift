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

            Text("First-time setup")
                .font(.title.bold())

            Text("On first launch the app downloads its tools (Python, ffmpeg, yt-dlp – about 80 MB in total) into “Application Support”. After that it is ready to use offline.")
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
                        Text("Please wait …").foregroundStyle(.secondary).font(.caption)
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
                    Label("Try again", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
            }

        default:
            Button {
                Task { await store.runSetup() }
            } label: {
                Label("Install tools", systemImage: "arrow.down.circle")
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
        case .python: component = String(localized: "Python runtime")
        case .ffmpeg: component = "ffmpeg / ffprobe"
        case .ytdlp:  component = "yt-dlp"
        }
        let step: String
        switch progress.step {
        case .downloading: step = String(localized: "downloading")
        case .verifying:   step = String(localized: "verifying")
        case .installing:  step = String(localized: "installing")
        case .signing:     step = String(localized: "signing")
        case .finalizing:  step = String(localized: "finishing")
        }
        if let frac = progress.fractionCompleted, progress.step == .downloading {
            return String(localized: "\(component) · \(step) … \(Int(frac * 100)) %")
        }
        return String(localized: "\(component) · \(step) …")
    }
}
