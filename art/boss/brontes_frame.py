"""Brontes' board frame (forged iron: src/brontes/frame_kit_iron.png, the Kraken's v2 kit sheet re-drawn piece for piece),
built exactly as the Kraken's. python brontes_frame.py <scratch dir> <font> <out dir> <godot dir>
The Kraken's board frame, built as the Mistress' (mistress_frame.py) from his own drawn kit (src/kraken/frame_kit.png:
the Mistress' sheet re-drawn by the image generator in his materials, the same layout): weathered whaling-ship planks
cut to length along every outside edge of the board (joints hidden under rusted iron bands), more bands
at random, a corner piece on every turn - outer or inner (a notch) - then the whole frame on the 1-pt grid with an ink
rim, like the boss. One picture per board of the fight, as BossFrame.use_stage expects (no tail frames), and the
square avatar frame (avatar.png/.json: a 48-pt portrait inside).
python kraken_frame.py <scratch dir> <font> <out dir> [area] [cell_pt]   (boards: game_data.json AREAS[area].boss.stages, 2)
"""
import sys, json, random, os
import numpy as np
from PIL import Image, ImageEnhance

# the boss art (its sources, anim.py) is untracked and lives in the main checkout
HERE = os.environ.get('BOSS_ART', 'C:/Users/Максим/Documents/samocvet-rudnik/art/boss')
MY = sys.argv[1:]
src = open(HERE + '/anim.py', encoding='utf-8').read()
sys.argv = ['x'] + MY[:2] + [HERE]
__file__ = HERE + '/anim.py'   # anim.py and what it reads find their files next to it
exec(src[:src.index("# --- boss moods")])
OUT = MY[2]
AREA = 3
GODOT = MY[3]

CELL_PT = 37.0   # the board's cell on screen (9 x 10 boards: 37)
BAR_PT = 24.0       # a bar's thickness on screen, rough edge included
GAP_PT = 1.0        # between the cells and the bar
MARGIN_PT = 30.0    # room round the frame
K = HI              # working px per pt
TONE = (0.85, 0.85)  # the sheet is brighter than the scene: its saturation and brightness are cut to sit with the boss
PLATE = {'outer': 1.15, 'inner': 0.85}   # corner plate size, in bar thicknesses
RUST = 18           # a corner piece's bracket: pixels this much redder than green

# the kit's pieces: where they are on the Mistress' sheet (x, y, w, h); his sheet keeps the layout, each piece is then
# found again in its box (grown by SLACK) as the opaque pixels there
PIECES = {
    'top': (64, 68, 668, 108), 'bottom': (808, 84, 672, 104), 'left': (88, 228, 104, 464), 'right': (1356, 228, 108, 464),
    'strap0': (472, 396, 60, 176), 'strap1': (732, 388, 72, 192), 'strap2': (1008, 396, 60, 176),
    'outer_tl': (40, 748, 152, 160), 'outer_tr': (224, 748, 152, 160), 'outer_bl': (400, 752, 160, 168),
    'outer_br': (596, 752, 160, 168),
    'inner_br': (808, 748, 120, 148), 'inner_bl': (992, 748, 120, 148), 'inner_tr': (1164, 748, 140, 156),
    'inner_tl': (1348, 748, 140, 156),
}


SLACK = 28
# the kit sheet: frame_kit_v2.png (planks of uneven lengths, rope lashings, whale-rib corners) - its corners are whole bone
# pieces, kept as they are; frame_kit.png (v1, the Mistress' build re-drawn) - only the rusted bracket of a corner
SHEET = 'frame_kit_iron.png'
CROP_CORNERS = SHEET == 'frame_kit.png'
# cells between the bands/lashings that aren't on a joint (the rope ones are busy: fewer)
STRAP_GAP = (2.4, 4.2)


