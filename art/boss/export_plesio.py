"""Bake the plesiosaur's parts for his hunt (GulpView -> godot/assets/boss/plesio/), on the 1-pt grid like the other
bosses: his neck (one straight drawing, repeated end to end and bent round the board by the game) and his head as two
parts (the skull with the upper jaw, the lower jaw alone: the game hinges it).
python export_plesio.py <scratch dir> <font> [neck png] [head png]
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
HEAD_PT = 104        # the skull's length, pt
NECK = MY[2] if len(MY) > 2 else 'neck_a.png'
HEAD = MY[3] if len(MY) > 3 else 'head_a.png'

neck = keyed(S + NECK)
al = np.asarray(neck.getchannel('A')) > 127
# the rows the neck fills across the picture's middle, and a stretch of it clear of the picture's edges
rows = np.where(al[:, al.shape[1] // 4: al.shape[1] * 3 // 4].mean(axis=1) > 0.5)[0]
y0, y1 = int(rows.min()), int(rows.max()) + 1
pad = int((y1 - y0) * 0.12)
x0, x1 = int(neck.width * 0.06), int(neck.width * 0.94)
neck = neck.crop((x0, max(0, y0 - pad), x1, min(neck.height, y1 + pad)))

head = keyed(S + HEAD)
ha = np.asarray(head.getchannel('A')) > 127
# the two parts lie one over the other with a band of background between: the widest empty band of rows splits them
rows_on = ha.any(axis=1)
ys = np.where(rows_on)[0]
best, cut = 0, 0
run = 0
for y in range(int(ys.min()), int(ys.max()) + 1):
    if not rows_on[y]:
        run += 1
        if run > best: best, cut = run, y
    else:
        run = 0
parts = []
for lo, hi in ((0, cut), (cut, head.height)):
    m = ha[lo:hi]
    yy, xx = np.where(m)
    box = (int(xx.min()), lo + int(yy.min()), int(xx.max()) + 1, lo + int(yy.max()) + 1)
    parts.append((box, head.crop(box)))
(sb, skull), (jb, jaw) = parts

pal = shared_palette([neck, skull, jaw], 48)
cell_n = (y1 - y0) / NECK_PT
to_pixels(neck, cell_n, pal).save(DST + 'neck.png')
cell_h = skull.width / HEAD_PT
sk = to_pixels(skull, cell_h, pal)
jw = to_pixels(jaw, cell_h, pal)
sk.save(DST + 'skull.png')
jw.save(DST + 'jaw.png')
# where the jaw hangs under the skull as drawn (its top left from the skull's, pt) - the generator's gap closed by the game
info = {'neck_pt': NECK_PT, 'head_pt': HEAD_PT, 'skull': list(sk.size), 'jaw': list(jw.size),
        'jaw_dx': round((jb[0] - sb[0]) / cell_h, 1), 'gap': round((jb[1] - sb[3]) / cell_h, 1)}
json.dump(info, open(DST + 'plesio.json', 'w'), indent=1)
print('ok', info, to_pixels(neck, cell_n, pal).size)
