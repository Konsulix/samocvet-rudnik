class_name SpecPearl
extends RefCounted
## Pearl: grown in a pearl oyster (Pinctada), nacre laid over nacre. Shown in its oyster — two valves on their hinge,
## the upper one breathing slowly open and shut, the pearl on the mother-of-pearl of the lower — on a single valve
## with a blister pearl grown into it, or loose. Bodies: white akoya with a rose overtone, silver south sea, golden,
## black Tahitian with a peacock overtone, pink conch and orange melo with their flame structure (no nacre: loose
## only). Shapes: round, near round, drop, button, baroque, circled. The oyster: its lip (silver, gold, black) round
## the nacre, a fringe of growth scales, barnacles on its back; rare seed pearls along the nacre's edge.
## Legendary "moon pearl": it glows from within, clouds drifting through it, lighting its shell.
## Drawn by shaders/pearl.gdshader (part 0 the pearl, part 1 the shell).

const U := preload("res://scripts/specimen/spec_util.gd")
const SHADER := preload("res://shaders/pearl.gdshader")

## body: colour, overtone, how strong the overtone and orient, flame (conch / melo), the oyster's lip
const BODY := {
	akoya = {n = "akoya", col = 0xf2ece4, over = 0xf4c6c8, ok = 0.45, orient = 0.35, flame = 0.0, lip = "silver", w = 4.0},
	south_sea = {n = "south sea", col = 0xe9e6e0, over = 0xd8e4ee, ok = 0.35, orient = 0.3, flame = 0.0, lip = "silver", w = 2.0},
	golden = {n = "golden", col = 0xe0bb72, over = 0xf2dca0, ok = 0.4, orient = 0.25, flame = 0.0, lip = "gold", w = 2.0},
	tahitian = {n = "Tahitian", col = 0x4a4d4a, over = 0x3f8a6c, ok = 0.7, orient = 0.3, flame = 0.0, lip = "black", w = 3.0},
	conch = {n = "conch", col = 0xec7470, over = 0xffd2c8, ok = 0.2, orient = 0.0, flame = 1.0, lip = "", w = 0.8},
	melo = {n = "melo", col = 0xec8a3a, over = 0xffcf8a, ok = 0.2, orient = 0.0, flame = 0.9, lip = "", w = 0.6},
}
## a Tahitian's overtone varies: peacock, aubergine, pistachio, green
const TAHITI := [["peacock", 0x3f8a6c, 0xa05a8c], ["aubergine", 0x7a4a7c, 0x7a4a7c], ["pistachio", 0x8a9a4a, 0x8a9a4a], ["green", 0x2f7a5a, 0x2f7a5a]]
## the oyster's lip round its nacre, and the back of its shell
## the lip, the back, the nacre's own grey
const LIP := {"silver": [0xc8c8c4, 0x6a6a5c, 0x9c9c9a], "gold": [0xc89a48, 0x7a6232, 0xb4a88a], "black": [0x22262a, 0x3a3a30, 0x4a4e4c], "": [0xb0a8a0, 0x6a6458, 0x9c9a96]}
const SHAPES := {round = "round", near = "near round", drop = "drop", button = "button", baroque = "baroque", circled = "circled"}

