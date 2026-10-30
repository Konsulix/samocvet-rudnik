class_name SpecimenBuilder
extends RefCounted
## Every find is a one-off mineral sculpture. build(o) turns a description into a Node3D:
##   {seed, sid, kind, gi, traits, cut, legend}  a specimen
##   {seed, jewel = {rid, cols}}                  a piece of jewellery
##   {machine = id}                               a machine for the depot
## Ported from the prototype's specimen.js (buildSpecimen / buildJewel / buildMachine), same seeds, same looks.
## The returned root carries meta "glow" (haze colour) and, for machines, "anim" ([node, axis, speed]).

const UP := Vector3.UP
const U := preload("res://scripts/specimen/spec_util.gd")

var rng: Rng32
var root: Node3D
var dt := {}            # where the crystals turn into rock; final values are applied in _finish()
var dt_mats := []
var crust_ok := true
var gene_m := {}
var trs := []             # the find's traits
var green_spots := []
## what really grew on the stone, so the card names nothing it doesn't show: gene id (a trait, an accent, or "fx")
## -> [[point, normal], ...] in the specimen's own space, where a callout can point at it
var grown := {}
var arng := Rng32.new(7)
var boxes := []            # every crystal's box in its own axes: {bounds, inverse}; no growth on the rock goes in one   # picks callout spots without touching the stone's own random stream

static func build(o: Dictionary) -> Node3D:
	var b := SpecimenBuilder.new()
	if o.has("machine"):
		return SpecMachines.build(o.machine)
	if o.has("jewel"):
		return SpecJewels.build(int(o.get("seed", 1)), o.jewel)
	return b._specimen(o)

# ---------------------------------------------------------------- specimen

static func quat_to_l(a: Vector3, b: Vector3) -> Quaternion:
	return U.quat_to(a, b.normalized())

func _rv() -> Vector3:
	return Vector3(rng.next() - 0.5, rng.next() - 0.5, rng.next() - 0.5)

func _place(node: Node3D, at: Vector3, dir: Vector3, s: float, spin: float) -> void:
	node.transform = Transform3D(Basis(U.quat_to(UP, dir.normalized())) * Basis(UP, spin) * Basis.from_scale(Vector3(s, s, s)), at)

## which way a foot at `at` sticks out past the rock's top (box rb), or zero when it stands on the rock
func _off_rock(at: Vector3, rb: AABB) -> Vector3:
	var c := rb.get_center()
	var off := Vector3((at.x - c.x) / (rb.size.x * 0.4), 0, (at.z - c.z) / (rb.size.z * 0.4))
	return off.normalized() if off.length() > 1.0 else Vector3.ZERO

## a crystal that broke off the block: it lies at the rock's foot on the side `out`, the body along the ground,
## tipped a little up, its flat side (local z, `thick` through) down; `back`: how far its foot sits below its origin
func _lay(c: MeshInstance3D, rb: AABB, out: Vector3, thick: float, back: float) -> void:
	var y := (out.rotated(UP, (rng.next() - 0.5) * 1.2) + UP * (0.1 + rng.next() * 0.2)).normalized()
	var z := (UP - y * UP.dot(y)).normalized()
	var ctr := rb.get_center()
	var foot := Vector3(ctr.x + out.x * rb.size.x * 0.38, rb.position.y + rb.size.y * 0.15 + thick * 0.5, ctr.z + out.z * rb.size.z * 0.38)
	c.transform = Transform3D(Basis(y.cross(z), y, z), foot + y * back)

func _mark(id: String, p: Vector3, n := Vector3.ZERO) -> void:
	if not grown.has(id):
		grown[id] = []
	(grown[id] as Array).append([p, n])

## a point inside a mesh, `f` of the way up its box, in the specimen's space (for what fills a crystal)
func _mid(m: Node3D, f := 0.5) -> Vector3:
	if not (m and m.has_meta("geo")):
		return Vector3.ZERO
	var bb := (m.get_meta("geo") as Geo).aabb()
	return U.rel_xform(m, root) * (bb.position + bb.size * Vector3(0.5, f, 0.5))

## a spot on a mesh's upper half, with its normal (for what colours or etches a whole surface)
func _mark_on(id: String, m: Node3D) -> void:
	if not (m and m.has_meta("geo")):
		_mark(id, Vector3.ZERO)
		return
	var bb := (m.get_meta("geo") as Geo).aabb()
	var y0 := bb.position.y + bb.size.y * 0.35
	var back := U.rel_xform(m, root).affine_inverse()
	var pts := RockKit.surf_pts(m, 1, arng, func(p: Vector3, _n: Vector3) -> bool: return (back * p).y > y0, root)
	if pts.is_empty():
		_mark(id, _mid(m, 0.6))
	else:
		_mark(id, pts[0][0], pts[0][1])

## another mineral on the same rock (SpecLooks with): "blades" — pale glassy tablets standing on it (celestine on
## sulphur); "crust" — a matte crust of small grains spread in patches over it (sulphur on aragonite, orpiment)
func _companion(what: String, c: Color, id: String, st: Dictionary) -> void:
	var r2 := Rng32.new(int(rng.next() * 100000.0) + 7)
	var top := func() -> Vector3:
		var b: Vector3 = st.pick.call()
		for k in 3:
			var q: Vector3 = st.pick.call()
			if q.y > b.y: b = q
		return b
	if what == "blades":
		var m := SpecMat.make({col = c, flat = true, glass = true, thick = 1.2, frost = 0.25, holo = 0.1, seed = r2.next() * 40.0, prio = 2, tint_body = 0.6})
		for k in 4 + int(r2.next() * 5):
			var p: Vector3 = top.call()
			var w := 0.07 + r2.next() * 0.07
			var g := RockKit.prism(r2, {sides = 4, w = w, d = w * 0.32, h = w * (2.2 + r2.next() * 2.0), point = false, slope = 0.9, y0 = -w * 0.6, detail = 1},
				{cA = c, cB = c, zk = 0.0})
			var mi := U.mesh(g, m, root)
			_place(mi, p, ((st.nrm.call(p) as Vector3).lerp(UP, 0.4) + _rv() * 0.6).normalized(), 1.0, r2.next() * TAU)
			mi.set_meta("col", true)
			if k == 0: _mark(id, _mid(mi, 0.6))
	else:
		var m := SpecMat.make({col = c, rough = 0.85, grain = 0.6, flat = true})
		var grain := Geo.icosa(1.0, 1)
		for patch in 4 + int(r2.next() * 4):
			var p0: Vector3 = st.pick.call()
			var n0: Vector3 = st.nrm.call(p0)
			if patch == 0: _mark(id, p0, n0)
			var place := func(k: int) -> Array:
				var off := (_rv() - n0 * _rv().dot(n0)) * 0.3
				var s := 0.014 + pow(r2.next(), 2.0) * 0.035
				return [Transform3D(Basis.from_scale(Vector3(s, s * 0.7, s)), p0 + off), Color(1, 1, 1)]
			U.inst(grain, m, 70 + int(r2.next() * 60), place, root)

## each crystal's box in its own axes (a leaning column's world box would cover the empty rock round its foot),
## a little bigger for the crust its foot still gets
func _crystal_boxes(main: MeshInstance3D, mat: ShaderMaterial) -> Array:
	var out := []
	for c: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var cm := c.material_override
		if not c.has_meta("geo") or not (c.get_meta("col", false) or c == main or (cm and (cm == mat or cm in dt_mats))):
			continue
		var xf := U.rel_xform(c, root)
		out.append({bounds = (c.get_meta("geo") as Geo).aabb().grow(0.03 / maxf(0.2, xf.basis.get_scale().x)), inverse = xf.affine_inverse()})
	return out

## a spot on the rock with no crystal over it
func _free(p: Vector3) -> bool:
	for b: Dictionary in boxes:
		if (b.bounds as AABB).has_point((b.inverse as Transform3D) * p):
			return false
	return true

func _rot_inst(p: Vector3, e: Vector3, sc: Vector3) -> Transform3D:
	return Transform3D(U.eul(e.x, e.y, e.z) * Basis.from_scale(sc), p)

