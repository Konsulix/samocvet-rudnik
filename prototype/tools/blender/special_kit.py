# Timber locks and the special pieces in the look of the gem sets (gem_kit.py, blocker_kit.py): the same camera
# (front, a little above) and lamp.
#   lock   two hewn timber beams crossed over the cell, iron bolts at their ends and a band where they cross
#   rh/rv  a stick of dynamite, lying across / standing up (which way it fires), its fuse sparking
#   bomb   three sticks tied with twine, one fuse
#   drill  a twisted steel auger in a brass collar
#   orb    the resonator: an opal drop, its play of colour glowing from within
#   blender -b -P special_kit.py -- <out_dir> [px] [samples] [only: name,...]
import bpy, bmesh, sys, math, os, random, importlib.util
from mathutils import Vector, Quaternion
argv = sys.argv[sys.argv.index("--") + 1:]
OUT = argv[0]
PX = int(argv[1]) if len(argv) > 1 else 256
SAMPLES = int(argv[2]) if len(argv) > 2 else 128
ONLY = argv[3].split(",") if len(argv) > 3 else None

_real = sys.argv
sys.argv = ["blender", "--", OUT, str(PX), str(SAMPLES), "none"]
_spec = importlib.util.spec_from_file_location("gem_kit", os.path.join(os.path.dirname(__file__), "gem_kit.py"))
gk = importlib.util.module_from_spec(_spec); _spec.loader.exec_module(gk)
sys.argv = _real
WOOD = "art/textures/dark_wooden_planks/dark_wooden_planks"
ANCHORS = {}   # model points the game animates on top of a sprite (a fuse's spark, the radar's screen)

def scene():
    sc = gk.setup()
    bpy.data.objects["sun"].data.energy = 4.0
    bpy.data.worlds["w"].node_tree.nodes["Background"].inputs[1].default_value = 0.35
    return sc

class Nodes:
    """a little helper over a material's node tree"""
    def __init__(self, name):
        self.m = bpy.data.materials.new(name); self.m.use_nodes = True
        self.n = self.m.node_tree; self.L = self.n.links
        self.p = self.n.nodes["Principled BSDF"]
        self.pos = self.new("ShaderNodeTexCoord").outputs["Object"]
    def new(self, t): return self.n.nodes.new(t)
    def link(self, a, b): self.L.new(a, b)
    def remap(self, v, f0, f1, t0, t1):
        k = self.new("ShaderNodeMapRange")
        k.inputs["From Min"].default_value = f0; k.inputs["From Max"].default_value = f1
        k.inputs["To Min"].default_value = t0; k.inputs["To Max"].default_value = t1
        self.link(v, k.inputs["Value"]); return k.outputs[0]
    def noise(self, scale, detail=4, vec=None, distortion=0.0):
        k = self.new("ShaderNodeTexNoise"); k.inputs["Scale"].default_value = scale; k.inputs["Detail"].default_value = detail
        k.inputs["Distortion"].default_value = distortion
        self.link(vec or self.pos, k.inputs["Vector"]); return k
    def ramp(self, v, stops):
        k = self.new("ShaderNodeValToRGB"); cr = k.color_ramp
        cr.elements[0].position, c0 = stops[0]; cr.elements[0].color = (*c0, 1)
        cr.elements[1].position, c1 = stops[-1]; cr.elements[1].color = (*c1, 1)
        for pos, c in stops[1:-1]:
            e = cr.elements.new(pos); e.color = (*c, 1)
        self.link(v, k.inputs["Fac"]); return k.outputs[0]
    def mix(self, fac, a, b):
        k = self.new("ShaderNodeMix"); k.data_type = 'RGBA'
        self.link(fac, k.inputs["Factor"]); self.link(a, k.inputs["A"])
        if isinstance(b, tuple): k.inputs["B"].default_value = (*b, 1)
        else: self.link(b, k.inputs["B"])
        return k.outputs[2]
    def edges(self, radius=0.015, amount=0.4):
        geo = self.new("ShaderNodeNewGeometry")
        bv = self.new("ShaderNodeBevel"); bv.inputs["Radius"].default_value = radius; bv.samples = 8
        dt = self.new("ShaderNodeVectorMath"); dt.operation = 'DOT_PRODUCT'
        self.link(bv.outputs[0], dt.inputs[0]); self.link(geo.outputs["Normal"], dt.inputs[1])
        return self.remap(dt.outputs["Value"], 0.999, 0.97, 0.0, amount)
    def bump(self, h, strength, normal=None):
        b = self.new("ShaderNodeBump"); b.inputs["Strength"].default_value = strength
        self.link(h, b.inputs["Height"])
        if normal: self.link(normal, b.inputs["Normal"])
        return b.outputs[0]

