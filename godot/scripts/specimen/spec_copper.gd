class_name SpecCopper
extends RefCounted
## Native copper as the Keweenaw gives it (25.11, the user's photos): two ways besides the nugget, the vein and the tree.
##   float — a lump rolled by the ice: its skin velvety green malachite and dark oxide, its high points worn through to
##           bright, smooth copper windows (how much is worn: `bare`)
##   slab  — such a lump sawn and polished: a mirror of copper with the grinder's scratches, calcite caught in it, a rind
##           of red cuprite and the green skin round it; now and then both halves stood open like a book (`pair`)
##   (a sheet of copper through basalt was tried and dropped, 25.11: the rock sat on a copper lump like a cap)
## All on their own stream (SpecGenome takes the kind from here): no other gene of the find moves.
## Drawn by shaders/copper_patina.gdshader (COLOR: r bare copper, g a sawn face, b how far in from the face's rim).

const U := preload("res://scripts/specimen/spec_util.gd")
const VIEW_DIR := Vector3(-0.5646, 0.0, 0.8253)
const KINDS := [["float", 5.0], ["slab", 3.0]]
const NAMES := {float = "float copper", slab = "sawn and polished", bookends = "bookend pair"}
## how often a native copper nugget or vein is one of these (its own stream)
const SHARE := 0.55

static func kind_of(seed_v: int) -> String:
	var r := Rng32.new((seed_v * 2654435761 + 433) % 4294967296)
	if r.next() >= SHARE: return ""
	return Stones.pick_w(KINDS, r)

static func genes(seed_v: int, kind: String, o: Dictionary = {}) -> Dictionary:
	var r := Rng32.new((seed_v * 2246822519 + 439) % 4294967296)
	var g := {kind = kind, seed = int(r.next() * 9000.0), bare = 0.18 + pow(r.next(), 1.3) * 0.45,
		tarnish = r.next() * 0.7, green = 0.75 + r.next() * 0.5, blue = r.next() * 0.6, calcite = 0.05 + r.next() * 0.35,
		pair = kind == "slab" and r.next() < 0.3}
	if o.has("cu_pair"): g.pair = kind == "slab" and bool(o.cu_pair)
	if o.has("cu_bare"): g.bare = float(o.cu_bare)
	return g

## (25.11, the user: «these are just formations, not genes») no chips of their own: the form is named in "Form"
static func accents(_g: Dictionary) -> Array:
	return []

static func gene_name(id: String) -> String:
	return NAMES.get(id.trim_prefix("cu_"), "")

