import Foundation

/// Interface of the runtime/toolchain manager. The app talks only to this protocol;
/// the concrete implementation (`ToolchainManager`) downloads/verifies/signs the tools.
public protocol ToolchainProviding: Sendable {
    var paths: ToolchainPaths { get }

    /// Checks the current state (without installing anything).
    func currentStatus() async -> ToolchainStatus

    /// Ensures all tools are present & runnable. Emits continuous status updates.
    func setup() -> AsyncStream<ToolchainStatus>

    /// Updates yt-dlp via pip. Returns the (old, new) version.
    func updateYTDLP() async throws -> (old: String?, new: String?)

    /// Removes and reinstalls the entire toolchain.
    func reset() async throws
}
