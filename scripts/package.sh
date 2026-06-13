#!/usr/bin/env bash
# Build a distributable release bundle under dist/
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
NAME="finder-go-up"
STAGING="$DIST/$NAME"
ARCHIVE="$DIST/${NAME}-macos.tar.gz"

echo "==> Building"
make -C "$ROOT" clean all launchagents

echo "==> Staging $STAGING"
rm -rf "$STAGING" "$ARCHIVE"
mkdir -p "$STAGING/bin" "$STAGING/launchagents" "$STAGING/scripts"

cp "$ROOT/build/finder-go-up-daemon" "$ROOT/build/finder-go-up-client" "$STAGING/bin/"
cp -R "$ROOT/build/finder-go-up.app" "$STAGING/"
cp "$ROOT/launchagents/"*.template "$STAGING/launchagents/"
cp -R "$ROOT/resources/finder-go-up.workflow" "$STAGING/"
cp "$ROOT/scripts/install-release.sh" "$STAGING/install.sh"
cp "$ROOT/scripts/uninstall.sh" "$STAGING/scripts/"
cp "$ROOT/LICENSE" "$ROOT/README.md" "$STAGING/"

(
  cd "$DIST"
  tar czf "${NAME}-macos.tar.gz" "$NAME"
)

echo
echo "Package: $ARCHIVE"
echo "Install: tar xzf ${NAME}-macos.tar.gz && cd $NAME && bash install.sh"
