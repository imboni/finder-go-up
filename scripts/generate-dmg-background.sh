#!/usr/bin/env bash
set -euo pipefail

OUT="${1:-build/dmg-stage/.background/background.png}"
mkdir -p "$(dirname "$OUT")"
export OUT

python3 <<'PY'
import os, struct, zlib, pathlib, math

w, h = 660, 360
pixels = bytearray(w * h * 4)

def set_px(x, y, r, g, b, a=255):
    if 0 <= x < w and 0 <= y < h:
        i = (y * w + x) * 4
        pixels[i:i+4] = [r, g, b, a]

for y in range(h):
    for x in range(w):
        t = y / max(h - 1, 1)
        u = x / max(w - 1, 1)
        r = min(255, int(246 + (255 - 246) * t + 4 * math.sin(u * math.pi)))
        g = min(255, int(247 + (255 - 247) * t + 3 * math.sin(u * math.pi)))
        b = min(255, int(249 + (255 - 249) * t + 2 * math.sin(u * math.pi)))
        set_px(x, y, r, g, b)

# Soft drop zones
for cx, cy, rw, rh in [(150, 190, 96, 96), (470, 190, 96, 96)]:
    for y in range(cy - rh // 2, cy + rh // 2):
        for x in range(cx - rw // 2, cx + rw // 2):
            dx = abs(x - cx) / (rw / 2)
            dy = abs(y - cy) / (rh / 2)
            if dx * dx + dy * dy <= 1.0:
                set_px(x, y, 255, 255, 255, 28)

# Arrow between icons
gray = (140, 140, 148)
for x in range(300, 340):
    for dy in range(-2, 3):
        set_px(x, 228 + dy, *gray)
for t in range(12):
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
