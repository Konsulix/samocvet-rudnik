# A look test for the board, path-traced in Blender (Cycles): real glass (transmission, dispersion,
# caustics) on a dark stone slab, seen straight down. If this is the look, the pieces get pre-rendered
# into sprites for the game. Usage:
#   blender -b -P board_look.py -- <out.png> <project_dir> [samples]
import bpy, sys, math, random, os
argv = sys.argv[sys.argv.index("--") + 1:]
OUT, PROJ = argv[0], argv[1]
SAMPLES = int(argv[2]) if len(argv) > 2 else 96
R, C = 9, 8
random.seed(5)

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
sc.cycles.blur_glossy = 0.5
try:
    prefs = bpy.context.preferences.addons["cycles"].preferences
    prefs.compute_device_type = 'CUDA'
    prefs.get_devices()
    for d in prefs.devices: d.use = True
    sc.cycles.device = 'GPU'
except Exception as e:
    print("GPU off", e)

# world: the same photographed studio the specimens use, dimmed
w = bpy.data.worlds.new("w"); w.use_nodes = True; sc.world = w
nt = w.node_tree
env = nt.nodes.new("ShaderNodeTexEnvironment")
env.image = bpy.data.images.load(os.path.join(PROJ, "godot/assets/hdri/studio_small_09_1k.hdr"))
nt.links.new(env.outputs[0], nt.nodes["Background"].inputs[0])
nt.nodes["Background"].inputs[1].default_value = 0.35

# key light: a big soft box from the upper left, a cool rim from the lower right
def area(name, loc, energy, size, col):
    d = bpy.data.lights.new(name, 'AREA'); d.energy = energy; d.size = size; d.color = col
    o = bpy.data.objects.new(name, d); o.location = loc
    sc.collection.objects.link(o)
    c = o.constraints.new('TRACK_TO'); c.target = slab; c.track_axis = 'TRACK_NEGATIVE_Z'; c.up_axis = 'UP_Y'

# the slab: dark stone, photo scan
bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, -0.2))
slab = bpy.context.object; slab.scale = (C + 0.6, R + 0.6, 0.4)
bpy.ops.object.modifier_add(type='BEVEL'); slab.modifiers[-1].width = 0.08; slab.modifiers[-1].segments = 3
sm = bpy.data.materials.new("slab"); sm.use_nodes = True
n = sm.node_tree; b = n.nodes["Principled BSDF"]
tc = n.nodes.new("ShaderNodeTexCoord"); mp = n.nodes.new("ShaderNodeMapping"); mp.inputs["Scale"].default_value = (0.35, 0.35, 0.35)
n.links.new(tc.outputs["Object"], mp.inputs[0])
tex = os.path.join(PROJ, "godot/assets/textures/rock_face_03/rock_face_03_")
dif = n.nodes.new("ShaderNodeTexImage"); dif.image = bpy.data.images.load(tex + "diff_1k.jpg"); dif.projection = 'BOX'
nor = n.nodes.new("ShaderNodeTexImage"); nor.image = bpy.data.images.load(tex + "nor_gl_1k.jpg"); nor.image.colorspace_settings.name = 'Non-Color'; nor.projection = 'BOX'
for t in (dif, nor): n.links.new(mp.outputs[0], t.inputs[0])
hsv = n.nodes.new("ShaderNodeHueSaturation"); hsv.inputs["Saturation"].default_value = 0.25; hsv.inputs["Value"].default_value = 0.35
n.links.new(dif.outputs[0], hsv.inputs["Color"]); n.links.new(hsv.outputs[0], b.inputs["Base Color"])
nm = n.nodes.new("ShaderNodeNormalMap"); n.links.new(nor.outputs[0], nm.inputs["Color"]); n.links.new(nm.outputs[0], b.inputs["Normal"])
b.inputs["Roughness"].default_value = 0.6
slab.data.materials.append(sm)
# shallow pockets: darker squares just under each cell
pm = bpy.data.materials.new("pocket"); pm.use_nodes = True
pm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.09, 0.09, 0.1, 1)
pm.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.8
for r in range(R):
    for c in range(C):
        bpy.ops.mesh.primitive_plane_add(size=0.9, location=(c - C / 2 + 0.5, r - R / 2 + 0.5, 0.002))
        bpy.context.object.data.materials.append(pm)

area("key", (-5, 6, 9), 2600, 8, (1.0, 0.95, 0.88))
area("rim", (6, -5, 4), 600, 5, (0.7, 0.8, 1.0))

