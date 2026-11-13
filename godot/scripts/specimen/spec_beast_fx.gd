class_name SpecBeastFx
extends RefCounted
## The legends of an animal's skull (SpecSkull, docs/skulls.md "черепа зверей"), each for its kind of beast:
## horned — blossoming horns (they flower, shed their petals and flower again), starlit horns (dark glass with a sky
## inside), thunder horns (lightning leaps between their tips); hunters — kitsune fire (blue wisps circling, diving into
## the eyes), the wolf's moon (a moon over it going through its phases, the eyes flashing at the full), the beast's
## breath (steam from its nose, an ember glowing in its throat); birds — phoenix feathers (embers running along its
## feathers, sparks off its crown), the raven's eye (a living eye in its socket, blinking); the old reptiles —
## lava awakening (basalt bone, lava in its cracks, the jaw opening on heat and ash), the amber drop (the skull in a drop
## of amber, old insects drifting in it). Everything in the skull's own space (face toward +Z), before it is posed.

const FLAME := preload("res://shaders/skull_flame.gdshader")
const GLOW := preload("res://shaders/skull_glow.gdshader")
const MOON := preload("res://shaders/beast_moon.gdshader")
const STEAM := preload("res://shaders/beast_steam.gdshader")
const PETALS := preload("res://shaders/beast_petals.gdshader")
const GHOST := preload("res://shaders/beast_ghost.gdshader")
const STAR_HORN := preload("res://shaders/horn_star.gdshader")
const GHOST_DIR := "res://assets/specimen/ghosts/"
const U := preload("res://scripts/specimen/spec_util.gd")

## which legends each beast can have (SpecGenome's pool for an animal's skull)
const HORNED := ["deer", "mouflon", "ram", "longhorn", "musk_ox"]
const POOL := {
	deer = ["blossom", "blossom", "starhorn", "thunder"], mouflon = ["blossom", "starhorn", "thunder", "thunder"],
	ram = ["thunder", "thunder", "starhorn", "blossom"], longhorn = ["thunder", "starhorn", "blossom"],
	musk_ox = ["thunder", "starhorn", "blossom", "breath"],
	wolf = ["wolfmoon", "wolfmoon", "foxfire", "breath"], fox = ["foxfire", "foxfire", "wolfmoon"],
	lion = ["breath", "breath", "foxfire", "wolfmoon"], bear = ["breath", "breath", "wolfmoon", "foxfire"],
	horse = ["breath", "wolfmoon", "foxfire"],
	raven = ["raveneye", "raveneye", "phoenix"], spoonbill = ["phoenix", "raveneye"], hornbill = ["phoenix", "phoenix", "raveneye"],
	alligator = ["lavaborn", "amberdrop"], trex = ["lavaborn", "lavaborn", "amberdrop"], triceratops = ["amberdrop", "lavaborn"]}
const ALL := ["blossom", "starhorn", "thunder", "foxfire", "wolfmoon", "breath", "phoenix", "raveneye", "lavaborn", "amberdrop", "ghost"]

## a beast's legends: its kind's, and its ghost if there is a head for it (assets/specimen/ghosts)
static func pool(beast: String) -> Array:
	var out: Array = (POOL.get(beast, []) as Array).duplicate()
	if ResourceLoader.exists(GHOST_DIR + beast + ".json"): out.append_array(["ghost", "ghost"])
	return out

static func dress(b: RefCounted, sk: Dictionary, bones: Array, nrs: Array, bone_m: Material, surf: SpecSurf) -> void:
	var root: Node3D = b.root
	var r := Rng32.new(int(sk.skin_seed) + 911)
	var cr: Geo = bones[0]
	match String(sk.fx):
		"foxfire": _foxfire(root, sk, r, cr, surf)
		"wolfmoon": _wolfmoon(root, sk, r, cr, surf)
		"breath": _breath(root, sk, r, cr)
		"blossom": _blossom(root, sk, r)
		"starhorn": _starhorn(sk)
		"thunder": _thunder(root, sk, r)
		"phoenix": _phoenix(root, sk, r, cr, bone_m)
		"raveneye": _raveneye(root, sk, r, cr, surf)
		"lavaborn": _lavaborn(root, sk, r, cr, bone_m)
		"amberdrop": _amberdrop(root, sk, r, bones)
		"ghost": _ghost(root, sk, r, bones, surf)

## the head's middle and size
static func _box(cr: Geo) -> AABB:
	return cr.aabb()

## the tip of the snout (the points furthest forward, +Z), and the nose a little back and up from it
static func _snout(cr: Geo) -> Vector3:
	var bb := cr.aabb()
	var acc := Vector3.ZERO
	var n := 0
	var zmax := bb.end.z
	for p in cr.v:
		if p.z > zmax - bb.size.z * 0.05:
			acc += p
			n += 1
	return acc / maxf(1.0, n)