static func genes(seed_v: int, tr: Array, o: Dictionary = {}) -> Dictionary:
	var rng := Rng32.new((seed_v * 2246822519 + 97) % 4294967296)
	var g := {kind = "pearl"}
	var bw := []
	for k: String in BODY:
		bw.append([k, float(BODY[k].w)])
	g.body = Stones.pick_w(bw, rng)
	if o.has("body"): g.body = o.body
	var flame: bool = float(BODY[g.body].flame) > 0.0
	g.tone = int(rng.next() * TAHITI.size())
	g.shape = Stones.pick_w([["round", 3.0], ["near", 2.0], ["drop", 1.5], ["button", 1.2], ["baroque", 2.5], ["circled", 1.5]], rng)
	if flame: g.shape = Stones.pick_w([["near", 2.0], ["drop", 1.0], ["baroque", 1.0]], rng)
	g.luster = 0.45 + rng.next() * 0.55
	g.show = "loose" if flame else Stones.pick_w([["shell", 5.0], ["valve", 2.0], ["loose", 2.0]], rng)
	g.count = 1 if rng.next() < 0.85 else 2 + int(rng.next() * 2.0)
	g.blister = rng.next() < 0.25
	g.seeds = rng.next() < 0.15
	g.barnacles = rng.next() < 0.55
	g.fringe = 0.4 + rng.next() * 0.6
	g.seed = int(rng.next() * 100000.0)
	if "irid" in tr or "aurora" in tr: g.luster = maxf(float(g.luster), 0.9)
	for k in ["shape", "luster", "show", "count", "blister", "seeds", "barnacles", "tone"]:
		if o.has(k): g[k] = o[k]
	if flame: g.show = "loose"
	if g.show == "valve": g.blister = true
	if g.show == "loose":
		g.blister = false
		g.seeds = false
		g.barnacles = false
	return g

static func accents(g: Dictionary) -> Array:
	var out := ["luster"]
	var b: Dictionary = BODY[g.body]
	if float(b.flame) > 0.0: out.append("flame")
	elif float(b.ok) > 0.0: out.append("overtone")
	if g.shape in ["baroque", "drop", "circled", "button"]: out.append("shape")
	if g.get("show", "") != "loose": out.append("nacre")
	if g.get("blister", false): out.append("blister")
	if g.get("seeds", false): out.append("seeds")
	if g.get("barnacles", false): out.append("barnacles")
	if int(g.get("count", 1)) > 1 and g.get("show", "") != "valve": out.append("twins")
	return out

static func gene_name(id: String, g: Dictionary) -> String:
	var b: Dictionary = BODY[g.body]
	match id:
		"luster": return "%s luster %d%%" % [b.n, roundi(float(g.luster) * 100.0)]
		"flame": return "flame structure"
		"overtone":
			if g.body == "tahitian": return "%s overtone" % TAHITI[int(g.tone)][0]
			return {akoya = "rose overtone", south_sea = "silver overtone", golden = "gold overtone"}.get(g.body, "overtone")
		"shape": return "%s pearl" % SHAPES.get(g.shape, "baroque")
		"nacre": return "%s-lip nacre" % b.lip
		"blister": return "blister pearl"
		"seeds": return "seed pearls"
		"barnacles": return "barnacles"
		"twins": return "%d pearls" % int(g.count)
	return ""

# ---------------------------------------------------------------- shapes

## a pearl of radius 1: its shape, the faint unevenness of a natural one
static func pearl_geo(shape: String, seed_v: int) -> Geo:
	# a grid sphere (indexed: smooth normals — an icosahedron's faces would show on a mirror-bright pearl)
	var g := Geo.sphere(1.0, 56, 36)
	var nz := FastNoiseLite.new()
	nz.seed = seed_v
	nz.frequency = 0.9
	for i in g.v.size():
		var p := g.v[i]
		var d := p.normalized()
		var r := 1.0 + 0.008 * nz.get_noise_3dv(d * 6.0)
		match shape:
			"near": r += 0.04 * nz.get_noise_3dv(d * 1.2)
			"drop":
				# a drop: drawn up to a soft point at the top
				r *= 1.0 + 0.42 * pow(maxf(0.0, d.y), 2.2) - 0.06 * maxf(0.0, -d.y)
			"button": if d.y < 0.0: d.y *= 0.55
			"baroque":
				r += 0.18 * nz.get_noise_3dv(d * 0.8) + 0.06 * nz.get_noise_3dv(d * 1.7 + Vector3(5, 0, 0)) + 0.15 * d.y * d.y
			"circled":
				# rings round it, grooved where the nacre grew unevenly as it turned
				r += 0.03 * nz.get_noise_3dv(d * 1.4) - 0.022 * pow(absf(sin(d.y * 11.0)), 6.0)
		g.v[i] = d * r
		g.rp.append(d)
	return g

