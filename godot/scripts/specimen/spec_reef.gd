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
	# the swimmers. A small fish (no `far`) loops round the find and turns with it in the hand; the giants (`far`) pass far
	# behind it, the world's way whatever the find does. anim: the shader's (sea_swim.gdshader) and two of Swim's own —
	# `go_f` the beats a second that push it on (the tail's swim_f unless given: a plesiosaur's are its flippers') and
	# `stride` the body lengths it makes on each beat. A big animal beats slowly: every one its own pace
	swim_coelacanth = {g = "swim", n = "coelacanth", k = 0.55, anim = {swim = 0.07, swim_f = 0.8, swim_k = 0.8, swim_from = 0.15, glide = 0.35, stride = 0.5, flip = 0.3, flip_w = 0.09, flip_x0 = -0.25, flip_x1 = 0.2, flip_mid = 0.0, flip_f = 0.9, eye_x = 0.417, eye_y = 0.226, eye_r = 0.013}},
	swim_cretoxyrhina = {g = "swim", n = "ginsu shark", k = 1.0, far = true, anim = {ram = 1.0, swim = 0.085, swim_f = 0.55, swim_k = 0.75, swim_from = 0.2, glide = 0.35, stride = 0.6, flip = 0.04, flip_w = 0.1, flip_x0 = 0.0, flip_x1 = 0.25, flip_mid = -1.0, flip_f = 0.3, jaw = 0.06, jaw_x = 0.325, jaw_y = 0.1106, jaw_s = 0.0, jaw_shut = 0.4, eye_x = 0.424, eye_y = 0.137, eye_r = 0.009}},
	swim_octopus = {g = "swim", n = "giant octopus", k = 0.6, far = true, anim = {swim = 0.0, swim_f = 0.33, stride = 0.75, jet = 0.3}},
	swim_mosasaurus = {g = "swim", n = "mosasaur", k = 1.1, far = true, anim = {ram = 1.0, near = 2.5, swim = 0.1, swim_f = 0.38, swim_k = 0.95, swim_from = 0.3, glide = 0.4, stride = 0.55, flip = 0.12, flip_w = 0.06, flip_x0 = -0.15, flip_x1 = 0.35, flip_mid = 0.1, flip_f = 0.38, jaw = 0.42, jaw_x = 0.376, jaw_y = 0.064, jaw_s = 0.0, jaw_shut = 0.025, jaw_fan = 0.004, eye_x = 0.406, eye_y = 0.083, eye_r = 0.006}},
	swim_ophthalmosaurus = {g = "swim", n = "ichthyosaur", k = 1.0, far = true, anim = {ram = 2.0, swim = 0.075, swim_f = 0.65, swim_k = 0.5, swim_from = 0.0, glide = 0.3, stride = 0.6, flip = 0.08, flip_w = 0.1, flip_x0 = 0.05, flip_x1 = 0.3, flip_mid = -1.0, flip_f = 0.4, jaw = 0.04, jaw_x = 0.282, jaw_y = 0.1154, jaw_s = 0.09, jaw_shut = 0.32, eye_x = 0.318, eye_y = 0.157, eye_r = 0.013}},
	swim_styxosaurus = {g = "swim", n = "plesiosaur", k = 1.15, far = true, anim = {swim = 0.01, swim_f = 0.4, swim_k = 1.0, swim_from = -0.2, glide = 0.3, go_f = 0.32, stride = 0.6, visit = 1.0, flip = 0.7, flip_w = 0.07, flip_x0 = -0.45, flip_x1 = -0.05, flip_mid = -0.25, flip_f = 0.32, neck = 0.11, neck_from = 0.0, jaw = 0.5, jaw_x = 0.4533, jaw_y = 0.1637, jaw_s = -0.1, jaw_shut = 0.04, jaw_fan = 0.004, jaw_ramp = 0.006, eye_x = 0.474, eye_y = 0.174, eye_r = 0.005}},
	swim_tylosaurus = {g = "swim", n = "Tylosaurus", k = 1.1, far = true, anim = {ram = 1.0, near = 2.5, swim = 0.11, swim_f = 0.32, swim_k = 1.0, swim_from = 0.3, glide = 0.45, stride = 0.55, flip = 0.1, flip_w = 0.1, flip_x0 = -0.2, flip_x1 = 0.35, flip_mid = 0.1, flip_f = 0.32, jaw = 0.42, jaw_x = 0.353, jaw_y = 0.107, jaw_s = -0.065, jaw_shut = 0.025, jaw_fan = 0.004, eye_x = 0.408, eye_y = 0.104, eye_r = 0.007}},
	swim_dallasaurus = {g = "swim", n = "Dallasaurus", k = 0.8, far = true, anim = {ram = 1.0, near = 2.5, swim = 0.1, swim_f = 0.6, swim_k = 1.1, swim_from = 0.35, glide = 0.5, stride = 0.5, flip = 0.15, flip_w = 0.065, flip_x0 = 0.05, flip_x1 = 0.3, flip_mid = 0.2, flip_f = 0.6, jaw = 0.35, jaw_x = 0.393, jaw_y = 0.0743, jaw_s = 0.05, jaw_shut = 0.1, eye_x = 0.452, eye_y = 0.094, eye_r = 0.006}},
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
		var an: Dictionary = md.get("anim", {})
		for k: String in an:
			if not k.begins_with("eye_") and k != "stride" and k != "go_f" and k != "visit": m.set_shader_parameter(k, float(an[k]))
		if an.has("eye_x"):
			m.set_shader_parameter("eye", Vector2(float(an.eye_x), float(an.eye_y)))
			m.set_shader_parameter("eye_r", float(an.eye_r))
		# (the big ones swim far off: the water between greys them into it, the more the further — but they keep their
		# light and shade, and the surface's light wanders over their backs)
		if md.get("far", false):
			m.set_shader_parameter("haze", 0.9)
			m.set_shader_parameter("haze_min", 0.4)
			m.set_shader_parameter("haze_d0", Swim.CAM + Swim.DEPTH * 0.7)
			m.set_shader_parameter("haze_d1", Swim.CAM + Swim.DEPTH * 2.4)
			m.set_shader_parameter("caust", 0.5)
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
		var md: Dictionary = MODELS[sw]
		var an: Dictionary = md.get("anim", {})
		var sn := Swim.new()
		parent.add_child(sn)
		var body := MeshInstance3D.new()
		body.mesh = mesh(sw)
		# (its own copy: its beat, and a far one's fading in and out of the deep)
		var bm := SpecUtil.mat_copy(mat(sw))
		body.material_override = bm
		body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sn.add_child(body)
		sn.body = body
		sn.mat = bm
		sn.sc = span * float(SIZE.swim) * float(md.k)
		sn.centre = Vector3(mid.x, rb.end.y, mid.z)
		sn.radius = span * 0.5
		sn.height = span * 0.3
		sn.a = r.next() * TAU
		sn.dir = 1.0 if r.next() < 0.5 else -1.0
		sn.ph = r.next()
		sn.glide = float(an.get("glide", 0.5))
		sn.beat = float(an.get("go_f", an.get("swim_f", 0.5)))
		sn.stride = float(an.get("stride", 0.55))
		sn.jet = float(an.get("jet", 0.0)) > 0.0
		sn.visits = an.has("visit")
		# (now and then it comes straight at the eye and strikes the card's glass: 1 rams it — the glass cracks,
		# GlassCrack; 2 only pokes it with its snout — the glass mists. Swim's pass 7)
		sn.rams = int(an.get("ram", 0.0))
		sn.near_k = float(an.get("near", 1.9)) if sn.rams == 1 else 1.0
		sn.swim0 = float(an.get("swim", 0.05))
		sn.tail_f0 = float(an.get("swim_f", 0.5))
		sn.nose = Vector2(0.5, float(an.get("eye_y", 0.11)) + 0.01)
		sn.seed_v = seed_v
		# a sea reptile, a shark: many metres long, it could never circle a stone a hand across — it passes far
		# behind the find instead, huge and dim in the water, out past the card's edges: the world's way, whatever
		# the find does in the hand (top_level: not a jot of the find's turning or rocking reaches it)
		var far: bool = md.get("far", false)
		if far:
			sn.far = true
			sn.top_level = true
			sn.sc = Swim.LEN * float(md.k)
			sn.first_pass(r.next())
		bm.set_shader_parameter("phase", sn.ph)
		sn._process(0.0)
		# (no unseen box round its loop, as the hunter has: the studio would frame the loop and the find would shrink;
		# its loop is kept tight round the slab instead, a fin now and then past the card's edge)
		# (the callout: the fish itself; a far one — the water over the find, where it passes behind)
		if far: out.append(["sea:" + sw, parent, sn.centre + Vector3(0, span * 0.45, -span * 0.2)])
		else: out.append(["sea:" + sw, sn, Vector3.ZERO])
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

