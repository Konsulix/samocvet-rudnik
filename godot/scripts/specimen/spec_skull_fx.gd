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

static func dress(b: RefCounted, sk: Dictionary, bones: Array, nrs: Array, bone_m: Material) -> void:
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
	if sk.get("lantern", false) and eyes.size(): _fireflies(root, r, eyes[0].deep.lerp(eyes[1].deep if eyes.size() > 1 else eyes[0].deep, 0.5) + Vector3(0, 0.08, -0.15), 0.16, 22, 0.05, false)
	if int(sk.get("pile", 0)) > 0: _pile(root, sk, r, bones, bone_m)
	match fx:
		"yaga": _yaga(root, sk, r, eyes)
		"watching": _watching(root, r, eyes)
		"candle": _candle(root, sk, r, bones, surf)
		"fireflies": _fireflies(root, r, Vector3(0, 0.1, 0.05), 0.75, 64, 0.14, true)
		"flutter": _flock(root, r)
		"deathless": root.set_meta("dim", true)

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
			at += Vector3(float(e.sx) * rad * 0.25, -rad * 0.55, 0.01)
			bas = Basis(Vector3.BACK, float(e.sx) * 0.35) * Basis(Vector3.RIGHT, PI * 0.5 - 0.5) * Basis(Vector3.UP, r.next() * TAU)
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
		if h.is_empty(): return
		ring.append(h[0])
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

## Yaga's fire: a flame burning in each eye socket, licking up over the rim, throwing its light on the bone
static func _yaga(root: Node3D, sk: Dictionary, r: Rng32, eyes: Array) -> void:
	var col: Color = Stones.pick_w(FIRE, Rng32.new(int(sk.skin_seed) + 77))
	root.set_meta("dark", true)
	for e: Dictionary in eyes:
		var rr: float = e.r
		for j in 2:
			var q := MeshInstance3D.new()
			var qm := QuadMesh.new()
			qm.size = Vector2(rr * (2.0 - j * 0.6), rr * (3.2 - j * 0.8))
			q.mesh = qm
			var m := ShaderMaterial.new()
			m.shader = FLAME
			m.set_shader_parameter("col", Vector3(col.r, col.g, col.b))
			m.set_shader_parameter("seed", r.next() * 20.0)
			m.set_shader_parameter("speed", 0.9 + r.next() * 0.4)
			m.set_shader_parameter("power", 0.6 if j == 0 else 0.9)
			q.material_override = m
			q.position = (e.deep as Vector3).lerp(e.front, 0.55) + Vector3(0, rr * (0.95 - j * 0.3), 0)
			root.add_child(q)
		var l := OmniLight3D.new()
		l.light_color = col
		l.light_energy = 1.3
		l.omni_range = 0.9
		l.position = (e.front as Vector3) + Vector3(0, 0.02, 0.04)
		root.add_child(l)
		var fl := Flicker.new()
		fl.light = l
		fl.base = 1.3
		fl.r = Rng32.new(int(sk.skin_seed) + int(e.sx * 9.0))
		root.add_child(fl)

## eyes that follow you: a cold point of light deep in each socket, turned toward the viewer as the find turns, and
## blinking out now and then
static func _watching(root: Node3D, r: Rng32, eyes: Array) -> void:
	root.set_meta("dark", true)
	var col := Color(1.0, 0.25, 0.12) if r.next() < 0.6 else Color(0.85, 0.95, 0.4)
	var w := Watch.new()
	for e: Dictionary in eyes:
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2.ONE * float(e.r) * 1.3
		q.mesh = qm
		var m := ShaderMaterial.new()
		m.shader = FLAME
		m.set_shader_parameter("col", Vector3(col.r, col.g, col.b))
		m.set_shader_parameter("mode", 1)
		m.set_shader_parameter("power", 3.0)
		q.material_override = m
		var home: Vector3 = (e.deep as Vector3).lerp(e.front, 0.75)
		q.position = home
		root.add_child(q)
		w.eyes.append([q, home, float(e.r)])
	root.add_child(w)

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
		var w0 := 0.014 + r.next() * 0.008
		SpecSkull._tongue(root, sm[0], sm[1], w0, w0 * 1.6, surf, wax, r.next() * 5.0)
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
static func _fireflies(root: Node3D, r: Rng32, centre: Vector3, rad: float, n: int, roam: float, swarm: bool) -> void:
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
	mesh.custom_aabb = AABB(centre - Vector3.ONE * (rad + roam * 2.0), Vector3.ONE * (rad + roam * 2.0) * 2.0)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := ShaderMaterial.new()
	m.shader = GLOW
	m.set_shader_parameter("roam", roam)
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
	else:
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

## the watching eyes: each point drifts toward the viewer within its socket; both blink out now and then
class Watch extends Node:
	var eyes := []   # [quad, home, socket radius]
	var t := 3.0
	var blink := 0.0
	func _process(dt: float) -> void:
		var cam := get_viewport().get_camera_3d() if get_viewport() else null
		t -= dt
		if t <= 0.0:
			blink = 0.25
			t = 2.5 + randf() * 4.0
		blink = maxf(0.0, blink - dt)
		var shut := 1.0 - sin(clampf(blink / 0.25, 0.0, 1.0) * PI)
		for e: Array in eyes:
			var q: Node3D = e[0]
			if not is_instance_valid(q): continue
			var home: Vector3 = e[1]
			var off := Vector3.ZERO
			if cam:
				var parent := q.get_parent() as Node3D
				var cl := parent.to_local(cam.global_position)
				var d := (cl - home)
				off = Vector3(d.x, d.y, 0).normalized() * float(e[2]) * 0.22 * clampf(Vector2(d.x, d.y).length() / maxf(0.01, absf(d.z)), 0.0, 1.0)
			q.position = home + off
			q.scale = Vector3(1.0, maxf(0.08, shut), 1.0)

## the cloud of butterflies: every few seconds all the resting ones take off together
class Flock extends Node:
	var r: Rng32
	var t := 4.0
	func _process(dt: float) -> void:
		t -= dt
		if t > 0.0: return
		t = 7.0 + r.next() * 5.0
		for n in get_parent().find_children("*", "", true, false):
			if n is SpecButterfly.Fly:
				var f = n
				if f.state == SpecButterfly.Fly.SIT: f.timer = r.next() * 0.3