func _specimen(o: Dictionary) -> Node3D:
	var seed_v: int = int(o.get("seed", 1))
	if seed_v == 0: seed_v = 1
	rng = Rng32.new((seed_v * 2654435761) % 4294967296)
	var sid: String = o.get("sid", "quartz")
	var sp: Dictionary = Data.SP.get(sid, Data.SP.quartz)
	var habit: String = Data.HABIT.get(sid, "prism")
	var tr: Array = o.get("traits", [])
	var gi: int = int(o.get("gi", 1))
	trs = tr
	var legend: bool = o.get("legend", false)
	root = Node3D.new()
	var col := SpecMat.lin_s(sp.c)
	col = SpecMat.offset_hsl(col, (rng.next() - 0.5) * 0.03, (rng.next() - 0.5) * 0.15, (rng.next() - 0.5) * 0.06)
	if gi < 2:
		col = col.lerp(SpecMat.lin(0xb8b4ac), 0.25 - gi * 0.1)
	var gene := SpecGenome.of(o)
	gene_m = gene
	# the traits the species always has (amethyst and fluorite are zoned): its look, on top of what it rolled
	var look := SpecLooks.of(sid)
	# the species' own colours (fluorite: green, purple, blue, yellow, colourless, pink), picked on their own stream
	var core_hex := int((look.get("core", [0]) as Array)[0])
	if look.has("palette"):
		var pal: Array = look.palette
		var pe: Array = Stones.pick_w(pal.map(func(e: Array) -> Array: return [e, e[2]]), Rng32.new((seed_v * 1597334677 + 31) % 4294967296))
		col = SpecMat.lin(int(pe[0]))
		if gi < 2:
			col = col.lerp(SpecMat.lin(0xb8b4ac), 0.25 - gi * 0.1)
		core_hex = int(pe[1])
	if (gene.sig as Array).size():
		tr = tr.duplicate()
		for t: String in gene.sig:
			if not t in tr: tr.append(t)
		trs = tr
	root.set_meta("genome", gene)
	root.set_meta("grown", grown)
	if gene.anomaly:
		# an anomaly: the stone grew in a colour its species never has, and glows faintly from inside
		col = SpecMat.offset_hsl(col, gene.hue, 0.3, 0.04)
	root.set_meta("glow", col)
	var irk := 1.9 if "aurora" in tr else 1.0 if "irid" in tr else 0.45 if legend else 0.14
	var metal := habit == "nugget" or sid in ["pyrite", "hematite"]
	var cut: String = o.get("cut", "")
	# a cut stone floats alone, tilted to show its table and pavilion
	if cut != "" and cut != "broken":
		var gm := SpecMat.make({col = col, flat = cut != "cab", glass = true, thick = 1.6, rf = 1.0, ir = 0.45 if cut == "master" else 0.2, seed = float(seed_v % 97), prio = 2})
		U.mesh(RockKit.gem(cut), gm, root, Vector3.ZERO, U.eul(-0.9 if cut == "cab" else PI - 0.55, 0, 0.15))
		return root

	# colour zoning along the crystals
	var zone := 1.0 if "zoned" in tr else 0.45 if rng.next() < 0.35 else 0.0
	var zmode := int(floor(rng.next() * 3))
	var zhue := 0.45
	if look.has("zone"):
		var zl: Array = look.zone
		zmode = int(zl[0])
		zone = float(zl[1])
		zhue = float(zl[2])
	var cA := col
	if zone > 0.0:
		cA = Color(1, 1, 1).lerp(col, 0.25) if zmode == 0 else col * 0.45 if zmode == 1 else SpecMat.offset_hsl(col, zhue, 0, 0)
	var cB := col
	# with the species' proportions (SpecLooks: hk, wk, blunt), which every crystal and column takes
	var zcfg := {cA = cA if zone > 0.0 else col, cB = cB, zk = zone, hk = float(look.get("hk", 1.0)), wk = float(look.get("wk", 1.0)),
		blunt = bool(look.get("blunt", false))}
	dt = {h = -99.0, a = 0.4, col = Color(0.1, 0.1, 0.1), fr = 0.7 if rng.next() < 0.5 else 0.0, local = false}
	var kind: String = o.get("kind", "crystal")
	var elongated := habit in ["prism", "blade", "barrel", "scaleno"]
	var needs_rock := "moss" in tr or "coral" in tr
	var layout: String = gene.form
	var rtype: String = gene.rock
	var gs: float = gene.scale
	var ero: float = gene.eroded
	if gene.lustre == "dark":
		ero = maxf(ero, 0.3)
	var scan: int = RockKit.SCAN_OF[rtype]
	dt.scan = scan
	# a species whose crystals do not frost over at the foot (SpecLooks foot_frost false)
	if not look.get("foot_frost", true):
		dt.fr = 0.0
		dt.fb = 0.0

	var st := {rocky = false, pick = func() -> Vector3: return Vector3.ZERO, nrm = func(v: Vector3) -> Vector3: return v.normalized(), rock = null, irk = irk,
		detail = 2 if layout in ["single", "columnar", "floater"] else 0 if layout == "geode" else 1, hollows = []}
	var stria := 1.0 if elongated else 0.0
	var cmat_spec := func() -> Dictionary:
		var irk2: float = st.irk
		if metal:
			# brassy metal crystals: striated faces, a rainbow tarnish here and there, sunk into the rock
			# (hematite: dark steel — SpecLooks metal_col)
			if look.has("metal_col"):
				# hematite's steel: darker, less mirror, its tarnish a rainbow in patches
				return {col = SpecMat.lin(int(look.metal_col)), metal = 0.95, rough = 0.3, coat = 0.6, coat_r = 0.08, flat = true, env = 2.6, oil = 0.5, st = 0.4, dirt = dt, prio = 2}
			return {col = Color(1, 1, 1), metal = 0.95, rough = 0.2, coat = 0.6, flat = true, env = 1.6, oil = 0.35, st = 1.0, dirt = dt, prio = 2}
		var op := 0.36 + (0.14 if gi < 2 else 0.0) if layout == "columnar" or layout == "cluster" else 0.8 if habit == "octa" or habit == "dodeca" else maxf(0.5, 0.82 - gi * 0.07)
		# an opaque species (SpecLooks opaque: aragonite's wax, realgar's resin): no glass, a lit surface of its colour
		if look.has("opaque"):
			var oq: Dictionary = look.opaque
			return {col = Color(1, 1, 1), rough = float(oq.get("rough", 0.35)), coat = float(oq.get("coat", 0.4)), coat_r = 0.15, flat = true, st = stria,
				dirt = dt, prio = 2, env = 1.3, grain = float(oq.get("grain", 0.1)), lava = 1.0 if gene.fx == "lava" else 0.0}
		# (SpecLooks ir: how much rainbow film and sheen the species takes — none on realgar's red or aragonite's milk)
		var irm := float(look.get("ir", 1.0))
		var d := {col = Color(1, 1, 1), flat = true, glass = true, ir = irk2 * 0.5 * irm, rf = 0.3, st = stria, dirt = dt, prio = 2,
			holo = float(gene.holo) * irm, emis = col * 0.35 if gene.anomaly else Color(0, 0, 0),
			lava = 1.0 if gene.fx == "lava" else 0.0,
			frost = float((look.get("glass", {}) as Dictionary).get("frost", 0.85 - gi * 0.3 if gi < 2 else 0.1 + rng.next() * 0.25)), thick = 1.0 + op * 0.4, seed = float(seed_v % 97),
			dark_body = float((look.get("glass", {}) as Dictionary).get("dark", 0.0)), tint_body = float((look.get("glass", {}) as Dictionary).get("tint", 0.0)),
			tint_glow = float((look.get("glass", {}) as Dictionary).get("glow", 0.06))}
		return d
	var make_cmat := func(d: Dictionary) -> ShaderMaterial:
		var m := SpecMat.make(d)
		if d.has("dirt"):
			dt_mats.append(m)
		return m
	var rock_mat := func(c: Color) -> ShaderMaterial:
		var rd := {col = Color(1, 1, 1), rough = 0.95, grain = 0.35, ao = 1.0, dirt = {h = 99.0, a = 0.3, col = c, fr = 0.0, scan = scan}, silv = gene.silv}
		if gene.fx == "lava": rd.lava = 1.0
		var rm := SpecMat.make(rd)
		rm.set_meta("rock", true)   # ultraviolet lights the crystals, never the rock
		st.rocky = true
		return rm
	var use_rock := func(shape: String) -> MeshInstance3D:
		var loose: float = gene.loose
		var R := RockKit.rock(rng, rtype, shape, 32, loose)
		var rm: ShaderMaterial = rock_mat.call(R.base)
		var mi := U.mesh(R.geo, rm, root)
		dt.col = R.base
		var top: Array = R.top
		st.hollows = R.hollows
		if loose > 0.0:
			_crumbs(rm, top, R.scale, loose)
		var sc: Vector3 = R.scale
		st.pick = func() -> Vector3: return top[int(floor(rng.next() * top.size()))] if top.size() else Vector3(0, 0.3, 0)
		st.nrm = func(w: Vector3) -> Vector3: return RockKit.rock_nrm(sc, w)
		st.rock = mi
		return mi
	if layout == "columnar" or layout == "cluster":
		irk = maxf(irk, 0.3)
		st.irk = irk
	var mat: ShaderMaterial = null
	if not metal and not (layout in ["nugget", "botryoid", "vein"]) and gene.lustre != "fossil":
		var d: Dictionary = cmat_spec.call()
		if gene.lustre == "dark":
			# a dark, lustrous stone: opaque, nearly black, an oil-slick rainbow sliding over it
			var dc: Color = gene.dark_col
			dt.fb = 0.15
			dt.fr = 0.0
			d = {col = dc, metal = 0.55, rough = 0.16, coat = 0.5, coat_r = 0.1, flat = true, oil = 1.0, st = stria, dirt = dt, prio = 2, env = 1.4,
				lava = 1.0 if gene.fx == "lava" else 0.0}
		d.merge(SpecLegend.shader_params(gene.fx, gene.fx_v), true)
		mat = make_cmat.call(d)
	var any_cmat := func() -> ShaderMaterial: return mat if mat else make_cmat.call(cmat_spec.call())
	var main: MeshInstance3D = null
	var crystal := func(h: float, s: float, at: Vector3, dir: Vector3, extra := {}, mo: ShaderMaterial = null, parent: Node3D = null) -> MeshInstance3D:
		var cfg := {h = h, tip = 0.05 if kind == "shard" or cut == "broken" else null, detail = st.detail, erode = ero if mo == null and parent == null else 0.0}
		cfg.merge(zcfg)
		cfg.merge(extra, true)
		var g := RockKit.crystal(habit, rng, cfg)
		var c := U.mesh(g, mo if mo else any_cmat.call(), parent if parent else root)
		_place(c, at, dir, s * gs, rng.next() * 6.28)
		return c
	var lean := func(d: Vector3, a: float) -> Vector3:
		return (d + Vector3((rng.next() - 0.5) * a, 0, (rng.next() - 0.5) * a)).normalized()

	match layout:
		"ammonite":
			main = SpecFossil.ammonite(self, gene, use_rock)
		"petrified_wood":
			main = SpecWood.build(self, gene)
		"fulgurite":
			main = SpecFulgurite.build(self, gene)
		"flower_quartz", "amber", "simetite":
			main = SpecFlower.build(self, gene)
		"trilobite":
			main = SpecTrilobite.build(self, gene, use_rock)
		"pearl":
			main = SpecPearl.build(self, gene)
		"obsidian":
			main = SpecObsidian.build(self, gene)
		"spray":
			# aragonite as Sicily gives it: a crowded ball of stubby six-sided columns, flat-ended, every way at once,
			# grown through each other on a little of its white rock, sulphur caught in the gaps
			use_rock.call(String(look.get("rock_shape", "small")))
			dt.local = true
			dt.h = 0.04 + rng.next() * 0.05
			dt.a = 0.25
			var cm: ShaderMaterial = any_cmat.call()
			var c0: Vector3 = st.pick.call()
			for k in 10:
				var q: Vector3 = st.pick.call()
				if q.y > c0.y: c0 = q
			# a ball: the columns start on a dome over the rock's top and point out from its middle
			# (sulphur's mound sits down on the rock, its foot hidden in it)
			var mid: Vector3 = c0 + Vector3(0, (0.05 if habit == "prism" else -0.12) * gs, 0)
			var gaps := []
			var nn := 90 + int(rng.next() * 40) if habit != "prism" else 150 + int(rng.next() * 50)
			for k in nn:
				var u := Vector3(rng.next() - 0.5, rng.next() * 0.9 - 0.15, rng.next() - 0.5).normalized()
				var p: Vector3 = mid + Vector3(u.x * 0.55, u.y * 0.4, u.z * 0.5) * gs * (0.5 + rng.next() * 0.45 if habit != "prism" else 0.62 + rng.next() * 0.2)
				gaps.append([p, u])
				var dir := (u + _rv() * 0.5).normalized()
				var w := (0.05 + pow(rng.next(), 1.3) * 0.06) * gs * (1.25 if habit == "prism" else 1.0)
				var h := w * ((0.8 + rng.next() * 0.9) if habit == "prism" else (1.4 + rng.next() * 1.6))
				var c: MeshInstance3D
				if habit == "prism":
					var g := RockKit.prism(rng, {sides = 6, w = w, d = w * (0.85 + rng.next() * 0.2), h = h, point = false, slope = 0.0, taper = 0.96, y0 = -w * 1.2, detail = 1, erode = ero * 0.5}, zcfg)
					c = U.mesh(g, cm, root)
					_place(c, p, dir, 1.0, rng.next() * TAU)
				else:
					# (sulphur's mound: its own bipyramids, big and small, crowded)
					var f := pow(rng.next(), 1.6)
					c = crystal.call(0.5 + f * 0.6, 0.3 + f * 0.5, p, (dir + UP * 0.9).normalized())
				c.set_meta("local", true)
				c.set_meta("col", true)
				if not main: main = c
			if "sulphur" in gene.accents:
				# sulphur grown in the gaps between the columns: lemon lumps of tiny crystals
				var sm := SpecMat.make({col = SpecMat.lin(0xf0d020), rough = 0.55, grain = 0.5, flat = true, emis = SpecMat.lin(0x5a4a04)})
				var nub := Geo.icosa(1.0, 1)
				for k in 3 + int(rng.next() * 3):
					var gp: Array = gaps[int(rng.next() * gaps.size())]
					var at: Vector3 = (gp[0] as Vector3) + (gp[1] as Vector3) * 0.04 * gs
					if k == 0: _mark("sulphur", at, gp[1])
					var place := func(i: int) -> Array:
						var s := (0.03 + pow(rng.next(), 2.0) * 0.07) * gs
						return [Transform3D(Basis.from_scale(Vector3(s, s * 0.8, s)), at + _rv() * 0.16 * gs), Color(1, 1, 1)]
					U.inst(nub, sm, 30 + int(rng.next() * 20), place, root)
		"platestack":
			# hematite's iron rose of plates: a big six-sided tablet of dark steel and on it smaller ones stacked in steps,
			# all turned the same way; tipped up towards the viewer so its face shows, its foot in a little rock
			var rk: MeshInstance3D = use_rock.call("small")
			rk.scale = Vector3(0.7, 0.7, 0.7)
			var cm: ShaderMaterial = any_cmat.call()
			var view := Basis(UP, -0.6) * Vector3.BACK
			for stack in 1 + int(rng.next() < 0.4):
				var face := (UP.lerp(view, 0.75) + _rv() * 0.25).normalized()
				var bs := Basis(quat_to_l(UP, face)) * Basis(UP, rng.next() * TAU)
				var w0 := (0.62 + rng.next() * 0.14) * gs * (1.0 if stack == 0 else 0.55)
				var base: Vector3 = Vector3(0, 0.05, 0) if stack == 0 else bs * Vector3(w0 * 0.9, 0.0, 0.0) + Vector3(0, -0.05, 0)
				var a0 := rng.next() * TAU
				var y := 0.0
				var w := w0
				for k in 8 + int(rng.next() * 5):
					var th := w0 * (0.09 + rng.next() * 0.04)
					var g := Geo.cylinder(w, w * 0.97, th, 6).translate(0, th * 0.5, 0)
					g.mark_edges()
					g.subdivide(1).jitter(w * 0.012, 4.0 / w, int(rng.next() * 100000))
					g.fill_color(Color(1, 1, 1))
					var c := U.mesh(g, cm, root)
					var off := Vector3((rng.next() - 0.5) * w0 * 0.08, y, (rng.next() - 0.5) * w0 * 0.08)
					# each plate a little tilted of its own: the steps catch the light one by one
					var tl := Basis(Vector3.RIGHT, (rng.next() - 0.5) * 0.16) * Basis(Vector3.BACK, (rng.next() - 0.5) * 0.16)
					c.transform = Transform3D(bs * tl * Basis(UP, a0 + (rng.next() - 0.5) * 0.08), base + bs * off)
					c.set_meta("col", true)
					y += th * 0.85
					w *= 0.8 + rng.next() * 0.08
					if not main: main = c
			# (no crust of rock climbing the steel)
			dt.h = -99.0
		"xenolith":
			# olivine brought up in a lava bomb: a dark lump of basalt broken open on a nodule packed with green grains,
			# olive to bottle-green to honey, a few gone rusty brown; the grains one mesh
			use_rock.call("chunk")
			var view := Basis(UP, -0.6) * Vector3.BACK
			var c0: Vector3 = st.pick.call()
			for k in 12:
				var q: Vector3 = st.pick.call()
				if (st.nrm.call(q) as Vector3).dot(view) + q.y > (st.nrm.call(c0) as Vector3).dot(view) + c0.y: c0 = q
			var n0: Vector3 = st.nrm.call(c0)
			var t1 := n0.cross(UP if absf(n0.y) < 0.9 else Vector3.RIGHT).normalized()
			var t2 := n0.cross(t1)
			var cols := [SpecMat.lin(0x6e7a18), SpecMat.lin(0x55661a), SpecMat.lin(0x8a8a24), SpecMat.lin(0x3c4a12), SpecMat.lin(0x9a8028), SpecMat.lin(0x5a3a16), SpecMat.lin(0x0e0e0c)]
			var nod := Geo.new()
			var R := (0.32 + rng.next() * 0.1) * gs
			for k in 700 + int(rng.next() * 160):
				var a := rng.next() * TAU
				var rr := sqrt(rng.next()) * R
				var s := (0.016 + rng.next() * 0.018) * gs
				var g := Geo.icosa(s, 1).to_soup()
				var sq := Vector3(1.0 + rng.next() * 0.3, 0.85 + rng.next() * 0.3, 1.0 + rng.next() * 0.2)
				var bs := Basis(U.eul(rng.next() * 6, rng.next() * 6, rng.next() * 6))
				var dome := sqrt(maxf(0.0, 1.0 - (rr / R) * (rr / R))) * R * 0.35
				# (packed: the nest's floor is grains too, no rock showing through)
				# a broken-open nest: the grains lie a little sunk in the face of the break
				var at := c0 + (t1 * cos(a) + t2 * sin(a)) * rr + n0 * (dome * 0.7 + R * 0.05 - s * 0.3)
				var cc: Color = (cols[int(Stones.pick_w([[0, 4.0], [1, 3.0], [2, 2.0], [3, 1.5], [4, 0.8], [5, 0.4], [6, 0.9]], rng))] as Color) * (0.45 + rng.next() * 0.35)
				for v in g.v:
					nod.v.append(at + bs * (v * sq))
					nod.col.append(cc)
			# (no crust on the grains: its islands showed as rusty blobs on the nest)
			var nd: Dictionary = cmat_spec.call()
			nd.erase("dirt")
			var nm := SpecMat.make(nd)
			main = U.mesh(nod, nm, root)
			main.set_meta("col", true)
			dt.h = -99.0
		"nugget":
			main = _nugget(sid, col)
		"vein":
			main = _vein(sid, col)
		"botryoid":
			_botryoid(sid, col, irk)
		"single":
			use_rock.call("small" if rng.next() < 0.6 else "chunk")
			var at := Vector3((rng.next() - 0.5) * 0.15, 0.22 if elongated else 0.1, (rng.next() - 0.5) * 0.15)
			main = crystal.call(1.15 + rng.next() * 0.5, 1.2 + rng.next() * 0.3, at, lean.call(UP, 0.35), {scepter = "scepter" in tr})
			dt.h = at.y + 0.1 + rng.next() * 0.25
			dt.a = 0.35
			for k in int(floor(rng.next() * 3)):
				var p: Vector3 = st.pick.call()
				crystal.call(0.45 + rng.next() * 0.5, 0.5 + rng.next() * 0.4, p, lean.call((st.nrm.call(p) as Vector3).lerp(UP, 0.5), 0.6))
			if "twin" in tr:
				var t: MeshInstance3D = crystal.call(1.0 + rng.next() * 0.4, 1.05, at, lean.call(Vector3(0.8, 1, 0.3), 0.3))
				t.rotate_object_local(Vector3.BACK, 0.6)
				_mark("twin", _mid(t, 0.7))
		"cluster":
			# a druse: a crumbling plate bristling with crystals of every size, their feet frosted and crusted over
			use_rock.call("slab" if rng.next() < 0.6 else "long")
			dt.local = true
			dt.h = 0.1 + rng.next() * 0.14
			dt.a = 0.3
			var cubic := habit == "cube"
			# (calcite's dogtooth scalenohedra keep their own shape: as columns they read as quartz)
			var prismy := (elongated or cubic) and habit != "scaleno"
			var cm: ShaderMaterial = any_cmat.call()
			var sides := 4 if cubic or habit == "blade" else 6
			var top_pick := func() -> Vector3:
				var b: Vector3 = st.pick.call()
				for k in 5:
					var c: Vector3 = st.pick.call()
					if c.y - Vector2(c.x, c.z).length() * 0.3 > b.y - Vector2(b.x, b.z).length() * 0.3:
						b = c
				return b
			for k in int((14 + int(floor(rng.next() * 14))) * float(look.get("dense", 1.0))):
				var f := pow(rng.next(), 1.8) if k else 1.0
				var p: Vector3 = st.pick.call() if k else top_pick.call()
				var dir: Vector3 = lean.call((st.nrm.call(p) as Vector3).lerp(UP, 0.55 if k else 0.85), 0.6 if k else 0.25)
				var c: MeshInstance3D
				if prismy:
					var w := (0.05 + f * 0.15) * (1.3 if cubic else 1.0) * gs
					var h := w * (1.3 + rng.next() * 0.7) if cubic else w * (3.0 + rng.next() * 3.5)
					var g := RockKit.prism(rng, {sides = sides, w = w, d = w * (0.6 if habit == "blade" else 0.75 + rng.next() * 0.35), h = h,
						point = not cubic and rng.next() < 0.7, slope = 0.5 if rng.next() < 0.3 else 0.0, y0 = -w * 0.8, detail = 1, erode = ero * 0.7}, zcfg)
					c = U.mesh(g, cm, root)
					_place(c, p, dir, 1.0, rng.next() * 6.28)
					c.set_meta("col", true)
				else:
					c = crystal.call(0.3 + f * 0.6, 0.35 + f * 0.6, p, dir)
				c.set_meta("local", true)
				if not main: main = c
		"columnar":
			# chunky columns pushing out of a crumbling rock that still climbs up their feet
			var R := RockKit.rock(rng, rtype, "small" if rng.next() < 0.5 else "chunk")
			dt.col = R.base
			var rm := U.mesh(R.geo, rock_mat.call(R.base), root)
			rm.transform = Transform3D(Basis.from_scale(Vector3(0.7, 0.7, 0.7)), Vector3(0, -0.2, 0))
			var rb: AABB = rm.transform * (R.geo as Geo).aabb()
			var cubic := habit == "cube"
			var sides := 4 if cubic or habit == "blade" or rng.next() < 0.3 else 6
			var axis: Vector3 = lean.call(UP, 0.3 if cubic else 0.55)
			var n := 4 + int(floor(rng.next() * 4)) if kind == "druse" else 1 + int(floor(rng.next() * 3))
			var cm: ShaderMaterial = any_cmat.call()
			# a column whose foot misses the rock broke off: it lies at the foot of the block, clean of the crust
			var loose_m := cm.duplicate() as ShaderMaterial
			for k in n:
				var at := Vector3((rng.next() - 0.5) * 0.55 if k else 0.0, -0.05, (rng.next() - 0.5) * 0.4 if k else 0.0)
				var lying := _off_rock(at, rb) != Vector3.ZERO
				var w := (0.13 + rng.next() * 0.17 if k else 0.27 + rng.next() * 0.13) * (1.25 if cubic else 1.0) * gs
				var h := w * (1.5 + rng.next() * 0.8) if cubic else (0.45 + rng.next() * 0.9 if k else 1.45 + rng.next() * 0.65) * gs
				if lying:
					h = minf(h, 0.55 * gs)
				var g := RockKit.prism(rng, {sides = sides, w = w, d = w * 0.62 if habit == "blade" else w * (0.7 + rng.next() * 0.45), h = h,
					point = not cubic and rng.next() < 0.45, slope = 0.4 + rng.next() * 1.1 if rng.next() < 0.65 else 0.0, detail = 2, erode = ero}, zcfg)
				var c := U.mesh(g, loose_m if lying else cm, root)
				c.set_meta("col", true)
				if lying: c.set_meta("lying", true)
				if lying:
					_lay(c, rb, _off_rock(at, rb), w, 0.0)
				else:
					_place(c, at, lean.call(axis, 1.2 if cubic else 0.35), 1.0, rng.next() * 6.28)
				if not main: main = c
			dt.h = 0.3 + rng.next() * 0.45
			dt.a = 0.5 + rng.next() * 0.5
		"radial":
			# a sunburst: crystals radiating from a small core
			var core := RockKit.rock(rng, rtype, "small")
			var cm2 := U.mesh(core.geo, rock_mat.call(core.base), root)
			cm2.scale = Vector3(0.85, 0.85, 0.85)
			for k in 14 + int(floor(rng.next() * 12)):
				var d := _rv().normalized()
				var c: MeshInstance3D = crystal.call(0.5 + rng.next() * 0.7, 0.55 + rng.next() * 0.45, d * 0.2, d)
				if not main: main = c
		"rosette":
			# a desert rose: tiers of blades fanned around the axis
			var rk: MeshInstance3D = use_rock.call("small")
			rk.scale = Vector3(0.7, 0.7, 0.7)
			# the rock shrank after its spots were taken: they shrink with it, or moss and plants hang in the air
			var raw_pick: Callable = st.pick
			var raw_nrm: Callable = st.nrm
			st.pick = func() -> Vector3: return (raw_pick.call() as Vector3) * 0.7
			st.nrm = func(w: Vector3) -> Vector3: return raw_nrm.call(w / 0.7)
			st.hollows = (st.hollows as Array).map(func(h: Array) -> Array: return [(h[0] as Vector3) * 0.7, h[1]])
			# a desert rose (SpecLooks rose): frosted petals full of sand; its petals keep their own length
			var rose_m: ShaderMaterial = null
			var rx := {hk = 1.0, wk = 1.0}
			if look.has("rose"):
				var rd: Dictionary = cmat_spec.call()
				rd.merge({frost = 1.0, holo = 0.0, ir = 0.04}, true)
				rd.merge(SpecLegend.shader_params(gene.fx, gene.fx_v), true)
				rose_m = make_cmat.call(rd)
				var rc: Array = look.rose
				rx.merge({cA = SpecMat.lin(int(rc[0])), cB = SpecMat.lin(int(rc[1])), zk = 1.0}, true)
			if rose_m:
				# a desert rose as they are found: no rock, a ball of thin blades crossing every way — each a ragged,
				# slightly cupped disc standing edge-out from the middle — sandy and dull, the blade edges bleached
				# pale; sometimes two or three roses grown together. All one mesh
				rk.visible = false
				var ca: Color = rx.cA
				var cb: Color = rx.cB
				var sand := SpecMat.make({col = Color(1, 1, 1), rough = 0.92, grain = 0.7, ao = 1.0, prio = 2})
				if look.get("rose_metal", false):
					# an iron rose: the same ball of blades in bright, dark steel
					sand = SpecMat.make({col = Color(1, 1, 1), metal = 0.6, rough = 0.45, coat = 0.1, env = 0.9, oil = 0.3, prio = 2})
				var balls := [[Vector3(0, 0.05, 0), 0.55 * gs]]
				for b_i in (0 if rng.next() < 0.55 else 1 + int(rng.next() * 2)):
					var dir := Vector3(cos(rng.next() * TAU), -0.2 - rng.next() * 0.3, sin(rng.next() * TAU)).normalized()
					var r2 := (0.3 + rng.next() * 0.12) * gs
					balls.append([Vector3(0, 0.05, 0) + dir * (0.55 * gs + r2) * 0.72, r2])
				var rose := Geo.new()
				for ball: Array in balls:
					var c0: Vector3 = ball[0]
					var R: float = ball[1]
					# the sand packed between the blades: a dull brown core that the gaps show
					var core := Geo.icosa(R * 0.72, 3).to_soup()
					for q in core.v.size():
						rose.v.append(core.v[q] * Vector3(1.0, 0.9, 1.0) + c0)
						rose.col.append(ca * 0.55)
					for k in int((230.0 * pow(R / 0.55, 2.0) + 20.0) * float(look.get("rose_n", 1.0))):
						var u := Vector3(rng.next() - 0.5, rng.next() - 0.5, rng.next() - 0.5).normalized()
						if u.y < -0.6: u.y = -u.y * 0.5
						u = u.normalized()
						var pr := R * (0.2 + rng.next() * 0.14) * float(look.get("rose_s", 1.0))
						# the blade: a disc of a middle, a ring half way and a ragged rim; brown sand in the middle,
						# paler out, the very edge bleached; cupped; both faces
						var nn := u.cross(Vector3.UP if absf(u.y) < 0.9 else Vector3.RIGHT).normalized().rotated(u, rng.next() * TAU)
						var bs := Basis(u, nn, u.cross(nn))
						var at := c0 + u * R * (0.55 + rng.next() * 0.3)
						var segs := 12
						var lobes := 3.0 + float(k % 4)
						var ph := rng.next() * TAU
						var ring := func(rf: float, side: float) -> Array:
							var out := []
							for q in segs:
								var a := TAU * q / segs
								var rag := 1.0 - 0.2 * absf(sin(a * lobes + ph)) if rf > 0.9 else 1.0
								out.append(bs * Vector3(cos(a) * pr * rf * rag, rf * rf * pr * 0.22 + side * pr * 0.025, sin(a) * pr * rf * rag) + at)
							return out
						var c_mid := ca
						var c_half := ca.lerp(cb, 0.6)
						var c_rim := cb if look.get("rose_metal", false) else cb.lerp(Color(0.9, 0.88, 0.84), 0.75)
						for side: float in [1.0, -1.0]:
							var mid: Vector3 = bs * Vector3(0, side * pr * 0.025, 0) + at
							var r1: Array = ring.call(0.6, side)
							var r2: Array = ring.call(1.0, side)
							for q in segs:
								var q2 := (q + 1) % segs
								var tris := [[mid, r1[q], r1[q2], c_mid, c_half, c_half], [r1[q], r2[q], r2[q2], c_half, c_rim, c_rim], [r1[q], r2[q2], r1[q2], c_half, c_rim, c_half]]
								for t: Array in tris:
									var o3 := [0, 1, 2] if side > 0.0 else [0, 2, 1]
									for e: int in o3:
										rose.v.append(t[e])
										rose.col.append(t[e + 3])
				var rm := U.mesh(rose, sand, root)
				rm.set_meta("col", true)
				main = rm
			else:
				for tier in 3:
					var n := 6 + int(floor(rng.next() * 4))
					for k in n:
						var a := float(k) / n * 6.28 + tier * 0.5 + rng.next() * 0.3
						var tilt := 0.55 + tier * 0.25 + rng.next() * 0.2
						var d := Vector3(cos(a) * sin(tilt), cos(tilt), sin(a) * sin(tilt))
						var c: MeshInstance3D = crystal.call(0.35 + rng.next() * 0.25, 0.7 + rng.next() * 0.3 - tier * 0.12, Vector3(0, 0.12 + tier * 0.1, 0), d, rx, rose_m)
						c.rotation.y += a
						if not main: main = c
		"slabs":
			# a stack of thick tabular plates fanning out of the rock, their tops broken off at a slant
			var rk: MeshInstance3D = use_rock.call("chunk" if rng.next() < 0.5 else "small")
			var rb: AABB = rk.transform * (rk.get_meta("geo") as Geo).aabb()
			var cm: ShaderMaterial = any_cmat.call()
			var loose_m := cm.duplicate() as ShaderMaterial
			var axis: Vector3 = lean.call(UP, 0.5)
			var common := Basis(quat_to_l(UP, axis)) * Basis(UP, rng.next() * TAU)
			var n := 3 + int(rng.next() * 4)
			var w0 := (0.22 + rng.next() * 0.16) * gs
			var off := -n * 0.5
			for k in n:
				var w := w0 * (0.6 + rng.next() * 0.6)
				var d := w * (0.22 + rng.next() * 0.2)
				var h := (0.7 + rng.next() * 0.9) * (1.0 if absf(k - n * 0.5) < 1.5 else 0.7)
				var at := common * Vector3(0, -0.05, (off + k) * d * 1.9) + Vector3((rng.next() - 0.5) * 0.1, 0, 0)
				var out := _off_rock(at, rb)
				if out != Vector3.ZERO:
					h = minf(h, 0.6)
				var g := RockKit.prism(rng, {sides = 4, w = w, d = d, h = h, point = false, slope = 0.6 + rng.next() * 1.2, taper = 0.95 + rng.next() * 0.1, y0 = -0.35, detail = 2, erode = ero}, zcfg)
				var c := U.mesh(g, loose_m if out != Vector3.ZERO else cm, root)
				var fan := Basis(Vector3.BACK, (k - n * 0.5) * (0.08 + rng.next() * 0.1)) * Basis(Vector3.RIGHT, (rng.next() - 0.5) * 0.25)
				if out != Vector3.ZERO:
					_lay(c, rb, out, d, 0.35)
					c.set_meta("lying", true)
				else:
					c.transform = Transform3D(common * fan, at)
					if not main: main = c
				c.set_meta("col", true)
			if not main: main = root.get_child(-1)
			dt.h = 0.25 + rng.next() * 0.3
			dt.a = 0.5
		"hopper":
			# skeletal cubes stepping in towards their middles, piled on one another
			use_rock.call("slab" if rng.next() < 0.5 else "chunk")
			dt.local = true
			dt.h = 0.04 + rng.next() * 0.08
			dt.a = 0.25
			var cm: ShaderMaterial = any_cmat.call()
			var placed := []
			for k in 9 + int(rng.next() * 10):
				var hs := (0.24 + rng.next() * 0.12 if k == 0 else 0.05 + pow(rng.next(), 1.5) * 0.17) * gs
				var at: Vector3
				var nn: Vector3
				if k > 0 and placed.size() and rng.next() < 0.35:
					var pr: Array = placed[int(rng.next() * placed.size())]
					nn = (Vector3(rng.next() - 0.5, rng.next() * 0.8 + 0.2, rng.next() - 0.5)).normalized()
					at = (pr[0] as Vector3) + nn * (float(pr[1]) * 0.9)
				else:
					at = st.pick.call()
					nn = st.nrm.call(at)
					at += nn * hs * 0.45
				var g := Geo.hopper(hs, 2 + int(rng.next() * 3), 0.22 + rng.next() * 0.12)
				g.mark_edges()
				g.subdivide(1).jitter(hs * 0.03, 4.0 / hs, int(rng.next() * 100000))
				g.fill_color(zcfg.cB)
				var c := U.mesh(g, cm, root)
				c.transform = Transform3D(Basis(quat_to_l(UP, lean.call(nn.lerp(UP, 0.5), 0.6))) * Basis(UP, rng.next() * TAU) * Basis(Vector3.RIGHT, (rng.next() - 0.5) * 0.4), at)
				c.set_meta("local", true)
				c.set_meta("col", true)
				placed.append([at, hs])
				if not main: main = c
		"pile":
			# a heap of chunky, glassy blocks crowding the top of the rock
			use_rock.call("chunk" if rng.next() < 0.6 else "slab")
			dt.local = true
			dt.h = 0.03 + rng.next() * 0.06
			dt.a = 0.2
			var cm: ShaderMaterial = any_cmat.call()
			var placed := []
			for k in 16 + int(rng.next() * 18):
				var hs := (0.09 + pow(rng.next(), 1.3) * 0.13) * gs
				var at: Vector3
				var nn: Vector3
				if placed.size() and rng.next() < 0.55:
					var pr: Array = placed[int(rng.next() * placed.size())]
					nn = Vector3(rng.next() - 0.5, rng.next() * 0.9 + 0.1, rng.next() - 0.5).normalized()
					at = (pr[0] as Vector3) + nn * (float(pr[1]) + hs) * 0.75
				else:
					at = st.pick.call()
					nn = st.nrm.call(at)
					at += nn * hs * 0.5
				var shape := rng.next()
				var g: Geo
				# a species with its own crystal shape heaps that (garnet's dodecahedra, cuprite's octahedra)
				if habit == "dodeca": shape = 0.6
				elif habit == "octa" or habit == "dipyr": shape = 0.9
				elif habit == "grain": shape = 0.95
				elif habit == "cube": shape = 0.1
				hs *= float(zcfg.wk)
				if shape > 0.92: g = Geo.icosa(hs * 1.1, 1).scale(1.0, 0.75 + rng.next() * 0.3, 0.9 + rng.next() * 0.2)
				elif shape < 0.5: g = Geo.box(hs * 2, hs * (1.6 + rng.next() * 0.8), hs * (1.6 + rng.next() * 0.6))
				elif shape < 0.8: g = Geo.dodeca(hs * 1.2).scale(1.0, 0.8 + rng.next() * 0.5, 1.0)
				else: g = Geo.octa(hs * 1.3).scale(1.0, 1.2 + rng.next() * 0.6, 1.0)
				g.fill_color(zcfg.cB)
				g.mark_edges()
				g.subdivide(3 if ero > 0.0 else 1).jitter(hs * 0.05, 3.0 / hs, int(rng.next() * 100000))
				if ero > 0.0: g.erode(ero, int(rng.next() * 100000))
				var c := U.mesh(g, cm, root)
				c.transform = Transform3D(U.eul(rng.next() * 6.3, rng.next() * 6.3, rng.next() * 6.3), at)
				c.set_meta("local", true)
				c.set_meta("col", true)
				placed.append([at, hs])
				if not main: main = c
		"hexplates":
			# stacks of flat hexagonal tablets, like barite or hematite roses
			use_rock.call("chunk")
			var cm: ShaderMaterial = any_cmat.call()
			for stack in 3 + int(rng.next() * 3):
				var base: Vector3 = st.pick.call()
				var nn: Vector3 = (st.nrm.call(base) as Vector3).lerp(UP, 0.4).normalized()
				var dir: Vector3 = lean.call(nn, 1.2)
				var bs := Basis(quat_to_l(UP, dir)) * Basis(UP, rng.next() * TAU)
				var w := (0.18 + rng.next() * 0.16) * gs
				for k in 3 + int(rng.next() * 4):
					var th := w * (0.16 + rng.next() * 0.12)
					var g := RockKit.prism(rng, {sides = 6, w = w * (1.0 - k * 0.06), d = w * (1.0 - k * 0.06), h = th, point = false, slope = 0.0, taper = 0.92, y0 = 0.0, detail = 1, erode = ero * 0.6}, zcfg)
					var c := U.mesh(g, cm, root)
					var tilt := Basis(Vector3.RIGHT, (rng.next() - 0.5) * 0.5) * Basis(Vector3.BACK, (rng.next() - 0.5) * 0.5)
					c.transform = Transform3D(bs * tilt, base + bs * Vector3((rng.next() - 0.5) * w * 0.3, k * th * 1.05, (rng.next() - 0.5) * w * 0.3))
					c.set_meta("col", true)
					if not main: main = c
			dt.h = 0.0 + rng.next() * 0.15
			dt.a = 0.3
		"floater":
			# a doubly terminated crystal that grew loose, with a satellite or two
			main = crystal.call(1.2 + rng.next() * 0.4, 1.25, Vector3.ZERO, Vector3(0.55 + rng.next() * 0.3, 1, 0.2), {dt = true, scepter = "scepter" in tr})
			for k in 1 + int(floor(rng.next() * 2)):
				var d := Vector3(rng.next() - 0.5, rng.next(), rng.next() - 0.5)
				crystal.call(0.35 + rng.next() * 0.3, 0.45, Vector3((rng.next() - 0.5) * 0.3, 0.3 + rng.next() * 0.5, (rng.next() - 0.5) * 0.2), d, {dt = true})
		"geode":
			main = _geode(sp, col, rtype, habit, elongated, metal, cmat_spec, make_cmat, crystal, st)
		"dendrite":
			# native metal grown as a little tree: branching twigs out of a piece of rock — copper beaded with small
			# crystals and patches of green patina; crystalline gold with flat bright platelets along its twigs
			var copper := sid == "nativecu"
			var rk: MeshInstance3D = use_rock.call("small")
			rk.scale = Vector3(0.75, 0.75, 0.75)
			var cu := SpecMat.make({col = SpecMat.lin(0xd2703a if copper else 0xf0c050), metal = 1.0, rough = 0.32 if copper else 0.22, coat = 0.2, env = 1.8,
				grain = 0.35, rough_var = 0.3, dirt = {h = -99.0, a = 0.3, col = SpecMat.lin(0x2f8a62 if copper else 0x7a4a18), fr = 0.0, isl = 0.3 if copper else 0.12, fb = 0.0}})
			var holder := Node3D.new()
			root.add_child(holder)
			var base: Vector3 = (st.pick.call() as Vector3) * 0.75
			for k in 4:
				var q: Vector3 = (st.pick.call() as Vector3) * 0.75
				if q.y > base.y: base = q
			holder.position = base - Vector3(0, 0.02, 0)
			holder.rotation.y = rng.next() * TAU
			var sk := SpecBranch.skeleton(rng, {r0 = (0.075 if copper else 0.055) * gs, len0 = 1.05 * gs, levels = 3, kids = [3, 4], kids2 = [2, 3], kid_r = 0.7,
				kid_len = 0.62, spread = 0.75, gnarl = 0.9, up = 0.9, taper = 0.45})
			var ms := SpecBranch.build(holder, sk, {m = 7, sub = 2, lump = 0.45, ridge = 0.0, flat = 0.85, seed = seed_v}, cu)
			for mi: MeshInstance3D in ms:
				mi.set_meta("col", true)
				# (the tubes carry the wood shader's data in their vertex colours, which would tint the metal)
				# (its mesh is made at the end, under the patina shader)
				(mi.get_meta("geo") as Geo).fill_color(Color(1, 1, 1))
			# little crystals beading the twigs: copper's octahedra, gold's flat hexagonal platelets
			var nub := Geo.octa(1.0) if copper else Geo.cylinder(1.0, 1.0, 0.14, 6)
			for br: Dictionary in sk:
				var pts: Array = br.pts
				var rad: Array = br.rad
				for i in range(2, pts.size(), 3):
					if rng.next() < (0.55 if copper else 0.8):
						var s := float(rad[i]) * ((1.1 + rng.next() * 0.9) if copper else (2.6 + rng.next() * 2.6))
						var c := U.mesh(nub, cu, holder, (pts[i] as Vector3) + _rv() * float(rad[i]) * 0.6, U.eul(rng.next() * 6, rng.next() * 6, rng.next() * 6) * Basis.from_scale(Vector3.ONE * s))
						c.set_meta("col", true)
			main = ms[0]

	# the species' companions (SpecLooks with): another mineral grown on the same rock
	if st.rocky and main:
		for w: Array in look.get("with", []):
			# (the spray puts its sulphur in its own gaps)
			if String(w[3]) in gene.accents and not (layout == "spray" and String(w[3]) == "sulphur"):
				_companion(String(w[0]), SpecMat.lin(int(w[1])), String(w[3]), st)
	# fluorite's phantom cubes (SpecLooks core): a cube of another colour inside every crystal, seen through the glass
	if look.has("core") and main and layout != "geode":
		var cc: Array = look.core
		var core_m := SpecMat.make({col = SpecMat.lin(core_hex), rough = 0.35, flat = true, emis = SpecMat.lin(core_hex) * 0.04})
		for n in root.find_children("*", "MeshInstance3D", true, false):
			var cm := (n as MeshInstance3D).material_override
			if not n.has_meta("geo") or n.has_meta("lying") or not (cm == mat or cm in dt_mats): continue
			var g: Geo = n.get_meta("geo")
			var bb := g.aabb()
			var inner := Geo.box(bb.size.x * float(cc[1]), bb.size.y * float(cc[1]), bb.size.z * float(cc[1]))
			U.mesh(inner, core_m, n, bb.get_center() + Vector3(0, bb.size.y * 0.06, 0))
	# genes that shape or colour the crystals themselves: there only if crystals grew
	var crystals := main != null and not (layout in ["nugget", "vein", "botryoid"])
	if "scepter" in tr and main and layout in ["single", "floater"] and habit in ["prism", "blade"]: _mark("scepter", _mid(main, 0.9))
	if "floater" in tr and layout == "floater": _mark("floater", _mid(main, 0.15))
	if "zoned" in tr and crystals: _mark_on("zoned", main)
	if "eroded" in tr and crystals and layout != "geode": _mark_on("eroded", main)
	for ti in ["irid", "aurora"]:
		if ti in tr and ((mat and gene.lustre != "dark") or layout == "botryoid"): _mark_on(ti, main)
	if "silver" in tr and st.rocky:
		# on the silver itself: spec.gdshaderinc lays it along one contour of the rock's ridge height (vertex green),
		# broken by a noise over the rock's coordinates (UV, UV2.x)
		var sv := func(_p: Vector3, uv: Vector2, uv2: Vector2, c: Color) -> float:
			return (1.0 - smoothstep(0.05, 0.09, absf(c.g - 0.82))) * smoothstep(0.3, 0.4, SpecMask.vn(Vector3(uv.x, uv.y, uv2.x) * 2.2 + Vector3(2, 2, 2)))
		var at: Array = SpecMask.spots([st.rock], root, sv, 3) if st.rock else []
		for q: Array in at: _mark("silver", q[0], q[1])
		if at.is_empty(): _mark_on("silver", st.rock if st.rock else main)
	if "anomaly" in tr: _mark_on("anomaly", main)
	if String(gene.fx) != "": _mark("fx", _mid(main, 0.65))

	# from here on whatever settles on the rock (plants, puffs, sprays, crusts, flakes, bubbles) keeps out of
	# the crystals: a spot under one is picked again, a few times, and the pits under them are dropped.
	# Moss and coral are the exception (`pick_any`, `hollows_all`): grown thick, the crystals look pushed up through them
	boxes = _crystal_boxes(main, mat)
	st.pick_any = st.pick
	st.hollows_all = st.hollows
	if boxes.size():
		var raw: Callable = st.pick
		st.pick = func() -> Vector3:
			var q: Vector3 = raw.call()
			for k in 12:
				if _free(q):
					break
				q = raw.call()
			return q
		st.hollows = (st.hollows as Array).filter(func(h: Array) -> bool: return _free(h[0]))

	match gene.fx:
		"jellyfish": SpecJelly.swarm(root, rng)
		"heart":
			SpecLegend.heart(root, main, rng, col)
			if main and main.material_override is ShaderMaterial:
				# the core glows through the main crystal's own glass, whatever the angle
				var hm := (main.material_override as ShaderMaterial).duplicate() as ShaderMaterial
				var bb: AABB = (main.get_meta("geo") as Geo).aabb()
				var hc := SpecLegend.heart_color(col) * 2.0
				hm.set_shader_parameter("heart_pos", bb.get_center() + Vector3(0, bb.size.y * 0.05, 0))
				hm.set_shader_parameter("heart_r", minf(bb.size.x, bb.size.z) * 0.32)
				hm.set_shader_parameter("heart_col", Vector3(hc.r, hc.g, hc.b))
				main.material_override = hm
				if mat in dt_mats: dt_mats.append(hm)
		"levitate": SpecLegend.levitate(root, mat if mat else any_cmat.call(), rng, habit, zcfg)
		"lightning":
			SpecLegend.lightning(main, rng)
			if main and main.material_override != mat and mat in dt_mats: dt_mats.append(main.material_override)
		"lava": SpecLegend.lava(root, st.rock if st.rock else main)
		"fluor":
			# nuggets, veins, kidneys, geodes and metal crystals build their own materials: light up every mineral,
			# but not the host rock
			root.set_meta("fluor", true)
			var fc: Color = SpecLegend.shader_params("fluor", gene.fx_v).fluor_col
			for n in root.find_children("*", "GeometryInstance3D", true, false):
				var gm := (n as GeometryInstance3D).material_override as ShaderMaterial
				if gm and gm.has_meta("dirt") and not gm.has_meta("rock"):   # made by SpecMat (asking the shader for its uniforms would stall the renderer)
					gm.set_shader_parameter("fluor_k", 1.0)
					gm.set_shader_parameter("fluor_col", Vector3(fc.r, fc.g, fc.b))
	crust_ok = layout != "geode"
	_inside(main, mat, habit, col, gi, tr, legend, layout, seed_v)
	if gene.gold:
		_gold(main, mat, st)
	_growths(main, mat, col, tr, layout, sid, st, legend)
	_accents(main, mat, gene, st, layout)
	# a trilobite's slab is held up to the viewer, everything that grew on it with it
	if layout == "trilobite":
		SpecTrilobite.lean(self, gene)
	_finish()
	# a sea find: sunlight through the water over it (its rock's mesh exists only now)
	if root.has_meta("sea"):
		SpecSea.caustics(root)
	if legend:
		root.set_meta("glow", U.raw(0xe4ae39))
	return root

