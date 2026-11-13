# Flower models for the specimen generator (SpecFlora): downloaded scans of real plants (.glb, see
# godot/assets/specimen/flora/CREDITS.md) -> a light mesh each, stood on its foot at the origin, one unit tall, with its
# colour and its relief baked into two small textures. The mushrooms' tool (../mushrooms/shroom_prep.py) with what a
# plant needs: the scanner's colour cube is told by its shape and dropped, a plant is every piece standing together
# (petals and stamens are often loose pieces), a file may hold several plants side by side.
#   blender -b -P flower_prep.py -- <folder with the downloads> <godot/assets/specimen/flora> [name,name...] [preview dir]
# Out: <name>.obj, <name>_d.png, <name>_n.png. With a preview dir, pictures of every result are rendered there.
import bpy, sys, os, math
import numpy as np
from mathutils import Vector, Matrix

argv = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT = argv[0], argv[1]
ONLY = [s for s in argv[2].split(",") if s] if len(argv) > 2 and argv[2] != "-" else []
PREVIEW = argv[3] if len(argv) > 3 else ""
TEX = 512

# name: the file; tris: the light mesh's triangles; gap: how far apart two pieces are still one plant, of the file's
# size (0.035 when not set; below 0 — never: every piece its own plant); split: the file holds this many plants, the biggest first (name_0,
# name_1...); orient: "pca" — a plant lying down: its long axis is the stem, the broad end the flower, stood up;
# keep_top: only this share of its height, from the flower down (a bare stem far too long for a rock);
# tilt: degrees about X and Y, by hand, after all;
# keep_uv: no bake — the light mesh keeps the scan's own unwrap and wears its own texture, made `tex` px (the bake
# missed in a crumpled heart, a rose's, and between close heads, the chrysanthemum's: black, then muddy patches); the
# relief is left flat
MODELS = [
    # (there are dozens of them on a stone: the lightest of all)
    dict(name="violet", file="cc0__kotachitsubo__violet.glb", tris=1500, keep_top=0.86),
    dict(name="gentian_a", file="gentian/cc0__gentian_gentiana_zollingeri.glb", tris=4500, keep_top=0.62),
    dict(name="gentian_b_0", file="gentian/cc0__japanese_gentian_gentiana_scabra.glb", tris=3200, keep_top=0.6),
    dict(name="lily_a", file="tiger/cc0__tiger_lily.glb", tris=6000, keep_top=0.7),
    dict(name="lily_b", file="tiger/cc0__tiger_lily_lilium_lancifolium (1).glb", tris=4500, keep_top=0.55),
    dict(name="lily_c", file="tiger/cc0__tiger_lily_lilium_lancifolium.glb", tris=7000, keep_top=0.7),
    dict(name="rose", file="7396d21515884397a2645b26a23cb096.glb", tris=30000, keep_top=0.6, keep_uv=True, tex=2048),
    # (the file's other plant, one big head on a stub of stem, is far too big a flower for a rock: only the spray)
    dict(name="daisy_0", file="cc0____chrysanthemum.glb", tris=30000, keep_top=0.6, keep_uv=True, tex=2048),
    dict(name="goldmum", file="cc0__indian_chrysanthemum_c._indicum.glb", tris=5000, orient="pca"),
    dict(name="azalea", file="cc0__moutain_azalea.glb", tris=6000),
    # (its leaf, its spray of buds and its open flower lie side by side in the scan, their boxes one through another:
    # every piece is its own plant — iris_0 the leaf, iris_1 the spray, iris_2 the flower)
    dict(name="iris", file="cc0__crested_iris_iris_japonica.glb", tris=3600, split=3, gap=-1.0, orient="pca"),
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

def parts(hi, split, gap_k=0.035):
    # the plants of the file: its pieces (petals, stamens, leaves are often loose) gathered into the ones standing
    # together; specks go, and the scanner's colour cube — a small piece as wide as it is tall and deep, off to a side
    f = tri_idx(hi)
    co = coords(hi)
    lab = components(f, len(hi.data.vertices))
    roots, counts = np.unique(lab[f[:, 0]], return_counts=True)
    big = roots[counts >= 20]
    lo = np.array([co[lab == r].min(axis=0) for r in big])
    hi_b = np.array([co[lab == r].max(axis=0) for r in big])
    gap = float(np.ptp(co, axis=0).max()) * gap_k
    group = np.arange(len(big))
    changed = gap >= 0.0
    while changed:
        changed = False
        for g in np.unique(group):
            m = group == g
            a0, a1 = lo[m].min(axis=0) - gap, hi_b[m].max(axis=0) + gap
            near = np.all((lo <= a1) & (hi_b >= a0), axis=1) & ~m
            if near.any():
                for h in np.unique(group[near]):
                    group[group == h] = g
                changed = True
                break
    plants = []
    for g in np.unique(group):
        m = group == g
        a0, a1 = lo[m].min(axis=0), hi_b[m].max(axis=0)
        plants.append(dict(roots=big[m], size=a1 - a0))
    plants.sort(key=lambda p: -p["size"].max())
    top = plants[0]["size"].max()
    keep = []
    for p in plants:
        sz = p["size"]
        # (pieces taken one by one are all the plant's: an open flower alone is as wide as it is tall)
        cube = gap >= 0.0 and sz.min() / sz.max() > 0.72 and sz.max() < top * 0.4
        speck = sz.max() < top * 0.06
        print("  piece", [round(float(v), 3) for v in sz], "cube" if cube else "speck" if speck else "plant", len(p["roots"]), "parts", flush=True)
        if not cube and not speck:
            keep.append(p)
    keep = keep[:split]
    outs = []
    for p in keep:
        o = hi.copy()
        o.data = hi.data.copy()
        bpy.context.scene.collection.objects.link(o)
        delete_verts(o, ~np.isin(lab, p["roots"]))
        outs.append(o)
    bpy.data.objects.remove(hi, do_unlink=True)
    return outs

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

def heal(img):
    # texels the bake never reached (between close-packed petals the light mesh lies where no ray finds the full one)
    # come out pure black: each takes the colour of its nearest baked neighbours, a ring at a time
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

def light_uv(hi, name, tris, tex):
    # lightened as it is, its unwrap kept (the collapse carries the UVs along), and the scan's own texture made small
    lo = hi.copy()
    lo.data = hi.data.copy()
    lo.name = name
    bpy.context.scene.collection.objects.link(lo)
    only(lo)
    for _ in range(5):
        n = len(tri_idx(lo))
        if n <= tris * 1.15:
            break
        mod = lo.modifiers.new("d", "DECIMATE")
        mod.ratio = tris / n
        bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.ops.object.shade_smooth()
    # the scan's textures (a big scan is cut into several, each part of the plant on its own): laid side by side in one
    # picture (2x2), each part's unwrap moved onto its own quarter
    imgs = []
    of_mat = []
    for mat in lo.data.materials:
        im = None
        if mat and mat.use_nodes:
            for n in mat.node_tree.nodes:
                if n.type == "TEX_IMAGE" and n.image and n.image.colorspace_settings.name != "Non-Color":
                    im = n.image
                    break
        if im is not None and im not in imgs:
            imgs.append(im)
        of_mat.append(imgs.index(im) if im is not None else 0)
    print("  keep_uv: textures", [(i.name, tuple(i.size)) for i in imgs], flush=True)
    grid = 1 if len(imgs) == 1 else 2
    tile = tex // grid
    atlas = np.zeros((tex, tex, 4), dtype=np.float32)
    atlas[:, :, 3] = 1.0
    for k, im in enumerate(imgs):
        c = im.copy()
        c.scale(tile, tile)
        px = np.empty(tile * tile * 4, dtype=np.float32)
        c.pixels.foreach_get(px)
        tx, ty = k % grid, k // grid
        atlas[ty * tile:(ty + 1) * tile, tx * tile:(tx + 1) * tile] = px.reshape(tile, tile, 4)
    uv = lo.data.uv_layers.active.data
    for poly in lo.data.polygons:
        k = of_mat[poly.material_index] if poly.material_index < len(of_mat) else 0
        tx, ty = k % grid, k // grid
        for li in poly.loop_indices:
            u, v = uv[li].uv
            uv[li].uv = ((tx + (u % 1.0)) / grid, (ty + (v % 1.0)) / grid)
    out = bpy.data.images.new(name + "_d", tex, tex, alpha=False)
    out.pixels.foreach_set(atlas.ravel())
    out.filepath_raw = os.path.join(OUT, name + "_d.png")
    out.file_format = "PNG"
    out.save()
    flat = bpy.data.images.new(name + "_n", 4, 4, alpha=False)
    flat.pixels.foreach_set(np.tile(np.array([0.5, 0.5, 1.0, 1.0], dtype=np.float32), 16))
    flat.filepath_raw = os.path.join(OUT, name + "_n.png")
    flat.file_format = "PNG"
    flat.save()
    bpy.ops.wm.obj_export(filepath=os.path.join(OUT, name + ".obj"), export_selected_objects=True, export_materials=False,
        export_uv=True, export_normals=True, export_triangulated_mesh=True, forward_axis="NEGATIVE_Z", up_axis="Y")
    return lo

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
    # (thin petals: the bake looks only a little way off the light mesh, or a petal takes its neighbour's colour —
    # a little by the plant's own size: a flat wide head stood one unit tall is far wider than that)
    wide = max(1.0, max(lo.dimensions))
    b.cage_extrusion = 0.012 * wide
    b.max_ray_distance = 0.035 * wide
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
    heal(d_img)
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
    for k, part in enumerate(parts(hi, split, M.get("gap", 0.035))):
        name = M["name"] + ("_%d" % k if split > 1 else "")
        if PREVIEW: print("FLOWER", name, flush=True)
        stand(part, M.get("orient", False), M.get("keep_top", 0.0), M.get("tilt"))
        full = len(tri_idx(part))
        lo = light_uv(part, name, M["tris"], M.get("tex", TEX)) if M.get("keep_uv") else light(part, name, M["tris"])
        print("FLOWER %s: %d -> %d tris, size %s" % (name, full, len(tri_idx(lo)), [round(v, 2) for v in lo.dimensions]), flush=True)
        if PREVIEW:
            picture(lo, name)
print("FLOWER done")
