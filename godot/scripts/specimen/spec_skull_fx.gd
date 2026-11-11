class_name SpecSkullFx
extends RefCounted
## The skull's dressings and its own living legends (docs/skulls.md): obols on the eyes, Koschei's diadem, fireflies
## living inside, a pile of two or three skulls; Yaga's fire in the eyes, a candle burning on the crown, eyes that
## follow you, a cloud of butterflies, a swarm of fireflies. ("Deathless" — light along the cracks — is the bone
## shader's own.) Everything here is in the skull's own space (face toward +Z), before it is posed.

const FLAME := preload("res://shaders/skull_flame.gdshader")
const GLOW := preload("res://shaders/skull_glow.gdshader")
const COIN := preload("res://shaders/skull_coin.gdshader")
const U := preload("res://scripts/specimen/spec_util.gd")

## Yaga's fire: its colour by the skull (green most, then blue, the forge's orange, violet)
## Yaga's fire: the two colours its flames drift between
const FIRE2 := [[[Color(0.35, 1.0, 0.4), Color(1.0, 0.5, 0.15)], 4.0], [[Color(0.35, 0.65, 1.0), Color(0.8, 0.4, 1.0)], 2.0],
	[[Color(1.0, 0.5, 0.15), Color(1.0, 0.85, 0.3)], 1.5]]
const FIRE := [[Color(0.35, 1.0, 0.4), 4.0], [Color(0.35, 0.65, 1.0), 2.5], [Color(1.0, 0.5, 0.15), 2.0], [Color(0.8, 0.4, 1.0), 1.0]]

static func dress(b: RefCounted, sk: Dictionary, bones: Array, nrs: Array, bone_m: Material, crystal: Callable, lean: Callable) -> void:
	var root: Node3D = b.root
	var r := Rng32.new(int(sk.skin_seed) + 501)
	var surf := SpecSurf.new()
	for k in bones.size(): surf.add(bones[k], nrs[k])
	var fx := String(sk.get("fx", ""))
	var eyes := []
	if fx in ["yaga", "watching"] or sk.get("coins", false) or sk.get("lantern", false):
		for sx: float in [-1.0, 1.0]:
			var e := eye(surf, sx, sk)
			if not e.is_empty(): eyes.append(e)
	if sk.get("coins", false) and eyes.size() == 2: _coins(root, sk, r, eyes)
	if sk.get("diadem", false): _diadem(root, sk, r, surf)
	if sk.get("lantern", false) and eyes.size():
		var c0: Vector3 = (eyes[0].deep as Vector3).lerp(eyes[eyes.size() - 1].deep, 0.5)
		_fireflies(root, r, c0 + Vector3(0, 0.06, -0.12), 0.15, 26, 0.05, false)
		(sk.marks as Array).append(["sk_lantern", eyes[0].front, Vector3.BACK])
	if int(sk.get("pile", 0)) > 0: _pile(root, sk, r, bones, bone_m)
	if sk.has("geode_pits"): _geode(sk, r, crystal, lean)
	match fx:
		"yaga": _yaga(root, sk, r, eyes)
		"watching": _watching(root, r, eyes)
		"candle": _candle(root, sk, r, bones, surf)
		"fireflies": _swarm(root, r)
		"flutter": _flock(root, r)
		"deathless": _shatter(root, sk, r, bones[0], bone_m)
	if fx in SpecBeastFx.ALL: SpecBeastFx.dress(b, sk, bones, nrs, bone_m, surf)

## an eye socket of this skull, found on the skull itself (as SpecSkull._lip): rays straight at the face fall deep into
## the opening and stop short on the bone round it. {front: centre on the rim's plane, deep: centre at the socket's
## floor, r: the opening's radius, sx}
static func eye(surf: SpecSurf, sx: float, sk: Dictionary = {}) -> Dictionary:
	if String(sk.get("beast", "")) != "":
		var lm: Dictionary = SpecSkull.body(String(sk.beast)).lm
		if not lm.has("eye_front"): return {}
		var fr := SpecSkull.lm_v(lm, "eye_front", sx)
		var dp := SpecSkull.lm_v(lm, "eye_deep", sx)
		return {front = fr, deep = dp.lerp(fr, 0.15), r = clampf(float(lm.eye_r) * 0.85, 0.04, 0.16), sx = sx}
	var hits := []
	var zf := -INF
	for yi in 14:
		for xi in 14:
			var q := Vector3(sx * (0.03 + xi * 0.022), -0.12 + yi * 0.024, 1.5)
			var h := surf.ray(q, Vector3.FORWARD, 3.0)
			if h.is_empty(): continue
			var hz: float = (h[0] as Vector3).z
			zf = maxf(zf, hz)
			hits.append(Vector3(q.x, q.y, hz))
	var c := Vector2.ZERO
	var zd := 0.0
	var nd := 0
	for hv: Vector3 in hits:
		if hv.z < zf - 0.15:
			c += Vector2(hv.x, hv.y)
			zd += hv.z
			nd += 1
	if nd < 4: return {}
	c /= nd
	zd /= nd
	var rs := 0.0
	for hv: Vector3 in hits:
		if hv.z < zf - 0.15: rs = maxf(rs, Vector2(hv.x, hv.y).distance_to(c))
	var front := zd + (zf - zd) * 0.75
	return {front = Vector3(c.x, c.y, front), deep = Vector3(c.x, c.y, zd + 0.03), r = clampf(rs * 0.85, 0.05, 0.12), sx = sx}

# ---------------------------------------------------------------- dressings

## a geode skull: where its crust broke away (bone.gdshader skin 8 — the same noise, SpecMask), the bone is hollowed in,
## so the druse lies in a pit; returns spots in the pits [point, normal], the deepest first
static func dig(cr: Geo, nr: PackedVector3Array, sk: Dictionary, seed_f: float) -> Array:
	var k := float(sk.skin_k) * 10.0
	var spots := []
	# (the mask goes to the shader in the mesh's UV.x — rp — so the pits and the crystals in them are the same places)
	cr.rp.resize(cr.v.size())
	for i in cr.v.size():
		var m := 0.0
		if SpecSkull._alive(cr, i):
			var q := (cr.v[i] + Vector3.ONE * seed_f) * 2.6 + Vector3.ONE * k
			m = smoothstep(0.5, 0.62, SpecMask.fbm(q)) * clampf(cr.col[i].r * 1.4, 0.0, 1.0)
		cr.rp[i] = Vector3(m, 0.0, 0.0)
		if m <= 0.0: continue
		cr.v[i] -= nr[i] * 0.035 * m
		if m > 0.6: spots.append([cr.v[i], nr[i]])
	return spots