# native metal: soft rounded lumps, hammered and pitted, with iron-oxide (or green patina on copper) packed into the hollows
func _nugget(sid: String, col: Color) -> MeshInstance3D:
	var copper := sid == "nativecu"
	var crust := SpecMat.lin(0x2f8a62 if copper else 0x5a3218)
	var mm := SpecMat.make({col = col, metal = 1.0, rough = 0.26 + rng.next() * 0.14, coat = 0.3, env = 1.7, grain = 0.15,
		dirt = {h = -99.0, a = 0.3, col = crust, fr = 0.0, isl = 0.45 if copper else 0.22, fb = 0.0}})
	var first: MeshInstance3D = null
	var lump := func(r: float, at: Vector3, o2 := {}) -> MeshInstance3D:
		var o := {r = r, sx = 1.2 + rng.next() * 0.3, sy = 0.7 + rng.next() * 0.25, sz = 1.0, wave = 0.16, bumps = [[14, 0.5, 0.14], [40, 0.2, 0.05]], pits = [30, 0.12, 0.05], seg = 72}
		o.merge(o2, true)
		var m := U.mesh(RockKit.crumble(rng, r, Vector3(o.sx, o.sy, o.sz)), mm, root, at, U.eul(rng.next() * 6.3, rng.next() * 6.3, rng.next() * 6.3))
		return m
	if not copper and rng.next() < 0.45:
		# gold set in a lump of milky vein quartz
		var Q := RockKit.lump(rng, {r = 0.55, sx = 1.25, sy = 0.85, sz = 1.0, wave = 0.22, bumps = [[8, 0.6, 0.12]], pits = [20, 0.15, 0.06], seg = 64})
		var qm := SpecMat.make({col = Color(1, 1, 1), rough = 0.6, grain = 0.3, ao = 1.0, dirt = {h = 99.0, a = 0.3, col = SpecMat.lin(0xd2d6dc), fr = 0.0}})
		var qg: Geo = RockKit.tint_cav(Q[0], Q[1], 0.5)
		first = U.mesh(qg, qm, root)
		var n := 3 + int(floor(rng.next() * 4))
		var k := 0
		var tries := 0
		while k < n and tries < 400:
			tries += 1
			var p := qg.v[int(floor(rng.next() * qg.v.size()))]
			if p.y < 0.1:
				continue
			lump.call(0.2 + rng.next() * 0.08 if k == 0 else 0.1 + rng.next() * 0.1, p * 0.93, {seg = 48})
			k += 1
	else:
		first = lump.call(0.5, Vector3.ZERO)
		for k in int(floor(rng.next() * 3)):
			lump.call(0.14 + rng.next() * 0.14, _rv().normalized() * 0.45, {seg = 48})
	return null

