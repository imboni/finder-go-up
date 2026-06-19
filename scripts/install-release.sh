#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="${APP_DIR:-$HOME/Applications}"
APP_PATH="$APP_DIR/Finder-go-up.app"
PREFIX="${PREFIX:-$HOME/.local}"

bash "$ROOT/scripts/purge.sh"
bash "$ROOT/scripts/sign-app.sh" "$ROOT/Finder-go-up.app"
rm -rf "$APP_PATH"
cp -R "$ROOT/Finder-go-up.app" "$APP_PATH"
bash "$ROOT/scripts/sign-app.sh" "$APP_PATH"

install -d "$PREFIX/bin"
install -m 755 "$APP_PATH/Contents/MacOS/finder-go-up-client" "$PREFIX/bin/finder-go-up"
bash "$ROOT/scripts/register-app-service.sh" "$APP_PATH"
bash "$ROOT/scripts/register-background-agent.sh" "$APP_PATH"
bash "$ROOT/scripts/configure-irightmouse.sh" || true

echo "Installed Finder-go-up → $APP_PATH"