## crystals growing in the geode's pits: the find's own, small, crowded, pointing out of the pit
static func _geode(sk: Dictionary, r: Rng32, crystal: Callable, lean: Callable) -> void:
	var spots: Array = sk.geode_pits
	var put := []
	for t in 900:
		if put.size() >= 110 or spots.is_empty(): break
		var q: Array = spots[int(r.next() * spots.size())]
		var p: Vector3 = q[0]
		var ok := true
		for o: Vector3 in put:
			if o.distance_to(p) < 0.026: ok = false
		if not ok: continue
		put.append(p)
		# (k 0.3: a druse of small crystals, not the crown's big ones)
		crystal.call(0.05 + r.next() * 0.25, p - (q[1] as Vector3) * 0.004, lean.call(q[1], 0.45), 0.3)
	if put.size(): (sk.marks as Array).append(["sk_geode", put[0], Vector3.BACK])

## obols on the eyes: two struck coins of old gold (or silver) laid over the sockets — a thick uneven blank, a raised
## rim, a ring of beads, an owl in relief, worn smooth on the high places and dark in the low ones (real relief in the
## mesh, so the light picks it out), one now and then slipped down the cheek
static func _coins(root: Node3D, sk: Dictionary, r: Rng32, eyes: Array) -> void:
	var gold := r.next() < 0.65
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.metallic = 1.0
	m.roughness = 0.38
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	for k in eyes.size():
		var e: Dictionary = eyes[k]
		var rad: float = float(e.r) * 1.15
		var mi := MeshInstance3D.new()
		mi.mesh = _coin_mesh(r, rad, gold)
		mi.material_override = m
		var slip := k == 1 and r.next() < 0.35
		var at: Vector3 = (e.front as Vector3) + Vector3(0, 0, 0.01)
		# (the coin's face is +Y; laid over the socket, facing out, a little tipped back on the brow)
		var bas := Basis(Vector3.RIGHT, PI * 0.5 - 0.18) * Basis(Vector3.UP, r.next() * TAU)
		if slip:
			at += Vector3(float(e.sx) * rad * 0.2, -rad * 0.7, -0.012)
			bas = Basis(Vector3.BACK, float(e.sx) * 0.4) * Basis(Vector3.RIGHT, PI * 0.5 - 0.32) * Basis(Vector3.UP, r.next() * TAU)
		mi.transform = Transform3D(bas, at)
		root.add_child(mi)
		if k == 0: (sk.marks as Array).append(["sk_coins", at, Vector3.BACK])

## one coin: a polar grid over an uneven round blank, the relief displacing the faces, its colour in the vertices
static func _coin_mesh(r: Rng32, rad: float, gold: bool) -> ArrayMesh:
	var rings := 16
	var segs := 64
	var th := rad * 0.16
	var sd := r.next() * 100.0
	var base := Color(0.86, 0.64, 0.28) if gold else Color(0.8, 0.8, 0.82)
	var dark := Color(0.3, 0.2, 0.08) if gold else Color(0.2, 0.2, 0.22)
	var out_r := PackedFloat32Array()
	for j in segs: out_r.append(1.0 + (SpecMask.vn(Vector3(cos(TAU * j / segs) * 1.6, sin(TAU * j / segs) * 1.6, sd)) - 0.5) * 0.14)
	var relief := func(p: Vector2, face: int) -> float:
		var rr := p.length()
		var h := smoothstep(0.8, 0.88, rr) * 0.9
		var a := atan2(p.y, p.x)
		h = maxf(h, (1.0 - smoothstep(0.0, 0.05, absf(rr - 0.72))) * smoothstep(0.35, 0.65, 0.5 + 0.5 * cos(a * 26.0)) * 0.6)
		if face == 0:
			# the owl: a body, two big eyes with dark pupils, ear tufts, a beak
			var q := p * 1.5
			var body := smoothstep(0.55, 0.45, (q - Vector2(0, -0.2)).length() / Vector2(1.0, 1.25).length() * 1.6)
			var eyes := 0.0
			for sx in [-1.0, 1.0]:
				var d := (q - Vector2(sx * 0.2, 0.28)).length()
				eyes = maxf(eyes, smoothstep(0.2, 0.16, d) - smoothstep(0.08, 0.04, d) * 0.6)
			var tufts := smoothstep(0.1, 0.0, absf(q.x) - 0.3) * smoothstep(0.42, 0.5, q.y) * smoothstep(0.62, 0.5, q.y) * smoothstep(0.15, 0.25, absf(q.x))
			h = maxf(h, body * 0.55 + eyes * 0.35 + tufts * 0.4)
		else:
			# the reverse: a worn head, hardly more than a swelling
			h = maxf(h, smoothstep(0.55, 0.2, p.length()) * 0.45)
		# worn: the high places rubbed down, scratches
		h -= SpecMask.fbm(Vector3(p.x * 5.0, p.y * 5.0, sd + face)) * 0.25
		return clampf(h, 0.0, 1.0)
	var g := Geo.new()
	for face in 2:
		var sg := 1.0 if face == 0 else -1.0
		var i0 := g.v.size()
		g.v.append(Vector3(0, sg * (th * 0.5 + float(relief.call(Vector2.ZERO, face)) * th * 0.35), 0))
		g.col.append(base)
		for i in range(1, rings + 1):
			var f := float(i) / rings
			for j in segs:
				var a := TAU * j / segs
				var p := Vector2(cos(a), sin(a)) * f
				var hh: float = relief.call(p, face)
				var rr := rad * f * out_r[j]
				g.v.append(Vector3(cos(a) * rr, sg * (th * 0.5 + hh * th * 0.35 - (1.0 - f) * 0.0), sin(a) * rr))
				g.col.append(dark.lerp(base, 0.35 + hh * 0.75))
		for j in segs:
			g.idx.append_array([i0, i0 + 1 + j, i0 + 1 + (j + 1) % segs])
		for i in range(1, rings):
			for j in segs:
				var a0 := i0 + 1 + (i - 1) * segs + j
				var a1 := i0 + 1 + (i - 1) * segs + (j + 1) % segs
				var b0 := a0 + segs
				var b1 := a1 + segs
				g.idx.append_array([a0, b0, b1, a0, b1, a1])
	# the edge between the two faces
	var top0 := 1 + (rings - 1) * segs
	var bot0 := g.v.size() / 2 + 1 + (rings - 1) * segs
	for j in segs:
		var j1 := (j + 1) % segs
		g.idx.append_array([top0 + j, bot0 + j, bot0 + j1, top0 + j, bot0 + j1, top0 + j1])
	# (each triangle facing away from the coin's middle)
	g.orient_out(Vector3.ZERO)
	return g.to_mesh()

