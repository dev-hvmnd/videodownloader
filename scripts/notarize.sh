#!/usr/bin/env bash
# Optional: notarize the DMG with Apple and staple the ticket (Developer ID only).
# Prerequisite: create credentials once with
#   xcrun notarytool store-credentials AC_NOTARY --key AuthKey.p8 --key-id <ID> --issuer <ISSUER>
set -euo pipefail

DMG="${1:-}"
[ -n "$DMG" ] || { echo "Usage: notarize.sh <path-to.dmg>"; exit 1; }
PROFILE="${NOTARY_PROFILE:-AC_NOTARY}"

echo "▸ Submitting for notarization …"
xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait
echo "▸ Stapling ticket …"
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"
echo "✓ Notarized + stapled: $DMG"
