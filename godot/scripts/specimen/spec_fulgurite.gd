class_name SpecFulgurite
extends RefCounted
## Fulgurite: lightning struck sand and fused it into branching tubes. Shown as a few crossing branches, crusted with
## the sand it caught — grainy, a few dark grains — and in stretches broken open to the glass inside: clear rods,
## a little smoky or milky, their ends snapped. Built on SpecBranch (sand: shaders/branch.gdshader mode 2; glass: the
## generator's own crystal glass, so it refracts like every other find's).

const U := preload("res://scripts/specimen/spec_util.gd")

const SAND := [0xa9a399, 0xa0907e, 0xc2bcb2, 0x8a847c]   # pale quartz sand, tan, white, grey-brown
const GLASS := [Color(0.93, 0.95, 0.97), Color(0.86, 0.84, 0.8), Color(0.82, 0.9, 0.86)]   # clear, smoky, faint green

static func genes(seed_v: int, tr: Array, o: Dictionary = {}) -> Dictionary:
	var rng := Rng32.new((seed_v * 3266489917 + 41) % 4294967296)
	var g := {kind = "fulgurite"}
	g.sand = int(rng.next() * SAND.size())
	g.glass = int(Stones.pick_w([[0, 4.0], [1, 2.0], [2, 1.0]], rng))
	g.open = 0.25 + rng.next() * 0.35        # how much of it is broken open to the glass
	g.branches = 2 + int(rng.next() * 2)
	g.seed = int(rng.next() * 100000.0)
	if "irid" in tr or "aurora" in tr: g.open = maxf(float(g.open), 0.5)
	for k in ["sand", "glass", "open", "branches"]:
		if o.has(k): g[k] = o[k]
	return g

static func accents(g: Dictionary) -> Array:
	return ["sand", "glass"]

static func gene_name(id: String, g: Dictionary) -> String:
	match id:
		"sand": return "fused sand crust"
		"glass": return "lightning glass %d%%" % roundi(float(g.open) * 100.0)
	return ""

