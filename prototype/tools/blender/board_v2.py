# Board look, reference #8 "natural balance": a pale travertine slab cut into tiles, faceted stones in
# classic colours, each a slightly irregular hand-cut gem. Path-traced in Blender (Cycles).
#   blender -b -P board_v2.py -- <out.png> [samples] [seed]
import bpy, bmesh, sys, math, random
from mathutils import Vector
argv = sys.argv[sys.argv.index("--") + 1:]
OUT = argv[0]
SAMPLES = int(argv[1]) if len(argv) > 1 else 128
random.seed(int(argv[2]) if len(argv) > 2 else 3)
R, C = 9, 8

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
sc.render.engine = 'CYCLES'
sc.cycles.samples = SAMPLES
sc.cycles.use_denoising = True
sc.render.resolution_x = 780
sc.render.resolution_y = 880
sc.view_settings.view_transform = 'AgX'
sc.view_settings.look = 'AgX - Medium High Contrast'
sc.cycles.max_bounces = 16
sc.cycles.transmission_bounces = 16
sc.cycles.caustics_refractive = True
sc.cycles.blur_glossy = 0.4
try:
    prefs = bpy.context.preferences.addons["cycles"].preferences
    prefs.compute_device_type = 'CUDA'; prefs.get_devices()
    for d in prefs.devices: d.use = True
    sc.cycles.device = 'GPU'
except Exception as e:
    print("GPU off", e)

# a real studio in the reflections: softboxes against dark walls give the facets their contrast
import os
PROJ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
w = bpy.data.worlds.new("w"); w.use_nodes = True; sc.world = w
env = w.node_tree.nodes.new("ShaderNodeTexEnvironment")
env.image = bpy.data.images.load(os.path.join(PROJ, "godot/assets/hdri/studio_small_09_1k.hdr"))
w.node_tree.links.new(env.outputs[0], w.node_tree.nodes["Background"].inputs[0])
w.node_tree.nodes["Background"].inputs[1].default_value = 0.45

# ---------------------------------------------------------------- travertine

def stone_mat(name, tint, rough=0.55):
    m = bpy.data.materials.new(name); m.use_nodes = True
    n = m.node_tree; b = n.nodes["Principled BSDF"]
    tc = n.nodes.new("ShaderNodeTexCoord")
    # soft cloudy tone + fine pores + a few faint veins
    nz = n.nodes.new("ShaderNodeTexNoise"); nz.inputs["Scale"].default_value = 1.6; nz.inputs["Detail"].default_value = 6
    n.links.new(tc.outputs["Object"], nz.inputs["Vector"])
    ramp = n.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = (tint[0] * 0.86, tint[1] * 0.84, tint[2] * 0.8, 1)
    ramp.color_ramp.elements[1].color = (*tint, 1)
    n.links.new(nz.outputs["Fac"], ramp.inputs["Fac"])
    # travertine's pits are stretched along its layers
    mp = n.nodes.new("ShaderNodeMapping"); mp.inputs["Scale"].default_value = (1.0, 4.0, 1.0)
    n.links.new(tc.outputs["Object"], mp.inputs[0])
    vor = n.nodes.new("ShaderNodeTexVoronoi"); vor.inputs["Scale"].default_value = 18
    n.links.new(mp.outputs[0], vor.inputs["Vector"])
    pore = n.nodes.new("ShaderNodeMath"); pore.operation = 'LESS_THAN'; pore.inputs[1].default_value = 0.12
    n.links.new(vor.outputs["Distance"], pore.inputs[0])
    mix = n.nodes.new("ShaderNodeMix"); mix.data_type = 'RGBA'
    n.links.new(pore.outputs[0], mix.inputs["Factor"])
    n.links.new(ramp.outputs[0], mix.inputs["A"])
    mix.inputs["B"].default_value = (tint[0] * 0.55, tint[1] * 0.5, tint[2] * 0.42, 1)
    n.links.new(mix.outputs["Result"], b.inputs["Base Color"])
    bump = n.nodes.new("ShaderNodeBump"); bump.inputs["Strength"].default_value = 0.5
    n.links.new(pore.outputs[0], bump.inputs["Height"])
    n.links.new(bump.outputs[0], b.inputs["Normal"])
    b.inputs["Roughness"].default_value = rough
    return m

slab_m = stone_mat("slab", (0.45, 0.37, 0.27), 0.8)
tile_m = stone_mat("tile", (0.52, 0.45, 0.35), 0.75)

bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, -0.12))
slab = bpy.context.object; slab.scale = (C + 0.7, R + 0.7, 0.24)
bpy.ops.object.modifier_add(type='BEVEL'); slab.modifiers[-1].width = 0.12; slab.modifiers[-1].segments = 4
slab.data.materials.append(slab_m)
disp = slab.modifiers.new("d", 'DISPLACE'); tx = bpy.data.textures.new("ragged", 'CLOUDS'); tx.noise_scale = 0.4
disp.texture = tx; disp.strength = 0.05
sub = slab.modifiers.new("s", 'SUBSURF'); sub.levels = 3; sub.render_levels = 3
slab.modifiers.move(slab.modifiers.find("s"), 1)
# raised tiles, one per cell: the grid is the shadowed gap between them
for r in range(R):
    for c in range(C):
        bpy.ops.mesh.primitive_cube_add(size=1, location=(c - C / 2 + 0.5, r - R / 2 + 0.5, 0.01))
        t = bpy.context.object; t.scale = (0.93, 0.93, 0.06)
        bpy.ops.object.modifier_add(type='BEVEL'); t.modifiers[-1].width = 0.02; t.modifiers[-1].segments = 3
        t.data.materials.append(tile_m)

# ---------------------------------------------------------------- light

def area(name, loc, energy, size, col):
    d = bpy.data.lights.new(name, 'AREA'); d.energy = energy; d.size = size; d.color = col
    o = bpy.data.objects.new(name, d); o.location = loc
    sc.collection.objects.link(o)
    c = o.constraints.new('TRACK_TO'); c.target = slab; c.track_axis = 'TRACK_NEGATIVE_Z'; c.up_axis = 'UP_Y'
area("key", (-6, 7, 8), 2200, 5, (1.0, 0.93, 0.82))
area("fill", (6, -4, 8), 250, 9, (0.9, 0.94, 1.0))

# ---------------------------------------------------------------- stones