static func _glow_mat(col: Color, power: float, seed: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = FLAME
	m.set_shader_parameter("col", Vector3(col.r, col.g, col.b))
	m.set_shader_parameter("col2", Vector3(col.r, col.g, col.b))
	m.set_shader_parameter("mode", 1)
	m.set_shader_parameter("power", power)
	m.set_shader_parameter("seed", seed)
	return m

static func _quad(parent: Node3D, size: float, m: Material, at := Vector3.ZERO) -> MeshInstance3D:
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2.ONE * size
	q.mesh = qm
	q.material_override = m
	q.position = at
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(q)
	return q

# ---------------------------------------------------------------- hunters

## kitsune fire: 3 to 9 blue wisps (as many as a fox's tails) circle the head on their own tilted rings, each a soft
## ball of cold fire with a tail of fading sparks; now and then one dives into an eye and out again
static func _foxfire(root: Node3D, sk: Dictionary, r: Rng32, cr: Geo, surf: SpecSurf) -> void:
	root.set_meta("dark", true)
	var bb := _box(cr)
	var w := Wisps.new()
	w.c = bb.get_center() + Vector3(0, bb.size.y * 0.1, 0)
	w.rad = maxf(bb.size.x, maxf(bb.size.y, bb.size.z)) * 0.62
	w.r = Rng32.new(int(r.next() * 100000))
	for sx: float in [-1.0, 1.0]:
		var e := SpecSkullFx.eye(surf, sx, sk)
		if not e.is_empty(): w.eyes.append(e.deep)
	var n := 3 + int(r.next() * 7.0)
	sk.foxfire_n = n
	var cols := [Color(0.08, 0.35, 1.0), Color(0.1, 0.55, 1.0), Color(0.35, 0.15, 1.0)]
	var base: Color = cols[int(r.next() * 3.0)]
	for k in n:
		var node := Node3D.new()
		w.add_child(node)
		var col := base.lerp(Color(0.9, 0.95, 1.0), r.next() * 0.2)
		# a ball of cold fire: a licking tongue over a soft glow, a white heart
		var fm := ShaderMaterial.new()
		fm.shader = FLAME
		fm.set_shader_parameter("col", Vector3(col.r, col.g, col.b))
		fm.set_shader_parameter("col2", Vector3(col.r, col.g, col.b))
		fm.set_shader_parameter("mode", 0)
		fm.set_shader_parameter("power", 0.75)
		fm.set_shader_parameter("seed", r.next() * 20.0)
		fm.set_shader_parameter("speed", 1.6)
		var tongue := _quad(node, w.rad * 0.34, fm, Vector3(0, w.rad * 0.08, 0))
		(tongue.mesh as QuadMesh).size = Vector2(w.rad * 0.2, w.rad * 0.36)
		_quad(node, w.rad * 0.55, _glow_mat(col, 0.55, r.next() * 20.0))
		_quad(node, w.rad * 0.06, _glow_mat(Color(0.7, 0.85, 1.0), 1.2, r.next() * 20.0))
		var trail := []
		for j in 7:
			var t := _quad(w, w.rad * (0.13 - j * 0.014), _glow_mat(col, 0.7 - j * 0.09, r.next() * 20.0))
			trail.append(t)
		w.items.append({node = node, trail = trail, hist = [], ph = r.next() * TAU, sp = (0.45 + r.next() * 0.35) * (1.0 if r.next() < 0.7 else -1.0),
			tilt = Basis(Vector3(r.next() - 0.5, 0, r.next() - 0.5).normalized(), 0.3 + r.next() * 0.7), rr = 0.75 + r.next() * 0.4, bob = r.next() * TAU})
	var l := OmniLight3D.new()
	l.light_color = base
	l.light_energy = 1.4
	l.omni_range = w.rad * 3.0
	w.light = l
	w.add_child(l)
	root.add_child(w)
	(sk.marks as Array).append(["fx", w.c + Vector3(0, w.rad * 0.6, w.rad * 0.4), Vector3.BACK])

class Wisps extends Node3D:
	var c := Vector3.ZERO
	var rad := 0.5
	var r: Rng32
	var items := []
	var eyes := []
	var light: OmniLight3D
	var t := 0.0
	var dive := -1
	var dive_t := 0.0
	var next_dive := 4.0
	func _process(dt: float) -> void:
		t += dt
		next_dive -= dt
		if dive < 0 and next_dive <= 0.0 and eyes.size():
			dive = int(r.next() * items.size())
			dive_t = 0.0
		var avg := Vector3.ZERO
		for k in items.size():
			var it: Dictionary = items[k]
			var a := float(it.ph) + t * float(it.sp)
			var p := c + (it.tilt as Basis) * Vector3(cos(a), sin(t * 0.7 + float(it.bob)) * 0.25, sin(a)) * rad * float(it.rr)
			if k == dive:
				# into the eye and out again: 2.4 s
				dive_t += dt
				var e: Vector3 = eyes[k % eyes.size()]
				var f := sin(clampf(dive_t / 2.4, 0.0, 1.0) * PI)
				p = p.lerp(e, smoothstep(0.0, 1.0, f) * 0.95)
				if dive_t >= 2.4:
					dive = -1
					next_dive = 5.0 + r.next() * 6.0
			var n: Node3D = it.node
			n.position = p
			var hist: Array = it.hist
			hist.push_front(p)
			if hist.size() > 24: hist.pop_back()
			var trail: Array = it.trail
			for j in trail.size():
				(trail[j] as Node3D).position = hist[mini(hist.size() - 1, (j + 1) * 2)]
			avg += p
		if light and items.size(): light.position = avg / items.size()

## the wolf's moon: a small moon hangs over the head in its own halo, going round its phases (half a minute a month);
## its cold light on the bone; at the full the eyes flash
static func _wolfmoon(root: Node3D, sk: Dictionary, r: Rng32, cr: Geo, surf: SpecSurf) -> void:
	root.set_meta("dark", true)
	var bb := _box(cr)
	var s := maxf(bb.size.x, maxf(bb.size.y, bb.size.z))
	var mo := MoonNode.new()
	var at := Vector3(bb.get_center().x, bb.end.y + s * 0.34, bb.get_center().z - s * 0.2)
	var ball := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = s * 0.13
	sm.height = s * 0.26
	ball.mesh = sm
	var mm := ShaderMaterial.new()
	mm.shader = MOON
	mm.set_shader_parameter("seed", r.next() * 50.0)
	ball.material_override = mm
	ball.position = at
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mo.add_child(ball)
	mo.moon = mm
	mo.halo = _glow_mat(Color(0.55, 0.7, 1.0), 0.8, 1.0)
	_quad(mo, s * 0.9, mo.halo, at - Vector3(0, 0, 0.02))
	var l := OmniLight3D.new()
	l.light_color = Color(0.65, 0.78, 1.0)
	l.omni_range = s * 4.0
	l.position = at
	mo.add_child(l)
	mo.light = l
	for sx: float in [-1.0, 1.0]:
		var e := SpecSkullFx.eye(surf, sx, sk)
		if e.is_empty(): continue
		var em := _glow_mat(Color(0.75, 0.9, 1.0), 0.0, r.next() * 9.0)
		_quad(root, float(e.r) * 2.6, em, (e.deep as Vector3).lerp(e.front, 0.6))
		mo.eyes.append(em)
	mo.t = r.next() * 30.0
	mo.at = at
	mo.sway = s * 0.15
	mo.ball = ball
	root.add_child(mo)
	# dust in its light, rising slowly
	SpecSkullFx._fireflies(root, r, bb.get_center() + Vector3(0, s * 0.1, 0), s * 0.7, 18, 0.03, false, Color(0.5, 0.65, 1.0), s * 0.5)
	(sk.marks as Array).append(["fx", at, Vector3.BACK])

class MoonNode extends Node3D:
	var moon: ShaderMaterial
	var halo: ShaderMaterial
	var light: OmniLight3D
	var eyes := []
	var t := 0.0
	var at := Vector3.ZERO
	var sway := 0.3
	var ball: MeshInstance3D
	func _process(dt: float) -> void:
		t += dt
		var ph := fmod(t / 30.0, 1.0)              # 0 new, 0.5 full
		# it crosses the sky over the head as the month goes: rising at one side, highest at the full, setting
		var arc := (ph - 0.5) * 2.0
		var p := at + Vector3(arc * sway * 2.0, -arc * arc * sway * 0.9, 0.0)
		for ch in get_children():
			if ch is MeshInstance3D or ch is OmniLight3D: (ch as Node3D).position = p - (Vector3(0, 0, 0.02) if ch != ball and ch is MeshInstance3D else Vector3.ZERO)
		var full := 0.5 - 0.5 * cos(ph * TAU)
		moon.set_shader_parameter("phase", ph)
		halo.set_shader_parameter("power", 0.15 + full * 0.9)
		light.light_energy = 0.25 + full * 1.6
		var flash := pow(maxf(0.0, 1.0 - absf(ph - 0.5) / 0.06), 2.0)
		for em: ShaderMaterial in eyes: em.set_shader_parameter("power", flash * 2.5)

## the beast's breath: it breathes — slow puffs of steam from its nose every four seconds, and in the dark of its
## throat an ember that glows up as it draws breath and dims as it lets it out
static func _breath(root: Node3D, sk: Dictionary, r: Rng32, cr: Geo) -> void:
	root.set_meta("dim", true)
	var bb := _box(cr)
	var s := maxf(bb.size.x, maxf(bb.size.y, bb.size.z))
	var tip := _snout(cr)
	var nose := tip + Vector3(0, s * 0.03, -s * 0.06)
	var v := PackedVector3Array()
	var uv2 := PackedVector2Array()
	var cl := PackedColorArray()
	var idx := PackedInt32Array()
	for k in 44:
		var c := Color(r.next(), r.next(), r.next(), float(k % 2))
		var i0 := v.size()
		for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			v.append(nose + Vector3((float(k % 2) - 0.5) * s * 0.06, 0, 0))
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
	mesh.custom_aabb = AABB(nose - Vector3.ONE * s, Vector3.ONE * s * 2.0)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := ShaderMaterial.new()
	m.shader = STEAM
	m.set_shader_parameter("dir", Vector3(0, 0.25, 1).normalized())
	m.set_shader_parameter("reach", s * 0.34)
	m.set_shader_parameter("size", s * 0.035)
	m.render_priority = 3
	mi.material_override = m
	root.add_child(mi)
	# the ember in the throat: behind the snout, low
	var throat := Vector3(bb.get_center().x, bb.position.y + bb.size.y * 0.3, lerpf(bb.get_center().z, tip.z, 0.35))
	var em := _glow_mat(Color(1.0, 0.45, 0.12), 1.0, 3.0)
	_quad(root, s * 0.45, em, throat)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.5, 0.2)
	l.omni_range = s * 0.9
	l.position = throat
	root.add_child(l)
	var bn := Breather.new()
	bn.ember = em
	bn.light = l
	root.add_child(bn)
	(sk.marks as Array).append(["fx", nose + Vector3(0, 0, s * 0.1), Vector3.BACK])

