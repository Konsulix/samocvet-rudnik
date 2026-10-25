"""The hoard's turntable (prototype/tools/blender/hoard_kit.py) onto the bosses' 1 pt pixel grid: one palette for all
frames (cell mode, as cellmode.py: each pixel = the most frequent palette colour of its cell, no mud), a dark outline
round the silhouette, and the geode mask brought onto the same grid. Packs both into sheets for the game.

python hoard_px.py <render dir with color/ and mask/> <out dir> [pt=300] [cols=6]
  out/hoard_color.png, out/hoard_mask.png (red = 20 x geode number), out/hoard.json
"""
import sys, os, json, glob
import numpy as np
from PIL import Image

SRC, OUT = sys.argv[1], sys.argv[2]
OPT = dict(a.split("=", 1) for a in sys.argv[3:] if "=" in a)
PT = int(OPT.get("pt", 300))
COLS = int(OPT.get("cols", 6))


def palette(img, n):
    q = img.quantize(colors=n, method=Image.Quantize.MEDIANCUT, kmeans=4)
    p = q.getpalette()
    k = min(n, len(p) // 3)
    return np.array(p[:k * 3], dtype=float).reshape(k, 3)


def index(a, pal):
    out = np.empty(a.shape[:2], dtype=np.int32)
    for y in range(0, a.shape[0], 64):
        d = ((a[y:y + 64, :, None, :] - pal[None, None]) ** 2).sum(-1)
        out[y:y + 64] = d.argmin(-1)
    return out


def cells(h, w, n):
    """the source pixel ranges of each of n x n output cells"""
    edges_y = (np.arange(n + 1) * h / n).astype(int)
    edges_x = (np.arange(n + 1) * w / n).astype(int)
    return edges_y, edges_x


def mode_grid(idx, n, k, valid=None):
    ey, ex = cells(*idx.shape, n)
    out = np.zeros((n, n), dtype=np.int32)
    for j in range(n):
        for i in range(n):
            c = idx[ey[j]:max(ey[j + 1], ey[j] + 1), ex[i]:max(ex[i + 1], ex[i] + 1)].ravel()
            if valid is not None:
                v = valid[ey[j]:max(ey[j + 1], ey[j] + 1), ex[i]:max(ex[i + 1], ex[i] + 1)].ravel()
                c = c[v] if v.any() else c
            out[j, i] = np.bincount(c, minlength=k).argmax()
    return out


files = sorted(glob.glob(os.path.join(SRC, "color", "*.png")))
frames = [Image.open(f).convert("RGBA") for f in files]
masks = [Image.open(os.path.join(SRC, "mask", os.path.basename(f))).convert("RGBA") for f in files]
# one palette for the whole turn: sampled from every few frames, plus the brightest accents (gold, the eyes)
sample = []
for im in frames[::6]:
    a = np.asarray(im)
    sample.append(a[a[..., 3] > 128][:, :3])
px = np.vstack(sample)
lum = px @ np.array([0.3, 0.59, 0.11])
pal = np.vstack([palette(Image.fromarray(px.reshape(-1, 1, 3).astype(np.uint8)), 52),
                 palette(Image.fromarray(px[lum >= np.percentile(lum, 98.5)].reshape(-1, 1, 3).astype(np.uint8)), 6)])
dark = int(np.argmin(pal @ np.array([0.3, 0.59, 0.11])))
rows = (len(frames) + COLS - 1) // COLS
sheet_c = Image.new("RGBA", (COLS * PT, rows * PT), (0, 0, 0, 0))
sheet_m = Image.new("RGBA", (COLS * PT, rows * PT), (0, 0, 0, 255))
for f, (im, mk) in enumerate(zip(frames, masks)):
    a = np.asarray(im).astype(float)
    solid = a[..., 3] > 128
    idx = index(a[..., :3], pal)
    g = mode_grid(idx, PT, len(pal), solid)
    al = mode_grid(solid.astype(np.int32), PT, 2)
    # a dark outline where the silhouette meets the air, as in the boss' pictures
    edge = np.zeros_like(al, dtype=bool)
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        edge |= (al == 1) & (np.roll(al, (dy, dx), (0, 1)) == 0)
    g[edge] = dark
    rgb = pal[g].astype(np.uint8)
    out = np.dstack([rgb, (al * 255).astype(np.uint8)])
    m = np.rint(np.asarray(mk)[..., 0] / 20.0).astype(np.int32)
    mg = mode_grid(m, PT, 16) * (al == 1)
    x, y = (f % COLS) * PT, (f // COLS) * PT
    sheet_c.paste(Image.fromarray(out, "RGBA"), (x, y))
    mm = np.zeros((PT, PT, 4), dtype=np.uint8); mm[..., 0] = mg * 20; mm[..., 3] = 255
    sheet_m.paste(Image.fromarray(mm, "RGBA"), (x, y))
os.makedirs(OUT, exist_ok=True)
sheet_c.save(os.path.join(OUT, "hoard_color.png"))
sheet_m.save(os.path.join(OUT, "hoard_mask.png"))
json.dump({"frames": len(frames), "cols": COLS, "size": PT, "geodes": 9}, open(os.path.join(OUT, "hoard.json"), "w"))
print("hoard: %d frames, %d colours -> %s" % (len(frames), len(pal), OUT))
