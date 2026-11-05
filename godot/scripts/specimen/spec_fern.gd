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

const PLANT := ["fern", "ginkgo", "redwood", "horsetail", "palm", "annularia", "lepido"]
const PLANT_N := {fern = "tree fern", ginkgo = "ginkgo leaves", redwood = "dawn redwood", horsetail = "horsetail",
	palm = "fan palm", annularia = "star leaves", lepido = "scale-tree bark"}
## the film: its colour, and the stone it lies on (a nodule has its own ironstone, NODULE_STONE)
const FILM := [
	{name = "carbon film", col = 0x141110, stone = 0x8e8a80},
	{name = "pyritized", col = 0xf0c858, stone = 0x34322f},
	{name = "silver film", col = 0xa9aeb0, stone = 0x2e2c2a},
	{name = "iron-stained", col = 0x8e3c16, stone = 0x7a664a},
	{name = "natural cast", col = 0xd6c6a2, stone = 0xd6c6a2},
	{name = "kaolinite", col = 0xece6da, stone = 0x8c8070},
	{name = "brown film", col = 0x4a2812, stone = 0xdccdaa},
]
const NODULE_STONE := 0x8c8070
const GUEST_N := {dragonfly = "dragonfly", fish = "little fish"}

static func genes(seed_v: int, tr: Array, o: Dictionary = {}) -> Dictionary:
	var rng := Rng32.new((seed_v * 2246822519 + 59) % 4294967296)
	var g := {kind = "fern"}
	g.plant = PLANT[int(Stones.pick_w([[0, 4.0], [1, 2.0], [2, 1.6], [3, 1.0], [4, 1.6], [5, 1.8], [6, 1.2]], rng))]
	g.film = int(Stones.pick_w([[0, 3.0], [1, 1.5], [2, 2.0], [3, 1.5], [4, 2.0], [6, 2.0]], rng))
	g.pair = rng.next() < 0.2
	g.litter = rng.next() < 0.4
	g.seed = int(rng.next() * 100000.0)
	# the later genes on their own stream: how it is shown (a split ironstone nodule), its film there, a visitor
	var r2 := Rng32.new((seed_v * 1597334677 + 211) % 4294967296)
	var nod: bool = r2.next() < 0.3 and g.plant in ["fern", "annularia", "redwood", "horsetail"]
	var nf := int(Stones.pick_w([[0, 2.0], [3, 1.2], [4, 2.0], [5, 2.5]], r2))
	var np := r2.next() < 0.65
	var gr := r2.next()
	var dn := r2.next()
	g.show = "nodule" if nod else "slab"
	if nod:
		g.film = nf
		g.pair = np
		g.litter = false
	g.guest = "" if nod else "dragonfly" if gr < 0.09 else "fish" if gr < 0.16 else ""
	# black manganese dendrites branching in from the slab's edge (they would not show on black shale)
	g.dendrites = not nod and dn < 0.35
	if "irid" in tr or "aurora" in tr:
		g.film = 1
		g.show = "slab"
	for k in ["plant", "film", "pair", "litter", "show", "guest", "dendrites"]:
		if o.has(k): g[k] = o[k]
	# what does not go together: a big palm or a strip of bark will not fit a nodule; kaolinite is a nodule's film
	if g.show == "nodule" and g.plant in ["ginkgo", "palm", "lepido"]: g.show = "slab"
	if g.show == "nodule":
		g.guest = ""
		g.dendrites = false
	if int(g.film) in [1, 2]: g.dendrites = false
	if int(g.film) == 5 and g.show != "nodule": g.film = 4
	return g

static func accents(g: Dictionary) -> Array:
	var out := ["film", "plant"]
	if g.get("show", "") == "nodule": out.append("nodule")
	if g.get("pair", false): out.append("pair")
	if g.get("litter", false): out.append("litter")
	if String(g.get("guest", "")) != "": out.append("guest")
	if g.get("dendrites", false): out.append("dendrites")
	return out

