"""The boss's reward, the hoard of Great Poloz, drawn like the boss's book illustration: flat fills in three steps of
shade (EEVEE, Shader to RGB), thick dark outlines (an inverted hull round every part), big readable shapes in Old
Adit's palette (docs/boss-art.md: brown and grey stone, ochre, white quartz, candle amber, gold the accent).
A hewn boulder with thick veins of gold, the stone serpent coiled round it (ring plates, gold scales, golden eyes,
a beard of heavy tendrils), nine round geodes with a split full of white and amber crystals, quartz druses,
pyrite cubes. Rendered as a turntable, every frame twice: the picture and a mask in which each geode (its rind and
its crystals) is its own flat red (20 x geode number), so the game knows which geode is under a finger and can light
exactly its pixels. The frames then go through art/boss/hoard_px.py onto the 1 pt pixel grid.

blender -b -P hoard_kit.py -- <out dir> [frames=36] [px=450] [only=<frame>]
  out/color/0001.png ..., out/mask/0001.png ...
"""
import bpy, bmesh, sys, math, os
from mathutils import Vector, Matrix
from mathutils.noise import seed_set, random as nrand

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = os.path.abspath(argv[0]) if argv else os.path.abspath("hoard_out")
OPT = dict(a.split("=", 1) for a in argv[1:] if "=" in a)
FRAMES = int(OPT.get("frames", 36))
PX = int(OPT.get("px", 450))
ONLY = int(OPT["only"]) if "only" in OPT else None
N_GEO = 9
LINE = 0.022   # outline thickness, in boulder radii


def hexc(h):
    """an sRGB hex colour as Blender's linear one (the view is Standard, so it comes out as written)"""
    c = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return tuple(v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in c)


# three steps of shade (dark, mid, light) and a highlight for the shiny ones
P = {
    "rock": ("1c130d", "3e2b1c", "6a4b2f"),
    "rock_edge": "8c6844",
    "gold": ("7a4a12", "c98b2a", "f3c35c", "fff1b8"),
    "hide": ("1e150e", "45311f", "765536"),
    "belly": ("2c1f14", "5f4630", "927049"),
    "crust": ("2b231d", "5c4c3e", "917c66"),
    "split": ("0c0806",),
    "quartz": ("6a6e78", "c8c4ba", "f3f0e6", "ffffff"),
    "amber": ("7a320a", "d8741c", "ffbf5c", "fff0c0"),
    "pyrite": ("5c4a22", "a88c48", "e0c878", "fff6d0"),
    "eye": ("ffcf40",),
    "line": ("0b0705",),
}


def setup():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_EEVEE'
    sc.eevee.taa_render_samples = 16
    sc.render.resolution_x = PX
    sc.render.resolution_y = PX
    sc.render.film_transparent = True
    sc.render.filter_size = 0.8
    sc.view_settings.view_transform = 'Standard'
    sc.view_settings.look = 'None'
    wd = bpy.data.worlds.new("w"); sc.world = wd
    wd.use_nodes = True
    # a little light all round, so a side turned from the key is the middle step, and only cast shadow the dark one
    wd.node_tree.nodes["Background"].inputs[0].default_value = (1.0, 0.92, 0.82, 1)
    wd.node_tree.nodes["Background"].inputs[1].default_value = 0.2
    # one key light from the top left, as on the gems and the boss: the steps of shade follow it
    d = bpy.data.lights.new("key", 'SUN'); d.energy = 6.5; d.angle = math.radians(2)
    d.use_shadow = False   # the contour shells would shade what they wrap; the steps come from the angle to the light
    s = bpy.data.objects.new("key", d)
    s.rotation_euler = (-Vector((-0.55, -0.7, 0.9))).to_track_quat('-Z', 'Y').to_euler()
    sc.collection.objects.link(s)
    cd = bpy.data.cameras.new("cam"); cd.lens = 98
    cam = bpy.data.objects.new("cam", cd)
    cam.location = Vector((0, -8.6, 2.9))
    cam.rotation_euler = (Vector((0, 0, 0.1)) - cam.location).to_track_quat('-Z', 'Y').to_euler()
    sc.collection.objects.link(cam); sc.camera = cam
    return sc


