# The board's stone kit for one mine: cell tiles, frame bars and the caps on their joints, as sprites in the
# same light as the gems. The game builds any board shape out of them (board_view.gd); a mine is a row in ROCKS.
# The shapes are fixed; the rock is a material: a photo scan gives the relief, the mine's palette the colour,
# then chipped light edges, grime in the hollows and rust (or ore) in the cracks on top.
#   blender -b -P board_kit.py -- <out_dir> <rock> [px_per_cell] [samples] [only]
# writes <out_dir>/<rock>/{tile0..2,bar_h,bar_v,cap}.png and kit.json (sizes, for the game)
import bpy, bmesh, sys, math, os, json, random
from mathutils import Vector, Matrix
argv = sys.argv[sys.argv.index("--") + 1:]
OUT = argv[0]
ROCK = argv[1]
P = int(argv[2]) if len(argv) > 2 else 192
SAMPLES = int(argv[3]) if len(argv) > 3 else 96
ONLY = argv[4].split(",") if len(argv) > 4 else None
PROJ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))

# sizes in cells
FW = 0.34            # frame bar width
FH = 0.20            # how far the frame stands above the tiles
CAP = 0.46           # the block on a joint
TILE = 0.94          # a tile; the rest of the cell is the dark gap between tiles
BAR_N = {"bar_h": 9, "bar_v": 10}   # long enough for the widest/tallest run (8 x 9 cells), so a run has no seam
MARGIN = 0.06        # transparent room round a piece for its chipped edge

SCANS = {
    "rock_face_03": "godot/assets/textures/rock_face_03/rock_face_03",
    "rock_face_04": "art/textures/rock_face_04/rock_face_04",
    "rock_06": "art/textures/rock_06/rock_06",
}
# the crack masks (prototype/tools/crack_maps.py) live with the board's own scans in art/textures
def crack_path(scan):
    return "art/textures/%s/%s_crack_1k.png" % (scan, scan)

# a mine's rock (optional keys: vein_all - every crack filled; cu - (colour, share) of the cracks filled with copper
# instead, as metal; fleck - metal grains; facets - hewn facets (scale, strength); sharp - light only on real edges;
# blocks - the frame hewn into blocks with this gap; tile/tile_h/tile_bevel/tile_chip - the tile's size, height, rounded rim, broken edge; bed_k - how dark the gap). scan: relief; dark/mid/light: the palette the scan's shading is mapped onto; edge: the chipped edges;
# grime: the hollows; vein: colour, metal and amount of what fills the cracks; speck: granite's grains (amount, colours)
ROCKS = {
    "basalt": dict(scan="rock_face_04", scale=0.55, dark=(0.025, 0.025, 0.027), mid=(0.075, 0.074, 0.072), light=(0.17, 0.165, 0.155),
                   edge=(0.42, 0.38, 0.32), grime=(0.01, 0.009, 0.008), vein=((0.13, 0.055, 0.02), 0.0, 0.7), speck=None,
                   tile_k=0.8, chip=0.02),
    "granite": dict(scan="rock_face_03", scale=0.5, dark=(0.16, 0.11, 0.09), mid=(0.36, 0.27, 0.22), light=(0.62, 0.5, 0.44),
                    edge=(0.8, 0.72, 0.64), grime=(0.04, 0.03, 0.025), vein=((0.18, 0.07, 0.04), 0.0, 0.5),
                    speck=(0.55, (0.02, 0.02, 0.022), (0.8, 0.4, 0.22), (0.85, 0.82, 0.78)), tile_k=0.55, chip=0.03),
    "sandstone": dict(scan="rock_06", scale=0.45, dark=(0.2, 0.11, 0.04), mid=(0.48, 0.3, 0.13), light=(0.78, 0.58, 0.32),
                      edge=(0.92, 0.78, 0.55), grime=(0.06, 0.03, 0.01), vein=((0.3, 0.14, 0.04), 0.0, 0.6), speck=None,
                      tile_k=0.9, chip=0.03),
    "goldvein": dict(scan="rock_face_04", scale=0.55, dark=(0.025, 0.025, 0.027), mid=(0.075, 0.074, 0.072), light=(0.17, 0.165, 0.155),
                     edge=(0.42, 0.38, 0.32), grime=(0.01, 0.009, 0.008), vein=((1.0, 0.7, 0.25), 1.0, 1.0), speck=None,
                     tile_k=0.8, chip=0.02),
    # Copper Mountain: grey-green serpentine, malachite in the cracks, flecks of native copper
    "serpentine": dict(scan="rock_face_04", scale=0.55, dark=(0.04, 0.042, 0.04), mid=(0.13, 0.135, 0.128), light=(0.32, 0.33, 0.31),
                       edge=(0.5, 0.5, 0.47), grime=(0.008, 0.009, 0.008), vein=((0.03, 0.62, 0.42), 0.0, 1.0), speck=None,
                       vein_sharp=(0.35, 0.75), cu=((1.0, 0.56, 0.3), 0.3), facets=(11.0, 0.55), sharp=0.53, tile_h=0.1, tile_bevel=0.07,
                       tile=0.975, tile_chip=1.4, blocks=-0.004, bed_k=0.9, tile_k=1.0, chip=0.025),
    # boss frame: the Great Poloz' brown-grey stone with gold in the cracks
    "poloz": dict(scan="rock_face_03", scale=0.5, dark=(0.05, 0.04, 0.03), mid=(0.16, 0.13, 0.1), light=(0.36, 0.3, 0.24),
                  edge=(0.6, 0.5, 0.38), grime=(0.015, 0.012, 0.01), vein=((1.0, 0.68, 0.22), 1.0, 0.9), speck=None,
                  tile_k=0.6, chip=0.03),
}
R = ROCKS[ROCK]

