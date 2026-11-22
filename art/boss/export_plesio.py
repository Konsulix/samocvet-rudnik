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
NECK, HEAD, BODY, MAW = 'neck3_a.png', 'head3_a.png', 'body_b.png', 'maw_a.png'


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
hy, ht = exit_right(head.crop(hbox))
# his moods: the same head edited (gen_edit.sh), each cut to its own box (a dropped jaw makes it taller) and laid
# by the plain head's corner: its top left's shift from the plain one's is kept (pt)
MOODS = {'head': HEAD, 'head_blink': 'head3_blink.png', 'head_hurt': 'head3_hurt.png', 'head_glare': 'head3_glare.png', 'head_open': 'head3_open.png'}
pics = {}
for nm, f in MOODS.items():
    if not os.path.exists(S + f): continue
    im = keyed(S + f)
    ob = box_of(im)
    box = (min(hbox[0], ob[0]), min(hbox[1], ob[1]), im.width, max(hbox[3], ob[3]))
    pics[nm] = (box, im.crop(box))
body = keyed(S + BODY)
bb = box_of(body)
body = body.crop((bb[0], bb[1], body.width, bb[3]))
by, bt = exit_right(body)

pal = shared_palette([neck, body] + [v[1] for v in pics.values()], 60)
to_pixels(neck, (y1 - y0) / NECK_PT, pal).save(DST + 'neck.png')
hc = ht / (NECK_PT * HEAD_K)
info = {'neck_pt': NECK_PT, 'head_k': HEAD_K, 'head_exit_y': round((hy) / hc, 1), 'mouth_x': 0.2, 'mouth_y': 0.78, 'moods': {}}
for nm, (box, im) in pics.items():
    px = to_pixels(im, hc, pal)
    px.save(DST + nm + '.png')
    info['moods'][nm] = [round((box[0] - hbox[0]) / hc, 1), round((box[1] - hbox[1]) / hc, 1)]
    if nm == 'head': info['head_exit_x'] = px.width
bc = bt / NECK_PT
bp = to_pixels(body, bc, pal)
bp.save(DST + 'body.png')
info['body_exit_x'] = bp.width
info['body_exit_y'] = round(by / bc, 1)
if os.path.exists(S + MAW):
    maw = keyed(S + MAW)
    maw = maw.crop(box_of(maw))
    to_pixels(maw, maw.width / MAW_PT, shared_palette([maw], 24)).save(DST + 'maw.png')
json.dump(info, open(DST + 'plesio.json', 'w'), indent=1)
for f in ('skull.png', 'jaw.png'):
    for g in (f, f + '.import'):
        if os.path.exists(DST + g): os.remove(DST + g)
print('ok', info, 'body', bp.size)
