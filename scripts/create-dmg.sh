#!/usr/bin/env bash
# Create a simple drag-to-Applications DMG (single-step, no mount/convert).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${VERSION:-0.0.3}"
APP="$ROOT/build/finder-go-up.app"
DMG="$ROOT/dist/finder-go-up-${VERSION}.dmg"
STAGE="$ROOT/build/dmg-stage"
VOL_NAME="finder-go-up"

[[ -d "$APP" ]] || { echo "Build app first: make all" >&2; exit 1; }

mkdir -p "$ROOT/dist"
rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -sf /Applications "$STAGE/Applications"

hdiutil create -volname "$VOL_NAME" -srcfolder "$STAGE" -ov -format UDZO -imagekey zlib-level=9 "$DMG"

echo "$DMG"
