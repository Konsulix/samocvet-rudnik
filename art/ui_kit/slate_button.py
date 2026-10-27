"""The slate twin of the green button: the same brass rim and end rivets, the green enamel face swapped for the
window's dark slate (its light and shade kept). Usage: py slate_button.py <btn_green.png> <window_square.png> <out.png>"""
import sys
from PIL import Image

g = Image.open(sys.argv[1]).convert("RGBA")
w = Image.open(sys.argv[2]).convert("RGBA")
slate = w.crop((90, 90, 324, 299)).resize(g.size, Image.LANCZOS)
px, sp = g.load(), slate.load()
face = []
for y in range(g.height):
    for x in range(g.width):
        r, gg, b, a = px[x, y]
        if a > 0 and gg > r + 12 and gg > b + 8:
            face.append((x, y, (r + gg + b) / 3))
mean = sum(f[2] for f in face) / len(face)
for x, y, l in face:
    s = sp[x, y]
    k = (l / mean) ** 1.1
    px[x, y] = (min(255, int(s[0] * k * 1.05)), min(255, int(s[1] * k * 1.05)), min(255, int(s[2] * k * 1.1)), px[x, y][3])
g.save(sys.argv[3])
