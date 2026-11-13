# Butterfly models for SpecButterfly from scans of pinned specimens (ffishAsia-and-floraZia, CC0 — see
# godot/assets/specimen/butterflies/CREDITS.md): a scan is still, its wings spread flat, so this gives it what an
# animated model has — two wing bones on a hinge along the body and a wingbeat clip "fly" — and makes it light.
#   blender -b -P butterfly_prep.py -- <folder with the downloads> <godot/assets/specimen/butterflies> [name,...] [preview dir]
# Out: <name>.glb (mesh, skeleton Root / LeftUpperWing / RightUpperWing, clip "fly"), its colour and relief in two
# 1024 px textures inside it. The specimen is turned so (in Blender, Z up): head +X, back +Z, wings along Y — in the .glb,
# Y up: head +X, back +Y, wings along Z; wingspan SPAN units.
# How the scan lies is found by itself (wing plane — its thinnest axis; left-right — the axis it is mirror-even about;
# the head — the end with the longer forewings; the back — the side the legs are not on); `flip` (head, back) by hand.
import bpy, sys, os, math
import numpy as np
from mathutils import Vector, Matrix

argv = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT = argv[0], argv[1]
ONLY = [s for s in argv[2].split(",") if s] if len(argv) > 2 and argv[2] != "-" else []
PREVIEW = argv[3] if len(argv) > 3 else ""
TEX = 1024
SPAN = 2.5
TRIS = 7000

# name: the kind's file; file: the download; flip: "head" / "back" / both, when the guess is wrong
MODELS = [
    dict(name="chestnut", file="Chestnut Tiger Butterfly/cc0____chestnut_tiger_butterfly.glb"),
    dict(name="chestnut_b", file="Chestnut Tiger Butterfly/cc0____chestnut_tiger_butterfly (1).glb"),
    dict(name="chestnut_c", file="Chestnut Tiger Butterfly/cc0____chestnut_tiger_butterfly (2).glb"),
    dict(name="chestnut_d", file="Chestnut Tiger Butterfly/cc0____chestnut_tiger_butterfly (3).glb"),
    dict(name="bluebottle", file="Common Bluebottle/cc0___common_bluebottle_g._sarpedon.glb"),
    dict(name="bluebottle_b", file="Common Bluebottle/cc0___common_bluebottle_g._sarpedon (1).glb"),
    dict(name="silkmoth", file="Oak Silkmoth/cc0___oak_silkmoth_antheraea_yamamai.glb"),
    dict(name="silkmoth_b", file="Oak Silkmoth/cc0___oak_silkmoth_antheraea_yamamai (1).glb"),
    dict(name="spangle", file="cc0____long_tail_spangle_p._macilentus.glb"),
]

def coords(o):
    a = np.empty(len(o.data.vertices) * 3, dtype=np.float64)
    o.data.vertices.foreach_get("co", a)
    return a.reshape(-1, 3)

def tri_idx(o):
    o.data.calc_loop_triangles()
    f = np.empty(len(o.data.loop_triangles) * 3, dtype=np.int64)
    o.data.loop_triangles.foreach_get("vertices", f)
    return f.reshape(-1, 3)

def only(o):
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o

