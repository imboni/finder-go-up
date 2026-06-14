#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${VERSION:-0.0.1}"
DIST="$ROOT/dist"
NAME="finder-go-up-${VERSION}-macos"
STAGING="$DIST/$NAME"
ARCHIVE="$DIST/${NAME}.tar.gz"

make -C "$ROOT" clean all
rm -rf "$STAGING" "$ARCHIVE"
mkdir -p "$STAGING/scripts"

cp -R "$ROOT/build/finder-go-up.app" "$STAGING/"
cp "$ROOT/scripts/install-release.sh" "$STAGING/install.sh"
cp "$ROOT/scripts/purge.sh" "$ROOT/scripts/sign-app.sh" \
   "$ROOT/scripts/register-app-service.sh" "$ROOT/scripts/set-service-shortcut.sh" \
   "$STAGING/scripts/"
cp "$ROOT/scripts/uninstall.sh" "$STAGING/scripts/"
cp "$ROOT/LICENSE" "$STAGING/"
cp "$ROOT/README.md" "$STAGING/"

tar -czf "$ARCHIVE" -C "$DIST" "$NAME"
echo "$ARCHIVE"
