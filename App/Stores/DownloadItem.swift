import Foundation
import Observation
import YTDLPEngine

/// An entry in the download list. `@Observable` so the row updates granularly.
@MainActor
@Observable
final class DownloadItem: Identifiable {
    let id = UUID()
    let url: String
    var title: String
    var progress: DownloadProgress
    var state: State
    var outputPath: String?

    enum State: Equatable {
        case waiting
        case running
        case completed
        case failed(String)
        case cancelled

        var isActive: Bool { self == .waiting || self == .running }
    }

    init(url: String) {
        self.url = url
        self.title = url
        self.progress = DownloadProgress()
        self.state = .waiting
    }
}
