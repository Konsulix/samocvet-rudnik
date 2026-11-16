class_name SpecReef
extends RefCounted
## The living sea floor of a sea find (a trilobite's or an ammonite's slab): scans of real weed, corals and anemones,
## starfish and urchins, shells, crabs (assets/specimen/sea, made by prototype/tools/sea/sea_prep.py; authors in
## CREDITS.md there) set on the slab round the fossil — the tall ones behind it, the small ones before and beside it —
## and now and then a big swimmer of the old seas circling the find (the sea's butterflies). The weed and the anemones
## sway, a swimmer's body waves (shaders/fungi_model.gdshader: sway, swim).
## Its genes are drawn on their own stream (genes()), so the finds' other draws stay where they were.

const DIR := "res://assets/specimen/sea/"
const U := preload("res://scripts/specimen/spec_util.gd")
const SWIM := preload("res://shaders/sea_swim.gdshader")

## each model: its group, its name on the card, its size (k, of its group's), its colour (gain, sat, tint), sway
const MODELS := {
	weed_kelp = {g = "weed", n = "giant kelp", k = 1.1, sway = 0.07},
	weed_claret = {g = "weed", n = "sea oak", k = 1.0, sway = 0.06, gain = 5.0, sat = 0.85, tint = Color(1.25, 1.0, 0.75)},
	weed_wiggle = {g = "weed", n = "bladder wrack", k = 0.85, sway = 0.07, gain = 5.0, sat = 0.85, tint = Color(1.25, 1.0, 0.75)},
	coral_red = {g = "coral", n = "red coral", k = 1.0, tint = Color(1.0, 0.62, 0.5), sat = 1.4},
	coral_organ = {g = "coral", n = "organ pipe coral", k = 0.8},
	coral_blue = {g = "coral", n = "blue coral", k = 0.9},
	coral_staghorn = {g = "coral", n = "staghorn coral", k = 1.0},
	coral_pocillopora = {g = "coral", n = "cauliflower coral", k = 0.8},
	coral_rosebrain = {g = "coral", n = "rose brain coral", k = 0.65},
	anemone_elegant = {g = "coral", n = "elegant anemone", k = 0.55, sway = 0.05},
	anemone_purple = {g = "coral", n = "purple anemone", k = 0.55, sway = 0.05},
	star_bat = {g = "star", n = "bat star", k = 0.9},
	star_brittle = {g = "star", n = "brittle star", k = 1.1},
	star_brittle_b = {g = "star", n = "banded brittle star", k = 1.1},
	star_sand = {g = "star", n = "sand star", k = 1.0},
	star_cushion = {g = "star", n = "cushion star", k = 0.85},
	star_sea = {g = "star", n = "ochre star", k = 1.0},
	star_sunflower = {g = "star", n = "sunflower star", k = 1.15},
	urchin_purple = {g = "star", n = "purple urchin", k = 0.7},
	shell_tun = {g = "shell", n = "giant tun", k = 1.0, gain = 0.8},
	shell_triton = {g = "shell", n = "knobbed triton", k = 1.15},
	shell_tridacna = {g = "shell", n = "giant clam", k = 1.05},
	shell_moon = {g = "shell", n = "moon scallop", k = 0.95},
	shell_noble = {g = "shell", n = "noble scallop", k = 0.95},
	shell_cone = {g = "shell", n = "marbled cone", k = 0.85},
	crab_lobster = {g = "crab", n = "fan lobster", k = 1.05},
	crab_hermit_b = {g = "crab", n = "hermit crab", k = 0.9},
	crab_hermit_c = {g = "crab", n = "Mediterranean hermit", k = 0.95},
	crab_fiddler = {g = "crab", n = "fiddler crab", k = 0.9},
	crab_frog = {g = "crab", n = "red frog crab", k = 0.95, gain = 1.0},
	crab_elbow = {g = "crab", n = "elbow crab", k = 1.0},
	crab_mantis = {g = "crab", n = "mantis shrimp", k = 1.1},
	crab_isopod = {g = "crab", n = "giant isopod", k = 0.95},
	swim_coelacanth = {g = "swim", n = "coelacanth", k = 0.8, anim = {swim = 0.05, swim_f = 0.55, swim_k = 0.8, swim_from = 0.1, glide = 0.3, flip = 0.5, flip_w = 0.09, flip_x0 = -0.25, flip_x1 = 0.2, flip_mid = 0.0, flip_f = 0.7, jaw = 0.25, jaw_x = 0.38, jaw_y = 0.16}},
	swim_cretoxyrhina = {g = "swim", n = "ginsu shark", k = 1.0, far = true, anim = {swim = 0.11, swim_f = 1.0, swim_k = 0.9, swim_from = 0.05, glide = 0.5, flip = 0.12, flip_w = 0.1, flip_x0 = 0.0, flip_x1 = 0.25, flip_mid = -1.0, flip_f = 0.35, jaw = 0.35, jaw_x = 0.33, jaw_y = 0.11}},
	swim_octopus = {g = "swim", n = "giant octopus", k = 0.8, anim = {swim = 0.02, swim_f = 0.3, swim_k = 1.0, swim_from = 0.0, glide = 0.4, jet = 0.12}},
	swim_mosasaurus = {g = "swim", n = "mosasaur", k = 1.1, far = true, anim = {swim = 0.11, swim_f = 0.55, swim_k = 1.4, swim_from = 0.35, glide = 0.6, flip = 0.35, flip_w = 0.06, flip_x0 = -0.15, flip_x1 = 0.35, flip_mid = 0.1, flip_f = 0.4, jaw = 0.5, jaw_x = 0.32, jaw_y = 0.085}},
	swim_ophthalmosaurus = {g = "swim", n = "ichthyosaur", k = 1.0, far = true, anim = {swim = 0.11, swim_f = 1.2, swim_k = 0.7, swim_from = -0.1, glide = 0.45, flip = 0.25, flip_w = 0.1, flip_x0 = 0.05, flip_x1 = 0.3, flip_mid = -1.0, flip_f = 0.4, jaw = 0.3, jaw_x = 0.3, jaw_y = 0.09}},
	swim_styxosaurus = {g = "swim", n = "plesiosaur", k = 1.15, far = true, anim = {swim = 0.01, swim_f = 0.4, swim_k = 1.0, swim_from = -0.2, glide = 0.3, flip = 0.45, flip_w = 0.07, flip_x0 = -0.45, flip_x1 = -0.05, flip_mid = -0.25, flip_f = 0.32, neck = 0.09, neck_from = 0.0, jaw = 0.4, jaw_x = 0.44, jaw_y = 0.163}},
	swim_tylosaurus = {g = "swim", n = "Tylosaurus", k = 1.1, far = true, anim = {swim = 0.1, swim_f = 0.5, swim_k = 1.3, swim_from = 0.3, glide = 0.6, flip = 0.3, flip_w = 0.1, flip_x0 = -0.2, flip_x1 = 0.35, flip_mid = 0.1, flip_f = 0.45, jaw = 0.5, jaw_x = 0.3, jaw_y = 0.09}},
	swim_dallasaurus = {g = "swim", n = "Dallasaurus", k = 0.8, far = true, anim = {swim = 0.13, swim_f = 0.8, swim_k = 1.6, swim_from = 0.4, glide = 0.55, flip = 0.4, flip_w = 0.065, flip_x0 = 0.05, flip_x1 = 0.3, flip_mid = 0.2, flip_f = 0.8, jaw = 0.4, jaw_x = 0.38, jaw_y = 0.075}},
}
## the size of a group's thing, of the slab's span (for the weed and the corals their height; the rest their reach)
const SIZE := {weed = 0.75, coral = 0.45, star = 0.38, shell = 0.28, crab = 0.34, swim = 0.58}

