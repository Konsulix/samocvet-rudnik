# The Great Poloz as a frame: a stone serpent's body running round the board (or round an avatar), in the board's
# light. The body is a tube built here vertex by vertex along a path: stone plates with dark seams, twisted bands
# with gold in the grooves, dry moss on top, a tapered tail curling over the start, quartz on two corners.
# The render is later brought to the 1-pt pixel grid (art/boss/layout.py) like the boss himself.
#   blender -b -P serpent_kit.py -- <out_dir> [board|avatar|all|kit] [px_per_cell] [samples] [cols] [rows]
# writes <out_dir>/frame_<cols>x<rows>.png + .json (px per cell, pixel of the cells' top-left corner), avatar.png
import bpy, bmesh, sys, math, os, json
from mathutils import Vector
argv = sys.argv[sys.argv.index("--") + 1:]
OUT = argv[0]
WHAT = argv[1] if len(argv) > 1 else "all"
P = int(argv[2]) if len(argv) > 2 else 160
SAMPLES = int(argv[3]) if len(argv) > 3 else 48
COLS = int(argv[4]) if len(argv) > 4 else 8
ROWS = int(argv[5]) if len(argv) > 5 else 9
PROJ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))

# sizes in cells
D = 0.38             # body thickness on the board
GAP = 0.02           # between the cells and the body
BAND = 0.62          # length of one twisted band
TWIST = 1.0          # bands turn once round the body
PLATES = 2.2         # stone plates per cell along the body
TAIL = 1.4           # length of the tapered tail
MARGIN = 0.55        # room round the frame for the tail and crystals

# palette (linear): Old Adit stone, ink seams, gold, dry moss
STONE = ((0.03, 0.022, 0.015), (0.1, 0.072, 0.045), (0.24, 0.18, 0.12))
INK = (0.006, 0.005, 0.004)
GOLD = (1.0, 0.62, 0.16)
MOSS = (0.2, 0.09, 0.02)


def setup(w, h, scale, cx, cy):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.samples = SAMPLES
    sc.cycles.use_denoising = True
    sc.render.resolution_x = w
    sc.render.resolution_y = h
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
    wd = bpy.data.worlds.new("w"); wd.use_nodes = True; sc.world = wd
    env = wd.node_tree.nodes.new("ShaderNodeTexEnvironment")
    env.image = bpy.data.images.load(os.path.join(PROJ, "godot/assets/hdri/studio_small_09_1k.hdr"))
    wd.node_tree.links.new(env.outputs[0], wd.node_tree.nodes["Background"].inputs[0])
    wd.node_tree.nodes["Background"].inputs[1].default_value = 0.3
    # the same key light as the gems and the board
    d = bpy.data.lights.new("sun", 'SUN'); d.energy = 3.0; d.angle = math.radians(8); d.color = (1.0, 0.96, 0.9)
    s = bpy.data.objects.new("sun", d)
    s.rotation_euler = Vector((0.55, -0.6, -1.0)).to_track_quat('-Z', 'Y').to_euler()
    sc.collection.objects.link(s)
    cd = bpy.data.cameras.new("cam"); cd.type = 'ORTHO'; cd.ortho_scale = scale
    cam = bpy.data.objects.new("cam", cd); cam.location = (cx, cy, 10)
    sc.collection.objects.link(cam); sc.camera = cam
    return sc


def groove(x):
    """1 in the groove between two bands, 0 on the band"""
    return (0.5 + 0.5 * math.cos(2 * math.pi * x)) ** 6


def tube(name, pts, radius_at, lift_at, mat, s0=0.0):
    """Tube along a 2D path (list of (x, y)); u = length in cells, v = round the body (0..1)."""
    seg = 40
    bm = bmesh.new()
    uv_l = bm.loops.layers.uv.new("UVMap")
    gr_l = bm.verts.layers.float.new("groove")
    n = len(pts)
    s = s0
    rings = []
    for i in range(n):
        if i:
            s += (Vector(pts[i]) - Vector(pts[i - 1])).length
        sl = s - s0
        a = Vector(pts[max(0, i - 1)]); b = Vector(pts[min(n - 1, i + 1)])
        t = (b - a).normalized()
        nrm = Vector((-t.y, t.x, 0.0))
        r0 = radius_at(sl)
        z0 = lift_at(sl) + D * 0.45
        ring = []
        for j in range(seg):
            v = j / seg
            th = 2 * math.pi * v
            g = groove(s / BAND + v * TWIST)
            r = r0 * (1.0 - 0.24 * g)
            p = Vector((pts[i][0], pts[i][1], z0)) + nrm * (math.cos(th) * r) + Vector((0, 0, 1)) * (math.sin(th) * r * 0.85)
            vert = bm.verts.new(p)
            vert[gr_l] = g
            ring.append((vert, s, v))
        rings.append(ring)
    for i in range(n - 1):
        for j in range(seg):
            q = [rings[i][j], rings[i][(j + 1) % seg], rings[i + 1][(j + 1) % seg], rings[i + 1][j]]
            f = bm.faces.new([x[0] for x in q])
            for k, loop in enumerate(f.loops):
                vv = q[k][2] if not (k in (1, 2) and j == seg - 1) else 1.0
                loop[uv_l].uv = (q[k][1], vv)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me); bm.free()
    for p in me.polygons: p.use_smooth = True
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    o.data.materials.append(mat)
    return o


