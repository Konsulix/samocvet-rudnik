"""Cut the kelp sheet (gen.sh: four tangles on magenta) into godot/assets/board/kelp/kelp_0..3.png, 256 px each.
python cut.py <sheet png> <out dir>"""
import sys, os
import numpy as np
from PIL import Image
src, dst = sys.argv[1], sys.argv[2]
os.makedirs(dst, exist_ok=True)
im = np.asarray(Image.open(src).convert('RGB')).astype(np.float32)
r, g, b = im[..., 0], im[..., 1], im[..., 2]
# magenta: red and blue high, green low
mag = np.clip((np.minimum(r, b) - g) / 110.0, 0, 1)
alpha = 1.0 - np.clip((mag - 0.25) / 0.5, 0, 1)
# pull the magenta fringe out of the colour
spill = np.clip(np.minimum(r, b) - g, 0, 255) * (alpha < 1.0)
out = np.dstack([np.clip(r - spill * 0.9, 0, 255), g, np.clip(b - spill * 0.9, 0, 255), alpha * 255]).astype(np.uint8)
cols = np.where((alpha > 0.5).sum(axis=0) > 3)[0]
runs, start = [], cols[0]
for a, bb in zip(cols[:-1], cols[1:]):
    if bb - a > 20:
        runs.append((start, a + 1)); start = bb
runs.append((start, cols[-1] + 1))
for i, (x0, x1) in enumerate(runs[:4]):
    part = out[:, x0:x1]
    rows = np.where((part[..., 3] > 127).sum(axis=1) > 3)[0]
    part = Image.fromarray(part[rows[0]:rows[-1] + 1])
    side = max(part.size)
    sq = Image.new('RGBA', (side, side), (0, 0, 0, 0))
    sq.paste(part, ((side - part.width) // 2, (side - part.height) // 2))
    sq.resize((256, 256), Image.LANCZOS).save('%s/kelp_%d.png' % (dst, i))
print('ok', len(runs))
