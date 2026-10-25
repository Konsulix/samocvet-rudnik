# The board's big blocks (the user's reference sheet): a zone of w x h cells walled in hewn stone, one block per cell,
# veined gold (the find: a specimen sealed in the rock) or violet (a geode). They break in stages: cracks open,
# then the blocks split and fall away from the middle outwards, showing what is inside.
# Until they open the two look alike (only the faint vein colour differs), so a player has to look before blasting.
#   find   a golden nugget sealed inside; "open": the nest empty, the nugget spilled at the corner
#   geode  an amethyst-lined cave inside; "open": the rim of rock left standing round the cave (it stays on the board)
# Zone sizes: SIZES; stages 0 (whole) .. STAGES-1 (one hit from open). Same camera and lamp as the gem sets.
#   blender -b -P zone_kit.py -- <out_dir> [px_per_cell] [samples] [only: kind_w x h,...]
# writes <out_dir>/<kind>_<w>x<h>_<stage>.png and <kind>_<w>x<h>_open.png
import bpy, bmesh, sys, math, os, random, importlib.util
from mathutils import Vector, Quaternion
argv = sys.argv[sys.argv.index("--") + 1:]
OUT = argv[0]
PXC = int(argv[1]) if len(argv) > 1 else 160
SAMPLES = int(argv[2]) if len(argv) > 2 else 96
ONLY = argv[3].split(",") if len(argv) > 3 else None

_real = sys.argv
sys.argv = ["blender", "--", OUT, "64", str(SAMPLES), "none"]
_spec = importlib.util.spec_from_file_location("gem_kit", os.path.join(os.path.dirname(__file__), "gem_kit.py"))
gk = importlib.util.module_from_spec(_spec); _spec.loader.exec_module(gk)
sys.argv = _real

SIZES = [(2, 2), (2, 1), (1, 2), (3, 1), (1, 3)]
STAGES = 8
MARGIN = 0.12          # room round the zone in the sprite, in cells: chips and the shadow side
BLOCK = 0.47           # a cell's stone block, half width (0.5 = touching its neighbour)
VEIN = {"find": (0.62, 0.42, 0.18), "geode": (0.45, 0.32, 0.62)}   # faint: the two must look alike until they open

def scene(w, h):
    sc = gk.setup()
    span_x, span_y = w + MARGIN * 2, h + MARGIN * 2
    sc.render.resolution_x = round(span_x * PXC); sc.render.resolution_y = round(span_y * PXC)
    cam = sc.camera; cam.data.ortho_scale = max(span_x, span_y)
    bpy.data.objects["sun"].data.energy = 4.0
    bpy.data.worlds["w"].node_tree.nodes["Background"].inputs[1].default_value = 0.35
    return sc