def gem_mat(name, col, density=2.2, sss=0.12):
    """a cut stone, not plastic: colour clouds and veins through the body, tiny inclusions,
    fine grain on the faces, worn frosty edges, polish varying from face to face"""
    m = bpy.data.materials.new(name); m.use_nodes = True
    n = m.node_tree; L = n.links
    p = n.nodes["Principled BSDF"]
    tc = n.nodes.new("ShaderNodeTexCoord")
    oi = n.nodes.new("ShaderNodeObjectInfo")
    # every stone its own pattern: shift the coordinates by the object's random value
    off = n.nodes.new("ShaderNodeVectorMath"); off.operation = 'ADD'
    L.new(tc.outputs["Object"], off.inputs[0])
    rnd = n.nodes.new("ShaderNodeCombineXYZ")
    mul = n.nodes.new("ShaderNodeMath"); mul.operation = 'MULTIPLY'; mul.inputs[1].default_value = 100.0
    L.new(oi.outputs["Random"], mul.inputs[0])
    for k in ("X", "Y", "Z"): L.new(mul.outputs[0], rnd.inputs[k])
    L.new(rnd.outputs[0], off.inputs[1])
    co = off.outputs[0]
    # clouds of deeper and paler colour
    nz = n.nodes.new("ShaderNodeTexNoise"); nz.inputs["Scale"].default_value = 2.5; nz.inputs["Detail"].default_value = 8; nz.inputs["Roughness"].default_value = 0.65
    L.new(co, nz.inputs["Vector"])
    ramp = n.nodes.new("ShaderNodeValToRGB")
    cr = ramp.color_ramp
    cr.elements[0].position = 0.35; cr.elements[0].color = (col[0] * 0.55, col[1] * 0.55, col[2] * 0.55, 1)
    cr.elements[1].position = 0.7; cr.elements[1].color = (min(1, col[0] * 1.1), min(1, col[1] * 1.1), min(1, col[2] * 1.1), 1)
    L.new(nz.outputs["Fac"], ramp.inputs["Fac"])
    # veins: thin ridges of a warped noise
    wv = n.nodes.new("ShaderNodeTexWave"); wv.wave_type = 'BANDS'; wv.inputs["Scale"].default_value = 1.4
    wv.inputs["Distortion"].default_value = 9.0; wv.inputs["Detail"].default_value = 6
    L.new(co, wv.inputs["Vector"])
    vein = n.nodes.new("ShaderNodeMath"); vein.operation = 'GREATER_THAN'; vein.inputs[1].default_value = 0.992
    L.new(wv.outputs["Fac"], vein.inputs[0])
    mixv = n.nodes.new("ShaderNodeMix"); mixv.data_type = 'RGBA'
    L.new(vein.outputs[0], mixv.inputs["Factor"]); L.new(ramp.outputs[0], mixv.inputs["A"])
    mixv.inputs["B"].default_value = (min(1, col[0] * 0.9 + 0.08), min(1, col[1] * 0.9 + 0.08), min(1, col[2] * 0.9 + 0.08), 1)
    # worn edges: pointiness picks out the ridges, which turn paler and frosted
    geo = n.nodes.new("ShaderNodeNewGeometry")
    edge = n.nodes.new("ShaderNodeMapRange"); edge.inputs["From Min"].default_value = 0.6; edge.inputs["From Max"].default_value = 0.72
    L.new(geo.outputs["Pointiness"], edge.inputs["Value"])
    mixe = n.nodes.new("ShaderNodeMix"); mixe.data_type = 'RGBA'
    L.new(edge.outputs["Result"], mixe.inputs["Factor"]); L.new(mixv.outputs["Result"], mixe.inputs["A"])
    mixe.inputs["B"].default_value = (min(1, col[0] * 0.9 + 0.2), min(1, col[1] * 0.9 + 0.2), min(1, col[2] * 0.9 + 0.2), 1)
    L.new(mixe.outputs["Result"], p.inputs["Base Color"])
    # polish varies over the faces; the worn edges are rough
    rn = n.nodes.new("ShaderNodeTexNoise"); rn.inputs["Scale"].default_value = 9.0
    L.new(co, rn.inputs["Vector"])
    rr = n.nodes.new("ShaderNodeMapRange"); rr.inputs["To Min"].default_value = 0.14; rr.inputs["To Max"].default_value = 0.45
    L.new(rn.outputs["Fac"], rr.inputs["Value"])
    radd = n.nodes.new("ShaderNodeMath"); radd.operation = 'ADD'; radd.use_clamp = True
    L.new(rr.outputs["Result"], radd.inputs[0])
    rem = n.nodes.new("ShaderNodeMath"); rem.operation = 'MULTIPLY'; rem.inputs[1].default_value = 0.45
    L.new(edge.outputs["Result"], rem.inputs[0]); L.new(rem.outputs[0], radd.inputs[1])
    L.new(radd.outputs[0], p.inputs["Roughness"])
    # fine grain and a few pits on the faces
    gr = n.nodes.new("ShaderNodeTexNoise"); gr.inputs["Scale"].default_value = 160.0; gr.inputs["Detail"].default_value = 4
    L.new(co, gr.inputs["Vector"])
    vo = n.nodes.new("ShaderNodeTexVoronoi"); vo.inputs["Scale"].default_value = 30.0
    L.new(co, vo.inputs["Vector"])
    pit = n.nodes.new("ShaderNodeMath"); pit.operation = 'LESS_THAN'; pit.inputs[1].default_value = 0.06
    L.new(vo.outputs["Distance"], pit.inputs[0])
    hs = n.nodes.new("ShaderNodeMath"); hs.operation = 'SUBTRACT'
    L.new(gr.outputs["Fac"], hs.inputs[0]); L.new(pit.outputs[0], hs.inputs[1])
    bump = n.nodes.new("ShaderNodeBump"); bump.inputs["Strength"].default_value = 0.12; bump.inputs["Distance"].default_value = 0.004
    L.new(hs.outputs[0], bump.inputs["Height"]); L.new(bump.outputs[0], p.inputs["Normal"])
    # light still sinks into the body a little
    p.inputs["Transmission Weight"].default_value = 0.2
    p.inputs["Subsurface Weight"].default_value = 0.1
    p.inputs["Subsurface Radius"].default_value = (1.0, 0.6, 0.4)
    p.inputs["Subsurface Scale"].default_value = 0.05
    p.inputs["IOR"].default_value = 1.6
    p.inputs["Coat Weight"].default_value = 0.0
    vol = n.nodes.new("ShaderNodeVolumeAbsorption")
    vol.inputs["Color"].default_value = (*col, 1); vol.inputs["Density"].default_value = density
    L.new(vol.outputs[0], n.nodes["Material Output"].inputs["Volume"])
    return m

KINDS = [
    ("ruby",     (0.55, 0.06, 0.06), "crystal"),
    ("emerald",  (0.07, 0.36, 0.17), "emerald"),
    ("sapphire", (0.07, 0.15, 0.5),  "round"),
    ("citrine",  (0.78, 0.45, 0.08), "trillion"),
    ("amethyst", (0.33, 0.13, 0.52), "marquise"),
    ("diamond",  (0.72, 0.72, 0.7),  "cushion"),
]
mats = [gem_mat(k[0], k[1], 0.6 if k[0] == "diamond" else 4.0) for k in KINDS]

