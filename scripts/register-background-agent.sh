#!/usr/bin/env bash
# Keep finder-go-up running in the background after login.
set -euo pipefail

APP_DIR="${APP_DIR:-$HOME/Applications}"
APP_PATH="${1:-$APP_DIR/finder-go-up.app}"
AGENT_ONLY="${2:-}"
LAUNCH_AGENTS_DIR="${LAUNCH_AGENTS_DIR:-$HOME/Library/LaunchAgents}"
PLIST="$LAUNCH_AGENTS_DIR/com.acode.finder-go-up.plist"
UID_NUM="$(id -u)"
DOMAIN="gui/$UID_NUM"

[[ -d "$APP_PATH" ]] || { echo "App not found: $APP_PATH" >&2; exit 1; }

python3 <<PY
import plistlib
plist = {
    "Label": "com.acode.finder-go-up",
    "ProgramArguments": ["/usr/bin/open", "-g", "$APP_PATH"],
    "RunAtLoad": True,
}
with open("$PLIST", "wb") as f:
    plistlib.dump(plist, f)
PY

launchctl bootout "$DOMAIN/com.acode.finder-go-up" 2>/dev/null || true
launchctl bootstrap "$DOMAIN" "$PLIST" 2>/dev/null || launchctl load "$PLIST" 2>/dev/null || true

if [[ "$AGENT_ONLY" != "--agent-only" ]] && ! pgrep -f "finder-go-up.app/Contents/MacOS/finder-go-up" >/dev/null 2>&1; then
  open -g "$APP_PATH"
fi

echo "Background agent enabled."
