import Foundation

public enum YTDLPError: Error, Sendable, Equatable, LocalizedError {
    case toolchainNotReady
    case executableNotFound(String)
    case invalidURL(String)
    case processFailed(exitCode: Int32, stderr: String)
    case parsingFailed(String)
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .toolchainNotReady:
            return String(localized: "The tools (Python/ffmpeg/yt-dlp) are not ready yet.", bundle: .module)
        case .executableNotFound(let path):
            return String(localized: "Program not found: \(path)", bundle: .module)
        case .invalidURL(let url):
            return String(localized: "Invalid URL: \(url)", bundle: .module)
        case .processFailed(let code, let stderr):
            let trimmed = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            let base = String(localized: "yt-dlp exited with code \(String(code)).", bundle: .module)
            return base + (trimmed.isEmpty ? "" : "\n\(trimmed)")
        case .parsingFailed(let what):
            return String(localized: "Could not read the response: \(what)", bundle: .module)
        case .cancelled:
            return String(localized: "Cancelled.", bundle: .module)
        }
    }
}
