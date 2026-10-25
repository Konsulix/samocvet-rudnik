# The board's gems in the two styles the player picks from: "natural" (rough, water-worn stones with many small
# facets) and "faceted" (clean geometric crystals: cube on its corner, bipyramid, ball, emerald block, tetrahedron,
# doubly terminated prism). Seen from the front and a little above, lit like the board kit (board_kit.py).
# The colour is painterly: mottled glassy body, a fine crumpled grain, light running along the facet edges,
# a glow from within.
#   blender -b -P gem_kit.py -- <out_dir> [px] [samples] [only: style/name,...]
# writes <out_dir>/<style>/<name>.png
import bpy, bmesh, sys, math, os, random
from mathutils import Vector, Matrix, Quaternion
argv = sys.argv[sys.argv.index("--") + 1:]
OUT = argv[0]
PX = int(argv[1]) if len(argv) > 1 else 256
SAMPLES = int(argv[2]) if len(argv) > 2 else 128
ONLY = argv[3].split(",") if len(argv) > 3 else None
PROJ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
SPAN = 1.15   # a sprite covers this many cells (BoardSprites.SPAN)

# board colour order (BoardSprites.GEMS): name, body colour (linear), how milky (0 clear .. 1 opaque)
GEMS = [
    ("ruby",     (0.62, 0.035, 0.02), 0.35),
    ("sapphire", (0.02, 0.16, 0.75), 0.35),
    ("emerald",  (0.01, 0.30, 0.09), 0.5),
    ("citrine",  (0.85, 0.42, 0.03), 0.35),
    ("amethyst", (0.30, 0.07, 0.62), 0.35),
    ("diamond",  (0.55, 0.52, 0.48), 0.25),
]

def setup():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.samples = SAMPLES
    sc.cycles.use_denoising = True
    sc.render.resolution_x = PX
    sc.render.resolution_y = PX
    sc.render.film_transparent = True
    sc.view_settings.view_transform = 'Standard'
    sc.view_settings.look = 'Medium High Contrast'
    try:
        prefs = bpy.context.preferences.addons["cycles"].preferences
        prefs.compute_device_type = 'CUDA'; prefs.get_devices()
        for d in prefs.devices: d.use = True
        sc.cycles.device = 'GPU'
    except Exception:
        pass
    w = bpy.data.worlds.new("w"); w.use_nodes = True; sc.world = w
    env = w.node_tree.nodes.new("ShaderNodeTexEnvironment")
    env.image = bpy.data.images.load(os.path.join(PROJ, "godot/assets/hdri/studio_small_09_1k.hdr"))
    w.node_tree.links.new(env.outputs[0], w.node_tree.nodes["Background"].inputs[0])
    w.node_tree.nodes["Background"].inputs[1].default_value = 0.22
    # the board's key light, from the upper left
    d = bpy.data.lights.new("sun", 'SUN'); d.energy = 4.2; d.angle = math.radians(10); d.color = (1.0, 0.97, 0.92)
    s = bpy.data.objects.new("sun", d)
    s.rotation_euler = Vector((0.75, 0.35, -0.6)).to_track_quat('-Z', 'Y').to_euler()
    sc.collection.objects.link(s)
    # front view from a little above: the camera looks along +Y, tipped down 12 degrees
    cd = bpy.data.cameras.new("cam"); cd.type = 'ORTHO'; cd.ortho_scale = SPAN
    cam = bpy.data.objects.new("cam", cd)
    tilt = math.radians(12)
    cam.location = (0, -10 * math.cos(tilt), 10 * math.sin(tilt))
    cam.rotation_euler = (math.pi / 2 - tilt, 0, 0)
    sc.collection.objects.link(cam); sc.camera = cam
    return sc

def hull(points):
    me = bpy.data.meshes.new("gem"); bm = bmesh.new()
    for p in points: bm.verts.new(p)
    bmesh.ops.convex_hull(bm, input=bm.verts)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.002)
    # coplanar triangles merged into real facets
    bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(1.0), verts=bm.verts, edges=bm.edges)
    # every facet its own depth of colour, as light bends differently through each
    rnd = random.Random(len(points))
    lay = bm.loops.layers.color.new("facet")
    for f in bm.faces:
        v = rnd.uniform(0.4, 1.15)
        for lp in f.loops: lp[lay] = (v, v, v, 1.0)
    bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new("gem", me); bpy.context.scene.collection.objects.link(o)
    return o

# ---------------------------------------------------------------- shapes, about 0.9 across, centred

def natural(seed, w=0.42, h=0.47, point=0.35, n=130):
    """a rough stone: points on an egg narrowing upwards, so its hull is a crowd of uneven facets"""
    rnd = random.Random(seed)
    pts = []
    for k in range(n):
        z = rnd.uniform(-1, 1)
        a = rnd.uniform(0, math.tau)
        # the egg: wide low, narrow high, a little flattened front to back
        # an egg: its widest point low, tapering to a blunt point on top
        r = math.sqrt(max(0.0, 1 - z * z)) * (1.0 - point * max(0.0, z) ** 1.2) * (1.0 + 0.12 * (1 - z) * 0.5) * rnd.uniform(0.95, 1.0)
        pts.append(Vector((math.cos(a) * r * w, math.sin(a) * r * w * 0.8, z * h)))
    pts += [Vector((0, 0, h * 0.98)), Vector((0, 0, -h * 0.9))]
    return hull(pts)