def stone_mat(kind):
    """dark hewn stone, its veins gold (the find) or violet (a geode), each facet its own shade"""
    m = bpy.data.materials.new("stone_" + kind); m.use_nodes = True
    n = m.node_tree; L = n.links; nd = n.nodes.new
    p = n.nodes["Principled BSDF"]
    pos = nd("ShaderNodeTexCoord").outputs["Object"]
    mp = nd("ShaderNodeMapping"); mp.inputs["Scale"].default_value = (1.4, 1.4, 1.4)
    L.new(pos, mp.inputs["Vector"])
    def scan(suffix, data=True, path="godot/assets/textures/rock_face_03/rock_face_03_%s_1k.jpg"):
        t = nd("ShaderNodeTexImage"); t.image = bpy.data.images.load(os.path.join(gk.PROJ, path % suffix))
        if data: t.image.colorspace_settings.name = 'Non-Color'
        t.projection = 'BOX'; t.projection_blend = 0.35
        L.new(mp.outputs[0], t.inputs["Vector"]); return t.outputs["Color"]
    bw = nd("ShaderNodeRGBToBW"); L.new(scan("diff", False), bw.inputs[0])
    lv = nd("ShaderNodeMapRange"); lv.inputs["From Min"].default_value = 0.05; lv.inputs["From Max"].default_value = 0.4
    L.new(bw.outputs[0], lv.inputs["Value"])
    ramp = nd("ShaderNodeValToRGB"); cr = ramp.color_ramp
    cr.elements[0].color = (0.025, 0.024, 0.023, 1); cr.elements[1].color = (0.36, 0.34, 0.32, 1)
    e = cr.elements.new(0.5); e.color = (0.12, 0.115, 0.11, 1)
    L.new(lv.outputs[0], ramp.inputs["Fac"])
    col = ramp.outputs[0]
    fa = nd("ShaderNodeVertexColor"); fa.layer_name = "facet"
    ft = nd("ShaderNodeMix"); ft.data_type = 'RGBA'; ft.blend_type = 'MULTIPLY'; ft.inputs["Factor"].default_value = 0.6
    L.new(col, ft.inputs["A"]); L.new(fa.outputs["Color"], ft.inputs["B"]); col = ft.outputs[2]
    # veins: thin diagonal streaks, as in the reference
    wv = nd("ShaderNodeTexWave"); wv.wave_type = 'BANDS'; wv.bands_direction = 'DIAGONAL'
    wv.inputs["Scale"].default_value = 2.2; wv.inputs["Distortion"].default_value = 6.0; wv.inputs["Detail"].default_value = 4
    L.new(pos, wv.inputs["Vector"])
    vr = nd("ShaderNodeMapRange"); vr.inputs["From Min"].default_value = 0.93; vr.inputs["From Max"].default_value = 1.0
    vr.inputs["To Max"].default_value = 0.45
    L.new(wv.outputs["Fac"], vr.inputs["Value"])
    vn = nd("ShaderNodeTexNoise"); vn.inputs["Scale"].default_value = 3.0
    L.new(pos, vn.inputs["Vector"])
    gate = nd("ShaderNodeMapRange"); gate.inputs["From Min"].default_value = 0.42; gate.inputs["From Max"].default_value = 0.55
    L.new(vn.outputs["Fac"], gate.inputs["Value"])
    vk = nd("ShaderNodeMath"); vk.operation = 'MULTIPLY'
    L.new(vr.outputs[0], vk.inputs[0]); L.new(gate.outputs[0], vk.inputs[1])
    mv = nd("ShaderNodeMix"); mv.data_type = 'RGBA'
    L.new(vk.outputs[0], mv.inputs["Factor"]); L.new(col, mv.inputs["A"]); mv.inputs["B"].default_value = (*VEIN[kind], 1)
    L.new(mv.outputs[2], p.inputs["Base Color"])
    L.new(mv.outputs[2], p.inputs["Emission Color"])
    em = nd("ShaderNodeMath"); em.operation = 'MULTIPLY_ADD'; em.inputs[1].default_value = 0.15; em.inputs[2].default_value = 0.08
    L.new(vk.outputs[0], em.inputs[0]); L.new(em.outputs[0], p.inputs["Emission Strength"])
    p.inputs["Roughness"].default_value = 0.8
    nm = nd("ShaderNodeNormalMap"); nm.inputs["Strength"].default_value = 1.3
    L.new(scan("nor_gl"), nm.inputs["Color"]); L.new(nm.outputs[0], p.inputs["Normal"])
    return m

def amethyst_mat():
    m = bpy.data.materials.new("amethyst"); m.use_nodes = True
    n = m.node_tree; p = n.nodes["Principled BSDF"]
    fa = n.nodes.new("ShaderNodeVertexColor"); fa.layer_name = "facet"
    ramp = n.nodes.new("ShaderNodeValToRGB"); cr = ramp.color_ramp
    cr.elements[0].color = (0.02, 0.006, 0.04, 1); cr.elements[1].color = (0.42, 0.26, 0.62, 1)   # deep, as in the drawing
    bw = n.nodes.new("ShaderNodeRGBToBW"); n.links.new(fa.outputs["Color"], bw.inputs[0])
    n.links.new(bw.outputs[0], ramp.inputs["Fac"])
    n.links.new(ramp.outputs[0], p.inputs["Base Color"]); n.links.new(ramp.outputs[0], p.inputs["Emission Color"])
    p.inputs["Emission Strength"].default_value = 0.12; p.inputs["Roughness"].default_value = 0.25
    p.inputs["Coat Weight"].default_value = 0.6
    return m