# native metal in vein quartz, as it is mined: a dull lump of milky quartz, the gold (or copper) filling the cracks
# that run over it — flattened, ragged patches strung along each crack, sunk into the stone, a few loose specks;
# rust-red oxide in the hollows (green patina on copper)
func _vein(sid: String, col: Color) -> MeshInstance3D:
	var copper := sid == "nativecu"
	var metal_c := SpecMat.lin(0xd9773a) if copper else SpecMat.lin(0xf0c050)
	var crust := SpecMat.lin(0x2f8a62) if copper else SpecMat.lin(0x7a2a10)
	var mm := SpecMat.make({col = metal_c, metal = 1.0, rough = 0.26, coat = 0.25, env = 1.8, grain = 0.5, rough_var = 0.4,
		dirt = {h = -99.0, a = 0.3, col = crust, fr = 0.0, isl = 0.4 if copper else 0.3, fb = 0.0}})
	# broken, not water-worn: few segments and flat faces give it the angular look of quarried quartz
	var Q := RockKit.lump(rng, {r = 0.6, sx = 1.3 + rng.next() * 0.2, sy = 0.85, sz = 1.0, wave = 0.3, bumps = [[5, 0.9, 0.2], [12, 0.4, 0.07]], pits = [10, 0.15, 0.05], seg = 20})
	# milky vein quartz: cold white, a little glossy
	var qm := SpecMat.make({col = Color(1, 1, 1), rough = 0.32, coat = 0.4, coat_r = 0.2, grain = 0.2, ao = 1.0, flat = true,
		dirt = {h = 99.0, a = 0.3, col = SpecMat.lin(0xc4c8ce if copper else 0xccd2da), fr = 0.0}})
	var qg: Geo = RockKit.tint_cav(Q[0], Q[1], 0.35)
	# the haze behind it: the quartz is most of the find, so a cool grey with only a hint of the metal's colour
	# (in the metal's own colour it tinted the white stone yellow)
	root.set_meta("glow", (root.get_meta("glow", col) as Color).lerp(Color(0.2, 0.24, 0.3), 0.75))
	var main := U.mesh(qg, qm, root)
	var qn := qg.normals()
	var near := func(p: Vector3) -> int:
		var best := 0
		var bd := INF
		for k in range(0, qg.v.size(), 3):
			var d := qg.v[k].distance_squared_to(p)
			if d < bd:
				bd = d
				best = k
		return best
	# the cracks run over the side the viewer sees (every find is shown turned 0.6 about y) and over the top
	var view := Basis(UP, -0.6) * Vector3.BACK
	var seen := func(vi: int) -> bool: return qn[vi].dot(view) > 0.25 or qn[vi].y > 0.6
	# the crack itself: a dark seam (sulphides) the metal sits in
	var seam := SpecMat.make({col = SpecMat.lin(0x2a2622), rough = 0.6, metal = 0.3})
	for c in 3 + int(rng.next() * 3):
		var vi := int(rng.next() * qg.v.size())
		for t in 60:
			if qg.v[vi].y > -0.1 and seen.call(vi): break
			vi = int(rng.next() * qg.v.size())
		var p := qg.v[vi]
		var d := qn[vi].cross(Vector3.UP if absf(qn[vi].y) < 0.9 else Vector3.RIGHT).normalized().rotated(qn[vi], rng.next() * TAU)
		var w := 0.08 + rng.next() * 0.07
		for k in 10 + int(rng.next() * 10):
			var nv: Vector3 = qn[vi]
			var sz := w * (0.5 + rng.next() * 0.9)
			var bs := Basis(U.quat_to(UP, nv)) * Basis(UP, rng.next() * TAU)
			U.mesh(RockKit.crumble(rng, sz * 0.9, Vector3(1.3, 0.1, 0.32)), seam, root, qg.v[vi] - nv * sz * 0.05, bs)
			if rng.next() < 0.7:
				U.mesh(RockKit.crumble(rng, sz, Vector3(1.6, 0.4, 1.1)), mm, root, qg.v[vi] + nv * sz * 0.04, bs)
			# along the crack: a step forward, wandering, back onto the stone
			d = (d + Vector3(rng.next() - 0.5, rng.next() - 0.5, rng.next() - 0.5) * 0.7).normalized()
			d = (d - nv * d.dot(nv)).normalized()
			vi = near.call(qg.v[vi] + d * sz * 1.3)
	# a nest or two of metal grown into the stone, half out of it
	for k in 1 + int(rng.next() * 2):
		var vi := int(rng.next() * qg.v.size())
		for t in 60:
			if seen.call(vi): break
			vi = int(rng.next() * qg.v.size())
		var sz := 0.14 + rng.next() * 0.08
		U.mesh(RockKit.crumble(rng, sz, Vector3(1.4, 0.75, 1.1)), mm, root, qg.v[vi] - qn[vi] * sz * 0.35, Basis(U.quat_to(UP, qn[vi])) * Basis(UP, rng.next() * TAU))
	# loose specks, most where they are seen
	for k in 12 + int(rng.next() * 10):
		var vi := int(rng.next() * qg.v.size())
		for t in 8:
			if seen.call(vi): break
			vi = int(rng.next() * qg.v.size())
		var sz := 0.025 + rng.next() * 0.045
		U.mesh(RockKit.crumble(rng, sz, Vector3(1.3, 0.4, 1.0)), mm, root, qg.v[vi] - qn[vi] * sz * 0.1, Basis(U.quat_to(UP, qn[vi])))
	return main

