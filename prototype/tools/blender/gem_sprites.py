# Renders the board's pieces as game sprites: one clean, symmetric cut per colour, seen straight down,
# transparent background, no shadow (set SPRITE_SHADOW=1 for the old soft contact shadow). A hidden bright plate under each stone
# lights it from behind, so the colour glows through the facets the way cut stones do.
#   blender -b -P gem_sprites.py -- <out_dir> [px] [samples]
import bpy, bmesh, sys, math, os
from mathutils import Vector
argv = sys.argv[sys.argv.index("--") + 1:]
OUT = argv[0]
PX = int(argv[1]) if len(argv) > 1 else 256
SAMPLES = int(argv[2]) if len(argv) > 2 else 256
PROJ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))

# name, colour (linear), cut. Order = the board's colour index.
GEMS = [
    ("ruby",     (0.75, 0.02, 0.08), "asscher"),
    ("sapphire", (0.04, 0.22, 0.95), "round"),
    ("emerald",  (0.02, 0.55, 0.18), "emerald"),
    ("citrine",  (1.0, 0.62, 0.02),  "kite"),
    ("amethyst", (0.42, 0.08, 0.9),  "trillion"),
    ("diamond",  (0.9, 0.93, 0.97),  "hexagon"),
]

def ring(n, r, z, rot=0.0, sx=1.0, sy=1.0):
    return [Vector((math.cos(rot + k / n * math.tau) * r * sx, math.sin(rot + k / n * math.tau) * r * sy, z)) for k in range(n)]

def cut_points(cut):
    """symmetric point clouds; the convex hull of each is the stone"""
    g, t = 0.06, 0.34         # girdle height, table height
    if cut == "round":
        return ring(16, 0.4, 0) + ring(16, 0.4, g) + ring(8, 0.32, (g + t) * 0.55, math.pi / 8) + ring(8, 0.19, t)
    if cut == "asscher":
        o = ring(8, 0.43, 0, math.pi / 8, 0.98, 0.98)
        return o + [p + Vector((0, 0, g)) for p in o] + ring(8, 0.34, (g + t) * 0.62, math.pi / 8) + ring(8, 0.24, t, math.pi / 8)
    if cut == "emerald":
        def rect(w, h, c, z): return [Vector(p) for p in [(-w + c, h, z), (w - c, h, z), (w, h - c, z), (w, -h + c, z), (w - c, -h, z), (-w + c, -h, z), (-w, -h + c, z), (-w, h - c, z)]]
        return rect(0.33, 0.42, 0.1, 0) + rect(0.33, 0.42, 0.1, g) + rect(0.27, 0.36, 0.08, (g + t) * 0.6) + rect(0.2, 0.28, 0.06, t)
    if cut == "kite":
        o = [Vector(p) for p in [(0, 0.46, 0), (0.33, 0, 0), (0, -0.46, 0), (-0.33, 0, 0)]]
        return o + [p + Vector((0, 0, g)) for p in o] + [Vector((0, 0, t + 0.06))] + [p * 0.45 + Vector((0, 0, t - 0.04)) for p in o]
    if cut == "trillion":
        o = ring(3, 0.48, 0, math.pi / 2)
        o2 = ring(3, 0.48, 0, math.pi / 2)
        return o + [p + Vector((0, 0, g)) for p in o2] + ring(3, 0.24, t, math.pi / 2) + ring(3, 0.36, (g + t) * 0.6, -math.pi / 2, 0.75, 0.75)
    # hexagon
    return ring(6, 0.43, 0, math.pi / 6) + ring(6, 0.43, g, math.pi / 6) + ring(6, 0.34, (g + t) * 0.6, 0) + ring(6, 0.25, t, math.pi / 6)

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
    sc.cycles.max_bounces = 16
    sc.cycles.transmission_bounces = 16
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
    w.node_tree.nodes["Background"].inputs[1].default_value = 0.35
    # soft daylight from the upper left, as through a window
    d = bpy.data.lights.new("sun", 'SUN'); d.energy = 3.0; d.angle = math.radians(8); d.color = (1.0, 0.96, 0.9)
    s = bpy.data.objects.new("sun", d)
    s.rotation_euler = Vector((0.55, -0.6, -1.0)).to_track_quat('-Z', 'Y').to_euler()   # shadows fall down and right
    sc.collection.objects.link(s)
    # the floor: only the stone's shadow is kept (off by default: the board reads cleaner without)
    if os.environ.get("SPRITE_SHADOW") == "1":
        bpy.ops.mesh.primitive_plane_add(size=4, location=(0, 0, 0))
        fl = bpy.context.object; fl.is_shadow_catcher = True
    # a hidden bright plate just under the stone: light coming up through it
    bpy.ops.mesh.primitive_plane_add(size=1.3, location=(0, 0, 0.002))
    bp = bpy.context.object; bp.visible_camera = False; bp.visible_shadow = False
    bp.visible_diffuse = False; bp.visible_glossy = False
    em = bpy.data.materials.new("glow"); em.use_nodes = True
    nt = em.node_tree; nt.nodes.remove(nt.nodes["Principled BSDF"])
    e = nt.nodes.new("ShaderNodeEmission"); e.inputs[1].default_value = 1.6
    nt.links.new(e.outputs[0], nt.nodes["Material Output"].inputs[0])
    bp.data.materials.append(em)
    cd = bpy.data.cameras.new("cam"); cd.type = 'ORTHO'; cd.ortho_scale = 1.15
    cam = bpy.data.objects.new("cam", cd); cam.location = (0, 0, 10)
    sc.collection.objects.link(cam); sc.camera = cam
    return sc