## Koschei's diadem: a band of old gold round the brow (a rounded strip with a raised edge and a groove along it), a
## little askew; its points are leaves of metal rising and leaning out, each with a bead at its tip, the front one
## tallest with a red stone set at its foot
static func _diadem(root: Node3D, sk: Dictionary, r: Rng32, surf: SpecSurf) -> void:
	var bb := AABB()
	for k in surf.ta.size(): bb = AABB(surf.ta[k], Vector3.ZERO) if k == 0 else bb.expand(surf.ta[k])
	var y0 := bb.position.y + bb.size.y * 0.7
	var tilt := (r.next() - 0.5) * 0.12
	var roll := (r.next() - 0.5) * 0.1
	var n := 72
	var ring := []
	for k in n:
		var a := TAU * float(k) / float(n)
		var y := y0 + tilt * cos(a) + roll * sin(a)
		var o := Vector3(sin(a) * 1.2, y, cos(a) * 1.2)
		var h := surf.ray(o, (Vector3(0, y, 0) - o).normalized(), 1.5)
		ring.append(h[0] if h.size() else null)
	if ring.count(null) > n / 3: return
	for k in n:
		if ring[k] == null:
			for d in range(1, n):
				if ring[(k + d) % n] != null:
					ring[k] = ring[(k + d) % n]
					break
	# smooth the ring (a band does not follow every bump)
	for it in 3:
		var sm := []
		for k in n: sm.append(((ring[(k + n - 1) % n] as Vector3) + (ring[k] as Vector3) * 2.0 + (ring[(k + 1) % n] as Vector3)) * 0.25)
		ring = sm
	var cen := Vector3.ZERO
	for p: Vector3 in ring: cen += p
	cen /= ring.size()
	var gold := Color(0.78, 0.58, 0.26)
	var dark := Color(0.3, 0.2, 0.08)
	var g := Geo.new()
	# the band: a profile swept round — inner face against the bone, a raised rim top and bottom, a groove between
	var prof := [[0.0, -1.0, 0.2], [0.55, -1.0, 0.8], [0.8, -0.85, 1.0], [0.7, -0.55, 0.7], [0.62, 0.0, 0.25], [0.7, 0.55, 0.7], [0.8, 0.85, 1.0], [0.55, 1.0, 0.8], [0.0, 1.0, 0.2]]
	var hb := 0.034
	var tk := 0.02
	var outs := []
	for k in n:
		var p: Vector3 = ring[k]
		var od := Vector3(p.x - cen.x, 0, p.z - cen.z).normalized()
		outs.append(od)
		for q: Array in prof:
			g.v.append(p + od * (0.004 + float(q[0]) * tk) + Vector3(0, float(q[1]) * hb, 0))
			g.col.append(dark.lerp(gold, float(q[2])))
	var np := prof.size()
	for k in n:
		for j in np - 1:
			var a0 := k * np + j
			var a1 := ((k + 1) % n) * np + j
			g.idx.append_array([a0, a1, a0 + 1, a0 + 1, a1, a1 + 1])
	g.orient_out(cen)
	# the points: leaves of metal, every 6th place, taller toward the front, leaning out, a bead on each
	var beads := []
	var gems := []
	var lv := Geo.new()
	for k in range(0, n, 6):
		var p: Vector3 = ring[k]
		var od: Vector3 = outs[k]
		var front := 0.5 + 0.5 * cos(TAU * float(k) / float(n))
		var hgt := 0.08 + front * 0.09
		var side := Vector3.UP.cross(od).normalized()
		var base := p + od * 0.012 + Vector3(0, hb * 0.8, 0)
		var up := (Vector3.UP + od * 0.25).normalized()
		var outline := [[-1.0, 0.0], [-0.9, 0.35], [-0.45, 0.7], [0.0, 1.0], [0.45, 0.7], [0.9, 0.35], [1.0, 0.0]]
		var wid := 0.034 + front * 0.012
		var i0 := lv.v.size()
		lv.v.append(base + up * hgt * 0.35 + od * 0.004)
		lv.col.append(gold)
		for q: Array in outline:
			lv.v.append(base + side * float(q[0]) * wid + up * float(q[1]) * hgt)
			lv.col.append(dark.lerp(gold, 0.7))
		for j in outline.size() - 1:
			lv.idx.append_array([i0, i0 + 1 + j, i0 + 2 + j])
		beads.append(base + up * hgt + od * 0.002)
		if front > 0.9: gems.append(base + up * hgt * 0.35 + od * 0.01)
	var lmesh := lv
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.metallic = 1.0
	m.roughness = 0.34
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	U.mesh(g, m, root)
	U.mesh(lmesh, m, root)
	var bm := StandardMaterial3D.new()
	bm.albedo_color = gold
	bm.metallic = 1.0
	bm.roughness = 0.22
	for p: Vector3 in beads:
		var s := MeshInstance3D.new()
		var sm2 := SphereMesh.new()
		sm2.radius = 0.013
		sm2.height = 0.026
		s.mesh = sm2
		s.material_override = bm
		s.position = p
		root.add_child(s)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.5, 0.02, 0.05)
	gm.roughness = 0.06
	gm.metallic_specular = 1.0
	gm.emission_enabled = true
	gm.emission = Color(0.2, 0.0, 0.02)
	for p: Vector3 in gems:
		var s := MeshInstance3D.new()
		var sm3 := SphereMesh.new()
		sm3.radius = 0.022
		sm3.height = 0.03
		s.mesh = sm3
		s.material_override = gm
		s.position = p
		root.add_child(s)
	(sk.marks as Array).append(["sk_diadem", (ring[0] as Vector3) + Vector3(0, 0.04, 0.01), Vector3.BACK])

