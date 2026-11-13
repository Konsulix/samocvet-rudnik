class_name SpecFlower
extends RefCounted
## Inclusions: something whole held in clear stone — a smooth tumbled pebble (shaders/amber.gdshader) of clear or
## smoky quartz (ice-like cracks flashing white, a few bubbles) or of amber / copal (its resin run in flow lines,
## specks of bark, sun spangles, a weathered crust). What it holds:
##   an insect — a scan of a real dried specimen (assets/specimen/insects, CREDITS.md there; made light by
##              prototype/tools/insects/insect_prep.py: head +x, back +y, its longest reach one unit, colour and relief
##              baked into two textures, drawn by the mushrooms' shader without sway). Its group is the gene (`insect`:
##              wasps and bees, spiders and scorpions, beetles...); which of the group's models a find holds is its
##              seed's (`bug`, find_bug);
##   a plant — scans as well, laid the same way (`sprig`): a flowering sprig (content "flower") or a fern frond, an oak
##              leaf, acorns, pine cones (content "fern"). Nothing in it is drawn by code.
## Three finds use it: "flower_quartz" (a flower, in quartz mostly), "amber" and "simetite" (an insect mostly).

const U := preload("res://scripts/specimen/spec_util.gd")
const AMBER := preload("res://shaders/amber.gdshader")
## amber's colour: how fast it swallows red, green and blue along the way through it (per unit of the stone's
## radius) — thin it is pale, thick it deepens: lemon, honey, cognac, cherry
const TONES := {lemon = [Vector3(0.02, 0.14, 1.5), 1.5], honey = [Vector3(0.04, 0.32, 2.2), 4.0],
	cognac = [Vector3(0.15, 0.75, 3.0), 3.0], cherry = [Vector3(0.5, 1.8, 3.5), 1.0]}

## the insect groups (the gene, and the amber atlas's collection): [group, weight]
const INSECTS := [["wasp", 2.0], ["spider", 1.5], ["beetle", 3.0], ["cicada", 1.5], ["dragonfly", 1.0], ["moth", 1.2],
	["mantis", 1.0], ["other", 1.2]]
## the models of every group, and what a find holding each is called; k: its size beside the others (all are one unit
## at their longest reach: a centipede or a stick insect is long and thin, a beetle squat)
const BUGS := {
	wasp = [["wasp_hornet", "black-tailed hornet"], ["wasp_carpenter", "carpenter bee"]],
	spider = [["spider_argiope", "wasp spider"], ["spider_scorpion", "forest scorpion"], ["spider_scorpion_b", "scorpion"]],
	beetle = [["beetle_longhorn", "blue longhorn beetle"], ["beetle_fruit", "fruit chafer"], ["beetle_tiger", "tiger beetle"],
		["beetle_stag", "stag beetle"], ["beetle_diving", "diving beetle"], ["beetle_eudicella", "flower beetle"],
		["beetle_dynastes", "rhinoceros beetle"], ["beetle_cerambyx", "longhorn beetle"]],
	cicada = [["cicada_kaempfer", "cicada"], ["cicada_locust", "migratory locust"]],
	dragonfly = [["dragonfly_demoiselle", "demoiselle"], ["dragonfly_darner", "dragonfly nymph"]],
	moth = [["moth_fritillary", "fritillary caterpillar"], ["moth_tiger", "tiger moth"], ["moth_sphinx", "sphinx moth"],
		["moth_morpho", "blue morpho"], ["moth_luna", "luna moth"], ["moth_silk", "silk moth"]],
	mantis = [["mantis_korean", "mantis nymph"], ["mantis_stick", "stick insect"]],
	other = [["other_centipede", "centipede"], ["other_bug", "leaf-footed bug"], ["other_snail", "snail"]],
}
## plants held in it (scans too, laid the same way): a sprig in flower (content "flower"), or a leaf, acorns, pine
## cones, a fern frond (content "fern")
const SPRIGS := {
	flower = [["flower_camellia", "camellia sprig"], ["flower_azalea", "azalea"], ["flower_lotus", "lotus"],
		["flower_plum", "plum blossom"], ["flower_magnolia", "magnolia"]],
	fern = [["leaf_fern", "fern frond"], ["leaf_oak", "oak leaf"], ["leaf_oak_b", "acorns"], ["leaf_pine", "pine cones"]],
}
## the groups' names (the atlas, the awards)
const GROUPS := {wasp = "Wasps & bees", spider = "Spiders & scorpions", beetle = "Beetles", cicada = "Cicadas & locusts",
	dragonfly = "Dragonflies", moth = "Butterflies & moths", mantis = "Mantises & stick insects", other = "Odd ones"}