def cell_pieces(cx, cz, inward, seed):
    """a cell's block cut in three by two planes through a point near its inner corner: the piece facing the
    zone's middle, and two behind it. Returns (object, how far towards the middle it faces)"""
    rnd = random.Random(seed)
    # a pillow of rock: a rounded block cut into many small, uneven facets, as in the drawing
    base = gk.block_planes(150, seed, BLOCK, 0.27, BLOCK, 2.7, (0.0, 0.022))
    hub = Vector((inward.x * 0.12 + rnd.uniform(-0.05, 0.05), 0, inward.z * 0.12 + rnd.uniform(-0.05, 0.05)))
    a0 = math.atan2(inward.z, inward.x)
    # first cut: across the inward direction; second: splitting the back half in two
    d1 = Vector((math.cos(a0 + rnd.uniform(-0.3, 0.3)), rnd.uniform(-0.1, 0.1), math.sin(a0 + rnd.uniform(-0.3, 0.3)))).normalized()
    d2 = Vector((-d1.z, rnd.uniform(-0.1, 0.1), d1.x)).normalized()
    hub2 = hub - d1 * 0.12
    # gk.cut keeps what lies behind each plane's normal
    parts = [([(hub, -d1)], d1),                          # the inner piece: on the inward side of the first cut
             ([(hub, d1), (hub2, -d2)], (-d1 + d2).normalized()),
             ([(hub, d1), (hub2, d2)], (-d1 - d2).normalized())]
    out = []
    for k, (cuts, d) in enumerate(parts):
        o = gk.cut(base + cuts, seed * 10 + k, (0.55, 1.1))
        o.location = Vector((cx, 0, cz))
        o["out"] = Vector((d.x, 0, d.z))
        out.append((o, d.dot(inward)))
    return out

def gold_mat():
    """a faceted gold nugget: metal, each facet catching the lamp its own way, warm and bright"""
    m = bpy.data.materials.new("gold"); m.use_nodes = True
    n = m.node_tree; p = n.nodes["Principled BSDF"]
    fa = n.nodes.new("ShaderNodeVertexColor"); fa.layer_name = "facet"
    bw = n.nodes.new("ShaderNodeRGBToBW"); n.links.new(fa.outputs["Color"], bw.inputs[0])
    ramp = n.nodes.new("ShaderNodeValToRGB"); cr = ramp.color_ramp
    cr.elements[0].color = (0.12, 0.055, 0.015, 1); cr.elements[1].color = (0.75, 0.45, 0.16, 1)   # old bronzy gold
    n.links.new(bw.outputs[0], ramp.inputs["Fac"])
    n.links.new(ramp.outputs[0], p.inputs["Base Color"])
    n.links.new(ramp.outputs[0], p.inputs["Emission Color"])
    p.inputs["Emission Strength"].default_value = 0.06
    p.inputs["Metallic"].default_value = 1.0; p.inputs["Roughness"].default_value = 0.42
    return m

def rubble_floor(centre, rx, rz, mat, rnd, n):
    """the floor of an emptied hollow: loose broken stone"""
    for k in range(n):
        a = rnd.uniform(0, math.tau); rr = math.sqrt(rnd.random())
        s = rnd.uniform(0.035, 0.07)
        o = gk.cut(gk.block_planes(12, 1500 + k, s, s * 0.7, s, 2.4, (0.0, 0.01)), 1500 + k, (0.3, 0.9))
        gk.paint_facets(o); o.data.materials.append(mat)
        o.rotation_euler = (rnd.uniform(0, 6), rnd.uniform(0, 6), rnd.uniform(0, 6))
        o.location = centre + Vector((math.cos(a) * rx * rr, 0.14, math.sin(a) * rz * rr))

