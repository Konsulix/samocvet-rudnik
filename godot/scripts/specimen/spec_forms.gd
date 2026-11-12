class_name SpecForms
extends RefCounted
## The layouts of the minerals that do not look like "a crystal" (12.11, docs/showy-minerals.md): wulfenite's orange
## window-panes, vanadinite's red barrels, crocoite's jackstraw needles, cavansite's blue balls on white, erythrite's
## magenta fans, bismuth's rainbow staircases, tourmaline's striped pencils and watermelon slices. Each is a species'
## own way of growing (SpecLooks forms), built here so the builder stays readable.
## `b` is the SpecimenBuilder (its rng, root, marks), `c` what its _specimen() worked out:
##   {st, col, gs, look, zcfg, kind, gene, ero, use_rock, any_cmat, cmat_spec, make_cmat, crystal, lean}

const UP := Vector3.UP
const U := preload("res://scripts/specimen/spec_util.gd")
const VIEW := Vector3(-0.5646, 0.0, 0.8253)   # SpecimenBuilder.VIEW_DIR
const BISMUTH: Shader = preload("res://shaders/bismuth.gdshader")
const BLADES: Shader = preload("res://shaders/blades.gdshader")
const PEARL: Shader = preload("res://shaders/pearl_crust.gdshader")

static func _rv(b: RefCounted) -> Vector3:
	var v: Vector3 = b._rv()
	return v

## the hero crystal of a group is the gem of it: clear, cloud only at its root (glass.parts — the number _finish gives the shader)
static func _hero(mi: MeshInstance3D, seed_v: int, k := 0) -> void:
	mi.set_meta("part", 0.26 + 0.22 * fposmod((seed_v % 1000 + k * 37) * 0.6180339, 1.0))

## a spot on the rock that looks at the viewer and sits high: the best of `tries` picks
static func _show_spot(b: RefCounted, st: Dictionary, tries := 8, up := 1.0) -> Vector3:
	var p: Vector3 = st.pick.call()
	for t in tries:
		var q: Vector3 = st.pick.call()
		if (st.nrm.call(q) as Vector3).dot(VIEW) + q.y * up > (st.nrm.call(p) as Vector3).dot(VIEW) + p.y * up: p = q
	return p

## wulfenite: thin square plates of orange glass stood on their edges and corners at every angle, a few big ones and
## their small kin, bevelled all round; the middle of a plate deeper in colour than its rim
static func tablets(b: RefCounted, c: Dictionary) -> MeshInstance3D:
	var rng: Rng32 = b.rng
	var st: Dictionary = c.st
	var gs: float = c.gs
	var col: Color = c.col
	c.use_rock.call("slab" if rng.next() < 0.5 else "chunk")
	b.dt.local = true
	b.dt.h = 0.02 + rng.next() * 0.04
	b.dt.a = 0.2
	var cm: ShaderMaterial = c.any_cmat.call()
	var druse: bool = c.kind == "druse"
	var n := 12 + int(rng.next() * 12) if druse else 4 + int(rng.next() * 5)
	var rim := SpecMat.offset_hsl(col, 0.03, 0.0, 0.0)
	var deep := SpecMat.offset_hsl(col, -0.012, 0.0, 0.0)
	var main: MeshInstance3D = null
	var placed := []
	for k in n:
		var f := 1.0 if k == 0 else 0.75 if k == 1 and not druse else pow(rng.next(), 1.7)
		var w := (0.1 + f * 0.3) * gs
		var th := w * (0.04 + rng.next() * 0.045)
		var g := RockKit.tablet(w, th, {bevel = 0.12 + rng.next() * 0.2, cut = 0.0 if rng.next() < 0.45 else 0.1 + rng.next() * 0.3})
		# on a corner (a diamond) or on an edge, a third of it in the rock
		var corner := rng.next() < 0.5
		if corner: g.xform(Transform3D(Basis(Vector3.BACK, PI * 0.25 + (rng.next() - 0.5) * 0.3), Vector3.ZERO))
		else: g.xform(Transform3D(Basis(Vector3.BACK, (rng.next() - 0.5) * 0.35), Vector3.ZERO))
		g.translate(0, w * (0.95 if corner else 0.62), 0)
		g.mark_edges()
		g.subdivide(1).jitter(w * 0.012, 3.0 / w, int(rng.next() * 100000))
		# the pane's colour: deep in its middle, paler and yellower to the bevelled rim
		g.col.resize(g.v.size())
		var mid := Vector3(0, w * (0.95 if corner else 0.62), 0)
		for i in g.v.size():
			var d := (g.v[i] - mid).length() / (w * 1.2)
			var cc := deep.lerp(rim, smoothstep(0.35, 1.0, d))
			cc.a = 1.0
			g.col[i] = cc
		var p: Vector3 = _show_spot(b, st, 6) if k < 2 else st.pick.call()
		# small ones crowd the feet of the big ones
		if k >= 2 and placed.size() and rng.next() < 0.45:
			var pr: Array = placed[int(rng.next() * minf(placed.size(), 3.0))]
			for t in 6:
				var q: Vector3 = st.pick.call()
				if q.distance_to(pr[0]) < p.distance_to(pr[0]): p = q
		var nn: Vector3 = st.nrm.call(p)
		var dir := (nn.lerp(UP, 0.45) + _rv(b) * (0.5 if k < 2 else 1.1)).normalized()
		var mi: MeshInstance3D = U.mesh(g, cm, b.root)
		# the big panes face the viewer, more or less; the rest any way
		var spin := rng.next() * TAU
		if k < 2:
			var flat := (VIEW - dir * VIEW.dot(dir)).normalized()
			var bs := Basis(U.quat_to(UP, dir))
			var z0 := bs.z
			spin = z0.signed_angle_to(flat, dir) + (rng.next() - 0.5) * 0.9
		b._place(mi, p, dir, 1.0, spin)
		mi.set_meta("local", true)
		mi.set_meta("col", true)
		if k < 2: _hero(mi, int(c.seed), k)
		placed.append([p, w])
		if not main: main = mi
	return main

## vanadinite: short six-sided barrels of deep red glass, flat-ended, crowding the rock every way up — standing,
## leaning, lying on their sides, grown into one another in clumps
static func barrels(b: RefCounted, c: Dictionary) -> MeshInstance3D:
	var rng: Rng32 = b.rng
	var st: Dictionary = c.st
	var gs: float = c.gs
	c.use_rock.call("slab" if rng.next() < 0.6 else "chunk")
	b.dt.local = true
	b.dt.h = 0.02 + rng.next() * 0.03
	b.dt.a = 0.2
	var druse: bool = c.kind == "druse"
	var n := int((26 + int(rng.next() * 22)) * float((c.look as Dictionary).get("dense", 1.0))) if druse else 8 + int(rng.next() * 8)
	var main: MeshInstance3D = null
	var placed := []
	for k in n:
		var f := 1.0 if k == 0 else pow(rng.next(), 1.5 if druse else 0.9)
		var s := (0.2 + f * (0.42 if druse else 0.5))
		var p: Vector3
		var nn: Vector3
		if k > 0 and placed.size() and rng.next() < 0.5:
			# grown on another: a clump
			var pr: Array = placed[int(rng.next() * placed.size())]
			nn = (Vector3(rng.next() - 0.5, rng.next() * 0.8, rng.next() - 0.5)).normalized()
			p = (pr[0] as Vector3) + nn * float(pr[1]) * 0.22 * gs
		else:
			p = _show_spot(b, st, 6) if k == 0 else st.pick.call()
			nn = st.nrm.call(p)
		var dir := (nn.lerp(UP, 0.35) + _rv(b) * (0.5 if k == 0 else 1.5)).normalized()
		# (every third shows its six-sided end to the viewer)
		if k % 3 == 1: dir = (VIEW + UP * 0.35 + _rv(b) * 0.5).normalized()
		var mi: MeshInstance3D = c.crystal.call(0.34 + rng.next() * 0.3, s, p, dir)
		mi.set_meta("local", true)
		mi.set_meta("col", true)
		if k == 0: _hero(mi, int(c.seed))
		placed.append([p, s])
		if not main: main = mi
	return main

