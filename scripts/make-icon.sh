#!/usr/bin/env bash
# Generates the app icon (all macOS sizes) from a 1024px master.
set -euo pipefail

DIR="$(cd "$(dirname "$0")/.." && pwd)"
ICONSET="$DIR/App/Resources/Assets.xcassets/AppIcon.appiconset"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

swift "$DIR/scripts/make-icon.swift" "$TMP/icon_1024.png"

gen() { sips -z "$1" "$1" "$TMP/icon_1024.png" --out "$ICONSET/$2" >/dev/null; }
gen 16 icon_16.png
gen 32 icon_32.png
gen 64 icon_64.png
gen 128 icon_128.png
gen 256 icon_256.png
gen 512 icon_512.png
cp "$TMP/icon_1024.png" "$ICONSET/icon_1024.png"

cat > "$ICONSET/Contents.json" <<'JSON'
{
  "images" : [
    { "idiom" : "mac", "scale" : "1x", "size" : "16x16",   "filename" : "icon_16.png" },
    { "idiom" : "mac", "scale" : "2x", "size" : "16x16",   "filename" : "icon_32.png" },
    { "idiom" : "mac", "scale" : "1x", "size" : "32x32",   "filename" : "icon_32.png" },
    { "idiom" : "mac", "scale" : "2x", "size" : "32x32",   "filename" : "icon_64.png" },
    { "idiom" : "mac", "scale" : "1x", "size" : "128x128", "filename" : "icon_128.png" },
    { "idiom" : "mac", "scale" : "2x", "size" : "128x128", "filename" : "icon_256.png" },
    { "idiom" : "mac", "scale" : "1x", "size" : "256x256", "filename" : "icon_256.png" },
    { "idiom" : "mac", "scale" : "2x", "size" : "256x256", "filename" : "icon_512.png" },
    { "idiom" : "mac", "scale" : "1x", "size" : "512x512", "filename" : "icon_512.png" },
    { "idiom" : "mac", "scale" : "2x", "size" : "512x512", "filename" : "icon_1024.png" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
JSON

echo "App icon generated in $ICONSET"
