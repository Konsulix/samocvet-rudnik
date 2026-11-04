# Cut the tile sheet of gen_tiles.sh (4 slate tiles over 4 mud tiles on magenta) into the board kit's tiles:
# each tile squared, its magenta fringe cleaned, scaled to the kit's tile (board_kit.py: TILE 0.94 of a 192 px cell)
# and centred on the kit's 215 px canvas (MARGIN 0.06 each side).
# Usage: py cut_tiles.py <sheet.png> <slate_out_dir> <mud_out_dir> [first_slate,second.. order]
import sys, os
from PIL import Image

src, out_s, out_m = sys.argv[1], sys.argv[2], sys.argv[3]
P, TILE, MARGIN = 192, 0.94, 0.06
CANVAS = round((1 + MARGIN * 2) * P)
MUD_K = (0.78, 0.74, 0.74)   # the mud a little darker and less orange, as in mock F
SIDE = round(TILE * P)

im = Image.open(src).convert("RGBA")
W, H = im.size
px = im.load()

def magenta(c):
    r, g, b = c[0], c[1], c[2]
    return r > 150 and b > 150 and g < 110 and abs(r - b) < 90

mask = Image.new("L", (W, H))
mp = mask.load()
for y in range(H):
    for x in range(W):
        if not magenta(px[x, y]): mp[x, y] = 255

def runs(profile, minlen):
    out, start = [], None
    for i, v in enumerate(profile):
        if v and start is None: start = i
        if not v and start is not None:
            if i - start >= minlen: out.append((start, i))
            start = None
    if start is not None and len(profile) - start >= minlen: out.append((start, len(profile)))
    return out

rows = runs([sum(1 for x in range(0, W, 2) if mp[x, y]) > W * 0.08 for y in range(H)], 60)
tiles = []
for y0, y1 in rows[:2]:
    cols = runs([sum(1 for y in range(y0, y1, 2) if mp[x, y]) > (y1 - y0) * 0.2 for x in range(W)], 60)
    tiles.append([(x0, y0, x1, y1) for x0, x1 in cols])
print("rows", len(tiles), [len(r) for r in tiles])

for k, (row, out) in enumerate(zip(tiles, [out_s, out_m])):
    os.makedirs(out, exist_ok=True)
    for i, (x0, y0, x1, y1) in enumerate(row[:3]):
        t = im.crop((x0, y0, x1, y1))
        # tighten to the tile itself, then shave the anti-aliased magenta rim
        bb = mask.crop((x0, y0, x1, y1)).getbbox()
        t = t.crop(bb)
        e = max(2, round(t.width * 0.012))
        t = t.crop((e, e, t.width - e, t.height - e))
        # the magenta round the chamfered corners and in the anti-aliased rim: out, and the rim's pink tint taken off
        tp = t.load()
        for yy in range(t.height):
            for xx in range(t.width):
                r, g, b, a = tp[xx, yy]
                spill = min(r, b) - g
                if magenta((r, g, b)) or spill > 60:
                    tp[xx, yy] = (0, 0, 0, 0)
                elif spill > 15:
                    tp[xx, yy] = (min(r, g + 15), g, min(b, g + 15), int(a * (1 - (spill - 15) / 45)))
                elif k == 1:
                    tp[xx, yy] = (int(r * MUD_K[0]), int(g * MUD_K[1]), int(b * MUD_K[2]), a)
        t = t.resize((SIDE, SIDE), Image.LANCZOS)
        c = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
        c.paste(t, ((CANVAS - SIDE) // 2, (CANVAS - SIDE) // 2))
        c.save(os.path.join(out, "tile%d.png" % i))
        print("OK", out, i)