def mat_plain(col, rough=0.5, metal=0.0):
    m = bpy.data.materials.new("plain"); m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (*col, 1); p.inputs["Roughness"].default_value = rough
    p.inputs["Metallic"].default_value = metal
    return m

# ---------------------------------------------------------------- timber

def wood_mat():
    N = Nodes("timber")
    mp = N.new("ShaderNodeMapping"); mp.inputs["Scale"].default_value = (0.8, 1.6, 1.6)
    N.link(N.pos, mp.inputs["Vector"])
    def scan(suffix, data=True):
        t = N.new("ShaderNodeTexImage"); t.image = bpy.data.images.load(os.path.join(gk.PROJ, WOOD + "_%s_1k.jpg" % suffix))
        if data: t.image.colorspace_settings.name = 'Non-Color'
        t.projection = 'BOX'; t.projection_blend = 0.3
        N.link(mp.outputs[0], t.inputs["Vector"]); return t.outputs["Color"]
    bw = N.new("ShaderNodeRGBToBW"); N.link(scan("diff", False), bw.inputs[0])
    # a mine prop's old pine: warm brown, darker in its grain, greyed where it is worn
    col = N.ramp(N.remap(bw.outputs[0], 0.03, 0.22, 0.0, 1.0),
                 [(0.0, (0.03, 0.014, 0.005)), (0.45, (0.13, 0.065, 0.025)), (1.0, (0.36, 0.2, 0.08))])
    fa = N.new("ShaderNodeVertexColor"); fa.layer_name = "facet"
    ft = N.new("ShaderNodeMix"); ft.data_type = 'RGBA'; ft.blend_type = 'MULTIPLY'; ft.inputs["Factor"].default_value = 0.5
    N.link(col, ft.inputs["A"]); N.link(fa.outputs["Color"], ft.inputs["B"]); col = ft.outputs[2]
    col = N.mix(N.edges(0.005, 0.3), col, (0.62, 0.42, 0.22))   # only the very edges catch light: the strips are thin
    N.link(col, N.p.inputs["Base Color"])
    N.p.inputs["Roughness"].default_value = 0.85
    nm = N.new("ShaderNodeNormalMap"); nm.inputs["Strength"].default_value = 1.5
    N.link(scan("nor_gl"), nm.inputs["Color"])
    N.link(N.bump(scan("disp"), 0.4, nm.outputs[0]), N.p.inputs["Normal"])
    return N.m

def iron_mat():
    N = Nodes("iron")
    nz = N.noise(30.0, 6)
    # dark wrought iron, rust blooming over it
    col = N.ramp(nz.outputs["Fac"], [(0.35, (0.04, 0.04, 0.045)), (0.55, (0.11, 0.11, 0.12)), (0.72, (0.28, 0.1, 0.035))])
    N.link(col, N.p.inputs["Base Color"])
    N.p.inputs["Metallic"].default_value = 0.85
    N.link(N.remap(nz.outputs["Fac"], 0.3, 0.7, 0.3, 0.7), N.p.inputs["Roughness"])
    return N.m

def beam(length, w, t, seed):
    """an old beam along x, split lengthwise into strips of wood: each strip ends in its own slanted break, so the
    beam's ends are splintered, and the strips stand a hair proud of one another, so the splits read as cracks"""
    rnd = random.Random(seed)
    strips = 3
    out = []
    for k in range(strips):
        z0 = -w / 2 + k * w / strips
        z1 = z0 + w / strips
        pl = [(Vector((0, t / 2 + rnd.uniform(-0.004, 0.006), 0)), Vector((0, 1, 0))), (Vector((0, -t / 2 - rnd.uniform(0.0, 0.008), 0)), Vector((0, -1, 0))),
              (Vector((0, 0, z1 - 0.0008)), Vector((0, 0, 1))), (Vector((0, 0, z0 + 0.0008)), Vector((0, 0, -1)))]
        # the edges of the outer strips worn round
        if k == 0: pl.append((Vector((0, -t / 2, z0)) + Vector((0, 0.7, 0.7)).normalized() * -0.012, Vector((0, -0.7, -0.7)).normalized()))
        if k == strips - 1: pl.append((Vector((0, -t / 2, z1)) + Vector((0, 0.7, -0.7)).normalized() * -0.012, Vector((0, -0.7, 0.7)).normalized()))
        for sx in (-1, 1):
            # a ragged break: the strip's end cut by two or three planes at odd angles
            end = length / 2 - rnd.uniform(0.0, 0.07)
            for j in range(2 + (k % 2)):
                n = Vector((sx, rnd.uniform(-0.8, 0.8), rnd.uniform(-0.6, 0.6))).normalized()
                pl.append((Vector((sx * (end - j * 0.02), 0, (z0 + z1) / 2)), n))
        o = gk.cut(pl, seed * 10 + k, (0.7, 1.1))
        gk.paint_facets(o)
        out.append(o)
    return out