class Breather extends Node:
	var ember: ShaderMaterial
	var light: OmniLight3D
	func _process(_dt: float) -> void:
		# the same four-second breath as the steam (beast_steam.gdshader): out in the first third, in after
		var ph := fmod(Time.get_ticks_msec() / 1000.0 / 4.0, 1.0)
		var inhale := smoothstep(0.35, 0.85, ph) * (1.0 - smoothstep(0.92, 1.0, ph))
		var k := 0.25 + 0.75 * inhale
		ember.set_shader_parameter("power", 0.6 + k * 1.4)
		light.light_energy = 0.3 + k * 1.6

# ---------------------------------------------------------------- horns

## points on the horns (rp.x along them, 0 at the skull .. 1 at the tip) facing outward, from u0 to u1
static func _horn_pts(sk: Dictionary, n: int, u0: float, u1: float, r: Rng32) -> Array:
	if not sk.has("horn_geo"): return []
	var hg: Geo = sk.horn_geo
	var nr := hg.normals()
	var c := hg.aabb().get_center()
	var out := []
	for t in n * 40:
		if out.size() >= n: break
		var i := int(r.next() * hg.v.size())
		var u := hg.rp[i].x
		if u < u0 or u > u1: continue
		if nr[i].dot((hg.v[i] - c).normalized()) < 0.0 and nr[i].y < 0.2: continue
		var ok := true
		for q: Array in out:
			if (q[0] as Vector3).distance_to(hg.v[i]) < 0.06: ok = false
		if ok: out.append([hg.v[i], nr[i], u])
	return out

