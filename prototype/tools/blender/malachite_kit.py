# The Mistress of the Copper Mountain's frame round each of her boards: a bar of dark banded malachite with bevelled
# edges running round the board's outline in one piece (no seams), held by blackened copper straps with rivets on the
# runs (at random, unevenly), a copper plate or a rough malachite block on each corner; the bar wobbles and its outer edge is chipped. No body of hers in it - her lizards run over it as sprites in the game.
# Same light, camera and outline code as the serpent frame (serpent_kit.py); the render is brought to the 1-pt grid
# like the serpent's (art/boss/export.py).
#   blender -b -P malachite_kit.py -- <out_dir> boss [px_per_cell] [samples] [area]
# writes <out_dir>/stage<N>.png + .json (px per cell, cells, pixel of the cells' top-left corner, tail_frames 0).
# The boards come from game_data.json AREAS[area].boss.stages (the Mistress has none yet: area 0 for a test).
import os, sys, math, json, random
_src = open(os.path.join(os.path.dirname(__file__), "serpent_kit.py"), encoding="utf-8").read()
exec(_src[:_src.index("os.makedirs(OUT, exist_ok=True)\nif WHAT")])

W = 0.42             # bar width on the board, cells
H = 0.18             # bar height
BEV = 0.05           # bevel of its top edges
GAP_M = 0.02         # between the cells and the bar
MARGIN_M = 0.3       # room round the frame
STRAP = 1.6          # a strap every so many cells along a run
CORNER_PLATE = 0.5   # copper plate on an outer corner, cells


def wobble(total, seed, amp, waves=(3, 7, 13)):
    """a smooth random wobble along a closed loop of length `total` (periodic, no jump at the start)"""
    rnd = random.Random(seed)
    terms = [(max(1, round(k * rnd.uniform(0.8, 1.2))) * 2 * math.pi / total, rnd.uniform(0, 2 * math.pi), rnd.uniform(0.5, 1.0))
             for k in waves]
    norm = sum(w for _, _, w in terms)
    return lambda x: amp * sum(w * math.sin(f * x + ph) for f, ph, w in terms) / norm


def chips(total, seed, every=0.55):
    """dents along the outer edge: (centre, half length, depth)"""
    rnd = random.Random(seed)
    out, x = [], rnd.uniform(0, every)
    while x < total:
        out.append((x, rnd.uniform(0.04, 0.12), rnd.uniform(0.02, 0.06)))
        x += rnd.uniform(0.4, 1.6) * every
    return out


def beam(name, loop, mat, seed=0):
    """a closed bar of bevelled rectangular section along a closed 2D loop; its sides wobble a little and the outer
    edge (to the left of the clockwise walk) is chipped"""
    bm = bmesh.new()
    uv_l = bm.loops.layers.uv.new("UVMap")
    n = len(loop)
    lens = [0.0]
    for i in range(1, n):
        lens.append(lens[-1] + (Vector(loop[i]) - Vector(loop[i - 1])).length)
    total = lens[-1] + (Vector(loop[0]) - Vector(loop[-1])).length
    w_in, w_out, h_w = wobble(total, seed, 0.025), wobble(total, seed + 1, 0.035), wobble(total, seed + 2, 0.025)
    dents = chips(total, seed + 3)

    def dent(x):
        d = 0.0
        for c0, hl, dp in dents:
            t = abs(x - c0) / hl
            if t < 1: d = max(d, dp * (1 - t * t))
        return d
    rings = []
    for i in range(n):
        a = Vector(loop[i - 1]); b = Vector(loop[(i + 1) % n])
        t = (b - a).normalized()
        nrm = Vector((-t.y, t.x, 0.0))
        p = Vector((loop[i][0], loop[i][1], 0.0))
        x = lens[i]
        dx = dent(x)
        wo = W / 2 + w_out(x) - dx
        wi = W / 2 + w_in(x)
        h = H + h_w(x) - dx * 0.6
        prof = [(-wi, 0.0), (-wi, h - BEV), (-wi + BEV, h), (wo - BEV, h - dx * 0.5), (wo, h - BEV - dx), (wo, 0.0)]
        rings.append([(bm.verts.new(p + nrm * u + Vector((0, 0, z))), u / W) for u, z in prof])
    for i in range(n):
        r0, r1 = rings[i], rings[(i + 1) % n]
        s0, s1 = lens[i], (lens[i + 1] if i + 1 < n else total)
        for j in range(5):
            q = [(r0[j], s0), (r0[j + 1], s0), (r1[j + 1], s1), (r1[j], s1)]
            f = bm.faces.new([v[0][0] for v in q])
            for k, loop_ in enumerate(f.loops):
                loop_[uv_l].uv = (q[k][1], q[k][0][1])
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    o.data.materials.append(mat)
    return o


