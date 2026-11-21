# Everything the Copper Mountain mine screen needs, from art/zone/mine2 into godot/assets/mine/copper_mountain/
# (the same conventions as export_mine.py for Old Adit: coordinates in mine.json in SOURCE px of the 1536-wide stack,
# pictures saved scaled by K so that 390 pt at 3x is drawn 1:1).
# Layout: the sky extension, the surface (the 1024x1536 pictures scaled x1.5), then the depth bands (rows 190..760 of each
# 1536x1024 band picture). The inclined shaft zigzags down the solid rock at the left of the bands (x < 470).
# python export_mine2.py <godot project dir>
import sys, os, json, math, re
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageChops
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from anim_hall_lib import key, by_shape, label
import layers_mine2 as L

HERE = os.path.dirname(os.path.abspath(__file__))
M = os.path.join(HERE, "mine2")
OUT = os.path.join(sys.argv[1], "assets", "mine", "copper_mountain")
K = 1170 / 1536
W = 1536
S = 1.5                        # the surface pictures (1024 wide) -> source px
SKY = 574                      # rows of the sky added above the surface
SURF = 2060                    # rows of the scaled surface kept (down into its cut of soil)
BAND = (190, 760)
ZONE = 470                     # the bands' solid rock at the left, where the shaft runs
info = {"K": K, "W": W, "sky": SKY, "surf": SURF, "band": BAND[1] - BAND[0], "zone": ZONE}
os.makedirs(OUT, exist_ok=True)

def _open(n): return Image.open(os.path.join(M, n + ".png")).convert("RGBA")
REACH_BASE = {"d4": "done", "d8": "done", "d9": "done"}   # as in gen_mine2.py
def img(n):
    # a depth whose gallery was extended to the shaft (gen_mine2.py REACH): the edited picture stands for the state it was
    # edited from (and the closed one for the closed state); the other task stages get its passage - everything left of
    # the gallery's left end - pasted in with a soft seam
    m_ = re.fullmatch(r"(d\d)_(clear|closed|step1|step2|done)", n)
    if not m_ or not os.path.exists(os.path.join(M, m_[1] + "_reach.png")): return _open(n)
    d, st = m_[1], m_[2]
    if st == "closed": return _open(d + "_reach_closed") if os.path.exists(os.path.join(M, d + "_reach_closed.png")) else _open(n)
    if st == REACH_BASE.get(d, "clear"): return _open(d + "_reach")
    left = json.load(open(os.path.join(M, "depths.json")))[d[1]]["left"]
    pm = Image.new("L", (1536, 1024), 0); ImageDraw.Draw(pm).rectangle((0, 0, left - 10, 1024), fill=255)
    return Image.composite(_open(d + "_reach"), _open(n), pm.filter(ImageFilter.GaussianBlur(5)))
