"""Grid over beast_prep's renders (Godot coordinates, 0.1 steps, labels every 0.5) + a sheet of front/side/top per beast.
usage: py beast_grid.py <grid dir> <out.png> [ids,...]"""
import sys, glob, os
from PIL import Image, ImageDraw
d, out = sys.argv[1], sys.argv[2]
ids = sys.argv[3].split(",") if len(sys.argv) > 3 else sorted({os.path.basename(f).rsplit("_", 1)[0] for f in glob.glob(os.path.join(d, "*_front.png"))})
S = 640
def px(c): return (c + 1.6) / 3.2 * S
rows = []
for bid in ids:
    ims = []
    for v in ["front", "side", "top"]:
        f = os.path.join(d, bid + "_" + v + ".png")
        if not os.path.exists(f): continue
        im = Image.open(f).convert("RGB"); dr = ImageDraw.Draw(im)
        for i in range(-16, 17):
            c = i / 10; x = px(c); y = S - px(c)
            col = (90, 90, 140) if i % 5 else (170, 170, 230)
            dr.line([(x, 0), (x, S)], fill=col, width=1); dr.line([(0, y), (S, y)], fill=col, width=1)
        for i in range(-3, 4):
            c = i / 2
            # horizontal axis: front/top x, side -z ; vertical: front/side y, top z (down = +z)
            hx = c if v != "side" else -c
            dr.text((px(c) + 2, S - 12), f"{hx:+.1f}", fill=(255, 255, 120))
            vy = c if v != "top" else -c
            dr.text((2, S - px(c) + 2), f"{vy:+.1f}", fill=(255, 255, 120))
        dr.text((4, 4), bid + " " + v + ("  (x→, y↑)" if v == "front" else "  (−z→, y↑)" if v == "side" else "  (x→, z↓)"), fill=(255, 255, 255))
        ims.append(im)
    if ims: rows.append(ims)
W = S * 3
sh = Image.new("RGB", (W, S * len(rows)), (0, 0, 0))
for r, ims in enumerate(rows):
    for c, im in enumerate(ims): sh.paste(im, (c * S, r * S))
sh.save(out)
