"""An animal skull scan (GLB, RISD Nature Lab & co., CC BY) -> godot/assets/specimen/beasts/<id>.json for SpecSkull.
usage: blender -b -P beast_prep.py -- <beasts.json> <id> <src dir> <out dir> [grid dir]

The config (beasts.json, one entry per beast):
  src      file name of the GLB in <src dir>
  rot      euler XYZ, degrees (Blender frame): turns the scan anatomical — snout toward -Y, top of the head +Z
  jaw      true: the second largest loose part is the mandible (only scans with a separate jaw)
  horns    cuts that take the horns / antlers off the skull: [[point, normal], ...] in the normalised anatomical frame
           (Godot axes: x right, y up, z toward the snout); faces beyond a cut plane, on its side of the head
           (sign of point.x), go to the horns
  size     largest size of the skull without horns, generator units (the human skull ~1.3)
  display  euler XYZ degrees (Godot frame) applied last: how the skull is held to the viewer (a mounted deer face-on,
           snout down; a wolf in three-quarters)
  tris     [skull, jaw, horns] triangle budgets
  lm       landmarks, passed on (Godot frame, after display): eye {front, deep, r} of the +x eye, crest [A, B],
           side [A, B] (+x side), flags
Output parts: cranium, mandible (maybe), horns (maybe, with "u": distance from the base along the horn, 0..1 per horn),
teeth none (the scans' teeth are fused to the bone). Y up, face toward +Z (after display), triangles counter-clockwise.
With [grid dir]: front / side / top renders with a 0.1 grid in Godot coordinates, for reading landmarks."""
import bpy, bmesh, sys, json, math, os, heapq
from mathutils import Vector, Euler, Matrix

a = sys.argv[sys.argv.index("--") + 1:]
cfg_all = json.load(open(a[0], encoding="utf-8"))
bid = a[1]
cfg = cfg_all[bid]
src = os.path.join(a[2], cfg["src"])
out_dir = a[3]
grid_dir = a[4] if len(a) > 4 else ""

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
obs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
for o in bpy.context.scene.objects: o.select_set(o.type == "MESH")
bpy.context.view_layer.objects.active = obs[0]
if len(obs) > 1: bpy.ops.object.join()
ob = bpy.context.view_layer.objects.active
for o in list(bpy.context.scene.objects):
    if o != ob: bpy.data.objects.remove(o, do_unlink=True)
ob.parent = None
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
me = ob.data
# no materials, no uv: just the shape
me.materials.clear()

def bm_of(m):
    b = bmesh.new(); b.from_mesh(m); return b

# weld, drop loose crumbs (decimating them is a waste)
b = bm_of(me)
bmesh.ops.remove_doubles(b, verts=b.verts, dist=1e-5 * max(ob.dimensions))
b.to_mesh(me); b.free()

def loose_parts(b):
    b.verts.ensure_lookup_table()
    seen = set(); parts = []
    for v in b.verts:
        if v.index in seen: continue
        st = [v]; seen.add(v.index); comp = []
        while st:
            x = st.pop(); comp.append(x)
            for e in x.link_edges:
                y = e.other_vert(x)
                if y.index not in seen: seen.add(y.index); st.append(y)
        parts.append(comp)
    parts.sort(key=len, reverse=True)
    return parts

b = bm_of(me)
parts = loose_parts(b)
nv = len(b.verts)
minf = cfg.get("min_part", 0.002)
drop = [v for p in parts if len(p) < nv * minf for v in p]
jaw_ids = set()
if cfg.get("jaw") and len(parts) > 1:
    jaw_ids = {v.index for v in parts[1]}
# mark the jaw in a face layer so it survives decimation
lay = b.faces.layers.int.new("part")
for f in b.faces:
    f[lay] = 1 if f.verts[0].index in jaw_ids else 0
bmesh.ops.delete(b, geom=drop, context="VERTS")
print("PREP parts", len(parts), "kept verts", len(b.verts), "of", nv, "jaw", len(jaw_ids))
b.to_mesh(me); b.free()

# anatomical: snout -Y, top +Z
r = cfg.get("rot", [0, 0, 0])
ob.rotation_euler = Euler([math.radians(x) for x in r], "XYZ")
bpy.ops.object.transform_apply(rotation=True)

def decimate(target):
    t = len(me.polygons)
    if t <= target: return
    md = ob.modifiers.new("d", "DECIMATE")
    md.ratio = target / t
    md.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=md.name)

budget = cfg.get("tris", [12000, 3500, 5000])
# a first coarse pass (cutting a million triangles is slow), finer budgets per part later
decimate(sum(budget) * 3)