def ring(n, rx, ry, z, rot=0.0, f=None):
    pts = []
    for k in range(n):
        a = rot + k / n * math.tau
        x, y = math.cos(a) * rx, math.sin(a) * ry
        if f: x, y = f(a, x, y)
        pts.append(Vector((x, y, z)))
    return pts

def outline(kind):
    """girdle outline (points in xy) of each cut"""
    if kind == "crystal":     # a long hexagon, pointed at both ends
        return [Vector(p) for p in [(0, 0.44, 0), (0.25, 0.26, 0), (0.25, -0.26, 0), (0, -0.44, 0), (-0.25, -0.26, 0), (-0.25, 0.26, 0)]]
    if kind == "emerald":     # a rectangle with cut corners
        w, h, c = 0.3, 0.4, 0.1
        return [Vector(p) for p in [(-w + c, h, 0), (w - c, h, 0), (w, h - c, 0), (w, -h + c, 0), (w - c, -h, 0), (-w + c, -h, 0), (-w, -h + c, 0), (-w, h - c, 0)]]
    if kind == "round":
        return ring(16, 0.39, 0.39, 0)
    if kind == "trillion":
        return ring(3, 0.47, 0.47, 0, math.pi / 2)
    if kind == "marquise":
        return ring(16, 0.27, 0.45, 0, 0, lambda a, x, y: (x * (abs(math.sin(a)) ** 0.15), y))
    return ring(4, 0.48, 0.48, 0, math.pi / 4, None)  # cushion (rounded by the bevel below)

def make_gem(kind):
    base = outline(kind)
    j = lambda v, a: v + Vector((random.uniform(-a, a), random.uniform(-a, a), 0))
    pts = []
    girdle_z, crown_z = 0.1, 0.36 if kind != "crystal" else 0.42
    table = 0.42 if kind not in ("crystal", "trillion") else 0.3
    for p in base:
        pts.append(j(p * 0.92, 0.012) + Vector((0, 0, 0.0)))          # pavilion foot
        pts.append(j(p, 0.022) + Vector((0, 0, girdle_z + random.uniform(-0.02, 0.02))))   # girdle
        pts.append(j(p * table, 0.025) + Vector((0, 0, crown_z + random.uniform(-0.025, 0.02))))   # table edge
    if kind == "crystal":
        pts += [Vector((0, 0.3, crown_z + 0.06)), Vector((0, -0.3, crown_z + 0.06))]   # a ridge
    if kind == "trillion":
        pts.append(Vector((0, 0, crown_z + 0.08)))
    if kind in ("round", "marquise", "cushion", "emerald"):
        # a ring of star facets between girdle and table
        n = len(base)
        for k in range(n):
            mid = (base[k] + base[(k + 1) % n]) * 0.5
            pts.append(j(mid * 0.8, 0.01) + Vector((0, 0, (girdle_z + crown_z) * 0.62)))
    me = bpy.data.meshes.new(kind); bm = bmesh.new()
    for p in pts: bm.verts.new(p)
    bmesh.ops.convex_hull(bm, input=bm.verts)
    bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new(kind, me); sc.collection.objects.link(o)
    bev = o.modifiers.new("b", 'BEVEL'); bev.width = 0.012; bev.segments = 2
    bev.limit_method = 'ANGLE'
    return o

for r in range(R):
    for c in range(C):
        t = random.randrange(len(KINDS))
        o = make_gem(KINDS[t][2])
        o.location = (c - C / 2 + 0.5, (R - 1 - r) - R / 2 + 0.5, 0.05)
        o.rotation_euler = (random.uniform(-0.05, 0.05), random.uniform(-0.05, 0.05), random.uniform(-0.12, 0.12))
        s = random.uniform(1.08, 1.16); o.scale = (s, s, s)
        o.data.materials.append(mats[t])

cam_d = bpy.data.cameras.new("cam"); cam_d.type = 'ORTHO'; cam_d.ortho_scale = R + 0.9
cam = bpy.data.objects.new("cam", cam_d); cam.location = (0, 0, 20)
sc.collection.objects.link(cam); sc.camera = cam
sc.render.filepath = OUT
bpy.ops.render.render(write_still=True)
print("DONE", OUT)