# one flowing mass of melted-together grapes (or a stand of rounded stalagmites), banded like a polished slab, weathered in the hollows
func _botryoid(sid: String, col: Color, irk: float) -> void:
	var banded := sid in ["malachite", "azurite", "chrysocolla"]
	var crust := SpecMat.lin(0x8a7a68 if sid == "opal" else 0x2a1a10 if banded else 0x4a3424)
	var bc := col * 0.6 if banded else col
	bc.a = 1.0
	var bm := SpecMat.make({col = bc, rough = 0.12 if sid == "opal" else 0.22, coat = 0.8, coat_r = 0.15, env = 1.4,
		ir = 0.95 if sid == "opal" else maxf(irk, 0.12), bd = 0.3 if banded else 0.0, dirt = {h = -0.3, a = 0.35, col = crust, fr = 0.0, isl = 0.08, fb = 0.0}})
	if rng.next() < 0.35:
		# rounded stalagmites crowded together on a crusty foot
		for k in 4 + int(floor(rng.next() * 5)):
			var len := 0.6 + rng.next() * 0.8
			var L := RockKit.lump(rng, {r = 0.5, sx = 0.34 + rng.next() * 0.12, sy = len, sz = 0.34 + rng.next() * 0.12, wave = 0.05, k = 160.0, bumps = [[24, 0.38, 0.2], [70, 0.15, 0.06]], seg = 48})
			var at := Vector3((rng.next() - 0.5) * 0.7, len * 0.35 - 0.2, (rng.next() - 0.5) * 0.5)
			U.mesh(RockKit.tint_cav(L[0], L[1], 0.6), bm, root, at, U.eul((rng.next() - 0.5) * 0.35, rng.next() * 6.3, (rng.next() - 0.5) * 0.35))
		var F := RockKit.lump(rng, {r = 0.55, sx = 1.3, sy = 0.35, sz = 1.0, wave = 0.1, k = 160.0, bumps = [[30, 0.32, 0.18], [90, 0.13, 0.06]], seg = 64})
		U.mesh(RockKit.tint_cav(F[0], F[1], 0.6), bm, root, Vector3(0, -0.3, 0))
	else:
		var M := RockKit.lump(rng, {r = 0.5, sx = 1.2 + rng.next() * 0.3, sy = 0.75 + rng.next() * 0.25, sz = 1.0, wave = 0.08, k = 160.0, bumps = [[30, 0.38, 0.26], [120, 0.13, 0.07]], seg = 72})
		U.mesh(RockKit.tint_cav(M[0], M[1], 0.8), bm, root)
		for k in int(floor(rng.next() * 3)):
			var L := RockKit.lump(rng, {r = 0.16 + rng.next() * 0.12, wave = 0.06, k = 160.0, bumps = [[16, 0.5, 0.26], [40, 0.18, 0.08]], seg = 48})
			U.mesh(RockKit.tint_cav(L[0], L[1], 0.6), bm, root, Vector3(rng.next() - 0.5, rng.next() * 0.6, rng.next() - 0.5).normalized() * 0.5)

