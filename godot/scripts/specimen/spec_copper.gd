class_name SpecCopper
extends RefCounted
## Native copper as the Keweenaw gives it (25.11, the user's photos): three ways besides the nugget, the vein and the tree.
##   float — a lump rolled by the ice: its skin velvety green malachite and dark oxide, its high points worn through to
##           bright, smooth copper windows (how much is worn: `bare`)
##   slab  — such a lump sawn and polished: a mirror of copper with the grinder's scratches, calcite caught in it, a rind
##           of red cuprite and the green skin round it; now and then both halves stood open like a book (`pair`)
##   sheet — a sheet of copper filling a crack through dark basalt, the rock above it broken away: the sheet's face
##           under its patina, its broken edge bright along the rock's side
## All on their own stream (SpecGenome takes the kind from here): no other gene of the find moves.
## Drawn by shaders/copper_patina.gdshader (COLOR: r bare copper, g a sawn face, b how far in from the face's rim).

const U := preload("res://scripts/specimen/spec_util.gd")
const VIEW_DIR := Vector3(-0.5646, 0.0, 0.8253)
const KINDS := [["float", 5.0], ["slab", 3.0], ["sheet", 2.0]]
const NAMES := {float = "float copper", slab = "sawn and polished", sheet = "copper sheet", bookends = "bookend pair"}
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

static func accents(g: Dictionary) -> Array:
	if g.is_empty(): return []
	var out := ["cu_" + String(g.kind)]
	if g.get("pair", false): out.append("cu_bookends")
	return out

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
	return m

static func build(b: SpecimenBuilder, g: Dictionary) -> MeshInstance3D:
	match String(g.kind):
		"slab": return _slab(b, g)
		"sheet": return _sheet(b, g)
	return _float(b, g)

## the worn lump's skin and windows: the high points, the side to the viewer, a little noise — `bare` of it copper;
## the skin stands a hair above the copper, so a window reads as worn through it
static func _windows(rng: Rng32, gm: Geo, cav: PackedFloat32Array, bare: float, c: Vector3, raise := 0.016) -> void:
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
	for i in gm.v.size():
		var r := clampf(0.5 + (val[i] - thr) * 5.0, 0.0, 1.0)
		gm.col[i] = Color(r, 0.0, 0.0, 1.0)
		gm.v[i] += (gm.v[i] - c).normalized() * raise * (1.0 - r)

## float copper: one rolled lump, a smaller one or two grown to it
static func _float(b: SpecimenBuilder, g: Dictionary) -> MeshInstance3D:
	var rng := b.rng
	var m := material(g)
	var L := RockKit.lump(rng, {r = 0.55, sx = 1.3 + rng.next() * 0.25, sy = 0.78 + rng.next() * 0.2, sz = 1.0, wave = 0.24,
		bumps = [[9, 0.75, 0.22], [28, 0.32, 0.08]], pits = [24, 0.14, 0.05], seg = 96})
	var gm: Geo = L[0]
	_windows(rng, gm, L[1], float(g.bare), Vector3.ZERO)
	var main := U.mesh(gm, m, b.root, Vector3.ZERO, U.eul((rng.next() - 0.5) * 0.4, rng.next() * 6.3, (rng.next() - 0.5) * 0.3))
	for k in int(rng.next() * 2.6):
		var rr := 0.16 + rng.next() * 0.14
		var S := RockKit.lump(rng, {r = rr, sx = 1.2, sy = 0.8, sz = 1.0, wave = 0.2, bumps = [[7, 0.7, 0.2], [18, 0.3, 0.07]], seg = 48})
		var sg: Geo = S[0]
		_windows(rng, sg, S[1], float(g.bare), Vector3.ZERO, 0.01)
		var dir := Vector3(rng.next() - 0.5, rng.next() * 0.4 - 0.1, rng.next() - 0.5).normalized()
		U.mesh(sg, m, b.root, dir * Vector3(0.5, 0.3, 0.4), U.eul(rng.next() * 6.3, rng.next() * 6.3, rng.next() * 6.3))
	# the callout: on the window that faces the viewer best
	var best := -INF
	var at := Vector3.ZERO
	var nn := Vector3.UP
	var xf := main.transform
	for i in range(0, gm.v.size(), 7):
		if gm.col[i].r < 0.9: continue
		var w := xf * gm.v[i]
		var s := w.normalized().dot(VIEW_DIR) + w.y * 0.3
		if s > best:
			best = s
			at = w
			nn = w.normalized()
	b._mark("cu_float", at, nn)
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
	_windows(rng, gm, L[1], 0.12, Vector3.ZERO, 0.012)
	var main: MeshInstance3D
	if not g.get("pair", false):
		var n := (VIEW_DIR + Vector3.UP * 0.35).normalized()
		var on := _press(gm, n * 0.04, n)
		var mid := _face(gm, on, n)
		m.set_shader_parameter("scratch_dir", n.cross(Vector3.UP).normalized().rotated(n, rng.next() * 0.6 - 0.3))
		main = U.mesh(gm, m, b.root)
		b._mark("cu_slab", mid, n)
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
	# (each face leans back a little to the lamps above: stood upright the polish showed the dark of the room)
	var da := (VIEW_DIR * 0.9 + right * 0.3 + Vector3.UP * 0.18).normalized()
	var db := (VIEW_DIR * 0.9 - right * 0.3 + Vector3.UP * 0.18).normalized()
	var ba := Basis(U.quat_to(Vector3.RIGHT, da))
	var bb := Basis(U.quat_to(Vector3.LEFT, db))
	var gap := 0.04
	var at_a := -right * (0.6 + gap) - ba * mid_a + Vector3(0, 0, 0)
	var at_b := right * (0.6 + gap) - bb * mid_b
	at_a.y = 0.0
	at_b.y = 0.0
	main = U.mesh(ga, m, b.root, at_a, ba)
	U.mesh(gb, m, b.root, at_b, bb)
	b._mark("cu_slab", at_a + ba * mid_a, da)
	b._mark("cu_bookends", (at_a + ba * mid_a + at_b + bb * mid_b) * 0.5 + Vector3.UP * 0.25, VIEW_DIR)
	return main

