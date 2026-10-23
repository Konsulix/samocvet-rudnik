# Everything else on the board, as sprites in the same light as the gems: specials (dynamite, bundle,
# drill, resonator), the gold nugget, blockers (soft and hard rock, mud, a timber lock), the marble
# tile and a marble slab texture. Straight-down camera, transparent background, no shadow
# (SPRITE_SHADOW=1 brings back the soft contact shadow).
#   blender -b -P board_sprites.py -- <out_dir> [px] [samples] [only]
import bpy, bmesh, sys, math, os, random
from mathutils import Vector
argv = sys.argv[sys.argv.index("--") + 1:]
OUT = argv[0]
PX = int(argv[1]) if len(argv) > 1 else 256
SAMPLES = int(argv[2]) if len(argv) > 2 else 128
ONLY = argv[3].split(",") if len(argv) > 3 else None
PROJ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))

def setup(px=PX, shadow=True, transparent=True, scale=1.15):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.samples = SAMPLES
    sc.cycles.use_denoising = True
    sc.render.resolution_x = px
    sc.render.resolution_y = px
    sc.render.film_transparent = transparent
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
    w.node_tree.nodes["Background"].inputs[1].default_value = 0.35
    d = bpy.data.lights.new("sun", 'SUN'); d.energy = 3.0; d.angle = math.radians(8); d.color = (1.0, 0.96, 0.9)
    s = bpy.data.objects.new("sun", d)
    s.rotation_euler = Vector((0.55, -0.6, -1.0)).to_track_quat('-Z', 'Y').to_euler()
    sc.collection.objects.link(s)
    if shadow:
        bpy.ops.mesh.primitive_plane_add(size=4, location=(0, 0, 0))
        bpy.context.object.is_shadow_catcher = True
    cd = bpy.data.cameras.new("cam"); cd.type = 'ORTHO'; cd.ortho_scale = scale
    cam = bpy.data.objects.new("cam", cd); cam.location = (0, 0, 10)
    sc.collection.objects.link(cam); sc.camera = cam
    return sc

def mat(name, col, rough=0.5, metal=0.0, coat=0.0, emit=None, emit_k=0.0):
    m = bpy.data.materials.new(name); m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (*col, 1)
    p.inputs["Roughness"].default_value = rough
    p.inputs["Metallic"].default_value = metal
    p.inputs["Coat Weight"].default_value = coat
    if emit:
        p.inputs["Emission Color"].default_value = (*emit, 1)
        p.inputs["Emission Strength"].default_value = emit_k
    return m

def noise_color(m, a, b, scale=6.0, bump=0.3):
    """mottle a material between two colours and give it a little grain"""
    n = m.node_tree; L = n.links; p = n.nodes["Principled BSDF"]
    tc = n.nodes.new("ShaderNodeTexCoord")
    nz = n.nodes.new("ShaderNodeTexNoise"); nz.inputs["Scale"].default_value = scale; nz.inputs["Detail"].default_value = 8
    L.new(tc.outputs["Object"], nz.inputs["Vector"])
    r = n.nodes.new("ShaderNodeValToRGB")
    r.color_ramp.elements[0].color = (*a, 1); r.color_ramp.elements[1].color = (*b, 1)
    L.new(nz.outputs["Fac"], r.inputs["Fac"]); L.new(r.outputs[0], p.inputs["Base Color"])
    g = n.nodes.new("ShaderNodeTexNoise"); g.inputs["Scale"].default_value = 80
    L.new(tc.outputs["Object"], g.inputs["Vector"])
    bp = n.nodes.new("ShaderNodeBump"); bp.inputs["Strength"].default_value = bump
    L.new(g.outputs["Fac"], bp.inputs["Height"]); L.new(bp.outputs[0], p.inputs["Normal"])
    return m

def link(o, m):
    o.data.materials.append(m)
    return o

def cyl(r, d, loc, rot, m, verts=32):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=d, location=loc, rotation=rot)
    o = bpy.context.object; bpy.ops.object.shade_smooth()
    return link(o, m)

