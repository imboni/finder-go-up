#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="${APP_DIR:-$HOME/Applications}"
APP_PATH="$APP_DIR/finder-go-up.app"
PREFIX="${PREFIX:-$HOME/.local}"

bash "$ROOT/scripts/purge.sh"

make -C "$ROOT" clean all APP_DIR="$APP_DIR"
rm -rf "$APP_PATH"
cp -R "$ROOT/build/finder-go-up.app" "$APP_PATH"
bash "$ROOT/scripts/sign-app.sh" "$APP_PATH"

install -d "$PREFIX/bin"
install -m 755 "$APP_PATH/Contents/MacOS/finder-go-up-client" "$PREFIX/bin/finder-go-up"

bash "$ROOT/scripts/register-app-service.sh" "$APP_PATH"

rm -f "$HOME/Library/Application Support/finder-go-up/onboarded"
open -a "$APP_PATH" --args --show

echo "Installed finder-go-up → $APP_PATH"
