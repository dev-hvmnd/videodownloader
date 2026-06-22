import Foundation
import Observation
import Toolchain
import YTDLPEngine

/// UI-facing state of the toolchain. Drives the `ToolchainManager` and mirrors its status.
@MainActor
@Observable
final class ToolchainStore {
    private(set) var status: ToolchainStatus = .unknown
    private(set) var versions: ToolchainVersions?
    private(set) var isBusy = false
    private(set) var lastMessage: String?

    private let manager: (any ToolchainProviding)?
    private let initError: String?

    init() {
        do {
            self.manager = try ToolchainManager.makeDefault()
            self.initError = nil
        } catch {
            self.manager = nil
            self.initError = error.localizedDescription
        }
    }

    var isReady: Bool {
        if case .ready = status { return true }
        return false
    }

    /// Runtime context for executing yt-dlp (paths exist regardless of the ready status).
    func runtime() -> YTDLPRuntime? {
        guard let manager else { return nil }
        let paths = manager.paths
        return YTDLPRuntime(
            pythonExecutable: paths.pythonExecutable,
            modulePath: paths.ytdlpDir,
            ffmpegDirectory: paths.ffmpegDir
        )
    }

    /// Checks (without installing) whether all tools are ready.
    func checkStatus() async {
        guard let manager else {
            status = .failed(initError ?? "Toolchain-Manager nicht initialisiert.")
            return
        }
        status = .checking
        apply(await manager.currentStatus())
    }

    /// Downloads/installs missing tools and reports progress continuously.
    func runSetup() async {
        guard let manager else {
            status = .failed(initError ?? "Toolchain-Manager nicht initialisiert.")
            return
        }
        isBusy = true
        defer { isBusy = false }
        for await newStatus in manager.setup() {
            apply(newStatus)
        }
    }

    /// Updates yt-dlp via pip; sets `lastMessage`.
    /// `announceUnchanged: false` (e.g. auto-update at launch) reports only real updates/errors.
    func updateYTDLP(announceUnchanged: Bool = true) async {
        guard let manager else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            let (old, new) = try await manager.updateYTDLP()
            await checkStatus()
            if let new {
                if let old, old != new {
                    lastMessage = "yt-dlp aktualisiert: \(old) → \(new)"
                } else if announceUnchanged {
                    lastMessage = "yt-dlp ist aktuell (\(new))"
                }
            }
        } catch {
            lastMessage = "Update fehlgeschlagen: \(error.localizedDescription)"
        }
    }

    /// Removes all tools and re-checks the status.
    func reset() async {
        guard let manager else { return }
        isBusy = true
        defer { isBusy = false }
        try? await manager.reset()
        versions = nil
        await checkStatus()
    }

    func dismissMessage() { lastMessage = nil }

    private func apply(_ newStatus: ToolchainStatus) {
        status = newStatus
        if case .ready(let v) = newStatus { versions = v }
    }
}
