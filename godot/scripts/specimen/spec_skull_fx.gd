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
			var e := eye(surf, sx)
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
		"fireflies": _fireflies(root, r, Vector3(0, 0.1, 0.05), 0.75, 64, 0.14, true)
		"flutter": _flock(root, r)
		"deathless": _shatter(root, sk, r, bones[0], bone_m)

## an eye socket of this skull, found on the skull itself (as SpecSkull._lip): rays straight at the face fall deep into
## the opening and stop short on the bone round it. {front: centre on the rim's plane, deep: centre at the socket's
## floor, r: the opening's radius, sx}
static func eye(surf: SpecSurf, sx: float) -> Dictionary:
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
		if m > 0.75 and i % 2 == 0: spots.append([cr.v[i], nr[i]])
	return spots

## crystals growing in the geode's pits: the find's own, small, crowded, pointing out of the pit
static func _geode(sk: Dictionary, r: Rng32, crystal: Callable, lean: Callable) -> void:
	var spots: Array = sk.geode_pits
	var put := []
	for t in 260:
		if put.size() >= 46 or spots.is_empty(): break
		var q: Array = spots[int(r.next() * spots.size())]
		var p: Vector3 = q[0]
		var ok := true
		for o: Vector3 in put:
			if o.distance_to(p) < 0.04: ok = false
		if not ok: continue
		put.append(p)
		crystal.call(0.08 + r.next() * 0.2, p - (q[1] as Vector3) * 0.006, lean.call(q[1], 0.5))
	if put.size(): (sk.marks as Array).append(["sk_geode", put[0], Vector3.BACK])

## obols on the eyes: two old coins laid over the sockets, gold or silver, one now and then slipped askew
static func _coins(root: Node3D, sk: Dictionary, r: Rng32, eyes: Array) -> void:
	var gold := r.next() < 0.65
	for k in eyes.size():
		var e: Dictionary = eyes[k]
		var rad: float = float(e.r) * 1.15
		var cm := CylinderMesh.new()
		cm.top_radius = rad
		cm.bottom_radius = rad
		cm.height = 0.012
		cm.radial_segments = 40
		var m := ShaderMaterial.new()
		m.shader = COIN
		m.set_shader_parameter("metal_col", Vector3(0.95, 0.72, 0.32) if gold else Vector3(0.82, 0.83, 0.86))
		m.set_shader_parameter("rad", rad)
		m.set_shader_parameter("seed", r.next() * 10.0)
		var mi := MeshInstance3D.new()
		mi.mesh = cm
		mi.material_override = m
		var slip := k == 1 and r.next() < 0.35
		var at: Vector3 = (e.front as Vector3) + Vector3(0, 0, 0.012)
		var bas := Basis(Vector3.RIGHT, PI * 0.5 - 0.15) * Basis(Vector3.UP, r.next() * TAU)
		if slip:
			at += Vector3(float(e.sx) * rad * 0.2, -rad * 0.7, -0.012)
			bas = Basis(Vector3.BACK, float(e.sx) * 0.4) * Basis(Vector3.RIGHT, PI * 0.5 - 0.32) * Basis(Vector3.UP, r.next() * TAU)
		mi.transform = Transform3D(bas, at)
		root.add_child(mi)
		if k == 0: (sk.marks as Array).append(["sk_coins", at, Vector3.BACK])

