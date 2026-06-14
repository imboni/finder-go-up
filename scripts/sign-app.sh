#!/usr/bin/env bash
set -euo pipefail

APP_PATH="${1:-$HOME/Applications/finder-go-up.app}"
IDENT="${CODESIGN_IDENTITY:--}"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

[[ -d "$APP_PATH" ]] || { echo "App not found: $APP_PATH" >&2; exit 1; }

xattr -cr "$APP_PATH" 2>/dev/null || true

sign() { codesign -s "$IDENT" --force --timestamp=none "$1"; }

sign "$APP_PATH/Contents/MacOS/finder-go-up"
sign "$APP_PATH/Contents/MacOS/finder-go-up-client"
sign "$APP_PATH"

codesign -vv --strict "$APP_PATH"
"$LSREGISTER" -f -R -trusted "$APP_PATH" >/dev/null 2>&1 || true