## a pile: one or two more skulls lying under and behind it, bare and old, on their sides
static func _pile(root: Node3D, sk: Dictionary, r: Rng32, bones: Array, bone_m: Material) -> void:
	var cr: Geo = bones[0]
	var mesh := cr.to_mesh()
	var places := [[Vector3(-0.42, -0.6, -0.28), Vector3(0.35, 0.9, 1.45)], [Vector3(0.46, -0.56, -0.4), Vector3(-0.25, -0.8, -1.3)]]
	for k in int(sk.pile):
		var pl: Array = places[k]
		var e: Vector3 = pl[1]
		var bas := Basis.from_euler(e + Vector3((r.next() - 0.5) * 0.3, (r.next() - 0.5) * 0.6, (r.next() - 0.5) * 0.3)).scaled(Vector3.ONE * (0.88 + r.next() * 0.1))
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = bone_m
		mi.transform = Transform3D(bas, pl[0])
		mi.set_meta("geo", cr)
		root.add_child(mi)
		if k == 0: (sk.marks as Array).append(["sk_pile", mi.transform * Vector3(0, 0.2, 0.3), Vector3.BACK])

# ---------------------------------------------------------------- legends

## Yaga's fire, as on the fence round her hut: the sockets burn inside — little flames rising from the floor of each
## socket and licking out over its rim, the fire breathing (it dies down, then roars up), its colour drifting between
## two (green and orange, or blue and violet), sparks rising off it, a glow down inside, its light on the bone
static func _yaga(root: Node3D, sk: Dictionary, r: Rng32, eyes: Array) -> void:
	var pair: Array = Stones.pick_w(FIRE2, Rng32.new(int(sk.skin_seed) + 77))
	var ca: Color = pair[0]
	var cb: Color = pair[1]
	root.set_meta("dark", true)
	var breath := r.next() * 10.0
	for e: Dictionary in eyes:
		var rr: float = e.r
		var front: Vector3 = e.front
		var deep: Vector3 = e.deep
		var g := MeshInstance3D.new()
		var gq := QuadMesh.new()
		gq.size = Vector2.ONE * rr * 2.0
		g.mesh = gq
		g.material_override = _flame_mat(ca, cb, 1, 1.3, r.next() * 20.0, -1.0)
		g.position = deep.lerp(front, 0.3)
		root.add_child(g)
		for j in 5:
			var q := MeshInstance3D.new()
			var qm := QuadMesh.new()
			var hgt := rr * (2.1 + r.next() * 0.9) * (1.0 if j < 2 else 0.75)
			qm.size = Vector2(hgt * 0.55, hgt)
			q.mesh = qm
			q.material_override = _flame_mat(ca, cb, 0, 0.75, r.next() * 20.0, breath + float(j) * 0.7)
			var x := (r.next() - 0.5) * rr * 0.9
			var at := deep.lerp(front, 0.25 + float(j) * 0.1) + Vector3(x, -rr * 0.55 + hgt * 0.5, 0)
			q.position = at
			root.add_child(q)
		_fireflies(root, r, front + Vector3(0, rr * 0.3, 0.0), rr * 0.6, 12, 0.015, false, ca.lerp(cb, 0.5), rr * 5.0)
		var l := OmniLight3D.new()
		l.light_color = ca
		l.light_energy = 1.0
		l.omni_range = 1.0
		l.position = front + Vector3(0, rr * 0.6, 0.08)
		root.add_child(l)
		var fl := Flicker.new()
		fl.light = l
		fl.base = 1.0
		fl.col_a = ca
		fl.col_b = cb
		fl.r = Rng32.new(int(sk.skin_seed) + int(float(e.sx) * 9.0))
		root.add_child(fl)
	if eyes.size(): (sk.marks as Array).append(["fx", (eyes[0].front as Vector3), Vector3.BACK])