## one valve of the oyster: the inside (nacre) is concave, facing down (-y); the hinge a straight line along x at
## z = ZH through the umbo, the shell grown out from it towards -z. Rays from the umbo (beta 0..pi) carry the growth
## rings (rho, 0..1 at the nacre's edge, beyond it the fringe of growth scales). UV: rho, beta / pi; UV2.x: 0 outside,
## 1 inside, 0.5 the edge.
const ZH := 0.62
const DEPTH := 0.3
static func _reach(beta: float, nz: FastNoiseLite) -> float:
	var s := sin(beta)
	var t := ZH * s + sqrt(ZH * ZH * s * s + 1.0 - ZH * ZH)
	# the ears at each end of the hinge
	t *= 1.0 + 0.2 * exp(-pow(beta / 0.22, 2.0)) + 0.2 * exp(-pow((PI - beta) / 0.22, 2.0))
	return t * (1.0 + 0.05 * nz.get_noise_1d(beta * 3.0))

static func _outer_y(x: float, z: float) -> float:
	var q := Vector2(x, z).length() / 1.12
	# flat along the hinge, so the two valves close on it
	return DEPTH * pow(maxf(0.0, 1.0 - q * q), 0.75) * (0.15 + 0.85 * smoothstep(0.0, 0.45, ZH - z))

static func _thick(rho: float) -> float:
	return 0.035 * (1.0 - minf(rho, 1.0)) + 0.009

static func valve_geo(f: Dictionary, seed_v: int) -> Geo:
	var nz := FastNoiseLite.new()
	nz.seed = seed_v
	nz.frequency = 0.6
	var g := Geo.new()
	var na := 64
	var nr := 30
	var fringe: float = f.get("fringe", 0.6)
	for side in 2:
		for j in na + 1:
			var beta := PI * float(j) / na
			var t := _reach(beta, nz)
			# the fringe: thin scales of the outer layer standing past the nacre, longer away from the hinge
			var fr := (0.05 + 0.12 * pow(0.5 + 0.5 * sin(beta * 23.0 + nz.get_noise_1d(beta * 9.0) * 4.0), 4.0)) * fringe * smoothstep(0.1, 0.6, sin(beta))
			for i in nr + 1:
				var rho := float(i) / nr * (1.0 + fr)
				var x := cos(beta) * rho * t
				var z := ZH - sin(beta) * rho * t
				var y := _outer_y(x, z) + 0.004 * nz.get_noise_2d(x * 9.0, z * 9.0)
				if side == 1: y -= _thick(rho)
				g.v.append(Vector3(x, y, z))
				g.rp.append(Vector3(rho, beta / PI, float(side)))
				g.col.append(Color(1, 1, 1, 1))
	var per := (na + 1) * (nr + 1)
	for side in 2:
		for j in na:
			for i in nr:
				var a := side * per + j * (nr + 1) + i
				var b := a + nr + 1
				if side == 0: g.idx.append_array([a, a + 1, b, b, a + 1, b + 1])
				else: g.idx.append_array([a, b, a + 1, a + 1, b, b + 1])
	# the edge round the margin and along the hinge, outside to inside
	var edge := func(o0: int, i0: int, o1: int, i1: int) -> void:
		g.idx.append_array([o0, o1, i0, i0, o1, i1])
	for j in na:
		var a := j * (nr + 1) + nr
		var b := (j + 1) * (nr + 1) + nr
		edge.call(a, a + per, b, b + per)
	for i in nr:
		edge.call(i + 1, i + 1 + per, i, i + per)
		var a := na * (nr + 1) + i
		edge.call(a, a + per, a + 1, a + 1 + per)
	return g

