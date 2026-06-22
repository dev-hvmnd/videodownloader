import Foundation
import CryptoKit

/// Downloads files (with progress) and moves them atomically to the destination.
///
/// Two variants:
///  - `download(from:to:expectedSHA256:progress:)` - verifies the SHA256 of the **downloaded file**
///    (e.g. the python-build-standalone tarball, whose SHA256SUMS hash the tarball itself).
///  - `download(from:to:progress:)` - without verification (for archives whose published checksum refers to the
///    **extracted content**, e.g. osxexperts ffmpeg zips -> verification happens after extraction).
public struct Downloader: Sendable {
    public init() {}

    public func download(
        from url: URL,
        to destination: URL,
        expectedSHA256: String,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws {
        let temp = try await fetchToTemp(from: url, progress: progress)
        defer { try? FileManager.default.removeItem(at: temp) }
        let actual = try Self.sha256(ofFileAt: temp)
        guard actual.caseInsensitiveCompare(expectedSHA256) == .orderedSame else {
            throw ToolchainError.checksumMismatch(
                component: url.lastPathComponent, expected: expectedSHA256, actual: actual
            )
        }
        try Self.moveIntoPlace(temp, to: destination)
    }

    public func download(
        from url: URL,
        to destination: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws {
        let temp = try await fetchToTemp(from: url, progress: progress)
        defer { try? FileManager.default.removeItem(at: temp) }
        try Self.moveIntoPlace(temp, to: destination)
    }

    private func fetchToTemp(
        from url: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> URL {
        let session = DownloadSession(onProgress: progress)
        do {
            return try await withTaskCancellationHandler {
                try await session.start(url: url)
            } onCancel: {
                session.cancel()
            }
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost,
                 .cannotConnectToHost, .timedOut, .dnsLookupFailed:
                throw ToolchainError.noNetwork(error.localizedDescription)
            default:
                throw error
            }
        }
    }

    private static func moveIntoPlace(_ temp: URL, to destination: URL) throws {
        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: temp, to: destination)
    }

    /// Streaming SHA256 (does not load the entire file into RAM).
    static func sha256(ofFileAt url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

/// Wraps exactly one download via `URLSessionDownloadDelegate`.
private final class DownloadSession: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let onProgress: @Sendable (Double) -> Void
    private let lock = NSLock()
    private var continuation: CheckedContinuation<URL, Error>?
    private var session: URLSession?
    private var finished = false

    init(onProgress: @escaping @Sendable (Double) -> Void) {
        self.onProgress = onProgress
        super.init()
    }

    func start(url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { cont in
            lock.lock(); continuation = cont; lock.unlock()
            let config = URLSessionConfiguration.ephemeral
            config.waitsForConnectivity = false
            config.timeoutIntervalForRequest = 60
            let s = URLSession(configuration: config, delegate: self, delegateQueue: nil)
            lock.lock(); session = s; lock.unlock()
            s.downloadTask(with: url).resume()
        }
    }

    func cancel() {
        lock.lock(); let s = session; lock.unlock()
        s?.invalidateAndCancel()
        complete(.failure(CancellationError()))
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        onProgress(min(1.0, Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)))
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        if let http = downloadTask.response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            complete(.failure(ToolchainError.httpError(
                component: downloadTask.originalRequest?.url?.lastPathComponent ?? "Datei",
                statusCode: http.statusCode
            )))
            return
        }
        // The system deletes `location` after returning - copy it away immediately.
        let stable = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".download")
        do {
            try? FileManager.default.removeItem(at: stable)
            try FileManager.default.moveItem(at: location, to: stable)
            complete(.success(stable))
        } catch {
            complete(.failure(error))
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error { complete(.failure(error)) }
    }

    private func complete(_ result: Result<URL, Error>) {
        lock.lock()
        guard !finished, let cont = continuation else { lock.unlock(); return }
        finished = true
        continuation = nil
        let s = session
        lock.unlock()
        switch result {
        case .success(let url): cont.resume(returning: url)
        case .failure(let err): cont.resume(throwing: err)
        }
        s?.finishTasksAndInvalidate()
    }
}
