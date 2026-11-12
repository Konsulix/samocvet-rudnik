class_name SpecButterfly
extends RefCounted
## Butterflies and moths on a find (any find: SpecButterfly.for_find; Koschei's skulls decide their own, docs/skulls.md).
## Each kind is a whole animated model (wings on bones, a furred body, legs, antennae — assets/specimen/CREDITS.md);
## the way it flies is ours (Fly, below): it flies round the find by forces, beat by beat, lands on it, sits, takes off.

const DIR := "res://assets/specimen/butterflies/"

## id: its size (wingspan, against the span the find gives), how it flies (STYLE), how common
const KINDS := {
	monarch = {span = 1.05, style = "glide", w = 2.5},
	apollo = {span = 1.0, style = "float", w = 2.5},
	peacock = {span = 0.85, style = "glide", w = 2.5},
	swallowtail = {span = 1.1, style = "float", w = 2.5},
	bluetiger = {span = 1.0, style = "glide", w = 2.0},
	birdwing = {span = 1.35, style = "float", w = 1.5},
	glasswing = {span = 0.95, style = "weave", w = 1.5},
	hawkmoth = {span = 1.0, style = "hover", w = 1.5},
}

## their names on the card (a callout, one per kind: "Apollo ×2")
const NAME := {monarch = "monarch", apollo = "Apollo", peacock = "peacock butterfly", swallowtail = "swallowtail",
	bluetiger = "blue tiger", birdwing = "birdwing", glasswing = "clearwing swallowtail", hawkmoth = "elephant hawk-moth"}
## which of them live by each mine (its area): Old Adit's meadows (peacock, swallowtail), the Alpine Apollo of the copper
## mountain, the hawk-moth of the Sicilian sulphur and of the coal seam, the far-eastern valley's blue tiger and
## birdwing; the barrow's skulls have all of them (SpecSkull). The sea cove and the polar pit: none.
const AREA_KINDS := {0: ["peacock", "swallowtail"], 1: ["apollo"], 3: ["hawkmoth"], 5: ["bluetiger", "birdwing"],
	6: ["monarch", "apollo", "peacock", "swallowtail", "bluetiger", "birdwing", "glasswing", "hawkmoth"], 7: ["hawkmoth"]}
## how often a find (not a skull: those decide their own) has butterflies on it
const FIND_P := 0.06

## the models: file; its wingspan in its own units; the turn that brings its head to +x (as Fly wants it); how far its
## flight clip holds the body nose-up already (ours is added to it); its clips — fly (a wingbeat: Fly shows it stroke
## by stroke), sit (if it has one: else it sits in the top of its stroke, wings over its back), and for a model with
## everything (the monarch) land, off and the sail in its flight; tip/base — the bones its wing's rise is read from
## (else the wing bone "LeftUpperWing", whose own axis lies along the wing)
const MODELS := {
	monarch = {file = "monarch.glb", span = 2.6, yaw = 0.0, pitch = 0.0, clips = {fly = "Danaus_plexippus_Flight",
		land = "Danaus_plexippus_Landing_InPlace", sit = "Danaus_plexippus_Perched_Idle", off = "Danaus_plexippus_Takeoff_InPlace"}},
	apollo = {file = "apollo.glb", scales = true, span = 2.995, yaw = -PI / 2, pitch = 0.35, clips = {fly = "fly"}},
	peacock = {file = "peacock.glb", scales = true, span = 2.389, yaw = -PI / 2, pitch = 0.35, clips = {fly = "fly"}},
	swallowtail = {file = "swallowtail.glb", scales = true, span = 2.369, yaw = -PI / 2, pitch = 0.35, clips = {fly = "fly"}},
	birdwing = {file = "birdwing.glb", scales = true, span = 2.457, yaw = -PI / 2, pitch = 0.35, clips = {fly = "fly"}},
	glasswing = {file = "glasswing.glb", scales = true, span = 2.266, yaw = -PI / 2, pitch = 0.35, clips = {fly = "fly"}},
	hawkmoth = {file = "hawkmoth.glb", scales = true, span = 2.691, yaw = -PI / 2, pitch = 0.25, clips = {fly = "fly", sit = "idle"}},
	bluetiger = {file = "bluetiger.glb", span = 0.12, yaw = PI / 2, pitch = 0.15, clips = {fly = "hover", sit = "idle"},
		tip = "r_frnt_wings08", base = "chest_jnt"},
	# not a butterfly: the fireflies of a skull's swarm (SpecSkullFx._swarm). Its one clip is its flight, the wings a
	# blur: looped as it is (loop: at this speed); it stands 1.6 above its own origin; a flat helper plane hidden
	firefly = {file = "res://assets/specimen/firefly/firefly.glb", span = 2.2, yaw = PI / 2, pitch = 0.1, clips = {fly = "Take 01"},
		loop = 1.0, centre = Vector3(0.04, 1.64, 0.02), hide = ["1catalogue_Mesh"]},
}

static func label(kind: String, n: int) -> String:
	return String(NAME.get(kind, kind)) + (" ×%d" % n if n > 1 else "")

static func style(kind: String) -> String:
	return String((KINDS.get(kind, {}) as Dictionary).get("style", "glide"))

static var _area := {}
static var fly_big := 1.0   # a test key (-- fly_big=1.8): every butterfly this much larger (a trailer's close cards)
## the mine a species is found in (each species belongs to one mine's pool); -1 none
static func area_of(sid: String) -> int:
	if _area.is_empty():
		for i in Data.AREAS.size():
			for s: String in (Data.AREAS[i] as Dictionary).get("pool", {}): _area[s] = i
	return int(_area.get(sid, -1))

