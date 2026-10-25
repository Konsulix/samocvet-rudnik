# The board's gems in the two styles the player picks from (the user's reference sheets):
#   natural  rough stones, each its own silhouette: a ruby drop, a citrine crystal with a sharp tip, a tall sapphire
#            egg, a tilted malachite block with its rings, an amethyst octagon, a smoky quartz drop
#   faceted  clean geometric crystals: a cube on its corner, a bipyramid, a faceted ball, an emerald block,
#            a tetrahedron, a doubly terminated prism
# A stone is cut, not modelled: a block is sliced by planes (tangent to an egg, or the crystal's own faces), so
# every facet is a real polygon of its own size, like the facets in the drawings. Seen from the front and a little
# above, lit like the board kit. The colour is painted rather than glassy: every facet its own depth of colour,
# a crumpled grain, light veins, thin light lines along the edges, lighter towards the top left.
#   blender -b -P gem_kit.py -- <out_dir> [px] [samples] [only: style/name,...]
# writes <out_dir>/<style>/<name>.png
import bpy, bmesh, sys, math, os, random
from mathutils import Vector, Quaternion
argv = sys.argv[sys.argv.index("--") + 1:]
OUT = argv[0]
PX = int(argv[1]) if len(argv) > 1 else 256
SAMPLES = int(argv[2]) if len(argv) > 2 else 128
ONLY = argv[3].split(",") if len(argv) > 3 else None
PROJ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
SPAN = 1.15   # a sprite covers this many cells (BoardSprites.SPAN)

# board colour order (BoardSprites.GEMS): name, dark / mid / light of its paint (linear)
GEMS = [
    ("ruby",     (0.16, 0.006, 0.004), (0.62, 0.04, 0.02), (1.0, 0.36, 0.2)),
    ("sapphire", (0.004, 0.03, 0.2),  (0.02, 0.2, 0.85), (0.35, 0.65, 1.0)),
    ("emerald",  (0.004, 0.06, 0.02), (0.02, 0.32, 0.11), (0.25, 0.75, 0.4)),
    ("citrine",  (0.3, 0.12, 0.01),   (0.85, 0.45, 0.06), (1.0, 0.82, 0.4)),
    ("amethyst", (0.07, 0.015, 0.2),  (0.33, 0.1, 0.7),   (0.72, 0.55, 1.0)),
    ("diamond",  (0.05, 0.035, 0.02), (0.27, 0.21, 0.15), (0.86, 0.8, 0.72)),
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
    w.node_tree.nodes["Background"].inputs[1].default_value = 0.2
    # the key light from the upper left and a little in front, as in the drawings
    d = bpy.data.lights.new("sun", 'SUN'); d.energy = 3.4; d.angle = math.radians(20); d.color = (1.0, 0.97, 0.92)
    s = bpy.data.objects.new("sun", d)
    s.rotation_euler = Vector((0.75, 0.45, -0.55)).to_track_quat('-Z', 'Y').to_euler()
    sc.collection.objects.link(s)
    # front view from a little above: the camera looks along +Y, tipped down 12 degrees
    cd = bpy.data.cameras.new("cam"); cd.type = 'ORTHO'; cd.ortho_scale = SPAN
    cam = bpy.data.objects.new("cam", cd)
    tilt = math.radians(12)
    cam.location = (0, -10 * math.cos(tilt), 10 * math.sin(tilt))
    cam.rotation_euler = (math.pi / 2 - tilt, 0, 0)
    sc.collection.objects.link(cam); sc.camera = cam
    return sc

# ---------------------------------------------------------------- cutting a stone out of planes

def cut(planes, seed, tone=(0.32, 1.15)):
    """the solid inside every plane [point, outward normal]: a block sliced plane by plane"""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=2.0)
    for co, no in planes:
        geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
        bmesh.ops.bisect_plane(bm, geom=geom, plane_co=co, plane_no=no, clear_outer=True, dist=1e-5)
        # close the cut, so the next plane slices a solid again
        bmesh.ops.holes_fill(bm, edges=bm.edges[:], sides=0)
    pts = [v.co.copy() for v in bm.verts]
    bm.free()
    # the hull of what is left is the stone; coplanar triangles merge back into the cut facets
    bm = bmesh.new()
    for p in pts: bm.verts.new(p)
    bmesh.ops.convex_hull(bm, input=bm.verts)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.004)
    bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(2.0), verts=bm.verts, edges=bm.edges)
    # every facet its own depth of colour, as light bends differently through each
    rnd = random.Random(seed)
    lay = bm.loops.layers.color.new("facet")
    for f in bm.faces:
        v = rnd.uniform(*tone)
        for lp in f.loops: lp[lay] = (v, v, v, 1.0)
    me = bpy.data.meshes.new("gem"); bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new("gem", me); bpy.context.scene.collection.objects.link(o)
    for poly in me.polygons: poly.use_smooth = False
    return o