def big(n): return img(n).resize((W, round(1536 * S)), Image.LANCZOS)
def cyc(n): return key(Image.open(os.path.join(M, "cyc_" + n + ".png")))
def save(im, rel, scale=True):
    p = os.path.join(OUT, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    if scale:
        im = im.resize((max(1, round(im.width * K)), max(1, round(im.height * K))), Image.LANCZOS)
    im.save(p, optimize=True)
def P(x, y): return [round(x * S), round(SKY + y * S)]          # a point of the 1024x1536 surface -> stack px
def ex(n): return os.path.exists(os.path.join(M, n + ".png"))

# ------------------------------------------------------------------ the sky and the surface
# the surface stages are edits of s_dry (no smoke, wheel, flywheel or water - those are layers). surface.png is the
# ruined picture under the sky extension; each place is cut out of its step pictures with a soft mask, finished = s_dry.
ext = img("sky2")                   # its rows 574.. are the top of the scaled surface
def surface(src):
    full = Image.new("RGBA", (W, SKY + SURF), (0, 0, 0, 255))
    full.alpha_composite(src.crop((0, 0, W, SURF)), (0, SKY))
    m = Image.new("L", (W, SKY + 80), 255)
    ImageDraw.Draw(m).rectangle((0, SKY + 30, W, SKY + 80), fill=0)
    m = m.filter(ImageFilter.GaussianBlur(16))
    full.paste(Image.composite(ext.crop((0, 0, W, SKY + 80)), full.crop((0, 0, W, SKY + 80)), m), (0, 0))
    return full
ruined = big("s_ruined")
save(surface(ruined), "surface.png")
# the places, in 1024x1536 px of the picture; drawn in this order, each without what a later one covers
PLACE_POLY = {
    "wheel": [(0, 425), (300, 425), (300, 772), (0, 772)],
    "smelter": [(300, 160), (768, 160), (768, 805), (650, 842), (520, 850), (400, 814), (300, 784)],
    "incline": [(768, 180), (1024, 180), (1024, 852), (768, 852)],
    "draught": [(768, 110), (872, 110), (874, 808), (768, 808)],
    "hoist": [(30, 772), (300, 784), (400, 814), (520, 850), (535, 1048), (30, 1048)],
    "lapidary": [(598, 846), (1024, 846), (1024, 1192), (598, 1192)],
}
STEPS = {p: ["s_%s1" % p, "s_%s2" % p, "s_dry"] for p in PLACE_POLY}
info["places"], info["place_box"] = {}, {}
for p, poly in PLACE_POLY.items():
    m = Image.new("L", (W, SURF), 0)
    ImageDraw.Draw(m).polygon([(x * S, y * S) for x, y in poly], fill=255)
    m = m.filter(ImageFilter.GaussianBlur(7))
    x0, y0, x1, y1 = m.getbbox()
    mc = m.crop((x0, y0, x1, y1))
    for i, name in enumerate(STEPS[p]):
        if not ex(name):
            print("missing", name); continue
        strip = big(name).crop((x0, y0, x1, y1))
        strip.putalpha(ImageChops.multiply(strip.getchannel("A"), mc))
        save(strip, f"place/{p}_{i + 1}.png")
    info["places"][p] = [x0, SKY + y0]
    info["place_box"][p] = [x0, SKY + y0, x1, SKY + y1]

# ------------------------------------------------------------------ the mill: wheel, water, flywheel
spr, front, linfo = L.build()
WW = L.WATER_WHEEL
wheel = spr["wheel"].resize((512, 512), Image.LANCZOS)
save(wheel, "wheel.png", scale=False)              # drawn squashed into the ellipse by the game: its own size is free
save(L.ring(wheel, WW["rim"]), "wheel_rim.png", scale=False)
info["wheel"] = {"c": P(*WW["c"]), "rx": WW["rx"] * S, "ry": WW["ry"] * S, "depth": [WW["depth"][0] * S, WW["depth"][1] * S],
                 "layers": WW["layers"], "rate": -0.12}
back, foam, falls = L.water_layers()
def place_layer(im, rel):
    """a layer of the 1024x1536 picture, cropped to what it has, scaled into the stack -> its top left (stack px)"""
    bb = im.getbbox()
    c = im.crop(bb)
    c = c.resize((round(c.width * S), round(c.height * S)), Image.LANCZOS)
    save(c, rel)
    return [round(bb[0] * S), round(SKY + bb[1] * S)], bb
wb_at, wb_bb = place_layer(back, "water_back.png")
fo_at, _ = place_layer(foam, "water_foam.png")
# the falls' rectangles in the water texture's px (scaled by S and K)
ys, xs = np.nonzero(falls)
def frect(x0, y0, x1, y1):
    q = (xs >= x0) & (xs < x1) & (ys >= y0) & (ys < y1)
    if not q.any(): return [0, 0, 0, 0]
    return [round((xs[q].min() - wb_bb[0]) * S * K), round((ys[q].min() - wb_bb[1]) * S * K),
            round((xs[q].max() + 1 - wb_bb[0]) * S * K), round((ys[q].max() + 1 - wb_bb[1]) * S * K)]
info["water"] = {"back": wb_at, "foam": fo_at, "falls": [frect(112, 470, 205, 745), frect(35, 655, 95, 760)],
                 "reflection": P(160, 522)}
fwc, fwr, _ = L.WHEELS["flywheel"]
save(spr["flywheel"].resize((round(2 * fwr * S), round(2 * fwr * S)), Image.LANCZOS), "flywheel.png")
ff = front["flywheel"]; fb = ff.getbbox(); ffc = ff.crop(fb)
save(ffc.resize((round(ffc.width * S), round(ffc.height * S)), Image.LANCZOS), "flywheel_front.png")
info["flywheel"] = {"c": P(*fwc), "r": fwr * S, "rate": 0.45, "front": P(fb[0], fb[1]), "steam": P(322, 845)}

# ------------------------------------------------------------------ the depth bands
# per depth (band rows, i.e. picture rows - 190): the rails' top, the lamps, the niche's pedestal top, where the gallery
# begins at the left (the shaft's landing reaches it), the crew; measured on the pictures (mine2/grid_*.png)
DEP = json.load(open(os.path.join(M, "depths.json")))
info["floors"], info["lamps"], info["niches"], info["galleries"] = {}, {}, {}, {}
for d in range(1, 10):
    if str(d) not in DEP: print("no measures for depth", d); continue
    dd = DEP[str(d)]
    for st in ("clear", "closed", "step1", "step2", "done"):
        name = f"d{d}_{st}"
        if ex(name):
            save(img(name).crop((0, BAND[0], W, BAND[1])), f"band/{name}.png")
    info["floors"][str(d)] = dd["floor"]
    info["lamps"][str(d)] = dd["lamps"]
    if dd.get("niche"): info["niches"][str(d)] = dd["niche"]
    info["galleries"][str(d)] = dd["left"]

# ------------------------------------------------------------------ the factory's own things
def poly_cut(src, poly, rel):
    """a piece of a surface picture inside a polygon (1024 px) -> saved, its top left in stack px"""
    m = Image.new("L", src.size, 0)
    ImageDraw.Draw(m).polygon([(x * S, y * S) for x, y in poly], fill=255)
    m = m.filter(ImageFilter.GaussianBlur(1.2))
    a = src.copy(); a.putalpha(m)
    bb = m.getbbox()
    save(a.crop(bb), rel)
    return [bb[0], SKY + bb[1]]
dry = big("s_dry")
# the draught stack again, in front of the incline cart (the rails run behind it)
def stack_mask():
    """the draught stack's own outline in s_dry (1024 px): per row the run of brick-red pixels around the stack's axis,
    widened by its ink line, filled solid - nothing of the sky, trees or rails beside it"""
    src = np.asarray(img("s_dry").convert("RGB")).astype(int)
    m = np.zeros((1536, 1024), bool)
    for y in range(110, 720):
        row = src[y, 770:870]
        red = (row[:, 0] > row[:, 1] + 18) & (row[:, 0] > 70)
        xs = np.nonzero(red)[0]
        if len(xs) < 6: continue
        xs = xs[np.abs(xs - np.median(xs)) < 30]
        m[y, 770 + xs.min() - 3: 770 + xs.max() + 4] = True     # + the black outline on both sides
    im = Image.fromarray((m * 255).astype(np.uint8)).filter(ImageFilter.MedianFilter(5)).filter(ImageFilter.GaussianBlur(0.7))
    return im.resize((W, round(1536 * S)), Image.LANCZOS)
sm_ = stack_mask()
st_ = dry.copy(); st_.putalpha(sm_)
bb_ = sm_.getbbox()
save(st_.crop(bb_), "stack_front.png")
info["stack_front"] = [bb_[0], SKY + bb_[1]]
# the incline cart rides on the track's rail: a polyline measured on s_dry (the trestle bends a little at the stack), from
# where the track comes out from behind the smelter to the winch house's platform
# (22.11: the foot of the run raised clear of the smelter wing's roof — the cart stood on it)
info["incline"] = {"path": [P(744, 413), P(790, 388), P(837, 362), P(930, 325)], "s": 0.34}
info["smelter"] = {"mouth": P(418, 716) + [round(104 * S), round(96 * S)]}
info["draught"] = {"door": P(806, 766)}
info["lapidary"] = {"windows": [P(x, 1060) + [110] for x in (768, 845, 921, 998)]}
info["surface_lamps"] = {"portal": [P(113, 1108) + [1.0]], "hoist": [P(247, 920) + [0.9]],
                         "lapidary": [P(688, 1068) + [0.8]], "incline": [P(952, 262) + [0.9]],
                         "smelter": [P(470, 760) + [2.2, "#ff7a2a55"]]}
# smoke: x, y (stack px), size, warm (lit orange from below)
info["smoke"] = {"smelter": [P(425, 226) + [1.3, 1.0], P(512, 200) + [1.2, 1.0], P(578, 184) + [1.2, 1.0]],
                 "draught": [P(812, 126) + [0.9, 0.2]], "hoist": [P(325, 800) + [0.5, 0.0]]}
# a soft puff for the smoke (drawn, not a picture: grey, round, its edge soft)
pf = Image.new("L", (96, 96), 0)
ImageDraw.Draw(pf).ellipse((8, 8, 88, 88), fill=255)
pf = pf.filter(ImageFilter.GaussianBlur(10))
puff = Image.new("RGBA", (96, 96), (205, 205, 210, 0)); puff.putalpha(pf)
save(puff, "puff.png", scale=False)

# ------------------------------------------------------------------ people, animals, effects (sheets on magenta)
ORDER = {}     # sheet -> the drawings' order that was played (new index -> drawing of the sheet)

def smooth_order(fr):
    """GPT numbers the drawings of a loop, but they do not always follow each other: neighbours on the sheet can be poses
    far apart, and the loop jumps. Find the order through all drawings with the least change from one to the next
    (a closed tour: nearest neighbour, then 2-opt), starting from the sheet's first drawing and keeping its direction."""
    sz = (48, 48)
    def vec(f):
        g = Image.new("RGBA", f.size, (0, 0, 0, 0)); g.alpha_composite(f)
        a = np.asarray(g.resize(sz, Image.BILINEAR)).astype(float) / 255
        return np.concatenate([a[..., 3].ravel() * 2, (a[..., :3].mean(2) * a[..., 3]).ravel()])
    v = np.array([vec(f) for f in fr])
    D = np.sqrt(((v[:, None] - v[None]) ** 2).sum(-1))
    n = len(fr)
    tour, left = [0], set(range(1, n))
    while left:
        j = min(left, key=lambda k: D[tour[-1], k]); tour.append(j); left.discard(j)
    better = True
    while better:
        better = False
        for i in range(1, n - 1):
            for j in range(i + 1, n):
                a, b, c, d = tour[i - 1], tour[i], tour[j], tour[(j + 1) % n]
                if D[a, c] + D[b, d] < D[a, b] + D[c, d] - 1e-9:
                    tour[i:j + 1] = tour[i:j + 1][::-1]; better = True
    if tour[1] > tour[-1]:            # the sheet's own direction: frame 1 is followed by an early drawing
        tour = [tour[0]] + tour[1:][::-1]
    return tour

def by_columns(im, n):
    """a one-row sheet cut at the empty columns between its drawings (a burst's flying stones are separate shapes - by
    silhouettes they came out as drawings of their own and the burst jumped about); the narrowest gaps are inside a
    drawing and are joined until n are left. All on the sheet's common band of rows: one scale, one height"""
    a = np.asarray(im)[..., 3] > 60
    cols = a.any(axis=0); segs, x = [], 0
    while x < len(cols):
        if cols[x]:
            x1 = x
            while x1 < len(cols) and cols[x1]: x1 += 1
            segs.append([x, x1]); x = x1
        else: x += 1
    while len(segs) > n:
        i = min(range(len(segs) - 1), key=lambda j: segs[j + 1][0] - segs[j][1])
        segs[i] = [segs[i][0], segs[i + 1][1]]; del segs[i + 1]
    if len(segs) < n:                        # drawings that touch: even cells over the drawn span
        x0, x1 = segs[0][0], segs[-1][1]; w = (x1 - x0) / n
        segs = [[round(x0 + i * w), round(x0 + (i + 1) * w)] for i in range(n)]
    rows = np.nonzero(a.any(axis=1))[0]; y0, y1 = int(rows.min()), int(rows.max()) + 1
    return [im.crop((x0, y0, x1, y1)) for x0, x1 in segs]

def by_grid(im, n, rows):
    """the sheet cut into its even grid of cells (for sheets whose drawings touch their neighbours - the stoker's long rake
    joined two men into one shape), each cell trimmed and the cells lined up by the feet like by_shape"""
    x0, y0, x1, y1 = im.getbbox()
    cols = n // rows
    cw, ch = (x1 - x0) / cols, (y1 - y0) / rows
    cells = []
    for r in range(rows):
        for c in range(cols):
            cell = im.crop((round(x0 + c * cw), round(y0 + r * ch), round(x0 + (c + 1) * cw), round(y0 + (r + 1) * ch)))
            # only the man standing in this cell: the biggest shape, and small bits near it (a rake from the left is cut off)
            a = np.asarray(cell)[..., 3] > 100
            lab, k = label(a[::2, ::2])
            if k > 1:
                sz = np.bincount(lab.ravel()); sz[0] = 0
                keep = np.repeat(np.repeat(lab == sz.argmax(), 2, 0), 2, 1)[:a.shape[0], :a.shape[1]]
                keep = np.pad(keep, ((0, a.shape[0] - keep.shape[0]), (0, a.shape[1] - keep.shape[1])))
                arr = np.asarray(cell).copy(); arr[..., 3] = arr[..., 3] * keep; cell = Image.fromarray(arr)
            cells.append(cell.crop(cell.getbbox()))
    W_ = max(c.width for c in cells); H_ = max(c.height for c in cells)
    out = []
    for c in cells:
        al = np.asarray(c)[..., 3] > 100; ys, xs = np.nonzero(al)
        fx = float(np.median(xs[ys > ys.max() - (ys.max() - ys.min()) * 0.12]))
        g = Image.new("RGBA", (2 * W_, H_), (0, 0, 0, 0)); g.alpha_composite(c, (int(W_ - fx), H_ - c.height)); out.append(g)
    return out

GRID = {"stoker24", "tealad_cheer", "pumpman_cheer"}   # sheets cut by their grid, not by shapes (neighbours touch)
COLS = {"dust8"}          # one-row sheets cut at the empty columns between drawings

FIRST_H = {}   # sheet -> the height its first drawing (the working pose) got in the game, px

def frames(name, n, rows, height, folder, align="feet", dark=1.0, mirror=False, reorder=False, match=None):
    """a sheet cut into its drawings, scaled to `height` (median) - or, with `match`, so that its first drawing is as tall
    as that sheet's first drawing: a reaction starts and ends in the working pose, and the man must not change size"""
    if not ex("cyc_" + name):
        print("missing sheet", name); return 0
    fr = by_columns(cyc(name), n) if name in COLS else by_grid(cyc(name), n, rows) if name in GRID else by_shape(cyc(name), n, rows=rows, align=align, ahead=align == "feet")
    def unpink(f):
        x = np.asarray(f).astype(float)
        pink = (x[..., 0] > 140) & (x[..., 2] > 120) & (x[..., 1] < x[..., 0] * 0.6) & (x[..., 1] < x[..., 2] * 0.7)
        x[..., 3][pink] = 0
        return Image.fromarray(x.astype(np.uint8))
    fr = [unpink(f) for f in fr]
    if reorder:
        ORDER[name] = smooth_order(fr)
        fr = [fr[i] for i in ORDER[name]]
    if align == "feet":
        # the canvas symmetric about the feet: a man is placed by his feet, and a flipped one stays on the spot
        def feet(f):
            al = np.asarray(f)[..., 3] > 100; ys, xs = np.nonzero(al)
            return float(np.median(xs[ys > ys.max() - (ys.max() - ys.min()) * 0.12]))
        fx = float(np.median([feet(f) for f in fr]))
        half = max(fx, fr[0].width - fx)
        out = []
        for f in fr:
            g = Image.new("RGBA", (int(2 * half) + 2, f.height), (0, 0, 0, 0)); g.alpha_composite(f, (int(half - fx), 0)); out.append(g)
        fr = out
    k_ = height / float(np.median([f.height for f in fr]))
    if match and match in FIRST_H:
        k_ = FIRST_H[match] / float(fr[0].height)
    FIRST_H[name] = fr[0].height * k_
    for i, f in enumerate(fr):
        f = f.resize((max(1, round(f.width * k_)), max(1, round(f.height * k_))), Image.LANCZOS)
        if mirror: f = f.transpose(Image.FLIP_LEFT_RIGHT)
        if dark < 1:
            a = np.asarray(f).astype(float); a[..., :3] *= dark; f = Image.fromarray(a.astype(np.uint8))
        save(f, f"{folder}/{i:02d}.png")
    return len(fr)

MAN = 178                        # a standing man in a gallery (source px)
CREWS = {   # depth: sheet, height, x (feet), flip, the drawing of the blow on the sheet (sound; the riveter's spark)
    "1": ("hewer24", MAN * 1.05, 1390, False, 9),
    "2": ("pumpman24", MAN * 1.0, 1215, False, None),
    "3": ("tealad24", MAN * 0.66, 760, False, None),
    "4": ("riveter24", MAN * 1.02, 1185, False, 8),
    "5": ("sorter24", MAN * 0.97, 1180, False, None),
    "6": ("groom24", MAN * 1.0, 660, False, None),
    "7": ("cutter24", MAN * 0.72, 720, True, 9),
    "8": ("winch24", MAN * 1.04, 1290, False, None),
}
# how the sheet plays: [drawing, how long] in the order they show (1 = one drawing at the sheet's fps). GPT spaces the
# drawings evenly, the motion is not: a swing hangs at the top and drops in a flash, the blow and a look hold; a drawing GPT
# got wrong is skipped, a move missing on the sheet is played back. The loop gets as long as it needs.
def ev(a, b, k=1.0):
    return [[i, k] for i in range(a, b + 1)]
PLAY = {
    # stands -> lifts over the shoulder -> top -> drops -> blow at the ground (9) -> back; second swing from the front,
    # top (19-21) -> down in one drawing (23, the second blow)
    "hewer24":   [[0, 3], [1, 1], [2, 1], [3, 1], [4, 1.5], [5, 4], [6, .6], [7, .6], [8, .6], [9, 4], [10, 1.5], [11, 2],
                  [12, 2]] + ev(13, 19) + [[20, 3.5], [21, 1], [22, .6], [23, 4]],
    # low -> up -> overhead (4-5) -> drops -> blow with the spark (8) -> recoil; up again, overhead (18-20), down (21-23)
    "riveter24": [[0, 3], [1, 1], [2, 1], [3, 1], [4, 1.5], [5, 4], [6, .6], [7, .6], [8, 3.5], [9, 1.5], [10, 1.5],
                  [11, 2.5], [12, 2]] + ev(13, 17) + [[18, 1.2], [19, 3.5], [20, 1], [21, .6], [22, 1], [23, 3]],
    # sorts (0-5) -> picks a stone (6-8) -> looks at it (9-11) -> winds up (13) -> throws (14-16) -> sorts again
    "sorter24":  ev(0, 5, 1.5) + [[6, 1], [7, 1], [8, 1], [9, 1.5], [10, 4], [11, 2], [12, 1], [13, 2.5], [14, .6],
                  [15, 1.5], [16, 3], [17, 1.5]] + ev(18, 23, 1.5),
    # sets the chisel (0-5) -> the mallet rises, top (8) -> tap with chips (9-10) -> blows the dust, looks (11-17) -> sets again
    "cutter24":  ev(0, 5, 1.5) + [[6, 1], [7, 1], [8, 3], [9, 2.5], [10, 1.5]] + ev(11, 17, 1.5) + ev(18, 23, 1.2),
    # leans on the lever down to the bottom (9), lets it rise with the arms (10-23), a breath at the top
    "pumpman24": [[0, 2.5]] + ev(1, 8, 1.2) + [[9, 3]] + ev(10, 22, .9) + [[23, 1.5]],
    # blows on the tea, sips (holds the sip), lowers the mug and swings his feet, looks round (holds)
    "tealad24":  ev(0, 5, 1.5) + ev(6, 7, 1.8) + [[8, 3], [9, 3]] + ev(10, 11, 1.8) + ev(12, 17, 1.2) + ev(18, 19, 1.5)
                  + [[20, 3]] + ev(21, 22, 1.5) + [[23, 1]],
    # brush strokes, then pats with the free hand
    "groom24":   ev(0, 9) + ev(10, 17, 1.2) + ev(18, 23),
    # the surface: the stoker (10 a second) pushes the poker in and holds, pulls back and holds - twice
    "stoker24":  ev(0, 4) + [[5, 2.5]] + ev(6, 10) + [[11, 2]] + ev(12, 16) + [[17, 2.5]] + ev(18, 22) + [[23, 2]],
    # the guide (8 a second): lifts the lens, looks long (8), lowers it (13-14 played back - on the sheet he lifts it twice,
    # and in drawing 19 the lens is gone), holds the stone low a while
    "guide24":   [[0, 3]] + ev(1, 7) + [[8, 4]] + ev(9, 11, 1.5) + [[14, 1], [13, 1], [12, 3], [15, 1.5], [16, 1.5],
                  [17, 3], [22, 1.5], [23, 1.5]],
}
info["crew_n"], info["crews"] = {}, {}
for d, (nm, h, x, flip, hit) in CREWS.items():
    # the sheet's own order: GPT draws these actions in sequence, and reordering by likeness played swings backwards
    n = frames(nm, 24, 4, h, nm, dark=0.9)
    info["crew_n"][nm] = n
    if not n: continue
    cr = {"work": [nm, x, ""], "flip": flip}
    if hit is not None: cr["hit"] = hit
    if nm in PLAY: cr["play"] = PLAY[nm]
    if nm == "riveter24": cr["spark"] = [60, -100]
    if nm == "groom24": cr["pet"] = ["pony12", x + 112]      # its flank under his brush (hand ~99 px ahead of his feet)
    info["crews"][d] = cr
    base = nm[:-2]
    for what in ("cheer", "scratch"):
        info["crew_n"][f"{base}_{what}"] = frames(f"{base}_{what}", 12, 2, h, f"react/{base}_{what}", dark=0.9, match=nm)
info["crew_n"]["pony12"] = frames("pony12", 12, 2, MAN * 0.92, "pony12", dark=0.9)
# the surface (the factory is a little further away than the galleries: its people smaller)
SMAN = 128
info["crew_n"]["stoker24"] = frames("stoker24b" if ex("cyc_stoker24b") else "stoker24", 24, 4, SMAN * 1.05, "stoker24")
info["crew_n"]["guide24"] = frames("guide24", 24, 4, SMAN * 0.8, "guide24")
info["crew_n"]["cat12"] = frames("cat12", 12, 2, 30, "cat12")
info["crew_n"]["pigeon12"] = frames("pigeon12", 12, 2, 26, "pigeon12")
info["crew_n"]["duck12"] = frames("duck12", 12, 2, 30, "duck12")
def L_(name, place, x, y, **kw):
    return dict(name=name, place=place, x=round(x * S), y=round(y * S), **kw)
# placed on the picture's own floors (checked on frames of the game): the stoker on the rubble ledge in front of the
# ingot pile right of the furnace mouth (left of it is the engine house roof), turned to it; the cat curled on top of the warm ingots by the small door
info["life"] = [L_("stoker24", "smelter", 532, 825, fps=10, flip=True, play=PLAY["stoker24"]),
                L_("guide24", "lapidary", 722, 1176, fps=8, flip=True, play=PLAY["guide24"]),
                L_("cat12", "smelter", 566, 789, fps=6),
                L_("pigeon12", "incline", 925, 206, fps=7, ph=0.0),
                L_("pigeon12", "incline", 968, 207, fps=6, ph=2.7, flip=True),
]
info["crew_n"]["flame"] = frames("flame12", 12, 2, round(96 * S), "flame", align="center")
info["crew_n"]["lizard"] = frames("lizard_run8", 8, 1, 70, "lizard", align="center")
n_dust = frames("dust8", 8, 1, 200, "burst", align="center")
if ex("cyc_mistress_reflect"):
    # her FACE shows for a moment in the curtain of the waterfall: the head of her figure, soft oval edge, pale and green
    # like the water, cut by the water itself (outside the falls nothing of her is drawn)
    fig = cyc("mistress_reflect"); fig = fig.crop(fig.getbbox())
    head = fig.crop((225, 10, 365, 200))
    FW = 74                                          # px of the 1024 picture: the falls are ~90 wide
    head = head.resize((FW, round(head.height * FW / head.width)), Image.LANCZOS)
    a = np.asarray(head).astype(float)
    hh, ww = a.shape[:2]
    Y_, X_ = np.mgrid[0:hh, 0:ww]
    oval = np.clip(1.4 - np.hypot((X_ - ww / 2) / (ww * 0.48), (Y_ - hh * 0.5) / (hh * 0.52)) * 1.4, 0, 1)
    lum = a[..., :3].mean(2, keepdims=True)
    a[..., :3] = lum * np.array([0.75, 1.1, 1.0]) * 0.9 + np.array([40, 90, 85]) * 0.35     # pale, washed into the water
    a[..., 3] *= oval
    # where she sits: centred on the main falls; then cut by the water's alpha there
    cx, cy = 158, 540
    wa = np.asarray(back)[..., 3].astype(float) / 255
    x0, y0 = cx - ww // 2, cy - hh // 2
    a[..., 3] *= wa[y0:y0 + hh, x0:x0 + ww]
    for y in range(hh):                              # wavering with the water
        a[y] = np.roll(a[y], int(round(1.5 * math.sin(y * 0.35))), axis=0)
    face = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))
    save(face.resize((round(ww * S), round(hh * S)), Image.LANCZOS), "reflection.png")
    info["water"]["reflection"] = P(cx, cy)