def lump(r, sc, m, seed, strength=0.25, sub=3, loc=(0, 0, 0)):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub, radius=r, location=loc)
    o = bpy.context.object; o.scale = sc
    tx = bpy.data.textures.new("n%d" % seed, 'CLOUDS'); tx.noise_scale = 0.35; tx.noise_depth = 3
    d = o.modifiers.new("d", 'DISPLACE'); d.texture = tx; d.strength = strength; d.texture_coords = 'OBJECT'
    em = bpy.data.objects.new("e%d" % seed, None); em.location = (seed * 3.1, seed * 1.7, 0); bpy.context.scene.collection.objects.link(em)
    d.texture_coords_object = em
    return link(o, m)

# ---------------------------------------------------------------- the pieces

def dynamite(rot_z=0.0):
    red = mat("red", (0.62, 0.05, 0.04), 0.45, coat=0.3)
    paper = mat("paper", (0.85, 0.8, 0.68), 0.7)
    cyl(0.13, 0.72, (0, 0, 0.14), (0, math.pi / 2, rot_z), red)
    for x in (-0.22, 0.22):
        cyl(0.134, 0.06, (x * math.cos(rot_z), x * math.sin(rot_z), 0.14), (0, math.pi / 2, rot_z), paper)
    # a fuse curling off one end, its tip glowing
    end = Vector((0.37 * math.cos(rot_z), 0.37 * math.sin(rot_z), 0.16))
    fuse = mat("fuse", (0.12, 0.1, 0.08), 0.8)
    cyl(0.018, 0.12, end + Vector((0.05 * math.cos(rot_z), 0.05 * math.sin(rot_z), 0.03)), (0, math.pi / 2 - 0.6, rot_z), fuse, 8)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.035, location=end + Vector((0.1 * math.cos(rot_z), 0.1 * math.sin(rot_z), 0.07)))
    link(bpy.context.object, mat("spark", (1, 0.6, 0.1), emit=(1.0, 0.55, 0.1), emit_k=12))

def bundle():
    red = mat("red", (0.62, 0.05, 0.04), 0.45, coat=0.3)
    for k, (x, y, z) in enumerate([(-0.15, -0.05, 0.12), (0.15, -0.05, 0.12), (0.0, 0.1, 0.3)]):
        cyl(0.12, 0.62, (x, y, z), (math.pi / 2, 0, 0), red)
    rope = mat("rope", (0.55, 0.42, 0.25), 0.9)
    for y in (-0.14, 0.14):
        bpy.ops.mesh.primitive_torus_add(major_radius=0.27, minor_radius=0.025, location=(0, y, 0.2), rotation=(math.pi / 2, 0, 0))
        o = bpy.context.object; o.scale = (1.15, 1.0, 0.85); link(o, rope)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.04, location=(0.0, 0.42, 0.42))
    link(bpy.context.object, mat("spark", (1, 0.6, 0.1), emit=(1.0, 0.55, 0.1), emit_k=12))

def drill():
    steel = mat("steel", (0.75, 0.77, 0.8), 0.22, metal=1.0)
    bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=0.26, radius2=0.0, depth=0.78, location=(0, -0.06, 0.2), rotation=(math.pi / 2, 0, 0))
    o = bpy.context.object
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.subdivide(number_cuts=12); bpy.ops.object.mode_set(mode='OBJECT')
    tw = o.modifiers.new("t", 'SIMPLE_DEFORM'); tw.deform_method = 'TWIST'; tw.angle = math.radians(420); tw.deform_axis = 'Z'
    link(o, steel)
    brass = mat("brass", (0.8, 0.55, 0.2), 0.3, metal=1.0)
    cyl(0.14, 0.2, (0, 0.4, 0.2), (math.pi / 2, 0, 0), brass)

def orb():
    # the resonator: a cracked geode, a violet glow inside its crystal cave
    shell = noise_color(mat("shell", (0.4, 0.36, 0.32), 0.9), (0.25, 0.22, 0.2), (0.5, 0.46, 0.4), 4.0, 0.5)
    lump(0.38, (1, 1, 0.75), shell, 3, 0.12)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.27, location=(0, 0, 0.18))
    o = bpy.context.object; o.scale = (1, 1, 0.75)
    m = mat("cave", (0.35, 0.08, 0.7), 0.15, coat=1.0, emit=(0.45, 0.12, 0.95), emit_k=0.6)
    vo = m.node_tree.nodes.new("ShaderNodeTexVoronoi"); vo.inputs["Scale"].default_value = 30
    bp = m.node_tree.nodes.new("ShaderNodeBump"); bp.inputs["Strength"].default_value = 0.8
    m.node_tree.links.new(vo.outputs["Distance"], bp.inputs["Height"])
    m.node_tree.links.new(bp.outputs[0], m.node_tree.nodes["Principled BSDF"].inputs["Normal"])
    link(o, m)

