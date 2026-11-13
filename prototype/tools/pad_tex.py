"""Edge padding for baked scan textures: the empty space between UV islands is pure black, and a GPU filtering
or mipmapping near an island's edge pulled that black into the colour (dark blotches in the roses' hearts, black
hairlines across petals). Each island's colour is grown out into the black around it, ring by ring, until
nothing is left empty.

    py prototype/tools/pad_tex.py [dark=N] <file_d.png> [more files...]

dark=N: dark specks count as empty too — texels whose brightest channel is under N (0..255) and under 45% of the mean
round them (7x7): the near-black specks a bake leaves inside the islands (a rose's heart was spotted with them even
unlit). Evenly dark places (dark leaves, deep blue gentians) are not specks and stay.

Only pure black (0, 0, 0) counts as empty — a baked scan has no truly black texel of its own (check a texture
with real black patterns, butterflies' wings, before running this on it).
"""
import sys
import numpy as np
from PIL import Image


def pad(path: str, rings: int = 256, dark: int = 0) -> None:
    im = Image.open(path)
    mode = im.mode
    a = np.asarray(im.convert("RGBA")).astype(np.float32)
    rgb = a[..., :3]
    mx = rgb.max(-1)
    empty = mx == 0
    if dark > 0:
        around = np.zeros_like(mx)
        for dy in range(-3, 4):
            for dx in range(-3, 4):
                around += np.roll(np.roll(mx, dy, 0), dx, 1)
        around /= 49.0
        empty |= (mx < dark) & (mx < around * 0.45)
    n0 = int(empty.sum())
    for _ in range(rings):
        if not empty.any():
            break
        full = ~empty
        acc = np.zeros_like(rgb)
        cnt = np.zeros(empty.shape, np.float32)
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                if dx == 0 and dy == 0:
                    continue
                f = np.roll(np.roll(full, dy, 0), dx, 1)
                c = np.roll(np.roll(rgb, dy, 0), dx, 1)
                acc += c * f[..., None]
                cnt += f
        grow = empty & (cnt > 0)
        rgb[grow] = acc[grow] / cnt[grow][:, None]
        # (a grown texel is never pure black again, or the next ring would take it for empty)
        rgb[grow] = np.maximum(rgb[grow], 1.0)
        empty &= ~grow
    if empty.any():
        rgb[empty] = rgb[~empty].mean(0)
    a[..., :3] = rgb
    out = Image.fromarray(np.clip(a + 0.5, 0, 255).astype(np.uint8), "RGBA")
    out.convert(mode if mode in ("RGB", "RGBA") else "RGB").save(path)
    print(f"{path}: {n0} empty texels filled")


if __name__ == "__main__":
    dk = 0
    for p in sys.argv[1:]:
        if p.startswith("dark="):
            dk = int(p[5:])
            continue
        pad(p, dark=dk)