## the butterflies on a find (its species' mine decides which), on their own random stream so no other gene moves;
## pinned from outside: flies=N (0 none), fly_kind=<kind>
static func for_find(seed_v: int, sid: String, o: Dictionary) -> Array:
	var ks: Array = AREA_KINDS.get(area_of(sid), [])
	if o.has("fly_kind") and KINDS.has(String(o.fly_kind)): ks = [String(o.fly_kind)]
	if ks.is_empty(): return []
	var r := Rng32.new((seed_v * 2654435761 + 433) % 4294967296)
	var n := 0 if r.next() >= FIND_P else 1 + int(pow(r.next(), 1.6) * 3.0)
	if o.has("flies"): n = int(o.flies)
	var out: Array = []
	var one := String(_pick_of(r, ks)) if r.next() < 0.7 else ""
	for k in n: out.append(one if one != "" else _pick_of(r, ks))
	return out

static func _pick_of(r: Rng32, ks: Array) -> String:
	return Stones.pick_w(ks.map(func(k: String) -> Array: return [k, float(KINDS[k].w)]), r)

static func pick(rng: Rng32) -> String:
	return Stones.pick_w(KINDS.keys().map(func(k: String) -> Array: return [k, float(KINDS[k].w)]), rng)

## a butterfly on a find: starting perched at `at` on normal `n`, or flying round it; perches: [point, normal] where it
## may land (in the parent's space); span: its wingspan in find units before the kind's own size
static func put(parent: Node3D, rng: Rng32, id: String, at: Vector3, n: Vector3, span: float, flying: bool, perches := []) -> Node3D:
	if not KINDS.has(id): id = "monarch"   # (a kind there is no more, in an old find)
	var k: Dictionary = KINDS[id]
	return put_model(parent, rng, id, String(k.style), span * float(k.span) * fly_big, flying, at, n, perches)

## any of the MODELS flying round a find the same way (a butterfly; a firefly of the swarm — SpecSkullFx): span — its
## wingspan in find units; lands false — it never comes down (its points to hover over are the perches all the same)
static func put_model(parent: Node3D, rng: Rng32, id: String, how: String, span: float, flying: bool, at: Vector3, n: Vector3,
		perches := [], lands := true) -> Fly:
	var md: Dictionary = MODELS[id]
	var fb := Fly.new()
	parent.add_child(fb)
	var file := String(md.file)
	var model := (load(file if file.begins_with("res://") else DIR + file) as PackedScene).instantiate() as Node3D
	var turn := Node3D.new()
	turn.rotation = Vector3(0, float(md.yaw), 0)
	turn.scale = Vector3.ONE * span / float(md.span)
	fb.add_child(turn)
	turn.add_child(model)
	# (a model not standing on its own origin: brought to it)
	if md.has("centre"): model.position = -(md.centre as Vector3)
	for nm: String in md.get("hide", []):
		var hn := model.find_child(nm, true, false) as Node3D
		if hn: hn.visible = false
	if md.get("scales", false): _scales(model, id)
	fb.ap = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	fb.anim = md.clips
	fb.kind = id
	fb.model = model
	fb.lands = lands
	fb.loop_clip = float(md.get("loop", 0.0))
	fb.setup(rng, null, how, flying, at, n, perches if perches.size() else [[at, n]], span / 2.0)
	return fb

## a model's flat painted wings given a surface (shaders/butterfly_scales.gdshader: rows of scales, powder, a velvet
## sheen): its one material swapped for the shader's with the same picture; one material per kind, shared
const SCALES := preload("res://shaders/butterfly_scales.gdshader")
static var _scale_mats := {}
static var _scale_lock := Mutex.new()
static func _scales(model: Node3D, id: String) -> void:
	for n in model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null: continue
		for si in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(si) as BaseMaterial3D
			if src == null or src.albedo_texture == null: continue
			# (a see-through wing — the clearwing's — keeps its glass, but is lit from within a little and catches the
			# light at its edge: dark glass over a dark card was all but invisible)
			if src.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA:
				_scale_lock.lock()
				var gk := id + ":glass" + str(si)
				if not _scale_mats.has(gk):
					var gm := StandardMaterial3D.new()
					gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					gm.cull_mode = BaseMaterial3D.CULL_DISABLED
					gm.albedo_texture = src.albedo_texture
					gm.albedo_color = Color(1.5, 1.5, 1.6, 1.0)
					gm.emission_enabled = true
					gm.emission_texture = src.albedo_texture
					gm.emission_energy_multiplier = 0.9
					gm.roughness = 0.25
					gm.rim_enabled = true
					gm.rim = 0.8
					gm.rim_tint = 0.3
					_scale_mats[gk] = gm
				_scale_lock.unlock()
				mi.set_surface_override_material(si, _scale_mats[gk])
				continue
			_scale_lock.lock()
			var key := id + ":" + str(si)
			if not _scale_mats.has(key):
				var m := ShaderMaterial.new()
				m.shader = SCALES
				m.set_shader_parameter("tex", src.albedo_texture)
				m.set_shader_parameter("cut", 0.5 if src.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED else 0.0)
				_scale_mats[key] = m
			_scale_lock.unlock()
			mi.set_surface_override_material(si, _scale_mats[key])

