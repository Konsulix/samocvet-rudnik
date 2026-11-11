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

const PLANT := ["fern", "ginkgo", "redwood", "horsetail", "palm", "annularia", "lepido"]
const PLANT_N := {fern = "tree fern", ginkgo = "ginkgo leaves", redwood = "dawn redwood", horsetail = "horsetail",
	palm = "fan palm", annularia = "star leaves", lepido = "scale-tree bark"}
## the film: its colour, and the stone it lies on
const FILM := [
	{name = "carbon film", col = 0x141110, stone = 0x8e8a80},
	{name = "pyritized", col = 0xf0c858, stone = 0x34322f},
	{name = "silver film", col = 0xa9aeb0, stone = 0x2e2c2a},
	{name = "iron-stained", col = 0x8e3c16, stone = 0x7a664a},
	{name = "natural cast", col = 0xd6c6a2, stone = 0xd6c6a2},
	{name = "kaolinite", col = 0xece6da, stone = 0x8c8070},
	{name = "brown film", col = 0x4a2812, stone = 0xdccdaa},
	{name = "ammolite leaf", col = 0x1a1410, stone = 0x34322f},
	{name = "opal leaf", col = 0x101828, stone = 0x8a7a5a},
]
## crystals grown over the leaf where it rotted away: their colour, metal, shape
const CRYS := {
	pyrite = {name = "pyrite crystals", col = 0xe8c060, metal = 1.0, rough = 0.18, shape = "cube"},
	quartz = {name = "quartz druse", col = 0xc8d4dc, metal = 0.0, rough = 0.04, shape = "point"},
	amethyst = {name = "amethyst druse", col = 0xa060d8, metal = 0.0, rough = 0.06, shape = "point"},
	calcite = {name = "calcite crystals", col = 0xf0c070, metal = 0.0, rough = 0.12, shape = "point"},
}
## how far the split rock is tipped up to the viewer (the film's shader reads the rock's coordinates after it)
const LEAN := 0.9
const GUEST_N := {dragonfly = "dragonfly", fish = "little fish"}

static func genes(seed_v: int, tr: Array, o: Dictionary = {}) -> Dictionary:
	var rng := Rng32.new((seed_v * 2246822519 + 59) % 4294967296)
	var g := {kind = "fern"}
	g.plant = PLANT[int(Stones.pick_w([[0, 4.0], [1, 2.0], [2, 1.6], [3, 1.0], [4, 1.6], [5, 1.8], [6, 1.2]], rng))]
	g.film = int(Stones.pick_w([[0, 3.0], [1, 1.5], [2, 2.0], [3, 1.5], [4, 2.0], [6, 2.0], [7, 1.1], [8, 0.8]], rng))
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
	# the rock it split from: grey mudstone under carbon, black shale under pyrite and silver, ironstone under rust,
	# pale limestone (or white gypsum) under a cast and the Green River brown
	var rk := r2.next()
	# crystals grown into the hollow the leaf left
	var cr := r2.next()
	var ck := r2.next()
	g.crystals = "" if cr > 0.28 else String(Stones.pick_w([["pyrite", 3.0], ["amethyst", 2.5], ["calcite", 2.0], ["quartz", 1.0]], Rng32.new(int(ck * 100000.0))))
	g.fire_h = r2.next()
	# black manganese dendrites branching in from the slab's edge (they would not show on black shale)
	g.dendrites = not nod and dn < 0.35
	if "irid" in tr or "aurora" in tr:
		g.film = 1
		g.show = "slab"
	for k in ["plant", "film", "pair", "litter", "show", "guest", "dendrites", "crystals"]:
		if o.has(k): g[k] = o[k]
	# what does not go together: a big palm or a strip of bark will not fit a nodule; kaolinite is a nodule's film
	if g.show == "nodule" and g.plant in ["ginkgo", "palm", "lepido"]: g.show = "slab"
	if g.show == "nodule":
		g.guest = ""
		g.dendrites = false
	if int(g.film) in [1, 2]: g.dendrites = false
	if int(g.film) == 5 and g.show != "nodule": g.film = 4
	g.rock = ["limestone", "slate", "slate", "limestone", "limestone" if rk < 0.6 else "gypsum", "ironstone", "limestone", "slate", "limestone"][int(g.film)]
	# (crystals would be lost on a film that glitters or burns with colour already)
	if int(g.film) in [1, 7, 8] and not o.has("crystals"): g.crystals = ""
	if g.show == "nodule": g.rock = "ironstone"
	return g

