"""Small square icons of the big blocks (find, geode) for the interface: goals, the level window, Look.

The board's block sprites (zone_kit.py, 287 px and up, not a power of two, with mipmaps) came out as plain white
squares when drawn small in the interface on iPhone, though the board drew them fine. The icons are drawn from
these instead: 128x128, the block centred on a transparent square, no mipmaps (the import default).

    py prototype/tools/zone_icons.py            -> godot/assets/board/zones/<look>/icon/<kind>_<w>x<h>.png
"""
import glob
import os

from PIL import Image

ROOT = os.path.join(os.path.dirname(__file__), "..", "..", "godot", "assets", "board", "zones")
PX = 128

for look in ("hewn", "pillow"):
    out = os.path.join(ROOT, look, "icon")
    os.makedirs(out, exist_ok=True)
    for f in sorted(glob.glob(os.path.join(ROOT, look, "find_*_0.png")) + [os.path.join(ROOT, look, "geode_2x2_0.png")]):
        im = Image.open(f).convert("RGBA")
        im = im.crop(im.getbbox())
        k = PX / max(im.size)
        im = im.resize((max(1, round(im.width * k)), max(1, round(im.height * k))), Image.LANCZOS)
        sq = Image.new("RGBA", (PX, PX), (0, 0, 0, 0))
        sq.paste(im, ((PX - im.width) // 2, (PX - im.height) // 2), im)
        name = os.path.basename(f)[: -len("_0.png")] + ".png"
        sq.save(os.path.join(out, name))
        print(look, name)
