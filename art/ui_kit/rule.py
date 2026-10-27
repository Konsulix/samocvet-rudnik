"""The brass rule under a window's title: a strip of the window frame's own brass rim (art/ui_kit/window_square.png),
laid end to end (every other piece mirrored, so no seams), its ends fading out.
Usage: py rule.py <window_square.png> <out.png> [width px]"""
import sys
from PIL import Image

src, out = sys.argv[1], sys.argv[2]
W = int(sys.argv[3]) if len(sys.argv) > 3 else 720
im = Image.open(src).convert("RGBA")
strip = im.crop((100, 5, 314, 25))           # the rim's dark outline, brass band and its inner shadow
res = Image.new("RGBA", (W, strip.height))
x = 0
k = 0
while x < W:
    res.paste(strip if k % 2 == 0 else strip.transpose(Image.FLIP_LEFT_RIGHT), (x, 0))
    x += strip.width
    k += 1
px = res.load()
fade = W * 0.22
for xx in range(W):
    f = min(1.0, min(xx, W - 1 - xx) / fade)
    f = f * f * (3 - 2 * f)
    for y in range(res.height):
        r, g, b, a = px[xx, y]
        px[xx, y] = (r, g, b, int(a * f))
res.save(out)