def lock():
    wm = wood_mat(); im = iron_mat()
    objs = []
    for k, (ang, y) in enumerate(((math.radians(45), 0.0), (math.radians(-45), -0.1))):
        for b in beam(1.2, 0.21, 0.09, 70 + k):
            b.data.materials.append(wm)
            b.rotation_euler = (0, -ang, 0); b.location = (0, y, 0)
            objs.append(b)
    # an iron cross of two riveted straps over the crossing, a big rivet at its middle
    for k, ang in enumerate((math.radians(45), math.radians(-45))):
        bpy.ops.mesh.primitive_cube_add(size=1, location=(0, -0.16 - k * 0.012, 0), rotation=(0, -ang, 0))
        o = bpy.context.object; o.scale = (0.44, 0.016, 0.1); o.data.materials.append(im)
        bv = o.modifiers.new("b", 'BEVEL'); bv.width = 0.006
        objs.append(o)
        for e in (-0.17, 0.17):
            p = Vector((e * math.cos(ang), -0.185, e * math.sin(ang)))
            bpy.ops.mesh.primitive_uv_sphere_add(radius=0.026, location=p)
            r = bpy.context.object; r.scale = (1, 0.6, 1); r.data.materials.append(im); bpy.ops.object.shade_smooth()
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.036, location=(0, -0.19, 0))
    r = bpy.context.object; r.scale = (1, 0.6, 1); r.data.materials.append(im); bpy.ops.object.shade_smooth()
    return objs

# ---------------------------------------------------------------- dynamite

def paper_mat():
    N = Nodes("paper")
    fib = N.noise(40.0, 8, distortion=0.5)
    wr = N.noise(6.0, 3)
    col = N.ramp(N.remap(wr.outputs["Fac"], 0.3, 0.7, 0.0, 1.0), [(0.0, (0.32, 0.025, 0.015)), (0.6, (0.62, 0.05, 0.03)), (1.0, (0.85, 0.16, 0.08))])
    col = N.mix(N.remap(fib.outputs["Fac"], 0.55, 0.75, 0.0, 0.25), col, (0.9, 0.5, 0.35))
    N.link(col, N.p.inputs["Base Color"])
    N.p.inputs["Roughness"].default_value = 0.55
    N.p.inputs["Coat Weight"].default_value = 0.15
    N.link(N.bump(wr.outputs["Fac"], 0.15), N.p.inputs["Normal"])
    return N.m

def band_mat():
    N = Nodes("band")
    fib = N.noise(60.0, 6)
    col = N.ramp(fib.outputs["Fac"], [(0.35, (0.55, 0.45, 0.3)), (0.65, (0.82, 0.74, 0.56))])
    N.link(col, N.p.inputs["Base Color"]); N.p.inputs["Roughness"].default_value = 0.8
    return N.m

def twine_mat():
    N = Nodes("twine")
    tw = N.new("ShaderNodeTexWave"); tw.inputs["Scale"].default_value = 40.0; tw.inputs["Distortion"].default_value = 2.0
    N.link(N.pos, tw.inputs["Vector"])
    col = N.ramp(tw.outputs["Fac"], [(0.2, (0.22, 0.14, 0.06)), (0.8, (0.62, 0.48, 0.28))])
    N.link(col, N.p.inputs["Base Color"]); N.p.inputs["Roughness"].default_value = 0.9
    N.link(N.bump(tw.outputs["Fac"], 0.5), N.p.inputs["Normal"])
    return N.m

def spark_mat():
    m = bpy.data.materials.new("spark"); m.use_nodes = True
    n = m.node_tree; n.nodes.remove(n.nodes["Principled BSDF"])
    e = n.nodes.new("ShaderNodeEmission"); e.inputs["Color"].default_value = (1.0, 0.62, 0.15, 1); e.inputs["Strength"].default_value = 14
    n.links.new(e.outputs[0], n.nodes["Material Output"].inputs["Surface"])
    return m

def cyl(r, d, loc, rot, m, verts=40):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=d, location=loc, rotation=rot)
    o = bpy.context.object; bpy.ops.object.shade_smooth()
    bv = o.modifiers.new("b", 'BEVEL'); bv.width = r * 0.12; bv.segments = 3; bv.limit_method = 'ANGLE'
    o.data.materials.append(m)
    return o