def cave_mat():
    m = bpy.data.materials.new("cave"); m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (0.018, 0.016, 0.015, 1); p.inputs["Roughness"].default_value = 0.95
    return m

def zone(kind, w, h, stage, open_=False):
    """stage 0..STAGES-1 as the hits land; open_: after the last one (the find taken out, the geode emptied)"""
    rnd = random.Random(w * 7 + h)
    sm = stone_mat(kind)
    centre = Vector(((w - 1) / 2, 0, -(h - 1) / 2))
    # the bed under the blocks: dark rock, so the joints and the hole read as depth
    bpy.ops.mesh.primitive_cube_add(size=1, location=centre + Vector((0, 0.22, 0)))
    bed = bpy.context.object; bed.scale = (w - 0.1, 0.12, h - 0.1)
    bv = bed.modifiers.new("b", 'BEVEL'); bv.width = 0.1; bv.segments = 3
    bed.data.materials.append(cave_mat())
    pieces = []
    order = list(range(w * h)); rnd.shuffle(order)       # which cell cracks first, second...
    for r in range(h):
        for c in range(w):
            rank = order.index(r * w + c)
            p = Vector((c, 0, -r))
            inward = (centre - p)
            inward = inward.normalized() if inward.length > 1e-3 else Vector((rnd.uniform(-1, 1), 0, rnd.uniform(-1, 1))).normalized()
            # the same cut for both kinds: until it opens, a geode and a find look alike
            for o, close in cell_pieces(p.x, p.z, inward, 400 + r * 17 + c * 5):
                gk.paint_facets(o); o.data.materials.append(sm)
                o["rank"] = rank
                pieces.append((o, close + rnd.uniform(-0.1, 0.1)))
    # the order they fall: the pieces facing the middle first
    pieces.sort(key=lambda t: -t[1])
    inner = len(pieces) // 3
    # stage 0 whole, 1-2 cracks, 3.. the inner pieces fall away a few at a time; open: all the inner ones gone
    if open_: gone = inner
    else: gone = 0 if stage < 3 else round((stage - 2) / (STAGES - 2) * inner)
    spread = 0.0 if stage == 0 and not open_ else 0.01 + min(stage, 4) * 0.007
    for i, (o, close) in enumerate(pieces):
        if i < gone:
            bpy.data.objects.remove(o)
            continue
        # a cell's block splits only once the cracks have reached it: one at the first hit, all by the third
        cracked = open_ or o["rank"] < max(0.0, stage) * (w * h) / 3.0
        o.location += Vector(o["out"]) * (spread if cracked else 0.0)
        if (stage >= 2 or open_) and i < gone + 2:
            o.rotation_euler = (rnd.uniform(-0.12, 0.12), rnd.uniform(-0.15, 0.15), rnd.uniform(-0.12, 0.12))
    # rubble at the foot once it breaks open
    if stage >= 4 or open_:
        for k in range(2 + min(stage, 6)):
            s = rnd.uniform(0.04, 0.075)
            o = gk.cut(gk.block_planes(12, 900 + k, s, s * 0.8, s, 2.4, (0.0, 0.01)), 900 + k, (0.5, 1.1))
            gk.paint_facets(o); o.data.materials.append(sm)
            o.location = Vector((rnd.uniform(-0.45, w - 0.55), -0.28, -(h - 0.5) + rnd.uniform(-0.04, 0.1)))
    # what is inside: nothing until a piece has fallen, so through the cracks a find and a geode look the same
    hidden = gone == 0 and not open_
    rx, rz = min(w, h) * 0.32 + (w - min(w, h)) * 0.45, min(w, h) * 0.32 + (h - min(w, h)) * 0.45
    if hidden:
        pass
    elif kind == "geode":
        am = amethyst_mat()
        n = int(320 * rx * rz)
        for k in range(n):
            a = rnd.uniform(0, math.tau); rr = math.sqrt(rnd.random())
            # a bowl: the crystals near its rim stand further forward, those in the middle sit deep
            at = centre + Vector((math.cos(a) * rx * rr, 0.16 - rr * rr * 0.12, math.sin(a) * rz * rr))
            sz = rnd.uniform(0.06, 0.11) * (0.75 if open_ else 1.0)
            spin = rnd.uniform(0, 6)
            pl = gk.ring_planes(6, sz * 0.55, 0, 0.0, spin)
            pl += gk.ring_planes(6, sz * 0.35, sz * 1.3, math.radians(58), spin)
            pl.append((Vector((0, 0, -sz)), Vector((0, 0, -1))))
            o = gk.cut(pl, 1000 + k, (0.35, 1.2))
            gk.paint_facets(o); o.data.materials.append(am)
            o.rotation_mode = 'QUATERNION'
            o.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(Vector((rnd.uniform(-0.5, 0.5), -1, rnd.uniform(-0.5, 0.5))).normalized())
            o.location = at
        if open_:
            # a few loose crystals spilled at the foot
            for k in range(5):
                sz = rnd.uniform(0.04, 0.06)
                o = gk.cut(gk.ring_planes(6, sz * 0.55, 0, 0.0, 0) + gk.ring_planes(6, sz * 0.3, sz, math.radians(58), 0)
                           + [(Vector((0, 0, -sz)), Vector((0, 0, -1)))], 1300 + k, (0.35, 1.2))
                gk.paint_facets(o); o.data.materials.append(am)
                o.rotation_euler = (rnd.uniform(0, 6), rnd.uniform(0, 6), rnd.uniform(0, 6))
                o.location = Vector((rnd.uniform(w * 0.3, w - 0.5), -0.28, -(h - 0.55) + rnd.uniform(-0.03, 0.08)))
    else:
        # a golden nugget sealed in the rock; once taken, it lies spilled at the corner
        gm = gold_mat()
        s = min(rx, rz) * 0.75
        o = gk.cut(gk.egg_planes(110, 77, w=s, d=s * 0.75, h=s * 1.05, point=0.2, low=0.05, depth=(0.0, 0.015)), 77, (0.4, 1.2))
        gk.paint_facets(o); o.data.materials.append(gm)
        o.rotation_euler = (math.pi / 2, 0, 0.3)
        if open_:
            rubble_floor(centre, rx * 0.9, rz * 0.9, sm, rnd, int(40 * rx * rz))
            o.scale = (0.75, 0.75, 0.75)
            o.location = Vector((w - 0.55, -0.15, -(h - 0.62)))
        else:
            o.location = centre + Vector((0, 0.06, 0))     # set back in its nest, behind the blocks' faces
    root = bpy.data.objects.new("root", None); bpy.context.scene.collection.objects.link(root)
    for o in list(bpy.context.scene.objects):
        if o.type == 'MESH' and o.parent is None:
            o.parent = root
    root.location = -centre

def render(kind, w, h, stage, open_=False):
    sc = scene(w, h)
    zone(kind, w, h, stage, open_)
    tag = "%s_%dx%d_%s" % (kind, w, h, "open" if open_ else stage)
    sc.render.filepath = os.path.join(OUT, tag + ".png")
    bpy.ops.render.render(write_still=True)
    print("ZONE", tag)

os.makedirs(OUT, exist_ok=True)
for kind in ("find", "geode"):
    for w, h in SIZES:
        key = "%s_%dx%d" % (kind, w, h)
        if ONLY and key not in ONLY: continue
        for s in range(STAGES):
            render(kind, w, h, s)
        render(kind, w, h, STAGES - 1, open_=True)
