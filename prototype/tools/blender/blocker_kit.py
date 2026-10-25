# The board's blockers in the look of the gem sets (gem_kit.py): hewn, rounded blocks of rock that fill their cell,
# lit by the same lamp. One block, three rocks: mud (red-brown clay), sandstone (ochre, layered), granite (speckled).
# Granite takes two hits: after the first it is really split, into three pieces with gaps between and crumbs at its
# foot; the same cut gives the shards the game throws about when a blocker breaks.
#   blender -b -P blocker_kit.py -- <out_dir> [px] [samples] [only: name,...]
# writes <out_dir>/{mud,sand,granite,granite_cracked,gas}.png and <out_dir>/shards/<rock>_<k>.png
import bpy, sys, math, os, random, importlib.util
from mathutils import Vector, Quaternion
argv = sys.argv[sys.argv.index("--") + 1:]
OUT = argv[0]
PX = int(argv[1]) if len(argv) > 1 else 256
SAMPLES = int(argv[2]) if len(argv) > 2 else 128
ONLY = argv[3].split(",") if len(argv) > 3 else None

# the gem kit's scene, cutting and fitting, without running its renders
_real = sys.argv
sys.argv = ["blender", "--", OUT, str(PX), str(SAMPLES), "none"]
_spec = importlib.util.spec_from_file_location("gem_kit", os.path.join(os.path.dirname(__file__), "gem_kit.py"))
gk = importlib.util.module_from_spec(_spec); _spec.loader.exec_module(gk)
sys.argv = _real

SIZE = 0.86   # a blocker's width, in cells: it fills its cell more than a gem does

# each rock: the Poly Haven scan its colour and relief come from (art/textures, godot/assets/textures), how its colour
# is pushed, and extras. Granite has no usable scan (only polished tiles), so its grains are painted over a rock's relief
SCAN = {
    "rock_06": "art/textures/rock_06/rock_06",
    "rock_face_03": "godot/assets/textures/rock_face_03/rock_face_03",
}
ROCKS = {
    # pal: the reference's dark / mid / light, laid over the scan's own light and shade
    # mud: packed clay; its shading from a rough rock scan (the clay scans are too flat to read at this size)
    "mud":     dict(scan="rock_face_03", relief="rock_face_03", scale=0.8, seed=3,
                    pal=((0.09, 0.03, 0.01), (0.36, 0.14, 0.05), (0.7, 0.38, 0.2))),
    "sand":    dict(scan="rock_06", relief="rock_06", scale=0.7, seed=5,
                    pal=((0.3, 0.15, 0.04), (0.62, 0.38, 0.12), (0.9, 0.7, 0.38))),
    "granite": dict(scan=None, relief="rock_face_03", scale=0.9, base=(0.66, 0.53, 0.45), seed=7,
                    grains=((0.025, 0.022, 0.022), (0.7, 0.3, 0.12), (0.85, 0.8, 0.74))),
}

def lit_scene():
    sc = gk.setup()
    # rock is lit, not glowing: a stronger lamp and a little more sky than the gems get
    sun = bpy.data.objects["sun"]; sun.data.energy = 4.0
    bpy.data.worlds["w"].node_tree.nodes["Background"].inputs[1].default_value = 0.35
    return sc

