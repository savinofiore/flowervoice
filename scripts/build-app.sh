#!/usr/bin/env bash
# Builds dist/FlowerVoice.app (release, icon, signed).
#   ./scripts/build-app.sh            build only
#   ./scripts/build-app.sh --install  build, install into /Applications and launch
# Signs with a stable identity so macOS keeps the granted permissions across rebuilds.
set -euo pipefail

VERSION="1.0.1"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT/dist/FlowerVoice.app"
INSTALL_DIR="/Applications/FlowerVoice.app"
LEGACY_INSTALL_DIR="$HOME/Applications/FlowerVoice.app"
SIGN_IDENTITY="${FLOWER_SIGN_IDENTITY:-$(security find-identity -v -p codesigning | awk -F'"' '/Apple Development/ {print $2; exit}')}"

cd "$ROOT"
[[ -f Assets/AppIcon.icns ]] || ./scripts/make-icon.sh
swift build -c release
BINARY="$(swift build -c release --show-bin-path)/FlowerVoice"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BINARY" "$APP_DIR/Contents/MacOS/FlowerVoice"
cp Assets/AppIcon.icns "$APP_DIR/Contents/Resources/AppIcon.icns"

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>dev.fiore.flowervoice</string>
    <key>CFBundleDevelopmentRegion</key><string>it</string>
    <key>CFBundleLocalizations</key><array><string>it</string></array>
    <key>CFBundleName</key><string>FlowerVoice</string>
    <key>CFBundleDisplayName</key><string>FlowerVoice</string>
    <key>CFBundleExecutable</key><string>FlowerVoice</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
    <key>LSUIElement</key><true/>
    <key>NSHumanReadableCopyright</key><string>© Savino Fiore</string>
    <key>NSMicrophoneUsageDescription</key><string>FlowerVoice registra la tua voce per trascriverla.</string>
</dict>
</plist>
PLIST

if [[ -n "$SIGN_IDENTITY" ]]; then
    codesign --force --options runtime --entitlements "$ROOT/scripts/FlowerVoice.entitlements" --sign "$SIGN_IDENTITY" "$APP_DIR"
else
    echo "No signing identity found: ad-hoc signing (permissions reset on every rebuild)."
    codesign --force --sign - "$APP_DIR"
fi
echo "Built $APP_DIR"

[[ "${1:-}" == "--install" ]] || exit 0
pkill -f "FlowerVoice.app/Contents/MacOS/FlowerVoice" 2>/dev/null || true
rm -rf "$INSTALL_DIR" "$LEGACY_INSTALL_DIR"
ditto "$APP_DIR" "$INSTALL_DIR"
echo "Installed $INSTALL_DIR"
open "$INSTALL_DIR"
