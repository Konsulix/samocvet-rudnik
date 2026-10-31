"""A seamless slate tile for the kit's windows and dark buttons, without streaks.
The old tile (slate_fill.py) blended a half-shifted copy of itself towards its edges: that copy's own seam ran through
the middle of the tile and showed as a stripe every tile. Here the biggest square of slate inside the window is made
periodic by the periodic-plus-smooth split (Moisan 2011): only the smooth part that jumps at the edges is taken off,
the grain stays as it was. Usage: py slate_tile.py <window.png> <out slate.png> [size]"""
import sys
import numpy as np
from PIL import Image

src, out = sys.argv[1], sys.argv[2]
T = int(sys.argv[3]) if len(sys.argv) > 3 else 290
im = np.asarray(Image.open(src).convert("RGB")).astype(np.float64)
H, W, _ = im.shape
y0, x0 = H // 2 - T // 2, W // 2 - T // 2
u = im[y0:y0 + T, x0:x0 + T]


def periodic(u):
    """u minus its smooth component: the part that makes opposite edges disagree"""
    M, N = u.shape
    v = np.zeros_like(u)
    v[0, :] += u[-1, :] - u[0, :]
    v[-1, :] += u[0, :] - u[-1, :]
    v[:, 0] += u[:, -1] - u[:, 0]
    v[:, -1] += u[:, 0] - u[:, -1]
    q = np.arange(M).reshape(M, 1)
    r = np.arange(N).reshape(1, N)
    den = 2 * np.cos(2 * np.pi * q / M) + 2 * np.cos(2 * np.pi * r / N) - 4
    den[0, 0] = 1
    s = np.fft.fft2(v) / den
    s[0, 0] = 0
    return u - np.real(np.fft.ifft2(s))


p = np.dstack([periodic(u[..., c]) for c in range(3)])
# the window's own light and shade (darker towards its rim) would come back as blotches every tile: the broad
# shading is taken off (a wide blur of the tile, wrapped round), the grain and cracks stay
from PIL import ImageFilter
big = np.tile(p, (3, 3, 1))
blur = np.asarray(Image.fromarray(np.clip(big, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(T / 6))).astype(np.float64)
blur = blur[T:2 * T, T:2 * T]
p = p - blur + blur.mean(axis=(0, 1))
# the same colour as the tile it replaces, where there is one
try:
    old = np.asarray(Image.open(out).convert("RGB")).astype(np.float64)
    p = (p - p.mean(axis=(0, 1))) / p.std(axis=(0, 1)) * old.std(axis=(0, 1)) + old.mean(axis=(0, 1))
except FileNotFoundError:
    pass
Image.fromarray(np.clip(p + 0.5, 0, 255).astype(np.uint8)).convert("RGBA").save(out)
print(out, T)