def load_kit(bar_pt=None):
    sheet = Image.open(HERE + '/src/brontes/' + SHEET).convert('RGB')
    a, alpha = key_magenta(np.asarray(sheet, dtype=float))
    rgb = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))
    rgb = ImageEnhance.Brightness(ImageEnhance.Color(rgb).enhance(TONE[0])).enhance(TONE[1])
    rgba = rgb.convert('RGBA')
    rgba.putalpha(alpha)
    kit = {}
    for n, (x, y, w, h) in PIECES.items():
        p = rgba.crop((x - SLACK, y - SLACK, x + w + SLACK, y + h + SLACK))
        p = p.crop(p.getchannel('A').point(lambda v: 255 if v > 127 else 0).getbbox())
        if CROP_CORNERS and n.startswith(('outer', 'inner')):
            # only the rusted bracket: its plank stubs carry their own ink ends and would show a seam against the bars.
            # Rust is red over green; the weathered planks are grey
            c = np.asarray(p, dtype=int)
            fe = (c[..., 0] > c[..., 1] + RUST) & (c[..., 3] > 127)
            ys, xs = np.nonzero(fe)
            if len(xs) > 40:
                p = p.crop((max(0, xs.min() - 3), max(0, ys.min() - 3), xs.max() + 4, ys.max() + 4))
        kit[n] = p
    # the bars' median thickness = BAR_PT; a corner plate PLATE bar thicknesses; a strap a little longer than the
    # bar is thick
    al = np.asarray(kit['left'].getchannel('A')) > 127
    src_bar = np.median(al.sum(1)[al.sum(1) > 0])
    s = (bar_pt or BAR_PT) * K / src_bar
    out = {}
    for n, p in kit.items():
        k = s * (PLATE[n[:5]] * src_bar / max(p.size) if n.startswith(('outer', 'inner')) else
                 1.25 * src_bar / max(p.size) if n.startswith('strap') else 1.0)
        out[n] = p.resize((max(1, round(p.width * k)), max(1, round(p.height * k))), Image.LANCZOS)
    return out


