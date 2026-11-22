"""Bake the plesiosaur's parts for his hunt (GulpView -> godot/assets/boss/plesio/), on the 1-pt grid like the other
bosses, all at one scale - the neck NECK_PT thick everywhere, so the parts meet:
  neck.png       one straight piece of neck (repeated end to end and bent round the board by the game)
  head.png       his head in three-quarter view, its neck leaving through the picture's right edge near the bottom
  head_open.png  the same head, jaws wide (the bite) - the same crop as head.png
  body.png       his body with a flipper, its neck leaving through the right edge near the top
plesio.json: where each neck leaves its picture (pt), the mouth's place on the head.
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
NECK, HEAD, HEAD_OPEN, BODY = 'neck3_a.png', 'head3_a.png', 'head3_open.png', 'body_b.png'


def solid(rgba):
    return np.asarray(rgba.getchannel('A')) > 127


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
hbox = Image.fromarray((solid(head) * 255).astype(np.uint8)).getbbox()
hbox = (hbox[0], hbox[1], head.width, hbox[3])        # (to the right edge: the neck leaves through it)
head = head.crop(hbox)
hy, ht = exit_right(head)
body = keyed(S + BODY)
bbox = Image.fromarray((solid(body) * 255).astype(np.uint8)).getbbox()
bbox = (bbox[0], bbox[1], body.width, bbox[3])
body = body.crop(bbox)
by, bt = exit_right(body)
parts = [neck, head, body]
head_open = None
if os.path.exists(S + HEAD_OPEN):
    ho = keyed(S + HEAD_OPEN)
    obox = Image.fromarray((solid(ho) * 255).astype(np.uint8)).getbbox()
    # the same crop as the shut head, grown to hold the dropped jaw (the game lays both by their top right)
    obox = (min(hbox[0], obox[0]), min(hbox[1], obox[1]), ho.width, max(hbox[3], obox[3]))
    head_open = ho.crop(obox)
    parts.append(head_open)

pal = shared_palette(parts, 56)
to_pixels(neck, (y1 - y0) / NECK_PT, pal).save(DST + 'neck.png')
hc = ht / NECK_PT
hp = to_pixels(head, hc, pal)
hp.save(DST + 'head.png')
bc = bt / NECK_PT
bp = to_pixels(body, bc, pal)
bp.save(DST + 'body.png')
info = {'neck_pt': NECK_PT,
        'head_exit_x': hp.width, 'head_exit_y': round(hy / hc, 1),
        'body_exit_x': bp.width, 'body_exit_y': round(by / bc, 1),
        'mouth_x': 0.2, 'mouth_y': 0.78}
if head_open is not None:
    op = to_pixels(head_open, hc, pal)
    op.save(DST + 'head_open.png')
    # how far its top left lies from the shut head's (pt): both are laid by the neck's end
    info['open_dx'] = round((obox[0] - hbox[0]) / hc, 1)
    info['open_dy'] = round((obox[1] - hbox[1]) / hc, 1)
json.dump(info, open(DST + 'plesio.json', 'w'), indent=1)
for f in ('skull.png', 'jaw.png'):
    if os.path.exists(DST + f): os.remove(DST + f)
    if os.path.exists(DST + f + '.import'): os.remove(DST + f + '.import')
print('ok', info, 'head', hp.size, 'body', bp.size)