def rock_mat(kind):
    R = ROCKS[kind]
    m = bpy.data.materials.new(kind); m.use_nodes = True
    n = m.node_tree; L = n.links; nd = n.nodes.new
    p = n.nodes["Principled BSDF"]
    pos = nd("ShaderNodeTexCoord").outputs["Object"]
    mp = nd("ShaderNodeMapping"); mp.inputs["Scale"].default_value = (R["scale"],) * 3
    mp.inputs["Location"].default_value = (R["seed"] * 0.37, R["seed"] * 0.71, 0)
    L.new(pos, mp.inputs["Vector"])
    def scan(name, suffix, data=True):
        t = nd("ShaderNodeTexImage")
        t.image = bpy.data.images.load(os.path.join(gk.PROJ, SCAN[name] + "_%s_1k.jpg" % suffix))
        if data: t.image.colorspace_settings.name = 'Non-Color'
        t.projection = 'BOX'; t.projection_blend = 0.35
        L.new(mp.outputs[0], t.inputs["Vector"])
        return t.outputs["Color"]
    def remap(v, f0, f1, t0, t1):
        k = nd("ShaderNodeMapRange")
        k.inputs["From Min"].default_value = f0; k.inputs["From Max"].default_value = f1
        k.inputs["To Min"].default_value = t0; k.inputs["To Max"].default_value = t1
        L.new(v, k.inputs["Value"]); return k.outputs[0]
    def mix(fac, a, b_col):
        k = nd("ShaderNodeMix"); k.data_type = 'RGBA'
        L.new(fac, k.inputs["Factor"]); L.new(a, k.inputs["A"]); k.inputs["B"].default_value = (*b_col, 1)
        return k.outputs[2]
    if R["scan"]:
        # the scan's light and shade, coloured with the reference's palette (its own colour has black stains)
        bw = nd("ShaderNodeRGBToBW"); L.new(scan(R["scan"], "diff", False), bw.inputs[0])
        lo = nd("ShaderNodeMapRange"); lo.inputs["From Min"].default_value = 0.05; lo.inputs["From Max"].default_value = 0.45
        L.new(bw.outputs[0], lo.inputs["Value"])
        ramp = nd("ShaderNodeValToRGB"); cr = ramp.color_ramp
        dark, mid, light = R["pal"]
        cr.elements[0].color = (*dark, 1); cr.elements[1].color = (*light, 1)
        e = cr.elements.new(0.45); e.color = (*mid, 1)
        L.new(lo.outputs[0], ramp.inputs["Fac"])
        col = ramp.outputs[0]
    else:
        # granite: a pale pinkish ground shaded by the relief scan, then grains of mica, feldspar and quartz
        h = scan(R["relief"], "disp")
        bw = nd("ShaderNodeRGBToBW"); L.new(h, bw.inputs[0])
        sh = nd("ShaderNodeMix"); sh.data_type = 'RGBA'
        L.new(remap(bw.outputs[0], 0.3, 0.8, 0.0, 1.0), sh.inputs["Factor"])
        sh.inputs["A"].default_value = (*(c * 0.55 for c in R["base"]), 1); sh.inputs["B"].default_value = (*R["base"], 1)
        col = sh.outputs[2]
        black, orange, white = R["grains"]
        for scale, colour, keep in ((24.0, black, 0.22), (17.0, orange, 0.17), (30.0, white, 0.14), (46.0, black, 0.2)):
            vo = nd("ShaderNodeTexVoronoi"); vo.inputs["Scale"].default_value = scale
            L.new(pos, vo.inputs["Vector"])
            sep = nd("ShaderNodeSeparateColor"); L.new(vo.outputs["Color"], sep.inputs[0])
            col = mix(remap(sep.outputs["Red"], keep - 0.03, keep, 1.0, 0.0), col, colour)
    # each hewn facet a touch lighter or darker, so the cuts read
    fa = nd("ShaderNodeVertexColor"); fa.layer_name = "facet"
    ft = nd("ShaderNodeMix"); ft.data_type = 'RGBA'; ft.blend_type = 'MULTIPLY'; ft.inputs["Factor"].default_value = 0.6
    L.new(col, ft.inputs["A"]); L.new(fa.outputs["Color"], ft.inputs["B"])
    col = ft.outputs[2]
    # light catching the chipped edges
    geo = nd("ShaderNodeNewGeometry")
    bv = nd("ShaderNodeBevel"); bv.inputs["Radius"].default_value = 0.02; bv.samples = 8
    dt = nd("ShaderNodeVectorMath"); dt.operation = 'DOT_PRODUCT'
    L.new(bv.outputs[0], dt.inputs[0]); L.new(geo.outputs["Normal"], dt.inputs[1])
    edge = nd("ShaderNodeMix"); edge.data_type = 'RGBA'; edge.blend_type = 'SCREEN'
    L.new(remap(dt.outputs["Value"], 0.999, 0.97, 0.0, 0.18), edge.inputs["Factor"]); L.new(col, edge.inputs["A"])
    edge.inputs["B"].default_value = (1, 0.95, 0.85, 1)
    L.new(edge.outputs[2], p.inputs["Base Color"])
    # the scan's relief: its normals, and its height as a strong bump, so the block looks hewn out of real rock
    nm = nd("ShaderNodeNormalMap"); nm.inputs["Strength"].default_value = 1.4
    L.new(scan(R["relief"], "nor_gl"), nm.inputs["Color"])
    bump = nd("ShaderNodeBump"); bump.inputs["Strength"].default_value = 0.6; bump.inputs["Distance"].default_value = 0.02
    L.new(scan(R["relief"], "disp"), bump.inputs["Height"]); L.new(nm.outputs[0], bump.inputs["Normal"])
    L.new(bump.outputs[0], p.inputs["Normal"])
    if R["scan"]:
        L.new(remap(scan(R["scan"], "rough"), 0.0, 1.0, 0.6, 1.0), p.inputs["Roughness"])
    else:
        p.inputs["Roughness"].default_value = 0.8
    return m