## Koschei's diadem: a thin band of tarnished gold round the brow, a little askew, its points rising, the front one
## tallest with a red stone at its foot
static func _diadem(root: Node3D, sk: Dictionary, r: Rng32, surf: SpecSurf) -> void:
	var bb := AABB()
	for k in surf.ta.size(): bb = AABB(surf.ta[k], Vector3.ZERO) if k == 0 else bb.expand(surf.ta[k])
	var y0 := bb.position.y + bb.size.y * 0.72
	var tilt := (r.next() - 0.5) * 0.12
	var roll := (r.next() - 0.5) * 0.1
	var n := 36
	var ring := []
	for k in n:
		var a := TAU * k / n
		var y := y0 + tilt * cos(a) + roll * sin(a)
		var o := Vector3(sin(a) * 1.2, y, cos(a) * 1.2)
		var h := surf.ray(o, (Vector3(0, y, 0) - o).normalized(), 1.5)
		ring.append(h[0] if h.size() else null)
	var miss := ring.count(null)
	if miss > n / 3: return
	for k in n:
		if ring[k] == null:
			for d in range(1, n):
				var q2: Variant = ring[(k + d) % n]
				if q2 != null:
					ring[k] = q2
					break
	var cen := Vector3.ZERO
	for p: Vector3 in ring: cen += p
	cen /= ring.size()
	var g := Geo.new()
	var hb := 0.022
	var out := []
	for k in n:
		var p: Vector3 = ring[k]
		var od := Vector3(p.x - cen.x, 0, p.z - cen.z).normalized()
		out.append(od)
		var base := p + od * 0.008
		g.v.append_array([base - Vector3(0, hb, 0), base + Vector3(0, hb, 0), base + od * 0.012 - Vector3(0, hb, 0), base + od * 0.012 + Vector3(0, hb, 0)])
	for k in n:
		var a0 := k * 4
		var a1 := ((k + 1) % n) * 4
		# outer face, top, bottom (the inner face is against the bone)
		g.idx.append_array([a0 + 2, a1 + 2, a0 + 3, a0 + 3, a1 + 2, a1 + 3])
		g.idx.append_array([a0 + 1, a0 + 3, a1 + 1, a1 + 1, a0 + 3, a1 + 3])
		g.idx.append_array([a0, a1, a0 + 2, a0 + 2, a1, a1 + 2])
	# the points: every third, taller toward the front
	var gems := []
	for k in range(0, n, 3):
		var p: Vector3 = ring[k]
		var od: Vector3 = out[k]
		var front := 0.5 + 0.5 * cos(TAU * k / n)
		var hgt := 0.035 + front * 0.05
		var side := Vector3.UP.cross(od).normalized() * 0.022
		var base := p + od * 0.014 + Vector3(0, hb * 0.6, 0)
		var tip := base + Vector3(0, hgt, 0) + od * 0.006
		var i0 := g.v.size()
		g.v.append_array([base - side, base + side, tip, base - side - od * 0.01, base + side - od * 0.01])
		g.idx.append_array([i0, i0 + 2, i0 + 1, i0 + 3, i0 + 4, i0 + 2, i0, i0 + 3, i0 + 2, i0 + 1, i0 + 2, i0 + 4])
		if front > 0.85: gems.append([base + od * 0.006 + Vector3(0, 0.012, 0), od])
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.62, 0.47, 0.22)
	m.metallic = 1.0
	m.roughness = 0.38
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	U.mesh(g.to_soup(), m, root)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.55, 0.03, 0.05)
	gm.roughness = 0.08
	gm.metallic_specular = 1.0
	gm.emission_enabled = true
	gm.emission = Color(0.25, 0.0, 0.02)
	for q: Array in gems:
		var s := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.014
		sm.height = 0.022
		s.mesh = sm
		s.material_override = gm
		s.position = q[0]
		root.add_child(s)
	var fp: Vector3 = ring[0]
	(sk.marks as Array).append(["sk_diadem", fp + Vector3(0, 0.04, 0), Vector3.BACK])

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