static func _flame_mat(ca: Color, cb: Color, mode: int, power: float, seed: float, breath: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = FLAME
	m.set_shader_parameter("col", Vector3(ca.r, ca.g, ca.b))
	m.set_shader_parameter("col2", Vector3(cb.r, cb.g, cb.b))
	m.set_shader_parameter("shift", 0.45)
	m.set_shader_parameter("mode", mode)
	m.set_shader_parameter("power", power)
	m.set_shader_parameter("seed", seed)
	m.set_shader_parameter("speed", 1.2)
	m.set_shader_parameter("breath", breath)
	return m

## a swarm of fireflies round the skull: little dark beetles each with a glowing tail and a soft halo, flying in
## wandering loops, their lights pulsing on and off each in its own rhythm; a light goes with two of them
static func _swarm(root: Node3D, r: Rng32) -> void:
	root.set_meta("dark", true)
	var sw := Swarm.new()
	sw.r = r
	root.add_child(sw)
	var body_m := StandardMaterial3D.new()
	body_m.albedo_color = Color(0.1, 0.07, 0.05)
	body_m.roughness = 0.4
	var wing_m := StandardMaterial3D.new()
	wing_m.albedo_color = Color(0.8, 0.85, 0.9, 0.25)
	wing_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wing_m.cull_mode = BaseMaterial3D.CULL_DISABLED
	wing_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for k in 22:
		var f := Node3D.new()
		sw.add_child(f)
		var body := MeshInstance3D.new()
		var cm := CapsuleMesh.new()
		cm.radius = 0.013
		cm.height = 0.055
		body.mesh = cm
		body.material_override = body_m
		body.rotation = Vector3(PI * 0.5, 0, 0)
		f.add_child(body)
		var tail := MeshInstance3D.new()
		var tm := SphereMesh.new()
		tm.radius = 0.015
		tm.height = 0.03
		tail.mesh = tm
		var tmat := StandardMaterial3D.new()
		tmat.albedo_color = Color(0.85, 1.0, 0.35)
		tmat.emission_enabled = true
		tmat.emission = Color(0.75, 1.0, 0.3)
		tail.material_override = tmat
		tail.position = Vector3(0, -0.004, -0.024)
		f.add_child(tail)
		var wings := []
		for s in [-1.0, 1.0]:
			var w := MeshInstance3D.new()
			var wq := QuadMesh.new()
			wq.size = Vector2(0.042, 0.022)
			w.mesh = wq
			w.material_override = wing_m
			w.position = Vector3(s * 0.021, 0.008, 0.004)
			w.rotation = Vector3(-PI * 0.5, 0, 0)
			f.add_child(w)
			wings.append(w)
		var halo := MeshInstance3D.new()
		var hq := QuadMesh.new()
		hq.size = Vector2.ONE * 0.16
		halo.mesh = hq
		var hm := _flame_mat(Color(0.75, 1.0, 0.3), Color(0.75, 1.0, 0.3), 1, 1.0, r.next() * 20.0, -1.0)
		hm.set_shader_parameter("shift", 0.0)
		halo.material_override = hm
		halo.position = Vector3(0, 0, -0.024)
		f.add_child(halo)
		sw.flies.append({node = f, tail = tmat, halo = hm, wings = wings, ph = r.next() * TAU, sp = 0.35 + r.next() * 0.4,
			rad = 0.45 + r.next() * 0.35, hy = (r.next() - 0.3) * 0.5, tilt = (r.next() - 0.5) * 0.9, blink = 1.6 + r.next() * 1.8, bph = r.next() * 10.0})
	for k in 2:
		var l := OmniLight3D.new()
		l.light_color = Color(0.7, 1.0, 0.35)
		l.light_energy = 0.8
		l.omni_range = 0.8
		sw.add_child(l)
		sw.lights.append(l)

## eyes that follow you: an eyeball in each socket, dark and wet, with a burning iris and a slit pupil that turn to the
## viewer as the find turns — lagging a little, darting, now and then glancing away and snapping back; they blink
static func _watching(root: Node3D, r: Rng32, eyes: Array) -> void:
	root.set_meta("dark", true)
	var col := Color(1.0, 0.3, 0.1) if r.next() < 0.6 else Color(0.85, 0.95, 0.35)
	var w := Watch.new()
	var ball_m := StandardMaterial3D.new()
	ball_m.albedo_color = Color(0.03, 0.025, 0.025)
	ball_m.roughness = 0.08
	ball_m.metallic_specular = 0.9
	var iris_m := StandardMaterial3D.new()
	iris_m.albedo_color = col
	iris_m.emission_enabled = true
	iris_m.emission = col
	iris_m.emission_energy_multiplier = 2.5
	var pupil_m := StandardMaterial3D.new()
	pupil_m.albedo_color = Color(0, 0, 0)
	pupil_m.roughness = 0.1
	for e: Dictionary in eyes:
		var rr: float = e.r
		# (sunk well into the socket: only the front of the ball shows)
		var c: Vector3 = (e.deep as Vector3).lerp(e.front, 0.2)
		var R := rr * 0.72
		var ball := MeshInstance3D.new()
		var bs := SphereMesh.new()
		bs.radius = R
		bs.height = R * 2.0
		ball.mesh = bs
		ball.material_override = ball_m
		ball.position = c
		root.add_child(ball)
		var eye_n := Node3D.new()
		eye_n.position = c
		root.add_child(eye_n)
		var iris := MeshInstance3D.new()
		var im := SphereMesh.new()
		im.radius = R * 0.55
		im.height = R * 0.3
		iris.mesh = im
		iris.material_override = iris_m
		iris.position = Vector3(0, 0, R * 0.9)
		iris.rotation = Vector3(PI * 0.5, 0, 0)
		eye_n.add_child(iris)
		var pupil := MeshInstance3D.new()
		var pm := SphereMesh.new()
		pm.radius = R * 0.4
		pm.height = R * 0.2
		pupil.mesh = pm
		pupil.material_override = pupil_m
		pupil.position = Vector3(0, 0, R * 1.0)
		pupil.rotation = Vector3(PI * 0.5, 0, 0)
		pupil.scale = Vector3(0.28, 1.0, 1.0)
		eye_n.add_child(pupil)
		var glow := MeshInstance3D.new()
		var gq := QuadMesh.new()
		gq.size = Vector2.ONE * R * 2.2
		glow.mesh = gq
		var gm := ShaderMaterial.new()
		gm.shader = FLAME
		gm.set_shader_parameter("col", Vector3(col.r, col.g, col.b))
		gm.set_shader_parameter("mode", 1)
		gm.set_shader_parameter("power", 0.5)
		glow.material_override = gm
		glow.position = Vector3(0, 0, R * 1.1)
		eye_n.add_child(glow)
		w.eyes.append([eye_n, c])
	root.add_child(w)

## deathless: the skull lies broken in shards on the ground, rises and gathers itself into the whole (light running
## along its cracks as they close), stays a while, and falls apart again — every seven seconds. The bone is cut into
## shards here; everything else on it (teeth, jaw, crystals, moss) moves as pieces of its own (Shatter).
static func _shatter(root: Node3D, sk: Dictionary, r: Rng32, cr: Geo, bone_m: Material) -> void:
	root.set_meta("dim", true)
	var nr := cr.normals()
	var seeds := []
	var tries := 0
	while seeds.size() < 18 and tries < 400:
		tries += 1
		var i := int(r.next() * cr.v.size())
		if not SpecSkull._alive(cr, i): continue
		var ok := true
		for sp: Vector3 in seeds:
			if sp.distance_to(cr.v[i]) < 0.16: ok = false
		if ok: seeds.append(cr.v[i])
	var parts := []
	for k in seeds.size(): parts.append(Geo.new())
	var ix := cr.idx
	for t in cr.tri_count():
		var a := ix[t * 3]
		var b := ix[t * 3 + 1]
		var c := ix[t * 3 + 2]
		if not (SpecSkull._alive(cr, a) and SpecSkull._alive(cr, b) and SpecSkull._alive(cr, c)): continue
		var m := (cr.v[a] + cr.v[b] + cr.v[c]) / 3.0
		var bi := 0
		var bd := INF
		for k in seeds.size():
			var d := m.distance_squared_to(seeds[k])
			if d < bd:
				bd = d
				bi = k
		var g: Geo = parts[bi]
		for vi in [a, b, c]:
			g.v.append(cr.v[vi])
			g.col.append(cr.col[vi])
			g.own_n.append(nr[vi])
	var hold := Node3D.new()
	hold.name = "shards"
	root.add_child(hold)
	for g: Geo in parts:
		if g.v.size() < 3: continue
		var mi := MeshInstance3D.new()
		mi.mesh = g.to_mesh()
		mi.material_override = bone_m
		hold.add_child(mi)
	# the whole bone is not drawn (its shards are); it stays only to frame the find
	if sk.has("cr_mi"): (sk.cr_mi as MeshInstance3D).visible = false
	var low := INF
	for v in cr.v: low = minf(low, v.y)
	var sh := Shatter.new()
	sh.r = Rng32.new(int(sk.skin_seed) + 900)
	sh.bone_m = bone_m
	sh.low_pts = PackedVector3Array(cr.v)
	root.add_child(sh)

## a candle burning on the crown: a stub of wax stuck to the bone, its wax run down over the skull and set, its flame
## swaying, its light flickering over the head
static func _candle(root: Node3D, sk: Dictionary, r: Rng32, bones: Array, surf: SpecSurf) -> void:
	root.set_meta("dim", true)
	var down := SpecSkull.down_of(sk)
	var cr: Geo = bones[0]
	var nr: PackedVector3Array = (cr.normals())
	var best := 0
	var bs := -INF
	for i in range(0, cr.v.size(), 3):
		if not SpecSkull._alive(cr, i): continue
		var s := -cr.v[i].dot(down) - absf(cr.v[i].x) * 0.6 + nr[i].dot(-down) * 0.1
		if s > bs:
			bs = s
			best = i
	var base := cr.v[best]
	var up := -down
	var h := 0.2 + r.next() * 0.1
	var rad := 0.055
	var wax := StandardMaterial3D.new()
	wax.albedo_color = Color(0.93, 0.88, 0.74) if r.next() < 0.7 else Color(0.7, 0.12, 0.1)
	wax.roughness = 0.45
	wax.rim_enabled = true
	wax.rim = 0.4
	var cm := CylinderMesh.new()
	cm.top_radius = rad * 0.92
	cm.bottom_radius = rad
	cm.height = h
	cm.radial_segments = 20
	var c := MeshInstance3D.new()
	c.mesh = cm
	c.material_override = wax
	c.transform = Transform3D(Basis(U.quat_to(Vector3.UP, up)), base + up * (h * 0.5 - 0.01))
	root.add_child(c)
	# the wax run down over the bone
	for k in 3 + int(r.next() * 3):
		var a := TAU * k / 5.0 + r.next()
		var side := Basis(U.quat_to(Vector3.UP, up)) * Vector3(cos(a), 0, sin(a))
		var res := surf.run(base + side * rad * 1.1, down, 0.012, 0.08 + r.next() * 0.18, Vector3.ZERO, 0.65)
		if res.is_empty(): continue
		var rr: Array = (res.runs as Array)[0]
		if (rr[0] as Array).size() < 4: continue
		var sm := SpecSkull._smooth_run(rr[0], rr[1], 0.006)
		var w0 := 0.02 + r.next() * 0.012
		SpecSkull._tongue(root, sm[0], sm[1], w0, w0 * 1.7, surf, wax, r.next() * 5.0)
	# the flame and its light
	var tip := base + up * (h + 0.012)
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.07, 0.17)
	q.mesh = qm
	var m := ShaderMaterial.new()
	m.shader = FLAME
	m.set_shader_parameter("col", Vector3(1.0, 0.55, 0.15))
	m.set_shader_parameter("seed", r.next() * 20.0)
	m.set_shader_parameter("speed", 1.3)
	q.material_override = m
	q.position = tip + up * 0.065
	root.add_child(q)
	var halo := MeshInstance3D.new()
	var hm := QuadMesh.new()
	hm.size = Vector2.ONE * 0.16
	halo.mesh = hm
	var hmat := ShaderMaterial.new()
	hmat.shader = FLAME
	hmat.set_shader_parameter("col", Vector3(1.0, 0.55, 0.2))
	hmat.set_shader_parameter("mode", 1)
	hmat.set_shader_parameter("power", 0.35)
	halo.material_override = hmat
	halo.position = tip + up * 0.04
	root.add_child(halo)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.7, 0.35)
	l.light_energy = 2.0
	l.omni_range = 1.4
	l.position = tip + up * 0.06
	root.add_child(l)
	var fl := Flicker.new()
	fl.light = l
	fl.base = 2.0
	fl.r = Rng32.new(int(sk.skin_seed) + 3)
	root.add_child(fl)
	(sk.marks as Array).append(["fx", tip, up])

