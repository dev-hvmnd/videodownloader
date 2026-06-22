# Video Downloader

A native macOS app (SwiftUI) that is a convenient GUI wrapper around
[**yt-dlp**](https://github.com/yt-dlp/yt-dlp) and **ffmpeg**. On first launch the app
automatically downloads its runtime tools (an embedded Python, ffmpeg/ffprobe, and yt-dlp)
and keeps yt-dlp up to date.

## Features

- Paste a URL → pick format/quality → download with live progress (%, speed, ETA) and cancel
- Download queue (sequential or parallel) with a concurrency limit and a history
- Playlists & channels: pick which entries to download
- Audio extraction (MP3/M4A)
- Subtitles (including auto-subs), thumbnails, and metadata embedding
- One-click yt-dlp update (with optional auto-update on launch)
- Drag & drop URLs onto the window

## How it works

- **UI:** SwiftUI + the `@Observable` macro (MVVM), targeting macOS 14.0+.
- **Engine:** yt-dlp runs as a **subprocess** (not in-process). Pure Swift, no external dependencies.
- **Toolchain:** Python ([python-build-standalone](https://github.com/astral-sh/python-build-standalone)),
  ffmpeg/ffprobe ([osxexperts.net](https://www.osxexperts.net/)), and yt-dlp are downloaded on first
  launch into `~/Library/Application Support/<bundle-id>/`. yt-dlp can be updated via `pip` without
  breaking the app's code signature. Pinned versions and SHA-256 checksums live in
  [`App/Resources/Toolchain.json`](App/Resources/Toolchain.json).
- **Project:** [XcodeGen](https://github.com/yonaskolb/XcodeGen) — `project.yml` is the source of truth,
  the generated `.xcodeproj` is git-ignored.

> On Apple Silicon, downloaded executables are re-signed ad-hoc (and their `com.apple.provenance` /
> `com.apple.quarantine` attributes stripped) so they can run — otherwise macOS 15+ kills them on launch.

## Install

Download the latest `.dmg` from the [Releases](../../releases) page and drag the app to **Applications**.
The first launch downloads the tools (~80 MB) into Application Support.

### Opening an unsigned build

Official releases that are notarized with an Apple Developer ID open without a warning. Self-built or
ad-hoc-signed builds are blocked by Gatekeeper at first. Two ways to open them:

- **Right-click** the app → **Open** → **Open** again in the dialog, or
- remove the quarantine attribute in Terminal:
  ```bash
  xattr -dr com.apple.quarantine "/Applications/VideoDownloader.app"
  ```

## Build from source

Requirements: macOS 14+, Xcode 26.x, [Homebrew](https://brew.sh).

```bash
brew install xcodegen create-dmg
xcodegen generate                          # creates VideoDownloader.xcodeproj
xcodebuild -scheme VideoDownloader build
# or open it in Xcode:
open VideoDownloader.xcodeproj
```

Engine tests:

```bash
cd Packages/YTDLPKit && swift test
```

Build a release DMG (ad-hoc, no Apple account required):

```bash
bash scripts/build-release.sh              # output: build/*.dmg
```

### Scripts

| Script | Purpose |
|---|---|
| `scripts/generate.sh` | `project.yml` → `VideoDownloader.xcodeproj` |
| `scripts/make-icon.sh` | Regenerate the app icon (all sizes) |
| `scripts/build-release.sh` | Universal `.app` + DMG (ad-hoc; set `SIGN_ID=…` for Developer ID) |
| `scripts/notarize.sh` | Notarize a DMG with Apple and staple the ticket (optional) |

Official, warning-free releases are produced by **GitHub Actions**
([`.github/workflows/release.yml`](.github/workflows/release.yml)) when a `v*` tag is pushed.
Without signing secrets it builds an ad-hoc DMG; with Developer-ID secrets it additionally builds a
notarized DMG.

## Project structure

```
video-downloader/
├─ project.yml                 # XcodeGen project definition (source of truth)
├─ App/                        # SwiftUI app: views, @Observable stores, resources
├─ Packages/YTDLPKit/          # local Swift package (no external dependencies)
│   └─ Sources/
│       ├─ YTDLPEngine/        # subprocess, argument builder, parsers, models
│       └─ Toolchain/          # download/verify/sign/install of Python, ffmpeg, yt-dlp
├─ scripts/                    # generate / build-release / notarize / make-icon
└─ .github/workflows/          # release CI
```

## License & notes

This wrapper is released under the **MIT License** (see [`LICENSE`](LICENSE)). yt-dlp and ffmpeg are
**separate projects** with their own licenses; they are downloaded at runtime and run as separate
processes — they are not part of this source code. Please respect the terms of service of the
respective video platforms and applicable copyright law.