## crocoite: long thin square needles of scarlet glass thrown across one another like jackstraws, out of a few nests
## in the brown rock, some lying right across the rest
static func jackstraw(b: RefCounted, c: Dictionary) -> MeshInstance3D:
	var rng: Rng32 = b.rng
	var st: Dictionary = c.st
	var gs: float = c.gs
	c.use_rock.call("chunk" if rng.next() < 0.6 else "slab")
	b.dt.local = true
	b.dt.h = 0.02 + rng.next() * 0.03
	b.dt.a = 0.2
	var cm: ShaderMaterial = c.any_cmat.call()
	var druse: bool = c.kind == "druse"
	var main: MeshInstance3D = null
	var nests := 2 + int(rng.next() * 3) if druse else 1 + int(rng.next() * 2)
	for ni in nests:
		var p0: Vector3 = _show_spot(b, st, 8) if ni == 0 else st.pick.call()
		var n0: Vector3 = st.nrm.call(p0)
		var axis := (n0.lerp(UP, 0.5) + _rv(b) * 0.7).normalized()
		var t1 := axis.cross(UP if absf(axis.y) < 0.9 else Vector3.RIGHT).normalized()
		var t2 := axis.cross(t1)
		var cnt := (12 + int(rng.next() * 14)) if druse else (9 + int(rng.next() * 10))
		for k in cnt:
			var f := pow(rng.next(), 1.4)
			var across := rng.next() < 0.18
			var dir := (axis + _rv(b) * (2.4 if across else 1.15)).normalized()
			if dir.dot(n0) < 0.05: dir = (dir + n0 * 0.6).normalized()
			var w := (0.016 + f * 0.03) * gs
			var h := (0.4 + rng.next() * 0.75 + f * 0.35) * gs * (1.0 if ni == 0 else 0.75)
			var g := RockKit.prism(rng, {sides = 4, w = w, d = w * (0.75 + rng.next() * 0.3), h = h, point = false, slope = 0.5 + rng.next() * 0.9 if rng.next() < 0.6 else 0.0,
				taper = 0.94 + rng.next() * 0.05, y0 = -w * 2.5, detail = 1, erode = float(c.ero) * 0.4}, c.zcfg)
			var mi: MeshInstance3D = U.mesh(g, cm, b.root)
			var at := p0 + (t1 * (rng.next() - 0.5) + t2 * (rng.next() - 0.5)) * 0.2 * gs
			b._place(mi, at, dir, 1.0, rng.next() * TAU)
			mi.set_meta("local", true)
			mi.set_meta("col", true)
			if not main: main = mi
	return main

# ---------------------------------------------------------------- one-mesh forms: balls, fans, staircases

## a unit spike: a point at the origin, four-sided rings (a diamond across: half-width w along x, t along z) up to a
## point at y = 1; `rings` [[y, w, t], ...]. Soup, wound outward
static func _spike(rings: Array) -> Geo:
	var g := Geo.new()
	var rs := []
	for r: Array in rings:
		var y := float(r[0])
		var w := float(r[1])
		var t := float(r[2])
		rs.append([Vector3(w, y, 0), Vector3(0, y, t), Vector3(-w, y, 0), Vector3(0, y, -t)])
	var root := Vector3.ZERO
	var tip := Vector3(0, 1, 0)
	for k in 4:
		var j := (k + 1) % 4
		var r0: Array = rs[0]
		var r9: Array = rs[rs.size() - 1]
		g.v.append_array([root, r0[k], r0[j]])
		for i in rs.size() - 1:
			var a: Array = rs[i]
			var c: Array = rs[i + 1]
			g.v.append_array([a[k], c[k], c[j], a[k], c[j], a[j]])
		g.v.append_array([tip, r9[j], r9[k]])
	return g.orient_out(Vector3(0, 0.5, 0))

## a copy of `tpl` put through `xf` and added to `g`, coloured from c0 at the template's y = 0 to c1 at y = 1
static func _add(g: Geo, tpl: Geo, xf: Transform3D, c0: Color, c1: Color, flip := false, own := false) -> void:
	var n := tpl.v.size()
	var b := g.v.size()
	g.v.resize(b + n)
	g.col.resize(b + n)
	# (own: the template's coordinates go along — across, along, through a blade — for blades.gdshader)
	if own: g.rp.resize(b + n)
	for i in n:
		var p := tpl.v[i]
		# (a mirrored transform turns the winding: swap two corners of every triangle)
		var j := i
		if flip:
			var m := i % 3
			j = i + 1 if m == 1 else i - 1 if m == 2 else i
		g.v[b + j] = xf * p
		if own: g.rp[b + j] = p
		var cc := c0.lerp(c1, clampf(p.y, 0.0, 1.0))
		cc.a = 1.0
		g.col[b + j] = cc

