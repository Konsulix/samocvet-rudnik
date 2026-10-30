class_name SpecFulgurite
extends RefCounted
## Fulgurite: lightning struck sand and fused it into a tube that branches down like the strike itself — a thick
## throat at the top splitting into ever thinner roots (a Lichtenberg figure). Crusted with the sand it caught, the
## tube is hollow: its broken ends open on a bore lined with smooth glass; in stretches the crust is broken away to
## clear glass rods. Its sands and glasses vary (quartz sand and near-clear glass; volcanic black sand and dark green
## glass…), the crust sometimes half melted to a froth, sometimes with beads of iron the lightning reduced. Shown lying
## loose, or dug out still standing in its sand. Rare: a fresh strike, the glass still glowing; legendary: "living
## lightning", the discharge running down it again and again. Built on SpecBranch (sand: shaders/branch.gdshader
## mode 2; glass: the generator's crystal glass).

const U := preload("res://scripts/specimen/spec_util.gd")

## sand: crust colour, dark grains; the glass it fused to: tint, the bore's lining
const SAND := [
	{name = "quartz sand", light = 0xd2ccbe, dark = 0x3a3430, glass = 0},
	{name = "desert sand", light = 0xb09878, dark = 0x2e2420, glass = 1},
	{name = "red sand", light = 0x86705f, dark = 0x3a1a10, glass = 1},
	{name = "volcanic sand", light = 0x5a5650, dark = 0x1a1816, glass = 3},
	{name = "beach sand", light = 0xa0a090, dark = 0x2a2a26, glass = 2},
]
## (lightning glass is not clear crystal: frosted, full of fine bubbles, often smoky)
const GLASS := [
	{name = "clear glass", tint = Color(0.93, 0.95, 0.97), lining = 0x8a9490, smoke = 0.0, smoke_col = Color(0.3, 0.3, 0.3)},
	{name = "smoky glass", tint = Color(0.86, 0.82, 0.76), lining = 0x5a4e44, smoke = 0.45, smoke_col = Color(0.25, 0.17, 0.1)},
	{name = "green glass", tint = Color(0.8, 0.92, 0.82), lining = 0x4a6a50, smoke = 0.35, smoke_col = Color(0.1, 0.25, 0.12)},
	{name = "black glass", tint = Color(0.55, 0.58, 0.56), lining = 0x1c2220, smoke = 0.85, smoke_col = Color(0.05, 0.06, 0.06)},
]

static func genes(seed_v: int, tr: Array, o: Dictionary = {}) -> Dictionary:
	var rng := Rng32.new((seed_v * 3266489917 + 41) % 4294967296)
	var g := {kind = "fulgurite"}
	g.sand = int(Stones.pick_w([[0, 3.0], [1, 3.0], [2, 1.5], [3, 1.2], [4, 1.5]], rng))
	g.glass = int(SAND[int(g.sand)].glass)
	if rng.next() < 0.25: g.glass = int(rng.next() * GLASS.size())
	g.open = 0.25 + rng.next() * 0.35        # how much of it is broken open to the glass
	g.branches = 3                            # forking levels of the strike
	g.seed = int(rng.next() * 100000.0)
	g.show = "sand" if rng.next() < 0.4 else "loose"
	g.froth = 0.0 if rng.next() < 0.65 else 0.4 + rng.next() * 0.6
	g.iron = rng.next() < 0.25
	g.hot = rng.next() < 0.05
	if "irid" in tr or "aurora" in tr: g.open = maxf(float(g.open), 0.5)
	for k in ["sand", "glass", "open", "branches", "show", "froth", "iron", "hot"]:
		if o.has(k): g[k] = o[k]
	return g

static func accents(g: Dictionary) -> Array:
	var out := ["sand", "glass", "bore"]
	if float(g.get("froth", 0.0)) > 0.0: out.append("froth")
	if g.get("iron", false): out.append("iron")
	if g.get("hot", false): out.append("hot")
	return out

static func gene_name(id: String, g: Dictionary) -> String:
	match id:
		"sand": return "fused %s" % SAND[int(g.sand)].name
		"glass": return "%s %d%%" % [GLASS[int(g.glass)].name, roundi(float(g.open) * 100.0)]
		"bore": return "glass-lined bore"
		"froth": return "frothy glass"
		"iron": return "iron beads"
		"hot": return "fresh strike"
	return ""