## the horns' two tips (the furthest along each, by side)
static func _horn_tips(sk: Dictionary) -> Array:
	if not sk.has("horn_geo"): return []
	var hg: Geo = sk.horn_geo
	var best := {}
	for i in hg.v.size():
		var sd := 1 if hg.v[i].x > 0.0 else -1
		if not best.has(sd) or hg.rp[i].x > hg.rp[int(best[sd])].x: best[sd] = i
	var out := []
	for sd: int in best: out.append(hg.v[int(best[sd])])
	return out

## blossoming horns: blossom along the horns — they open, petals stream off them on the air, they fall and close, and
## flower again (a quarter of a minute round)
static func _blossom(root: Node3D, sk: Dictionary, r: Rng32) -> void:
	var pts := _horn_pts(sk, 24, 0.15, 0.97, r)
	if pts.is_empty(): return
	var pals := [[Color(1.0, 0.82, 0.88), Color(0.95, 0.45, 0.62)], [Color(1.0, 1.0, 0.97), Color(1.0, 0.75, 0.82)],
		[Color(0.98, 0.72, 0.4), Color(0.85, 0.3, 0.2)], [Color(0.75, 0.6, 1.0), Color(1.0, 0.95, 0.6)]]
	var pal: Array = pals[int(r.next() * pals.size())]
	var bl := Blossom.new()
	root.add_child(bl)
	for q: Array in pts:
		var node := Node3D.new()
		node.position = q[0]
		bl.add_child(node)
		var bt := SpecBloom.batch()
		var face := ((q[1] as Vector3) + Vector3(0, 0.3, 0.3)).normalized()
		SpecBloom.head(bt, r, "cosmos" if r.next() < 0.7 else "bud", Vector3.ZERO, face, 0.22 + r.next() * 0.12, pal[0], pal[1])
		SpecBloom.flush(bt, node)
		node.scale = Vector3.ONE * 0.01
		bl.flowers.append([node, r.next() * 1.5])
	# the petals on the wind: one mesh of quads, each from a flower, drifting down and away
	var v := PackedVector3Array()
	var uv2 := PackedVector2Array()
	var cl := PackedColorArray()
	var idx := PackedInt32Array()
	for k in 90:
		var q: Array = pts[k % pts.size()]
		var c := Color(r.next(), r.next(), r.next(), 1)
		var i0 := v.size()
		for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			v.append(q[0])
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
	var hb := (sk.horn_geo as Geo).aabb()
	mesh.custom_aabb = hb.grow(1.0)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := ShaderMaterial.new()
	m.shader = PETALS
	m.set_shader_parameter("col", Vector3((pal[0] as Color).r, (pal[0] as Color).g, (pal[0] as Color).b))
	m.set_shader_parameter("col2", Vector3((pal[1] as Color).r, (pal[1] as Color).g, (pal[1] as Color).b))
	m.set_shader_parameter("fall", hb.size.y * 1.1 + 0.4)
	mi.material_override = m
	root.add_child(mi)
	bl.petals = m
	(sk.marks as Array).append(["fx", pts[0][0], pts[0][1]])

class Blossom extends Node3D:
	var flowers := []
	var petals: ShaderMaterial
	var t := 0.0
	func _process(dt: float) -> void:
		t += dt
		var ph := fmod(t, 15.0)
		var open := 0.0
		for f: Array in flowers:
			var d := float(f[1])
			# open (0–3 s), full (3–9), shedding and closing (9–13), bare (13–15)
			var k := smoothstep(d, d + 2.5, ph) * (1.0 - smoothstep(9.5 + d, 12.5 + d * 0.5, ph))
			(f[0] as Node3D).scale = Vector3.ONE * maxf(0.01, k)
			open += k
		open /= maxf(1.0, flowers.size())
		# (petals only off open flowers: a few on the air while they bloom, a shower as they drop, none once bare)
		var shower := smoothstep(7.0, 9.5, ph) * (1.0 - smoothstep(11.5, 13.0, ph))
		if petals: petals.set_shader_parameter("shed", clampf(minf(1.0, open * 1.6) * (0.2 + 0.8 * shower), 0.0, 1.0))