static var _mesh := {}
static var _mat := {}

static func group(g: String) -> Array:
	var out := []
	for k: String in MODELS:
		if String((MODELS[k] as Dictionary).g) == g: out.append(k)
	return out

static func label(id: String) -> String:
	return String((MODELS.get(id, {}) as Dictionary).get("n", id))

## what lives on this find's floor (its own stream) — a little, so the find stays the thing: the common weed nearly
## always (sea oak or bladder wrack, one clump — the backdrop, not an accent), behind it maybe a coral or the giant
## kelp, before it most often one small thing (a star, an urchin, a shell, a crab), rarely two, and now and then a swimmer
const COMMON := ["weed_claret", "weed_wiggle"]
static func genes(seed_v: int, salt: int) -> Dictionary:
	var r := Rng32.new((seed_v * 2654435761 + salt * 977 + 41) % 4294967296)
	var tall: Array = []
	var near: Array = []
	if r.next() < 0.88: tall.append(COMMON[int(r.next() * 2.0)])
	var v := r.next()
	if v < 0.38: tall.append(_pick(r, "coral", tall))
	elif v < 0.5: tall.append("weed_kelp")
	var small := ["star", "shell", "crab"]
	if r.next() < 0.7:
		near.append(_pick(r, String(small[int(r.next() * 3.0)]), near))
		if r.next() < 0.15 / 0.7: near.append(_pick(r, String(small[int(r.next() * 3.0)]), near))
	if tall.is_empty() and near.is_empty(): tall.append(COMMON[int(r.next() * 2.0)])
	var swim := _pick(r, "swim", []) if r.next() < 0.15 else ""
	return {tall = tall, near = near, swim = swim, clumps = 1, stalks = 4 + int(r.next() * 4.0)}

