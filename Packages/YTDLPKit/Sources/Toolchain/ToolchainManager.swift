import Foundation
import YTDLPEngine

/// Downloads, verifies, signs, and installs Python, ffmpeg/ffprobe, and yt-dlp; keeps yt-dlp up to date.
public final class ToolchainManager: ToolchainProviding {
    public let paths: ToolchainPaths
    private let manifest: ToolchainManifest
    private let arch: Architecture
    private let runner: any ProcessRunning
    private let downloader: Downloader
    private let signer: CodeSigner
    private let archiver: Archiver

    public init(
        paths: ToolchainPaths,
        manifest: ToolchainManifest,
        arch: Architecture = .current,
        runner: any ProcessRunning = FoundationProcessRunner()
    ) {
        self.paths = paths
        self.manifest = manifest
        self.arch = arch
        self.runner = runner
        self.downloader = Downloader()
        self.signer = CodeSigner(runner: runner)
        self.archiver = Archiver(runner: runner)
    }

    /// Loads the manifest from the app bundle (`Toolchain.json`) and uses the default paths.
    public static func makeDefault(bundle: Bundle = .main) throws -> ToolchainManager {
        guard let url = bundle.url(forResource: "Toolchain", withExtension: "json") else {
            throw ToolchainError.manifestMissing
        }
        let manifest = try ToolchainManifest.load(from: url)
        let paths = try PathResolver.defaultPaths(bundleIdentifier: bundle.bundleIdentifier)
        return ToolchainManager(paths: paths, manifest: manifest)
    }

    // MARK: - ToolchainProviding

    public func currentStatus() async -> ToolchainStatus {
        if let versions = await verifyInstalled() {
            return .ready(versions)
        }
        return .needsSetup
    }