static func build(b: RefCounted, gene: Dictionary) -> MeshInstance3D:
	var f: Dictionary = gene.fossil
	var rng := Rng32.new(int(f.seed) * 7 + 1)
	var root: Node3D = b.root
	var holder := Node3D.new()
	root.add_child(holder)
	var gs: float = gene.scale
	var sand: Dictionary = SAND[int(f.sand)]
	var glass: Dictionary = GLASS[int(f.glass)]
	var hot: bool = f.get("hot", false)
	# the strike: a throat at the top forking down into thinner and thinner roots (grown up, then turned over)
	var sk := SpecBranch.skeleton(rng, {r0 = 0.1 + rng.next() * 0.03, len0 = 1.1 + rng.next() * 0.4, levels = int(f.branches), kids = [2, 3],
		kids2 = [1, 2], kid_r = 0.74, kid_len = 0.72, spread = 0.55, gnarl = 0.9, up = 0.6, taper = 0.5})
	var flip := Basis(Vector3.RIGHT, PI)
	var lo := INF
	var hi := -INF
	for br: Dictionary in sk:
		var pts: Array = []
		for q in br.pts:
			var w := flip * (q as Vector3)
			pts.append(w)
			lo = minf(lo, w.y)
			hi = maxf(hi, w.y)
		br.pts = pts
	var sm := ShaderMaterial.new()
	sm.shader = SpecBranch.SHADER
	sm.set_shader_parameter("mode", 2)
	sm.set_shader_parameter("seed", float(int(f.seed) % 997) * 0.37)
	sm.set_shader_parameter("c_light", Color.hex(int(sand.light) << 8 | 0xff))
	sm.set_shader_parameter("c_bark", Color.hex(int(sand.dark) << 8 | 0xff))
	sm.set_shader_parameter("c_end", Color.hex(int(sand.light) << 8 | 0xff))
	sm.set_shader_parameter("c_glass", Color.hex(int(glass.lining) << 8 | 0xff))
	sm.set_shader_parameter("froth_k", f.get("froth", 0.0))
	sm.set_shader_parameter("hot_k", 1.0 if hot else 0.0)
	sm.set_shader_parameter("sand_tex", load("res://assets/textures/dense_sand/dense_sand_diff_1k.jpg"))
	var tint: Color = glass.tint
	var gm: Material
	if hot:
		# still glowing: the glass lit from within, orange-white
		var hm := ShaderMaterial.new()
		hm.shader = SpecWood.STONE
		hm.set_shader_parameter("mode", 1)
		hm.set_shader_parameter("seed", float(int(f.seed) % 97))
		hm.set_shader_parameter("glow_col", Color(1.0, 0.55, 0.2))
		gm = hm
	else:
		gm = SpecMat.make({col = Color(1, 1, 1), glass = true, frost = 0.55, thick = 1.0, seed = 7.0, smoke = glass.smoke, smoke_col = glass.smoke_col})
	var milk := SpecMat.make({col = SpecMat.lin(0xe8e6e0), rough = 0.55})
	var first: MeshInstance3D = null
	var glass_at := []
	var surf := PackedVector3Array()
	var tubes := []
	var beads := []
	# the throat and the thick roots open on their bore where they broke; the thin roots run out to points
	var ends := {tip = "hollow", root = "hollow", kid_tip = "taper"}
	for k in sk.size():
		var br: Dictionary = sk[k]
		var n: int = (br.pts as Array).size()
		# stretches broken open to the glass, on the thicker roots
		var cuts := []
		if int(br.depth) <= 1:
			var i := 1 + int(rng.next() * 3)
			while i < n - 2:
				if rng.next() < float(f.open) * 0.6:
					var ln := 4 + int(rng.next() * 4)
					cuts.append([i, mini(i + ln, n - 1)])
					i += ln + 5
				else:
					i += 3 + int(rng.next() * 4)
		var e := ends.duplicate()
		if int(br.depth) >= 1 and float(br.rad[br.rad.size() - 1]) > 0.035 and rng.next() < 0.5: e.kid_tip = "hollow"
		var tg := SpecBranch.tube(br, {m = 16, sub = 3, lump = 0.3, ridge = 0.1, flat = 0.9, seed = int(f.seed) + k, glass = cuts, ends = e}, k == 0)
		var mi := U.mesh(tg, sm, holder)
		mi.set_meta("col", true)
		tubes.append(mi)
		if first == null: first = mi
		for q in range(0, tg.v.size(), 23): surf.append(tg.v[q])
		# the glass inside: a thinner smooth rod over each open stretch, a little longer than it
		for c: Array in cuts:
			var i0 := maxi(0, int(c[0]) - 1)
			var i1 := mini(n - 1, int(c[1]) + 1)
			var sub_pts: Array = (br.pts as Array).slice(i0, i1 + 1)
			var sub_r: Array = []
			for q in (br.rad as Array).slice(i0, i1 + 1): sub_r.append(float(q) * 0.75)
			if sub_pts.size() < 3 or (sub_pts[0] as Vector3).distance_to(sub_pts[sub_pts.size() - 1]) < 0.02: continue
			var gb := {pts = sub_pts, rad = sub_r, depth = 1, rnd = rng.next()}
			var gg := SpecBranch.tube(gb, {m = 12, sub = 3, lump = 0.06, ridge = 0.03, flat = 0.95, seed = int(f.seed) + 99 + k,
				ends = {tip = "torn", root = "torn"}}, true)
			gg.col.resize(gg.v.size())
			gg.col.fill(tint)
			var gi := U.mesh(gg, gm, holder)
			gi.set_meta("col", true)
			if not hot:
				# the milky streak down its middle (where the sand only half melted), seen through the clear glass
				var core_r: Array = []
				for q in sub_r: core_r.append(float(q) * 0.3)
				var cg := SpecBranch.tube({pts = sub_pts, rad = core_r, depth = 1, rnd = gb.rnd}, {m = 8, sub = 3, lump = 0.25, ridge = 0.05, flat = 0.7,
					seed = int(f.seed) + 7 + k}, true)
				cg.col.resize(cg.v.size())
				cg.col.fill(Color(1, 1, 1))
				U.mesh(cg, milk, holder)
			glass_at.append([sub_pts[int(sub_pts.size() / 2)], float(sub_r[0])])
	# beads of iron the lightning reduced from the sand: little bright spheres on the glass and in the crust
	if f.get("iron", false):
		var im := SpecMat.make({col = SpecMat.lin(0x9a9894), metal = 1.0, rough = 0.18})
		var bead := Geo.icosa(1.0, 2)
		for k in 10 + int(rng.next() * 12):
			if surf.is_empty(): break
			var p: Vector3 = surf[int(rng.next() * surf.size())]
			if glass_at.size() and rng.next() < 0.5:
				var ga: Array = glass_at[int(rng.next() * glass_at.size())]
				p = (ga[0] as Vector3) + Vector3(rng.next() - 0.5, rng.next() - 0.5, rng.next() - 0.5).normalized() * float(ga[1]) * 0.9
			var s := 0.006 + pow(rng.next(), 2.0) * 0.016
			var bi := U.mesh(bead, im, holder, p, Basis.from_scale(Vector3.ONE * s))
			bi.set_meta("col", true)
			beads.append([p, s])
	# dug out still in its sand: it stands, its roots going down into a heap of sand
	var sand_mi: MeshInstance3D = null
	if f.get("show", "loose") == "sand":
		# the heap buries the lower half: the roots go down into it, the throat stands out
		var bury := lo + (hi - lo) * 0.5
		var reach := 0.0
		for br: Dictionary in sk:
			for q in br.pts:
				if (q as Vector3).y < bury:
					reach = maxf(reach, Vector2((q as Vector3).x, (q as Vector3).z).length())
		var mg := _heap(rng, clampf(reach * 0.8, (hi - lo) * 0.25, (hi - lo) * 0.45), (hi - lo) * 0.5, int(f.seed))
		sand_mi = U.mesh(mg, sm, holder, Vector3(0, lo - (hi - lo) * 0.05, 0))
		sand_mi.set_meta("col", true)
	if f.get("show", "loose") == "sand":
		# upright, a little leaning, turned a bit to the viewer
		holder.transform = Transform3D(Basis(Vector3.UP, -0.6 + (rng.next() - 0.5) * 0.6) * Basis(Vector3.BACK, (rng.next() - 0.5) * 0.25) * Basis.from_scale(Vector3.ONE * gs * 0.9), Vector3(0, -(lo + hi) * 0.5 * gs * 0.9, 0))
	else:
		# lying loose: laid across the view, the throat to one side
		holder.transform = Transform3D(Basis(Vector3.UP, -0.6 + (rng.next() - 0.5) * 0.5) * Basis(Vector3.BACK, (0.9 + rng.next() * 0.5) * (1.0 if rng.next() < 0.5 else -1.0)) * Basis.from_scale(Vector3.ONE * gs), Vector3.ZERO)
		holder.position = -(holder.transform.basis * Vector3(0, (lo + hi) * 0.5, 0))
	# a fresh strike lights the sand round it
	if hot:
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.5, 0.18)
		lamp.light_energy = 1.4
		lamp.omni_range = (hi - lo) * 0.9
		lamp.position = Vector3(0, (lo + hi) * 0.5, 0.2)
		holder.add_child(lamp)
	# living lightning: the discharge runs down it again and again, sparks crackle over its crust, the glass flashes
	if gene.fx == "discharge":
		var bb := AABB(surf[0], Vector3.ZERO)
		for q in surf: bb = bb.expand(q)
		var bolt := SpecBolt.new()
		holder.add_child(bolt)
		if gm is ShaderMaterial and not hot:
			bolt.glass = gm as ShaderMaterial
		bolt.setup(bb, int(f.seed), Color(0.55, 0.65, 3.4), surf)
	var xf := U.rel_xform(holder, root)
	for k in mini(3, glass_at.size()):
		b._mark("glass", xf * (glass_at[k][0] as Vector3), Vector3.BACK)
	var top: Array = sk[0].pts
	b._mark("bore", xf * (top[0] as Vector3), (xf.basis * Vector3.UP).normalized())
	# the crust and its froth where branch.gdshader (mode 2) paints them: on the tubes themselves, the froth in its pits
	var sd := float(int(f.seed) % 997) * 0.37
	var fk := float(f.get("froth", 0.0))
	var crust := func(_p: Vector3, _uv: Vector2, _uv2: Vector2, c: Color) -> float: return float(c.r < 0.5 and c.a < 0.9)
	for at: Array in SpecMask.spots(tubes, root, crust, 2):
		b._mark("sand", at[0], at[1])
	if fk > 0.0:
		var pits := func(_p: Vector3, uv: Vector2, _uv2: Vector2, c: Color) -> float:
			if c.r > 0.5 or c.a > 0.9: return 0.0
			var vc := SpecMask.vor2(Vector2(uv.x * 2.2, uv.y * 26.0) + Vector2.ONE * (c.g * 37.0 + sd))
			return (1.0 - smoothstep(0.1, 0.3, vc.x)) * float(vc.z >= 1.0 - fk * 0.8)
		for at: Array in SpecMask.spots(tubes, root, pits, 3):
			b._mark("froth", at[0], at[1])
	# the biggest beads of iron
	beads.sort_custom(func(x: Array, y: Array) -> bool: return float(x[1]) > float(y[1]))
	for bd: Array in beads.slice(0, 3):
		b._mark("iron", xf * (bd[0] as Vector3), Vector3.ZERO)
	if hot and glass_at.size(): b._mark("hot", xf * (glass_at[0][0] as Vector3), Vector3.BACK)
	return first

