import Foundation

/// Determines the writable root folder under Application Support.
/// `~` is never hard-coded - always via `FileManager`.
public enum PathResolver {
    public static let fallbackBundleID = "io.dev-hvmnd.videodownloader.app"

    public static func applicationSupportRoot(
        bundleIdentifier: String? = Bundle.main.bundleIdentifier
    ) throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let id = bundleIdentifier ?? fallbackBundleID
        return base.appendingPathComponent(id, isDirectory: true)
    }

    public static func defaultPaths(
        bundleIdentifier: String? = Bundle.main.bundleIdentifier
    ) throws -> ToolchainPaths {
        ToolchainPaths(root: try applicationSupportRoot(bundleIdentifier: bundleIdentifier))
    }
}