## a sheet of copper through a block of basalt: the rock under it, the sheet, the rock over it broken away at the front
static func _sheet(b: SpecimenBuilder, g: Dictionary) -> MeshInstance3D:
	var rng := b.rng
	b.root.set_meta("face", true)
	var m := material(g)
	var rock := SpecMat.make({col = Color(0.42, 0.42, 0.44), rough = 0.75, grain = 0.3, ao = 1.0, flat = true,
		dirt = {h = 99.0, a = 0.3, col = Color(0.075, 0.072, 0.07), fr = 0.0, scan = 2}})
	var B := RockKit.lump(rng, {r = 0.6, sx = 1.45, sy = 0.95, sz = 1.05, wave = 0.28, bumps = [[5, 0.9, 0.18], [12, 0.4, 0.06]],
		pits = [10, 0.15, 0.05], seg = 48})
	var blk: Geo = B[0]
	# the crack: a wavy plane leaning to the viewer
	var mdir := (Vector3.UP * 0.6 + VIEW_DIR * 0.8 + Vector3((rng.next() - 0.5) * 0.3, 0, (rng.next() - 0.5) * 0.3)).normalized()
	var c0 := Vector3(0, (rng.next() - 0.5) * 0.12, 0)
	var t := 0.06 + rng.next() * 0.05
	var nz := FastNoiseLite.new()
	nz.seed = int(rng.next() * 100000.0)
	nz.frequency = 0.9
	var dist := func(p: Vector3) -> float: return (p - c0).dot(mdir) + nz.get_noise_3dv(p * 1.5) * 0.08
	# under the sheet (its top just inside the sheet)
	var lo := _copy(blk)
	for i in lo.v.size():
		var d: float = dist.call(lo.v[i])
		if d > -t * 0.5 + 0.004: lo.v[i] -= mdir * (d - (-t * 0.5 + 0.004))
	# the sheet: the block between the crack's two walls
	var sh := _copy(blk)
	var top := PackedByteArray()
	top.resize(sh.v.size())
	for i in sh.v.size():
		var d: float = dist.call(sh.v[i])
		if d > t * 0.5:
			sh.v[i] -= mdir * (d - t * 0.5)
			top[i] = 1
		elif d < -t * 0.5:
			sh.v[i] -= mdir * (d + t * 0.5)
			top[i] = 2
	# its face under the patina, worn here and there; its broken edge (along the block's sides) bright copper
	_windows(rng, sh, B[1], float(g.bare) * 0.8, Vector3.ZERO, 0.0)
	for i in sh.v.size():
		if top[i] == 0: sh.col[i] = Color(1.0, 0.0, 0.0, 1.0)
		elif top[i] == 1: sh.v[i] += mdir * 0.006 * (1.0 - sh.col[i].r)
	# over the sheet, broken away at the front: only its back stands
	var hi := _copy(blk)
	var fdir := (VIEW_DIR + mdir * 0.25).normalized()
	var fk := 0.02 - rng.next() * 0.1
	var jn := FastNoiseLite.new()
	jn.seed = nz.seed + 7
	jn.frequency = 3.0
	for i in hi.v.size():
		var d: float = dist.call(hi.v[i])
		if d < t * 0.5 - 0.004: hi.v[i] -= mdir * (d - (t * 0.5 - 0.004))
		var e := (hi.v[i] - c0).dot(fdir) - fk
		if e > 0.0: hi.v[i] -= fdir * (e + jn.get_noise_3dv(hi.v[i] * 2.0) * 0.03)
	# (dark basalt: the scan takes its colour from the vertices, as RockKit's rocks give it)
	lo.fill_color(Color(0.12, 0.12, 0.13))
	hi.fill_color(Color(0.12, 0.12, 0.13))
	U.mesh(lo, rock, b.root)
	U.mesh(hi, rock, b.root)
	var main := U.mesh(sh, m, b.root)
	# the callout: on the sheet's face, toward the viewer
	var best := -INF
	var at := Vector3.ZERO
	for i in range(0, sh.v.size(), 5):
		if top[i] != 1: continue
		var s := (sh.v[i] - c0).dot(VIEW_DIR) + sh.v[i].y * 0.2
		if s > best:
			best = s
			at = sh.v[i]
	b._mark("cu_sheet", at, mdir)
	b.root.set_meta("glow", Color(0.2, 0.22, 0.2))
	return main
