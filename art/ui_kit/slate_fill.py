"""The kit window as a hollow frame over a tiled slate, so a tall card does not stretch the slate into streaks.
From the rounded window (godot/assets/ui/kit/window.png): window_frame.png keeps the rim, its inner shadow and the
corner plates, fading out to nothing past FADE px in; slate.png is a seamless tile cut from the slate in the middle
(blended with a half-shifted copy of itself towards the tile's edges). Usage: py slate_fill.py <window.png> <out dir>"""
import sys, os
from PIL import Image

src, out = sys.argv[1], sys.argv[2]
im = Image.open(src).convert("RGBA")
W, H = im.size
px = im.load()
FADE = (34, 46)          # the rim's inner shadow fades over this depth (px from the outer edge)

def plate(x, y):
    """the corner plate, in the corner's own coordinates (as in round_window.py)"""
    return x + y < 88 or (x < 26 and y < 84) or (y < 26 and x < 84)

fr = im.copy()
fp = fr.load()
for y in range(H):
    for x in range(W):
        cx, cy = min(x, W - 1 - x), min(y, H - 1 - y)
        if cx < 90 and cy < 90 and plate(cx, cy):
            continue
        d = min(cx, cy)
        if d >= FADE[1]:
            fp[x, y] = (0, 0, 0, 0)
        elif d > FADE[0]:
            r, g, b, a = fp[x, y]
            fp[x, y] = (r, g, b, int(a * (FADE[1] - d) / (FADE[1] - FADE[0])))
fr.save(os.path.join(out, "window_frame.png"))

T = 200
c = im.crop((W // 2 - T // 2, H // 2 - T // 2, W // 2 + T // 2, H // 2 + T // 2))
sh = Image.new("RGBA", (T, T))
for qx in (0, 1):
    for qy in (0, 1):
        sh.paste(c.crop((qx * T // 2, qy * T // 2, qx * T // 2 + T // 2, qy * T // 2 + T // 2)), ((1 - qx) * T // 2, (1 - qy) * T // 2))
cp, sp = c.load(), sh.load()
tile = Image.new("RGBA", (T, T))
tp = tile.load()
for y in range(T):
    for x in range(T):
        # the original in the middle, the shifted copy (seamless at the edges) towards the edges
        e = max(abs(x - T / 2 + 0.5), abs(y - T / 2 + 0.5)) / (T / 2)
        k = min(1.0, max(0.0, (e - 0.55) / 0.4))
        a, b = cp[x, y], sp[x, y]
        tp[x, y] = tuple(int(a[i] * (1 - k) + b[i] * k) for i in range(3)) + (255,)
# even out the light: the slate's broad brightening towards the window's middle would show as a grid of patches
from PIL import ImageFilter
wrap = Image.new("RGBA", (T * 3, T * 3))
for i in range(3):
    for j in range(3):
        wrap.paste(tile, (i * T, j * T))
low = wrap.filter(ImageFilter.GaussianBlur(28)).crop((T, T, 2 * T, 2 * T)).load()
mean = [sum(tp[x, y][i] for x in range(T) for y in range(T)) / (T * T) for i in range(3)]
for y in range(T):
    for x in range(T):
        tp[x, y] = tuple(max(0, min(255, int(tp[x, y][i] - low[x, y][i] + mean[i]))) for i in range(3)) + (255,)
tile.save(os.path.join(out, "slate.png"))