def fib(n, rnd, jitter=0.35):
    """n directions spread evenly over the sphere, shaken a little so the facets differ in size"""
    out = []
    ga = math.pi * (3 - math.sqrt(5))
    for k in range(n):
        z = 1 - (k + 0.5) / n * 2 + rnd.uniform(-jitter, jitter) / n * 2
        z = max(-1, min(1, z))
        a = k * ga + rnd.uniform(-jitter, jitter)
        r = math.sqrt(1 - z * z)
        out.append(Vector((math.cos(a) * r, math.sin(a) * r, z)))
    return out

def egg_planes(n, seed, w=0.4, d=0.32, h=0.46, point=0.35, lean=0.0, low=0.06, depth=(0.0, 0.03)):
    """facets tangent to an egg: widest low, tapering to a tip (point: how sharp); lean tips it sideways"""
    rnd = random.Random(seed)
    def F(p):
        t = max(-1.0, min(1.0, p.z / h))
        R = (1.0 - point * max(0.0, t) ** 1.3) * (1.0 + low * (1 - t) * 0.5)
        return (p.x / (w * R)) ** 2 + (p.y / (d * R)) ** 2 + t * t - 1.0
    planes = []
    rot = Quaternion((0, 1, 0), lean)
    for u in fib(n, rnd):
        lo, hi = 0.0, 1.0
        for _ in range(30):
            m = (lo + hi) / 2
            if F(u * m) < 0: lo = m
            else: hi = m
        p = u * lo
        e = 1e-3
        g = Vector((F(p + Vector((e, 0, 0))) - F(p - Vector((e, 0, 0))), F(p + Vector((0, e, 0))) - F(p - Vector((0, e, 0))),
                    F(p + Vector((0, 0, e))) - F(p - Vector((0, 0, e))))).normalized()
        # each facet cut a little deeper or shallower than the egg: facets of uneven size
        p = p - g * rnd.uniform(*depth)
        planes.append((rot @ p, rot @ g))
    return planes

def block_planes(n, seed, a=0.3, b=0.24, c=0.42, power=3.0, depth=(0.0, 0.02)):
    """facets tangent to a rounded block (a superellipsoid): a worn, chunky stone"""
    rnd = random.Random(seed)
    def F(p):
        return abs(p.x / a) ** power + abs(p.y / b) ** power + abs(p.z / c) ** power - 1.0
    planes = []
    for u in fib(n, rnd):
        lo, hi = 0.0, 1.0
        for _ in range(30):
            m = (lo + hi) / 2
            if F(u * m) < 0: lo = m
            else: hi = m
        q = u * lo
        e = 1e-3
        g = Vector((F(q + Vector((e, 0, 0))) - F(q - Vector((e, 0, 0))), F(q + Vector((0, e, 0))) - F(q - Vector((0, e, 0))),
                    F(q + Vector((0, 0, e))) - F(q - Vector((0, 0, e))))).normalized()
        planes.append((q - g * rnd.uniform(*depth), g))
    return planes