## how each kind lives: its wingbeats a second, the top and bottom of its stroke (a drawn wing's angles: the model's
## own stroke is fitted to them), how fast it flies, how readily it sails (0 never) and changes its mind, how long it
## flies and sits, how often it opens its wings to the sun as it sits, and how they rest (1.5 closed over the back)
const STYLE := {
	float = {hz = 3.2, up = 1.5, dn = -0.55, speed = 1.3, glide = 0.45, jerk = 0.2, fly = [5.0, 9.0], sit = [3.0, 7.0], sun = 0.7, rest = 1.5},
	glide = {hz = 4.5, up = 1.5, dn = -0.5, speed = 1.6, glide = 0.35, jerk = 0.25, fly = [4.0, 8.0], sit = [2.5, 6.0], sun = 0.5, rest = 1.5},
	flit = {hz = 9.0, up = 1.45, dn = -0.4, speed = 1.8, glide = 0.0, jerk = 1.0, fly = [2.0, 4.5], sit = [1.5, 3.5], sun = 0.6, rest = 1.5},
	hover = {hz = 23.0, up = 0.85, dn = -0.35, speed = 3.6, glide = 0.0, jerk = 0.1, fly = [7.0, 12.0], sit = [4.0, 8.0], sun = 0.0, rest = -0.08, dart = 1.0},
	drift = {hz = 2.0, up = 1.35, dn = -0.5, speed = 0.9, glide = 0.15, jerk = 0.1, fly = [6.0, 10.0], sit = [4.0, 8.0], sun = 0.0, rest = 0.2},
	# a firefly: a slow drift on blurred wings, level (grav: its own, hardly a bounce), wandering, never still for long
	glow = {hz = 18.0, up = 0.85, dn = -0.35, speed = 1.5, glide = 0.0, jerk = 0.6, fly = [9.0, 9.0], sit = [1.0, 1.0], sun = 0.0, rest = 0.0, grav = 90.0},
	weave = {hz = 6.0, up = 1.45, dn = -0.45, speed = 1.2, glide = 0.05, jerk = 0.7, fly = [3.0, 6.0], sit = [2.0, 4.5], sun = 0.3, rest = 1.5},
}

