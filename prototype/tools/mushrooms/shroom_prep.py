# Mushroom models for the specimen generator (SpecFungi): downloaded scans and models (.glb, see
# godot/assets/specimen/fungi/CREDITS.md) -> a light mesh each, stood on its foot at the origin, one unit tall, with its
# colour and its relief baked into two small textures.
#   blender -b -P shroom_prep.py -- <folder with the downloads> <godot/assets/specimen/fungi> [name,name...] [preview dir]
# For every entry of MODELS: the file is read, its chunks welded, the scanner's colour card and loose specks dropped,
# the mushroom turned upright (where asked), cut (where asked), then a decimated copy gets new UVs and the colour and
# the tangent normals of the full mesh are baked onto it (Cycles, selected to active). Out: <name>.obj, <name>_d.png,
# <name>_n.png. With a preview dir, a side picture of every result is rendered there.
import bpy, sys, os, math
import numpy as np
from mathutils import Vector, Matrix

argv = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT = argv[0], argv[1]
ONLY = [s for s in argv[2].split(",") if s] if len(argv) > 2 and argv[2] != "-" else []
PREVIEW = argv[3] if len(argv) > 3 else ""
TEX = 512

# name: the file; tris: the light mesh's triangles; orient: find the stem's axis and stand it up — "pca" for one lying
# any way (its long axis is the stem), "z" for one nearly upright but leaning; split: the file holds this many mushrooms, the biggest first (name_0, name_1...); keep_top: only this
# share of its height, from the cap down (a stem far too long for a rock); tilt: degrees about X and Y, by hand, after all
MODELS = [
    dict(name="agaric_red", file="мухоморы/fly_agaric_mushroom.glb", tris=3200),
    dict(name="agaric_gold_a", file="мухоморы/amanita_muscaria_mushroom.glb", tris=3200),
    dict(name="agaric_gold_b", file="мухоморы/amanita_muscaria_mushroom (1).glb", tris=3200),
    dict(name="bolete_brown", file="губчатые/2c7d032e858b4d73b48c21a771ffac2c.glb", tris=3000),
    dict(name="bolete_jack", file="губчатые/cc0___slippery_jack_mushroom.glb", tris=3000),
    dict(name="bolete_suede", file="губчатые/cc0___suede_bolete_x._subtomentosus.glb", tris=3000),
    dict(name="bolete_wine", file="губчатые/orange-cap_boletus_mushroom.glb", tris=3000, orient="z"),
    dict(name="chanterelle", file="cantharellus_formosus_mushroom.glb", tris=3500),
    dict(name="morel", file="cc0___common_morel_morchella_esculenta.glb", tris=4500),
    dict(name="panther", file="cc0___white_panther_cap.glb", tris=3200, split=3),
    dict(name="oyster", file="mushrooms_-_blue_oyster.glb", tris=6000),
    dict(name="honey", file="realistic_mushroom_-_01.glb", tris=4200),
    dict(name="mycena", file="типа мицены/cc0___mushroom.glb", tris=1800, orient="pca", keep_top=0.42),
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

def components(faces, nv):
    # labels of the connected pieces: every vertex takes the smallest label round its triangles, with pointer jumps
    lab = np.arange(nv)
    while True:
        m = lab[faces].min(axis=1)
        new = lab.copy()
        for k in range(3):
            np.minimum.at(new, faces[:, k], m)
        new = new[new]
        new = new[new]
        if np.array_equal(new, lab):
            return lab
        lab = new

def delete_verts(o, mask):
    only(o)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_mode(type="VERT")
    bpy.ops.mesh.select_all(action="DESELECT")
    bpy.ops.object.mode_set(mode="OBJECT")
    o.data.vertices.foreach_set("select", mask.astype(bool))
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.delete(type="VERT")
    bpy.ops.object.mode_set(mode="OBJECT")

def load(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
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
    # the chunks a big scan was cut into: welded along their borders
    # (how close is "the same point": a sixth of a typical edge — some scans' chunks do not meet exactly)
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

def parts(hi, split):
    # the pieces of it: specks and the colour card go; a file of several mushrooms is told apart
    f = tri_idx(hi)
    lab = components(f, len(hi.data.vertices))
    roots, counts = np.unique(lab[f[:, 0]], return_counts=True)
    order = np.argsort(-counts)
    total = counts.sum()
    if split > 1:
        # (the biggest by its size, not by how finely it was scanned: the grown one first, the button last)
        co = coords(hi)
        top = [roots[i] for i in order[:split]]
        top.sort(key=lambda r: -np.ptp(co[lab == r], axis=0).max())
        roots = np.array(top)
        order = np.arange(split)
        outs = []
        for k in range(split):
            o = hi.copy()
            o.data = hi.data.copy()
            bpy.context.scene.collection.objects.link(o)
            delete_verts(o, lab != roots[order[k]])
            outs.append(o)
        bpy.data.objects.remove(hi, do_unlink=True)
        return outs
    keep = roots[counts >= max(40, total * 0.003)]
    drop = ~np.isin(lab, keep)
    if drop.any():
        delete_verts(hi, drop)
    return [hi]

def stand(o, orient, keep_top, tilt):
    co = coords(o)
    if orient:
        # the axis of it: the direction that stands apart from the other two (long for a stemmed one, short for a flat
        # cap), then set right through the middles of its slices; the cap's end is the broad one
        c = co.mean(axis=0)
        if orient == "z":
            ax = np.array([0.0, 0.0, 1.0])
        else:
            w, v = np.linalg.eigh(np.cov((co - c).T))
            ax = v[:, 2] if w[2] / max(w[1], 1e-12) > w[1] / max(w[0], 1e-12) else v[:, 0]
            t = (co - c) @ ax
            rad = np.linalg.norm((co - c) - np.outer(t, ax), axis=1)
            if rad[t < np.quantile(t, 0.3)].mean() > rad[t > np.quantile(t, 0.7)].mean():
                ax = -ax
        # (the foot's middle and the middle of the whole cap both lie on the axis: the line through them, a few times over)
        for _ in range(4):
            t = (co - c) @ ax
            a = co[t < np.quantile(t, 0.1)].mean(axis=0)
            b = co[t > np.quantile(t, 0.6)].mean(axis=0)
            ax = (b - a) / np.linalg.norm(b - a)
        q = Vector(ax).rotation_difference(Vector((0, 0, 1)))
        o.data.transform(q.to_matrix().to_4x4())
        co = coords(o)
    if tilt:
        m = Matrix.Rotation(math.radians(tilt[0]), 4, "X") @ Matrix.Rotation(math.radians(tilt[1]), 4, "Y")
        o.data.transform(m)
        co = coords(o)
    if keep_top:
        z0, z1 = co[:, 2].min(), co[:, 2].max()
        cut = z1 - (z1 - z0) * keep_top
        delete_verts(o, co[:, 2] < cut)
        co = coords(o)
    # on its foot at the origin, one unit tall
    z0, z1 = co[:, 2].min(), co[:, 2].max()
    foot = co[co[:, 2] < z0 + (z1 - z0) * 0.05].mean(axis=0)
    s = 1.0 / (z1 - z0)
    o.data.transform(Matrix.Scale(s, 4) @ Matrix.Translation(Vector((-foot[0], -foot[1], -z0))))
    o.data.update()

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
    # every material of the full mesh shows its colour texture as emission: baked as EMIT it is the texture itself,
    # whatever shader the file gave it (scans come "unlit": a diffuse bake of them is black)
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

def light(hi, name, tris):
    lo = hi.copy()
    lo.data = hi.data.copy()
    lo.name = name
    bpy.context.scene.collection.objects.link(lo)
    lo.data.materials.clear()
    only(lo)
    # (a scan with open seams gives way slowly: asked again until it is light enough)
    for _ in range(5):
        n = len(tri_idx(lo))
        if n <= tris * 1.15:
            break
        mod = lo.modifiers.new("d", "DECIMATE")
        mod.ratio = tris / n
        bpy.ops.object.modifier_apply(modifier=mod.name)
    if len(tri_idx(lo)) > tris * 1.25:
        # a scan of loose triangles will not collapse at all: its surface is built anew as one skin, then lightened
        mod = lo.modifiers.new("r", "REMESH")
        mod.mode = "VOXEL"
        mod.voxel_size = max(lo.dimensions) / 110.0
        bpy.ops.object.modifier_apply(modifier=mod.name)
        for _ in range(4):
            n = len(tri_idx(lo))
            if n <= tris * 1.15:
                break
            mod = lo.modifiers.new("d", "DECIMATE")
            mod.ratio = tris / n
            bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.quads_convert_to_tris()
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.012)
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.object.shade_smooth()
    # the bake: what the full mesh shows, onto the light one
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 2
    b = sc.render.bake
    b.use_selected_to_active = True
    b.cage_extrusion = 0.035
    b.max_ray_distance = 0.12
    b.margin = 8
    bpy.ops.object.select_all(action="DESELECT")
    hi.select_set(True)
    lo.select_set(True)
    bpy.context.view_layer.objects.active = lo
    # (the relief first, with the file's own materials — their normal maps count; then the colour as light)
    n_img, mat, n_node = image_mat(lo, name + "_n", False)
    bpy.ops.object.bake(type="NORMAL")
    n_img.filepath_raw = os.path.join(OUT, name + "_n.png")
    n_img.file_format = "PNG"
    n_img.save()
    as_light(hi)
    d_img, _, node = image_mat(lo, name + "_d", True)
    bpy.ops.object.bake(type="EMIT")
    d_img.filepath_raw = os.path.join(OUT, name + "_d.png")
    d_img.file_format = "PNG"
    d_img.save()
    # (for the picture: the baked colour as the material's own)
    nt = mat.node_tree
    bsdf = next((x for x in nt.nodes if x.type == "BSDF_PRINCIPLED"), None)
    if bsdf:
        nt.links.new(node.outputs["Color"], bsdf.inputs["Base Color"])
    for x in nt.nodes:
        x.select = False
    node.select = True
    nt.nodes.active = node
    only(lo)
    bpy.ops.wm.obj_export(filepath=os.path.join(OUT, name + ".obj"), export_selected_objects=True, export_materials=False,
        export_uv=True, export_normals=True, export_triangulated_mesh=True, forward_axis="NEGATIVE_Z", up_axis="Y")
    return lo

def picture(lo, name):
    sc = bpy.context.scene
    for o in sc.objects:
        o.hide_render = o != lo
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = "TEXTURE"
    sc.render.resolution_x = sc.render.resolution_y = 360
    w = bpy.data.worlds.new("w")
    w.color = (0.05, 0.05, 0.06)
    sc.world = w
    cd = bpy.data.cameras.new("c")
    cd.type = "ORTHO"
    cd.ortho_scale = 1.5
    cam = bpy.data.objects.new("c", cd)
    sc.collection.objects.link(cam)
    sc.camera = cam
    for tag, d in (("a", Vector((0.9, -1.0, 0.3))), ("b", Vector((-0.2, -0.3, -1.0))), ("f", Vector((0.0, -1.0, 0.0))), ("s", Vector((1.0, 0.0, 0.0)))):
        d = d.normalized()
        cam.location = Vector((0, 0, 0.5)) + d * 6
        cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = os.path.join(PREVIEW, name + "_" + tag + ".png")
        bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(cam, do_unlink=True)
    for o in sc.objects:
        o.hide_render = False

os.makedirs(OUT, exist_ok=True)
if PREVIEW:
    os.makedirs(PREVIEW, exist_ok=True)
for M in MODELS:
    if ONLY and M["name"] not in ONLY:
        continue
    hi = load(os.path.join(SRC, M["file"]))
    split = M.get("split", 1)
    for k, part in enumerate(parts(hi, split)):
        name = M["name"] + ("_%d" % k if split > 1 else "")
        stand(part, M.get("orient", False), M.get("keep_top", 0.0), M.get("tilt"))
        full = len(tri_idx(part))
        lo = light(part, name, M["tris"])
        print("SHROOM %s: %d -> %d tris, size %s" % (name, full, len(tri_idx(lo)), [round(v, 2) for v in lo.dimensions]), flush=True)
        if PREVIEW:
            picture(lo, name)
print("SHROOM done")