def ring_planes(n, r, z, tilt, spin, rnd=None, jit=0.0):
    """n planes round the upright axis at height z, their normals tilted up by `tilt` (0: upright sides)"""
    out = []
    for k in range(n):
        a = spin + k * math.tau / n + (rnd.uniform(-jit, jit) if rnd else 0.0)
        no = Vector((math.cos(a) * math.cos(tilt), math.sin(a) * math.cos(tilt), math.sin(tilt)))
        rr = r * (1.0 + (rnd.uniform(-jit, jit) * 0.3 if rnd else 0.0))
        out.append((Vector((math.cos(a) * rr, math.sin(a) * rr, z)), no))
    return out

def box_planes(x, y, z):
    return [(Vector((x, 0, 0)), Vector((1, 0, 0))), (Vector((-x, 0, 0)), Vector((-1, 0, 0))), (Vector((0, y, 0)), Vector((0, 1, 0))),
            (Vector((0, -y, 0)), Vector((0, -1, 0))), (Vector((0, 0, z)), Vector((0, 0, 1))), (Vector((0, 0, -z)), Vector((0, 0, -1)))]

def plane(no, off):
    """a plane facing `no`, `off` from the centre: cuts a corner or an edge off"""
    n = Vector(no).normalized()
    return (n * off, n)

def turned(planes, q):
    return [(q @ co, q @ no) for co, no in planes]

# ---------------------------------------------------------------- the natural stones

def nat_ruby():
    return cut(egg_planes(90, 3, w=0.4, d=0.34, h=0.45, point=0.42, lean=0.1, low=0.12, depth=(0.0, 0.025)), 3)

def nat_citrine():
    # a hexagonal crystal with a sharp tip and a worn, rounded foot
    rnd = random.Random(7)
    pl = ring_planes(6, 0.29, 0, 0.0, 0.3, rnd, 0.12)                       # the prism's sides
    pl += ring_planes(6, 0.2, 0.24, math.radians(30), 0.3, rnd, 0.1)      # the point
    pl += [p for p in egg_planes(40, 8, w=0.36, d=0.3, h=0.44, point=0.0, low=0.0) if p[1].z < -0.2]
    return cut(pl, 7)

def nat_sapphire():
    return cut(egg_planes(80, 11, w=0.38, d=0.32, h=0.48, point=0.62, lean=-0.06, low=0.05, depth=(0.0, 0.03)), 11, (0.4, 1.15))

def nat_emerald():
    # malachite: a worn, rounded block, tilted, a few big facets
    pl = block_planes(40, 19, 0.32, 0.25, 0.4, 2.2, (0.0, 0.025))
    return cut(turned(pl, Quaternion((0, 1, 0), math.radians(-16))), 19, (0.6, 1.1))

def nat_amethyst():
    # an octagon block: upright sides, its corners and its front cut into many facets
    return cut(block_planes(44, 5, 0.3, 0.24, 0.43, 2.8, (0.0, 0.015)), 5, (0.45, 1.1))

def nat_diamond():
    return cut(egg_planes(80, 23, w=0.37, d=0.3, h=0.47, point=0.75, lean=0.05, low=0.12, depth=(0.0, 0.03)), 23, (0.5, 1.15))

# ---------------------------------------------------------------- the faceted crystals