static func accents(g: Dictionary) -> Array:
	var out := ["film", "plant"]
	if g.get("show", "") == "nodule": out.append("nodule")
	if g.get("pair", false): out.append("pair")
	if g.get("litter", false): out.append("litter")
	if String(g.get("guest", "")) != "": out.append("guest")
	if g.get("dendrites", false): out.append("dendrites")
	if String(g.get("crystals", "")) != "": out.append("crystals")
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
		"crystals": return String((CRYS.get(g.get("crystals", ""), {}) as Dictionary).get("name", ""))
	return ""

## rk: on a rock, what the film needs to be drawn as the rock itself ({scan, col (linear), to_film}); a nodule has none
static func film_mat(f: Dictionary, mould: bool, spring: bool, stone_c: Color, rk: Dictionary = {}) -> ShaderMaterial:
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
	m.set_shader_parameter("fire_h", float(f.get("fire_h", 0.3)))
	if rk.size():
		var i: int = rk.scan
		var rc: Color = rk.col
		m.set_shader_parameter("rocky", 1.0)
		m.set_shader_parameter("scan_diff", SpecMat.scan_tex(i, "diff"))
		m.set_shader_parameter("scan_nrm", SpecMat.scan_tex(i, "nor_gl"))
		m.set_shader_parameter("scan_rough", SpecMat.scan_tex(i, "rough"))
		m.set_shader_parameter("rock_col", Vector3(rc.r, rc.g, rc.b))
		m.set_shader_parameter("to_film", rk.to_film)
		m.set_shader_parameter("lean_a", LEAN)
		m.set_shader_parameter("peel", [0.5, 0.25, 0.4, 0.6, 0.0, 0.3, 0.5, 0.22, 0.15][int(f.film)])
	return m

