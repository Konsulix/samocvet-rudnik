class_name SpecFlower
extends RefCounted
## Inclusions: something whole held in clear stone — a smooth tumbled pebble (shaders/amber.gdshader) of clear or
## smoky quartz (ice-like cracks flashing white, a few bubbles) or of amber / copal (its resin run in flow lines,
## specks of bark, sun spangles, a weathered crust). What it holds:
##   a flower — star, rose, daisy, bell, blossom or poppy; petals of their own shape (shaders/petal.gdshader: colour,
##              an eye at the base, a sheen on the rims, veins, spots or stripes), stamens tipped with gold, leaves;
##   an insect — ant, beetle, fly, mosquito or spider, built from its body parts, legs jointed and splayed as it
##              was caught, wings see-through (shaders/wing.gdshader).
## Two finds use it: "flower_quartz" (a flower, in quartz mostly) and "amber" (an insect mostly).

const U := preload("res://scripts/specimen/spec_util.gd")
const PETAL := preload("res://shaders/petal.gdshader")
const WING := preload("res://shaders/wing.gdshader")
const AMBER := preload("res://shaders/amber.gdshader")
## amber's colour: how fast it swallows red, green and blue along the way through it (per unit of the stone's
## radius) — thin it is pale, thick it deepens: lemon, honey, cognac, cherry
const TONES := {lemon = [Vector3(0.02, 0.14, 1.5), 1.5], honey = [Vector3(0.04, 0.32, 2.2), 4.0],
	cognac = [Vector3(0.15, 0.75, 3.0), 3.0], cherry = [Vector3(0.5, 1.8, 3.5), 1.0]}

## petal colours: [name, base, sheen/rim, eye, eye reach, spots, stripes, sheen strength]
const LOOKS := [
	["bronze", 0x16100c, 0xb8763c, 0x16100c, 0.0, 0.0, 0.0, 1.0],
	["copper", 0x1e0c08, 0xc8643a, 0x1e0c08, 0.0, 0.0, 0.0, 1.0],
	["crimson", 0x8a1020, 0xe0604a, 0x1a0408, 0.3, 0.0, 0.0, 0.5],
	["ivory", 0xe2dccc, 0xfaf2de, 0xe0b040, 0.22, 0.0, 0.0, 0.4],
	["blush", 0xe8b4c0, 0xf8e0e6, 0xb04a6a, 0.25, 0.0, 0.6, 0.4],
	["indigo", 0x1a1a4a, 0x8a7ad8, 0x0a0a1a, 0.2, 0.0, 0.0, 0.8],
	["golden", 0xe0a820, 0xf8d860, 0x6a2a10, 0.15, 0.0, 0.0, 0.5],
	["violet", 0x6a3a9a, 0xc8a8e8, 0x2a1040, 0.3, 0.8, 0.0, 0.5],
	["scarlet", 0xc82810, 0xf06a3a, 0x100808, 0.25, 0.0, 0.0, 0.4],
	["azure", 0x3a6ac8, 0xa8c8f0, 0xf0f0f0, 0.15, 0.0, 0.0, 0.5],
]
## flower forms and insects: [name, weight]
const FORMS := [["star", 3.0], ["rose", 2.0], ["daisy", 2.0], ["bell", 1.5], ["blossom", 2.0], ["poppy", 1.5]]
const INSECTS := [["ant", 3.0], ["beetle", 2.0], ["fly", 2.5], ["mosquito", 2.0], ["spider", 1.5]]
## hosts: [name, tint (linear), absorb, fractures, veils, bubbles, flow, debris, frost, inner glow]
const HOSTS := {quartz = "clear quartz", smoky = "smoky quartz", amber = "Baltic amber", copal = "copal"}

static func genes(seed_v: int, sid: String, tr: Array, o: Dictionary = {}) -> Dictionary:
	var rng := Rng32.new((seed_v * 2246822519 + 77) % 4294967296)
	var g := {kind = sid}
	if sid == "amber":
		g.host = Stones.pick_w([["amber", 4.0], ["copal", 1.5]], rng)
		g.content = Stones.pick_w([["insect", 7.0], ["flower", 2.0], ["fern", 1.2], ["feather", 1.0]], rng)
	else:
		g.host = Stones.pick_w([["quartz", 5.0], ["smoky", 2.0], ["amber", 1.0]], rng)
		g.content = "flower"
	g.bloom = Stones.pick_w(FORMS, rng)
	g.look = int(rng.next() * LOOKS.size())
	g.insect = Stones.pick_w(INSECTS, rng)
	g.petals = 5 + int(rng.next() * 3)
	g.leaves = int(Stones.pick_w([[0, 2.0], [1, 2.0], [2, 2.0], [3, 1.0]], rng))
	g.gold = (rng.next() < 0.3 or "goldfleck" in tr) and g.host != "amber" and g.host != "copal"
	g.seed = int(rng.next() * 100000.0)
	g.bare = false   # showcases: what it holds, without its stone
	# resin: its colour, sun spangles (disc cracks that flash gold), a weathered crust left on, a polished window,
	# milky clouds
	var tw := []
	for k: String in TONES: tw.append([k, float(TONES[k][1])])
	g.tone = "lemon" if g.host == "copal" else Stones.pick_w(tw, rng)
	g.spangle = rng.next() < 0.3
	g.crust = 0.0 if rng.next() < 0.6 else 0.2 + rng.next() * 0.6
	g.window = rng.next() < 0.4
	g.cloud = 0.0 if rng.next() < 0.8 else 0.3 + rng.next() * 0.5
	if g.host == "copal": g.cloud = maxf(float(g.cloud), 0.25)
	for k in ["host", "content", "bloom", "look", "insect", "petals", "leaves", "gold", "bare", "tone", "spangle", "crust", "window", "cloud"]:
		if o.has(k): g[k] = o[k]
	if g.host == "copal" and not o.has("tone"): g.tone = "lemon"
	return g

