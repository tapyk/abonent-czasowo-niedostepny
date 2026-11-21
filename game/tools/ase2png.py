"""Minimal .aseprite (RGBA, 32 bpp) -> PNG: composites visible layers of frame 0."""
import struct, zlib, sys
from PIL import Image
src, dst = sys.argv[1], sys.argv[2]
d = open(src, 'rb').read()
_, magic, frames, W, H, depth = struct.unpack('<IHHHHH', d[:14])
assert magic == 0xA5E0 and depth == 32, (hex(magic), depth)
pos = 128
fsize, fmagic, old_chunks, dur, _, new_chunks = struct.unpack('<IHHH2sI', d[pos:pos+16])
n = new_chunks or old_chunks
p = pos + 16
layers, cels = [], []
for _ in range(n):
    csize, ctype = struct.unpack('<IH', d[p:p+6]); body = d[p+6:p+csize]
    if ctype == 0x2004:  # layer
        flags, ltype, child, _, _, blend, opacity = struct.unpack('<HHHHHHB', body[:13])
        layers.append({'visible': flags & 1, 'type': ltype, 'opacity': opacity})
    elif ctype == 0x2005:  # cel
        li, x, y, op, ct = struct.unpack('<HhhBH', body[:9])
        rest = body[16:]
        if ct in (0, 2):
            w, h = struct.unpack('<HH', rest[:4]); px = rest[4:]
            if ct == 2: px = zlib.decompress(px)
            cels.append((li, x, y, op, Image.frombytes('RGBA', (w, h), px)))
    p += csize
out = Image.new('RGBA', (W, H), (0, 0, 0, 0))
for li, x, y, op, im in cels:
    L = layers[li] if li < len(layers) else {'visible': 1, 'type': 0}
    if not L['visible'] or L['type'] != 0: continue
    out.alpha_composite(im, (x, y)) if x >= 0 and y >= 0 else out.paste(im, (x, y), im)
out.save(dst); print(dst, out.size, out.getbbox(), len(layers), 'layers', len(cels), 'cels')
