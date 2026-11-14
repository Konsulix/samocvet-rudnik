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
	shell_tun = {g = "shell", n = "giant tun", k = 1.0, gain = 0.85},
	shell_triton = {g = "shell", n = "knobbed triton", k = 1.15},
	shell_tridacna = {g = "shell", n = "giant clam", k = 1.05},
	shell_moon = {g = "shell", n = "moon scallop", k = 0.95},
	shell_noble = {g = "shell", n = "noble scallop", k = 0.95},
	shell_cone = {g = "shell", n = "marbled cone", k = 0.85},
	crab_lobster = {g = "crab", n = "fan lobster", k = 1.05},
	crab_hermit_b = {g = "crab", n = "hermit crab", k = 0.9},
	crab_hermit_c = {g = "crab", n = "Mediterranean hermit", k = 0.95},
	crab_fiddler = {g = "crab", n = "fiddler crab", k = 0.9},
	crab_frog = {g = "crab", n = "red frog crab", k = 0.95},
	crab_elbow = {g = "crab", n = "elbow crab", k = 1.0},
	crab_mantis = {g = "crab", n = "mantis shrimp", k = 1.1},
	crab_isopod = {g = "crab", n = "giant isopod", k = 0.95},
	swim_coelacanth = {g = "swim", n = "coelacanth", k = 0.8},
	swim_cretoxyrhina = {g = "swim", n = "ginsu shark", k = 1.0},
	swim_octopus = {g = "swim", n = "giant octopus", k = 0.8},
	swim_mosasaurus = {g = "swim", n = "mosasaur", k = 1.1},
	swim_ophthalmosaurus = {g = "swim", n = "ichthyosaur", k = 1.0},
	swim_styxosaurus = {g = "swim", n = "plesiosaur", k = 1.15},
	swim_tylosaurus = {g = "swim", n = "Tylosaurus", k = 1.1},
	swim_dallasaurus = {g = "swim", n = "Dallasaurus", k = 0.8},
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

## what lives on this find's floor (its own stream): the common weed nearly always (sea oak or bladder wrack — it grows
## in clumps, grow() spreads them), behind it maybe a coral or the giant kelp, maybe a coral or an anemone beside, one
## to three small things before it (a star, a shell, a crab), and now and then a swimmer
const COMMON := ["weed_claret", "weed_wiggle"]
static func genes(seed_v: int, salt: int) -> Dictionary:
	var r := Rng32.new((seed_v * 2654435761 + salt * 977 + 41) % 4294967296)
	var tall: Array = []
	var near: Array = []
	if r.next() < 0.88: tall.append(COMMON[int(r.next() * 2.0)])
	var v := r.next()
	if v < 0.55: tall.append(_pick(r, "coral", tall))
	elif v < 0.75: tall.append("weed_kelp")
	if tall.is_empty(): tall.append(_pick(r, "coral", tall))
	if r.next() < 0.4: near.append(_pick(r, "coral", tall))
	for gp: Array in [["star", 0.55], ["shell", 0.5], ["crab", 0.45]]:
		if r.next() < float(gp[1]): near.append(_pick(r, String(gp[0]), near))
	# (at least one small thing before it)
	if not near.any(func(k: String) -> bool: return String((MODELS[k] as Dictionary).g) in ["star", "shell", "crab"]):
		near.append(_pick(r, String(["star", "shell", "crab"][int(r.next() * 3.0)]), near))
	var swim := _pick(r, "swim", []) if r.next() < 0.28 else ""
	# the common weed's clumps: how many, and how many stalks in each
	var clumps := 1 + (1 if r.next() < 0.55 else 0)
	return {tall = tall, near = near, swim = swim, clumps = clumps, stalks = 4 + int(r.next() * 4.0)}

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
	return float({weed = 0.4, coral = 0.9, star = 0.8, shell = 0.8, crab = 1.0, swim = 2.2}.get(g, 0.5))

static func mesh(id: String) -> Mesh:
	if not _mesh.has(id):
		_mesh[id] = load(DIR + id + ".obj") as Mesh
	return _mesh[id]

