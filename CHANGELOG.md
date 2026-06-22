# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2026-06-22

### Fixed
- Video downloads now reliably produce an **MP4** file. yt-dlp previously fell back to
  MKV whenever the chosen video/audio streams were not natively MP4-compatible
  (e.g. VP9 video or Opus audio), because `--merge-output-format` is only a preference.
  Output is now forced to MP4 via `--merge-output-format mp4 --remux-video mp4`
  (container change only — no re-encode).

### Changed
- Reworked the format picker: video is offered by **resolution + frame rate** instead of
  by codec/container. Every frame-rate variant is now selectable (including 60 fps, which
  YouTube often provides only as VP9). WebM is no longer a separate choice — where both an
  MP4 and a WebM stream exist at the same resolution/fps, the MP4/H.264 stream is preferred.
- The "audio track (original format)" list no longer offers WebM/Opus streams.

## [0.1.0] - 2026-06-22

### Added
- Initial release: native macOS SwiftUI GUI wrapping yt-dlp + ffmpeg.
- First-run toolchain setup — Python (python-build-standalone), ffmpeg/ffprobe (osxexperts),
  and yt-dlp (pip) downloaded into Application Support, with the Apple-Silicon SIGKILL
  workaround (xattr strip + ad-hoc re-signing).
- Single downloads with live progress and cancel; concurrency-limited queue; history.
- Format selection, playlist/channel multi-select, audio extraction (MP3/M4A),
  subtitles, thumbnails, and metadata embedding.
- yt-dlp update mechanism with an optional auto-update at launch.
- English and German localization (follows the system language).
- Universal (arm64 + x86_64) ad-hoc-signed DMG; GitHub Actions release on `v*` tags;
  optional Developer ID notarization when signing secrets are configured.

[0.2.0]: https://github.com/dev-hvmnd/videodownloader/releases/tag/v0.2.0
[0.1.0]: https://github.com/dev-hvmnd/videodownloader/releases/tag/v0.1.0