def malachite_material(along=True):
    """banded malachite, dirty, chipped. along: on the bar, the bands run along it as thin pale wavy lines on dark
    green (u = length, v = across, bent by a slow noise along the length); else wavy concentric rings in world space
    (the corner blocks)"""
    m = bpy.data.materials.new("malachite"); m.use_nodes = True
    n = m.node_tree; L = n.links; nd = n.nodes.new
    p = n.nodes["Principled BSDF"]
    co = nd("ShaderNodeNewGeometry")   # world position for the dirt and the pits
    if along:
        uv = nd("ShaderNodeUVMap"); uv.uv_map = "UVMap"
        sep = nd("ShaderNodeSeparateXYZ"); L.new(uv.outputs[0], sep.inputs[0])
        bend = nd("ShaderNodeTexNoise"); bend.inputs["Scale"].default_value = 1.3; bend.inputs["Detail"].default_value = 3.0
        bv = nd("ShaderNodeCombineXYZ"); L.new(sep.outputs[0], bv.inputs[0]); bv.inputs[1].default_value = 3.7
        L.new(bv.outputs[0], bend.inputs["Vector"])
        sub = nd("ShaderNodeMath"); sub.operation = 'MULTIPLY_ADD'
        L.new(bend.outputs["Fac"], sub.inputs[0]); sub.inputs[1].default_value = 1.6; sub.inputs[2].default_value = -0.8
        add = nd("ShaderNodeMath"); add.operation = 'ADD'
        L.new(sep.outputs[1], add.inputs[0]); L.new(sub.outputs[0], add.inputs[1])
        wvec = nd("ShaderNodeCombineXYZ"); L.new(add.outputs[0], wvec.inputs[0])
        sl = nd("ShaderNodeMath"); sl.operation = 'MULTIPLY'; sl.inputs[1].default_value = 0.15
        L.new(sep.outputs[0], sl.inputs[0]); L.new(sl.outputs[0], wvec.inputs[1])
        wv = nd("ShaderNodeTexWave"); wv.wave_type = 'BANDS'; wv.bands_direction = 'X'
        wv.inputs["Scale"].default_value = 0.62; wv.inputs["Distortion"].default_value = 3.0
        wv.inputs["Detail"].default_value = 2.0; wv.inputs["Detail Scale"].default_value = 1.0
        L.new(wvec.outputs[0], wv.inputs["Vector"])
        cols = [(0.0, (0.006, 0.05, 0.022)), (0.3, (0.014, 0.11, 0.045)), (0.58, (0.03, 0.2, 0.08)),
                (0.8, (0.07, 0.32, 0.14)), (0.9, (0.2, 0.52, 0.28)), (0.95, (0.035, 0.2, 0.08))]
    else:
        wv = nd("ShaderNodeTexWave"); wv.wave_type = 'RINGS'; wv.rings_direction = 'SPHERICAL'
        wv.inputs["Scale"].default_value = 0.42; wv.inputs["Distortion"].default_value = 4.5
        wv.inputs["Detail"].default_value = 2.5; wv.inputs["Detail Scale"].default_value = 1.2
        L.new(co.outputs["Position"], wv.inputs["Vector"])
        cols = [(0.0, (0.008, 0.06, 0.026)), (0.22, (0.018, 0.14, 0.06)), (0.46, (0.04, 0.24, 0.1)),
                (0.7, (0.1, 0.38, 0.17)), (0.8, (0.2, 0.52, 0.3)), (0.85, (0.014, 0.1, 0.045))]
    ramp = nd("ShaderNodeValToRGB"); cr = ramp.color_ramp
    cr.interpolation = 'CONSTANT'
    cr.elements[0].position, cr.elements[0].color = cols[0][0], cols[0][1] + (1,)
    cr.elements[1].position, cr.elements[1].color = cols[1][0], cols[1][1] + (1,)
    for pos, c in cols[2:]:
        e = cr.elements.new(pos); e.color = c + (1,)
    L.new(wv.outputs["Fac"], ramp.inputs[0])
    # dirt: a coarse noise darkens and greys it (the Inscryption grime)
    nz = nd("ShaderNodeTexNoise"); nz.inputs["Scale"].default_value = 3.0; nz.inputs["Detail"].default_value = 6.0
    L.new(co.outputs["Position"], nz.inputs["Vector"])
    dr = nd("ShaderNodeMapRange"); dr.inputs[1].default_value = 0.45; dr.inputs[2].default_value = 0.7
    dr.inputs[3].default_value = 0.0; dr.inputs[4].default_value = 0.25
    L.new(nz.outputs["Fac"], dr.inputs[0])
    mix = nd("ShaderNodeMix"); mix.data_type = 'RGBA'; mix.blend_type = 'MIX'
    mix.inputs[7].default_value = (0.012, 0.016, 0.012, 1)
    L.new(dr.outputs[0], mix.inputs[0]); L.new(ramp.outputs[0], mix.inputs[6])
    L.new(mix.outputs[2], p.inputs["Base Color"])
    p.inputs["Roughness"].default_value = 0.32
    # chips and pits as bump
    vb = nd("ShaderNodeTexVoronoi"); vb.inputs["Scale"].default_value = 14.0
    L.new(co.outputs["Position"], vb.inputs["Vector"])
    bp = nd("ShaderNodeBump"); bp.inputs["Strength"].default_value = 0.4
    L.new(vb.outputs["Distance"], bp.inputs["Height"]); L.new(bp.outputs[0], p.inputs["Normal"])
    return m


