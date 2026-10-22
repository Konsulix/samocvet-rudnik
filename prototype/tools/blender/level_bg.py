# The level screen's backdrop: a pale marble table seen from above, clusters of crystals in the top
# corners, a blurred sprig of leaves in a lower corner, soft window light falling across it in slanted
# bars. Rendered once; the board, HUD and buttons sit on top in the game.
#   blender -b -P level_bg.py -- <out.png> [w] [h] [samples]
import bpy, bmesh, sys, math, os, random
from mathutils import Vector
argv = sys.argv[sys.argv.index("--") + 1:]
OUT = argv[0]
W = int(argv[1]) if len(argv) > 1 else 780
H = int(argv[2]) if len(argv) > 2 else 1688
SAMPLES = int(argv[3]) if len(argv) > 3 else 128
PROJ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
random.seed(7)

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
sc.render.engine = 'CYCLES'
sc.cycles.samples = SAMPLES
sc.cycles.use_denoising = True
sc.render.resolution_x = W
sc.render.resolution_y = H
sc.view_settings.view_transform = 'Standard'
sc.view_settings.look = 'Medium High Contrast'
try:
    prefs = bpy.context.preferences.addons["cycles"].preferences
    prefs.compute_device_type = 'CUDA'; prefs.get_devices()
    for d in prefs.devices: d.use = True
    sc.cycles.device = 'GPU'
except Exception:
    pass

aspect = H / W
SW = 10.0                    # world width of the view
SH = SW * aspect

# ---------------------------------------------------------------- the marble table
def marble():
    m = bpy.data.materials.new("marble"); m.use_nodes = True
    n = m.node_tree; L = n.links; p = n.nodes["Principled BSDF"]
    tc = n.nodes.new("ShaderNodeTexCoord")
    nz = n.nodes.new("ShaderNodeTexNoise"); nz.inputs["Scale"].default_value = 0.35; nz.inputs["Detail"].default_value = 10
    L.new(tc.outputs["Object"], nz.inputs["Vector"])
    r = n.nodes.new("ShaderNodeValToRGB")
    r.color_ramp.elements[0].color = (0.56, 0.52, 0.46, 1); r.color_ramp.elements[1].color = (0.68, 0.65, 0.59, 1)
    L.new(nz.outputs["Fac"], r.inputs["Fac"])
    wv = n.nodes.new("ShaderNodeTexWave"); wv.inputs["Scale"].default_value = 0.25; wv.inputs["Distortion"].default_value = 30; wv.inputs["Detail"].default_value = 10
    L.new(tc.outputs["Object"], wv.inputs["Vector"])
    vr = n.nodes.new("ShaderNodeMapRange"); vr.inputs["From Min"].default_value = 0.86; vr.inputs["From Max"].default_value = 1.0; vr.inputs["To Max"].default_value = 0.45
    L.new(wv.outputs["Fac"], vr.inputs["Value"])
    mx = n.nodes.new("ShaderNodeMix"); mx.data_type = 'RGBA'
    L.new(vr.outputs[0], mx.inputs["Factor"]); L.new(r.outputs[0], mx.inputs["A"])
    mx.inputs["B"].default_value = (0.4, 0.37, 0.33, 1)
    L.new(mx.outputs["Result"], p.inputs["Base Color"])
    p.inputs["Roughness"].default_value = 0.3
    return m

bpy.ops.mesh.primitive_plane_add(size=1, location=(0, 0, 0))
table = bpy.context.object; table.scale = (SW * 1.6, SH * 1.6, 1)
table.data.materials.append(marble())

# ---------------------------------------------------------------- light: a window, its frame casting bars
sun_d = bpy.data.lights.new("sun", 'SUN'); sun_d.energy = 1.6; sun_d.angle = math.radians(5); sun_d.color = (1.0, 0.93, 0.82)
sun = bpy.data.objects.new("sun", sun_d)
sun.rotation_euler = Vector((0.75, -0.55, -1.0)).to_track_quat('-Z', 'Y').to_euler()
sc.collection.objects.link(sun)
# window mullions: thin bars high above, only casting shadows
for k in range(-2, 3):
    bpy.ops.mesh.primitive_cube_add(size=1, location=(k * 5.5 - 2, 2, 8))
    b = bpy.context.object; b.scale = (1.6, 30, 0.1); b.rotation_euler = (0, 0, math.radians(-35))
    b.visible_camera = False; b.visible_glossy = False; b.visible_diffuse = False
w = bpy.data.worlds.new("w"); w.use_nodes = True; sc.world = w
w.node_tree.nodes["Background"].inputs[0].default_value = (0.85, 0.88, 0.95, 1)
w.node_tree.nodes["Background"].inputs[1].default_value = 0.9