## whether the floor already has a coral standing (the sea lilies then keep away: one tall living thing is enough)
static func has_coral(reef: Dictionary) -> bool:
	return (reef.get("tall", []) as Array).any(func(k: String) -> bool: return String((MODELS.get(k, {}) as Dictionary).get("g", "")) == "coral")

static func _pick(r: Rng32, g: String, taken: Array) -> String:
	var ks := group(g).filter(func(k: String) -> bool: return not k in taken)
	return ks[int(r.next() * ks.size())]

## the card's accents of a reef: a model each ("sea:coral_red"), the swimmer ("swim:swim_mosasaurus")
static func accents(reef: Dictionary) -> Array:
	var out := []
	for k: String in (reef.get("tall", []) as Array) + (reef.get("near", []) as Array):
		out.append("sea:" + k)
	if String(reef.get("swim", "")) != "": out.append("sea:" + String(reef.swim))
	return out

static func gene_name(id: String) -> String:
	return label(id.trim_prefix("sea:"))

## the points it adds to a find's price: a swimmer most, a coral or a crab more than a weed
static func points(id: String) -> float:
	var g := String((MODELS.get(id.trim_prefix("sea:"), {}) as Dictionary).get("g", ""))
	return float({weed = 0.2, coral = 0.9, star = 0.8, shell = 0.8, crab = 1.0, swim = 2.2}.get(g, 0.5))

static func mesh(id: String) -> Mesh:
	if not _mesh.has(id):
		_mesh[id] = load(DIR + id + ".obj") as Mesh
	return _mesh[id]

