#!/usr/bin/env bash
# Generates the Xcode project file from project.yml.
set -euo pipefail
cd "$(dirname "$0")/.."
command -v xcodegen >/dev/null || { echo "xcodegen missing — install: brew install xcodegen"; exit 1; }
xcodegen generate
echo "Project generated. Open with:  open VideoDownloader.xcodeproj"