static func gene_name(id: String, g: Dictionary) -> String:
	match id:
		"film": return FILM[int(g.film)].name
		"plant": return PLANT_N.get(g.plant, "")
		"pair": return "part & counterpart"
		"litter": return "leaf litter"
		"nodule": return "ironstone nodule"
		"guest": return GUEST_N.get(g.get("guest", ""), "")
		"dendrites": return "manganese dendrites"
	return ""

static func film_mat(f: Dictionary, mould: bool, spring: bool, stone_c: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = FILM_SHADER
	var fc := Color.hex(int(FILM[int(f.film)].col) << 8 | 0xff)
	# a cast is the stone itself
	if int(f.film) == 4: fc = stone_c
	m.set_shader_parameter("film_col", fc)
	m.set_shader_parameter("stone_col", stone_c)
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
	var nod: bool = f.get("show", "") == "nodule"
	var stone_c := Color.hex(int(NODULE_STONE if nod else film.stone) << 8 | 0xff)
	var stone := ShaderMaterial.new()
	stone.shader = SLAB_SHADER
	stone.set_shader_parameter("stone", stone_c)
	stone.set_shader_parameter("tex", load("res://assets/textures/rock_surface/rock_surface_diff_1k.jpg"))
	stone.set_shader_parameter("seed", float(int(f.seed) % 13) * 0.17)
	stone.set_shader_parameter("rust", 1.0 if int(f.film) == 3 else 0.0)
	stone.set_shader_parameter("nodule", 1.0 if nod else 0.0)
	stone.set_meta("rock", true)
	var pair: bool = f.get("pair", false)
	var halves := [[Vector3(-0.74, 0, 0.02), false], [Vector3(0.74, 0, -0.02), true]] if pair else [[Vector3.ZERO, false]]
	var rx := 0.68 if pair else 0.78
	var rz := 0.98 if pair else 1.0
	if nod:
		halves = [[Vector3(-0.66, 0, 0.02), false], [Vector3(0.66, 0, -0.02), true]] if pair else [[Vector3.ZERO, false]]
		rx = 0.6 if pair else 0.66
		rz = 0.92 if pair else 0.95
	var main: MeshInstance3D = null
	for h: Array in halves:
		var mould: bool = h[1]
		var rng := Rng32.new(int(f.seed) * 7 + 5)
		var srng := Rng32.new(int(f.seed) * 13 + (29 if mould else 3))
		var shape := _nodule(srng, rx, rz, int(f.seed) + (5 if mould else 0)) if nod else _slab(srng, rx, rz, int(f.seed) + (5 if mould else 0))
		var sm := U.mesh(shape, stone, holder, h[0])
		sm.set_meta("col", true)
		var g := Geo.new()
		var pts := []
		var base := Vector3((rng.next() - 0.5) * rx * 0.25, 0, rz * 0.82)
		var dir := Vector2((rng.next() - 0.5) * 0.35, -1.0).normalized()
		match String(f.plant):
			"fern": pts = _fern(g, rng, base, dir, rz * 1.62)
			"ginkgo": pts = _ginkgos(g, rng, rx, rz)
			"redwood": pts = _redwood(g, rng, base, dir, rz * 1.55)
			"palm": pts = _palm(g, rng, rx, rz)
			"annularia": pts = _annularia(g, rng, rx, rz)
			"lepido": pts = _lepido(g, rng, rx, rz)
			_: pts = _horsetail(g, rng, base, dir, rz * 1.6)
		var lit := []
		if f.get("litter", false):
			lit = _litter(g, rng, rx, rz, String(f.plant))
		var gpts := []
		if String(f.get("guest", "")) != "":
			gpts = _guest(g, Rng32.new(int(f.seed) * 31 + 17), String(f.guest), rx, rz)
		# a film lying flat: its normal straight up, whichever way its triangles wind
		g.own_n.resize(g.v.size())
		g.own_n.fill(Vector3.UP)
		var leaf := Node3D.new()
		holder.add_child(leaf)
		leaf.position = h[0] + Vector3(0, 0.006, 0)
		# the counterpart is the mirror image: the same leaf seen from the other side of the split
		if mould: leaf.scale = Vector3(-1, 1, 1)
		var mi := U.mesh(g, film_mat(f, mould, spring, stone_c), leaf)
		var dpts := []
		if f.get("dendrites", false):
			var gd := Geo.new()
			dpts = _dendrites(gd, Rng32.new(int(f.seed) * 11 + (3 if mould else 1)), rx, rz)
			gd.own_n.resize(gd.v.size())
			gd.own_n.fill(Vector3.UP)
			var dl := Node3D.new()
			holder.add_child(dl)
			dl.position = h[0] + Vector3(0, 0.0052, 0)
			var dm := film_mat({film = 0, seed = f.seed}, false, false, stone_c)
			dm.set_shader_parameter("film_col", Color(0.07, 0.05, 0.04))
			dm.set_shader_parameter("relief", 0.25)
			U.mesh(gd, dm, dl)
		if main == null:
			main = mi
			var xf := U.rel_xform(leaf, root)
			for k in mini(3, pts.size()):
				b._mark("film", xf * (pts[int(k * pts.size() / 3)] as Vector3), xf.basis * Vector3.UP)
			if pts.size(): b._mark("plant", xf * (pts[0] as Vector3), xf.basis * Vector3.UP)
			if lit.size(): b._mark("litter", xf * (lit[0] as Vector3), xf.basis * Vector3.UP)
			for p in gpts:
				b._mark("guest", xf * (p as Vector3), xf.basis * Vector3.UP)
			for p in dpts:
				b._mark("dendrites", xf * (p as Vector3), xf.basis * Vector3.UP)
			if nod:
				var hx := U.rel_xform(sm, root)
				b._mark("nodule", hx * Vector3(rx * 0.86, 0, rz * 0.3), hx.basis * Vector3.UP)
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
			var r := 0.0
			if i <= nr:
				var t := float(i) / nr
				x = sin(a) * rx * t * wob
				z = cos(a) * rz * t * wob
				y = 0.004 * nz.get_noise_2d(x * 9.0, z * 9.0)
				r = t
				if t > 0.85:
					var e := (t - 0.85) / 0.15
					y -= 0.03 * (1.0 - cos(e * PI * 0.5))
			elif i <= nr + ns:
				var t := float(i - nr) / ns
				var k := 1.0 + (0.03 + 0.05 * nz.get_noise_2d(a * 5.0, t * 4.0)) * t
				x = sin(a) * rx * wob * k
				z = cos(a) * rz * wob * k
				y = -0.03 - t * (depth - 0.03) + 0.015 * nz.get_noise_2d(a * 7.0, 9.0) * t
				r = 1.0 + t
			else:
				var t := 1.0 - float(i - nr - ns) / nd
				x = sin(a) * rx * wob * 1.05 * t
				z = cos(a) * rz * wob * 1.05 * t
				y = -depth - 0.02 * nz.get_noise_2d(x * 4.0, z * 4.0)
				r = 2.0
			g.v.append(Vector3(x, y, z))
			g.rp.append(Vector3(x, z, r))
	var rows := nr + ns + nd
	for i in rows:
		for j in na:
			var p0 := i * (na + 1) + j
			var p1 := p0 + na + 1
			g.idx.append_array([p0, p0 + 1, p1, p0 + 1, p1 + 1, p1])
	return g.orient_out(Vector3(0, -depth * 0.5, 0))

## a blade: base at `at`, out along `d` (unit, xz), length l, full width w; a rounded base and a blunt or pointed tip;
## u the place along the whole plant (UV2.x); part: what it is to the film shader (COLOR.b: 0 a leaf blade, 0.3 a palm
## segment, 0.4 an insect's body, 0.8 a wing, 0.9 a fish); flip: a wing's leading edge on its +UV.y side
static func _blade(g: Geo, at: Vector3, d: Vector2, l: float, w: float, u: float, rnd: float, tip := 0.8, part := 0.0, flip := false) -> void:
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
			g.col.append(Color(0, rnd, part, 0.0 if flip else 1.0))
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
			var pin := _curve(at, pd, pl, -float(side) * 0.35, 12)
			# the pinna in one piece: its pinnules grown together into a lobed ribbon (the lobes cut in the shader)
			_ribbon(g, pin, pw * 3.4, pw * 1.1, t, rng.next(), float(maxi(2, int(pl / pw))) / 64.0)
			if i == npin / 3: spots.append(pin[5])
	_blade(g, rach[40], dir, pw * 2.4, pw * 1.1, 1.0, rng.next(), 0.6)
	return [base] + spots + [rach[20], rach[30]]

## ginkgo: a few fan leaves on long stalks, scattered as they fell, each fan notched in the middle and finely veined
static func _ginkgos(g: Geo, rng: Rng32, rx: float, rz: float) -> Array:
	var out := []
	var n := 4 + int(rng.next() * 3)
	for k in n:
		var at := Vector3((rng.next() - 0.5) * rx * 0.9, 0, (rng.next() - 0.3) * rz * 0.9)
		var d := _rot(Vector2(0, -1), (rng.next() - 0.5) * 2.4)
		var s := (0.9 + rng.next() * 0.5 if k else 1.5) * 1.15
		var st := _curve(at, d, 0.22 * s, (rng.next() - 0.5) * 0.6, 8)
		_stem(g, st, 0.012 * s, 0.009 * s, 0.0, 0.2)
		var tip: Vector3 = st[8]
		var td := Vector2(tip.x - (st[7] as Vector3).x, tip.z - (st[7] as Vector3).z).normalized()
		_fan(g, tip, td, 0.26 * s, 0.95 + rng.next() * 0.25, rng.next() < 0.7, rng.next())
		out.append(tip + Vector3(td.x, 0, td.y) * 0.13 * s)
	return out

static func _fan(g: Geo, at: Vector3, d: Vector2, R: float, th: float, notch: bool, rnd: float) -> void:
	var na := 36
	var nr := 8
	var b0 := g.v.size()
	for i in nr + 1:
		var t := float(i) / nr
		for j in na + 1:
			var s := float(j) / na * 2.0 - 1.0
			var a := s * th
			var r := R * t * (1.0 - (0.4 * exp(-pow(s / 0.09, 2.0)) if notch else 0.0)) * (1.0 + 0.025 * sin(s * 23.0 + rnd * 9.0) * t)
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

## a nodule (Mazon Creek): an ironstone concretion split in half — the flat oval face the leaf lies on, its edge
## rounding over into a domed back. rp.z: 0..1 across the face, 1..2 down the back (the slab shader's rind and crust)
static func _nodule(rng: Rng32, rx: float, rz: float, seed_v: int) -> Geo:
	var nz := FastNoiseLite.new()
	nz.seed = seed_v
	nz.frequency = 1.4
	var g := Geo.new()
	var na := 64
	var nr := 10
	var ns := 12
	var depth := rx * (0.5 + rng.next() * 0.15)
	for i in nr + ns + 1:
		for j in na + 1:
			var a := TAU * float(j) / na
			var wob := 1.0 + 0.05 * nz.get_noise_1d(a * 2.0) + 0.012 * nz.get_noise_1d(a * 9.0 + 40.0)
			var x := 0.0
			var z := 0.0
			var y := 0.0
			var r := 0.0
			if i <= nr:
				var t := float(i) / nr
				x = sin(a) * rx * t * wob
				z = cos(a) * rz * t * wob
				y = 0.003 * nz.get_noise_2d(x * 9.0, z * 9.0)
				if t > 0.9: y -= 0.014 * (t - 0.9) / 0.1
				r = t
			else:
				var t := float(i - nr) / ns
				var ph := t * PI * 0.5
				var k := cos(ph) * (1.0 + 0.03 * sin(ph * 2.0))
				x = sin(a) * rx * wob * k
				z = cos(a) * rz * wob * k
				y = -0.014 - depth * sin(ph) + 0.012 * nz.get_noise_2d(a * 6.0, t * 5.0) * sin(ph * 2.0)
				r = 1.0 + t
			g.v.append(Vector3(x, y, z))
			g.rp.append(Vector3(x, z, r))
	for i in nr + ns:
		for j in na:
			var p0 := i * (na + 1) + j
			var p1 := p0 + na + 1
			g.idx.append_array([p0, p0 + 1, p1, p0 + 1, p1 + 1, p1])
	return g.orient_out(Vector3(0, -depth * 0.4, 0))

## how far from p along d before leaving the slab's face (an ellipse a little inside its wobbling edge)
static func _reach(p: Vector3, d: Vector2, rx: float, rz: float, k := 0.84) -> float:
	var ax := rx * k
	var az := rz * k
	var qa := d.x * d.x / (ax * ax) + d.y * d.y / (az * az)
	var qb := 2.0 * (p.x * d.x / (ax * ax) + p.z * d.y / (az * az))
	var qc := p.x * p.x / (ax * ax) + p.z * p.z / (az * az) - 1.0
	var disc := qb * qb - 4.0 * qa * qc
	if disc < 0.0 or qa <= 0.0: return 0.0
	return maxf(0.0, (-qb + sqrt(disc)) / (2.0 * qa))

static func _inside(p: Vector3, rx: float, rz: float, k := 0.84) -> bool:
	return pow(p.x / (rx * k), 2) + pow(p.z / (rz * k), 2) < 1.0

## a fan palm (Sabalites, as Green River gives it): a stout stalk up from the slab's edge, and from its top a great fan
## of long pleated segments, a few torn short, running out to the edge of the stone
static func _palm(g: Geo, rng: Rng32, rx: float, rz: float) -> Array:
	var base := Vector3((rng.next() - 0.5) * rx * 0.3, 0, rz * 0.86)
	var dir := Vector2((rng.next() - 0.5) * 0.4, -1.0).normalized()
	var stalk := _curve(base, dir, rz * (0.5 + rng.next() * 0.15), (rng.next() - 0.5) * 0.3, 12)
	_stem(g, stalk, 0.055, 0.045, 0.0, 0.3)
	var hp: Vector3 = stalk[12]
	var hd := Vector2(hp.x - (stalk[11] as Vector3).x, hp.z - (stalk[11] as Vector3).z).normalized()
	var n := 15 + int(rng.next() * 8)
	var span := 2.4 + rng.next() * 0.8
	var out := [base, hp]
	for k in n:
		var a := -span * 0.5 + span * (float(k) + 0.5) / n + (rng.next() - 0.5) * 0.03
		var d := _rot(hd, a)
		var st := hp + Vector3(d.x, 0, d.y) * 0.02
		st.y = 0.0001 * k
		var l := minf(_reach(st, d, rx, rz, 0.9) * 0.98, rz * 1.15) * (0.85 + 0.15 * rng.next())
		if rng.next() < 0.12: l *= 0.4 + 0.35 * rng.next()
		if l < 0.08: continue
		_blade(g, st, d, l, 0.08 + rng.next() * 0.015, 0.3 + 0.7 * float(k) / n, rng.next(), 0.42, 0.3)
		if k == n / 2: out.append(st + Vector3(d.x, 0, d.y) * l * 0.6)
	return out

## Annularia: slender jointed stems, and at every joint a flat star of narrow leaves — the stars drift across the slab
static func _annularia(g: Geo, rng: Rng32, rx: float, rz: float) -> Array:
	var out := []
	var base := Vector3((rng.next() - 0.5) * rx * 0.5, 0, rz * 0.8)
	var dir := Vector2((rng.next() - 0.5) * 0.7, -1.0).normalized()
	var lines := []
	var main := _curve(base, dir, maxf(0.3, _reach(base, dir, rx, rz, 0.95) * 0.95), (rng.next() - 0.5) * 0.3, 24)
	lines.append(main)
	for k in 2 + int(rng.next() * 2):
		var t := 0.2 + 0.5 * float(k) / 3.0 + rng.next() * 0.08
		var at: Vector3 = main[int(t * 24.0)]
		var bd := _rot(dir, (0.55 + rng.next() * 0.35) * (1.0 if k % 2 == 0 else -1.0))
		var l := _reach(at, bd, rx, rz, 0.92) * (0.75 + rng.next() * 0.2)
		if l > 0.15: lines.append(_curve(at, bd, l, (rng.next() - 0.5) * 0.4, 16))
	for li in lines.size():
		var ln: Array = lines[li]
		_stem(g, ln, 0.013 if li == 0 else 0.009, 0.006, 0.0, 1.0)
		var seg := 0.12 + rng.next() * 0.03
		var tot := 0.0
		for i in ln.size() - 1:
			tot += (ln[i + 1] as Vector3).distance_to(ln[i])
		var m := int(tot / seg)
		for w in m:
			var i := int(float(w + 1) / (m + 1) * (ln.size() - 1))
			var at: Vector3 = ln[i]
			if not _inside(at, rx, rz, 0.78): continue
			var tg := Vector2((ln[mini(i + 1, ln.size() - 1)] as Vector3).x - (ln[maxi(i - 1, 0)] as Vector3).x, (ln[mini(i + 1, ln.size() - 1)] as Vector3).z - (ln[maxi(i - 1, 0)] as Vector3).z).normalized()
			var nb := 14 + int(rng.next() * 7)
			var ll := 0.06 + rng.next() * 0.025
			var turn := rng.next() * TAU
			at.y = 0.0003 * (w % 3)
			for j in nb:
				var a := turn + TAU * float(j) / nb + (rng.next() - 0.5) * 0.12
				var d := _rot(tg, a)
				# the star is a little longer across the stem than along it
				var side := absf(d.x * tg.y - d.y * tg.x)
				_blade(g, at, d, ll * (0.8 + 0.35 * side) * (0.9 + rng.next() * 0.2), 0.017, float(i) / ln.size(), rng.next(), 0.75)
			if out.size() < 4: out.append(at)
	return out

## a strip of scale-tree bark (Lepidodendron): rows of diamond leaf-cushions, a ragged broken piece of the trunk
static func _lepido(g: Geo, rng: Rng32, rx: float, rz: float) -> Array:
	var nz := FastNoiseLite.new()
	nz.seed = int(rng.next() * 9999.0)
	nz.frequency = 3.0
	var c := Vector3((rng.next() - 0.5) * rx * 0.15, 0, (rng.next() - 0.5) * rz * 0.15)
	var d := _rot(Vector2(0, -1), (rng.next() - 0.5) * 0.5)
	var p := Vector2(-d.y, d.x)
	var L := rz * 2.0 * 0.76
	var W := rx * 2.0 * (0.55 + rng.next() * 0.12)
	var nx := 24
	var ny := 10
	var b0 := g.v.size()
	var rnd := rng.next()
	var c2 := Vector2(c.x, c.z)
	for i in nx + 1:
		var t := float(i) / nx
		var wl := 1.0 + 0.12 * nz.get_noise_2d(t * 3.0, 1.0)
		var wr := 1.0 + 0.12 * nz.get_noise_2d(t * 3.0, 9.0)
		for j in ny + 1:
			var s := float(j) / ny * 2.0 - 1.0
			var ww := (wl if s < 0.0 else wr) * W * 0.5
			# the ends broken off ragged, not square
			var tt := t + (0.05 * nz.get_noise_2d(s * 2.0, 30.0 + t) if i == 0 or i == nx else 0.0)
			var q := c2 + d * (tt - 0.5) * L + p * s * ww
			# keep it on the stone
			var off := q - c2
			if off.length() > 0.0001:
				var lim := _reach(c, off.normalized(), rx, rz, 0.88)
				if off.length() > lim: q = c2 + off.normalized() * lim
			g.v.append(Vector3(q.x, 0, q.y))
			# cushion units: a diamond is 2 along by 2 across — longer than wide on the stone
			g.rp.append(Vector3((tt - 0.5) * L / 0.1, s * ww / 0.062, t))
			g.col.append(Color(0, rnd, 0.7, 1))
	for i in nx:
		for j in ny:
			var a := b0 + i * (ny + 1) + j
			var b2 := a + ny + 1
			g.idx.append_array([a, b2, a + 1, a + 1, b2, b2 + 1])
	var dv := Vector3(d.x, 0, d.y)
	return [c, c + dv * L * 0.3, c - dv * L * 0.3]

## a visitor on the same slab, where the plant left room: a dragonfly with its wings spread, or a little fish
static func _guest(g: Geo, rng: Rng32, kind: String, rx: float, rz: float) -> Array:
	# the emptiest spot: the farthest from everything already on the film
	var best := Vector3.ZERO
	var bd := -1.0
	for k in 40:
		var a := rng.next() * TAU
		var r := sqrt(rng.next()) * 0.6
		var q := Vector3(sin(a) * rx * r, 0, cos(a) * rz * r)
		var md := 99.0
		for i in range(0, g.v.size(), 2):
			md = minf(md, Vector2(g.v[i].x - q.x, g.v[i].z - q.z).length())
		if md > bd:
			bd = md
			best = q
	var d := _rot(Vector2(0, -1), rng.next() * TAU)
	var pp := Vector2(-d.y, d.x)
	var dv := Vector3(d.x, 0, d.y)
	var pv := Vector3(pp.x, 0, pp.y)
	if kind == "dragonfly":
		var s := minf(rx, rz) * 0.95
		var o := best
		var wy := Vector3(0, 0.0012, 0)
		var by := Vector3(0, 0.0018, 0)
		for side in [-1.0, 1.0]:
			for fore in [true, false]:
				var wd := _rot(d, float(side) * (1.42 if fore else 1.78))
				var lead := Vector2(-wd.y, wd.x).dot(d) > 0.0
				_blade(g, o + dv * (0.13 if fore else 0.075) * s + wy, wd, 0.42 * s, (0.08 if fore else 0.1) * s, 0.5, rng.next(), 0.5, 0.8, lead)
		_blade(g, o + dv * 0.06 * s + by, -d, 0.44 * s, 0.032 * s, 0.4, rng.next(), 0.3, 0.4)
		_blade(g, o + dv * 0.05 * s + by, d, 0.13 * s, 0.07 * s, 0.6, rng.next(), 0.6, 0.4)
		_blade(g, o + dv * 0.17 * s + by, d, 0.055 * s, 0.08 * s, 0.7, rng.next(), 1.0, 0.4)
		return [o + dv * 0.1 * s, o + (dv * 0.1 + pv * 0.3) * s]
	# a fish: head forward, its tail fan forked, fins on its back and belly
	var sf := minf(rx, rz) * 0.85
	var head := best + dv * 0.26 * sf
	var fy := Vector3(0, 0.0012, 0)
	_fan(g, best - dv * 0.22 * sf + fy, -d, 0.13 * sf, 0.55, true, rng.next())
	_fan(g, best + dv * 0.02 * sf + pv * 0.055 * sf + fy, (pp * 0.75 - d * 0.65).normalized(), 0.075 * sf, 0.45, false, rng.next())
	_fan(g, best - dv * 0.08 * sf - pv * 0.05 * sf + fy, (-pp * 0.75 - d * 0.65).normalized(), 0.06 * sf, 0.4, false, rng.next())
	_fan(g, best + dv * 0.14 * sf - pv * 0.03 * sf + fy * 1.5, (-pp * 0.4 - d * 0.9).normalized(), 0.05 * sf, 0.3, false, rng.next())
	_blade(g, head + Vector3(0, 0.0018, 0), -d, 0.5 * sf, 0.17 * sf, 0.5, rng.next(), 0.55, 0.9)
	return [best, head]

## a ribbon along a curve: full width w0 at its start narrowing to w1, the end rounded; for a whole pinna (COLOR.b 0.2,
## COLOR.a its number of lobes / 64 — the film shader cuts the margin into lobes)
static func _ribbon(g: Geo, pts: Array, w0: float, w1: float, u: float, rnd: float, lobes: float) -> void:
	var b0 := g.v.size()
	var n := pts.size()
	for i in n:
		var a: Vector3 = pts[maxi(i - 1, 0)]
		var c: Vector3 = pts[mini(i + 1, n - 1)]
		var d := Vector2(c.x - a.x, c.z - a.z).normalized()
		var p := Vector2(-d.y, d.x)
		var t := float(i) / (n - 1)
		var hw := lerpf(w0, w1, t) * 0.5 * (sqrt(maxf(0.0, 1.0 - pow(maxf(0.0, (t - 0.8) / 0.2), 2.0))) if t > 0.8 else 1.0)
		hw = maxf(hw, 0.0005)
		var q: Vector3 = pts[i]
		for s in [-1.0, 0.0, 1.0]:
			g.v.append(Vector3(q.x + p.x * hw * float(s), q.y + 0.0004, q.z + p.y * hw * float(s)))
			g.rp.append(Vector3(t, float(s), u))
			g.col.append(Color(0, rnd, 0.2, lobes))
	for i in n - 1:
		var a := b0 + i * 3
		for s in 2:
			g.idx.append_array([a + s, a + 3 + s, a + s + 1, a + s + 1, a + 3 + s, a + 4 + s])

## manganese dendrites: black mossy trees branching in from the slab's edge along the bedding plane, finer and finer
static func _dendrites(g: Geo, rng: Rng32, rx: float, rz: float) -> Array:
	var out := []
	var nroot := 2 + int(rng.next() * 3)
	var a0 := rng.next() * TAU
	for k in nroot:
		var a := a0 + (rng.next() - 0.5) * 1.6 + (PI if k % 2 else 0.0)
		var at := Vector3(sin(a) * rx * 0.86, 0, cos(a) * rz * 0.86)
		var d := Vector2(-sin(a), -cos(a)).rotated((rng.next() - 0.5) * 0.6)
		_dendro(g, rng, at, d, (0.2 + rng.next() * 0.14) * minf(rx, rz), 0.02, 0, rx, rz)
		out.append(at + Vector3(d.x, 0, d.y) * 0.12)
	return out

static func _dendro(g: Geo, rng: Rng32, at: Vector3, d: Vector2, l: float, w: float, depth: int, rx: float, rz: float) -> void:
	var pts := [at]
	var p := at
	var dd := d
	for i in 6:
		dd = dd.rotated((rng.next() - 0.5) * 0.7)
		p += Vector3(dd.x, 0, dd.y) * l / 6.0
		pts.append(p)
	_stem(g, pts, w, w * 0.6, 0.0, 1.0)
	# a little blot where twigs crowd
	if depth >= 3:
		_fan(g, p, dd, w * (2.5 + rng.next() * 2.0), PI, false, rng.next())
	if depth >= 5 or not _inside(p, rx, rz, 0.95): return
	var nk := 3 + int(rng.next() * 2)
	for k in nk:
		var t := 0.25 + 0.75 * float(k + 1) / nk
		var q: Vector3 = pts[int(t * 6.0)]
		var side := 1.0 if k % 2 == 0 else -1.0
		_dendro(g, rng, q, dd.rotated(side * (0.25 + rng.next() * 0.45)), l * (0.5 + rng.next() * 0.15), w * 0.66, depth + 1, rx, rz)