## cavansite: balls of electric-blue blades, each a little sun of flat pointed crystals, sitting on a bed of white
## zeolite crystals over dark basalt. The balls one mesh, the white bed one MultiMesh
static func balls(b: RefCounted, c: Dictionary) -> MeshInstance3D:
	var rng: Rng32 = b.rng
	var st: Dictionary = c.st
	var gs: float = c.gs
	var col: Color = c.col
	c.use_rock.call("slab" if rng.next() < 0.6 else "chunk")
	var druse: bool = c.kind == "druse"
	var nb := 3 + int(rng.next() * 4) if druse else 1 + int(rng.next() * 2)
	var deep := SpecMat.offset_hsl(col, 0.03, 0.0, 0.0) * 0.14
	var tipc := SpecMat.offset_hsl(col, -0.02, 0.0, 0.0) * 0.55
	var tpl := _spike([[0.1, 0.55, 0.6], [0.86, 1.0, 1.0]])
	var g := Geo.new()
	var spots := []
	for k in nb:
		var R := (0.2 + rng.next() * 0.1 if k == 0 else 0.09 + rng.next() * 0.12) * gs * (1.0 if druse else 1.35)
		var p: Vector3 = _show_spot(b, st, 8) if k == 0 else st.pick.call()
		# apart from the others, or half grown into a neighbour
		for t in 10:
			var ok := true
			for s: Array in spots:
				if p.distance_to(s[0]) < (float(s[1]) + R) * 0.8: ok = false
			if ok: break
			p = st.pick.call()
		var nn: Vector3 = st.nrm.call(p)
		var c0 := p + nn * R * 0.55
		spots.append([c0, R])
		b.keep_out.append([c0, R * 1.05])
		# the heart of the ball, so no gap shows through
		var core := Geo.icosa(R * 0.5, 1).to_soup()
		_add(g, core, Transform3D(Basis.IDENTITY, c0), deep * 0.5, deep * 0.5, false, true)
		var cnt := int(230 + rng.next() * 90)
		for i in cnt:
			var u := Vector3(rng.next() - 0.5, rng.next() - 0.5, rng.next() - 0.5).normalized()
			if u.dot(nn) < -0.35: u = (u - nn * 2.0 * u.dot(nn)).normalized()
			var x := u.cross(UP if absf(u.y) < 0.9 else Vector3.RIGHT).normalized().rotated(u, rng.next() * TAU)
			var L := R * (0.86 + rng.next() * 0.16)
			var w := R * (0.1 + rng.next() * 0.07)
			var bs := Basis(x * w, u * L, u.cross(x) * w * 0.26)
			# no two blades quite the same blue: some deep, some bright, a few nearly ink
			var vb := 0.55 + rng.next() * 0.9
			var hb := SpecMat.offset_hsl(tipc, (rng.next() - 0.5) * 0.035, 0.0, 0.0) * vb
			_add(g, tpl, Transform3D(bs, c0), deep * vb, hb, bs.determinant() < 0.0, true)
	var m := ShaderMaterial.new()
	m.shader = BLADES
	var tc := col.lerp(Color(0.0, 0.3, 0.9), 0.22)
	m.set_shader_parameter("thin_col", Vector3(tc.r, tc.g, tc.b))
	var mi: MeshInstance3D = U.mesh(g, m, b.root)
	mi.set_meta("col", true)
	# the white bed: stubby pearly zeolite crystals crowded under and round the balls
	var bed := []
	var wm := SpecMat.make({col = SpecMat.lin(0xd6d0c6), rough = 0.3, coat = 0.6, coat_r = 0.2, flat = true, env = 1.2})
	for s: Array in spots:
		var c0: Vector3 = s[0]
		var R: float = s[1]
		for i in int(170 + rng.next() * 80):
			var q: Vector3 = st.pick.call()
			for t in 4:
				var q2: Vector3 = st.pick.call()
				if q2.distance_to(c0) < q.distance_to(c0): q = q2
			if q.distance_to(c0) > R * 3.2: continue
			var qn: Vector3 = st.nrm.call(q)
			var d := (qn + _rv(b) * 1.3).normalized()
			var sz := (0.016 + pow(rng.next(), 1.8) * 0.04) * gs
			bed.append(Transform3D(Basis(U.quat_to(UP, d)) * Basis(UP, rng.next() * TAU) * Basis.from_scale(Vector3(sz * 0.55, sz * 1.5, sz * 0.38)), q - qn * sz * 0.3))
	if bed.size():
		U.inst(_spike([[0.1, 0.9, 0.9], [0.8, 1.0, 1.0]]).fill_color(Color(1, 1, 1)), wm, bed.size(), func(i: int) -> Array: return [bed[i], Color(1, 1, 1) * (0.62 + 0.38 * fposmod(i * 0.6180339, 1.0))], b.root)
	return mi

## erythrite, the cobalt bloom: fans and stars of flat magenta blades laid out on the dark rock, their roots near
## purple, their tips bright pink; a pink bloom dusting the rock round them. All the blades one mesh
static func fans(b: RefCounted, c: Dictionary) -> MeshInstance3D:
	var rng: Rng32 = b.rng
	var st: Dictionary = c.st
	var gs: float = c.gs
	var col: Color = c.col
	c.use_rock.call("slab" if rng.next() < 0.5 else "chunk")
	var druse: bool = c.kind == "druse"
	var nf := 3 + int(rng.next() * 4) if druse else 1 + int(rng.next() * 2)
	var deep := SpecMat.offset_hsl(col, 0.04, 0.0, 0.0) * 0.12
	var tipc := SpecMat.offset_hsl(col, -0.01, 0.0, 0.0) * 0.6
	var tpl := _spike([[0.06, 0.55, 1.0], [0.8, 1.0, 1.0]])
	var g := Geo.new()
	var spots := []
	for k in nf:
		var p: Vector3 = _show_spot(b, st, 8) if k == 0 else st.pick.call()
		for t in 8:
			var ok := true
			for s: Array in spots:
				if p.distance_to(s[0]) < 0.2 * gs: ok = false
			if ok: break
			p = st.pick.call()
		var nn: Vector3 = st.nrm.call(p)
		var R := (0.42 + rng.next() * 0.22 if k == 0 else 0.18 + rng.next() * 0.2) * gs * (1.0 if druse else 1.25)
		spots.append([p, R])
		b.keep_out.append([p, R * 0.5])
		# the fan opens in a plane that leans to the viewer; its middle blade points up and out of the rock
		var fn := (nn.lerp(VIEW, 0.55) + _rv(b) * 0.35).normalized()
		var mid := (UP - fn * UP.dot(fn) + _rv(b) * 0.4)
		mid = (mid - fn * mid.dot(fn)).normalized()
		var side := fn.cross(mid)
		var star := rng.next() < 0.3
		var arc := TAU if star else 1.6 + rng.next() * 1.6
		var cnt := int((60 + rng.next() * 40) * (arc / 2.4))
		for i in cnt:
			var a := (rng.next() - 0.5) * arc
			var lift := (rng.next() - 0.3) * 0.5
			var u := (mid * cos(a) + side * sin(a) + fn * lift).normalized()
			if u.dot(nn) < 0.02: u = (u + nn * 0.5).normalized()
			# longest in the middle of the fan, ragged
			var shape := 0.8 if star else 0.55 + 0.45 * cos(a * PI / arc)
			var L := R * shape * (0.7 + rng.next() * 0.4)
			var w := R * (0.016 + rng.next() * 0.024)
			var x := (fn.cross(u)).normalized().rotated(u, (rng.next() - 0.5) * 1.4)
			var bs := Basis(x * w, u * L, u.cross(x) * w * 0.3)
			var vb := 0.55 + rng.next() * 0.9
			var hb := SpecMat.offset_hsl(tipc, (rng.next() - 0.5) * 0.04, 0.0, 0.0) * vb
			_add(g, tpl, Transform3D(bs, p - nn * 0.01), deep * vb, hb, bs.determinant() < 0.0, true)
	var m := ShaderMaterial.new()
	m.shader = BLADES
	var tc := col.lerp(Color(0.9, 0.02, 0.22), 0.5)
	m.set_shader_parameter("thin_col", Vector3(tc.r, tc.g, tc.b))
	m.set_shader_parameter("pearl", 0.7)
	var mi: MeshInstance3D = U.mesh(g, m, b.root)
	mi.set_meta("col", true)
	# the bloom: a pink dust of tiny crystals over the rock near the fans
	var dust := []
	var dm := SpecMat.make({col = SpecMat.offset_hsl(col, -0.02, 0.0, 0.08), rough = 0.8, grain = 0.5, flat = true, emis = col * 0.15})
	for s: Array in spots:
		for i in int(60 + rng.next() * 60):
			var q: Vector3 = st.pick.call()
			for t in 3:
				var q2: Vector3 = st.pick.call()
				if q2.distance_to(s[0]) < q.distance_to(s[0]): q = q2
			var sz := (0.008 + pow(rng.next(), 2.0) * 0.022) * gs
			dust.append(Transform3D(Basis.from_scale(Vector3(sz, sz * 0.6, sz)), q))
	if dust.size():
		U.inst(Geo.icosa(1.0, 0), dm, dust.size(), func(i: int) -> Array: return [dust[i], Color(1, 1, 1)], b.root)
	return mi

