#!/usr/bin/env bash
# Builds dist/FlowerVoice-<version>.dmg: drag FlowerVoice into Applications to install.
# Public builds never carry a personal Apple Development certificate: they are signed with a
# "Developer ID Application" identity when one is installed, ad-hoc otherwise.
# With a Developer ID, set FLOWER_NOTARY_PROFILE (see `xcrun notarytool store-credentials`) to notarize.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEVELOPER_ID="$(security find-identity -v -p codesigning | awk -F'"' '/Developer ID Application/ {print $2; exit}')"
FLOWER_SIGN_IDENTITY="${DEVELOPER_ID:--}" "$ROOT/scripts/build-app.sh"

APP_DIR="$ROOT/dist/FlowerVoice.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP_DIR/Contents/Info.plist")"
DMG_PATH="$ROOT/dist/FlowerVoice-$VERSION.dmg"
STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT

ditto "$APP_DIR" "$STAGING/FlowerVoice.app"
ln -s /Applications "$STAGING/Applications"
rm -f "$DMG_PATH"
hdiutil create -volname "FlowerVoice" -srcfolder "$STAGING" -fs HFS+ -format UDZO "$DMG_PATH" >/dev/null
echo "Created $DMG_PATH"

[[ -n "$DEVELOPER_ID" && -n "${FLOWER_NOTARY_PROFILE:-}" ]] || exit 0
codesign --sign "$DEVELOPER_ID" --timestamp "$DMG_PATH"
xcrun notarytool submit "$DMG_PATH" --keychain-profile "$FLOWER_NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG_PATH"
echo "Notarized $DMG_PATH"
