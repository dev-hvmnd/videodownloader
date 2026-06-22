import Foundation

/// CPU architecture of the running process. For a universal build this corresponds to the
/// natively executed slice (arm64 on Apple Silicon, x86_64 on Intel).
public enum Architecture: String, Sendable {
    case arm64
    case x86_64

    public static var current: Architecture {
        #if arch(arm64)
        return .arm64
        #else
        return .x86_64
        #endif
    }
}