## smithsonite: a crust of pearly bubbles, big ones crowded with small, over the rock, like a bunch of grapes pressed flat;
## one mesh, the hollows between the bubbles a little deeper in colour
static func grapes(b: RefCounted, c: Dictionary) -> MeshInstance3D:
	var rng: Rng32 = b.rng
	var st: Dictionary = c.st
	var gs: float = c.gs
	var col: Color = c.col
	c.use_rock.call("slab" if rng.next() < 0.5 else "chunk")
	var ball := Geo.icosa(1.0, 2).to_soup()
	var g := Geo.new()
	var placed := []
	var p0: Vector3 = _show_spot(b, st, 8)
	var col2 := SpecMat.offset_hsl(col, 0.07 if rng.next() < 0.5 else -0.07, 0.0, 0.03)
	var drift := Vector3(rng.next() - 0.5, rng.next() - 0.5, rng.next() - 0.5).normalized() * (5.0 + rng.next() * 5.0) / gs
	var n := 130 + int(rng.next() * 80)
	for k in n:
		var r := (0.11 + rng.next() * 0.08 if k < 5 else 0.028 + pow(rng.next(), 1.7) * 0.085) * gs
		var p: Vector3
		var nn: Vector3
		if placed.size() and rng.next() < 0.2:
			# a small one budding on another's crown
			var pr: Array = placed[int(rng.next() * minf(placed.size(), 14.0))]
			r = minf(r, float(pr[1]) * 0.55)
			nn = ((pr[2] as Vector3) + Vector3(rng.next() - 0.5, rng.next() - 0.5, rng.next() - 0.5) * 1.1).normalized()
			p = (pr[0] as Vector3) + nn * float(pr[1]) * 0.5
		else:
			# on the rock hard by those already there: a carpet of them, not a heap
			var anchor: Vector3 = p0 if placed.is_empty() or rng.next() < 0.3 else (placed[int(rng.next() * placed.size())] as Array)[0]
			p = st.pick.call()
			for t in 5:
				var q: Vector3 = st.pick.call()
				if q.distance_to(anchor) < p.distance_to(anchor): p = q
			nn = st.nrm.call(p)
		placed.append([p, r, nn])
		if k < 6: b.keep_out.append([p, r])
		# a low dome, its middle in the rock: half a flattened ball shows
		var sq := Basis(U.quat_to(UP, nn)) * Basis.from_scale(Vector3(r, r * (0.5 + rng.next() * 0.28), r))
		var nrm_b := sq.inverse().transposed()
		var b0 := g.v.size()
		_add(g, ball, Transform3D(sq, p), col, col)
		# (the colour drifts across the crust from one hue to its neighbour, bubble by bubble)
		var colb := col.lerp(col2, 0.5 + 0.5 * sin(p.dot(drift))) * (0.8 + rng.next() * 0.4)
		# deeper where a bubble sinks into its neighbours and the rock, brightest on its crown; round, not faceted
		g.own_n.resize(g.v.size())
		for i in range(b0, g.v.size()):
			var out := (nrm_b * ball.v[i - b0]).normalized()
			g.own_n[i] = out
			var cc := colb * (0.3 + 0.5 * smoothstep(-0.2, 0.8, out.dot(nn)))
			cc.a = 1.0
			g.col[i] = cc
	var m := ShaderMaterial.new()
	m.shader = PEARL
	m.set_shader_parameter("seed", float(int(c.seed) % 89))
	var mi: MeshInstance3D = U.mesh(g, m, b.root)
	mi.set_meta("col", true)
	return mi

## the colours the oxide skin of bismuth runs through as it thickens: gold, rose, violet, blue, teal, green
static func _film(t: float) -> Color:
	var stops := [SpecMat.lin(0xe8b030), SpecMat.lin(0xe84a8a), SpecMat.lin(0x8a38d8), SpecMat.lin(0x2a54e8), SpecMat.lin(0x10a8b8), SpecMat.lin(0x40c050), SpecMat.lin(0xe0c030)]
	var x := fposmod(t, 1.0) * (stops.size() - 1)
	var i := int(x)
	var c0: Color = stops[i]
	var c1: Color = stops[mini(i + 1, stops.size() - 1)]
	return c0.lerp(c1, x - i)

## one hopper crystal of bismuth: square walls nested one inside the next, each a step higher than the last and each
## wall of a ring a little higher than the one before, a square spiral staircase, up to a tower in the middle or down
## into a funnel. Its foot at the origin, y up; `a` the half-width. Added to `g`, coloured by how thick the film is
static func _stair(g: Geo, rng: Rng32, a: float, xf: Transform3D, hue0: float, size_k := 1.0) -> void:
	var box := Geo.box(1, 1, 1).translate(0, 0.5, 0)
	var n := 5 + int(rng.next() * 4)
	var tower := rng.next() < 0.6
	var ax := a
	var az := a * (0.75 + rng.next() * 0.25)
	var step := 1.0 / (n + 1.3)
	var wall := a * step * (0.42 + rng.next() * 0.2)      # thin walls, deep grooves between: a skeleton, not a block
	var sh := a * (0.13 + rng.next() * 0.1)
	var h0 := a * (0.12 + rng.next() * 0.12)
	var hk := 0.05 + rng.next() * 0.04      # how fast the colour runs up the staircase
	var flip := xf.basis.determinant() < 0.0
	var ytop := h0 + float(n) * sh
	var put := func(mn: Vector3, mx: Vector3, t: float) -> void:
		var sz := mx - mn
		var bx := Transform3D(Basis.from_scale(sz), Vector3((mn.x + mx.x) * 0.5, mn.y, (mn.z + mx.z) * 0.5))
		var b0 := g.v.size()
		_add(g, box, xf * bx, Color.WHITE, Color.WHITE, flip)
		# for the shader (bismuth.gdshader): the place in this crystal, the film's thickness (more of it up a wall), shade
		g.bary.resize(g.v.size())
		g.rp.resize(g.v.size())
		for i in box.v.size():
			var j := i
			if flip:
				var m := i % 3
				j = i + 1 if m == 1 else i - 1 if m == 2 else i
			var lp: Vector3 = bx * box.v[i]
			g.bary[b0 + j] = Vector3(lp.x / ax, lp.y / a, lp.z / az)
			g.rp[b0 + j] = Vector3(hue0 + (t - 1.6 * (1.0 - box.v[i].y)) * hk, 0.42 + 0.58 * smoothstep(0.0, 1.0, lp.y / ytop), size_k)
	# a funnel's outer wall is its highest: plates laid against it lower and lower, or its side is one blank slab
	if not tower:
		var y0 := h0 + (float(n) - 3.5) * sh
		for k in range(1, 3 + int(rng.next() * 2)):
			var o := a * step * 0.3 * k
			var yk := y0 * (1.0 - 0.26 * k - rng.next() * 0.08)
			if yk < a * 0.05: break
			put.call(Vector3(-ax - o, 0, -az - o), Vector3(ax + o, yk, -az - o + wall), -float(k))
			put.call(Vector3(-ax - o, 0, az + o - wall), Vector3(ax + o, yk, az + o), -float(k))
			put.call(Vector3(-ax - o, 0, -az - o), Vector3(-ax - o + wall, yk, az + o), -float(k))
			put.call(Vector3(ax + o - wall, 0, -az - o), Vector3(ax + o, yk, az + o), -float(k))
	for i in n:
		var ex := ax * (1.0 - i * step)
		var ez := az * (1.0 - i * step)
		for j in 4:
			var t := float(i) + j * 0.25
			var y := h0 + (t if tower else float(n) - 1.75 - absf(t - 1.75)) * sh
			match j:
				0: put.call(Vector3(ex - wall, 0, -ez), Vector3(ex, y, ez), t)
				1: put.call(Vector3(-ex + wall, 0, ez - wall), Vector3(ex - wall, y, ez), t)
				2: put.call(Vector3(-ex, 0, -ez), Vector3(-ex + wall, y, ez), t)
				3: put.call(Vector3(-ex + wall, 0, -ez), Vector3(ex - wall, y, -ez + wall), t)
	# the middle: the top of the tower, or the floor of the funnel
	var ex2 := ax * (1.0 - n * step)
	var ez2 := az * (1.0 - n * step)
	var yt := h0 + float(n) * sh if tower else h0 * 0.6
	put.call(Vector3(-ex2, 0, -ez2), Vector3(ex2, yt, ez2), float(n))

