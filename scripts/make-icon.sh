#!/usr/bin/env bash
# Generates Assets/AppIcon.icns from scripts/make-icon.swift.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

swift "$ROOT/scripts/make-icon.swift" "$WORK/icon_1024.png"
ICONSET="$WORK/AppIcon.iconset"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$WORK/icon_1024.png" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z "$double" "$double" "$WORK/icon_1024.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
mkdir -p "$ROOT/Assets"
iconutil -c icns "$ICONSET" -o "$ROOT/Assets/AppIcon.icns"
cp "$WORK/icon_1024.png" "$ROOT/Assets/AppIcon.png"
echo "Created $ROOT/Assets/AppIcon.icns"
