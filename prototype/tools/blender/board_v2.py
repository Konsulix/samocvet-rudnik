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
w.node_tree.nodes["Background"].inputs[1].default_value = 0.6

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
    vor = n.nodes.new("ShaderNodeTexVoronoi"); vor.inputs["Scale"].default_value = 60
    n.links.new(tc.outputs["Object"], vor.inputs["Vector"])
    pore = n.nodes.new("ShaderNodeMath"); pore.operation = 'LESS_THAN'; pore.inputs[1].default_value = 0.08
    n.links.new(vor.outputs["Distance"], pore.inputs[0])
    mix = n.nodes.new("ShaderNodeMix"); mix.data_type = 'RGBA'
    n.links.new(pore.outputs[0], mix.inputs["Factor"])
    n.links.new(ramp.outputs[0], mix.inputs["A"])
    mix.inputs["B"].default_value = (tint[0] * 0.55, tint[1] * 0.5, tint[2] * 0.42, 1)
    n.links.new(mix.outputs["Result"], b.inputs["Base Color"])
    bump = n.nodes.new("ShaderNodeBump"); bump.inputs["Strength"].default_value = 0.25
    n.links.new(pore.outputs[0], bump.inputs["Height"])
    n.links.new(bump.outputs[0], b.inputs["Normal"])
    b.inputs["Roughness"].default_value = rough
    return m

slab_m = stone_mat("slab", (0.42, 0.36, 0.28))
tile_m = stone_mat("tile", (0.55, 0.49, 0.4), 0.5)

bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, -0.12))
slab = bpy.context.object; slab.scale = (C + 0.7, R + 0.7, 0.24)
bpy.ops.object.modifier_add(type='BEVEL'); slab.modifiers[-1].width = 0.12; slab.modifiers[-1].segments = 4
slab.data.materials.append(slab_m)
# raised tiles, one per cell: the grid is the shadowed gap between them
for r in range(R):
    for c in range(C):
        bpy.ops.mesh.primitive_cube_add(size=1, location=(c - C / 2 + 0.5, r - R / 2 + 0.5, 0.01))
        t = bpy.context.object; t.scale = (0.95, 0.95, 0.04)
        bpy.ops.object.modifier_add(type='BEVEL'); t.modifiers[-1].width = 0.012; t.modifiers[-1].segments = 2
        t.data.materials.append(tile_m)

# ---------------------------------------------------------------- light

def area(name, loc, energy, size, col):
    d = bpy.data.lights.new(name, 'AREA'); d.energy = energy; d.size = size; d.color = col
    o = bpy.data.objects.new(name, d); o.location = loc
    sc.collection.objects.link(o)
    c = o.constraints.new('TRACK_TO'); c.target = slab; c.track_axis = 'TRACK_NEGATIVE_Z'; c.up_axis = 'UP_Y'
area("key", (-6, 7, 10), 1600, 5, (1.0, 0.94, 0.85))
area("fill", (6, -4, 8), 250, 9, (0.9, 0.94, 1.0))

# ---------------------------------------------------------------- stones

def gem_mat(name, col, density=2.2, sss=0.12):
    m = bpy.data.materials.new(name); m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (*col, 1)
    p.inputs["Transmission Weight"].default_value = 1.0
    p.inputs["Subsurface Weight"].default_value = 0.0
    p.inputs["Subsurface Radius"].default_value = (0.3, 0.3, 0.3)
    p.inputs["Subsurface Scale"].default_value = 0.2
    p.inputs["Roughness"].default_value = 0.02
    p.inputs["IOR"].default_value = 1.6
    vol = m.node_tree.nodes.new("ShaderNodeVolumeAbsorption")
    vol.inputs["Color"].default_value = (*col, 1); vol.inputs["Density"].default_value = density
    m.node_tree.links.new(vol.outputs[0], m.node_tree.nodes["Material Output"].inputs["Volume"])
    return m

KINDS = [
    ("ruby",     (0.85, 0.06, 0.08), "crystal"),
    ("emerald",  (0.05, 0.62, 0.22), "emerald"),
    ("sapphire", (0.08, 0.22, 0.9),  "round"),
    ("citrine",  (0.98, 0.7, 0.08),  "trillion"),
    ("amethyst", (0.5, 0.15, 0.85),  "marquise"),
    ("diamond",  (0.95, 0.96, 0.98), "cushion"),
]
mats = [gem_mat(k[0], k[1], 0.3 if k[0] == "diamond" else 5.0) for k in KINDS]

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
    girdle_z, crown_z = 0.06, 0.2 if kind != "crystal" else 0.26
    table = 0.55 if kind not in ("crystal", "trillion") else 0.35
    for p in base:
        pts.append(j(p * 0.92, 0.008) + Vector((0, 0, 0.0)))          # pavilion foot
        pts.append(j(p, 0.012) + Vector((0, 0, girdle_z)))              # girdle
        pts.append(j(p * table, 0.012) + Vector((0, 0, crown_z)))       # table edge
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
    bev = o.modifiers.new("b", 'BEVEL'); bev.width = 0.035 if kind == "cushion" else 0.01; bev.segments = 3 if kind == "cushion" else 1
    bev.limit_method = 'ANGLE'
    return o

for r in range(R):
    for c in range(C):
        t = random.randrange(len(KINDS))
        o = make_gem(KINDS[t][2])
        o.location = (c - C / 2 + 0.5, (R - 1 - r) - R / 2 + 0.5, 0.05)
        o.rotation_euler = (random.uniform(-0.05, 0.05), random.uniform(-0.05, 0.05), random.uniform(-0.12, 0.12))
        s = random.uniform(0.95, 1.05); o.scale = (s, s, s)
        o.data.materials.append(mats[t])

cam_d = bpy.data.cameras.new("cam"); cam_d.type = 'ORTHO'; cam_d.ortho_scale = R + 0.9
cam = bpy.data.objects.new("cam", cam_d); cam.location = (0, 0, 20)
sc.collection.objects.link(cam); sc.camera = cam
sc.render.filepath = OUT
bpy.ops.render.render(write_still=True)
print("DONE", OUT)