## a heap of loose sand: a low mound, ripples and lumps on it
static func _heap(rng: Rng32, rad: float, h: float, seed_v: int) -> Geo:
	var nz := FastNoiseLite.new()
	nz.seed = seed_v + 31
	nz.frequency = 1.4
	var g := Geo.new()
	var na := 48
	var nr := 16
	# its top off the middle, its foot spread unevenly; on the viewer's side dug away, a scooped slope where the
	# fulgurite was freed (the viewer looks along -z, the find turned -0.6 about y by the holder)
	var peak := Vector2(rng.next() - 0.5, rng.next() - 0.5) * rad * 0.25
	var dig := Vector2(sin(0.6), cos(0.6))
	for i in na + 1:
		var a := TAU * float(i) / na
		for j in nr + 1:
			var t := float(j) / nr
			var rr := rad * t * (1.0 + 0.28 * nz.get_noise_2d(cos(a) * 1.4, sin(a) * 1.4))
			var tt := clampf(t - Vector2(cos(a), sin(a)).dot(peak) / rad * (1.0 - t), 0.0, 1.0)
			var y := h * pow(1.0 - tt * tt, 1.3) + h * 0.14 * nz.get_noise_2d(cos(a) * rr * 4.0, sin(a) * rr * 4.0) * (1.0 - t)
			var front := maxf(0.0, Vector2(cos(a), sin(a)).dot(dig))
			y *= 1.0 - 0.45 * front * smoothstep(0.2, 0.7, t)
			g.v.append(Vector3(cos(a) * rr, y, sin(a) * rr))
			g.rp.append(Vector3(rr * 14.0, float(i) / na, 0.3))
			g.col.append(Color(0, rng.next(), 0, 0.5))
	for i in na:
		for j in nr:
			var p0 := i * (nr + 1) + j
			var p1 := p0 + nr + 1
			g.idx.append_array([p0, p1, p0 + 1, p0 + 1, p1, p1 + 1])
	return g