# normalise in the Godot frame: G = (x, z, -y)
def to_g(v): return Vector((v.x, v.z, -v.y))
def to_b(g): return Vector((g.x, -g.z, g.y))
b = bm_of(me)
lay = b.faces.layers.int.get("part")
pts = [to_g(v.co) for v in b.verts]
lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
# horns are cut in the normalised frame, but the normalisation should not count them: a first guess from the whole,
# then measured again on the skull alone
# fwd / up: where the snout and the top of the head point after rot (read off the renders): turned to +Z / +Y
F = Vector(cfg.get("fwd", [0, 0, 1])).normalized()
Up = Vector(cfg.get("up", [0, 1, 0]))
Up = (Up - F * Up.dot(F)).normalized()
Rt = Matrix((Up.cross(F).normalized(), Up, F))   # rows: x, y, z of the new frame in the old one
for v in b.verts: v.co = to_b(Rt @ to_g(v.co))
pts = [to_g(v.co) for v in b.verts]
lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
cen = (lo + hi) / 2
k = cfg.get("size", 1.45) / max(hi - lo)
for v in b.verts:
    g = (to_g(v.co) - cen) * k
    v.co = to_b(g)

# the head's plane of symmetry: the reflection that best maps the scan onto itself (normal near x, searched over
# small turns about y and z), then turned to x = 0 — a skull read a little crooked off the renders comes out straight
if cfg.get("sym", True):
    from mathutils.kdtree import KDTree
    import random
    random.seed(1)
    pts = [to_g(v.co) for v in b.verts]
    samp = random.sample(pts, min(2500, len(pts)))
    kd = KDTree(len(pts))
    for i, p in enumerate(pts): kd.insert(p, i)
    kd.balance()
    def score(n):
        d = sum(p.dot(n) for p in samp) / len(samp)
        s = 0.0
        for p in samp:
            q = p - n * (2 * (p.dot(n) - d))
            s += kd.find(q)[2]
        return s / len(samp), d
    def nrm(yaw, roll):
        return (Matrix.Rotation(math.radians(yaw), 3, "Y") @ Matrix.Rotation(math.radians(roll), 3, "Z") @ Vector((1, 0, 0))).normalized()
    best = (score(nrm(0, 0))[0], 0, 0)
    for step, span in [(6, 48), (2, 6), (0.5, 2)]:
        y0, r0 = best[1], best[2]
        ys = [y0 + i * step for i in range(-int(span / step), int(span / step) + 1)]
        for yy in ys:
            for rr in [r0 + i * step for i in range(-int(span / step), int(span / step) + 1)]:
                sc = score(nrm(yy, rr))[0]
                if sc < best[0]: best = (sc, yy, rr)
    n = nrm(best[1], best[2]); d = score(n)[1]
    q = n.rotation_difference(Vector((1, 0, 0))).to_matrix()
    print("PREP symmetry yaw", best[1], "roll", best[2], "score", round(best[0], 4))
    for v in b.verts:
        g = to_g(v.co)
        g = q @ (g - n * d)
        v.co = to_b(g)

# pitch: the snout raised (-) or lowered (+), degrees about x, for a scan that lies nose up or down
if cfg.get("pitch", 0):
    Rp = Matrix.Rotation(math.radians(cfg["pitch"]), 3, "X")
    for v in b.verts: v.co = to_b(Rp @ to_g(v.co))

# the horns: cut along each plane, faces beyond it (on its side of the head) become horn
horn_lay = b.faces.layers.int.new("horn")
for hi_, (p, n) in enumerate(cfg.get("horns", [])):
    pg, ng = Vector(p), Vector(n).normalized()
    pb, nb = to_b(pg), to_b(ng)
    geom = b.verts[:] + b.edges[:] + b.faces[:]
    bmesh.ops.bisect_plane(b, geom=geom, dist=1e-6, plane_co=pb, plane_no=nb)
    # beyond the plane, the piece holding the point farthest along it (the tip): flood over faces across edges
    b.faces.ensure_lookup_table()
    sx = 1 if pg.x >= 0 else -1
    beyond = {f.index for f in b.faces if (to_g(f.calc_center_median()) - pg).dot(ng) > 0
              and (to_g(f.calc_center_median()).x * sx > 0 or abs(pg.x) < 1e-6) and f[horn_lay] == 0}
    if not beyond: continue
    seed = max(beyond, key=lambda i: (to_g(b.faces[i].calc_center_median()) - pg).dot(ng))
    st = [seed]; got = {seed}
    while st:
        f = b.faces[st.pop()]
        for e in f.edges:
            for f2 in e.link_faces:
                if f2.index in beyond and f2.index not in got:
                    got.add(f2.index); st.append(f2.index)
    for i in got: b.faces[i][horn_lay] = hi_ + 1
    print("PREP horn", hi_, len(got), "faces of", len(beyond), "beyond")
