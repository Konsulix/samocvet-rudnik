class_name SpecFern
extends RefCounted
## Fossil leaves from Svalbard's coal measures (the plant beds round Pyramiden): a split slab of shale with a leaf laid
## flat on it as a thin film — a tree-fern frond (pinnae of tongue-shaped pinnules), ginkgo fans, sprigs of dawn
## redwood or a jointed horsetail. The film is what makes it: glossy black carbon on grey mudstone, gold pyrite on black
## shale, pale silver on black, or rusty iron on buff stone. Sometimes both halves of the split (the leaf and its
## pressed counterpart), sometimes leaf litter round it. Legendary "spring": light runs up its veins and it greens as if
## alive. The leaf film: shaders/fern_film.gdshader; the slab: the generator's rock material on its own shape.

const U := preload("res://scripts/specimen/spec_util.gd")
const FILM_SHADER := preload("res://shaders/fern_film.gdshader")
const SLAB_SHADER := preload("res://shaders/fern_slab.gdshader")

const PLANT := ["fern", "ginkgo", "redwood", "horsetail"]
const PLANT_N := {fern = "tree fern", ginkgo = "ginkgo leaves", redwood = "dawn redwood", horsetail = "horsetail"}
## the film: its colour, and the stone it lies on
const FILM := [
	{name = "carbon film", col = 0x141110, stone = 0x8e8a80},
	{name = "pyritized", col = 0xf0c858, stone = 0x34322f},
	{name = "silver film", col = 0xc8ccc8, stone = 0x2e2c2a},
	{name = "iron-stained", col = 0xa8400e, stone = 0x7a664a},
]

static func genes(seed_v: int, tr: Array, o: Dictionary = {}) -> Dictionary:
	var rng := Rng32.new((seed_v * 2246822519 + 59) % 4294967296)
	var g := {kind = "fern"}
	g.plant = PLANT[int(Stones.pick_w([[0, 5.0], [1, 2.0], [2, 2.0], [3, 1.2]], rng))]
	g.film = int(Stones.pick_w([[0, 4.0], [1, 1.5], [2, 2.0], [3, 2.0]], rng))
	g.pair = rng.next() < 0.2
	g.litter = rng.next() < 0.4
	g.seed = int(rng.next() * 100000.0)
	if "irid" in tr or "aurora" in tr: g.film = 1
	for k in ["plant", "film", "pair", "litter"]:
		if o.has(k): g[k] = o[k]
	return g

static func accents(g: Dictionary) -> Array:
	var out := ["film", "plant"]
	if g.get("pair", false): out.append("pair")
	if g.get("litter", false): out.append("litter")
	return out

static func gene_name(id: String, g: Dictionary) -> String:
	match id:
		"film": return FILM[int(g.film)].name
		"plant": return PLANT_N.get(g.plant, "")
		"pair": return "part & counterpart"
		"litter": return "leaf litter"
	return ""