## fireflies: a swarm round the skull (the legend), or a few living inside it (seen through the eyes and the nose).
## One mesh of little quads (shaders/skull_glow.gdshader): each drifts about its home and blinks in its own rhythm.
## rise > 0: sparks instead — each flies straight up that far, fading, and starts again (Yaga's fire)
static func _fireflies(root: Node3D, r: Rng32, centre: Vector3, rad: float, n: int, roam: float, swarm: bool, col := Color(0.75, 1.0, 0.35), rise := 0.0) -> void:
	var v := PackedVector3Array()
	var uv2 := PackedVector2Array()
	var cl := PackedColorArray()
	var idx := PackedInt32Array()
	for k in n:
		var d := Vector3(r.next() - 0.5, r.next() - 0.5, r.next() - 0.5).normalized()
		var home := centre + d * rad * (0.55 + 0.45 * r.next() if swarm else r.next())
		if swarm and home.y < -0.35: home.y = -0.35 + r.next() * 0.1
		var c := Color(r.next(), r.next(), r.next(), 1)
		var i0 := v.size()
		for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			v.append(home)
			uv2.append(corner)
			cl.append(c)
		idx.append_array([i0, i0 + 1, i0 + 2, i0, i0 + 2, i0 + 3])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_TEX_UV2] = uv2
	arr[Mesh.ARRAY_COLOR] = cl
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	# (its bounds grown by how far they roam: not culled when one drifts out of the box)
	mesh.custom_aabb = AABB(centre - Vector3.ONE * (rad + roam * 2.0), Vector3.ONE * (rad + roam * 2.0) * 2.0 + Vector3(0, rise, 0))
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := ShaderMaterial.new()
	m.shader = GLOW
	m.set_shader_parameter("roam", roam)
	m.set_shader_parameter("col", Vector3(col.r, col.g, col.b))
	m.set_shader_parameter("rise", rise)
	m.set_shader_parameter("size", 0.04 if swarm else 0.03)
	m.render_priority = 4
	mi.material_override = m
	root.add_child(mi)
	if swarm:
		root.set_meta("dark", true)
		for k in 2:
			var l := OmniLight3D.new()
			l.light_color = Color(0.7, 1.0, 0.4)
			l.light_energy = 0.9
			l.omni_range = 1.2
			l.position = centre + Vector3((k * 2 - 1) * rad * 0.6, 0.1, rad * 0.4)
			root.add_child(l)
	elif rise == 0.0:
		var l := OmniLight3D.new()
		l.light_color = Color(0.7, 1.0, 0.4)
		l.light_energy = 1.2
		l.omni_range = 0.7
		l.position = centre + Vector3(0, 0, 0.25)
		root.add_child(l)

## a cloud of butterflies: they rest all over the skull, and every few seconds all of them take off at once, whirl round
## it and settle again (the butterflies themselves are SpecButterfly's, set to start resting by the genes)
static func _flock(root: Node3D, r: Rng32) -> void:
	var f := Flock.new()
	f.r = Rng32.new(int(r.next() * 100000))
	root.add_child(f)

# ---------------------------------------------------------------- living parts