def body_material():
    m = bpy.data.materials.new("poloz"); m.use_nodes = True
    n = m.node_tree; L = n.links; nd = n.nodes.new
    p = n.nodes["Principled BSDF"]
    uv = nd("ShaderNodeUVMap"); uv.uv_map = "UVMap"
    sep = nd("ShaderNodeSeparateXYZ"); L.new(uv.outputs[0], sep.inputs[0])
    # plates: voronoi cells on (u * PLATES, v * circumference * PLATES)
    cu = nd("ShaderNodeMath"); cu.operation = 'MULTIPLY'; cu.inputs[1].default_value = PLATES
    L.new(sep.outputs[0], cu.inputs[0])
    cv = nd("ShaderNodeMath"); cv.operation = 'MULTIPLY'; cv.inputs[1].default_value = math.pi * D * PLATES * 1.1
    L.new(sep.outputs[1], cv.inputs[0])
    cmb = nd("ShaderNodeCombineXYZ"); L.new(cu.outputs[0], cmb.inputs[0]); L.new(cv.outputs[0], cmb.inputs[1])
    vo = nd("ShaderNodeTexVoronoi"); vo.voronoi_dimensions = '2D'; vo.inputs["Randomness"].default_value = 0.9
    L.new(cmb.outputs[0], vo.inputs["Vector"])
    ve = nd("ShaderNodeTexVoronoi"); ve.voronoi_dimensions = '2D'; ve.feature = 'DISTANCE_TO_EDGE'
    ve.inputs["Randomness"].default_value = 0.9
    L.new(cmb.outputs[0], ve.inputs["Vector"])
    # each plate its own tone of the stone
    bw = nd("ShaderNodeRGBToBW"); L.new(vo.outputs["Color"], bw.inputs[0])
    ramp = nd("ShaderNodeValToRGB"); cr = ramp.color_ramp
    cr.elements[0].position = 0.15; cr.elements[0].color = (*STONE[0], 1)
    cr.elements[1].position = 0.85; cr.elements[1].color = (*STONE[2], 1)
    e = cr.elements.new(0.5); e.color = (*STONE[1], 1)
    L.new(bw.outputs[0], ramp.inputs["Fac"])
    col = ramp.outputs[0]
    # plates lighter at their middle (each one a little rounded)
    dome = nd("ShaderNodeMapRange"); dome.inputs["From Min"].default_value = 0.0; dome.inputs["From Max"].default_value = 0.35
    dome.inputs["To Min"].default_value = 0.55; dome.inputs["To Max"].default_value = 1.35
    L.new(ve.outputs["Distance"], dome.inputs["Value"])
    md = nd("ShaderNodeMix"); md.data_type = 'RGBA'; md.blend_type = 'MULTIPLY'; md.inputs["Factor"].default_value = 1.0
    L.new(col, md.inputs["A"])
    cd = nd("ShaderNodeCombineColor"); L.new(dome.outputs[0], cd.inputs[0]); L.new(dome.outputs[0], cd.inputs[1]); L.new(dome.outputs[0], cd.inputs[2])
    L.new(cd.outputs[0], md.inputs["B"])
    col = md.outputs[2]
    # dry moss on top, in patches
    geo = nd("ShaderNodeNewGeometry")
    nz = nd("ShaderNodeSeparateXYZ"); L.new(geo.outputs["Normal"], nz.inputs[0])
    top = nd("ShaderNodeMapRange"); top.inputs["From Min"].default_value = 0.2; top.inputs["From Max"].default_value = 0.6
    L.new(nz.outputs[2], top.inputs["Value"])
    mn = nd("ShaderNodeTexNoise"); mn.inputs["Scale"].default_value = 2.2; mn.inputs["Detail"].default_value = 4
    L.new(uv.outputs[0], mn.inputs["Vector"])
    mp = nd("ShaderNodeMapRange"); mp.inputs["From Min"].default_value = 0.46; mp.inputs["From Max"].default_value = 0.5
    L.new(mn.outputs["Fac"], mp.inputs["Value"])
    mt = nd("ShaderNodeMath"); mt.operation = 'MULTIPLY'
    L.new(top.outputs[0], mt.inputs[0]); L.new(mp.outputs[0], mt.inputs[1])
    mf = nd("ShaderNodeTexNoise"); mf.inputs["Scale"].default_value = 90.0; mf.inputs["Detail"].default_value = 8
    L.new(uv.outputs[0], mf.inputs["Vector"])
    mr = nd("ShaderNodeValToRGB")
    mr.color_ramp.elements[0].color = (*[c * 0.4 for c in MOSS], 1); mr.color_ramp.elements[1].color = (*[c * 1.6 for c in MOSS], 1)
    L.new(mf.outputs["Fac"], mr.inputs["Fac"])
    mm = nd("ShaderNodeMix"); mm.data_type = 'RGBA'
    L.new(mt.outputs[0], mm.inputs["Factor"]); L.new(col, mm.inputs["A"]); L.new(mr.outputs[0], mm.inputs["B"])
    col = mm.outputs[2]
    # ink: dark seams between the plates and in the band grooves
    ink = nd("ShaderNodeMapRange"); ink.inputs["From Min"].default_value = 0.11; ink.inputs["From Max"].default_value = 0.06
    L.new(ve.outputs["Distance"], ink.inputs["Value"])
    ga = nd("ShaderNodeAttribute"); ga.attribute_name = "groove"
    gi = nd("ShaderNodeMapRange"); gi.inputs["From Min"].default_value = 0.35; gi.inputs["From Max"].default_value = 0.6
    L.new(ga.outputs["Fac"], gi.inputs["Value"])
    imax = nd("ShaderNodeMath"); imax.operation = 'MAXIMUM'
    L.new(ink.outputs[0], imax.inputs[0]); L.new(gi.outputs[0], imax.inputs[1])
    mi = nd("ShaderNodeMix"); mi.data_type = 'RGBA'
    L.new(imax.outputs[0], mi.inputs["Factor"]); L.new(col, mi.inputs["A"]); mi.inputs["B"].default_value = (*INK, 1)
    col = mi.outputs[2]
    # gold: in the heart of each groove, broken here and there
    gc = nd("ShaderNodeMapRange"); gc.inputs["From Min"].default_value = 0.86; gc.inputs["From Max"].default_value = 0.95
    L.new(ga.outputs["Fac"], gc.inputs["Value"])
    gn = nd("ShaderNodeTexNoise"); gn.inputs["Scale"].default_value = 5.0
    L.new(uv.outputs[0], gn.inputs["Vector"])
    gb = nd("ShaderNodeMapRange"); gb.inputs["From Min"].default_value = 0.5; gb.inputs["From Max"].default_value = 0.56
    L.new(gn.outputs["Fac"], gb.inputs["Value"])
    gm = nd("ShaderNodeMath"); gm.operation = 'MULTIPLY'
    L.new(gc.outputs[0], gm.inputs[0]); L.new(gb.outputs[0], gm.inputs[1])
    # a few plates have a gold seam too
    pr = nd("ShaderNodeMath"); pr.operation = 'GREATER_THAN'; pr.inputs[1].default_value = 0.93
    L.new(bw.outputs[0], pr.inputs[0])
    pe = nd("ShaderNodeMath"); pe.operation = 'MULTIPLY'
    L.new(pr.outputs[0], pe.inputs[0]); L.new(ink.outputs[0], pe.inputs[1])
    gall = nd("ShaderNodeMath"); gall.operation = 'MAXIMUM'
    L.new(gm.outputs[0], gall.inputs[0]); L.new(pe.outputs[0], gall.inputs[1])
    mg = nd("ShaderNodeMix"); mg.data_type = 'RGBA'
    L.new(gall.outputs[0], mg.inputs["Factor"]); L.new(col, mg.inputs["A"]); mg.inputs["B"].default_value = (*GOLD, 1)
    L.new(mg.outputs[2], p.inputs["Base Color"])
    L.new(gall.outputs[0], p.inputs["Metallic"])
    p.inputs["Emission Color"].default_value = (*GOLD, 1)
    es = nd("ShaderNodeMath"); es.operation = 'MULTIPLY'; es.inputs[1].default_value = 2.5
    L.new(gall.outputs[0], es.inputs[0]); L.new(es.outputs[0], p.inputs["Emission Strength"])
    p.inputs["Roughness"].default_value = 0.75
    # plate relief
    # each plate a low dome: highlight on its upper-left, shade on its lower-right
    hd = nd("ShaderNodeMapRange"); hd.inputs["From Min"].default_value = 0.0; hd.inputs["From Max"].default_value = 0.55
    hd.inputs["To Min"].default_value = 1.0; hd.inputs["To Max"].default_value = 0.0
    L.new(vo.outputs["Distance"], hd.inputs["Value"])
    hs = nd("ShaderNodeMath"); hs.operation = 'POWER'; hs.inputs[1].default_value = 0.6
    L.new(hd.outputs[0], hs.inputs[0])
    bump = nd("ShaderNodeBump"); bump.inputs["Strength"].default_value = 0.9; bump.inputs["Distance"].default_value = 0.06
    L.new(hs.outputs[0], bump.inputs["Height"]); L.new(bump.outputs[0], p.inputs["Normal"])
    return m


