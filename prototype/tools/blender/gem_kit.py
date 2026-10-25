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
    ("ruby",     (0.07, 0.002, 0.001), (0.33, 0.01, 0.005), (0.95, 0.08, 0.035)),
    ("sapphire", (0.002, 0.012, 0.13), (0.01, 0.11, 0.65), (0.25, 0.5, 1.0)),
    ("emerald",  (0.001, 0.02, 0.008), (0.005, 0.13, 0.05), (0.08, 0.45, 0.2)),
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
    w.node_tree.nodes["Background"].inputs[1].default_value = 0.1
    # the key light from the upper left and a little in front, as in the drawings
    d = bpy.data.lights.new("sun", 'SUN'); d.energy = 1.5; d.angle = math.radians(20); d.color = (1.0, 0.97, 0.92)
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
    me = bpy.data.meshes.new("gem"); bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new("gem", me); bpy.context.scene.collection.objects.link(o)
    for poly in me.polygons: poly.use_smooth = False
    o["seed"] = seed; o["tone"] = tone
    return o

def paint_facets(o):
    """what the paint needs to know of every facet (once the stone has its final size): its own depth of colour,
    its centre, and the way light runs across it, bright at one side and deep at the other, as through a cut stone"""
    rnd = random.Random(o["seed"])
    tone = tuple(o["tone"])
    bm = bmesh.new(); bm.from_mesh(o.data)
    deep = bm.loops.layers.float_color.new("facet")
    cen = bm.loops.layers.float_color.new("fcen")
    run = bm.loops.layers.float_color.new("frun")
    for f in bm.faces:
        v = rnd.uniform(*tone)
        c = f.calc_center_median()
        # a direction lying in the facet, mostly from the upper left down to the lower right
        d = Vector((rnd.uniform(-1, 0.3), rnd.uniform(-1, 1), rnd.uniform(-0.3, 1)))
        d = (d - f.normal * d.dot(f.normal)).normalized()
        for lp in f.loops:
            lp[deep] = (v, v, v, 1.0)
            lp[cen] = ((c.x + 1) / 2, (c.y + 1) / 2, (c.z + 1) / 2, 1.0)
            lp[run] = ((d.x + 1) / 2, (d.y + 1) / 2, (d.z + 1) / 2, 1.0)
    bm.to_mesh(o.data); bm.free()

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
    # an octahedron's hexagonal outline (pointed left and right), seen as a low pyramid looking at us:
    # six faces running in from the outline to a small plateau in the middle
    rnd = random.Random(31)
    pl = [(Vector((0, 0.12, 0)), Vector((0, 1, 0)))]                       # its flat back
    tilt = math.radians(38)                                                  # how steeply the faces rise to the middle
    for k in range(6):
        a = math.radians(30 + 60 * k) + rnd.uniform(-0.06, 0.06)
        n = Vector((math.cos(a) * math.cos(tilt), -math.sin(tilt), math.sin(a) * math.cos(tilt)))
        pl.append((n * (0.3 * math.cos(tilt) + rnd.uniform(-0.01, 0.01)), n))
    pl.append((Vector((0, -0.31, 0)), Vector((0, -1, 0))))                  # a small plateau at the tip
    return cut(pl, 31, (0.5, 1.1))

def fac_citrine():
    # an elongated bipyramid turned a little, small facets round its waist
    pl = []
    for k in range(4):
        a = k * math.pi / 2 + math.pi / 4
        for s in (-1, 1):
            n = Vector((math.cos(a), math.sin(a) * 1.3, s * 0.62)).normalized()
            pl.append((n * 0.2, n))
    # small facets round the waist, never reaching its four points
    pl += ring_planes(4, 0.3, 0, 0.0, math.pi / 4)
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