## the watching eyes: each eye turns (with a little lag) to look at the viewer, darts now and then, sometimes glances
## away and snaps back; the pupils narrow as they find you; both blink
class Watch extends Node:
	var eyes := []   # [eye node (its iris and pupil on +Z), centre]
	var t := 2.0
	var blink := 0.0
	var away := 0.0
	var away_dir := Vector3.ZERO
	var dart := Vector3.ZERO
	var dart_t := 0.5
	func _process(dt: float) -> void:
		var cam := get_viewport().get_camera_3d() if get_viewport() else null
		t -= dt
		if t <= 0.0:
			blink = 0.22
			t = 2.5 + randf() * 4.0
			if randf() < 0.35:
				away = 0.9
				away_dir = Vector3(randf() - 0.5, randf() * 0.4 - 0.3, 0.0).normalized()
		blink = maxf(0.0, blink - dt)
		away = maxf(0.0, away - dt)
		dart_t -= dt
		if dart_t <= 0.0:
			dart = Vector3(randf() - 0.5, randf() - 0.5, 0.0) * 0.18
			dart_t = 0.4 + randf() * 1.2
		var shut := 1.0 - sin(clampf(blink / 0.22, 0.0, 1.0) * PI)
		for e: Array in eyes:
			var n: Node3D = e[0]
			if not is_instance_valid(n) or cam == null: continue
			var parent := n.get_parent() as Node3D
			var to := (parent.to_local(cam.global_position) - (e[1] as Vector3)).normalized()
			if away > 0.0: to = (Vector3(0, 0, 1) + away_dir * 1.2).normalized()
			to = (to + dart).normalized()
			# (it can only roll so far in its socket)
			var fwd := Vector3(0, 0, 1)
			var ang := fwd.angle_to(to)
			if ang > 0.8: to = fwd.slerp(to, 0.8 / ang)
			if e.size() < 3: e.append(to)
			var cur: Vector3 = (e[2] as Vector3).slerp(to, 1.0 - exp(-dt * 7.0))
			e[2] = cur
			n.basis = Basis.looking_at(-cur, Vector3.UP).scaled(Vector3(1.0, maxf(0.06, shut), 1.0))

## a light flickering as a flame does, its colour drifting between two (col_b = col_a: one colour)
class Flicker extends Node:
	var light: OmniLight3D
	var base := 2.0
	var r: Rng32
	var t := 0.0
	var to := 1.0
	var col_a := Color.WHITE
	var col_b := Color.WHITE
	var drift := false
	func _ready() -> void:
		drift = col_a != col_b
	func _process(dt: float) -> void:
		if not is_instance_valid(light): return
		t -= dt
		if t <= 0.0:
			to = 0.75 + r.next() * 0.45
			t = 0.05 + r.next() * 0.12
		light.light_energy = lerpf(light.light_energy, base * to, minf(1.0, dt * 12.0))
		# (in step with the flames' own colour: shaders/skull_flame.gdshader, shift 0.45)
		if drift: light.light_color = col_a.lerp(col_b, 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.001 * 0.45))

## the fireflies: each flies its own wandering loop round the skull, wings a blur, its tail pulsing on and off
class Swarm extends Node3D:
	var r: Rng32
	var flies := []
	var lights := []
	var t := 0.0
	func _process(dt: float) -> void:
		t += dt
		for i in flies.size():
			var f: Dictionary = flies[i]
			var n: Node3D = f.node
			var a: float = t * float(f.sp) + float(f.ph)
			var rad: float = f.rad
			var p := Vector3(cos(a) * rad, float(f.hy) + sin(a * 1.7 + float(f.ph)) * 0.12, sin(a) * rad * 0.8)
			p = Basis(Vector3.RIGHT, float(f.tilt)) * p
			p += Vector3(sin(a * 3.1) * 0.04, sin(a * 2.3) * 0.03, cos(a * 2.7) * 0.04)
			var prev := n.position
			n.position = p
			var v := p - prev
			if v.length() > 1e-5: n.basis = Basis.looking_at(-v.normalized(), Vector3.UP)
			# the light: on for a moment, off a while, each its own rhythm
			var s := fmod(t + float(f.bph), float(f.blink)) / float(f.blink)
			var on := smoothstep(0.0, 0.08, s) * (1.0 - smoothstep(0.25, 0.45, s))
			var glow := 0.15 + on * 1.6
			(f.tail as StandardMaterial3D).emission_energy_multiplier = glow * 2.0
			(f.halo as ShaderMaterial).set_shader_parameter("power", glow)
			for w: MeshInstance3D in f.wings:
				w.rotation.z = sin(t * 60.0 + float(f.ph)) * 0.8 * (1.0 if w.position.x > 0 else -1.0)
			if i < lights.size():
				(lights[i] as OmniLight3D).position = p
				(lights[i] as OmniLight3D).light_energy = 0.15 + on * 0.9

## the cloud of butterflies: they sit on the skull opening and closing their wings, then all at once take off, whirl
## round it for a few seconds, and settle again. While they sit, any still flying is sent to a free spot of its own
## (their own search often found none among the crystals and kept them in the air)
class Flock extends Node:
	var r: Rng32
	var phase := 0    # 0 sitting, 1 up
	var t := 8.0
	func _process(dt: float) -> void:
		t -= dt
		var flies := get_parent().find_children("*", "", true, false).filter(func(n: Node) -> bool: return n is SpecButterfly.Fly)
		if phase == 0:
			for f in flies:
				if not f.looked: continue
				if f.state == SpecButterfly.Fly.SIT: f.timer = maxf(f.timer, 1.0)
				elif f.state == SpecButterfly.Fly.FLY:
					var spot := _spot(f)
					if spot.size():
						f.spot = spot
						f._claim(spot[0], true)
						f.state = SpecButterfly.Fly.LAND
						f.land_from = f.pos
						f.timer = 0.0
						f.retarget = 0.0
						f.land_key = Vector3.INF
			if t <= 0.0:
				phase = 1
				t = 3.5 + r.next() * 1.5
				for f in flies:
					if f.state == SpecButterfly.Fly.SIT: f.timer = r.next() * 0.35
		else:
			for f in flies:
				if f.state == SpecButterfly.Fly.FLY: f.timer = maxf(f.timer, 0.5)
			if t <= 0.0:
				phase = 0
				t = 7.0 + r.next() * 4.0

	## a free place to sit: on the bone, a span from any other (crystals or not — it lands among them)
	func _spot(f) -> Array:
		var taken: Array = f._taken()
		var perch: Array = f.perch
		if perch.is_empty(): return []
		for k in 16:
			var q: Array = perch[int(r.next() * perch.size())]
			var ok := true
			for o: Vector3 in taken:
				if o.distance_to(q[0]) < float(f.size) * 1.1: ok = false
			if ok: return q
		return []