## starlit horns: the horns turned to dark glass with a night sky deep in them (horn.gdshader mode 5)
static func _starhorn(sk: Dictionary) -> void:
	if not sk.has("horn_mi"): return
	var m := ShaderMaterial.new()
	m.shader = STAR_HORN
	m.set_shader_parameter("seed", float(int(sk.skin_seed) % 97) * 0.7)
	(sk.horn_mi as MeshInstance3D).material_override = m
	if sk.has("horn_geo"):
		var tips := _horn_tips(sk)
		if tips.size(): (sk.marks as Array).append(["fx", tips[0], Vector3.UP])

## thunder horns: every few seconds lightning leaps from one horn's tip to the other's, the tips glowing hot before
static func _thunder(root: Node3D, sk: Dictionary, r: Rng32) -> void:
	var tips := _horn_tips(sk)
	if tips.size() < 2: return
	root.set_meta("dim", true)
	var a: Vector3 = tips[0]
	var z: Vector3 = tips[1]
	var bb := AABB(a, Vector3.ZERO).expand(z)
	bb = bb.grow(a.distance_to(z) * 0.15)
	var arc := HornArc.new()
	arc.pa = a
	arc.pz = z
	root.add_child(arc)
	arc.setup(bb, int(r.next() * 100000), Color(0.55, 0.65, 3.4))
	# the tips: a glow that builds before each leap
	for p: Vector3 in [a, z]:
		var g := _glow_mat(Color(0.6, 0.75, 1.0), 0.0, r.next() * 9.0)
		_quad(arc, a.distance_to(z) * 0.18, g, p)
		arc.tip_glow.append(g)
	(sk.marks as Array).append(["fx", a.lerp(z, 0.5), Vector3.BACK])

class HornArc extends SpecBolt:
	var pa := Vector3.ZERO
	var pz := Vector3.ZERO
	var tip_glow := []
	func _strike() -> void:
		_t = 0.0
		_next = 1.6 + rng.randf() * 2.4
		var segs := []
		var halo := []
		var d := pa.distance_to(pz)
		# (bowed up between the horns, as a spark leaps)
		var mid := pa.lerp(pz, 0.5) + Vector3(0, d * rng.randf_range(0.05, 0.25), d * rng.randf_range(-0.1, 0.15))
		var big := AABB(bounds.position - bounds.size, bounds.size * 3.0)
		_bolt(pa, mid, d * 0.12, 6, segs, halo, 1.0, 0.012 + d * 0.012, big.position, big.end, rng.randf())
		_bolt(mid, pz, d * 0.12, 6, segs, halo, 1.0, 0.012 + d * 0.012, big.position, big.end, rng.randf())
		mesh = _build(segs, halo)
		if sparks: sparks.restart()
	func _process(dt: float) -> void:
		super._process(dt)
		var k := _t / maxf(0.001, _next)
		var build := smoothstep(0.55, 1.0, k) * 1.6 + (1.0 - smoothstep(0.0, 0.25, _t)) * 2.0
		for g: ShaderMaterial in tip_glow: g.set_shader_parameter("power", build)

# ---------------------------------------------------------------- birds

## phoenix feathers: the feathers smoulder — embers run in waves along their edges and shafts (bone.gdshader skin 9,
## ember), sparks fly up off the crown, and once a round the whole cloak flares and cools
static func _phoenix(root: Node3D, sk: Dictionary, r: Rng32, cr: Geo, bone_m: Material) -> void:
	root.set_meta("dark", true)
	var bb := _box(cr)
	var s := maxf(bb.size.x, maxf(bb.size.y, bb.size.z))
	if bone_m is ShaderMaterial: (bone_m as ShaderMaterial).set_shader_parameter("ember", 1.0)
	SpecSkullFx._fireflies(root, r, Vector3(bb.get_center().x, bb.end.y - s * 0.1, bb.get_center().z - s * 0.1), s * 0.3, 26, 0.02, false, Color(1.0, 0.55, 0.15), s * 0.9)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.55, 0.2)
	l.omni_range = s * 2.0
	l.position = bb.get_center() + Vector3(0, s * 0.4, s * 0.3)
	root.add_child(l)
	var fl := Flare.new()
	fl.light = l
	fl.mat = bone_m as ShaderMaterial
	root.add_child(fl)
	(sk.marks as Array).append(["fx", Vector3(bb.get_center().x, bb.end.y, bb.get_center().z), Vector3.UP])

class Flare extends Node:
	var light: OmniLight3D
	var mat: ShaderMaterial
	var t := 0.0
	func _process(dt: float) -> void:
		t += dt
		# smoulder (0–4 s), the fire runs from the nose back over the head (4–6.5), charred and glowing (6.5–8), the
		# feathers grow again from the back of the head to the nose (8–11), whole (11–12)
		var ph := fmod(t, 12.0)
		var burn := 2.0
		var regrow := -1.0
		if ph >= 4.0 and ph < 11.0:
			burn = lerpf(1.15, -0.2, smoothstep(4.0, 6.5, ph))
			if ph >= 8.0: regrow = lerpf(-0.2, 1.2, smoothstep(8.0, 11.0, ph))
		var blaze := smoothstep(3.6, 4.4, ph) * (1.0 - smoothstep(6.2, 7.2, ph))
		if mat:
			mat.set_shader_parameter("burn_front", burn)
			mat.set_shader_parameter("regrow_front", regrow)
			mat.set_shader_parameter("ember_flare", blaze * 0.6)
		light.light_energy = 0.5 + 0.25 * sin(t * 7.0) * sin(t * 3.1) + blaze * 3.0