def quartz_material():
    m = bpy.data.materials.new("quartz"); m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (0.75, 0.72, 0.66, 1)
    p.inputs["Roughness"].default_value = 0.25
    p.inputs["Emission Color"].default_value = (0.9, 0.85, 0.75, 1)
    p.inputs["Emission Strength"].default_value = 0.08
    return m


def crystal(x, y, z, h, w, yaw, tilt, mat):
    """hexagonal quartz prism with a pointed tip, leaning outwards"""
    bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=w, depth=h, location=(0, 0, h / 2))
    c = bpy.context.object
    bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=w, radius2=0, depth=w * 2.2, location=(0, 0, h + w * 1.1))
    t = bpy.context.object
    c.select_set(True); t.select_set(True); bpy.context.view_layer.objects.active = c
    bpy.ops.object.join()
    c.rotation_euler = (tilt, 0, yaw)
    c.location = (x, y, z)
    c.data.materials.append(mat)
    for poly in c.data.polygons: poly.use_smooth = False
    return c


def cluster(x, y, yaw0, mat, seed, n=5):
    import random
    rnd = random.Random(seed)
    for i in range(n):
        yaw = yaw0 + rnd.uniform(-0.9, 0.9)
        crystal(x + rnd.uniform(-0.1, 0.1), y + rnd.uniform(-0.1, 0.1), D * 0.8,
                rnd.uniform(0.45, 0.75), rnd.uniform(0.08, 0.115), yaw, rnd.uniform(0.4, 0.8), mat)