def toon(name, key, steps=(0.18, 0.55), spec=0.0, emit=0.0, mask=None):
    """flat fills: the light on the surface (diffuse, as RGB) cut into dark / mid / light; a hard highlight
    where a glossy reflection is bright (spec > 0); mask: a (value socket maker) choosing gold instead"""
    m = bpy.data.materials.new(name); m.use_nodes = True
    n = m.node_tree; L = n.links; nd = n.nodes.new
    for x in list(n.nodes): n.nodes.remove(x)
    out = nd("ShaderNodeOutputMaterial")
    dif = nd("ShaderNodeBsdfDiffuse")
    s2r = nd("ShaderNodeShaderToRGB"); L.new(dif.outputs[0], s2r.inputs[0])
    bw = nd("ShaderNodeRGBToBW"); L.new(s2r.outputs[0], bw.inputs[0])
    def steps_of(cols):
        r = nd("ShaderNodeValToRGB"); cr = r.color_ramp; cr.interpolation = 'CONSTANT'
        cr.elements[0].position = 0.0; cr.elements[0].color = (*hexc(cols[0]), 1)
        cr.elements[1].position = steps[1]; cr.elements[1].color = (*hexc(cols[2]), 1)
        e = cr.elements.new(steps[0]); e.color = (*hexc(cols[1]), 1)
        L.new(bw.outputs[0], r.inputs["Fac"])
        return r.outputs[0]
    cols = P[key]
    col = steps_of(cols) if len(cols) >= 3 else None
    if col is None:
        rgb = nd("ShaderNodeRGB"); rgb.outputs[0].default_value = (*hexc(cols[0]), 1); col = rgb.outputs[0]
    def highlight(col, hi, k):
        g = nd("ShaderNodeBsdfGlossy"); g.inputs["Roughness"].default_value = 0.3
        s2 = nd("ShaderNodeShaderToRGB"); L.new(g.outputs[0], s2.inputs[0])
        b2 = nd("ShaderNodeRGBToBW"); L.new(s2.outputs[0], b2.inputs[0])
        th = nd("ShaderNodeMath"); th.operation = 'GREATER_THAN'; th.inputs[1].default_value = k
        L.new(b2.outputs[0], th.inputs[0])
        mx = nd("ShaderNodeMix"); mx.data_type = 'RGBA'
        L.new(th.outputs[0], mx.inputs["Factor"]); L.new(col, mx.inputs["A"]); mx.inputs["B"].default_value = (*hexc(hi), 1)
        return mx.outputs[2]
    if spec and len(cols) > 3:
        col = highlight(col, cols[3], spec)
    if mask is not None:
        # gold where the mask says: its own steps and highlight
        gold = steps_of(P["gold"])
        gold = highlight(gold, P["gold"][3], 0.6)
        mx = nd("ShaderNodeMix"); mx.data_type = 'RGBA'
        L.new(mask(n), mx.inputs["Factor"]); L.new(col, mx.inputs["A"]); L.new(gold, mx.inputs["B"])
        col = mx.outputs[2]
    em = nd("ShaderNodeEmission"); em.inputs["Strength"].default_value = 1.0 + emit
    L.new(col, em.inputs["Color"])
    L.new(em.outputs[0], out.inputs[0])
    return m


def flat(name, key, k=0):
    m = bpy.data.materials.new(name); m.use_nodes = True
    n = m.node_tree
    for x in list(n.nodes): n.nodes.remove(x)
    e = n.nodes.new("ShaderNodeEmission"); o = n.nodes.new("ShaderNodeOutputMaterial")
    e.inputs["Color"].default_value = (*hexc(P[key][0]), 1)
    n.links.new(e.outputs[0], o.inputs[0])
    return m


def mask_mat(k):
    """flat, unlit: red = 20 x k (k = 0 for everything that is not a geode), exact after the Standard view"""
    m = bpy.data.materials.new("mask%d" % k); m.use_nodes = True
    n = m.node_tree
    for x in list(n.nodes): n.nodes.remove(x)
    e = n.nodes.new("ShaderNodeEmission"); o = n.nodes.new("ShaderNodeOutputMaterial")
    v = (k * 20) / 255.0
    e.inputs["Color"].default_value = (v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4, 0, 0, 1)
    n.links.new(e.outputs[0], o.inputs[0])
    return m


LINE_MAT = None