def setup(w, h, scale):
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
    wd.node_tree.nodes["Background"].inputs[1].default_value = 0.35
    # the same key light as the gems (gem_sprites.py / board_sprites.py)
    d = bpy.data.lights.new("sun", 'SUN'); d.energy = 3.0; d.angle = math.radians(8); d.color = (1.0, 0.96, 0.9)
    s = bpy.data.objects.new("sun", d)
    s.rotation_euler = Vector((0.55, -0.6, -1.0)).to_track_quat('-Z', 'Y').to_euler()
    sc.collection.objects.link(s)
    cd = bpy.data.cameras.new("cam"); cd.type = 'ORTHO'; cd.ortho_scale = scale
    cam = bpy.data.objects.new("cam", cd); cam.location = (0, 0, 10)
    sc.collection.objects.link(cam); sc.camera = cam
    return sc

def img(path, data=True):
    i = bpy.data.images.load(os.path.join(PROJ, path))
    if data: i.colorspace_settings.name = 'Non-Color'
    return i

def stone(name, offset, tile=False):
    """the mine's rock: scan relief and shading recoloured with the palette, chipped edges, grime, veins"""
    m = bpy.data.materials.new(name); m.use_nodes = True
    n = m.node_tree; L = n.links; nd = n.nodes.new
    p = n.nodes["Principled BSDF"]
    base = SCANS[R["scan"]]
    tc = nd("ShaderNodeTexCoord")
    mp = nd("ShaderNodeMapping")
    mp.inputs["Location"].default_value = offset
    mp.inputs["Scale"].default_value = (R["scale"] * (1.6 if tile else 1.0),) * 3
    L.new(tc.outputs["Object"], mp.inputs["Vector"])
    def scan(suffix, data=True, path=None):
        t = nd("ShaderNodeTexImage"); t.image = img(path or base + "_%s_1k.jpg" % suffix, data)
        t.projection = 'BOX'; t.projection_blend = 0.3
        L.new(mp.outputs[0], t.inputs["Vector"])
        return t
    diff = scan("diff", False)
    # the scan's own light and dark, not its colour: the palette decides the colour
    bw = nd("ShaderNodeRGBToBW"); L.new(diff.outputs["Color"], bw.inputs[0])
    lv = nd("ShaderNodeMapRange"); lv.inputs["From Min"].default_value = 0.08; lv.inputs["From Max"].default_value = 0.55
    L.new(bw.outputs[0], lv.inputs["Value"])
    ramp = nd("ShaderNodeValToRGB"); cr = ramp.color_ramp
    k = R["tile_k"] if tile else 1.0
    cr.elements[0].color = (*[c * k for c in R["dark"]], 1)
    cr.elements[1].color = (*[c * k for c in R["light"]], 1)
    mid = cr.elements.new(0.5); mid.color = (*[c * k for c in R["mid"]], 1)
    L.new(lv.outputs[0], ramp.inputs["Fac"])
    col = ramp.outputs[0]
    if R["speck"]:
        # granite: grains of black mica, pink feldspar and milky quartz
        amt, c1, c2, c3 = R["speck"]
        vo = nd("ShaderNodeTexVoronoi"); vo.inputs["Scale"].default_value = 26.0 if not tile else 30.0
        vo.inputs["Randomness"].default_value = 1.0
        L.new(mp.outputs[0], vo.inputs["Vector"])
        sr = nd("ShaderNodeValToRGB"); e = sr.color_ramp.elements
        e[0].position = 0.0; e[0].color = (*c1, 1); e[1].position = 0.75; e[1].color = (*c3, 1)
        e2 = sr.color_ramp.elements.new(0.33); e2.color = (*c2, 1)
        sr.color_ramp.interpolation = 'CONSTANT'
        L.new(vo.outputs["Color"], sr.inputs["Fac"])
        nz = nd("ShaderNodeTexNoise"); nz.inputs["Scale"].default_value = 40.0
        L.new(mp.outputs[0], nz.inputs["Vector"])
        gate = nd("ShaderNodeMapRange"); gate.inputs["From Min"].default_value = 0.42; gate.inputs["From Max"].default_value = 0.6
        gate.inputs["To Max"].default_value = amt * (0.45 if tile else 1.0)   # calmer under the gems
        L.new(nz.outputs["Fac"], gate.inputs["Value"])
        # the grains keep some of the scan's shading
        mm = nd("ShaderNodeMix"); mm.data_type = 'RGBA'
        L.new(gate.outputs[0], mm.inputs["Factor"]); L.new(col, mm.inputs["A"])
        sh = nd("ShaderNodeMix"); sh.data_type = 'RGBA'; sh.blend_type = 'MULTIPLY'; sh.inputs["Factor"].default_value = 1.0
        L.new(sr.outputs[0], sh.inputs["A"]); L.new(lv.outputs[0], sh.inputs["B"])
        gain = nd("ShaderNodeMix"); gain.data_type = 'RGBA'; gain.blend_type = 'MIX'
        L.new(sr.outputs[0], gain.inputs["A"]); L.new(sh.outputs[2], gain.inputs["B"]); gain.inputs["Factor"].default_value = 0.4
        L.new(gain.outputs[2], mm.inputs["B"])
        col = mm.outputs[2]
    # cracks: the dark lines of the scan, filled with rust (or with ore)
    vc, vmetal, vamt = R["vein"]
    crack = scan("crack", path=crack_path(R["scan"]))
    cv = nd("ShaderNodeMapRange"); cv.inputs["To Max"].default_value = vamt
    if R.get("vein_sharp"):
        # only the crack's core: thin lines, not a blur
        cv.inputs["From Min"].default_value, cv.inputs["From Max"].default_value = R["vein_sharp"]
    L.new(crack.outputs["Color"], cv.inputs["Value"])
    # not every crack holds something: patches of it
    vn = nd("ShaderNodeTexNoise"); vn.inputs["Scale"].default_value = 4.0
    L.new(mp.outputs[0], vn.inputs["Vector"])
    vg = nd("ShaderNodeMath"); vg.operation = 'MULTIPLY'
    vs = nd("ShaderNodeMapRange"); vs.inputs["From Min"].default_value = 0.38; vs.inputs["From Max"].default_value = 0.55
    L.new(vn.outputs["Fac"], vs.inputs["Value"])
    L.new(cv.outputs[0], vg.inputs[0])
    if R.get("vein_all"): vg.inputs[1].default_value = 1.0
    else: L.new(vs.outputs[0], vg.inputs[1])
    vfac = vg.outputs[0]
    cu = None
    if R.get("cu"):
        # some cracks hold native copper instead: the same lines, in stretches, shining as metal
        cc, share = R["cu"]
        cn = nd("ShaderNodeTexNoise"); cn.inputs["Scale"].default_value = 2.6; cn.inputs["Detail"].default_value = 1
        L.new(mp.outputs[0], cn.inputs["Vector"])
        sel = nd("ShaderNodeMapRange"); sel.inputs["From Min"].default_value = 0.5 - share * 0.1 + 0.02
        sel.inputs["From Max"].default_value = 0.5 - share * 0.1 + 0.04
        L.new(cn.outputs["Fac"], sel.inputs["Value"])
        cu = nd("ShaderNodeMath"); cu.operation = 'MULTIPLY'; L.new(vg.outputs[0], cu.inputs[0]); L.new(sel.outputs[0], cu.inputs[1])
        tq = nd("ShaderNodeMath"); tq.operation = 'SUBTRACT'; L.new(vg.outputs[0], tq.inputs[0]); L.new(cu.outputs[0], tq.inputs[1])
        vfac = tq.outputs[0]
    mv = nd("ShaderNodeMix"); mv.data_type = 'RGBA'
    L.new(vfac, mv.inputs["Factor"]); L.new(col, mv.inputs["A"]); mv.inputs["B"].default_value = (*vc, 1)
    col = mv.outputs[2]
    if cu:
        mc = nd("ShaderNodeMix"); mc.data_type = 'RGBA'
        L.new(cu.outputs[0], mc.inputs["Factor"]); L.new(col, mc.inputs["A"]); mc.inputs["B"].default_value = (*cc, 1)
        col = mc.outputs[2]
    fl = cu
    if R.get("fleck"):
        # native copper: irregular metal grains here and there, shining like metal
        famt, fc = R["fleck"]
        fw = nd("ShaderNodeTexNoise"); fw.inputs["Scale"].default_value = 30.0; fw.inputs["Detail"].default_value = 3
        L.new(mp.outputs[0], fw.inputs["Vector"])
        fwm = nd("ShaderNodeMix"); fwm.data_type = 'VECTOR'; fwm.inputs["Factor"].default_value = 0.12
        L.new(mp.outputs[0], fwm.inputs[4]); L.new(fw.outputs["Color"], fwm.inputs[5])
        fv = nd("ShaderNodeTexVoronoi"); fv.inputs["Scale"].default_value = 6.0
        L.new(fwm.outputs[1], fv.inputs["Vector"])
        fd = nd("ShaderNodeMapRange"); fd.inputs["From Min"].default_value = 0.24; fd.inputs["From Max"].default_value = 0.19
        L.new(fv.outputs["Distance"], fd.inputs["Value"])
        fr = nd("ShaderNodeMapRange"); fr.inputs["From Min"].default_value = 0.76; fr.inputs["From Max"].default_value = 0.77
        L.new(fv.outputs["Color"], fr.inputs["Value"])   # only some cells hold a grain
        f1 = nd("ShaderNodeMath"); f1.operation = 'MULTIPLY'; L.new(fd.outputs[0], f1.inputs[0]); L.new(fr.outputs[0], f1.inputs[1])
        fl = nd("ShaderNodeMath"); fl.operation = 'MULTIPLY'; L.new(f1.outputs[0], fl.inputs[0]); fl.inputs[1].default_value = famt
        mf = nd("ShaderNodeMix"); mf.data_type = 'RGBA'
        L.new(fl.outputs[0], mf.inputs["Factor"]); L.new(col, mf.inputs["A"]); mf.inputs["B"].default_value = (*fc, 1)
        col = mf.outputs[2]
    # grime settles where light does not reach
    ao = nd("ShaderNodeAmbientOcclusion"); ao.inputs["Distance"].default_value = 0.06; ao.samples = 8
    gm = nd("ShaderNodeMapRange"); gm.inputs["From Min"].default_value = 1.0; gm.inputs["From Max"].default_value = 0.4
    gm.inputs["To Max"].default_value = 0.75
    L.new(ao.outputs["AO"], gm.inputs["Value"])
    mg = nd("ShaderNodeMix"); mg.data_type = 'RGBA'
    L.new(gm.outputs[0], mg.inputs["Factor"]); L.new(col, mg.inputs["A"]); mg.inputs["B"].default_value = (*R["grime"], 1)
    col = mg.outputs[2]
    # chipped edges: worn lighter where the stone sticks out, broken up by noise
    geo = nd("ShaderNodeNewGeometry")
    ed = nd("ShaderNodeMapRange"); ed.inputs["From Min"].default_value = R.get("sharp", 0.505); ed.inputs["From Max"].default_value = R.get("sharp", 0.505) + 0.045
    L.new(geo.outputs["Pointiness"], ed.inputs["Value"])
    en = nd("ShaderNodeTexNoise"); en.inputs["Scale"].default_value = 30.0; en.inputs["Detail"].default_value = 6
    L.new(mp.outputs[0], en.inputs["Vector"])
    eb = nd("ShaderNodeMapRange"); eb.inputs["From Min"].default_value = 0.4; eb.inputs["From Max"].default_value = 0.6
    L.new(en.outputs["Fac"], eb.inputs["Value"])
    ek = nd("ShaderNodeMath"); ek.operation = 'MULTIPLY'
    L.new(ed.outputs[0], ek.inputs[0]); L.new(eb.outputs[0], ek.inputs[1])
    ek2 = nd("ShaderNodeMath"); ek2.operation = 'MULTIPLY'; ek2.inputs[1].default_value = 1.0
    L.new(ek.outputs[0], ek2.inputs[0])
    me = nd("ShaderNodeMix"); me.data_type = 'RGBA'
    L.new(ek2.outputs[0], me.inputs["Factor"]); L.new(col, me.inputs["A"]); me.inputs["B"].default_value = (*R["edge"], 1)
    L.new(me.outputs[2], p.inputs["Base Color"])
    # surface: the scan's roughness and fine relief; ore in the veins shines like metal
    rough = scan("rough")
    rr = nd("ShaderNodeMapRange"); rr.inputs["To Min"].default_value = 0.55; rr.inputs["To Max"].default_value = 0.95
    L.new(rough.outputs["Color"], rr.inputs["Value"])
    if vmetal > 0:
        rm = nd("ShaderNodeMix"); rm.data_type = 'FLOAT'
        L.new(vg.outputs[0], rm.inputs["Factor"]); L.new(rr.outputs[0], rm.inputs["A"]); rm.inputs["B"].default_value = 0.25
        L.new(rm.outputs[0], p.inputs["Roughness"])
        L.new(vg.outputs[0], p.inputs["Metallic"])
    elif fl:
        rm = nd("ShaderNodeMix"); rm.data_type = 'FLOAT'
        L.new(fl.outputs[0], rm.inputs["Factor"]); L.new(rr.outputs[0], rm.inputs["A"]); rm.inputs["B"].default_value = 0.3
        L.new(rm.outputs[0], p.inputs["Roughness"])
        fm = nd("ShaderNodeMath"); fm.operation = 'MULTIPLY'; fm.inputs[1].default_value = 0.65
        L.new(fl.outputs[0], fm.inputs[0]); L.new(fm.outputs[0], p.inputs["Metallic"])
    else:
        L.new(rr.outputs[0], p.inputs["Roughness"])
    nm = nd("ShaderNodeNormalMap"); nm.inputs["Strength"].default_value = 1.2
    L.new(scan("nor_gl").outputs["Color"], nm.inputs["Color"])
    if R.get("facets"):
        # hewn: the face broken into small flat facets, their ridges catching the light
        fsc, fst = R["facets"]
        fvo = nd("ShaderNodeTexVoronoi"); fvo.feature = 'DISTANCE_TO_EDGE'; fvo.inputs["Scale"].default_value = fsc * (1.3 if tile else 1.0)
        L.new(mp.outputs[0], fvo.inputs["Vector"])
        fb = nd("ShaderNodeBump"); fb.inputs["Strength"].default_value = fst; fb.inputs["Distance"].default_value = 0.05
        L.new(fvo.outputs["Distance"], fb.inputs["Height"]); L.new(nm.outputs[0], fb.inputs["Normal"])
        L.new(fb.outputs[0], p.inputs["Normal"])
    else:
        L.new(nm.outputs[0], p.inputs["Normal"])
    return m

