# Sea life for the sea floor of the sea finds (SpecSea: a trilobite's or an ammonite's slab): downloaded scans and
# models (.glb, see godot/assets/specimen/sea/CREDITS.md) -> a light mesh each with its colour and relief baked into two
# small textures. The flowers' tool (../flowers/flower_prep.py): the scanner's colour cube dropped, the pieces lying
# together kept as one, set on its foot at the origin.
#   blender -b -P sea_prep.py -- <Desktop/sea> <godot/assets/specimen/sea> [name,name...] [preview dir]
# Out: <name>.obj, <name>_d.png, <name>_n.png. With a preview dir, pictures of every result are rendered there.
import bpy, sys, os, math
import numpy as np
from mathutils import Vector, Matrix

argv = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT = argv[0], argv[1]
ONLY = [s for s in argv[2].split(",") if s] if len(argv) > 2 and argv[2] != "-" else []
PREVIEW = argv[3] if len(argv) > 3 else ""
TEX = 512
CUR_TEX = TEX

# name: file (under Desktop/sea); tris: the light mesh's triangles; tex: the baked textures' size (512);
# reach: lying or swimming — its longest reach one unit, its box's middle over the origin (else stood on its foot, one
# unit tall); turn: degrees about the up axis (a swimmer: its head to +X); tilt: degrees about X and Y, by hand;
# orient: "pca" — stood by its own shape (see stand); gap: how far apart two pieces are still one, of its size
MODELS = [
    # weed: stands and sways
    dict(name="weed_claret", file="водоросли/claret_tall_seaweed.glb", tris=4000),
    dict(name="weed_wiggle", file="водоросли/claret_wiggle_seaweed (1).glb", tris=4000),
    dict(name="weed_kelp", file="водоросли/kelp_with_animation.glb", tris=6000, gap=0.3),
    # corals and anemones: stand
    dict(name="coral_red", file="кораллы и ко/corallium_rubrum.glb", tris=8000),
    dict(name="coral_organ", file="кораллы и ко/organ_pipe_coral_nhmw-zoo-ev-0000128.glb", tris=7000),
    dict(name="coral_blue", file="кораллы и ко/blue_coral.glb", tris=7000),
    dict(name="coral_staghorn", file="кораллы и ко/staghorn_coral.glb", tris=8000),
    dict(name="coral_pocillopora", file="кораллы и ко/pocillopora_verrucosa_fresh_sample.glb", tris=7000),
    dict(name="coral_rosebrain", file="кораллы и ко/rose_brain_coral.glb", tris=6000),
    dict(name="anemone_elegant", file="кораллы и ко/elegant_anemone_sagartia_elegans.glb", tris=5000, tilt=(180, 0)),
    dict(name="anemone_purple", file="кораллы и ко/purple_sea_anemone_l.glb", tris=5000),
    # stars and urchins: lie
    dict(name="star_bat", file="звезды и еж/cc0__blue_bat_star_patiria_pectinifera.glb", tris=4000, reach=True),
    dict(name="star_brittle", file="звезды и еж/cc0__brittle_star_o._japonicus.glb", tris=4000, reach=True),
    dict(name="star_brittle_b", file="звезды и еж/cc0__brittle_star_o._lopendrina.glb", tris=4000, reach=True),
    dict(name="star_sand", file="звезды и еж/cc0__sand_sea_star_astropecten_scoparius.glb", tris=4000, reach=True),
    dict(name="star_cushion", file="звезды и еж/cushion_sea_star.glb", tris=4000, reach=True, tilt=(-90, 0)),
    dict(name="star_sea", file="звезды и еж/sea_star.glb", tris=4000, reach=True, tilt=(-90, 0)),
    dict(name="star_sunflower", file="звезды и еж/sunflower_sea_star.glb", tris=5000, reach=True, tilt=(-90, 0)),
    dict(name="urchin_purple", file="звезды и еж/cc0__purple_sea_urchin_h._crassispina.glb", tris=8000, reach=True),
    # shells: lie
    # (shell_top: the scan's texture is a mosaic of tiny islands, it falls to a jumble at any light size — not used)
    # dict(name="shell_top", file="ракушки/818ed75ca81c46abb7133ff8bae3539e.glb", tris=5000, reach=True, weld=3.0, min_tris=1, gap=0.1, keep_uv=True, tex=1024),
    dict(name="shell_tun", file="ракушки/cc0___giant_tun_tonna_olearium.glb", tris=5000, reach=True),
    dict(name="shell_triton", file="ракушки/cc0___knobbed_triton_charonia_lampas.glb", tris=5000, reach=True),
    # (shell_neptune: the scan's texture is a mosaic of tiny islands, it falls to a jumble at any light size — not used)
    # dict(name="shell_neptune", file="ракушки/cc0___thick_neptune_snail_n._heros.glb", tris=5000, reach=True, weld=3.0, min_tris=1, gap=0.1, keep_uv=True, tex=1024),
    dict(name="shell_tridacna", file="ракушки/cc0__boring_clam_tridacna_crocea.glb", tris=5000, reach=True),
    dict(name="shell_moon", file="ракушки/cc0__japanses_moon_scallop_y._japonicum.glb", tris=4000, reach=True),
    dict(name="shell_noble", file="ракушки/cc0__noble_scallop_mimachlamys_nobilis.glb", tris=5000, reach=True),
    dict(name="shell_cone", file="ракушки/snail_conus_marmoreus_pri_76850.glb", tris=4000, reach=True),
    # crabs and the like: lie
    dict(name="crab_lobster", file="крабы/888d324fef46406483039db4aa080d08.glb", tris=6000, reach=True),
    dict(name="crab_hermit_b", file="крабы/a7216d61f2d7401a97da99a4a8ee6823.glb", tris=6000, reach=True),
    dict(name="crab_hermit_c", file="крабы/cc0__mediterranean_hermit_crab.glb", tris=6000, reach=True),
    dict(name="crab_fiddler", file="крабы/cc0____bowed_fiddler_crab_t._arcuata.glb", tris=6000, reach=True),
    dict(name="crab_frog", file="крабы/cc0____red_frog_crab_ranina_ranina.glb", tris=6000, reach=True),
    # (crab_snow: long legs, the slab has no room for it — not used)
    # dict(name="crab_snow", file="крабы/cc0____snow_crab_chionoecetes_opilio.glb", tris=6000, reach=True),
    dict(name="crab_elbow", file="крабы/cc0___elbow_crab_parthenope_validus.glb", tris=6000, reach=True),
    dict(name="crab_mantis", file="крабы/cc0___japanese_mantis_shrimp_o._oratoria.glb", tris=6000, reach=True),
    dict(name="crab_isopod", file="крабы/cc0__giant_isopod_b._doederleinii.glb", tris=6000, reach=True),
    # the big swimmers round the find (the butterflies of the sea): head to +X
    dict(name="swim_coelacanth", file="живность большая/coelacanth.glb", tris=6000, tex=1024, reach=True, turn=180),
    dict(name="swim_cretoxyrhina", file="живность большая/cretoxyrhina.glb", tris=6000, tex=1024, reach=True, turn=90),
    # (swim_dolichorhynchops: its surface comes inside out: black, in shards — not used)
    # dict(name="swim_dolichorhynchops", file="живность большая/dolichorhynchops.glb", tris=6000, tex=1024, reach=True, gap=-1.0, turn=90),
    # (the mosasaur comes on its back: rolled over — its flippers down, the fluke's lobe up)
    dict(name="swim_mosasaurus", file="живность большая/mosasaurus.glb", tris=6000, tex=1024, reach=True, tilt=(90, 90), mouth=(0.376, 0.064, 0.0)),
    dict(name="swim_ophthalmosaurus", file="живность большая/opthalmosaurus.glb", tris=6000, tex=1024, reach=True, gap=-1.0, turn=90),
    # (swim_turtle: no plastron: an open shell from below — not used)
    # dict(name="swim_turtle", file="живность большая/sea_turtle.glb", tris=6000, tex=1024, reach=True),
    dict(name="swim_styxosaurus", file="живность большая/styxosaurus_snowii.glb", tris=6000, tex=1024, reach=True, turn=90, mouth=(0.4533, 0.1608, -0.114)),
    dict(name="swim_tylosaurus", file="живность большая/tylosaurus.glb", tris=6000, tex=1024, reach=True, turn=90, mouth=(0.353, 0.107, -0.065)),
    dict(name="swim_dallasaurus", file="живность большая/dallasaurus.glb", tris=6000, tex=1024, reach=True, turn=90),
    # (the octopus: a soft flat body, its arms close together — the light mesh lies further off the scan than a stiff
    # shell's does, and the bake's rays fell short: black patches. It looks further (cage), and is a little less light.
    # The tips of its arms come off the scan in loose scraps, a row of dashes in the water: only its one whole piece is kept — `whole`)
    dict(name="swim_octopus", file="живность большая/cc0___north_pacific_giant_octopus.glb", tris=9000, tex=1024, reach=True, cage=2.5, whole=True),
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

def load(path, weld=1.0):
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
    bpy.ops.mesh.remove_doubles(threshold=edge / 6.0 * weld)
    bpy.ops.object.mode_set(mode="OBJECT")
    return hi

def parts(hi, split, gap_k=0.035, min_tris=20):
    # the plants of the file: its pieces (petals, stamens, leaves are often loose) gathered into the ones standing
    # together; specks go, and the scanner's colour cube — a small piece as wide as it is tall and deep, off to a side
    f = tri_idx(hi)
    co = coords(hi)
    lab = components(f, len(hi.data.vertices))
    roots, counts = np.unique(lab[f[:, 0]], return_counts=True)
    big = roots[counts >= min_tris]
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

def stand(o, orient, keep_top, tilt, reach=False, turn=0.0):
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
    if tilt or turn:
        tilt = tilt or (0.0, 0.0)
        m = Matrix.Rotation(math.radians(turn), 4, "Z") @ Matrix.Rotation(math.radians(tilt[0]), 4, "X") @ Matrix.Rotation(math.radians(tilt[1]), 4, "Y")
        o.data.transform(m)
        co = coords(o)
    if keep_top:
        z0, z1 = co[:, 2].min(), co[:, 2].max()
        cut = z1 - (z1 - z0) * keep_top
        delete_verts(o, co[:, 2] < cut)
        co = coords(o)
    # on its foot at the origin, one unit tall (or, a thing lying or swimming — a star, a shell, a crab, a fish — its
    # box's middle over the origin and its longest reach one unit)
    z0, z1 = co[:, 2].min(), co[:, 2].max()
    foot = co[co[:, 2] < z0 + (z1 - z0) * 0.05].mean(axis=0)
    s = 1.0 / (z1 - z0)
    if reach:
        lo_, hi_ = co.min(axis=0), co.max(axis=0)
        foot = (lo_ + hi_) * 0.5
        s = 1.0 / float((hi_ - lo_).max())
    o.data.transform(Matrix.Scale(s, 4) @ Matrix.Translation(Vector((-foot[0], -foot[1], -z0))))
    o.data.update()

def image_mat(o, name, colour):
    img = bpy.data.images.new(name, CUR_TEX, CUR_TEX, alpha=False)
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
        else:
            # (no texture: its colour in its vertices — a red coral, a turtle — or the material's flat colour)
            bsdf = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
            if o.data.color_attributes:
                vc = nt.nodes.new("ShaderNodeVertexColor")
                vc.layer_name = o.data.color_attributes[0].name
                nt.links.new(vc.outputs["Color"], em.inputs["Color"])
            elif bsdf:
                em.inputs["Color"].default_value = bsdf.inputs["Base Color"].default_value
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
        # (not across the unwrap's seams: a welded scan's islands would be torn into a jumble of triangles)
        mod.delimit = {"UV"}
        bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.ops.object.shade_smooth()
    # the scan's textures (a big scan is cut into several, each part of the plant on its own): laid side by side in one
    # picture (2x2), each part's unwrap moved onto its own quarter
    imgs = []
    of_mat = []
    used = set(p.material_index for p in lo.data.polygons)   # (the colour cube's own texture went with it)
    for mi, mat in enumerate(lo.data.materials):
        im = None
        if mi in used and mat and mat.use_nodes:
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

def cut_mouth(lo, mouth):
    # a model whose lips are one skin (its teeth painted across them) cannot open its mouth: the jaw turned, the skin
    # between only stretches. The light mesh is cut along the mouth's line, before the hinge — mouth: (x, up, slope) of
    # the hinge and the line, as the game's model has them (SpecReef.MODELS jaw_x, jaw_y, jaw_s) — and the two lips
    # parted, each with its own vertices
    import bmesh
    jx, jy, js = mouth
    bm = bmesh.new()
    bm.from_mesh(lo.data)
    faces = [f for f in bm.faces if all(v.co.x > jx for v in f.verts)]
    geom = list({v for f in faces for v in f.verts}) + list({e for f in faces for e in f.edges}) + faces
    co, no = Vector((jx, 0.0, jy)), Vector((-js, 0.0, 1.0)).normalized()
    res = bmesh.ops.bisect_plane(bm, geom=geom, dist=1e-6, plane_co=co, plane_no=no)
    edges = [g for g in res["geom_cut"] if isinstance(g, bmesh.types.BMEdge)]
    # every face before the hinge and under the line is the lower jaw's: parted from the rest, with vertices of its own
    # all along the line (teeth are thin spikes: parting only the cut's edges left some of them joined across it)
    lower = [f for f in bm.faces if all(v.co.x > jx for v in f.verts) and (f.calc_center_median() - co).dot(no) < 0.0]
    bmesh.ops.split(bm, geom=lower, use_only_faces=True)
    lower = [f for f in bm.faces if all(v.co.x > jx for v in f.verts) and (f.calc_center_median() - co).dot(no) < 0.0]
    low_v = {v for f in lower for v in f.verts}
    # (the two lips lie one on the other: each is moved a hair to its own side of the line, so the game's shader can
    # tell the lower jaw's from the upper's by where they are; off the line the parting is sewn up again)
    # (and not only the cut's own vertices: the lips' lie within a hair of the line too, some on the wrong side of it)
    on = [v for v in bm.verts if v.co.x > jx - 1e-4 and abs((v.co - co).dot(no)) < 0.002]
    for v in on:
        v.co += no * ((-0.002 if v in low_v else 0.002) - (v.co - co).dot(no))
    on_set = set(on)
    bmesh.ops.remove_doubles(bm, verts=[v for v in bm.verts if v not in on_set], dist=1e-7)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    bm.to_mesh(lo.data)
    bm.free()
    lo.data.update()
    print("  mouth cut: %d edges" % len(edges), flush=True)

def one_piece(lo):
    # only the largest piece of the light mesh is kept: an octopus's thin arm tips come out of the lightening as loose
    # scraps, a row of dashes in the water behind each arm
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(lo.data)
    seen, best = set(), []
    for v0 in bm.verts:
        if v0 in seen:
            continue
        isle, stack = [], [v0]
        seen.add(v0)
        while stack:
            v = stack.pop()
            isle.append(v)
            for e in v.link_edges:
                w = e.other_vert(v)
                if w not in seen:
                    seen.add(w)
                    stack.append(w)
        if len(isle) > len(best):
            best = isle
    keep = set(best)
    drop = [v for v in bm.verts if v not in keep]
    print("  one piece: %d loose vertices dropped" % len(drop), flush=True)
    bmesh.ops.delete(bm, geom=drop, context="VERTS")
    bm.to_mesh(lo.data)
    bm.free()
    lo.data.update()

def light(hi, name, tris, remesh=False, cage=1.0, mouth=None, whole=False):
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
    if remesh or len(tri_idx(lo)) > tris * 1.25:
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
    if whole:
        one_piece(lo)
    if mouth:
        cut_mouth(lo, mouth)
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
    b.cage_extrusion = 0.012 * wide * cage
    b.max_ray_distance = 0.035 * wide * cage
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
    cd.ortho_scale = 1.25 * max(1.0, max(lo.dimensions))
    cam = bpy.data.objects.new("c", cd)
    sc.collection.objects.link(cam)
    sc.camera = cam
    for tag, d in (("a", Vector((0.9, -1.0, 0.3))), ("b", Vector((-0.2, -0.3, -1.0))), ("f", Vector((0.0, -1.0, 0.0))), ("s", Vector((1.0, 0.0, 0.0)))):
        d = d.normalized()
        cam.location = Vector((0, 0, lo.dimensions.z * 0.5)) + d * 6
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
    CUR_TEX = M.get("tex", TEX)
    hi = load(os.path.join(SRC, M["file"]), M.get("weld", 1.0))
    split = M.get("split", 1)
    for k, part in enumerate(parts(hi, split, M.get("gap", 0.035), M.get("min_tris", 20))):
        name = M["name"] + ("_%d" % k if split > 1 else "")
        print("SEA", name, flush=True)
        stand(part, M.get("orient", False), M.get("keep_top", 0.0), M.get("tilt"), M.get("reach", False), M.get("turn", 0.0))
        full = len(tri_idx(part))
        lo = light_uv(part, name, M["tris"], M.get("tex", TEX)) if M.get("keep_uv") else light(part, name, M["tris"], M.get("remesh", False), M.get("cage", 1.0), M.get("mouth"), M.get("whole", False))
        print("SEA %s: %d -> %d tris, size %s" % (name, full, len(tri_idx(lo)), [round(v, 2) for v in lo.dimensions]), flush=True)
        if PREVIEW:
            picture(lo, name)
print("SEA done")