def gem_mat(dark, mid, light, malachite=False, ore=None, mask=False):
    m = bpy.data.materials.new("gem"); m.use_nodes = True
    n = m.node_tree; L = n.links; nd = n.nodes.new
    p = n.nodes["Principled BSDF"]
    tc = nd("ShaderNodeTexCoord")
    pos = tc.outputs["Object"]
    glow = tuple(min(1.0, c * 0.75 + 0.3) for c in light)    # the brightest light inside the stone
    def attr(name):
        a = nd("ShaderNodeVertexColor"); a.layer_name = name
        return a.outputs["Color"]
    def math_(op, a, b=None, value=None):
        k = nd("ShaderNodeMath"); k.operation = op
        L.new(a, k.inputs[0]) if not isinstance(a, float) else k.inputs[0].__setattr__("default_value", a)
        if b is not None: L.new(b, k.inputs[1])
        if value is not None: k.inputs[1].default_value = value
        return k.outputs[0]
    def remap(v, f0, f1, t0, t1):
        k = nd("ShaderNodeMapRange")
        k.inputs["From Min"].default_value = f0; k.inputs["From Max"].default_value = f1
        k.inputs["To Min"].default_value = t0; k.inputs["To Max"].default_value = t1
        L.new(v, k.inputs["Value"])
        return k.outputs[0]
    def unpack(c):
        # a direction or a point packed into 0..1 colour channels, back to -1..1
        k = nd("ShaderNodeVectorMath"); k.operation = 'MULTIPLY_ADD'
        L.new(c, k.inputs[0]); k.inputs[1].default_value = (2, 2, 2); k.inputs[2].default_value = (-1, -1, -1)
        return k.outputs[0]
    def mix(fac, a, b_col):
        k = nd("ShaderNodeMix"); k.data_type = 'RGBA'
        L.new(fac, k.inputs["Factor"]); L.new(a, k.inputs["A"]); k.inputs["B"].default_value = (*b_col, 1)
        return k.outputs[2]
    # how deep the colour is here:
    # the facet's own depth
    bw = nd("ShaderNodeRGBToBW"); L.new(attr("facet"), bw.inputs[0])
    v = math_('MULTIPLY', bw.outputs[0], value=0.55)
    # light running across the facet: bright towards one side, deep towards the other
    rel = nd("ShaderNodeVectorMath"); rel.operation = 'SUBTRACT'
    L.new(pos, rel.inputs[0]); L.new(unpack(attr("fcen")), rel.inputs[1])
    run = nd("ShaderNodeVectorMath"); run.operation = 'DOT_PRODUCT'
    L.new(rel.outputs[0], run.inputs[0]); L.new(unpack(attr("frun")), run.inputs[1])
    v = math_('ADD', v, remap(run.outputs["Value"], -0.15, 0.15, -0.28, 0.28))
    # the whole stone lighter towards the top left, deeper at the bottom right
    sep = nd("ShaderNodeSeparateXYZ"); L.new(pos, sep.inputs[0])
    v = math_('ADD', v, remap(math_('SUBTRACT', sep.outputs["Z"], sep.outputs["X"]), -0.7, 0.7, -0.22, 0.2))
    # a soft cloud, then a fine, sharp mottle, as pigment settling in the grain of the paper
    cl = nd("ShaderNodeTexNoise"); cl.inputs["Scale"].default_value = 4.0; cl.inputs["Detail"].default_value = 3
    L.new(pos, cl.inputs["Vector"])
    v = math_('ADD', v, remap(cl.outputs["Fac"], 0.3, 0.7, -0.06, 0.06))
    mt = nd("ShaderNodeTexNoise"); mt.inputs["Scale"].default_value = 55.0; mt.inputs["Detail"].default_value = 6
    mt.inputs["Roughness"].default_value = 0.75
    L.new(pos, mt.inputs["Vector"])
    v = math_('ADD', v, remap(mt.outputs["Fac"], 0.38, 0.62, -0.13, 0.11))
    v = math_('ADD', v, value=0.02)
    ramp = nd("ShaderNodeValToRGB"); cr = ramp.color_ramp
    cr.elements[0].position = 0.08; cr.elements[0].color = (*dark, 1)
    cr.elements[1].position = 1.0; cr.elements[1].color = (*glow, 1)
    for pos_k, c in ((0.45, mid), (0.78, light)):
        e = cr.elements.new(pos_k); e.color = (*c, 1)
    L.new(v, ramp.inputs["Fac"])
    col = ramp.outputs[0]
    if malachite:
        # malachite's bands: thin dark lines flowing over a lighter green, and a bull's-eye of rings on its face
        wv = nd("ShaderNodeTexWave"); wv.wave_type = 'BANDS'; wv.inputs["Scale"].default_value = 4.5
        wv.inputs["Distortion"].default_value = 16.0; wv.inputs["Detail"].default_value = 3
        L.new(pos, wv.inputs["Vector"])
        rg = nd("ShaderNodeTexWave"); rg.wave_type = 'RINGS'; rg.rings_direction = 'SPHERICAL'; rg.inputs["Scale"].default_value = 11.0
        mp = nd("ShaderNodeMapping"); mp.inputs["Location"].default_value = (-0.02, 0.25, -0.08)
        L.new(pos, mp.inputs["Vector"]); L.new(mp.outputs[0], rg.inputs["Vector"])
        dist = nd("ShaderNodeVectorMath"); dist.operation = 'LENGTH'; L.new(mp.outputs[0], dist.inputs[0])
        eye = remap(dist.outputs["Value"], 0.15, 0.12, 0.0, 1.0)
        mx = nd("ShaderNodeMix"); mx.data_type = 'FLOAT'
        L.new(eye, mx.inputs["Factor"]); L.new(wv.outputs["Fac"], mx.inputs["A"]); L.new(rg.outputs["Fac"], mx.inputs["B"])
        col = mix(remap(mx.outputs[0], 0.25, 0.08, 0.0, 0.45), col, dark)
        col = mix(remap(mx.outputs[0], 0.8, 0.97, 0.0, 0.6), col, glow)
    else:
        # a fine web of light cracks inside the stone, warped so no cell is a straight polygon
        wn = nd("ShaderNodeTexNoise"); wn.inputs["Scale"].default_value = 3.0; wn.inputs["Detail"].default_value = 2
        L.new(pos, wn.inputs["Vector"])
        wo = nd("ShaderNodeMix"); wo.data_type = 'VECTOR'; wo.inputs["Factor"].default_value = 0.15
        L.new(pos, wo.inputs[4]); L.new(wn.outputs["Color"], wo.inputs[5])
        vn = nd("ShaderNodeTexVoronoi"); vn.feature = 'DISTANCE_TO_EDGE'; vn.inputs["Scale"].default_value = 7.0
        L.new(wo.outputs[1], vn.inputs["Vector"])
        # only here and there, not a net over everything
        vp = nd("ShaderNodeTexNoise"); vp.inputs["Scale"].default_value = 5.0
        L.new(pos, vp.inputs["Vector"])
        crack = math_('MULTIPLY', remap(vn.outputs["Distance"], 0.018, 0.0, 0.0, 0.55), remap(vp.outputs["Fac"], 0.45, 0.6, 0.0, 1.0))
        col = mix(crack, col, glow)
    geo = nd("ShaderNodeNewGeometry")
    def edge_mask(radius, f0, f1, amount):
        bv = nd("ShaderNodeBevel"); bv.inputs["Radius"].default_value = radius; bv.samples = 8
        dt = nd("ShaderNodeVectorMath"); dt.operation = 'DOT_PRODUCT'
        L.new(bv.outputs[0], dt.inputs[0]); L.new(geo.outputs["Normal"], dt.inputs[1])
        return remap(dt.outputs["Value"], f0, f1, 0.0, amount)
    # light gathers along every edge: a soft glow spreading onto both facets...
    col = mix(edge_mask(0.045, 0.999, 0.95, 0.35), col, light)
    # ...and a thin bright line on the edge itself, lit from within so it shines even on the shaded side
    # strong where the stone is lit, fading on its deep side
    line = math_('MULTIPLY', edge_mask(0.012, 0.9995, 0.985, 1.0), remap(v, 0.25, 0.85, 0.2, 1.0))
    col = mix(math_('MULTIPLY', line, value=0.95), col, glow)
    # painted more than lit: the colour carries its own light (the drawings barely shade), the key light only models it
    p.inputs["Roughness"].default_value = 0.45
    p.inputs["Specular IOR Level"].default_value = 0.25
    emit_col = col
    es = nd("ShaderNodeMath"); es.operation = 'MULTIPLY_ADD'; es.inputs[1].default_value = 0.9; es.inputs[2].default_value = 0.26
    L.new(line, es.inputs[0])
    glow_k = es.outputs[0]
    if ore:
        # an ore-bearing stone: glowing veins run through part of it. Not a real metal's colour: one look that stands
        # out on every stone: a hot bright core, a dark rim that cuts it from the stone's own colour, a faint halo
        on = nd("ShaderNodeTexNoise"); on.inputs["Scale"].default_value = 2.2
        L.new(pos, on.inputs["Vector"])
        ow = nd("ShaderNodeTexNoise"); ow.inputs["Scale"].default_value = 2.0; ow.inputs["Detail"].default_value = 2
        L.new(pos, ow.inputs["Vector"])
        warp = nd("ShaderNodeMix"); warp.data_type = 'VECTOR'; warp.inputs["Factor"].default_value = 0.25
        L.new(pos, warp.inputs[4]); L.new(ow.outputs["Color"], warp.inputs[5])
        ov = nd("ShaderNodeTexVoronoi"); ov.feature = 'DISTANCE_TO_EDGE'; ov.inputs["Scale"].default_value = 3.6
        L.new(warp.outputs[1], ov.inputs["Vector"])
        where = remap(on.outputs["Fac"], 0.4, 0.5, 0.0, 1.0)            # veins over about half the stone
        dist = ov.outputs["Distance"]
        core = math_('MULTIPLY', remap(dist, 0.024, 0.013, 0.0, 1.0), where)
        rim = math_('MULTIPLY', remap(dist, 0.048, 0.026, 0.0, 1.0), where)
        halo = math_('MULTIPLY', remap(dist, 0.12, 0.04, 0.0, 1.0), where)
        col = mix(math_('MULTIPLY', halo, value=0.35), col, ORE_LOOK["halo"])
        col = mix(math_('MULTIPLY', rim, value=0.85), col, ORE_LOOK["rim"])
        col = mix(core, col, ORE_LOOK["core"])
        emit_col = col
        L.new(math_('MULTIPLY', core, value=0.6), p.inputs["Metallic"])
        # the core burns: far brighter than the stone, so the render's bloom spreads it a little
        glow_k = math_('ADD', math_('MULTIPLY', glow_k, math_('SUBTRACT', 1.0, rim)), math_('MULTIPLY', core, value=ORE_LOOK["burn"]))
        glow_k = math_('ADD', glow_k, math_('MULTIPLY', halo, value=0.25))
        if mask:
            # the glow mask the game shimmers: only the veins' light, white on black
            mk = nd("ShaderNodeMath"); mk.operation = 'MULTIPLY_ADD'; mk.inputs[1].default_value = 0.3
            L.new(halo, mk.inputs[0]); L.new(core, mk.inputs[2])
            ems = nd("ShaderNodeEmission"); ems.inputs["Color"].default_value = (1, 1, 1, 1)
            L.new(mk.outputs[0], ems.inputs["Strength"])
            L.new(ems.outputs[0], n.nodes["Material Output"].inputs["Surface"])
            return m
    L.new(col, p.inputs["Base Color"])
    L.new(emit_col, p.inputs["Emission Color"])
    L.new(glow_k, p.inputs["Emission Strength"])
    return m