if ex("cyc_hotcrack"):
    hc = cyc("hotcrack"); hc = hc.crop(hc.getbbox())
    save(hc.resize((round(hc.width * 160 / hc.height), 160), Image.LANCZOS), "hotcrack.png")
# carts: the sheet's first two objects (empty, full), the wheel
ct = cyc("carts")
lab, nl = label(np.asarray(ct)[..., 3] > 128)
sizes = np.bincount(lab.ravel()); sizes[0] = 0
objs = sorted([i for i in np.argsort(sizes)[::-1][:5]], key=lambda i: (np.nonzero(lab == i)[0].mean() > ct.height / 2, np.nonzero(lab == i)[1].mean()))
def obj(i):
    ys_, xs_ = np.nonzero(lab == i)
    return ct.crop((xs_.min(), ys_.min(), xs_.max() + 1, ys_.max() + 1))
for i, nm in zip(objs[:2], ("cart_empty", "cart_full")):
    o = obj(i); save(o.resize((round(o.width * 200 / o.width), round(o.height * 200 / o.width)), Image.LANCZOS), nm + ".png")

# ------------------------------------------------------------------ the inclined shaft
# One steep flight per level in the solid rock at the left of the bands (x < ZONE), zigzagging: an even level's flight runs
# down to the right from x=XA to x=XB, an odd level's back (the picture mirrored) - XA + XB = ZONE, so the flights meet at
# the seams. At each level a short drift (a landing) runs from the flight to the gallery's left end at its floor.
XA, XB = 118, 352
seg = cyc("shaftseg2") if ex("cyc_shaftseg2") else None
drift = cyc("drift") if ex("cyc_drift") else None
BH = BAND[1] - BAND[0]
info["shaft"] = {"path": {}, "cart_s": 0.38}
if seg is not None:
    a_ = np.asarray(seg)[..., 3] > 128
    rows = [np.nonzero(a_[y])[0] for y in (40, seg.height - 40)]
    c0, c1 = rows[0].mean(), rows[1].mean()          # the tunnel's axis at its top and bottom
    # scale it to one level's height, the axis from XA (top) to XB (bottom): a horizontal scale and shift + a vertical scale
    ky = BH / (seg.height - 80)
    flight = seg.crop((0, 40, seg.width, seg.height - 40)).resize((seg.width, BH), Image.LANCZOS)
    kx = (XB - XA) / (c1 - c0)
    kx = max(kx, 0.36)                                # keep the timbers from going too thin
    fl = flight.resize((max(1, round(flight.width * kx)), BH), Image.LANCZOS)
    # shear each row so the axis runs exactly XA -> XB whatever kx did
    arr = np.asarray(fl).copy(); out = np.zeros((BH, ZONE + 200, 4), np.uint8)
    for y in range(BH):
        ax = c0 * kx + (c1 - c0) * kx * y / BH
        want = XA + (XB - XA) * y / BH
        sh_ = int(round(want - ax))
        row = arr[y]
        x0 = max(0, sh_); x1 = min(out.shape[1], sh_ + row.shape[0])
        out[y, x0:x1] = row[x0 - sh_:x1 - sh_]
    flight = Image.fromarray(out[:, :ZONE + 120])
