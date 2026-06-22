import Foundation
import Observation

struct HistoryEntry: Identifiable, Codable, Sendable {
    let id: UUID
    let title: String
    let url: String
    let path: String?
    let finishedAt: Date
}

/// Persistent history of completed downloads (UserDefaults).
@MainActor
@Observable
final class HistoryStore {
    private(set) var entries: [HistoryEntry] = []

    private let defaults: UserDefaults
    private let key = "downloadHistory"
    private let limit = 200

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func record(title: String, url: String, path: String?) {
        entries.insert(HistoryEntry(id: UUID(), title: title, url: url, path: path, finishedAt: Date()), at: 0)
        if entries.count > limit { entries = Array(entries.prefix(limit)) }
        save()
    }

    func remove(_ entry: HistoryEntry) {
        entries.removeAll { $0.id == entry.id }
        save()
    }

    func clear() {
        entries = []
        save()
    }

    private func load() {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([HistoryEntry].self, from: data) else { return }
        entries = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(entries) {
            defaults.set(data, forKey: key)
        }
    }
}