# a cracked-open geode: rough shell, agate rind, a cave of crystals inside
func _geode(sp: Dictionary, col: Color, rtype: String, habit: String, elongated: bool, metal: bool, cmat_spec: Callable, make_cmat: Callable, crystal: Callable, st: Dictionary) -> MeshInstance3D:
	var shell := Node3D.new()
	root.add_child(shell)
	var R: Dictionary = RockKit.ROCKS["basalt" if rtype == "quartzite" else rtype]
	var outer := RockKit.warp(Geo.sphere(1, 64, 32, 0, TAU, 0, PI / 2), rng, 0.3, 1.6)
	var ocol := SpecMat.hsl(R.h[0], R.s[0] + 0.05, R.l[0] + 0.06).srgb_to_linear()
	var om := SpecMat.make({col = Color(1, 1, 1), rough = 0.95, flat = true, dirt = {h = 99.0, a = 0.3, col = ocol, fr = 0.0, scan = RockKit.SCAN_OF[rtype]}})
	om.set_meta("rock", true)
	var outer_mesh := U.mesh(outer, om, shell)
	var ic := col.lerp(Color(0.25, 0.27, 0.3), 0.6) * 0.35
	ic.a = 1.0
	U.mesh(Geo.sphere(0.9, 40, 20, 0, TAU, 0, PI / 2), SpecMat.make({col = ic, rough = 0.92, spec = 0.3, side = "back"}), shell)
	# a glittering carpet of tiny crystals over the cave wall
	var place := func(k: int) -> Array:
		var d := Vector3(rng.next() - 0.5, rng.next() * 0.98 + 0.02, rng.next() - 0.5).normalized()
		var e := Vector3(rng.next() * 3, rng.next() * 3, rng.next() * 3)
		var s := 0.008 + rng.next() * 0.014
		var c := col * (0.6 + rng.next() * 0.5)
		c.a = 1.0
		return [_rot_inst(d * 0.885, e, Vector3(s, s * 1.7, s)), c]
	U.inst(Geo.octa(1), SpecMat.make({rough = 0.08, coat = 1.0, flat = true, env = 2.4}), 800, place, shell)
	# agate rind: fine bands from the dark outer crust through grey and milky layers to a hint of the stone's own colour
	var hue := SpecMat.get_hsl(Color(sp.c)).x
	var band := func(t: float) -> Color:
		var r := t * 40.0
		var j := sin(r * 2.1) * 0.5 + sin(r * 0.37) * 0.5
		if t < 0.25:
			return SpecMat.hsl((20.0 + j * 8.0) / 360.0, 0.35 + j * 0.15, 0.12 + t * 0.4 + j * 0.06)
		return SpecMat.hsl(hue if t > 0.8 else (30.0 + j * 180.0) / 360.0, 0.3 if t > 0.8 else 0.06 + j * 0.08, 0.18 + t * 0.28 + j * 0.12)
	# a broken, uneven lip instead of a clean ring
	var rg := Geo.ring(0.74, 1.02, 64, 16)
	var wob := []
	for k in 4:
		wob.append([1 + int(floor(rng.next() * 9)), rng.next() * 6.3])
	for i in rg.v.size():
		var p := rg.v[i]
		var a := atan2(p.y, p.x)
		var r := Vector2(p.x, p.y).length()
		var t := (r - 0.74) / 0.28
		# the lip meets the warped shell at its actual edge, at every angle (the shell's last row of vertices)
		var edge: Vector3 = outer.v[32 * 65 + roundi(fposmod(PI - a, TAU) / TAU * 64.0)]
		var edge_r := Vector2(edge.x, edge.z).length()
		var n := 0.0
		for w in wob:
			n += sin(a * w[0] + w[1]) * 0.25
		n += sin(a * 37.0 + r * 9.0) * 0.12
		var rr := edge_r * (0.74 + t * 0.28)
		rg.v[i] = Vector3(cos(a) * rr, sin(a) * rr, (n * 0.05 + sin(a * 53.0) * 0.012) * (1.0 - absf(t - 0.5)))
	rg.col.resize(rg.v.size())
	for i in rg.v.size():
		var t := 1.0 - float(i / 65) / 16.0
		rg.col[i] = (band.call(clampf(t, 0.0, 1.0)) as Color).srgb_to_linear()
	var rim := U.mesh(rg, SpecMat.make({col = Color(1, 1, 1), rough = 0.8, flat = true, side = "double"}), shell)
	rim.rotation.x = PI / 2
	# pointed crystals crowding the cave: milky at their roots, deep colour at the tips
	var gd: Dictionary = cmat_spec.call()
	if not metal:
		gd.a = 0.8
		gd.emis = col * 0.18
	var gm: ShaderMaterial = make_cmat.call(gd)
	dt.local = true
	dt.h = 0.06 + rng.next() * 0.08
	dt.a = 0.2
	dt.col = Color(0.5, 0.5, 0.52)
	dt.fr = 0.0
	var c_root := Color(0.92, 0.93, 0.95).lerp(col, 0.45)
	var c_tip := SpecMat.offset_hsl(col, 0, 0.15, -0.08)
	var prismy := elongated or habit == "cube"
	var main: MeshInstance3D = null
	for k in 80 + int(floor(rng.next() * 40)):
		var d := Vector3(rng.next() - 0.5, rng.next() * 0.95 + 0.05, rng.next() - 0.5).normalized()
		var f := pow(rng.next(), 1.6)
		var dir := ((-d).lerp(UP, 0.15) + Vector3((rng.next() - 0.5) * 0.45, (rng.next() - 0.5) * 0.2, (rng.next() - 0.5) * 0.45)).normalized()
		var c: MeshInstance3D
		if prismy:
			var w := 0.05 + f * 0.13
			var h := w * 1.4 if habit == "cube" else minf(0.42, w * (2.4 + rng.next() * 2.2))
			var g := RockKit.prism(rng, {sides = 4 if habit == "cube" else 6, w = w, d = w * (0.8 + rng.next() * 0.3), h = h, point = habit != "cube", y0 = -w * 0.4}, {cA = c_root, cB = c_tip, zk = 1.0})
			c = U.mesh(g, gm, shell)
			_place(c, d * 0.86, dir, 1.0, rng.next() * 6.28)
		else:
			c = crystal.call(0.3 + f * 0.5, 0.4 + f * 0.5, d * 0.86, dir, {cA = c_root, cB = c_tip, zk = 1.0}, gm, shell)
		c.set_meta("local", true)
		if not main: main = c
	shell.transform = Transform3D(U.eul(-PI / 2 - 0.55, 0.35, 0), Vector3.ZERO)
	# moss, tufts and the rest settle on the outside of the shell
	st.rock = outer_mesh
	st.pick = func() -> Vector3:
		var pts := RockKit.surf_pts(outer_mesh, 1, rng, Callable(), root)
		return pts[0][0] if pts.size() else Vector3.ZERO
	st.nrm = func(v: Vector3) -> Vector3: return v.normalized()
	return main

# inside the main crystal: a ghost of an earlier crystal, golden rutile hairs, a milky core, inclusions and veils
func _inside(main: MeshInstance3D, mat: ShaderMaterial, habit: String, col: Color, gi: int, tr: Array, legend: bool, layout: String, seed_v: int) -> void:
	var ok := main != null and mat != null
	var h := 1.2
	var g: Geo = main.get_meta("geo") if main else null
	var bb := g.aabb() if g else AABB()
	if ok and "phantom" in tr:
		var pc := SpecMat.offset_hsl(col, 0.05, 0.2, -0.15)
		var ph := U.mesh(RockKit.crystal(habit, rng, {h = h * 0.7}), SpecMat.make({col = pc * 0.8, rough = 0.6, flat = true}), main)
		ph.transform = Transform3D(Basis.from_scale(Vector3.ONE * 0.62), Vector3(0, 0.05, 0))
		_mark("phantom", _mid(ph))
	if ok and "rutile" in tr:
		var gm := SpecMat.make({col = U.raw(0xd8a23a), metal = 1.0, rough = 0.25, emis = U.raw(0x3a2208)})
		var w := minf(bb.size.x, bb.size.z)
		var hh := bb.end.y - maxf(0.0, bb.position.y)
		for k in 22:
			var len := minf(hh * 0.7, w * 1.6) * (0.4 + rng.next() * 0.6)
			var at := Vector3(bb.get_center().x + (rng.next() - 0.5) * w * 0.4, maxf(0.0, bb.position.y) + hh * (0.25 + rng.next() * 0.45), bb.get_center().z + (rng.next() - 0.5) * w * 0.4)
			U.mesh(Geo.cylinder(0.004, 0.004, len, 4), gm, main, at, U.eul((rng.next() - 0.5) * 0.8, rng.next() * 3, (rng.next() - 0.5) * 0.8))
		_mark("rutile", _mid(main, 0.55))
	if ok and gi < 2:
		# a milky core: the glass clouds over inside
		mat.set_shader_parameter("frost_k", 1.1 - gi * 0.35)
	# the look of a fine specimen: things trapped inside the clear crystal
	var INC := [[0xe8b030, 0xe07020, 0xc02818, 0xf4e0b0], [0x8a4020, 0xb06030, 0x4a2010, 0xd09050], [0x1a1a1a, 0x3a3a3a, 0x6a6a6a, 0xe8e8e8], [0x2a4a2a, 0x4a6a3a, 0x1a2a1a, 0x8aa070]]
	var inc_i := int(floor(rng.next() * INC.size()))
	var inc_p := []
	for hx in INC[inc_i]:
		inc_p.append(SpecMat.lin(hx))
	set_meta("inc_p", inc_p)
	if ok and layout != "geode" and rng.next() < (1.0 if legend else 0.85 if layout == "columnar" else 0.5 + gi * 0.1):
		var cx := bb.get_center().x
		var cz := bb.get_center().z
		var rx := bb.size.x * 0.32
		var rz := bb.size.z * 0.32
		var y0 := maxf(bb.position.y, 0.05)
		var y1 := bb.position.y + bb.size.y * 0.82
		var clouds := []
		for k in 2 + int(floor(rng.next() * 3)):
			clouds.append(Vector3(cx + (rng.next() - 0.5) * rx, y0 + rng.next() * (y1 - y0), cz + (rng.next() - 0.5) * rz))
		var place := func(k: int) -> Array:
			var cl: Vector3 = clouds[k % clouds.size()]
			var v := Vector3((rng.next() - 0.5) * rx * 1.3, (rng.next() - 0.5) * 0.35, (rng.next() - 0.5) * rz * 1.3) * pow(rng.next(), 0.6) + cl
			v.x = cx + clampf(v.x - cx, -rx, rx)
			v.z = cz + clampf(v.z - cz, -rz, rz)
			v.y = clampf(v.y, y0, y1)
			var e := Vector3(rng.next() * 3, rng.next() * 3, rng.next() * 3)
			var s0 := 0.006 + pow(rng.next(), 3) * 0.05
			var sc := Vector3(s0, s0 * (0.25 + rng.next() * 0.4), s0 * (0.6 + rng.next() * 0.6))
			var c: Color = inc_p[int(floor(rng.next() * 4))] * (0.7 + rng.next() * 0.6)
			c.a = 1.0
			return [_rot_inst(v, e, sc), c]
		U.inst(Geo.icosa(1, 0), SpecMat.make({rough = 0.45, metal = 0.5 if inc_i == 0 else 0.2, flat = true}), 360, place, main)
		# smoky veils drifting through the body
		if rng.next() < 0.7:
			var wc: Color = inc_p[0] if rng.next() < 0.5 else Color(0.04, 0.04, 0.05) if rng.next() < 0.5 else Color(0.9, 0.9, 0.92)
			mat.set_shader_parameter("smoke_k", 0.45 + rng.next() * 0.4)
			mat.set_shader_parameter("smoke_col", Vector3(wc.r, wc.g, wc.b))

