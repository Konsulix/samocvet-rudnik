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
	var legend: bool = o.get("legend", false)
	root = Node3D.new()
	var col := SpecMat.lin_s(sp.c)
	col = SpecMat.offset_hsl(col, (rng.next() - 0.5) * 0.03, (rng.next() - 0.5) * 0.15, (rng.next() - 0.5) * 0.06)
	if gi < 2:
		col = col.lerp(SpecMat.lin(0xb8b4ac), 0.25 - gi * 0.1)
	var gene := SpecGenome.of(o)
	gene_m = gene
	root.set_meta("genome", gene)
	if gene.anomaly:
		# an anomaly: the stone grew in a colour its species never has, and glows faintly from inside
		col = SpecMat.offset_hsl(col, gene.hue, 0.3, 0.04)
	root.set_meta("glow", col)
	var irk := 1.9 if "aurora" in tr else 1.0 if "irid" in tr else 0.45 if legend else 0.14
	var metal := habit == "nugget" or sid == "pyrite"
	var cut: String = o.get("cut", "")
	# a cut stone floats alone, tilted to show its table and pavilion
	if cut != "" and cut != "broken":
		var gm := SpecMat.make({col = col, flat = cut != "cab", glass = true, thick = 1.6, rf = 1.0, ir = 0.45 if cut == "master" else 0.2, seed = float(seed_v % 97), prio = 2})
		U.mesh(RockKit.gem(cut), gm, root, Vector3.ZERO, U.eul(-0.9 if cut == "cab" else PI - 0.55, 0, 0.15))
		return root

	# colour zoning along the crystals
	var zone := 1.0 if "zoned" in tr else 0.45 if rng.next() < 0.35 else 0.0
	var zmode := int(floor(rng.next() * 3))
	var cA := col
	if zone > 0.0:
		cA = Color(1, 1, 1).lerp(col, 0.25) if zmode == 0 else col * 0.45 if zmode == 1 else SpecMat.offset_hsl(col, 0.45, 0, 0)
	var cB := col
	var zcfg := {cA = cA if zone > 0.0 else col, cB = cB, zk = zone}
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

	var st := {pick = func() -> Vector3: return Vector3.ZERO, nrm = func(v: Vector3) -> Vector3: return v.normalized(), rock = null, irk = irk,
		detail = 2 if layout in ["single", "columnar", "floater"] else 0 if layout == "geode" else 1}
	var stria := 1.0 if elongated else 0.0
	var cmat_spec := func() -> Dictionary:
		var irk2: float = st.irk
		if metal:
			# brassy metal crystals: striated faces, a rainbow tarnish here and there, sunk into the rock
			return {col = Color(1, 1, 1), metal = 0.95, rough = 0.2, coat = 0.6, flat = true, env = 1.6, oil = 0.35, st = 1.0, dirt = dt, prio = 2}
		var op := 0.36 + (0.14 if gi < 2 else 0.0) if layout == "columnar" or layout == "cluster" else 0.8 if habit == "octa" or habit == "dodeca" else maxf(0.5, 0.82 - gi * 0.07)
		var d := {col = Color(1, 1, 1), flat = true, glass = true, ir = irk2 * 0.5, rf = 0.3, st = stria, dirt = dt, prio = 2,
			rim = gene.rim, holo = gene.holo, emis = col * 0.35 if gene.anomaly else Color(0, 0, 0),
			frost = 0.85 - gi * 0.3 if gi < 2 else 0.1 + rng.next() * 0.25, thick = 1.0 + op * 0.4, seed = float(seed_v % 97)}
		return d
	var make_cmat := func(d: Dictionary) -> ShaderMaterial:
		var m := SpecMat.make(d)
		if d.has("dirt"):
			dt_mats.append(m)
		return m
	var rock_mat := func(c: Color) -> ShaderMaterial:
		return SpecMat.make({col = Color(1, 1, 1), rough = 0.95, grain = 0.35, ao = 1.0, dirt = {h = 99.0, a = 0.3, col = c, fr = 0.0, scan = scan}})
	var use_rock := func(shape: String) -> MeshInstance3D:
		var R := RockKit.rock(rng, rtype, shape)
		var mi := U.mesh(R.geo, rock_mat.call(R.base), root)
		dt.col = R.base
		var top: Array = R.top
		var sc: Vector3 = R.scale
		st.pick = func() -> Vector3: return top[int(floor(rng.next() * top.size()))] if top.size() else Vector3(0, 0.3, 0)
		st.nrm = func(w: Vector3) -> Vector3: return RockKit.rock_nrm(sc, w)
		st.rock = mi
		return mi
	if layout == "columnar" or layout == "cluster":
		irk = maxf(irk, 0.3)
		st.irk = irk
	var mat: ShaderMaterial = null
	if not metal and not (layout in ["nugget", "botryoid", "vein"]):
		var d: Dictionary = cmat_spec.call()
		if gene.lustre == "dark":
			# a dark, lustrous stone: opaque, nearly black, an oil-slick rainbow sliding over it
			var dc: Color = gene.dark_col
			dt.fb = 0.15
			dt.fr = 0.0
			d = {col = dc, metal = 0.55, rough = 0.16, coat = 0.5, coat_r = 0.1, flat = true, oil = 1.0, st = stria, dirt = dt, prio = 2, env = 1.4}
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
		"cluster":
			# a druse: a crumbling plate bristling with crystals of every size, their feet frosted and crusted over
			use_rock.call("slab" if rng.next() < 0.6 else "long")
			dt.local = true
			dt.h = 0.1 + rng.next() * 0.14
			dt.a = 0.3
			var cubic := habit == "cube"
			var prismy := elongated or cubic
			var cm: ShaderMaterial = any_cmat.call()
			var sides := 4 if cubic or habit == "blade" else 6
			var top_pick := func() -> Vector3:
				var b: Vector3 = st.pick.call()
				for k in 5:
					var c: Vector3 = st.pick.call()
					if c.y - Vector2(c.x, c.z).length() * 0.3 > b.y - Vector2(b.x, b.z).length() * 0.3:
						b = c
				return b
			for k in 14 + int(floor(rng.next() * 14)):
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
			if rng.next() < 0.45:
				var rm := U.mesh(R.geo, rock_mat.call(R.base), root)
				rm.transform = Transform3D(Basis.from_scale(Vector3(0.7, 0.7, 0.7)), Vector3(0, -0.2, 0))
			var cubic := habit == "cube"
			var sides := 4 if cubic or habit == "blade" or rng.next() < 0.3 else 6
			var axis: Vector3 = lean.call(UP, 0.3 if cubic else 0.55)
			var n := 4 + int(floor(rng.next() * 4)) if kind == "druse" else 1 + int(floor(rng.next() * 3))
			var cm: ShaderMaterial = any_cmat.call()
			for k in n:
				var w := (0.13 + rng.next() * 0.17 if k else 0.27 + rng.next() * 0.13) * (1.25 if cubic else 1.0) * gs
				var h := w * (1.5 + rng.next() * 0.8) if cubic else (0.45 + rng.next() * 0.9 if k else 1.45 + rng.next() * 0.65) * gs
				var g := RockKit.prism(rng, {sides = sides, w = w, d = w * 0.62 if habit == "blade" else w * (0.7 + rng.next() * 0.45), h = h,
					point = not cubic and rng.next() < 0.45, slope = 0.4 + rng.next() * 1.1 if rng.next() < 0.65 else 0.0, detail = 2, erode = ero}, zcfg)
				var c := U.mesh(g, cm, root)
				c.set_meta("col", true)
				var at := Vector3((rng.next() - 0.5) * 0.55 if k else 0.0, -0.05, (rng.next() - 0.5) * 0.4 if k else 0.0)
				_place(c, at, lean.call(axis, 1.2 if cubic else 0.35), 1.0, rng.next() * 6.28)
				if not main: main = c
			dt.h = 0.3 + rng.next() * 0.45
			dt.a = 0.5 + rng.next() * 0.5
		"radial":
			# a sunburst: crystals radiating from a small core
			if rng.next() < 0.6:
				var core := RockKit.rock(rng, rtype, "small")
				var cm2 := U.mesh(core.geo, SpecMat.make({col = Color(1, 1, 1), rough = core.rough, flat = true}), root)
				cm2.scale = Vector3(0.45, 0.45, 0.45)
			for k in 14 + int(floor(rng.next() * 12)):
				var d := _rv().normalized()
				var c: MeshInstance3D = crystal.call(0.5 + rng.next() * 0.7, 0.55 + rng.next() * 0.45, d * 0.12, d)
				if not main: main = c
		"rosette":
			# a desert rose: tiers of blades fanned around the axis
			var rk: MeshInstance3D = use_rock.call("small")
			rk.scale = Vector3(0.7, 0.7, 0.7)
			for tier in 3:
				var n := 6 + int(floor(rng.next() * 4))
				for k in n:
					var a := float(k) / n * 6.28 + tier * 0.5 + rng.next() * 0.3
					var tilt := 0.55 + tier * 0.25 + rng.next() * 0.2
					var d := Vector3(cos(a) * sin(tilt), cos(tilt), sin(a) * sin(tilt))
					var c: MeshInstance3D = crystal.call(0.35 + rng.next() * 0.25, 0.7 + rng.next() * 0.3 - tier * 0.12, Vector3(0, 0.12 + tier * 0.1, 0), d)
					c.rotation.y += a
					if not main: main = c
		"slabs":
			# a stack of thick tabular plates fanning out of the rock, their tops broken off at a slant
			use_rock.call("chunk" if rng.next() < 0.5 else "small")
			var cm: ShaderMaterial = any_cmat.call()
			var axis: Vector3 = lean.call(UP, 0.5)
			var common := Basis(quat_to_l(UP, axis)) * Basis(UP, rng.next() * TAU)
			var n := 3 + int(rng.next() * 4)
			var w0 := (0.22 + rng.next() * 0.16) * gs
			var off := -n * 0.5
			for k in n:
				var w := w0 * (0.6 + rng.next() * 0.6)
				var d := w * (0.22 + rng.next() * 0.2)
				var h := (0.7 + rng.next() * 0.9) * (1.0 if absf(k - n * 0.5) < 1.5 else 0.7)
				var g := RockKit.prism(rng, {sides = 4, w = w, d = d, h = h, point = false, slope = 0.6 + rng.next() * 1.2, taper = 0.95 + rng.next() * 0.1, y0 = -0.35, detail = 2, erode = ero}, zcfg)
				var c := U.mesh(g, cm, root)
				var fan := Basis(Vector3.BACK, (k - n * 0.5) * (0.08 + rng.next() * 0.1)) * Basis(Vector3.RIGHT, (rng.next() - 0.5) * 0.25)
				c.transform = Transform3D(common * fan, common * Vector3(0, -0.05, (off + k) * d * 1.9) + Vector3((rng.next() - 0.5) * 0.1, 0, 0))
				c.set_meta("col", true)
				if not main: main = c
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
				if shape < 0.5: g = Geo.box(hs * 2, hs * (1.6 + rng.next() * 0.8), hs * (1.6 + rng.next() * 0.6))
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

	crust_ok = layout != "geode"
	_inside(main, mat, habit, col, gi, tr, legend, layout, seed_v)
	if gene.gold:
		_gold(main, st)
	_growths(main, mat, col, tr, layout, sid, st, legend)
	_accents(main, mat, gene, st, layout)
	_finish()
	if legend:
		var halo := U.mesh(Geo.torus(1.05, 0.008, 6, 90), SpecMat.make({col = U.raw(0xe4ae39), unshaded = true}), root, Vector3.ZERO, Basis(Vector3.RIGHT, PI / 2 - 0.3))
		halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
		var qm := SpecMat.make({col = Color(1, 1, 1), rough = 0.6, grain = 0.3, ao = 1.0, dirt = {h = 99.0, a = 0.3, col = SpecMat.lin(0xd8d0c0), fr = 0.0, scan = 0}})
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
	# dendrites: branching wires with rounded joints, the classic look of crystallised copper and wire gold
	if copper or rng.next() < 0.4:
		var list := []
		var joints := []
		var grow := func(fn: Callable, p: Vector3, d: Vector3, l: float, r: float, depth: int) -> void:
			list.append([p, d, l, r])
			var e := p + d * l
			joints.append([e, r * 1.5])
			if depth > 0:
				for k in 2 + (1 if rng.next() < 0.3 else 0):
					fn.call(fn, e, (d + Vector3(rng.next() - 0.5, rng.next() * 0.5, rng.next() - 0.5) * 1.2).normalized(), l * (0.68 + rng.next() * 0.15), r * 0.78, depth - 1)
		for k in (4 if copper else 2):
			var d := Vector3(rng.next() - 0.5, 0.4 + rng.next() * 0.6, rng.next() - 0.5).normalized()
			grow.call(grow, d * 0.35, d, 0.26, 0.035, 3)
		var cyl := Geo.cylinder(1, 1, 1, 10).translate(0, 0.5, 0)
		var wm := SpecMat.make({col = col, metal = 1.0, rough = 0.3, env = 1.7})
		var place := func(k: int) -> Array:
			var L: Array = list[k]
			return [Transform3D(Basis(U.quat_to(UP, L[1])) * Basis.from_scale(Vector3(L[3], L[2], L[3])), L[0]), Color(1, 1, 1)]
		U.inst(cyl, wm, list.size(), place, root)
		var place2 := func(k: int) -> Array:
			var s: float = joints[k][1]
			return [Transform3D(Basis.from_scale(Vector3(s, s, s)), joints[k][0]), col]
		U.inst(Geo.sphere(1, 12, 8), SpecMat.make({metal = 1.0, rough = 0.3, env = 1.7}), joints.size(), place2, root)
	return null