def outline(o, thick=1.0):
    """the dark contour: a shell pushed out along the normals, inside out, showing only its back"""
    global LINE_MAT
    if LINE_MAT is None:
        LINE_MAT = flat("line", "line"); LINE_MAT.use_backface_culling = True
    o.data.materials.append(LINE_MAT)
    s = o.modifiers.new("line", 'SOLIDIFY')
    s.thickness = -LINE * thick; s.offset = 1.0; s.use_flip_normals = True
    s.material_offset = len(o.data.materials) - 1
    s.use_rim = False


def put(o, mat, parent, line=1.0):
    o.data.materials.clear()
    o.data.materials.append(mat)
    o.parent = parent
    if line: outline(o, line)
    return o


def to_mesh(o):
    bpy.ops.object.select_all(action='DESELECT')
    o.select_set(True); bpy.context.view_layer.objects.active = o
    bpy.ops.object.convert(target='MESH')
    return bpy.context.object


def crystal(h, r, at, axis, mat, parent, name):
    """a six-sided prism with a pointed tip, standing at `at` along `axis`"""
    bm = bmesh.new()
    bot, top = [], []
    for q in range(6):
        a = q / 6 * math.tau
        bot.append(bm.verts.new((math.cos(a) * r, math.sin(a) * r, 0)))
        top.append(bm.verts.new((math.cos(a) * r, math.sin(a) * r, h)))
    tip = bm.verts.new((0, 0, h + r * 1.8))
    for q in range(6):
        bm.faces.new((bot[q], bot[(q + 1) % 6], top[(q + 1) % 6], top[q]))
        bm.faces.new((top[q], top[(q + 1) % 6], tip))
    bm.faces.new(list(reversed(bot)))
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(o)
    o.matrix_world = Matrix.Translation(at) @ axis.to_track_quat('Z', 'Y').to_matrix().to_4x4()
    return put(o, mat, parent, 0.7)


