class_name SpecFlower
extends RefCounted
## A flower held in clear stone: a rounded lump of quartz (worn smooth, chipped flat in places, milky veils and
## cracks inside) with a whole flower in it — dark petals with a metallic sheen on their rims (shaders/petal.gdshader),
## stamens tipped with gold, sometimes gold dust settled under it. The stone is the generator's own glass, so the
## flower is seen through it bent and blurred where the glass clouds.

const U := preload("res://scripts/specimen/spec_util.gd")
const PETAL := preload("res://shaders/petal.gdshader")

## petal colours: [name, middle, sheen]
const LOOKS := [
	["bronze", 0x16100c, 0xb8763c], ["copper", 0x1e0c08, 0xc8643a], ["red", 0x3a0810, 0xd0503a],
	["indigo", 0x0e0e2a, 0x8a7ad8], ["white", 0xcfc8bc, 0xf4ead2], ["green", 0x0c1a10, 0x8ab060],
]
const STONE := [Color(0.95, 0.97, 0.98), Color(0.82, 0.78, 0.72), Color(0.98, 0.86, 0.66)]   # clear, smoky, amber
const STONE_N := ["clear quartz", "smoky quartz", "amber"]

static func genes(seed_v: int, tr: Array, o: Dictionary = {}) -> Dictionary:
	var rng := Rng32.new((seed_v * 2246822519 + 77) % 4294967296)
	var g := {kind = "flower_quartz"}
	g.look = int(Stones.pick_w([[0, 4.0], [1, 2.5], [2, 2.0], [3, 1.2], [4, 1.0], [5, 0.8]], rng))
	g.petals = 5 + int(rng.next() * 3)
	g.inner = int(Stones.pick_w([[0, 2.0], [3, 2.0], [4, 1.5], [5, 1.0]], rng))
	g.stone = int(Stones.pick_w([[0, 5.0], [1, 2.0], [2, 1.5]], rng))
	g.gold = rng.next() < 0.45 or "goldfleck" in tr
	g.veils = 0
	g.seed = int(rng.next() * 100000.0)
	g.bare = false   # showcases: the flower without its stone
	for k in ["look", "petals", "inner", "stone", "gold", "veils", "bare"]:
		if o.has(k): g[k] = o[k]
	return g

static func accents(g: Dictionary) -> Array:
	var out := ["flower", "stone"]
	if g.gold: out.append("gold_dust")
	return out

static func gene_name(id: String, g: Dictionary) -> String:
	match id:
		"flower": return "%s-edged flower, %d petals" % [LOOKS[int(g.look)][0], int(g.petals) + int(g.inner)]
		"stone": return STONE_N[int(g.stone)]
		"gold_dust": return "gold dust"
	return ""

## a petal: base at the origin, running out along +y, its face towards +z; cupped across, bent back near the tip,
## its rim waving
static func _petal(rng: Rng32, ln: float, wd: float, cup: float, bend: float) -> Geo:
	var g := Geo.new()
	var nt := 22
	var ns := 10
	var ph := rng.next() * TAU
	var wave := 0.04 + rng.next() * 0.05
	for i in nt + 1:
		var t := float(i) / nt
		# wide in the middle, a pointed tip, a narrow claw at the base
		var w := wd * pow(sin(PI * pow(t, 0.8)), 0.75) * (0.35 + 0.65 * smoothstep(0.0, 0.25, t))
		for j in ns + 1:
			var s := float(j) / ns * 2.0 - 1.0
			var x := s * w
			var y := t * ln
			var z := -cup * x * x / maxf(wd, 0.001) + bend * t * t * ln + wave * ln * sin(t * 9.0 + ph) * s * s
			g.v.append(Vector3(x, y, z))
			g.rp.append(Vector3(t, s, 0))
	for i in nt:
		for j in ns:
			var p0 := i * (ns + 1) + j
			var p1 := p0 + ns + 1
			g.idx.append_array([p0, p1, p0 + 1, p0 + 1, p1, p1 + 1])
	return g