def faceted(kind):
    if kind == "cube":
        # a cube on its corner, that corner cut off: a hexagon with a facet in its middle and a Y of edges
        pts = []
        for x in (-1, 1):
            for y in (-1, 1):
                for z in (-1, 1):
                    c = Vector((x, y, z))
                    if c == Vector((1, 1, 1)):
                        pts += [c - Vector(a) * 0.4 for a in ((2, 0, 0), (0, 2, 0), (0, 0, 2))]
                    else:
                        pts.append(c)
        o = hull([p * 0.27 for p in pts])
        # the cut corner faces us from a little above; then spun about that axis until a corner of the
        # outline points straight up, as in the drawing
        diag = Vector((1, 1, 1)).normalized()
        align = diag.rotation_difference(Vector((0, -1, 0.42)).normalized())
        best = None
        for deg in range(0, 120):
            q = align @ Quaternion(diag, math.radians(deg))
            top = max((q @ Vector(c) for c in [(-1, -1, 1), (-1, 1, -1), (1, -1, -1), (-1, 1, 1), (1, -1, 1), (1, 1, -1)]), key=lambda v: v.z)
            if best is None or abs(top.x) < best[0]: best = (abs(top.x), q)
        o.rotation_mode = 'QUATERNION'
        o.rotation_quaternion = best[1]
        return o
    if kind == "bipyramid":
        return hull([Vector((0, 0, 0.47)), Vector((0, 0, -0.47))] + [Vector((math.cos(a) * 0.3, math.sin(a) * 0.22, 0)) for a in (0, math.pi / 2, math.pi, 1.5 * math.pi)])
    if kind == "ball":
        bm = bmesh.new(); bmesh.ops.create_icosphere(bm, subdivisions=2, radius=0.41)
        return hull([v.co.copy() for v in bm.verts])
    if kind == "block":
        c = 0.07
        pts = []
        for y in (-0.15, 0.15):
            for x, z in [(-0.3 + c, 0.42), (0.3 - c, 0.42), (0.3, 0.42 - c), (0.3, -0.42 + c), (0.3 - c, -0.42), (-0.3 + c, -0.42), (-0.3, -0.42 + c), (-0.3, 0.42 - c)]:
                pts.append(Vector((x, y * (0.6 if y < 0 else 1.0) - 0.05, z)))
        pts += [Vector((x * 0.75, -0.24, z * 0.8)) for x, z in [(-0.3, 0.42), (0.3, 0.42), (0.3, -0.42), (-0.3, -0.42)]]
        return hull(pts)
    if kind == "tetra":
        # standing on its base, one edge turned to us: two faces showing, the apex on top
        base = [Vector((math.cos(a) * 0.5, math.sin(a) * 0.5, -0.32)) for a in (math.radians(-100), math.radians(20), math.radians(140))]
        return hull([Vector((0.02, 0, 0.46))] + base)
    # a doubly terminated hexagonal prism
    pts = []
    for z, r in [(0.2, 0.26), (-0.2, 0.26)]:
        pts += [Vector((math.cos(a) * r, math.sin(a) * r * 0.85, z)) for a in [k * math.tau / 6 + 0.25 for k in range(6)]]
    return hull(pts + [Vector((0.02, 0, 0.47)), Vector((-0.02, 0, -0.47))])

FACETED = {"ruby": "cube", "citrine": "bipyramid", "sapphire": "ball", "emerald": "block", "amethyst": "tetra", "diamond": "prism"}
NATURAL = {"ruby": dict(seed=3, point=0.5), "citrine": dict(seed=7, w=0.33, point=0.5), "sapphire": dict(seed=11, w=0.37, point=0.25),
           "emerald": dict(seed=19, w=0.38, point=0.1), "amethyst": dict(seed=5, w=0.37, point=0.15), "diamond": dict(seed=23, w=0.34, point=0.45)}

# ---------------------------------------------------------------- the painterly glass

