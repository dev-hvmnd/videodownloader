import Foundation

/// An event from a running subprocess.
public enum ProcessEvent: Sendable, Equatable {
    case stdout(String)
    case stderr(String)
    case exited(code: Int32)
}