static func build(b: RefCounted, gene: Dictionary, use_rock: Callable, st: Dictionary) -> MeshInstance3D:
	var f: Dictionary = gene.fossil
	var nod: bool = f.get("show", "") == "nodule"
	var root: Node3D = b.root
	var spring: bool = gene.fx == "spring"
	var pair: bool = f.get("pair", false)
	# the generator's own rock, split along a bedding plane: a flat face for the leaf, the living rock round it
	var srng := Rng32.new(int(f.seed) * 19 + 3)
	# (a nodule: a rounded ironstone lump split through its middle)
	var rk: MeshInstance3D = use_rock.call("chunk" if nod else "slab" if srng.next() < 0.7 else "chunk")
	var stone_c: Color = (rk.get_meta("base", Color(0.3, 0.3, 0.3)) as Color).linear_to_srgb()
	var sp := _split(rk, st, srng)
	# the plant's long axis along the face's longer side, sized to sit inside it
	var ea: float = maxf(sp.ex, sp.ez)
	var eb: float = minf(sp.ex, sp.ez)
	var k := ea / 0.95
	var rx := eb * 0.95 / k
	var rz := ea * 0.95 / k
	var yaw := PI * 0.5 if sp.ex >= sp.ez else 0.0
	yaw += (srng.next() - 0.5) * 0.25
	var t1 := Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3.ONE * k), Vector3(sp.cx, 0.0, sp.cz))
	var halves := [[t1, false, 0.0]]
	# the rock's top as heights: the leaf is laid over its relief, not printed on a plane
	var hf := _hfield(rk.get_meta("geo"))
	var scan := int(RockKit.SCAN_OF.get(String(gene.rock), 0))
	var rcol: Color = rk.get_meta("base", Color(0.3, 0.3, 0.3))
	if pair:
		# the counterpart: the other half of the split, its face the mirror of this one, laid beside it
		var rg: Geo = rk.get_meta("geo")
		var dz := rg.aabb().size.z * 1.04
		var mir := Transform3D(Basis(Vector3(-1, 0, 0), Vector3.UP, Vector3.BACK), Vector3(0, 0, dz))
		U.mesh(_mirror(rg, dz), rk.material_override, root)
		halves.append([mir * t1, true, dz])
	var main: MeshInstance3D = null
	for h: Array in halves:
		var mould: bool = h[1]
		var leaf := Node3D.new()
		root.add_child(leaf)
		leaf.transform = h[0]
		var made := _plant(f, rx, rz, mould)
		_drape(made.g, h[0], hf, mould, float(h[2]), 0.006)
		for key in ["pts", "lit", "gpts", "dpts"]:
			_drape_pts(made[key], h[0], hf, mould, float(h[2]))
		var rkd := {scan = scan, col = rcol, to_film = (h[0] as Transform3D).basis.inverse()}
		var mi := U.mesh(made.g, film_mat(f, mould, spring, stone_c, rkd), leaf)
		if made.gd:
			_drape(made.gd, h[0], hf, mould, float(h[2]), 0.0045)
			var dl := Node3D.new()
			leaf.add_child(dl)
			var dm := film_mat({film = 0, seed = f.seed}, false, false, stone_c, rkd)
			dm.set_shader_parameter("film_col", Color(0.07, 0.05, 0.04))
			dm.set_shader_parameter("relief", 0.25)
			U.mesh(made.gd, dm, dl)
		if main == null:
			main = mi
			_marks(b, root, leaf, made)
			if nod:
				var lx0 := U.rel_xform(leaf, root)
				b._mark("nodule", lx0 * Vector3(rx * 0.9, 0.0, 0.0), (lx0.basis * Vector3.UP).normalized())
			if String(f.get("crystals", "")) != "":
				var lx := U.rel_xform(leaf, root)
				for cp in _crystals(mi, leaf, String(f.crystals), k, Rng32.new(int(f.seed) * 23 + 1)):
					b._mark("crystals", lx * (cp as Vector3), (lx.basis * Vector3.UP).normalized())
		else:
			var xf2 := U.rel_xform(leaf, root)
			b._mark("pair", xf2 * Vector3.ZERO, xf2.basis * Vector3.UP)
	if spring:
		root.set_meta("dim", true)
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(0.5, 1.0, 0.4)
		lamp.light_energy = 0.3
		lamp.omni_range = 2.2
		lamp.position = Vector3(sp.cx, sp.y0 + 0.6, sp.cz)
		root.add_child(lamp)
	return main

## everything the leaf film holds, in the plant's own frame (its face an ellipse rx × rz round the origin)
static func _plant(f: Dictionary, rx: float, rz: float, mould: bool) -> Dictionary:
	var rng := Rng32.new(int(f.seed) * 7 + 5)
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
	# a film lying flat: its normal straight up, whichever way its triangles wind (the trunk keeps its round ones)
	var had := g.own_n.size()
	g.own_n.resize(g.v.size())
	for i in range(had, g.v.size()):
		g.own_n[i] = Vector3.UP
	var gd: Geo = null
	var dpts := []
	if f.get("dendrites", false):
		gd = Geo.new()
		dpts = _dendrites(gd, Rng32.new(int(f.seed) * 11 + (3 if mould else 1)), rx, rz)
		gd.own_n.resize(gd.v.size())
		gd.own_n.fill(Vector3.UP)
	return {g = g, pts = pts, lit = lit, gpts = gpts, gd = gd, dpts = dpts}

static func _marks(b: RefCounted, root: Node3D, leaf: Node3D, made: Dictionary) -> void:
	var xf := U.rel_xform(leaf, root)
	var up := (xf.basis * Vector3.UP).normalized()
	var pts: Array = made.pts
	for k in mini(3, pts.size()):
		b._mark("film", xf * (pts[int(k * pts.size() / 3)] as Vector3), up)
	if pts.size(): b._mark("plant", xf * (pts[0] as Vector3), up)
	if (made.lit as Array).size(): b._mark("litter", xf * (made.lit[0] as Vector3), up)
	for p in made.gpts:
		b._mark("guest", xf * (p as Vector3), up)
	for p in made.dpts:
		b._mark("dendrites", xf * (p as Vector3), up)