def chip(o, seed, strength):
    """dense, even mesh, then broken-flake relief: the stone looks hewn, its edges chipped"""
    rm = o.modifiers.new("remesh", 'REMESH'); rm.mode = 'VOXEL'; rm.voxel_size = 0.006
    tx = bpy.data.textures.new("chip%d" % seed, 'VORONOI')
    tx.distance_metric = 'DISTANCE'; tx.noise_scale = 0.07; tx.weight_1 = 1.0; tx.weight_2 = -0.4
    em = bpy.data.objects.new("chip_e%d" % seed, None); em.location = (seed * 3.7, seed * 1.3, 0)
    bpy.context.scene.collection.objects.link(em)
    d = o.modifiers.new("chip", 'DISPLACE'); d.texture = tx; d.strength = strength; d.mid_level = 0.6
    d.texture_coords = 'OBJECT'; d.texture_coords_object = em
    tx2 = bpy.data.textures.new("grain%d" % seed, 'CLOUDS'); tx2.noise_scale = 0.03; tx2.noise_depth = 2
    d2 = o.modifiers.new("grain", 'DISPLACE'); d2.texture = tx2; d2.strength = strength * 0.3
    d2.texture_coords = 'OBJECT'; d2.texture_coords_object = em
    bpy.ops.object.shade_smooth()