for d in range(1, 10):
    if seg is None: break
    if str(d) not in DEP: continue
    dd = DEP[str(d)]
    k = d - 1
    fdir = flight if k % 2 == 0 else flight.transpose(Image.FLIP_LEFT_RIGHT).crop((flight.width - ZONE, 0, flight.width, BH))
    canvas = Image.new("RGBA", (W, BH), (0, 0, 0, 0))
    floor = dd["floor"]
    # the landing: the drift from the flight to the gallery, its rails on the gallery's floor
    xs_ = XA + (XB - XA) * floor / BH if k % 2 == 0 else ZONE - (XA + (XB - XA) * floor / BH)
    if drift is not None and not ex(f"d{d}_reach"):   # an extended gallery reaches the shaft itself
        dr = drift.crop((0, 335, drift.width, 725))          # the drift's rows; its rails' top at row 625
        dh = 250
        dr = dr.resize((round(dr.width * dh / dr.height), dh), Image.LANCZOS)
        rail = round((625 - 335) * dh / 390)
        # laid from the gallery back to the flight: the drift ends on a whole post (the sheet's post at 1105..1141 px)
        # right at the gallery's mouth, its cut-off piece is under the flight - no stub of a frame inside the gallery
        f = dh / 390
        end = dd["left"] + 48
        piece = dr.crop((0, 0, round(1141 * f), dh))
        x = end - piece.width
        canvas.alpha_composite(piece, (x, floor - rail))
        while x > int(xs_) - 20:
            x -= dr.width
            canvas.alpha_composite(dr, (x, floor - rail)) if x >= 0 else canvas.alpha_composite(dr.crop((-x, 0, dr.width, dh)), (0, floor - rail))
    canvas.alpha_composite(fdir.crop((0, 0, min(fdir.width, W), BH)), (0, 0))
    save(canvas.crop((0, 0, max(dd["left"] + 60, ZONE + 120), BH)), f"shaft/flight_{d}.png")
    # the cart's way through this level: down the flight (on its rails, a little above the axis' bottom line)
    ya, yb = 0, BH
    RAIL = 32                                        # the rails run that far to the floor side of the axis
    pa = [XA - RAIL, ya] if k % 2 == 0 else [ZONE - XA + RAIL, ya]
    pb = [XB - RAIL, yb] if k % 2 == 0 else [ZONE - XB + RAIL, yb]
    info["shaft"]["path"][str(d)] = [pa, pb]