def copper_material():
    """blackened copper with green verdigris in patches"""
    m = bpy.data.materials.new("copper"); m.use_nodes = True
    n = m.node_tree; L = n.links; nd = n.nodes.new
    p = n.nodes["Principled BSDF"]
    co = nd("ShaderNodeTexCoord")
    nz = nd("ShaderNodeTexNoise"); nz.inputs["Scale"].default_value = 9.0; nz.inputs["Detail"].default_value = 5.0
    L.new(co.outputs["Object"], nz.inputs["Vector"])
    ramp = nd("ShaderNodeValToRGB"); cr = ramp.color_ramp
    cr.elements[0].position, cr.elements[0].color = 0.25, (0.2, 0.07, 0.025, 1)
    cr.elements[1].position, cr.elements[1].color = 0.6, (0.55, 0.22, 0.09, 1)
    e = cr.elements.new(0.72); e.color = (0.5, 0.2, 0.08, 1)
    e = cr.elements.new(0.76); e.color = (0.06, 0.2, 0.14, 1)
    L.new(nz.outputs["Fac"], ramp.inputs[0])
    L.new(ramp.outputs[0], p.inputs["Base Color"])
    mt = nd("ShaderNodeMapRange"); mt.inputs[1].default_value = 0.72; mt.inputs[2].default_value = 0.76
    mt.inputs[3].default_value = 0.95; mt.inputs[4].default_value = 0.1
    L.new(nz.outputs["Fac"], mt.inputs[0]); L.new(mt.outputs[0], p.inputs["Metallic"])
    p.inputs["Roughness"].default_value = 0.36
    return m


def box(x, y, yaw, sx, sy, sz, z, mat, bevel=0.012):
    bpy.ops.mesh.primitive_cube_add(size=1, location=(x, y, z + sz / 2))
    o = bpy.context.object
    o.scale = (sx, sy, sz); o.rotation_euler = (0, 0, yaw)
    bpy.ops.object.transform_apply(scale=True)
    md = o.modifiers.new("b", 'BEVEL'); md.width = bevel; md.segments = 2
    o.data.materials.append(mat)
    return o


def rivet(x, y, z, mat, r=0.026):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, segments=12, ring_count=6, location=(x, y, z))
    o = bpy.context.object
    o.scale = (1, 1, 0.6)
    for poly in o.data.polygons: poly.use_smooth = True
    o.data.materials.append(mat)


def strap(x, y, yaw, cu, width, rivets):
    """a copper band across the bar, one or two rivets"""
    box(x, y, yaw, width, W + 0.06, 0.035, H - 0.02, cu)
    d = Vector((-math.sin(yaw), math.cos(yaw)))
    for s in ((-1, 1) if rivets == 2 else (0,)):
        rivet(x + d.x * s * W * 0.3, y + d.y * s * W * 0.3, H + 0.02, cu)