# the look of ore in a stone (docs/progression-redesign.md: a stone either holds ore or not; which ore, the mine
# says by colour). Chosen to read on every colour of stone, not to copy a real metal
ORE_LOOK = dict(
    core=(1.0, 0.78, 0.32),     # the hot, bright metal in the veins and the nuggets
    rim=(0.03, 0.02, 0.012),    # the dark seam round each vein
    halo=(1.0, 0.65, 0.25),     # light the veins throw onto the stone
    burn=1.4,                   # how much brighter than the stone the veins glow
)

def flat_emit(name, strength):
    """a plain light (or, at 0, plain black) for the glow mask"""
    m = bpy.data.materials.new(name); m.use_nodes = True
    n = m.node_tree
    e = n.nodes.new("ShaderNodeEmission"); e.inputs["Strength"].default_value = strength
    n.links.new(e.outputs[0], n.nodes["Material Output"].inputs["Surface"])
    return m

def metal_mat(mask=False):
    """a nugget of ore, glowing like the veins"""
    if mask: return flat_emit("ore_mask", 0.8)
    m = bpy.data.materials.new("ore"); m.use_nodes = True
    n = m.node_tree; L = n.links; nd = n.nodes.new
    p = n.nodes["Principled BSDF"]
    tc = nd("ShaderNodeTexCoord")
    p.inputs["Base Color"].default_value = (*ORE_LOOK["core"], 1)
    p.inputs["Metallic"].default_value = 0.8
    rn = nd("ShaderNodeTexNoise"); rn.inputs["Scale"].default_value = 30.0
    L.new(tc.outputs["Object"], rn.inputs["Vector"])
    rr = nd("ShaderNodeMapRange"); rr.inputs["To Min"].default_value = 0.2; rr.inputs["To Max"].default_value = 0.45
    L.new(rn.outputs["Fac"], rr.inputs["Value"]); L.new(rr.outputs[0], p.inputs["Roughness"])
    # brightest where it faces us, deeper where it turns away: still a lump, not a flat light
    lw = nd("ShaderNodeLayerWeight"); lw.inputs["Blend"].default_value = 0.5
    em = nd("ShaderNodeMapRange"); em.inputs["From Min"].default_value = 0.2; em.inputs["From Max"].default_value = 0.9
    em.inputs["To Min"].default_value = ORE_LOOK["burn"] * 0.45; em.inputs["To Max"].default_value = ORE_LOOK["burn"] * 0.08
    L.new(lw.outputs["Facing"], em.inputs["Value"])
    p.inputs["Emission Color"].default_value = (*ORE_LOOK["core"], 1)
    L.new(em.outputs[0], p.inputs["Emission Strength"])
    return m

