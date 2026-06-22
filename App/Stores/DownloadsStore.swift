import Foundation
import Observation
import YTDLPEngine

/// Manages the download queue with a concurrency limit; writes completed ones to the history.
@MainActor
@Observable
final class DownloadsStore {
    private(set) var items: [DownloadItem] = []

    private let settings: SettingsStore
    private let history: HistoryStore
    private let runtimeProvider: @MainActor () -> YTDLPRuntime?

    private var tasks: [UUID: Task<Void, Never>] = [:]
    private var pendingOptions: [UUID: DownloadOptions] = [:]

    init(
        settings: SettingsStore,
        history: HistoryStore,
        runtimeProvider: @escaping @MainActor () -> YTDLPRuntime?
    ) {
        self.settings = settings
        self.history = history
        self.runtimeProvider = runtimeProvider
    }

    var activeCount: Int { items.filter { $0.state.isActive }.count }

    /// Enqueues a download (starts immediately if a slot is free).
    @discardableResult
    func add(url: String, configure: ((inout DownloadOptions) -> Void)? = nil) -> Bool {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, runtimeProvider() != nil else { return false }

        let item = DownloadItem(url: trimmed)
        var options = DownloadOptions(url: trimmed, outputDirectory: settings.outputDirectory)
        settings.applyDownloadPreferences(to: &options)   // audio/subtitles/thumbnails from the preferences
        configure?(&options)                               // explicit format choice overrides the mode
        pendingOptions[item.id] = options
        items.append(item)
        pump()
        return true
    }

    /// Probes a URL (single video → formats, playlist → entries).
    func probe(url: String) async throws -> ProbeResult {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw YTDLPError.invalidURL("(leer)") }
        guard let runtime = runtimeProvider() else { throw YTDLPError.toolchainNotReady }
        return try await YTDLPClient(runtime: runtime).probe(url: trimmed)
    }

    func cancel(_ item: DownloadItem) {
        item.state = .cancelled
        pendingOptions[item.id] = nil
        tasks[item.id]?.cancel()
        tasks[item.id] = nil
        pump()
    }

    func remove(_ item: DownloadItem) {
        pendingOptions[item.id] = nil
        tasks[item.id]?.cancel()
        tasks[item.id] = nil
        items.removeAll { $0.id == item.id }
        pump()
    }

    func clearFinished() {
        for item in items where !item.state.isActive { tasks[item.id] = nil }
        items.removeAll { !$0.state.isActive }
    }

    // MARK: - Scheduling

    private func pump() {
        let runningCount = items.filter { $0.state == .running }.count
        var freeSlots = max(0, settings.maxConcurrentDownloads - runningCount)
        guard freeSlots > 0 else { return }

        for item in items where item.state == .waiting {
            guard freeSlots > 0 else { break }
            guard let options = pendingOptions[item.id], let runtime = runtimeProvider() else { continue }
            pendingOptions[item.id] = nil
            start(item: item, options: options, runtime: runtime)
            freeSlots -= 1
        }
    }

    private func start(item: DownloadItem, options: DownloadOptions, runtime: YTDLPRuntime) {
        item.state = .running
        let client = YTDLPClient(runtime: runtime)
        tasks[item.id] = Task { [weak self] in
            await self?.run(item: item, client: client, options: options)
        }
    }

    private func run(item: DownloadItem, client: YTDLPClient, options: DownloadOptions) async {
        do {
            for try await event in client.download(options) {
                switch event {
                case .destination(let path):
                    item.outputPath = path
                    item.title = (path as NSString).lastPathComponent
                case .progress(let progress):
                    item.progress = progress
                case .completed:
                    item.state = .completed
                }
            }
            if item.state == .running { item.state = .completed }
        } catch {
            if Task.isCancelled || item.state == .cancelled {
                item.state = .cancelled
            } else {
                item.state = .failed(error.localizedDescription)
            }
        }
        tasks[item.id] = nil
        if item.state == .completed {
            history.record(title: item.title, url: item.url, path: item.outputPath)
        }
        pump()   // start the next waiting download
    }
}
