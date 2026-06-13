#!/usr/bin/env bash
# Install from a prebuilt release package (no compile required).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
PREFIX="${PREFIX:-$HOME/.local}"
APP_DIR="${APP_DIR:-$HOME/Applications}"
LAUNCH_AGENTS_DIR="${LAUNCH_AGENTS_DIR:-$HOME/Library/LaunchAgents}"
UID_NUM="$(id -u)"
DOMAIN="gui/$UID_NUM"

OLD_DAEMON_LABEL="com.user.finder-go-up"
OLD_WARM_LABEL="com.user.finder-go-up-warm"
NEW_DAEMON_LABEL="com.acode.finder-go-up"
NEW_WARM_LABEL="com.acode.finder-go-up-warm"
LEGACY_APP="$APP_DIR/返回上一级.app"
LEGACY_SERVICE="$HOME/Library/Services/返回上一级.workflow"

BIN_DIR="$PREFIX/bin"
APP_PATH="$APP_DIR/finder-go-up.app"
CLIENT_PATH="$BIN_DIR/finder-go-up-client"
WORKFLOW_DST="$HOME/Library/Services/finder-go-up.workflow"

mkdir -p "$BIN_DIR" "$APP_DIR"

echo "==> Removing legacy installs"
rm -rf "$LEGACY_APP" "$LEGACY_SERVICE"

echo "==> Installing binaries to $BIN_DIR"
install -m 755 "$ROOT/bin/finder-go-up-daemon" "$BIN_DIR/finder-go-up-daemon"
install -m 755 "$ROOT/bin/finder-go-up-client" "$BIN_DIR/finder-go-up-client"

echo "==> Installing Finder context menu"
rm -rf "$WORKFLOW_DST"
mkdir -p "$WORKFLOW_DST/Contents/Resources"
cp "$ROOT/finder-go-up.workflow/Contents/Info.plist" "$WORKFLOW_DST/Contents/Info.plist"
sed "s|@@CLIENT_PATH@@|$CLIENT_PATH|g" \
  "$ROOT/finder-go-up.workflow/Contents/Resources/document.wflow" \
  > "$WORKFLOW_DST/Contents/Resources/document.wflow"
/System/Library/CoreServices/pbs -flush 2>/dev/null || true

echo "==> Installing app bundle to $APP_PATH"
rm -rf "$APP_PATH"
cp -R "$ROOT/finder-go-up.app" "$APP_PATH"

echo "==> Installing LaunchAgents"
for label in "$OLD_DAEMON_LABEL" "$OLD_WARM_LABEL" "$NEW_DAEMON_LABEL" "$NEW_WARM_LABEL"; do
  launchctl bootout "$DOMAIN/$label" 2>/dev/null || true
done

install -m 644 "$ROOT/launchagents/daemon.plist.template" \
  "$LAUNCH_AGENTS_DIR/com.acode.finder-go-up.plist.tmp"
sed \
  -e "s|@@PREFIX@@|$PREFIX|g" \
  -e "s|@@APP_PATH@@|$APP_PATH|g" \
  -e "s|@@LOG_PATH@@|/tmp/finder-go-up-daemon.log|g" \
  "$LAUNCH_AGENTS_DIR/com.acode.finder-go-up.plist.tmp" \
  > "$LAUNCH_AGENTS_DIR/com.acode.finder-go-up.plist"
rm -f "$LAUNCH_AGENTS_DIR/com.acode.finder-go-up.plist.tmp"

install -m 644 "$ROOT/launchagents/warm.plist.template" \
  "$LAUNCH_AGENTS_DIR/com.acode.finder-go-up-warm.plist.tmp"
sed \
  -e "s|@@PREFIX@@|$PREFIX|g" \
  -e "s|@@APP_PATH@@|$APP_PATH|g" \
  "$LAUNCH_AGENTS_DIR/com.acode.finder-go-up-warm.plist.tmp" \
  > "$LAUNCH_AGENTS_DIR/com.acode.finder-go-up-warm.plist"
rm -f "$LAUNCH_AGENTS_DIR/com.acode.finder-go-up-warm.plist.tmp"

rm -f "$LAUNCH_AGENTS_DIR/$OLD_DAEMON_LABEL.plist" "$LAUNCH_AGENTS_DIR/$OLD_WARM_LABEL.plist"

launchctl bootstrap "$DOMAIN" "$LAUNCH_AGENTS_DIR/com.acode.finder-go-up.plist"
launchctl bootstrap "$DOMAIN" "$LAUNCH_AGENTS_DIR/com.acode.finder-go-up-warm.plist"

echo "==> Opening finder-go-up for setup"
open "$APP_PATH"

echo
echo "Installed finder-go-up"
echo "  daemon  : $BIN_DIR/finder-go-up-daemon"
echo "  client  : $BIN_DIR/finder-go-up-client"
echo "  app     : $APP_PATH"
echo "  service : $WORKFLOW_DST"
