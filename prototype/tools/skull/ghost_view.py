"""Side views of ghost heads (ghost_prep.py output) in a row, to check the cut. usage: py ghost_view.py <out.png> <a.json>..."""
import sys, json
from PIL import Image, ImageDraw
tiles = []
for path in sys.argv[2:]:
    d = json.load(open(path)); v = d['v']; f = d['f']
    P = [(v[i * 3 + 2], v[i * 3 + 1]) for i in range(len(v) // 3)]
    lo = (min(p[0] for p in P), min(p[1] for p in P)); hi = (max(p[0] for p in P), max(p[1] for p in P))
    S = 280 / max(hi[0] - lo[0], hi[1] - lo[1])
    im = Image.new('RGB', (300, 300), (20, 20, 24)); dr = ImageDraw.Draw(im)
    for t in range(0, len(f), 3):
        dr.polygon([(10 + (P[f[t + k]][0] - lo[0]) * S, 290 - (P[f[t + k]][1] - lo[1]) * S) for k in range(3)], outline=(200, 190, 170))
    dr.text((6, 6), path.replace(chr(92), '/').split('/')[-1], fill=(255, 120, 120))
    tiles.append(im)
c = Image.new('RGB', (300 * len(tiles), 300))
for i, t in enumerate(tiles): c.paste(t, (i * 300, 0))
c.save(sys.argv[1])