## split the rock along a flat bedding plane: everything above it pressed down onto it — a flat face with the rock's
## own broken outline. What grows on it (moss, lichen, mushrooms) is told to keep to the rim and the sides below the face.
static func _split(rk: MeshInstance3D, st: Dictionary, rng: Rng32) -> Dictionary:
	var g: Geo = rk.get_meta("geo")
	var lo := INF
	var hi := -INF
	for v in g.v:
		lo = minf(lo, v.y)
		hi = maxf(hi, v.y)
	var y0 := lo + (hi - lo) * (0.55 + rng.next() * 0.1)
	var face := []
	var rim := []
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for i in g.v.size():
		var v := g.v[i]
		if v.y >= y0:
			# the bedding plane it split along: the top eased down towards it, its weathered relief kept
			g.v[i] = Vector3(v.x, y0 + (v.y - y0) * 0.5, v.z)
			face.append(Vector2(v.x, v.z))
		elif v.y > y0 - (y0 - lo) * 0.45:
			rim.append(v)
	# the face's middle and reach (most of it: a lone spur of the outline does not count)
	var c := Vector2.ZERO
	for p: Vector2 in face:
		c += p
	c /= maxf(1.0, face.size())
	var dx: Array[float] = []
	var dz: Array[float] = []
	for p: Vector2 in face:
		dx.append(absf(p.x - c.x))
		dz.append(absf(p.y - c.y))
	dx.sort()
	dz.sort()
	var ex := dx[int(dx.size() * 0.93)] if dx.size() else 0.5
	var ez := dz[int(dz.size() * 0.93)] if dz.size() else 0.4
	# the face as its own sheet a hair above the rock: every triangle lying wholly in the plane
	var fg := Geo.new()
	var remap := {}
	for t in range(0, g.idx.size(), 3):
		var ok := true
		for j in 3:
			if g.v[g.idx[t + j]].y < y0 - 0.0001: ok = false
		if not ok: continue
		for j in 3:
			var vi := g.idx[t + j]
			if not remap.has(vi):
				remap[vi] = fg.v.size()
				var w := g.v[vi]
				fg.v.append(Vector3(w.x, y0 + 0.0012, w.z))
				fg.rp.append(Vector3(w.x, w.z, 0.0))
			fg.idx.append(int(remap[vi]))
	fg.own_n.resize(fg.v.size())
	fg.own_n.fill(Vector3.UP)
	if rim.size():
		st.pick = func() -> Vector3: return rim[int(floor(rng.next() * rim.size()))]
		st.pick_any = st.pick
	var hol: Array = st.get("hollows", [])
	st.hollows = hol.filter(func(hn: Array) -> bool: return (hn[0] as Vector3).y < y0 - 0.01)
	return {y0 = y0, cx = c.x, cz = c.y, ex = ex, ez = ez, face = fg}

## the rock mirrored left to right (its triangles turned back the right way out), moved dz along
static func _mirror(g: Geo, dz: float) -> Geo:
	var m := Geo.new()
	m.v = g.v.duplicate()
	for i in m.v.size():
		m.v[i] = Vector3(-m.v[i].x, m.v[i].y, m.v[i].z + dz)
	m.col = g.col.duplicate()
	m.rp = g.rp.duplicate()
	for i in m.rp.size():
		m.rp[i] = Vector3(-m.rp[i].x, m.rp[i].y + dz, m.rp[i].z)
	m.own_n = g.own_n.duplicate()
	m.idx = g.idx.duplicate()
	for t in range(0, m.idx.size(), 3):
		var s := m.idx[t + 1]
		m.idx[t + 1] = m.idx[t + 2]
		m.idx[t + 2] = s
	return m

## the camera looks nearly level: hold the split face up to the viewer, with everything that grew on the rock
static func lean(b: RefCounted, gene: Dictionary) -> void:
	var root: Node3D = b.root
	root.set_meta("face", true)
	var pv := Node3D.new()
	var kids := root.get_children()
	root.add_child(pv)
	pv.basis = Basis(Vector3.RIGHT, LEAN)
	for k: Node in kids:
		k.reparent(pv, false)
	var grown: Dictionary = b.grown
	for id: String in grown:
		for m: Array in grown[id]:
			m[0] = pv.basis * (m[0] as Vector3)
			m[1] = pv.basis * (m[1] as Vector3)

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

