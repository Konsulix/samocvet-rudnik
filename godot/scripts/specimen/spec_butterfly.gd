class_name SpecButterfly
extends RefCounted
## Butterflies and moths on a find (Koschei's skulls, docs/skulls.md). The wings are museum specimens photographed
## from above (Wikimedia Commons, CC BY-SA — assets/specimen/butterflies/CREDITS.md), cut out by
## prototype/tools/skull/cut_butterfly.py; the body, antennae and the way each one moves are ours.
## A butterfly either rests on the find (opening and closing its wings) or flies round it — each kind in its own way.

const SHADER := preload("res://shaders/butterfly.gdshader")
const DIR := "res://assets/specimen/butterflies/"

## id: [wing file, span (x), body colour, band colour (0 none), body thickness, abdomen length, how it flies,
##      iridescent, see-through, weight, can perch]
## how it flies:
##   float — big slow beats and long glides on wide loops (morpho, apollo)
##   glide — a few strong beats, then a sail (monarch, mourning cloak)
##   flit  — quick, small and jerky, close round the find, hopping (the blues)
##   hover — wings a blur, darts and hangs in the air (the hawkmoth)
##   drift — slow heavy beats, the long tails trailing, gentle wide loops (the comet moth)
##   weave — fluttering, wandering this way and that (the glasswing)
const KINDS := {
	morpho = ["morpho", 1.25, Color(0.06, 0.05, 0.05), Color(0, 0, 0, 0), 1.0, 1.0, "float", 1.0, 0.0, 3.0],
	apollo = ["apollo", 1.0, Color(0.15, 0.14, 0.13), Color(0, 0, 0, 0), 1.2, 0.9, "float", 0.0, 0.0, 2.5],
	monarch = ["monarch", 1.05, Color(0.04, 0.03, 0.03), Color(0.9, 0.9, 0.85, 0.3), 1.0, 1.0, "glide", 0.0, 0.0, 2.5],
	deathshead = ["deathshead", 1.1, Color(0.1, 0.08, 0.06), Color(0.85, 0.65, 0.12, 1.0), 2.2, 1.2, "hover", 0.0, 0.0, 1.5],
	glasswing = ["glasswing", 0.8, Color(0.12, 0.08, 0.06), Color(0, 0, 0, 0), 0.8, 0.95, "weave", 0.0, 1.0, 1.5],
	comet = ["comet", 1.5, Color(0.75, 0.42, 0.12), Color(0.55, 0.25, 0.08, 0.4), 1.6, 1.0, "drift", 0.0, 0.0, 1.2],
	mourning = ["mourning", 1.0, Color(0.06, 0.04, 0.04), Color(0, 0, 0, 0), 1.1, 0.95, "glide", 0.0, 0.0, 2.0],
	blue = ["blue", 0.55, Color(0.18, 0.18, 0.2), Color(0, 0, 0, 0), 0.8, 0.85, "flit", 0.0, 0.0, 2.5],
}

static var _cards := {}
static var _tex := {}

static func pick(rng: Rng32) -> String:
	return Stones.pick_w(KINDS.keys().map(func(k: String) -> Array: return [k, float(KINDS[k][9])]), rng)

## the wing cards of a kind: both sides, a grid so the wing can bend; the body axis is x (head +), the wing joins at x 0
static func _card(id: String) -> Array:
	if _cards.has(id):
		return _cards[id]
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + String(KINDS[id][0]) + ".json"))
	var asp := float(meta.aspect)
	var root := float(meta.root)
	var nu := 10
	var nv := 12
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var nm := PackedVector3Array()
	var idx := PackedInt32Array()
	for side: float in [1.0, -1.0]:
		var b := v.size()
		for j in nv + 1:
			for i in nu + 1:
				var u := float(i) / nu
				var w := float(j) / nv
				v.append(Vector3((root - w) * 1.0, 0.0, u * asp * side))
				uv.append(Vector2(u, w))
				nm.append(Vector3.UP)
		for j in nv:
			for i in nu:
				var a := b + j * (nu + 1) + i
				var c := a + nu + 1
				if side > 0: idx.append_array([a, c, a + 1, a + 1, c, c + 1])
				else: idx.append_array([a, a + 1, c, a + 1, c + 1, c])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = nm
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	# (the card's length along the body is 1; its reach out is the aspect)
	_cards[id] = [m, asp, root]
	return _cards[id]