## the inside of a valve at (x, z): its height (valve space)
static func _inner_y(x: float, z: float) -> float:
	var rho := clampf(Vector2(x, z - ZH).length() / 1.6, 0.0, 1.0)
	return _outer_y(x, z) - _thick(rho)

static func mat(f: Dictionary, part: int) -> ShaderMaterial:
	var b: Dictionary = BODY[f.body]
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("part", part)
	var over: int = b.over
	var over2: int = b.over
	if f.body == "tahitian":
		over = TAHITI[int(f.tone)][1]
		over2 = TAHITI[int(f.tone)][2]
	m.set_shader_parameter("body_col", Color.hex(int(b.col) << 8 | 0xff))
	m.set_shader_parameter("over_col", Color.hex(over << 8 | 0xff))
	m.set_shader_parameter("over2_col", Color.hex(over2 << 8 | 0xff))
	m.set_shader_parameter("over_k", b.ok)
	m.set_shader_parameter("orient_k", b.orient)
	m.set_shader_parameter("flame_k", b.flame)
	m.set_shader_parameter("luster", f.luster)
	m.set_shader_parameter("circle_k", 1.0 if f.shape == "circled" else 0.0)
	var lip: Array = LIP[String(b.lip)]
	m.set_shader_parameter("lip_col", Color.hex(int(lip[0]) << 8 | 0xff))
	m.set_shader_parameter("back_col", Color.hex(int(lip[1]) << 8 | 0xff))
	m.set_shader_parameter("nacre_col", Color.hex(int(lip[2]) << 8 | 0xff))
	m.set_shader_parameter("seed", float(int(f.seed) % 997) * 0.11)
	return m

# ---------------------------------------------------------------- building