def build(sc):
    seed_set(7)
    turn = bpy.data.objects.new("turn", None); sc.collection.objects.link(turn)
    # the boulder: hewn into big facets, a flat foot to sit on, gold in thick veins
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, radius=1.0)
    rock = bpy.context.object; rock.name = "rock"
    t1 = bpy.data.textures.new("lumps", 'VORONOI'); t1.noise_scale = 0.6
    d1 = rock.modifiers.new("d1", 'DISPLACE'); d1.texture = t1; d1.strength = 0.25; d1.mid_level = 0.6
    bpy.ops.object.modifier_apply(modifier="d1")
    for v in rock.data.vertices:
        v.co.z = max(v.co.z, -0.78)
        v.co.x *= 1.12; v.co.z *= 0.95
    bpy.ops.object.shade_flat()
    def veins(n):
        tc = n.nodes.new("ShaderNodeTexCoord")
        w = n.nodes.new("ShaderNodeTexNoise"); w.inputs["Scale"].default_value = 2.2; w.inputs["Detail"].default_value = 2
        w.inputs["Roughness"].default_value = 0.4
        n.links.new(tc.outputs["Object"], w.inputs["Vector"])
        sub = n.nodes.new("ShaderNodeMath"); sub.operation = 'SUBTRACT'; sub.inputs[1].default_value = 0.5
        n.links.new(w.outputs["Fac"], sub.inputs[0])
        ab = n.nodes.new("ShaderNodeMath"); ab.operation = 'ABSOLUTE'; n.links.new(sub.outputs[0], ab.inputs[0])
        lt = n.nodes.new("ShaderNodeMath"); lt.operation = 'LESS_THAN'; lt.inputs[1].default_value = 0.013
        n.links.new(ab.outputs[0], lt.inputs[0])
        return lt.outputs[0]
    put(rock, toon("rock", "rock", (0.2, 0.6), mask=veins), turn, 1.0)
    bvh = rock

    def surface(d, lift=0.0):
        ok, loc, nrm, _ = bvh.ray_cast(d * 3.0, -d)
        if ok and nrm.dot(d) < 0: nrm = -nrm   # the face may be wound inwards: always out of the rock
        return (loc + nrm * lift, nrm) if ok else (d, d)

    # the serpent: a thick coil hugging the rock, its neck rising off the top and arching to the camera
    coil = []
    turns = 1.1
    a_end = math.radians(-55)
    for k in range(60):
        t = k / 59
        a = a_end - (1.0 - t) * math.tau * turns
        z = -0.58 + t * 1.2
        p, _ = surface(Vector((math.cos(a), math.sin(a), z * 0.9)).normalized(), 0.13)
        coil.append((p, t))
    tip, _ = coil[-1]
    up = tip.normalized()
    look = Vector((0.15, -1.0, -0.3)).normalized()
    for k, (u, f) in enumerate(((0.18, 0.0), (0.36, 0.1), (0.46, 0.25), (0.48, 0.4))):
        coil.append((tip + up * u + look * f, 1.0))
    cu = bpy.data.curves.new("serpent", 'CURVE'); cu.dimensions = '3D'
    cu.bevel_depth = 0.21; cu.bevel_resolution = 3
    sp = cu.splines.new('POLY'); sp.points.add(len(coil) - 1)
    for i, (p, t) in enumerate(coil):
        sp.points[i].co = (*p, 1)
        sp.points[i].radius = 0.3 + 0.7 * min(1.0, t / 0.75) ** 0.6
    sp.use_smooth = True
    snake = bpy.data.objects.new("serpent", cu); sc.collection.objects.link(snake)
    snake = to_mesh(snake)
    # ring plates across the body, every few a band of gold scales
    def plates(n):
        tc = n.nodes.new("ShaderNodeTexCoord")
        vo = n.nodes.new("ShaderNodeTexVoronoi"); vo.inputs["Scale"].default_value = 11.0
        n.links.new(tc.outputs["Object"], vo.inputs["Vector"])
        bwv = n.nodes.new("ShaderNodeRGBToBW"); n.links.new(vo.outputs["Color"], bwv.inputs[0])
        gt = n.nodes.new("ShaderNodeMath"); gt.operation = 'GREATER_THAN'; gt.inputs[1].default_value = 0.8
        n.links.new(bwv.outputs[0], gt.inputs[0])
        return gt.outputs[0]
    hide = toon("hide", "hide", (0.2, 0.58), mask=plates)
    put(snake, hide, turn, 1.0)
    # seams between the plates: dark rings round the body
    for k in range(6, len(coil) - 4, 3):
        p, t = coil[k]
        q, _ = coil[k + 1]
        ax = (q - p).normalized()
        r = 0.21 * (0.3 + 0.7 * min(1.0, t / 0.75) ** 0.6)
        bpy.ops.mesh.primitive_torus_add(major_radius=r * 1.01, minor_radius=r * 0.07, major_segments=24, minor_segments=4)
        ring = bpy.context.object
        ring.matrix_world = Matrix.Translation(p) @ ax.to_track_quat('Z', 'Y').to_matrix().to_4x4()
        put(ring, flat("seam%d" % k, "line"), turn, 0)
    # the head: lofted from sections, a broad skull, heavy brows, the snout, the jaw a little open
    neck, _ = coil[-1]
    fwd = look
    side = fwd.cross(Vector((0, 0, 1))).normalized()
    up2 = side.cross(fwd).normalized()
    def loft(name, at, length, prof, mat, tilt=0.0):
        bm = bmesh.new()
        rot = Matrix.Rotation(tilt, 3, side)
        f2 = rot @ fwd; u2 = rot @ up2
        rings = []
        n = 12
        for j, (w, h, dz) in enumerate(prof):
            c = at + f2 * (j / (len(prof) - 1) * length) + u2 * dz
            ring = []
            for q in range(n):
                a = q / n * math.tau
                y = math.sin(a) * (0.75 if math.sin(a) > 0 else 1.0)
                ring.append(bm.verts.new(c + side * math.cos(a) * w + u2 * y * h))
            rings.append(ring)
        for j in range(len(rings) - 1):
            for q in range(n):
                bm.faces.new((rings[j][q], rings[j][(q + 1) % n], rings[j + 1][(q + 1) % n], rings[j + 1][q]))
        bm.faces.new(list(reversed(rings[0]))); bm.faces.new(rings[-1])
        me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
        o = bpy.data.objects.new(name, me); sc.collection.objects.link(o)
        for poly in me.polygons: poly.use_smooth = True
        sd = o.modifiers.new("s", 'SUBSURF'); sd.levels = 1; sd.render_levels = 1
        return put(o, mat, turn, 1.0)
    K = 1.35   # the head a size up, to read on the pixel grid
    loft("skull", neck - fwd * 0.1, 0.62 * K, [(w * K, h * K, z * K) for w, h, z in
         [(0.15, 0.13, 0.0), (0.2, 0.15, 0.02), (0.19, 0.13, 0.02), (0.15, 0.1, 0.0), (0.11, 0.075, -0.01), (0.085, 0.06, -0.02), (0.05, 0.04, -0.03)]], hide)
    belly = toon("belly", "belly", (0.2, 0.58))
    loft("jaw", neck - fwd * 0.03 - up2 * 0.1 * K, 0.5 * K, [(w * K, h * K, 0) for w, h in
         [(0.13, 0.06), (0.12, 0.05), (0.09, 0.04), (0.065, 0.03), (0.035, 0.02)]], belly, tilt=-0.25)
    eye = flat("eye", "eye")
    for s_ in (-1, 1):
        e = neck + fwd * 0.18 * K + up2 * 0.08 * K + side * s_ * 0.2 * K
        bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=0.06 * K, location=e)
        put(bpy.context.object, eye, turn, 1.2)
        bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=6, radius=1)
        br = bpy.context.object
        br.matrix_world = Matrix.Translation(e + up2 * 0.06 * K) @ Matrix((side, fwd, up2)).transposed().to_4x4() @ Matrix.Diagonal((0.09 * K, 0.13 * K, 0.04 * K, 1))
        put(br, belly, turn, 1.0)
    # the beard: three heavy tendrils hanging from the jaw
    beard = toon("beard", "belly", (0.25, 0.6))
    for k in range(3):
        bc = bpy.data.curves.new("tendril%d" % k, 'CURVE'); bc.dimensions = '3D'; bc.bevel_depth = 0.04
        bs = bc.splines.new('NURBS'); bs.points.add(4); bs.use_endpoint_u = True
        root = neck + fwd * (0.32 - k * 0.06) * K - up2 * 0.16 * K + side * (k - 1) * 0.1
        for j in range(5):
            q = root - Vector((0, 0, 1)) * (j * 0.11) - fwd * (j * 0.03) + side * (math.sin(j * 1.5 + k * 2) * 0.05)
            bs.points[j].co = (*q, 1); bs.points[j].radius = 1.0 - j * 0.17
        bo = bpy.data.objects.new("tendril%d" % k, bc); sc.collection.objects.link(bo)
        put(to_mesh(bo), beard, turn, 0.8)
    # nine geodes where the coil is not: round rinds split open, white and amber crystals in the split
    cands = []
    n = 160
    for i in range(n):
        z = 1.0 - (i + 0.5) / n * 2.0
        r = math.sqrt(1 - z * z); a = i * 2.399963
        if z < -0.5: continue
        cands.append(Vector((r * math.cos(a), r * math.sin(a), z)))
    def clear(d, lim):
        p, _ = surface(d)
        return all((p - q).length > lim for q, _ in coil)
    spots = []
    for lim in (0.5, 0.4, 0.3):
        for d in cands:
            if len(spots) >= N_GEO: break
            if clear(d, lim) and all((d - q).length > 0.66 for q in spots):
                spots.append(d)
    crust = toon("crust", "crust", (0.2, 0.6))
    split = flat("split", "split")
    quartz = toon("quartz", "quartz", (0.25, 0.6), spec=0.55)
    amber = toon("amber", "amber", (0.25, 0.6), spec=0.55, emit=0.15)
    for i, d in enumerate(spots):
        p, nrm = surface(d)
        g = "geode%d" % (i + 1)
        rot = nrm.to_track_quat('Z', 'Y').to_matrix().to_4x4() @ Matrix.Rotation(i * 0.7, 4, 'Z')
        at = p + nrm * 0.04
        # the rind: a round, knobbly nodule
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.28)
        o = bpy.context.object; o.name = "%s_rind" % g
        tv = bpy.data.textures.new("gv%d" % i, 'VORONOI'); tv.noise_scale = 0.2
        dv = o.modifiers.new("v", 'DISPLACE'); dv.texture = tv; dv.strength = 0.06; dv.mid_level = 0.6
        bpy.ops.object.modifier_apply(modifier="v")
        o.matrix_world = Matrix.Translation(at) @ rot @ Matrix.Diagonal((1.0, 1.0, 0.9, 1))
        bpy.ops.object.shade_flat()
        put(o, crust, turn, 1.0)
        # the split across its outer side: a dark gap, crystals pushing out of it
        bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=1)
        gap = bpy.context.object; gap.name = "%s_gap" % g
        gap.matrix_world = Matrix.Translation(at) @ rot @ Matrix.Translation((0, 0, 0.235)) @ Matrix.Diagonal((0.085, 0.22, 0.05, 1))
        put(gap, split, turn, 0)
        mat = amber if i % 3 == 0 else quartz
        for j in range(6):
            y = (j - 2.5) * 0.06
            tilt = Matrix.Rotation((nrand() - 0.5) * 0.8, 3, 'X') @ Matrix.Rotation((nrand() - 0.5) * 0.6 + (j - 2.5) * 0.12, 3, 'X')
            axis = (rot.to_3x3() @ (tilt @ Vector((0, 0, 1)))).normalized()
            base = (Matrix.Translation(at) @ rot) @ Vector(((nrand() - 0.5) * 0.04, y, 0.22))
            crystal(0.08 + nrand() * 0.14, 0.05, base, axis, mat, turn, "%s_c%d" % (g, j))
    # druses of quartz and pyrite cubes between them
    pyrite = toon("pyrite", "pyrite", (0.25, 0.6), spec=0.5)
    extra = [d for d in cands if clear(d, 0.3) and all((d - q).length > 0.5 for q in spots)]
    for k, d in enumerate(extra[:10]):
        p, nrm = surface(d)
        if k % 2 == 0:
            for j in range(6):
                off = nrm.cross(Vector((0, 0, 1))).normalized() * (nrand() - 0.5) * 0.25 + Vector((0, 0, (nrand() - 0.5) * 0.15))
                ax = (nrm + Vector(((nrand() - 0.5), (nrand() - 0.5), (nrand() - 0.5))) * 0.8).normalized()
                crystal(0.15 + nrand() * 0.25, 0.055, p + off - nrm * 0.02, ax, quartz, turn, "druse%d_%d" % (k, j))
        else:
            bpy.ops.mesh.primitive_cube_add(size=0.13)
            c = bpy.context.object
            c.matrix_world = Matrix.Translation(p) @ nrm.to_track_quat('Z', 'Y').to_matrix().to_4x4() @ Matrix.Rotation(nrand() * 6, 4, 'Z') @ Matrix.Rotation(0.5, 4, 'X')
            put(c, pyrite, turn, 0.8)
    turn.rotation_euler = (0, 0, 0); turn.keyframe_insert("rotation_euler", frame=1)
    turn.rotation_euler = (0, 0, math.tau); turn.keyframe_insert("rotation_euler", frame=FRAMES + 1)
    return turn