def load(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    # (the scanner's colour cube: a box of 24 corners of its own)
    for o in list(meshes):
        if len(o.data.vertices) <= 24:
            meshes.remove(o)
            bpy.data.objects.remove(o, do_unlink=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    if len(meshes) > 1:
        bpy.ops.object.join()
    hi = bpy.context.view_layer.objects.active
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for o in list(bpy.context.scene.objects):
        if o != hi:
            bpy.data.objects.remove(o, do_unlink=True)
    co = coords(hi)
    f = tri_idx(hi)
    pick = f[np.linspace(0, len(f) - 1, min(len(f), 4000)).astype(np.int64)]
    edge = float(np.median(np.linalg.norm(co[pick[:, 0]] - co[pick[:, 1]], axis=1)))
    only(hi)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.remove_doubles(threshold=edge / 6.0)
    bpy.ops.object.mode_set(mode="OBJECT")
    return hi

def _mirror_err(p, axis, c):
    # how far the scan is from its own mirror image across the plane through c normal to `axis` (a sample)
    from mathutils.kdtree import KDTree
    s = p[np.linspace(0, len(p) - 1, min(len(p), 6000)).astype(np.int64)]
    kd = KDTree(len(s))
    for i, v in enumerate(s):
        kd.insert(v, i)
    kd.balance()
    m = s - 2.0 * np.outer((s - c) @ axis, axis)
    return float(np.mean([kd.find(v)[2] for v in m[::4]]))

def orient(o, flip):
    p = coords(o)
    c = p.mean(axis=0)
    w, v = np.linalg.eigh(np.cov((p - c).T))
    up = v[:, 0]                       # the thinnest: across the wings
    a, b = v[:, 1], v[:, 2]
    # left-right: the axis the scan is mirror-even about (its mirror across the plane normal to it lands on itself)
    best = None
    for ax in (a, b):
        # (the plane through the middle of the scan's extent along that axis — the body)
        t = p @ ax
        cc = c + ax * ((t.min() + t.max()) * 0.5 - c @ ax)
        e = _mirror_err(p, ax, cc)
        if best is None or e < best[0]:
            best = (e, ax, cc)
    lr = best[1]
    fwd = b if lr is a else a
    mid = best[2]
    # the head: the forewings reach further out sideways than the hindwings
    s = (p - mid) @ fwd
    side = np.abs((p - mid) @ lr)
    front = side[s > 0].max() if (s > 0).any() else 0
    back = side[s < 0].max() if (s < 0).any() else 0
    if back > front:
        fwd = -fwd
    # the back: the legs hang on the belly side — the scan reaches further from the wing plane there
    h = (p - mid) @ up
    if abs(h.min()) < abs(h.max()):
        up = -up
    if "head" in flip: fwd = -fwd
    if "back" in flip: up = -up
    lr = np.cross(up, fwd)             # (right-handed: X head, Y the left wing, Z back)
    R = Matrix(((*fwd, 0), (*lr, 0), (*up, 0), (0, 0, 0, 1)))
    # the body's middle at the origin; wingspan SPAN
    sp = float(((p - mid) @ lr).max() - ((p - mid) @ lr).min())
    k = SPAN / sp
    o.data.transform(Matrix.Translation(Vector(-mid)))
    o.data.transform(R)
    o.data.transform(Matrix.Scale(k, 4))
    o.data.update()
    q = coords(o)
    # (the body's line across the scan: halfway between its outermost points along X, at the narrow middle)
    body = q[np.abs(q[:, 1]) < 0.05 * SPAN]
    o.data.transform(Matrix.Translation(Vector((0.0, 0.0, -float(np.median(body[:, 2])) if len(body) else 0.0))))
    o.data.update()
    return best[0] / sp

def image_mat(o, name, colour):
    img = bpy.data.images.new(name, TEX, TEX, alpha=False)
    if not colour:
        img.colorspace_settings.name = "Non-Color"
    mat = o.data.materials[0] if o.data.materials else None
    if mat is None:
        mat = bpy.data.materials.new("bake")
        mat.use_nodes = True
        o.data.materials.append(mat)
    nt = mat.node_tree
    node = nt.nodes.new("ShaderNodeTexImage")
    node.image = img
    for n in nt.nodes:
        n.select = False
    node.select = True
    nt.nodes.active = node
    return img, mat, node

def as_light(o):
    for mat in o.data.materials:
        if not mat or not mat.use_nodes:
            continue
        nt = mat.node_tree
        tex = None
        for link in nt.links:
            if link.to_socket.name in ("Base Color", "Color", "Emission", "Emission Color") and link.from_node.type == "TEX_IMAGE":
                tex = link.from_node
                if link.to_socket.name == "Base Color":
                    break
        if tex is None:
            tex = next((n for n in nt.nodes if n.type == "TEX_IMAGE" and n.image and n.image.colorspace_settings.name != "Non-Color"), None)
        out = next((n for n in nt.nodes if n.type == "OUTPUT_MATERIAL"), None) or nt.nodes.new("ShaderNodeOutputMaterial")
        em = nt.nodes.new("ShaderNodeEmission")
        if tex is not None:
            nt.links.new(tex.outputs["Color"], em.inputs["Color"])
        nt.links.new(em.outputs["Emission"], out.inputs["Surface"])

def heal(img):
    w, h = img.size
    px = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    px = px.reshape(h, w, 4)
    rgb = px[:, :, :3]
    bad = rgb.max(axis=2) < 0.004
    good = ~bad
    for _ in range(32):
        if not bad.any():
            break
        acc = np.zeros_like(rgb)
        cnt = np.zeros((h, w), dtype=np.float32)
        for sh in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            g = np.roll(good, sh, axis=(0, 1))
            acc += np.roll(rgb, sh, axis=(0, 1)) * g[:, :, None]
            cnt += g
        new = bad & (cnt > 0)
        rgb[new] = acc[new] / cnt[new][:, None]
        good |= new
        bad &= ~new
    img.pixels.foreach_set(px.ravel())

def light(hi, name):
    lo = hi.copy()
    lo.data = hi.data.copy()
    lo.name = name
    bpy.context.scene.collection.objects.link(lo)
    lo.data.materials.clear()
    only(lo)
    for _ in range(5):
        n = len(tri_idx(lo))
        if n <= TRIS * 1.15:
            break
        mod = lo.modifiers.new("d", "DECIMATE")
        mod.ratio = TRIS / n
        bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.quads_convert_to_tris()
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.006)
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.object.shade_smooth()
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 2
    b = sc.render.bake
    b.use_selected_to_active = True
    # (a wing is a thin sheet: the bake looks only a hair off the light mesh, or it takes the other face's colour)
    b.cage_extrusion = 0.004 * SPAN
    b.max_ray_distance = 0.012 * SPAN
    b.margin = 8
    bpy.ops.object.select_all(action="DESELECT")
    hi.select_set(True)
    lo.select_set(True)
    bpy.context.view_layer.objects.active = lo
    n_img, mat, n_node = image_mat(lo, name + "_n", False)
    bpy.ops.object.bake(type="NORMAL")
    as_light(hi)
    d_img, _, d_node = image_mat(lo, name + "_d", True)
    bpy.ops.object.bake(type="EMIT")
    heal(d_img)
    for img in (n_img, d_img):
        img.pack()
    # the light mesh's own material: the baked colour and relief (glTF carries them into the .glb)
    nt = mat.node_tree
    for x in list(nt.nodes):
        if x not in (n_node, d_node):
            nt.nodes.remove(x)
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    outn = nt.nodes.new("ShaderNodeOutputMaterial")
    nm = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(d_node.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(n_node.outputs["Color"], nm.inputs["Color"])
    nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    nt.links.new(bsdf.outputs["BSDF"], outn.inputs["Surface"])
    bsdf.inputs["Roughness"].default_value = 0.6
    mat.use_backface_culling = False
    bpy.data.objects.remove(hi, do_unlink=True)
    return lo

def rig(lo):
    # a hinge along the body (X): the wings' bones from the middle out along ±Y, the body's own bone along X
    arm_d = bpy.data.armatures.new("rig")
    arm = bpy.data.objects.new("rig", arm_d)
    bpy.context.scene.collection.objects.link(arm)
    only(arm)
    bpy.ops.object.mode_set(mode="EDIT")
    root = arm_d.edit_bones.new("Root")
    root.head, root.tail = (-0.3, 0, 0), (0.3, 0, 0)
    L = arm_d.edit_bones.new("LeftUpperWing")
    L.head, L.tail = (0, 0, 0.0), (0, SPAN * 0.5, 0)
    L.parent = root
    R = arm_d.edit_bones.new("RightUpperWing")
    R.head, R.tail = (0, 0, 0.0), (0, -SPAN * 0.5, 0)
    R.parent = root
    bpy.ops.object.mode_set(mode="OBJECT")
    # weights: the body stays, the wing beyond it turns — a soft hinge a little way out from the middle
    q = coords(lo)
    gL = lo.vertex_groups.new(name="LeftUpperWing")
    gR = lo.vertex_groups.new(name="RightUpperWing")
    gB = lo.vertex_groups.new(name="Root")
    w0, w1 = 0.035 * SPAN, 0.075 * SPAN
    for i, (x, y, z) in enumerate(q):
        t = min(1.0, max(0.0, (abs(y) - w0) / (w1 - w0)))
        t = t * t * (3 - 2 * t)
        (gL if y > 0 else gR).add([i], t, "REPLACE")
        gB.add([i], 1.0 - t, "REPLACE")
    lo.parent = arm
    mod = lo.modifiers.new("arm", "ARMATURE")
    mod.object = arm
    # the wingbeat: up to ~88° (closed over the back — it sits in the top of its stroke), down to ~45° below, and back
    act = bpy.data.actions.new("fly")
    arm.animation_data_create()
    arm.animation_data.action = act
    sc = bpy.context.scene
    sc.render.fps = 24
    N = 24
    only(arm)
    bpy.ops.object.mode_set(mode="POSE")
    for f in range(N + 1):
        a = math.radians(21.5 + 66.5 * math.cos(2 * math.pi * f / N))
        for nm, sgn in (("LeftUpperWing", 1.0), ("RightUpperWing", -1.0)):   # (+Y up toward +Z: a turn +; -Y: −)
            pb = arm.pose.bones[nm]
            pb.rotation_mode = "XYZ"
            # (the bone points along ±Y; turning about the body's line, X: the wing's tip rises toward +Z)
            pb.rotation_euler = (0.0, 0.0, 0.0)
            pb.rotation_euler = _about_x(pb, sgn * a)
            pb.keyframe_insert("rotation_euler", frame=f)
    bpy.ops.object.mode_set(mode="OBJECT")
    sc.frame_start, sc.frame_end = 0, N
    return arm

def _about_x(pb, ang):
    # a turn about the armature's X axis, as the bone's own euler
    rest = pb.bone.matrix_local.to_3x3()
    rot = Matrix.Rotation(ang, 3, "X")
    local = rest.inverted() @ rot @ rest
    return local.to_euler("XYZ")

def export(name, arm, lo):
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    lo.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"), use_selection=True, export_format="GLB",
        export_animations=True, export_skins=True, export_image_format="AUTO", export_yup=True)

def picture(name, arm, lo):
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = "TEXTURE"
    sc.render.resolution_x, sc.render.resolution_y = 420, 300
    w = bpy.data.worlds.new("w")
    w.color = (0.05, 0.05, 0.06)
    sc.world = w
    cd = bpy.data.cameras.new("c")
    cd.type = "ORTHO"
    cd.ortho_scale = SPAN * 1.25
    cam = bpy.data.objects.new("c", cd)
    sc.collection.objects.link(cam)
    sc.camera = cam
    # (from above with the head up the picture; from the front at the top of the stroke and at its bottom)
    for tag, d, f in (("top", Vector((0.0, 0.0, 1.0)), 6), ("up", Vector((1.0, 0.0, 0.25)), 0), ("down", Vector((1.0, 0.0, 0.25)), 12)):
        sc.frame_set(f)
        cam.location = d.normalized() * 6
        cam.rotation_euler = (-d.normalized()).to_track_quat("-Z", "X" if tag == "top" else "Z").to_euler()
        sc.render.filepath = os.path.join(PREVIEW, name + "_" + tag + ".png")
        bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(cam, do_unlink=True)

os.makedirs(OUT, exist_ok=True)
if PREVIEW:
    os.makedirs(PREVIEW, exist_ok=True)
for M in MODELS:
    if ONLY and M["name"] not in ONLY:
        continue
    hi = load(os.path.join(SRC, M["file"]))
    full = len(tri_idx(hi))
    err = orient(hi, M.get("flip", ""))
    lo = light(hi, M["name"])
    arm = rig(lo)
    export(M["name"], arm, lo)
    print("BFLY %s: %d -> %d tris, mirror error %.3f of span" % (M["name"], full, len(tri_idx(lo)), err), flush=True)
    if PREVIEW:
        picture(M["name"], arm, lo)
print("BFLY done")