## a swimmer of the old seas, alive by the shader's swim (sea_swim.gdshader) and moved on here by the same beat: so far
## for every beat of its tail (its length x stride x beats a second), quicker on its strong beats, coasting between —
## each at its own pace.
##  - a small fish loops round the find, rising and sinking, banking into its turns, in the find's own frame: turned in
##    the hand, it turns with it
##  - a giant (far) passes far behind, in the world's frame (top_level): a pass at a time, each another way — across,
##    corner to corner, down from above or up from below, out of the deep towards the eye and off past an edge, off
##    into the deep, a wide turn behind the find — then a rest out of sight
class Swim extends Node3D:
	const CAM := 6.6      # (the studio's camera: so far before the find, SpecStudio)
	const FOV := 0.249    # (the tangent of half its angle)
	const DEPTH := 14.0   # (a far one's usual distance behind the find, in the world's units: a seated find is ~2.3 across)
	const LEN := 9.2      # (a far one's length there)
	## (tests: `-- swim_pass=N` — every pass of a far one this way: 0 across, 1 corner to corner, 2 down or up, 3 out of
	## the deep, 4 into it, 5 a wide turn, 6 a plesiosaur's visit, 7 straight at the eye and into the glass)
	static var test_kind := -2
	var body: Node3D
	var mat: ShaderMaterial
	var sc := 1.0
	var centre := Vector3.ZERO
	var radius := 0.5
	var height := 0.3
	var a := 0.0
	var dir := 1.0
	var bank := 0.0
	var tan := Vector3.RIGHT
	var far := false
	var ph := 0.0
	var glide := 0.5
	var beat := 0.5
	var stride := 0.55
	var jet := false
	var seed_v := 0
	var vel := -1.0
	## (a small fish: the find's root, what the hand turns)
	var home: Node3D
	## a far one's pass: a curve from pa by pc to pb, s along it; `deep`: it comes out of the deep (1) or goes off into it (-1)
	var pa := Vector3.ZERO
	var pb := Vector3.ZERO
	var pc := Vector3.ZERO
	var s := 0.0
	var rest := 0.0
	var passes := 0
	var deep := 0
	var kind := 0
	## a visit (a plesiosaur: `visit` in its anim): it comes in behind the find and slows, its long neck curving out to
	## the eye till its head is by the find; looks it over, draws back, strikes at it — bubbles, the find jolts — chews,
	## and goes on its way. stage: 0 coming, 1 at the find (tv seconds), 2 leaving
	var visits := false
	var stage := 0
	var tv := 0.0
	var hdg := Vector3.RIGHT
	var stop := Vector3.ZERO
	var snapped := false
	var jolt := 0.0
	var jolt_off := Vector3.ZERO
	const HEAD := Vector2(0.5, 0.16)     # (the snout's tip, the model's units)
	const NECK := 0.4                    # (how far aside the neck carries the head, the model's units)
	## (where it bites, the world's units: before the find's upper half, past its middle — the neck lies across over the
	## find; behind a tall slab the head was hidden)
	var bite := Vector3(0.35, 0.75, 0.9)
	## a ram (`ram` in its anim; pass 7): out of the deep straight at the eye, faster and faster, jaws opening — and into
	## the card's glass (glass_hit: SpecView cracks it there and shakes); it reels back, shakes its head, turns away
	## into the deep. A poke (rams 2): it comes up slowly, touches the glass with its snout, looks, and goes.
	## The glass is GLASS before the find. At the glass it is near_k its far size (a rammer near twice, a sea lizard two and
	## a half times — `near` in its anim: a monster, its head more than the card holds; a poker about its own). Near the
	## eye it blinks now and then, and shuts its eyes on the blow. The water it drives before it sweeps the find off as it
	## comes — aside, out of its way, rolling over — and the find drifts home gently when it has gone (wash_t).
	## Struck, the beast is no board: its body whips (the shader's `curve`), it rolls, sinks back, and comes round in a
	## long bend, the body curved into the turn, the tail driving hard. stage: 0 coming, 1 at the glass, 2 leaving.
	## sea_call: what it sounds like now ("rush", "roar", "song" — SpecView plays them while the card shows)
	signal glass_hit(at: Vector3, soft: bool)
	const GLASS := 4.0
	var near_k := 0.9
	var wash_t := -1.0
	var wash_base := Transform3D.IDENTITY
	var swim0 := 0.05
	var curve := 0.0
	var roared := false
	## the tail's own beats a second, what it beats at now, and the phase that has run it on (the shader's swim_ph).
	## Charging the glass and making off from it, a giant's slow tail looked lifeless: it beats quick then — never
	## under QUICK a second, half as fast again in the rush (the Dallasaurus's own quick beat read best)
	const QUICK := 0.62
	var tail_f0 := 0.5
	var tail_f := -1.0
	var tail_ph := 0.0
	var sing_in := 6.0
	signal sea_call(what: String)
	var rams := 0
	var nose := Vector2(0.5, 0.12)
	var face := Vector3.BACK
	var hit_at := Vector3.ZERO

	## how hard it pushes on now, about 1 on the whole: a tail's strong beats and its glides, an octopus's squeeze and
	## its coasting — the same as the shader's (burst, squeeze)
	func go() -> float:
		var t := Time.get_ticks_msec() * 0.001
		if jet:
			var c := fposmod(t * beat + ph, 1.0)
			return 0.45 + 1.5 * smoothstep(0.0, 0.14, c) * (1.0 - smoothstep(0.22, 0.85, c))
		var b := lerpf(1.0 - glide, 1.0, smoothstep(-0.3, 0.7, sin(t * 0.42 + ph * TAU)))
		return b / (1.0 - glide * 0.5)

	func at(t: float) -> Vector3:
		return Vector3(cos(t) * radius, sin(t * 2.0 + 0.6) * height * 0.3, sin(t) * radius * 0.7 * dir)

	## the first pass: across, already part of the way (a still picture of the find has it in)
	func first_pass(u: float) -> void:
		new_pass(0, 0.3 + u * 0.3)

	## the next pass, each another way. All in the world's units, the find at the origin, the eye at +z
	func new_pass(k := -1, from := 0.0) -> void:
		passes += 1
		var r := Rng32.new((seed_v * 40503 + passes * 7919 + 17) % 4294967296)
		var pick := [0, 0, 1, 1, 2, 2, 3, 4, 5]
		if visits: pick.append_array([6, 6, 6])
		if rams > 0: pick.append_array([7, 7])
		var k2: int = pick[int(r.next() * pick.size()) % pick.size()]
		# (not the same way twice running)
		if k2 == kind: k2 = pick[(int(r.next() * pick.size()) + 3) % pick.size()]
		kind = k if k >= 0 else k2
		if test_kind == -2:
			test_kind = -1
			for arg in OS.get_cmdline_user_args():
				if arg.begins_with("swim_pass="): test_kind = int(arg.get_slice("=", 1))
		if test_kind >= 0: kind = test_kind
		if kind == 7 and rams == 0: kind = 3
		dir = 1.0 if r.next() < 0.5 else -1.0
		var v := 1.0 if r.next() < 0.5 else -1.0
		var d := DEPTH * lerpf(0.85, 1.25, r.next())
		# (what the eye sees that far off: half the card's width, and its height — a card is taller than wide; past
		# them by half its own length, it is out of sight)
		var hw := FOV * (CAM + d)
		var x0 := hw + sc * 0.56
		var y0 := hw * 1.2 + sc * 0.52
		deep = 0
		stage = 0
		roared = false
		curve = 0.0
		if mat:
			mat.set_shader_parameter("curve", 0.0)
			mat.set_shader_parameter("swim", swim0)
		match kind:
			7:
				# straight at the eye, a little down from above (its body clears the find's top), into the glass
				hdg = Vector3(0.1 * dir, -0.28, 1.0).normalized()
				hit_at = Vector3(-0.08 * dir, 0.42, GLASS)
				var hb := Basis.looking_at(hdg, Vector3.UP)
				stop = hit_at - (hdg * nose.x + hb * Vector3.UP * nose.y) * sc * near_k
				pa = Vector3(-dir * hw * 0.5, 4.5, -DEPTH * 1.7)
				pc = stop - hdg * 12.0
				pb = stop
				deep = 1
			6:
				# a visit: across behind the find, close, to where the neck's reach puts the head by it
				hdg = Vector3(0.97 * dir, 0.0, 0.24).normalized()
				bite = Vector3(0.35 * dir, 0.75, 0.9)
				var peer := bite - hdg * 0.45 + Vector3(0, 0.45, 0)
				stop = peer - (hdg * HEAD.x + Vector3.UP * HEAD.y + _aside() * NECK) * sc
				pa = Vector3(-(x0 + 3.0) * dir, 1.0, -DEPTH * 0.9)
				pc = stop - hdg * 7.0
				pb = stop
			0:
				# across, on a slant: nearer at one end, further at the other (seen three quarters on)
				var sl := d * lerpf(-0.4, 0.4, r.next())
				pa = Vector3(-x0 * dir, lerpf(-0.8, 2.2, r.next()), -d + sl)
				pb = Vector3(x0 * dir, lerpf(-0.8, 2.2, r.next()), -d - sl)
				pc = (pa + pb) * 0.5 + Vector3(0, lerpf(-1.5, 1.5, r.next()), 0)
			1:
				# corner to corner
				pa = Vector3(-x0 * dir * 0.8, -y0 * v * 0.75, -d)
				pb = Vector3(x0 * dir * 0.8, y0 * v * 0.75, -d * lerpf(0.85, 1.2, r.next()))
				pc = (pa + pb) * 0.5 + Vector3(dir * lerpf(-2.5, 2.5, r.next()), 0, 0)
			2:
				# down from above, or up from below
				var xa := hw * lerpf(-0.35, 0.35, r.next())
				pa = Vector3(xa - dir * hw * 0.8, y0 * v, -d)
				pb = Vector3(xa + dir * hw * 0.8, -y0 * v, -d * lerpf(0.9, 1.15, r.next()))
				pc = (pa + pb) * 0.5 + Vector3(dir * hw * lerpf(-0.5, 0.5, r.next()), 0, 0)
			3, 4:
				# out of the deep, towards the eye and off past an edge — or the same the other way, off into the deep
				var far_p := Vector3(-dir * hw * lerpf(0.2, 0.9, r.next()), lerpf(0.5, 5.0, r.next()), -DEPTH * 2.6)
				var out_p := Vector3(x0 * dir, lerpf(-0.5, 2.0, r.next()), -d * 0.8)
				pc = Vector3(-dir * hw * 0.2, lerpf(-0.5, 2.0, r.next()), -d * 0.95)
				if kind == 3:
					pa = far_p
					pb = out_p
					deep = 1
				else:
					pa = out_p
					pb = far_p
					deep = -1
			_:
				# a wide turn behind the find: in from one side, round, and off the same side further away
				var d2 := d * 1.9
				pa = Vector3(x0 * dir, lerpf(-0.5, 2.0, r.next()), -d * 0.85)
				pb = Vector3((FOV * (CAM + d2) + sc * 0.56) * dir, lerpf(0.0, 3.0, r.next()), -d2)
				pc = Vector3(-x0 * dir, lerpf(-0.5, 2.5, r.next()), -d * 1.35)
		s = from
		rest = 0.0
		tan = Vector3.ZERO

	## the find's root: what the hand turns (it is marked "sea"); before the find is whole, the top of what there is
	func _home() -> Node3D:
		var n := get_parent() as Node3D
		var top := n
		while n:
			if n.has_meta("sea"):
				return n
			top = n
			n = n.get_parent() as Node3D
		return top if not is_inside_tree() else get_parent() as Node3D

	## the model's +z in the world, as it heads hdg (the side its neck bends to: the eye's)
	func _aside() -> Vector3:
		return (Basis.looking_at(hdg, Vector3.UP) * Basis(Vector3.UP, PI / 2)) * Vector3.BACK

	## at the find: the head's reach and the jaws by the clock
	func _visit(dt: float) -> void:
		tv += dt
		var side := Vector3(0, 0, NECK)
		var rc := Vector3.ZERO
		var jw := 0.0
		var hit := Vector3(0.45, -0.45, 0.0) / sc
		if tv < 1.4:
			# looks it over
			rc = Vector3(0, -0.012, 0.012 * sin(tv * 3.0)) * smoothstep(0.0, 0.8, tv)
		elif tv < 1.85:
			# draws back, the jaws opening
			var u := smoothstep(0.0, 1.0, (tv - 1.4) / 0.45)
			rc = Vector3(0, -0.012, 0).lerp(Vector3(-0.03, 0.02, 0.0), u)
			jw = u
		elif tv < 1.97:
			# strikes
			var u2 := (tv - 1.85) / 0.12
			rc = Vector3(-0.03, 0.02, 0.0).lerp(hit, u2 * u2)
			jw = 1.0
		else:
			if not snapped:
				snapped = true
				_snap()
			# and lifts its head again, chewing
			var u3 := smoothstep(0.0, 1.0, (tv - 1.97) / 1.7)
			rc = hit.lerp(Vector3(0, 0.012, 0), u3)
			if tv > 2.15: jw = 0.3 * maxf(0.0, sin((tv - 2.15) * 11.0)) * (1.0 - u3)
		if mat:
			mat.set_shader_parameter("reach", side + rc)
			mat.set_shader_parameter("jaw_force", jw)
		transform = Transform3D(Basis.looking_at(hdg, Vector3.UP) * Basis(Vector3.UP, PI / 2) * Basis.from_scale(Vector3.ONE * sc), stop + Vector3(0, sin(tv * 1.3) * 0.05, 0))
		if tv > 3.9:
			# on its way: off past the edge, deeper, its neck straightening as it goes
			stage = 2
			pa = stop
			pc = stop + hdg * 6.0
			pb = Vector3((FOV * (CAM + DEPTH) + sc * 0.56) * dir, 2.5, -DEPTH)
			s = 0.0
			vel = 0.0
			tan = hdg
			if mat: mat.set_shader_parameter("jaw_force", -1.0)

	## at the glass: thrown back by the blow, shaking its head, the jaws closing (a poke: it hangs there, nodding, looking
	## in) — then off, turning away into the deep
	func _ram(dt: float) -> void:
		tv += dt
		var b := Basis.looking_at(hdg, Vector3.UP)
		var back := 0.0
		var roll := 0.0
		var sink := 0.0
		if rams == 1:
			# thrown back and still drifting, the body whipping from the blow, rolling, sinking a little; the jaws close
			back = 1.6 * (1.0 - exp(-tv * 5.0)) + 0.9 * tv
			curve = 0.55 * sin(tv * 8.0) * exp(-tv * 2.2) * smoothstep(0.0, 0.1, tv)
			roll = 0.32 * sin(tv * 4.2) * exp(-tv * 1.3)
			sink = 0.5 * smoothstep(0.1, 1.2, tv)
			if mat:
				mat.set_shader_parameter("jaw_force", maxf(0.0, 1.0 - tv * 1.6))
				mat.set_shader_parameter("swim", swim0 * lerpf(0.3, 1.2, smoothstep(0.5, 1.2, tv)))
		else:
			back = 0.12 * smoothstep(0.0, 0.4, tv) + 0.05 * sin(tv * 2.4)
			curve = 0.18 * sin(tv * 1.9) * smoothstep(0.3, 1.0, tv) * (1.0 - smoothstep(2.2, 2.8, tv))
			roll = 0.08 * sin(tv * 1.3)
		if mat: mat.set_shader_parameter("curve", curve)
		var at_p := stop - hdg * back + Vector3.DOWN * sink
		transform = Transform3D(b * Basis(Vector3.UP, PI / 2) * Basis(Vector3.RIGHT, roll) * Basis.from_scale(Vector3.ONE * sc * near_k), at_p)
		if tv > (1.2 if rams == 1 else 2.8):
			# off: a long bend aside and away into the deep, gathering way from rest
			stage = 2
			pa = at_p
			pc = at_p + Vector3(dir * sc * near_k * 0.55, -0.4, -1.0)
			pb = Vector3(dir * FOV * (CAM + DEPTH) * 1.3, 3.0, -DEPTH * 2.0)
			deep = -1
			s = 0.0
			vel = 0.0
			bank = roll
			tan = hdg
			if mat: mat.set_shader_parameter("jaw_force", -1.0)

	## the bite: a burst of bubbles at the find, and the find jolts
	func _snap() -> void:
		jolt = 1.0
		var bb := Burst.new()
		bb.top_level = true
		add_child(bb)
		bb.global_transform = Transform3D(Basis.IDENTITY, bite + Vector3(0, -0.2, 0.1))

	func _process(dt: float) -> void:
		if jolt > 0.0 or jolt_off != Vector3.ZERO:
			jolt = maxf(0.0, jolt - dt * 1.5)
			if home == null or not is_instance_valid(home): home = _home()
			var jo := Vector3(0.02, -0.07, 0) * jolt * jolt * cos((1.0 - jolt) * 20.0)
			if home:
				home.position += jo - jolt_off
				jolt_off = jo
		if wash_t >= 0.0:
			# the water driven before it: the find is swept off aside, out of its way, rolling right over as it goes,
			# hangs there while the beast is at the glass, and drifts home gently, coming upright as it arrives
			if home == null or not is_instance_valid(home): home = _home()
			if home and home != self and home.get_parent() is Node3D:
				if wash_t == 0.0: wash_base = home.transform
				wash_t += maxf(dt, 0.0001)
				var soft_k := 1.0 if rams == 1 else 0.1
				var e := smoothstep(0.0, 0.45, wash_t) * (1.0 - smoothstep(1.5, 5.4, wash_t))
				var wo := (Vector3(-dir * 2.7, -0.55, -0.4) * e + Vector3(0.1 * sin(wash_t * 4.0), 0.08 * sin(wash_t * 5.3), 0) * e) * soft_k
				var roll := TAU * smoothstep(0.0, 5.4, wash_t) * (1.0 if rams == 1 else 0.0)
				var pb0 := (home.get_parent() as Node3D).global_transform.basis.orthonormalized().inverse()
				var spin := Basis((pb0 * Vector3(0.25, 0.2, 1.0)).normalized(), -dir * roll) * Basis((pb0 * Vector3.RIGHT).normalized(), 0.5 * sin(PI * e) * soft_k)
				home.transform = Transform3D(Basis.IDENTITY, pb0 * wo) * Transform3D(spin, Vector3.ZERO) * wash_base
				if wash_t > 5.7:
					wash_t = -1.0
					home.transform = wash_base
			else:
				wash_t = -1.0
		# its voice now and then, as it passes
		if far and visible and rest <= 0.0:
			sing_in -= dt
			if sing_in <= 0.0:
				sing_in = 11.0 + 9.0 * fposmod(ph * 3.7 + passes * 0.37, 1.0)
				if not (kind == 7 and stage < 2 and s > 0.4): sea_call.emit("song")
		if far and mat and rams > 0:
			var fq := maxf(tail_f0, QUICK)
			var f_to := tail_f0
			if kind == 7 and rest <= 0.0:
				if stage == 0: f_to = lerpf(tail_f0, fq * (1.45 if rams == 1 else 1.0), smoothstep(0.05, 0.5, s))
				elif stage == 1: f_to = fq * (0.7 if rams == 1 else 0.8)
				else: f_to = lerpf(fq * 1.35, tail_f0, smoothstep(0.35, 0.95, s))
			if tail_f < 0.0: tail_f = tail_f0
			tail_f = lerpf(tail_f, f_to, minf(1.0, dt * 3.0))
			tail_ph = fposmod(tail_ph + TAU * (tail_f - tail_f0) * dt, TAU)
			mat.set_shader_parameter("swim_ph", tail_ph)
			# near the eye it blinks, a quick one every second or so; on the blow its eyes shut a moment
			var bl := 0.0
			if kind == 7 and rest <= 0.0 and ((stage == 0 and s > 0.55) or stage == 1 or (stage == 2 and s < 0.45)):
				var c := fposmod(Time.get_ticks_msec() * 0.001 * 0.75 + ph, 1.0)
				bl = smoothstep(0.0, 0.04, c) * (1.0 - smoothstep(0.09, 0.16, c))
				if stage == 1 and rams == 1: bl = maxf(bl, 1.0 - smoothstep(0.2, 0.45, tv))
			mat.set_shader_parameter("blink_force", bl)
		var want := sc * stride * beat * go()
		# (a body's weight: it gathers way and loses it slowly)
		vel = want if vel < 0.0 else lerpf(vel, want, minf(1.0, dt * 1.5))
		if far:
			if rest > 0.0:
				rest -= dt
				if rest <= 0.0: new_pass()
				return
			if kind == 6 and stage == 1:
				_visit(dt)
				return
			if kind == 7 and stage == 1:
				_ram(dt)
				return
			var dp := (pc - pa) * (2.0 * (1.0 - s)) + (pb - pc) * (2.0 * s)
			# (a visit: it slows as it comes up to the find, the neck curving out; leaving, the neck straightens)
			var slow := 1.0
			if kind == 6 and mat:
				if stage == 0:
					slow = lerpf(1.0, 0.12, smoothstep(0.55, 1.0, s))
					mat.set_shader_parameter("reach", Vector3(0, 0, NECK) * smoothstep(0.45, 1.0, s))
				else:
					mat.set_shader_parameter("reach", Vector3(0, 0, NECK) * (1.0 - smoothstep(0.0, 0.35, s)))
			var size := sc
			if kind == 7:
				if stage == 0:
					# (the rush: it gathers speed all the way in; a poke comes up easily and slows at the glass)
					slow = lerpf(2.0, 8.0, smoothstep(0.1, 0.8, s)) if rams == 1 else lerpf(2.0, 3.5, smoothstep(0.1, 0.6, s)) * lerpf(1.0, 0.15, smoothstep(0.8, 1.0, s))
					if mat and rams == 1: mat.set_shader_parameter("jaw_force", smoothstep(0.8, 0.96, s))
					size = sc * lerpf(1.0, near_k, smoothstep(0.1, 1.0, s))
					if mat: mat.set_shader_parameter("swim", swim0 * lerpf(1.0, 1.8, smoothstep(0.1, 0.7, s)))
					# (the water before it reaches the find first: the find is swept off as it comes)
					if rams == 1 and wash_t < 0.0 and s > 0.72:
						wash_t = 0.0
						sea_call.emit("rush")
					if rams == 1 and not roared and s > 0.8:
						roared = true
						sea_call.emit("roar")
				else:
					size = sc * lerpf(near_k, 1.0, smoothstep(0.05, 0.9, s))
					slow = 1.8
					if mat: mat.set_shader_parameter("swim", swim0 * lerpf(2.2, 1.0, smoothstep(0.0, 0.7, s)))
			s += vel * slow * dt / maxf(0.01, dp.length())
			if s >= 1.0 and kind == 7 and stage == 0:
				stage = 1
				tv = 0.0
				face = hdg
				glass_hit.emit(hit_at, rams == 2)
				if wash_t < 0.0: wash_t = 0.0
				if rams == 1:
					var bb := Burst.new()
					bb.top_level = true
					add_child(bb)
					bb.global_transform = Transform3D(Basis.from_scale(Vector3.ONE * 1.6), Vector3(-dir * 0.5, 0.0, 2.0))
				_ram(0.0)
				return
			if s >= 1.0 and kind == 6 and stage == 0:
				stage = 1
				tv = 0.0
				snapped = false
				_visit(0.0)
				return
			if s >= 1.0:
				# out of sight a while, then another pass
				visible = false
				rest = 0.5 + 2.0 * fposmod(ph * 7.31 + passes * 0.618, 1.0)
				return
			visible = true
			var p := pa * ((1.0 - s) * (1.0 - s)) + pc * (2.0 * (1.0 - s) * s) + pb * (s * s)
			var nt := dp.normalized()
			if kind == 7 and stage == 2:
				# (from the glass it comes round slowly, a heavy body — and bends into its turn, the head leading)
				var was := face
				face = face.slerp(nt, minf(1.0, dt * lerpf(0.5, 1.8, smoothstep(0.0, 0.35, s)))).normalized()
				nt = face
				if dt > 0.0:
					curve = lerpf(curve, clampf(was.cross(face).y / dt * 0.55, -0.7, 0.7), minf(1.0, dt * 2.5))
					if mat: mat.set_shader_parameter("curve", curve)
			# (it banks into its turns)
			if dt > 0.0 and tan != Vector3.ZERO:
				bank = lerpf(bank, clampf(-tan.cross(nt).y / dt * 1.6, -0.55, 0.55), minf(1.0, dt * 1.5))
			tan = nt
			if mat:
				mat.set_shader_parameter("fade", smoothstep(0.0, 0.22, s) if deep > 0 else 1.0 - smoothstep(0.72, 0.98, s) if deep < 0 else 1.0)
			# (its head is the model's +x: turned to the way it goes)
			transform = Transform3D(Basis.looking_at(nt, Vector3.UP) * Basis(Vector3.UP, PI / 2) * Basis(Vector3.RIGHT, bank) * Basis.from_scale(Vector3.ONE * size), p)
			return
		# a small fish: its loop is level in the find's own frame, round and above the slab's top (a trilobite's slab is
		# tipped up to the eye: the loop is above its face, not through it). Its place is set in its parent's space —
		# nothing of it lags a frame behind the hand
		if home == null or not is_instance_valid(home) or not home.has_meta("sea"):
			home = _home()
		var par := get_parent() as Node3D
		var rel := Transform3D.IDENTITY
		if par and home and par != home: rel = SpecUtil.rel_xform(par, home)
		var up := (rel.basis * Vector3.UP).normalized()
		var mid := rel * centre + up * height * 0.9 + Vector3.UP * height * 0.6
		a += vel * dt / maxf(0.001, radius * 0.85)
		var q := at(a)
		var nq := (at(a + 0.02) - q).normalized()
		if dt > 0.0:
			bank = lerpf(bank, clampf(-tan.cross(nq).y / dt * 0.25, -0.4, 0.4), minf(1.0, dt * 2.0))
		tan = nq
		var k := rel.basis.get_scale().x
		transform = rel.affine_inverse() * Transform3D(Basis.looking_at(nq, Vector3.UP) * Basis(Vector3.UP, PI / 2) * Basis(Vector3.RIGHT, bank) * Basis.from_scale(Vector3.ONE * sc * k), mid + q)