## a butterfly on a find: starting perched at `at` on normal `n`, or flying round it; perches: [point, normal] where it
## may land (in the parent's space); span: its wingspan in find units before the kind's own size
static func put(parent: Node3D, rng: Rng32, id: String, at: Vector3, n: Vector3, span: float, flying: bool, perches := []) -> Node3D:
	var k: Array = KINDS[id]
	var card: Array = _card(id)
	var asp: float = card[1]
	var b := Fly.new()
	parent.add_child(b)
	# the card is 1 long, 2·aspect across: scale it to the span
	var s := span * float(k[1]) / (2.0 * asp)
	var m := ShaderMaterial.new()
	m.shader = SHADER
	if not _tex.has(id): _tex[id] = load(DIR + String(k[0]) + ".png")
	m.set_shader_parameter("wing", _tex[id])
	m.set_shader_parameter("iri", float(k[7]))
	m.set_shader_parameter("glass", float(k[8]))
	m.set_shader_parameter("seed", rng.next() * 50.0)
	m.set_shader_parameter("curve", 0.15 + rng.next() * 0.2)
	var wings := Node3D.new()
	wings.scale = Vector3.ONE * s
	b.add_child(wings)
	var w := MeshInstance3D.new()
	w.mesh = card[0]
	w.material_override = m
	w.position = Vector3(0, 0.035, 0)
	wings.add_child(w)
	# (the body goes by the span, not by the card: a comet's card is long with its tails)
	var body := Node3D.new()
	body.scale = Vector3.ONE * span * float(k[1]) * 0.5 / (1.5 if String(k[0]) == "comet" else 1.0)
	b.add_child(body)
	_body(body, k)
	b.setup(rng, m, String(k[6]), flying, at, n, perches if perches.size() else [[at, n]], s)
	return b

## thorax, a tapering abdomen (banded on some), the head, two clubbed antennae (feathery on the moths: straight here)
static func _body(hold: Node3D, k: Array) -> void:
	var col: Color = k[2]
	var band: Color = k[3]
	var th := 0.045 * float(k[4])
	var ln := 0.55 * float(k[5])
	var bm := StandardMaterial3D.new()
	bm.albedo_color = col
	bm.roughness = 0.95
	var thorax := SphereMesh.new()
	thorax.radius = th * 1.1
	thorax.height = th * 2.6
	var t := MeshInstance3D.new()
	t.mesh = thorax
	t.material_override = bm
	t.rotation.z = PI * 0.5
	t.position = Vector3(0.0, 0.03, 0)
	hold.add_child(t)
	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = th * 0.75
	hm.height = th * 1.5
	head.mesh = hm
	head.material_override = bm
	head.position = Vector3(th * 1.5, 0.03, 0)
	hold.add_child(head)
	# the abdomen: segments narrowing to the tip, the band colour on alternate ones
	var segs := 6
	for i in segs:
		var f := float(i) / segs
		var seg := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = th * (0.95 - f * 0.55)
		sm.height = ln / segs * 1.9
		seg.mesh = sm
		var mm := bm
		if band.a > 0.0 and i % 2 == 1:
			mm = StandardMaterial3D.new()
			mm.albedo_color = col.lerp(Color(band.r, band.g, band.b), band.a)
			mm.roughness = 0.95
		seg.material_override = mm
		seg.rotation.z = PI * 0.5
		seg.position = Vector3(-th * 1.0 - (f + 0.5 / segs) * ln, 0.03 - f * 0.01, 0)
		hold.add_child(seg)
	# the antennae: from the top of the head, forward and apart, a gentle curve, a club at the tip
	var am := StandardMaterial3D.new()
	am.albedo_color = col.darkened(0.3)
	am.roughness = 0.9
	var hp := Vector3(th * 1.5, 0.03 + th * 0.4, 0.0)
	for sd: float in [1.0, -1.0]:
		var pts: Array[Vector3] = []
		for j in 6:
			var f := float(j) / 5.0
			pts.append(hp + Vector3(f * 0.2, f * 0.07 + f * f * 0.03, sd * (0.012 + f * 0.08)))
		var g := Geo.tube(pts, 8, 0.004, 4)
		var ant := MeshInstance3D.new()
		ant.mesh = g.to_mesh()
		ant.material_override = am
		hold.add_child(ant)
		var club := MeshInstance3D.new()
		var clm := SphereMesh.new()
		clm.radius = 0.011
		clm.height = 0.03
		club.mesh = clm
		club.material_override = am
		club.position = pts[pts.size() - 1]
		hold.add_child(club)