def fuse(start, direction, length, rnd):
    """a curling fuse from `start`, its tip glowing with a little star of sparks"""
    fm = twine_mat(); sm = spark_mat()
    pts = []
    p = Vector(start); d = Vector(direction).normalized()
    for k in range(6):
        pts.append(p.copy())
        d = (d + Vector((rnd.uniform(-0.5, 0.5), rnd.uniform(-0.2, 0.2), rnd.uniform(-0.1, 0.5)))).normalized()
        p += d * length / 5
    cu = bpy.data.curves.new("fuse", 'CURVE'); cu.dimensions = '3D'; cu.bevel_depth = 0.014; cu.bevel_resolution = 3
    sp = cu.splines.new('NURBS'); sp.points.add(len(pts) - 1)
    for i, q in enumerate(pts): sp.points[i].co = (*q, 1)
    sp.use_endpoint_u = True; sp.order_u = 3
    o = bpy.data.objects.new("fuse", cu); bpy.context.scene.collection.objects.link(o); o.data.materials.append(fm)
    tip = pts[-1]
    ANCHORS.setdefault("sparks", []).append(tip.copy())
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.035, location=tip)
    bpy.context.object.data.materials.append(sm)
    for k in range(7):
        a = k / 7 * math.tau
        dd = Vector((math.cos(a), rnd.uniform(-0.3, 0.3), math.sin(a)))
        bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.008, depth=rnd.uniform(0.05, 0.09),
                                        location=tip + dd * 0.05, rotation=Vector((0, 0, 1)).rotation_difference(dd).to_euler())
        bpy.context.object.data.materials.append(sm)

def stick(at, axis, length=0.78, r=0.12):
    """a stick of dynamite: red paper, a pale band near each end"""
    pm, bm = paper_mat(), band_mat()
    q = Vector((0, 0, 1)).rotation_difference(Vector(axis))
    o = cyl(r, length, at, q.to_euler(), pm)
    for s in (-0.3, 0.3):
        cyl(r * 1.03, length * 0.07, Vector(at) + Vector(axis) * length * s, q.to_euler(), bm)
    return o

def dynamite(vertical):
    rnd = random.Random(5)
    if vertical:
        stick((0, 0, -0.06), (0.12, 0, 1), 0.72)
        fuse((0.04, 0, 0.3), (0.3, 0, 1), 0.2, rnd)
    else:
        stick((-0.04, 0, 0), (1, 0, 0.12), 0.8)
        fuse((0.36, 0, 0.05), (1, 0, 0.6), 0.2, rnd)

def bomb():
    rnd = random.Random(9)
    for x, y, z in ((-0.12, 0.0, -0.05), (0.12, 0.0, -0.05), (0.0, -0.1, 0.0)):
        stick((x, y, z), (0, 0, 1), 0.68, 0.11)
    tm = twine_mat()
    for z in (-0.2, 0.12):
        bpy.ops.mesh.primitive_torus_add(major_radius=0.235, minor_radius=0.018, location=(0, -0.03, z))
        o = bpy.context.object; o.scale = (1.05, 0.75, 1.0); o.data.materials.append(tm)
        bpy.ops.object.shade_smooth()
    fuse((0.0, -0.1, 0.34), (0.2, 0, 1), 0.18, rnd)

# ---------------------------------------------------------------- drill

def steel_mat():
    N = Nodes("steel")
    sc = N.noise(80.0, 4)
    col = N.ramp(sc.outputs["Fac"], [(0.4, (0.42, 0.45, 0.5)), (0.6, (0.62, 0.65, 0.7))])
    # grime in the flutes
    ao = N.new("ShaderNodeAmbientOcclusion"); ao.inputs["Distance"].default_value = 0.05
    col = N.mix(N.remap(ao.outputs["AO"], 1.0, 0.5, 0.0, 0.7), col, (0.05, 0.045, 0.04))
    N.link(col, N.p.inputs["Base Color"])
    N.p.inputs["Metallic"].default_value = 1.0
    N.p.inputs["Roughness"].default_value = 0.28
    return N.m

def brass_mat():
    N = Nodes("brass")
    nz = N.noise(25.0, 5)
    col = N.ramp(nz.outputs["Fac"], [(0.35, (0.35, 0.2, 0.05)), (0.65, (0.85, 0.6, 0.22))])
    N.link(col, N.p.inputs["Base Color"]); N.p.inputs["Metallic"].default_value = 1.0
    N.link(N.remap(nz.outputs["Fac"], 0.3, 0.7, 0.2, 0.45), N.p.inputs["Roughness"])
    return N.m

