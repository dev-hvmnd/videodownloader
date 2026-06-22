import Foundation

/// Installed tool versions (for display + update comparison).
public struct ToolchainVersions: Sendable, Equatable {
    public var python: String?
    public var ffmpeg: String?
    public var ytdlp: String?

    public init(python: String? = nil, ffmpeg: String? = nil, ytdlp: String? = nil) {
        self.python = python
        self.ffmpeg = ffmpeg
        self.ytdlp = ytdlp
    }
}

/// Fine-grained progress during setup/update.
public struct ToolchainProgress: Sendable, Equatable {
    public enum Component: String, Sendable, Equatable, CaseIterable {
        case python, ffmpeg, ytdlp
    }

    public enum Step: String, Sendable, Equatable {
        case downloading, verifying, installing, signing, finalizing
    }

    public var component: Component
    public var step: Step
    /// 0…1, if known.
    public var fractionCompleted: Double?

    public init(component: Component, step: Step, fractionCompleted: Double? = nil) {
        self.component = component
        self.step = step
        self.fractionCompleted = fractionCompleted
    }
}

/// Overall state of the toolchain.
public enum ToolchainStatus: Sendable, Equatable {
    case unknown
    case checking
    case needsSetup
    case installing(ToolchainProgress)
    case ready(ToolchainVersions)
    case failed(String)
}