def rounded_rect(x0, y0, x1, y1, rc, step):
    """centreline: starts at the bottom edge by the bottom-right corner, runs clockwise on screen (left first)"""
    pts = []

    def line(a, b):
        a, b = Vector(a), Vector(b)
        k = max(1, int((b - a).length / step))
        for i in range(k):
            pts.append(tuple(a + (b - a) * (i / k)))

    def arc(c, a0, a1):
        k = max(2, int(abs(a1 - a0) * rc / step))
        for i in range(k):
            a = a0 + (a1 - a0) * i / k
            pts.append((c[0] + rc * math.cos(a), c[1] + rc * math.sin(a)))
    line((x1 - rc, y0), (x0 + rc, y0))
    arc((x0 + rc, y0 + rc), -math.pi / 2, -math.pi)
    line((x0, y0 + rc), (x0, y1 - rc))
    arc((x0 + rc, y1 - rc), math.pi, math.pi / 2)
    line((x0 + rc, y1), (x1 - rc, y1))
    arc((x1 - rc, y1 - rc), math.pi / 2, 0)
    line((x1, y1 - rc), (x1, y0 + rc))
    arc((x1 - rc, y0 + rc), 0, -math.pi / 2)
    return pts


def tail_path(start, step):
    """after closing the loop the tail runs on over the start of the body, then curls neatly outwards"""
    pts = []
    x, y = start
    run = 0.75
    for i in range(1, int(run / step)):
        pts.append((x - i * step, y))
    x -= run
    r = 0.22
    c = (x, y - r)
    turn = 1.65 * math.pi
    k = int(turn * r / step * 1.2)
    for i in range(1, k):
        t = i / k
        a = math.pi / 2 + t * turn
        rr = r * (1 - 0.5 * t)
        pts.append((c[0] + rr * math.cos(a), c[1] + rr * math.sin(a)))
    return pts


def sway(pts, phase, amp=0.38, still=0.3):
    """swing the tail round its root: still near the body, more and more towards the tip, a wave running down it"""
    lens = [0.0]
    for i in range(1, len(pts)):
        lens.append(lens[-1] + (Vector(pts[i]) - Vector(pts[i - 1])).length)
    total = lens[-1]
    # the root: where the tail leaves the body
    ri = next(i for i, l in enumerate(lens) if l >= still)
    root = Vector(pts[ri])
    out = []
    for i, p in enumerate(pts):
        w = max(0.0, (lens[i] - still) / (total - still))
        w = w * w * (3 - 2 * w)
        a = amp * w * math.sin(phase - lens[i] * 1.8)
        d = Vector(p) - root
        out.append((root.x + d.x * math.cos(a) - d.y * math.sin(a), root.y + d.x * math.sin(a) + d.y * math.cos(a)))
    return out


def render(path, w_cells, h_cells, cx, cy, border=None):
    w = round(w_cells * P); h = round(h_cells * P)
    sc = bpy.context.scene
    sc.render.resolution_x = w; sc.render.resolution_y = h
    sc.camera.data.ortho_scale = max(w_cells, h_cells)
    sc.camera.location = (cx, cy, 10)
    sc.render.use_border = border is not None
    sc.render.use_crop_to_border = False
    if border:
        sc.render.border_min_x, sc.render.border_min_y, sc.render.border_max_x, sc.render.border_max_y = border
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("SERPENT", path, w, h)


def moss_material():
    m = bpy.data.materials.new("moss"); m.use_nodes = True
    n = m.node_tree; L = n.links; nd = n.nodes.new
    p = n.nodes["Principled BSDF"]
    tc = nd("ShaderNodeTexCoord")
    nz = nd("ShaderNodeTexNoise"); nz.inputs["Scale"].default_value = 140.0; nz.inputs["Detail"].default_value = 10
    L.new(tc.outputs["Object"], nz.inputs["Vector"])
    r = nd("ShaderNodeValToRGB")
    r.color_ramp.elements[0].color = (*[c * 0.35 for c in MOSS], 1)
    r.color_ramp.elements[1].color = (*[c * 1.7 for c in MOSS], 1)
    L.new(nz.outputs["Fac"], r.inputs["Fac"])
    L.new(r.outputs[0], p.inputs["Base Color"])
    p.inputs["Roughness"].default_value = 0.95
    return m


