import Testing
import Foundation
@testable import Toolchain
import YTDLPEngine

/// Integration tests for the zip safety validation (uses the real `zip`/`unzip`/`ditto`/`python3`).
@Suite struct ZipSafetyTests {
    private func sh(_ command: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", command]
        try process.run()
        process.waitUntilExit()
    }

    private func tempDir() -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("ziptest-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test func acceptsNormalZip() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let zip = dir.appendingPathComponent("normal.zip")
        try sh("cd \(dir.path) && echo hi > a.txt && /usr/bin/zip -q \(zip.path) a.txt")

        let archiver = Archiver(runner: FoundationProcessRunner())
        let out = dir.appendingPathComponent("out")
        try await archiver.extractZip(zip, into: out)   // must not throw
        #expect(FileManager.default.fileExists(atPath: out.appendingPathComponent("a.txt").path))
    }

    @Test func rejectsParentTraversal() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let zip = dir.appendingPathComponent("trav.zip")
        try sh("/usr/bin/python3 -c \"import zipfile; z=zipfile.ZipFile('\(zip.path)','w'); z.writestr('ok.txt','y'); z.writestr('../escape.txt','x'); z.close()\"")

        let archiver = Archiver(runner: FoundationProcessRunner())
        await #expect(throws: ToolchainError.self) {
            try await archiver.extractZip(zip, into: dir.appendingPathComponent("out"))
        }
    }

    @Test func rejectsSymlink() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let zip = dir.appendingPathComponent("sym.zip")
        try sh("cd \(dir.path) && ln -s /etc/hosts link && /usr/bin/zip -qy \(zip.path) link")

        let archiver = Archiver(runner: FoundationProcessRunner())
        await #expect(throws: ToolchainError.self) {
            try await archiver.extractZip(zip, into: dir.appendingPathComponent("out"))
        }
    }
}