def block_planes(seed):
    """a hewn block: a rounded cube cut into many uneven facets"""
    return gk.block_planes(140, seed, 0.36, 0.3, 0.34, 3.0, (0.0, 0.045))

def size_up(objs, ref=None):
    """scale (and centre on screen) so the block is SIZE cells wide; the same factor for its pieces"""
    ref = ref or objs
    xs = [(o.matrix_world @ v.co).x for o in ref for v in o.data.vertices]
    k = SIZE / (max(xs) - min(xs))
    cx = (max(xs) + min(xs)) / 2
    for o in objs:
        o.scale = (k, k, k); o.location = (o.location - Vector((cx, 0, 0))) * k
    return k

def stone(kind):
    o = gk.cut(block_planes(ROCKS[kind]["seed"]), ROCKS[kind]["seed"], (0.55, 1.1))
    gk.paint_facets(o)
    o.data.materials.append(rock_mat(kind))
    return o

def split_planes(seed):
    """three pieces: a crack running down from the top and branching to the left and right"""
    rnd = random.Random(seed)
    hub = Vector((rnd.uniform(-0.04, 0.04), 0, rnd.uniform(-0.02, 0.06)))
    dirs = [math.radians(90 + rnd.uniform(-12, 12)), math.radians(210 + rnd.uniform(-12, 12)), math.radians(330 + rnd.uniform(-12, 12))]
    # piece k lies between crack k and crack k+1: the side of each crack plane facing the piece
    pieces = []
    for k in range(3):
        a0, a1 = dirs[k], dirs[(k + 1) % 3]
        n0 = Vector((math.sin(a0), 0, -math.cos(a0)))          # normal of crack k, pointing away from piece k
        n1 = Vector((-math.sin(a1), 0, math.cos(a1)))          # normal of crack k+1, pointing away from piece k
        mid = (a0 + ((a1 - a0) % math.tau) / 2)
        pieces.append(([(hub, n0), (hub, n1)], Vector((math.cos(mid), 0, math.sin(mid)))))
    return pieces

def cracked(kind, seed):
    base = block_planes(ROCKS[kind]["seed"])
    objs = []
    for k, (cuts, out) in enumerate(split_planes(seed)):
        o = gk.cut(base + cuts, ROCKS[kind]["seed"] + k, (0.55, 1.1))
        o.location = out * 0.018          # the pieces pulled apart a little: a dark gap shows between them
        objs.append(o)
    return objs

def crumbs(kind, seed, n=3):
    rnd = random.Random(seed)
    objs = []
    for k in range(n):
        s = rnd.uniform(0.05, 0.09) * (1.0 if k else 1.3)
        o = gk.cut(gk.block_planes(14, seed * 10 + k, s, s * 0.8, s * 0.9, 2.4, (0.0, 0.01)), seed * 10 + k, (0.5, 1.1))
        o.location = Vector((0.36 + rnd.uniform(0.0, 0.08), -0.05, -0.2 + k * 0.12 + rnd.uniform(-0.03, 0.03)))
        o.rotation_euler = (rnd.uniform(0, 6), rnd.uniform(0, 6), rnd.uniform(0, 6))
        objs.append(o)
    return objs

def render(name, objs, kind, ref=None):
    for o in objs:
        gk.paint_facets(o)
        if not o.data.materials: o.data.materials.append(MATS[kind])
    bpy.context.view_layer.update()
    size_up(objs, ref)
    path = os.path.join(OUT, name + ".png")
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("BLOCK", name)