def moss_tufts(pts, centre, mat, seed, every=0.2, chance=0.7):
    """shaggy tufts of dry moss sitting on the body, spilling over its outer side"""
    import random
    rnd = random.Random(seed)
    s, nxt = 0.0, 0.3
    tx = bpy.data.textures.new("moss_clouds%d" % seed, 'CLOUDS'); tx.noise_scale = 0.025; tx.noise_depth = 3
    for i in range(1, len(pts) - 1):
        s += (Vector(pts[i]) - Vector(pts[i - 1])).length
        if s < nxt:
            continue
        nxt = s + every * rnd.uniform(0.7, 1.3)
        if rnd.random() > chance:
            continue
        t = (Vector(pts[i + 1]) - Vector(pts[i - 1])).normalized()
        nrm = Vector((-t.y, t.x, 0.0))
        if centre is None:
            nrm = nrm if rnd.random() < 0.5 else -nrm
        elif nrm.dot(Vector((pts[i][0] - centre[0], pts[i][1] - centre[1], 0))) < 0:
            nrm = -nrm                     # towards the outside
        rad = rnd.uniform(0.045, 0.075)
        side = rnd.uniform(-0.1, 0.55) * D / 2
        loc = Vector((pts[i][0], pts[i][1], 0)) + nrm * side + Vector((0, 0, D * 0.78))
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, radius=rad, location=loc)
        o = bpy.context.object
        o.scale = (1.0, 1.0, 0.45)
        o.rotation_euler = (0, 0, math.atan2(nrm.y, nrm.x))
        o.scale = (1.5, 1.1, 0.3)           # a flat patch lying along the body
        o.rotation_euler = (0, 0, math.atan2(t.y, t.x) + rnd.uniform(-0.4, 0.4))
        o.location = loc
        dm = o.modifiers.new("shag", 'DISPLACE'); dm.texture = tx; dm.strength = rad * 0.6; dm.texture_coords = 'GLOBAL'
        o.data.materials.append(mat)
        o["part"] = "body"


def frame_set(name, x0, y0, x1, y1, rc, clusters, cx, cy, w_c, h_c, frames=8):
    """the body (with moss and crystals) in one picture, the tail alone in `frames` pictures of its sway"""
    setup(10, 10, 1, 0, 0)
    step = 0.012
    loop = rounded_rect(x0, y0, x1, y1, rc, step)
    total_loop = sum((Vector(loop[i]) - Vector(loop[i - 1])).length for i in range(1, len(loop)))
    mat = body_material()

    def radius(s):
        r = D / 2
        if s < 0.25:                       # the start, hidden under the tail: rounded off
            r *= 0.55 + 0.45 * math.sqrt(max(0.0, s / 0.25))
        return r
    body = tube("body", loop + [loop[0]], radius, lambda s: 0.0, mat)
    moss_tufts(loop, (cx, cy), moss_material(), 7)
    q = quartz_material()
    for i, (x, y, yaw, n) in enumerate(clusters):
        cluster(x, y, math.radians(yaw), q, 11 + i, n)
    parts = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    base = os.path.join(OUT, name)
    render(base + ".png", w_c, h_c, cx, cy)
    for o in parts:
        o.hide_render = True
    # the tail: its own object, re-built for every frame of the sway
    tpath = [loop[0]] + tail_path(loop[0], step)
    tl = sum((Vector(tpath[i]) - Vector(tpath[i - 1])).length for i in range(1, len(tpath)))

    def t_radius(s):
        t = s / tl
        return D / 2 * max(0.1, 1 - t) ** 0.85

    def t_lift(s):
        return min(1.0, s / 0.25) * D * 0.5
    # render only round the tail
    xs = [p[0] for p in tpath]; ys = [p[1] for p in tpath]
    pad = 0.45
    bx0 = (min(xs) - pad - (cx - w_c / 2)) / w_c; bx1 = (max(xs) + pad - (cx - w_c / 2)) / w_c
    by0 = (min(ys) - pad - (cy - h_c / 2)) / h_c; by1 = (max(ys) + pad - (cy - h_c / 2)) / h_c
    border = (max(0, bx0), max(0, by0), min(1, bx1), min(1, by1))
    for f in range(frames):
        o = tube("tail", sway(tpath, 2 * math.pi * f / frames), t_radius, t_lift, mat, s0=total_loop)
        render(base + "_tail%02d.png" % f, w_c, h_c, cx, cy, border)
        bpy.data.objects.remove(o)
    px = round(w_c * P) / w_c
    meta = {"px_per_cell": px, "size_cells": [w_c, h_c], "tail_frames": frames,
            "inner_top_left": [(x0 + D / 2 + GAP - (cx - w_c / 2)) * px, ((cy + h_c / 2) - (y1 - D / 2 - GAP)) * px]}
    return base, meta