b.faces.ensure_lookup_table()

# re-normalise on the skull alone
skull_pts = [to_g(v.co) for f in b.faces if f[horn_lay] == 0 for v in f.verts]
lo = Vector((min(p.x for p in skull_pts), min(p.y for p in skull_pts), min(p.z for p in skull_pts)))
hi = Vector((max(p.x for p in skull_pts), max(p.y for p in skull_pts), max(p.z for p in skull_pts)))
cen = (lo + hi) / 2
k2 = cfg.get("size", 1.45) / max(hi - lo)
disp = Euler([math.radians(x) for x in cfg.get("display", [0, 0, 0])], "XYZ").to_matrix()
for v in b.verts:
    g = (to_g(v.co) - Vector((cen.x, cen.y, cen.z))) * k2
    v.co = to_b(disp @ g)
b.to_mesh(me); b.free()
print("PREP scale", k * k2)

# split into objects by part (0 skull, 1 jaw, 2 horns) and decimate each to its budget
def split(keep):
    o2 = ob.copy(); o2.data = ob.data.copy(); bpy.context.scene.collection.objects.link(o2)
    bb = bm_of(o2.data)
    pl = bb.faces.layers.int.get("part"); hl = bb.faces.layers.int.get("horn")
    dead = [f for f in bb.faces if not keep(f[pl], f[hl])]
    bmesh.ops.delete(bb, geom=dead, context="FACES")
    loose = [v for v in bb.verts if not v.link_faces]
    bmesh.ops.delete(bb, geom=loose, context="VERTS")
    bb.to_mesh(o2.data); bb.free()
    return o2

objs = {"cranium": split(lambda p, h: p == 0 and h == 0)}
if cfg.get("jaw"): objs["mandible"] = split(lambda p, h: p == 1 and h == 0)
if cfg.get("horns"): objs["horns"] = split(lambda p, h: h > 0)
bpy.data.objects.remove(ob, do_unlink=True)
tb = {"cranium": budget[0], "mandible": budget[1], "horns": budget[2]}
for name, o in objs.items():
    for s in bpy.context.scene.objects: s.select_set(False)
    o.select_set(True); bpy.context.view_layer.objects.active = o
    globals()["ob"] = o; globals()["me"] = o.data
    decimate(tb[name])
    bb = bm_of(o.data)
    bmesh.ops.remove_doubles(bb, verts=bb.verts, dist=1e-5)
    bmesh.ops.triangulate(bb, faces=bb.faces)
    bb.to_mesh(o.data); bb.free()

def dump(o, horn=False):
    bb = bm_of(o.data)
    bb.verts.ensure_lookup_table(); bb.faces.ensure_lookup_table()
    vs = []
    for v in bb.verts:
        g = to_g(v.co); vs += [round(g.x, 4), round(g.y, 4), round(g.z, 4)]
    fs = []
    for f in bb.faces:
        fs += [v.index for v in f.verts]
    out = {"v": vs, "f": fs}
    if horn:
        # distance from the base along the horn (Dijkstra over the edges from the open rim where it was cut), 0..1 per horn
        hl = bb.faces.layers.int.get("horn")
        rim = [v for v in bb.verts if v.is_boundary]
        dist = [math.inf] * len(bb.verts)
        q = []
        for v in rim:
            dist[v.index] = 0.0; heapq.heappush(q, (0.0, v.index))
        while q:
            d, i = heapq.heappop(q)
            if d > dist[i]: continue
            for e in bb.verts[i].link_edges:
                j = e.other_vert(bb.verts[i]).index
                nd = d + e.calc_length()
                if nd < dist[j]:
                    dist[j] = nd; heapq.heappush(q, (nd, j))
        # per horn island: the farthest point is 1
        comps = loose_parts(bb)
        u = [0.0] * len(bb.verts)
        lens = []
        for c in comps:
            m = max((dist[v.index] for v in c if dist[v.index] < math.inf), default=1.0) or 1.0
            lens.append(round(m, 4))
            for v in c: u[v.index] = round(min(1.0, dist[v.index] / m) if dist[v.index] < math.inf else 1.0, 3)
        out["u"] = u
        out["len"] = lens
    print("PREP part", o.name, len(bb.verts), "verts", len(bb.faces), "tris")
    bb.free()
    return out