## a piece of a scale-tree trunk (Lepidodendron) lying half sunk in the rock: its rounded back covered in spiral rows
## of diamond leaf-cushions (pressed into the mesh too, so its outline is knobbly), both ends broken off ragged
static func _lepido(g: Geo, rng: Rng32, rx: float, rz: float) -> Array:
	var nz := FastNoiseLite.new()
	nz.seed = int(rng.next() * 9999.0)
	nz.frequency = 2.0
	var R := rx * (0.26 + rng.next() * 0.06)
	var L := rz * (1.85 + rng.next() * 0.15)
	var bend := (rng.next() - 0.5) * 0.5
	var cx := (rng.next() - 0.5) * rx * 0.2
	var sink := 0.42 + rng.next() * 0.12
	var th_m := acos(sink) * 1.08
	var tw := (rng.next() - 0.5) * 0.25
	var ca := R * 0.3     # cushion units: a diamond is 2 along by 2 across
	var cb := R * 0.2
	var nx := 110
	var ny := 44
	var b0 := g.v.size()
	var rnd := rng.next()
	for j in ny + 1:
		var th := -th_m + 2.0 * th_m * float(j) / ny
		var z0 := -L * 0.5 + L * 0.1 * (nz.get_noise_1d(th * 4.0) + 0.8)
		var z1 := L * 0.5 - L * 0.1 * (nz.get_noise_1d(th * 4.0 + 50.0) + 0.8)
		for i in nx + 1:
			var t := float(i) / nx
			var z := lerpf(z0, z1, t)
			var arc := R * th
			var u := z / ca
			var w := arc / cb + z * tw / cb
			var f := Vector2(fposmod(u * 0.5 + w * 0.5, 1.0), fposmod(u * 0.5 - w * 0.5, 1.0))
			var d := maxf(absf(f.x - 0.5), absf(f.y - 0.5)) * 2.0
			var r := R * (1.0 + 0.045 * (1.0 - d * d))
			# a gentle bow along it
			var bx := bend * R * (1.0 - pow(2.0 * z / L, 2.0))
			g.v.append(Vector3(cx + bx + r * sin(th), -sink * R + r * cos(th), z))
			g.own_n.append(Vector3(sin(th), cos(th), 0.0))
			g.rp.append(Vector3(u, w, t))
			g.col.append(Color(0, rnd, 0.7, 1))
	for j in ny:
		for i in nx:
			var a := b0 + j * (nx + 1) + i
			var a2 := a + nx + 1
			g.idx.append_array([a, a2, a + 1, a + 1, a2, a2 + 1])
	return [Vector3(cx, (1.0 - sink) * R, 0), Vector3(cx, (1.0 - sink) * R, L * 0.3), Vector3(cx, (1.0 - sink) * R, -L * 0.3)]

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

## crystals grown over the leaf: a crowd of little cubes (pyrite) or points (quartz, amethyst, calcite) on the film,
## catching the light one by one. In the leaf's frame (scaled k): sizes divided by k.
static func _crystals(mi: MeshInstance3D, leaf: Node3D, kind: String, k: float, rng: Rng32) -> Array:
	var cd: Dictionary = CRYS[kind]
	var pts := RockKit.surf_pts(mi, 700, rng, Callable(), leaf)
	if pts.is_empty():
		return []
	var col := Color.hex(int(cd.col) << 8 | 0xff)
	var m := SpecMat.make({col = col, metal = float(cd.metal), rough = float(cd.rough), flat = true, holo = 0.0 if float(cd.metal) > 0.5 else 0.35, seed = 5.0})
	var cube: bool = cd.shape == "cube"
	var geo: Geo = Geo.box(1, 1, 1) if cube else Geo.octa(1).scale(0.55, 1.5, 0.55)
	var place := func(i: int) -> Array:
		var p: Vector3 = pts[i][0]
		var s := (0.004 + pow(rng.next(), 2.2) * 0.014) / k
		var c := col * (0.8 + rng.next() * 0.45)
		c.a = 1.0
		var bs := Basis.from_euler(Vector3(rng.next() * 6.3, rng.next() * 6.3, rng.next() * 6.3))
		if not cube:
			bs = Basis(Vector3.UP, rng.next() * 6.3) * Basis(Vector3.RIGHT, (rng.next() - 0.5) * 1.6)
		return [Transform3D(bs * Basis.from_scale(Vector3.ONE * s), p + Vector3(0, s * 0.3, 0)), c]
	U.inst(geo, m, pts.size(), place, leaf)
	var out := []
	for i in mini(3, pts.size()):
		out.append(pts[i * pts.size() / 3][0])
	return out