    public func setup() -> AsyncStream<ToolchainStatus> {
        AsyncStream { continuation in
            let task = Task {
                do {
                    let versions = try await performSetup { continuation.yield($0) }
                    continuation.yield(.ready(versions))
                } catch is CancellationError {
                    continuation.yield(.failed(String(localized: "Setup cancelled.", bundle: .module)))
                } catch {
                    continuation.yield(.failed(error.localizedDescription))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    public func updateYTDLP() async throws -> (old: String?, new: String?) {
        let old = try? await ytdlpVersion()
        try await pipInstallYTDLP(upgrade: true)
        try await signer.prepareTree(at: paths.ytdlpDir)
        let new = try await ytdlpVersion()
        try enforceMinVersion(new)
        if var state = ToolchainState.load(from: paths.stateFile) {
            state.ytdlp = .init(version: new, installedAt: Date(), lastUpdateCheck: Date())
            try? state.save(to: paths.stateFile)
        }
        return (old, new)
    }

    public func reset() async throws {
        try? FileManager.default.removeItem(at: paths.toolchain)
        try? FileManager.default.removeItem(at: paths.stateFile)
        try? FileManager.default.removeItem(at: paths.downloadsDir)
    }

    // MARK: - Setup flow

    private func performSetup(
        progress: @escaping @Sendable (ToolchainStatus) -> Void
    ) async throws -> ToolchainVersions {
        try ensureDirectories()
        let state = ToolchainState.load(from: paths.stateFile)

        // (Re)install components whose pinned version/arch/hash no longer matches the manifest.
        var pythonChanged = false
        if !pythonUpToDate(state) {
            try await installPython(progress: progress)
            pythonChanged = true
        }
        try Task.checkCancellation()

        if !ffmpegUpToDate(state) {
            try await installFFmpeg(progress: progress)
        }
        try Task.checkCancellation()

        // yt-dlp: reinstall if the Python runtime changed (ABI), or if it is missing / below the floor.
        var needsYTDLP = pythonChanged
        if !needsYTDLP {
            needsYTDLP = await validatedYTDLPVersion() == nil
        }
        if needsYTDLP {
            progress(.installing(ToolchainProgress(component: .ytdlp, step: .installing)))
            // `pip install --target` warns and SKIPS when the package dir already exists (without
            // `--upgrade`), so a stale install would survive and keep failing the version check.
            // Wipe the target for a guaranteed clean reinstall — this also discards dependency
            // `.so` files (pycryptodomex, brotli, …) compiled against a now-replaced Python runtime.
            try? FileManager.default.removeItem(at: paths.ytdlpDir)
            try await pipInstallYTDLP(upgrade: false)
            try await signer.prepareTree(at: paths.ytdlpDir)
        }
        try Task.checkCancellation()

        progress(.installing(ToolchainProgress(component: .ytdlp, step: .finalizing)))
        let versions = try await smokeTestAndCollectVersions()
        try writeState(ytdlpVersion: versions.ytdlp)
        return versions
    }

    private func ensureDirectories() throws {
        for dir in [paths.toolchain, paths.stateDir, paths.downloadsDir, paths.logsDir] {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    // MARK: - Validation / re-validation

    /// Python is current if it is installed and the recorded state matches the manifest pin + arch.
    private func pythonUpToDate(_ state: ToolchainState?) -> Bool {
        pythonInstalled()
            && state?.arch == arch.rawValue
            && state?.python?.version == manifest.python.version
    }

    /// ffmpeg/ffprobe are current if installed, the recorded state matches the manifest pin + arch,
    /// and the on-disk binaries still hash to the values recorded at install time (post-signing).
    /// (The manifest's pinned hashes are checked at install time, before we re-sign the binaries.)
    private func ffmpegUpToDate(_ state: ToolchainState?) -> Bool {
        guard let recorded = state?.ffmpeg,
              ffmpegInstalled(),
              state?.arch == arch.rawValue,
              recorded.version == manifest.ffmpeg.version
        else { return false }
        guard let ffmpeg = try? Downloader.sha256(ofFileAt: paths.ffmpegExecutable),
              ffmpeg.caseInsensitiveCompare(recorded.ffmpegSHA256) == .orderedSame,
              let ffprobe = try? Downloader.sha256(ofFileAt: paths.ffprobeExecutable),
              ffprobe.caseInsensitiveCompare(recorded.ffprobeSHA256) == .orderedSame
        else { return false }
        return true
    }

    /// Returns the yt-dlp version if it is installed, runnable, and meets the manifest minimum; else nil.
    private func validatedYTDLPVersion() async -> String? {
        guard FileManager.default.fileExists(atPath: paths.ytdlpDir.appendingPathComponent("yt_dlp").path),
              let version = try? await ytdlpVersion(),
              meetsMinVersion(version)
        else { return nil }
        return version
    }

    private func verifyInstalled() async -> ToolchainVersions? {
        let state = ToolchainState.load(from: paths.stateFile)
        guard state?.setupComplete == true,
              state?.schemaVersion == ToolchainState.currentSchemaVersion,
              state?.arch == arch.rawValue,
              pythonUpToDate(state),
              ffmpegUpToDate(state),
              let ytdlp = await validatedYTDLPVersion()
        else { return nil }

        // Fresh runtime versions for display.
        let python = try? await pythonVersion()
        let ffmpeg = try? await ffmpegVersion()
        return ToolchainVersions(python: python, ffmpeg: ffmpeg, ytdlp: ytdlp)
    }

    // MARK: - Version comparison (yt-dlp uses date-based YYYY.MM.DD versions)

    private func meetsMinVersion(_ version: String) -> Bool {
        guard let minimum = manifest.ytdlp.minVersion, !minimum.isEmpty else { return true }
        return Self.versionAtLeast(version, minimum)
    }

    private func enforceMinVersion(_ version: String) throws {
        guard meetsMinVersion(version) else {
            let minimum = manifest.ytdlp.minVersion ?? ""
            throw ToolchainError.smokeTestFailed(
                String(localized: "installed yt-dlp \(version) is older than the required minimum \(minimum)", bundle: .module)
            )
        }
    }

    static func versionAtLeast(_ version: String, _ minimum: String) -> Bool {
        func parts(_ s: String) -> [Int] {
            s.split(separator: ".").map { Int($0.prefix { $0.isNumber }) ?? 0 }
        }
        let v = parts(version), m = parts(minimum)
        for i in 0..<max(v.count, m.count) {
            let a = i < v.count ? v[i] : 0
            let b = i < m.count ? m[i] : 0
            if a != b { return a > b }
        }
        return true
    }

    // MARK: - Python

    private func pythonInstalled() -> Bool {
        FileManager.default.isExecutableFile(atPath: paths.pythonExecutable.path)
    }

    private func installPython(progress: @escaping @Sendable (ToolchainStatus) -> Void) async throws {
        let asset = manifest.python.asset(for: arch)
        guard let url = URL(string: asset.url) else { throw ToolchainError.manifestInvalid("python-URL") }

        progress(.installing(ToolchainProgress(component: .python, step: .downloading, fractionCompleted: 0)))
        let archive = paths.downloadsDir.appendingPathComponent("python.tar.gz")
        try await downloader.download(from: url, to: archive, expectedSHA256: asset.sha256) { frac in
            progress(.installing(ToolchainProgress(component: .python, step: .downloading, fractionCompleted: frac)))
        }

        progress(.installing(ToolchainProgress(component: .python, step: .installing)))
        let staging = paths.downloadsDir.appendingPathComponent("python-staging", isDirectory: true)
        try? FileManager.default.removeItem(at: staging)
        try await archiver.extractTarGz(archive, into: staging)

        // python-build-standalone "install_only" extracts to "<staging>/python".
        let extracted = staging.appendingPathComponent("python", isDirectory: true)
        guard FileManager.default.fileExists(atPath: extracted.path) else {
            throw ToolchainError.extractionFailed(component: "python", detail: String(localized: "no python/ directory in the archive", bundle: .module))
        }
        try? FileManager.default.removeItem(at: paths.pythonDir)
        try FileManager.default.moveItem(at: extracted, to: paths.pythonDir)
        try? FileManager.default.removeItem(at: staging)
        try? FileManager.default.removeItem(at: archive)

        progress(.installing(ToolchainProgress(component: .python, step: .signing)))
        try await signer.prepareTree(at: paths.pythonDir)
    }

    // MARK: - ffmpeg / ffprobe

    private func ffmpegInstalled() -> Bool {
        FileManager.default.isExecutableFile(atPath: paths.ffmpegExecutable.path)
            && FileManager.default.isExecutableFile(atPath: paths.ffprobeExecutable.path)
    }

    private func installFFmpeg(progress: @escaping @Sendable (ToolchainStatus) -> Void) async throws {
        let spec = manifest.ffmpeg.spec(for: arch)
        try FileManager.default.createDirectory(at: paths.ffmpegDir, withIntermediateDirectories: true)
        try await installBinary(
            name: "ffmpeg", urlString: spec.ffmpegURL, sha256: spec.ffmpegSHA256,
            destination: paths.ffmpegExecutable, span: (0.0, 0.5), progress: progress
        )
        try await installBinary(
            name: "ffprobe", urlString: spec.ffprobeURL, sha256: spec.ffprobeSHA256,
            destination: paths.ffprobeExecutable, span: (0.5, 1.0), progress: progress
        )
    }

    private func installBinary(
        name: String,
        urlString: String,
        sha256: String,
        destination: URL,
        span: (Double, Double),
        progress: @escaping @Sendable (ToolchainStatus) -> Void
    ) async throws {
        guard let url = URL(string: urlString) else { throw ToolchainError.manifestInvalid("\(name)-URL") }
        let zip = paths.downloadsDir.appendingPathComponent("\(name).zip")
        // Download the zip without verification - osxexperts publishes the SHA256 of the extracted binary,
        // not the zip. The archive's entries are sanity-checked (no traversal/symlinks) before extraction,
        // and the extracted binary is verified against the pinned hash below.
        try await downloader.download(from: url, to: zip) { frac in
            let mapped = span.0 + frac * (span.1 - span.0)
            progress(.installing(ToolchainProgress(component: .ffmpeg, step: .downloading, fractionCompleted: mapped)))
        }

        progress(.installing(ToolchainProgress(component: .ffmpeg, step: .verifying, fractionCompleted: span.1)))
        let staging = paths.downloadsDir.appendingPathComponent("\(name)-staging", isDirectory: true)
        try? FileManager.default.removeItem(at: staging)
        try await archiver.extractZip(zip, into: staging)

        guard let binary = findFile(named: name, in: staging) else {
            throw ToolchainError.extractionFailed(component: name, detail: String(localized: "Binary \"\(name)\" not found in the archive", bundle: .module))
        }
        let actual = try Downloader.sha256(ofFileAt: binary)
        guard actual.caseInsensitiveCompare(sha256) == .orderedSame else {
            throw ToolchainError.checksumMismatch(component: name, expected: sha256, actual: actual)
        }
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: binary, to: destination)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destination.path)
        try? FileManager.default.removeItem(at: staging)
        try? FileManager.default.removeItem(at: zip)

        progress(.installing(ToolchainProgress(component: .ffmpeg, step: .signing, fractionCompleted: span.1)))
        try await signer.prepareFile(at: destination)
    }

    private func findFile(named name: String, in directory: URL) -> URL? {
        guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil) else {
            return nil
        }
        for case let url as URL in enumerator where url.lastPathComponent == name {
            return url
        }
        return nil
    }

    // MARK: - yt-dlp via pip

    private func pipInstallYTDLP(upgrade: Bool) async throws {
        var args = [
            "-m", "pip", "install",
            "--no-input", "--disable-pip-version-check",
            "--target", paths.ytdlpDir.path,
        ]
        if upgrade { args.append("--upgrade") }
        args.append("yt-dlp")
        let result = try await runner.runCaptured(
            executable: paths.pythonExecutable,
            arguments: args,
            environment: pipEnv(),
            maxLines: 1000
        )
        guard result.succeeded else {
            throw ToolchainError.pipFailed(result.stderr.isEmpty ? result.stdout : result.stderr)
        }
    }

    // MARK: - Versions / smoke test

    private func smokeTestAndCollectVersions() async throws -> ToolchainVersions {
        let importCheck = try await runner.runCaptured(
            executable: paths.pythonExecutable,
            arguments: ["-c", "import yt_dlp"],
            environment: runEnv()
        )
        guard importCheck.succeeded else {
            throw ToolchainError.smokeTestFailed("import yt_dlp: \(importCheck.stderr)")
        }
        let ytdlp = try await ytdlpVersion()
        try enforceMinVersion(ytdlp)
        let python = try? await pythonVersion()
        let ffmpeg = try? await ffmpegVersion()
        return ToolchainVersions(python: python, ffmpeg: ffmpeg, ytdlp: ytdlp)
    }

    private func ytdlpVersion() async throws -> String {
        let result = try await runner.runCaptured(
            executable: paths.pythonExecutable,
            arguments: ["-m", "yt_dlp", "--version"],
            environment: runEnv()
        )
        guard result.succeeded else { throw ToolchainError.smokeTestFailed("yt-dlp --version: \(result.stderr)") }
        return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func pythonVersion() async throws -> String {
        let result = try await runner.runCaptured(
            executable: paths.pythonExecutable,
            arguments: ["--version"],
            environment: baseEnv()
        )
        return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "Python ", with: "")
    }

    private func ffmpegVersion() async throws -> String {
        let result = try await runner.runCaptured(
            executable: paths.ffmpegExecutable,
            arguments: ["-version"],
            environment: baseEnv()
        )
        // first line: "ffmpeg version 8.1 Copyright ..."
        let first = result.stdout.split(separator: "\n").first.map(String.init) ?? ""
        let parts = first.split(separator: " ")
        if let idx = parts.firstIndex(of: "version"), idx + 1 < parts.count {
            return String(parts[idx + 1])
        }
        return first
    }

    /// Records the manifest-pinned versions for Python/ffmpeg (so future manifest bumps are detected)
    /// plus the runtime yt-dlp version.
    private func writeState(ytdlpVersion: String?) throws {
        var state = ToolchainState(arch: arch.rawValue)
        state.python = .init(version: manifest.python.version, installedAt: Date())
        let ffmpegHash = (try? Downloader.sha256(ofFileAt: paths.ffmpegExecutable)) ?? ""
        let ffprobeHash = (try? Downloader.sha256(ofFileAt: paths.ffprobeExecutable)) ?? ""
        state.ffmpeg = .init(
            version: manifest.ffmpeg.version,
            ffmpegSHA256: ffmpegHash,
            ffprobeSHA256: ffprobeHash,
            installedAt: Date()
        )
        if let ytdlpVersion {
            state.ytdlp = .init(version: ytdlpVersion, installedAt: Date(), lastUpdateCheck: Date())
        }
        state.setupComplete = true
        try state.save(to: paths.stateFile)
    }

    // MARK: - Environments (clean, not inherited from the user -> deterministic)

    private func baseEnv() -> [String: String] {
        var env: [String: String] = [
            "PATH": "\(paths.ffmpegDir.path):/usr/bin:/bin",
            "HOME": NSHomeDirectory(),
            "TMPDIR": NSTemporaryDirectory(),
            "PYTHONDONTWRITEBYTECODE": "1",
            "PYTHONUTF8": "1",
        ]
        // Forward proxy configuration so setup/downloads work behind a corporate proxy.
        let inherited = ProcessInfo.processInfo.environment
        for key in ["HTTP_PROXY", "HTTPS_PROXY", "NO_PROXY", "http_proxy", "https_proxy", "no_proxy", "ALL_PROXY", "all_proxy"] {
            if let value = inherited[key] { env[key] = value }
        }
        return env
    }

    /// For `pip install` - without PYTHONPATH (yt-dlp is not imported here).
    private func pipEnv() -> [String: String] { baseEnv() }

    /// For running yt-dlp - with PYTHONPATH pointing at the `--target` directory.
    private func runEnv() -> [String: String] {
        var env = baseEnv()
        env["PYTHONPATH"] = paths.ytdlpDir.path
        return env
    }
}