static func accents(g: Dictionary) -> Array:
	var out := [{flower = "flower", insect = "insect", fern = "fern", feather = "feather"}.get(g.content, "insect"), "stone"]
	if g.content == "flower" and int(g.leaves) > 0: out.append("leaves")
	if g.gold: out.append("gold_dust")
	if g.host in ["amber", "copal"] and g.get("spangle", false): out.append("spangles")
	return out

static func gene_name(id: String, g: Dictionary) -> String:
	match id:
		"flower": return "%s %s" % [LOOKS[int(g.look)][0], {star = "star flower", rose = "rose", daisy = "daisy", bell = "bellflower",
			blossom = "blossom", poppy = "poppy"}.get(g.bloom, "flower")]
		"insect": return {ant = "ant", beetle = "beetle", fly = "fly", mosquito = "mosquito", spider = "spider"}.get(g.insect, "insect")
		"stone": return String(HOSTS[g.host]) if not g.host == "amber" else "%s Baltic amber" % g.get("tone", "honey")
		"spangles": return "sun spangles"
		"leaves": return "leaves"
		"fern": return "fern frond"
		"feather": return "feather"
		"gold_dust": return "gold dust"
	return ""

# ---------------------------------------------------------------- petals and flowers

## a petal: base at the origin, running out along +y, its face towards +z. o: tip ("point", "round", "notch",
## "strap"), cup (across), bend (back near the tip), wave (rim), crinkle (all over)
static func _petal(rng: Rng32, ln: float, wd: float, o: Dictionary) -> Geo:
	var g := Geo.new()
	var nt := 22
	var ns := 12
	var ph := rng.next() * TAU
	var tip: String = o.get("tip", "point")
	var cup: float = o.get("cup", 0.6)
	var bend: float = o.get("bend", -0.2)
	var wave: float = o.get("wave", 0.05)
	var crinkle: float = o.get("crinkle", 0.0)
	for i in nt + 1:
		var t := float(i) / nt
		var w: float
		match tip:
			"round", "notch": w = wd * pow(sin(PI * pow(t, 0.62)), 0.5)
			"strap": w = wd * smoothstep(0.0, 0.12, t) * (1.0 - 0.5 * smoothstep(0.8, 1.0, t)) * (0.4 if t >= 0.999 else 1.0)
			_: w = wd * pow(sin(PI * pow(t, 0.8)), 0.75)
		w *= 0.3 + 0.7 * smoothstep(0.0, 0.22, t)
		for j in ns + 1:
			var s := float(j) / ns * 2.0 - 1.0
			var x := s * w
			var y := t * ln
			if tip == "notch":
				y -= ln * 0.1 * (1.0 - absf(s)) * smoothstep(0.75, 1.0, t)
			var z := -cup * x * x / maxf(wd, 0.001) + bend * t * t * ln + wave * ln * sin(t * 9.0 + ph) * s * s
			z += crinkle * ln * 0.04 * sin(s * 9.0 + t * 7.0 + ph) * t
			g.v.append(Vector3(x, y, z))
			g.rp.append(Vector3(t, s, 0))
	for i in nt:
		for j in ns:
			var p0 := i * (ns + 1) + j
			var p1 := p0 + ns + 1
			g.idx.append_array([p0, p1, p0 + 1, p0 + 1, p1, p1 + 1])
	return g

