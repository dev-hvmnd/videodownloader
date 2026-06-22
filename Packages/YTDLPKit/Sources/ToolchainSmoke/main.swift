import Foundation
import Toolchain
import YTDLPEngine

// Integration test of the toolchain pipeline.
// Usage: swift run ToolchainSmoke <path/to/Toolchain.json> <root-directory>

let args = CommandLine.arguments
guard args.count >= 3 else {
    FileHandle.standardError.write(Data("Usage: ToolchainSmoke <manifest.json> <root-dir>\n".utf8))
    exit(2)
}

let manifestURL = URL(fileURLWithPath: args[1])
let rootURL = URL(fileURLWithPath: args[2])

func log(_ s: String) { print(s); fflush(stdout) }

do {
    let manifest = try ToolchainManifest.load(from: manifestURL)
    let manager = ToolchainManager(paths: ToolchainPaths(root: rootURL), manifest: manifest)

    log("Arch:     \(Architecture.current.rawValue)")
    log("Root:     \(rootURL.path)")
    log("Python:   \(manifest.python.version)")
    log("ffmpeg:   \(manifest.ffmpeg.version)")
    log("--- setup ---")

    var lastKey = ""
    var lastDecile = -1

    for await status in manager.setup() {
        switch status {
        case .installing(let p):
            let key = "\(p.component.rawValue)/\(p.step.rawValue)"
            if let frac = p.fractionCompleted {
                let decile = Int(frac * 10)
                if key != lastKey || decile != lastDecile {
                    log("  [\(key)] \(Int(frac * 100))%")
                    lastKey = key; lastDecile = decile
                }
            } else if key != lastKey {
                log("  [\(key)]")
                lastKey = key; lastDecile = -1
            }
        case .ready(let v):
            log("READY ✅  python=\(v.python ?? "?")  ffmpeg=\(v.ffmpeg ?? "?")  yt-dlp=\(v.ytdlp ?? "?")")
        case .failed(let msg):
            log("FAILED ❌  \(msg)")
            exit(1)
        case .checking, .needsSetup, .unknown:
            log("  status: \(status)")
        }
    }
    log("--- done ---")
} catch {
    log("ERROR: \(error.localizedDescription)")
    exit(1)
}
