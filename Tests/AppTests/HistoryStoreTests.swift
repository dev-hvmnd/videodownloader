import Testing
import Foundation
@testable import VideoDownloader

@MainActor
@Suite struct HistoryStoreTests {
    @Test func recordsNewestFirstAndPersists() {
        let name = "test.\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: name)!
        defer { suite.removePersistentDomain(forName: name) }

        let first = HistoryStore(defaults: suite)
        first.record(title: "A", url: "https://x/a", path: "/p/a.mp4")
        first.record(title: "B", url: "https://x/b", path: nil)
        #expect(first.entries.count == 2)
        #expect(first.entries.first?.title == "B")   // newest first

        // Persisted: a fresh instance sees the same entries.
        let second = HistoryStore(defaults: suite)
        #expect(second.entries.count == 2)
        #expect(second.entries.map(\.title) == ["B", "A"])

        second.clear()
        #expect(second.entries.isEmpty)
        #expect(HistoryStore(defaults: suite).entries.isEmpty)
    }
}