## bismuth: stepped hopper crystals grown through one another at right angles, every terrace a different colour of
## the oxide film, gold running to rose, violet, blue and green. No rock: it stands on its own corner. One mesh
static func staircase(b: RefCounted, c: Dictionary) -> MeshInstance3D:
	var rng: Rng32 = b.rng
	var gs: float = c.gs
	var g := Geo.new()
	var a := 0.4 * gs
	var hue0 := rng.next()
	_stair(g, rng, a, Transform3D.IDENTITY, hue0)
	# stood so its terraces face the viewer: the axis tipped well towards them
	var axis := (VIEW * (0.55 + rng.next() * 0.35) + UP * 0.6 + Vector3(rng.next() - 0.5, 0, rng.next() - 0.5) * 0.3).normalized()
	var tilt := Basis(U.quat_to(UP, axis)) * Basis(UP, rng.next() * TAU)
	# others out of its sides and corners, their axes along the first one's; none with its blank foot to the viewer
	var axes := []
	for bs0: Basis in [Basis.IDENTITY, Basis(Vector3.RIGHT, PI * 0.5), Basis(Vector3.RIGHT, -PI * 0.5), Basis(Vector3.BACK, PI * 0.5), Basis(Vector3.BACK, -PI * 0.5)]:
		if (tilt * bs0 * UP).dot((VIEW + UP * 0.4).normalized()) > 0.05: axes.append(bs0)
	for k in 2 + int(rng.next() * 4):
		var bs: Basis = axes[int(rng.next() * axes.size())]
		var s := 0.35 + rng.next() * 0.4
		var at := Vector3((rng.next() - 0.5) * 1.6, 0.1 + rng.next() * 0.7, (rng.next() - 0.5) * 1.6) * a
		_stair(g, rng, a * s, Transform3D(bs, at), hue0 + (rng.next() - 0.5) * 0.4, s)
	g.xform(Transform3D(tilt, Vector3.ZERO))
	var bb := g.aabb()
	g.translate(-bb.get_center().x, -bb.position.y - 0.25, -bb.get_center().z)
	var m := ShaderMaterial.new()
	m.shader = BISMUTH
	m.set_shader_parameter("seed", float(int(c.seed) % 89))
	var mi: MeshInstance3D = U.mesh(g, m, b.root)
	mi.set_meta("col", true)
	b.root.set_meta("face", true)
	return mi

# ---------------------------------------------------------------- tourmaline

## the ways the colour of a tourmaline runs along it, foot to tip: [name, weight, [[where 0..1, colour], ...]]
const TOURM := [
	["watermelon", 4.0, [[0.0, 0x147032], [0.46, 0x2ea048], [0.6, 0xe4508a], [1.0, 0xcc1e62]]],
	["bicolour", 3.0, [[0.0, 0xc8246a], [0.46, 0xe45a96], [0.6, 0x3cb058], [1.0, 0x0e6834]]],
	["tricolour", 2.5, [[0.0, 0x0e6834], [0.3, 0x2ea048], [0.42, 0xe6d27a], [0.56, 0xee96b0], [0.68, 0xdc4484], [1.0, 0xb81a5a]]],
	["blue cap", 2.5, [[0.0, 0xe4508a], [0.66, 0xd0347a], [0.76, 0x3252dc], [1.0, 0x1626a0]]],
	["rubellite", 2.0, [[0.0, 0xb81a50], [1.0, 0xe83a78]]],
	["indicolite", 1.5, [[0.0, 0x1a4a9a], [0.6, 0x1e7ab8], [1.0, 0x28a8c8]]],
	["verdelite", 1.5, [[0.0, 0x0e5a34], [0.7, 0x2a9a4a], [1.0, 0x8ad060]]],
	["paraiba", 0.8, [[0.0, 0x0aa0c0], [0.5, 0x10d0d0], [1.0, 0x40f0c8]]],
]

static func tourm_of(seed_v: int) -> Array:
	var r := Rng32.new((seed_v * 2246822519 + 611) % 4294967296)
	var tw := TOURM.map(func(e: Array) -> Array: return [e, e[1]])
	var e: Array = Stones.pick_w(tw, r)
	return e

static func _stop_at(s: Array, shift: float) -> float:
	var x := float(s[0])
	return clampf(x + (shift if x > 0.01 and x < 0.99 else 0.0), 0.0, 1.0)

static func _stops(stops: Array, t: float, shift := 0.0) -> Color:
	var prev: Array = stops[0]
	for s: Array in stops:
		var at := _stop_at(s, shift)
		if t <= at:
			var p0 := _stop_at(prev, shift)
			var f := 0.0 if at <= p0 else (t - p0) / (at - p0)
			return SpecMat.lin(int(prev[1])).lerp(SpecMat.lin(int(s[1])), f * f * (3.0 - 2.0 * f))
		prev = s
	return SpecMat.lin(int(prev[1]))

