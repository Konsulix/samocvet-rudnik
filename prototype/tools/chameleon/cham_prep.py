# The chameleon of the "chameleon" legend (25.11): two scans from Sketchfab (CC BY, see
# godot/assets/specimen/chameleon/CREDITS.md) -> light meshes for the card's corner.
#   chameleon.glb (RISD Nature Lab): a veiled chameleon climbing a twig - the twig cut off by its colour (brown against
#     the animal's grey), both kept, sharing the scan's own texture: cham_body.obj, cham_branch.obj, cham_d.png
#   virtual_taxidermy_of_chamaeleo_calyptratus.glb (yoniren2): its skeleton, no texture - its stand and twig dropped:
#     cham_skel.obj, its own twig cham_skel_branch.obj
# Each one unit long (its largest size), the twig's frame kept for both (the skeleton in its own).
#   blender -b -P cham_prep.py -- <downloads folder> <godot/assets/specimen/chameleon> [preview dir]
import bpy, sys, os, math
import numpy as np
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT = argv[0], argv[1]
PREVIEW = argv[2] if len(argv) > 2 else ""
os.makedirs(OUT, exist_ok=True)

def coords(o):
    a = np.empty(len(o.data.vertices) * 3, dtype=np.float64)
    o.data.vertices.foreach_get("co", a)
    return a.reshape(-1, 3)

def only(o):
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o

def join(objs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs: o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    if len(objs) > 1: bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return o

def weld(o, k=6.0):
    co = coords(o)
    e = [ (co[ed.vertices[0]] - co[ed.vertices[1]]) for ed in list(o.data.edges)[:4000] ]
    edge = float(np.median(np.linalg.norm(np.array(e), axis=1)))
    only(o)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.remove_doubles(threshold=edge / k)
    bpy.ops.object.mode_set(mode="OBJECT")

def decimate(o, tris):
    only(o)
    bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT"); bpy.ops.mesh.quads_convert_to_tris(); bpy.ops.object.mode_set(mode="OBJECT")
    for _ in range(6):
        n = len(o.data.polygons)
        if n <= tris * 1.15: break
        m = o.modifiers.new("d", "DECIMATE"); m.ratio = tris / n
        bpy.ops.object.modifier_apply(modifier=m.name)
    bpy.ops.object.shade_smooth()

def export(o, name):
    only(o)
    bpy.ops.wm.obj_export(filepath=os.path.join(OUT, name + ".obj"), export_selected_objects=True, export_materials=False,
        export_uv=True, export_normals=True, export_triangulated_mesh=True, forward_axis="NEGATIVE_Z", up_axis="Y")
    print("OUT", name, len(o.data.polygons), "tris", tuple(round(x, 3) for x in o.dimensions), flush=True)

def norm(objs):
    # one unit long, the middle of all at the origin
    mins = Vector((1e9,) * 3); maxs = Vector((-1e9,) * 3)
    for o in objs:
        for c in o.bound_box:
            p = o.matrix_world @ Vector(c); mins = Vector(map(min, mins, p)); maxs = Vector(map(max, maxs, p))
    c = (mins + maxs) / 2; s = 1.0 / max(maxs - mins)
    for o in objs:
        me = o.data
        for v in me.vertices: v.co = (v.co - c) * s

# ---- the live one
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.join(SRC, "chameleon.glb"))
hi = join([o for o in bpy.context.scene.objects if o.type == "MESH"])
for o in list(bpy.context.scene.objects):
    if o != hi: bpy.data.objects.remove(o, do_unlink=True)
weld(hi)
img = None
for n in hi.data.materials[0].node_tree.nodes:
    if n.type == "TEX_IMAGE" and n.image: img = n.image; break
W, H = img.size
px = np.empty(W * H * 4, dtype=np.float32); img.pixels.foreach_get(px); px = px.reshape(H, W, 4)
# each face by the colour of the scan under its middle: brown (the twig) or grey (the animal)
uv = np.empty(len(hi.data.loops) * 2, dtype=np.float32); hi.data.uv_layers.active.data.foreach_get("uv", uv); uv = uv.reshape(-1, 2)
twig = np.zeros(len(hi.data.polygons), dtype=bool)
for p in hi.data.polygons:
    u = uv[list(p.loop_indices)].mean(axis=0) % 1.0
    r, g, b, _ = px[min(H - 1, int(u[1] * H)), min(W - 1, int(u[0] * W))]
    mx = max(r, g, b); mn = min(r, g, b)
    twig[p.index] = mx > 0.02 and (mx - mn) / mx > 0.32 and r >= g >= b
# a face's call smoothed by its neighbours (a few passes): spots of brown on the animal, of grey on the twig, go
nbr = {}
for e in hi.data.edges:
    pass
fv = [tuple(p.vertices) for p in hi.data.polygons]
v2f = [[] for _ in hi.data.vertices]
for i, vs in enumerate(fv):
    for v in vs: v2f[v].append(i)
for it in range(4):
    nt = twig.copy()
    for i, vs in enumerate(fv):
        ns = set(j for v in vs for j in v2f[v])
        k = sum(twig[j] for j in ns) / len(ns)
        nt[i] = k > 0.5
    twig = nt
print("twig faces", int(twig.sum()), "of", len(twig), flush=True)
br = hi.copy(); br.data = hi.data.copy(); br.name = "cham_branch"; bpy.context.scene.collection.objects.link(br)
for o, drop in [(hi, twig), (br, ~twig)]:
    only(o)
    bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="DESELECT"); bpy.ops.object.mode_set(mode="OBJECT")
    for p in o.data.polygons: p.select = bool(drop[p.index])
    bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.delete(type="FACE"); bpy.ops.object.mode_set(mode="OBJECT")
hi.name = "cham_body"
norm([hi, br])
decimate(hi, 16000); decimate(br, 2500)
small = img.copy(); small.scale(1024, 1024); small.filepath_raw = os.path.join(OUT, "cham_d.png"); small.file_format = "PNG"; small.save()
export(hi, "cham_body"); export(br, "cham_branch")

# ---- the skeleton
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.join(SRC, "virtual_taxidermy_of_chamaeleo_calyptratus.glb"))
# (its own twig kept: the bones' feet hold it, and no other twig fits their pose — cham_skel_branch)
tw = join([o for o in bpy.context.scene.objects if o.type == "MESH" and o.name.startswith("branche")])
ms = [o for o in bpy.context.scene.objects if o.type == "MESH" and o != tw and not o.name.startswith("pCube") and "lambert2" not in o.name]
sk = join(ms)
for o in list(bpy.context.scene.objects):
    if o not in (sk, tw): bpy.data.objects.remove(o, do_unlink=True)
weld(sk, 10.0)
norm([sk, tw])
decimate(sk, 24000)
export(sk, "cham_skel")
export(tw, "cham_skel_branch")

if PREVIEW:
    for nm in ["cham_body", "cham_branch", "cham_skel"]: pass