def fac_ruby():
    # a cube on its corner, every corner and edge cut a little: a hexagon with a facet in its middle
    pl = []
    for x in (-1, 1):
        for y in (-1, 1):
            for z in (-1, 1):
                pl.append(plane((x, y, z), 0.27 * 1.732 * (0.82 if (x, y, z) == (1, 1, 1) else 0.93)))
    for a in range(3):
        for s1 in (-1, 1):
            for s2 in (-1, 1):
                v = [0, 0, 0]; v[(a + 1) % 3] = s1; v[(a + 2) % 3] = s2
                pl.append(plane(v, 0.27 * 1.414 * 0.96))
    pl += [plane(n, 0.27) for n in [(1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1)]]
    # the cut corner faces us from a little above, spun until a corner of the outline points straight up
    diag = Vector((1, 1, 1)).normalized()
    align = diag.rotation_difference(Vector((0, -1, 0.25)).normalized())
    best = None
    for deg in range(0, 120):
        q = align @ Quaternion(diag, math.radians(deg))
        top = max((q @ Vector(c) for c in [(-1, -1, 1), (-1, 1, -1), (1, -1, -1), (-1, 1, 1), (1, -1, 1), (1, 1, -1)]), key=lambda v: v.z)
        if best is None or abs(top.x) < best[0]: best = (abs(top.x), q)
    return cut(turned(pl, best[1]), 31, (0.5, 1.1))

def fac_citrine():
    # an elongated bipyramid turned a little, small facets round its waist
    pl = []
    for k in range(4):
        a = k * math.pi / 2 + math.pi / 4
        for s in (-1, 1):
            n = Vector((math.cos(a), math.sin(a) * 1.3, s * 0.62)).normalized()
            pl.append((n * 0.2, n))
    pl += ring_planes(8, 0.3, 0, 0.0, math.pi / 8)
    return cut(turned(pl, Quaternion((0, 0, 1), math.radians(22))), 37, (0.5, 1.1))

def fac_sapphire():
    rnd = random.Random(41)
    return cut([(u * 0.41, u) for u in fib(30, rnd, 0.6)], 41, (0.45, 1.15))

def fac_emerald():
    # a step-cut block, its front broken into a few slanting planes
    pl = box_planes(0.3, 0.2, 0.42)
    pl += [plane((1, 0, 1), 0.48), plane((-1, 0, -1), 0.48), plane((1, 0, -1), 0.53), plane((-1, 0, 1), 0.53)]
    pl += [plane((0.25, -1, 0.3), 0.19), plane((-0.3, -1, -0.15), 0.19), plane((0.15, -1, -0.4), 0.195), plane((-0.2, -1, 0.45), 0.2),
           plane((0.4, -1, -0.05), 0.2), plane((-0.05, -1, 0.1), 0.185), plane((-0.45, -1, 0.25), 0.215)]
    return cut(pl, 43, (0.4, 1.15))

def fac_amethyst():
    # a tetrahedron on its base, an edge towards us, its tip cut off a hair
    pl = [(Vector((0, 0, -0.33)), Vector((0, 0, -1)))]
    for a in (math.radians(80), math.radians(200), math.radians(320)):
        n = Vector((math.cos(a), math.sin(a), 0.36)).normalized()
        pl.append((Vector((0, 0, 0.44)), n))
    pl.append((Vector((0, 0, 0.42)), Vector((0, 0, 1))))
    pl.append(plane((0.3, -1, 0.1), 0.2))
    return cut(pl, 47, (0.5, 1.1))

def fac_diamond():
    # a doubly terminated hexagonal crystal, uneven
    rnd = random.Random(53)
    pl = ring_planes(6, 0.25, 0, 0.0, 0.2, rnd, 0.08)
    pl += ring_planes(6, 0.18, 0.2, math.radians(35), 0.2, rnd, 0.1)
    pl += ring_planes(6, 0.18, -0.2, math.radians(-38), 0.2, rnd, 0.1)
    return cut(pl, 53, (0.45, 1.15))

SHAPES = {
    "natural": {"ruby": nat_ruby, "citrine": nat_citrine, "sapphire": nat_sapphire, "emerald": nat_emerald, "amethyst": nat_amethyst, "diamond": nat_diamond},
    "faceted": {"ruby": fac_ruby, "citrine": fac_citrine, "sapphire": fac_sapphire, "emerald": fac_emerald, "amethyst": fac_amethyst, "diamond": fac_diamond},
}