def block(size, z0, h, bevel, name, offset, seed, tile=False, chamfer_corners=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, z0 + h / 2))
    o = bpy.context.object; o.name = name
    o.scale = (size[0], size[1], h)
    bpy.ops.object.transform_apply(scale=True)
    if chamfer_corners > 0:
        # the vertical corners cut off at 45 degrees: an octagonal cap
        b0 = o.modifiers.new("corners", 'BEVEL'); b0.width = chamfer_corners; b0.segments = 1
        b0.limit_method = 'VGROUP'
        vg = o.vertex_groups.new(name="all")
        vg.add([v.index for v in o.data.vertices], 1.0, 'REPLACE')
        b0.vertex_group = "all"; b0.affect = 'EDGES'
        bpy.ops.object.modifier_apply(modifier="corners")
    b = o.modifiers.new("bevel", 'BEVEL'); b.width = bevel; b.segments = (4 if R.get("tile_bevel") else 2) if tile else 1
    b.limit_method = 'ANGLE'
    bpy.ops.object.modifier_apply(modifier="bevel")
    o.data.materials.append(stone(name, offset, tile))
    chip(o, seed, R["chip"] * (R.get("tile_chip", 0.5) if tile else 1.0))
    return o

def render(name, w_cells, h_cells, build):
    w = round((w_cells + MARGIN * 2) * P); h = round((h_cells + MARGIN * 2) * P)
    sc = setup(w, h, max(w, h) / P)
    build()
    sc.render.filepath = os.path.join(OUT, ROCK, name + ".png")
    bpy.ops.render.render(write_still=True)
    print("KIT", ROCK, name, w, h)

