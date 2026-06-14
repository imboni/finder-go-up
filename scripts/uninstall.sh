#!/usr/bin/env bash
set -euo pipefail

bash "$(cd "$(dirname "$0")/.." && pwd)/scripts/purge.sh"

PREFIX="${PREFIX:-$HOME/.local}"
APP_DIR="${APP_DIR:-$HOME/Applications}"

rm -f "$PREFIX/bin/finder-go-up" "$PREFIX/bin/finder-go-up-client"
rm -rf "$APP_DIR/finder-go-up.app"
rm -rf "$HOME/Library/Application Support/finder-go-up"
/System/Library/CoreServices/pbs -flush 2>/dev/null || true

echo "Uninstalled."