## Yaga's fire, as on the fence round her hut: the sockets full of fire — tongues pouring up out of each eye over the
## brow, each its own, the whole fire breathing (it dies down, then roars up), sparks rising off it, a glow deep in the
## sockets and the fire's light leaping over the bone
static func _yaga(root: Node3D, sk: Dictionary, r: Rng32, eyes: Array) -> void:
	var col: Color = Stones.pick_w(FIRE, Rng32.new(int(sk.skin_seed) + 77))
	root.set_meta("dark", true)
	var breath := r.next() * 10.0
	for e: Dictionary in eyes:
		var rr: float = e.r
		var front: Vector3 = e.front
		var deep: Vector3 = e.deep
		# the glow down in the socket
		var g := MeshInstance3D.new()
		var gq := QuadMesh.new()
		gq.size = Vector2.ONE * rr * 2.2
		g.mesh = gq
		var gm := ShaderMaterial.new()
		gm.shader = FLAME
		gm.set_shader_parameter("col", Vector3(col.r, col.g, col.b))
		gm.set_shader_parameter("mode", 1)
		gm.set_shader_parameter("power", 1.6)
		g.material_override = gm
		g.position = deep.lerp(front, 0.4)
		root.add_child(g)
		# the tongues: a big one and two smaller to its sides, rooted on the socket's lower rim, rising over the brow
		for j in 3:
			var q := MeshInstance3D.new()
			var qm := QuadMesh.new()
			var big := j == 0
			qm.size = Vector2(rr * (1.6 if big else 1.0), rr * (4.4 if big else 2.8 + r.next()))
			q.mesh = qm
			var m := ShaderMaterial.new()
			m.shader = FLAME
			m.set_shader_parameter("col", Vector3(col.r, col.g, col.b))
			m.set_shader_parameter("seed", r.next() * 20.0)
			m.set_shader_parameter("speed", 1.1 + r.next() * 0.5)
			m.set_shader_parameter("power", 0.8)
			m.set_shader_parameter("breath", breath + float(j) * 0.4)
			q.material_override = m
			var off := 0.0 if big else (rr * 0.55 * (1.0 if j == 1 else -1.0))
			q.position = front + Vector3(off, -rr * 0.35 + float(qm.size.y) * 0.5, 0.02 + float(j) * 0.004)
			root.add_child(q)
		# sparks flying up off it
		_fireflies(root, r, front + Vector3(0, rr * 0.4, 0.02), rr * 0.7, 14, 0.02, false, col, rr * 6.0)
		var l := OmniLight3D.new()
		l.light_color = col
		l.light_energy = 1.1
		l.omni_range = 1.0
		l.position = front + Vector3(0, rr, 0.1)
		root.add_child(l)
		var fl := Flicker.new()
		fl.light = l
		fl.base = 1.1
		fl.r = Rng32.new(int(sk.skin_seed) + int(float(e.sx) * 9.0))
		root.add_child(fl)
	if eyes.size(): (sk.marks as Array).append(["fx", (eyes[0].front as Vector3) + Vector3(0, float(eyes[0].r), 0), Vector3.BACK])

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
		var c: Vector3 = (e.deep as Vector3).lerp(e.front, 0.45)
		var R := rr * 0.78
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

## a light flickering as a flame does
class Flicker extends Node:
	var light: OmniLight3D
	var base := 2.0
	var r: Rng32
	var t := 0.0
	var to := 1.0
	func _process(dt: float) -> void:
		if not is_instance_valid(light): return
		t -= dt
		if t <= 0.0:
			to = 0.75 + r.next() * 0.45
			t = 0.05 + r.next() * 0.12
		light.light_energy = lerpf(light.light_energy, base * to, minf(1.0, dt * 12.0))

## the cloud of butterflies: they sit on the skull opening and closing their wings, then all at once take off, whirl
## round it for a few seconds, and settle again
class Flock extends Node:
	var r: Rng32
	var phase := 0    # 0 sitting, 1 up
	var t := 8.0
	func _process(dt: float) -> void:
		t -= dt
		var flies := get_parent().find_children("*", "", true, false).filter(func(n: Node) -> bool: return n is SpecButterfly.Fly)
		if phase == 0:
			for f in flies:
				# (sitting ones stay put; any still up comes down soon)
				if f.state == SpecButterfly.Fly.SIT: f.timer = maxf(f.timer, 1.0)
				elif f.state == SpecButterfly.Fly.FLY: f.timer = minf(f.timer, 0.4)
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
		var stack: Array[Node] = top.get_children()
		var nodes := []
		for n in stack:
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
		for n: Node3D in nodes:
			var home := n.transform
			var c := home.origin
			if n is MeshInstance3D and (n as MeshInstance3D).mesh:
				c = home * (n as MeshInstance3D).mesh.get_aabb().get_center()
			var flat := (c - mid) - up * (c - mid).dot(up)
			var out := flat.normalized() if flat.length() > 0.01 else Vector3(r.next() - 0.5, 0, r.next() - 0.5).normalized()
			var target := c + out * (0.1 + r.next() * 0.35) + up * (floor_h + 0.03 - c.dot(up))
			var axis := Vector3(r.next() - 0.5, r.next() - 0.5, r.next() - 0.5).normalized()
			var rot := Basis(axis, (0.6 + r.next() * 1.6) * (1.0 if r.next() < 0.5 else -1.0))
			var fl := Transform3D(rot, target - rot * c) * home
			pieces.append([n, home, fl, r.next() * 0.45, up])
		ready_ = true
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
