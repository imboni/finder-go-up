#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${VERSION:-0.0.2}"
APP="$ROOT/build/finder-go-up.app"
DMG="$ROOT/dist/finder-go-up-${VERSION}.dmg"
STAGE="$ROOT/build/dmg-stage"
VOL_NAME="finder-go-up"
TMP_DMG="$ROOT/build/finder-go-up-temp.dmg"

[[ -d "$APP" ]] || { echo "Build app first: make all" >&2; exit 1; }

mkdir -p "$ROOT/dist"
rm -rf "$STAGE" "$TMP_DMG" "$DMG"
mkdir -p "$STAGE/.background"
cp -R "$APP" "$STAGE/"
ln -sf /Applications "$STAGE/Applications"
cp "$ROOT/resources/AppIcon.icns" "$STAGE/.VolumeIcon.icns"
if command -v SetFile >/dev/null 2>&1; then
  SetFile -a C "$STAGE" || true
fi

bash "$ROOT/scripts/generate-dmg-background.sh" "$STAGE/.background/background.png"

layout_dmg() {
  local mount="$1"
  /usr/bin/osascript <<APPLESCRIPT
tell application "Finder"
  tell disk "$VOL_NAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {200, 120, 860, 480}
    set theViewOptions to the icon view options of container window
    set arrangement of theViewOptions to not arranged
    set icon size of theViewOptions to 128
    set background picture of theViewOptions to file ".background:background.png"
    set position of item "finder-go-up.app" of container window to {150, 170}
    set position of item "Applications" of container window to {470, 170}
    close
    open
    update without registering applications
    delay 2
  end tell
end tell
APPLESCRIPT
}

if hdiutil create -size 200m -fs HFS+ -volname "$VOL_NAME" -ov "$TMP_DMG" >/dev/null 2>&1; then
  MOUNT=$(hdiutil attach "$TMP_DMG" -nobrowse | grep '/Volumes/' | tail -1 | awk '{for(i=1;i<=NF;i++) if($i ~ /^\/Volumes\//) print $i}')
  cp -R "$STAGE/." "$MOUNT/"
  chmod -Rf go-w "$MOUNT" 2>/dev/null || true
  layout_dmg "$MOUNT"
  chmod -Rf go-w "$MOUNT" 2>/dev/null || true
  sync
  hdiutil detach "$MOUNT" >/dev/null
  hdiutil convert "$TMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG" >/dev/null
  rm -f "$TMP_DMG"
else
  hdiutil create -volname "$VOL_NAME" -srcfolder "$STAGE" -format UDZO -imagekey zlib-level=9 -o "$DMG" >/dev/null
fi

echo "$DMG"
