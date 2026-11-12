class_name SpecFungi
extends RefCounted
## Mushrooms on the host rock (the "mushrooms" gene): eight kinds, every one a real mushroom — scans and models
## (assets/specimen/fungi, CREDITS.md there; made light by prototype/tools/mushrooms/shroom_prep.py), each mesh one unit
## tall on its foot, with its colour and relief baked into two textures and drawn by shaders/fungi_model.gdshader.
## A kind may have several looks — the boletes four species, the fly agarics the red one and the golden — and a find
## grows one of them; the panther caps come in three ages (grown, half open, a button), the honey fungus and the oysters
## as whole tufts. The glowing mycena glows, more so when the studio goes dark.
## A cluster grows from one spot on the rock: a grown one and young ones of every size around it.
## Decisions and placement use their own random stream (seeded from the stone).

const NAMES := ["fly agarics", "chanterelles", "boletes", "glowing mycena", "honey fungus", "morels", "blue oysters", "panther caps"]
const DIR := "res://assets/specimen/fungi/"
const SHADER: Shader = preload("res://shaders/fungi_model.gdshader")

## looks: the models of each look ([[name, ...], ...]; one look to a find, its models mixed in the cluster);
## k: how tall a grown one stands beside the size asked for; tuft: the model is a whole tuft (fewer of them, none tiny);
## ages: the look's models are one mushroom at three ages, grown to button; shelf: grows out of a steep face as gladly
## as on a flat one (the rest keep to rock that faces up, where there is any); glow, tint, gain, sat, rough: the material
const KINDS := [
	{looks = [["agaric_red"], ["agaric_gold_a", "agaric_gold_b"]], k = 1.0, rough = 0.4, gain = 0.95, sat = 1.15},
	{looks = [["chanterelle"]], k = 0.66, gain = 1.25},
	{looks = [["bolete_brown"], ["bolete_jack"], ["bolete_suede"], ["bolete_wine"]], k = 0.82, rough = 0.45},
	{looks = [["mycena"]], k = 0.95, glow = 2.4, tint = Color(0.7, 1.0, 0.8), gain = 1.25, sat = 0.4},
	{looks = [["honey"]], k = 0.95, tuft = true, shelf = true, rough = 0.4},
	{looks = [["morel"]], k = 0.9, gain = 1.15},
	{looks = [["oyster"]], k = 0.85, tuft = true, shelf = true, rough = 0.45},
	{looks = [["panther_0", "panther_1", "panther_2"]], k = 1.05, ages = true, gain = 0.8},
]

static var _meshes := {}
static var look_pin := -1
static var _mats := {}

## does this stone grow mushrooms, and which kind (-1: none). Its own random stream, not the genome's.
## (the honey fungus grows on dead wood only: SpecWood asks for it by number)
static func roll(seed_v: int) -> int:
	var r := Rng32.new((seed_v * 2654435 + 4093) % 4294967296)
	if r.next() > 0.14:
		return -1
	return int(Stones.pick_w([[0, 3.0], [1, 2.5], [2, 2.5], [3, 1.4], [5, 1.6], [6, 1.3], [7, 1.6]], r))

static func model(name: String) -> Mesh:
	if not _meshes.has(name):
		_meshes[name] = load(DIR + name + ".obj") as Mesh
	return _meshes[name]

static func mat_of(name: String, kind: int) -> ShaderMaterial:
	if _mats.has(name):
		return _mats[name]
	var K: Dictionary = KINDS[kind]
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("tex_d", load(DIR + name + "_d.png"))
	m.set_shader_parameter("tex_n", load(DIR + name + "_n.png"))
	var t: Color = K.get("tint", Color(1, 1, 1))
	m.set_shader_parameter("tint", Vector3(t.r, t.g, t.b))
	m.set_shader_parameter("gain", float(K.get("gain", 1.1)))
	m.set_shader_parameter("sat", float(K.get("sat", 1.0)))
	m.set_shader_parameter("rough", float(K.get("rough", 0.55)))
	m.set_shader_parameter("glow", float(K.get("glow", 0.0)))
	_mats[name] = m
	return m

## (the first model of a kind: for the shader's warm-up at the start)
static func mesh(kind: int) -> Mesh:
	return model(String(((KINDS[kind].looks as Array)[0] as Array)[0]))

static func material(kind: int) -> ShaderMaterial:
	return mat_of(String(((KINDS[kind].looks as Array)[0] as Array)[0]), kind)

