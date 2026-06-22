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
            return "Die Werkzeuge (Python/ffmpeg/yt-dlp) sind noch nicht bereit."
        case .executableNotFound(let path):
            return "Programm nicht gefunden: \(path)"
        case .invalidURL(let url):
            return "Ungültige URL: \(url)"
        case .processFailed(let code, let stderr):
            let trimmed = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            return "yt-dlp endete mit Code \(code)." + (trimmed.isEmpty ? "" : "\n\(trimmed)")
        case .parsingFailed(let what):
            return "Antwort konnte nicht gelesen werden: \(what)"
        case .cancelled:
            return "Abgebrochen."
        }
    }
}
