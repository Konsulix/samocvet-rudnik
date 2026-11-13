# Insect models for amber inclusions (SpecFlower): downloaded scans of real dried specimens (.glb, see
# godot/assets/specimen/insects/CREDITS.md) -> a light mesh each, laid the way it is seen in amber — head +X, back up,
# its middle at the origin, its longest reach one unit — with its colour and relief baked into two small textures.
# The flowers' tool (../flowers/flower_prep.py) with what a specimen needs: the scanner's colour cube is dropped, the
# legs and wings (loose pieces) are kept with the body, and it is turned by its own shape (as butterfly_prep.py does):
# the thinnest axis is its back-to-belly, the axis it is mirror-even about is left-right, the belly is where the legs
# hang. No skeleton — an inclusion never moves.
#   blender -b -P insect_prep.py -- <folder with the downloads> <godot/assets/specimen/insects> [name,name...] [preview dir]
# Out: <name>.obj, <name>_d.png, <name>_n.png. With a preview dir, pictures of every result (back, side, front).
import bpy, sys, os, math
import numpy as np
from mathutils import Vector, Matrix

argv = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT = argv[0], argv[1]
ONLY = [s for s in argv[2].split(",") if s] if len(argv) > 2 and argv[2] != "-" else []
PREVIEW = argv[3] if len(argv) > 3 else ""
TEX = 512

