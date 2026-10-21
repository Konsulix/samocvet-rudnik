"""Key the magenta background out of the generated sprites and export game-ready WebP files."""
import os
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.abspath(__file__))
RAW, OUT = os.path.join(ROOT, 'assets', 'raw'), os.path.join(ROOT, 'img')

def key_magenta(name, size=512):
    im = np.asarray(Image.open(os.path.join(RAW, name + '.png')).convert('RGB')).astype(np.float32)
    r, g, b = im[..., 0], im[..., 1], im[..., 2]
    mag = np.minimum(r, b) - g                       # how magenta a pixel is
    alpha = 1 - np.clip((mag - 40) / 90, 0, 1)
    # pull the pink fringe off semi-transparent edges
    spill = np.clip(np.minimum(r, b) - g, 0, None) * (1 - alpha) * 1.0 + np.clip(np.minimum(r, b) - g - 25, 0, None) * alpha * .5
    r2, b2 = r - spill, b - spill
    out = np.dstack([np.clip(r2, 0, 255), g, np.clip(b2, 0, 255), alpha * 255]).astype(np.uint8)
    img = Image.fromarray(out, 'RGBA')
    bbox = img.getchannel('A').point(lambda v: 255 if v > 30 else 0).getbbox()
    img = img.crop(bbox)
    w, h = img.size; s = max(w, h); pad = int(s * .04); S = s + pad * 2
    canvas = Image.new('RGBA', (S, S), (0, 0, 0, 0)); canvas.paste(img, ((S - w) // 2, (S - h) // 2))
    canvas.resize((size, size), Image.LANCZOS).save(os.path.join(OUT, name + '.webp'), 'WEBP', quality=88, method=6)

def texture(name, size=512):
    Image.open(os.path.join(RAW, name + '.png')).convert('RGB').resize((size, size), Image.LANCZOS).save(os.path.join(OUT, name + '.webp'), 'WEBP', quality=84, method=6)

if __name__ == '__main__':
    for n in ['miner_top', 'crawler_top', 'golem_top', 'moss_top']:
        if os.path.exists(os.path.join(RAW, n + '.png')): key_magenta(n)
    for n in ['floor_tex', 'rock_tex']:
        if os.path.exists(os.path.join(RAW, n + '.png')): texture(n)
    for f in sorted(os.listdir(OUT)):
        if any(k in f for k in ('_top', '_tex')): print(f, os.path.getsize(os.path.join(OUT, f)) // 1024, 'KB')