## the raven's eye: a living eye in its socket — black, wet, a dark gold ring — following you as the skull turns,
## blinking
static func _raveneye(root: Node3D, sk: Dictionary, r: Rng32, cr: Geo, surf: SpecSurf) -> void:
	var bb := _box(cr)
	var s := maxf(bb.size.x, maxf(bb.size.y, bb.size.z))
	var ball_m := StandardMaterial3D.new()
	ball_m.albedo_color = Color(0.02, 0.018, 0.016)
	ball_m.roughness = 0.05
	ball_m.metallic_specular = 1.0
	var iris_m := StandardMaterial3D.new()
	iris_m.albedo_color = Color(0.35, 0.22, 0.06)
	iris_m.emission_enabled = true
	iris_m.emission = Color(0.6, 0.38, 0.1)
	iris_m.emission_energy_multiplier = 0.6
	iris_m.roughness = 0.1
	var pupil_m := StandardMaterial3D.new()
	pupil_m.albedo_color = Color(0, 0, 0)
	pupil_m.roughness = 0.05
	var ey := BirdEye.new()
	for sx: float in [-1.0, 1.0]:
		var e := SpecSkullFx.eye(surf, sx, sk)
		if e.is_empty(): continue
		var rr: float = e.r
		var c: Vector3 = (e.deep as Vector3).lerp(e.front, 0.35)
		var axis := ((e.front as Vector3) - (e.deep as Vector3)).normalized()
		var R := rr * 0.8
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
		im.radius = R * 0.62
		im.height = R * 0.3
		iris.mesh = im
		iris.material_override = iris_m
		iris.position = Vector3(0, 0, R * 0.86)
		iris.rotation = Vector3(PI * 0.5, 0, 0)
		eye_n.add_child(iris)
		var pupil := MeshInstance3D.new()
		var pm := SphereMesh.new()
		pm.radius = R * 0.44
		pm.height = R * 0.22
		pupil.mesh = pm
		pupil.material_override = pupil_m
		pupil.position = Vector3(0, 0, R * 0.97)
		pupil.rotation = Vector3(PI * 0.5, 0, 0)
		eye_n.add_child(pupil)
		ey.eyes.append([eye_n, c, axis])
	root.add_child(ey)
	if ey.eyes.size(): (sk.marks as Array).append(["fx", ey.eyes[0][1], ey.eyes[0][2]])

class BirdEye extends Node:
	var eyes := []   # [node, centre, the socket's axis]
	var t := 2.0
	var blink := 0.0
	func _process(dt: float) -> void:
		var cam := get_viewport().get_camera_3d() if get_viewport() else null
		t -= dt
		if t <= 0.0:
			blink = 0.18
			t = 2.0 + randf() * 3.5
		blink = maxf(0.0, blink - dt)
		var shut := 1.0 - sin(clampf(blink / 0.18, 0.0, 1.0) * PI)
		for e: Array in eyes:
			var n: Node3D = e[0]
			if not is_instance_valid(n) or cam == null: continue
			var parent := n.get_parent() as Node3D
			var to := (parent.to_local(cam.global_position) - (e[1] as Vector3)).normalized()
			var ax: Vector3 = e[2]
			var ang := ax.angle_to(to)
			if ang > 0.7: to = ax.slerp(to, 0.7 / ang)
			if e.size() < 4: e.append(ax)
			var cur: Vector3 = (e[3] as Vector3).slerp(to, 1.0 - exp(-dt * 6.0))
			e[3] = cur
			var up := Vector3.UP if absf(cur.y) < 0.95 else Vector3.BACK
			n.basis = Basis.looking_at(-cur, up).scaled(Vector3(1.0, maxf(0.05, shut), 1.0))

# ---------------------------------------------------------------- the old reptiles

## lava awakening: the bone gone to dark basalt, lava glowing in its cracks and breathing (bone.gdshader lava); every
## few seconds the jaw drops a little and heat and ash pour out of the mouth
static func _lavaborn(root: Node3D, sk: Dictionary, r: Rng32, cr: Geo, bone_m: Material) -> void:
	root.set_meta("dark", true)
	var bb := _box(cr)
	var s := maxf(bb.size.x, maxf(bb.size.y, bb.size.z))
	if bone_m is ShaderMaterial: (bone_m as ShaderMaterial).set_shader_parameter("lava", 1.0)
	var tip := _snout(cr)
	var mouth := Vector3(tip.x, bb.position.y + bb.size.y * 0.25, lerpf(bb.get_center().z, tip.z, 0.6))
	SpecSkullFx._fireflies(root, r, mouth, s * 0.12, 30, 0.02, false, Color(1.0, 0.4, 0.1), s * 0.8)
	var g := _glow_mat(Color(1.0, 0.35, 0.08), 1.2, 2.0)
	_quad(root, s * 0.5, g, mouth)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.42, 0.12)
	l.omni_range = s * 1.6
	l.position = mouth + Vector3(0, s * 0.05, s * 0.1)
	root.add_child(l)
	var jw := JawHeat.new()
	jw.light = l
	jw.glow = g
	if sk.has("jaw_mi"):
		jw.jaw = sk.jaw_mi
		# the hinge: the back of the jaw, at its top
		var jb := ((sk.jaw_mi as MeshInstance3D).mesh as ArrayMesh).get_aabb()
		jw.hinge = Vector3(jb.get_center().x, jb.end.y, jb.position.z + jb.size.z * 0.08)
	root.add_child(jw)
	(sk.marks as Array).append(["fx", bb.get_center() + Vector3(0, bb.size.y * 0.3, bb.size.z * 0.2), Vector3.UP])