# native metal grown through vein quartz: clear slabs of quartz with a spongy, crumbling mass of gold
# (or copper) wrapped round their feet and clinging to their faces, foil flakes caught inside the glass,
# rust-red oxide in the hollows (green patina and red cuprite on copper)
func _vein(sid: String, col: Color) -> MeshInstance3D:
	var copper := sid == "nativecu"
	var metal_c := SpecMat.lin(0xd9773a) if copper else SpecMat.lin(0xf0c050)
	var crust := SpecMat.lin(0x2f8a62) if copper else SpecMat.lin(0x7a2a10)
	var mm := SpecMat.make({col = metal_c, metal = 1.0, rough = 0.26, coat = 0.25, env = 1.8, grain = 0.5, rough_var = 0.4,
		dirt = {h = -99.0, a = 0.3, col = crust, fr = 0.0, isl = 0.4 if copper else 0.34, fb = 0.0}})
	var qtint := Color(0.97, 0.95, 0.86) if not copper else Color(0.92, 0.95, 0.97)
	var qm := SpecMat.make({col = qtint, flat = true, glass = true, frost = 0.15 + rng.next() * 0.25, holo = 0.08 + rng.next() * 0.18, thick = 1.1, seed = rng.next() * 50.0, prio = 2})
	var axis: Vector3 = (UP + Vector3(rng.next() - 0.5, 0, rng.next() - 0.5) * 0.6).normalized()
	var common := Basis(U.quat_to(UP, axis)) * Basis(UP, rng.next() * TAU)
	var slabs := []
	var main: MeshInstance3D = null
	for k in 2 + int(rng.next() * 3):
		var w := 0.16 + rng.next() * 0.16
		var g := RockKit.prism(rng, {sides = 4, w = w, d = w * (0.35 + rng.next() * 0.4), h = 0.8 + rng.next() * 0.8, point = rng.next() < 0.3,
			slope = 0.5 + rng.next() * 1.2, y0 = -0.35, detail = 2}, {cA = Color(1, 1, 1), cB = Color(1, 1, 1), zk = 0.0})
		var c := U.mesh(g, qm, root)
		var tilt := Basis(Vector3.BACK, (rng.next() - 0.5) * 0.7) * Basis(Vector3.RIGHT, (rng.next() - 0.5) * 0.5)
		c.transform = Transform3D(common * tilt, common * Vector3((rng.next() - 0.5) * 0.35, 0, (k - 1.5) * 0.12))
		slabs.append(c)
		if not main: main = c
	# the metal mass round the feet
	var big := RockKit.crumble(rng, 0.3, Vector3(1.25, 0.6, 1.05))
	U.mesh(big, mm, root, common * Vector3(0, -0.28, 0), common)
	# masses climbing the faces
	# masses grown right through the quartz, seen bent and broken up by the glass
	for sl in slabs:
		var sbb: AABB = (sl.get_meta("geo") as Geo).aabb()
		for k in 2 + int(rng.next() * 4):
			var p: Vector3 = sl.transform * (sbb.position + Vector3(0.2 + rng.next() * 0.6, 0.05 + rng.next() * 0.6, 0.3 + rng.next() * 0.4) * sbb.size)
			var s := 0.04 + pow(rng.next(), 1.5) * 0.09
			U.mesh(RockKit.crumble(rng, s, Vector3(1.4, 0.8, 1.0)), mm, root, p, U.eul(rng.next() * 6, rng.next() * 6, rng.next() * 6))
	for k in 6 + int(rng.next() * 8):
		var sl: MeshInstance3D = slabs[int(rng.next() * slabs.size())]
		var pts := RockKit.surf_pts(sl, 1, rng, func(p: Vector3, n: Vector3) -> bool: return true)
		if pts.is_empty(): continue
		var p: Vector3 = pts[0][0]
		var s := 0.05 + pow(rng.next(), 1.6) * 0.14
		var cg := RockKit.crumble(rng, s, Vector3(1.0 + rng.next() * 0.6, 0.6 + rng.next() * 0.5, 1.0))
		U.mesh(cg, mm, root, p, U.eul(rng.next() * 6, rng.next() * 6, rng.next() * 6))
	# foil caught in the glass
	var fm := SpecMat.make({col = metal_c, metal = 1.0, rough = 0.2, flat = true, env = 1.8})
	for sl in slabs:
		var bb: AABB = (sl.get_meta("geo") as Geo).aabb()
		var place := func(k: int) -> Array:
			var p := bb.position + Vector3(0.15 + rng.next() * 0.7, rng.next() * 0.75, 0.15 + rng.next() * 0.7) * bb.size
			var s := 0.012 + pow(rng.next(), 2.0) * 0.06
			return [_rot_inst(p, Vector3(rng.next() * 6, rng.next() * 6, rng.next() * 6), Vector3(s, s * 0.12, s * (0.5 + rng.next()))), Color(1, 1, 1)]
		U.inst(Geo.icosa(1, 0), fm, 60 + int(rng.next() * 70), place, sl)
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
	U.mesh(outer, SpecMat.make({col = Color(1, 1, 1), rough = 0.95, flat = true, dirt = {h = 99.0, a = 0.3, col = ocol, fr = 0.0, scan = RockKit.SCAN_OF[rtype]}}), shell)
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
	var rg := Geo.ring(0.84, 1.01, 120, 16)
	var wob := []
	for k in 4:
		wob.append([1 + int(floor(rng.next() * 9)), rng.next() * 6.3])
	for i in rg.v.size():
		var p := rg.v[i]
		var a := atan2(p.y, p.x)
		var r := Vector2(p.x, p.y).length()
		var t := (r - 0.84) / 0.17
		var n := 0.0
		for w in wob:
			n += sin(a * w[0] + w[1]) * 0.25
		n += sin(a * 37.0 + r * 9.0) * 0.12
		var rr := r + (n * 0.03 if t > 0.5 else 0.0)
		rg.v[i] = Vector3(cos(a) * rr, sin(a) * rr, (n * 0.05 + sin(a * 53.0) * 0.012) * (1.0 - absf(t - 0.5)))
	rg.col.resize(rg.v.size())
	for i in rg.v.size():
		var t := 1.0 - (Vector2(rg.v[i].x, rg.v[i].y).length() - 0.84) / 0.2
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
	st.pick = func() -> Vector3:
		var a := rng.next() * PI
		return Vector3(cos(a), sin(a) * 0.9, 0)
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
	if ok and "rutile" in tr:
		var gm := SpecMat.make({col = U.raw(0xd8a23a), metal = 1.0, rough = 0.25, emis = U.raw(0x3a2208)})
		var w := minf(bb.size.x, bb.size.z)
		var hh := bb.end.y - maxf(0.0, bb.position.y)
		for k in 22:
			var len := minf(hh * 0.7, w * 1.6) * (0.4 + rng.next() * 0.6)
			var at := Vector3(bb.get_center().x + (rng.next() - 0.5) * w * 0.4, maxf(0.0, bb.position.y) + hh * (0.25 + rng.next() * 0.45), bb.get_center().z + (rng.next() - 0.5) * w * 0.4)
			U.mesh(Geo.cylinder(0.004, 0.004, len, 4), gm, main, at, U.eul((rng.next() - 0.5) * 0.8, rng.next() * 3, (rng.next() - 0.5) * 0.8))
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
func _gold(main: MeshInstance3D, st: Dictionary) -> void:
	var gm := SpecMat.make({col = SpecMat.lin(0xf2c35a), metal = 1.0, rough = 0.22, flat = true, env = 1.8})
	var flake := Geo.icosa(1, 0)
	if main:
		var bb: AABB = (main.get_meta("geo") as Geo).aabb()
		var place := func(k: int) -> Array:
			var p := bb.position + Vector3(0.2 + rng.next() * 0.6, 0.15 + rng.next() * 0.7, 0.2 + rng.next() * 0.6) * bb.size
			var s := 0.006 + pow(rng.next(), 2.5) * 0.03
			return [_rot_inst(p, Vector3(rng.next() * 6, rng.next() * 6, rng.next() * 6), Vector3(s, s * 0.25, s * (0.6 + rng.next() * 0.6))), Color(1, 1, 1)]
		U.inst(flake, gm, 70 + int(rng.next() * 80), place, main)
	if st.rock:
		var pick: Callable = st.pick
		var place2 := func(k: int) -> Array:
			var p: Vector3 = pick.call()
			var s := 0.008 + pow(rng.next(), 2.0) * 0.035
			return [_rot_inst(p, Vector3(rng.next() * 6, rng.next() * 6, rng.next() * 6), Vector3(s, s * 0.45, s)), Color(1, 1, 1)]
		U.inst(flake, gm, 40 + int(rng.next() * 60), place2, root)

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
		var pts := RockKit.surf_pts(cols[int(rng.next() * cols.size())], 1, rng)
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
			SpecAccents.tuft(root, rng, a[0], a[1], 450 + int(rng.next() * 350), (0.16 + rng.next() * 0.14) * gs, 0.012, 0.8, 0.2, pc)
	if "straw" in acc:
		var sc: Array = SpecAccents.STRAW[int(pal.straw)]
		for k in 2 + int(rng.next() * 3):
			var a: Array = spot.call(0.35)
			if a.is_empty(): continue
			# tangled hair: roots spread over a patch, long, strongly bent, every which way
			# all swept one way, like hair combed by water
			var sweep: Vector3 = ((a[1] as Vector3) + Vector3(rng.next() - 0.5, rng.next() * 0.3, rng.next() - 0.5) * 2.2).normalized()
			for bend in [1.4, 2.4]:
				SpecAccents.tuft(root, rng, a[0], sweep, 80 + int(rng.next() * 80), (0.2 + rng.next() * 0.2) * gs, 0.008, 0.45, bend, sc, 0.09 * gs)
	if "lichen" in acc and st.rock:
		var pool := []
		for k in 700:
			var q: Vector3 = st.pick.call()
			pool.append([q, st.nrm.call(q)])
		var lt: Color = SpecAccents.LICHEN[int(pal.lichen)]
		for k in 2 + int(rng.next() * 4):
			var c0: Vector3 = st.pick.call()
			SpecPlants.cushion(root, rng, pool, c0, 0.1 + rng.next() * 0.14, 0.012, lt)
	if mat and main and gene.lustre == "glass":
		if "inkspots" in acc:
			SpecAccents.inkspots(main, rng, 3 + int(rng.next() * 9))
		if "clouds" in acc:
			var cc: Color = SpecAccents.CLOUDS[int(pal.clouds)]
			mat.set_shader_parameter("smoke_k", 0.75 + rng.next() * 0.25)
			mat.set_shader_parameter("smoke_col", Vector3(cc.r, cc.g, cc.b) * 0.6)