## a tourmaline pencil: a long prism, rounded-three-sided across and ribbed along its length, flat-ended with a low
## bevel; its colour runs through `stops` from foot to tip. Foot at the origin (a little below), y up
static func _pencil(rng: Rng32, r: float, h: float, stops: Array, shift: float) -> Geo:
	var seg := 30
	var ph := rng.next() * TAU
	var rib := 0.04 + rng.next() * 0.03
	var prof := []
	for k in seg:
		var a := float(k) / seg * TAU
		var rr := r * (1.0 + 0.11 * cos(3.0 * a + ph) + rib * absf(cos(6.0 * a + ph * 2.0)) + 0.012 * cos(15.0 * a))
		prof.append(Vector2(cos(a) * rr, sin(a) * rr))
	var ys := [-r * 0.6]
	var rows := 12
	for i in rows + 1: ys.append(h * float(i) / rows)
	var g := Geo.new()
	var ring := func(y: float, k: float) -> Array:
		var out := []
		for q: Vector2 in prof: out.append(Vector3(q.x * k, y, q.y * k))
		return out
	var col_at := func(y: float) -> Color:
		var cc := _stops(stops, clampf(y / h, 0.0, 1.0), shift)
		cc.a = 1.0
		return cc
	var quad := func(a: Vector3, bq: Vector3, cq: Vector3, d: Vector3) -> void:
		for p: Vector3 in [a, bq, cq, a, cq, d]:
			g.v.append(p)
			g.col.append(col_at.call(p.y))
	var prev: Array = ring.call(ys[0], 0.96)
	for i in range(1, ys.size()):
		var cur: Array = ring.call(ys[i], 1.0 - 0.03 * float(i) / ys.size())
		for k in seg:
			var j := (k + 1) % seg
			quad.call(prev[k], prev[j], cur[j], cur[k])
		prev = cur
	# the end: a narrow bevel, then the flat face
	var bev: Array = ring.call(h + r * 0.14, 0.8)
	var top := Vector3(0, h + r * 0.2, 0)
	for k in seg:
		var j := (k + 1) % seg
		quad.call(prev[k], prev[j], bev[j], bev[k])
		for p: Vector3 in [bev[k], bev[j], top]:
			g.v.append(p)
			g.col.append(col_at.call(h))
	return g.orient_out(Vector3(0, h * 0.5, 0))

## tourmaline: a few long ribbed pencils standing in white feldspar, striped along their length (green to pink,
## pink under a blue cap), with lilac books of mica at their feet
static func pencils(b: RefCounted, c: Dictionary) -> MeshInstance3D:
	var rng: Rng32 = b.rng
	var st: Dictionary = c.st
	var gs: float = c.gs
	c.use_rock.call("small" if rng.next() < 0.5 else "chunk")
	b.dt.local = true
	b.dt.h = 0.02 + rng.next() * 0.04
	b.dt.a = 0.2
	var cm: ShaderMaterial = c.any_cmat.call()
	var scheme: Array = tourm_of(int(c.seed))
	var stops: Array = scheme[2]
	var druse: bool = c.kind == "druse"
	var n := 3 + int(rng.next() * 4) if druse else 1 + int(rng.next() * 2)
	var main: MeshInstance3D = null
	var p0: Vector3 = _show_spot(b, st, 8, 2.0)
	var axis := (UP + _rv(b) * 0.5).normalized()
	for k in n:
		var f := 1.0 if k == 0 else 0.35 + rng.next() * 0.5
		var r := (0.12 + rng.next() * 0.05) * gs * (0.55 + 0.45 * f)
		var h := (1.15 + rng.next() * 0.5) * gs * f
		var g := _pencil(rng, r, h, stops, (rng.next() - 0.5) * 0.14)
		g.mark_edges(30.0)
		var mi: MeshInstance3D = U.mesh(g, cm, b.root)
		var p: Vector3 = p0
		if k > 0:
			p = st.pick.call()
			for t in 5:
				var q: Vector3 = st.pick.call()
				if q.distance_to(p0) < p.distance_to(p0): p = q
		var dir := (axis + _rv(b) * (0.25 if k == 0 else 0.7)).normalized()
		b._place(mi, p - dir * 0.02, dir, 1.0, rng.next() * TAU)
		mi.set_meta("local", true)
		mi.set_meta("col", true)
		if k == 0: _hero(mi, int(c.seed))
		if not main: main = mi
	var at: Vector3 = b._mid(main, 0.7)
	b._mark("tm_" + String(scheme[0]).replace(" ", "_"), at)
	# lepidolite: lilac books of mica at the feet
	var flakes := []
	var lm := SpecMat.make({col = SpecMat.lin(0xb48ad0), metal = 0.35, rough = 0.25, coat = 0.5, env = 1.8, flat = true, emis = SpecMat.lin(0xb48ad0) * 0.06})
	for book in 3 + int(rng.next() * 4):
		var q: Vector3 = st.pick.call()
		for t in 3:
			var q2: Vector3 = st.pick.call()
			if q2.distance_to(p0) < q.distance_to(p0): q = q2
		var qn: Vector3 = st.nrm.call(q)
		var d := (qn + _rv(b) * 0.8).normalized()
		var bs := Basis(U.quat_to(UP, d)) * Basis(UP, rng.next() * TAU)
		var sz := (0.05 + rng.next() * 0.05) * gs
		for i in 5 + int(rng.next() * 6):
			flakes.append(Transform3D(bs * Basis(UP, (rng.next() - 0.5) * 0.3) * Basis.from_scale(Vector3(sz, sz * 0.06, sz * (0.8 + rng.next() * 0.3))), q + d * (i * sz * 0.085) + _rv(b) * sz * 0.08))
	if flakes.size():
		U.inst(Geo.cylinder(1, 1, 1, 6), lm, flakes.size(), func(i: int) -> Array: return [flakes[i], Color(1, 1, 1)], b.root)
	return main

## a watermelon slice: a tourmaline sawn across and polished, a rounded triangle of glass, raspberry in its heart, a
## pale ring, then the green rind; stood up facing the viewer, nothing else
static func slice(b: RefCounted, c: Dictionary) -> MeshInstance3D:
	var rng: Rng32 = b.rng
	var gs: float = c.gs
	var seg := 36
	var R := 0.74 * gs
	var th := R * (0.15 + rng.next() * 0.05)
	var ph := rng.next() * TAU
	var ring_ph := rng.next() * 10.0
	var hearts := [0xe83a78, 0xf05a90, 0xd02868]
	var rinds := [0x2a9a4a, 0x1e8a5a, 0x5ab040]
	var heart := SpecMat.lin(int(hearts[int(rng.next() * 3)]))
	var pale := SpecMat.lin(0xf4e6d8)
	var rind := SpecMat.lin(int(rinds[int(rng.next() * 3)]))
	var skin := SpecMat.lin(0x0e4a2a)
	var w_heart := 0.45 + rng.next() * 0.15
	var col_at := func(f: float) -> Color:
		var cc := heart.lerp(pale, smoothstep(w_heart - 0.05, w_heart + 0.03, f))
		cc = cc.lerp(rind, smoothstep(w_heart + 0.06, w_heart + 0.14, f))
		cc = cc.lerp(skin, smoothstep(0.93, 1.0, f))
		# growth rings: the colour a little deeper and paler by turns
		cc = cc.lerp(cc * 0.55, 0.5 + 0.5 * sin(f * 38.0 + ring_ph))
		cc.a = 1.0
		return cc
	var out := func(a: float, f: float) -> Vector2:
		# the outline: three-sided, rounded, a little ragged; the inner rings follow it
		var rr := R * f * (1.0 + (0.1 + 0.03 * f) * cos(3.0 * a + ph) + 0.02 * f * cos(7.0 * a + ph * 3.0))
		return Vector2(cos(a) * rr, sin(a) * rr)
	var g := Geo.new()
	var rings := []
	for i in 25: rings.append(float(i) / 24.0)
	for side: float in [1.0, -1.0]:
		for i in rings.size() - 1:
			var f0: float = rings[i]
			var f1: float = rings[i + 1]
			for k in seg:
				var a0 := float(k) / seg * TAU
				var a1 := float(k + 1) / seg * TAU
				var q: Array[Vector2] = [out.call(a0, f0), out.call(a1, f0), out.call(a1, f1), out.call(a0, f1)]
				var fs: Array[float] = [f0, f0, f1, f1]
				for e: int in [0, 1, 2, 0, 2, 3]:
					# domed: full thickness in the middle, rounding down to the rim
					g.v.append(Vector3(q[e].x, q[e].y, th * side * (1.0 - 0.55 * pow(fs[e], 3.0))))
					g.col.append(col_at.call(fs[e]))
	# the rind round the edge
	for k in seg:
		var a0 := float(k) / seg * TAU
		var a1 := float(k + 1) / seg * TAU
		var p0: Vector2 = out.call(a0, 1.0)
		var p1: Vector2 = out.call(a1, 1.0)
		var te := th * 0.45
		for p: Vector3 in [Vector3(p0.x, p0.y, te), Vector3(p0.x, p0.y, -te), Vector3(p1.x, p1.y, -te), Vector3(p0.x, p0.y, te), Vector3(p1.x, p1.y, -te), Vector3(p1.x, p1.y, te)]:
			g.v.append(p)
			g.col.append(skin)
	g.orient_out()
	g.mark_edges(30.0)
	var sd: Dictionary = c.cmat_spec.call()
	sd.merge({st = 0.0, deep_body = 0.75, tint_glow = 0.14, dark_body = 0.3, thick = 1.8, holo = 0.0}, true)
	var cm: ShaderMaterial = c.make_cmat.call(sd)
	var mi: MeshInstance3D = U.mesh(g, cm, b.root)
	# its face to the viewer, tipped back a little
	var zb := (VIEW + UP * 0.18 + Vector3(rng.next() - 0.5, 0, rng.next() - 0.5) * 0.25).normalized()
	var xb := UP.cross(zb).normalized()
	mi.transform = Transform3D(Basis(xb, zb.cross(xb), zb) * Basis(Vector3.BACK, rng.next() * TAU), Vector3(0, R * 0.9, 0))
	mi.set_meta("col", true)
	b.root.set_meta("face", true)
	b._mark("tm_slice", mi.transform * Vector3(0, 0, th), zb)
	return mi

