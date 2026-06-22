import Testing
import Foundation
@testable import VideoDownloader
import YTDLPEngine

@MainActor
@Suite struct DownloadsStoreTests {
    private func makeStore(runner: StubRunner, maxConcurrent: Int = 2) -> (DownloadsStore, HistoryStore) {
        let suite = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        let settings = SettingsStore(defaults: suite)
        settings.maxConcurrentDownloads = maxConcurrent
        settings.outputDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
        let history = HistoryStore(defaults: suite)
        let runtime = YTDLPRuntime(
            pythonExecutable: URL(fileURLWithPath: "/usr/bin/true"),
            modulePath: URL(fileURLWithPath: NSTemporaryDirectory()),
            ffmpegDirectory: URL(fileURLWithPath: NSTemporaryDirectory())
        )
        let store = DownloadsStore(settings: settings, history: history, runtimeProvider: { runtime }, runner: runner)
        return (store, history)
    }

    @Test func completionRecordsHistoryWithParsedTitle() async throws {
        let (store, history) = makeStore(runner: StubRunner(mode: .complete, destinationName: "clip.mp4"))
        store.add(url: "https://example.com/v")
        try await waitUntil("completed") { store.items.first?.state == .completed }
        #expect(history.entries.count == 1)
        #expect(history.entries.first?.title == "clip.mp4")
        #expect(!store.hasActiveDownloads)
    }

    @Test func respectsConcurrencyLimitAndPromotesQueuedOnCancel() async throws {
        let runner = StubRunner(mode: .block)
        let (store, _) = makeStore(runner: runner, maxConcurrent: 2)
        store.add(url: "a")
        store.add(url: "b")
        store.add(url: "c")

        try await waitUntil("two started") { runner.started >= 2 }
        try await Task.sleep(nanoseconds: 80_000_000)   // ensure the 3rd does not slip past the limit
        #expect(runner.started == 2)
        #expect(store.items.filter { $0.state == .running }.count == 2)
        #expect(store.items.filter { $0.state == .waiting }.count == 1)
        #expect(store.hasActiveDownloads)

        let running = try #require(store.items.first { $0.state == .running })
        store.cancel(running)

        try await waitUntil("queued promoted") { runner.started >= 3 }
        #expect(store.items.filter { $0.state == .running }.count == 2)   // limit still respected
        #expect(store.items.contains { $0.state == .cancelled })

        for item in store.items where item.state == .running { store.cancel(item) }
        try await waitUntil("drained") { !store.hasActiveDownloads }
    }

    @Test func rejectsEmptyURL() {
        let (store, _) = makeStore(runner: StubRunner(mode: .complete))
        #expect(store.add(url: "   ") == false)
        #expect(store.items.isEmpty)
    }
}