def nugget():
    gold = mat("gold", (1.0, 0.72, 0.25), 0.25, metal=1.0)
    n = gold.node_tree
    vo = n.nodes.new("ShaderNodeTexVoronoi"); vo.inputs["Scale"].default_value = 14
    tc = n.nodes.new("ShaderNodeTexCoord"); n.links.new(tc.outputs["Object"], vo.inputs["Vector"])
    rr = n.nodes.new("ShaderNodeMapRange"); rr.inputs["To Min"].default_value = 0.15; rr.inputs["To Max"].default_value = 0.55
    n.links.new(vo.outputs["Distance"], rr.inputs["Value"]); n.links.new(rr.outputs[0], n.nodes["Principled BSDF"].inputs["Roughness"])
    lump(0.3, (1.15, 0.95, 0.6), gold, 7, 0.22, 4)
    lump(0.13, (1, 1, 0.8), gold, 9, 0.1, 3, (0.24, -0.18, 0.05))

def rock(hard):
    if hard:
        m = noise_color(mat("basalt", (0.2, 0.2, 0.22), 0.7), (0.1, 0.1, 0.11), (0.3, 0.3, 0.32), 5.0, 0.6)
    else:
        m = noise_color(mat("sand", (0.6, 0.48, 0.32), 0.9), (0.45, 0.34, 0.22), (0.72, 0.6, 0.42), 5.0, 0.6)
    random.seed(11 if hard else 5)
    spots = [(-0.17, 0.14, 0.24), (0.18, 0.1, 0.22), (-0.02, -0.18, 0.25)] if not hard else [(-0.1, 0.06, 0.32), (0.17, -0.12, 0.25)]
    for k, (x, y, r) in enumerate(spots):
        o = lump(r, (1.1, 1.0, 0.75 if not hard else 0.85), m, k + (20 if hard else 0), 0.18, 3, (x, y, r * 0.5))
        if hard:
            # flat broken faces catch the light
            o.modifiers.new("dec", 'DECIMATE').ratio = 0.15

def mud():
    m = mat("mud", (0.2, 0.12, 0.06), 0.18, coat=1.0)
    noise_color(m, (0.12, 0.07, 0.03), (0.3, 0.2, 0.1), 4.0, 0.4)
    m.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.15
    lump(0.44, (1, 1, 0.12), m, 31, 0.08, 4, (0, 0, 0.02))

def lock():
    # two timber planks nailed across the cell; the stone shows between them
    wood = noise_color(mat("wood", (0.55, 0.35, 0.18), 0.7), (0.38, 0.22, 0.1), (0.62, 0.42, 0.22), 2.0, 0.4)
    for a in (math.pi / 4, -math.pi / 4):
        bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 0.32 if a > 0 else 0.28), rotation=(0, 0, a))
        o = bpy.context.object; o.scale = (1.12, 0.17, 0.06)
        o.modifiers.new("b", 'BEVEL').width = 0.015
        link(o, wood)
    iron = mat("iron", (0.3, 0.3, 0.32), 0.4, metal=1.0)
    for x, y in [(0.32, 0.32), (-0.32, -0.32), (0.32, -0.32), (-0.32, 0.32)]:
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.035, location=(x, y, 0.36))
        link(bpy.context.object, iron)

def gas():
    # a pocket of toxic gas: soft, glowing yellow-green puffs
    m = mat("gas", (0.22, 0.5, 0.06), 0.6, emit=(0.35, 0.75, 0.08), emit_k=0.25)
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Transmission Weight"].default_value = 0.5
    random.seed(17)
    for k in range(7):
        a = k / 7 * math.tau + random.uniform(-0.3, 0.3)
        rr = random.uniform(0.12, 0.25) if k else 0.0
        bpy.ops.mesh.primitive_uv_sphere_add(radius=random.uniform(0.16, 0.24), location=(math.cos(a) * rr, math.sin(a) * rr, 0.18))
        o = bpy.context.object; o.scale = (1, 1, 0.7); bpy.ops.object.shade_smooth()
        link(o, m)

