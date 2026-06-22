import Foundation
import Observation

/// Root state of the app. Holds the sub-stores; injected via `.environment`.
@MainActor
@Observable
final class AppModel {
    let settings: SettingsStore
    let history: HistoryStore
    let toolchain: ToolchainStore
    let downloads: DownloadsStore

    init() {
        let settings = SettingsStore()
        let history = HistoryStore()
        let toolchain = ToolchainStore()
        self.settings = settings
        self.history = history
        self.toolchain = toolchain
        self.downloads = DownloadsStore(
            settings: settings,
            history: history,
            runtimeProvider: { toolchain.runtime() }
        )
    }
}
