"""Bake Brontes, the Smith of Etna, for the game (<godot>/assets/boss/brontes/), on the 1-pt grid like the Kraken
(export_kraken.py): every mood x line-boil variants of his three phases (p1_* at work, p2_* he has noticed you, p3_*
forging the thunderbolt; a mood a phase lacks falls back to its base), the forge cavern, his board pieces (billets at
four heats, the anvil: src/brontes/parts.png), the frame round each board (brontes_frame.py, run first into
<boss art>/frame_out_brontes/).
python export_brontes.py <scratch dir> <font> <godot dir>     (ONLY_PARTS=1: the board pieces only)
The boss art (sources, anim.py) is untracked and lives in the main checkout (BOSS_ART).
"""
import sys, json, os, shutil
import numpy as np
from PIL import Image, ImageEnhance, ImageFilter

HERE = os.environ.get('BOSS_ART', 'C:/Users/Максим/Documents/samocvet-rudnik/art/boss')
MY = sys.argv[1:]
src = open(HERE + '/anim.py', encoding='utf-8').read()
sys.argv = ['x'] + MY[:2] + [HERE]
__file__ = HERE + '/anim.py'   # anim.py and what it reads find their files next to it
exec(src[:src.index("# --- boss moods")])
S = HERE + '/src/brontes/'
DST = MY[2].rstrip('/') + '/assets/boss/brontes/'
os.makedirs(DST, exist_ok=True)
SPR_W = 390          # his sprite's width, pt: the whole stage
ONLY_PARTS = os.environ.get('ONLY_PARTS') == '1'


def pic(name, fallback):
    return name if os.path.exists(S + name + '.png') else fallback


def keyed(path):
    """the flat magenta background off, strictly: his thunderbolt's violet glow and lilac hair are near magenta, and the
    other bosses' wide key (layout.key_magenta) took them for background. Only colours close to #FF00FF go, the
    magenta-tinted rim round the figure is pulled to its neighbours' grey"""
    im = np.asarray(Image.open(path).convert('RGB'), dtype=float)
    d = np.sqrt((im[..., 0] - 255) ** 2 + im[..., 1] ** 2 + (im[..., 2] - 255) ** 2)
    bg = d < 120
    alpha = Image.fromarray(np.where(bg, 0, 255).astype(np.uint8)).filter(ImageFilter.MinFilter(3))
    rim = (np.asarray(alpha.filter(ImageFilter.MinFilter(5))) == 0) & (np.asarray(alpha) > 0)
    a = im.copy()
    mn = np.minimum(a[..., 0], a[..., 2])
    spill = rim & (mn - a[..., 1] > 40)
    a[..., 0][spill] = a[..., 1][spill] + (a[..., 0][spill] - mn[spill]) * 0.5 + 20
    a[..., 2][spill] = a[..., 1][spill] + (a[..., 2][spill] - mn[spill]) * 0.5 + 20
    out = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)).convert('RGBA')
    out.putalpha(alpha)
    return out


MOODS = ['idle', 'blink', 'hurt', 'cast', 'scream', 'rage', 'fall', 'defeated']
BOILP = {'idle': (1.6, 3), 'blink': (1.6, 3), 'hurt': (3.0, 1), 'cast': (3.0, 2), 'scream': (5.5, 1), 'rage': (2.4, 2),
         'fall': (3.0, 2), 'defeated': (1.0, 4)}
PHASES = (('', 'p1_'), ('p2_', 'p2_'), ('p3_', 'p3_'))
# his rest on the last board ("rage") is his base there: forging the bolt, roaring
REST = {'rage': 'base'}
moods = {}
if not ONLY_PARTS:
    for prefix, sp in PHASES:
        base = pic(sp + 'base', 'p2_base')
        P = {m: pic(sp + REST.get(m, m), base) for m in MOODS}
        pics = sorted(set(P.values()))
        hi = {n: keyed(S + n + '.png') for n in pics}
        cell = hi[P['idle']].width / SPR_W
        # the last phase is lit two ways (the forge orange, the bolt violet): more colours for it
        pal = shared_palette([hi[n] for n in pics], 88 if sp == "p3_" else 64)
        for mood, p in P.items():
            for b in range(BOIL):
                to_pixels(boil(hi[p], b, BOILP[mood][0]), cell, pal).save(DST + '%s%s_%d.png' % (prefix, mood, b))
            moods[prefix + mood] = list(BOILP[mood])
        print('phase', prefix or 'p1', 'from', pics)