class JawHeat extends Node:
	var jaw: MeshInstance3D
	var hinge := Vector3.ZERO
	var light: OmniLight3D
	var glow: ShaderMaterial
	func _process(_dt: float) -> void:
		var t := Time.get_ticks_msec() / 1000.0
		var ph := fmod(t / 6.0, 1.0)
		var open := smoothstep(0.55, 0.7, ph) * (1.0 - smoothstep(0.82, 0.95, ph))
		if is_instance_valid(jaw):
			var bs := Basis(Vector3.RIGHT, open * 0.22)
			jaw.transform = Transform3D(bs, hinge - bs * hinge)
		var k := 0.4 + open * 1.6 + 0.15 * sin(t * 6.0) * sin(t * 2.3)
		light.light_energy = k
		glow.set_shader_parameter("power", 0.3 + open * 1.8)

## the amber drop: the whole skull sealed in a drop of amber (SpecFlower's resin), and in it old insects drifting slowly
## round the head, as if the amber had not set
static func _amberdrop(root: Node3D, sk: Dictionary, r: Rng32, bones: Array) -> void:
	# everything on the skull so far (the bone, its crystals, its horns) goes inside
	var bb := (bones[0] as Geo).aabb()
	for n in root.find_children("*", "MeshInstance3D", true, false):
		if n.has_meta("geo"): bb = bb.merge(U.rel_xform(n as Node3D, root) * (n.get_meta("geo") as Geo).aabb())
	var c := bb.get_center()
	var hs := bb.size * 0.5
	var f := {host = "amber", tone = ["honey", "lemon", "cognac"][int(r.next() * 3.0)], crust = 0.0, window = false, seed = int(r.next() * 10000), cloud = 0.03, spangle = r.next() < 0.5}
	# a drop as resin runs: round and heavy below, drawn up to a blunt point where it hung, its skin gently uneven
	var ext := Vector3(hs.x * 1.42 + 0.06, hs.y * 1.3 + 0.06, hs.z * 1.42 + 0.06)
	var g := Geo.icosa(1.0, 5).to_soup()
	var nz := FastNoiseLite.new()
	nz.seed = int(f.seed)
	nz.frequency = 0.7
	for i in g.v.size():
		var d := g.v[i].normalized()
		var up := smoothstep(0.1, 1.0, d.y)
		var p := Vector3(d.x * (1.0 - 0.42 * up), d.y * (1.0 + 0.5 * up * up) - 0.1, d.z * (1.0 - 0.42 * up))
		p *= 1.0 + nz.get_noise_3dv(d * 1.5) * 0.06
		g.v[i] = c + p * ext
	g.col.resize(g.v.size())
	g.orient_out()
	SpecFlower._smooth(g, -1.0)
	var drop := U.mesh(g, SpecFlower.amber_mat(f, g), root)
	drop.set_meta("col", true)
	# the insects
	var sw := Drifters.new()
	sw.c = c
	sw.ext = ext * 0.85
	root.add_child(sw)
	for k in 3 + int(r.next() * 3.0):
		var holder := Node3D.new()
		sw.add_child(holder)
		var inner := Node3D.new()
		holder.add_child(inner)
		# (the scans held in amber finds: an insect mostly, now and then a leaf or a sprig in flower)
		var kind: String = Stones.pick_w(SpecFlower.INSECTS, r)
		var sd := int(r.next() * 1000)
		if r.next() < 0.25:
			var pl: Array = SpecFlower.SPRIGS.flower + SpecFlower.SPRIGS.fern
			SpecFlower._insect(inner, r, {bug = (pl[mini(int(r.next() * pl.size()), pl.size() - 1)] as Array)[0]})
		else:
			SpecFlower._insect(inner, r, {insect = kind, seed = sd})
		inner.scale = Vector3.ONE * (0.2 + r.next() * 0.08) * maxf(ext.x, ext.y)
		inner.rotation = Vector3(r.next() * TAU, r.next() * TAU, r.next() * TAU)
		sw.items.append({node = holder, inner = inner, ph = r.next() * TAU, sp = (0.06 + r.next() * 0.06) * (1.0 if r.next() < 0.5 else -1.0),
			e = Vector3(0.75 + r.next() * 0.2, (r.next() - 0.5) * 0.9, 0.75 + r.next() * 0.2), spin = Vector3(r.next() - 0.5, r.next() - 0.5, r.next() - 0.5) * 0.25})
	(sk.marks as Array).append(["fx", c + Vector3(ext.x * 0.6, ext.y * 0.5, ext.z * 0.7), Vector3(0.5, 0.5, 0.7).normalized()])

class Drifters extends Node3D:
	var c := Vector3.ZERO
	var ext := Vector3.ONE
	var items := []
	var t := 0.0
	func _process(dt: float) -> void:
		t += dt
		for it: Dictionary in items:
			var a := float(it.ph) + t * float(it.sp)
			var e: Vector3 = it.e
			(it.node as Node3D).position = c + Vector3(cos(a) * ext.x * e.x, e.y * ext.y + sin(t * 0.13 + float(it.ph)) * ext.y * 0.1, sin(a) * ext.z * e.z)
			(it.inner as Node3D).rotation += (it.spin as Vector3) * dt

# ---------------------------------------------------------------- every beast