def linear_turn(turn):
    """Blender 5 keeps fcurves in action layers: make every key linear wherever they live"""
    act = turn.animation_data.action
    curves = []
    if hasattr(act, "fcurves"):
        curves = list(act.fcurves)
    else:
        for layer in act.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    curves += list(bag.fcurves)
    for fc in curves:
        for kp in fc.keyframe_points: kp.interpolation = 'LINEAR'


def render_all(sc, sub):
    os.makedirs(os.path.join(OUT, sub), exist_ok=True)
    for f in ([ONLY] if ONLY else range(1, FRAMES + 1)):
        sc.frame_set(f)
        sc.render.filepath = os.path.join(OUT, sub, "%04d.png" % f)
        bpy.ops.render.render(write_still=True)


sc = setup()
turn = build(sc)
linear_turn(turn)
render_all(sc, "color")
# the mask: every part of a geode flat red by its number, the rest flat black, no smoothing across pixels
sc.eevee.taa_render_samples = 1
sc.render.filter_size = 0.0
black = mask_mat(0)
for o in sc.objects:
    if o.type != 'MESH': continue
    k = int(o.name[5:].split("_")[0]) if o.name.startswith("geode") else 0
    m = mask_mat(k) if k else black
    for i in range(len(o.data.materials)):
        o.data.materials[i] = m
render_all(sc, "mask")
print("hoard: %d frames to %s" % (1 if ONLY else FRAMES, OUT))
