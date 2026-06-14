#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${VERSION:-0.0.1}"
DIST="$ROOT/dist"
APP="$ROOT/build/finder-go-up.app"
ZIP="$DIST/finder-go-up-${VERSION}.app.zip"

make -C "$ROOT" clean all
rm -rf "$DIST"
mkdir -p "$DIST"
ditto -c -k --keepParent "$APP" "$ZIP"
echo "$ZIP"