## one cluster of `kind` round a spot of `spots` ([pos, normal]); size: the height of a grown one
## blockers: the crystals ({bounds, inverse}: their box in their own axes, and the way into them) no cap may grow into.
## Gives the spot of the biggest cap, or an empty array when none found room
static func cluster(parent: Node3D, rng: Rng32, spots: Array, kind: int, count: int, size: float, blockers: Array = []) -> Array:
	if spots.is_empty():
		return []
	var K: Dictionary = KINDS[kind]
	var looks: Array = K.looks
	var look: Array = looks[mini(int(rng.next() * looks.size()), looks.size() - 1)]
	if look_pin >= 0: look = looks[mini(look_pin, looks.size() - 1)]   # (tests/fungi_view: this look and no other)
	var tuft: bool = K.get("tuft", false)
	var ages: bool = K.get("ages", false)
	if tuft: count = maxi(1, int(ceil(count / 4.0)))
	# rock that faces up, where there is any: a wide cap standing off a wall hangs in the air beside it
	var base: Array = spots
	var lean := 0.0 if K.get("shelf", false) else 0.3
	var tops := spots.filter(func(q: Array) -> bool: return (q[1] as Vector3).y > lean)
	if tops.size(): base = tops
	var c0: Array = base[int(rng.next() * base.size())]
	var reach := size * (0.9 if kind == 3 else 1.4)
	var near := []
	for s in base:
		if (s[0] as Vector3).distance_to(c0[0]) < reach: near.append(s)
	if near.is_empty(): near = [c0]
	var placed := {}      # model -> [transforms, tints]
	var first: Array = []
	for k in count:
		# a few tries for a spot clear of the crystals; none clear, and this one never comes up
		for attempt in 20:
			var pool: Array = near if attempt < 5 else base if attempt < 11 else spots
			var at: Array = c0 if k == 0 and attempt == 0 else pool[int(rng.next() * pool.size())]
			var p: Vector3 = at[0]
			var nrm: Vector3 = at[1]
			# mostly upright, leaning a little off the rock face
			var up := (nrm.lerp(Vector3.UP, 0.7) + Vector3(rng.next() - 0.5, 0, rng.next() - 0.5) * 0.35).normalized()
			# a grown one or two, then young ones of every size, down to buttons (a tuft is never tiny)
			var grow := 1.0 if k == 0 else 0.25 + 0.75 * pow(rng.next(), 1.4)
			if tuft and k > 0: grow = 0.55 + 0.45 * rng.next()
			var name: String = look[mini(int(rng.next() * look.size()), look.size() - 1)]
			if ages: name = look[0] if grow > 0.7 else look[1] if grow > 0.42 else look[2]
			# (no room by the crystals: a smaller one may find it)
			var s := size * float(K.k) * grow * (1.0 if attempt < 5 else 0.72 if attempt < 9 else 0.5 if attempt < 14 else 0.34)
			var b := Basis(SpecUtil.quat_to(Vector3.UP, up)) * Basis(Vector3.UP, rng.next() * TAU)
			b = b * Basis.from_scale(Vector3(s * (0.92 + rng.next() * 0.18), s * (0.9 + rng.next() * 0.22), s * (0.92 + rng.next() * 0.18)))
			var xf := Transform3D(b, p - nrm * s * 0.04)
			var box := model(name).get_aabb()
			# (a cap's rim may touch a crystal: its box drawn in a little)
			var core := box.grow(-0.1 * minf(box.size.x, box.size.z))
			var hit := false
			for bl: Dictionary in blockers:
				if ((bl.inverse as Transform3D) * xf * core).intersects(bl.bounds):
					hit = true
					break
			if hit:
				continue
			var v := 0.88 + rng.next() * 0.22
			if not placed.has(name): placed[name] = [[], []]
			(placed[name][0] as Array).append(xf)
			(placed[name][1] as Array).append(Color(v, v * (0.96 + rng.next() * 0.06), v))
			if first.is_empty(): first = [xf * box.get_center(), xf.basis.y.normalized()]
			break
	if first.is_empty():
		return []
	for name: String in placed:
		var xfs: Array = placed[name][0]
		var tints: Array = placed[name][1]
		var buf := SpecUtil.mm_buf(xfs.size())
		for k in xfs.size():
			SpecUtil.put(buf, k, xfs[k], tints[k])
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = model(name)
		mm.instance_count = xfs.size()
		mm.buffer = buf
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = mat_of(name, kind)
		parent.add_child(mi)
	# the middle of the biggest cap
	return first
