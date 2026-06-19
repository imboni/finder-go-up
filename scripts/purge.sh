#!/usr/bin/env bash
# Remove all Finder-go-up artifacts including legacy extension/daemon installs.
set -euo pipefail

PREFIX="${PREFIX:-$HOME/.local}"
APP_DIRS=(
  "${APP_DIR:-$HOME/Applications}"
  "$HOME/Applications"
  "/Applications"
)
LAUNCH_AGENTS_DIR="${LAUNCH_AGENTS_DIR:-$HOME/Library/LaunchAgents}"
BTM_DIR="$HOME/Library/Application Support/com.apple.backgroundtaskmanagementagent"
UID_NUM="$(id -u)"
DOMAIN="gui/$UID_NUM"
BUNDLE_ID="com.acode.finder-go-up"

killall finder-go-up finder-go-up-daemon 2>/dev/null || true
pkill -f "finder-go-up.app/Contents/MacOS/finder-go-up" 2>/dev/null || true
pkill -f "Finder-go-up.app/Contents/MacOS/finder-go-up" 2>/dev/null || true
pkill -f "finder-go-up --background" 2>/dev/null || true
pkill -f "/usr/bin/open.*finder-go-up" 2>/dev/null || true
pkill -f "/usr/bin/open.*Finder-go-up" 2>/dev/null || true

for label in \
  com.acode.finder-go-up com.acode.finder-go-up-warm \
  com.user.finder-go-up com.user.finder-go-up-warm \
  8.com.acode.finder-go-up 8.com.user.finder-go-up; do
  launchctl bootout "$DOMAIN/$label" 2>/dev/null || true
done

rm -f \
  "$LAUNCH_AGENTS_DIR/com.acode.finder-go-up.plist" \
  "$LAUNCH_AGENTS_DIR/com.acode.finder-go-up-warm.plist" \
  "$LAUNCH_AGENTS_DIR/com.user.finder-go-up.plist" \
  "$LAUNCH_AGENTS_DIR/com.user.finder-go-up-warm.plist"

# Remove debug/temporary launch agents (e.g. ProgramArguments -> /usr/bin/true).
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

for bin_dir in "$PREFIX/bin" /usr/local/bin /opt/homebrew/bin; do
  rm -f \
    "$bin_dir/finder-go-up" \
    "$bin_dir/finder-go-up-client" \
    "$bin_dir/finder-go-up-daemon"
done

for app_dir in "${APP_DIRS[@]}"; do
  rm -rf \
    "$app_dir/Finder-go-up.app" \
    "$app_dir/finder-go-up.app" \
    "$app_dir/返回上一级.app"
done

rm -rf \
  "$HOME/Library/Services/finder-go-up.workflow" \
  "$HOME/Library/Services/返回上一级.workflow" \
  "$HOME/Library/Application Support/finder-go-up" \
  "$HOME/Library/Caches/$BUNDLE_ID" \
  "$HOME/Library/HTTPStorages/$BUNDLE_ID" \
  "$HOME/Library/Preferences/$BUNDLE_ID.plist" \
  "$HOME/Library/Saved Application State/$BUNDLE_ID.savedState" \
  "$HOME/Library/WebKit/$BUNDLE_ID"

rm -f /tmp/finder-go-up.sock /tmp/finder-go-up-daemon.log
rm -f "$BTM_DIR"/backgrounditems.btm.bak.*

pluginkit -r -i com.acode.finder-go-up.findersync 2>/dev/null || true
defaults delete "$BUNDLE_ID" 2>/dev/null || true

# Clear ghost login/background records (com.user.*, /usr/bin/true, etc.).
if command -v sfltool >/dev/null 2>&1; then
  if sfltool dumpbtm 2>/dev/null | grep -qiE \
    'finder-go-up|com\.user\.finder-go-up|8\.com\.user\.finder-go-up|/usr/bin/true'; then
    sfltool resetbtm 2>/dev/null || true
  fi
fi

/System/Library/CoreServices/pbs -flush 2>/dev/null || true