def board_frame():
    c = D / 2 + GAP
    x0, y0, x1, y1 = -c, -c, COLS + c, ROWS + c
    w_c, h_c = COLS + 2 * (c + MARGIN), ROWS + 2 * (c + MARGIN)
    cx, cy = COLS / 2, ROWS / 2
    clusters = [(x0 + 0.04, y1 - 0.04, 135, 6), (x0 + 0.04, y0 + 0.04, 225, 5), (x1 - 0.04, y1 - 0.04, 45, 3)]
    base, meta = frame_set("frame_%dx%d" % (COLS, ROWS), x0, y0, x1, y1, 0.3, clusters, cx, cy, w_c, h_c)
    meta.update({"cells": [COLS, ROWS], "cells_top_left": [(w_c / 2 - cx) * meta["px_per_cell"], (h_c / 2 - ROWS / 2) * meta["px_per_cell"]]})
    with open(base + ".json", "w") as f:
        json.dump(meta, f, indent=1)


def avatar():
    global D
    D = 0.44
    half = 1.2                         # centreline half-size of the square
    c = D / 2 + GAP
    w = 2 * (half + D / 2 + 0.5)
    clusters = [(-half + 0.04, half - 0.04, 135, 5), (half - 0.04, half - 0.04, 45, 3)]
    base, meta = frame_set("avatar", -half, -half, half, half, 0.32, clusters, 0, 0, w, w)
    meta["inner_size_cells"] = 2 * (half - c)
    with open(base + ".json", "w") as f:
        json.dump(meta, f, indent=1)



# ---------------------------------------------------------------- the kit: any board's outline from pieces
# Like the board's stone kit (board_kit.py, BoardKit): straight runs cut to length, corners on top of their ends.
# Coordinates in cells, the grid point the piece belongs to at the origin; Blender's y is up (the screen's down is -y).
# outer_*: a corner of a single board cell (the cell lies towards the piece's opposite side), inner_*: a notch's corner
# (one missing cell there). *_x: the board's extreme corners, with quartz. The tail curls over the bottom-right corner.

KIT_CANVAS = 3.0     # a corner piece's picture, cells, centred on its grid point
KIT_LEN = 10.0       # a straight piece's length, cells

def _rot(p, k):
    x, y = p
    for _ in range(k % 4):
        x, y = -y, x
    return (x, y)

def _poly(points, step):
    """a polyline sampled every `step`"""
    out = []
    for a, b in zip(points, points[1:]):
        a, b = Vector(a), Vector(b)
        n = max(1, int((b - a).length / step))
        for i in range(n):
            out.append(tuple(a + (b - a) * (i / n)))
    out.append(tuple(points[-1]))
    return out

def _arc(cx, cy, r, a0, a1, step):
    n = max(2, int(abs(a1 - a0) * r / step))
    return [(cx + r * math.cos(a0 + (a1 - a0) * i / n), cy + r * math.sin(a0 + (a1 - a0) * i / n)) for i in range(n + 1)]

def outer_path(step, c, rc=0.3, stub=0.6):
    """top-left corner of a cell lying to the bottom-right: along the top leftwards, round, down the left side"""
    return (_poly([(stub, c), (-c + rc, c)], step) + _arc(-c + rc, c - rc, rc, math.pi / 2, math.pi, step)[1:]
            + _poly([(-c, c - rc), (-c, -stub)], step)[1:])

def inner_path(step, c, ri=0.1, stub=0.6):
    """a notch's corner, the missing cell to the top-left: down the notch's right side, round, left along its bottom"""
    return (_poly([(-c, stub), (-c, c + ri)], step) + _arc(-c - ri, c + ri, ri, 0.0, -math.pi / 2, step)[1:]
            + _poly([(-c - ri, c), (-stub, c)], step)[1:])

