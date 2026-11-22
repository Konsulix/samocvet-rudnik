"""Bake the plesiosaur's parts for his hunt (GulpView -> godot/assets/boss/plesio/), on the 1-pt grid like the other
bosses; the game draws them pixel for pixel:
  neck.png       one straight piece of neck, NECK_PT thick (repeated end to end and bent round the board by the game)
  head.png       his head in three-quarter view, its neck leaving through the picture's right edge near the bottom;
                 HEAD_K times bigger than its neck would have it (the neck comes out from behind it)
  head_open.png  the same head, jaws wide (the bite) - laid by the same corner as head.png
  maw.png        the mark of his bite on the board: a ring of teeth, MAW_PT wide
plesio.json: where the head's neck leaves its picture (pt), the mouth's place on the head.
python export_plesio.py <scratch dir> <font>
"""
import sys, json, os
import numpy as np
from PIL import Image

HERE = __file__.replace('\\', '/').rsplit('/', 1)[0]
MY = sys.argv[1:]
src = open(HERE + '/anim.py', encoding='utf-8').read()
sys.argv = ['x'] + MY[:2] + [HERE]
exec(src[:src.index("# --- boss moods")])
S = HERE + '/src/plesio/'
DST = HERE + '/../../godot/assets/boss/plesio/'
os.makedirs(DST, exist_ok=True)
NECK_PT = 26         # the neck's thickness, pt
HEAD_K = 1.5         # the head half as big again as its neck would have it: the face of the fight
MAW_PT = 112         # the bite mark's width, pt: two cells of the board and the gums round them
NECK, HEAD, HEAD_OPEN, MAW = 'neck3_a.png', 'head3_a.png', 'head3_open.png', 'maw_a.png'


def solid(rgba):
    return np.asarray(rgba.getchannel('A')) > 127


def box_of(rgba):
    return Image.fromarray((solid(rgba) * 255).astype(np.uint8)).getbbox()


def exit_right(rgba):
    """the neck where it leaves through the right edge: (its middle's y, its thickness), px"""
    al = solid(rgba)
    col = al[:, al.shape[1] - 14: al.shape[1] - 4].mean(axis=1) > 0.5
    ys = np.where(col)[0]
    return (int(ys.min()) + int(ys.max()) + 1) / 2.0, int(ys.max()) + 1 - int(ys.min())


neck = keyed(S + NECK)
al = solid(neck)
rows = np.where(al[:, al.shape[1] // 4: al.shape[1] * 3 // 4].mean(axis=1) > 0.5)[0]
y0, y1 = int(rows.min()), int(rows.max()) + 1
pad = int((y1 - y0) * 0.12)
neck = neck.crop((int(neck.width * 0.06), max(0, y0 - pad), int(neck.width * 0.94), min(neck.height, y1 + pad)))

head = keyed(S + HEAD)
hb = box_of(head)
hbox = (hb[0], hb[1], head.width, hb[3])        # (to the right edge: the neck leaves through it)
head = head.crop(hbox)
hy, ht = exit_right(head)
parts = [neck, head]
head_open = None
if os.path.exists(S + HEAD_OPEN):
    ho = keyed(S + HEAD_OPEN)
    ob = box_of(ho)
    # the shut head's crop, grown to hold the dropped jaw (the game lays both by the shut one's corner)
    obox = (min(hbox[0], ob[0]), min(hbox[1], ob[1]), ho.width, max(hbox[3], ob[3]))
    head_open = ho.crop(obox)
    parts.append(head_open)

pal = shared_palette(parts, 56)
to_pixels(neck, (y1 - y0) / NECK_PT, pal).save(DST + 'neck.png')
hc = ht / (NECK_PT * HEAD_K)
hp = to_pixels(head, hc, pal)
hp.save(DST + 'head.png')
info = {'neck_pt': NECK_PT, 'head_exit_x': hp.width, 'head_exit_y': round(hy / hc, 1), 'mouth_x': 0.2, 'mouth_y': 0.78}
if head_open is not None:
    to_pixels(head_open, hc, pal).save(DST + 'head_open.png')
    info['open_dx'] = round((obox[0] - hbox[0]) / hc, 1)
    info['open_dy'] = round((obox[1] - hbox[1]) / hc, 1)
if os.path.exists(S + MAW):
    maw = keyed(S + MAW)
    maw = maw.crop(box_of(maw))
    to_pixels(maw, maw.width / MAW_PT, shared_palette([maw], 24)).save(DST + 'maw.png')
json.dump(info, open(DST + 'plesio.json', 'w'), indent=1)
for f in ('skull.png', 'jaw.png', 'body.png'):
    for g in (f, f + '.import'):
        if os.path.exists(DST + g): os.remove(DST + g)
print('ok', info, 'head', hp.size)