def drill():
    # an auger: a long four-sided bar, tapered to a point and twisted into spiral flutes
    bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.17, radius2=0.0, depth=0.72, location=(0, 0, -0.06), rotation=(math.pi, 0, 0))
    o = bpy.context.object
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.subdivide(number_cuts=30); bpy.ops.object.mode_set(mode='OBJECT')
    tw = o.modifiers.new("twist", 'SIMPLE_DEFORM'); tw.deform_method = 'TWIST'; tw.angle = math.radians(540); tw.deform_axis = 'Z'
    bv = o.modifiers.new("b", 'BEVEL'); bv.width = 0.008; bv.segments = 2
    bpy.ops.object.shade_smooth(); o.data.materials.append(steel_mat())
    # the brass collar it sits in, a hex nut on top
    br = brass_mat()
    cyl(0.19, 0.12, (0, 0, 0.33), (0, 0, 0), br, 6)
    cyl(0.11, 0.1, (0, 0, 0.43), (0, 0, 0.5), br, 6)

# ---------------------------------------------------------------- opal

def opal_mat():
    """milky glass with patches of play-of-colour: each patch one bright spectral colour, glowing from within"""
    N = Nodes("opal")
    vo = N.new("ShaderNodeTexVoronoi"); vo.inputs["Scale"].default_value = 9.0
    wn = N.noise(3.0, 2)
    wp = N.new("ShaderNodeMix"); wp.data_type = 'VECTOR'; wp.inputs["Factor"].default_value = 0.2
    N.link(N.pos, wp.inputs[4]); N.link(wn.outputs["Color"], wp.inputs[5]); N.link(wp.outputs[1], vo.inputs["Vector"])
    sep = N.new("ShaderNodeSeparateColor"); N.link(vo.outputs["Color"], sep.inputs[0])
    hue = N.new("ShaderNodeCombineColor"); hue.mode = 'HSV'
    N.link(sep.outputs["Red"], hue.inputs["Red"]); hue.inputs["Green"].default_value = 0.9; hue.inputs["Blue"].default_value = 0.75
    patch = N.remap(vo.outputs["Distance"], 0.4, 0.05, 0.0, 1.0)   # bright cores, fading to the milky body between
    lw = N.new("ShaderNodeLayerWeight"); lw.inputs["Blend"].default_value = 0.4
    body = N.ramp(lw.outputs["Facing"], [(0.0, (0.45, 0.55, 0.68)), (1.0, (0.15, 0.25, 0.45))])
    col = N.mix(N.remap(patch, 0.0, 1.0, 0.25, 1.0), body, hue.outputs[0])
    fa = N.new("ShaderNodeVertexColor"); fa.layer_name = "facet"
    ft = N.new("ShaderNodeMix"); ft.data_type = 'RGBA'; ft.blend_type = 'MULTIPLY'; ft.inputs["Factor"].default_value = 0.35
    N.link(col, ft.inputs["A"]); N.link(fa.outputs["Color"], ft.inputs["B"]); col = ft.outputs[2]
    col = N.mix(N.edges(0.012, 0.45), col, (0.9, 0.95, 1.0))
    N.link(col, N.p.inputs["Base Color"])
    N.link(col, N.p.inputs["Emission Color"])
    N.link(N.remap(patch, 0.0, 1.0, 0.05, 0.4), N.p.inputs["Emission Strength"])
    N.p.inputs["Roughness"].default_value = 0.3
    N.p.inputs["Coat Weight"].default_value = 0.3
    N.p.inputs["Specular IOR Level"].default_value = 0.3
    return N.m

def opal():
    o = gk.cut(gk.egg_planes(70, 81, w=0.4, d=0.32, h=0.46, point=0.5, low=0.1, depth=(0.0, 0.025)), 81, (0.6, 1.1))
    gk.fit(o, 0.86)
    gk.paint_facets(o)
    o.data.materials.append(opal_mat())

# ---------------------------------------------------------------- render