# ---------------------------------------------------------------- crystal clusters in the corners
def glass(col, smoky=0.0):
    m = bpy.data.materials.new("q"); m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (*col, 1)
    p.inputs["Transmission Weight"].default_value = 1.0
    p.inputs["Roughness"].default_value = 0.18
    p.inputs["IOR"].default_value = 1.45
    p.inputs["Subsurface Weight"].default_value = 0.4
    p.inputs["Subsurface Radius"].default_value = (0.5, 0.5, 0.5)
    vol = m.node_tree.nodes.new("ShaderNodeVolumeAbsorption")
    vol.inputs["Color"].default_value = (*col, 1); vol.inputs["Density"].default_value = smoky
    m.node_tree.links.new(vol.outputs[0], m.node_tree.nodes["Material Output"].inputs["Volume"])
    return m

def crystal(base, d, h, r, m):
    pts = []
    for k in range(6):
        a = k / 6 * math.tau
        pts.append(Vector((math.cos(a) * r, math.sin(a) * r, 0)))
        pts.append(Vector((math.cos(a) * r, math.sin(a) * r, h)))
    pts.append(Vector((0, 0, h + r * 1.6)))
    me = bpy.data.meshes.new("c"); bm = bmesh.new()
    for p in pts: bm.verts.new(p)
    bmesh.ops.convex_hull(bm, input=bm.verts); bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new("c", me); sc.collection.objects.link(o)
    o.location = base
    o.rotation_euler = Vector((0, 0, 1)).rotation_difference(d).to_euler()
    o.data.materials.append(m)

def cluster(cx, cy, n, mats, size=1.0):
    rock = bpy.data.materials.new("rock"); rock.use_nodes = True
    rock.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.62, 0.58, 0.52, 1)
    rock.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.9
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, radius=0.9 * size, location=(cx, cy, 0))
    o = bpy.context.object; o.scale = (1.3, 1, 0.45)
    tx = bpy.data.textures.new("t", 'CLOUDS'); tx.noise_scale = 0.4
    dm = o.modifiers.new("d", 'DISPLACE'); dm.texture = tx; dm.strength = 0.4
    o.data.materials.append(rock)
    for k in range(n):
        a = random.uniform(0, math.tau); rr = random.uniform(0, 0.7) * size
        base = Vector((cx + math.cos(a) * rr, cy + math.sin(a) * rr, 0.15 * size))
        d = Vector((math.cos(a) * random.uniform(0.2, 0.9), math.sin(a) * random.uniform(0.2, 0.9), 1.0)).normalized()
        crystal(base, d, random.uniform(0.5, 1.6) * size, random.uniform(0.12, 0.28) * size, random.choice(mats))

clear = glass((0.95, 0.96, 0.98), 0.05)
smoke = glass((0.85, 0.65, 0.42), 0.35)
cluster(-SW * 0.5 + 0.3, SH * 0.5 - 3.0, 22, [clear, clear, smoke], 1.7)
cluster(SW * 0.5 - 0.2, SH * 0.5 - 6.0, 20, [clear, smoke, smoke], 1.6)

# ---------------------------------------------------------------- leaves: a blurred sprig in a lower corner, near the lens
leaf_m = bpy.data.materials.new("leaf"); leaf_m.use_nodes = True
lp = leaf_m.node_tree.nodes["Principled BSDF"]
lp.inputs["Base Color"].default_value = (0.1, 0.22, 0.08, 1); lp.inputs["Roughness"].default_value = 0.5
lp.inputs["Subsurface Weight"].default_value = 0.3
for k in range(14):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.5, location=(-SW * 0.5 + random.uniform(-0.3, 1.6), -SH * 0.5 + random.uniform(-0.3, 1.8), random.uniform(2.0, 3.2)))
    o = bpy.context.object; o.scale = (2.0, 0.9, 0.12); o.rotation_euler = (random.uniform(-0.5, 0.5), random.uniform(-0.5, 0.5), random.uniform(0, math.tau))
    o.data.materials.append(leaf_m)

# ---------------------------------------------------------------- camera: straight down, shallow depth of field on the leaves
cd = bpy.data.cameras.new("cam"); cd.type = 'ORTHO'; cd.ortho_scale = SH
cam = bpy.data.objects.new("cam", cd); cam.location = (0, 0, 20)
sc.collection.objects.link(cam); sc.camera = cam
sc.render.filepath = OUT
bpy.ops.render.render(write_still=True)
print("DONE", OUT)
