#!/usr/bin/env bash
# Remove all finder-go-up artifacts including legacy extension/daemon installs.
set -euo pipefail

PREFIX="${PREFIX:-$HOME/.local}"
APP_DIR="${APP_DIR:-$HOME/Applications}"
LAUNCH_AGENTS_DIR="${LAUNCH_AGENTS_DIR:-$HOME/Library/LaunchAgents}"
UID_NUM="$(id -u)"
DOMAIN="gui/$UID_NUM"

killall finder-go-up finder-go-up-daemon 2>/dev/null || true
pkill -f "finder-go-up --background" 2>/dev/null || true

for label in com.acode.finder-go-up com.acode.finder-go-up-warm \
             com.user.finder-go-up com.user.finder-go-up-warm; do
  launchctl bootout "$DOMAIN/$label" 2>/dev/null || true
done

rm -f \
  "$LAUNCH_AGENTS_DIR/com.acode.finder-go-up.plist" \
  "$LAUNCH_AGENTS_DIR/com.acode.finder-go-up-warm.plist" \
  "$LAUNCH_AGENTS_DIR/com.user.finder-go-up.plist" \
  "$LAUNCH_AGENTS_DIR/com.user.finder-go-up-warm.plist"

rm -f "$PREFIX/bin/finder-go-up-daemon" "$PREFIX/bin/finder-go-up-client"
rm -rf "$APP_DIR/finder-go-up.app" "$APP_DIR/返回上一级.app"
rm -rf "$HOME/Library/Services/finder-go-up.workflow"
rm -rf "$HOME/Library/Services/返回上一级.workflow"
rm -f /tmp/finder-go-up.sock /tmp/finder-go-up-daemon.log

pluginkit -r -i com.acode.finder-go-up.findersync 2>/dev/null || true
/System/Library/CoreServices/pbs -flush 2>/dev/null || true