# flakes of native gold caught inside the crystal and scattered over the rock
func _gold(main: MeshInstance3D, mat: ShaderMaterial, st: Dictionary) -> void:
	var gm := SpecMat.make({col = SpecMat.lin(0xf2c35a), metal = 1.0, rough = 0.22, flat = true, env = 1.8})
	var flake := Geo.icosa(1, 0)
	var glass := main != null and mat != null
	if glass:
		var bb: AABB = (main.get_meta("geo") as Geo).aabb()
		var place := func(k: int) -> Array:
			var p := bb.position + Vector3(0.2 + rng.next() * 0.6, 0.15 + rng.next() * 0.7, 0.2 + rng.next() * 0.6) * bb.size
			var s := 0.006 + pow(rng.next(), 2.5) * 0.03
			return [_rot_inst(p, Vector3(rng.next() * 6, rng.next() * 6, rng.next() * 6), Vector3(s, s * 0.25, s * (0.6 + rng.next() * 0.6))), Color(1, 1, 1)]
		U.inst(flake, gm, 70 + int(rng.next() * 80), place, main)
		_mark("goldfleck", _mid(main, 0.65))
	if st.rock:
		var pick: Callable = st.pick
		var place2 := func(k: int) -> Array:
			var p: Vector3 = pick.call()
			var s := 0.008 + pow(rng.next(), 2.0) * 0.035
			return [_rot_inst(p, Vector3(rng.next() * 6, rng.next() * 6, rng.next() * 6), Vector3(s, s * 0.45, s)), Color(1, 1, 1)]
		U.inst(flake, gm, 40 + int(rng.next() * 60), place2, root)
		if not glass: _mark_on("goldfleck", st.rock)

# a crumbling rock sheds bits: chips lying on it, a few about to fall, sand in the hollows
func _crumbs(rm: ShaderMaterial, top: Array, sc: Vector3, loose: float) -> void:
	if top.is_empty():
		return
	for k in int(6 + loose * 18):
		var p: Vector3 = top[int(rng.next() * top.size())]
		var n := RockKit.rock_nrm(sc, p)
		var s := 0.02 + pow(rng.next(), 1.8) * 0.06
		U.mesh(RockKit.crumble(rng, s, Vector3(1.3, 0.6, 1.0)), rm, root, p + n * s * 0.25, Basis(U.quat_to(UP, n)) * Basis(UP, rng.next() * 6.3))
	var gm := SpecMat.make({col = dt.col * 1.6, rough = 0.9, flat = true})
	var place := func(k: int) -> Array:
		var p: Vector3 = top[int(rng.next() * top.size())]
		var s := 0.004 + rng.next() * 0.008
		return [_rot_inst(p * 1.005, Vector3(rng.next() * 6, rng.next() * 6, rng.next() * 6), Vector3.ONE * s), Color(1, 1, 1)]
	U.inst(Geo.icosa(1, 0), gm, int(150 + loose * 250), place, root)

# the accent genes: fibre pom-poms, straw hairs, lichen, dark spots and coloured clouds in the glass
func _accents(main: MeshInstance3D, mat: ShaderMaterial, gene: Dictionary, st: Dictionary, layout: String) -> void:
	var acc: Array = gene.accents
	if acc.is_empty():
		return
	var pal: Dictionary = gene.palette
	var cols := []
	for c in root.get_children():
		if c is MeshInstance3D and c.get_meta("col", false):
			cols.append(c)
	if main and not main in cols:
		cols.append(main)
	var on_rock := func() -> Array:
		if not st.rock:
			return []
		var q: Vector3 = st.pick.call()
		return [q, st.nrm.call(q)]
	var on_crystal := func() -> Array:
		if cols.is_empty():
			return []
		var pts := RockKit.surf_pts(cols[int(rng.next() * cols.size())], 1, rng, Callable(), root)
		return pts[0] if pts.size() else []
	var spot := func(crystal_first: float) -> Array:
		var a: Array = on_crystal.call() if rng.next() < crystal_first else on_rock.call()
		if a.is_empty(): a = on_rock.call() if rng.next() < 0.5 else on_crystal.call()
		return a
	var gs: float = gene.scale
	if "pompom" in acc:
		var pc: Array = SpecAccents.POMPOM[int(pal.pompom)]
		for k in 1 + int(rng.next() * 4):
			var a: Array = spot.call(0.6)
			if a.is_empty(): continue
			var ln := (0.16 + rng.next() * 0.14) * gs
			SpecAccents.tuft(root, rng, a[0], a[1], 450 + int(rng.next() * 350), ln, 0.012, 0.8, 0.2, pc)
			# the middle of the puff, not its root
			_mark("pompom", (a[0] as Vector3) + (a[1] as Vector3) * ln * 0.45, a[1])
	if "straw" in acc:
		var sc: Array = SpecAccents.STRAW[int(pal.straw)]
		for k in 2 + int(rng.next() * 3):
			var a: Array = spot.call(0.35)
			if a.is_empty(): continue
			# tangled hair: roots spread over a patch, long, strongly bent, every which way
			# all swept one way, like hair combed by water
			var sweep: Vector3 = ((a[1] as Vector3) + Vector3(rng.next() - 0.5, rng.next() * 0.3, rng.next() - 0.5) * 2.2).normalized()
			_mark("straw", a[0], a[1])
			for bend in [1.4, 2.4]:
				SpecAccents.tuft(root, rng, a[0], sweep, 80 + int(rng.next() * 80), (0.2 + rng.next() * 0.2) * gs, 0.008, 0.45, bend, sc, 0.09 * gs)
	var hollows: Array = st.get("hollows", [])
	var in_pits: bool = gene.nest == "hollows" and hollows.size() > 30
	var rock_spots := []
	if st.rock:
		for k in 700:
			var q: Vector3 = st.pick.call()
			rock_spots.append([q, st.nrm.call(q)])
	var nest_spots: Array = hollows if in_pits else rock_spots
	if "lichen" in acc and st.rock:
		var lt: Color = SpecAccents.LICHEN[int(pal.lichen)]
		for k in (5 + int(rng.next() * 5)) if in_pits else (2 + int(rng.next() * 4)):
			var c0: Vector3 = nest_spots[int(rng.next() * nest_spots.size())][0]
			var top := SpecPlants.cushion(root, rng, nest_spots, c0, (0.06 + rng.next() * 0.07) if in_pits else (0.1 + rng.next() * 0.14), 0.012, lt)
			_mark("lichen", c0, nest_spots[0][1] if top.is_empty() else (top[0][1] as Vector3))
			for q in mini(4, top.size()):
				var tp: Array = top[(q * top.size()) / 4]
				_mark("lichen", tp[0], tp[1])
	# little plants root where there is moss, or in the pits, or anywhere on the rock
	# where moss grew under a crystal, nothing roots in it there
	var open_green := green_spots.filter(func(g: Array) -> bool: return _free(g[0]))
	var green: Array = open_green if open_green.size() else nest_spots
	if green.size():
		if "fronds" in acc:
			var fp: Array = SpecAccents.FROND[int(pal.frond)]
			for k in 1 + int(rng.next() * 3):
				var at: Array = green[int(rng.next() * green.size())]
				SpecAccents.fronds(root, rng, [at], 8 + int(rng.next() * 9), (0.3 + rng.next() * 0.22) * gs, fp)
				_mark("fronds", at[0], at[1])
		if "flowers" in acc:
			var fc: Color = SpecAccents.FLOWER[int(pal.flower)]
			for k in 1 + int(rng.next() * 3):
				var c0: Array = green[int(rng.next() * green.size())]
				var near := []
				for g2 in green:
					if (g2[0] as Vector3).distance_to(c0[0]) < 0.12: near.append(g2)
				SpecAccents.flowers(root, rng, near if near.size() else [c0], 4 + int(rng.next() * 7), (0.12 + rng.next() * 0.08) * gs, fc)
				_mark("flowers", c0[0], c0[1])
	if "mushrooms" in acc and nest_spots.size():
		# their own random stream too: the rest of the stone stays as it was
		var fr := Rng32.new((int(gene.shroom_seed) * 69069 + 12345) % 4294967296)
		var kind: int = gene.shroom
		var tiny := kind == 3
		for k in 1 + int(fr.next() * (3.0 if tiny else 2.0)):
			var n := (4 + int(fr.next() * 6)) if tiny else (2 + int(fr.next() * 4))
			var cap: Array = SpecFungi.cluster(root, fr, nest_spots, kind, n, (0.22 + fr.next() * 0.14) * gs * (0.6 if tiny else 1.0), boxes)
			if cap.size(): _mark("mushrooms", cap[0], cap[1])
	if mat and main and gene.lustre == "glass":
		if "inkspots" in acc:
			var had := main.get_child_count()
			SpecAccents.inkspots(main, rng, 3 + int(rng.next() * 9))
			# each spot where it sits in the glass
			for k in range(had, main.get_child_count()):
				_mark("inkspots", U.rel_xform(main.get_child(k) as Node3D, root).origin)
		if "clouds" in acc:
			var cc: Color = SpecAccents.CLOUDS[int(pal.clouds)]
			mat.set_shader_parameter("smoke_k", 0.75 + rng.next() * 0.25)
			mat.set_shader_parameter("smoke_col", Vector3(cc.r, cc.g, cc.b) * 0.6)
			_mark("clouds", _mid(main, 0.8))