static func film_mat(f: Dictionary, mould: bool, spring: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = FILM_SHADER
	m.set_shader_parameter("film_col", Color.hex(int(FILM[int(f.film)].col) << 8 | 0xff))
	m.set_shader_parameter("film", int(f.film))
	m.set_shader_parameter("mould", 1.0 if mould else 0.0)
	m.set_shader_parameter("spring", 1.0 if spring and not mould else 0.0)
	m.set_shader_parameter("seed", float(int(f.seed) % 97))
	return m

static func build(b: RefCounted, gene: Dictionary) -> MeshInstance3D:
	var f: Dictionary = gene.fossil
	var root: Node3D = b.root
	var gs: float = gene.scale
	var holder := Node3D.new()
	root.add_child(holder)
	var film: Dictionary = FILM[int(f.film)]
	var spring: bool = gene.fx == "spring"
	var stone := ShaderMaterial.new()
	stone.shader = SLAB_SHADER
	stone.set_shader_parameter("stone", Color.hex(int(film.stone) << 8 | 0xff))
	stone.set_shader_parameter("tex", load("res://assets/textures/rock_surface/rock_surface_diff_1k.jpg"))
	stone.set_shader_parameter("seed", float(int(f.seed) % 13) * 0.17)
	stone.set_shader_parameter("rust", 1.0 if int(f.film) == 3 else 0.0)
	stone.set_meta("rock", true)
	var pair: bool = f.get("pair", false)
	var halves := [[Vector3(-0.74, 0, 0.02), false], [Vector3(0.74, 0, -0.02), true]] if pair else [[Vector3.ZERO, false]]
	var rx := 0.68 if pair else 0.78
	var rz := 0.98 if pair else 1.0
	var main: MeshInstance3D = null
	var marks := {}
	for h: Array in halves:
		var mould: bool = h[1]
		var rng := Rng32.new(int(f.seed) * 7 + 5)
		var srng := Rng32.new(int(f.seed) * 13 + (29 if mould else 3))
		var sm := U.mesh(_slab(srng, rx, rz, int(f.seed) + (5 if mould else 0)), stone, holder, h[0])
		sm.set_meta("col", true)
		var g := Geo.new()
		var pts := []
		var base := Vector3((rng.next() - 0.5) * rx * 0.25, 0, rz * 0.82)
		var dir := Vector2((rng.next() - 0.5) * 0.35, -1.0).normalized()
		match String(f.plant):
			"fern": pts = _fern(g, rng, base, dir, rz * 1.62)
			"ginkgo": pts = _ginkgos(g, rng, rx, rz)
			"redwood": pts = _redwood(g, rng, base, dir, rz * 1.55)
			_: pts = _horsetail(g, rng, base, dir, rz * 1.6)
		var lit := []
		if f.get("litter", false):
			lit = _litter(g, rng, rx, rz, String(f.plant))
		# a film lying flat: its normal straight up, whichever way its triangles wind
		g.own_n.resize(g.v.size())
		g.own_n.fill(Vector3.UP)
		var leaf := Node3D.new()
		holder.add_child(leaf)
		leaf.position = h[0] + Vector3(0, 0.006, 0)
		# the counterpart is the mirror image: the same leaf seen from the other side of the split
		if mould: leaf.scale = Vector3(-1, 1, 1)
		var mi := U.mesh(g, film_mat(f, mould, spring), leaf)
		if main == null:
			main = mi
			var xf := U.rel_xform(leaf, root)
			for k in mini(3, pts.size()):
				b._mark("film", xf * (pts[int(k * pts.size() / 3)] as Vector3), xf.basis * Vector3.UP)
			if pts.size(): b._mark("plant", xf * (pts[0] as Vector3), xf.basis * Vector3.UP)
			if lit.size(): b._mark("litter", xf * (lit[0] as Vector3), xf.basis * Vector3.UP)
		elif mould:
			var xf2 := U.rel_xform(leaf, root)
			b._mark("pair", xf2 * Vector3(0, 0, 0), xf2.basis * Vector3.UP)
	# lying on the table, tipped up to face the viewer
	root.set_meta("face", true)
	var yaw := (Rng32.new(int(f.seed) + 77).next() - 0.5) * 0.4
	holder.transform = Transform3D(Basis(Vector3.RIGHT, 0.95) * Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3.ONE * gs), Vector3.ZERO)
	if spring:
		root.set_meta("dim", true)
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(0.5, 1.0, 0.4)
		lamp.light_energy = 0.3
		lamp.omni_range = 2.2
		lamp.position = Vector3(0, 0.5, 0)
		holder.add_child(lamp)
	return main

## the split slab: an irregular flat top (the bedding plane the leaf lies on), a rounded broken edge, stepped sides
static func _slab(rng: Rng32, rx: float, rz: float, seed_v: int) -> Geo:
	var nz := FastNoiseLite.new()
	nz.seed = seed_v
	nz.frequency = 1.6
	var g := Geo.new()
	var na := 64
	var nr := 10
	var ns := 6
	var nd := 4
	var depth := 0.16 + rng.next() * 0.06
	for i in nr + ns + nd + 1:
		for j in na + 1:
			var a := TAU * float(j) / na
			var wob := 1.0 + 0.12 * nz.get_noise_1d(a * 2.2) + 0.025 * nz.get_noise_1d(a * 7.0 + 40.0)
			var x := 0.0
			var z := 0.0
			var y := 0.0
			if i <= nr:
				var t := float(i) / nr
				x = sin(a) * rx * t * wob
				z = cos(a) * rz * t * wob
				y = 0.004 * nz.get_noise_2d(x * 9.0, z * 9.0)
				if t > 0.85:
					var r := (t - 0.85) / 0.15
					y -= 0.03 * (1.0 - cos(r * PI * 0.5))
			elif i <= nr + ns:
				var t := float(i - nr) / ns
				var k := 1.0 + (0.03 + 0.05 * nz.get_noise_2d(a * 5.0, t * 4.0)) * t
				x = sin(a) * rx * wob * k
				z = cos(a) * rz * wob * k
				y = -0.03 - t * (depth - 0.03) + 0.015 * nz.get_noise_2d(a * 7.0, 9.0) * t
			else:
				var t := 1.0 - float(i - nr - ns) / nd
				x = sin(a) * rx * wob * 1.05 * t
				z = cos(a) * rz * wob * 1.05 * t
				y = -depth - 0.02 * nz.get_noise_2d(x * 4.0, z * 4.0)
			g.v.append(Vector3(x, y, z))
			g.rp.append(Vector3(x, z, 0))
	var rows := nr + ns + nd
	for i in rows:
		for j in na:
			var p0 := i * (na + 1) + j
			var p1 := p0 + na + 1
			g.idx.append_array([p0, p0 + 1, p1, p0 + 1, p1 + 1, p1])
	return g.orient_out(Vector3(0, -depth * 0.5, 0))