def geode():
    # a round nodule of crusty rock spanning 2x2 cells, a ring of violet crystal showing where it split
    shell = noise_color(mat("shell", (0.35, 0.3, 0.25), 0.95), (0.2, 0.17, 0.14), (0.42, 0.37, 0.3), 3.0, 0.8)
    o = lump(0.82, (1, 1, 0.55), shell, 41, 0.18, 4)
    vio = mat("vio", (0.4, 0.15, 0.75), 0.15, coat=1.0, emit=(0.4, 0.15, 0.85), emit_k=0.4)
    for k in range(28):
        a = k / 28 * math.tau
        bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=0.06, depth=0.12, location=(math.cos(a) * 0.62, math.sin(a) * 0.62, 0.3), rotation=(0, math.pi / 2.4, a))
        link(bpy.context.object, vio)

def marble_mat(light=True):
    m = bpy.data.materials.new("marble"); m.use_nodes = True
    n = m.node_tree; L = n.links; p = n.nodes["Principled BSDF"]
    tc = n.nodes.new("ShaderNodeTexCoord")
    nz = n.nodes.new("ShaderNodeTexNoise"); nz.inputs["Scale"].default_value = 1.2; nz.inputs["Detail"].default_value = 10
    L.new(tc.outputs["Object"], nz.inputs["Vector"])
    r = n.nodes.new("ShaderNodeValToRGB")
    base = (0.8, 0.76, 0.69) if light else (0.66, 0.62, 0.55)
    r.color_ramp.elements[0].color = (base[0] * 0.92, base[1] * 0.9, base[2] * 0.87, 1); r.color_ramp.elements[1].color = (*base, 1)
    L.new(nz.outputs["Fac"], r.inputs["Fac"])
    wv = n.nodes.new("ShaderNodeTexWave"); wv.inputs["Scale"].default_value = 0.5; wv.inputs["Distortion"].default_value = 28; wv.inputs["Detail"].default_value = 8
    L.new(tc.outputs["Object"], wv.inputs["Vector"])
    vr = n.nodes.new("ShaderNodeMapRange"); vr.inputs["From Min"].default_value = 0.94; vr.inputs["From Max"].default_value = 1.0
    vr.inputs["To Max"].default_value = 0.35
    L.new(wv.outputs["Fac"], vr.inputs["Value"])
    mx = n.nodes.new("ShaderNodeMix"); mx.data_type = 'RGBA'
    L.new(vr.outputs[0], mx.inputs["Factor"]); L.new(r.outputs[0], mx.inputs["A"])
    mx.inputs["B"].default_value = (0.58, 0.55, 0.5, 1)
    L.new(mx.outputs["Result"], p.inputs["Base Color"])
    p.inputs["Roughness"].default_value = 0.35
    return m

def tile():
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 0.03))
    o = bpy.context.object; o.scale = (0.96, 0.96, 0.06)
    b = o.modifiers.new("b", 'BEVEL'); b.width = 0.02; b.segments = 3
    link(o, marble_mat(True))

def slab_texture(path):
    sc = setup(1024, shadow=False, transparent=False, scale=4.0)
    bpy.ops.mesh.primitive_plane_add(size=8)
    link(bpy.context.object, marble_mat(False))
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)

JOBS = {
    "rh": lambda: dynamite(0.0), "rv": lambda: dynamite(math.pi / 2), "bomb": bundle, "drill": drill, "orb": orb,
    "nug": nugget, "gas": gas, "geode": geode, "rock1": lambda: rock(False), "rock2": lambda: rock(True), "mud": mud, "lock": lock, "tile": tile,
}
os.makedirs(OUT, exist_ok=True)
for name, fn in JOBS.items():
    if ONLY and name not in ONLY: continue
    sc = setup(scale=2.3 if name == "geode" else 1.15 if name != "tile" else 1.0, shadow=name != "tile" and os.environ.get("SPRITE_SHADOW") == "1")
    fn()
    sc.render.filepath = os.path.join(OUT, name + ".png")
    bpy.ops.render.render(write_still=True)
    print("SPRITE", name)
if not ONLY or "slab" in ONLY:
    slab_texture(os.path.join(OUT, "slab.png"))
    print("SPRITE slab")