## the stone: a lump worn round, chipped flat here and there
static func _stone(rng: Rng32) -> Geo:
	var g := Geo.icosa(1.0, 3).to_soup()
	var nz := FastNoiseLite.new()
	nz.seed = int(rng.next() * 100000.0)
	nz.frequency = 0.9
	nz.fractal_octaves = 3
	var cuts := []
	for k in 4 + int(rng.next() * 4):
		var d := Vector3(rng.next() - 0.5, rng.next() - 0.5, rng.next() - 0.5).normalized()
		cuts.append([d, 0.62 + rng.next() * 0.22])
	var sc := Vector3(1.0 + rng.next() * 0.2, 1.05 + rng.next() * 0.25, 0.8 + rng.next() * 0.15)
	for i in g.v.size():
		var d := g.v[i].normalized()
		var r := 1.0 + nz.get_noise_3dv(d * 1.3) * 0.24
		var p := d * r
		for c: Array in cuts:
			var cd: Vector3 = c[0]
			var over := p.dot(cd) - float(c[1])
			if over > 0.0:
				p -= cd * over
		g.v[i] = p * sc
	g.col.resize(g.v.size())
	# smooth normals over the worn round, a sharp edge where a chip's flat meets it: average the faces round each
	# point, but only those turned within ~35 degrees of the face being lit
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
			var vi := k * 3 + q if not g.indexed() else g.idx[k * 3 + q]
			var key := g.v[vi].snapped(Vector3.ONE * 0.0001)
			var acc := Vector3.ZERO
			for o in at[key]:
				if (fn[o] as Vector3).dot(fn[k]) > 0.82: acc += fn[o]
			g.own_n[vi] = acc.normalized()
	return g

