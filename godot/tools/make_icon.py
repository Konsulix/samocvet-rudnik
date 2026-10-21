"""Draws the app icon (1024x1024): a faceted gem glowing on dark rock. Run: python tools/make_icon.py"""
import math, os
from PIL import Image, ImageDraw, ImageFilter

S = 1024
here = os.path.dirname(os.path.abspath(__file__))
img = Image.new('RGB', (S, S), (14, 20, 32))
d = ImageDraw.Draw(img)

# night-blue backdrop that warms toward the centre, like lamplight in a gallery
for r in range(S // 2 + 200, 0, -6):
    t = r / (S // 2 + 200)
    c = (int(14 + (60 - 14) * (1 - t) ** 2), int(20 + (44 - 20) * (1 - t) ** 2), int(32 + (30 - 32) * (1 - t) ** 2))
    d.ellipse([S / 2 - r, S / 2 - r - 40, S / 2 + r, S / 2 + r - 40], fill=c)

# glow behind the gem
glow = Image.new('RGBA', (S, S), (0, 0, 0, 0))
ImageDraw.Draw(glow).ellipse([250, 180, 774, 704], fill=(120, 200, 255, 150))
img.paste(glow.filter(ImageFilter.GaussianBlur(90)), (0, 0), glow.filter(ImageFilter.GaussianBlur(90)))
d = ImageDraw.Draw(img)

# a rocky ledge the gem sits on
ledge = [(120, 860), (260, 760), (420, 790), (560, 740), (720, 780), (900, 740), (1024, 820), (1024, 1024), (0, 1024), (0, 900)]
d.polygon(ledge, fill=(58, 48, 40))
d.line(ledge[:7], fill=(110, 96, 82), width=10, joint='curve')

# the gem: a brilliant-cut outline split into facets of different shades
cx, cy = S / 2, 470
table = [(cx - 150, cy - 170), (cx + 150, cy - 170)]
crown = [(cx - 300, cy - 30), (cx - 150, cy - 170), (cx + 150, cy - 170), (cx + 300, cy - 30)]
tip = (cx, cy + 330)
girdle_l, girdle_r = (cx - 300, cy - 30), (cx + 300, cy - 30)
facets = [
    ([girdle_l, table[0], (cx - 60, cy - 30)], (150, 225, 255)),
    ([table[0], table[1], (cx + 60, cy - 30), (cx - 60, cy - 30)], (205, 245, 255)),
    ([table[1], girdle_r, (cx + 60, cy - 30)], (110, 190, 245)),
    ([girdle_l, (cx - 60, cy - 30), tip], (70, 150, 230)),
    ([(cx - 60, cy - 30), (cx + 60, cy - 30), tip], (120, 200, 250)),
    ([(cx + 60, cy - 30), girdle_r, tip], (40, 110, 200)),
]
for poly, col in facets:
    d.polygon(poly, fill=col)
for poly, _ in facets:
    d.polygon(poly, outline=(235, 250, 255), width=6)
# a bright glint
d.polygon([(cx - 120, cy - 150), (cx - 40, cy - 150), (cx - 170, cy - 40), (cx - 230, cy - 40)], fill=(255, 255, 255))

img.save(os.path.join(here, '..', 'icon.png'))
print('icon.png written')