static func build(b: RefCounted, gene: Dictionary) -> MeshInstance3D:
	var f: Dictionary = gene.fossil
	var rng := Rng32.new(int(f.seed) * 5 + 9)
	var root: Node3D = b.root
	var gs: float = gene.scale
	var pm := mat(f, 0)
	var holder := Node3D.new()
	root.add_child(holder)
	var main: MeshInstance3D = null
	var marks := {}
	var pearls: Array = []
	var show: String = f.show
	var pg := pearl_geo(String(f.shape), int(f.seed))
	var moon: bool = gene.fx == "moon"
	if moon: pm.set_shader_parameter("moon_k", 1.0)
	if show == "loose":
		# the pearl alone; its twins beside it
		var n := int(f.count)
		for k in n:
			var s := gs * (0.62 if n == 1 else 0.48 - 0.08 * k)
			var at := Vector3((float(k) - (n - 1) * 0.5) * gs * 1.0, -0.06 * k * gs, 0.1 * k * gs)
			var mi := U.mesh(pg if k == 0 else pearl_geo(String(f.shape), int(f.seed) + k), pm, holder, at,
				Basis(Vector3.BACK, (rng.next() - 0.5) * 0.5) * Basis(Vector3.UP, rng.next() * TAU) * Basis.from_scale(Vector3.ONE * s))
			mi.set_meta("col", true)
			pearls.append(mi)
		main = pearls[0]
	else:
		var sm := mat(f, 1)
		var vg := valve_geo(f, int(f.seed))
		var oy := Node3D.new()
		holder.add_child(oy)
		# the lower valve lies cupped, its nacre up (turned over on the hinge's own line)
		var low := U.mesh(vg, sm, oy, Vector3.ZERO, Basis(Vector3.BACK, PI))
		low.set_meta("col", true)
		main = low
		marks.nacre = Vector3(-0.35, -_inner_y(0.35, -0.55) + 0.01, -0.55)
		var lip_at := Vector3(-0.8, -_inner_y(0.8, -0.3), -0.3)
		# pearls lying in it
		var spots := [Vector2(0.08, -0.35), Vector2(-0.3, -0.2), Vector2(0.32, -0.15)]
		var n := int(f.count) if show == "shell" else 0
		for k in n:
			var sp: Vector2 = spots[k]
			sp += Vector2(rng.next() - 0.5, rng.next() - 0.5) * 0.12
			var s := (0.27 if k == 0 else 0.2) * (1.0 if f.shape != "drop" else 0.85)
			var at := Vector3(-sp.x, -_inner_y(sp.x, sp.y) + s * 0.82, sp.y)
			var mi := U.mesh(pg if k == 0 else pearl_geo(String(f.shape), int(f.seed) + k), pm, oy, at,
				Basis(Vector3.BACK, (rng.next() - 0.5) * 0.6 + (PI * 0.5 if f.shape == "drop" else 0.0)) * Basis(Vector3.UP, rng.next() * TAU) * Basis.from_scale(Vector3.ONE * s))
			mi.set_meta("col", true)
			pearls.append(mi)
		# a blister pearl grown into the nacre: a dome rising out of it
		if f.get("blister", false):
			var sp := Vector2(-0.2, -0.55) if show == "shell" else Vector2(0.0, -0.4)
			var s := 0.2 if show == "valve" else 0.15
			var bg := Geo.sphere(1.0, 28, 12, 0.0, TAU, 0.0, PI * 0.55)
			for i in bg.v.size():
				bg.v[i].y *= 0.7
				bg.rp.append(bg.v[i].normalized())
			var bm := pm.duplicate() as ShaderMaterial
			bm.set_shader_parameter("blister_k", 1.0)
			var bl := U.mesh(bg, bm, oy, Vector3(-sp.x, -_inner_y(sp.x, sp.y) - s * 0.12, sp.y), Basis.from_scale(Vector3.ONE * s))
			bl.set_meta("col", true)
			marks.blister = Vector3(-sp.x, -_inner_y(sp.x, sp.y) + s * 0.5, sp.y)
			if show == "valve": pearls.append(bl)
		# seed pearls along the nacre's edge
		if f.get("seeds", false):
			var sg := Geo.icosa(1.0, 2)
			for k in 9 + int(rng.next() * 8.0):
				var beta := 0.5 + rng.next() * (PI - 1.0)
				var rho := 0.62 + rng.next() * 0.2
				var x := cos(beta) * rho * 1.5
				var z := ZH - sin(beta) * rho * 1.5
				var s := 0.012 + rng.next() * 0.018
				var mi := U.mesh(sg, pm, oy, Vector3(-x, -_inner_y(x, z) + s * 0.7, z), Basis.from_scale(Vector3(s, s * 0.85, s)))
				mi.set_meta("col", true)
				if k == 0: marks.seeds = Vector3(-x, -_inner_y(x, z) + s, z)
		# the upper valve, open on its hinge, breathing (the valve shown alone has none)
		if show == "shell":
			var hinge := Node3D.new()
			hinge.position = Vector3(0, 0.02, ZH)
			oy.add_child(hinge)
			var up := U.mesh(vg, sm, hinge, Vector3(0, 0, -ZH), Basis.IDENTITY)
			up.set_meta("col", true)
			var open := 1.4 + rng.next() * 0.15
			hinge.basis = Basis(Vector3.RIGHT, open)
			var br := Breath.new()
			br.hinge = hinge
			br.open = open
			br.phase = rng.next() * TAU
			oy.add_child(br)
			marks.lip = U.rel_xform(up, oy) * Vector3(0.7, _outer_y(0.7, -0.3) - 0.06, -0.3)
			if f.get("barnacles", false):
				_barnacles(up, rng)
				marks.barnacles = U.rel_xform(up, oy) * Vector3(0.1, _outer_y(0.1, -0.2) + 0.03, -0.2)
		elif f.get("barnacles", false):
			# a single valve shows its nacre: barnacles round its rim only
			_barnacles(low, rng, 0.78)
		if not marks.has("lip"): marks.lip = lip_at
		# hinge to the back, the cupped valve tipped up to the viewer
		oy.transform = Transform3D(Basis(Vector3.RIGHT, 0.7 if show == "shell" else 0.9) * Basis(Vector3.UP, PI) * Basis.from_scale(Vector3.ONE * gs * 1.25), Vector3(0, -0.1 * gs, 0))
		for id: String in marks:
			if id != "lip":
				marks[id] = U.rel_xform(oy, root) * (marks[id] as Vector3)
		marks.lip = U.rel_xform(oy, root) * (marks.lip as Vector3)
	# the legendary moon pearl: a light inside it, its shell lit by it, the room darkened
	if moon and pearls.size():
		root.set_meta("dark", true)
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(0.75, 0.82, 1.0)
		lamp.light_energy = 0.3
		lamp.omni_range = gs * 1.6
		(pearls[0] as Node3D).add_child(lamp)
	# callouts
	if pearls.size():
		var p0 := pearls[0] as MeshInstance3D
		var px := U.rel_xform(p0, root)
		var top := px * Vector3(0, 0.75, 0.6)
		var nrm := (px.basis * Vector3(0, 0.75, 0.6)).normalized()
		b._mark("luster", top, nrm)
		for id: String in ["flame", "overtone", "shape"]:
			if id in gene.accents: b._mark(id, px * Vector3(0.7, 0.2, 0.6), (px.basis * Vector3(0.7, 0.2, 0.6)).normalized())
		if "twins" in gene.accents and pearls.size() > 1:
			var p1 := pearls[1] as MeshInstance3D
			b._mark("twins", U.rel_xform(p1, root) * Vector3(0, 0.9, 0.3), Vector3.UP)
	for id: String in ["nacre", "blister", "seeds", "barnacles"]:
		if marks.has(id) and id in gene.accents: b._mark(id, marks[id] as Vector3, Vector3.BACK)
	return main