def tile(k):
    render("tile%d" % k, 1.0, 1.0, lambda: block((R.get("tile", TILE),) * 2, 0.0, R.get("tile_h", 0.06), R.get("tile_bevel", 0.03), "tile",
                                                   (k * 1.7, k * 2.9, 0), 50 + k, tile=True))

def hewn(lo, hi, planes, bevel, name, offset, seed, segs=2):
    """a hewn stone: the box lo..hi sliced by planes [(point, outward normal)], edges rounded and chipped"""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector([lo[i] + (hi[i] - lo[i]) * (v.co[i] + 0.5) for i in range(3)])
    for co, no in planes:
        geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
        bmesh.ops.bisect_plane(bm, geom=geom, plane_co=co, plane_no=no, clear_outer=True, dist=1e-6)
        bmesh.ops.holes_fill(bm, edges=bm.edges[:], sides=0)
    # what is left is convex: its hull is the clean solid
    pts = [v.co.copy() for v in bm.verts]; bm.free()
    bm = bmesh.new()
    for q in pts: bm.verts.new(q)
    bmesh.ops.convex_hull(bm, input=bm.verts)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.002)
    bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(2.0), verts=bm.verts, edges=bm.edges)
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(o)
    bpy.context.view_layer.objects.active = o; o.select_set(True)
    b = o.modifiers.new("bevel", 'BEVEL'); b.width = bevel; b.segments = segs; b.limit_method = 'ANGLE'
    bpy.ops.object.modifier_apply(modifier="bevel")
    o.data.materials.append(stone(name, offset))
    chip(o, seed, R["chip"])
    o.select_set(False)
    return o