static func mat(id: String) -> ShaderMaterial:
	if not _mat.has(id):
		var md: Dictionary = MODELS[id]
		var m := ShaderMaterial.new()
		m.shader = SpecFungi.SHADER
		m.set_shader_parameter("tex_d", load(DIR + id + "_d.png"))
		m.set_shader_parameter("tex_n", load(DIR + id + "_n.png"))
		m.set_shader_parameter("gain", float(md.get("gain", 1.35)))
		m.set_shader_parameter("sat", float(md.get("sat", 1.15)))
		m.set_shader_parameter("rough", 0.45)
		m.set_shader_parameter("tint", md.get("tint", Color.WHITE))
		m.set_shader_parameter("sway", float(md.get("sway", 0.0)))
		if String(md.g) == "swim":
			m.set_shader_parameter("swim", 0.06)
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
			spot = _room(cands if it[1] else (front if front.size() else cands), occ, foot * shrink, r, behind if it[1] else INF)
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
		mi.transform = Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3.ONE * sz), at)
		if float(md.get("sway", 0.0)) == 0.0: mi.set_meta("sea_light", true)
		occ.append([Vector2(at.x, at.z), foot])
		out.append(["sea:" + id, mi, Vector3(0, bx.end.y * 0.7, 0) if not lying else Vector3(0, bx.end.y, 0)])
		# the common weed grows in clumps: long and short stalks of both kinds round the first, and another clump
		# along the slab's rim
		if id in COMMON:
			for c in int(reef.get("clumps", 1)):
				var ctr := at
				if c > 0:
					var far: Variant = _room(cands, occ, foot * 0.6, r)
					if far == null: break
					ctr = far
				for k in int(reef.get("stalks", 5)) - (1 if c == 0 else 0):
					var near_c := cands.filter(func(p: Vector3) -> bool: return Vector2(p.x - ctr.x, p.z - ctr.z).length() < span * 0.16)
					var sp: Variant = _room(near_c, occ, span * 0.012, r)
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
					st.transform = Transform3D(Basis(Vector3.UP, r.next() * TAU) * Basis(Vector3.RIGHT, (r.next() - 0.5) * 0.35) * Basis.from_scale(Vector3.ONE * ssz), sa)
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
		sn._process(0.0)
		# (no unseen box round its loop, as the hunter has: the studio would frame the loop and the find would shrink;
		# its loop is kept tight round the slab instead, a fin now and then past the card's edge)
		out.append(["sea:" + sw, sn, Vector3.ZERO])
	return out

## a spot from cands for a thing of footprint r, clear of what is there (occ: [centre (x, z), radius]) — the discs
## taken are generous (a trilobite's covers its spines and the slab round it), so life may tuck in under their rims:
## only its own middle must keep clear, by most of a disc's radius. behind: only spots behind z (tall things)
static func _room(cands: Array, occ: Array, r: float, rng: Rng32, behind := INF) -> Variant:
	if cands.is_empty():
		return null
	for tries in 80:
		var p: Vector3 = cands[int(rng.next() * cands.size())]
		var ok := p.z < behind
		for o: Array in occ:
			if Vector2(p.x, p.z).distance_to(o[0] as Vector2) < r * 0.6 + float(o[1]) * 0.78:
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
	func at(t: float) -> Vector3:
		return centre + Vector3(cos(t) * radius, height + sin(t * 2.0 + 0.6) * height * 0.25, sin(t) * radius * 0.7 * dir)
	func _process(dt: float) -> void:
		a += dt * TAU / 21.0
		var p := at(a)
		var nt := (at(a + 0.02) - p).normalized()
		var turn := tan.cross(nt).y / maxf(dt, 0.001) if dt > 0.0 else 0.0
		bank = lerpf(bank, clampf(-turn * 0.25, -0.4, 0.4), minf(1.0, dt * 2.0))
		tan = nt
		position = p
		# (its head is the model's +x: turned to the way it goes)
		basis = Basis.looking_at(nt, Vector3.UP) * Basis(Vector3.UP, PI / 2) * Basis(Vector3.RIGHT, bank) * Basis.from_scale(Vector3.ONE * sc)
