"""Butterfly specimen photo (dorsal, plain background) -> one wing pair as RGBA texture + json.
usage: py cut_butterfly.py <photo.jpg> <out.png> [glass]
The specimen's right side (its left in the photo is mirrored the same) is cut away from the body: the texture's left
edge is the body axis, head at the top. glass: see-through wings on a pale ground -> alpha from how much darker than
the ground. Writes <out>.json: {aspect: w/h, root: row (0 top..1) where the wings join the body}."""
import sys, json
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

src, out = sys.argv[1], sys.argv[2]
glass = len(sys.argv) > 3 and sys.argv[3] == "glass"
im = Image.open(src).convert("RGB")
im.thumbnail((1800, 1800))
a = np.asarray(im).astype(np.float32)
H, W, _ = a.shape
border = np.concatenate([a[0], a[-1], a[:, 0], a[:, -1]])
bg = np.median(border, axis=0)
dist = np.abs(a - bg).max(axis=2)
fg = dist > (14 if glass else 40)
m = Image.fromarray((fg * 255).astype(np.uint8)).copy()   # (a writable copy: floodfill on an image over numpy's memory does nothing)
# open: drops the antennae, legs, hairs and the scale bar's text; close: mends the wings' pale spots
m = m.filter(ImageFilter.MinFilter(7)).filter(ImageFilter.MaxFilter(7))
m = m.filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.MinFilter(9))
# keep the specimen: flood its body from the middle of the picture
ys, xs = np.nonzero(np.asarray(m) > 0)
cx = int(np.median(xs))
seed = None
for dy in range(0, H // 2, 4):
    for y in (H // 2 + dy, H // 2 - dy):
        if 0 <= y < H and np.asarray(m)[y, cx] > 0:
            seed = (cx, y)
            break
    if seed: break
ImageDraw.floodfill(m, seed, 128)
keep = np.asarray(m) == 128
# holes inside it (white spots, see-through cells) belong to it: fill what the border cannot reach
inv = Image.fromarray(np.where(keep, 0, 255).astype(np.uint8)).copy()
# (from every border pixel of the ground: a long tail touching the edge would cut the ground in two)
inv_a = np.asarray(inv)
for x in range(0, W, 8):
    for y in (0, H - 1):
        if inv.getpixel((x, y)) == 255: ImageDraw.floodfill(inv, (x, y), 64)
for y in range(0, H, 8):
    for x in (0, W - 1):
        if inv.getpixel((x, y)) == 255: ImageDraw.floodfill(inv, (x, y), 64)
keep = keep | (np.asarray(inv) == 255)
ys, xs = np.nonzero(keep)
top, bot = ys.min(), ys.max()
# the body: the narrowest run of the specimen round the middle column, measured on the rows below the wings
cx = int(round((xs.min() + xs.max()) / 2))
# the body's half width: on rows where the specimen round the middle is only body (above and below the wings)
span = xs.max() - xs.min()
halves = []
for y in range(top, bot + 1):
    row = keep[y]
    if not row[cx]: continue
    l = cx
    while l > 0 and row[l - 1]: l -= 1
    r = cx
    while r < W - 1 and row[r + 1]: r += 1
    if r - l < span * 0.16: halves.append(max(cx - l, r - cx))
half = int(np.percentile(halves, 90) * 1.1) if len(halves) > 5 else int(span * 0.022)
half = max(6, half)
x0 = cx + half
x1 = xs.max() + 2
crop_keep = keep[top:bot + 1, x0:x1]
rows = np.nonzero(crop_keep.any(axis=1))[0]
r0, r1 = rows.min(), rows.max()
crop_keep = crop_keep[r0:r1 + 1]
rgb = a[top + r0:top + r1 + 1, x0:x1]
d = dist[top + r0:top + r1 + 1, x0:x1]
alpha = crop_keep.astype(np.float32)
if glass:
    # see-through: the darker than the ground, the more solid; colour taken back out of the ground
    # (the membrane is only a little darker than the ground: clear; the veins and the eyespot well darker: solid)
    al = np.clip((d - 35.0) / 110.0, 0.05, 1.0) * alpha
    rgb = np.clip(bg + (rgb - bg) / np.maximum(al[..., None], 0.2), 0, 255)
    alpha = al
am = Image.fromarray((alpha * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.0))
# colour bleeds out past the edge, so mipmaps do not darken the rim with the background
rgb_im = Image.fromarray(rgb.astype(np.uint8))
spread = rgb_im
for k in range(6):
    grown = spread.filter(ImageFilter.MaxFilter(3)) if bg.mean() < 128 else spread.filter(ImageFilter.MinFilter(3))
    spread = Image.composite(spread, grown, Image.fromarray((crop_keep * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(3 + 2 * k)))
res = spread.convert("RGBA")
res.putalpha(am)
h, w = crop_keep.shape
s = 1024 / max(h, w)
res = res.resize((max(1, int(w * s)), max(1, int(h * s))), Image.LANCZOS)
res.save(out)
# where the wings join: the rows at the body edge that carry wing
col = crop_keep[:, : max(3, w // 40)].any(axis=1)
jr = np.nonzero(col)[0]
root = float((jr.min() + jr.max()) / 2 / h) if len(jr) else 0.4
json.dump({"aspect": w / h, "root": root}, open(out.replace(".png", ".json"), "w"))
print(out, res.size, "aspect %.2f root %.2f" % (w / h, root))
