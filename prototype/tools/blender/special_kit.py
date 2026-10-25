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
    mp = N.new("ShaderNodeMapping"); mp.inputs["Scale"].default_value = (1.2, 4.0, 4.0)
    N.link(N.pos, mp.inputs["Vector"])
    def scan(suffix, data=True):
        t = N.new("ShaderNodeTexImage"); t.image = bpy.data.images.load(os.path.join(gk.PROJ, WOOD + "_%s_1k.jpg" % suffix))
        if data: t.image.colorspace_settings.name = 'Non-Color'
        t.projection = 'BOX'; t.projection_blend = 0.3
        N.link(mp.outputs[0], t.inputs["Vector"]); return t.outputs["Color"]
    bw = N.new("ShaderNodeRGBToBW"); N.link(scan("diff", False), bw.inputs[0])
    # a mine prop's old pine: warm brown, darker in its grain, greyed where it is worn
    col = N.ramp(N.remap(bw.outputs[0], 0.04, 0.3, 0.0, 1.0),
                 [(0.0, (0.06, 0.03, 0.012)), (0.45, (0.26, 0.14, 0.06)), (1.0, (0.55, 0.36, 0.18))])
    fa = N.new("ShaderNodeVertexColor"); fa.layer_name = "facet"
    ft = N.new("ShaderNodeMix"); ft.data_type = 'RGBA'; ft.blend_type = 'MULTIPLY'; ft.inputs["Factor"].default_value = 0.5
    N.link(col, ft.inputs["A"]); N.link(fa.outputs["Color"], ft.inputs["B"]); col = ft.outputs[2]
    col = N.mix(N.edges(0.02, 0.35), col, (0.72, 0.55, 0.36))
    N.link(col, N.p.inputs["Base Color"])
    N.p.inputs["Roughness"].default_value = 0.85
    nm = N.new("ShaderNodeNormalMap"); nm.inputs["Strength"].default_value = 1.5
    N.link(scan("nor_gl"), nm.inputs["Color"])
    N.link(N.bump(scan("disp"), 0.4, nm.outputs[0]), N.p.inputs["Normal"])
    return N.m

def iron_mat():
    N = Nodes("iron")
    nz = N.noise(30.0, 6)
    col = N.ramp(nz.outputs["Fac"], [(0.35, (0.05, 0.05, 0.055)), (0.55, (0.16, 0.16, 0.17)), (0.75, (0.3, 0.12, 0.05))])
    N.link(col, N.p.inputs["Base Color"])
    N.p.inputs["Metallic"].default_value = 0.85
    N.link(N.remap(nz.outputs["Fac"], 0.3, 0.7, 0.3, 0.7), N.p.inputs["Roughness"])
    return N.m

def beam(length, w, t, seed):
    """a hewn beam along x: a long block with uneven adze cuts along its edges"""
    rnd = random.Random(seed)
    pl = gk.box_planes(length / 2, t / 2, w / 2)
    # its edges hewn off by the adze: a narrow chamfer of uneven width along each, tipped a hair along the beam
    for sy, sz in ((-1, 1), (-1, -1), (1, 1), (1, -1)):
        for k in range(2):
            n = Vector((rnd.uniform(-0.02, 0.02), sy * rnd.uniform(0.7, 1.3), sz)).normalized()
            pl.append((Vector((0, sy * t / 2, sz * w / 2)) - n * rnd.uniform(0.012, 0.022), n))
    for sx in (-1, 1):
        n = Vector((sx, rnd.uniform(-0.3, 0.3), rnd.uniform(-0.3, 0.3))).normalized()
        pl.append((Vector((sx * length / 2, 0, 0)), n))
    o = gk.cut(pl, seed, (0.75, 1.1))
    gk.paint_facets(o)
    return o

def lock():
    wm = wood_mat(); im = iron_mat()
    objs = []
    for k, (ang, y) in enumerate(((math.radians(45), 0.0), (math.radians(-45), -0.09))):
        b = beam(1.18, 0.2, 0.085, 70 + k)
        b.data.materials.append(wm)
        b.rotation_euler = (0, -ang, 0); b.location = (0, y, 0)
        objs.append(b)
        # bolts near both ends
        for e in (-0.44, 0.44):
            p = Vector((e * math.cos(ang), y - 0.05, e * math.sin(ang)))
            bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.03, depth=0.03, location=p, rotation=(math.pi / 2, 0, 0.3))
            o = bpy.context.object; o.data.materials.append(im)
            bv = o.modifiers.new("b", 'BEVEL'); bv.width = 0.006
            objs.append(o)
    # an iron band round the crossing
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, -0.14, 0), rotation=(0, math.radians(45), 0))
    o = bpy.context.object; o.scale = (0.05, 0.02, 0.26); o.data.materials.append(im)
    bv = o.modifiers.new("b", 'BEVEL'); bv.width = 0.006
    objs.append(o)
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

JOBS = {"lock": (lock, 1.08), "rh": (lambda: dynamite(False), 1.04), "rv": (lambda: dynamite(True), 1.0),
        "bomb": (bomb, 0.96), "drill": (drill, 1.0), "orb": (opal, 0.86)}
os.makedirs(OUT, exist_ok=True)
for name, (fn, size) in JOBS.items():
    if ONLY and name not in ONLY: continue
    sc = scene()
    fn()
    fit_all(size)
    sc.render.filepath = os.path.join(OUT, name + ".png")
    bpy.ops.render.render(write_still=True)
    print("SPECIAL", name)