## the rock's top as a grid of heights (root space): the highest surface over each cell, then widened a cell (so a
## film laid on it rides over the little bumps rather than sinking into them) and a smoothed copy (for normals and
## for the bark's trunk, which follows the rock's lie, not its grain)
static func _hfield(g: Geo, n := 140) -> Dictionary:
	var bb := g.aabb()
	var cs := maxf(bb.size.x, bb.size.z) / float(n - 1)
	var nx := int(bb.size.x / cs) + 3
	var nz := int(bb.size.z / cs) + 3
	var x0 := bb.position.x - cs
	var z0 := bb.position.z - cs
	var hd := PackedFloat32Array()
	hd.resize(nx * nz)
	hd.fill(-1e9)
	var tops := 0.0
	var ntop := 0
	for t in range(0, g.idx.size(), 3):
		var a := g.v[g.idx[t]]
		var b := g.v[g.idx[t + 1]]
		var c := g.v[g.idx[t + 2]]
		var den := (b.z - c.z) * (a.x - c.x) + (c.x - b.x) * (a.z - c.z)
		if absf(den) < 1e-12: continue
		var i0 := int((minf(a.x, minf(b.x, c.x)) - x0) / cs)
		var i1 := int((maxf(a.x, maxf(b.x, c.x)) - x0) / cs) + 1
		var j0 := int((minf(a.z, minf(b.z, c.z)) - z0) / cs)
		var j1 := int((maxf(a.z, maxf(b.z, c.z)) - z0) / cs) + 1
		for j in range(maxi(j0, 0), mini(j1, nz - 1) + 1):
			var pz := z0 + j * cs
			for i in range(maxi(i0, 0), mini(i1, nx - 1) + 1):
				var px := x0 + i * cs
				var l1 := ((b.z - c.z) * (px - c.x) + (c.x - b.x) * (pz - c.z)) / den
				var l2 := ((c.z - a.z) * (px - c.x) + (a.x - c.x) * (pz - c.z)) / den
				var l3 := 1.0 - l1 - l2
				if l1 < -0.001 or l2 < -0.001 or l3 < -0.001: continue
				var y := l1 * a.y + l2 * b.y + l3 * c.y
				var k := j * nx + i
				if y > hd[k]: hd[k] = y
	for k in hd.size():
		if hd[k] > -1e8:
			tops += hd[k]
			ntop += 1
	var fall := tops / maxf(1.0, ntop)
	# widen: the max over each cell's neighbours (rows, then columns)
	var w1 := hd.duplicate()
	for j in nz:
		for i in nx:
			var m := hd[j * nx + i]
			if i > 0: m = maxf(m, hd[j * nx + i - 1])
			if i < nx - 1: m = maxf(m, hd[j * nx + i + 1])
			w1[j * nx + i] = m
	var hw := w1.duplicate()
	for j in nz:
		for i in nx:
			var m := w1[j * nx + i]
			if j > 0: m = maxf(m, w1[(j - 1) * nx + i])
			if j < nz - 1: m = maxf(m, w1[(j + 1) * nx + i])
			hw[j * nx + i] = m
	# smooth: a box blur over valid cells, 4 cells each way (rows, then columns)
	var r := 4
	var s1 := PackedFloat32Array()
	s1.resize(nx * nz)
	for j in nz:
		for i in nx:
			var sum := 0.0
			var cnt := 0
			for q in range(maxi(0, i - r), mini(nx - 1, i + r) + 1):
				var v := hw[j * nx + q]
				if v > -1e8:
					sum += v
					cnt += 1
			s1[j * nx + i] = sum / cnt if cnt else -1e9
	var hs := PackedFloat32Array()
	hs.resize(nx * nz)
	for j in nz:
		for i in nx:
			var sum := 0.0
			var cnt := 0
			for q in range(maxi(0, j - r), mini(nz - 1, j + r) + 1):
				var v := s1[q * nx + i]
				if v > -1e8:
					sum += v
					cnt += 1
			hs[j * nx + i] = sum / cnt if cnt else -1e9
	return {x0 = x0, z0 = z0, cs = cs, nx = nx, nz = nz, hd = hw, hs = hs, fall = fall}