def hewn_bar(n, name, seed):
    """the frame as a row of hewn blocks of uneven length, cut at a slant, with dark cracks between them"""
    rnd = random.Random(seed)
    cuts = [-n / 2 - 0.5]
    while cuts[-1] < n / 2 + 0.5:
        cuts.append(cuts[-1] + rnd.uniform(0.6, 1.15))
    slant = [Vector((1.0, rnd.uniform(-0.45, 0.45), 0.0)).normalized() for _ in cuts]
    gap = R["blocks"]
    # a dark bed under the blocks: the cracks between them read dark, not as holes
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 0.02))
    bed = bpy.context.object; bed.scale = (n + 1.0, FW * 0.9, 0.04)
    m = bpy.data.materials.new("bed"); m.use_nodes = True
    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*[c * 0.5 for c in R["dark"]], 1)
    m.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.9
    bed.data.materials.append(m); bed.select_set(False)
    for k in range(len(cuts) - 1):
        h = FH * rnd.uniform(0.86, 1.06)
        planes = [(Vector((cuts[k] + gap / 2, 0, 0)), -slant[k]), (Vector((cuts[k + 1] - gap / 2, 0, 0)), slant[k + 1])]
        # the outer and inner sides not dead straight
        for side in (-1, 1):
            planes.append((Vector(((cuts[k] + cuts[k + 1]) / 2, side * FW / 2 * rnd.uniform(0.94, 1.0), 0)),
                           Vector((rnd.uniform(-0.08, 0.08), side, rnd.uniform(0.0, 0.25))).normalized()))
        planes.append((Vector(((cuts[k] + cuts[k + 1]) / 2, 0, h)), Vector((rnd.uniform(-0.05, 0.05), rnd.uniform(-0.05, 0.05), 1)).normalized()))
        hewn((cuts[k] - 0.5, -FW / 2, 0.0), (cuts[k + 1] + 0.5, FW / 2, h + 0.05), planes, 0.018, name,
             (0.4 + k * 1.3, 0.8 + k * 0.7, 0), seed * 31 + k)

