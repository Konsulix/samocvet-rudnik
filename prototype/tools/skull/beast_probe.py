"""Look at a downloaded skull scan: stats and a 3-view workbench render.
usage: blender -b -P beast_probe.py -- <in.glb> <out.png>
Prints: objects, triangles, loose parts (largest first, by vertex count), bounding box."""
import bpy, sys, bmesh, math
from mathutils import Vector
a = sys.argv[sys.argv.index("--") + 1:]
src, out = a[0], a[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
obs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
print("PROBE objects", [(o.name, len(o.data.polygons)) for o in obs])
for o in bpy.context.scene.objects: o.select_set(o.type == "MESH")
bpy.context.view_layer.objects.active = obs[0]
if len(obs) > 1: bpy.ops.object.join()
ob = bpy.context.view_layer.objects.active
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
me = ob.data
bm = bmesh.new(); bm.from_mesh(me)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
bm.verts.ensure_lookup_table()
seen = set(); parts = []
for v in bm.verts:
    if v.index in seen: continue
    st = [v]; seen.add(v.index); n = 0; lo = Vector(v.co); hi = Vector(v.co)
    while st:
        x = st.pop(); n += 1
        lo = Vector(map(min, lo, x.co)); hi = Vector(map(max, hi, x.co))
        for e in x.link_edges:
            y = e.other_vert(x)
            if y.index not in seen: seen.add(y.index); st.append(y)
    parts.append((n, tuple(round(c, 3) for c in lo), tuple(round(c, 3) for c in hi)))
parts.sort(reverse=True)
tris = sum(len(f.verts) - 2 for f in bm.faces)
lo = Vector(map(min, *[v.co for v in bm.verts])) if False else None
xs = [v.co for v in bm.verts]
lo = Vector((min(p.x for p in xs), min(p.y for p in xs), min(p.z for p in xs)))
hi = Vector((max(p.x for p in xs), max(p.y for p in xs), max(p.z for p in xs)))
print("PROBE tris", tris, "verts", len(bm.verts), "parts", len(parts), "bbox", tuple(round(c, 3) for c in lo), tuple(round(c, 3) for c in hi))
for p in parts[:8]: print("PROBE part", p)
bm.free()
# render: front (-Y view in Blender = glTF +Z), side, top
sc = bpy.context.scene
sc.render.engine = "BLENDER_WORKBENCH"
sc.display.shading.light = "MATCAP"
sc.display.shading.color_type = "SINGLE"
sc.render.resolution_x = 360; sc.render.resolution_y = 360
sc.render.film_transparent = False
sc.world = bpy.data.worlds.new("w") if not sc.world else sc.world
c = (lo + hi) / 2; ext = max(hi - lo) * 0.6
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam)
cam.data.type = "ORTHO"; cam.data.ortho_scale = ext * 2; sc.camera = cam
views = {"front": (Vector((0, -1, 0)), (math.pi / 2, 0, 0)), "side": (Vector((1, 0, 0)), (math.pi / 2, 0, math.pi / 2)), "top": (Vector((0, 0, 1)), (0, 0, 0))}
import os
base = out[:-4]
for k, (d, rot) in views.items():
    cam.location = c + d * ext * 4
    cam.rotation_euler = rot
    cam.data.clip_end = ext * 10
    sc.render.filepath = base + "_" + k + ".png"
    bpy.ops.render.render(write_still=True)