## how each way of flying moves: wingbeats a second, the stroke (top and bottom root angle), cruising speed (in spans
## a second), how often it sails with the wings held out, how jerky its path, how long it flies and sits (s),
## how often it opens its wings to the sun when it sits, and its resting wings (closed up, or a moth's flat roof)
const STYLE := {
	float = {hz = 3.2, up = 1.5, dn = -0.55, speed = 1.3, glide = 0.45, jerk = 0.2, fly = [5.0, 9.0], sit = [3.0, 7.0], sun = 0.7, rest = 1.5},
	glide = {hz = 4.5, up = 1.5, dn = -0.5, speed = 1.6, glide = 0.35, jerk = 0.25, fly = [4.0, 8.0], sit = [2.5, 6.0], sun = 0.5, rest = 1.5},
	flit = {hz = 9.0, up = 1.45, dn = -0.4, speed = 1.8, glide = 0.0, jerk = 1.0, fly = [2.0, 4.5], sit = [1.5, 3.5], sun = 0.6, rest = 1.5},
	hover = {hz = 26.0, up = 0.9, dn = -0.35, speed = 2.6, glide = 0.0, jerk = 0.5, fly = [6.0, 11.0], sit = [4.0, 8.0], sun = 0.0, rest = -0.08},
	drift = {hz = 2.0, up = 1.35, dn = -0.5, speed = 0.9, glide = 0.15, jerk = 0.1, fly = [6.0, 10.0], sit = [4.0, 8.0], sun = 0.0, rest = 0.2},
	weave = {hz = 6.0, up = 1.45, dn = -0.45, speed = 1.2, glide = 0.05, jerk = 0.7, fly = [3.0, 6.0], sit = [2.0, 4.5], sun = 0.3, rest = 1.5},
}

