# Bakes a seamless "worked gold" texture set: hammered dents, fine scratches and polishing marks,
# rose-to-yellow colour shifts and dark tarnish in the crevices. Writes albedo, normal (GL) and roughness.
# Usage: python make_gold.py <out_dir> [silver]
# With "silver": the same worked metal in native silver, cold grey drifting warm, black tarnish in the crevices.
import sys, numpy as np
from PIL import Image
out = sys.argv[1]
metal = sys.argv[2] if len(sys.argv) > 2 else "gold"
N = 512
rng = np.random.default_rng(11 if metal == "gold" else 23)
y, x = np.mgrid[0:N, 0:N].astype(np.float32) / N

def wrapdist(px, py):
    dx = np.abs(x - px); dx = np.minimum(dx, 1 - dx)
    dy = np.abs(y - py); dy = np.minimum(dy, 1 - dy)
    return np.sqrt(dx * dx + dy * dy)

def blur(a, r):
    # wrap-around box blur, a few passes ~ gaussian
    for _ in range(3):
        a = sum(np.roll(a, s, 0) for s in range(-r, r + 1)) / (2 * r + 1)
        a = sum(np.roll(a, s, 1) for s in range(-r, r + 1)) / (2 * r + 1)
    return a

# hammer dents: overlapping shallow round cups
h = np.zeros((N, N), np.float32)
for k in range(260):
    px, py = rng.random(2)
    r = 0.025 + rng.random() * 0.05
    d = wrapdist(px, py)
    cup = np.clip(1 - (d / r) ** 2, 0, None)
    h -= cup * (0.6 + rng.random() * 0.6) * r * 10
# soft lumps
lump = blur(rng.standard_normal((N, N)).astype(np.float32), 18)
h += lump / np.abs(lump).max() * 0.8
# fine grain
grain = blur(rng.standard_normal((N, N)).astype(np.float32), 1)
h += grain / np.abs(grain).max() * 0.06
# scratches: thin straight grooves, mostly one direction (polishing)
scr = np.zeros((N, N), np.float32)
for k in range(140):
    ang = rng.normal(0.4, 0.35) if rng.random() < 0.75 else rng.random() * np.pi
    cx, cy = rng.random(2)
    L = 0.05 + rng.random() * 0.35
    nx, ny = -np.sin(ang), np.cos(ang)
    dx = (x - cx + 0.5) % 1 - 0.5; dy = (y - cy + 0.5) % 1 - 0.5
    along = dx * np.cos(ang) + dy * np.sin(ang)
    across = dx * nx + dy * ny
    m = (np.abs(along) < L / 2) & (np.abs(across) < 0.0015 + rng.random() * 0.0015)
    scr[m] = np.maximum(scr[m], 0.3 + rng.random() * 0.7)
scr = blur(scr, 1)
h -= scr * 0.35
h = (h - h.min()) / (h.max() - h.min())

# normal from height (wrapped central differences)
s = 6.0
gx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * s
gy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * s
n = np.stack([-gx, gy, np.ones_like(h)], -1)
n /= np.linalg.norm(n, axis=-1, keepdims=True)
Image.fromarray(((n * 0.5 + 0.5) * 255).astype(np.uint8)).save(f"{out}/{metal}_nrm.png")

# crevices: below the local average
cav = np.clip((blur(h, 6) - h) * 6, 0, 1)
# roughness: polished tops, duller in the dents, scratches catch light differently
rough = 0.18 + cav * 0.45 + scr * 0.15 + (blur(rng.random((N, N)).astype(np.float32), 12) - 0.5) * 0.12
Image.fromarray((np.clip(rough, 0, 1) * 255).astype(np.uint8)).save(f"{out}/{metal}_rough.png")

# albedo: rich yellow gold drifting to rose gold, tarnish in the crevices (sRGB)
t = blur(rng.random((N, N)).astype(np.float32), 30); t = (t - t.min()) / (t.max() - t.min())
if metal == "gold":
	yellow = np.array([1.0, 0.78, 0.34]); rose = np.array([0.98, 0.66, 0.42]); tarnish = np.array([0.35, 0.22, 0.08])
else:
	yellow = np.array([0.93, 0.94, 0.96]); rose = np.array([0.90, 0.86, 0.80]); tarnish = np.array([0.10, 0.09, 0.09])
col = yellow[None, None] * (1 - t[..., None] * 0.6) + rose[None, None] * (t[..., None] * 0.6)
col = col * (1 - cav[..., None] * 0.75) + tarnish[None, None] * (cav[..., None] * 0.75)
Image.fromarray((np.clip(col, 0, 1) * 255).astype(np.uint8)).save(f"{out}/{metal}_diff.png")
print("ok")
