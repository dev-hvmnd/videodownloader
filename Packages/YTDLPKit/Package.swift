// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "YTDLPKit",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        // Pure engine: yt-dlp invocation, argument building, parsing, models. No SwiftUI.
        .library(name: "YTDLPEngine", targets: ["YTDLPEngine"]),
        // Runtime/toolchain manager: download/verify/install/update of Python, ffmpeg, yt-dlp.
        .library(name: "Toolchain", targets: ["Toolchain"]),
    ],
    targets: [
        .target(name: "YTDLPEngine", resources: [.process("Resources")]),
        .target(name: "Toolchain", dependencies: ["YTDLPEngine"], resources: [.process("Resources")]),
        // Integration/CI tool: exercises the complete toolchain pipeline (download→sign→pip→run).
        // Not a product → not part of the app. Usage: swift run ToolchainSmoke <manifest.json> <root-dir>
        .executableTarget(name: "ToolchainSmoke", dependencies: ["Toolchain", "YTDLPEngine"]),
        .testTarget(name: "YTDLPEngineTests", dependencies: ["YTDLPEngine"]),
    ]
)
