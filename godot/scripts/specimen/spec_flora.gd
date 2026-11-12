class_name SpecFlora
extends RefCounted
## Flowers on the host rock (the "flowers" gene): eight kinds, every one a real plant — scans (assets/specimen/flora,
## CREDITS.md there; made light by prototype/tools/flowers/flower_prep.py), each mesh one unit tall on its foot, its
## colour and relief baked into two textures, drawn by the mushrooms' shader (shaders/fungi_model.gdshader) with a
## little sway. A kind may have several looks, and a find grows one of them; a look may be several models mixed
## (the two gentians, the three tiger lilies; the iris's open flower, its spray of buds and its leaf). The mountain violets are small and many, all over the rock, as they
## grow in scree; the rest stand as one or two plants with a smaller one beside.
## Which kind a find grows is the genome's (`flora`, from roll); placement uses its own random stream.

const NAMES := ["mountain violets", "gentians", "tiger lilies", "wild roses", "daisies", "golden daisies", "azaleas", "crested irises"]
const DIR := "res://assets/specimen/flora/"

## looks: the models of each look; k: how tall a grown one stands beside the size asked for; many: small ones all over
## the rock (the violets) and not one clump; lead: the model of a clump's first, grown plant; more: this many more
## plants to a clump; gain, sat, rough, sway: the material
const KINDS := [
	{looks = [["violet"]], k = 0.7, many = true, gain = 1.25, sat = 1.7},
	{looks = [["gentian_a", "gentian_b_0"]], more = 1, k = 1.0, gain = 1.5, sat = 1.3},
	{looks = [["lily_a", "lily_b", "lily_c"]], k = 1.2, gain = 1.3, sat = 1.15},
	{looks = [["rose"]], k = 1.05, gain = 1.35, sat = 1.15},
	{looks = [["daisy_0"]], k = 1.05, gain = 1.15},
	{looks = [["goldmum"]], k = 1.05, gain = 1.35, sat = 1.2},
	{looks = [["azalea"]], k = 1.05, gain = 1.3, sat = 1.15},
	{looks = [["iris_2", "iris_1", "iris_0", "iris_0"]], lead = "iris_2", more = 2, k = 1.0, gain = 1.3, sat = 1.2},
]

static var _meshes := {}
static var _mats := {}
static var look_pin := -1

## which kind of flower a stone grows, if it grows any (the "flowers" gene decides that). Its own random stream.
static func roll(seed_v: int) -> int:
	var r := Rng32.new((seed_v * 2246822 + 9173) % 4294967296)
	return int(Stones.pick_w([[0, 4.0], [1, 2.0], [2, 1.5], [3, 1.5], [4, 1.5], [5, 1.5], [6, 1.3], [7, 1.3]], r))

## which look of its kind a find grows (one to a find): from the stone's seed
static func find_look(seed_v: int, kind: int) -> int:
	var n: int = (KINDS[kind].looks as Array).size()
	return mini(int(Rng32.new((seed_v * 48271 + 1291) % 4294967296).next() * n), n - 1)

static func model(name: String) -> Mesh:
	if not _meshes.has(name):
		_meshes[name] = load(DIR + name + ".obj") as Mesh
	return _meshes[name]

static func mat_of(name: String, kind: int) -> ShaderMaterial:
	if _mats.has(name):
		return _mats[name]
	var K: Dictionary = KINDS[kind]
	var m := ShaderMaterial.new()
	m.shader = SpecFungi.SHADER
	m.set_shader_parameter("tex_d", load(DIR + name + "_d.png"))
	m.set_shader_parameter("tex_n", load(DIR + name + "_n.png"))
	m.set_shader_parameter("gain", float(K.get("gain", 1.3)))
	m.set_shader_parameter("sat", float(K.get("sat", 1.1)))
	m.set_shader_parameter("rough", float(K.get("rough", 0.6)))
	m.set_shader_parameter("sway", float(K.get("sway", 0.03)))
	_mats[name] = m
	return m