static func build(b: RefCounted, gene: Dictionary) -> MeshInstance3D:
	var f: Dictionary = gene.fossil
	var rng := Rng32.new(int(f.seed) * 3 + 11)
	var root: Node3D = b.root
	var holder := Node3D.new()
	root.add_child(holder)
	var gs: float = gene.scale
	# the flower faces the viewer, a little turned and tipped (the viewer sees every find turned 0.6 about y)
	var flower := Node3D.new()
	holder.add_child(flower)
	flower.transform = Transform3D(Basis(Vector3.UP, -0.6 + (rng.next() - 0.5) * 0.7) * Basis(Vector3.RIGHT, -0.25 + (rng.next() - 0.5) * 0.4), Vector3(0, 0.05, 0))
	var look: Array = LOOKS[int(f.look)]
	var pm := ShaderMaterial.new()
	pm.shader = PETAL
	pm.set_shader_parameter("c_base", Color.hex(int(look[1]) << 8 | 0xff))
	pm.set_shader_parameter("c_rim", Color.hex(int(look[2]) << 8 | 0xff))
	pm.set_shader_parameter("seed", float(int(f.seed) % 97))
	var marks := []
	# two whorls: big outer petals opening wide, smaller inner ones more upright between them
	var whorls := [[int(f.petals), 0.78, 0.3, 0.35, 0.0], [int(f.inner), 0.52, 0.2, 0.85, 0.5]]
	for wv: Array in whorls:
		var n: int = wv[0]
		for k in n:
			var ang := (float(k) + float(wv[4]) + (rng.next() - 0.5) * 0.25) / maxf(n, 1) * TAU
			var ln := float(wv[1]) * (0.85 + rng.next() * 0.3)
			var pg := _petal(rng, ln, float(wv[2]) * (0.85 + rng.next() * 0.3), 0.5 + rng.next() * 0.4, -0.15 - rng.next() * 0.25)
			# out from the middle, tipped up out of the flower's plane
			var tilt := float(wv[3]) + (rng.next() - 0.5) * 0.25
			var bs := Basis(Vector3.BACK, ang) * Basis(Vector3.RIGHT, tilt)
			var mi := U.mesh(pg, pm, flower, Vector3.ZERO, bs)
			mi.set_meta("col", true)
			if marks.size() < 3 and wv[4] == 0.0:
				marks.append(U.rel_xform(mi, root) * Vector3(0, ln * 0.6, 0))
	# the middle: a little dome, stamens fanning out of it with gold anthers
	var gold := SpecMat.make({col = SpecMat.lin(0xd8a440), metal = 0.7, rough = 0.35})
	var stalk := SpecMat.make({col = SpecMat.lin(0x9a7a4a), rough = 0.5})
	U.mesh(Geo.icosa(1.0, 2), SpecMat.make({col = SpecMat.lin(0x3a2a14), rough = 0.6}), flower, Vector3(0, 0, 0.02), Basis.from_scale(Vector3(0.07, 0.07, 0.045)))
	var cyl := Geo.cylinder(1, 1, 1, 5).translate(0, 0.5, 0)
	var ball := Geo.icosa(1.0, 1)
	for k in 16 + int(rng.next() * 10):
		var a := rng.next() * TAU
		var lean := 0.25 + rng.next() * 0.6
		var d := (Basis(Vector3.BACK, a) * Basis(Vector3.RIGHT, PI / 2 - lean)) * Vector3.UP
		var h := 0.16 + rng.next() * 0.12
		var at := Vector3(cos(a), sin(a), 0) * 0.02 + Vector3(0, 0, 0.03)
		var bs := Basis(U.quat_to(Vector3.UP, d))
		U.mesh(cyl, stalk, flower, at, bs * Basis.from_scale(Vector3(0.006, h, 0.006)))
		U.mesh(ball, gold, flower, at + d * h, bs * Basis.from_scale(Vector3(0.016, 0.026, 0.016)))
	# gold dust settled in the stone under the flower
	if f.gold:
		var gm := SpecMat.make({col = SpecMat.lin(0xe8b84a), metal = 1.0, rough = 0.25, flat = true})
		var flake := Geo.icosa(1.0, 0)
		var place := func(k: int) -> Array:
			var p := Vector3((rng.next() - 0.5) * 0.9, -0.35 - rng.next() * 0.35, (rng.next() - 0.5) * 0.6)
			var s := 0.006 + pow(rng.next(), 3.0) * 0.025
			return [Transform3D(Basis(Vector3(rng.next(), rng.next(), rng.next()).normalized(), rng.next() * TAU) * Basis.from_scale(Vector3(s, s * 0.3, s)), p), Color(1, 1, 1)]
		U.inst(flake, gm, 90, place, holder)
		b._mark("gold_dust", U.rel_xform(holder, root) * Vector3(0, -0.5, 0.2), Vector3.BACK)
	# milky veils and cracks inside the stone
	var vm := SpecMat.make({col = Color(0.85, 0.86, 0.88), a = 0.07, transp = true, side = "double", rough = 0.6})
	for k in int(f.veils):
		var vg := Geo.icosa(1.0, 2)
		var sv := Vector3(0.4 + rng.next() * 0.3, 0.01, 0.3 + rng.next() * 0.25)
		U.mesh(vg, vm, holder, Vector3((rng.next() - 0.5) * 0.5, -0.2 - rng.next() * 0.4, (rng.next() - 0.5) * 0.4),
			Basis(Vector3(rng.next(), rng.next(), rng.next()).normalized(), rng.next() * TAU) * Basis.from_scale(sv))
	# the stone round it all
	var sg := _stone(rng)
	sg.col.fill(STONE[int(f.stone)])
	var glass := SpecMat.make({col = Color(1, 1, 1), glass = true, frost = 0.06, thick = 0.45, seed = 3.0})
	var stone := U.mesh(sg, glass, holder)
	stone.visible = not f.get("bare", false)
	stone.set_meta("col", true)
	holder.transform = Transform3D(Basis.from_scale(Vector3.ONE * gs * 0.75), Vector3.ZERO)
	for p in marks:
		b._mark("flower", p, Vector3.BACK)
	b._mark("stone", U.rel_xform(holder, root) * Vector3(0.5, 0.6, 0.4), Vector3(0.5, 0.6, 0.6).normalized())
	return stone
