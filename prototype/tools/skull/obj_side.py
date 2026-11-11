"""Side and top view of an OBJ (y up, z forward) as a PNG, to choose where its head is cut.
usage: py obj_side.py <in.obj> <out.png> [cut_z]"""
import sys
from PIL import Image, ImageDraw
src, out = sys.argv[1], sys.argv[2]
cut = float(sys.argv[3]) if len(sys.argv) > 3 else None
v, f = [], []
for l in open(src, encoding='utf-8', errors='ignore'):
    if l.startswith('v '): v.append(list(map(float, l.split()[1:4])))
    elif l.startswith('f '): f.append([int(t.split('/')[0]) - 1 for t in l.split()[1:]])
lo = [min(p[i] for p in v) for i in range(3)]; hi = [max(p[i] for p in v) for i in range(3)]
S = 900 / max(hi[2] - lo[2], 1e-6)
W, H = 940, int((hi[1] - lo[1] + hi[0] - lo[0]) * S) + 80
im = Image.new('RGB', (W, H), (20, 20, 24)); d = ImageDraw.Draw(im)
def side(p): return (20 + (p[2] - lo[2]) * S, 20 + (hi[1] - p[1]) * S)
def top(p): return (20 + (p[2] - lo[2]) * S, 60 + (hi[1] - lo[1]) * S + (p[0] - lo[0]) * S)
for face in f:
    for proj in (side, top):
        pts = [proj(v[i]) for i in face]
        d.polygon(pts, outline=(200, 190, 170))
if cut is not None:
    x = 20 + (cut - lo[2]) * S
    d.line([(x, 0), (x, H)], fill=(255, 60, 60), width=2)
im.save(out)
print('bbox', lo, hi)
