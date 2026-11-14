#!/usr/bin/env bash
# Builds dist/FlowerVoice-<version>.dmg: drag FlowerVoice into Applications to install.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$ROOT/scripts/build-app.sh"

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