static func mat(id: String) -> ShaderMaterial:
	if not _mat.has(id):
		var md: Dictionary = MODELS[id]
		var m := ShaderMaterial.new()
		m.shader = SWIM if String(md.g) == "swim" else SpecFungi.SHADER
		m.set_shader_parameter("tex_d", load(DIR + id + "_d.png"))
		m.set_shader_parameter("tex_n", load(DIR + id + "_n.png"))
		m.set_shader_parameter("gain", float(md.get("gain", 1.35)))
		m.set_shader_parameter("sat", float(md.get("sat", 1.15)))
		m.set_shader_parameter("rough", 0.45)
		m.set_shader_parameter("tint", md.get("tint", Color.WHITE))
		m.set_shader_parameter("sway", float(md.get("sway", 0.0)))
		# (solid things — shells, crabs, stars, stony corals, the swimmers — let no light through: lit from behind their
		# thin legs and rims glowed)
		if float(md.get("sway", 0.0)) == 0.0: m.set_shader_parameter("back_k", 0.15)
		# a swimmer's own way of swimming (sea_swim.gdshader)
		for k: String in (md.get("anim", {}) as Dictionary):
			m.set_shader_parameter(k, float(md.anim[k]))
		# (the big ones swim far off: the water between greys them into it)
		if md.get("far", false): m.set_shader_parameter("haze", 0.9)
		_mat[id] = m
	return _mat[id]

