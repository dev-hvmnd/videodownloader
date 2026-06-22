#!/usr/bin/env bash
# Builds a universal (arm64 + x86_64) .app and packages it into a DMG.
# Default: ad-hoc signature (without an Apple account). For Developer ID: set SIGN_ID="Developer ID Application: …".
set -euo pipefail
cd "$(dirname "$0")/.."

SCHEME="VideoDownloader"
APP_NAME="VideoDownloader"
VOL_NAME="Video Downloader"
CONFIG="Release"
BUILD_DIR="$PWD/build"
ARCHIVE="$BUILD_DIR/$SCHEME.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
APP="$EXPORT_DIR/$APP_NAME.app"
DMG="$BUILD_DIR/$VOL_NAME.dmg"
ENTITLEMENTS="$PWD/App/VideoDownloader.entitlements"
SIGN_ID="${SIGN_ID:--}"            # "-" = ad-hoc

command -v xcodegen >/dev/null || { echo "xcodegen missing (run: brew install xcodegen)"; exit 1; }
xcodegen generate

echo "▸ Archiving (universal) …"
xcodebuild archive \
  -project VideoDownloader.xcodeproj \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -archivePath "$ARCHIVE" \
  -destination "generic/platform=macOS" \
  ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="$SIGN_ID" \
  ENABLE_HARDENED_RUNTIME=YES \
  -quiet

rm -rf "$EXPORT_DIR"; mkdir -p "$EXPORT_DIR"
cp -R "$ARCHIVE/Products/Applications/$APP_NAME.app" "$APP"

echo "▸ Signing ($SIGN_ID) …"
if [ "$SIGN_ID" = "-" ]; then TS="--timestamp=none"; else TS="--timestamp"; fi
codesign --force --options runtime $TS --entitlements "$ENTITLEMENTS" --sign "$SIGN_ID" "$APP"
codesign --verify --strict --verbose=2 "$APP"
echo "  Architectures: $(lipo -archs "$APP/Contents/MacOS/$APP_NAME")"

echo "▸ Creating DMG …"
rm -f "$DMG"
if command -v create-dmg >/dev/null 2>&1; then
  create-dmg \
    --volname "$VOL_NAME" \
    --window-size 540 380 \
    --icon-size 110 \
    --icon "$APP_NAME.app" 150 190 \
    --app-drop-link 390 190 \
    --hdiutil-quiet \
    "$DMG" "$EXPORT_DIR" \
  || hdiutil create -volname "$VOL_NAME" -srcfolder "$EXPORT_DIR" -ov -format UDZO "$DMG"
else
  hdiutil create -volname "$VOL_NAME" -srcfolder "$EXPORT_DIR" -ov -format UDZO "$DMG"
fi

echo "✓ Done: $DMG"