# name: group_kind (the group is SpecFlower's gene); file; tris; flip: "back" / "head" — the guess by shape turned
# over; rot: degrees about X, Y, Z (Blender's, X the head, Z the back) by hand, after all; gap: how far apart two
# pieces are still one animal, of the file's size; axes: (head, back) — which of the scan's axes, once turned by its
# shape, are its head and its back ("-y", "x"...: a scan lying on its side)
MODELS = [
    # wasps and bees
    dict(name="wasp_hornet", file="насекомые/42aac36b6d304c1cbab3ce8dd996a081.glb", tris=5000),
    dict(name="wasp_carpenter", file="насекомые/f0aac424f44b48cf9217ffe126ace5ca.glb", tris=5000),
    # spiders and scorpions
    dict(name="spider_argiope", file="насекомые/5dde6a72eb324086b93b71757d79bb05.glb", tris=5000),
    dict(name="spider_scorpion", file="насекомые/ypm_ent.618741_scorpiones_uroctonus_mordax.glb", tris=5000),
    dict(name="spider_scorpion_b", file="насекомые/ypm_ent.618753_scorpion_scorpionoidea.glb", tris=5000),
    # beetles
    dict(name="beetle_longhorn", file="насекомые/cc0__blue_longhorn_beetle_r._bates.glb", tris=5000),
    dict(name="beetle_fruit", file="насекомые/cc0__japanese_fruit_beetle_m._splendens.glb", tris=4500, flip="back"),
    dict(name="beetle_tiger", file="насекомые/cc0__japanese_tiger_beetle_c._japonica.glb", tris=4500),
    dict(name="beetle_stag", file="насекомые/cc0___asian_red-footed_stag_beetle.glb", tris=5000),
    dict(name="beetle_diving", file="насекомые/cc0___diving_beetle_cybister_chinensis.glb", tris=4500, flip="back"),
    dict(name="beetle_eudicella", file="насекомые/ypm_ent.620680_coleoptera_eudicella.glb", tris=4500, axes=("-y", "-x")),
    dict(name="beetle_dynastes", file="насекомые/ypm_ent.620689_coleoptera_dynastes_tityus.glb", tris=4500, flip="back"),
    dict(name="beetle_cerambyx", file="насекомые/ypm_ent.623715_coleoptera_cerambycidae.glb", tris=5000, flip="back"),
    # cicadas and grasshoppers
    dict(name="cicada_kaempfer", file="насекомые/cc0___kaempfer_cicada_p._kaempferi.glb", tris=5000),
    dict(name="cicada_locust", file="насекомые/cc0____migratory_locust_l._migratoria.glb", tris=5000, axes=("x", "y")),
    # dragonflies
    dict(name="dragonfly_demoiselle", file="насекомые/cc0___demoiselle_dragonfly_c._atrata.glb", tris=12000),
    dict(name="dragonfly_darner", file="насекомые/cc0__elegant_darner_macromia_elegans.glb", tris=4500),
    # butterflies and moths
    dict(name="moth_fritillary", file="насекомые/cc0___indian_fritillary_a._hyperbius.glb", tris=4500),
    dict(name="moth_tiger", file="бабочки/ypm_ent.574592_lepidoptera_grammia_virgo.glb", tris=4500),
    dict(name="moth_sphinx", file="бабочки/ypm_ent.587431_sphinx_moth_xylophanes_tyndarus.glb", tris=4500),
    dict(name="moth_morpho", file="бабочки/ypm_ent.798173_blue_morpho_morpho_achilles.glb", tris=4500),
    dict(name="moth_luna", file="бабочки/ypm_ent.845663_luna_moth_actias_luna.glb", tris=5000),
    dict(name="moth_silk", file="бабочки/ypm_ent.929992_silkmoth_eupackardia_calleta.glb", tris=4500),
    # mantises and stick insects
    # (cc0___asian_jumping_mantis_s._maculata.glb: the scan is in crumbs — not used)
    dict(name="mantis_korean", file="насекомые/0a78f8afc95d4e8190500786b99550eb.glb", tris=5000),
    dict(name="mantis_stick", file="насекомые/cc0___stick_insect_phraortes_illepidus.glb", tris=3500),
    # the rest
    dict(name="other_centipede", file="насекомые/cc0__chinese_red-headed_centipede.glb", tris=5000),
    dict(name="other_bug", file="насекомые/ypm_ent.611538_hemiptera_anisoscelis_foliacea.glb", tris=4500),
    dict(name="other_snail", file="насекомые/snail_house.glb", tris=4000),
    # (macrobrachium_rosenbergii.glb: a modelled prawn of loose primitives, not a scan — not used)
    # plants held in amber (SpecFlower: content "flower" and "leaf") — laid by their own shape the same way: flat, face up
    dict(name="flower_camellia", file="цветы/cc0____tsubaki_camellia_japonica.glb", tris=6000, plant=True),
    dict(name="flower_azalea", file="цветы/cc0__hirado_azalea_r._x_pulchrum.glb", tris=6000, plant=True),
    dict(name="flower_lotus", file="цветы/cc0__indian_lotus_nelumbo_nucifera.glb", tris=6000, plant=True),
    dict(name="flower_plum", file="цветы/cc0__japanese_apricot_prunus_mume.glb", tris=6000, plant=True),
    dict(name="flower_magnolia", file="цветы/cc0__lilytree_magnolia_denudata.glb", tris=6000, plant=True),
    dict(name="leaf_fern", file="листья и фигня/cc0__autumn_fern_dryopteris_erythrosora.glb", tris=6000, plant=True),
    # (cc0__japanese_common_chestnut_c._crenata.glb: the spiny burr falls to jagged shards when made light — not used)
    dict(name="leaf_oak", file="листья и фигня/cc0__konara_oak_quercus_serrata.glb", tris=4000, plant=True),
    dict(name="leaf_oak_b", file="листья и фигня/cc0__ring-cupped_oak_quercus_glauca.glb", tris=4000, plant=True),
    dict(name="leaf_pine", file="листья и фигня/cc0___japanese_black_pine_p._thunbergii.glb", tris=9000, plant=True),
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

def animal(hi, gap_k):
    # the animal: its pieces (legs, antennae, wings are often loose) gathered into the ones lying together; specks go,
    # and the scanner's colour cube — a small piece as wide as it is tall and deep, off to a side
    f = tri_idx(hi)
    co = coords(hi)
    lab = components(f, len(hi.data.vertices))
    roots, counts = np.unique(lab[f[:, 0]], return_counts=True)
    big = roots[counts >= 12]
    lo = np.array([co[lab == r].min(axis=0) for r in big])
    hi_b = np.array([co[lab == r].max(axis=0) for r in big])
    gap = float(np.ptp(co, axis=0).max()) * gap_k
    group = np.arange(len(big))
    changed = True
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
    found = []
    for g in np.unique(group):
        m = group == g
        found.append(dict(roots=big[m], size=hi_b[m].max(axis=0) - lo[m].min(axis=0)))
    found.sort(key=lambda p: -p["size"].max())
    top = found[0]["size"].max()
    keep = []
    for p in found:
        sz = p["size"]
        cube = sz.min() / sz.max() > 0.72 and sz.max() < top * 0.4 and len(p["roots"]) <= 3
        speck = sz.max() < top * 0.04
        print("  piece", [round(float(v), 3) for v in sz], "cube" if cube else "speck" if speck else "animal", len(p["roots"]), "parts", flush=True)
        if not cube and not speck:
            keep.append(p)
    roots = np.concatenate([p["roots"] for p in keep[:1]])
    delete_verts(hi, ~np.isin(lab, roots))
    return hi

def _mirror_err(p, ax, c):
    # how far the scan is from its own mirror across the plane through c normal to ax (a sample, nearest points)
    rng = np.random.default_rng(1)
    s = p[rng.choice(len(p), min(len(p), 1500), replace=False)]
    m = s - 2.0 * np.outer((s - c) @ ax, ax)
    q = p[rng.choice(len(p), min(len(p), 6000), replace=False)]
    d = np.sqrt(((m[:, None, :] - q[None, :, :]) ** 2).sum(axis=2)).min(axis=1)
    return float(np.median(d))

def orient(o, flip, rot, axes=None):
    p = coords(o)
    c = p.mean(axis=0)
    w, v = np.linalg.eigh(np.cov((p - c).T))
    up = v[:, 0]                       # the thinnest: back to belly
    a, b = v[:, 1], v[:, 2]
    best = None
    for ax in (a, b):
        t = p @ ax
        cc = c + ax * ((t.min() + t.max()) * 0.5 - c @ ax)
        e = _mirror_err(p, ax, cc)
        if best is None or e < best[0]:
            best = (e, ax, cc)
    lr = best[1]
    fwd = b if lr is a else a
    mid = best[2]
    # the head: the end where the body is thicker near the axis (the abdomen tapers)... a guess, turned by hand if not
    s = (p - mid) @ fwd
    side = np.abs((p - mid) @ lr)
    near = side < np.quantile(side, 0.3)
    if (s[near] > 0).sum() < (s[near] < 0).sum():
        fwd = -fwd
    # the back: the legs hang on the belly side — the scan reaches further from the body there
    h = (p - mid) @ up
    if abs(h.min()) < abs(h.max()):
        up = -up
    if "head" in flip: fwd = -fwd
    if "back" in flip: up = -up
    lr = np.cross(up, fwd)
    R = Matrix(((*fwd, 0), (*lr, 0), (*up, 0), (0, 0, 0, 1)))
    o.data.transform(Matrix.Translation(Vector(-mid)))
    o.data.transform(R)
    if axes:
        e = {"x": Vector((1, 0, 0)), "y": Vector((0, 1, 0)), "z": Vector((0, 0, 1))}
        ax = lambda t: -e[t[1]] if t[0] == "-" else e[t]
        hx, bz = ax(axes[0]), ax(axes[1])
        o.data.transform(Matrix((hx, bz.cross(hx), bz)).to_4x4())
    if rot:
        o.data.transform(Matrix.Rotation(math.radians(rot[2]), 4, "Z") @ Matrix.Rotation(math.radians(rot[1]), 4, "Y") @ Matrix.Rotation(math.radians(rot[0]), 4, "X"))
    # its box's middle at the origin, its longest reach one unit
    q = coords(o)
    lo_, hi_ = q.min(axis=0), q.max(axis=0)
    o.data.transform(Matrix.Scale(1.0 / float((hi_ - lo_).max()), 4) @ Matrix.Translation(Vector(-(lo_ + hi_) * 0.5)))
    o.data.update()
    return best[0]

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
        else:
            # (no texture: its flat colour)
            bsdf = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
            if bsdf: em.inputs["Color"].default_value = bsdf.inputs["Base Color"].default_value
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

def light(hi, name, tris):
    lo = hi.copy()
    lo.data = hi.data.copy()
    lo.name = name
    bpy.context.scene.collection.objects.link(lo)
    lo.data.materials.clear()
    only(lo)
    for _ in range(5):
        n = len(tri_idx(lo))
        if n <= tris * 1.15:
            break
        mod = lo.modifiers.new("d", "DECIMATE")
        mod.ratio = tris / n
        bpy.ops.object.modifier_apply(modifier=mod.name)
    if len(tri_idx(lo)) > tris * 1.25:
        mod = lo.modifiers.new("r", "REMESH")
        mod.mode = "VOXEL"
        mod.voxel_size = max(lo.dimensions) / 160.0
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
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 2
    b = sc.render.bake
    b.use_selected_to_active = True
    # (thin legs and wings: the bake looks only a little way off the light mesh)
    b.cage_extrusion = 0.008
    b.max_ray_distance = 0.025
    b.margin = 8
    bpy.ops.object.select_all(action="DESELECT")
    hi.select_set(True)
    lo.select_set(True)
    bpy.context.view_layer.objects.active = lo
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
    sc.render.resolution_x = sc.render.resolution_y = 300
    w = bpy.data.worlds.new("w")
    w.color = (0.05, 0.05, 0.06)
    sc.world = w
    cd = bpy.data.cameras.new("c")
    cd.type = "ORTHO"
    cd.ortho_scale = 1.15
    cam = bpy.data.objects.new("c", cd)
    sc.collection.objects.link(cam)
    sc.camera = cam
    # (from above: its back, head to the right; from its left side; three quarters from above and in front)
    for tag, d, upv in (("top", Vector((0, 0, 1)), Vector((0, 1, 0))), ("side", Vector((0, 1, 0)), Vector((0, 0, 1))),
                        ("tq", Vector((0.7, -0.6, 0.7)), Vector((0, 0, 1)))):
        d = d.normalized()
        cam.location = d * 6
        m = Matrix.Identity(3)
        z = d
        x = upv.cross(z).normalized()
        y = z.cross(x)
        m = Matrix((x, y, z)).transposed()
        cam.rotation_euler = m.to_euler()
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
    print("INSECT", M["name"], flush=True)
    hi = load(os.path.join(SRC, M["file"]))
    hi = animal(hi, M.get("gap", 0.04))
    err = orient(hi, M.get("flip", ""), M.get("rot"), M.get("axes"))
    full = len(tri_idx(hi))
    lo = light(hi, M["name"], M["tris"])
    print("INSECT %s: %d -> %d tris, size %s, mirror %.4f" % (M["name"], full, len(tri_idx(lo)), [round(v, 2) for v in lo.dimensions], err), flush=True)
    if PREVIEW:
        picture(lo, M["name"])
print("INSECT done")