## the reef on a slab: rk the slab (its "geo"), rb its box, cands its top spots, occ the discs already taken (grown on);
## parent the node things go under. Returns the callouts: [id, node, a point of it (node's space)]
static func grow(parent: Node3D, rk: MeshInstance3D, rb: AABB, cands: Array, occ: Array, reef: Dictionary, span: float, seed_v: int) -> Array:
	var r := Rng32.new((seed_v * 1597334677 + 113) % 4294967296)
	var out := []
	var mid := rb.get_center()
	var behind := mid.z - rb.size.z * 0.05
	# (out to the slab's edge: the fossil fills its middle; the tall ones stand at its back rim)
	var wide := SpecTrilobite._top_spots(rk, rb, 0.5)
	if wide.size() > cands.size(): cands = wide
	var front := cands.filter(func(p: Vector3) -> bool: return p.z > mid.z - rb.size.z * 0.1)
	var all: Array = (reef.get("tall", []) as Array).map(func(k: String) -> Array: return [k, true])
	all += (reef.get("near", []) as Array).map(func(k: String) -> Array: return [k, false])
	for it: Array in all:
		var id: String = it[0]
		if not MODELS.has(id): continue
		var md: Dictionary = MODELS[id]
		var g := String(md.g)
		var sz := span * float(SIZE[g]) * float(md.k) * (0.85 + r.next() * 0.3)
		var m := mesh(id)
		if m == null: continue
		var bx := m.get_aabb()
		# its footprint: half its width (a stood thing is one unit tall, a lying one one unit long)
		var foot := maxf(bx.size.x, bx.size.z) * sz * (0.3 if it[1] else 0.42)
		var spot: Variant = null
		for shrink: float in [1.0, 0.8, 0.65, 0.5]:
			# (the weed, a spreading clump, keeps clear of the find altogether)
			spot = _room(cands if it[1] else (front if front.size() else cands), occ, foot * shrink, r, behind if it[1] else INF, 1.0 if g == "weed" else 0.78)
			if spot != null:
				sz *= shrink
				foot *= shrink
				break
		if spot == null:
			continue
		var at: Vector3 = spot
		var lying := g in ["star", "shell", "crab"]
		at.y = SpecTrilobite._ground(rk, at, foot * 0.8) - sz * (0.02 if lying else 0.04)
		var yaw := r.next() * TAU
		# (a lying thing's box middle is its origin: down onto the rock by its half height)
		if lying: at.y += -bx.position.y * sz * 0.92
		var mi := MeshInstance3D.new()
		mi.mesh = m
		mi.material_override = mat(id)
		parent.add_child(mi)
		# (a tall thing leans back, away from the viewer, as the sea lilies do: the slab is held up to the eye, and
		# upright it would stand over the find in the picture)
		var back := Basis(Vector3.RIGHT, -(0.35 + r.next() * 0.25)) if it[1] else Basis.IDENTITY
		mi.transform = Transform3D(back * Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3.ONE * sz), at)
		if float(md.get("sway", 0.0)) == 0.0: mi.set_meta("sea_light", true)
		occ.append([Vector2(at.x, at.z), foot])
		out.append(["sea:" + id, mi, Vector3(0, bx.end.y * 0.7, 0) if not lying else Vector3(0, bx.end.y, 0)])
		# the common weed grows in clumps: long and short stalks of both kinds round the first, and another clump
		# along the slab's rim
		if id in COMMON:
			# (the stalks root in from the rim: on the rim itself they hung off the slab's edge)
			var inner := SpecTrilobite._top_spots(rk, rb, 0.42)
			for c in int(reef.get("clumps", 1)):
				var ctr := at
				if c > 0:
					var far: Variant = _room(cands, occ, foot * 0.6, r, INF, 1.0)
					if far == null: break
					ctr = far
				for k in int(reef.get("stalks", 5)) - (1 if c == 0 else 0):
					var near_c := inner.filter(func(p: Vector3) -> bool: return Vector2(p.x - ctr.x, p.z - ctr.z).length() < span * 0.16)
					var sp: Variant = _room(near_c, occ, span * 0.05, r, INF, 1.0)
					if sp == null: continue
					var sid: String = COMMON[int(r.next() * 2.0)]
					var ssz := span * float(SIZE.weed) * float((MODELS[sid] as Dictionary).k) * (0.45 + r.next() * 0.6)
					var sa: Vector3 = sp
					sa.y = SpecTrilobite._ground(rk, sa, span * 0.02) - ssz * 0.04
					var st := MeshInstance3D.new()
					st.mesh = mesh(sid)
					st.material_override = mat(sid)
					parent.add_child(st)
					# (each leans a little its own way, as weed does in a current)
					st.transform = Transform3D(Basis(Vector3.RIGHT, -(0.3 + r.next() * 0.35)) * Basis(Vector3.BACK, (r.next() - 0.5) * 0.4) * Basis(Vector3.UP, r.next() * TAU) * Basis.from_scale(Vector3.ONE * ssz), sa)
	var sw := String(reef.get("swim", ""))
	if sw != "" and MODELS.has(sw):
		var sn := Swim.new()
		parent.add_child(sn)
		var body := MeshInstance3D.new()
		body.mesh = mesh(sw)
		body.material_override = mat(sw)
		body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sn.add_child(body)
		sn.body = body
		sn.sc = span * float(SIZE.swim) * float((MODELS[sw] as Dictionary).k)
		sn.centre = Vector3(mid.x, rb.end.y, mid.z)
		sn.radius = span * 0.5
		sn.height = span * 0.38
		sn.a = r.next() * TAU
		sn.dir = 1.0 if r.next() < 0.5 else -1.0
		# a sea reptile, a shark: many metres long, it could never circle a stone a hand across — it passes far
		# behind the find instead, huge and dim in the water, out past the card's edges, now this way, now back
		if (MODELS[sw] as Dictionary).get("far", false):
			sn.far = true
			sn.sc = span * 4.3 * float((MODELS[sw] as Dictionary).k)
			sn.radius = span * 4.6
			sn.height = span * 0.18
			sn.depth = span * 3.9
			sn.a = 0.15 + r.next() * 0.5
		# (its path is in the find's own space — the top of what it grows under — but its turn is the world's: the find
		# turned in the hand, it keeps swimming its way; a trilobite's slab tipped up to the eye does not tip it either)
		var top: Node3D = parent
		while top.get_parent() is Node3D: top = top.get_parent() as Node3D
		sn.frame = top
		sn.ph = r.next()
		sn.glide = float(((MODELS[sw] as Dictionary).get("anim", {}) as Dictionary).get("glide", 0.5))
		(body.material_override as ShaderMaterial).set_shader_parameter("phase", sn.ph)
		sn._process(0.0)
		# (no unseen box round its loop, as the hunter has: the studio would frame the loop and the find would shrink;
		# its loop is kept tight round the slab instead, a fin now and then past the card's edge)
		out.append(["sea:" + sw, sn, Vector3.ZERO])
	return out

