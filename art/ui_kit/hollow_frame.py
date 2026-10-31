"""A kit plate as a hollow frame over a tiled slate (like the window, slate_fill.py): the plate's own slate middle,
repeated to fit, showed its joins as stripes on the dark buttons. Keeps the rim and its dark lip - everything within
RIM px of the plate's outline - fading out over a few px further in; a dark tile with the plate's own slate colour is
made from the window's tile. Usage: py hollow_frame.py <plate.png> <slate tile.png> <out dir> [rim px]
    -> <plate>_frame.png, <plate>_slate.png"""
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

src, tile, out = sys.argv[1], sys.argv[2], sys.argv[3]
RIM = int(sys.argv[4]) if len(sys.argv) > 4 else 24
name = os.path.splitext(os.path.basename(src))[0]
im = Image.open(src).convert("RGBA")
a = im.getchannel("A")
solid = a.point(lambda v: 255 if v > 128 else 0)
# the inside: what stays solid after eating RIM px off the outline, softened at its edge
inner = solid.filter(ImageFilter.MinFilter(2 * RIM + 1)).filter(ImageFilter.GaussianBlur(2))
px = np.asarray(im).astype(np.float64)
keep = 1.0 - np.asarray(inner).astype(np.float64) / 255
fr = px.copy()
fr[..., 3] = px[..., 3] * keep
Image.fromarray(np.clip(fr + 0.5, 0, 255).astype(np.uint8), "RGBA").save(os.path.join(out, name + "_frame.png"))

# the tile in the plate's own slate colour (mean and spread of the middle it replaces)
mid = np.asarray(inner).astype(np.float64) > 250
own = px[..., :3][mid]
t = np.asarray(Image.open(tile).convert("RGB")).astype(np.float64)
t = (t - t.mean(axis=(0, 1))) / t.std(axis=(0, 1)) * own.std(axis=0) + own.mean(axis=0)
Image.fromarray(np.clip(t + 0.5, 0, 255).astype(np.uint8)).convert("RGBA").save(os.path.join(out, name + "_slate.png"))
print(name, "inside", int(mid.sum()), "px, colour", own.mean(axis=0).round(1))
