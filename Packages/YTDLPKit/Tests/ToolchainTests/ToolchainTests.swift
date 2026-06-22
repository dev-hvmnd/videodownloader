import Testing
import Foundation
@testable import Toolchain

@Suite struct VersionComparisonTests {
    @Test func dateBasedVersions() {
        #expect(ToolchainManager.versionAtLeast("2026.06.09", "2024.01.01"))
        #expect(ToolchainManager.versionAtLeast("2024.01.01", "2024.01.01"))   // equal
        #expect(!ToolchainManager.versionAtLeast("2023.12.31", "2024.01.01"))
        #expect(ToolchainManager.versionAtLeast("2024.1.9", "2024.01.08"))     // 9 > 8, zero-padding agnostic
        #expect(!ToolchainManager.versionAtLeast("2024.1.8", "2024.1.9"))
        #expect(ToolchainManager.versionAtLeast("2024.08.06.123456", "2024.08.06"))  // extra component
    }
}

@Suite struct ToolchainStateTests {
    @Test func codableRoundTrip() throws {
        let when = Date(timeIntervalSince1970: 1_700_000_000)
        var state = ToolchainState(arch: "arm64")
        state.python = .init(version: "3.12.13+20260610", installedAt: when)
        state.ffmpeg = .init(version: "8.1 (arm64) / 8.0 (x86_64)", ffmpegSHA256: "aaaa", ffprobeSHA256: "bbbb", installedAt: when)
        state.ytdlp = .init(version: "2026.06.09", installedAt: when, lastUpdateCheck: when)
        state.setupComplete = true

        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("installed.json")
        try state.save(to: file)

        let loaded = try #require(ToolchainState.load(from: file))
        #expect(loaded.schemaVersion == ToolchainState.currentSchemaVersion)
        #expect(loaded.arch == "arm64")
        #expect(loaded.python?.version == "3.12.13+20260610")
        #expect(loaded.ffmpeg?.version == "8.1 (arm64) / 8.0 (x86_64)")
        #expect(loaded.ffmpeg?.ffmpegSHA256 == "aaaa")
        #expect(loaded.ffmpeg?.ffprobeSHA256 == "bbbb")
        #expect(loaded.ytdlp?.version == "2026.06.09")
        #expect(loaded.setupComplete)
    }

    @Test func loadMissingFileReturnsNil() {
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).json")
        #expect(ToolchainState.load(from: missing) == nil)
    }
}