static func _petal_mat(look: Array, seed_v: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = PETAL
	m.set_shader_parameter("c_base", Color.hex(int(look[1]) << 8 | 0xff))
	m.set_shader_parameter("c_rim", Color.hex(int(look[2]) << 8 | 0xff))
	m.set_shader_parameter("c_eye", Color.hex(int(look[3]) << 8 | 0xff))
	m.set_shader_parameter("eye_k", look[4])
	m.set_shader_parameter("spots", look[5])
	m.set_shader_parameter("stripes", look[6])
	m.set_shader_parameter("sheen", look[7])
	m.set_shader_parameter("seed", seed_v)
	return m

## one whorl of petals round the flower's axis (+z): n of them, each tipped up out of the plane by `tilt`
static func _whorl(parent: Node3D, rng: Rng32, mat: Material, n: int, ln: float, wd: float, tilt: float, off: float, o: Dictionary, marks: Array) -> void:
	for k in n:
		var ang := (float(k) + off + (rng.next() - 0.5) * 0.2) / maxf(n, 1) * TAU
		var pg := _petal(rng, ln * (0.88 + rng.next() * 0.24), wd * (0.85 + rng.next() * 0.3), o)
		var bs := Basis(Vector3.BACK, ang) * Basis(Vector3.RIGHT, tilt + (rng.next() - 0.5) * 0.2)
		var mi := U.mesh(pg, mat, parent, Vector3.ZERO, bs)
		mi.set_meta("col", true)
		if marks.size() < 2 and k % 2 == 0:
			marks.append(mi.transform * Vector3(0, ln * 0.6, 0))

## stamens fanning out of the middle, gold-tipped
static func _stamens(parent: Node3D, rng: Rng32, n: int, h: float, spread: float) -> void:
	var gold := SpecMat.make({col = SpecMat.lin(0xd8a440), metal = 0.6, rough = 0.35})
	var stalk := SpecMat.make({col = SpecMat.lin(0xb8a070), rough = 0.5})
	var cyl := Geo.cylinder(1, 1, 1, 5).translate(0, 0.5, 0)
	var ball := Geo.icosa(1.0, 1)
	for k in n:
		var a := rng.next() * TAU
		var lean := spread * (0.4 + rng.next() * 0.6)
		var d := (Basis(Vector3.BACK, a) * Basis(Vector3.RIGHT, PI / 2 - lean)) * Vector3.UP
		var hh := h * (0.75 + rng.next() * 0.4)
		var at := Vector3(cos(a), sin(a), 0) * 0.02 + Vector3(0, 0, 0.02)
		var bs := Basis(U.quat_to(Vector3.UP, d))
		U.mesh(cyl, stalk, parent, at, bs * Basis.from_scale(Vector3(0.005, hh, 0.005)))
		U.mesh(ball, gold, parent, at + d * hh, bs * Basis.from_scale(Vector3(0.014, 0.024, 0.014)))

## the flower, its axis along +z, about 0.8 across
static func _flower(parent: Node3D, rng: Rng32, f: Dictionary) -> Array:
	var marks := []
	var look: Array = LOOKS[int(f.look)]
	var pm := _petal_mat(look, float(int(f.seed) % 97))
	var np: int = f.petals
	match f.bloom:
		"rose":
			# a spiral of rounded petals, cupped, the inner ones ever more upright and smaller
			var n := 22
			for k in n:
				var u := float(k) / n
				var ang := k * 2.4
				var ln := lerpf(0.42, 0.16, u)
				var pg := _petal(rng, ln, ln * 0.85, {tip = "round", cup = 1.4, bend = lerpf(-0.35, 0.1, u), wave = 0.06})
				var bs := Basis(Vector3.BACK, ang) * Basis(Vector3.RIGHT, lerpf(0.5, 1.45, u))
				var mi := U.mesh(pg, pm, parent, Vector3(cos(ang), sin(ang), 0) * 0.02 * (1.0 - u), bs)
				mi.set_meta("col", true)
				if k == 2: marks.append(mi.transform * Vector3(0, ln * 0.6, 0))
		"daisy":
			# many narrow strap petals round a big domed disc of florets
			_whorl(parent, rng, pm, 18 + int(rng.next() * 10), 0.42, 0.055, 0.1, 0.0, {tip = "strap", cup = 0.3, bend = -0.1, wave = 0.02}, marks)
			var dm := SpecMat.make({col = SpecMat.lin(0xc89020 if rng.next() < 0.6 else 0x4a2a10), rough = 0.85, grain = 1.0})
			U.mesh(Geo.icosa(1.0, 3), dm, parent, Vector3(0, 0, 0.02), Basis.from_scale(Vector3(0.13, 0.13, 0.07)))
		"bell":
			# petals joined into a cup, flaring at the rims
			_whorl(parent, rng, pm, np, 0.42, 0.2, 1.15, 0.0, {tip = "round", cup = 0.5, bend = -0.55, wave = 0.04}, marks)
			_stamens(parent, rng, 6, 0.2, 0.15)
		"blossom":
			# five round, notched petals opening flat, a crowd of stamens
			_whorl(parent, rng, pm, 5, 0.36, 0.3, 0.2, 0.0, {tip = "notch", cup = 0.35, bend = -0.05, wave = 0.05}, marks)
			_stamens(parent, rng, 26 + int(rng.next() * 12), 0.13, 0.8)
		"poppy":
			# four wide crinkled petals, a dark eye, a crowned seed head
			_whorl(parent, rng, pm, 4, 0.44, 0.42, 0.45, 0.0, {tip = "round", cup = 0.7, bend = -0.15, wave = 0.08, crinkle = 1.0}, marks)
			U.mesh(Geo.icosa(1.0, 2), SpecMat.make({col = SpecMat.lin(0x4a5a30), rough = 0.6}), parent, Vector3(0, 0, 0.05), Basis.from_scale(Vector3(0.06, 0.06, 0.06)))
			_stamens(parent, rng, 30, 0.1, 1.0)
		_:
			# a star: pointed petals in two whorls
			_whorl(parent, rng, pm, np, 0.48, 0.18, 0.35, 0.0, {tip = "point", cup = 0.7, bend = -0.25, wave = 0.05}, marks)
			_whorl(parent, rng, pm, np, 0.32, 0.12, 0.85, 0.5, {tip = "point", cup = 0.6, bend = -0.1, wave = 0.04}, marks)
			U.mesh(Geo.icosa(1.0, 2), SpecMat.make({col = SpecMat.lin(0x3a2a14), rough = 0.6}), parent, Vector3(0, 0, 0.02), Basis.from_scale(Vector3(0.06, 0.06, 0.04)))
			_stamens(parent, rng, 16 + int(rng.next() * 8), 0.2, 0.6)
	# leaves behind it, and a bit of stem
	if int(f.leaves) > 0:
		var lm := ShaderMaterial.new()
		lm.shader = PETAL
		var greens := [[0x2a4a1a, 0x6a8a3a], [0x1a3a2a, 0x5a8a6a], [0x3a3a1a, 0x8a8a4a]]
		var gc: Array = greens[int(rng.next() * greens.size())]
		lm.set_shader_parameter("c_base", Color.hex(int(gc[0]) << 8 | 0xff))
		lm.set_shader_parameter("c_rim", Color.hex(int(gc[1]) << 8 | 0xff))
		lm.set_shader_parameter("leaf", 1.0)
		lm.set_shader_parameter("seed", float(int(f.seed) % 89))
		for k in int(f.leaves):
			var ang := rng.next() * TAU
			var pg := _petal(rng, 0.55 + rng.next() * 0.2, 0.17, {tip = "point", cup = 0.3, bend = -0.15, wave = 0.04})
			var bs := Basis(Vector3.BACK, ang) * Basis(Vector3.RIGHT, -0.2 - rng.next() * 0.3)
			var mi := U.mesh(pg, lm, parent, Vector3(0, 0, -0.06), bs)
			mi.set_meta("col", true)
		var stem := SpecMat.make({col = SpecMat.lin(0x4a5a2a), rough = 0.6})
		U.mesh(Geo.cylinder(1, 1, 1, 6).translate(0, 0.5, 0), stem, parent, Vector3(0, 0, -0.02),
			Basis(Vector3.RIGHT, -PI / 2 - 0.6) * Basis.from_scale(Vector3(0.018, 0.4, 0.018)))
	return marks

# ---------------------------------------------------------------- insects

static func _ell(parent: Node3D, m: Material, at: Vector3, r: Vector3, bs := Basis.IDENTITY) -> void:
	U.mesh(Geo.icosa(1.0, 2), m, parent, at, bs * Basis.from_scale(r))

static func _seg(parent: Node3D, m: Material, a: Vector3, b: Vector3, r: float) -> void:
	var d := b - a
	if d.length() < 1e-4:
		return
	U.mesh(Geo.cylinder(0.75, 1.0, 1, 5).translate(0, 0.5, 0), m, parent, a, Basis(U.quat_to(Vector3.UP, d.normalized())) * Basis.from_scale(Vector3(r, d.length(), r)))

## a jointed leg from `at`, reaching out (`out`: sideways and forward/back) — up to the knee, down to the foot
static func _leg(parent: Node3D, m: Material, rng: Rng32, at: Vector3, out: Vector3, ls: Array, r: float, lift: float) -> void:
	var up := Vector3.UP
	var j1: Vector3 = at + (out * cos(lift) + up * sin(lift)).normalized() * float(ls[0])
	var dn := lift * 0.9 + 0.5 + (rng.next() - 0.5) * 0.4
	var j2: Vector3 = j1 + (out * cos(dn) - up * sin(dn)).normalized() * float(ls[1])
	var j3: Vector3 = j2 + (out * 0.7 - up * 0.5).normalized() * float(ls[2])
	_seg(parent, m, at, j1, r)
	_seg(parent, m, j1, j2, r * 0.8)
	_seg(parent, m, j2, j3, r * 0.55)
	U.mesh(Geo.icosa(1.0, 1), m, parent, j1, Basis.from_scale(Vector3.ONE * r * 1.15))

## a wing from its root at `at`, lying back over the body, spread `ang` to its side, tipped up a little
static func _wing(parent: Node3D, rng: Rng32, at: Vector3, ln: float, wd: float, ang: float, side: float, seed_v: float) -> void:
	var wm := ShaderMaterial.new()
	wm.shader = WING
	wm.set_shader_parameter("seed", seed_v + side)
	var pg := _petal(rng, ln, wd, {tip = "round", cup = 0.05, bend = 0.0, wave = 0.01})
	# the petal runs along +y with its face +z: lay it along -x (back), face up, then swing it out to its side
	var bs := Basis(Vector3.UP, side * ang) * Basis(Vector3.BACK, PI / 2) * Basis(Vector3.RIGHT, -PI / 2 + 0.2)
	var mi := U.mesh(pg, wm, parent, at, bs)
	mi.set_meta("col", true)

## the insect, head towards +x, back up +y; about 1 long
static func _insect(parent: Node3D, rng: Rng32, f: Dictionary) -> Array:
	var kind: String = f.insect
	var cols := {ant = [0x3a1a10, 0.3], beetle = [[0x1a3a1a, 0x2a1a3a, 0x3a2a10, 0x0e0e0e][int(rng.next() * 4)], 0.5],
		fly = [0x1a1a1a, 0.2], mosquito = [0x3a3028, 0.1], spider = [0x2a2018, 0.15]}
	var cv: Array = cols.get(kind, [0x2a1a10, 0.2])
	var ch := SpecMat.make({col = SpecMat.lin(int(cv[0])), metal = cv[1], rough = 0.28, coat = 0.6, coat_r = 0.1})
	var leg_m := SpecMat.make({col = SpecMat.lin(int(cv[0])) * 1.3, rough = 0.4, coat = 0.3})
	var sd := float(int(f.seed) % 97)
	match kind:
		"ant":
			_ell(parent, ch, Vector3(-0.32, 0.0, 0), Vector3(0.22, 0.16, 0.16))
			_ell(parent, ch, Vector3(-0.08, 0.03, 0), Vector3(0.05, 0.06, 0.045))
			_ell(parent, ch, Vector3(0.08, 0.05, 0), Vector3(0.16, 0.07, 0.07), Basis(Vector3.BACK, 0.15))
			_ell(parent, ch, Vector3(0.32, 0.07, 0), Vector3(0.1, 0.09, 0.085))
			for s in [-1.0, 1.0]:
				_seg(parent, leg_m, Vector3(0.4, 0.04, s * 0.03), Vector3(0.46, 0.0, s * 0.06), 0.012)   # mandibles
				var e := Vector3(0.38, 0.13, s * 0.04)
				var k1 := e + Vector3(0.02, 0.15, s * 0.05)
				_seg(parent, leg_m, e, k1, 0.008)
				_seg(parent, leg_m, k1, k1 + Vector3(0.18, -0.02, s * 0.08), 0.007)
				for i in 3:
					var x: float = [0.15, 0.08, 0.0][i]
					var fw: float = [0.7, 0.05, -0.75][i]
					_leg(parent, leg_m, rng, Vector3(x, 0.0, s * 0.05), Vector3(fw, 0, s).normalized(), [0.2, 0.24, 0.16], 0.013, 0.6)
		"beetle":
			_ell(parent, ch, Vector3(-0.12, 0.06, 0), Vector3(0.34, 0.17, 0.22))
			_ell(parent, ch, Vector3(0.24, 0.05, 0), Vector3(0.1, 0.1, 0.16))
			_ell(parent, ch, Vector3(0.36, 0.03, 0), Vector3(0.07, 0.06, 0.09))
			for s in [-1.0, 1.0]:
				var e := Vector3(0.4, 0.05, s * 0.05)
				_seg(parent, leg_m, e, e + Vector3(0.12, 0.06, s * 0.1), 0.008)
				_seg(parent, leg_m, e + Vector3(0.12, 0.06, s * 0.1), e + Vector3(0.22, 0.05, s * 0.16), 0.01)
				for i in 3:
					var x: float = [0.24, 0.05, -0.1][i]
					var fw: float = [0.6, 0.0, -0.7][i]
					_leg(parent, leg_m, rng, Vector3(x, -0.02, s * 0.1), Vector3(fw, 0, s).normalized(), [0.13, 0.15, 0.1], 0.017, 0.35)
		"fly", "mosquito":
			var slim := kind == "mosquito"
			_ell(parent, ch, Vector3(0.05, 0.05, 0), Vector3(0.09, 0.08, 0.07) if slim else Vector3(0.14, 0.12, 0.12))
			_ell(parent, ch, Vector3(0.18 if slim else 0.22, 0.04, 0), Vector3(0.05, 0.05, 0.05) if slim else Vector3(0.07, 0.08, 0.1))
			_ell(parent, ch, Vector3(-0.27 if slim else -0.2, 0.02, 0), Vector3(0.26, 0.045, 0.045) if slim else Vector3(0.18, 0.1, 0.11))
			if not slim:
				var eye := SpecMat.make({col = SpecMat.lin(0x6a1a0a), rough = 0.25, coat = 0.8})
				for s in [-1.0, 1.0]: _ell(parent, eye, Vector3(0.24, 0.06, s * 0.065), Vector3(0.05, 0.06, 0.045))
			else:
				_seg(parent, leg_m, Vector3(0.22, 0.03, 0), Vector3(0.48, -0.04, 0), 0.006)
			for s in [-1.0, 1.0]:
				_wing(parent, rng, Vector3(0.06, 0.12, s * 0.04), 0.42, 0.06 if slim else 0.14, 0.35, s, sd)
				for i in 3:
					var x: float = [0.12, 0.05, -0.02][i]
					var fw: float = [0.7, 0.05, -0.7][i]
					var ls: Array = [0.3, 0.36, 0.3] if slim else [0.15, 0.17, 0.12]
					_leg(parent, leg_m, rng, Vector3(x, -0.02, s * 0.03), Vector3(fw, 0, s).normalized(), ls, 0.006 if slim else 0.011, 0.5)
		"spider":
			_ell(parent, ch, Vector3(0.12, 0.05, 0), Vector3(0.14, 0.08, 0.12))
			_ell(parent, ch, Vector3(-0.2, 0.08, 0), Vector3(0.2, 0.16, 0.17))
			for s in [-1.0, 1.0]:
				for i in 4:
					var fw: float = [0.9, 0.35, -0.3, -0.85][i]
					_leg(parent, leg_m, rng, Vector3(0.14 - i * 0.03, 0.04, s * 0.06), Vector3(fw, 0, s).normalized(), [0.24, 0.28, 0.22], 0.014, 0.9)
	return [Vector3(0.0, 0.12, 0)]

# ---------------------------------------------------------------- fern, feather

## a fern frond: a curving stalk, leaflets in pairs along it, smaller towards the tip
static func _fern(parent: Node3D, rng: Rng32, f: Dictionary) -> Array:
	var lm := ShaderMaterial.new()
	lm.shader = PETAL
	lm.set_shader_parameter("c_base", Color.hex(0x3a4a1aff if rng.next() < 0.6 else 0x5a4a1aff))
	lm.set_shader_parameter("c_rim", Color.hex(0x8a9a4aff))
	lm.set_shader_parameter("leaf", 1.0)
	lm.set_shader_parameter("seed", float(int(f.seed) % 89))
	var stalk := SpecMat.make({col = SpecMat.lin(0x4a4020), rough = 0.6})
	var n := 13
	var p := Vector3(-0.55, -0.1, 0)
	var d := Vector3(1, 0.25, 0).normalized()
	var curl := 0.08 + rng.next() * 0.06
	for k in n:
		var t := float(k) / n
		var step := 0.085
		var q := p + d * step
		_seg(parent, stalk, p, q, 0.012 * (1.0 - t * 0.6))
		var side := Vector3(-d.y, d.x, 0)
		var ln := 0.3 * (1.0 - t * 0.75) * (0.9 + rng.next() * 0.2)
		for s in [-1.0, 1.0]:
			var pg := _petal(rng, ln, ln * 0.22, {tip = "point", cup = 0.25, bend = -0.1, wave = 0.05})
			var dir: Vector3 = (side * float(s) + d * 0.45).normalized()
			var bs := Basis(U.quat_to(Vector3.UP, dir)) * Basis(Vector3.UP, (rng.next() - 0.5) * 0.4)
			var mi := U.mesh(pg, lm, parent, q, bs)
			mi.set_meta("col", true)
		p = q
		d = d.rotated(Vector3.BACK, curl * (0.5 + t))
	return [Vector3(0.0, 0.15, 0.02)]

## a feather: a shaft, its vane of barbs either side, banded; the down at its foot
static func _feather(parent: Node3D, rng: Rng32, f: Dictionary) -> Array:
	var cols := [[0x5a3a20, 0xe8dcc8], [0x2a2a2a, 0xd8d8d8], [0x8a5a30, 0x3a2410], [0x3a4a6a, 0xa8c0d8]]
	var cc: Array = cols[int(rng.next() * cols.size())]
	var fm := ShaderMaterial.new()
	fm.shader = PETAL
	fm.set_shader_parameter("c_base", Color.hex(int(cc[0]) << 8 | 0xff))
	fm.set_shader_parameter("c_rim", Color.hex(int(cc[1]) << 8 | 0xff))
	fm.set_shader_parameter("c_eye", Color.hex(int(cc[1]) << 8 | 0xff))
	fm.set_shader_parameter("eye_k", 0.25)
	fm.set_shader_parameter("stripes", 0.8)
	fm.set_shader_parameter("sheen", 0.3)
	fm.set_shader_parameter("seed", float(int(f.seed) % 89))
	var ln := 1.05
	# the vane: a long narrow blade, waved and split in places (barbs pulled apart)
	var pg := _petal(rng, ln, 0.17, {tip = "point", cup = 0.15, bend = -0.08, wave = 0.12, crinkle = 1.5})
	var bs := Basis(Vector3.BACK, -PI / 2 + 0.3)
	var mi := U.mesh(pg, fm, parent, Vector3(-0.5, -0.15, 0), bs)
	mi.set_meta("col", true)
	var shaft := SpecMat.make({col = SpecMat.lin(0xe8e0d0), rough = 0.4})
	_seg(parent, shaft, Vector3(-0.62, -0.19, 0.01), bs * Vector3(0, ln * 0.95, 0) + Vector3(-0.5, -0.15, 0.01), 0.008)
	return [Vector3(0.0, 0.0, 0.02)]

# ---------------------------------------------------------------- the stone

## the stone: a lump worn round, chipped flat here and there (quartz), or a rounded drop of resin (amber)
## amber: a polished free-form pebble — smooth all over, flattened, its outline in soft lobes; sometimes a flat
## polished window on its face (a sharp edge round it). Raw pieces are lumpier.
static func _resin(rng: Rng32, f: Dictionary) -> Geo:
	var g := Geo.icosa(1.0, 5).to_soup()
	var nz := FastNoiseLite.new()
	nz.seed = int(rng.next() * 100000.0)
	nz.frequency = 0.55
	nz.fractal_octaves = 2
	var bumps := FastNoiseLite.new()
	bumps.seed = nz.seed + 7
	bumps.frequency = 2.2
	var raw := float(f.crust) > 0.0
	var flat := 0.5 + rng.next() * 0.18
	var sc := Vector3(1.05 + rng.next() * 0.3, 0.8 + rng.next() * 0.25, flat)
	var win := 0.78 + rng.next() * 0.1 if f.window else 9.0
	for i in g.v.size():
		var d := g.v[i].normalized()
		# lobes of the outline (around z), a drop-like taper to one end
		var r := 1.0 + nz.get_noise_3d(d.x * 1.2, d.y * 1.2, 0.0) * 0.32 + nz.get_noise_3dv(d * 1.6) * 0.1
		r += d.x * 0.08
		if raw: r += bumps.get_noise_3dv(d) * 0.05
		var p := d * r * sc
		if p.z > win * flat: p.z = win * flat
		g.v[i] = p
	g.col.resize(g.v.size())
	g.orient_out()
	_smooth(g, 0.45 if f.window else -1.0)
	return g

## normals averaged over the faces round each corner — all of them, or only those within `keep` of each other
## (a sharp edge where a flat cut meets the round)
static func _smooth(g: Geo, keep: float) -> void:
	var fn := []
	var at := {}
	for k in g.tri_count():
		var t := g.tri(k)
		var n := (t[1] - t[0]).cross(t[2] - t[0]).normalized()
		if n.dot((t[0] + t[1] + t[2]) / 3.0) < 0.0: n = -n
		fn.append(n)
		for q in 3:
			var key := t[q].snapped(Vector3.ONE * 0.0001)
			if not at.has(key): at[key] = []
			(at[key] as Array).append(k)
	g.own_n.resize(g.v.size())
	for k in g.tri_count():
		for q in 3:
			var vi := k * 3 + q
			var acc := Vector3.ZERO
			for o in at[g.v[vi].snapped(Vector3.ONE * 0.0001)]:
				if (fn[o] as Vector3).dot(fn[k]) > keep: acc += fn[o]
			g.own_n[vi] = acc.normalized()

static func amber_mat(f: Dictionary, g: Geo) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = AMBER
	var resin: bool = f.host in ["amber", "copal"]
	m.set_shader_parameter("sigma", TONES[f.get("tone", "honey")][0] if resin else (Vector3(0.015, 0.012, 0.01) if f.host == "quartz" else Vector3(0.25, 0.32, 0.45)))
	if not resin:
		# quartz: white light through it, its cracks flashing white like ice, no flow lines, no dirt
		m.set_shader_parameter("light_col", Vector3(0.95, 0.97, 1.0))
		m.set_shader_parameter("spangle_col", Vector3(0.85, 0.9, 1.0))
		m.set_shader_parameter("dirt_k", 0.0)
		m.set_shader_parameter("debris_k", 0.0)
		m.set_shader_parameter("flow_k", 0.0)
		m.set_shader_parameter("spangle_k", 0.8)
		m.set_shader_parameter("cloud_k", 0.12)
		m.set_shader_parameter("bubble_k", 0.3)
		m.set_shader_parameter("back_k", 0.6)
		m.set_shader_parameter("base_k", 0.05)
		m.set_shader_parameter("held_k", 0.95)
		m.set_shader_parameter("crust_k", 0.0)
	m.set_shader_parameter("axes", _axes(g))
	if not resin:
		m.set_shader_parameter("axes", _axes(g))
		m.set_shader_parameter("seed", float(int(f.seed) % 97) * 0.7)
		return m
	m.set_shader_parameter("spangle_k", 1.0 if f.get("spangle", false) else 0.0)
	m.set_shader_parameter("crust_k", f.get("crust", 0.0))
	m.set_shader_parameter("crack_tex", load("res://assets/textures/mud_cracked_dry_03/mud_cracked_dry_03_diff_1k.jpg"))
	m.set_shader_parameter("crack_k", 1.0)
	m.set_shader_parameter("cloud_k", f.get("cloud", 0.0))
	m.set_shader_parameter("dirt_k", 0.3 + float(int(f.seed) % 7) / 7.0 * 0.7)
	m.set_shader_parameter("flow_k", 0.6 if f.host == "amber" else 0.35)
	m.set_shader_parameter("seed", float(int(f.seed) % 97) * 0.7)
	return m

static func _axes(g: Geo) -> Vector3:
	var bb := g.aabb()
	return Vector3(maxf(-bb.position.x, bb.end.x), maxf(-bb.position.y, bb.end.y), maxf(-bb.position.z, bb.end.z)) * 1.04

static func build(b: RefCounted, gene: Dictionary) -> MeshInstance3D:
	var f: Dictionary = gene.fossil
	var rng := Rng32.new(int(f.seed) * 3 + 11)
	var root: Node3D = b.root
	var holder := Node3D.new()
	root.add_child(holder)
	var gs: float = gene.scale
	var inner := Node3D.new()
	holder.add_child(inner)
	var marks := []
	# every host is now a flattened pebble shown by its face: all are placed the way amber is
	var resin := true
	# amber: a flattened pebble turned to show its face (the viewer turns every find 0.6 about y), what it holds
	# lies in it flat, smaller, off the middle; quartz: a round lump, the flower facing the viewer
	var face := Basis.IDENTITY if resin else Basis(Vector3.UP, -0.6)
	var at := Vector3((rng.next() - 0.5) * 0.4, (rng.next() - 0.5) * 0.3, (rng.next() - 0.5) * 0.1) if resin else Vector3.ZERO
	var lie := Basis(Vector3.BACK, rng.next() * TAU) * Basis(Vector3.RIGHT, PI / 2) if resin else Basis.IDENTITY
	if f.content in ["fern", "feather"]:
		var k := (1.05 if f.content == "feather" else 0.85) if resin else (1.4 if f.content == "feather" else 1.1)
		inner.transform = Transform3D(face * Basis(Vector3.UP, (rng.next() - 0.5) * 0.6) * Basis(Vector3.BACK, (rng.next() - 0.5) * 0.8) * Basis.from_scale(Vector3.ONE * k), at)
		marks = _fern(inner, rng, f) if f.content == "fern" else _feather(inner, rng, f)
	elif f.content == "insect":
		# caught as it fell: turned any way, legs splayed
		var k := (0.72 if f.insect in ["mosquito", "spider"] else 0.85) if resin else (1.15 if f.insect in ["mosquito", "spider"] else 1.45)
		inner.transform = Transform3D(face * lie * Basis(Vector3.UP, (rng.next() - 0.5) * 1.2) * Basis(Vector3.RIGHT, (rng.next() - 0.5) * 0.7) * Basis(Vector3.BACK, (rng.next() - 0.5) * 0.5) * Basis.from_scale(Vector3.ONE * k), at)
		marks = _insect(inner, rng, f)
	else:
		# the flower faces the viewer, a little turned and tipped
		inner.transform = Transform3D(face * Basis(Vector3.UP, (rng.next() - 0.5) * 0.7) * Basis(Vector3.RIGHT, -0.25 + (rng.next() - 0.5) * 0.4) * Basis.from_scale(Vector3.ONE * (0.9 if resin else 1.15)), at + Vector3(0, 0.05, 0))
		marks = _flower(inner, rng, f)
	# gold dust settled under it
	if f.gold:
		var gm := SpecMat.make({col = SpecMat.lin(0xe8b84a), metal = 1.0, rough = 0.25, flat = true})
		var flake := Geo.icosa(1.0, 0)
		var place := func(k: int) -> Array:
			var p := Vector3((rng.next() - 0.5) * 0.9, -0.35 - rng.next() * 0.35, (rng.next() - 0.5) * 0.6)
			var s := 0.006 + pow(rng.next(), 3.0) * 0.025
			return [Transform3D(Basis(Vector3(rng.next(), rng.next(), rng.next()).normalized(), rng.next() * TAU) * Basis.from_scale(Vector3(s, s * 0.3, s)), p), Color(1, 1, 1)]
		U.inst(flake, gm, 90, place, holder)
		b._mark("gold_dust", U.rel_xform(holder, root) * Vector3(0, -0.5, 0.2), Vector3.BACK)
	# every host a smooth tumbled pebble: amber, or clear / smoky quartz (shaders/amber.gdshader for both)
	var sg := _resin(rng, f)
	var stone := U.mesh(sg, amber_mat(f, sg), holder)
	stone.set_meta("col", true)
	stone.visible = not f.get("bare", false)
	# amber shows its face, turned a little so its thickness shows at one side
	var turn := Basis(Vector3.UP, -0.6 + 0.35 + (rng.next() - 0.5) * 0.3) * Basis(Vector3.RIGHT, -0.2 + (rng.next() - 0.5) * 0.3) * Basis(Vector3.BACK, (rng.next() - 0.5) * 0.8) if resin else Basis.IDENTITY
	holder.transform = Transform3D(turn * Basis.from_scale(Vector3.ONE * gs * (0.85 if resin else 0.75)), Vector3.ZERO)
	var ix := U.rel_xform(inner, root)
	for p in marks:
		b._mark({flower = "flower", insect = "insect", fern = "fern", feather = "feather"}.get(f.content, "insect"), ix * (p as Vector3), Vector3.BACK)
	if f.content == "flower" and int(f.leaves) > 0:
		b._mark("leaves", ix * Vector3(0.35, -0.3, -0.06), Vector3.BACK)
	b._mark("stone", U.rel_xform(holder, root) * Vector3(0.5, 0.6, 0.4), Vector3(0.5, 0.6, 0.6).normalized())
	return stone