def nuggets(o, seed, mask=False):
    """two or three lumps of ore grown into the stone's front, low and to the sides, each in a dark socket"""
    rnd = random.Random(seed * 7 + 3)
    faces = [f for f in o.data.polygons if f.normal.y < -0.35 and f.center.z < 0.15]
    rnd.shuffle(faces)
    mm = metal_mat(mask)
    if mask:
        dark = flat_emit("socket_mask", 0.0)
    else:
        dark = bpy.data.materials.new("socket"); dark.use_nodes = True
        dp = dark.node_tree.nodes["Principled BSDF"]
        dp.inputs["Base Color"].default_value = (*ORE_LOOK["rim"], 1); dp.inputs["Roughness"].default_value = 0.8
    made = []
    for f in faces:
        if len(made) >= 2 + (seed % 2): break
        c = Vector(f.center)
        if any((c - q).length < 0.2 for q in made): continue
        made.append(c)
        r = rnd.uniform(0.065, 0.085)
        nrm = Vector(f.normal)
        for mat, rr, sink in ((dark, r * 1.25, 0.55), (mm, r, 0.3)):
            bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, radius=rr, location=c - nrm * rr * sink)
            nug = bpy.context.object
            nug.scale = (1.0, 0.7, 0.85)
            tx = bpy.data.textures.new("nug", 'VORONOI'); tx.noise_scale = 0.05
            d = nug.modifiers.new("lumps", 'DISPLACE'); d.texture = tx; d.strength = rr * 0.3
            nug.data.materials.append(mat)
            for poly in nug.data.polygons: poly.use_smooth = True

