import Foundation

public enum ToolchainError: Error, Sendable, LocalizedError {
    case manifestMissing
    case manifestInvalid(String)
    case noNetwork(String)
    case httpError(component: String, statusCode: Int)
    case checksumMismatch(component: String, expected: String, actual: String)
    case extractionFailed(component: String, detail: String)
    case commandFailed(command: String, exitCode: Int32, output: String)
    case missingExecutable(String)
    case pipFailed(String)
    case smokeTestFailed(String)

    public var errorDescription: String? {
        switch self {
        case .manifestMissing:
            return "Toolchain.json (gepinnte Versionen) wurde im App-Bundle nicht gefunden."
        case .manifestInvalid(let detail):
            return "Toolchain.json ist ungültig: \(detail)"
        case .noNetwork(let detail):
            return "Keine Internetverbindung. \(detail)"
        case .httpError(let component, let code):
            return "Download von \(component) fehlgeschlagen (HTTP \(code))."
        case .checksumMismatch(let component, let expected, let actual):
            return "Prüfsumme von \(component) stimmt nicht.\nErwartet: \(expected)\nErhalten: \(actual)"
        case .extractionFailed(let component, let detail):
            return "Entpacken von \(component) fehlgeschlagen: \(detail)"
        case .commandFailed(let command, let code, let output):
            return "Befehl »\(command)« endete mit Code \(code).\n\(output)"
        case .missingExecutable(let path):
            return "Programm fehlt nach der Installation: \(path)"
        case .pipFailed(let detail):
            return "pip-Installation von yt-dlp fehlgeschlagen:\n\(detail)"
        case .smokeTestFailed(let detail):
            return "Funktionsprüfung fehlgeschlagen: \(detail)"
        }
    }
}
