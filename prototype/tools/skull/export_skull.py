"""Skull scan -> godot/assets/specimen/skull.json (one LOD of PolyOne's "Free Pack - Human Skull", CC BY).
usage: py export_skull.py <pack.obj> <out.json> [group=SM_HumanSkull_v1]
Parts: cranium, upper teeth, mandible, lower teeth; triangles, counter-clockwise, Y up, face toward +Z,
centred on x/z, bottom of the jaw at y = 0, units of the source (cm)."""
import sys, json
from collections import defaultdict
src, out = sys.argv[1], sys.argv[2]
want = sys.argv[3] if len(sys.argv) > 3 else "SM_HumanSkull_v1"
V = []; F = []; cur = None
for line in open(src, encoding="utf-8", errors="replace"):
    if line.startswith("v "): V.append(tuple(map(float, line.split()[1:4])))
    elif line.startswith("g "): cur = line.split(None, 1)[1].strip()
    elif line.startswith("f ") and cur == want:
        F.append([int(t.split("/")[0]) - 1 for t in line.split()[1:]])
used = sorted({i for f in F for i in f})
par = {i: i for i in used}
def fd(a):
    while par[a] != a: par[a] = par[par[a]]; a = par[a]
    return a
for f in F:
    for i in f[1:]: par[fd(i)] = fd(f[0])
comp = defaultdict(list)
for i in used: comp[fd(i)].append(i)
cs = sorted(comp.values(), key=len, reverse=True)
cranium, mandible, teeth = cs[0], cs[1], cs[2:]
cx = (min(V[i][0] for i in used) + max(V[i][0] for i in used)) / 2
cz = (min(V[i][2] for i in used) + max(V[i][2] for i in used)) / 2
y0 = min(V[i][1] for i in used)
upper, lower = [], []
def near(t, part):
    # closest approach of a tooth to a bone
    return min(min((V[i][0]-V[j][0])**2+(V[i][1]-V[j][1])**2+(V[i][2]-V[j][2])**2 for j in part[::3]) for i in t[::4])
for t in teeth:
    (upper if near(t, cranium) < near(t, mandible) else lower).extend(t)
def part(ids):
    s = set(ids); remap = {}; vs = []; tris = []
    for i in ids:
        if i not in remap:
            remap[i] = len(remap); x, y, z = V[i]
            vs += [round(x - cx, 4), round(y - y0, 4), round(z - cz, 4)]
    for f in F:
        if f[0] in s:
            for k in range(1, len(f) - 1):
                tris += [remap[f[0]], remap[f[k]], remap[f[k + 1]]]
    return {"v": vs, "f": tris}
P = {"cranium": part(cranium), "teeth_up": part(upper), "mandible": part(mandible), "teeth_low": part(lower)}
for k, p in P.items(): print(k, len(p["v"]) // 3, "verts", len(p["f"]) // 3, "tris")
json.dump({"source": "Free Pack - Human Skull by PolyOne Studio, CC BY 4.0, sketchfab.com/3d-models/16c47e71dc594ae2ac81ed99a8e3f94c (" + want + ")", "parts": P}, open(out, "w"), separators=(",", ":"))
