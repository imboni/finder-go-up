#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${VERSION:-0.0.3}"

make -C "$ROOT" clean all
bash "$ROOT/scripts/create-dmg.sh"
echo "Package: $ROOT/dist/finder-go-up-${VERSION}.dmg"
