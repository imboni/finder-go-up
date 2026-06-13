#!/usr/bin/env bash
# Generate AppIcon.icns from assets/logo.png (1024×1024 recommended).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MASTER="${1:-$ROOT/assets/logo.png}"
ICONSET="$ROOT/build/AppIcon.iconset"
OUTPUT="$ROOT/resources/AppIcon.icns"

if [[ ! -f "$MASTER" ]]; then
  echo "Logo not found: $MASTER" >&2
  exit 1
fi

mkdir -p "$ICONSET"

generate() {
  local name="$1"
  local size="$2"
  sips -z "$size" "$size" "$MASTER" --out "$ICONSET/$name" >/dev/null
}

generate icon_16x16.png 16
generate icon_16x16@2x.png 32
generate icon_32x32.png 32
generate icon_32x32@2x.png 64
generate icon_128x128.png 128
generate icon_128x128@2x.png 256
generate icon_256x256.png 256
generate icon_256x256@2x.png 512
generate icon_512x512.png 512
generate icon_512x512@2x.png 1024

iconutil -c icns "$ICONSET" -o "$OUTPUT"
rm -rf "$ICONSET"

echo "Generated $OUTPUT"