# ---------------------------------------------------------------- an association: a second species on the same rock

## a species' colour for this find (its palette picked on a stream of its own)
static func col_of(sid: String, seed_v: int) -> Color:
	var look := SpecLooks.of(sid)
	var col := SpecMat.lin_s(String(Data.SP[sid].c))
	if look.has("palette"):
		var pal: Array = look.palette
		var pe: Array = Stones.pick_w(pal.map(func(e: Array) -> Array: return [e, e[2]]), Rng32.new((seed_v * 1597334677 + 31) % 4294967296))
		col = SpecMat.lin(int(pe[0]))
	return col

## a species' crystal material where it grows as a guest: metal, opaque or glass as its look says; no crust of rock
static func mat_of(sid: String, seed_v: int) -> ShaderMaterial:
	var look := SpecLooks.of(sid)
	if look.has("metal_col"):
		return SpecMat.make({col = SpecMat.lin(int(look.metal_col)), metal = 0.95, rough = float(look.get("mrough", 0.3)), coat = 0.6, coat_r = 0.08, flat = true,
			env = float(look.get("menv", 2.6)), oil = float(look.get("tarnish", 0.5)), prio = 2})
	if sid in ["pyrite", "hematite", "galena"] or String(Data.HABIT.get(sid, "")) == "nugget":
		return SpecMat.make({col = Color(1, 1, 1), metal = 0.95, rough = 0.2, coat = 0.6, flat = true, env = 1.6, oil = 0.35, prio = 2})
	if look.has("opaque"):
		var oq: Dictionary = look.opaque
		return SpecMat.make({col = Color(1, 1, 1), rough = float(oq.get("rough", 0.35)), coat = float(oq.get("coat", 0.4)), coat_r = 0.15, flat = true, env = 1.3,
			grain = float(oq.get("grain", 0.1)), prio = 2})
	var gl: Dictionary = look.get("glass", {})
	var irm := float(look.get("ir", 1.0))
	return SpecMat.make({col = Color(1, 1, 1), flat = true, glass = true, ir = 0.07 * irm, rf = 0.3, frost = float(gl.get("frost", 0.15)), thick = 1.4,
		seed = float(seed_v % 97), holo = 0.2 * irm, dark_body = float(gl.get("dark", 0.0)), tint_body = float(gl.get("tint", 0.0)),
		tint_glow = float(gl.get("glow", 0.06)), deep_body = float(gl.get("deep", 0.0)), prio = 2})