# his board pieces: the four billets (top row of the sheet) and the anvil (bottom), each found as an opaque blob,
# laid on the grid - a billet BILLET_PT wide (a cell is 37 pt), the anvil ANVIL_PT (its 2 x 2 cells)
BILLET_PT, ANVIL_PT = 37, 84
sheet = keyed(S + 'parts.png')
a = np.asarray(sheet.getchannel('A')) > 127
split = sheet.height * 2 // 5
cols = np.nonzero(a[:split].any(0))[0]
runs, start = [], cols[0]
for i in range(1, len(cols)):
    if cols[i] > cols[i - 1] + 12:     # a white-hot billet's loose sparks are a few px apart: one run with it
        runs.append((start, cols[i - 1] + 1)); start = cols[i]
runs.append((start, cols[-1] + 1))
runs = sorted([r for r in runs if r[1] - r[0] > 60], key=lambda r: r[0])[:4]
bil = []
for x0, x1 in runs:
    p = sheet.crop((x0, 0, x1, split))
    bil.append(p.crop(p.getchannel('A').point(lambda v: 255 if v > 127 else 0).getbbox()))
bpal = shared_palette(bil, 40)
w0 = max(p.width for p in bil)
for k, p in enumerate(bil):
    to_pixels(p, w0 / BILLET_PT, bpal).save(DST + 'billet_%d.png' % (k + 1))
anv = sheet.crop((0, split, sheet.width, sheet.height))
anv = anv.crop(anv.getchannel('A').point(lambda v: 255 if v > 127 else 0).getbbox())
to_pixels(anv, anv.width / ANVIL_PT, shared_palette([anv], 40)).save(DST + 'anvil.png')
print('parts', [p.size for p in bil], anv.size)
if ONLY_PARTS:
    sys.exit(0)

# the frames round his three boards, as BossFrame wants them
os.makedirs(DST + 'kit', exist_ok=True)
FR = HERE + '/frame_out_brontes/'
for i in range(3):
    if os.path.exists(FR + 'kit_stage%d.png' % i):
        shutil.copy(FR + 'kit_stage%d.png' % i, DST + 'kit/stage%d.png' % i)
        shutil.copy(FR + 'kit_stage%d.json' % i, DST + 'kit/stage%d.json' % i)
json.dump({'cell_pt': 37.0, 'offset': 0.35, 'canvas': 3.0, 'straight': 10.0, 'tail_frames': 0, 'pieces': False},
          open(DST + 'kit/kit.json', 'w'), indent=1)
if os.path.exists(FR + 'avatar.png'):
    shutil.copy(FR + 'avatar.png', DST + 'kit/avatar.png')
    shutil.copy(FR + 'avatar.json', DST + 'kit/avatar.json')

# the forge cavern
bgsrc = Image.open(S + 'bg.png').convert('RGB')
s = max(W / bgsrc.width, H / bgsrc.height)
bgc = bgsrc.resize((int(bgsrc.width * s), int(bgsrc.height * s)), Image.LANCZOS)
bgc = bgc.crop(((bgc.width - W) // 2, 0, (bgc.width - W) // 2 + W, H))
bgc.save(MY[0] + '/brontes_bg_fit.png')
ImageEnhance.Brightness(pixel_sprite(MY[0] + '/brontes_bg_fit.png', W, 40, keyed=False).convert('RGB')).enhance(0.9).save(DST + 'bg.png')

sw, sh = Image.open(DST + 'idle_0.png').size
json.dump({
    'boil': BOIL, 'moods': moods, 'size': [sw, sh],
    'x': 0, 'sink': 40,
    # on the last board he sits a little lower: the thunderbolt raised over his shoulder clears the top bar
    'sinks': [40, 40, 56],
    'phases': 3,
    'dust_at': [round(sw * 0.5), round(sh * 0.72)], 'neck_at': [round(sw * 0.48), round(sh * 0.5)],
    'head_at': [round(sw * 0.48), round(sh * 0.3)],
    # bits off him as he falls: soot, bronze skin, iron scale
    'pebbles': ['#2a2420', '#7a4a2e', '#4a4a52'],
}, open(DST + 'boss.json', 'w'), indent=1)
print('exported', sw, sh, len(moods), 'moods')