# the eye socket, found on the skull (as SpecSkullFx.eye on the human one): rays along the socket's axis (lm "eye":
# [rough middle, axis out of it], anatomical frame) over a disc round it; the ones that fall deep are the opening —
# its middle and radius; the rim where the shallow ones stop
from mathutils.bvhtree import BVHTree
def find_eye(o, c, ax):
    bb = bm_of(o.data); tree = BVHTree.FromBMesh(bb); bb.free()
    c = to_b(disp @ Vector(c)); a = to_b(disp @ Vector(ax)).normalized()
    u = a.cross(Vector((0, 0, 1)) if abs(a.z) < 0.9 else Vector((1, 0, 0))).normalized(); w = a.cross(u)
    hits = []
    R = cfg.get("eye_search", 0.2); n = 24
    for i in range(-n, n + 1):
        for j in range(-n, n + 1):
            l = (u * i + w * j) * (R / n)
            if l.length > R: continue
            org = c + l + a * 0.6
            loc, nor, idx, dist = tree.ray_cast(org, -a, 2.0)
            dd = (loc - c).dot(a) if loc else -0.6
            hits.append((l, max(dd, -0.6)))
    top = max(h[1] for h in hits)
    deep = [h for h in hits if h[1] < top - cfg.get("eye_drop", 0.08)]
    if len(deep) < 4: print("PREP eye: none"); return None
    m = sum((h[0] for h in deep), Vector()) / len(deep)
    # keep the deep ones round the middle (one opening, not the gaps beside it)
    deep = [h for h in deep if (h[0] - m).length < R * 0.7]
    m = sum((h[0] for h in deep), Vector()) / len(deep)
    zd = sum(h[1] for h in deep) / len(deep)
    rad = sorted((h[0] - m).length for h in deep)[int(len(deep) * 0.8)]
    front = c + m + a * (zd + (top - zd) * 0.8)
    back = c + m + a * zd
    g1, g2 = to_g(front), to_g(back)
    print("PREP eye front", [round(x, 3) for x in g1], "deep", [round(x, 3) for x in g2], "r", round(rad, 3), "top", round(top, 3), "zd", round(zd, 3))
    return [round(x, 4) for x in g1], [round(x, 4) for x in g2], round(min(rad, 0.16), 4)
eye = None
if "eye" in cfg.get("lm", {}):
    ec, ea = cfg["lm"]["eye"]
    eye = find_eye(objs["cranium"], ec, ea)

P = {}
for name, o in objs.items(): P[name] = dump(o, name == "horns")
src_line = cfg.get("credit", cfg["src"])
os.makedirs(out_dir, exist_ok=True)
# landmarks are read off the renders without display (the anatomical frame): turned with the skull
lm = json.loads(json.dumps(cfg.get("lm", {})))
def tv(a): w = disp @ Vector(a); return [round(w.x, 4), round(w.y, 4), round(w.z, 4)]
lm.pop("eye", None)
if eye: lm["eye_front"], lm["eye_deep"], lm["eye_r"] = eye
for key in ["crest", "side"]:
    if key in lm: lm[key][0] = tv(lm[key][0]); lm[key][1] = tv(lm[key][1])
res = {"source": src_line, "parts": P, "lm": lm, "flags": cfg.get("flags", [])}
json.dump(res, open(os.path.join(out_dir, bid + ".json"), "w"), separators=(",", ":"))

if grid_dir:
    os.makedirs(grid_dir, exist_ok=True)
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = "OBJECT"
    for name, o in objs.items():
        o.color = {"cranium": (0.85, 0.82, 0.75, 1), "mandible": (0.6, 0.75, 0.9, 1), "horns": (0.9, 0.6, 0.3, 1)}[name]
    sc.render.resolution_x = 640; sc.render.resolution_y = 640
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam)
    cam.data.type = "ORTHO"; cam.data.ortho_scale = 3.2; sc.camera = cam
    cam.data.clip_start = 0.01; cam.data.clip_end = 100
    # Godot views: front = from +Z (Blender -Y), side = from +X, top = from +Y (Blender +Z)
    views = {"front": (Vector((0, -10, 0)), (math.pi / 2, 0, 0)), "side": (Vector((10, 0, 0)), (math.pi / 2, 0, math.pi / 2)),
             "top": (Vector((0, 0, 10)), (0, 0, 0))}
    for kname, (loc, rot) in views.items():
        cam.location = loc; cam.rotation_euler = rot
        sc.render.filepath = os.path.join(grid_dir, bid + "_" + kname + ".png")
        bpy.ops.render.render(write_still=True)