## the butterfly's life, all in the find's own space: it flies round the find (wingbeats, sails, bobbing on each
## stroke, banking into turns), picks a spot on the find, comes in, lands and folds its wings, sits (now and then opening
## them to the sun, or a slow clap), and takes off again. The wings' angles go to the shader (ang, flex).
class Fly extends Node3D:
	enum { FLY, LAND, SIT, OFF }
	var mat: ShaderMaterial
	var st: Dictionary
	var rng: Rng32
	var size := 0.2
	var state := FLY
	var timer := 0.0
	var phase := 0.0        # wingbeat phase
	var gliding := 0.0      # 0 flapping .. 1 sailing
	var glide_t := 0.0
	var pos := Vector3.ZERO
	var vel := Vector3.ZERO
	var target := Vector3.ZERO
	var retarget := 0.0
	var bank := 0.0
	var heading := Vector3.FORWARD
	var perch := []         # [point, normal] on the find where it may land
	var spot: Array = []    # the one it is landing on / sitting on
	var land_from := Vector3.ZERO
	var sun := 0.0          # sitting: 0 wings closed .. 1 opened to the sun
	var sun_to := 0.0
	var sun_t := 0.0
	var start_at := Vector3.ZERO
	var start_n := Vector3.UP
	var start_fly := true
	# the find: its box (the studio frames it) and its pieces to keep out of (ellipsoids)
	var top_n: Node3D
	var box := AABB()
	var obst := []
	var stand: Array[AABB] = []
	var looked := false

	func setup(r: Rng32, m: ShaderMaterial, how: String, fly: bool, at: Vector3, n: Vector3, perches: Array, s: float) -> void:
		rng = r
		mat = m
		st = SpecButterfly.STYLE[how]
		size = s
		start_fly = fly
		start_at = at
		start_n = n
		perch = perches
		phase = rng.next() * TAU
		# a first pose before the find is looked round (in the parent's space: where it was put)
		transform = Transform3D(Basis(SpecUtil.quat_to(Vector3.UP, n)), at)
		_wings(1.5, 0.0)

	func _rnd(a: Array) -> float:
		return lerpf(float(a[0]), float(a[1]), rng.next())

	## the find, once it is built: its box and its pieces (the skull, the crystals, the rock), in the find's space
	func _look_round() -> void:
		looked = true
		top_n = self
		var p := get_parent()
		while p is Node3D:
			top_n = p
			if p.has_meta("grown"): break
			p = p.get_parent()
		var first := true
		var stack: Array[Node] = [top_n]
		while stack.size():
			var n: Node = stack.pop_back()
			if n is Fly: continue
			stack.append_array(n.get_children())
			if not (n is MeshInstance3D) or not n.has_meta("geo"): continue
			var g: Geo = n.get_meta("geo")
			var bb: AABB = SpecUtil.rel_xform(n as Node3D, top_n) * g.aabb()
			if bb.size.length() < 0.04: continue
			box = bb if first else box.merge(bb)
			first = false
			obst.append([bb.get_center(), bb.size * 0.5 + Vector3.ONE * size * 0.3])
			# the things standing up off the bone (crystals, trees, moss, mushrooms): a wing must not open into them
			if n.has_meta("col") or n.has_meta("local") or (n.get_parent() != top_n and not n.get_parent() is Fly):
				stand.append(bb.grow(size * 0.45))
		# the perches and the start, into the find's space
		var pt := SpecUtil.rel_xform(get_parent() as Node3D, top_n) if get_parent() != top_n else Transform3D.IDENTITY
		perch = perch.map(func(q: Array) -> Array: return [pt * (q[0] as Vector3), (pt.basis * (q[1] as Vector3)).normalized()])
		# only where the wings have room: no crystal or tree within a span, and fairly level
		var free := perch.filter(func(q: Array) -> bool:
			if (q[1] as Vector3).y < 0.55: return false
			for bb: AABB in stand:
				if bb.has_point(q[0]): return false
			return true)
		if free.size(): perch = free
		if start_fly:
			pos = _shell()
			vel = Vector3(rng.next() - 0.5, 0.1, rng.next() - 0.5).normalized() * size * float(st.speed)
			target = _shell()
			state = FLY
			timer = _rnd(st.fly) * 0.45   # (the first landing soon: a card is not looked at for long)
		else:
			# a spot of its own (they all started on the first spot of the list, one on top of the other)
			var pick := _free_spot() if perch.size() else []
			if pick.is_empty():
				# nowhere to sit: it flies instead
				start_fly = true
				pos = _shell()
				target = _shell()
				state = FLY
				timer = _rnd(st.fly)
				return
			spot = pick
			_claim(spot[0], true)
			pos = (spot[0] as Vector3) + (spot[1] as Vector3) * size * 0.08
			heading = (Vector3(rng.next() - 0.5, 0, rng.next() - 0.5)).normalized()
			state = SIT
			timer = _rnd(st.sit) * (0.3 + rng.next() * 0.7)

	## a point to fly towards: on a shell round the find, inside the frame
	func _shell() -> Vector3:
		if box.size == Vector3.ZERO: return Vector3(0, 0.5, 0)
		var c := box.get_center()
		var h := box.size * 0.5
		var a := rng.next() * TAU
		return Vector3(c.x + cos(a) * (h.x * 0.92 + size * 0.15), box.position.y + box.size.y * (0.4 + rng.next() * 0.45),
			c.z + sin(a) * (h.z + size * 0.5))

	func _process(dt: float) -> void:
		if not looked:
			_look_round()
		dt = minf(dt, 0.05)
		timer -= dt
		match state:
			FLY: _fly(dt)
			LAND: _land(dt)
			SIT: _sit(dt)
			_: _off(dt)
		_place()

	## a wingbeat: the stroke between the top (wings almost meeting over the back) and the bottom (below the body),
	## the tip lagging the root; returns the lift of this moment (the body rises on the downstroke)
	func _flap(dt: float, hz: float, k := 1.0) -> float:
		phase += dt * hz * TAU
		var up := float(st.up)
		var dn := float(st.dn)
		var mid := (up + dn) * 0.5
		var amp := (up - dn) * 0.5 * k
		# the downstroke a little faster than the upstroke
		var c := cos(phase + 0.25 * sin(phase))
		var a := mid + amp * c
		# the tip trails the stroke: bent up going down, bent down going up
		_wings(a, sin(phase) * 0.55 * k)
		return maxf(0.0, sin(phase)) * k

	func _wings(a: float, f: float) -> void:
		mat.set_shader_parameter("ang", a)
		mat.set_shader_parameter("flex", f)

	func _fly(dt: float) -> void:
		var hz: float = float(st.hz)
		# now and then it sails, wings held out a little above flat
		glide_t -= dt
		if glide_t <= 0.0:
			var sail := rng.next() < float(st.glide)
			glide_t = (0.5 + rng.next() * 0.9) if sail else (0.6 + rng.next() * 1.2)
			gliding = 1.0 if sail else 0.0
		var g := 0.0
		if gliding > 0.5:
			_wings(0.12 + 0.05 * sin(phase), 0.0)
			phase += dt * 2.0
		else:
			g = _flap(dt, hz)
		# steer for the target; a jerky one changes its mind often
		retarget -= dt
		if pos.distance_to(target) < size * 1.5 or retarget <= 0.0:
			target = _shell()
			retarget = (0.3 + rng.next() * 0.5) / maxf(0.2, float(st.jerk)) if float(st.jerk) > 0.6 else 1.5 + rng.next() * 2.0
		var speed := size * float(st.speed) * (0.85 if gliding > 0.5 else 1.0)
		var want := (target - pos).normalized() * speed
		var turn := 2.0 + float(st.jerk) * 6.0
		var old := vel
		vel = vel.lerp(want, minf(1.0, dt * turn))
		# each downstroke lifts it, a sail sinks it
		vel.y += (g * 1.6 - 0.55) * size * dt * (1.0 if gliding < 0.5 else 0.4)
		pos += vel * dt
		_keep_out()
		# and out of each other's way
		for n: Node in get_parent().get_children():
			if n != self and n is Fly:
				var o := (n as Fly).pos
				var dd := pos.distance_to(o)
				if dd < size * 1.2 and dd > 1e-4: pos += (pos - o).normalized() * (size * 1.2 - dd) * 0.5
		var lat := (vel - old).cross(Vector3.UP).y if dt > 0.0 else 0.0
		bank = lerpf(bank, clampf(-lat * 20.0 / maxf(size, 0.01), -0.7, 0.7), minf(1.0, dt * 4.0))
		if vel.length() > 1e-4:
			heading = Vector3(vel.x, vel.y * 0.6, vel.z).normalized()
		# time to land: pick a spot on the find
		if timer <= 0.0 and perch.size():
			var pick := _free_spot()
			if pick.is_empty():
				timer = 1.0 + rng.next()
				return
			spot = pick
			_claim(spot[0], true)
			state = LAND
			land_from = pos
			timer = 0.0
			retarget = 0.0

	## the flies on this find share their landing spots: a spot one has taken (or is coming in to) is no one else's
	func _taken() -> Array:
		if not top_n.has_meta("fly_taken"): top_n.set_meta("fly_taken", [])
		return top_n.get_meta("fly_taken")

	func _claim(p: Vector3, on: bool) -> void:
		var t := _taken()
		if on: t.append(p)
		else: t.erase(p)

	## a landing spot with room: none taken by another fly within a span, its hovering point clear of crystals and trees
	func _free_spot() -> Array:
		var t := _taken()
		for k in 8:
			var q: Array = perch[int(rng.next() * perch.size())]
			var p: Vector3 = q[0]
			var ok := true
			for o: Vector3 in t:
				if o.distance_to(p) < size * 1.3: ok = false
			var hover := p + (q[1] as Vector3) * size * 0.8
			for bb: AABB in stand:
				if bb.has_point(hover): ok = false
			if ok: return q
		return []

	## coming in: flies at the spot from above it, slowing, wings fluttering, then folds them as the feet touch
	func _land(dt: float) -> void:
		var p: Vector3 = spot[0]
		var n: Vector3 = spot[1]
		var hover := p + n * size * 0.8
		var d := pos.distance_to(hover)
		retarget -= dt
		if d > size * 0.25 and retarget > -4.0:
			var speed := size * float(st.speed) * clampf(d / size, 0.4, 1.0)
			vel = vel.lerp((hover - pos).normalized() * speed, minf(1.0, dt * 4.0))
			pos += vel * dt
			_keep_out(p)
			heading = Vector3(vel.x, 0.0, vel.z).normalized() if Vector2(vel.x, vel.z).length() > 1e-4 else heading
			_flap(dt, float(st.hz) * 1.15)
			bank = lerpf(bank, 0.0, minf(1.0, dt * 4.0))
		else:
			# settle down onto the spot over half a second, a few short beats
			timer += dt
			var f := clampf(timer / 0.5, 0.0, 1.0)
			if timer <= dt: land_from = pos
			pos = land_from.lerp(p + n * size * 0.08, f * f)
			_flap(dt, float(st.hz) * 0.8, 1.0 - f * 0.7)
			if f >= 1.0:
				state = SIT
				timer = _rnd(st.sit)
				sun = 0.0
				sun_t = 0.5 + rng.next()

	## sitting: wings closed over the back (a moth's flat roof), opened to the sun for a while, a slow clap now and then
	func _sit(dt: float) -> void:
		var rest := float(st.rest)
		sun_t -= dt
		if sun_t <= 0.0:
			sun_to = 1.0 if rng.next() < float(st.sun) and sun_to < 0.5 else 0.0
			sun_t = 1.2 + rng.next() * 2.5
		sun = move_toward(sun, sun_to, dt * 1.6)
		# opened to the sun only to a V, never flat: flat wings dipped into the curve of the bone
		var open := lerpf(rest, 0.5, smoothstep(0.0, 1.0, sun))
		# a slow clap while open, a shiver while closed
		var clap := sin(timer * 2.2) * 0.12 * sun + sin(timer * 17.0) * 0.015
		_wings(open + clap, 0.0)
		bank = 0.0
		if timer <= 0.0:
			state = OFF
			timer = 0.6
			vel = (spot[1] as Vector3) * size * float(st.speed) * 0.8
			_claim(spot[0], false)

	## taking off: a few strong beats straight up off the spot, then away
	func _off(dt: float) -> void:
		var g := _flap(dt, float(st.hz) * 1.2, 1.1)
		vel = vel.lerp(((spot[1] as Vector3) + Vector3.UP).normalized() * size * float(st.speed) * 1.2, minf(1.0, dt * 3.0))
		vel.y += g * size * dt
		pos += vel * dt
		if timer <= 0.0:
			state = FLY
			timer = _rnd(st.fly)
			target = _shell()
			gliding = 0.0
			glide_t = 0.6

	## keep out of every piece of the find (but for the one being landed on, near its spot)
	func _keep_out(near := Vector3.INF) -> void:
		for o: Array in obst:
			var oc: Vector3 = o[0]
			var oh: Vector3 = o[1]
			var q := (pos - oc) / oh
			var l := q.length()
			if l < 1.0:
				# (coming in to land: the piece it lands on — any piece whose shell holds the spot — lets it through)
				if near != Vector3.INF and (((near - oc) / oh).length() < 1.0 or pos.distance_to(near) < size * 1.2): continue
				if l < 1e-4: q = Vector3.UP
				var out := oc + q.normalized() * oh
				var nrm := (out - oc).normalized()
				pos = out
				vel -= nrm * minf(0.0, vel.dot(nrm))

	func _place() -> void:
		if not looked: return
		var up := Vector3.UP
		var fwd := heading
		if state == SIT or (state == LAND and timer > 0.0):
			up = spot[1]
			fwd = (heading - up * heading.dot(up)).normalized()
			if fwd.length() < 1e-3: fwd = up.cross(Vector3.RIGHT).normalized()
		var side := fwd.cross(up).normalized()
		up = side.cross(fwd).normalized()
		var bas := Basis(side, up, -fwd).orthonormalized()
		# the card's head is +x: turn it to face along fwd; bank into the turn
		bas = bas * Basis(Vector3.UP, PI * 0.5) * Basis(Vector3.RIGHT, bank)
		var into := SpecUtil.rel_xform(get_parent() as Node3D, top_n).affine_inverse() if get_parent() != top_n else Transform3D.IDENTITY
		transform = into * Transform3D(bas, pos)