def fit_all(height):
    """the whole piece `height` cells tall on screen (or as wide, if wider), centred"""
    bpy.context.view_layer.update()
    tilt = math.radians(12)
    up = Vector((0, math.sin(tilt), math.cos(tilt)))
    pts = []
    for o in bpy.context.scene.objects:
        if o.type not in ('MESH', 'CURVE'): continue
        dg = o.evaluated_get(bpy.context.evaluated_depsgraph_get())
        me = dg.to_mesh()
        pts += [o.matrix_world @ v.co for v in me.vertices]
        dg.to_mesh_clear()
    xs = [p.x for p in pts]; ys = [p.dot(up) for p in pts]
    k = height / max(max(xs) - min(xs), max(ys) - min(ys))
    c = Vector(((max(xs) + min(xs)) / 2, 0, 0)) + up * ((max(ys) + min(ys)) / 2)
    root = bpy.data.objects.new("root", None); bpy.context.scene.collection.objects.link(root)
    for o in list(bpy.context.scene.objects):
        if o.type in ('MESH', 'CURVE') and o.parent is None:
            o.parent = root
    root.location = -c * k; root.scale = (k, k, k)
    return c, k

def to_uv(p, c, k):
    """a model point as the sprite's UV (the camera sees SPAN cells across, centred on the origin)"""
    tilt = math.radians(12)
    up = Vector((0, math.sin(tilt), math.cos(tilt)))
    q = (Vector(p) - c) * k
    return [round(0.5 + q.x / gk.SPAN, 4), round(0.5 - q.dot(up) / gk.SPAN, 4)]

# ---------------------------------------------------------------- the pickaxe (a booster)

def pickaxe():
    """a miner's pick: a long curved steel head, both ends pointed, on a worn ash handle, leaning to the right"""
    wm = wood_mat(); st = steel_mat(); im = iron_mat()
    tilt = math.radians(-35)
    q = Quaternion((0, 1, 0), tilt)
    # the handle, slightly thicker towards its foot
    bpy.ops.mesh.primitive_cone_add(vertices=16, radius1=0.05, radius2=0.04, depth=0.86, location=(0, 0, -0.08))
    h = bpy.context.object; bpy.ops.object.shade_smooth(); h.data.materials.append(wm)
    h.rotation_mode = 'QUATERNION'; h.rotation_quaternion = q; h.location = q @ Vector((0, 0, -0.08))
    # the head: a long four-sided spike each way, bent down at its tips
    # built along its own z, then turned across the handle: its local x ends up pointing down
    bpy.ops.mesh.primitive_cylinder_add(vertices=4, radius=0.055, depth=0.86, rotation=(0, 0, math.pi / 4))
    hd = bpy.context.object
    bpy.ops.object.transform_apply(rotation=True)
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.subdivide(number_cuts=24); bpy.ops.object.mode_set(mode='OBJECT')
    for v in hd.data.vertices:
        t = abs(v.co.z) / 0.43
        v.co.x *= 1.0 - t * 0.92; v.co.y *= 1.0 - t * 0.92          # tapering to the points
        v.co.x += (v.co.z ** 2) * 0.55                                # curving down at both ends
    bv = hd.modifiers.new("b", 'BEVEL'); bv.width = 0.006
    hd.data.materials.append(st)
    hd.rotation_mode = 'QUATERNION'; hd.rotation_quaternion = q @ Quaternion((0, 1, 0), math.pi / 2)
    hd.location = q @ Vector((0, 0, 0.35))
    # the eye it sits in
    bpy.ops.mesh.primitive_cube_add(size=1)
    e = bpy.context.object; e.scale = (0.14, 0.1, 0.12); e.data.materials.append(im)
    bv = e.modifiers.new("b", 'BEVEL'); bv.width = 0.015; bv.segments = 2
    e.rotation_mode = 'QUATERNION'; e.rotation_quaternion = q; e.location = q @ Vector((0, 0, 0.35))

# ---------------------------------------------------------------- the resonator: a radar set into the rock

def rock_mat():
    N = Nodes("rock")
    t = N.new("ShaderNodeTexImage")
    t.image = bpy.data.images.load(os.path.join(gk.PROJ, "godot/assets/textures/rock_face_03/rock_face_03_diff_1k.jpg"))
    t.projection = 'BOX'; t.projection_blend = 0.3
    mp = N.new("ShaderNodeMapping"); mp.inputs["Scale"].default_value = (1.6, 1.6, 1.6)
    N.link(N.pos, mp.inputs["Vector"]); N.link(mp.outputs[0], t.inputs["Vector"])
    bw = N.new("ShaderNodeRGBToBW"); N.link(t.outputs["Color"], bw.inputs[0])
    col = N.ramp(N.remap(bw.outputs[0], 0.05, 0.4, 0.0, 1.0), [(0.0, (0.015, 0.016, 0.018)), (0.5, (0.06, 0.062, 0.068)), (1.0, (0.17, 0.175, 0.185))])
    fa = N.new("ShaderNodeVertexColor"); fa.layer_name = "facet"
    ft = N.new("ShaderNodeMix"); ft.data_type = 'RGBA'; ft.blend_type = 'MULTIPLY'; ft.inputs["Factor"].default_value = 0.6
    N.link(col, ft.inputs["A"]); N.link(fa.outputs["Color"], ft.inputs["B"])
    N.link(ft.outputs[2], N.p.inputs["Base Color"]); N.p.inputs["Roughness"].default_value = 0.85
    return N.m

