# The bits stuck on a card's back (gen3.sh parts: six tapes, a glass vial, a brass plate on magenta) -> separate pngs.
#   py cut_parts.py <secret_parts.png> <godot/assets/ui/card_back/>
import sys, os
from PIL import Image
import numpy as np

src, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
a = np.asarray(Image.open(src).convert("RGB")).astype(np.float32)
r, g, b = a[..., 0], a[..., 1], a[..., 2]
mag = np.clip((np.minimum(r, b) - g - 60.0) / 80.0, 0.0, 1.0)
alpha = 1.0 - mag
k = mag[..., None]
rgb = np.clip((a - k * np.array([255.0, 0.0, 255.0])) / np.maximum(1.0 - k, 0.05), 0, 255)
img = np.dstack([rgb, alpha * 255.0]).astype(np.uint8)
# the pieces: bands of rows with anything in them, then runs of columns in each band
def runs(v, gap):
    out, start, last = [], None, -999
    for i, on in enumerate(v):
        if on:
            if start is None or i - last > gap:
                if start is not None: out.append((start, last + 1))
                start = i
            last = i
    if start is not None: out.append((start, last + 1))
    return out
items = []
for y0, y1 in runs((alpha > 0.5).sum(1) > 3, 12):
    for x0, x1 in runs((alpha[y0:y1] > 0.5).sum(0) > 0, 12):
        if (x1 - x0) * (y1 - y0) < 2000: continue
        items.append((y0, x0, (slice(y0 - 6, y1 + 6), slice(x0 - 6, x1 + 6))))
names = ["tape_0", "tape_1", "tape_2", "tape_3", "tape_4", "tape_5", "vial", "plate"]
for name, it in zip(names, items):
    sl = it[2]
    y0, y1, x0, x1 = sl[0].start + 6, sl[0].stop - 6, sl[1].start + 6, sl[1].stop - 6
    piece = Image.fromarray(img[y0:y1, x0:x1], "RGBA")
    piece.save(os.path.join(out, name + ".png"))
    print(name, piece.size)