## a blade: base at `at`, out along `d` (unit, xz), length l, full width w; a rounded base and a blunt or pointed tip;
## u the place along the whole plant (UV2.x); fan: a ginkgo fan instead
static func _blade(g: Geo, at: Vector3, d: Vector2, l: float, w: float, u: float, rnd: float, tip := 0.8) -> void:
	var n := 7
	var p := Vector2(-d.y, d.x)
	var b0 := g.v.size()
	for i in n + 1:
		var t := float(i) / n
		var hw := w * 0.5 * pow(sin(PI * clampf(t * 0.94 + 0.03, 0.0, 1.0)), tip) * (1.0 + 0.15 * (1.0 - t))
		var c := Vector2(at.x, at.z) + d * l * t
		for s in [-1.0, 0.0, 1.0]:
			var q := c + p * hw * float(s)
			g.v.append(Vector3(q.x, at.y + 0.0015 * (1.0 - absf(float(s))), q.y))
			g.rp.append(Vector3(t, float(s), u))
			g.col.append(Color(0, rnd, 0, 1))
	for i in n:
		var a := b0 + i * 3
		for s in 2:
			g.idx.append_array([a + s, a + 3 + s, a + s + 1, a + s + 1, a + 3 + s, a + 4 + s])

## a stem along a polyline: width w0 at its start to w1 at its end
static func _stem(g: Geo, pts: Array, w0: float, w1: float, u0: float, u1: float) -> void:
	var b0 := g.v.size()
	var n := pts.size()
	for i in n:
		var a: Vector3 = pts[maxi(i - 1, 0)]
		var c: Vector3 = pts[mini(i + 1, n - 1)]
		var d := Vector2(c.x - a.x, c.z - a.z).normalized()
		var p := Vector2(-d.y, d.x)
		var t := float(i) / (n - 1)
		var hw := lerpf(w0, w1, t) * 0.5
		var q: Vector3 = pts[i]
		for s in [-1.0, 1.0]:
			g.v.append(Vector3(q.x + p.x * hw * float(s), q.y + 0.001, q.z + p.y * hw * float(s)))
			g.rp.append(Vector3(t, float(s), lerpf(u0, u1, t)))
			g.col.append(Color(1, 0, 0, 1))
	for i in n - 1:
		var a := b0 + i * 2
		g.idx.append_array([a, a + 2, a + 1, a + 1, a + 2, a + 3])

static func _rot(d: Vector2, a: float) -> Vector2:
	return Vector2(d.x * cos(a) - d.y * sin(a), d.x * sin(a) + d.y * cos(a))

## a curving line: n points from `at` along d, bending by `bend` (radians over its length)
static func _curve(at: Vector3, d: Vector2, l: float, bend: float, n: int) -> Array:
	var out := [at]
	var p := Vector2(at.x, at.z)
	var dd := d
	for i in n:
		dd = _rot(dd, bend / n)
		p += dd * l / n
		out.append(Vector3(p.x, at.y, p.y))
	return out