## a spot from cands for a thing of footprint r, clear of what is there (occ: [centre (x, z), radius]) — the discs
## taken are generous (a trilobite's covers its spines and the slab round it), so life may tuck in under their rims:
## only its own middle must keep clear, by most of a disc's radius. behind: only spots behind z (tall things)
static func _room(cands: Array, occ: Array, r: float, rng: Rng32, behind := INF, keep := 0.78) -> Variant:
	if cands.is_empty():
		return null
	for tries in 80:
		var p: Vector3 = cands[int(rng.next() * cands.size())]
		var ok := p.z < behind
		for o: Array in occ:
			if Vector2(p.x, p.z).distance_to(o[0] as Vector2) < r * 0.6 + float(o[1]) * keep:
				ok = false
				break
		if ok:
			return p
	return null

## a big swimmer of the old seas: round and round the find on a lazy loop, rising and sinking, banking into its turns;
## its body waves as it goes (the shader's swim)
class Swim extends Node3D:
	var body: Node3D
	var sc := 1.0
	var centre := Vector3.ZERO
	var radius := 0.5
	var height := 0.3
	var a := 0.0
	var dir := 1.0
	var bank := 0.0
	var tan := Vector3.RIGHT
	var far := false
	var frame: Node3D
	var depth := 1.0
	var ph := 0.0
	var glide := 0.5
	const PASS := 30.0   # (seconds across, far off, at an even pace)
	const REST := 7.0    # (out of sight before it comes back the other way)

	## how hard it swims now: a few strong beats, then a glide — the same as the shader's tail (sea_swim.gdshader)
	func burst() -> float:
		var t := Time.get_ticks_msec() * 0.001
		return lerpf(1.0 - glide, 1.0, smoothstep(-0.3, 0.7, sin(t * 0.42 + ph * TAU)))

	func at(t: float) -> Vector3:
		return Vector3(cos(t) * radius, height + sin(t * 2.0 + 0.6) * height * 0.25, sin(t) * radius * 0.7 * dir)

	func _process(dt: float) -> void:
		var b := burst()
		var off: Vector3
		var bs: Basis
		if far:
			# far off: across behind the find, quicker on its beats, slower gliding; rising and sinking, nosing about;
			# then out of sight a while, and back the other way
			a += dt / PASS * lerpf(0.55, 1.3, b)
			if a > 1.0 + REST / PASS:
				a = 0.0
				dir = -dir
			visible = a <= 1.0
			var s := clampf(a, 0.0, 1.0)
			var rise := sin(s * TAU * 0.7 + ph * 5.0)
			off = Vector3(lerpf(-radius, radius, s) * dir, height + rise * height * 0.5, -depth)
			var yaw := sin(s * TAU * 1.6 + ph * 3.0) * 0.12
			bs = Basis(Vector3.UP, (0.0 if dir > 0.0 else PI) + yaw) * Basis(Vector3.BACK, cos(s * TAU * 0.7 + ph * 5.0) * 0.12)
		else:
			a += dt * TAU / 21.0 * lerpf(0.6, 1.25, b)
			var p := at(a)
			var nt := (at(a + 0.02) - p).normalized()
			var turn := tan.cross(nt).y / maxf(dt, 0.001) if dt > 0.0 else 0.0
			bank = lerpf(bank, clampf(-turn * 0.25, -0.4, 0.4), minf(1.0, dt * 2.0))
			tan = nt
			off = p
			# (its head is the model's +x: turned to the way it goes)
			bs = Basis.looking_at(nt, Vector3.UP) * Basis(Vector3.UP, PI / 2) * Basis(Vector3.RIGHT, bank)
		if frame and is_instance_valid(frame) and is_inside_tree() and frame.is_inside_tree():
			# the find's place and size, but the world's turn
			var fx := frame.global_transform
			var k := fx.basis.get_scale().x
			global_transform = Transform3D(bs * Basis.from_scale(Vector3.ONE * sc * k), fx * centre + off * k)
		else:
			transform = Transform3D(bs * Basis.from_scale(Vector3.ONE * sc), centre + off)