static func material(g: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/copper_patina.gdshader")
	m.set_shader_parameter("seed", float(int(g.seed) % 97))
	m.set_shader_parameter("green_k", float(g.green))
	m.set_shader_parameter("blue_k", float(g.blue))
	m.set_shader_parameter("tarnish", float(g.tarnish))
	m.set_shader_parameter("calcite", float(g.calcite))
	m.set_shader_parameter("crust_tex", SpecMat.scan_tex(0, "diff"))
	return m

static func build(b: SpecimenBuilder, g: Dictionary) -> MeshInstance3D:
	match String(g.kind):
		"slab": return _slab(b, g)
	return _float(b, g)

## the worn lump's skin and windows: the high points, the side to the viewer, a little noise — `bare` of it copper;
## the skin stands a hair above the copper, so a window reads as worn through it
static func _windows(rng: Rng32, gm: Geo, cav: PackedFloat32Array, bare: float, c: Vector3, raise := 0.016, grind := true) -> void:
	var nz := FastNoiseLite.new()
	nz.seed = int(rng.next() * 100000.0)
	nz.frequency = 1.6
	var val := PackedFloat32Array()
	val.resize(gm.v.size())
	for i in gm.v.size():
		var d := (gm.v[i] - c).normalized()
		var conv := 1.0 - (cav[i] if i < cav.size() else 0.5)
		val[i] = conv * 0.55 + maxf(0.0, d.dot(VIEW_DIR)) * 0.3 + maxf(0.0, d.y) * 0.1 + nz.get_noise_3dv(gm.v[i] * 2.0) * 0.4
	var sorted := val.duplicate()
	sorted.sort()
	var thr := sorted[clampi(int((1.0 - bare) * sorted.size()), 0, sorted.size() - 1)]
	gm.col.resize(gm.v.size())
	var rr := PackedFloat32Array()
	rr.resize(gm.v.size())
	for i in gm.v.size():
		rr[i] = clampf(0.5 + (val[i] - thr) * 12.0, 0.0, 1.0)
	# (smoothed over the neighbours: a mask that jumped from one vertex to the next cut the window's edge and the skin's
	# step along the triangles — saw teeth that crawled as the stone turned)
	var NB := _nbrs(gm)
	var rep_of: PackedInt32Array = NB[0]
	var nb: Array = NB[1]
	rr = _smooth(rr, rep_of, nb, 3)
	# (25.11, "a smoother way from copper to skin") the same, smoothed far wider: the copper browning over a wide way
	# to the skin, the skin thinning to a film near the copper, the skin's rise a slope, not a step (COLOR.b)
	var ww := _smooth(rr, rep_of, nb, 14)
	for i in gm.v.size():
		gm.col[i] = Color(rr[i], 0.0, ww[i], 1.0)
	# ground flat: the windows smoothed toward their neighbours (the bumps' tops worn down into flat lobes)
	if grind: _grind(gm)
	# the skin stands above the copper: rising over the wide way
	for i in gm.v.size():
		gm.v[i] += (gm.v[i] - c).normalized() * raise * (1.0 - smoothstep(0.15, 0.6, ww[i]))

static func _smooth(src: PackedFloat32Array, rep_of: PackedInt32Array, nb: Array, n: int) -> PackedFloat32Array:
	var rr := src.duplicate()
	for it in n:
		var nr := rr.duplicate()
		for i in rr.size():
			if rep_of[i] != i: continue
			var ns: PackedInt32Array = nb[i]
			if ns.is_empty(): continue
			var sum := rr[i]
			for j in ns: sum += rr[j]
			nr[i] = sum / (ns.size() + 1)
		for i in rr.size(): rr[i] = nr[rep_of[i]]
	return rr

## each vertex's neighbours, the sphere's seam welded by position
static func _nbrs(gm: Geo) -> Array:
	var rep_of := PackedInt32Array()
	rep_of.resize(gm.v.size())
	var seen := {}
	for i in gm.v.size():
		var k := Vector3i((gm.v[i] * 20000.0).round())
		if not seen.has(k): seen[k] = i
		rep_of[i] = int(seen[k])
	var nb := []
	nb.resize(gm.v.size())
	for i in gm.v.size(): nb[i] = PackedInt32Array()
	for t in range(0, gm.idx.size(), 3):
		for e in 3:
			var a := rep_of[gm.idx[t + e]]
			var b := rep_of[gm.idx[t + (e + 1) % 3]]
			if a == b: continue
			(nb[a] as PackedInt32Array).append(b)
			(nb[b] as PackedInt32Array).append(a)
	return [rep_of, nb]

static func _grind(gm: Geo) -> void:
	var NB := _nbrs(gm)
	var rep_of: PackedInt32Array = NB[0]
	var nb: Array = NB[1]
	for it in 10:
		var nv := gm.v.duplicate()
		for i in gm.v.size():
			if rep_of[i] != i: continue
			var r := gm.col[i].r
			if r <= 0.05: continue
			var ns: PackedInt32Array = nb[i]
			if ns.is_empty(): continue
			var avg := Vector3.ZERO
			for j in ns: avg += gm.v[j]
			avg /= ns.size()
			nv[i] = gm.v[i].lerp(avg, 0.7 * r * r)
		for i in gm.v.size(): gm.v[i] = nv[rep_of[i]]

## float copper: one rolled lump, a smaller one or two grown to it
static func _float(b: SpecimenBuilder, g: Dictionary) -> MeshInstance3D:
	var rng := b.rng
	var m := material(g)
	var L := RockKit.lump(rng, {r = 0.55, sx = 1.3 + rng.next() * 0.25, sy = 0.78 + rng.next() * 0.2, sz = 1.0, wave = 0.24,
		bumps = [[9, 0.75, 0.22], [28, 0.32, 0.08]], pits = [24, 0.14, 0.05], seg = 144})
	var gm: Geo = L[0]
	_windows(rng, gm, L[1], float(g.bare), Vector3.ZERO)
	var main := U.mesh(gm, m, b.root, Vector3.ZERO, U.eul((rng.next() - 0.5) * 0.4, rng.next() * 6.3, (rng.next() - 0.5) * 0.3))
	for k in int(rng.next() * 2.6):
		var rr := 0.16 + rng.next() * 0.14
		var S := RockKit.lump(rng, {r = rr, sx = 1.2, sy = 0.8, sz = 1.0, wave = 0.2, bumps = [[7, 0.7, 0.2], [18, 0.3, 0.07]], seg = 48})
		var sg: Geo = S[0]
		_windows(rng, sg, S[1], float(g.bare), Vector3.ZERO, 0.018)
		var dir := Vector3(rng.next() - 0.5, rng.next() * 0.4 - 0.1, rng.next() - 0.5).normalized()
		U.mesh(sg, m, b.root, dir * Vector3(0.5, 0.3, 0.4), U.eul(rng.next() * 6.3, rng.next() * 6.3, rng.next() * 6.3))
	return main

## press every vertex past a plane onto it; returns which were pressed
static func _press(gm: Geo, p0: Vector3, n: Vector3) -> PackedByteArray:
	var on := PackedByteArray()
	on.resize(gm.v.size())
	for i in gm.v.size():
		var d := (gm.v[i] - p0).dot(n)
		if d > 0.0:
			gm.v[i] -= n * d
			on[i] = 1
	return on

## a sawn face: colours its vertices (g 1, b how far in from the rim — by the rim's outline round the face's middle)
static func _face(gm: Geo, on: PackedByteArray, n: Vector3) -> Vector3:
	var u := n.cross(Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT).normalized()
	var w := n.cross(u)
	# the rim: pressed vertices of a triangle that is not all pressed
	var rim := {}
	for t in range(0, gm.idx.size(), 3):
		var a := gm.idx[t]
		var bb := gm.idx[t + 1]
		var c := gm.idx[t + 2]
		var k := on[a] + on[bb] + on[c]
		if k > 0 and k < 3:
			for x in [a, bb, c]:
				if on[x] == 1: rim[x] = true
	var mid := Vector3.ZERO
	for x: int in rim: mid += gm.v[x]
	mid /= maxf(1.0, rim.size())
	const NB := 72
	var R := PackedFloat32Array()
	R.resize(NB)
	for x: int in rim:
		var q := gm.v[x] - mid
		var ang := atan2(q.dot(w), q.dot(u))
		var bi := posmod(int(floor((ang + PI) / TAU * NB)), NB)
		R[bi] = maxf(R[bi], Vector2(q.dot(u), q.dot(w)).length())
	for pass_i in 3:
		for bi in NB:
			if R[bi] <= 0.0: R[bi] = maxf(R[(bi + 1) % NB], R[(bi + NB - 1) % NB])
	gm.col.resize(gm.v.size())
	for i in gm.v.size():
		if on[i] != 1: continue
		var q := gm.v[i] - mid
		var ang := atan2(q.dot(w), q.dot(u))
		var bi := posmod(int(floor((ang + PI) / TAU * NB)), NB)
		var rr := maxf(R[bi], 0.01)
		var f := clampf(1.0 - Vector2(q.dot(u), q.dot(w)).length() / rr, 0.0, 1.0)
		gm.col[i] = Color(1.0, 1.0, f, 1.0)
	return mid

static func _copy(gm: Geo) -> Geo:
	var c := Geo.new()
	c.v = gm.v.duplicate()
	c.idx = gm.idx.duplicate()
	c.col = gm.col.duplicate()
	return c

## a sawn and polished lump (or both its halves, stood open like a book)
static func _slab(b: SpecimenBuilder, g: Dictionary) -> MeshInstance3D:
	var rng := b.rng
	# (its polished face to the viewer: on the card it rocks about the face, never turns its back)
	b.root.set_meta("face", true)
	var m := material(g)
	var L := RockKit.lump(rng, {r = 0.55, sx = 1.25 + rng.next() * 0.2, sy = 1.0 + rng.next() * 0.25, sz = 0.85, wave = 0.22,
		bumps = [[10, 0.7, 0.2], [30, 0.3, 0.07]], pits = [24, 0.14, 0.05], seg = 96})
	var gm: Geo = L[0]
	# (its back worn a little through its skin, as the float lumps are)
	_windows(rng, gm, L[1], 0.12, Vector3.ZERO, 0.02)
	var main: MeshInstance3D
	if not g.get("pair", false):
		var n := (VIEW_DIR + Vector3.UP * 0.35).normalized()
		var on := _press(gm, n * 0.04, n)
		_face(gm, on, n)
		m.set_shader_parameter("scratch_dir", n.cross(Vector3.UP).normalized().rotated(n, rng.next() * 0.6 - 0.3))
		main = U.mesh(gm, m, b.root)
		return main
	# the pair: cut through the middle across x, one half each way, each turned to the viewer, side by side
	var right := (-VIEW_DIR).cross(Vector3.UP).normalized()
	var ga := gm
	var gb := _copy(gm)
	var on_a := _press(ga, Vector3.ZERO, Vector3.RIGHT)
	var on_b := _press(gb, Vector3.ZERO, Vector3.LEFT)
	var mid_a := _face(ga, on_a, Vector3.RIGHT)
	var mid_b := _face(gb, on_b, Vector3.LEFT)
	m.set_shader_parameter("scratch_dir", Vector3(0.0, 0.3, 1.0))
	# (turned off the lamps' line, one face caught the dark of the room and the other a softbox: a softer polish lights both)
	m.set_shader_parameter("face_dull", 0.12)
	# (each face leans back a little to the lamps above, the two turned alike, so they light alike)
	var da := (VIEW_DIR * 0.9 + right * 0.2 + Vector3.UP * 0.38).normalized()
	var db := (VIEW_DIR * 0.9 - right * 0.2 + Vector3.UP * 0.38).normalized()
	var ba := Basis(U.quat_to(Vector3.RIGHT, da))
	var bb := Basis(U.quat_to(Vector3.LEFT, db))
	# side by side on one ground: the inner edges a little apart, both standing on the same line
	var gap := 0.035
	var ext := func(gg: Geo, bs: Basis) -> Array:   # [lowest y, least and most along `right`]
		var lo_y := INF
		var lo_r := INF
		var hi_r := -INF
		for v in gg.v:
			var w := bs * v
			lo_y = minf(lo_y, w.y)
			lo_r = minf(lo_r, w.dot(right))
			hi_r = maxf(hi_r, w.dot(right))
		return [lo_y, lo_r, hi_r]
	var ea: Array = ext.call(ga, ba)
	var eb: Array = ext.call(gb, bb)
	var at_a := right * (-gap * 0.5 - float(ea[2])) + Vector3.UP * (-float(ea[0]))
	var at_b := right * (gap * 0.5 - float(eb[1])) + Vector3.UP * (-float(eb[0]))
	main = U.mesh(ga, m, b.root, at_a, ba)
	U.mesh(gb, m, b.root, at_b, bb)
	return main