## a tree-fern frond (Pecopteris): a rachis, pinnae alternating up it, each fringed with tongue-shaped pinnules
static func _fern(g: Geo, rng: Rng32, base: Vector3, dir: Vector2, L: float) -> Array:
	var bend := (rng.next() - 0.5) * 0.5
	var rach := _curve(base, dir, L, bend, 40)
	_stem(g, rach, 0.022, 0.004, 0.0, 1.0)
	var npin := 13 + int(rng.next() * 6)
	var pw := 0.024 + rng.next() * 0.008
	var spots := []
	for i in npin:
		for side in [-1.0, 1.0]:
			var t := 0.06 + 0.9 * (float(i) + (0.0 if side < 0 else 0.45)) / npin
			var k := int(t * 40.0)
			var at: Vector3 = rach[k]
			var tg := Vector2((rach[k + 1] as Vector3).x - at.x, (rach[k + 1] as Vector3).z - at.z).normalized()
			var pl := L * 0.34 * pow(1.0 - t, 0.75) * (0.6 + 0.4 * smoothstep(0.0, 0.25, t))
			var pd := _rot(tg, float(side) * (1.15 - 0.3 * t))
			var pin := _curve(at, pd, pl, -float(side) * 0.35, 10)
			_stem(g, pin, 0.007, 0.002, t, t + 0.05)
			var m := maxi(2, int(pl / pw))
			for j in m:
				var s := (float(j) + 0.5) / m
				var q: Vector3 = pin[int(s * 10.0)]
				var qd := Vector2((pin[mini(int(s * 10.0) + 1, 10)] as Vector3).x - q.x, (pin[mini(int(s * 10.0) + 1, 10)] as Vector3).z - q.z).normalized()
				var ln := pw * 1.85 * (1.0 - 0.4 * s)
				for s2 in [-1.0, 1.0]:
					_blade(g, q, _rot(qd, float(s2) * 1.2), ln, pw * 1.2, t, rng.next(), 0.45)
			_blade(g, pin[10], pd, pw * 1.6, pw * 0.9, t + 0.05, rng.next(), 0.6)
			if i == npin / 3: spots.append(pin[5])
	_blade(g, rach[40], dir, pw * 2.4, pw * 1.1, 1.0, rng.next(), 0.6)
	return [base] + spots + [rach[20], rach[30]]

## ginkgo: a few fan leaves on long stalks, scattered as they fell, each fan notched in the middle and finely veined
static func _ginkgos(g: Geo, rng: Rng32, rx: float, rz: float) -> Array:
	var out := []
	var n := 3 + int(rng.next() * 3)
	for k in n:
		var at := Vector3((rng.next() - 0.5) * rx * 0.9, 0, (rng.next() - 0.3) * rz * 0.9)
		var d := _rot(Vector2(0, -1), (rng.next() - 0.5) * 2.4)
		var s := 0.7 + rng.next() * 0.5 if k else 1.25
		var st := _curve(at, d, 0.22 * s, (rng.next() - 0.5) * 0.6, 8)
		_stem(g, st, 0.012 * s, 0.009 * s, 0.0, 0.2)
		var tip: Vector3 = st[8]
		var td := Vector2(tip.x - (st[7] as Vector3).x, tip.z - (st[7] as Vector3).z).normalized()
		_fan(g, tip, td, 0.26 * s, 0.95 + rng.next() * 0.25, rng.next() < 0.7, rng.next())
		out.append(tip + Vector3(td.x, 0, td.y) * 0.13 * s)
	return out

static func _fan(g: Geo, at: Vector3, d: Vector2, R: float, th: float, notch: bool, rnd: float) -> void:
	var na := 20
	var nr := 6
	var b0 := g.v.size()
	for i in nr + 1:
		var t := float(i) / nr
		for j in na + 1:
			var s := float(j) / na * 2.0 - 1.0
			var a := s * th
			var r := R * t * (1.0 - (0.4 * exp(-pow(s / 0.09, 2.0)) if notch else 0.0)) * (1.0 + 0.03 * sin(s * 37.0 + rnd * 9.0) * t)
			var q := Vector2(at.x, at.z) + _rot(d, a) * r
			g.v.append(Vector3(q.x, at.y + 0.001, q.y))
			g.rp.append(Vector3(t, s, 0.2 + t * 0.8))
			g.col.append(Color(0, rnd, 0.5, 1))
	for i in nr:
		for j in na:
			var p0 := b0 + i * (na + 1) + j
			var p1 := p0 + na + 1
			g.idx.append_array([p0, p1, p0 + 1, p0 + 1, p1, p1 + 1])