# ---------------------------------------------------------------- the paint

def gem_mat(dark, mid, light, malachite=False):
    m = bpy.data.materials.new("gem"); m.use_nodes = True
    n = m.node_tree; L = n.links; nd = n.nodes.new
    p = n.nodes["Principled BSDF"]
    tc = nd("ShaderNodeTexCoord")
    # how deep the colour is here: the facet's own depth, a soft cloud, lighter towards the top left
    fa = nd("ShaderNodeVertexColor"); fa.layer_name = "facet"
    fbw = nd("ShaderNodeRGBToBW"); L.new(fa.outputs["Color"], fbw.inputs[0])
    cl = nd("ShaderNodeTexNoise"); cl.inputs["Scale"].default_value = 4.0; cl.inputs["Detail"].default_value = 4
    L.new(tc.outputs["Object"], cl.inputs["Vector"])
    sep = nd("ShaderNodeSeparateXYZ"); L.new(tc.outputs["Object"], sep.inputs[0])
    tl = nd("ShaderNodeMath"); tl.operation = 'SUBTRACT'
    L.new(sep.outputs["Z"], tl.inputs[0]); L.new(sep.outputs["X"], tl.inputs[1])
    tlr = nd("ShaderNodeMapRange"); tlr.inputs["From Min"].default_value = -0.7; tlr.inputs["From Max"].default_value = 0.7
    tlr.inputs["To Min"].default_value = -0.26; tlr.inputs["To Max"].default_value = 0.22
    L.new(tl.outputs[0], tlr.inputs["Value"])
    a1 = nd("ShaderNodeMath"); a1.operation = 'MULTIPLY'; a1.inputs[1].default_value = 0.72
    L.new(fbw.outputs[0], a1.inputs[0])
    a2 = nd("ShaderNodeMath"); a2.operation = 'MULTIPLY_ADD'; a2.inputs[1].default_value = 0.14
    L.new(cl.outputs["Fac"], a2.inputs[0]); L.new(a1.outputs[0], a2.inputs[2])
    a3 = nd("ShaderNodeMath"); a3.operation = 'ADD'
    L.new(a2.outputs[0], a3.inputs[0]); L.new(tlr.outputs[0], a3.inputs[1])
    # a crumpled grain, as paint on rough paper: small cells each a touch lighter or darker
    vc = nd("ShaderNodeTexNoise"); vc.inputs["Scale"].default_value = 28.0; vc.inputs["Detail"].default_value = 3
    L.new(tc.outputs["Object"], vc.inputs["Vector"])
    gr = nd("ShaderNodeMapRange"); gr.inputs["To Min"].default_value = -0.14; gr.inputs["To Max"].default_value = 0.1
    L.new(vc.outputs["Fac"], gr.inputs["Value"]); gr.inputs["From Min"].default_value = 0.3; gr.inputs["From Max"].default_value = 0.7
    a4 = nd("ShaderNodeMath"); a4.operation = 'ADD'
    L.new(a3.outputs[0], a4.inputs[0]); L.new(gr.outputs[0], a4.inputs[1])
    ramp = nd("ShaderNodeValToRGB"); e = ramp.color_ramp.elements
    e[0].position = 0.12; e[0].color = (*dark, 1); e[1].position = 1.0; e[1].color = (*light, 1)
    em = ramp.color_ramp.elements.new(0.56); em.color = (*mid, 1)
    L.new(a4.outputs[0], ramp.inputs["Fac"])
    col = ramp.outputs[0]
    if malachite:
        # malachite's bands: wavy stripes, and a bull's-eye of rings on its face
        wv = nd("ShaderNodeTexWave"); wv.wave_type = 'BANDS'; wv.inputs["Scale"].default_value = 3.0
        wv.inputs["Distortion"].default_value = 24.0; wv.inputs["Detail"].default_value = 4
        L.new(tc.outputs["Object"], wv.inputs["Vector"])
        rg = nd("ShaderNodeTexWave"); rg.wave_type = 'RINGS'; rg.rings_direction = 'SPHERICAL'; rg.inputs["Scale"].default_value = 8.0
        mp = nd("ShaderNodeMapping"); mp.inputs["Location"].default_value = (-0.02, 0.25, -0.1)
        L.new(tc.outputs["Object"], mp.inputs["Vector"]); L.new(mp.outputs[0], rg.inputs["Vector"])
        dist = nd("ShaderNodeVectorMath"); dist.operation = 'LENGTH'; L.new(mp.outputs[0], dist.inputs[0])
        eye = nd("ShaderNodeMapRange"); eye.inputs["From Min"].default_value = 0.13; eye.inputs["From Max"].default_value = 0.11
        L.new(dist.outputs["Value"], eye.inputs["Value"])
        mx = nd("ShaderNodeMix"); mx.data_type = 'FLOAT'
        L.new(eye.outputs[0], mx.inputs["Factor"]); L.new(wv.outputs["Fac"], mx.inputs["A"]); L.new(rg.outputs["Fac"], mx.inputs["B"])
        bnd = nd("ShaderNodeMapRange"); bnd.inputs["From Min"].default_value = 0.62; bnd.inputs["From Max"].default_value = 0.85
        bnd.inputs["To Max"].default_value = 0.55
        L.new(mx.outputs[0], bnd.inputs["Value"])
        bm = nd("ShaderNodeMix"); bm.data_type = 'RGBA'
        L.new(bnd.outputs[0], bm.inputs["Factor"]); L.new(col, bm.inputs["A"]); bm.inputs["B"].default_value = (*dark, 1)
        col = bm.outputs[2]
    else:
        # a fine web of light cracks inside the stone, warped so no cell is a straight polygon
        wn = nd("ShaderNodeTexNoise"); wn.inputs["Scale"].default_value = 3.0; wn.inputs["Detail"].default_value = 2
        L.new(tc.outputs["Object"], wn.inputs["Vector"])
        wo = nd("ShaderNodeMix"); wo.data_type = 'VECTOR'; wo.inputs["Factor"].default_value = 0.12
        L.new(tc.outputs["Object"], wo.inputs[4]); L.new(wn.outputs["Color"], wo.inputs[5])
        vn = nd("ShaderNodeTexVoronoi"); vn.feature = 'DISTANCE_TO_EDGE'; vn.inputs["Scale"].default_value = 6.0
        L.new(wo.outputs[1], vn.inputs["Vector"])
        vr = nd("ShaderNodeMapRange"); vr.inputs["From Min"].default_value = 0.025; vr.inputs["From Max"].default_value = 0.0
        vr.inputs["To Max"].default_value = 0.18
        L.new(vn.outputs["Distance"], vr.inputs["Value"])
        vm = nd("ShaderNodeMix"); vm.data_type = 'RGBA'
        L.new(vr.outputs[0], vm.inputs["Factor"]); L.new(col, vm.inputs["A"]); vm.inputs["B"].default_value = (*light, 1)
        col = vm.outputs[2]
    # thin light lines along every edge, where a rounded normal parts from the flat one
    bv = nd("ShaderNodeBevel"); bv.inputs["Radius"].default_value = 0.012; bv.samples = 8
    geo = nd("ShaderNodeNewGeometry")
    dt = nd("ShaderNodeVectorMath"); dt.operation = 'DOT_PRODUCT'
    L.new(bv.outputs[0], dt.inputs[0]); L.new(geo.outputs["Normal"], dt.inputs[1])
    edge = nd("ShaderNodeMapRange"); edge.inputs["From Min"].default_value = 0.9995; edge.inputs["From Max"].default_value = 0.985
    edge.inputs["To Max"].default_value = 0.75
    L.new(dt.outputs["Value"], edge.inputs["Value"])
    # and a broader, softer light along the inside of each facet's rim, its middle stays deep
    bw2 = nd("ShaderNodeBevel"); bw2.inputs["Radius"].default_value = 0.05; bw2.samples = 8
    dt2 = nd("ShaderNodeVectorMath"); dt2.operation = 'DOT_PRODUCT'
    L.new(bw2.outputs[0], dt2.inputs[0]); L.new(geo.outputs["Normal"], dt2.inputs[1])
    rim = nd("ShaderNodeMapRange"); rim.inputs["From Min"].default_value = 0.999; rim.inputs["From Max"].default_value = 0.96
    rim.inputs["To Max"].default_value = 0.3
    L.new(dt2.outputs["Value"], rim.inputs["Value"])
    mr = nd("ShaderNodeMix"); mr.data_type = 'RGBA'
    L.new(rim.outputs[0], mr.inputs["Factor"]); L.new(col, mr.inputs["A"]); mr.inputs["B"].default_value = (*light, 1)
    col = mr.outputs[2]
    me = nd("ShaderNodeMix"); me.data_type = 'RGBA'
    L.new(edge.outputs[0], me.inputs["Factor"]); L.new(col, me.inputs["A"])
    me.inputs["B"].default_value = (*tuple(min(1.0, c * 0.6 + 0.45) for c in light), 1)
    L.new(me.outputs[2], p.inputs["Base Color"])
    # painted, not mirrored: soft satin light, a gentle glow of its own colour so it never goes dull
    p.inputs["Roughness"].default_value = 0.32
    p.inputs["Specular IOR Level"].default_value = 0.35
    p.inputs["Emission Color"].default_value = (*mid, 1)
    p.inputs["Emission Strength"].default_value = 0.05
    return m