## a height off the grid at (x, z): bilinear over the valid corners
static func _hat(H: Dictionary, x: float, z: float, smooth := false) -> float:
	var arr: PackedFloat32Array = H.hs if smooth else H.hd
	var nx: int = H.nx
	var nz: int = H.nz
	var fx := clampf((x - float(H.x0)) / float(H.cs), 0.0, nx - 1.001)
	var fz := clampf((z - float(H.z0)) / float(H.cs), 0.0, nz - 1.001)
	var i := int(fx)
	var j := int(fz)
	var tx := fx - i
	var tz := fz - j
	# (the four corners in turn, written out: a list of lists here was twenty small arrays made per point of the film,
	# and a frond of half a million points took ten seconds to lay down)
	var k := j * nx + i
	var sum := 0.0
	var wsum := 0.0
	var v := arr[k]
	var w := (1.0 - tx) * (1.0 - tz)
	if v > -1e8:
		sum += v * w
		wsum += w
	v = arr[k + 1]
	w = tx * (1.0 - tz)
	if v > -1e8:
		sum += v * w
		wsum += w
	v = arr[k + nx]
	w = (1.0 - tx) * tz
	if v > -1e8:
		sum += v * w
		wsum += w
	v = arr[k + nx + 1]
	w = tx * tz
	if v > -1e8:
		sum += v * w
		wsum += w
	return sum / wsum if wsum > 0.0001 else float(H.fall)

static func _hnorm(H: Dictionary, x: float, z: float) -> Vector3:
	var e: float = H.cs * 1.5
	var dx := _hat(H, x + e, z, true) - _hat(H, x - e, z, true)
	var dz := _hat(H, x, z + e, true) - _hat(H, x, z - e, true)
	return Vector3(-dx, 2.0 * e, -dz).normalized()

## lay a film (built flat in the leaf's frame xf) over the rock: every point set down on the rock's top just above
## it, its normal the rock's there. The counterpart lies on the mirrored rock moved dz: its heights are the first's
## read through the mirror. The bark's trunk (its own round normals) is lifted whole onto the rock's lie.
static func _drape(g: Geo, xf: Transform3D, H: Dictionary, mir: bool, dz: float, eps: float) -> void:
	var inv := xf.affine_inverse()
	if g.own_n.size() != g.v.size():
		g.own_n.resize(g.v.size())
		g.own_n.fill(Vector3.UP)
	g.bary.resize(g.v.size())
	for i in g.v.size():
		var w := xf * g.v[i]
		var qx := -w.x if mir else w.x
		var qz := w.z - dz if mir else w.z
		var nr := _hnorm(H, qx, qz)
		if mir: nr.x = -nr.x
		if g.own_n[i] != Vector3.UP:
			# the trunk: follows the rock's lie as a whole, keeps its own round normal
			w.y += _hat(H, qx, qz, true)
			g.v[i] = inv * w
			g.bary[i] = w
			continue
		w.y += _hat(H, qx, qz) + eps
		g.v[i] = inv * w
		g.bary[i] = w
		g.own_n[i] = (inv.basis * nr).normalized()
	g._mesh = null

## the callouts' points set down on the rock the same way
static func _drape_pts(pts: Array, xf: Transform3D, H: Dictionary, mir: bool, dz: float) -> void:
	var inv := xf.affine_inverse()
	for i in pts.size():
		var w := xf * (pts[i] as Vector3)
		w.y = _hat(H, -w.x if mir else w.x, w.z - dz if mir else w.z) + 0.006
		pts[i] = inv * w