## the beast's ghost: every ten seconds the living head forms over the skull out of cold light — from the neck to the
## nose — its eyes kindling in the sockets, holds a breath, and dissolves away into sparks (a low-poly head cut by
## prototype/tools/skull/ghost_prep.py, fitted nose to nose, a little bigger than the bone)
static func _ghost(root: Node3D, sk: Dictionary, r: Rng32, bones: Array, surf: SpecSurf) -> void:
	var path := GHOST_DIR + String(sk.beast) + ".json"
	if not ResourceLoader.exists(path): return
	root.set_meta("dark", true)
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var fv: Array = d.v
	var ff: Array = d.f
	var fu: Array = d.get("u", [])
	var g := Geo.new()
	g.v.resize(fv.size() / 3)
	for i in g.v.size(): g.v[i] = Vector3(float(fv[i * 3]), float(fv[i * 3 + 1]), float(fv[i * 3 + 2]))
	for x in ff: g.idx.append(int(x))
	var uv := PackedVector2Array()
	for i in g.v.size(): uv.append(Vector2(float(fu[i]) if i < fu.size() else 1.0, 0.0))
	# the skull's own axis, back of the head to the nose: forward, or down for one hung face-on on a wall
	var lm: Dictionary = SpecSkull.body(String(sk.beast)).get("lm", {})
	var axis := Vector3.BACK
	var bb: AABB = (bones[0] as Geo).aabb()
	for b: Geo in bones: bb = bb.merge(b.aabb())
	if lm.get("mount", false) and lm.has("eye_front"):
		# (hung face-on: its nose is the point of its midline furthest below the eyes)
		var e := SpecSkull.lm_v(lm, "eye_front")
		e.x = 0.0
		var far := 0.0
		for p in (bones[0] as Geo).v:
			if absf(p.x) < bb.size.x * 0.08 and p.y < e.y and p.distance_to(e) > far:
				far = p.distance_to(e)
				axis = (p - e).normalized()
	var lo := INF
	var hi := -INF
	for b: Geo in bones:
		for p in b.v:
			lo = minf(lo, p.dot(axis))
			hi = maxf(hi, p.dot(axis))
	var tip := Vector3.ZERO
	var tn := 0
	for b: Geo in bones:
		for p in b.v:
			if p.dot(axis) > hi - (hi - lo) * 0.05:
				tip += p
				tn += 1
	tip /= maxf(1.0, tn)
	# the ghost's nose and length (its axis is +Z), fitted nose to nose, a little bigger than the bone
	var hb := g.aabb()
	var gt := Vector3.ZERO
	var gn := 0
	for p in g.v:
		if p.z > hb.end.z - hb.size.z * 0.05:
			gt += p
			gn += 1
	gt /= maxf(1.0, gn)
	var k := (hi - lo) * 1.1 / maxf(0.001, hb.size.z)
	var R := Basis(SpecUtil.quat_to(Vector3.BACK, axis))
	for i in g.v.size():
		g.v[i] = tip + axis * (hi - lo) * 0.04 + R * ((g.v[i] - gt) * k)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = g.v
	arr[Mesh.ARRAY_NORMAL] = g.normals()
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_INDEX] = g.idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := ShaderMaterial.new()
	m.shader = GHOST
	var cols := [Color(0.4, 0.9, 1.0), Color(0.45, 1.0, 0.6), Color(1.0, 0.78, 0.35), Color(0.7, 0.5, 1.0)]
	var col: Color = cols[int(r.next() * cols.size())]
	m.set_shader_parameter("col", Vector3(col.r, col.g, col.b))
	m.set_shader_parameter("seed", r.next() * 50.0)
	m.render_priority = 5
	mi.material_override = m
	# (not part of the find's box: the studio frames the skull, the ghost may reach past it)
	root.add_child(mi)
	var gh := Ghost.new()
	gh.mat = m
	gh.t = 0.0   # (it forms as the card opens)
	for sx: float in [-1.0, 1.0]:
		var e := SpecSkullFx.eye(surf, sx, sk)
		if e.is_empty(): continue
		var em := _glow_mat(col.lerp(Color.WHITE, 0.3), 0.0, r.next() * 9.0)
		_quad(root, float(e.r) * 3.0, em, (e.deep as Vector3).lerp(e.front, 0.7))
		gh.eyes.append(em)
	var l := OmniLight3D.new()
	l.light_color = col
	l.omni_range = bb.size.length() * 1.5
	l.position = bb.get_center() + Vector3(0, bb.size.y * 0.3, bb.size.z * 0.3)
	root.add_child(l)
	gh.light = l
	root.add_child(gh)
	SpecSkullFx._fireflies(root, r, bb.get_center() + Vector3(0, bb.size.y * 0.2, 0), bb.size.length() * 0.3, 18, 0.03, false, col, bb.size.y * 1.2)
	(sk.marks as Array).append(["fx", bb.get_center() + Vector3(0, bb.size.y * 0.45, bb.size.z * 0.2), Vector3.BACK])

class Ghost extends Node:
	var mat: ShaderMaterial
	var light: OmniLight3D
	var eyes := []
	var t := 0.0
	func _process(dt: float) -> void:
		t += dt
		var ph := fmod(t, 10.0)
		# forms (0–1.8 s), holds, breathing (to 5.5), dissolves (5.5–7.3), gone (to 10)
		var s := smoothstep(0.0, 1.8, ph) * (1.0 - smoothstep(5.5, 7.3, ph))
		var breath := 1.0 + 0.08 * sin(t * 2.2) * s
		mat.set_shader_parameter("show", s * breath)
		light.light_energy = s * 1.4
		for em: ShaderMaterial in eyes: em.set_shader_parameter("power", smoothstep(1.2, 2.2, ph) * (1.0 - smoothstep(5.0, 6.0, ph)) * 2.4)