def corner_plate(x, y, cu, rnd):
    size = rnd.uniform(0.42, 0.56)
    box(x, y, rnd.uniform(-0.15, 0.15), size, size * rnd.uniform(0.85, 1.1), 0.04, H - 0.02, cu, bevel=0.02)
    k = size * 0.32
    spots = [(-1, -1), (-1, 1), (1, -1), (1, 1)]
    rnd.shuffle(spots)
    for sx, sy in spots[:rnd.choice((3, 4, 4))]:
        rivet(x + sx * k, y + sy * k, H + 0.03, cu, 0.03)


def corner_stone(x, y, mat, rnd):
    """a rough block of malachite on a corner, a bit wider and higher than the bar, chipped and askew"""
    size = rnd.uniform(0.5, 0.62)
    bpy.ops.mesh.primitive_cube_add(size=1, location=(x, y, (H + 0.05) / 2))
    o = bpy.context.object
    o.scale = (size, size * rnd.uniform(0.85, 1.1), H + 0.05)
    o.rotation_euler = (0, 0, rnd.uniform(-0.25, 0.25))
    bpy.ops.object.transform_apply(scale=True)
    b = o.modifiers.new("b", 'BEVEL'); b.width = 0.04; b.segments = 2
    sd = o.modifiers.new("s", 'SUBSURF'); sd.levels = 3; sd.render_levels = 3; sd.subdivision_type = 'SIMPLE'
    tx = bpy.data.textures.new("chips%d" % rnd.randrange(1 << 30), 'VORONOI')
    tx.noise_scale = 0.25
    dp = o.modifiers.new("d", 'DISPLACE'); dp.texture = tx; dp.strength = -0.035; dp.texture_coords = 'GLOBAL'
    o.data.materials.append(mat)
    return o


def malachite_frames(stages):
    step = 0.012
    c = W / 2 + GAP_M
    for si, rows in enumerate(stages):
        outline = board_outline(rows)
        corners = offset_loop(outline, c)
        loop = fillet_path(corners, step, r_out=0.14, r_in=W / 2 + 0.04)   # inner turn wider than the half-bar: no fold
        R_, C_ = len(rows), max(len(r) for r in rows)
        w_c, h_c = C_ + 2 * (c + MARGIN_M), R_ + 2 * (c + MARGIN_M)
        cx, cy = C_ / 2, -R_ / 2
        setup(10, 10, 1, 0, 0)
        mal = malachite_material(along=False)
        beam("bar", loop, malachite_material(), seed=si * 11)
        rnd = random.Random(si * 7 + 1)
        cu = copper_material()
        n = len(corners)
        # straps at random along each run (uneven gaps and widths, slightly askew, now and then a pair), keeping
        # clear of the corners; a plate on every outer corner
        for i in range(n):
            a, b = Vector(corners[i]), Vector(corners[(i + 1) % n])
            d1 = b - a
            ln = d1.length
            yaw = math.atan2(d1.y, d1.x)
            x = rnd.uniform(0.5, 0.5 + STRAP)
            while x < ln - 0.5:
                p = a + d1 * (x / ln)
                strap(p.x, p.y, yaw + rnd.uniform(-0.12, 0.12), cu, rnd.uniform(0.07, 0.16), rnd.choice((1, 2, 2)))
                if rnd.random() < 0.25 and x + 0.2 < ln - 0.5:
                    p = a + d1 * ((x + 0.2) / ln)
                    strap(p.x, p.y, yaw + rnd.uniform(-0.12, 0.12), cu, rnd.uniform(0.06, 0.1), 1)
                x += rnd.uniform(0.55, 1.6) * STRAP
        for i in range(n):
            p, v, q = Vector(corners[i - 1]), Vector(corners[i]), Vector(corners[(i + 1) % n])
            d1 = v - p; d2 = q - v
            if d1.x * d2.y - d1.y * d2.x < 0:
                if rnd.random() < 0.5:
                    corner_plate(v.x, v.y, cu, rnd)
                else:
                    corner_stone(v.x, v.y, mal, rnd)
        base = os.path.join(OUT, "stage%d" % si)
        render(base + ".png", w_c, h_c, cx, cy)
        with open(base + ".json", "w") as fh:
            json.dump({"px_per_cell": P, "cells": [C_, R_], "tail_frames": 0,
                       "cells_top_left": [(c + MARGIN_M) * P, (c + MARGIN_M) * P]}, fh, indent=1)


os.makedirs(OUT, exist_ok=True)
gd = json.load(open(os.path.join(PROJ, "godot/data/game_data.json"), encoding="utf-8"))
malachite_frames([st["map"].split("|") for st in gd["AREAS"][int(argv[4]) if len(argv) > 4 else 0]["boss"]["stages"]])
