# Bakes a seamless "moss bed" texture from Poly Haven's scanned moss sprigs (CC0):
# thousands of sprigs scattered over a square tile (wrapped at the borders so it tiles),
# rendered straight down three times: colour (lit by an even sky, so the shading between sprigs is baked in),
# normals and height. Usage:
#   blender -b -P bake_moss_bed.py -- <moss_01.gltf> <moss_01_diff_1k.png> <out_dir> [count] [res]
import bpy, sys, random, math, os
from mathutils import Vector, Euler

argv = sys.argv[sys.argv.index("--") + 1:]
GLTF, DIFF_PNG, OUT = argv[0], argv[1], argv[2]
COUNT = int(argv[3]) if len(argv) > 3 else 2600
RES = int(argv[4]) if len(argv) > 4 else 1024
T = 0.11          # tile size in metres
random.seed(7)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLTF)
sprigs = [o for o in bpy.context.scene.objects if o.type == 'MESH' and o.name.endswith("LOD0")]
for o in sprigs:
    o.location = (0, 0, 0)
    o.hide_render = True
    o.hide_viewport = True
mat = sprigs[0].data.materials[0]
mat.use_nodes = True
nt = mat.node_tree
bsdf = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
img = bpy.data.images.load(DIFF_PNG)
tex = nt.nodes.new("ShaderNodeTexImage")
tex.image = img
for l in list(bsdf.inputs["Base Color"].links): nt.links.remove(l)
nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
nt.links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
uvsrc = next((n for n in nt.nodes if n.type == 'TEX_IMAGE' and n is not tex), None)

# soil under the moss
bpy.ops.mesh.primitive_plane_add(size=T * 3, location=(T / 2, T / 2, -0.002))
soil = bpy.context.object
sm = bpy.data.materials.new("soil")
sm.use_nodes = True
sm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.03, 0.025, 0.015, 1)
soil.data.materials.append(sm)

col = bpy.data.collections.new("bed")
bpy.context.scene.collection.children.link(col)
def place(x, y, z, rot, s, src):
    o = bpy.data.objects.new("s", src.data)
    o.location = (x, y, z)
    o.rotation_euler = rot
    o.scale = (s, s, s)
    col.objects.link(o)
for i in range(COUNT):
    src = random.choice(sprigs)
    x, y = random.random() * T, random.random() * T
    z = random.random() * 0.004
    rot = Euler((random.uniform(-0.45, 0.45), random.uniform(-0.45, 0.45), random.uniform(0, 6.283)))
    s = random.uniform(0.75, 1.35)
    m = 0.03
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            xx, yy = x + dx * T, y + dy * T
            if -m <= xx <= T + m and -m <= yy <= T + m:
                place(xx, yy, z, rot, s, src)

cam_data = bpy.data.cameras.new("cam")
cam_data.type = 'ORTHO'
cam_data.ortho_scale = T
cam = bpy.data.objects.new("cam", cam_data)
cam.location = (T / 2, T / 2, 0.5)
bpy.context.scene.collection.objects.link(cam)
sc = bpy.context.scene
sc.camera = cam
sc.render.engine = 'CYCLES'
sc.cycles.samples = 48
sc.cycles.use_denoising = True
sc.render.resolution_x = RES
sc.render.resolution_y = RES
sc.render.film_transparent = False
sc.view_settings.view_transform = 'Standard'
world = bpy.data.worlds.new("w")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (1, 1, 1, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 1.0
sc.world = world

def render(path):
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)

# 1. colour under an even sky: albedo with the soft shading of the bed baked in
render(os.path.join(OUT, "moss_bed_diff.png"))

# 2/3. normals and height as emission, keeping the leaves cut out by their alpha
def emit_override(make_color):
    for m in [mat, sm]:
        t = m.node_tree
        out = next(n for n in t.nodes if n.type == 'OUTPUT_MATERIAL')
        em = t.nodes.new("ShaderNodeEmission")
        make_color(t, em)
        if m is mat:
            tr = t.nodes.new("ShaderNodeBsdfTransparent")
            mix = t.nodes.new("ShaderNodeMixShader")
            t.links.new(tex.outputs["Alpha"], mix.inputs["Fac"])
            t.links.new(tr.outputs[0], mix.inputs[1])
            t.links.new(em.outputs[0], mix.inputs[2])
            t.links.new(mix.outputs[0], out.inputs["Surface"])
        else:
            t.links.new(em.outputs[0], out.inputs["Surface"])
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.0
    sc.cycles.samples = 16

def normal_col(t, em):
    geo = t.nodes.new("ShaderNodeNewGeometry")
    vm = t.nodes.new("ShaderNodeVectorMath")
    vm.operation = 'MULTIPLY_ADD'
    vm.inputs[1].default_value = (0.5, 0.5, 0.5)
    vm.inputs[2].default_value = (0.5, 0.5, 0.5)
    t.links.new(geo.outputs["Normal"], vm.inputs[0])
    t.links.new(vm.outputs[0], em.inputs["Color"])
emit_override(normal_col)
render(os.path.join(OUT, "moss_bed_nrm.png"))

def height_col(t, em):
    for n in [n for n in t.nodes if n.type == 'EMISSION' and n is not em]:
        pass
    geo = t.nodes.new("ShaderNodeNewGeometry")
    sep = t.nodes.new("ShaderNodeSeparateXYZ")
    mr = t.nodes.new("ShaderNodeMapRange")
    mr.inputs["From Min"].default_value = -0.002
    mr.inputs["From Max"].default_value = 0.034
    t.links.new(geo.outputs["Position"], sep.inputs[0])
    t.links.new(sep.outputs["Z"], mr.inputs["Value"])
    t.links.new(mr.outputs["Result"], em.inputs["Color"])
emit_override(height_col)
render(os.path.join(OUT, "moss_bed_height.png"))
print("BAKED", OUT)
