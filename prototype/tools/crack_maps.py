# Crack masks for the board kit (blender/board_kit.py): the narrow hollows of a scan's height map, white where
# a crack runs. A high-pass of the height (local average minus height), scaled so a few percent of the stone is crack.
#   python crack_maps.py <scan_disp.jpg> [...]   writes <scan>_crack_1k.png next to each
import sys
import numpy as np
from PIL import Image, ImageFilter

for path in sys.argv[1:]:
    im = Image.open(path).convert("L")
    d = np.asarray(im, dtype=np.float32) / 255.0
    # wrap-around blur, so the mask tiles like the scan
    big = Image.fromarray((np.tile(d, (3, 3)) * 255).astype(np.uint8))
    blur = np.asarray(big.filter(ImageFilter.GaussianBlur(5)), dtype=np.float32)[d.shape[0]:2 * d.shape[0], d.shape[1]:2 * d.shape[1]] / 255.0
    hp = blur - d
    lo, hi = np.percentile(hp, 93), np.percentile(hp, 99.3)
    m = np.clip((hp - lo) / (hi - lo), 0, 1)
    out = path.replace("_disp_1k.jpg", "_crack_1k.png")
    Image.fromarray((m * 255).astype(np.uint8)).save(out)
    print(out, round(float(m.mean()), 3))
