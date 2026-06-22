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
            return String(localized: "Toolchain.json (pinned versions) was not found in the app bundle.", bundle: .module)
        case .manifestInvalid(let detail):
            return String(localized: "Toolchain.json is invalid: \(detail)", bundle: .module)
        case .noNetwork(let detail):
            return String(localized: "No internet connection. \(detail)", bundle: .module)
        case .httpError(let component, let code):
            return String(localized: "Download of \(component) failed (HTTP \(String(code))).", bundle: .module)
        case .checksumMismatch(let component, let expected, let actual):
            return String(localized: "Checksum of \(component) does not match.\nExpected: \(expected)\nGot: \(actual)", bundle: .module)
        case .extractionFailed(let component, let detail):
            return String(localized: "Extracting \(component) failed: \(detail)", bundle: .module)
        case .commandFailed(let command, let code, let output):
            return String(localized: "Command \"\(command)\" exited with code \(String(code)).\n\(output)", bundle: .module)
        case .missingExecutable(let path):
            return String(localized: "Program missing after installation: \(path)", bundle: .module)
        case .pipFailed(let detail):
            return String(localized: "pip install of yt-dlp failed:\n\(detail)", bundle: .module)
        case .smokeTestFailed(let detail):
            return String(localized: "Verification failed: \(detail)", bundle: .module)
        }
    }
}
