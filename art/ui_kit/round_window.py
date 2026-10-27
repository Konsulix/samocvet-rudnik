"""Rounds the kit window's corners: art/ui_kit/window_square.png -> godot/assets/ui/kit/window.png.
Inside radius R the brass rim follows an arc (its profile taken from the straight top edge), the drawn corner
plates stay, trimmed to the arc. Usage: py round_window.py <src> <dst> [R]"""
import sys, math
from PIL import Image

src, dst = sys.argv[1], sys.argv[2]
R = int(sys.argv[3]) if len(sys.argv) > 3 else 72
im = Image.open(src).convert("RGBA")
W, H = im.size

def PLATE(x, y):
    """the drawn corner plate: an L with a diagonal inner edge and a tab down each side"""
    return x + y < 88 or (x < 26 and y < 84) or (y < 26 and x < 84)

def corner(img):
    """rounds the top-left corner of img in place"""
    px = img.load()
    w, h = img.size
    prof = [px[w // 2, t] for t in range(48)]
    out = img.copy()
    o = out.load()
    for y in range(max(R, 84)):
        for x in range(max(R, 84)):
            if x >= R or y >= R:
                continue
            d = math.hypot(R - 0.5 - x, R - 0.5 - y)
            t = R - d       # depth in from the rounded outline
            if t < 0:
                o[x, y] = (0, 0, 0, 0)
            elif t < 40:
                a, b = prof[int(t)], prof[min(47, int(t) + 1)]
                f = t - int(t)
                c = tuple(int(a[i] * (1 - f) + b[i] * f) for i in range(4))
                if t < 1: c = c[:3] + (int(c[3] * t),)
                o[x, y] = c
            else:
                o[x, y] = px[x + 130, y]
            if PLATE(x, y) and t >= 5:
                o[x, y] = px[x, y]   # the brass corner plate stays as drawn, trimmed by the arc's dark outline     # same height from the edge: the slate's shading carries on
    # the plate's big rivet sat right in the corner, where the arc now cuts: moved in along the diagonal
    # (its old place is covered with plain plate brass from between the rivets first)
    for y in range(-13, 14):
        for x in range(-13, 14):
            if x * x + y * y <= 170 and o[25 + x, 25 + y][3] == 255 and PLATE(25 + x, 25 + y):
                o[25 + x, 25 + y] = px[42 + x // 2, 36 + y // 2]
    for y in range(-11, 12):
        for x in range(-11, 12):
            if x * x + y * y <= 110:
                o[31 + x, 36 + y] = px[25 + x, 25 + y]
    return out

for flip in range(4):
    img = im
    if flip & 1: img = img.transpose(Image.FLIP_LEFT_RIGHT)
    if flip & 2: img = img.transpose(Image.FLIP_TOP_BOTTOM)
    img = corner(img)
    if flip & 2: img = img.transpose(Image.FLIP_TOP_BOTTOM)
    if flip & 1: img = img.transpose(Image.FLIP_LEFT_RIGHT)
    im = img
im.save(dst)