## a burst of bubbles (a plesiosaur's bite): out and up from a point, each its own way, growing a little and gone
class Burst extends Node3D:
	var items: Array = []
	var t := 0.0
	func _ready() -> void:
		var bm := ShaderMaterial.new()
		bm.shader = SpecSea.BUBBLE
		bm.render_priority = 60
		var mesh := Geo.sphere(1.0, 10, 7).to_mesh()
		for k in 16:
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			mi.material_override = bm
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)
			var a := k * 2.399
			var u := fposmod(k * 0.618, 1.0)
			items.append([mi, Vector3(cos(a) * (0.25 + u * 0.5), 0.5 + u * 0.9, sin(a) * (0.25 + u * 0.5)), 0.025 + 0.05 * fposmod(k * 0.377, 1.0), u * 0.25])
		_process(0.0)
	func _process(dt: float) -> void:
		t += dt
		for it: Array in items:
			var mi: MeshInstance3D = it[0]
			var v: Vector3 = it[1]
			var tt := maxf(0.0, t - float(it[3]))
			# (thrown out, then only rising, wobbling)
			var p := Vector3(v.x, 0, v.z) * (1.0 - exp(-tt * 3.0)) * 0.6 + Vector3(sin(tt * 5.0 + v.x * 9.0) * 0.03, v.y * tt, 0)
			var k := smoothstep(0.0, 0.08, tt) * (1.0 - smoothstep(1.6, 2.4, tt))
			mi.visible = k > 0.0
			mi.transform = Transform3D(Basis.from_scale(Vector3.ONE * float(it[2]) * (0.7 + tt * 0.25) * k), p)
		if t > 2.8: queue_free()