def bloom(sc):
    """the glowing ore spreads a soft light round itself"""
    sc.render.use_compositing = True
    tree = bpy.data.node_groups.new("bloom", 'CompositorNodeTree')
    sc.compositing_node_group = tree
    rl = tree.nodes.new("CompositorNodeRLayers")
    gl = tree.nodes.new("CompositorNodeGlare")
    out = tree.nodes.new("NodeGroupOutput")
    tree.interface.new_socket("Image", in_out='OUTPUT', socket_type='NodeSocketColor')
    for k, v in (("Type", 'Fog Glow'), ("Quality", 'High'), ("Threshold", 1.2), ("Size", 0.4), ("Strength", 0.6)):
        if k in gl.inputs: gl.inputs[k].default_value = v
    tree.links.new(rl.outputs["Image"], gl.inputs["Image"])
    tree.links.new(gl.outputs["Image"], out.inputs[0])

# width / height on screen, as in the drawings; every stone is then fitted to the same height
ASPECT = {"natural": {"ruby": 0.84, "citrine": 0.72, "sapphire": 0.78, "emerald": 0.86, "amethyst": 0.72, "diamond": 0.74},
          "faceted": {"ruby": 1.08, "citrine": 0.7, "sapphire": 1.0, "emerald": 0.7, "amethyst": 1.05, "diamond": 0.66}}
HEIGHT = 0.78   # of a cell

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

def render(style, name, dark, mid, light, ore=None, mask=False):
    """<style>/<name>.png, or with ore <style>/<name>_ore.png: the same stone holding ore, and
    <name>_ore_glow.png: the light of its veins and nuggets alone, white on black, for the game to shimmer"""
    sc = setup()
    o = SHAPES[style][name]()
    fit(o, ASPECT[style][name])
    paint_facets(o)
    o.data.materials.append(gem_mat(dark, mid, light, malachite=(style == "natural" and name == "emerald"), ore=ore, mask=mask))
    if ore:
        nuggets(o, o["seed"], mask)
        if not mask: bloom(sc)
    tag = name + ("_ore" if ore else "") + ("_glow" if mask else "")
    sc.render.filepath = os.path.join(OUT, style, tag + ".png")
    bpy.ops.render.render(write_still=True)
    print("GEM", style, tag)

for style in ("natural", "faceted"):
    for name, dark, mid, light in GEMS:
        for ore in (False, True):
            tag = style + "/" + name + ("_ore" if ore else "")
            if ONLY and tag not in ONLY and style + "/" + name not in ONLY: continue
            os.makedirs(os.path.join(OUT, style), exist_ok=True)
            render(style, name, dark, mid, light, ore)
            if ore: render(style, name, dark, mid, light, ore, mask=True)