## barnacles on a valve's back (outside, +y in valve space): chalky cones each with its crater
static func _barnacles(v: MeshInstance3D, rng: Rng32, rim := 0.0) -> void:
	var prof := [Vector2(1.0, 0.0), Vector2(0.96, 0.22), Vector2(0.78, 0.55), Vector2(0.52, 0.78), Vector2(0.44, 0.8),
		Vector2(0.36, 0.7), Vector2(0.0, 0.5)]
	var bg := Geo.lathe(prof, 10)
	var bm := SpecMat.make({col = SpecMat.lin(0xd2ccbe), rough = 0.85, side = "double"})
	var c0 := Vector2((rng.next() - 0.5) * 0.6, -0.1 - rng.next() * 0.5)
	for k in 7 + int(rng.next() * 9.0):
		var q := c0 + Vector2(rng.next() - 0.5, rng.next() - 0.5) * 0.45
		if rim > 0.0:
			var a := rng.next() * PI
			q = Vector2(cos(a) * 1.05, ZH - sin(a) * 1.25)
		var s := 0.03 + pow(rng.next(), 1.5) * 0.06
		var y := _outer_y(q.x, q.y)
		var nrm := Vector3(-q.x * 0.5, 1.0, -q.y * 0.5).normalized()
		var mi := U.mesh(bg, bm, v, Vector3(q.x, y - s * 0.1, q.y),
			Basis(U.quat_to(Vector3.UP, nrm)) * Basis(Vector3.UP, rng.next() * TAU) * Basis.from_scale(Vector3(s, s * (0.6 + rng.next() * 0.5), s)))
		mi.set_meta("col", true)

## the oyster breathing: the upper valve eases open and shut on its hinge, slowly, a pause when shut
class Breath extends Node3D:
	var hinge: Node3D
	var open := 1.8
	var phase := 0.0
	var t := 0.0
	func _process(dt: float) -> void:
		t += dt
		var c := sin(t * TAU / 7.0 + phase)
		hinge.basis = Basis(Vector3.RIGHT, open - 0.09 * (0.5 + 0.5 * c * absf(c)))
