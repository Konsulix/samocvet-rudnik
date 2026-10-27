# Cuts the UI kit sheets GPT drew on flat magenta into separate pieces for the game (godot/assets/ui/kit/).
#   python kit_cut.py frames <sheet.png> <out_dir>   pieces found as separate regions, named row by row (FRAMES)
#   python kit_cut.py icons  <sheet.png> <out_dir>   a 5x4 grid of icons, each cell trimmed to its picture (ICONS)
import sys, os
import numpy as np
from PIL import Image

FRAMES = ["window", "card", "tab", "tab_on", "btn_green", "btn_gold", "btn_dark", "title",
          "capsule", "sq_gold", "sq_dark", "ring", "portrait"]
ICONS = ["map", "mine", "collection", "equipment", "build", "play", "coin", "iron", "gold", "copper",
         "heart", "gear", "plus", "minus", "check", "lock", "close", "alert", "lantern", "pick"]

MODE, SRC, OUT = sys.argv[1], sys.argv[2], sys.argv[3]
os.makedirs(OUT, exist_ok=True)
im = np.asarray(Image.open(SRC).convert("RGB")).astype(np.float32) / 255.0
r, g, b = im[..., 0], im[..., 1], im[..., 2]
mag = np.clip((np.minimum(r, b) - g - 0.25) / 0.45, 0.0, 1.0)
alpha = 1.0 - mag
M = np.array([1.0, 0.0, 1.0])
a3 = np.maximum(alpha[..., None], 1e-3)
fg = np.clip((im - (1.0 - a3) * M) / a3, 0.0, 1.0)
rgba = np.dstack([fg, alpha])

def save(name, y0, y1, x0, x1, keep=None):
    sub = rgba[y0:y1, x0:x1].copy()
    if keep is not None: sub[..., 3] *= keep[y0:y1, x0:x1]
    a = sub[..., 3] > 0.04
    ys, xs = np.nonzero(a)
    sub = sub[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    sub = np.pad(sub, ((2, 2), (2, 2), (0, 0)))
    Image.fromarray((sub * 255).astype(np.uint8), "RGBA").save(os.path.join(OUT, name + ".png"))
    print(name, sub.shape[1], sub.shape[0])

def regions(m, grow, min_px):
    """connected regions of the mask grown by `grow` px (loose bits stay with their piece): label image, boxes"""
    grown = m.copy()
    for _ in range(grow):
        g2 = grown.copy()
        g2[1:] |= grown[:-1]; g2[:-1] |= grown[1:]; g2[:, 1:] |= grown[:, :-1]; g2[:, :-1] |= grown[:, 1:]
        grown = g2
    lab = np.zeros(m.shape, np.int32); n = 0; boxes = []
    H, W = m.shape
    for y0, x0 in zip(*np.nonzero(grown)):
        if lab[y0, x0]: continue
        n += 1; st = [(y0, x0)]; lab[y0, x0] = n; ys = []; xs = []
        while st:
            y, x = st.pop(); ys.append(y); xs.append(x)
            for yy, xx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
                if 0 <= yy < H and 0 <= xx < W and grown[yy, xx] and not lab[yy, xx]:
                    lab[yy, xx] = n; st.append((yy, xx))
        if len(ys) > min_px:
            boxes.append((n, min(ys), max(ys) + 1, min(xs), max(xs) + 1))
    return lab, boxes

if MODE == "icons":
    # each region goes to the grid cell its middle falls in; an icon is all the regions of its cell
    h, w = alpha.shape
    lab, boxes = regions(alpha > 0.5, 3, 300)
    for i, name in enumerate(ICONS):
        cx, cy = i % 5, i // 5
        mine = [bx for bx in boxes if int((bx[3] + bx[4]) / 2 * 5 / w) == cx and int((bx[1] + bx[2]) / 2 * 4 / h) == cy]
        keep = np.isin(lab, [bx[0] for bx in mine]).astype(np.float32)
        save(name, min(b[1] for b in mine), max(b[2] for b in mine), min(b[3] for b in mine), max(b[4] for b in mine), keep)
else:
    lab, boxes = regions(alpha > 0.5, 6, 2000)
    # rows: pieces whose vertical middles are close
    boxes.sort(key=lambda b: (b[1] + b[2]) / 2)
    rows = []
    for bx in boxes:
        cy = (bx[1] + bx[2]) / 2
        if rows and abs(cy - rows[-1][0]) < 120: rows[-1][1].append(bx)
        else: rows.append([cy, [bx]])
    order = [bx for _, rb in rows for bx in sorted(rb, key=lambda b: b[3])]
    for name, (k, y0, y1, x0, x1) in zip(FRAMES, order):
        save(name, y0, y1, x0, x1, (lab == k).astype(np.float32))
    print(len(order), "pieces")