static func build(b: RefCounted, gene: Dictionary) -> MeshInstance3D:
	var f: Dictionary = gene.fossil
	var rng := Rng32.new(int(f.seed) * 7 + 1)
	var root: Node3D = b.root
	var holder := Node3D.new()
	root.add_child(holder)
	var gs: float = gene.scale
	# a few crossing branches, each forking a little: as found, broken out of the sand
	var sk := []
	for k in int(f.branches):
		# long and nearly straight, crossing near the middle at a slant
		var part := SpecBranch.skeleton(rng, {r0 = 0.07 + rng.next() * 0.03, len0 = 1.6 + rng.next() * 0.6, levels = 1, kids = [1, 2],
			kid_r = 0.75, kid_len = 0.4, spread = 0.55, gnarl = 0.35, up = 0.0, taper = 0.7})
		var lean := (0.35 + rng.next() * 0.5) * (1.0 if k % 2 == 0 else -1.0)
		# all roughly in one plane, facing the viewer, as a piece lies on a table
		var turn := Basis(Vector3.BACK, lean) * Basis(Vector3.UP, (rng.next() - 0.5) * 0.8)
		var shift := Vector3((rng.next() - 0.5) * 0.3, (rng.next() - 0.5) * 0.3, (rng.next() - 0.5) * 0.2) - turn * Vector3(0, 0.9, 0)
		for br: Dictionary in part:
			var pts: Array = []
			for q in br.pts: pts.append(turn * (q as Vector3) + shift)
			br.pts = pts
			sk.append(br)
	var sm := ShaderMaterial.new()
	sm.shader = SpecBranch.SHADER
	sm.set_shader_parameter("mode", 2)
	sm.set_shader_parameter("seed", float(int(f.seed) % 997) * 0.37)
	sm.set_shader_parameter("c_light", Color.hex(int(SAND[int(f.sand)]) << 8 | 0xff))
	sm.set_shader_parameter("c_bark", Color.hex(0x2a2420ff))
	sm.set_shader_parameter("c_end", Color.hex(0xb8a688ff))
	sm.set_shader_parameter("sand_tex", load("res://assets/textures/dense_sand/dense_sand_diff_1k.jpg"))
	var tint: Color = GLASS[int(f.glass)]
	var gm := SpecMat.make({col = Color(1, 1, 1), glass = true, frost = 0.22, thick = 1.0, seed = 7.0})
	var milk := SpecMat.make({col = SpecMat.lin(0xe8e6e0), rough = 0.55})
	var first: MeshInstance3D = null
	var glass_at := []
	for k in sk.size():
		var br: Dictionary = sk[k]
		var n: int = (br.pts as Array).size()
		# stretches broken open to the glass
		var cuts := []
		var i := 1 + int(rng.next() * 3)
		while i < n - 2:
			if rng.next() < float(f.open) * 0.6:
				var ln := 4 + int(rng.next() * 4)
				cuts.append([i, mini(i + ln, n - 1)])
				i += ln + 5
			else:
				i += 3 + int(rng.next() * 4)
		var sand := SpecBranch.tube(br, {m = 16, sub = 3, lump = 0.3, ridge = 0.1, flat = 0.9, seed = int(f.seed) + k, glass = cuts}, false)
		var mi := U.mesh(sand, sm, holder)
		mi.set_meta("col", true)
		if first == null: first = mi
		# the glass inside: a thinner smooth rod over each open stretch, a little longer than it
		for c: Array in cuts:
			var i0 := maxi(0, int(c[0]) - 1)
			var i1 := mini(n - 1, int(c[1]) + 1)
			var sub_pts: Array = (br.pts as Array).slice(i0, i1 + 1)
			var sub_r: Array = []
			for q in (br.rad as Array).slice(i0, i1 + 1): sub_r.append(float(q) * 0.75)
			if sub_pts.size() < 3 or (sub_pts[0] as Vector3).distance_to(sub_pts[sub_pts.size() - 1]) < 0.02: continue
			var gb := {pts = sub_pts, rad = sub_r, depth = 1, rnd = rng.next()}
			var gg := SpecBranch.tube(gb, {m = 12, sub = 3, lump = 0.06, ridge = 0.03, flat = 0.95, seed = int(f.seed) + 99 + k}, true)
			gg.col.resize(gg.v.size())
			gg.col.fill(tint)
			var gi := U.mesh(gg, gm, holder)
			gi.set_meta("col", true)
			# the milky streak down its middle (where the sand only half melted), seen through the clear glass
			var core_r: Array = []
			for q in sub_r: core_r.append(float(q) * 0.3)
			var cg := SpecBranch.tube({pts = sub_pts, rad = core_r, depth = 1, rnd = gb.rnd}, {m = 8, sub = 3, lump = 0.25, ridge = 0.05, flat = 0.7, seed = int(f.seed) + 7 + k}, true)
			cg.col.resize(cg.v.size())
			cg.col.fill(Color(1, 1, 1))
			U.mesh(cg, milk, holder)
			glass_at.append(sub_pts[int(sub_pts.size() / 2)])
	holder.transform = Transform3D(Basis(Vector3.UP, -0.6 + (rng.next() - 0.5) * 0.6) * Basis.from_scale(Vector3.ONE * gs), Vector3.ZERO)
	var xf := U.rel_xform(holder, root)
	for k in mini(3, glass_at.size()):
		b._mark("glass", xf * (glass_at[k] as Vector3), Vector3.BACK)
	for k in 2:
		var br: Dictionary = sk[k % sk.size()]
		var pts: Array = br.pts
		var p: Vector3 = pts[int(pts.size() * (0.3 + 0.4 * k))]
		b._mark("sand", xf * (p + Vector3(0, float(br.rad[0]), 0)), Vector3.UP)
	return first
