"""Zoomed views of beast_prep's renders with a 0.05 grid (labels every 0.1), Godot coordinates.
usage: py beast_zoom.py <grid dir> <out.png> <id> [half-size=0.8]"""
import sys, os
from PIL import Image, ImageDraw
d, out, bid = sys.argv[1:4]
H = float(sys.argv[4]) if len(sys.argv) > 4 else 0.8
S = 640
def px(c): return (c + 1.6) / 3.2 * S
Z = 900
ims = []
for v in ["front", "side", "top"]:
    im = Image.open(os.path.join(d, bid + "_" + v + ".png")).convert("RGB")
    im = im.crop((px(-H), S - px(H), px(H), S - px(-H))).resize((Z, Z), Image.LANCZOS)
    dr = ImageDraw.Draw(im)
    def zp(c): return (c + H) / (2 * H) * Z
    n = int(H / 0.05)
    for i in range(-n, n + 1):
        c = i * 0.05; x = zp(c); y = Z - zp(c)
        col = (70, 70, 110) if i % 2 else (140, 140, 210)
        dr.line([(x, 0), (x, Z)], fill=col); dr.line([(0, y), (Z, y)], fill=col)
        if i % 2 == 0:
            hx = c if v != "side" else -c
            vy = c if v != "top" else -c
            dr.text((x + 2, Z - 12), f"{hx:+.1f}", fill=(255, 255, 100))
            dr.text((2, y + 1), f"{vy:+.1f}", fill=(255, 255, 100))
    dr.text((4, 4), bid + " " + v + ("  x→ y↑" if v == "front" else "  −z→ y↑" if v == "side" else "  x→ z↓"), fill=(255, 255, 255))
    ims.append(im)
sh = Image.new("RGB", (Z * 3, Z))
for i, im in enumerate(ims): sh.paste(im, (i * Z, 0))
sh.save(out)