# width / height on screen, as in the drawings; every stone is then fitted to the same height
ASPECT = {"natural": {"ruby": 0.84, "citrine": 0.72, "sapphire": 0.78, "emerald": 0.86, "amethyst": 0.72, "diamond": 0.74},
          "faceted": {"ruby": 0.86, "citrine": 0.7, "sapphire": 1.0, "emerald": 0.7, "amethyst": 1.05, "diamond": 0.66}}
HEIGHT = 0.9   # of a cell

def fit(o, aspect):
    """scale the stone so it stands HEIGHT tall on screen and `aspect` wide, centred"""
    tilt = math.radians(12)
    up = Vector((0, math.sin(tilt), math.cos(tilt)))   # screen up, as the tipped camera sees it
    def extent():
        xs = [v.co.x for v in o.data.vertices]; ys = [v.co.dot(up) for v in o.data.vertices]
        return min(xs), max(xs), min(ys), max(ys)
    x0, x1, y0, y1 = extent()
    k = HEIGHT / (y1 - y0)
    kx = k * aspect * (y1 - y0) / (x1 - x0)
    for v in o.data.vertices:
        v.co = Vector((v.co.x * kx, v.co.y * k, v.co.z * k))
    x0, x1, y0, y1 = extent()
    c = Vector(((x0 + x1) / 2, 0, 0)) + up * ((y0 + y1) / 2)
    for v in o.data.vertices:
        v.co -= c

def render(style, name, dark, mid, light):
    sc = setup()
    o = SHAPES[style][name]()
    fit(o, ASPECT[style][name])
    o.data.materials.append(gem_mat(dark, mid, light, malachite=(style == "natural" and name == "emerald")))
    sc.render.filepath = os.path.join(OUT, style, name + ".png")
    bpy.ops.render.render(write_still=True)
    print("GEM", style, name, len(o.data.polygons))

for style in ("natural", "faceted"):
    for name, dark, mid, light in GEMS:
        if ONLY and style + "/" + name not in ONLY: continue
        os.makedirs(os.path.join(OUT, style), exist_ok=True)
        render(style, name, dark, mid, light)
