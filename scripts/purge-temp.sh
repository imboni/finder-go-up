#!/usr/bin/env bash
# Remove temporary/debug Finder-go-up background artifacts only (keep installed app).
set -euo pipefail

LAUNCH_AGENTS_DIR="${LAUNCH_AGENTS_DIR:-$HOME/Library/LaunchAgents}"
BTM_DIR="$HOME/Library/Application Support/com.apple.backgroundtaskmanagementagent"
UID_NUM="$(id -u)"
DOMAIN="gui/$UID_NUM"

for label in \
  com.user.finder-go-up com.user.finder-go-up-warm \
  8.com.user.finder-go-up 8.com.acode.finder-go-up; do
  launchctl bootout "$DOMAIN/$label" 2>/dev/null || true
done

rm -f \
  "$LAUNCH_AGENTS_DIR/com.user.finder-go-up.plist" \
  "$LAUNCH_AGENTS_DIR/com.user.finder-go-up-warm.plist"

for plist in "$LAUNCH_AGENTS_DIR"/*.plist; do
  [[ -f "$plist" ]] || continue
  base="$(basename "$plist" .plist)"
  [[ "$base" == *finder-go-up* ]] || continue
  if plutil -extract ProgramArguments.0 raw "$plist" 2>/dev/null | grep -q '/usr/bin/true'; then
    launchctl bootout "$DOMAIN/$base" 2>/dev/null || true
    launchctl bootout "$DOMAIN/8.$base" 2>/dev/null || true
    rm -f "$plist"
  fi
done

rm -f "$BTM_DIR"/backgrounditems.btm.bak.*

if command -v sfltool >/dev/null 2>&1; then
  if sfltool dumpbtm 2>/dev/null | grep -qiE \
    'finder-go-up|com\.user\.finder-go-up|8\.com\.user\.finder-go-up|/usr/bin/true'; then
    sfltool resetbtm 2>/dev/null || true
  fi
fi

echo "Temporary Finder-go-up background artifacts removed."