# the top: from the portal's mouth down through the cut of soil to the first flight - the lower rows of an odd (mirrored)
# flight, whose axis runs right to left and ends at XA, where the first level's flight begins
if seg is not None:
    fodd = flight.transpose(Image.FLIP_LEFT_RIGHT).crop((flight.width - ZONE, 0, flight.width, BH))
    th = 172                     # the cut of soil under the ground line
    y0 = BH - th
    save(fodd.crop((0, y0, ZONE, BH)), "shaft/top.png")
    ax = ZONE - (XA + (XB - XA) * y0 / BH)
    info["shaft"]["top"] = [0, SKY + SURF - th]
    # the cart comes out of the portal on its own rails (measured on s_dry: from the dark mouth down to the ground line,
    # where they meet the shaft) and turns down the cut
    info["shaft"]["path_top"] = [P(95, 1172), [round(ax) + 32, SKY + SURF - th], [XA + 32, SKY + SURF]]

# the lapidary's front: the window strip of s_dry without its glowing glass (stone piers, frames, the vases) - a shadow
# running inside the room passes behind them and comes out at the next window
src_l = np.asarray(img("s_dry").convert("RGB")).astype(int)
LB = (735, 975, 1024, 1140)
reg = src_l[LB[1]:LB[3], LB[0]:LB[2]]
glass = (reg[..., 1] > reg[..., 0] + 35) & (reg[..., 1] > 105)
gm = Image.fromarray((glass * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.8))
fr_ = img("s_dry").crop(LB); fr_.putalpha(ImageChops.invert(gm))
save(fr_.resize((round(fr_.width * S), round(fr_.height * S)), Image.LANCZOS), "lapidary_front.png")
info["lapidary"]["front"] = P(LB[0], LB[1])
info["lapidary"]["run"] = [P(728, 1062), P(1030, 1062)]     # the shadow's way across all four windows

