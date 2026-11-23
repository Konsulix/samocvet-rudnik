# A card back drawn by GPT on magenta (gen.sh) -> the game's card back: magenta keyed out, cropped to the card.
#   py cut.py <back_N.png> <godot/assets/ui/card_back.png> [width]
import sys
from PIL import Image
import numpy as np

src, out = sys.argv[1], sys.argv[2]
W = int(sys.argv[3]) if len(sys.argv) > 3 else 720
a = np.asarray(Image.open(src).convert("RGB")).astype(np.float32)
r, g, b = a[..., 0], a[..., 1], a[..., 2]
# how magenta a pixel is: red and blue high, green low
mag = np.clip((np.minimum(r, b) - g - 60.0) / 80.0, 0.0, 1.0)
alpha = 1.0 - mag
ys, xs = np.where(alpha > 0.5)
y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
# the fringe: what magenta bled into the edge pixels taken back out
rgb = a.copy()
k = mag[..., None]
rgb = np.clip((rgb - k * np.array([255.0, 0.0, 255.0])) / np.maximum(1.0 - k, 0.05), 0, 255)
img = np.dstack([rgb, alpha * 255.0]).astype(np.uint8)[y0:y1, x0:x1]
im = Image.fromarray(img, "RGBA")
h = round(W * im.height / im.width)
im.resize((W, h), Image.LANCZOS).save(out)
print(out, W, h)