## the size of a model beside the others, of its longest reach (by default 0.85)
const BUG_K := {other_centipede = 1.0, mantis_stick = 1.0, other_snail = 0.8, beetle_fruit = 0.7, beetle_tiger = 1.0,
	wasp_carpenter = 0.75}
## the groups the code-drawn insects of old finds were (a saved gene may still name one)
const OLD := {ant = "wasp", fly = "wasp", mosquito = "dragonfly"}
const BUG_DIR := "res://assets/specimen/insects/"
static var _bug_mesh := {}
static var _bug_mat := {}
## hosts: [name, tint (linear), absorb, fractures, veils, bubbles, flow, debris, frost, inner glow]
const HOSTS := {quartz = "clear quartz", smoky = "smoky quartz", amber = "Baltic amber", copal = "copal", simetite = "Sicilian simetite"}
## simetite, Sicily's amber: deep wine-red to garnet (it swallows green and blue fast), glowing blue on its skin
const SIMETITE := Vector3(0.55, 2.9, 4.6)

static func genes(seed_v: int, sid: String, tr: Array, o: Dictionary = {}) -> Dictionary:
	var rng := Rng32.new((seed_v * 2246822519 + 77) % 4294967296)
	var g := {kind = sid}
	if sid == "simetite":
		g.host = "simetite"
		g.content = Stones.pick_w([["insect", 6.0], ["flower", 1.0], ["fern", 1.0]], rng)
	elif sid == "amber":
		g.host = Stones.pick_w([["amber", 4.0], ["copal", 1.5]], rng)
		g.content = Stones.pick_w([["insect", 7.0], ["flower", 2.0], ["fern", 1.5]], rng)
	else:
		g.host = Stones.pick_w([["quartz", 5.0], ["smoky", 2.0], ["amber", 1.0]], rng)
		g.content = "flower"
	g.insect = Stones.pick_w(INSECTS, rng)
	g.gold = (rng.next() < 0.3 or "goldfleck" in tr) and not g.host in ["amber", "copal", "simetite"]
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
	if g.host == "copal": g.cloud = maxf(float(g.cloud), 0.12)
	for k in ["host", "content", "insect", "gold", "bare", "tone", "spangle", "crust", "window", "cloud"]:
		if o.has(k): g[k] = o[k]
	if g.host == "copal" and not o.has("tone"): g.tone = "lemon"
	g.insect = OLD.get(g.insect, g.insect)
	g.bug = String(o.bug) if o.has("bug") else find_bug(seed_v, g.insect)
	if o.has("bug"): g.insect = group_of(g.bug)
	# a plant: a scan, picked by the seed like the insect (an old find's feather is a fern now)
	if g.content == "feather": g.content = "fern"
	if o.has("sprig"): g.content = "flower" if String(o.sprig).begins_with("flower_") else "fern"
	if g.content in SPRIGS:
		var l: Array = SPRIGS[g.content]
		var r := Rng32.new((seed_v * 40503 + 8191) % 4294967296)
		g.sprig = String((l[mini(int(r.next() * l.size()), l.size() - 1)] as Array)[0])
		if o.has("sprig"): g.sprig = String(o.sprig)
	return g