## the plants of `kind` on the rock: spots [pos, normal] (the open rock), size — the find's scale; blockers: the
## crystals ({bounds, inverse}) no plant may grow into. Gives [pos, up] of the first plant of every clump (for the
## callouts), empty when none found room
static func grow(parent: Node3D, rng: Rng32, spots: Array, kind: int, gs: float, blockers: Array = [], pick := -1) -> Array:
	if spots.is_empty():
		return []
	var K: Dictionary = KINDS[kind]
	var looks: Array = K.looks
	var look: Array = looks[clampi(pick if pick >= 0 else int(rng.next() * looks.size()), 0, looks.size() - 1)]
	if look_pin >= 0: look = looks[mini(look_pin, looks.size() - 1)]
	var many: bool = K.get("many", false)
	# rock that faces up, where there is any
	var tops := spots.filter(func(q: Array) -> bool: return (q[1] as Vector3).y > 0.3)
	var base: Array = tops if tops.size() else spots
	# the rock's flanks: where the crystals leave the top no room, a plant grows out of the side, leaning off it
	var flank := spots.filter(func(q: Array) -> bool: return (q[1] as Vector3).y <= 0.3 and (q[1] as Vector3).y > -0.25)
	if flank.is_empty(): flank = base
	var placed := {}      # model -> [transforms, tints]
	var marks := []
	var clumps := (4 + int(rng.next() * 4)) if many else (1 + int(rng.next() * 2))
	for c in clumps:
		var c0: Array = base[int(rng.next() * base.size())]
		var size := (0.4 + rng.next() * 0.22) * gs
		var reach := size * (0.75 if many else 1.2)
		var near := base.filter(func(q: Array) -> bool: return (q[0] as Vector3).distance_to(c0[0]) < reach)
		if near.is_empty(): near = [c0]
		var count := (3 + int(rng.next() * 4)) if many else (1 + int(rng.next() * 2.4)) + int(K.get("more", 0))
		var first := true
		for k in count:
			for attempt in 24:
				# (no room by the crystals: farther off on the top, then out of the rock's flank at nearly its full
				# size, and only then smaller)
				var side := (attempt >= 10 and attempt < 16) or attempt >= 20
				var pool: Array = near if attempt < 6 else flank if side else base
				var at: Array = c0 if k == 0 and attempt == 0 else pool[int(rng.next() * pool.size())]
				var p: Vector3 = at[0]
				var nrm: Vector3 = at[1]
				var up := (nrm.lerp(Vector3.UP, 0.5 if side else 0.72) + Vector3(rng.next() - 0.5, 0, rng.next() - 0.5) * 0.3).normalized()
				# a grown one, then smaller ones beside it; the violets all of a size, more or less
				var age := (0.7 + 0.3 * rng.next()) if many else (1.0 if k == 0 else 0.5 + 0.35 * rng.next())
				var name: String = look[mini(int(rng.next() * look.size()), look.size() - 1)]
				if k == 0 and K.has("lead"): name = String(K.lead)
				var s := size * float(K.k) * age * (1.0 if attempt < 10 else 0.9 if attempt < 16 else 0.6 if attempt < 20 else 0.42)
				var box := model(name).get_aabb()
				# (every model is one unit tall: a wide flat one — a big head on a short stem — would be huge by that)
				s /= sqrt(maxf(1.0, maxf(box.size.x, box.size.z)))
				var b := Basis(SpecUtil.quat_to(Vector3.UP, up)) * Basis(Vector3.UP, rng.next() * TAU)
				b = b * Basis.from_scale(Vector3.ONE * s * (0.94 + rng.next() * 0.12))
				var xf := Transform3D(b, p - nrm * s * 0.03)
				var core := box.grow(-0.14 * minf(box.size.x, box.size.z))
				var hit := false
				for bl: Dictionary in blockers:
					if ((bl.inverse as Transform3D) * xf * core).intersects(bl.bounds):
						hit = true
						break
				if hit:
					continue
				if not placed.has(name): placed[name] = [[], []]
				(placed[name][0] as Array).append(xf)
				# (red: the plant's own beat in the sway; the rest a little tint apart from its neighbour)
				var v := 0.9 + rng.next() * 0.2
				(placed[name][1] as Array).append(Color(v, v, v, rng.next()))
				if first:
					marks.append([xf * Vector3(0, 0.8, 0), up])
					first = false
				break
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
		mi.set_meta("ibuf", buf)
		mi.set_meta("stand", true)   # (a butterfly does not land in them)
		parent.add_child(mi)
	return marks