## deathless: every piece of the skull (its bone shards, teeth, jaw, crystals, moss) on a seven-second round — lying
## scattered on the ground, rising and flying home (the cracks lit as they close), whole for a while, then falling
## apart again under its own weight
class Shatter extends Node:
	const ROUND := 7.0
	var r: Rng32
	var bone_m: ShaderMaterial
	var low_pts := PackedVector3Array()
	var pieces := []   # [node, home, floor, delay, spin axis]
	var t := 3.2       # (begins whole: the card's first look is the skull)
	var ready_ := false
	func _setup() -> void:
		var top := get_parent() as Node3D
		# the ground below it, in the space its pieces live in (the skull may be posed in a leaning node)
		var up := (top.global_transform.basis.inverse() * Vector3.UP).normalized() if top.is_inside_tree() else Vector3.UP
		var floor_h := INF
		for v in low_pts: floor_h = minf(floor_h, v.dot(up))
		var nodes := []
		for n in top.get_children():
			if n == self or n is Light3D or not (n is Node3D): continue
			if n.get_script() != null: continue
			if n is GeometryInstance3D and not (n as GeometryInstance3D).visible: continue
			if n.name == "shards":
				for c in n.get_children(): nodes.append(c)
			else:
				nodes.append(n)
		var mid := Vector3.ZERO
		for v in low_pts: mid += v
		mid /= maxf(1.0, low_pts.size())
		# where each piece comes to rest: scattered round the skull's foot, none on top of another, the bigger ones
		# nearer the middle; a shard of the vault lies with its outer face up (as a broken bowl does), anything else
		# tumbled any way; each set down so its lowest point just touches the ground
		var info := []
		for n: Node3D in nodes:
			var pts := _points(n)
			if pts.is_empty(): continue
			var c := Vector3.ZERO
			for p in pts: c += p
			c /= pts.size()
			var size := 0.0
			for p in pts: size = maxf(size, p.distance_to(c))
			info.append([n, pts, c, size])
		info.sort_custom(func(a: Array, b: Array) -> bool: return float(a[3]) > float(b[3]))
		var placed := []   # [ground point, radius]
		for it: Array in info:
			var n: Node3D = it[0]
			var pts: PackedVector3Array = it[1]
			var c: Vector3 = it[2]
			var size: float = it[3]
			var rot: Basis
			if n.get_parent() and n.get_parent().name == "shards":
				var outn := (c - mid).normalized()
				rot = Basis(up, r.next() * TAU) * Basis(_turn(outn, up))
			else:
				rot = Basis(Vector3(r.next() - 0.5, r.next() - 0.5, r.next() - 0.5).normalized(), r.next() * TAU)
			# a free place on the ground
			var flat := (c - mid) - up * (c - mid).dot(up)
			var dir := flat.normalized() if flat.length() > 0.01 else Vector3(1, 0, 0)
			var at := Vector3.ZERO
			for tries in 40:
				var d := dir.rotated(up, (r.next() - 0.5) * (0.8 + float(tries) * 0.06))
				var dist := 0.12 + r.next() * 0.25 + float(tries) * 0.012
				var cand := mid - up * mid.dot(up) + d * dist
				var ok := true
				for q: Array in placed:
					if (q[0] as Vector3).distance_to(cand) < (float(q[1]) + size) * 0.75: ok = false
				at = cand
				if ok: break
			placed.append([at, size])
			# down onto the ground: the lowest of its points after the turn on the floor
			var low := INF
			for p in pts: low = minf(low, (rot * (p - c)).dot(up))
			var target := at + up * (floor_h - low + 0.004)
			var fl := Transform3D(rot, target - rot * c) * n.transform
			pieces.append([n, n.transform, fl, r.next() * 0.45, up])
		ready_ = true

	## a few points of a piece, in the space it lives in (its vertices, or the corners of its box)
	func _points(n: Node3D) -> PackedVector3Array:
		var out := PackedVector3Array()
		if n is MeshInstance3D and (n as MeshInstance3D).mesh:
			var m := (n as MeshInstance3D).mesh
			var arr := m.surface_get_arrays(0) if m.get_surface_count() else []
			if arr.size() and arr[Mesh.ARRAY_VERTEX] != null:
				var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				var step := maxi(1, vs.size() / 80)
				for i in range(0, vs.size(), step): out.append(n.transform * vs[i])
				return out
		if n is VisualInstance3D:
			var bb := (n as VisualInstance3D).get_aabb()
			for k in 8: out.append(n.transform * bb.get_endpoint(k))
		return out

	## the turn that brings a onto b
	static func _turn(a: Vector3, b: Vector3) -> Quaternion:
		var c := a.cross(b)
		if c.length() < 1e-5: return Quaternion() if a.dot(b) > 0.0 else Quaternion(Vector3.RIGHT, PI)
		return Quaternion(c.normalized(), a.angle_to(b))

	func _process(dt: float) -> void:
		if not ready_:
			_setup()
		t = fmod(t + dt, ROUND)
		var glow := 0.0
		for p: Array in pieces:
			var n: Node3D = p[0]
			if not is_instance_valid(n): continue
			var d: float = p[3]
			var tt := t - d
			var s := 0.0   # 0 home .. 1 on the ground
			var lift := 0.0
			if tt < 1.2: s = 1.0
			elif tt < 2.9:
				var k := (tt - 1.2) / 1.7
				var e := 1.0 - pow(1.0 - k, 3.0)
				s = 1.0 - e
				lift = sin(k * PI) * 0.18
			elif tt < 5.3: s = 0.0
			elif tt < 6.4:
				var k2 := (tt - 5.3) / 1.1
				s = k2 * k2
				lift = sin(k2 * PI) * 0.05
			else: s = 1.0
			var x: Transform3D = (p[1] as Transform3D).interpolate_with(p[2], s)
			x.origin += (p[4] as Vector3) * lift
			n.transform = x
		# the cracks light up as it closes, and fade while it stands whole
		if t > 2.4 and t < 5.3: glow = clampf(1.0 - (t - 2.6) / 2.4, 0.0, 1.0)
		if bone_m: bone_m.set_shader_parameter("deathless", 0.2 + glow * 1.4)