## a sprig of dawn redwood (Metasequoia): a twig with branchlets in opposite pairs, each a double row of flat needles
static func _redwood(g: Geo, rng: Rng32, base: Vector3, dir: Vector2, L: float) -> Array:
	var tw := _curve(base, dir, L, (rng.next() - 0.5) * 0.5, 30)
	_stem(g, tw, 0.018, 0.006, 0.0, 1.0)
	var out := [base]
	var nb := 7 + int(rng.next() * 3)
	for i in nb:
		var t := 0.1 + 0.85 * float(i) / nb
		var k := int(t * 30.0)
		var at: Vector3 = tw[k]
		var tg := Vector2((tw[k + 1] as Vector3).x - at.x, (tw[k + 1] as Vector3).z - at.z).normalized()
		for side in [-1.0, 1.0]:
			var bl := L * 0.28 * (1.0 - 0.5 * t)
			var bd := _rot(tg, float(side) * 0.75)
			var br := _curve(at, bd, bl, -float(side) * 0.2, 16)
			_stem(g, br, 0.005, 0.002, t, t + 0.05)
			var nn := int(bl / 0.018)
			for j in nn:
				var s := (float(j) + 0.5) / nn
				var q: Vector3 = br[int(s * 16.0)]
				var qd := Vector2((br[mini(int(s * 16.0) + 1, 16)] as Vector3).x - q.x, (br[mini(int(s * 16.0) + 1, 16)] as Vector3).z - q.z).normalized()
				var nl := 0.05 * (1.0 - 0.4 * absf(s - 0.4))
				for s2 in [-1.0, 1.0]:
					_blade(g, q, _rot(qd, float(s2) * 1.35), nl, 0.011, t, rng.next(), 0.35)
			if i == 2 and side > 0: out.append(br[8])
	out.append(tw[15])
	return out

## a horsetail (Equisetum): a jointed stem, a dark ring at each node, whorls of thin leaves, a cone at the top
static func _horsetail(g: Geo, rng: Rng32, base: Vector3, dir: Vector2, L: float) -> Array:
	var st := _curve(base, dir, L, (rng.next() - 0.5) * 0.3, 40)
	var seg := 0.11 + rng.next() * 0.03
	var nseg := int(L / seg)
	for i in nseg:
		var a := int(float(i) / nseg * 40.0)
		var b := int(float(i + 1) / nseg * 40.0)
		_stem(g, (st as Array).slice(a, b), 0.05 - 0.02 * float(i) / nseg, 0.048 - 0.02 * float(i) / nseg, float(i) / nseg, float(i + 1) / nseg)
		var at: Vector3 = st[b]
		var tg := Vector2((st[mini(b + 1, 40)] as Vector3).x - at.x, (st[mini(b + 1, 40)] as Vector3).z - at.z).normalized()
		if i < nseg - 1:
			for side in [-1.0, 1.0]:
				for w in 3:
					_blade(g, at, _rot(tg, float(side) * (0.35 + w * 0.22)), 0.13 + rng.next() * 0.05, 0.009, float(i) / nseg, rng.next(), 0.3)
	var top: Vector3 = st[40]
	_blade(g, top, dir, 0.16, 0.07, 1.0, rng.next(), 0.9)
	return [base, st[20], top]

## leaf litter: a few small pieces round the main leaf — broken pinnae, little fans, needles
static func _litter(g: Geo, rng: Rng32, rx: float, rz: float, plant: String) -> Array:
	var out := []
	for k in 3 + int(rng.next() * 4):
		var a := rng.next() * TAU
		var r := 0.55 + rng.next() * 0.3
		var at := Vector3(sin(a) * rx * r, 0, cos(a) * rz * r)
		var d := _rot(Vector2(1, 0), rng.next() * TAU)
		if plant == "ginkgo" or rng.next() < 0.3:
			_fan(g, at, d, 0.1 + rng.next() * 0.06, 0.9, rng.next() < 0.6, rng.next())
		else:
			var pin := _curve(at, d, 0.14 + rng.next() * 0.1, (rng.next() - 0.5) * 0.6, 8)
			_stem(g, pin, 0.005, 0.002, 0.5, 0.6)
			for j in 5:
				var q: Vector3 = pin[1 + j]
				for s2 in [-1.0, 1.0]:
					_blade(g, q, _rot(d, float(s2) * 1.15), 0.035, 0.024, 0.5, rng.next(), 0.55)
		out.append(at)
	return out