## which of its group's models a find holds: from the stone's seed (its own stream)
static func find_bug(seed_v: int, group: String) -> String:
	var l: Array = BUGS.get(OLD.get(group, group), BUGS.beetle)
	var r := Rng32.new((seed_v * 69621 + 4127) % 4294967296)
	return String((l[mini(int(r.next() * l.size()), l.size() - 1)] as Array)[0])

static func group_of(bug: String) -> String:
	for gk: String in BUGS:
		for e: Array in BUGS[gk]:
			if e[0] == bug: return gk
	return "beetle"

static func bug_name(bug: String) -> String:
	for d: Dictionary in [BUGS, SPRIGS]:
		for gk: String in d:
			for e: Array in d[gk]:
				if e[0] == bug: return String(e[1])
	return "insect"

static func accents(g: Dictionary) -> Array:
	var out := [{flower = "flower", insect = "insect", fern = "fern"}.get(g.content, "insect"), "stone"]
	if g.gold: out.append("gold_dust")
	if g.host in ["amber", "copal", "simetite"] and g.get("spangle", false): out.append("spangles")
	if g.host == "simetite": out.append("blue_glow")
	return out

static func gene_name(id: String, g: Dictionary) -> String:
	if id in ["flower", "fern"] and g.has("sprig"):
		return bug_name(String(g.sprig))
	match id:
		"insect": return bug_name(String(g.get("bug", find_bug(int(g.get("seed", 0)), String(g.get("insect", "beetle"))))))
		"stone": return String(HOSTS[g.host]) if not g.host == "amber" else "%s Baltic amber" % g.get("tone", "honey")
		"spangles": return "sun spangles"
		"blue_glow": return "blue fluorescence"
		"flower": return "flower"
		"fern": return "fern frond"
		"gold_dust": return "gold dust"
	return ""

# ---------------------------------------------------------------- insects

static func bug_mesh(bug: String) -> Mesh:
	if not _bug_mesh.has(bug):
		_bug_mesh[bug] = load(BUG_DIR + bug + ".obj") as Mesh
	return _bug_mesh[bug]

## the scan's own colour and relief, opaque (the amber's march through itself stops at it, by the depth buffer)
static func bug_mat(bug: String) -> ShaderMaterial:
	if not _bug_mat.has(bug):
		var m := ShaderMaterial.new()
		m.shader = SpecFungi.SHADER
		m.set_shader_parameter("tex_d", load(BUG_DIR + bug + "_d.png"))
		m.set_shader_parameter("tex_n", load(BUG_DIR + bug + "_n.png"))
		m.set_shader_parameter("gain", 1.55)
		m.set_shader_parameter("sat", 1.1)
		m.set_shader_parameter("rough", 0.35)
		_bug_mat[bug] = m
	return _bug_mat[bug]