def screen_mat():
    """the radar's glass: deep teal, range rings and a cross glowing cyan (the sweep and the blips are drawn live
    in the game: shaders/special_fx.gdshader)"""
    N = Nodes("screen")
    sep = N.new("ShaderNodeSeparateXYZ"); N.link(N.pos, sep.inputs[0])
    xy = N.new("ShaderNodeCombineXYZ"); N.link(sep.outputs["X"], xy.inputs["X"]); N.link(sep.outputs["Y"], xy.inputs["Y"])
    rl = N.new("ShaderNodeVectorMath"); rl.operation = 'LENGTH'; N.link(xy.outputs[0], rl.inputs[0])
    r = rl.outputs["Value"]
    def line(v, width):
        k = N.new("ShaderNodeMath"); k.operation = 'ABSOLUTE'; N.link(v, k.inputs[0])
        return N.remap(k.outputs[0], width, 0.0, 0.0, 1.0)
    pp = N.new("ShaderNodeMath"); pp.operation = 'PINGPONG'; pp.inputs[1].default_value = 0.045
    N.link(r, pp.inputs[0])
    rings = N.remap(pp.outputs[0], 0.006, 0.0, 0.0, 1.0)
    cross = N.new("ShaderNodeMath"); cross.operation = 'MAXIMUM'
    N.link(line(sep.outputs["X"], 0.005), cross.inputs[0]); N.link(line(sep.outputs["Y"], 0.005), cross.inputs[1])
    lines = N.new("ShaderNodeMath"); lines.operation = 'MAXIMUM'
    N.link(rings, lines.inputs[0]); N.link(cross.outputs[0], lines.inputs[1])
    base = N.ramp(N.remap(r, 0.0, 0.28, 1.0, 0.0), [(0.0, (0.0, 0.03, 0.045)), (1.0, (0.0, 0.16, 0.22))])
    col = N.mix(N.remap(lines.outputs[0], 0.0, 1.0, 0.0, 0.85), base, (0.3, 0.95, 1.0))
    N.link(col, N.p.inputs["Base Color"]); N.link(col, N.p.inputs["Emission Color"])
    N.p.inputs["Emission Strength"].default_value = 0.6
    N.p.inputs["Roughness"].default_value = 0.08; N.p.inputs["Coat Weight"].default_value = 1.0
    return N.m

def radar():
    rnd = random.Random(23)
    face = Quaternion((0, 1, 0), math.radians(-18)) @ Quaternion((1, 0, 0), math.pi / 2)   # its disc facing us, tipped
    br, rk = brass_mat(), rock_mat()
    def put(o, local):
        o.rotation_mode = 'QUATERNION'; o.rotation_quaternion = face @ o.rotation_quaternion
        o.location = face @ Vector(local)
    # the rock it is set in: chunks round the rim, a dark core behind
    for k in range(14):
        a = k / 14 * math.tau + rnd.uniform(-0.12, 0.12)
        sz = rnd.uniform(0.11, 0.15)
        o = gk.cut(gk.block_planes(16, 300 + k, sz, sz * 0.8, sz * 0.9, 2.4, (0.0, 0.02)), 300 + k, (0.55, 1.1))
        gk.paint_facets(o); o.data.materials.append(rk)
        o.rotation_euler = (rnd.uniform(0, 6), rnd.uniform(0, 6), rnd.uniform(0, 6))
        o.location = face @ Vector((math.cos(a) * 0.37, math.sin(a) * 0.41, rnd.uniform(-0.09, -0.04)))
    bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=0.36, depth=0.08)
    o = bpy.context.object; o.data.materials.append(rk); put(o, (0, 0, -0.03))
    # the brass frame: an octagon with a rivet at four corners, a rim round the glass
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.37, depth=0.07, rotation=(0, 0, math.pi / 8))
    o = bpy.context.object; o.data.materials.append(br)
    bv = o.modifiers.new("b", 'BEVEL'); bv.width = 0.012; bv.segments = 2
    put(o, (0, 0, 0.02))
    bpy.ops.mesh.primitive_torus_add(major_radius=0.29, minor_radius=0.018)
    o = bpy.context.object; o.data.materials.append(br); bpy.ops.object.shade_smooth(); put(o, (0, 0, 0.058))
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.022)
        o = bpy.context.object; o.data.materials.append(br); bpy.ops.object.shade_smooth()
        put(o, (math.cos(a) * 0.33, math.sin(a) * 0.33, 0.055))
    bpy.ops.mesh.primitive_cylinder_add(vertices=64, radius=0.28, depth=0.02)
    o = bpy.context.object; o.data.materials.append(screen_mat()); put(o, (0, 0, 0.056))
    ANCHORS["screen"] = face @ Vector((0, 0, 0.067))
    ANCHORS["radius"] = 0.275
    # the antenna: a brass pipe out of the top right corner
    d = (face @ Vector((0.55, 0.85, 0.15))).normalized()
    q = Vector((0, 0, 1)).rotation_difference(d)
    base = face @ Vector((0.24, 0.36, 0.0))
    cyl(0.04, 0.2, base + d * 0.1, q.to_euler(), br, 20)
    cyl(0.05, 0.04, base + d * 0.2, q.to_euler(), br, 20)