# crusts, tufts, sprays, moss and bubbles on the rock and the crystals
func _growths(main: MeshInstance3D, mat: ShaderMaterial, col: Color, tr: Array, layout: String, sid: String, st: Dictionary, legend: bool) -> void:
	var cols := []
	for c in root.get_children():
		if c is MeshInstance3D and (c.get_meta("col", false) or (mat and c.material_override == mat)):
			cols.append(c)
	var inc_p: Array = get_meta("inc_p") if has_meta("inc_p") else [Color(0.8, 0.5, 0.2)]
	var pick: Callable = st.pick
	var pick_any: Callable = st.get("pick_any", st.pick)
	var nrm: Callable = st.nrm
	var dloc: bool = dt.local
	var dh: float = dt.h
	if cols.size() and dh > -50.0 and layout != "geode" and (sid == "pyrite" or rng.next() < 0.35):
		# bright little cubes, pyrite or galena, perched where crystal meets rock
		var pts := []
		if dloc:
			for k in 22:
				var q: Vector3 = pick.call()
				pts.append([q, nrm.call(q)])
		else:
			for m in cols:
				pts.append_array(RockKit.surf_pts(m, 14, rng, func(p: Vector3, n: Vector3) -> bool: return absf(p.y - dh - 0.05) < 0.22 and n.y > -0.3))
			pts = pts.slice(0, 26)
		var pc := SpecMat.lin(0xd8c890 if rng.next() < 0.6 else 0xc8ccd2)
		var place := func(k: int) -> Array:
			var p: Vector3 = pts[k][0]
			var nn: Vector3 = pts[k][1]
			var s0 := 0.03 + pow(rng.next(), 2) * 0.08
			return [_rot_inst(p + nn * s0 * 0.15, Vector3(rng.next() * 3, rng.next() * 3, rng.next() * 3), Vector3.ONE * s0), pc]
		U.inst(Geo.box(1, 1, 1), SpecMat.make({metal = 1.0, rough = 0.18, env = 1.6, flat = true}), pts.size(), place, root)
	if cols.size() and ("coral" in tr or rng.next() < 0.2):
		# a rusty, scruffy tuft of fine needles clinging to the crystal
		var at := []
		for m in cols:
			at.append_array(RockKit.surf_pts(m, 3, rng, func(p: Vector3, n: Vector3) -> bool: return dloc or dh < -50.0 or p.y > dh - 0.05))
		at = at.slice(0, 1 + int(floor(rng.next() * 2)))
		if "coral" in tr and at.size(): _mark("coral", at[0][0], at[0][1])
		var rc := [SpecMat.lin(0x9a3a12), SpecMat.lin(0xc8601e), SpecMat.lin(0x5a200a), SpecMat.lin(0xe08a3a)]
		for pn in at:
			var p: Vector3 = pn[0]
			var nn: Vector3 = pn[1]
			# hair-fine needles bursting from one point, splayed along the surface
			var place := func(k: int) -> Array:
				var d := (nn * (0.25 + rng.next() * 0.6) + _rv().normalized()).normalized()
				var c: Color = rc[int(floor(rng.next() * 4))] * (0.6 + rng.next() * 0.7)
				c.a = 1.0
				var ln := 0.03 + pow(rng.next(), 0.6) * 0.06
				return [Transform3D(Basis(U.quat_to(UP, d)) * Basis.from_scale(Vector3(0.0025, ln, 0.0025)), p + d * rng.next() * 0.008), c]
			U.inst(Geo.cone(1, 1, 4).translate(0, 0.5, 0), SpecMat.make({rough = 0.55, metal = 0.3}), 260, place, root)
	# a sparkling crust of tiny crystals over the big one
	if main and "druzy" in tr:
		# spread over the faces, not stacked on the mesh's corners (those stood in rings round the prism);
		# light sparkling grains half sunk into the face rather than dark glass beads
		var pts := RockKit.surf_pts(main, 420, rng)
		var dc := col.lerp(Color(1, 1, 1), 0.6)
		var place := func(k: int) -> Array:
			var p: Vector3 = pts[k][0]
			var nn: Vector3 = pts[k][1]
			var s := 0.008 + pow(rng.next(), 2) * 0.02
			var c := dc * (0.85 + rng.next() * 0.4)
			c.a = 1.0
			return [_rot_inst(p - nn * s * 0.3, Vector3(rng.next() * 3, rng.next() * 3, rng.next() * 3), Vector3.ONE * s), c]
		U.inst(Geo.octa(1), SpecMat.make({col = Color(1, 1, 1), rough = 0.12, flat = true, holo = 0.4, seed = 3.0}), pts.size(), place, main.get_parent())
		var to_root := U.rel_xform(main.get_parent(), root) if main.get_parent() != root else Transform3D.IDENTITY
		for k in mini(8, pts.size()):
			_mark("druzy", to_root * (pts[k][0] as Vector3), (to_root.basis * (pts[k][1] as Vector3)).normalized())
	var cyl := Geo.cylinder(1, 1, 1, 6).translate(0, 0.5, 0)
	var cone := Geo.cone(1, 1, 5).translate(0, 0.5, 0)
	var pals := [[0xff6a2a, 0xffb040, 0xd8302a], [0x3a6aff, 0x7fb4ff, 0x1a2a8a], [0xf4f0e8, 0xd8d0c0, 0xb8b0a0], [0xff4a8a, 0xffb0d0, 0x8a2a5a], [0xd8e04a, 0xf4f0a0, 0x7a8a2a]]
	var pal := []
	for hx in pals[int(floor(rng.next() * 5))]:
		pal.append(SpecMat.lin(hx))
	var segs := func(geo: Geo, m: Material, list: Array) -> void:
		var place := func(k: int) -> Array:
			var L: Array = list[k]
			return [Transform3D(Basis(U.quat_to(UP, L[1])) * Basis.from_scale(Vector3(L[3], L[2], L[3])), L[0]), L[4]]
		U.inst(geo, m, list.size(), place, root)
	var has_base: bool = not (layout in ["floater", "radial", "columnar", "geode", "nugget", "botryoid", "vein", "obsidian"]) and not (gene_m.lustre == "fossil" and not st.rock)
	var strong := "coral" in tr
	var style := -1
	if has_base:
		style = 0 if strong else 1 if "needles" in gene_m.accents else 2 if "crust" in gene_m.accents else -1
	if style == 0:
		# coralloid branches: forking stems with knobbly tips
		var list := []
		var tips := []
		var grow := func(fn: Callable, p: Vector3, d: Vector3, l: float, r: float, depth: int) -> void:
			list.append([p, d, l, r, pal[mini(2, 2 - depth % 3)]])
			var e := p + d * l
			if depth <= 0 or l < 0.02:
				tips.append(e)
				return
			for k in 2 + (1 if rng.next() < 0.35 else 0):
				fn.call(fn, e, (d + Vector3(rng.next() - 0.5, rng.next() * 0.5, rng.next() - 0.5) * 1.3).normalized(), l * (0.62 + rng.next() * 0.2), r * 0.72, depth - 1)
		for k in 6:
			var at: Vector3 = pick_any.call()
			grow.call(grow, at, (nrm.call(at) as Vector3).lerp(UP, 0.5).normalized(), 0.1 + rng.next() * 0.06, 0.016, 4)
		# tapering limy stems, soft and porous, with rounded knobs at the ends
		for L in list:
			L[4] = (L[4] as Color).lerp(Color(0.85, 0.8, 0.72), 0.35)
			L[3] = float(L[3]) * 1.3
		segs.call(Geo.cylinder(0.7, 1, 1, 8).translate(0, 0.5, 0), SpecMat.make({rough = 0.6, grain = 0.6}), list)
		var place := func(k: int) -> Array:
			var s := 0.014 + rng.next() * 0.016
			var c: Color = (pal[int(floor(rng.next() * 2))] as Color).lerp(Color(0.9, 0.85, 0.78), 0.3)
			return [Transform3D(Basis.from_scale(Vector3(s, s * 1.2, s)), tips[k]), c]
		U.inst(Geo.sphere(1, 12, 8), SpecMat.make({rough = 0.5, grain = 0.8}), tips.size(), place, root)
		if tips.size(): _mark("coral", tips[0])
	elif style == 1:
		# radiating needle sprays
		var list := []
		for s0 in (5 if strong else 2):
			var at: Vector3 = pick.call()
			var base := (nrm.call(at) as Vector3).lerp(UP, 0.3).normalized()
			for k in 70:
				var d := (base + _rv() * 1.4).normalized()
				if d.dot(base) < 0.15:
					continue
				list.append([at, d, 0.08 + rng.next() * 0.22, 0.006 + rng.next() * 0.006, pal[int(floor(rng.next() * 3))]])
			_mark("coral" if strong else "needles", at, base)
		segs.call(cone, SpecMat.make({rough = 0.25, coat = 0.6}), list)
	elif style == 2:
		# a crust of tiny crystals coating part of the rock
		var seeds := []
		for k in (7 if strong else 3):
			seeds.append(pick.call())
		_mark("coral" if strong else "crust", seeds[0], nrm.call(seeds[0]))
		var place := func(k: int) -> Array:
			var s0: Vector3 = seeds[k % seeds.size()]
			var r := 0.17
			var v := s0 + Vector3((rng.next() - 0.5) * r * 2, (rng.next() - 0.5) * r * 0.6, (rng.next() - 0.5) * r * 2)
			var e := Vector3(rng.next() * 3, rng.next() * 3, rng.next() * 3)
			var s := 0.008 + rng.next() * 0.02
			return [_rot_inst(v, e, Vector3(s, s * 1.6, s)), (pal[int(floor(rng.next() * 3))] as Color).lerp(Color(1, 1, 1), 0.45)]
		# sparkling glassy grains rather than painted beads
		U.inst(Geo.octa(1), SpecMat.make({col = Color(1, 1, 1), glass = true, thick = 2.0, flat = true, holo = 0.5, seed = 9.0}), 900 if strong else 300, place, root)
	if has_base and "moss" in tr:
		# cushions of moss and a few young ferns where the rock faces the sky
		var pool := []
		for k in 900:
			var q: Vector3 = pick_any.call()
			pool.append([q, nrm.call(q)])
		var hollows: Array = st.get("hollows_all", [])
		var in_pits: bool = gene_m.nest == "hollows" and hollows.size() > 30
		if in_pits:
			pool = hollows
		for k in (7 + int(rng.next() * 5)) if in_pits else (4 + int(rng.next() * 3)):
			var c0: Vector3 = (pool[int(rng.next() * pool.size())][0] as Vector3) if in_pits else (pick_any.call() as Vector3)
			var rad := (0.07 + rng.next() * 0.09) if in_pits else (0.18 + rng.next() * 0.2)
			green_spots.append([c0, nrm.call(c0)])
			var tint: Color = (SpecAccents.MOSS[int(gene_m.palette.moss)] as Color).lerp(Color(1.2, 1.1, 0.6), rng.next() * 0.3)
			# a cushion of moss bed, then sprigs, blades and the odd fern standing in it
			var top := SpecPlants.cushion(root, rng, pool, c0, rad, 0.035 + rng.next() * 0.03, tint)
			# a few spots over the whole cushion: its middle may be under a crystal while its edge shows
			for q in mini(6, top.size()):
				var tp: Array = top[(q * top.size()) / 6]
				_mark("moss", tp[0], tp[1])
			var on: Array = top if top.size() > 8 else pool
			SpecPlants.scatter(root, rng, on, c0, rad * 0.9, 300 + int(rng.next() * 300), "moss", 3.6 + rng.next() * 1.6, 0.3, tint)
			SpecPlants.scatter(root, rng, on, c0, rad * 0.7, 6 + int(rng.next() * 16), "grass", 1.4 + rng.next() * 1.0, 0.6, Color(0.9, 1.0, 0.8))
			if rng.next() < 0.3:
				SpecPlants.scatter(root, rng, on, c0, rad * 0.4, 1 + int(rng.next() * 2), "tuft", 0.9 + rng.next() * 0.5, 0.3)
			if rng.next() < 0.35:
				SpecPlants.scatter(root, rng, on, c0, 0.05, 1 + int(rng.next() * 2), "fern", 0.3 + rng.next() * 0.15, 0.5)
	# a dusting of red hematite on some
	if has_base and "dust" in gene_m.accents:
		var place := func(k: int) -> Array:
			var v: Vector3 = (pick.call() as Vector3) * 1.01
			if k < 8: _mark("dust", v, nrm.call(v))
			var s := 0.006 + rng.next() * 0.01
			return [Transform3D(Basis.from_scale(Vector3.ONE * s), v), SpecMat.hsl(0.01, 0.6, 0.2 + rng.next() * 0.1).srgb_to_linear()]
		U.inst(Geo.icosa(1, 0), SpecMat.make({rough = 0.9}), 160, place, root)
	# (a fossil with no rock under it — loose, sawn — has nowhere for them: they stacked up in a column over its middle)
	if "bubbles" in tr and not (Data.HABIT.get(sid, "") == "fossil" and not st.rock):
		var made := []
		var place := func(k: int) -> Array:
			var v: Vector3 = (pick.call() as Vector3) * 1.02
			v.y += rng.next() * 0.5
			var s := 0.015 + rng.next() * 0.05
			made.append([s, v])
			return [Transform3D(Basis.from_scale(Vector3.ONE * s), v), Color(1, 1, 1)]
		U.inst(Geo.sphere(1, 16, 12), SpecMat.make({col = Color(0.95, 0.97, 1.0), glass = true, thick = 2.0, prio = 2}), 40, place, root)
		# the thread points at one of the biggest bubbles (with no rock to sit on they all crowd into the stone's
		# middle, out of sight: none then)
		if st.rock:
			made.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
			for m: Array in made.slice(0, 6):
				_mark("bubbles", m[1])

## rock-line coordinates for every crystal, then the final dirt line on their materials, then the meshes
func _finish() -> void:
	for m in dt_mats:
		SpecMat.set_dirt(m, dt)
	var stack: Array[Node] = [root]
	while stack.size():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if not (n is MeshInstance3D) or (n as MeshInstance3D).mesh or not n.has_meta("geo"):
			continue
		var g: Geo = n.get_meta("geo")
		var gg := Geo.new()
		gg.v = g.v.duplicate()
		gg.idx = g.idx.duplicate()
		gg.col = g.col.duplicate()
		gg.bary = g.bary.duplicate()
		# where a crystal turns into rock the surface swells into a lumpy crust
		var crusty: bool = (n as MeshInstance3D).material_override in dt_mats and crust_ok
		if crusty and gg.tri_count() < 2500:
			gg.subdivide(1 if gg.tri_count() > 500 else 2)
		var local: bool = n.get_meta("local", false)
		var bb := gg.aabb()
		var hgt := maxf(0.001, bb.size.y)
		var t := U.rel_xform(n, root)
		var rp := PackedVector3Array()
		rp.resize(gg.v.size())
		for i in gg.v.size():
			rp[i] = (gg.v[i] - bb.position) / hgt if local else t * gg.v[i]
		if crusty:
			var fn := FastNoiseLite.new()
			fn.seed = int(rng.next() * 100000)
			fn.frequency = 2.2
			fn.fractal_octaves = 3
			var line: float = dt.h
			var amp := 0.05 * (hgt if local else 1.0) / maxf(0.2, t.basis.get_scale().x)
			for i in gg.v.size():
				var w := 1.0 - smoothstep(line - 0.14, line + 0.1, rp[i].y)
				if w > 0.0:
					var p := gg.v[i]
					var q := p * 9.0
					gg.v[i] = p + Vector3(fn.get_noise_3dv(q), fn.get_noise_3dv(q + Vector3(19, 0, 0)), fn.get_noise_3dv(q + Vector3(0, 0, 41))) * amp * w
		gg.rp = rp
		(n as MeshInstance3D).mesh = gg.to_mesh()
