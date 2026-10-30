# Proval's ice over a frozen stone (BoardModel LOCK 4 / 5), in the look of the blockers (blocker_kit.py): a hewn block of
# clear ice a little bigger than a gem, rendered as see-through glass over a transparent film - the stone under it shows
# through in the game, the facets' edges catch the lamp, frost dulls them towards the rim. After the first blow it is
# split in three pieces with white crazed gaps, like the granite; the same pieces fly off as shards.
#   blender -b -P ice_kit.py -- <out_dir> [px] [samples]
# writes <out_dir>/ice.png, ice_cracked.png, shards/ice_0..2.png
import bpy, sys, os, math, random, importlib.util
from mathutils import Vector
argv = sys.argv[sys.argv.index("--") + 1:]
OUT = argv[0]
PX = int(argv[1]) if len(argv) > 1 else 256
SAMPLES = int(argv[2]) if len(argv) > 2 else 192
_real = sys.argv
sys.argv = ["blender", "--", OUT, str(PX), str(SAMPLES), "none"]
_spec = importlib.util.spec_from_file_location("blocker_kit", os.path.join(os.path.dirname(__file__), "blocker_kit.py"))
bk = importlib.util.module_from_spec(_spec)
# blocker_kit renders its rocks when loaded unless ONLY names none of them
sys.argv = ["blender", "--", OUT, str(PX), str(SAMPLES), "none"]
_spec.loader.exec_module(bk)
sys.argv = _real
gk = bk.gk
bk.SIZE = 0.97          # the ice covers the gem under it, almost the whole cell

def scene():
    sc = bk.lit_scene()
    sc.cycles.film_transparent_glass = True
    sc.cycles.film_transparent_roughness = 0.35
    sc.cycles.max_bounces = 16
    sc.cycles.transmission_bounces = 12
    return sc

def ice_mat():
    m = bpy.data.materials.new("ice"); m.use_nodes = True
    n = m.node_tree; L = n.links; nd = n.nodes.new
    out = n.nodes["Material Output"]
    p = n.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (0.78, 0.92, 1.0, 1)
    p.inputs["Transmission Weight"].default_value = 1.0
    p.inputs["IOR"].default_value = 1.31
    # frost: rough and milky in patches, clear in between
    tc = nd("ShaderNodeTexCoord")
    nz = nd("ShaderNodeTexNoise"); nz.inputs["Scale"].default_value = 9.0; nz.inputs["Detail"].default_value = 6.0
    L.new(tc.outputs["Object"], nz.inputs["Vector"])
    rr = nd("ShaderNodeMapRange"); rr.inputs["From Min"].default_value = 0.45; rr.inputs["From Max"].default_value = 0.7
    rr.inputs["To Min"].default_value = 0.04; rr.inputs["To Max"].default_value = 0.35
    L.new(nz.outputs["Fac"], rr.inputs["Value"]); L.new(rr.outputs[0], p.inputs["Roughness"])
    # the rim of every facet turned away from us goes white with rime (layer weight), mixed over the glass
    lw = nd("ShaderNodeLayerWeight"); lw.inputs["Blend"].default_value = 0.35
    rim = nd("ShaderNodeMapRange"); rim.inputs["From Min"].default_value = 0.55; rim.inputs["From Max"].default_value = 0.95
    rim.inputs["To Min"].default_value = 0.0; rim.inputs["To Max"].default_value = 0.85
    L.new(lw.outputs["Facing"], rim.inputs["Value"])
    fr = nd("ShaderNodeBsdfDiffuse"); fr.inputs["Color"].default_value = (0.86, 0.94, 1.0, 1)
    mx = nd("ShaderNodeMixShader")
    L.new(rim.outputs[0], mx.inputs[0]); L.new(p.outputs[0], mx.inputs[1]); L.new(fr.outputs[0], mx.inputs[2])
    L.new(mx.outputs[0], out.inputs["Surface"])
    return m

def cracked_mat():
    """the faces of the cracks: white crazed ice"""
    m = bpy.data.materials.new("crack"); m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (0.9, 0.96, 1.0, 1)
    p.inputs["Roughness"].default_value = 0.25
    p.inputs["Transmission Weight"].default_value = 0.85
    return m

def render(name, objs, ref=None):
    bpy.context.view_layer.update()
    bk.size_up(objs, ref)
    path = os.path.join(OUT, name + ".png")
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    body(path)
    print("ICE", name)

def body(path):
    """the see-through film keeps only the glints: lay a pale blue body of ice under them inside the block's outline,
    so the stone reads as frozen in (brighter towards the top left, like the lamp)"""
    im = bpy.data.images.load(path)
    w, h = im.size
    px = list(im.pixels)
    a = [px[i * 4 + 3] for i in range(w * h)]
    rows = []
    for y in range(h):
        xs = [x for x in range(w) if a[y * w + x] > 0.04]
        rows.append((min(xs), max(xs)) if xs else None)
    for y in range(h):
        r = rows[y]
        if not r: continue
        for x in range(r[0], r[1] + 1):
            i = (y * w + x) * 4
            g = 0.5 + 0.5 * ((x / w) * -0.6 + (y / h) * 0.6)      # y counts up from the bottom in Blender's pixels
            fa = 0.2 + 0.08 * g
            fc = (0.62 + 0.12 * g, 0.84 + 0.08 * g, 1.0)
            sa = px[i + 3]
            oa = sa + fa * (1 - sa)
            for c in range(3):
                px[i + c] = (px[i + c] * sa + fc[c] * fa * (1 - sa)) / max(oa, 1e-4)
            px[i + 3] = oa
    im.pixels = px
    im.save()

SEED = 21
def block():
    return gk.block_planes(70, SEED, 0.38, 0.3, 0.36, 4.0, (0.0, 0.03))

os.makedirs(os.path.join(OUT, "shards"), exist_ok=True)
scene(); M = ice_mat()
o = gk.cut(block(), SEED, (0.9, 1.05)); o.data.materials.append(M)
render("ice", [o])
def pieces():
    out = []
    for k, (cuts, d) in enumerate(bk.split_planes(11)):
        p = gk.cut(block() + cuts, SEED + k, (0.9, 1.05))
        p.location = d * 0.009
        p.data.materials.append(M); p.data.materials.append(cracked_mat())
        # the faces along the cracks get the crazed material
        for f in p.data.polygons:
            c = Vector(f.center)
            if c.length < 0.26 and abs(f.normal.y) < 0.6: f.material_index = 1
        out.append(p)
    return out
scene(); M = ice_mat()
ps = pieces(); render("ice_cracked", ps)
for k in range(3):
    scene(); M = ice_mat()
    ps = pieces()
    for j, p in enumerate(ps):
        if j != k: p.hide_render = True
    render("shards/ice_%d" % k, ps)
