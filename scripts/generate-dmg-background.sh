#!/usr/bin/env bash
set -euo pipefail

OUT="${1:-build/dmg-stage/.background/background.png}"
mkdir -p "$(dirname "$OUT")"
export OUT

python3 <<'PY'
import os, struct, zlib, pathlib

w, h = 640, 360
pixels = []
for y in range(h):
    for x in range(w):
        t = y / max(h - 1, 1)
        r = int(248 + (255 - 248) * t)
        g = int(248 + (255 - 248) * t)
        b = int(250 + (255 - 250) * t)
        pixels.extend([r, g, b, 255])

def set_px(x, y, r, g, b, a=255):
    if 0 <= x < w and 0 <= y < h:
        i = (y * w + x) * 4
        pixels[i:i+4] = [r, g, b, a]

gray = (150, 150, 155)
for x in range(300, 340):
    for dy in range(-2, 3):
        set_px(x, 228 + dy, *gray)
for t in range(10):
    set_px(340 + t, 228 - t // 2, *gray)
    set_px(340 + t, 228 + t // 2, *gray)

rows = []
for y in range(h):
    row = bytearray([0])
    row.extend(pixels[y * w * 4:(y + 1) * w * 4])
    rows.append(bytes(row))

def chunk(tag, data):
    crc = zlib.crc32(tag + data) & 0xFFFFFFFF
    return struct.pack('>I', len(data)) + tag + data + struct.pack('>I', crc)

raw = b''.join(rows)
pathlib.Path(os.environ['OUT']).write_bytes(b''.join([
    b'\x89PNG\r\n\x1a\n',
    chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0)),
    chunk(b'IDAT', zlib.compress(raw, 9)),
    chunk(b'IEND', b''),
]))
PY