def bar(name):
    n = BAR_N[name]
    def build():
        if R.get("blocks"):
            hewn_bar(n, name, 7 if name == "bar_h" else 8)
            if name == "bar_v":
                for o in bpy.context.scene.objects:
                    if o.type == 'MESH':
                        o.matrix_world = Matrix.Rotation(math.pi / 2, 4, 'Z') @ o.matrix_world
            return
        o = block((n, FW), 0.0, FH, 0.095, name, (0.4, 0.8, 0), 7 if name == "bar_h" else 8)
        if name == "bar_v":
            o.rotation_euler = (0, 0, math.pi / 2)
    if name == "bar_h": render(name, n, FW, build)
    else: render(name, FW, n, build)

def cap():
    if R.get("blocks"):
        # the corner stone: a block a little wider than the bars, as tall, its corners worn round
        rnd = random.Random(9)
        w = FW * 1.15; h = FH * 1.02
        planes = []
        for k in range(8):
            a = k / 8 * math.tau
            d = Vector((math.cos(a), math.sin(a), 0.0))
            far = w / 2 * (1.0 if k % 2 == 0 else 1.3) * rnd.uniform(0.96, 1.0)   # sides, then the corners cut back
            planes.append((d * far, d))
        planes.append((Vector((0, 0, h)), Vector((rnd.uniform(-0.03, 0.03), rnd.uniform(-0.03, 0.03), 1)).normalized()))
        render("cap", CAP, CAP, lambda: hewn((-w / 2, -w / 2, 0), (w / 2, w / 2, h + 0.05), planes, 0.045, "cap", (3.1, 0.2, 0), 9, segs=4))
        return
    render("cap", CAP, CAP, lambda: block((CAP, CAP), 0.0, FH + 0.05, 0.1, "cap", (3.1, 0.2, 0), 9, chamfer_corners=CAP * 0.22))

JOBS = {"tile0": lambda: tile(0), "tile1": lambda: tile(1), "tile2": lambda: tile(2),
        "bar_h": lambda: bar("bar_h"), "bar_v": lambda: bar("bar_v"), "cap": cap}
os.makedirs(os.path.join(OUT, ROCK), exist_ok=True)
for name, fn in JOBS.items():
    if ONLY and name not in ONLY: continue
    fn()
with open(os.path.join(OUT, ROCK, "kit.json"), "w") as f:
    # the bed between the tiles: the rock's darkest tone, darker still, in sRGB for the game
    srgb = lambda c: round(255 * (12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055))
    bed = "#%02x%02x%02x" % tuple(srgb(c * R.get("bed_k", 0.2)) for c in R["dark"])
    json.dump({"px": P, "margin": MARGIN, "fw": FW, "cap": CAP, "tile": R.get("tile", TILE), "bar_n": BAR_N, "bed": bed}, f, indent=1)