# ---------------------------------------------------------------- a painted finish over everything

def paint_pass():
    """the gems are painted more than lit: every surface here gets the same light edges and a share of its own
    colour as light, so the specials sit with them instead of looking like photographs"""
    for m in bpy.data.materials:
        if not m.use_nodes or "Principled BSDF" not in m.node_tree.nodes: continue
        n = m.node_tree; p = n.nodes["Principled BSDF"]
        if p.inputs["Emission Strength"].is_linked or p.inputs["Emission Strength"].default_value > 0.0: continue
        src = p.inputs["Base Color"].links[0].from_socket if p.inputs["Base Color"].is_linked else None
        geo = n.nodes.new("ShaderNodeNewGeometry")
        bv = n.nodes.new("ShaderNodeBevel"); bv.inputs["Radius"].default_value = 0.012; bv.samples = 8
        dt = n.nodes.new("ShaderNodeVectorMath"); dt.operation = 'DOT_PRODUCT'
        n.links.new(bv.outputs[0], dt.inputs[0]); n.links.new(geo.outputs["Normal"], dt.inputs[1])
        e = n.nodes.new("ShaderNodeMapRange"); e.inputs["From Min"].default_value = 0.9995; e.inputs["From Max"].default_value = 0.985
        # rough rock has too many small facets for light edges: only a hint there
        e.inputs["To Max"].default_value = 0.06 if m.name.startswith(("rock", "timber")) else 0.55
        n.links.new(dt.outputs["Value"], e.inputs["Value"])
        mx = n.nodes.new("ShaderNodeMix"); mx.data_type = 'RGBA'; mx.blend_type = 'SCREEN'
        n.links.new(e.outputs[0], mx.inputs["Factor"])
        if src: n.links.new(src, mx.inputs["A"])
        else: mx.inputs["A"].default_value = p.inputs["Base Color"].default_value
        mx.inputs["B"].default_value = (1.0, 0.92, 0.8, 1)
        n.links.new(mx.outputs[2], p.inputs["Base Color"])
        n.links.new(mx.outputs[2], p.inputs["Emission Color"])
        p.inputs["Emission Strength"].default_value = 0.22
        # satin, not glossy: soft highlights like the gems'
        if not p.inputs["Roughness"].is_linked:
            p.inputs["Roughness"].default_value = max(p.inputs["Roughness"].default_value, 0.38)

JOBS = {"lock": (lock, 0.9), "rh": (lambda: dynamite(False), 1.04), "rv": (lambda: dynamite(True), 1.0),
        "bomb": (bomb, 0.96), "drill": (drill, 1.0), "orb": (radar, 0.98), "pick": (pickaxe, 1.0)}
os.makedirs(OUT, exist_ok=True)
import json
_af = os.path.join(OUT, "anchors.json")
OUTA = json.load(open(_af)) if os.path.exists(_af) else {}
for name, (fn, size) in JOBS.items():
    if ONLY and name not in ONLY: continue
    sc = scene()
    ANCHORS.clear()
    fn()
    paint_pass()
    c, k = fit_all(size)
    if "sparks" in ANCHORS:
        OUTA[name] = {"spark": [to_uv(t, c, k) for t in ANCHORS["sparks"]]}
    if "screen" in ANCHORS:
        OUTA[name] = {"screen": to_uv(ANCHORS["screen"], c, k), "radius": round(ANCHORS["radius"] * k / gk.SPAN, 4)}
    sc.render.filepath = os.path.join(OUT, name + ".png")
    bpy.ops.render.render(write_still=True)
    print("SPECIAL", name)
json.dump(OUTA, open(_af, "w"), indent=1)