## the second species of an association: a little group of its crystals (bubbles for the lumpy ones, nuggets for the
## native metals) on the free rock to one side of the first; marked "assoc"
static func partner(b: RefCounted, sid: String, st: Dictionary, gs: float, seed_v: int) -> void:
	var r := Rng32.new((seed_v * 2654435761 + 977) % 4294967296)
	var look := SpecLooks.of(sid)
	var habit := String(Data.HABIT.get(sid, "prism"))
	var col := col_of(sid, seed_v + 7)
	# a free spot that shows, and the spots round it
	var p0: Vector3 = st.pick.call()
	var best := -9.0
	for t in 24:
		var q: Vector3 = st.pick.call()
		var free: bool = b._free(q)
		var score := (st.nrm.call(q) as Vector3).dot(VIEW) + q.y * 0.6 + (2.0 if free else 0.0)
		if score > best:
			best = score
			p0 = q
	var near := func(reach: float) -> Vector3:
		var p: Vector3 = st.pick.call()
		for t in 8:
			var q: Vector3 = st.pick.call()
			var fq: bool = b._free(q)
			if fq and q.distance_to(p0) < p.distance_to(p0): p = q
		return p
	var n0: Vector3 = st.nrm.call(p0)
	if habit in ["botryoid", "grape"]:
		# bubbles: a little bunch of them (malachite beside azurite), banded where the species is
		var ball := Geo.icosa(1.0, 2).to_soup()
		var g := Geo.new()
		var placed := []
		for k in 10 + int(r.next() * 12):
			var rad := (0.07 + r.next() * 0.04 if k < 2 else 0.025 + pow(r.next(), 1.5) * 0.05) * gs
			var p: Vector3
			var nn: Vector3
			if placed.size() and r.next() < 0.6:
				var pr: Array = placed[int(r.next() * placed.size())]
				nn = Vector3(r.next() - 0.5, r.next() * 0.9, r.next() - 0.5).normalized()
				p = (pr[0] as Vector3) + nn * (float(pr[1]) * 0.75 + rad * 0.3)
			else:
				p = near.call(0.14 * gs) if k else p0
				nn = st.nrm.call(p)
				p += nn * rad * 0.3
			placed.append([p, rad])
			var b0 := g.v.size()
			_add(g, ball, Transform3D(Basis.from_scale(Vector3(rad, rad * 0.9, rad)), p), col, col)
			g.own_n.resize(g.v.size())
			for i in range(b0, g.v.size()):
				var out := (g.v[i] - p).normalized()
				g.own_n[i] = out
				var cc := col * (0.35 + 0.5 * smoothstep(-0.5, 0.7, out.dot(nn)))
				cc.a = 1.0
				g.col[i] = cc
		var banded := sid in ["malachite", "chrysocolla", "chalcedony"]
		var bm := SpecMat.make({col = Color(1, 1, 1), rough = 0.2, coat = 0.85, coat_r = 0.1, env = 1.4, ir = 0.15, bd = 0.6 if banded else 0.0, emis = col * 0.08, prio = 2})
		var mi: MeshInstance3D = U.mesh(g, bm, b.root)
		mi.set_meta("col", true)
		b._mark("assoc", (placed[0] as Array)[0] + n0 * float((placed[0] as Array)[1]), n0)
		return
	if habit == "nugget":
		# native metal: a few hammered lumps in the rock
		var copper := sid == "nativecu"
		var mm := SpecMat.make({col = SpecMat.lin(0xd2703a if copper else 0xf0c050), metal = 1.0, rough = 0.3, coat = 0.3, env = 1.8, grain = 0.15})
		for k in 3 + int(r.next() * 4):
			var rad := (0.07 + r.next() * 0.05 if k == 0 else 0.03 + r.next() * 0.04) * gs
			var p: Vector3 = near.call(0.16 * gs) if k else p0
			var nn: Vector3 = st.nrm.call(p)
			var mi: MeshInstance3D = U.mesh(RockKit.crumble(r, rad, Vector3(1.2 + r.next() * 0.3, 0.7 + r.next() * 0.25, 1.0)), mm, b.root, p + nn * rad * 0.3,
				U.eul(r.next() * 6.3, r.next() * 6.3, r.next() * 6.3))
			mi.set_meta("col", true)
			if k == 0: b._mark("assoc", p + nn * rad, nn)
		return
	# crystals of its own habit, a big one and its small kin
	var hb := habit
	if look.has("habits"): hb = String(((look.habits as Array)[0] as Array)[0])
	var m := mat_of(sid, seed_v)
	var elong := hb in ["prism", "blade", "barrel", "scaleno"]
	for k in 3 + int(r.next() * 4):
		var f := 1.0 if k == 0 else 0.35 + r.next() * 0.5
		var cfg := {h = (0.55 + f * 0.4) if elong else (0.45 + f * 0.4), detail = 1, cA = col, cB = col, zk = 0.0, hk = float(look.get("hk", 1.0)), wk = float(look.get("wk", 1.0)),
			blunt = bool(look.get("blunt", false)), saddle = float(look.get("saddle", 0.0)), rh = float(look.get("rh", 0.3)), steps = bool(look.get("steps", false)),
			bend = float(look.get("bend", 0.0))}
		var g := RockKit.crystal(hb, r, cfg)
		var mi: MeshInstance3D = U.mesh(g, m, b.root)
		var p: Vector3 = near.call(0.18 * gs) if k else p0
		var nn: Vector3 = st.nrm.call(p)
		var dir := (nn.lerp(UP, 0.45) + Vector3(r.next() - 0.5, r.next() - 0.5, r.next() - 0.5) * 0.8).normalized()
		b._place(mi, p - dir * 0.01, dir, (0.18 + f * 0.2) * gs * (0.85 if elong else 1.15), r.next() * TAU)
		mi.set_meta("col", true)
		if k == 0: b._mark("assoc", b._mid(mi, 0.6))

## an association grown on the first species' own crystal: a native metal (or a brassy sulphide) clinging to it in a
## few spongy clusters of tiny crystals, thick in the middle of each and thinning to single grains — gold on quartz.
## One MultiMesh, a nugget at the heart of each cluster; marked "assoc"
static func perch(b: RefCounted, sid: String, main: MeshInstance3D, gs: float, seed_v: int) -> void:
	var r := Rng32.new((seed_v * 2654435761 + 1213) % 4294967296)
	var pts: Array = RockKit.surf_pts(main, 1300, r, Callable(), b.root)
	if pts.is_empty(): return
	var y0 := INF
	var y1 := -INF
	for e: Array in pts:
		y0 = minf(y0, (e[0] as Vector3).y)
		y1 = maxf(y1, (e[0] as Vector3).y)
	var H := maxf(0.001, y1 - y0)
	var L := maxf(H, 0.3 * gs)
	var cube := sid in ["pyrite"]
	var hexes := {gold = 0xf2c044, nativecu = 0xd8743c, pyrite = 0xd6c07a, marcasite = 0xcfc890}
	var col := SpecMat.lin(int(hexes.get(sid, 0xf2c044)))
	var mm := SpecMat.make({col = col, metal = 1.0, rough = 0.27, coat = 0.3, env = 1.9, flat = true, grain = 0.1})
	# where: a few places up the crystal that the viewer sees, apart from one another
	var centres := []
	var want := 3 + int(r.next() * 3)
	var guard := 0
	while centres.size() < want and guard < 400:
		guard += 1
		var e: Array = pts[int(r.next() * pts.size())]
		var p: Vector3 = e[0]
		var n: Vector3 = e[1]
		if n.dot(VIEW) < (0.1 if centres.size() < want - 1 else -0.3): continue
		if p.y < y0 + H * 0.26 or p.y > y1 - H * 0.03: continue
		var ok := true
		for c: Array in centres:
			if p.distance_to(c[0]) < L * 0.17: ok = false
		if ok: centres.append([p, n, 0.45 + r.next() * 0.55 if centres.size() else 1.0])
	if centres.is_empty(): return
	var xfs := []
	var cols := []
	for c: Array in centres:
		var cp: Vector3 = c[0]
		var rho := L * (0.06 + 0.075 * float(c[2]))
		for e: Array in pts:
			var p: Vector3 = e[0]
			var d := p.distance_to(cp)
			if d > rho: continue
			var n: Vector3 = e[1]
			var f := 1.0 - d / rho
			# thick at the heart (crystals piled on crystals), a scatter of grains at the edge
			if f < 0.3 and r.next() < 0.5: continue
			for layer in (3 if f > 0.6 else 2 if f > 0.3 else 1):
				var s := L * (0.009 + 0.026 * f * (0.45 + r.next() * 0.75)) * (1.0 - 0.22 * layer)
				var at := p + n * s * (0.3 + layer * 1.05) + Vector3(r.next() - 0.5, r.next() - 0.5, r.next() - 0.5) * s * 0.9
				var bs := U.eul(r.next() * 6.3, r.next() * 6.3, r.next() * 6.3) * Basis.from_scale(Vector3(s, s * (0.75 + r.next() * 0.6), s))
				xfs.append(Transform3D(bs, at))
				cols.append(Color(1, 1, 1) * (0.72 + r.next() * 0.38))
		# the heart: a lump of the metal
		var hs := L * (0.02 + 0.022 * float(c[2]))
		var cn: Vector3 = c[1]
		var nug: MeshInstance3D = U.mesh(RockKit.crumble(r, hs, Vector3(1.25, 0.8, 1.0), 8), mm, b.root, cp + cn * hs * 0.45, U.eul(r.next() * 6.3, r.next() * 6.3, r.next() * 6.3))
		nug.set_meta("col", true)
	if xfs.size():
		var tpl := (Geo.box(1.3, 1.3, 1.3) if cube else Geo.octa(1)).fill_color(Color(1, 1, 1))
		U.inst(tpl, mm, xfs.size(), func(i: int) -> Array: return [xfs[i], cols[i]], b.root)
	var c0: Array = centres[0]
	b._mark("assoc", (c0[0] as Vector3) + (c0[1] as Vector3) * L * 0.04, c0[1])