def gem_mat(col, milky):
    m = bpy.data.materials.new("gem"); m.use_nodes = True
    n = m.node_tree; L = n.links; nd = n.nodes.new
    p = n.nodes["Principled BSDF"]
    tc = nd("ShaderNodeTexCoord")
    lite = tuple(min(1.0, c * 1.35 + 0.04) for c in col)
    deep = tuple(c * 0.22 for c in col)
    # a mottled body, cloudy light and dark patches of its own colour
    nz = nd("ShaderNodeTexNoise"); nz.inputs["Scale"].default_value = 5.0; nz.inputs["Detail"].default_value = 6
    nz.inputs["Roughness"].default_value = 0.6
    L.new(tc.outputs["Object"], nz.inputs["Vector"])
    body = nd("ShaderNodeValToRGB"); e = body.color_ramp.elements
    e[0].position = 0.3; e[0].color = (*deep, 1); e[1].position = 0.75; e[1].color = (*lite, 1)
    mid = body.color_ramp.elements.new(0.5); mid.color = (*col, 1)
    L.new(nz.outputs["Fac"], body.inputs["Fac"])
    # a fine crumpled grain over it, like paint on rough paper
    cr = nd("ShaderNodeTexVoronoi"); cr.feature = 'DISTANCE_TO_EDGE'; cr.inputs["Scale"].default_value = 30.0
    L.new(tc.outputs["Object"], cr.inputs["Vector"])
    crr = nd("ShaderNodeMapRange"); crr.inputs["From Min"].default_value = 0.0; crr.inputs["From Max"].default_value = 0.06
    crr.inputs["To Min"].default_value = 1.45; crr.inputs["To Max"].default_value = 1.0
    L.new(cr.outputs["Distance"], crr.inputs["Value"])
    grain = nd("ShaderNodeMix"); grain.data_type = 'RGBA'; grain.blend_type = 'MULTIPLY'; grain.inputs["Factor"].default_value = 1.0
    fa = nd("ShaderNodeVertexColor"); fa.layer_name = "facet"
    fm = nd("ShaderNodeMix"); fm.data_type = 'RGBA'; fm.blend_type = 'MULTIPLY'; fm.inputs["Factor"].default_value = 1.0
    L.new(body.outputs[0], fm.inputs["A"]); L.new(fa.outputs["Color"], fm.inputs["B"])
    L.new(fm.outputs[2], grain.inputs["A"])
    gc = nd("ShaderNodeCombineColor")
    for k in ("Red", "Green", "Blue"): L.new(crr.outputs[0], gc.inputs[k])
    L.new(gc.outputs[0], grain.inputs["B"])
    # light running along the facet edges: where a rounded (bevelled) normal parts from the true one
    bv = nd("ShaderNodeBevel"); bv.inputs["Radius"].default_value = 0.025; bv.samples = 8
    geo = nd("ShaderNodeNewGeometry")
    dt = nd("ShaderNodeVectorMath"); dt.operation = 'DOT_PRODUCT'
    L.new(bv.outputs[0], dt.inputs[0]); L.new(geo.outputs["Normal"], dt.inputs[1])
    edge = nd("ShaderNodeMapRange"); edge.inputs["From Min"].default_value = 0.999; edge.inputs["From Max"].default_value = 0.975
    L.new(dt.outputs["Value"], edge.inputs["Value"])
    ek = nd("ShaderNodeMath"); ek.operation = 'MULTIPLY'; ek.inputs[1].default_value = 0.7
    L.new(edge.outputs[0], ek.inputs[0])
    me = nd("ShaderNodeMix"); me.data_type = 'RGBA'
    L.new(ek.outputs[0], me.inputs["Factor"]); L.new(grain.outputs[2], me.inputs["A"])
    me.inputs["B"].default_value = (*tuple(min(1.0, c * 0.5 + 0.55) for c in col), 1)
    L.new(me.outputs[2], p.inputs["Base Color"])
    # glassy: light gets in and comes back coloured, a glow from within on the faces turned to us
    p.inputs["Subsurface Weight"].default_value = 0.35 - milky * 0.2
    p.inputs["Subsurface Radius"].default_value = (col[0] + 0.2, col[1] + 0.2, col[2] + 0.2)
    p.inputs["Subsurface Scale"].default_value = 0.15
    lw = nd("ShaderNodeLayerWeight"); lw.inputs["Blend"].default_value = 0.4
    inv = nd("ShaderNodeMath"); inv.operation = 'SUBTRACT'; inv.inputs[0].default_value = 1.0
    L.new(lw.outputs["Facing"], inv.inputs[1])
    gl = nd("ShaderNodeMath"); gl.operation = 'MULTIPLY'; gl.inputs[1].default_value = 0.18
    L.new(inv.outputs[0], gl.inputs[0])
    p.inputs["Emission Color"].default_value = (*col, 1)
    L.new(gl.outputs[0], p.inputs["Emission Strength"])
    # satin rather than mirror: no studio glare blowing a facet out white
    p.inputs["Roughness"].default_value = 0.38
    p.inputs["Coat Weight"].default_value = 0.25
    p.inputs["Coat Roughness"].default_value = 0.2
    return m

def render(style, name, col, milky):
    sc = setup()
    o = natural(**NATURAL[name]) if style == "natural" else faceted(FACETED[name])
    if style == "faceted":
        # narrow flat chamfers on the edges catch the light, as on a cut crystal
        bv = o.modifiers.new("chamfer", 'BEVEL'); bv.width = 0.012; bv.segments = 1; bv.limit_method = 'ANGLE'
    o.data.materials.append(gem_mat(col, milky))
    for poly in o.data.polygons: poly.use_smooth = False
    path = os.path.join(OUT, style, name + ".png")
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("GEM", style, name)

for style in ("natural", "faceted"):
    for name, col, milky in GEMS:
        if ONLY and style + "/" + name not in ONLY: continue
        os.makedirs(os.path.join(OUT, style), exist_ok=True)
        render(style, name, col, milky)
