"""Edge padding for the sea models' baked textures, by the model's own unwrap.

The space between UV islands comes out of the bake black (colour) or empty (relief). With mipmaps on, a GPU blends
that black into the islands' edges: dark seams along every fin and arm, a body lit wrong along them (the relief's
empty texels are no direction at all), an eyelid — the texture's small copy — far too dark. Here every texel no
triangle of the model covers takes the colour of the nearest covered one, ring by ring, until nothing is empty.

Unlike prototype/tools/pad_tex.py it does not take every black texel for empty (a painted model has black of its own:
a shark's eye): what is empty is read off the .obj's UVs, and inside the islands only wide black patches count — what
the bake's rays missed.

    py prototype/tools/sea/pad_uv.py <godot/assets/specimen/sea> [name ...]
"""
import os
import sys
import glob
import numpy as np
from PIL import Image, ImageDraw


def mask_of(obj: str, size: int) -> np.ndarray:
    uv = []
    im = Image.new("L", (size, size), 0)
    dr = ImageDraw.Draw(im)
    with open(obj, encoding="utf-8", errors="ignore") as f:
        for line in f:
            if line.startswith("vt "):
                p = line.split()
                uv.append((float(p[1]), float(p[2])))
            elif line.startswith("f "):
                idx = [int(q.split("/")[1]) - 1 for q in line.split()[1:] if "/" in q and q.split("/")[1]]
                if len(idx) >= 3:
                    pts = [((uv[i][0] % 1.0) * size, (1.0 - uv[i][1] % 1.0) * size) for i in idx]
                    dr.polygon(pts, fill=255, outline=255)
    return np.asarray(im) > 0


def pad(path: str, obj: str) -> None:
    im = Image.open(path)
    a = np.asarray(im.convert("RGB")).astype(np.float32)
    full = mask_of(obj, a.shape[0])
    empty = ~full
    if path.endswith("_d.png"):
        # patches inside the islands the bake's rays never reached come out pure black too (an octopus's arms lie close:
        # the light mesh is off the scan there): a black patch wider than an eye — 11 texels — is empty as well
        black = a.max(-1) == 0
        seed = black.copy()
        for ax in (0, 1):
            acc = seed.copy()
            for d in range(-5, 6):
                acc &= np.roll(seed, d, ax)
            seed = acc
        blob = seed.copy()
        for ax in (0, 1):
            acc = blob.copy()
            for d in range(-7, 8):
                acc |= np.roll(blob, d, ax)
            blob = acc
        missed = blob & black & full
        if missed.any():
            print("  %d texels the bake missed" % int(missed.sum()), flush=True)
        empty |= missed
    n0 = int(empty.sum())
    for _ in range(4096):
        if not empty.any():
            break
        acc = np.zeros_like(a)
        cnt = np.zeros(empty.shape, np.float32)
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                if dx == 0 and dy == 0:
                    continue
                f = np.roll(np.roll(~empty, dy, 0), dx, 1)
                acc += np.roll(np.roll(a, dy, 0), dx, 1) * f[..., None]
                cnt += f
        grow = empty & (cnt > 0)
        a[grow] = acc[grow] / cnt[grow][:, None]
        empty &= ~grow
    Image.fromarray(np.clip(a + 0.5, 0, 255).astype(np.uint8), "RGB").save(path)
    print("%s: %d empty texels filled (%.0f%%)" % (os.path.basename(path), n0, 100.0 * n0 / full.size), flush=True)


if __name__ == "__main__":
    d = sys.argv[1]
    names = sys.argv[2:] or sorted(os.path.basename(p)[:-4] for p in glob.glob(os.path.join(d, "*.obj")))
    for n in names:
        for tag in ("_d", "_n"):
            p = os.path.join(d, n + tag + ".png")
            if os.path.exists(p):
                pad(p, os.path.join(d, n + ".obj"))