# the sky: the moon (centre, radius) and the leaning tower of Nevyansk far away - its lit door, the windows a candle climbs
# past, the belfry where the bell is, the spire's tip (1024 px of s_dry)
info["moon"] = P(130, 170) + [round(19 * S)]
info["tower"] = {"windows": [P(179, 362), P(186, 322), P(183, 292), P(192, 266)], "belfry": P(192, 262), "spire": P(196, 216)}

# ------------------------------------------------------------------ the Mistress about the place, the finale
info["pump"] = {d: v["pump"] for d, v in DEP.items() if "pump" in v}
# the cracks the crowned lizard runs into: drawn into the walls by GPT edits (d*_crack), only the crack's neighbourhood is
# carried into the open gallery's picture; its pitch-black inside is cut out as a layer drawn over her, so she slips into
# the dark instead of fading on the rock. Per depth: the edit, the box searched, where she starts, where she enters
# (picture px), which way the crack goes in.
CRACKS = {2: ("d2_crack", (860, 280, 1010, 500), (944, 596), (932, 470), (0, -1), 45, None),
          # 250 m: the crack runs behind the scale - she comes from the bare rock right of it, above the beam, into the
          # crack's upper end and down; the scale's beam and chains are a layer over her (cut below)
          5: ("d5_crack2", (1360, 290, 1415, 560), (1428, 375), (1393, 356), (0, 1), 60, (1240, 380, 1470, 600)),
          # 350 m: from the bare malachite wall at the left (the slabs and rubble below the crack stand in front)
          7: ("d7_crack", (1230, 280, 1380, 520), (1232, 505), (1313, 468), (0, -1), 45, None)}
