#!/usr/bin/env bash
set -euo pipefail

APP_PATH="${1:-$HOME/Applications/Finder-go-up.app}"
IDENT="${CODESIGN_IDENTITY:--}"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"

[[ -d "$APP_PATH" ]] || { echo "App not found: $APP_PATH" >&2; exit 1; }

xattr -cr "$APP_PATH" 2>/dev/null || true

sign() { codesign -s "$IDENT" --force --timestamp=none "$1"; }

for nested in "$APP_PATH/Contents/Resources/"*.app; do
  [[ -d "$nested" ]] || continue
  bash "$SELF" "$nested"
done

for bin in "$APP_PATH/Contents/MacOS/"*; do
  [[ -f "$bin" ]] || continue
  sign "$bin"
done

sign "$APP_PATH"

codesign -vv --strict "$APP_PATH"
"$LSREGISTER" -f -R -trusted "$APP_PATH" >/dev/null 2>&1 || true