def kit():
    step = 0.012
    c = D / 2 + GAP
    kd = os.path.join(OUT, "kit")
    os.makedirs(kd, exist_ok=True)
    flat = lambda s: 0.0
    full = lambda s: D / 2
    # straight runs: horizontal (left to right) and vertical (top to bottom), the body's centre line in the middle
    setup(10, 10, 1, 0, 0)
    pts = _poly([(0.0, 0.0), (KIT_LEN, 0.0)], step)
    tube("h", pts, full, flat, body_material())
    moss_tufts(pts, None, moss_material(), 21)
    render(os.path.join(kd, "straight_h.png"), KIT_LEN, 1.0, KIT_LEN / 2, 0.0)
    setup(10, 10, 1, 0, 0)
    pts = _poly([(0.0, 0.0), (0.0, -KIT_LEN)], step)
    tube("v", pts, full, flat, body_material())
    moss_tufts(pts, None, moss_material(), 22)
    render(os.path.join(kd, "straight_v.png"), 1.0, KIT_LEN, 0.0, -KIT_LEN / 2)
    # corners: four turns each, each rendered in the same light
    turns = {"tl": 0, "bl": 1, "br": 2, "tr": 3}
    quartz = {"tl": (135, 6), "bl": (225, 5), "tr": (45, 3)}
    for kind, base in (("outer", outer_path(step, c)), ("inner", inner_path(step, c))):
        for nm, k in turns.items():
            setup(10, 10, 1, 0, 0)
            tube(kind + nm, [_rot(p, k) for p in base], full, flat, body_material())
            render(os.path.join(kd, "%s_%s.png" % (kind, nm)), KIT_CANVAS, KIT_CANVAS, 0.0, 0.0)
            if kind == "outer" and nm in quartz:
                yaw, n = quartz[nm]
                q = _rot((-c + 0.02, c - 0.02), k)
                cluster(q[0], q[1], math.radians(yaw), quartz_material(), 31 + k, n)
                render(os.path.join(kd, "%s_%s_x.png" % (kind, nm)), KIT_CANVAS, KIT_CANVAS, 0.0, 0.0)
    # the tail, over the bottom-right corner: out of the bottom run, leftwards, then curling down, outside the board
    setup(10, 10, 1, 0, 0)
    mat = body_material()
    y = -c
    tpath = _poly([(0.15, y), (-0.7, y)], step)
    r = 0.2
    turn = 1.6 * math.pi
    n = int(turn * r / step * 1.2)
    for i in range(1, n):
        t = i / n
        a = math.pi / 2 + t * turn
        rr = r * (1 - 0.5 * t)
        tpath.append((-0.7 + rr * math.cos(a), y - r + rr * math.sin(a)))
    tl = sum((Vector(tpath[i]) - Vector(tpath[i - 1])).length for i in range(1, len(tpath)))
    t_radius = lambda s: D / 2 * max(0.1, 1 - s / tl) ** 0.85
    t_lift = lambda s: min(1.0, s / 0.25) * D * 0.5
    for f in range(8):
        o = tube("tail", sway(tpath, 2 * math.pi * f / 8), t_radius, t_lift, mat)
        render(os.path.join(kd, "tail_%d.png" % f), KIT_CANVAS, KIT_CANVAS, 0.0, 0.0)
        bpy.data.objects.remove(o)
    with open(os.path.join(kd, "kit.json"), "w") as fh:
        json.dump({"px_per_cell": P, "canvas": KIT_CANVAS, "straight": KIT_LEN, "offset": c, "tail_frames": 8}, fh, indent=1)


# ---------------------------------------------------------------- a whole frame for each of the boss' boards
# The boss' boards are hand-made and few, so each gets its own frame in one piece: one tube round the board's
# outline, the bands running on without a seam. The outline comes from the board's map (game_data.json), '#' = no cell.

def board_outline(rows):
    """the board's outer edge as a loop of grid points, clockwise in Blender coords (y up, cell (r, c) at x c..c+1,
    y -r-1..-r), starting at the bottom-right-most corner and heading left along the bottom"""
    R_, C_ = len(rows), max(len(r) for r in rows)
    full = lambda r, c: 0 <= r < R_ and 0 <= c < C_ and c < len(rows[r]) and rows[r][c] != "#"
    edges = {}
    for r in range(R_):
        for c in range(C_):
            if not full(r, c): continue
            # each edge with the cell on its right when walking it (clockwise round the cells, y up)
            if not full(r - 1, c): edges[(c, -r)] = (c + 1, -r)              # top: left to right
            if not full(r, c + 1): edges[(c + 1, -r)] = (c + 1, -r - 1)       # right: down
            if not full(r + 1, c): edges[(c + 1, -r - 1)] = (c, -r - 1)       # bottom: right to left
            if not full(r, c - 1): edges[(c, -r - 1)] = (c, -r)               # left: up
    start = max(edges, key=lambda p: (p[0] - p[1] * 1.001, -p[1]))           # bottom-right-most
    # begin on the bottom edge that ends... the one leaving that corner leftwards
    loop = [start]
    p = edges[start]
    while p != start:
        loop.append(p)
        p = edges[p]
    # keep only the turning points
    out = []
    n = len(loop)
    for i in range(n):
        a, b, c2 = loop[i - 1], loop[i], loop[(i + 1) % n]
        if (b[0] - a[0], b[1] - a[1]) != (c2[0] - b[0], c2[1] - b[1]):
            out.append(b)
    i0 = out.index(start) if start in out else 0
    return out[i0:] + out[:i0]

def offset_loop(pts, d):
    """a rectilinear loop moved outwards by d (clockwise loop: outside is to the left of the walk)"""
    n = len(pts)
    out = []
    for i in range(n):
        a, b, c2 = Vector(pts[i - 1]), Vector(pts[i]), Vector(pts[(i + 1) % n])
        d1 = (b - a).normalized(); d2 = (c2 - b).normalized()
        n1 = Vector((-d1.y, d1.x)); n2 = Vector((-d2.y, d2.x))
        out.append(tuple(b + (n1 + n2) * d))
    return out