info["cracks"] = []
for d, (src, box, frm, ent, dirv, dark, front) in CRACKS.items():
    if not ex(src): continue
    a_ = np.asarray(img(f"d{d}_clear").convert("RGB")).astype(int); b_ = np.asarray(img(src).convert("RGB")).astype(int)
    x0, y0, x1, y1 = box
    m = np.zeros(a_.shape[:2], bool)
    m[y0:y1, x0:x1] = (b_[y0:y1, x0:x1].mean(2) < dark) & (a_[y0:y1, x0:x1].mean(2) - b_[y0:y1, x0:x1].mean(2) > 25)
    mm = np.asarray(Image.fromarray((m * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.MinFilter(3))) > 128
    lab_, n_ = label(mm); sz_ = np.bincount(lab_.ravel()); sz_[0] = 0
    inside = Image.fromarray(((lab_ == sz_.argmax()) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.0))
    # the crack into the band picture: the edited picture over the open one inside the box, soft edges
    pm = Image.new("L", (W, 1024), 0); ImageDraw.Draw(pm).rectangle((x0 + 12, y0 + 12, x1 - 12, y1 - 12), fill=255)
    pm = pm.filter(ImageFilter.GaussianBlur(8))
    merged = Image.composite(img(src), img(f"d{d}_clear"), pm)
    for st in ("clear",):
        save(merged.crop((0, BAND[0], W, BAND[1])), f"band/d{d}_{st}.png")
    lay = img(src); lay.putalpha(inside)
    bb = inside.getbbox()
    save(lay.crop(bb), f"crack_{d}.png")
    cr = {"d": d, "mask": [bb[0], bb[1] - BAND[0]], "from": [frm[0], frm[1] - BAND[0]],
          "to": [ent[0], ent[1] - BAND[0]], "dir": list(dirv), "into": 130 if d == 5 else 70}
    if front:
        # what stands in front of the wall there (the scale's iron: dark, and not the crack's inside), over her
        fx0, fy0, fx1, fy1 = front
        fm = np.zeros(b_.shape[:2], bool)
        fm[fy0:fy1, fx0:fx1] = b_[fy0:fy1, fx0:fx1].mean(2) < 58
        fm &= ~(np.asarray(inside) > 40)
        fmi = Image.fromarray((fm * 255).astype(np.uint8)).filter(ImageFilter.MedianFilter(3)).filter(ImageFilter.MaxFilter(3))
        fmi = fmi.filter(ImageFilter.GaussianBlur(0.6))
        fl = img(src); fl.putalpha(fmi)
        fb = fmi.getbbox()
        save(fl.crop(fb), f"crack_front_{d}.png")
        cr["front"] = [fb[0], fb[1] - BAND[0]]
    info["cracks"].append(cr)
# the herald of the next mine (the volcano's heart): a crack in the rock under the 400 m floor glows and steams now and then
info["hotcrack"] = {"d": 8, "x": 820, "y": 520}
if "9" in DEP and "hall" in DEP["9"]:
    info["hall"] = DEP["9"]["hall"]
json.dump(info, open(os.path.join(OUT, "mine.json"), "w"), indent=1)
print("exported", OUT)
for nm, o in ORDER.items():
    print("order", nm, o)

# ------------------------------------------------------------------ the pines' mask (only they sway)
# the tree lines on the ridges, as bands in 1024 px; inside them only the dark trees, stronger towards their tops
PINES = [[(0, 330), (360, 330), (360, 470), (0, 470)], [(640, 330), (790, 330), (790, 425), (640, 425)],
         [(828, 268), (885, 268), (885, 345), (828, 345)]]
TOWER = [(158, 205), (218, 205), (218, 385), (158, 385)]
pm = Image.new("L", (1024, 1536), 0)
d_ = ImageDraw.Draw(pm)
for p_ in PINES: d_.polygon(p_, fill=255)
d_.polygon(TOWER, fill=0)
src_ = np.asarray(img("s_dry").convert("RGB")).astype(float)
dark = src_.mean(2) < 70
grad = np.clip((480 - np.mgrid[0:1536, 0:1024][0]) / 150.0, 0, 1)          # the tops sway, the feet stay
pmask = (np.asarray(pm) > 0) * dark * grad
pim = Image.fromarray((pmask * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(2))
bb = pim.getbbox()
pim = pim.crop(bb)
pim.resize((round(pim.width * S / 2), round(pim.height * S / 2)), Image.LANCZOS).save(os.path.join(OUT, "pine_mask.png"))
info["sway"] = {"rect": [round(bb[0] * S), round(SKY + bb[1] * S), round((bb[2] - bb[0]) * S), round((bb[3] - bb[1]) * S)]}
json.dump(info, open(os.path.join(OUT, "mine.json"), "w"), indent=1)
