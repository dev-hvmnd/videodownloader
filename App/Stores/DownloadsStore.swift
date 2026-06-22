import Foundation
import Observation
import YTDLPEngine

/// Manages the download queue with a concurrency limit; writes completed ones to the history.
///
/// The concurrency limit is counted by **active tasks**, not by UI state. A download's queue slot
/// is therefore released only when its task actually finishes (after the process has ended), so
/// cancelling never lets the limit be exceeded by still-terminating processes.
@MainActor
@Observable
final class DownloadsStore {
    private(set) var items: [DownloadItem] = []

    private let settings: SettingsStore
    private let history: HistoryStore
    private let runtimeProvider: @MainActor () -> YTDLPRuntime?
    private let runner: any ProcessRunning

    private var tasks: [UUID: Task<Void, Never>] = [:]
    private var pendingOptions: [UUID: DownloadOptions] = [:]

    init(
        settings: SettingsStore,
        history: HistoryStore,
        runtimeProvider: @escaping @MainActor () -> YTDLPRuntime?,
        runner: any ProcessRunning = FoundationProcessRunner()
    ) {
        self.settings = settings
        self.history = history
        self.runtimeProvider = runtimeProvider
        self.runner = runner
    }

    /// True while any download task is in flight (running or still winding down after a cancel).
    var hasActiveDownloads: Bool { !tasks.isEmpty }
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
        guard !trimmed.isEmpty else { throw YTDLPError.invalidURL("(empty)") }
        guard let runtime = runtimeProvider() else { throw YTDLPError.toolchainNotReady }
        return try await YTDLPClient(runtime: runtime, runner: runner).probe(url: trimmed)
    }

    func cancel(_ item: DownloadItem) {
        item.state = .cancelled
        pendingOptions[item.id] = nil
        if let task = tasks[item.id] {
            task.cancel()   // run()'s cleanup removes it from `tasks` and pumps once the process ends
        } else {
            pump()          // it was only queued; no slot was held
        }
    }

    func remove(_ item: DownloadItem) {
        pendingOptions[item.id] = nil
        items.removeAll { $0.id == item.id }
        if let task = tasks[item.id] {
            task.cancel()   // slot is released by run()'s cleanup
        } else {
            pump()
        }
    }

    func clearFinished() {
        items.removeAll { !$0.state.isActive && tasks[$0.id] == nil }
    }

    // MARK: - Scheduling

    private func pump() {
        var freeSlots = max(0, settings.maxConcurrentDownloads - tasks.count)
        guard freeSlots > 0 else { return }

        for item in items where item.state == .waiting && tasks[item.id] == nil {
            guard freeSlots > 0 else { break }
            guard let options = pendingOptions[item.id], let runtime = runtimeProvider() else { continue }
            pendingOptions[item.id] = nil
            start(item: item, options: options, runtime: runtime)
            freeSlots -= 1
        }
    }

    private func start(item: DownloadItem, options: DownloadOptions, runtime: YTDLPRuntime) {
        item.state = .running
        let client = YTDLPClient(runtime: runtime, runner: runner)
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
        tasks[item.id] = nil   // release the slot only now (task has fully finished)
        if item.state == .completed {
            history.record(title: item.title, url: item.url, path: item.outputPath)
        }
        pump()   // start the next waiting download
    }
}
