"""A beast's head for its ghost (SpecBeastFx "ghost"): cut out of a low-poly animal (OBJ, y up, z forward: Quaternius,
CC0) — the faces in front of the neck (their middle past cut_z, above min_y) — turned so the head's own axis (the neck
cut's middle to the tip of the nose) lies along +Z (a horse's head hangs down 45°), and saved as compact JSON.
usage: py ghost_prep.py <in.obj> <out.json> <cut_z> [min_y] [credit]
"u" per vertex: 0 at the neck .. 1 at the nose (the shader fades it out at the neck). The game fits it over the skull,
nose to nose, along the skull's own axis."""
import sys, json, math
src, out, cut = sys.argv[1], sys.argv[2], float(sys.argv[3])
min_y = float(sys.argv[4]) if len(sys.argv) > 4 and sys.argv[4] != '-' else -1e9
credit = sys.argv[5] if len(sys.argv) > 5 else ''
v, f = [], []
for l in open(src, encoding='utf-8', errors='ignore'):
    if l.startswith('v '): v.append(list(map(float, l.split()[1:4])))
    elif l.startswith('f '):
        ids = [int(t.split('/')[0]) - 1 for t in l.split()[1:]]
        for k in range(1, len(ids) - 1): f.append([ids[0], ids[k], ids[k + 1]])
keep = [t for t in f if sum(v[i][2] for i in t) / 3 > cut and min(v[i][1] for i in t) > min_y]
used = sorted({i for t in keep for i in t})
remap = {o: n for n, o in enumerate(used)}
vv = [v[i] for i in used]
zmax = max(p[2] for p in vv); zmin = min(p[2] for p in vv); L = zmax - zmin
mean = lambda ps: [sum(p[i] for p in ps) / len(ps) for i in range(3)]
tip = mean([p for p in vv if p[2] > zmax - L * 0.06])
back = mean([p for p in vv if p[2] < zmin + L * 0.2])
# the head's axis, pitched down by a: turn it up about x so it lies along +z
a = math.atan2(back[1] - tip[1], tip[2] - back[2])
ca, sa = math.cos(a), math.sin(a)
rot = lambda p: [p[0], p[1] * ca + p[2] * sa, -p[1] * sa + p[2] * ca]
vr = [rot(p) for p in vv]
tz = rot(tip)[2]; bz = rot(back)[2]
u = [round(min(1.0, max(0.0, (p[2] - bz) / max(1e-6, tz - bz))), 3) for p in vr]
json.dump({'v': [round(c, 4) for p in vr for c in p], 'f': [remap[i] for t in keep for i in t], 'u': u, 'source': credit}, open(out, 'w'))
print('ghost', out, len(vv), 'verts', len(keep), 'tris', 'pitch', round(math.degrees(a), 1))