## the butterfly's life, all in the find's own space: it flies round the find (wingbeats, sails, bobbing on each
## stroke, banking into turns), picks a spot on the find, comes in, lands and folds its wings, sits (now and then opening
## them to the sun, or a slow clap), and takes off again. The wings' angles go to the shader (ang, flex).
class Fly extends Node3D:
	enum { FLY, LAND, SIT, OFF }
	var mat: ShaderMaterial
	var body_mat: ShaderMaterial
	var pitch := 0.0        # nose up (+) — tips with each stroke in the air
	var bob := 0.0          # the body's rise and fall on each stroke, in spans
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
	# a whole animated model (SpecButterfly.MODELS): its player and its animations by state
	var ap: AnimationPlayer
	var anim := {}
	var _playing := ""
	var kind := ""
	var lands := true       # false: it never comes down (a firefly of the swarm)
	var loop_clip := 0.0    # > 0: its flight clip simply loops, at this speed (wings too fast to show stroke by stroke)
	var model: Node3D
	var full := false       # a model with its own landing, sitting and take-off (the monarch)
	var tb := {}            # else: its flight clip as a table, the wing's rise by the clip's time (_m_table)
	var last_a := 9.0
	var going_down := true
	var pose_a := 0.0
	var pose_due := false
	var stand_raw := []     # [into its own space, its box there] of each thing standing on the find
	var touch := 0.0        # landing: seconds since the feet came down
	# a model's flight (the _m_ functions below)
	var yaw := 0.0
	var yaw_rate := 0.0
	var ct := 0.0           # the flight clip's time (driven from here, stroke by stroke)
	var wing := 0           # 0, 1: the clip's two beats in turn; 2 into a glide; 3 gliding; 4 out of it
	var lift := 0.0         # 1 while the wings come down
	var beat := false       # a beat has just begun
	var stroke := 1.0       # how hard this beat is
	var way := Vector3.ZERO # where it is making for
	var dwell := 0.0
	var far := false        # a long leg, out past the find (it may sail on it)
	var want_glide := false
	var glide_left := 0.0
	var mpitch := 0.0
	var mroll := 0.0
	var stage := 0          # landing: 0 coming to hover over the spot, 1 down onto it, 2 feet down
	var off_t := 0.0
	var quat := Quaternion.IDENTITY
	var trace := false
	var beat_t := 0.2       # seconds a wingbeat: its own (no two beat in step)
	var grav := 75.0        # half-spans / s²: by its beat (a slow beater would bounce a span at a time)
	var dart := 0.0         # a hawk-moth: darts straight to a point and hangs on it
	var wph := 0.0          # a drawn one's wingbeat, 0 (wings up) .. 1
	var land_key := Vector3.INF
	var beats_left := 4     # beats till it next sails
	var sail_k := 1.0       # how much of a sailer this one is

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
		var cand := []
		var stack: Array[Node] = [top_n]
		while stack.size():
			var n: Node = stack.pop_back()
			if n is Fly: continue
			stack.append_array(n.get_children())
			# what stands on the find as many copies of one mesh (the mushrooms, SpecFungi: marked "stand"): each copy
			# with its own box, in its own axes
			if n is MultiMeshInstance3D and n.has_meta("stand"):
				var mmi := n as MultiMeshInstance3D
				var mb := mmi.multimesh.mesh.get_aabb()
				var mx := SpecUtil.rel_xform(mmi, top_n)
				for k in mmi.multimesh.instance_count:
					var ix := mx * mmi.multimesh.get_instance_transform(k)
					var ib := ix * mb
					obst.append([ib.get_center(), ib.size * 0.5 + Vector3.ONE * size * 0.3])
					stand.append(ib.grow(size * 0.45))
					var inv := ix.affine_inverse()
					stand_raw.append([inv, mb.grow(size * 0.12 * inv.basis.get_scale().x)])
				continue
			if not (n is MeshInstance3D) or not n.has_meta("geo"): continue
			var g: Geo = n.get_meta("geo")
			var bb: AABB = SpecUtil.rel_xform(n as Node3D, top_n) * g.aabb()
			if bb.size.length() < 0.04: continue
			box = bb if first else box.merge(bb)
			first = false
			obst.append([bb.get_center(), bb.size * 0.5 + Vector3.ONE * size * 0.3])
			if not (n.has_meta("base") or n.has_meta("rock") or n.has_meta("box") or n.has_meta("ground")):
				cand.append([n, bb, g])
		# the things standing up off the body (crystals, trees, mushrooms): a butterfly does not land in them. Not the
		# body itself — the rock, the bone, a skull's horns and jaw (marked), nor anything as big as the whole find (the
		# rock's coats: its dirt, its sea light) — told by what it is, not by where it hangs
		for c: Array in cand:
			var cb: AABB = c[1]
			var wide := int(cb.size.x > box.size.x * 0.6) + int(cb.size.y > box.size.y * 0.6) + int(cb.size.z > box.size.z * 0.6)
			if wide >= 2: continue
			stand.append(cb.grow(size * 0.45))
			# (its own box, in its own axes: a leaning crystal's upright box takes in far more than the crystal)
			var into := SpecUtil.rel_xform(c[0] as Node3D, top_n).affine_inverse()
			stand_raw.append([into, (c[2] as Geo).aabb().grow(size * 0.12 * into.basis.get_scale().x)])
		# the perches and the start, into the find's space
		var pt := SpecUtil.rel_xform(get_parent() as Node3D, top_n) if get_parent() != top_n else Transform3D.IDENTITY
		perch = perch.map(func(q: Array) -> Array: return [pt * (q[0] as Vector3), (pt.basis * (q[1] as Vector3)).normalized()])
		# only where the wings have room: no crystal or tree within a span, and fairly level
		var free := perch.filter(func(q: Array) -> bool: return (q[1] as Vector3).y >= 0.55 and not _m_inside(q[0]))
		if free.size(): perch = free
		if start_fly:
			pos = _shell()
			vel = Vector3(rng.next() - 0.5, 0.1, rng.next() - 0.5).normalized() * size * float(st.speed)
			target = _shell()
			state = FLY
			timer = _rnd(st.fly) * 0.45   # (the first landing soon: a card is not looked at for long)
		else:
			# a spot of its own (they all started on the first spot of the list, one on top of the other)
			var pick := _m_spot() if perch.size() else []
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
			_m_init()
		dt = minf(dt, 0.05)
		timer -= dt
		_m_process(dt)

	func _swing(_v: float) -> void:
		pass

	## the wings at a stroke's angle (st.up at the top .. st.dn at the bottom): the model's flight clip shown at the
	## moment its own wings are there — on its downstroke if ours is coming down, on its upstroke if going up
	func _wings(a: float, _f: float) -> void:
		if full or tb.is_empty() or _playing != "fly": return
		pose_a = a
		pose_due = true

	## the pose asked for this frame, shown (once a frame: every showing moves the whole skeleton)
	func _m_pose() -> void:
		pose_due = false
		var a := pose_a
		if a < last_a - 1e-4: going_down = true
		elif a > last_a + 1e-4: going_down = false
		last_a = a
		# (with its feet down, only ever the downstroke's poses: the two halves of the stroke hold the body and the hind
		# wings a little differently, and a sitting butterfly's small movements flipped between them — it twitched)
		if state == SIT or (state == LAND and stage == 2): going_down = true
		var u := clampf((a - float(st.dn)) / (float(st.up) - float(st.dn)), 0.0, 1.0)
		var e := lerpf(float(tb.lo), float(tb.hi), u)
		var tab: Array = tb.down if going_down else tb.up
		var t: float = tab[tab.size() - 1][0]
		for i in range(1, tab.size()):
			var e0: float = tab[i - 1][1]
			var e1: float = tab[i][1]
			if (going_down and e1 <= e) or (not going_down and e1 >= e):
				var f := 0.0 if is_equal_approx(e0, e1) else clampf((e - e0) / (e1 - e0), 0.0, 1.0)
				t = lerpf(float(tab[i - 1][0]), float(tab[i][0]), f)
				break
		ap.seek(fmod(t, float(tb.len)), true)

	## a model's flight clip read once: its wing's rise at 120 moments, and from them one stroke — from a top down to
	## the bottom after it (down) and up to the next top (up) — as [clip time, rise] tables
	static var _tables := {}
	func _m_table() -> Dictionary:
		if _tables.has(kind): return _tables[kind]
		var md: Dictionary = SpecButterfly.MODELS[kind]
		var sk := model.find_child("Skeleton3D", true, false) as Skeleton3D
		var nm := String(anim.fly)
		var out := {}
		if sk == null or not ap.has_animation(nm):
			_tables[kind] = out
			return out
		var find := func(prefix: String) -> int:
			for i in sk.get_bone_count():
				if sk.get_bone_name(i).begins_with(prefix): return i
			return -1
		var tip: int = find.call(String(md.get("tip", "LeftUpperWing")))
		if tip < 0:
			_tables[kind] = out
			return out
		var base: int = find.call(String(md.base)) if md.has("base") else -1
		var rel := model.global_transform.affine_inverse() * sk.global_transform
		var L := ap.get_animation(nm).length
		var N := 120
		var e := PackedFloat32Array()
		ap.play(nm)
		ap.speed_scale = 0.0
		for i in N:
			ap.seek(L * i / N, true)
			var bp := rel * sk.get_bone_global_pose(tip)
			if base >= 0:
				var d := bp.origin - (rel * sk.get_bone_global_pose(base)).origin
				e.append(atan2(d.y, absf(d.x)))
			else:
				e.append(asin(clampf(bp.basis.y.normalized().y, -1.0, 1.0)))
		var top := 0
		for i in N:
			if e[i] > e[top]: top = i
		var lo := e[top]
		var hi := e[top]
		for v in e:
			lo = minf(lo, v)
		var mid := (lo + hi) * 0.5
		# down from the top to the first turn below the middle, then up to the first turn above it
		var j := top
		var down := [[L * top / N, hi]]
		for step in N:
			var nx := j + 1
			if e[nx % N] > e[j % N] + 0.002 and e[j % N] < mid: break
			j = nx
			down.append([L * j / N, minf(e[j % N], float(down[down.size() - 1][1]))])
		var up := [[L * j / N, e[j % N]]]
		for step in N:
			var nx := j + 1
			if e[nx % N] < e[j % N] - 0.002 and e[j % N] > mid: break
			j = nx
			up.append([L * j / N, maxf(e[j % N], float(up[up.size() - 1][1]))])
		out = {down = down, up = up, lo = float(down[down.size() - 1][1]), hi = hi, len = L}
		_tables[kind] = out
		return out

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

	## sitting: wings closed over the back (a moth's flat roof), opened to the sun for a while, a slow clap now and then
	func _sit(dt: float) -> void:
		var rest := float(st.rest)
		sun_t -= dt
		if sun_t <= 0.0:
			sun_to = 1.0 if rng.next() < float(st.sun) and sun_to < 0.5 else 0.0
			sun_t = 1.2 + rng.next() * 2.5
		sun = move_toward(sun, sun_to, dt * 1.6)
		# opened to the sun only to a V, never flat: flat wings dipped into the curve of the bone
		# (opened to the sun: a V, the wings ~35° above level — on a model, the stroke's angle at which its own wings
		# stand so; never flat)
		var vee := 0.5
		if not tb.is_empty():
			vee = lerpf(float(st.dn), float(st.up), clampf((0.6 - float(tb.lo)) / maxf(0.01, float(tb.hi) - float(tb.lo)), 0.0, 1.0))
		var open := lerpf(rest, vee, smoothstep(0.0, 1.0, sun))
		# a slow clap while open, a shiver while closed
		var clap := sin(timer * 2.2) * 0.12 * sun
		_wings(open + clap, 0.0)
		bank = 0.0
		pitch = 0.0
		bob = 0.0
		# (breathing: the abdomen rises and falls a little)
		_swing(sin(timer * 1.7) * 0.08)
		if timer <= 0.0:
			state = OFF
			timer = 0.6
			vel = (spot[1] as Vector3) * size * float(st.speed) * 0.8
			_claim(spot[0], false)

	## how deep a point is in a piece of the find: < 1 inside. The piece's shell is its box with the corners rounded
	## (a fourth-power ball: an ellipsoid inside the box left its corners open — butterflies flew through the rock there)
	static func _in(p: Vector3, oc: Vector3, oh: Vector3) -> float:
		var q := (p - oc) / oh
		return pow(q.x * q.x * q.x * q.x + q.y * q.y * q.y * q.y + q.z * q.z * q.z * q.z, 0.25)

	## keep out of every piece of the find (but for the one being landed on, near its spot)
	func _keep_out(near := Vector3.INF) -> void:
		for o: Array in obst:
			var oc: Vector3 = o[0]
			var oh: Vector3 = o[1]
			var l := _in(pos, oc, oh)
			if l < 1.0:
				# (coming in to land: the piece it lands on — any piece whose shell holds the spot — lets it through)
				if near != Vector3.INF and (_in(near, oc, oh) < 1.0 or pos.distance_to(near) < size * 1.2): continue
				var q := (pos - oc) / oh
				if l < 1e-4:
					q = Vector3.UP
					l = 1.0
				var out := oc + q / l * oh
				# (the shell's own normal there: the gradient of the fourth-power ball)
				var nrm := (Vector3(q.x * q.x * q.x, q.y * q.y * q.y, q.z * q.z * q.z) / oh).normalized()
				pos = out
				vel -= nrm * minf(0.0, vel.dot(nrm))

	# ---------------------------------------------------------------- a model's flight
	# A whole animated model (SpecButterfly.MODELS) flies by forces, not along a rail: gravity all the time, a push up
	# (and a little forward) on every downstroke — so its path bounces beat by beat, sinks when a beat is weak, climbs
	# when one is strong — steering by turning the body in jerks, beat by beat. Its wings are the model's own flight clip,
	# shown stroke by stroke from here (the clip holds two beats, 0–0.11 s and 0.42–0.53 s, and between them a beat that
	# ends in a glide, 0.11–0.36 s), so every push falls on a wing coming down and a glide is a glide. By a find it
	# forages: short hops between points over the find, hovering at each, landing now and then; a long leg out past the
	# find and back is the only place it sails. Units: its half-span (size) and seconds.

	func _m_play(key: String, blend := 0.15, at := 0.0, speed := 1.0) -> void:
		var nm := String(anim.get(key, ""))
		if nm == "" or not ap.has_animation(nm): return
		if key == "sit": ap.get_animation(nm).loop_mode = Animation.LOOP_LINEAR
		if key == "fly" and loop_clip > 0.0:
			ap.get_animation(nm).loop_mode = Animation.LOOP_LINEAR
			speed = loop_clip
			if at <= 0.0: at = rng.next() * ap.get_animation(nm).length
		ap.play(nm, blend)
		ap.speed_scale = speed
		if at > 0.0: ap.seek(at, true)
		_playing = key

	func _m_init() -> void:
		trace = OS.get_cmdline_user_args().has("flytrace")
		full = anim.has("land")
		dart = float(st.get("dart", 0.0))
		if not full and loop_clip <= 0.0: tb = _m_table()
		# a model beats at the pace its clip reads well; a drawn one at its kind's (STYLE hz), each a little off the rest
		beat_t = 0.19 + rng.next() * 0.06 if full else (1.0 / float(st.hz)) * (0.9 + rng.next() * 0.25)
		grav = 75.0 * pow(0.21 / beat_t, 1.4)
		# (a hawk-moth's wings are a blur: it hangs level, no bounce to speak of)
		if float(st.get("dart", 0.0)) > 0.0: grav = 170.0
		if st.has("grav"): grav = float(st.grav)
		sail_k = 0.7 + rng.next() * 0.7
		wph = rng.next()
		beats_left = 1 + int(rng.next() * 5.0)
		ct = rng.next() * 0.1
		yaw = atan2(vel.x, vel.z) if state == FLY else atan2(heading.x, heading.z)
		if state == FLY:
			_m_next()
			_m_play("fly", 0.0, 0.0, 0.0)
		elif anim.has("sit"):
			_m_play("sit", 0.0, rng.next() * 2.0)
		else:
			_m_play("fly", 0.0, 0.0, 0.0)
			_wings(float(st.rest), 0.0)
		quat = _m_basis().get_rotation_quaternion()

	func _m_process(dt: float) -> void:
		match state:
			FLY:
				_m_air(dt)
				# time to land: pick a spot on the find
				if timer <= 0.0 and perch.size() and lands:
					var pick := _m_spot()
					if pick.is_empty():
						timer = 1.0 + rng.next()
					else:
						spot = pick
						_claim(spot[0], true)
						state = LAND
						stage = 0
						far = false
						way = (spot[0] as Vector3) + (spot[1] as Vector3) * size * 1.1
						retarget = 6.0
			LAND: _m_land(dt)
			SIT:
				if full:
					if timer <= 0.0:
						state = OFF
						off_t = 0.0
						_claim(spot[0], false)
						_m_play("off", 0.1)
				else:
					# it sits in its own idle if it has one, else in its stroke (wings closed, opened to the sun, a slow
					# clap), and jumps off on a hard beat
					_sit(dt)
					if state == OFF:
						state = FLY
						_m_play("fly", 0.0, 0.0, 0.0)
						vel = ((spot[1] as Vector3) * 2.5 + Vector3.UP * 3.0) * size
						wing = 0
						wph = 0.0
						stroke = 1.5
						beats_left = 3
						timer = _rnd(st.fly)
						_m_next()
			_: _m_off(dt)
		if pose_due: _m_pose()
		var q := _m_basis().get_rotation_quaternion()
		quat = quat.slerp(q, 1.0 - exp(-dt * 11.0))
		var into := SpecUtil.rel_xform(get_parent() as Node3D, top_n).affine_inverse() if get_parent() != top_n else Transform3D.IDENTITY
		transform = into * Transform3D(Basis(quat), pos)
		# (flytrace: its path printed, for one butterfly on a find — printing is slow, several of them drag the frame)
		if trace: print("FLY %.3f %.4f %.4f %.4f %d %.3f %d %d" % [Time.get_ticks_msec() / 1000.0, pos.x / size, pos.y / size, pos.z / size, state, ct, wing, get_instance_id() % 1000])

	## where it is turned: along its heading, upright in the air (nose up when it hovers, down a little at speed, rolled
	## into a turn), on the surface's own up once its feet are down
	func _m_basis() -> Basis:
		var up := Vector3.UP
		var fwd := Vector3(sin(yaw), 0.0, cos(yaw))
		var down := state == SIT or (state == LAND and stage == 2) or (state == OFF and off_t < 0.2)
		if down and spot.size():
			up = spot[1]
			fwd = (fwd - up * fwd.dot(up)).normalized()
			if fwd.length() < 1e-3: fwd = up.cross(Vector3.RIGHT).normalized()
		var side := fwd.cross(up).normalized()
		up = side.cross(fwd).normalized()
		var bas := Basis(side, up, -fwd).orthonormalized() * Basis(Vector3.UP, PI * 0.5)
		# (a model's clip holds its body nose up already; a drawn one's card lies flat)
		if not down: bas = bas * Basis(Vector3.RIGHT, mroll) * Basis(Vector3.BACK, mpitch + float((SpecButterfly.MODELS[kind] as Dictionary).pitch))
		return bas

	## the next point to make for: mostly a hover over some spot on the find, sometimes out on the shell round it, now
	## and then a long leg out past it
	func _m_next() -> void:
		far = false
		var roll := rng.next()
		if perch.size() and roll < 0.6:
			var q: Array = perch[int(rng.next() * perch.size())]
			way = (q[0] as Vector3) + (q[1] as Vector3) * size * (1.2 + rng.next() * 1.6) + Vector3(rng.next() - 0.5, 0.0, rng.next() - 0.5) * size
		elif roll < 0.72:
			var sp := _shell()
			var c := box.get_center()
			way = c + (sp - c) * 1.45
			way.y = sp.y + size * 0.5
			far = true
		else:
			way = _shell()
		way = _m_clear(way)
		dwell = 0.3 + rng.next() * 1.1
		# (a hawk-moth hangs on the spot a good while, then is gone to the next)
		if dart > 0.0: dwell = 0.7 + rng.next() * 1.8
		retarget = 3.0

	## a point moved out of the find's pieces (it could never be reached inside one: the butterfly hung against it)
	func _m_clear(w: Vector3) -> Vector3:
		for o: Array in obst:
			var oc: Vector3 = o[0]
			var oh: Vector3 = o[1]
			var l := _in(w, oc, oh)
			if l < 1.15:
				var q := (w - oc) / oh
				if l < 1e-4:
					q = Vector3.UP
					l = 1.0
				w = oc + q / l * oh * 1.15
		return w

	## a point is inside something standing on the find (a crystal, a tree, a mushroom)
	func _m_inside(p: Vector3) -> bool:
		for ob: Array in stand_raw:
			if (ob[1] as AABB).has_point((ob[0] as Transform3D) * p): return true
		return false

	## a spot to land on, no other butterfly's: best one with room to come down on (nothing standing over it or where it
	## hovers before it comes down), else at least one not inside a crystal or a tree
	func _m_spot() -> Array:
		var t := _taken()
		var second := []
		for k in 24:
			var q: Array = perch[int(rng.next() * perch.size())]
			var p: Vector3 = q[0]
			var ok := true
			for o: Vector3 in t:
				if o.distance_to(p) < size * 1.3: ok = false
			if not ok: continue
			if _m_inside(p) or _m_inside(p + (q[1] as Vector3) * size * 0.3): continue
			var roomy := true
			var hover := p + (q[1] as Vector3) * size * 1.1
			for bb: AABB in stand:
				if bb.has_point(hover) or bb.has_point(p): roomy = false
			if roomy: return q
			if second.is_empty(): second = q
		return second

	## the wings: the clip's time moved on by one step; sets lift (the wings are coming down) and beat (one has begun)
	func _m_wings(h: float) -> void:
		if not full:
			_m_wings_drawn(h)
			return
		var r := 0.11 / beat_t
		beat = false
		match wing:
			0:
				ct += h * r
				if ct >= 0.11:
					if want_glide:
						wing = 2
						# (the beat that ends in the sail is just hard enough to stop its rise or fall: it floats into the sail level)
						stroke = clampf((1.0 - vel.y / (grav * size * 0.455 * beat_t)) / 2.2, 0.15, 1.5)
						want_glide = false
					else:
						ct = 0.42 + (ct - 0.11)
						wing = 1
						beat = true
			1:
				ct += h * r
				if ct >= 0.53:
					ct -= 0.53
					wing = 0
					beat = true
			2:
				ct += h * r
				if ct >= 0.36:
					ct = 0.36
					wing = 3
			3: pass
			_:
				ct += h * r
				if ct >= 0.42:
					wing = 1
					beat = true
		lift = 1.0 if ct < 0.05 or (ct >= 0.42 and ct < 0.47) or (ct >= 0.11 and ct < 0.17) else 0.0

	## a drawn one's wings: the stroke from the top (wings almost meeting over the back) down below the body and up
	## again, the down a little quicker, the tips trailing; into a sail — one more stroke down, then up only to a shallow
	## V and held there; out of it — up to the top and on
	func _m_wings_drawn(h: float) -> void:
		var up := float(st.up)
		var dn := float(st.dn)
		var sail := 0.16
		beat = false
		var a := up
		var flex := 0.0
		match wing:
			2:
				wph += h / beat_t
				if wph >= 1.0:
					wph = 1.0
					wing = 3
				a = lerpf(up, dn, smoothstep(0.0, 0.45, wph)) if wph < 0.45 else lerpf(dn, sail, smoothstep(0.45, 1.0, wph))
				flex = sin(minf(wph, 0.6) * TAU) * 0.5
			3:
				a = sail + sin(Time.get_ticks_msec() * 0.006 + beat_t * 40.0) * 0.03
			4:
				wph += h / beat_t * 2.2
				a = lerpf(sail, up, smoothstep(0.0, 1.0, wph))
				flex = -0.3 * sin(wph * PI)
				if wph >= 1.0:
					wph = 0.0
					wing = 0
					beat = true
			_:
				wph += h / beat_t
				if wph >= 1.0:
					wph -= 1.0
					if want_glide:
						wing = 2
						want_glide = false
						stroke = clampf((1.0 - vel.y / (grav * size * 0.455 * beat_t)) / 2.2, 0.15, 1.5)
					else:
						beat = true
				a = lerpf(up, dn, smoothstep(0.0, 0.45, wph)) if wph < 0.45 else lerpf(dn, up, smoothstep(0.45, 1.0, wph))
				flex = sin(wph * TAU) * 0.55
		lift = 1.0 if wing <= 2 and wph < 0.455 else 0.0
		_wings(a, flex)
		_swing(-sin(wph * TAU - 0.9) * 0.4 if wing <= 2 else 0.0)

	## the pilot, once a beat: how hard to beat (to hold its height: harder when low or sinking), which way to turn (in a
	## jerk, never quite true), whether to sail
	func _m_pilot() -> void:
		var to := way - pos
		var e := to.y / size
		stroke = clampf(1.0 + 0.45 * e - 0.1 * vel.y / size, 0.5, 1.7) * (0.9 + rng.next() * 0.2)
		var flat := Vector2(to.x, to.z)
		var want := atan2(to.x, to.z) if flat.length() > size * 0.6 else yaw + (rng.next() - 0.5) * (0.0 if dart > 0.0 else 1.6)
		var err := wrapf(want - yaw, -PI, PI) + (rng.next() - 0.5) * (0.3 + float(st.jerk) * 0.8)
		yaw_rate = clampf(err / beat_t * 0.7, -6.0, 6.0)
		var hs := Vector2(vel.x, vel.z).length()
		# its rhythm: a few beats, then it sails a moment — the last beat before a sail a strong one, so it rises into it
		# (not while it hovers on a point or comes down to land, nor when it is low)
		if wing == 0 and float(st.glide) > 0.0:
			beats_left -= 1
			var room := flat.length() > size * 1.3 and e < 0.5 and not (state == LAND and stage == 1)
			if beats_left <= 0 and room:
				want_glide = true
				glide_left = rng.next() * 0.5 * sail_k + (0.3 if far else 0.0)
				beats_left = 2 + int(rng.next() * 1.4 / float(st.glide) / sail_k)
			elif beats_left <= 0:
				beats_left = 1

	## in the air for dt: wings, pilot and forces in small steps
	func _m_air(dt: float) -> void:
		if _playing != "fly": _m_play("fly", 0.0, 0.0, 0.0)
		var n := ceili(dt / 0.008)
		var h := dt / n
		for k in n:
			_m_wings(h)
			if beat: _m_pilot()
			yaw += yaw_rate * h
			var fwd := Vector3(sin(yaw), 0.0, cos(yaw))
			var to := way - pos
			var flat := Vector3(to.x, 0.0, to.z)
			var d := flat.length()
			var dir := flat / d if d > 1e-4 else fwd
			var vdes := clampf(d / size * (6.0 if dart > 0.0 else 1.8), 0.0, (7.0 if far else 5.0) * float(st.speed) / 1.6) * size
			var hv := Vector3(vel.x, 0.0, vel.z)
			# it pulls itself along its own nose, and a little straight at the point (enough to hover on it)
			var want_v := fwd * vdes * maxf(0.0, fwd.dot(dir)) * 0.7 + dir * vdes * 0.3
			var acc := (want_v - hv) * 3.0
			# a hawk-moth (dart): straight at the point whichever way it faces, hard — and it stops dead on it
			if dart > 0.0:
				want_v = dir * vdes
				acc = (want_v - hv) * 10.0
			var ay := -grav * size - vel.y * 1.5
			if lift > 0.0: ay += 2.2 * grav * size * stroke
			var sailing := wing == 3 or wing == 4 or (wing == 2 and ct > 0.17)
			if sailing:
				# wings held out: they carry it while it has speed, it keeps its way and loses height slowly
				# spread wings carry it: whatever it was doing, it eases into a slow sink (most of a half-span a second)
				ay = (-0.8 * size - vel.y) * 12.0
				acc = (fwd * hv.length() - hv) * 2.0 - hv * 0.25
				glide_left -= h
				if wing == 3 and (glide_left <= 0.0 or pos.y < way.y - size * 0.7 or d < size * 1.5):
					wing = 4
					wph = 0.0
			vel += (acc + Vector3(0.0, ay, 0.0)) * h
			pos += vel * h
			var hsp := hv.length() / size
			mpitch = lerpf(mpitch, lerpf(0.3, -0.3, clampf(hsp / 5.0, 0.0, 1.0)) + (0.1 if sailing else 0.0) * -3.0, minf(1.0, h * 6.0))
			mroll = lerpf(mroll, clampf(yaw_rate * 0.07, -0.45, 0.45), minf(1.0, h * 8.0))
			if state == FLY:
				# there: it hovers a moment, then on to the next (also if it cannot get there)
				retarget -= h
				if d < size * 0.9 and absf(to.y) < size: dwell -= h
				if dwell <= 0.0 or retarget <= 0.0: _m_next()
		_keep_out((spot[0] as Vector3) if state == LAND and spot.size() else Vector3.INF)
		if full: ap.seek(ct, true)

	## coming in: to a hover over the spot, down onto it — beating all the way, the body standing up as it slows — and
	## the feet down: the model's own landing from there on (the last flicks of the wings as it settles), then it sits
	func _m_land(dt: float) -> void:
		var p: Vector3 = spot[0]
		var n: Vector3 = spot[1]
		# (sent to land from outside too — the butterfly cloud's Flock: the approach starts here)
		if land_key != p:
			land_key = p
			stage = 0
			far = false
			way = p + n * size * 1.1
			retarget = 6.0
		retarget -= dt
		if stage < 2:
			_m_air(dt)
			var hd := Vector2(pos.x - way.x, pos.z - way.z).length()
			if stage == 0 and ((hd < size * 0.8 and absf(pos.y - way.y) < size * 1.2) or retarget < 4.0):
				stage = 1
				retarget = 4.0
				way = p + n * size * 0.2
			elif stage == 1 and ((hd < size * 0.5 and pos.y - way.y < size * 0.45) or retarget < 2.8):
				stage = 2
				touch = 0.0
				land_from = pos
				vel = Vector3.ZERO
				if full: _m_play("land", 0.12, 0.5)
		else:
			touch += dt
			pos = land_from.lerp(p + n * size * 0.02, smoothstep(0.0, 0.22, touch))
			mpitch = 0.0
			mroll = 0.0
			# (a drawn one: a few dying flicks of the wings, settling to how it rests)
			if not full:
				var f := clampf(touch / 0.6, 0.0, 1.0)
				_wings(lerpf(float(st.up) * 0.6, float(st.rest), f) + sin(touch * 20.0) * 0.3 * (1.0 - f) * (1.0 - f), 0.0)
				_swing(0.0)
			if touch >= (0.85 if full else 0.6):
				state = SIT
				land_key = Vector3.INF
				timer = _rnd(st.sit)
				sun = 0.0
				sun_t = 0.5 + rng.next()
				if anim.has("sit"): _m_play("sit", 0.3, 0.0 if full else rng.next() * 2.0)

	## taking off: the model's own take-off — it gathers itself, jumps on the first stroke, three beats up and away
	func _m_off(dt: float) -> void:
		off_t += dt
		if off_t < 0.2: return
		var n: Vector3 = spot[1]
		vel += ((Vector3.UP * 0.9 + n * 0.3) * 14.0 * size - vel * 2.0) * dt
		pos += vel * dt
		mpitch = lerpf(mpitch, 0.3, minf(1.0, dt * 6.0))
		if off_t >= 0.57:
			state = FLY
			timer = _rnd(st.fly)
			ct = 0.0
			wing = 0
			_m_play("fly", 0.0, 0.0, 0.0)
			_m_next()