os.makedirs(os.path.join(OUT, "shards"), exist_ok=True)
for kind in ROCKS:
    if ONLY and kind not in ONLY: continue
    lit_scene(); MATS = {kind: rock_mat(kind)}
    o = gk.cut(block_planes(ROCKS[kind]["seed"]), ROCKS[kind]["seed"], (0.55, 1.1))
    render(kind, [o], kind)
    # the shards: the block split as for the cracked stage, each piece on its own, at the block's scale
    for k in range(3):
        lit_scene(); MATS = {kind: rock_mat(kind)}
        pieces = cracked(kind, 11)
        for j, p in enumerate(pieces):
            if j != k: p.hide_render = True
        render("shards/%s_%d" % (kind, k), pieces, kind)
if not ONLY or "granite_cracked" in ONLY:
    lit_scene(); MATS = {"granite": rock_mat("granite")}
    pieces = cracked("granite", 11)
    render("granite_cracked", pieces + crumbs("granite", 13), "granite", ref=pieces)

# ---------------------------------------------------------------- gas
GAS = dict(core=(0.4, 0.85, 0.08), edge=(0.02, 0.12, 0.01))   # a toxic yellow-green, glowing at its heart

def gas_mat():
    """soft, glowing puffs: bright in the middle of each, thinning out to nothing at its rim"""
    m = bpy.data.materials.new("gas"); m.use_nodes = True
    n = m.node_tree; L = n.links; nd = n.nodes.new
    out = n.nodes["Material Output"]; n.nodes.remove(n.nodes["Principled BSDF"])
    lw = nd("ShaderNodeLayerWeight"); lw.inputs["Blend"].default_value = 0.55
    face = nd("ShaderNodeMath"); face.operation = 'SUBTRACT'; face.inputs[0].default_value = 1.0
    L.new(lw.outputs["Facing"], face.inputs[1])
    nz = nd("ShaderNodeTexNoise"); nz.inputs["Scale"].default_value = 4.0; nz.inputs["Detail"].default_value = 8; nz.inputs["Distortion"].default_value = 2.5
    wisp = nd("ShaderNodeMath"); wisp.operation = 'MULTIPLY'
    L.new(face.outputs[0], wisp.inputs[0]); L.new(nz.outputs["Fac"], wisp.inputs[1])
    ramp = nd("ShaderNodeValToRGB"); cr = ramp.color_ramp
    cr.elements[0].position = 0.08; cr.elements[0].color = (*GAS["edge"], 1)
    cr.elements[1].position = 0.7; cr.elements[1].color = (*GAS["core"], 1)
    L.new(wisp.outputs[0], ramp.inputs["Fac"])
    em = nd("ShaderNodeEmission"); em.inputs["Strength"].default_value = 0.9
    L.new(ramp.outputs[0], em.inputs["Color"])
    tr = nd("ShaderNodeBsdfTransparent")
    a = nd("ShaderNodeMapRange"); a.inputs["From Min"].default_value = 0.08; a.inputs["From Max"].default_value = 0.5; a.inputs["To Max"].default_value = 0.8
    L.new(wisp.outputs[0], a.inputs["Value"])
    mx = nd("ShaderNodeMixShader")
    L.new(a.outputs[0], mx.inputs[0]); L.new(tr.outputs[0], mx.inputs[1]); L.new(em.outputs[0], mx.inputs[2])
    L.new(mx.outputs[0], out.inputs["Surface"])
    return m

def gas():
    rnd = random.Random(17)
    gm = gas_mat()
    objs = []
    for k in range(9):
        a = k / 9 * math.tau + rnd.uniform(-0.3, 0.3)
        rr = 0.0 if k == 0 else rnd.uniform(0.15, 0.27)
        bpy.ops.mesh.primitive_uv_sphere_add(radius=rnd.uniform(0.16, 0.24) * (1.25 if k == 0 else 1.0),
                                             location=(math.cos(a) * rr, rnd.uniform(-0.1, 0.1), math.sin(a) * rr * 0.85))
        o = bpy.context.object; bpy.ops.object.shade_smooth()
        o.data.materials.append(gm)
        objs.append(o)
    return objs

if not ONLY or "gas" in ONLY:
    lit_scene()
    bpy.context.scene.cycles.transparent_max_bounces = 64
    objs = gas()
    bpy.context.view_layer.update()
    size_up(objs)
    bpy.context.scene.render.filepath = os.path.join(OUT, "gas.png")
    bpy.ops.render.render(write_still=True)
    print("BLOCK gas")