def fillet_path(pts, step, r_out=0.3, r_in=0.12):
    """a closed polyline with its corners rounded, sampled every `step`; starts mid-way along the first edge"""
    n = len(pts)
    res = []
    for i in range(n):
        p, v, q = Vector(pts[i - 1]), Vector(pts[i]), Vector(pts[(i + 1) % n])
        d1 = (v - p); d2 = (q - v)
        convex = d1.x * d2.y - d1.y * d2.x < 0          # a right turn on a clockwise walk
        rr = min(r_out if convex else r_in, d1.length * 0.45, d2.length * 0.45)
        a = v - d1.normalized() * rr
        b = v + d2.normalized() * rr
        k = max(3, int(rr * 2.2 / step))
        for j in range(k + 1):
            t = j / k
            res.append(tuple(a * (1 - t) ** 2 + v * 2 * (1 - t) * t + b * t * t))
        # the straight on to the next corner
        nxt = Vector(pts[(i + 1) % n]); d3 = (Vector(pts[(i + 2) % n]) - nxt)
        conv2 = d2.x * d3.y - d2.y * d3.x < 0
        rr2 = min(r_out if conv2 else r_in, d2.length * 0.45, d3.length * 0.45)
        e = nxt - d2.normalized() * rr2
        res += _poly([tuple(b), tuple(e)], step)[1:-1]
    # start on the first edge (from the bottom-right corner leftwards): rotate to the point after its fillet
    return res

def boss_frames(stages):
    step = 0.012
    c = D / 2 + GAP
    for si, rows in enumerate(stages):
        corners = offset_loop(board_outline(rows), c)
        loop = fillet_path(corners, step)
        # begin just left of the first (bottom-right) corner's rounding, so the tail lies over the very start
        k0 = next(i for i, p in enumerate(loop) if p[0] < corners[0][0] - 0.32)
        loop = loop[k0:] + loop[:k0]
        R_, C_ = len(rows), max(len(r) for r in rows)
        w_c, h_c = C_ + 2 * (c + MARGIN), R_ + 2 * (c + MARGIN)
        cx, cy = C_ / 2, -R_ / 2
        setup(10, 10, 1, 0, 0)
        mat = body_material()
        total = sum((Vector(loop[i]) - Vector(loop[i - 1])).length for i in range(1, len(loop)))
        rad = lambda s: D / 2 * ((0.55 + 0.45 * math.sqrt(s / 0.25)) if s < 0.25 else 1.0)
        tube("body", loop + [loop[0]], rad, lambda s: 0.0, mat)
        moss_tufts(loop, (cx, cy), moss_material(), 7 + si)
        # quartz on the extreme corners: top-left, bottom-left, top-right
        q = quartz_material()
        for i, (score, yaw, n) in enumerate(((lambda p: -p[0] + p[1], 135, 6), (lambda p: -p[0] - p[1], 225, 5),
                                              (lambda p: p[0] + p[1], 45, 3))):
            v = max(corners, key=score)
            cluster(v[0] + (0.04 if yaw != 45 else -0.04), v[1] + (-0.04 if yaw != 225 else 0.04), math.radians(yaw), q, 11 + i + si * 3, n)
        parts = [o for o in bpy.context.scene.objects if o.type == 'MESH']
        base = os.path.join(OUT, "stage%d" % si)
        render(base + ".png", w_c, h_c, cx, cy)
        for o in parts:
            o.hide_render = True
        tpath = [loop[0]] + tail_path(loop[0], step)
        tl = sum((Vector(tpath[i]) - Vector(tpath[i - 1])).length for i in range(1, len(tpath)))
        t_radius = lambda s: D / 2 * max(0.1, 1 - s / tl) ** 0.85
        t_lift = lambda s: min(1.0, s / 0.25) * D * 0.5
        xs = [p[0] for p in tpath]; ys = [p[1] for p in tpath]
        pad = 0.45
        border = (max(0, (min(xs) - pad - (cx - w_c / 2)) / w_c), max(0, (min(ys) - pad - (cy - h_c / 2)) / h_c),
                  min(1, (max(xs) + pad - (cx - w_c / 2)) / w_c), min(1, (max(ys) + pad - (cy - h_c / 2)) / h_c))
        for f in range(8):
            o = tube("tail", sway(tpath, 2 * math.pi * f / 8), t_radius, t_lift, mat, s0=total)
            render(base + "_tail%d.png" % f, w_c, h_c, cx, cy, border)
            bpy.data.objects.remove(o)
        with open(base + ".json", "w") as fh:
            json.dump({"px_per_cell": P, "cells": [C_, R_], "tail_frames": 8,
                       "cells_top_left": [(c + MARGIN) * P, (c + MARGIN) * P]}, fh, indent=1)

os.makedirs(OUT, exist_ok=True)
if WHAT == "boss":
    # the boss' boards from the game's data: argv[4] = the boss' area index
    gd = json.load(open(os.path.join(PROJ, "godot/data/game_data.json"), encoding="utf-8"))
    boss_frames([st["map"].split("|") for st in gd["AREAS"][int(argv[4]) if len(argv) > 4 else 0]["boss"]["stages"]])
if WHAT == "kit":
    kit()
if WHAT in ("board", "all"):
    board_frame()
if WHAT in ("avatar", "all"):
    avatar()
