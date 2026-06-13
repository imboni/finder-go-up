#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PREFIX="${PREFIX:-$HOME/.local}"
APP_DIR="${APP_DIR:-$HOME/Applications}"
LAUNCH_AGENTS_DIR="${LAUNCH_AGENTS_DIR:-$HOME/Library/LaunchAgents}"
UID_NUM="$(id -u)"
DOMAIN="gui/$UID_NUM"

OLD_DAEMON_LABEL="com.user.finder-go-up"
OLD_WARM_LABEL="com.user.finder-go-up-warm"
NEW_DAEMON_LABEL="com.acode.finder-go-up"
NEW_WARM_LABEL="com.acode.finder-go-up-warm"

echo "==> Building"
make -C "$ROOT" all launchagents PREFIX="$PREFIX" APP_DIR="$APP_DIR"

BIN_DIR="$PREFIX/bin"
APP_PATH="$APP_DIR/返回上一级.app"
mkdir -p "$BIN_DIR" "$APP_DIR"

echo "==> Installing binaries to $BIN_DIR"
install -m 755 "$ROOT/build/finder-go-up-daemon" "$BIN_DIR/finder-go-up-daemon"
install -m 755 "$ROOT/build/finder-go-up-client" "$BIN_DIR/finder-go-up-client"

echo "==> Installing app bundle to $APP_PATH"
rm -rf "$APP_PATH"
cp -R "$ROOT/build/返回上一级.app" "$APP_PATH"

echo "==> Installing LaunchAgents"
for label in "$OLD_DAEMON_LABEL" "$OLD_WARM_LABEL" "$NEW_DAEMON_LABEL" "$NEW_WARM_LABEL"; do
  launchctl bootout "$DOMAIN/$label" 2>/dev/null || true
done

install -m 644 "$ROOT/build/launchagents/com.acode.finder-go-up.plist" \
  "$LAUNCH_AGENTS_DIR/com.acode.finder-go-up.plist"
install -m 644 "$ROOT/build/launchagents/com.acode.finder-go-up-warm.plist" \
  "$LAUNCH_AGENTS_DIR/com.acode.finder-go-up-warm.plist"

rm -f "$LAUNCH_AGENTS_DIR/$OLD_DAEMON_LABEL.plist" "$LAUNCH_AGENTS_DIR/$OLD_WARM_LABEL.plist"

launchctl bootstrap "$DOMAIN" "$LAUNCH_AGENTS_DIR/com.acode.finder-go-up.plist"
launchctl bootstrap "$DOMAIN" "$LAUNCH_AGENTS_DIR/com.acode.finder-go-up-warm.plist"

echo
echo "Installed Finder Go Up"
echo "  daemon : $BIN_DIR/finder-go-up-daemon"
echo "  client : $BIN_DIR/finder-go-up-client"
echo "  app    : $APP_PATH"
echo
echo "Configure your launcher to open:"
echo "  $APP_PATH"
echo "See docs/irightmouse.md for iRightMouse Pro setup."