# the pieces
COLS = [((0.92, 0.94, 0.96), "prism"), ((0.45, 0.18, 0.85), "octa"), ((0.95, 0.55, 0.12), "cube"),
        ((0.1, 0.65, 0.55), "pebble"), ((0.9, 0.22, 0.12), "tri"), ((0.08, 0.09, 0.11), "tablet")]

def glass(col, name, smoky=False):
    m = bpy.data.materials.new(name); m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (*col, 1)
    # translucent rather than clear: the body glows with its own colour, light scatters inside
    p.inputs["Transmission Weight"].default_value = 0.6 if smoky else 0.88
    p.inputs["Subsurface Weight"].default_value = 0.0 if smoky else 0.18
    p.inputs["Subsurface Radius"].default_value = (0.3, 0.3, 0.3)
    p.inputs["Subsurface Scale"].default_value = 0.25
    p.inputs["Roughness"].default_value = 0.02
    p.inputs["IOR"].default_value = 1.55
    p.inputs["Coat Weight"].default_value = 0.3
    try: p.inputs["Thin Film Thickness"].default_value = 250.0   # a faint oily sheen, as on the specimens
    except Exception: pass
    # body colour also absorbed through the volume, so thick parts get richer
    vol = m.node_tree.nodes.new("ShaderNodeVolumeAbsorption")
    vol.inputs["Color"].default_value = (*col, 1); vol.inputs["Density"].default_value = 1.6 if not smoky else 5.0
    m.node_tree.links.new(vol.outputs[0], m.node_tree.nodes["Material Output"].inputs["Volume"])
    return m

mats = [glass(c, k, k == "tablet") for c, k in COLS]

def make(kind):
    if kind == "prism":
        bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.2, depth=0.6)
        o = bpy.context.object; o.rotation_euler = (math.pi / 2, 0, 0)
        bpy.ops.object.transform_apply(rotation=True)
        # pointed ends
        for v in o.data.vertices:
            if abs(v.co.y) > 0.29: pass
        bpy.ops.object.modifier_add(type='BEVEL'); o.modifiers[-1].width = 0.03; o.modifiers[-1].segments = 2
        o.scale = (1, 1.15, 0.8)
    elif kind == "octa":
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.4)
        o = bpy.context.object
        bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.object.mode_set(mode='OBJECT')
        import bmesh
        bm = bmesh.new()
        for co in [(0.38, 0, 0), (-0.38, 0, 0), (0, 0.44, 0), (0, -0.44, 0), (0, 0, 0.3), (0, 0, -0.3)]: bm.verts.new(co)
        bmesh.ops.convex_hull(bm, input=bm.verts)
        bm.to_mesh(o.data); bm.free()
        bpy.ops.object.modifier_add(type='BEVEL'); o.modifiers[-1].width = 0.02; o.modifiers[-1].segments = 2
    elif kind == "cube":
        bpy.ops.mesh.primitive_cube_add(size=0.56)
        o = bpy.context.object; o.rotation_euler = (0.25, 0.2, random.uniform(-0.2, 0.2))
        bpy.ops.object.modifier_add(type='BEVEL'); o.modifiers[-1].width = 0.05; o.modifiers[-1].segments = 3
    elif kind == "pebble":
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.34, segments=32, ring_count=16)
        o = bpy.context.object; o.scale = (1.15, 0.92, 0.5)
        bpy.ops.object.shade_smooth()
    elif kind == "tri":
        bpy.ops.mesh.primitive_cone_add(vertices=3, radius1=0.48, depth=0.4)
        o = bpy.context.object; o.rotation_euler = (0, 0, math.pi / 2)
        bpy.ops.object.modifier_add(type='BEVEL'); o.modifiers[-1].width = 0.03; o.modifiers[-1].segments = 2
    else:
        bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.4, depth=0.2)
        o = bpy.context.object
        bpy.ops.object.modifier_add(type='BEVEL'); o.modifiers[-1].width = 0.05; o.modifiers[-1].segments = 2
    return o

for r in range(R):
    for c in range(C):
        t = random.randrange(6)
        o = make(COLS[t][1])
        o.location = (c - C / 2 + 0.5, (R - 1 - r) - R / 2 + 0.5, 0.22)
        o.rotation_euler[2] += random.uniform(-0.12, 0.12)
        o.data.materials.append(mats[t])

cam_d = bpy.data.cameras.new("cam"); cam_d.type = 'ORTHO'; cam_d.ortho_scale = R + 0.8
cam = bpy.data.objects.new("cam", cam_d); cam.location = (0, 0, 20)
sc.collection.objects.link(cam); sc.camera = cam
sc.render.filepath = OUT
bpy.ops.render.render(write_still=True)
print("DONE", OUT)