# crusts, tufts, sprays, moss and bubbles on the rock and the crystals
func _growths(main: MeshInstance3D, mat: ShaderMaterial, col: Color, tr: Array, layout: String, sid: String, st: Dictionary, legend: bool) -> void:
	var cols := []
	for c in root.get_children():
		if c is MeshInstance3D and (c.get_meta("col", false) or (mat and c.material_override == mat)):
			cols.append(c)
	var inc_p: Array = get_meta("inc_p") if has_meta("inc_p") else [Color(0.8, 0.5, 0.2)]
	var pick: Callable = st.pick
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
		var gv: Geo = main.get_meta("geo")
		var mt := main.transform
		var dc := col.lerp(Color(1, 1, 1), 0.6)
		var place := func(k: int) -> Array:
			var v: Vector3 = mt * gv.v[int(floor(rng.next() * gv.v.size()))]
			var s := 0.01 + rng.next() * 0.018
			return [_rot_inst(v, Vector3(rng.next() * 3, rng.next() * 3, rng.next() * 3), Vector3.ONE * s), dc]
		U.inst(Geo.octa(1), SpecMat.make({col = Color(1, 1, 1), glass = true, thick = 2.0, flat = true, holo = 0.4, seed = 3.0}), 260, place, main.get_parent())
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
	var has_base := not (layout in ["floater", "radial", "columnar", "geode", "nugget", "botryoid", "vein"])
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
			var at: Vector3 = pick.call()
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
		segs.call(cone, SpecMat.make({rough = 0.25, coat = 0.6}), list)
	elif style == 2:
		# a crust of tiny crystals coating part of the rock
		var seeds := []
		for k in (7 if strong else 3):
			seeds.append(pick.call())
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
			var q: Vector3 = pick.call()
			pool.append([q, nrm.call(q)])
		for k in 4 + int(rng.next() * 3):
			var c0: Vector3 = pick.call()
			var rad := 0.18 + rng.next() * 0.2
			var tint: Color = (SpecAccents.MOSS[int(gene_m.palette.moss)] as Color).lerp(Color(1.2, 1.1, 0.6), rng.next() * 0.3)
			# a cushion of moss bed, then sprigs, blades and the odd fern standing in it
			var top := SpecPlants.cushion(root, rng, pool, c0, rad, 0.035 + rng.next() * 0.03, tint)
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
			var s := 0.006 + rng.next() * 0.01
			return [Transform3D(Basis.from_scale(Vector3.ONE * s), v), SpecMat.hsl(0.01, 0.6, 0.2 + rng.next() * 0.1).srgb_to_linear()]
		U.inst(Geo.icosa(1, 0), SpecMat.make({rough = 0.9}), 160, place, root)
	if "bubbles" in tr:
		var place := func(k: int) -> Array:
			var v: Vector3 = (pick.call() as Vector3) * 1.02
			v.y += rng.next() * 0.5
			var s := 0.015 + rng.next() * 0.05
			return [Transform3D(Basis.from_scale(Vector3.ONE * s), v), Color(1, 1, 1)]
		U.inst(Geo.sphere(1, 16, 12), SpecMat.make({col = Color(0.95, 0.97, 1.0), glass = true, thick = 2.0, prio = 2}), 40, place, root)

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