def edge(p, side, band):
    """median position of the piece's opaque edge on `side` ('l', 'r', 't', 'b'), measured in the rows/columns of
    `band` ('t', 'b', 'l', 'r': the quarter of the piece where that stub is)"""
    al = np.asarray(p.getchannel('A')) > 127
    h, w = al.shape
    q = slice(0, h // 4) if band == 't' else slice(h * 3 // 4, h) if band == 'b' else \
        slice(0, w // 4) if band == 'l' else slice(w * 3 // 4, w)
    if side in 'lr':
        rows = al[q, :]
        idx = [np.nonzero(r)[0] for r in rows if r.any()]
        v = [i[0] if side == 'l' else i[-1] + 1 for i in idx]
    else:
        cols = al[:, q].T
        idx = [np.nonzero(c)[0] for c in cols if c.any()]
        v = [i[0] if side == 't' else i[-1] + 1 for i in idx]
    return float(np.median(v))


# where each corner piece's two straight (board-side) edges are, and where they go relative to the grid point:
# (x edge, its band), (y edge, its band), (dx, dy) sign of the gap
CORNER_FIT = {
    'outer_tl': (('r', 'b'), ('b', 'r'), (-1, -1)), 'outer_tr': (('l', 'b'), ('b', 'l'), (1, -1)),
    'outer_bl': (('r', 't'), ('t', 'r'), (-1, 1)), 'outer_br': (('l', 't'), ('t', 'l'), (1, 1)),
    'inner_br': (('l', 'b'), ('t', 'r'), (1, 1)), 'inner_bl': (('r', 'b'), ('t', 'l'), (-1, 1)),
    'inner_tr': (('l', 't'), ('b', 'r'), (1, -1)), 'inner_tl': (('r', 't'), ('b', 'l'), (-1, -1)),
}


def corner_kind(full, r, c):
    tl, tr, bl, br = full(r - 1, c - 1), full(r - 1, c), full(r, c - 1), full(r, c)
    n = tl + tr + bl + br
    if n == 1:
        return ['outer_tl' if br else 'outer_tr' if bl else 'outer_bl' if tr else 'outer_br']
    if n == 3:
        return ['inner_tl' if not tl else 'inner_tr' if not tr else 'inner_bl' if not bl else 'inner_br']
    if n == 2 and tl == br:
        return ['outer_tl', 'outer_br'] if tl else ['outer_tr', 'outer_bl']
    return []


def build(rows, kit, seed, cell_pt=CELL_PT, bar_pt=None):
    rnd = random.Random(seed)
    R, C = len(rows), max(len(r) for r in rows)
    full = lambda r, c: int(0 <= r < R and 0 <= c < C and c < len(rows[r]) and rows[r][c] != '#')
    cell, g, m = cell_pt * K, GAP_PT * K, MARGIN_PT * K
    W, H = round(C * cell + 2 * m), round(R * cell + 2 * m)
    img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    gx = lambda c: m + c * cell
    gy = lambda r: m + r * cell
    T = (bar_pt or BAR_PT) * K
    straps = []

    def is_outer(r, c):
        k = corner_kind(full, r, c)
        return bool(k) and k[0].startswith('outer')

    def lay(bar, length, horizontal):
        """a bar `length` px long cut from the kit's bar (several pieces if longer), the joints remembered"""
        p = kit[bar]
        n = p.width if horizontal else p.height
        out = Image.new('RGBA', (round(length), p.height) if horizontal else (p.width, round(length)), (0, 0, 0, 0))
        at, joints = 0, []
        while at < length:
            take = min(length - at, n * 0.85)
            o = rnd.uniform(0, n - take)
            piece = p.crop((round(o), 0, round(o + take), p.height)) if horizontal else p.crop((0, round(o), p.width, round(o + take)))
            out.alpha_composite(piece, (round(at), 0) if horizontal else (0, round(at)))
            at += take
            if at < length: joints.append(at)
        return out, joints

    # horizontal runs along each row line, vertical runs along each column line
    for r in range(R + 1):
        c = 0
        while c < C:
            above, below = full(r - 1, c), full(r, c)
            if above == below:
                c += 1; continue
            c0 = c
            while c < C and full(r - 1, c) == above and full(r, c) == below:
                c += 1
            x0 = gx(c0) - (T + g if is_outer(r, c0) else -g)
            x1 = gx(c) + (T + g if is_outer(r, c) else -g)
            bar = 'top' if below else 'bottom'
            piece, joints = lay(bar, x1 - x0, True)
            al = np.asarray(kit[bar].getchannel('A')) > 127
            straight = edge(kit[bar], 'b' if below else 't', 'l')
            y = gy(r) - g - straight if below else gy(r) + g - straight
            img.alpha_composite(piece, (round(x0), round(y)))
            mid = y + kit[bar].height / 2
            straps += [(x0 + j, mid, True) for j in joints]
            x = x0 + rnd.uniform(STRAP_GAP[0] * 0.7, STRAP_GAP[1] * 0.7) * cell
            while x < x1 - 0.8 * cell:
                straps.append((x, mid, True))
                x += rnd.uniform(*STRAP_GAP) * cell
    for c in range(C + 1):
        r = 0
        while r < R:
            left, right = full(r, c - 1), full(r, c)
            if left == right:
                r += 1; continue
            r0 = r
            while r < R and full(r, c - 1) == left and full(r, c) == right:
                r += 1
            y0 = gy(r0) - (T + g if is_outer(r0, c) else -g)
            y1 = gy(r) + (T + g if is_outer(r, c) else -g)
            bar = 'left' if right else 'right'
            piece, joints = lay(bar, y1 - y0, False)
            straight = edge(kit[bar], 'r' if right else 'l', 't')
            x = gx(c) - g - straight if right else gx(c) + g - straight
            img.alpha_composite(piece, (round(x), round(y0)))
            mid = x + kit[bar].width / 2
            straps += [(mid, y0 + j, False) for j in joints]
            y = y0 + rnd.uniform(STRAP_GAP[0] * 0.7, STRAP_GAP[1] * 0.7) * cell
            while y < y1 - 0.8 * cell:
                straps.append((mid, y, False))
                y += rnd.uniform(*STRAP_GAP) * cell
    for x, y, horizontal in straps:
        s = kit['strap%d' % rnd.randrange(3)]
        if not horizontal:
            s = s.rotate(90, expand=True)
        img.alpha_composite(s, (round(x - s.width / 2), round(y - s.height / 2)))
    # corners on top: inner first, then outer
    found = [(k, r, c) for r in range(R + 1) for c in range(C + 1) for k in corner_kind(full, r, c)]
    for k, r, c in sorted(found, key=lambda f: f[0].startswith('outer')):
        p = kit[k]
        dx, dy = CORNER_FIT[k][2]
        cx, cy = gx(c) + dx * (g + T * 0.45), gy(r) + dy * (g + T * 0.45)   # the middle of the two bars' overlap
        img.alpha_composite(p, (round(cx - p.width / 2), round(cy - p.height / 2)))
    return img


kit = load_kit()
gd = json.load(open(GODOT + '/data/game_data.json', encoding='utf-8'))
for si, st in enumerate(gd['AREAS'][AREA]['boss']['stages']):
    big = build(st['map'].split('|'), kit, 17 + si)
    pal = shared_palette([big], 40)
    ink_rim(to_pixels(big, HI, pal)).save(OUT + '/kit_stage%d.png' % si)
    json.dump({'cell_pt': CELL_PT, 'tail_frames': 0, 'cells_top_left': [MARGIN_PT, MARGIN_PT]},
              open(OUT + '/kit_stage%d.json' % si, 'w'), indent=1)
    print('stage', si, big.size)

# the avatar frame: the same frame round one square opening (a portrait inside), like the serpent's avatar
AVATAR_PT, AVATAR_BAR = 48.0, 14.0
big = build(['.'], load_kit(AVATAR_BAR), 5, AVATAR_PT, AVATAR_BAR)
ink_rim(to_pixels(big, HI, shared_palette([big], 40))).save(OUT + '/avatar.png')
json.dump({'inner_top_left': [MARGIN_PT, MARGIN_PT], 'inner_size': AVATAR_PT}, open(OUT + '/avatar.json', 'w'), indent=1)
print('avatar', big.size)