## the insect, head towards +x, back up +y; about 1 long (its group `insect`, its model `bug` — or one by the seed)
static func _insect(parent: Node3D, rng: Rng32, f: Dictionary) -> Array:
	var bug := String(f.get("bug", find_bug(int(f.get("seed", 0)), String(f.get("insect", "beetle")))))
	var k := float(BUG_K.get(bug, 0.85)) / 0.85
	var mi := MeshInstance3D.new()
	mi.mesh = bug_mesh(bug)
	mi.material_override = bug_mat(bug)
	mi.scale = Vector3.ONE * k
	mi.set_meta("col", true)
	parent.add_child(mi)
	# (the callout: on its back, a little before the middle)
	var box := bug_mesh(bug).get_aabb()
	return [Vector3(0.05, box.end.y * 0.5, 0) * k]

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
	var resin: bool = f.host in ["amber", "copal", "simetite"]
	m.set_shader_parameter("sigma", SIMETITE if f.host == "simetite" else TONES[f.get("tone", "honey")][0] if resin else (Vector3(0.015, 0.012, 0.01) if f.host == "quartz" else Vector3(0.25, 0.32, 0.45)))
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
	if f.host == "simetite":
		m.set_shader_parameter("blue_k", 0.9)
		m.set_shader_parameter("light_col", Vector3(0.85, 0.5, 0.3))
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
	if f.has("sprig"):
		# a plant: lying flat in it as the insects do, face to the viewer
		inner.transform = Transform3D(face * lie * Basis(Vector3.UP, (rng.next() - 0.5) * 1.2) * Basis(Vector3.RIGHT, (rng.next() - 0.5) * 0.5) * Basis.from_scale(Vector3.ONE * 1.15), at)
		marks = _insect(inner, rng, {bug = f.sprig})
	else:
		# caught as it fell: turned any way, legs splayed
		var k := 1.1 if resin else 1.6
		inner.transform = Transform3D(face * lie * Basis(Vector3.UP, (rng.next() - 0.5) * 1.2) * Basis(Vector3.RIGHT, (rng.next() - 0.5) * 0.7) * Basis(Vector3.BACK, (rng.next() - 0.5) * 0.5) * Basis.from_scale(Vector3.ONE * k), at)
		marks = _insect(inner, rng, f)
	# gold dust settled under it
	var flakes := []
	if f.gold:
		var gm := SpecMat.make({col = SpecMat.lin(0xe8b84a), metal = 1.0, rough = 0.25, flat = true})
		var flake := Geo.icosa(1.0, 0)
		var place := func(k: int) -> Array:
			var p := Vector3((rng.next() - 0.5) * 0.9, -0.35 - rng.next() * 0.35, (rng.next() - 0.5) * 0.6)
			var s := 0.006 + pow(rng.next(), 3.0) * 0.025
			flakes.append([p, s])
			return [Transform3D(Basis(Vector3(rng.next(), rng.next(), rng.next()).normalized(), rng.next() * TAU) * Basis.from_scale(Vector3(s, s * 0.3, s)), p), Color(1, 1, 1)]
		U.inst(flake, gm, 90, place, holder)
	# every host a smooth tumbled pebble: amber, or clear / smoky quartz (shaders/amber.gdshader for both)
	var sg := _resin(rng, f)
	var stone := U.mesh(sg, amber_mat(f, sg), holder)
	stone.set_meta("col", true)
	stone.visible = not f.get("bare", false)
	# amber shows its face, turned a little so its thickness shows at one side
	var turn := Basis(Vector3.UP, -0.6 + 0.35 + (rng.next() - 0.5) * 0.3) * Basis(Vector3.RIGHT, -0.2 + (rng.next() - 0.5) * 0.3) * Basis(Vector3.BACK, (rng.next() - 0.5) * 0.8) if resin else Basis.IDENTITY
	holder.transform = Transform3D(turn * Basis.from_scale(Vector3.ONE * gs * (0.85 if resin else 0.75)), Vector3.ZERO)
	var ix := U.rel_xform(inner, root)
	# the biggest flakes of gold (marked once the holder is turned and scaled)
	flakes.sort_custom(func(x: Array, y: Array) -> bool: return float(x[1]) > float(y[1]))
	for fl: Array in flakes.slice(0, 3):
		b._mark("gold_dust", U.rel_xform(holder, root) * (fl[0] as Vector3), Vector3.ZERO)
	for p in marks:
		b._mark({flower = "flower", insect = "insect", fern = "fern"}.get(f.content, "insect"), ix * (p as Vector3), Vector3.BACK)
	b._mark("stone", U.rel_xform(holder, root) * Vector3(0.5, 0.6, 0.4), Vector3(0.5, 0.6, 0.6).normalized())
	# the sun spangles: discs of light through the whole of the amber
	if "spangles" in (gene.get("accents", []) as Array):
		b._mark("spangles", U.rel_xform(holder, root) * Vector3(-0.35, 0.3, 0.45), Vector3(-0.4, 0.3, 0.8).normalized())
	# simetite's blue glow is strongest at its rim
	if f.host == "simetite":
		b._mark("blue_glow", U.rel_xform(holder, root) * Vector3(-0.75, 0.15, 0.2), Vector3(-0.8, 0.1, 0.6).normalized())
	return stone
