#!/usr/bin/env bash
# Register NSServices and configure default shortcut ⌃⌘↑.
set -euo pipefail

APP_PATH="${1:-$HOME/Applications/finder-go-up.app}"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

[[ -d "$APP_PATH" ]] || { echo "App not found: $APP_PATH" >&2; exit 1; }

rm -rf "$HOME/Library/Services/finder-go-up.workflow"
rm -rf "$HOME/Library/Services/返回上一级.workflow"

"$LSREGISTER" -f -R -trusted "$APP_PATH" >/dev/null 2>&1 || true
/System/Library/CoreServices/pbs -update 2>/dev/null || true
bash "$ROOT/scripts/set-service-shortcut.sh"
/System/Library/CoreServices/pbs -flush 2>/dev/null || true

if pgrep -x Finder >/dev/null 2>&1; then
  killall Finder 2>/dev/null || true
  sleep 0.5
  open -a Finder
fi