def stone(name, col, cut):
    me = bpy.data.meshes.new(name); bm = bmesh.new()
    for p in cut_points(cut): bm.verts.new(p)
    bmesh.ops.convex_hull(bm, input=bm.verts)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.001)
    bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(o)
    o.location.z = 0.004
    b = o.modifiers.new("b", 'BEVEL'); b.width = 0.006; b.segments = 2; b.limit_method = 'ANGLE'
    # a game gem: opaque, glowing from the middle, deep colour towards the edges, crisp reflections
    # of the studio on every facet (no see-through, so the sprite stays solid and saturated)
    m = bpy.data.materials.new(name); m.use_nodes = True
    n = m.node_tree; L = n.links
    p = n.nodes["Principled BSDF"]
    lw = n.nodes.new("ShaderNodeLayerWeight"); lw.inputs["Blend"].default_value = 0.45
    ramp = n.nodes.new("ShaderNodeValToRGB")
    lite = tuple(min(1.0, c * 1.1 + 0.06) for c in col)
    deep = tuple(c * 0.3 for c in col)
    ramp.color_ramp.elements[0].color = (*lite, 1)
    ramp.color_ramp.elements[1].color = (*deep, 1)
    ramp.color_ramp.elements[1].position = 0.85
    L.new(lw.outputs["Facing"], ramp.inputs["Fac"])
    # the pavilion seen through the table: alternating light and dark wedges radiating from the centre,
    # and rings stepping outwards, like the inside of a real cut stone
    tc = n.nodes.new("ShaderNodeTexCoord")
    sep = n.nodes.new("ShaderNodeSeparateXYZ"); L.new(tc.outputs["Object"], sep.inputs[0])
    ang = n.nodes.new("ShaderNodeMath"); ang.operation = 'ARCTAN2'
    L.new(sep.outputs["Y"], ang.inputs[0]); L.new(sep.outputs["X"], ang.inputs[1])
    sect = n.nodes.new("ShaderNodeMath"); sect.operation = 'MULTIPLY'
    sect.inputs[1].default_value = {"round": 16, "asscher": 8, "emerald": 4, "kite": 4, "trillion": 6, "hexagon": 12}[cut] / math.tau
    L.new(ang.outputs[0], sect.inputs[0])
    # hard wedges: which sector we are in, odd or even
    fl = n.nodes.new("ShaderNodeMath"); fl.operation = 'FLOOR'; L.new(sect.outputs[0], fl.inputs[0])
    fr = n.nodes.new("ShaderNodeMath"); fr.operation = 'FLOORED_MODULO'; fr.inputs[1].default_value = 2.0
    L.new(fl.outputs[0], fr.inputs[0])
    rad = n.nodes.new("ShaderNodeVectorMath"); rad.operation = 'LENGTH'
    xy = n.nodes.new("ShaderNodeCombineXYZ"); L.new(sep.outputs["X"], xy.inputs["X"]); L.new(sep.outputs["Y"], xy.inputs["Y"])
    L.new(xy.outputs[0], rad.inputs[0])
    # steps that follow the stone's own outline: the distance to the centre measured in its shape
    shape_d = rad.outputs["Value"]
    if cut == "emerald" or cut == "kite":
        ax = n.nodes.new("ShaderNodeMath"); ax.operation = 'ABSOLUTE'; L.new(sep.outputs["X"], ax.inputs[0])
        ay = n.nodes.new("ShaderNodeMath"); ay.operation = 'ABSOLUTE'; L.new(sep.outputs["Y"], ay.inputs[0])
        sx = n.nodes.new("ShaderNodeMath"); sx.operation = 'DIVIDE'; sx.inputs[1].default_value = 0.33; L.new(ax.outputs[0], sx.inputs[0])
        sy = n.nodes.new("ShaderNodeMath"); sy.operation = 'DIVIDE'; sy.inputs[1].default_value = 0.42 if cut == "emerald" else 0.46; L.new(ay.outputs[0], sy.inputs[0])
        mm = n.nodes.new("ShaderNodeMath"); mm.operation = 'MAXIMUM' if cut == "emerald" else 'ADD'
        L.new(sx.outputs[0], mm.inputs[0]); L.new(sy.outputs[0], mm.inputs[1])
        sc4 = n.nodes.new("ShaderNodeMath"); sc4.operation = 'MULTIPLY'; sc4.inputs[1].default_value = 0.4
        L.new(mm.outputs[0], sc4.inputs[0]); shape_d = sc4.outputs[0]
    elif cut in ("trillion", "hexagon", "asscher"):
        N = {"trillion": 3, "hexagon": 6, "asscher": 8}[cut]
        rot = {"trillion": math.pi / 2, "hexagon": math.pi / 6, "asscher": math.pi / 8}[cut]
        a2 = n.nodes.new("ShaderNodeMath"); a2.operation = 'SUBTRACT'; a2.inputs[1].default_value = rot
        L.new(ang.outputs[0], a2.inputs[0])
        md = n.nodes.new("ShaderNodeMath"); md.operation = 'FLOORED_MODULO'; md.inputs[1].default_value = math.tau / N
        L.new(a2.outputs[0], md.inputs[0])
        cen = n.nodes.new("ShaderNodeMath"); cen.operation = 'SUBTRACT'; cen.inputs[1].default_value = math.pi / N
        L.new(md.outputs[0], cen.inputs[0])
        co = n.nodes.new("ShaderNodeMath"); co.operation = 'COSINE'; L.new(cen.outputs[0], co.inputs[0])
        pd = n.nodes.new("ShaderNodeMath"); pd.operation = 'MULTIPLY'
        L.new(rad.outputs["Value"], pd.inputs[0]); L.new(co.outputs[0], pd.inputs[1])
        shape_d = pd.outputs[0]
    rings = n.nodes.new("ShaderNodeMath"); rings.operation = 'MULTIPLY'; rings.inputs[1].default_value = 7.0
    L.new(shape_d, rings.inputs[0])
    fl2 = n.nodes.new("ShaderNodeMath"); fl2.operation = 'FLOOR'; L.new(rings.outputs[0], fl2.inputs[0])
    rp0 = n.nodes.new("ShaderNodeMath"); rp0.operation = 'FLOORED_MODULO'; rp0.inputs[1].default_value = 2.0
    L.new(fl2.outputs[0], rp0.inputs[0])
    rp = n.nodes.new("ShaderNodeMath"); rp.operation = 'MULTIPLY'; rp.inputs[1].default_value = 0.25 if cut in ("emerald", "kite") else 0.6
    L.new(rp0.outputs[0], rp.inputs[0])
    pat = n.nodes.new("ShaderNodeMath"); pat.operation = 'ADD'
    L.new(fr.outputs[0], pat.inputs[0]); L.new(rp.outputs[0], pat.inputs[1])
    pr = n.nodes.new("ShaderNodeMapRange"); pr.inputs["From Min"].default_value = 0.0; pr.inputs["From Max"].default_value = 1.0
    pr.inputs["From Max"].default_value = 1.6
    pr.inputs["To Min"].default_value = 0.55; pr.inputs["To Max"].default_value = 1.2
    L.new(pat.outputs[0], pr.inputs["Value"])
    shade = n.nodes.new("ShaderNodeMix"); shade.data_type = 'RGBA'; shade.blend_type = 'MULTIPLY'
    shade.inputs["Factor"].default_value = 1.0
    L.new(ramp.outputs[0], shade.inputs["A"])
    gray = n.nodes.new("ShaderNodeCombineColor")
    for k in ("Red", "Green", "Blue"): L.new(pr.outputs["Result"], gray.inputs[k])
    L.new(gray.outputs[0], shade.inputs["B"])
    L.new(shade.outputs["Result"], p.inputs["Base Color"])
    # light from within: strongest on the table, fading on the steep facets
    inv = n.nodes.new("ShaderNodeMath"); inv.operation = 'SUBTRACT'; inv.inputs[0].default_value = 1.0
    L.new(lw.outputs["Facing"], inv.inputs[1])
    gl = n.nodes.new("ShaderNodeMath"); gl.operation = 'POWER'; gl.inputs[1].default_value = 2.0
    L.new(inv.outputs[0], gl.inputs[0])
    em = n.nodes.new("ShaderNodeMath"); em.operation = 'MULTIPLY'; em.inputs[1].default_value = 0.5 if name != "diamond" else 0.12
    L.new(gl.outputs[0], em.inputs[0])
    p.inputs["Emission Color"].default_value = (*col, 1)
    L.new(em.outputs[0], p.inputs["Emission Strength"])
    p.inputs["Roughness"].default_value = 0.06
    p.inputs["Coat Weight"].default_value = 0.3
    p.inputs["Coat Roughness"].default_value = 0.02
    p.inputs["IOR"].default_value = 1.7
    p.inputs["Specular IOR Level"].default_value = 0.3
    o.data.materials.append(m)
    return o

os.makedirs(OUT, exist_ok=True)
for name, col, cut in GEMS:
    sc = setup()
    stone(name, col, cut)
    sc.render.filepath = os.path.join(OUT, name + ".png")
    bpy.ops.render.render(write_still=True)
    print("SPRITE", name)
