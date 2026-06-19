#!/usr/bin/env bash
# Keep Finder-go-up running in the background after login.
set -euo pipefail

APP_DIR="${APP_DIR:-$HOME/Applications}"
APP_PATH="${1:-$APP_DIR/Finder-go-up.app}"
AGENT_ONLY="${2:-}"
LAUNCH_AGENTS_DIR="${LAUNCH_AGENTS_DIR:-$HOME/Library/LaunchAgents}"
PLIST="$LAUNCH_AGENTS_DIR/com.acode.finder-go-up.plist"
UID_NUM="$(id -u)"
DOMAIN="gui/$UID_NUM"
SERVICE="com.acode.finder-go-up"

[[ -d "$APP_PATH" ]] || { echo "App not found: $APP_PATH" >&2; exit 1; }

EXEC="$APP_PATH/Contents/MacOS/finder-go-up"
[[ -x "$EXEC" ]] || { echo "Executable not found: $EXEC" >&2; exit 1; }

python3 <<PY
import plistlib
plist = {
    "Label": "$SERVICE",
    "ProgramArguments": ["$EXEC", "--background"],
    "RunAtLoad": True,
    "KeepAlive": True,
    "ProcessType": "Background",
    "LimitLoadToSessionType": ["Aqua"],
    "AssociatedBundleIdentifiers": ["com.acode.finder-go-up"],
}
with open("$PLIST", "wb") as f:
    plistlib.dump(plist, f)
PY

launchctl bootout "$DOMAIN/$SERVICE" 2>/dev/null || true
if ! launchctl bootstrap "$DOMAIN" "$PLIST" 2>/dev/null; then
  launchctl load "$PLIST" 2>/dev/null || true
fi

if ! launchctl kickstart -k "$DOMAIN/$SERVICE" 2>/dev/null; then
  if [[ "$AGENT_ONLY" != "--agent-only" ]] && ! pgrep -f "Finder-go-up.app/Contents/MacOS/finder-go-up" >/dev/null 2>&1; then
    "$EXEC" --background &
  fi
fi

sleep 1
if pgrep -f "Finder-go-up.app/Contents/MacOS/finder-go-up --background" >/dev/null 2>&1; then
  echo "Background agent enabled."
else
  echo "Warning: background agent did not start. Services menu needs it." >&2
  exit 1
fi
