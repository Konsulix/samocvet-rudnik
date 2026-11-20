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
var crust_once := false   # split the crust only once (a skull: see _finish)
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
	var r := b._specimen(o)
	if r: b._alex(r)
	if r: r.set_meta("mass", b.body_mass if not b.body_mass.is_empty() else mass_of(r))
	return r

## alexandrite (SpecLooks alex): its crystals' glass knows its lamplight colour; the card turns them to it on a tap
## (SpecView._lamp, alex_k). Each its own copy of the material — the rock and what grows keep theirs
func _alex(r: Node3D) -> void:
	var lc: Variant = SpecLooks.of(_sid).get("alex", null)
	if lc == null: return
	var c := SpecMat.lin(int(lc))
	var done := {}
	for n in r.find_children("*", "MeshInstance3D", true, false):
		if not n.has_meta("crystal"): continue
		# (only the alexandrite's own: a partner on the same rock — the emerald beside it — keeps its colour)
		if String(n.get_meta("gene", "body")) != "body" or not _alex_of(n): continue
		var up := n
		var mine := true
		while up and up != r:
			if up.has_meta("partner"): mine = false
			up = up.get_parent()
		if not mine: continue
		var m := (n as MeshInstance3D).material_override as ShaderMaterial
		if not m or m.get_shader_parameter("tint_k") == null: continue
		if not done.has(m):
			var cm := SpecUtil.mat_copy(m)
			cm.set_shader_parameter("alex_col", Vector3(c.r, c.g, c.b))
			cm.set_shader_parameter("alex_p", float(SpecLooks.of(_sid).get("pleo", 0.0)))
			cm.set_meta("alex", true)
			done[m] = cm
		(n as MeshInstance3D).material_override = done[m]
	r.set_meta("alex", not done.is_empty())

## a crystal of the find's own body (not a gene's): the node or one above it tagged "body"
func _alex_of(n: Node) -> bool:
	var p := n
	while p and p != root:
		if p.has_meta("gene"): return String(p.get_meta("gene")) == "body"
		p = p.get_parent()
	return true

## the bulk of what was built (Stones.settle): the boxes of its meshes, half full, in the find's own space — the rock's
## (meta base, or a rock material) and the mineral's apart. Not what grows on it (moss, flowers: multimeshes mostly)
## nor what swims about it (top_level)
var body_mass := {}   # (taken as the body is done: _specimen, before anything grows on it)

static func mass_of(r: Node3D, body := false) -> Dictionary:
	var rock := 0.0
	var mineral := 0.0
	var all := AABB()
	var first := true
	for n in r.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.top_level or not mi.visible: continue
		var top: Node = mi
		while top.get_parent() and top.get_parent() != r: top = top.get_parent()
		if not body and String(top.get_meta("gene", "body")) != "body": continue
		var bb := AABB()
		if mi.mesh: bb = mi.mesh.get_aabb()
		elif mi.has_meta("geo"): bb = (mi.get_meta("geo") as Geo).aabb()
		else: continue
		var w := U.rel_xform(mi, r) * bb
		all = w if first else all.merge(w)
		first = false
		var v := w.size.x * w.size.y * w.size.z * 0.5
		var cm := mi.material_override
		if mi.has_meta("base") or (cm and cm.has_meta("rock")): rock += v
		else: mineral += v
	# (`span`: the find's size as its card frames it — the card fits every find to the same frame, so what reads as
	# heavy is how much of that frame is stone: a chunk filling it, not a spindly sceptre)
	return {rock = rock, min = mineral, span = maxf(0.01, maxf(all.size.x, all.size.y))}

# ---------------------------------------------------------------- specimen

static func quat_to_l(a: Vector3, b: Vector3) -> Quaternion:
	return U.quat_to(a, b.normalized())

func _rv() -> Vector3:
	return Vector3(rng.next() - 0.5, rng.next() - 0.5, rng.next() - 0.5)

func _place(node: Node3D, at: Vector3, dir: Vector3, s: float, spin: float) -> void:
	node.transform = Transform3D(Basis(U.quat_to(UP, dir.normalized())) * Basis(UP, spin) * Basis.from_scale(Vector3(s, s, s)), at)

## how hurt a find came out of the rock: 0 untouched (integrity 100) .. 1 (the least there is, 10)
## (20.11, playtest: one touch of a special — Fine, 88 — left the crystal pitted all over with its tip gone, «too
## cruel for one slip»: Fine (80+) is now a few small pits, no more; Chipped and below hurt as before)
static func damage_of(integ: int) -> float:
	if integ >= 88: return 0.0   # (Pristine: one slip forgiven, the stone shows nothing)
	if integ >= 70: return 0.05 * (88.0 - integ) / 18.0   # (Fine: a few light nicks)
	return clampf((100.0 - integ) / 90.0, 0.0, 1.0)

## the mushrooms' size asked for: once they found room at full size (the rock's sides, the open rock) they stood a
## third taller on average than they did when most shrank by the crystals (tests/rest_audit size: 0.073 -> 0.098 of
## the find's height) — brought back to what it was
const SHROOM_K := 0.75

## what grew since child `had` as copies of a model standing on the find (SpecFlora, SpecFungi: meta "stand"): the
## room of each copy taken (keep_out), so the next of the rock's life grows round it — not violets through a mushroom
func _claim(had: int) -> void:
	for i in range(had, root.get_child_count()):
		var mi := root.get_child(i) as MultiMeshInstance3D
		if mi == null or not mi.has_meta("stand") or not mi.has_meta("ibuf") or mi.multimesh == null or mi.multimesh.mesh == null: continue
		var buf: PackedFloat32Array = mi.get_meta("ibuf")
		var mm := mi.multimesh
		var stride := 12 + (4 if mm.use_colors else 0) + (4 if mm.use_custom_data else 0)
		var bx := mm.mesh.get_aabb().size
		var half := maxf(bx.x, bx.z) * 0.5
		for k in buf.size() / stride:
			var o := k * stride
			var sc := Vector3(buf[o], buf[o + 4], buf[o + 8]).length()
			keep_out.append([mi.transform * Vector3(buf[o + 3], buf[o + 7], buf[o + 11]), sc * half * 0.7])

## a lone crystal's rock climbing one of its sides (photos: a quartz point half sunk in a bubbly crust): a second lump
## of the same rock leaned against its foot, up a third to a half of its length, on a side of it the viewer sees but
## not in front of it; its top is new ground for what grows on rock (st.pick takes from it too, its own normals)
const HUG_P := 0.4
func _hug_rock(rk: MeshInstance3D, c: MeshInstance3D, st: Dictionary, rtype: String, hr: Rng32) -> void:
	if not (rk and c and c.has_meta("geo")): return
	var cg: Geo = c.get_meta("geo")
	var cb := cg.aabb()
	var cs := c.transform.basis.get_scale().x
	var up := c.transform.basis.y.normalized()
	var foot := c.transform * Vector3(cb.get_center().x, cb.position.y, cb.get_center().z)
	var ln := cb.size.y * cs
	var cr := maxf(cb.size.x, cb.size.z) * 0.5 * cs
	# (a long crystal only: on a squat point the climb came out a flat slab wider than the crystal, hanging over the rock)
	if ln < cr * 2.6: return
	# a side of it, turned 50-110 degrees off the line of sight, left or right
	var side := VIEW_DIR.rotated(UP, deg_to_rad(50.0 + hr.next() * 60.0) * (1.0 if hr.next() < 0.5 else -1.0))
	side = (side - up * side.dot(up)).normalized()
	var R := RockKit.rock(hr, rtype, "chunk", 28, 0.0)
	var g: Geo = R.geo
	var gb := g.aabb()
	var hh := ln * (0.42 + hr.next() * 0.2)
	var ww := minf(cr * (2.4 + hr.next() * 0.8), hh * 1.1)
	# (one piece with the rock under it, not a lump stuck on: its foot wide and sunk deep into the rock below, spreading
	# over it; up the crystal it narrows and leans in onto the crystal's side, as a crust that grew round it does)
	var c0 := foot + side * cr * (0.75 + hr.next() * 0.2) - up * hh * 0.25
	var turn := Basis(UP, hr.next() * TAU)
	for i in g.v.size():
		var q := g.v[i] - gb.get_center()
		var ly := (q.y - (gb.position.y - gb.get_center().y)) / maxf(gb.size.y, 0.01)   # 0 at its foot .. 1 at its top
		var w := turn * Vector3(q.x / maxf(gb.size.x, 0.01) * ww, 0.0, q.z / maxf(gb.size.z, 0.01) * ww * 0.85)
		var t := clampf(ly, 0.0, 1.0)
		w *= lerpf(1.3, 0.42, pow(t, 0.9))
		w = w - up * up.dot(w)
		var p := c0 + w + up * (ly * hh * 1.25) - side * cr * 0.75 * t * t
		g.v[i] = p
	var mi := U.mesh(g, rk.material_override, root)
	mi.set_meta("gene", "rock")   # (not one of the genes that grow on it: _tag, SpecSolid leave it be)
	var pts := RockKit.surf_pts(mi, 140, hr, func(_p: Vector3, nn: Vector3) -> bool: return nn.y > 0.2, root)
	if pts.is_empty(): return
	var hn := {}
	for q: Array in pts: hn[q[0]] = q[1]
	var raw_pick: Callable = st.pick
	var raw_nrm: Callable = st.nrm
	var pr := Rng32.new(int(hr.next() * 100000))
	st.pick = func() -> Vector3:
		if pr.next() < 0.4: return pts[int(pr.next() * pts.size()) % pts.size()][0]
		return raw_pick.call()
	st.nrm = func(w: Vector3) -> Vector3: return hn[w] if hn.has(w) else raw_nrm.call(w)

## a lone crystal wider than the rock it stands on (it read as stuck on a pebble, and nothing that grows on rock had
## room: a mushroom shrank to a speck): the rock grows out sideways, not up — the crystal's foot stays where it is —
## till it is wider than the foot by a margin; the spots on it for what grows there move with it
const FOOT_MARGIN := 1.35
static var widened := 0.0   # (the last find's factor, for tests)
func _widen_rock(rk: MeshInstance3D, c: MeshInstance3D, st: Dictionary) -> void:
	widened = 1.0
	if not (rk and c and rk.has_meta("geo") and c.has_meta("geo")): return
	var cg: Geo = c.get_meta("geo")
	var cb := cg.aabb()
	var foot := 0.0
	for v in cg.v:
		if v.y > cb.position.y + cb.size.y * 0.3: continue
		var w := c.transform * v
		foot = maxf(foot, Vector2(w.x, w.z).length())
	var rg: Geo = rk.get_meta("geo")
	var rb := rg.aabb()
	var half := minf(rb.size.x, rb.size.z) * 0.5
	if half <= 0.0 or foot * FOOT_MARGIN <= half: return
	var k := minf(foot * FOOT_MARGIN / half, 2.2)
	widened = k
	rg.scale(k, 1.0, k)
	if rk.mesh: rk.mesh = rg.to_mesh()
	var raw_pick: Callable = st.pick
	var raw_nrm: Callable = st.nrm
	st.pick = func() -> Vector3:
		var q: Vector3 = raw_pick.call()
		return Vector3(q.x * k, q.y, q.z * k)
	st.nrm = func(w: Vector3) -> Vector3:
		var n: Vector3 = raw_nrm.call(Vector3(w.x / k, w.y, w.z / k))
		return Vector3(n.x / k, n.y, n.z / k).normalized()
	st.hollows = (st.hollows as Array).map(func(h: Array) -> Array:
		var q: Vector3 = h[0]
		var n: Vector3 = h[1]
		return [Vector3(q.x * k, q.y, q.z * k), Vector3(n.x / k, n.y, n.z / k).normalized()])

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
	_tag(id)

## what was built since the last tag is this gene's, near enough (a gene marks itself as it grows): SpecSolid.clear
## and tests/overlap_audit tell the things on a find apart by it
func _tag(id: String) -> void:
	for c in root.get_children():
		if not c.has_meta("gene"): c.set_meta("gene", id)

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

## a spot high on a crystal's face that looks at the viewer — above the rock's crust at its foot (atypical habit:
## the point went anywhere above a third of the height and often sat in the crust or behind the crystal). Draws the
## same random numbers as _mark_on, so the other callouts stay where they were
func _mark_face(id: String, m: Node3D) -> void:
	_mark_on(id, m)
	if not (m and m.has_meta("geo")):
		return
	var g: Geo = m.get_meta("geo")
	var bb := g.aabb()
	var xf := U.rel_xform(m, root)
	var best := -INF
	var bp := Vector3.ZERO
	var bn := Vector3.ZERO
	for i in g.tri_count():
		var t := g.tri(i)
		var c: Vector3 = (t[0] + t[1] + t[2]) / 3.0
		var f := (c.y - bb.position.y) / maxf(bb.size.y, 0.001)
		if f < 0.55 or f > 0.92: continue
		var nw: Vector3 = (xf.basis * (t[1] - t[0]).cross(t[2] - t[0])).normalized()
		var k := nw.dot(VIEW_DIR) + f * 0.6
		if k > best:
			best = k
			bp = xf * c
			bn = nw
	if best > -INF:
		grown[id] = [[bp, bn]]

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
		c.set_meta("crystal", true)
	# (the body — rock and crystals — is there by now: what comes after is some gene's, see _mark)
	for c in root.get_children():
		if not c.has_meta("gene"): c.set_meta("gene", "body")
	return out

## a spot on the rock with no crystal over it
## other things lying on the rock that nothing may grow through (hyalite's drops, opal patches, millerite's sprays,
## wavellite's stars, wire silver, a jade sunk in it): [centre, radius] in root space
var keep_out := []

## pad: this much room round p as well (a plant's leaves and caps spread past its foot)
func _free(p: Vector3, pad := 0.0) -> bool:
	for ko: Array in keep_out:
		if p.distance_to(ko[0]) < float(ko[1]) + pad:
			return false
	# (asked tens of thousands of times a stone: each box's ball in root space is tried first - a point outside it
	# is outside the box - and the boxes are kept as plain lists beside `boxes`)
	if _fb_n != boxes.size() or not is_same(_fb_of, boxes):
		_fb_of = boxes
		_fb_n = boxes.size()
		_fb_inv.clear()
		_fb_bb.clear()
		_fb_c.resize(_fb_n)
		_fb_r.resize(_fb_n)
		for i in _fb_n:
			var bd: Dictionary = boxes[i]
			var bb: AABB = bd.bounds
			var inv: Transform3D = bd.inverse
			var fw := inv.affine_inverse()
			_fb_inv.append(inv)
			_fb_bb.append(bb)
			_fb_c[i] = fw * bb.get_center()
			var sc := fw.basis.get_scale()
			_fb_r[i] = bb.size.length() * 0.5 * maxf(sc.x, maxf(sc.y, sc.z)) * 1.01 + 1e-4
	for i in _fb_n:
		if p.distance_to(_fb_c[i]) > _fb_r[i]: continue
		if _fb_bb[i].has_point(_fb_inv[i] * p):
			return false
	return true

var _fb_of: Array
var _fb_n := -1
var _fb_inv: Array[Transform3D] = []
var _fb_bb: Array[AABB] = []
var _fb_c := PackedVector3Array()
var _fb_r := PackedFloat32Array()

var st_ref := {}
var hurt := {}   # the find's damage from a careless dig (zcfg.dmg), for the lumps that are no crystals (_shatter)
var seed0 := 1
var _lumpy_d := {}

## (16.11) malachite's own surface, whole as it is: lopsided, bumped and dented — what a chipped lump (RockKit.chip at
## the strength of a Damaged find) looked like, which the user found the truer malachite; its own stream
static var no_lumpy := false   # (tests/shatter_check: the whole lump without its dents and chips)
func _lumpy() -> Dictionary:
	if no_lumpy: return {}
	if _lumpy_d.is_empty():
		_lumpy_d = {k = 0.78, rng = Rng32.new((seed0 * 3266489917 + 101) % 4294967296)}
	return _lumpy_d

func _rot_inst(p: Vector3, e: Vector3, sc: Vector3) -> Transform3D:
	return Transform3D(U.eul(e.x, e.y, e.z) * Basis.from_scale(sc), p)

func _specimen(o: Dictionary) -> Node3D:
	var seed_v: int = int(o.get("seed", 1))
	if seed_v == 0: seed_v = 1
	seed0 = seed_v
	rng = Rng32.new((seed_v * 2654435761) % 4294967296)
	var sid: String = o.get("sid", "quartz")
	_sid = sid
	var sp: Dictionary = Data.SP.get(sid, Data.SP.quartz)
	var habit: String = Data.HABIT.get(sid, "prism")
	var tr: Array = o.get("traits", [])
	# (a trait the species never takes now is not drawn on a stone that rolled it before: fluorite's rainbow film,
	# an opal's phantom — a low-poly ball in the opal, 20.11)
	var nv := SpecLooks.never(sid)
	if tr.any(func(t: String) -> bool: return t in nv):
		tr = tr.filter(func(t: String) -> bool: return not t in nv)
	var gi: int = int(o.get("gi", 1))
	trs = tr
	var legend: bool = o.get("legend", false)
	keep_out = []
	root = Node3D.new()
	var col := SpecMat.lin_s(sp.c)
	col = SpecMat.offset_hsl(col, (rng.next() - 0.5) * 0.03, (rng.next() - 0.5) * 0.15, (rng.next() - 0.5) * 0.06)
	if gi < 2 and not SpecLooks.of(sid).get("keep_col", false):
		col = col.lerp(SpecMat.lin(0xb8b4ac), 0.25 - gi * 0.1)
	var gene := SpecGenome.of(o)
	gene_m = gene
	# an atypical find may grow another crystal than its species (SpecLooks.odd: apatite as a barrel)
	habit = String(gene.get("habit", habit))
	# the traits the species always has (amethyst and fluorite are zoned): its look, on top of what it rolled
	var look := SpecLooks.shape_of(sid, String(gene.get("pseudo", "")))
	# the species' own colours (fluorite: green, purple, blue, yellow, colourless, pink), picked on their own stream
	var core_hex := int((look.get("core", [0]) as Array)[0])
	if look.has("palette"):
		var pal: Array = look.palette
		var pe: Array = Stones.pick_w(pal.map(func(e: Array) -> Array: return [e, e[2]]), Rng32.new((seed_v * 1597334677 + 31) % 4294967296))
		col = SpecMat.lin(int(pe[0]))
		# a poorer stone is duller, not paler: a grey as bright as its own colour (a light grey turned ruby jack pink)
		if gi < 2:
			var lum := col.r * 0.3 + col.g * 0.55 + col.b * 0.15
			col = col.lerp(Color(lum, lum, lum), 0.2 - gi * 0.08)
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
	var metal := habit == "nugget" or sid in ["pyrite", "hematite"] or look.has("metal_col")
	var cut: String = o.get("cut", "")
	# a cut stone floats alone, tilted to show its table and pavilion
	if cut != "" and cut != "broken":
		var gm := SpecMat.make({col = col, flat = cut != "cab", glass = true, thick = 1.6, rf = 1.0, ir = 0.45 if cut == "master" else 0.2, seed = float(seed_v % 97), prio = 2})
		U.mesh(RockKit.gem(cut), gm, root, Vector3.ZERO, U.eul(-0.9 if cut == "cab" else PI - 0.55, 0, 0.15))
		return root

	# colour zoning along the crystals
	var zone := 1.0 if "zoned" in tr else 0.45 if rng.next() < 0.35 else 0.0
	var zmode := int(floor(rng.next() * 3))
	# (not on metal: its colour shifted half round the wheel turned brassy pyrite into a pale blue mirror that read as
	# glass on the phone, its pale root into silver — the draws stay, so nothing else of the stone moves)
	if metal: zone = 0.0
	var zhue := 0.45
	# (SpecLooks zmodes: which of the zonings a species may take — aquamarine's colour shifted half round the wheel went
	# pink and orange and read as rainbow quartz; it zones colourless to blue only. The draw stays, so nothing else moves)
	if look.has("zmodes"):
		var zms: Array = look.zmodes
		zmode = int(zms[zmode % zms.size()])
	if look.has("zone"):
		var zl: Array = look.zone
		zmode = int(zl[0])
		zone = float(zl[1])
		zhue = float(zl[2])
	# (SpecLooks zone_pal — fluorite: no zoning by chance; zoned, it bands in its own two colours, root the core's)
	if look.get("zone_pal", false):
		zone = 0.9 if "zoned" in tr else 0.0
		zmode = 3
	var cA := col
	if zmode == 3 and zone > 0.0: cA = SpecMat.lin(core_hex)
	elif zone > 0.0:
		cA = Color(1, 1, 1).lerp(col, 0.25) if zmode == 0 else col * 0.45 if zmode == 1 else SpecMat.offset_hsl(col, zhue, 0, 0)
	var cB := col
	# with the species' proportions (SpecLooks: hk, wk, blunt), which every crystal and column takes
	var zcfg := {cA = cA if zone > 0.0 else col, cB = cB, zk = zone, hk = float(look.get("hk", 1.0)), wk = float(look.get("wk", 1.0)),
		blunt = bool(look.get("blunt", false)), saddle = float(look.get("saddle", 0.0)), rh = float(look.get("rh", 0.3)), steps = bool(look.get("steps", false)),
		bend = float(look.get("bend", 0.0))}
	# dug out carelessly (BoardModel.find.integ: blasts chip the stone): its crystals pitted, tips knocked off, some
	# snapped to stumps (RockKit.damage) - on their own stream, so a damaged stone is the same stone, hurt
	var dk := damage_of(int(o.get("integ", 100)))
	# (a lone crystal is never snapped to a stump - the find would be gone with it; nor a group's first, its main one)
	if dk > 0.0: zcfg.dmg = {k = dk, rng = Rng32.new((seed_v * 2246822519 + 7) % 4294967296), n = 0, stumps = not String(gene.form) in ["single", "floater", "columnar"]}
	# (the lumps that are no crystals — a vein's quartz, a nugget, malachite — take it too: RockKit.chip)
	hurt = zcfg.get("dmg", {})
	dt = {h = -99.0, a = 0.4, col = Color(0.1, 0.1, 0.1), fr = 0.7 if rng.next() < 0.5 else 0.0, local = false}
	var limonite := "limonite" in tr and not "limonite" in (gene.lost as Array)   # (not on ironstone: unseen — SpecGenome)
	var kind: String = o.get("kind", "crystal")
	var elongated := habit in ["prism", "blade", "barrel", "scaleno"]
	var needs_rock := "moss" in tr or "coral" in tr
	var layout: String = gene.form
	var rtype: String = gene.rock
	var gs: float = gene.scale
	var ero := 0.0   # (the etched trait is gone: what etching there is now is the damage of a careless dig, zcfg.dmg)
	var scan: int = RockKit.SCAN_OF[rtype]
	dt.scan = scan
	# a species whose crystals do not frost over at the foot (SpecLooks foot_frost false)
	if not look.get("foot_frost", true):
		dt.fr = 0.0
		dt.fb = 0.0

	var st := {rocky = false, pick = func() -> Vector3: return Vector3.ZERO, nrm = func(v: Vector3) -> Vector3: return v.normalized(), rock = null, irk = irk,
		detail = 2 if layout in ["single", "columnar", "floater"] else 0 if layout == "geode" else 1, hollows = [], agate = look.get("agate", [])}
	st_ref = st
	var stria := 1.0 if elongated else 0.0
	# the species' own striations (SpecLooks stria: [strength, mode]) — across quartz, along the beryls, crossed on pyrite
	var st_mode := 0.0
	if look.has("stria"):
		stria = float(look.stria[0])
		st_mode = float(look.stria[1])
	var cmat_spec := func() -> Dictionary:
		var irk2: float = st.irk
		if metal:
			# brassy metal crystals: striated faces, a rainbow tarnish here and there, sunk into the rock
			# (hematite: dark steel — SpecLooks metal_col)
			if look.has("metal_col"):
				# hematite's steel: darker, less mirror, its tarnish a rainbow in patches
				return {col = SpecMat.lin(int(look.metal_col)), metal = 0.95, rough = float(look.get("mrough", 0.3)), coat = 0.6, coat_r = 0.08, flat = true, env = float(look.get("menv", 2.6)), oil = float(look.get("tarnish", 0.5)), peacock = float(look.get("peacock", 0.0)) * (0.55 + 0.9 * fposmod(float(seed_v) * 0.6180339, 1.0)), ir = float(look.get("tarnish", 0.0)) * 0.2, st = stria if look.has("stria") else 0.4, st_mode = st_mode, dirt = dt, prio = 2}
			return {col = Color(1, 1, 1), metal = 0.95, rough = 0.2, coat = 0.6, flat = true, env = 1.6, oil = 0.35, st = stria if look.has("stria") else 1.0, st_mode = st_mode, dirt = dt, prio = 2}
		var op := 0.36 + (0.14 if gi < 2 else 0.0) if layout == "columnar" or layout == "cluster" else 0.8 if habit == "octa" or habit == "dodeca" else maxf(0.5, 0.82 - gi * 0.07)
		# an opaque species (SpecLooks opaque: aragonite's wax, realgar's resin): no glass, a lit surface of its colour
		if look.has("opaque"):
			var oq: Dictionary = look.opaque
			return {col = Color(1, 1, 1), rough = float(oq.get("rough", 0.35)), coat = float(oq.get("coat", 0.4)), coat_r = 0.15, flat = true, st = stria, st_mode = st_mode,
				dirt = dt, prio = 2, env = 1.3, grain = float(oq.get("grain", 0.1)), lava = 1.0 if gene.fx == "lava" else 0.0,
				bd = float(oq.get("bd", 0.0)), ir = maxf(float(oq.get("ir", 0.0)), irk2 * 0.3 if irk2 >= 1.0 else 0.0), emis = col * float(oq.get("glow", 0.0))}
		# (SpecLooks ir: how much rainbow film and sheen the species takes — none on realgar's red or aragonite's milk)
		var irm := float(look.get("ir", 1.0))
		var d := {col = Color(1, 1, 1), flat = true, glass = true, ir = irk2 * 0.5 * irm, rf = 0.3, st = stria, st_mode = st_mode, dirt = dt, prio = 2,
			holo = float(gene.holo) * irm, emis = col * 0.35 if gene.anomaly else Color(0, 0, 0),
			lava = 1.0 if gene.fx == "lava" else 0.0,
			frost = float((look.get("glass", {}) as Dictionary).get("frost", 0.85 - gi * 0.3 if gi < 2 else 0.1 + rng.next() * 0.25)), thick = 1.0 + op * 0.4, seed = float(seed_v % 97),
			dark_body = float((look.get("glass", {}) as Dictionary).get("dark", 0.0)), tint_body = float((look.get("glass", {}) as Dictionary).get("tint", 0.0)),
			tint_glow = float((look.get("glass", {}) as Dictionary).get("glow", 0.06)), deep_body = float((look.get("glass", {}) as Dictionary).get("deep", 0.0))}
		if float((look.get("glass", {}) as Dictionary).get("opal", 0.0)) > 0.0: d.opal = float(look.glass.opal)
		# clarity by parts (docs/showy-minerals.md): every plain clear species has it — a cloudy root, a gem tip, one
		# crystal milkier than the next; a species says otherwise with glass.parts. Not where the body has a colour or
		# a darkness of its own (garnet, sulphur, smoky: their cloud would be a white patch), nor under a living effect
		var gl: Dictionary = look.get("glass", {})
		var plain: bool = float(gl.get("tint", 0.0)) <= 0.0 and float(gl.get("dark", 0.0)) <= 0.3 and float(gl.get("opal", 0.0)) <= 0.0 and String(gene.fx) == ""
		var pk := float(gl.get("parts", PARTS_K if plain else 0.0))
		if pk > 0.0: d.parts = pk
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
		mi.set_meta("base", R.base)
		dt.col = R.base
		var top: Array = R.top
		st.hollows = R.hollows
		if loose > 0.0:
			_crumbs(rm, top, R.scale, loose)
		var sc: Vector3 = R.scale
		st.pick = func() -> Vector3: return top[int(floor(rng.next() * top.size()))] if top.size() else Vector3(0, 0.3, 0)
		st.nrm = func(w: Vector3) -> Vector3: return RockKit.rock_nrm(sc, w)
		st.rock = mi
		st.rock_geo = R.geo
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
		var g := RockKit.crystal(String(extra.get("habit", habit)), rng, cfg)
		var c := U.mesh(g, mo if mo else any_cmat.call(), parent if parent else root)
		_place(c, at, dir, s * gs, rng.next() * 6.28)
		return c
	var lean := func(d: Vector3, a: float) -> Vector3:
		return (d + Vector3((rng.next() - 0.5) * a, 0, (rng.next() - 0.5) * a)).normalized()

	# what the showy minerals' own layouts (SpecForms) need of all this
	var sf := {st = st, col = col, gs = gs, look = look, zcfg = zcfg, kind = kind, gene = gene, ero = ero, seed = seed_v, sid = sid,
		use_rock = use_rock, any_cmat = any_cmat, cmat_spec = cmat_spec, make_cmat = make_cmat, crystal = crystal, lean = lean}
	match layout:
		"tablets": main = SpecForms.tablets(self, sf)
		"barrels": main = SpecForms.barrels(self, sf)
		"jackstraw": main = SpecForms.jackstraw(self, sf)
		"balls": main = SpecForms.balls(self, sf)
		"fans": main = SpecForms.fans(self, sf)
		"staircase": main = SpecForms.staircase(self, sf)
		"pencils": main = SpecForms.pencils(self, sf)
		"slice": main = SpecForms.slice(self, sf)
		"grapes": main = SpecForms.grapes(self, sf)
		"ammonite":
			main = SpecFossil.ammonite(self, gene, use_rock)
		"petrified_wood":
			main = SpecWood.build(self, gene)
		"fulgurite":
			main = SpecFulgurite.build(self, gene)
		"fern":
			main = SpecFern.build(self, gene, use_rock, st)
		"flower_quartz", "amber", "simetite":
			main = SpecFlower.build(self, gene)
		"trilobite":
			main = SpecTrilobite.build(self, gene, use_rock)
		"skull":
			# the skull's crystals: the druse's pointed columns (or the species' own crystal), f = 0..1 how big
			# the skull's own say on its crystals: clear glass as the species has it, or cloudy and matte
			# (frost: milky glass glowing in its colour; wax: opaque, soft, like resin or jade)
			var skg := SpecSkull.genes(int(gene.shroom_seed), gene.get("skull", {}))
			var cd: Dictionary = cmat_spec.call()
			# (a dark stone — morion, smoky, cinnabar — keeps its colour: cloudy, not milky white)
			var dark_sp := float(cd.get("dark_body", 0.0)) > 0.0 or col.get_luminance() < 0.2
			if skg.milk == "frost" and cd.get("glass", false):
				if dark_sp:
					# a dark stone only loses its rainbow and goes a little silky: milk would whiten it
					cd.merge({ir = 0.0, holo = 0.0, frost = 0.15}, true)
				else:
					cd.merge({frost = 1.0, ir = 0.0, holo = 0.0, rf = 0.0, thick = 2.0, tint_body = 0.9, tint_glow = 0.35}, true)
			elif skg.milk == "wax" and dark_sp and not metal:
				cd = {col = col * 1.4, rough = 0.38, coat = 0.35, coat_r = 0.2, flat = true, st = 0.3, dirt = dt, prio = 2, env = 0.9, grain = 0.12}
			elif skg.milk == "wax" and not metal:
				cd = {col = Color(1, 1, 1).lerp(col / maxf(0.001, maxf(col.r, maxf(col.g, col.b))), 0.75), rough = 0.42, coat = 0.3, coat_r = 0.25, flat = true, st = 0.3, dirt = dt, prio = 2, env = 0.9, grain = 0.12, emis = col * 0.14}
			var cmk: ShaderMaterial = make_cmat.call(cd)
			# (always pointed: a beryl's blunt end read as a stub of glass out of the bone)
			var zsk := zcfg.duplicate()
			zsk.blunt = false
			# (k: a size multiplier — the teeth's crystals are tiny)
			var grow := func(f: float, at: Vector3, dir: Vector3, k := 1.0) -> MeshInstance3D:
				var c: MeshInstance3D
				if elongated:
					var w := (0.018 + f * 0.12) * gs * k
					var g := RockKit.prism(rng, {sides = 6, w = w, d = w * (0.75 + rng.next() * 0.35), h = w * (2.2 + rng.next() * 1.8), point = true, slope = 0.0,
						y0 = -minf(w * 0.3, 0.035), detail = 1, erode = ero * 0.7}, zsk)   # (shallow: the skull is a shell, a deep foot shows inside the eyes)
					c = U.mesh(g, cmk, root)
					_place(c, at, dir, 1.0, rng.next() * 6.28)
					c.set_meta("col", true)
				else:
					c = crystal.call(0.3 + f * 0.6, (0.25 + f * 0.5) * k, at, dir)
				c.set_meta("local", true)
				return c
			main = SpecSkull.build(self, gene, st, rock_mat, grow, lean, use_rock)
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
			# (aragonite: fewer, longer, pointed — a spray of crystals catching the light, not a lump of facets)
			var nn := 90 + int(rng.next() * 40) if habit != "prism" else 70 + int(rng.next() * 30)
			for k in nn:
				var u := Vector3(rng.next() - 0.5, rng.next() * 0.9 - 0.15, rng.next() - 0.5).normalized()
				var p: Vector3 = mid + Vector3(u.x * 0.55, u.y * 0.4, u.z * 0.5) * gs * (0.5 + rng.next() * 0.45 if habit != "prism" else 0.3 + rng.next() * 0.2)
				gaps.append([p, u])
				var dir := (u + _rv() * 0.5).normalized()
				var w := (0.05 + pow(rng.next(), 1.3) * 0.06) * gs * (0.9 if habit == "prism" else 1.0)
				var h := w * ((2.6 + rng.next() * 2.4) if habit == "prism" else (1.4 + rng.next() * 1.6))
				var c: MeshInstance3D
				if habit == "prism":
					var g := RockKit.prism(rng, {sides = 6, w = w, d = w * (0.85 + rng.next() * 0.2), h = h, point = true, taper = 0.9, y0 = -w * 1.2, detail = 1, erode = ero * 0.5}, zcfg)
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
					# (19.11) hurt by the dig: each plate pitted, a piece of its rim knocked off — no tip to lose
					g.fill_color(Color(1, 1, 1))
					if zcfg.has("dmg"):
						var d2: Dictionary = (zcfg.dmg as Dictionary).duplicate()
						d2.flat = true
						RockKit.damage(g.subdivide(1), d2)
						zcfg.dmg.n = d2.n
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
			# (peridot: the grains glassy and bright, lime to bottle-green, a few honey and black)
			var cols := [SpecMat.lin(0x8cc020), SpecMat.lin(0x5e9a18), SpecMat.lin(0xb4c830), SpecMat.lin(0x3c6a12), SpecMat.lin(0xc0a030), SpecMat.lin(0x6a4a16), SpecMat.lin(0x0e0e0c)]
			var nod := Geo.new()
			var R := (0.32 + rng.next() * 0.1) * gs
			# the rock round the nest: each grain is dropped onto it along the ray from the middle (on a flat disc the
			# edge grains hung in the air over the lump's curve)
			var near := []
			for v: Vector3 in (st.rock_geo as Geo).v:
				if v.distance_to(c0) < R * 1.8 + 0.05: near.append(v)
			var on_rock := func(p: Vector3) -> Vector3:
				var d := p.normalized()
				var best := [-2.0, -2.0, -2.0]
				var rad := [0.0, 0.0, 0.0]
				for v: Vector3 in near:
					var c := v.normalized().dot(d)
					if c > best[2]:
						var j := 2
						while j > 0 and c > (best[j - 1] as float):
							best[j] = best[j - 1]
							rad[j] = rad[j - 1]
							j -= 1
						best[j] = c
						rad[j] = v.length()
				return d * (((rad[0] as float) + (rad[1] as float) + (rad[2] as float)) / 3.0) if near.size() > 2 else p
			for k in 300 + int(rng.next() * 80):
				var a := rng.next() * TAU
				var rr := sqrt(rng.next()) * R
				var s := (0.024 + rng.next() * 0.03) * gs
				var g := Geo.icosa(s, 0).to_soup()
				var sq := Vector3(1.0 + rng.next() * 0.3, 0.85 + rng.next() * 0.3, 1.0 + rng.next() * 0.2)
				var bs := Basis(U.eul(rng.next() * 6, rng.next() * 6, rng.next() * 6))
				var dome := sqrt(maxf(0.0, 1.0 - (rr / R) * (rr / R))) * R * 0.35
				# (packed: the nest's floor is grains too, no rock showing through)
				# a broken-open nest: the grains lie a little sunk in the face of the break
				var at: Vector3 = on_rock.call(c0 + (t1 * cos(a) + t2 * sin(a)) * rr) + n0 * (dome * 0.7 + R * 0.05 - s * 0.3)
				var cc: Color = (cols[int(Stones.pick_w([[0, 4.0], [1, 3.0], [2, 2.0], [3, 1.5], [4, 0.8], [5, 0.4], [6, 0.6]], rng))] as Color) * (0.35 + rng.next() * 0.3)
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
		"septaria":
			main = _septaria(crystal, st)
		"botryoid":
			# the lumpy species each grow their own way (docs/species-genes.md F11–F15); the rest keep the bubbly lump
			var look_b := SpecLooks.of(sid)
			if sid == "jadeite": main = _jade(col, use_rock, st, gs)
			elif sid == "carnelian": main = _pebble(sid, col, look_b.get("opaque", {}))
			elif sid == "flintstone": main = _flint(col, crystal, st)
			elif sid == "hyalite": main = _beads(col, use_rock, st, gs)
			elif sid == "opal": main = _opal_seam(col, use_rock, st, gs, seed_v)
			# malachite's crust grown over a piece of its rock — the commonest way it is found (on its own stream)
			elif sid == "malachite" and Rng32.new((seed_v * 1597334677 + 91) % 4294967296).next() < 0.35: main = _mal_crust(col, irk, use_rock, st)
			else: _botryoid(sid, col, irk)
		"single":
			var srk: MeshInstance3D = use_rock.call("small" if rng.next() < 0.6 else "chunk")
			var at := Vector3((rng.next() - 0.5) * 0.15, 0.22 if elongated else 0.1, (rng.next() - 0.5) * 0.15)
			var mh := 1.15 + rng.next() * 0.5
			var ms := 1.2 + rng.next() * 0.3
			main = crystal.call(mh, ms, at, lean.call(UP, 0.35), {scepter = "scepter" in tr})
			_widen_rock(srk, main, st)
			# now and then the rock climbs one side of it: the crystal half sunk in it, as it grew (its own stream)
			var hug_r := Rng32.new((seed_v * 1812433253 + 97) % 4294967296)
			if hug_r.next() < HUG_P: _hug_rock(srk, main, st, rtype, hug_r)
			dt.h = at.y + 0.1 + rng.next() * 0.25
			dt.a = 0.35
			for k in int(floor(rng.next() * 3)):
				# (14.11) a small one beside it grows out of the rock, its foot sunk in: on a spot that looks up (on a steep
				# side, tilted towards the sky, its foot stood in the air), and pushed down its own axis a third of its length
				var p: Vector3 = st.pick.call()
				var ok := false
				for tries in 16:
					if (st.nrm.call(p) as Vector3).y > 0.55:
						ok = true
						break
					p = st.pick.call()
				var sh := 0.45 + rng.next() * 0.5
				var ss := 0.5 + rng.next() * 0.4
				var sd: Vector3 = lean.call((st.nrm.call(p) as Vector3).lerp(UP, 0.5), 0.6)
				# (no spot looking up: none, rather than one hanging off the side)
				if ok: crystal.call(sh, ss, p - sd * sh * ss * gs * 0.32, sd)
			if sid == "japan_quartz":
				# the Japan-law twin (F7): two flattened crystals joined at their feet at 84°, a heart turned to the
				# viewer — the first crystal swung over into the twin's left arm
				var zv := (VIEW_DIR + Vector3((rng.next() - 0.5) * 0.3, 0.1, 0)).normalized()
				var arms: Array[MeshInstance3D] = [main, crystal.call(1.0 + rng.next() * 0.25, 1.15, at, UP)]
				var tilt := deg_to_rad(42.3) + (rng.next() - 0.5) * 0.06
				for ai in 2:
					var sgn := -1.0 if ai == 0 else 1.0
					var yv := (Basis(zv, sgn * tilt) * UP).normalized()
					var xv := yv.cross(zv).normalized()
					var s := arms[ai].transform.basis.get_scale().y
					arms[ai].transform = Transform3D(Basis(xv, yv, xv.cross(yv)) * Basis.from_scale(Vector3(s * 1.3, s, s * 0.5)), at)
				_mark("twin", _mid(arms[1], 0.6))
			elif "twin" in tr and habit == "cube":
				# (15.11) a cube's penetration twin, as fluorite's: a second cube of the same size through the first, turned
				# 60° about their shared body diagonal — its corners stand out of every face. (The prism's way below — a
				# second crystal at the foot, leaning — left a cube's twin all but hidden inside the first: "twin" on the
				# card, nothing to see)
				var t: MeshInstance3D = crystal.call(mh, ms, at, UP)
				var bb := (main.get_meta("geo") as Geo).aabb()
				var cc := bb.get_center()
				var ax := (bb.end - cc).normalized()
				var rb := Basis(ax, deg_to_rad(60.0))
				t.transform = main.transform * Transform3D(rb, cc - rb * cc)
				# the callout on the corner standing out highest towards the viewer (not those on the shared diagonal)
				var to_root := U.rel_xform(main, root)
				var best_p := _mid(t, 0.7)
				var best_k := -INF
				for ci in 8:
					var corner := bb.position + bb.size * Vector3(ci & 1, (ci >> 1) & 1, (ci >> 2) & 1)
					var d := corner - cc
					if d.normalized().cross(ax).length() < 0.2: continue
					var q := to_root * (rb * d + cc)
					var k := q.y + q.dot(VIEW_DIR) * 0.5
					if k > best_k:
						best_k = k
						best_p = q
				_mark("twin", best_p)
			elif "twin" in tr:
				var t: MeshInstance3D = crystal.call(1.0 + rng.next() * 0.4, 1.05, at, lean.call(Vector3(0.8, 1, 0.3), 0.3))
				t.rotate_object_local(Vector3.BACK, 0.6)
				_mark("twin", _mid(t, 0.7))
		"hair":
			# millerite (F8): brassy hairs in sprays out of the rock, fine as a brush, catching the light one by one
			main = use_rock.call("chunk")
			var hm: ShaderMaterial = any_cmat.call()
			var hairs := []
			for spr in 2 + int(rng.next() * 3):
				var p: Vector3 = st.pick.call()
				for t in 8:
					var q: Vector3 = st.pick.call()
					if (st.nrm.call(q) as Vector3).dot(VIEW_DIR) + q.y > (st.nrm.call(p) as Vector3).dot(VIEW_DIR) + p.y: p = q
				var nn: Vector3 = st.nrm.call(p)
				keep_out.append([p, 0.16 * gs])
				var reach := 0.4 + rng.next() * 0.35
				for k in 50 + int(rng.next() * 70):
					var d := (nn + _rv() * 1.6).normalized()
					if d.dot(nn) < 0.15: d = (d + nn).normalized()
					var ln := (0.12 + pow(rng.next(), 0.7) * 0.42) * gs * reach
					# (19.11) hurt by the dig: hairs snapped short, more the worse it is
					if zcfg.has("dmg") and (zcfg.dmg.rng as Rng32).next() < float(zcfg.dmg.k) * 0.9: ln *= 0.08 + (zcfg.dmg.rng as Rng32).next() * 0.32
					var r := (0.0028 + rng.next() * 0.0022) * gs
					hairs.append(Transform3D(Basis(quat_to_l(UP, d)) * Basis.from_scale(Vector3(r, ln, r)), p - nn * 0.01))
			U.inst(Geo.cylinder(1.0, 0.35, 1.0, 5).translate(0, 0.5, 0), hm, hairs.size(), func(i: int) -> Array: return [hairs[i], Color(1, 1, 1)], root)
		"coxcomb":
			# marcasite's cockscomb (F5): thin blades grown side by side in a crest, fanned out, each facing its
			# neighbour, the middle ones tallest
			use_rock.call("slab")
			var xv := UP.cross(VIEW_DIR).normalized()
			for crest in 1 + int(rng.next() < 0.5):
				var c0: Vector3 = st.pick.call()
				for t in 10:
					var q: Vector3 = st.pick.call()
					if q.y - absf(q.dot(xv)) * 0.5 > c0.y - absf(c0.dot(xv)) * 0.5: c0 = q
				c0 += VIEW_DIR * (0.12 * gs * float(crest))
				var nb := 7 + int(rng.next() * 6)
				var fan := 0.8 + rng.next() * 0.5
				var span := (0.45 + rng.next() * 0.2) * gs
				for k in nb:
					var f := float(k) / float(nb - 1) - 0.5
					var at := c0 + xv * f * span
					var dv := (Basis(VIEW_DIR, -f * fan) * UP).normalized()
					var c: MeshInstance3D = crystal.call((0.55 + (1.0 - absf(f) * 2.0) * 0.4) * (0.85 + rng.next() * 0.3), 0.95, at, dv, {habit = "blade"})
					var s := c.transform.basis.get_scale().y
					var zt := (xv - dv * xv.dot(dv)).normalized()
					c.transform = Transform3D(Basis(dv.cross(zt), dv, zt) * Basis.from_scale(Vector3.ONE * s), at)
					if not main: main = c
		"starburst":
			# wavellite (F10): flat discs of radiating needles on the broken face of the slab — green stars
			use_rock.call("slab")
			# (silky fibres: lit, glossy, a little glow of their green — glass needles this thin read black)
			var cm := SpecMat.make({col = col, rough = 0.28, coat = 0.6, coat_r = 0.15, env = 1.4, emis = col * 0.32})
			var needles := []
			var nstar := 4 + int(rng.next() * 6)
			for sk in nstar:
				var p: Vector3 = st.pick.call()
				for t in 6:
					var q: Vector3 = st.pick.call()
					if (st.nrm.call(q) as Vector3).dot(VIEW_DIR) + q.y > (st.nrm.call(p) as Vector3).dot(VIEW_DIR) + p.y: p = q
				var nn: Vector3 = st.nrm.call(p)
				var t1 := nn.cross(UP if absf(nn.y) < 0.9 else Vector3.RIGHT).normalized()
				var t2 := nn.cross(t1)
				var R := (0.08 + rng.next() * 0.1) * gs
				keep_out.append([p, R * 1.15])
				var cnt := 34 + int(rng.next() * 24)
				for k in cnt:
					var a := (float(k) + rng.next() * 0.6) / float(cnt) * TAU
					var d := (t1 * cos(a) + t2 * sin(a) + nn * (0.08 + rng.next() * 0.12)).normalized()
					var ln := R * (0.75 + rng.next() * 0.25)
					var r := R * 0.045
					needles.append(Transform3D(Basis(quat_to_l(UP, d)) * Basis.from_scale(Vector3(r, ln, r)), p + nn * r))
			U.inst(Geo.cylinder(1.0, 0.25, 1.0, 6).translate(0, 0.5, 0).fill_color(col), cm, needles.size(), func(i: int) -> Array: return [needles[i], Color(1, 1, 1)], root)
		"sawn":
			# a stalactite or a crust sawn through and polished: its growth rings as eyes (rhodochrosite's rose bands)
			main = _sawn(sid, col)
		"gwindel":
			# smoky quartz's gwindel (F6): a row of flattened crystals side by side, each turned a little further
			# about the row than the last — a twisted plate, its face to the viewer
			var grk: MeshInstance3D = use_rock.call("small")
			var plates: Array[MeshInstance3D] = []
			var zv := VIEW_DIR
			var xv := UP.cross(zv).normalized()
			var nn := 5 + int(rng.next() * 4)
			var twist := 0.2 + rng.next() * 0.2
			var hh := 1.15 + rng.next() * 0.35
			var w0 := 0.11 * gs
			for k in nn:
				var f := float(k) / float(nn - 1) - 0.5
				var at := Vector3(0, 0.2, 0) + xv * f * w0 * float(nn) * 0.8
				var c: MeshInstance3D = crystal.call(hh * (1.0 - absf(f) * 0.35), 1.2, at, UP)
				var s := c.transform.basis.get_scale().y
				var yv := (Basis(xv, f * twist * 2.0) * UP).normalized()
				var z2 := xv.cross(yv).normalized()
				c.transform = Transform3D(Basis(xv, yv, z2) * Basis.from_scale(Vector3(s * 0.9, s, s * 0.45)), at)
				if k == nn / 2: main = c
				plates.append(c)
			# (smoky glass, not a rainbow: thin plates took the holographic sheen over)
			if main and main.material_override is ShaderMaterial:
				(main.material_override as ShaderMaterial).set_shader_parameter("holo_k", 0.0)
				(main.material_override as ShaderMaterial).set_shader_parameter("ir_k", 0.03)
			# the rock as wide as the row (an end plate's foot is the widest): on a small pebble the plate stood several
			# times wider than its ground
			if plates.size(): _widen_rock(grk, plates[plates.size() - 1], st)
			dt.h = 0.3
			dt.a = 0.35
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
				if cubic and look.get("steps", false):
					# galena: true cubes with stepped terraces, tumbled at any angle, a few stood on a corner
					var cs := (0.11 + f * 0.3) * gs
					c = U.mesh(RockKit.cube_steps(rng, cs), cm, root)
					_place(c, p, dir, 1.0, rng.next() * 6.28)
					if rng.next() < 0.25: c.rotate_object_local(Vector3(1, 0, 1).normalized(), 0.62)
					else: c.rotate_object_local(Vector3.RIGHT, (rng.next() - 0.5) * 0.7)
					c.set_meta("col", true)
				elif prismy:
					var w := (0.05 + f * 0.15) * (1.3 if cubic else 1.0) * gs
					var h := w * (1.3 + rng.next() * 0.7) if cubic else w * (3.0 + rng.next() * 3.5)
					var g := RockKit.prism(rng, {sides = sides, w = w, d = w * (0.6 if habit == "blade" else 0.75 + rng.next() * 0.35), h = h,
						point = not cubic and not look.get("flat_top", false) and rng.next() < 0.7, slope = 0.5 if rng.next() < (0.6 if look.get("flat_top", false) else 0.3) else 0.0, y0 = -w * 0.8, detail = 1, erode = ero * 0.7}, zcfg)
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
			var loose_m := U.mat_copy(cm)
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
				# (19.11) hurt by the dig: the side it struck crushed — its blades broken down short and some gone, the
				# sand between them showing; here and there over the rest one snapped (the damage's own stream)
				var rdm: Dictionary = zcfg.get("dmg", {})
				var rk_d: float = rdm.get("k", 0.0)
				for ball: Array in balls:
					var c0: Vector3 = ball[0]
					var R: float = ball[1]
					var crush := Vector3.UP
					if rk_d > 0.0:
						var dr0: Rng32 = rdm.rng
						crush = (VIEW_DIR * 0.6 + UP * 0.5 + Vector3(dr0.next() - 0.5, dr0.next() - 0.5, dr0.next() - 0.5) * 1.2).normalized()
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
						if rk_d > 0.0:
							var dr1: Rng32 = rdm.rng
							# (a patch, not a side: a whole side crushed bared the sand ball under it, a faceted sphere)
							if u.dot(crush) > 0.93 - rk_d * 0.3:
								if dr1.next() < 0.15: continue
								pr *= 0.45 + dr1.next() * 0.3
								at = c0 + u * R * (0.5 + dr1.next() * 0.2)
							elif dr1.next() < rk_d * 0.25:
								pr *= 0.5 + dr1.next() * 0.3
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
			var loose_m := U.mat_copy(cm)
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
				elif habit == "tetra": shape = -1.0
				hs *= float(zcfg.wk)
				if shape < 0.0: g = RockKit.tetra(hs * 1.9, 0.15 + rng.next() * 0.15)
				elif habit == "cube" and look.get("steps", false): g = RockKit.cube_steps(rng, hs * 2.0)
				elif shape > 0.92: g = Geo.icosa(hs * 1.1, 1).scale(1.0, 0.75 + rng.next() * 0.3, 0.9 + rng.next() * 0.2)
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
			# (19.11) hurt by the dig: twigs snapped off part way, and whatever grew past the break gone with them; the
			# broken end torn, not tapered (the damage's own stream)
			var tdm: Dictionary = zcfg.get("dmg", {})
			if float(tdm.get("k", 0.0)) > 0.0:
				var tr2: Rng32 = tdm.rng
				var kept := []
				for bi in sk.size():
					var br: Dictionary = sk[bi]
					if bi > 0:
						# (a branch grows from a point of one before it: still there, or it went with the break)
						var p0: Vector3 = (br.pts as Array)[0]
						var on := false
						for kb: Dictionary in kept:
							var kp: Array = kb.pts
							for qi in kp.size():
								if p0.distance_to(kp[qi]) < float((kb.rad as Array)[qi]) * 1.8 + 0.002:
									on = true
									break
							if on: break
						if not on: continue
						if dr_snap(tr2, float(tdm.k), int(br.depth)):
							var n0 := (br.pts as Array).size()
							var j := maxi(2, int(n0 * (0.15 + tr2.next() * 0.35)))
							br.pts = (br.pts as Array).slice(0, j)
							br.rad = (br.rad as Array).slice(0, j)
							br.snapped = true
					kept.append(br)
				sk.assign(kept)
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
	# acanthite's wire silver (F9): bright curls of native silver sprouting from the rock among the dark crystals
	if look.get("wire", false) and st.rocky:
		var wm := SpecMat.make({col = SpecMat.lin(0xdfe2e6), metal = 1.0, rough = 0.16, env = 2.6})
		for k in 3 + int(rng.next() * 4):
			var p: Vector3 = st.pick.call()
			for t in 6:
				var q: Vector3 = st.pick.call()
				if (st.nrm.call(q) as Vector3).dot(VIEW_DIR) > (st.nrm.call(p) as Vector3).dot(VIEW_DIR): p = q
			var d: Vector3 = st.nrm.call(p)
			var ax := d.cross(_rv()).normalized()
			var pts := [p - d * 0.01]
			var q := p
			for i in 14 + int(rng.next() * 10):
				d = (Basis(ax, 0.35 + rng.next() * 0.3) * d + _rv() * 0.25).normalized()
				ax = (ax + _rv() * 0.3).normalized()
				q += d * 0.05 * gs
				pts.append(q)
			U.mesh(Geo.tube(pts, 64, (0.02 + rng.next() * 0.012) * gs, 7), wm, root)
			for pi in range(0, pts.size(), 3): keep_out.append([pts[pi], 0.05 * gs])
	# almandine's schist (SpecLooks mica): the rock round the crystals glitters with silvery flakes of mica
	if look.get("mica", false) and st.rocky:
		var fm := SpecMat.make({col = SpecMat.lin(0x8c8478), metal = 0.65, rough = 0.22, env = 2.2})
		var flakes := []
		for k in 420 + int(rng.next() * 200):
			var p: Vector3 = st.pick.call()
			var nn: Vector3 = st.nrm.call(p)
			var s := (0.005 + pow(rng.next(), 2.5) * 0.014) * gs
			var b := Basis(quat_to_l(UP, (nn + _rv() * 0.9).normalized())) * Basis(UP, rng.next() * TAU)
			flakes.append(Transform3D(b * Basis.from_scale(Vector3(s, s * 0.08, s)), p + nn * 0.004))
		U.inst(Geo.cylinder(1, 1, 1, 6), fm, flakes.size(), func(i: int) -> Array: return [flakes[i], Color(1, 1, 1)], root)
	# fluorite's phantom cubes (SpecLooks core): a cube of another colour inside every crystal, seen through the glass
	if look.has("core") and main and layout != "geode":
		var cc: Array = look.core
		# (phantom_core: the phantom gene is this cube made bright — glossy, lit from within, a touch bigger)
		var lit: bool = look.get("phantom_core", false) and "phantom" in tr
		var core_m := SpecMat.make({col = SpecMat.lin(core_hex) * (1.6 if lit else 1.0), rough = 0.2 if lit else 0.35, flat = true, emis = SpecMat.lin(core_hex) * (1.6 if lit else 0.04)})
		var first_core: Node3D = null
		for n in root.find_children("*", "MeshInstance3D", true, false):
			var cm := (n as MeshInstance3D).material_override
			if not n.has_meta("geo") or n.has_meta("lying") or not (cm == mat or cm in dt_mats): continue
			var g: Geo = n.get_meta("geo")
			var bb := g.aabb()
			var ck := float(cc[1]) * (1.25 if lit else 1.0)
			var inner := Geo.box(bb.size.x * ck, bb.size.y * ck, bb.size.z * ck)
			var cmi := U.mesh(inner, core_m, n, bb.get_center() + Vector3(0, bb.size.y * 0.06, 0))
			if first_core == null or n == main: first_core = cmi
		if lit and first_core: _mark("phantom", _mid(first_core))
	# genes that shape or colour the crystals themselves: there only if crystals grew
	var crystals := main != null and not (layout in ["nugget", "vein", "botryoid", "sawn", "balls", "fans", "staircase", "grapes"])
	if "scepter" in tr and main and layout in ["single", "floater"] and habit in ["prism", "blade"]: _mark("scepter", _mid(main, 0.9))
	if "floater" in tr and layout == "floater": _mark("floater", _mid(main, 0.15))
	if "atypical" in tr and main: _mark_face("atypical", main)
	if "zoned" in tr and crystals: _mark_on("zoned", main)
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
	if String(gene.get("pseudo", "")) != "" and main: _mark_on("pseudo", main)
	if String(gene.fx) != "": _mark("fx", _mid(main, 0.65))

	# from here on whatever settles on the rock (plants, puffs, sprays, crusts, flakes, bubbles) keeps out of
	# the crystals: a spot under one is picked again, a few times, and the pits under them are dropped.
	# Moss and coral are the exception (`pick_any`, `hollows_all`): grown thick, the crystals look pushed up through them
	body_mass = mass_of(root, true)   # (the rock and the crystals, nothing grown yet: Stones.settle)
	boxes = _crystal_boxes(main, mat)
	# an association: the second species grows on the free rock beside the first (and nothing grows through it after)
	# the hero crystal is the gem of the group: cloud only at its root (clarity by parts; SpecForms._hero set its own)
	if main and not main.has_meta("part"):
		main.set_meta("part", 0.26 + 0.22 * fposmod((seed_v % 1000) * 0.6180339, 1.0))
	var mate := String(gene.get("assoc", ""))
	if mate != "":
		# a metal may grow on the crystal itself (gold clinging to quartz) — always where there is no rock to grow on
		var perch: bool = mate in SpecLooks.PERCH and main != null and main.has_meta("geo") and mat != null and main.material_override == mat \
			and SpecLooks.perch_roll(seed_v, bool(st.rocky))
		if perch:
			SpecForms.perch(self, mate, main, gs, seed_v)
		elif st.rocky:
			var was := root.get_children()
			SpecForms.partner(self, mate, st, gs, seed_v)
			# (the partner's own: an alexandrite's lamp turns only the alexandrite, _alex)
			for c in root.get_children():
				if not c in was: c.set_meta("partner", true)
			boxes = _crystal_boxes(main, mat)
	st.pick_any = st.pick
	st.hollows_all = st.hollows
	if boxes.size() or keep_out.size():
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
		"borealis": SpecPolar.borealis(root, rng)
		"heart":
			SpecLegend.heart(root, main, rng, col)
			if main and main.material_override is ShaderMaterial:
				# the core glows through the main crystal's own glass, whatever the angle
				var hm := U.mat_copy(main.material_override as ShaderMaterial)
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
	crust_once = layout == "skull"
	_inside(main, mat, habit, col, gi, tr, legend, layout, seed_v)
	_tag("inside")   # (what lies in the crystals on purpose: needles of rutile, phantoms, clouds)
	if gene.gold:
		_gold(main, mat, st)
	_growths(main, mat, col, tr, layout, sid, st, legend)
	_accents(main, mat, gene, st, layout)
	# nothing that grew sits inside a crystal: what does is taken away (and a gene left with nothing is not "grown")
	_tag("accents")
	SpecSolid.clear(root, grown)
	# a trilobite's slab is held up to the viewer, everything that grew on it with it
	if layout == "trilobite":
		SpecTrilobite.lean(self, gene)
	elif layout == "fern":
		SpecFern.lean(self, gene)
	elif layout == "skull":
		SpecSkull.lean(self, gene)
	if limonite:
		# rusty limonite stains (G3): the crust at the crystals' feet turned rust-brown and climbing higher up them
		dt.col = SpecMat.lin(0x7a3a12)
		dt.h = maxf(float(dt.h), 0.25) + 0.12
		dt.a = 0.5
		if main: _mark_on("limonite", main)
	# a lump that is no crystal, hurt by a careless dig: broken in pieces, crumbs at its foot (16.11; 19.11 every
	# botryoidal lump — chalcedony, jadeite, carnelian, flint, opal, hyalite… — a septarian nodule, obsidian, a lava bomb)
	# (an opal egg is not broken apart — its lid of opal slid off its shell: it crazes instead, _geode)
	if hurt.size() and (layout in ["vein", "nugget", "botryoid", "septaria", "obsidian", "xenolith", "geode", "slice"] or (sid == "malachite" and layout == "sawn")) and not (layout == "geode" and sid == "opal"):
		_glassy = layout == "obsidian"
		_shatter()
	_finish()
	# a sea find: sunlight through the water over it (its rock's mesh exists only now)
	if root.has_meta("sea"):
		SpecSea.caustics(root)
	# frost over the crystals (their meshes, too, exist only now)
	if gene.fx == "frost":
		SpecPolar.frost(root, rng)
	if legend:
		root.set_meta("glow", U.raw(0xe4ae39))
	# hundreds of soil crumbs and moss sprigs drawn as a few objects (the same picture, far fewer draw calls)
	U.batch(root)
	# (a find the plesiosaur swallowed: only the plesiosaur is left on its card)
	if o.get("gulp", false): SpecReef.swallowed(root)
	st_ref = {}   # (its closures hold the builder: let it go)
	if soap_audit: _soap_check(o)
	return root

## (16.11) a lump that is no crystal (a vein's quartz with its metal, a nugget, malachite) hurt by a careless dig is not
## pitted and scribbled on ("plastic with a pen line across it") — it is broken: Chipped, a piece knocked off one end
## lies beside it; Damaged, it is split through, two pieces apart (the worst, three), each fracture rough and in the
## stone's own stuff, the faces turned to the viewer; crumbs and splinters of it at the foot. Everything grown on a
## piece goes with it. On the damage's own stream: the find is the same find, broken
func _shatter() -> void:
	var k: float = hurt.get("k", 0.0)
	if k < 0.2: return   # (Fine and better: whole)
	var dr: Rng32 = hurt.rng
	# (a pebble lies in a holder that turns it: a holder is no mesh, it went whole to one side and nothing broke — its
	# meshes are laid out under the root, in place)
	for c: Node in root.get_children():
		if c is Node3D and not c is VisualInstance3D and c.get_script() == null and c.get_child_count() > 0:
			var t := (c as Node3D).transform
			for x: Node in c.get_children():
				if not x is Node3D: continue
				var xt := t * (x as Node3D).transform
				c.remove_child(x)
				root.add_child(x)
				(x as Node3D).transform = xt
	# how it broke, the stone's own (16.11): an end knocked off sideways; its top knocked off; a slanting break, the
	# wedge above slid down; a piece fallen forward to the viewer. (A Damaged find is split through: no top off)
	var flat: bool = String(gene_m.get("form", "")) in ["sawn", "slice"]
	var mode: String = Stones.pick_w([["side", 4.0], ["top", 0.0 if flat else 3.0], ["slant", 3.0], ["front", 0.0 if flat else 2.0]] if k < 0.56
		else [["side", 4.0], ["slant", 3.0], ["front", 0.0 if flat else 2.0]], dr)
	var cuts: Array = []
	if k < 0.56: cuts = [0.72 + dr.next() * 0.08]                       # Chipped: an end knocked off (deeper than the very tip: a spongy lump's tip is all froth, it came off as flakes)
	else:
		cuts = [0.42 + dr.next() * 0.16]                                 # Damaged: through the middle
		# and a half broken again — near its middle (at 0.7–0.8 it cut a strip off, a plate); never a sawn slab: already
		# thin, its strips were plates
		if k > 0.7 and dr.next() < 0.6 and not flat: cuts.append(0.5 + dr.next() * 0.12)
	var across := UP.cross(VIEW_DIR).normalized()   # (the pieces part sideways across the picture)
	var pieces: Array = [root.get_children()]
	for ci in cuts.size():
		# the biggest piece breaks
		var gi := 0
		var best := -1.0
		for i in pieces.size():
			var bx := _box_of(pieces[i] as Array)
			if bx.size.length() > best:
				best = bx.size.length()
				gi = i
		var grp: Array = pieces[gi]
		var bb := _box_of(grp)
		var ext := bb.size.length()
		var sgn := 1.0 if dr.next() < 0.5 else -1.0
		# (a second break: across the first — the half's top knocked off. Along the first, as before, it sliced the
		# half thinner again and the slice stood up as a plate)
		var m := mode if ci == 0 else "top"
		var n: Vector3
		match m:
			"top": n = UP + across * sgn * (0.15 + dr.next() * 0.25) + VIEW_DIR * (dr.next() - 0.3) * 0.4
			"slant": n = across * sgn + UP * (0.7 + dr.next() * 0.5) + VIEW_DIR * (dr.next() - 0.5) * 0.4
			"front": n = VIEW_DIR + across * sgn * (0.2 + dr.next() * 0.3) + UP * (dr.next() * 0.3)
			_: n = across * sgn + Vector3(0, (dr.next() - 0.5) * 0.6, 0) + VIEW_DIR * (dr.next() - 0.5) * 0.5
		n = n.normalized()
		# the plane at a share of the way across the piece along n
		var lo := INF
		var hi := -INF
		for nd: Node in grp:
			for p: Vector3 in _pts_of(nd):
				lo = minf(lo, p.dot(n))
				hi = maxf(hi, p.dot(n))
		if lo > hi: continue
		var at := n * lerpf(lo, hi, float(cuts[ci]))
		var rough := FastNoiseLite.new()
		rough.seed = int(dr.next() * 100000)
		rough.frequency = 4.0 / maxf(0.1, ext)
		rough.fractal_octaves = 3
		var amp := ext * 0.035
		var a_side: Array = []
		var b_side: Array = []
		for x in grp:
			# (a fracture already cut with its skin, and freed, is passed over)
			if not is_instance_valid(x): continue
			var parts := _cut_node(x as Node, at, n, rough, amp, hi - lo)
			a_side.append_array(parts[0])
			b_side.append_array(parts[1])
		if b_side.is_empty() or a_side.is_empty():
			pieces[gi] = a_side + b_side
			continue
		# the piece beyond the break turned about its middle so its fracture (facing -n) comes round towards the viewer
		# and up — part of the way: turned hard into the studio's lamps a glossy skin flared white, like glass; a sawn
		# slab keeps its polished face to the viewer. Fallen pieces (top, slant, front) turn much further: they tumbled
		var fwant := (VIEW_DIR * 0.8 + UP * 0.6 + across * sgn * 0.3).normalized()
		var share: float = {"side": 0.25, "top": 0.75, "slant": 0.55, "front": 0.6}[m] + dr.next() * 0.15
		if flat: share = 0.0   # (a sawn slab: its polished face, turned, mirrored a studio lamp and burnt white — it only slides)
		var rot := Basis(Quaternion.IDENTITY.slerp(U.quat_to(-n, fwant), share)) * Basis(fwant, (dr.next() - 0.5) * 0.7 * (0.3 if flat else 1.0))
		var bc := _box_of(b_side).get_center()
		var tb := Transform3D(Basis.IDENTITY, bc) * Transform3D(rot, Vector3.ZERO) * Transform3D(Basis.IDENTITY, -bc)
		# the callouts of what grew beyond the break go with it
		var marks: Array = []
		for id in grown:
			for e: Array in grown[id]:
				if ((e[0] as Vector3) - at).dot(n) > 0.0: marks.append(e)
		_move(b_side, marks, tb)
		# then off to where it lies: along the ground (sideways, or forward for a piece fallen to the viewer), clear of
		# the rest with a gap, and down onto the same ground
		var h := Vector3(n.x, 0, n.z)
		if m == "top": h = across * sgn
		elif m == "front": h = (VIEW_DIR * 0.6 + across * sgn).normalized()   # (forward and aside: straight in front it hid the rest)
		h = h.normalized() if h.length() > 0.01 else across * sgn
		var pa := _span(a_side, h)
		var pb := _span(b_side, h)
		var gap := ext * (0.04 + dr.next() * 0.06 + (0.04 if ci == 0 and cuts.size() > 1 else 0.0))
		_move(b_side, marks, Transform3D(Basis.IDENTITY, h * (pa.y - pb.x + gap)))
		var drop := _box_of(b_side).position.y - _box_of(a_side).position.y
		_move(b_side, marks, Transform3D(Basis.IDENTITY, Vector3(0, -drop, 0)))
		pieces[gi] = a_side
		pieces.append(b_side)
	# crumbs and splinters at the foot, of the stone's own stuff, most on the side the viewer sees
	var all_n: Array = []
	for g: Array in pieces: all_n.append_array(g)
	var box := _box_of(all_n)
	var mats: Array = []
	var mcols: Array = []   # (a mesh coloured by its points: its crumbs take its mean colour — plain, they were white)
	for nd: Node in all_n:
		if nd is MeshInstance3D and nd.has_meta("geo") and (nd as MeshInstance3D).material_override and not nd.has_meta("no_crumbs"):
			var gs := _box_of([nd]).size.length()
			if gs > box.size.length() * 0.3:
				mats.append((nd as MeshInstance3D).material_override)
				var mc := Color(-1, 0, 0)
				var gg: Geo = nd.get_meta("geo")
				if _glassy and gg.col.size() > 0:
					mc = Color(0, 0, 0, 0)
					for c4 in gg.col: mc += c4 / gg.col.size()
				mcols.append(mc)
	if mats.is_empty(): return
	var ext := box.size.length()
	for i in int(8 + k * 18):
		# lying flat on the ground, small: crumbs and the odd flat splinter
		var r := ext * (0.008 + pow(dr.next(), 2.0) * 0.026)
		var sc := Vector3(1.0 + dr.next() * 0.6, 0.45 + dr.next() * 0.3, 0.8 + dr.next() * 0.4) if dr.next() < 0.7 else Vector3(1.6 + dr.next() * 0.8, 0.22, 0.55)
		var p := Vector3(box.get_center().x + (dr.next() - 0.5) * box.size.x * 0.95, box.position.y + r * sc.y * 0.5, box.get_center().z + (dr.next() - 0.5) * box.size.z * 0.95)
		p += VIEW_DIR * ext * 0.1 * dr.next()
		var mk := int(dr.next() * mats.size()) % mats.size()
		var cg := RockKit.crumble(dr, r, sc, 8)
		var cm: Material = mats[mk]
		if _glassy and cm is ShaderMaterial: cm = _matte(cm)
		var cmi := U.mesh(cg, cm, root, p, U.eul((dr.next() - 0.5) * 0.4, dr.next() * 6.3, (dr.next() - 0.5) * 0.4))
		cmi.set_meta("crumb", true)   # (a shake of the phone rattles them: SpecView.shake_find)
		if (mcols[mk] as Color).r >= 0.0:
			cg.col.resize(cg.v.size())
			cg.col.fill(mcols[mk])
			if cmi.mesh: cmi.mesh = cg.to_mesh()
			cmi.set_meta("col", true)

## the points of a node, in the find's space (a mesh's own; a multimesh's copies; anything else its place)
func _pts_of(nd: Node) -> PackedVector3Array:
	var out := PackedVector3Array()
	if not nd is Node3D: return out
	var t := U.rel_xform(nd as Node3D, root)
	if nd is MeshInstance3D and nd.has_meta("geo"):
		var g: Geo = nd.get_meta("geo")
		var step := maxi(1, g.v.size() / 400)
		for i in range(0, g.v.size(), step): out.append(t * g.v[i])
	elif nd is MultiMeshInstance3D:
		var b: PackedFloat32Array = nd.get_meta("ibuf", nd.get_meta("mmbuf", PackedFloat32Array()))
		for i in b.size() / 16: out.append(t * Vector3(b[i * 16 + 3], b[i * 16 + 7], b[i * 16 + 11]))
	else:
		out.append(t.origin)
	return out

## how far the nodes reach along h: (least, most)
func _span(nodes: Array, h: Vector3) -> Vector2:
	var lo := INF
	var hi := -INF
	for nd: Node in nodes:
		for p in _pts_of(nd):
			lo = minf(lo, p.dot(h))
			hi = maxf(hi, p.dot(h))
	return Vector2(lo, hi)

func _box_of(nodes: Array) -> AABB:
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	for nd: Node in nodes:
		for p in _pts_of(nd):
			lo = lo.min(p)
			hi = hi.max(p)
	return AABB(lo, hi - lo) if lo.x <= hi.x else AABB()

## (16.11) a spongy lump (a copper nugget) cut through falls apart past the break into a few tips of its froth, each
## closed by its own little cap — they hung in the air by the piece. A half keeps only its pieces of real size: any
## part joined to the rest by no edge, and under a third of the biggest, is dropped (whole, so nothing is left open)
func _drop_islands(skin: Geo, face: Geo, w: Geo) -> void:
	var key := func(p: Vector3) -> Vector3i: return Vector3i(roundi(p.x * 50000.0), roundi(p.y * 50000.0), roundi(p.z * 50000.0))
	var parent := {}
	var find := func(x: Vector3i) -> Vector3i:
		var r := x
		while parent.has(r) and parent[r] != r: r = parent[r]
		return r
	var tris := []   # [geo, start]
	for g: Geo in [skin, face]:
		for t in range(0, g.idx.size(), 3):
			var ks := [key.call(w.v[g.idx[t]]), key.call(w.v[g.idx[t + 1]]), key.call(w.v[g.idx[t + 2]])]
			for kk: Vector3i in ks:
				if not parent.has(kk): parent[kk] = kk
			var r0: Vector3i = find.call(ks[0])
			for c in [1, 2]:
				var rc: Vector3i = find.call(ks[c])
				if rc != r0: parent[rc] = r0
			tris.append([g, t, ks[0]])
	var size := {}
	for e: Array in tris:
		var r: Vector3i = find.call(e[2])
		size[r] = int(size.get(r, 0)) + 1
	if size.size() < 2: return
	var big := 0
	for r in size: big = maxi(big, int(size[r]))
	var keep_s := PackedInt32Array()
	var keep_f := PackedInt32Array()
	for e: Array in tris:
		if int(size[find.call(e[2])]) * 3 < big: continue
		var g: Geo = e[0]
		var t: int = e[1]
		(keep_s if g == skin else keep_f).append_array([g.idx[t], g.idx[t + 1], g.idx[t + 2]])
	skin.idx = keep_s
	face.idx = keep_f

## (16.11) the break is not a plane ("as if cut with a knife"): a wavy surface — the plane lifted by the noise, read
## in the plane's own two axes so every point over the same spot has the same height (both halves cut by it fit)
func _plane_uv(n: Vector3) -> Array:
	var u := n.cross(UP if absf(n.y) < 0.9 else Vector3.RIGHT).normalized()
	return [u, n.cross(u)]

func _wave(p: Vector3, at: Vector3, n: Vector3, rough: FastNoiseLite, amp: float) -> float:
	var uv := _plane_uv(n)
	var q := p - at
	return rough.get_noise_2d(q.dot(uv[0]), q.dot(uv[1])) * amp * BREAK_WAVE

## how far the break's surface wanders off its plane, in the noise's own amplitude (2.2 folded the cut over itself
## where the skin ran nearly along it: needles in the fracture)
const BREAK_WAVE := 1.5
## a mesh that reaches less than this share of the broken piece's depth past the break is not cut, it goes whole
## to its side
const SLIVER := 0.07

## one node split by the plane (at, n): [nodes on the near side, nodes beyond]. A mesh crossing it is cut in two,
## each half closed by the rough fracture (its own mesh, so the edge round it is sharp); a multimesh's copies are
## shared out; anything else goes whole to the side its middle is on
func _cut_node(nd: Node, at: Vector3, n: Vector3, rough: FastNoiseLite, amp: float, span_all := 1.0) -> Array:
	if not nd is Node3D: return [[nd], []]
	var t := U.rel_xform(nd as Node3D, root)
	if nd is MeshInstance3D and nd.has_meta("geo"):
		# a piece of an earlier break is two meshes on the same points: its skin and its fracture ("mate"). Cut apart,
		# each gave an open outline of its own and the caps did not meet — they are cut as one, the fracture's
		# triangles keeping the fracture's material
		var mate: MeshInstance3D = null
		if nd.has_meta("mate") and is_instance_valid(nd.get_meta("mate")):
			mate = nd.get_meta("mate")
			if nd.get_meta("is_face", false): return [[], []]   # (its skin cuts it, and reports it)
		var g: Geo = nd.get_meta("geo")
		var face_from := -1
		if mate:
			var gf: Geo = mate.get_meta("geo")
			var gc := Geo.new()
			gc.v = g.v
			gc.col = g.col
			gc.idx = g.idx.duplicate()
			face_from = gc.idx.size()
			gc.idx.append_array(gf.idx)
			g = gc
		var nb := 0
		var dlo := INF
		var dhi := -INF
		for i in g.v.size():
			var wp := t * g.v[i]
			var dd := (wp - at).dot(n) - _wave(wp, at, n, rough, amp)
			if dd > 0.0: nb += 1
			dlo = minf(dlo, dd)
			dhi = maxf(dhi, dd)
		var whole := [nd] if not mate else [nd, mate]
		if nb == 0: return [whole, []]
		if nb == g.v.size(): return [[], whole]
		# (a mesh the break only grazes — a bubble, a rim of crust, a lump's edge — is not shaved: a thin slice of it
		# went off with the other piece as a leaf, a plate. It goes whole to the side most of it is on)
		# (measured against the whole piece being broken, not the mesh: a Chipped find's end is a thin share of its
		# one big lump and must still come off)
		if dhi < span_all * SLIVER: return [whole, []]
		if -dlo < span_all * SLIVER: return [[], whole]
		var mi := nd as MeshInstance3D
		_cap_rim_col = _glassy
		var halves := [_half(g, t, at, n, rough, amp, false, face_from), _half(g, t, at, n, rough, amp, true, face_from)]
		var out := [[], []]
		for h in 2:
			var made := []
			for pi in 2:
				var part: Geo = (halves[h] as Array)[pi]
				if part.idx.is_empty():
					made.append(null)
					continue
				var m := MeshInstance3D.new()
				for mk in nd.get_meta_list(): m.set_meta(mk, nd.get_meta(mk))
				m.remove_meta("mate")
				m.remove_meta("is_face")
				m.set_meta("geo", part)
				m.material_override = mi.material_override
				# (the fracture: matte and silky, not polished — glossy it read as glass or plastic)
				if pi == 1:
					if mate: m.material_override = mate.material_override
					# (a boulder opal's seam: its fracture shows the seam running on through the stone — the same opal,
					# drawn a hair over the rock's own fracture. Matte, the opal read as a film on a hollow rock)
					elif nd.has_meta("seam"):
						var sm := U.mat_copy(mi.material_override)
						sm.set_shader_parameter("push", 0.003)
						m.material_override = sm
					# (obsidian — coloured by its points — breaks to the same glassy shell it is: no matte copy)
					elif mi.material_override is ShaderMaterial and not _glassy: m.material_override = _matte(mi.material_override)
					m.set_meta("is_face", true)
				m.transform = mi.transform
				if mi.mesh: m.mesh = part.to_mesh()
				nd.get_parent().add_child(m)
				(out[h] as Array).append(m)
				made.append(m)
			if made[0] and made[1]:
				(made[0] as Node).set_meta("mate", made[1])
				(made[1] as Node).set_meta("mate", made[0])
		for x: Node in whole:
			x.get_parent().remove_child(x)
			x.free()
		return out
	if nd is MultiMeshInstance3D:
		var mmi := nd as MultiMeshInstance3D
		var key := "ibuf" if nd.has_meta("ibuf") else "mmbuf" if nd.has_meta("mmbuf") else ""
		if key != "" and mmi.multimesh:
			var b: PackedFloat32Array = nd.get_meta(key)
			var ba := PackedFloat32Array()
			var bb2 := PackedFloat32Array()
			for i in b.size() / 16:
				var o := t * Vector3(b[i * 16 + 3], b[i * 16 + 7], b[i * 16 + 11])
				if (o - at).dot(n) > 0.0: bb2.append_array(b.slice(i * 16, i * 16 + 16))
				else: ba.append_array(b.slice(i * 16, i * 16 + 16))
			if bb2.is_empty(): return [[nd], []]
			if ba.is_empty(): return [[], [nd]]
			var mk2 := func(buf: PackedFloat32Array) -> MultiMeshInstance3D:
				var mm := MultiMesh.new()
				mm.transform_format = MultiMesh.TRANSFORM_3D
				mm.use_colors = mmi.multimesh.use_colors
				mm.use_custom_data = mmi.multimesh.use_custom_data
				mm.mesh = mmi.multimesh.mesh
				mm.instance_count = buf.size() / 16
				# (a buffer laid out with custom data is wider: copies are only shared out when it is the plain one)
				mm.buffer = buf
				var x := MultiMeshInstance3D.new()
				for m3 in nd.get_meta_list(): x.set_meta(m3, nd.get_meta(m3))
				x.set_meta(key, buf)
				x.multimesh = mm
				x.material_override = mmi.material_override
				x.transform = mmi.transform
				nd.get_parent().add_child(x)
				return x
			if mmi.multimesh.use_custom_data: return [[nd], []] if _side_of(nd, at, n) <= 0.0 else [[], [nd]]
			var xa: MultiMeshInstance3D = mk2.call(ba)
			var xb: MultiMeshInstance3D = mk2.call(bb2)
			nd.get_parent().remove_child(nd)
			nd.free()
			return [[xa], [xb]]
	return [[nd], []] if _side_of(nd, at, n) <= 0.0 else [[], [nd]]

## (19.11) a metal tree's twig hurt by the dig: snapped off part way? (the thin ones more often)
func dr_snap(r: Rng32, k: float, depth: int) -> bool:
	return r.next() < k * (0.55 + 0.2 * depth)

var _sid := ""   # (the species being built, for the builders that are not handed it: _geode)
## (20.11) tests: report every rock mesh with no rock coordinates — its scan on one texel, smooth as soap
static var soap_audit := false
func _soap_check(o: Dictionary) -> void:
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var m := mi.material_override as ShaderMaterial
		if not m or not m.get_meta("dirt", false) or not mi.mesh: continue
		var arr := mi.mesh.surface_get_arrays(0)
		var uv: Variant = arr[Mesh.ARRAY_TEX_UV]
		var flat := uv == null
		if not flat:
			var u: PackedVector2Array = uv
			var lo := Vector2(INF, INF)
			var hi := -lo
			for i in range(0, u.size(), maxi(1, u.size() / 200)):
				lo = lo.min(u[i])
				hi = hi.max(u[i])
			flat = (hi - lo).length() < 1e-4
		if flat: print("SOAP ", o.get("sid", "?"), " ", o.get("form", ""), " seed ", o.get("seed", 0), " mesh ", mi.name)

var _cap_rim_col := false   # (_half: the cap's points coloured as the rim's — a mesh coloured by its points)
var _glassy := false        # (_shatter: obsidian — black glass coloured by its points, breaking to the same glass)
static var fallbacks := 0   # (tests/shatter_check: how often a cap's outline would not triangulate as a polygon)
var _mattes := {}
func _matte(m: ShaderMaterial) -> ShaderMaterial:
	if not _mattes.has(m):
		var c := U.mat_copy(m)
		# (no coat, a dull sheen, no film: the studio's lamps on a flat glossy face flared it white, glass)
		# (a material of its own shader — obsidian's, a lava bomb's — has no "rough": left as it is)
		var r0: Variant = m.get_shader_parameter("rough")
		if r0 != null: c.set_shader_parameter("rough", maxf(0.45, float(r0)))
		c.set_shader_parameter("coat", 0.0)
		c.set_shader_parameter("spec", 0.2)
		c.set_shader_parameter("ir_k", 0.0)
		if m in dt_mats: dt_mats.append(c)
		_mattes[m] = c
	return _mattes[m]

func _side_of(nd: Node, at: Vector3, n: Vector3) -> float:
	var pts := _pts_of(nd)
	if pts.is_empty(): return -1.0
	var c := Vector3.ZERO
	for p in pts: c += p / pts.size()
	return (c - at).dot(n)

## one side of a mesh cut by the plane (beyond: the far side): its triangles clipped at the plane (kept indexed, new
## points on the cut edges shared by position — smooth shading stays, a sphere's seam closes), and the cut closed by a
## cap: the outline of the cut, points inside it, triangulated, made rough by the noise (the same for both halves:
## they fit) while its rim stays on the outline — closed, no hole. [the skin, the fracture] sharing the points.
## (16.11: the far side pressed flat onto the plane left holes wherever the bumpy skin there faced inwards — the
## piece showed as a hollow shell, "a thin leaf")
func _half(g: Geo, t: Transform3D, at: Vector3, n: Vector3, rough: FastNoiseLite, amp: float, beyond: bool, face_from := -1) -> Array:
	var sg := -1.0 if beyond else 1.0   # (this half keeps the points where (p - at)·n·sg <= 0)
	var out_n := n * sg                  # the cap looks out of this half
	var ti := t.affine_inverse()
	var w := Geo.new()
	w.v = g.v.duplicate()
	w.col = g.col.duplicate() if g.col.size() == g.v.size() else PackedColorArray()
	if w.col.is_empty(): w.fill_color(Color(1, 1, 1))
	var ix := g.idx
	if ix.is_empty():
		ix = PackedInt32Array()
		ix.resize(g.v.size())
		for i in g.v.size(): ix[i] = i
	var e := PackedFloat32Array()
	e.resize(w.v.size())
	var pk := PackedVector3Array()
	pk.resize(w.v.size())
	for i in w.v.size():
		var wp := t * w.v[i]
		pk[i] = wp
		var d := ((wp - at).dot(n) - _wave(wp, at, n, rough, amp)) * sg
		e[i] = d if d != 0.0 else -1e-7
	var made := {}     # the cut edge (its two ends by place) -> the new point on it
	var adj := {}      # a point on the cut -> the points it joins along the cut
	var key := func(i: int) -> Vector3i: return Vector3i(roundi(pk[i].x * 50000.0), roundi(pk[i].y * 50000.0), roundi(pk[i].z * 50000.0))
	var cut := func(a: int, b: int) -> int:
		var ka: Vector3i = key.call(a)
		var kb: Vector3i = key.call(b)
		var ek := [ka, kb] if str(ka) < str(kb) else [kb, ka]
		if made.has(ek): return made[ek]
		var f := e[a] / (e[a] - e[b])
		var vi := w.v.size()
		w.v.append(w.v[a].lerp(w.v[b], f))
		w.col.append(w.col[a].lerp(w.col[b], f))
		made[ek] = vi
		return vi
	var link := func(a: int, b: int) -> void:
		if a == b: return
		if not adj.has(a): adj[a] = []
		if not adj.has(b): adj[b] = []
		(adj[a] as Array).append(b)
		(adj[b] as Array).append(a)
	var skin := Geo.new()
	var sk := PackedInt32Array()
	var fk := PackedInt32Array()   # (from an earlier break's fracture: stays fracture)
	for k in range(0, ix.size(), 3):
		var into := fk if face_from >= 0 and k >= face_from else sk
		var tri := [ix[k], ix[k + 1], ix[k + 2]]
		var keep := [e[tri[0]] <= 0.0, e[tri[1]] <= 0.0, e[tri[2]] <= 0.0]
		var nk := int(keep[0]) + int(keep[1]) + int(keep[2])
		if nk == 3:
			into.append_array(tri)
		elif nk == 1:
			# one corner kept (turned to the front, winding kept): it and two points on the cut
			var r := 0 if keep[0] else 1 if keep[1] else 2
			var a: int = tri[r]
			var b: int = tri[(r + 1) % 3]
			var c: int = tri[(r + 2) % 3]
			var pab: int = cut.call(a, b)
			var pac: int = cut.call(a, c)
			into.append_array([a, pab, pac])
			link.call(pab, pac)
		elif nk == 2:
			# one corner cut off: a quad left, two triangles
			var r := 0 if not keep[0] else 1 if not keep[1] else 2
			var c: int = tri[r]
			var a: int = tri[(r + 1) % 3]
			var b: int = tri[(r + 2) % 3]
			var pbc: int = cut.call(b, c)
			var pca: int = cut.call(c, a)
			into.append_array([a, b, pbc, a, pbc, pca])
			link.call(pbc, pca)
	skin.idx = sk
	# the outline of the cut, as loops — walked edge by edge (where two cut points fell on one place a point joins four
	# edges: walked point by point the loop broke there and left a gap in the cap)
	var loops := []
	var used := {}
	for s0: int in adj:
		for s1: int in adj[s0]:
			var ek0 := Vector2i(mini(s0, s1), maxi(s0, s1))
			if used.has(ek0): continue
			var loop := PackedInt32Array([s0])
			used[ek0] = true
			var prev := s0
			var cur := s1
			var guard := 0
			while cur != s0 and guard < 100000:
				guard += 1
				loop.append(cur)
				var nxt := -1
				for o: int in adj[cur]:
					var ek := Vector2i(mini(cur, o), maxi(cur, o))
					if not used.has(ek):
						used[ek] = true
						nxt = o
						break
				if nxt < 0: break
				prev = cur
				cur = nxt
			if loop.size() >= 3: loops.append(loop)
	var face := Geo.new()
	var fc := fk
	if loops.size():
		# the cap in the plane's own two axes
		var uv := _plane_uv(n)
		var u: Vector3 = uv[0]
		var v2: Vector3 = uv[1]
		var pts := PackedVector2Array()
		var ids := PackedInt32Array()
		var polys := []
		var lo := Vector2(INF, INF)
		var hi := -lo
		for loop: PackedInt32Array in loops:
			var poly := PackedVector2Array()
			for vi in loop:
				var q := t * w.v[vi] - at
				var p2 := Vector2(q.dot(u), q.dot(v2))
				# (a point on the place of the one before it: dropped — the polygon's triangulation fails on it. The skin's
				# edge between them has no length: nothing left open)
				if poly.size() and p2.distance_squared_to(poly[poly.size() - 1]) < 1e-12: continue
				poly.append(p2)
				pts.append(p2)
				ids.append(vi)
				lo = lo.min(p2)
				hi = hi.max(p2)
			if poly.size() > 1 and poly[0].distance_squared_to(poly[poly.size() - 1]) < 1e-12:
				poly.remove_at(poly.size() - 1)
				pts.remove_at(pts.size() - 1)
				ids.remove_at(ids.size() - 1)
			polys.append(poly)
		var edge_d := func(p: Vector2) -> float:
			var best := INF
			for poly: PackedVector2Array in polys:
				for j in poly.size():
					best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, poly[j], poly[(j + 1) % poly.size()])))
			return best
		# each loop triangulated as a polygon (its edges exactly the outline: a Delaunay over points cut corners past
		# the skin's edge and left slits), then its triangles split at their middles, twice over the big ones, those
		# middles lifted by the noise — the rough break; the rim stays on the outline
		var step := maxf((hi - lo).length() / 16.0, 0.004)
		var tri_list := []   # [[id, id, id], [p2, p2, p2]]
		var fans := []       # loops that would not triangulate: [loop, its first point in pts]
		var base := 0
		for li in loops.size():
			var poly: PackedVector2Array = polys[li]
			var tri_ix := Geometry2D.triangulate_polygon(poly)
			if tri_ix.is_empty():
				# (a loop crossing itself — a bumpy skin gives points on one place, folds — will not take the polygon's
				# way. A Delaunay over it cut corners and spanned the break with long triangles: spikes and slits. A fan
				# from its middle instead, below — its rim exactly the outline)
				fallbacks += 1
				fans.append([li, base])
			for k in range(0, tri_ix.size(), 3):
				tri_list.append([[ids[base + tri_ix[k]], ids[base + tri_ix[k + 1]], ids[base + tri_ix[k + 2]]], [poly[tri_ix[k]], poly[tri_ix[k + 1]], poly[tri_ix[k + 2]]]])
			base += poly.size()
		# the rim's own heights over the plane (the cut points of the skin): next to the rim a point takes its nearest
		# rim point's height, and only further in the wave's — where the two differed the cap stood up in a spike
		var rim_h := PackedFloat32Array()
		for k2 in pts.size():
			rim_h.append((t * w.v[ids[k2]] - at).dot(n))
		var mid_pt := func(p2: Vector2) -> int:
			var wq := at + u * p2.x + v2 * p2.y
			var de: float = edge_d.call(p2)
			var near_h := 0.0
			var near_k := 0
			var bd := INF
			for k2 in pts.size():
				var dd := p2.distance_squared_to(pts[k2])
				if dd < bd:
					bd = dd
					near_h = rim_h[k2]
					near_k = k2
			wq += n * lerpf(near_h, _wave(wq, at, n, rough, amp), smoothstep(0.0, step * 3.0, de))
			# (and finer lumps over it, gone at the rim: the rim is the skin's own edge)
			wq += out_n * rough.get_noise_3dv(wq * 2.3) * amp * 0.8 * smoothstep(step, step * 3.0, de)
			w.v.append(ti * wq)
			# (a mesh coloured by its points — obsidian's black, a snowflake's white — takes its nearest rim point's:
			# the plain grey burnt white on it)
			w.col.append(w.col[ids[near_k]] if _cap_rim_col else Color(0.85, 0.85, 0.85, 1.0))
			return w.v.size() - 1
		for fl: Array in fans:
			var poly: PackedVector2Array = polys[int(fl[0])]
			var b0: int = fl[1]
			var c2 := Vector2.ZERO
			for q in poly: c2 += q / poly.size()
			var ci: int = mid_pt.call(c2)
			for j in poly.size():
				var j2 := (j + 1) % poly.size()
				tri_list.append([[ids[b0 + j], ids[b0 + j2], ci], [poly[j], poly[j2], c2]])
		for round_i in 4:
			var next := []
			for tr: Array in tri_list:
				var P: Array = tr[1]
				var area := absf((P[1] - P[0]).cross(P[2] - P[0])) * 0.5
				if area < step * step * 0.6:
					next.append(tr)
					continue
				var c2: Vector2 = (P[0] + P[1] + P[2]) / 3.0
				var ci: int = mid_pt.call(c2)
				var I: Array = tr[0]
				next.append([[I[0], I[1], ci], [P[0], P[1], c2]])
				next.append([[I[1], I[2], ci], [P[1], P[2], c2]])
				next.append([[I[2], I[0], ci], [P[2], P[0], c2]])
			tri_list = next
		# (split at their middles, the triangles fan out in long slivers — on copper a star of glints: flipped to
		# better shapes, Delaunay's way, over the inside edges only — the rim stays the outline)
		tri_list = _flip_slivers(tri_list)
		for tr: Array in tri_list:
			var I: Array = tr[0]
			var A: int = I[0]
			var B: int = I[1]
			var C: int = I[2]
			var fn := t.basis * (w.v[C] - w.v[B]).cross(w.v[A] - w.v[B])
			if fn.dot(out_n) < 0.0: fc.append_array([A, C, B])
			else: fc.append_array([A, B, C])
	face.idx = fc
	_drop_islands(skin, face, w)
	# only the points the half uses (16.11: the cut-away side's points left in it made every measure of the piece —
	# its box, its reach along the ground — take in the other half too: the pieces were pushed twice as far apart)
	var remap := PackedInt32Array()
	remap.resize(w.v.size())
	remap.fill(-1)
	var nv := PackedVector3Array()
	var ncol := PackedColorArray()
	for x: Geo in [skin, face]:
		for j in x.idx.size():
			var o := x.idx[j]
			if remap[o] < 0:
				remap[o] = nv.size()
				nv.append(w.v[o])
				ncol.append(w.col[o])
			x.idx[j] = remap[o]
	for x: Geo in [skin, face]:
		x.v = nv
		x.col = ncol
	return [skin, face]

## Lawson's flips over a cap's triangles ([[id, id, id], [p2, p2, p2]]): an inside edge whose far corner lies in the
## circle round the other triangle is turned the other way (where the two make a convex quad); edges with one
## triangle — the rim — never move
func _flip_slivers(tris: Array) -> Array:
	var pos := {}
	var T := []
	for tr: Array in tris:
		var I: Array = tr[0]
		var P: Array = tr[1]
		for c in 3: pos[int(I[c])] = P[c]
		T.append([int(I[0]), int(I[1]), int(I[2])])
	for pass_i in 8:
		var edges := {}
		for ti in T.size():
			var t3: Array = T[ti]
			for c in 3:
				var a: int = t3[c]
				var b: int = t3[(c + 1) % 3]
				var ek := Vector2i(mini(a, b), maxi(a, b))
				if not edges.has(ek): edges[ek] = []
				(edges[ek] as Array).append(ti)
		var flipped := 0
		var touched := {}
		for ek: Vector2i in edges:
			var ts: Array = edges[ek]
			if ts.size() != 2 or touched.has(ts[0]) or touched.has(ts[1]): continue
			var A: Array = T[ts[0]]
			var B: Array = T[ts[1]]
			var a := ek.x
			var b := ek.y
			var c := -1
			var d := -1
			for x: int in A: if x != a and x != b: c = x
			for x: int in B: if x != a and x != b: d = x
			if c < 0 or d < 0 or c == d: continue
			var pa: Vector2 = pos[a]
			var pb: Vector2 = pos[b]
			var pc: Vector2 = pos[c]
			var pd: Vector2 = pos[d]
			if not _in_circle(pa, pb, pc, pd): continue
			# (only a convex quad: the new edge c-d must cross the old a-b)
			if Geometry2D.segment_intersects_segment(pc, pd, pa, pb) == null: continue
			T[ts[0]] = [c, d, a]
			T[ts[1]] = [d, c, b]
			touched[ts[0]] = true
			touched[ts[1]] = true
			flipped += 1
		if flipped == 0: break
	var out := []
	for t3: Array in T:
		out.append([t3, [pos[t3[0]], pos[t3[1]], pos[t3[2]]]])
	return out

## is d inside the circle through a, b, c (any winding)
static func _in_circle(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	var ax := a.x - d.x
	var ay := a.y - d.y
	var bx := b.x - d.x
	var by := b.y - d.y
	var cx := c.x - d.x
	var cy := c.y - d.y
	var det := (ax * ax + ay * ay) * (bx * cy - cx * by) - (bx * bx + by * by) * (ax * cy - cx * ay) + (cx * cx + cy * cy) * (ax * by - bx * ay)
	var orient := (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
	return det * signf(orient) > 1e-12

## a piece moved by `tf` in the find's space: its nodes, and the marks ([point, normal], callouts) of what grew on it
func _move(nodes: Array, marks: Array, tf: Transform3D) -> void:
	for nd: Node in nodes:
		if nd is Node3D: (nd as Node3D).transform = tf * (nd as Node3D).transform
	for e: Array in marks:
		e[0] = tf * (e[0] as Vector3)
		if (e[1] as Vector3) != Vector3.ZERO: e[1] = tf.basis * (e[1] as Vector3)

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
		var qm := SpecMat.make({col = Color(1, 1, 1), rough = 0.6, grain = 0.3, ao = 1.0, dirt = {h = 99.0, a = 0.3, col = SpecMat.lin(0xd2d6dc), fr = 0.0, scan = 4}})
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
	# milky vein quartz: cold white, its grain and cracks from the white cliff scan (16.11: without a scan it was a
	# smooth glossy lump — "soap", as the perlite was), only a little greasy
	var qm := SpecMat.make({col = Color(1, 1, 1), rough = 0.5, coat = 0.15, coat_r = 0.3, grain = 0.2, ao = 1.0, flat = true,
		dirt = {h = 99.0, a = 0.3, col = SpecMat.lin(0xc4c8ce if copper else 0xccd2da), fr = 0.0, scan = 4}})
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
## the lumpy species' material: banded, glossy (malachite deep green, its bands near black)
func _botryoid_mat(sid: String, col: Color, irk: float) -> ShaderMaterial:
	var banded := sid in ["malachite", "azurite", "chrysocolla"]
	var crust := SpecMat.lin(0x8a7a68 if sid == "opal" else 0x2a1a10 if banded else 0x4a3424)
	# (malachite deep green, its bands near black; the others a little darker than their own colour)
	var bc := SpecMat.lin(0x0f6a34) if sid == "malachite" else col * 0.6 if banded else col
	bc.a = 1.0
	return SpecMat.make({col = bc, rough = 0.12 if sid == "opal" else 0.22, coat = 0.8, coat_r = 0.15, env = 1.4,
		ir = 0.95 if sid == "opal" else maxf(irk, 0.12), bd = 0.75 if sid == "malachite" else 0.3 if banded else 0.0, dirt = {h = -0.3, a = 0.35, col = crust, fr = 0.0, isl = 0.08, fb = 0.0}})

## malachite's crust on a piece of its rock: bubbles of every size grown over the rock's top, half sunk in it, each
## its own bands (each its own mesh: the bands centre on it) — the biggest is the find's main
func _mal_crust(col: Color, irk: float, use_rock: Callable, st: Dictionary) -> MeshInstance3D:
	use_rock.call("slab")
	var bm := _botryoid_mat("malachite", col, irk)
	var main: MeshInstance3D = null
	var big := 0.0
	var nb := 24 + int(rng.next() * 12)
	for k in nb:
		# (the highest of a few spots: the crust covers the top, not a ring round its rim with the rock bare inside)
		var p: Vector3 = st.pick.call()
		for t in 3:
			var q: Vector3 = st.pick.call()
			if q.y > p.y: p = q
		var nn: Vector3 = st.nrm.call(p)
		var r := (0.1 + pow(rng.next(), 1.4) * 0.24) if k > 0 else 0.34
		var L := RockKit.lump(rng, {r = r, wave = 0.06, k = 160.0, bumps = [[16, 0.38, 0.2], [50, 0.15, 0.06]], seg = 40})
		var lg: Geo = RockKit.tint_cav(L[0], L[1], 0.6)
		if r >= 0.18: RockKit.chip(lg, _lumpy())
		var m := U.mesh(lg, bm, root, p - nn * r * 0.45, U.eul(0, rng.next() * 6.3, 0))
		if r > big:
			big = r
			main = m
	return main

func _botryoid(sid: String, col: Color, irk: float) -> void:
	var bm := _botryoid_mat(sid, col, irk)
	if sid == "chalcedony":
		# blue chalcedony: waxy, translucent — lit a little from within, fine bands round each bubble, a soft sheen
		bm = SpecMat.make({col = col * 0.85, rough = 0.16, coat = 0.9, coat_r = 0.1, env = 1.5, ir = 0.22, bd = 0.18, emis = col * 0.22,
			dirt = {h = -0.3, a = 0.35, col = SpecMat.lin(0x3a3430), fr = 0.0, isl = 0.08, fb = 0.0}})
	if rng.next() < 0.35:
		# rounded stalagmites crowded together on a crusty foot
		for k in 4 + int(floor(rng.next() * 5)):
			var len := 0.6 + rng.next() * 0.8
			var L := RockKit.lump(rng, {r = 0.5, sx = 0.34 + rng.next() * 0.12, sy = len, sz = 0.34 + rng.next() * 0.12, wave = 0.05, k = 160.0, bumps = [[24, 0.38, 0.2], [70, 0.15, 0.06]], seg = 48})
			var at := Vector3((rng.next() - 0.5) * 0.7, len * 0.35 - 0.2, (rng.next() - 0.5) * 0.5)
			var lg: Geo = RockKit.tint_cav(L[0], L[1], 0.6)
			if sid == "malachite": RockKit.chip(lg, _lumpy())
			U.mesh(lg, bm, root, at, U.eul((rng.next() - 0.5) * 0.35, rng.next() * 6.3, (rng.next() - 0.5) * 0.35))
		var F := RockKit.lump(rng, {r = 0.55, sx = 1.3, sy = 0.35, sz = 1.0, wave = 0.1, k = 160.0, bumps = [[30, 0.32, 0.18], [90, 0.13, 0.06]], seg = 64})
		var fg: Geo = RockKit.tint_cav(F[0], F[1], 0.6)
		if sid == "malachite": RockKit.chip(fg, _lumpy())
		U.mesh(fg, bm, root, Vector3(0, -0.3, 0))
	else:
		var M := RockKit.lump(rng, {r = 0.5, sx = 1.2 + rng.next() * 0.3, sy = 0.75 + rng.next() * 0.25, sz = 1.0, wave = 0.08, k = 160.0, bumps = [[30, 0.38, 0.26], [120, 0.13, 0.07]], seg = 72})
		var mg: Geo = RockKit.tint_cav(M[0], M[1], 0.8)
		if sid == "malachite": RockKit.chip(mg, _lumpy())
		U.mesh(mg, bm, root)
		for k in int(floor(rng.next() * 3)):
			var L := RockKit.lump(rng, {r = 0.16 + rng.next() * 0.12, wave = 0.06, k = 160.0, bumps = [[16, 0.5, 0.26], [40, 0.18, 0.08]], seg = 48})
			U.mesh(RockKit.tint_cav(L[0], L[1], 0.6), bm, root, Vector3(rng.next() - 0.5, rng.next() * 0.6, rng.next() - 0.5).normalized() * 0.5)

## the side every find is shown from (turned 0.6 about y)
const VIEW_DIR := Vector3(-0.5646, 0.0, 0.8253)

# press every vertex past a plane onto it: a sawn and polished face (or a broken one)
func _saw(g: Geo, at: Vector3, p0: Vector3, n: Vector3) -> PackedByteArray:
	var on := PackedByteArray()
	on.resize(g.v.size())
	for i in g.v.size():
		var d := (g.v[i] + at - p0).dot(n)
		if d > 0.0:
			g.v[i] -= n * d
			on[i] = 1
	return on

# one mesh's triangles split in two by which vertices lie on the face: [the face, the rest] (they share the vertices)
func _split(g: Geo, on: PackedByteArray) -> Array:
	var a := Geo.new()
	var b := Geo.new()
	for x: Geo in [a, b]:
		x.v = g.v
		x.col = g.col
	if not g.indexed():
		g.idx.resize(g.v.size())
		for i in g.v.size(): g.idx[i] = i
	for t in range(0, g.idx.size(), 3):
		var f := on[g.idx[t]] == 1 and on[g.idx[t + 1]] == 1 and on[g.idx[t + 2]] == 1
		var x := a if f else b
		x.idx.append_array([g.idx[t], g.idx[t + 1], g.idx[t + 2]])
	return [a, b]

# malachite sawn through and polished (F13): a few bubbly lumps cut by one plane facing the viewer; each lump's
# own bands (bd_k: rings round its middle) show on the face as an "eye", and where two meet one face covers the other
func _sawn(sid: String, col: Color) -> MeshInstance3D:
	# malachite: bright green against near-black green; rhodochrosite: rose against pale pink
	var rho := sid == "rhodochrosite"
	var bc := col.lerp(Color(1, 1, 1), 0.1) if rho else SpecMat.lin(0x1e8e50)
	bc.a = 1.0
	var bm := SpecMat.make({col = bc, rough = 0.1, coat = 0.95, coat_r = 0.05, env = 1.6, ir = 0.12, bd = 0.5 if rho else 0.88,
		dirt = {h = -99.0, a = 0.35, col = col * 0.22, fr = 0.0, isl = 0.08, fb = 0.0}})   # (no crust over the polished face)
	var n := (VIEW_DIR + UP * 0.45).normalized()
	var main: MeshInstance3D = null
	# many lumps, big and small, grown into each other: on the face their bands meet as a crowd of eyes
	var nl := 6 + int(rng.next() * 6)
	# (now and then one nodule sawn through its middle, maybe a small one grown to it: a target of rings — its own
	# stream; the crowd of eyes otherwise)
	var bull := sid == "malachite" and Rng32.new((int(gene_m.get("shroom_seed", 1)) * 2654435761 + 17) % 4294967296).next() < 0.35
	if bull: nl = 1 + int(rng.next() < 0.5)
	var back := Geo.new()
	for k in nl:
		var r := 0.16 + pow(rng.next(), 1.5) * 0.3 if k > 0 else 0.42
		if bull: r = 0.62 if k == 0 else 0.26
		var at := Vector3((rng.next() - 0.5) * 1.15, (rng.next() - 0.5) * 0.7, 0.0) if k > 0 else Vector3.ZERO
		at = at.slide(n) - n * (rng.next() * r * 0.7)
		var L := RockKit.lump(rng, {r = r, wave = 0.06, k = 160.0, bumps = [[16, 0.38, 0.2], [50, 0.15, 0.06]], seg = 64})
		var g: Geo = RockKit.tint_cav(L[0], L[1], 0.6)
		# (knocked about before it was sawn: the chips show as bites out of the polished face's rim)
		if r >= 0.2 and not rho: RockKit.chip(g, _lumpy())
		# (each next lump's face a hair further out: no two faces fight on the same plane)
		var on := _saw(g, at, n * (0.0015 * k), n)
		# (a fin of skin between the saw's face and a chip close by: set down, as RockKit.chip does its own)
		if r >= 0.2 and not rho: RockKit._despike(g)
		for i in g.v.size():
			if on[i] == 1: g.col[i] = Color(1, 1, 1)
		var m := U.mesh(g, bm, root, at)
		if not main: main = m
		for i in g.v.size():
			back.v.append(g.v[i] + at)
			back.col.append(g.col[i])
	# its bubbly back and sides are the ground the shared layer grows on — never the polished face
	_rind_as_rock(main, back, n, -0.22, 0.0)
	return main

# a water-worn pebble (F12): jadeite in its brown weathered rind with a window ground and polished into it;
# carnelian whole and glowing through, faint bands
func _pebble(sid: String, col: Color, _oq: Dictionary) -> MeshInstance3D:
	# lit through like amber (shaders/amber.gdshader): its colour swallowed along the way through, deeper where thick,
	# milky veils of chalcedony in it; jadeite under a weathered skin, a window ground and polished through it
	var jade := sid == "jadeite"
	var main: MeshInstance3D = null
	var np := 1 if jade or rng.next() < 0.55 else 2 + int(rng.next() * 2)
	# how fast the stone swallows red, green and blue: from its own colour (thin it is pale, thick it deepens)
	var sig := Vector3(-log(maxf(col.r, 0.015)), -log(maxf(col.g, 0.015)), -log(maxf(col.b, 0.015))) * (0.75 if jade else 0.37)
	for k in np:
		var f := {host = "amber", seed = int(rng.next() * 9000.0), crust = 0.0, window = jade, cloud = 1.6 if jade else 0.55, spangle = false}
		var g := SpecFlower._resin(rng, f)
		var m := SpecFlower.amber_mat(f, g)
		m.set_shader_parameter("sigma", sig)
		m.set_shader_parameter("light_col", Vector3(0.95, 1.0, 0.95) if jade else Vector3(1.0, 0.88, 0.72))
		m.set_shader_parameter("flow_k", 0.0 if jade else 0.15)
		m.set_shader_parameter("debris_k", 0.0)
		m.set_shader_parameter("bubble_k", 0.0)
		m.set_shader_parameter("dirt_k", 0.1 if jade else 0.2)
		m.set_shader_parameter("spangle_k", 0.0)
		if jade:
			# the boulder's skin: ochre and rust-brown, crazed, the polished window through it to the green
			m.set_shader_parameter("crust_k", 0.7 + rng.next() * 0.15)
			m.set_shader_parameter("crust_lo", Vector3(0.045, 0.028, 0.012))
			m.set_shader_parameter("crust_hi", Vector3(0.19, 0.11, 0.045))
			m.set_shader_parameter("base_k", 0.6)
		var holder := Node3D.new()
		root.add_child(holder)
		var face := (VIEW_DIR + UP * (0.7 if jade else 0.3)).normalized()
		var turn := Basis(quat_to_l(Vector3.BACK, face)) * Basis(Vector3.BACK, (rng.next() - 0.5) * 1.2)
		var at := Vector3.ZERO if k == 0 else Vector3((rng.next() - 0.5) * 1.3, -0.12, (rng.next() - 0.5) * 0.7)
		var sz := (0.62 if jade else 0.42) * (1.0 if k == 0 else 0.55 + rng.next() * 0.3)
		holder.transform = Transform3D(turn * Basis.from_scale(Vector3.ONE * sz), at)
		var mi := U.mesh(g, m, holder)
		if not main: main = mi
	return main

# jadeite (F12): a jewel grown into rough rock — a lens of jade sunk in the stone, its top ground flat and polished,
# lit from within: milky, glowing apple-green (or lavender, or snow-white), the rough rock round it for contrast
func _jade(col: Color, use_rock: Callable, st: Dictionary, gs: float) -> MeshInstance3D:
	var rk: MeshInstance3D = use_rock.call("chunk")
	var p: Vector3 = st.pick.call()
	for t in 12:
		var q: Vector3 = st.pick.call()
		if (st.nrm.call(q) as Vector3).dot(VIEW_DIR) + q.y > (st.nrm.call(p) as Vector3).dot(VIEW_DIR) + p.y: p = q
	var nn: Vector3 = st.nrm.call(p)
	var f := {host = "amber", seed = int(rng.next() * 9000.0), crust = 0.0, window = true, cloud = 0.0, spangle = false}
	var g := SpecFlower._resin(rng, f)
	# its pattern drawn in the stone's own space (shaders/jade.gdshader), in one of the ways jadeite comes (own stream):
	# imperial — vivid green all through; moss in snow — white with green patches and veins; lavender or icy white with
	# flecks of green
	var bc := col
	var green := SpecMat.lin(0x2e9a52)
	var r3 := Rng32.new(int(rng.next() * 100000.0))
	var lum := bc.get_luminance()
	var style := 0 if lum < 0.15 and r3.next() < 0.6 else 1 if lum < 0.15 else 2
	var cb: Color
	var cp: Color
	var cv: Color
	var pk := 0.4
	match style:
		0:
			cb = bc
			cp = bc.lerp(Color(0.25, 0.85, 0.35), 0.35)
			cv = bc * 0.45
			pk = 0.35
		1:
			cb = Color(0.72, 0.8, 0.72)
			cp = green.lerp(bc, 0.3)
			cv = green * 0.6
			pk = 0.5
		_:
			# (lavender soft and milky, not violet)
			cb = bc.lerp(Color(0.85, 0.85, 0.9), 0.35) if bc.b > bc.g else bc
			cp = green
			cv = green * 0.7
			pk = 0.22
	var m := ShaderMaterial.new()
	m.shader = JADE
	m.set_shader_parameter("c_base", cb)
	m.set_shader_parameter("c_patch", cp)
	m.set_shader_parameter("c_vein", cv)
	m.set_shader_parameter("patch_k", pk)
	m.set_shader_parameter("vein_k", 0.3 + r3.next() * 0.5)
	m.set_shader_parameter("glow_k", 0.32 * (1.0 - 0.6 * cb.get_luminance()))
	m.set_shader_parameter("seed", r3.next() * 40.0)
	m.set_shader_parameter("scale", 0.9 + r3.next() * 0.5)
	var zw := -INF
	for v in g.v: zw = maxf(zw, v.z)
	var face := (nn * 0.55 + VIEW_DIR * 0.45 + UP * 0.25).normalized()
	var sz := (0.26 + rng.next() * 0.08) * gs
	var holder := Node3D.new()
	root.add_child(holder)
	# sunk so only the polished top and a little of its rounded shoulder stand out of the rock
	holder.transform = Transform3D(Basis(quat_to_l(Vector3.BACK, face)) * Basis(Vector3.BACK, rng.next() * TAU) * Basis.from_scale(Vector3.ONE * sz), p - face * zw * sz * 0.7)
	U.mesh(g, m, holder)
	root.set_meta("glow", (root.get_meta("glow", col) as Color).lerp(col, 0.6))
	# (nothing of the shared layer grows up through the jade: the rock under it is no ground)
	var jc := holder.position
	var jr := 1.4 * sz
	keep_out.append([jc, jr])
	var pick0: Callable = st.pick
	st.pick = func() -> Vector3:
		var q: Vector3 = pick0.call()
		for t in 12:
			if q.distance_to(jc) > jr: break
			q = pick0.call()
		return q
	var hol: Array = st.get("hollows", [])
	st.hollows = hol.filter(func(h: Array) -> bool: return (h[0] as Vector3).distance_to(jc) > jr)
	return rk

const FACE := preload("res://shaders/face.gdshader")
const OPAL_SEAM := preload("res://shaders/opal_seam.gdshader")

## precious opal's own play of colour (shaders/opal_seam.gdshader): its body and its fire, as the photographs have
## them: most stones blue and green, some a full harlequin with red, some green and gold, a few red-orange
## (body: -1 by chance, else 0 black, 1 milky, 2 crystal)
func _opal_mat(r: Rng32, scale: float, body := -1) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = OPAL_SEAM
	var b := body if body >= 0 else int(Stones.pick_w([[0, 4.0], [1, 2.0], [2, 1.5]], r))
	m.set_shader_parameter("opal_body", b)
	var fire: Array = Stones.pick_w([[[0.66, 0.16], 5.0], [[0.5, 0.48], 2.5], [[0.4, 0.14], 1.5], [[0.12, 0.16], 1.0]], r)
	m.set_shader_parameter("fire_h", float(fire[0]) + (r.next() - 0.5) * 0.08)
	m.set_shader_parameter("fire_spread", float(fire[1]))
	m.set_shader_parameter("fire_scale", scale)
	m.set_shader_parameter("soft", 0.7 if b == 1 else 0.1)
	m.set_shader_parameter("seed", r.next() * 40.0)
	m.set_shader_parameter("flow_k", 1.0 if gene_m.fx == "dragonfire" else 0.0)
	return m
const JADE := preload("res://shaders/jade.gdshader")

## a nodule's rind as the rock the shared layer grows on (lichen, moss, mushrooms, puffs): the points of it that face
## up or towards the viewer, well off the face (plane n·p = d)
func _rind_as_rock(mi: MeshInstance3D, g: Geo, n: Vector3, d: float, margin := 0.05) -> void:
	var top := []
	var hol := []
	for i in g.v.size():
		var v := g.v[i]
		if v.dot(n) > d - margin: continue
		var o := v.normalized()
		if o.dot(UP) > 0.1 or o.dot(VIEW_DIR) > 0.35:
			top.append(v)
			if g.col.size() > i and g.col[i].g > 0.55: hol.append([v, o])
	if top.is_empty(): return
	st_ref.rocky = true
	st_ref.rock = mi
	st_ref.pick = func() -> Vector3: return top[int(rng.next() * top.size())]
	st_ref.nrm = func(w: Vector3) -> Vector3: return w.normalized()
	st_ref.hollows = hol

## the face shader (shaders/face.gdshader) set to a face's own plane
func _face_mat(mode: int, fc: Vector3, n: Vector3, r: float) -> ShaderMaterial:
	var t1 := n.cross(UP if absf(n.y) < 0.95 else Vector3.RIGHT).normalized()
	var m := ShaderMaterial.new()
	m.shader = FACE
	m.set_shader_parameter("mode", mode)
	m.set_shader_parameter("face_c", fc)
	m.set_shader_parameter("face_t1", t1)
	m.set_shader_parameter("face_t2", n.cross(t1))
	m.set_shader_parameter("face_r", maxf(r, 0.01))
	m.set_shader_parameter("face_n", n)
	m.set_shader_parameter("face_d", fc.dot(n))
	m.set_shader_parameter("seed", rng.next() * 50.0)
	return m

# a septarian nodule sawn in half (F18): clay cells crazed by golden calcite veins — drawn pixel by pixel in the face
# shader — and a dark crack at its heart where the species' crystals stand: "dragon stone"
func _septaria(crystal: Callable, st: Dictionary) -> MeshInstance3D:
	# one half of the egg, built facing +z: a plump nodule sawn through near its middle
	var L := RockKit.lump(rng, {r = 0.6, sx = 1.25 + rng.next() * 0.2, sy = 0.95, sz = 1.0, wave = 0.12, k = 80.0,
		bumps = [[8, 0.8, 0.12], [30, 0.3, 0.05]], seg = 110})
	var g: Geo = L[0]
	var cav: PackedFloat32Array = L[1]
	g.col.resize(g.v.size())
	var n := (Vector3.BACK + UP * 0.25).normalized()
	var off := (rng.next() - 0.5) * 0.08
	var on := _saw(g, Vector3.ZERO, n * off, n)
	var fc := n * off
	var rmax := 0.0
	for i in g.v.size():
		if on[i] == 1: rmax = maxf(rmax, (g.v[i] - fc).length())
	# the cave at its heart, where the cracks meet: deep, lined with crystals
	var hole := rmax * (0.24 + rng.next() * 0.1)
	var spots := []
	for i in g.v.size():
		if on[i] != 1:
			g.col[i] = Color(0.0, cav[i] if cav.size() > i else 0.5, 0.0, 1.0)
			continue
		var q := g.v[i] - fc
		# (the cave's outline wanders)
		var ang := atan2(q.dot(n.cross(UP).normalized()), q.dot(UP))
		var hr := hole * (1.0 + 0.25 * sin(ang * 3.0 + off * 50.0) + 0.12 * sin(ang * 7.0))
		var rr := q.length()
		var hk := 1.0 - smoothstep(hr * 0.8, hr, rr)
		if rr < hr:
			g.v[i] -= n * rmax * 0.3 * sqrt(1.0 - pow(rr / hr, 2.0))
			spots.append([g.v[i], rr / hr])
		g.col[i] = Color(1.0, rr / rmax, hk, 1.0)
	var face := _face_mat(0, fc, n, rmax)
	face.set_shader_parameter("scan", load("res://assets/textures/rock_surface/rock_surface_diff_1k.jpg"))
	face.set_shader_parameter("rind_scan", SpecMat.scan_tex(1, "diff"))
	# its colours (own stream): the classic brown clay with yellow calcite, black clay with white, or honey-red
	var kind := int(Stones.pick_w([[0, 5.0], [1, 2.5], [2, 1.5]], Rng32.new(int(rng.next() * 100000.0))))
	var KINDS := [[0x7a6a58, 0x3a3028, 0xe8b040, 0x6a5440], [0x34302c, 0x141210, 0xf0ece0, 0x3a3430], [0x9a5a34, 0x4a2214, 0xf4c868, 0x6a4028]]
	var kd: Array = KINDS[kind]
	for kv in [["c_a", 0], ["c_b", 1], ["c_vein", 2], ["c_rind", 3]]:
		var c := Color.hex(int(kd[kv[1]]) << 8 | 0xff)
		face.set_shader_parameter(kv[0], c)
	# one half, or both side by side like an opened book (one pattern, mirrored)
	var pair := rng.next() < 0.35
	var view := Basis(UP, -0.6)
	var xr := view * Vector3.RIGHT
	# (tipped back and turned a little, so the rind's thickness shows under the face — a stone, not a tile)
	var halves := [Transform3D(view * Basis(UP, 0.35 * (1.0 if rng.next() < 0.5 else -1.0)) * Basis(Vector3.RIGHT, -0.5), Vector3(0, 0.05, 0))]
	# the other half: the same mesh mirrored (its pattern the mirror image, as the two halves of one stone are)
	var gm := Geo.new()
	gm.col = g.col
	for i in g.v.size(): gm.v.append(Vector3(-g.v[i].x, g.v[i].y, g.v[i].z))
	if g.indexed():
		for t in range(0, g.idx.size(), 3): gm.idx.append_array([g.idx[t], g.idx[t + 2], g.idx[t + 1]])
	if pair:
		halves = [Transform3D(view * Basis(UP, 0.55) * Basis(Vector3.RIGHT, -0.45) * Basis.from_scale(Vector3.ONE * 0.72), -xr * 0.62),
			Transform3D(view * Basis(UP, -0.55) * Basis(Vector3.RIGHT, -0.45) * Basis.from_scale(Vector3.ONE * 0.72), xr * 0.62)]
	var main: MeshInstance3D = null
	var cal := SpecMat.make({col = Color.hex(int(kd[2]) << 8 | 0xff).srgb_to_linear(), flat = true, glass = true, ir = 0.15, rf = 0.3, thick = 1.2,
		frost = 0.12, prio = 2, tint_body = 0.55, tint_glow = 0.25})
	for hi in halves.size():
		var T: Transform3D = halves[hi]
		var mi := U.mesh(gm if hi == 1 else g, face, root)
		mi.transform = T
		# (on the mirrored half, its spots and their directions mirrored too)
		var mx := Basis.from_scale(Vector3(-1, 1, 1)) if hi == 1 else Basis()
		T = T * Transform3D(mx, Vector3.ZERO)
		if not main:
			main = mi
			var wg := Geo.new()
			for i in g.v.size():
				wg.v.append(T * g.v[i])
			wg.col = g.col
			_rind_as_rock(mi, wg, (T.basis * n).normalized(), (T * fc).dot((T.basis * n).normalized()), 0.12)
		if spots.is_empty(): continue
		# the cave's lining: honey dogtooth calcite, small and many, pointing in towards the middle
		var k2 := 0
		for k in 26 + int(rng.next() * 16):
			var sp: Array = spots[int(rng.next() * spots.size())]
			var p: Vector3 = sp[0]
			var dir := (n * (1.0 - float(sp[1])) * 1.4 + (fc - p).normalized() * 0.6 + _rv() * 0.5).normalized()
			var f := pow(rng.next(), 1.6)
			var c: MeshInstance3D = crystal.call(0.12 + f * 0.16, 0.16 + f * 0.14, T * (p - n * 0.01), (T.basis * dir).normalized(), {habit = "scaleno"}, cal)
			k2 += 1
		# and the species' own crystals, a few, standing out of the cave
		for k in 2 + int(rng.next() * 3):
			var sp: Array = spots[int(rng.next() * spots.size())]
			var p: Vector3 = sp[0]
			var dir := (n * 1.3 + (p - fc).normalized() * 0.5 + _rv() * 0.4).normalized()
			crystal.call(0.2 + rng.next() * 0.16, 0.3 + rng.next() * 0.16, T * (p - n * 0.02), (T.basis * dir).normalized())
	return main

# a flint nodule out of the chalk, broken open (F11): a knobbly lump in its white chalk rind (the limestone scan), the
# break glassy black, conchoidal rings in the light (face shader); half of them hollow, a cave of real quartz crystals
func _flint(col: Color, crystal: Callable, st: Dictionary) -> MeshInstance3D:
	var L := RockKit.lump(rng, {r = 0.55, sx = 1.35 + rng.next() * 0.25, sy = 0.8, sz = 1.0, wave = 0.25, k = 120.0,
		bumps = [[9, 0.7, 0.3], [40, 0.25, 0.1]], seg = 150})
	var g: Geo = L[0]
	var cav: PackedFloat32Array = L[1]
	g.col.resize(g.v.size())
	var n := (VIEW_DIR + UP * 0.9 + Vector3((rng.next() - 0.5) * 0.5, 0, 0)).normalized()
	var mx := -INF
	for v in g.v: mx = maxf(mx, v.dot(n))
	var off := mx * (0.55 + rng.next() * 0.15)
	var on := _saw(g, Vector3.ZERO, n * off, n)
	var fc := Vector3.ZERO
	var nf := 0
	for i in g.v.size():
		if on[i] == 1:
			fc += g.v[i]
			nf += 1
	fc /= maxf(1.0, float(nf))
	var rmax := 0.0
	for i in g.v.size():
		if on[i] == 1: rmax = maxf(rmax, (g.v[i] - fc).length())
	var hollow := rng.next() < 0.5
	var R := rmax * (0.4 + rng.next() * 0.15)
	var dep := R * (0.6 + rng.next() * 0.3)
	var lining := []
	var chalk := SpecMat.lin(0xe6e0d0)
	for i in g.v.size():
		if on[i] != 1:
			g.col[i] = Color(0.0, cav[i] if cav.size() > i else 0.5, 0.0, 1.0)
			continue
		var rr := (g.v[i] - fc).length()
		var hk := 0.0
		if hollow and rr < R:
			var t := rr / R
			g.v[i] -= n * dep * (1.0 - t * t)
			hk = 1.0 - smoothstep(0.8, 1.0, t)
			if t < 0.85: lining.append(g.v[i])
		g.col[i] = Color(1.0, 0.0, hk, 1.0)
	# how deep in from the break's edge each point of it lies: the bands follow the nodule's outline
	var edge := []
	for i in g.v.size():
		if on[i] == 1 and (g.v[i] - fc).length() > rmax * 0.55: edge.append(g.v[i])
	var dmax := 0.001
	var dist := PackedFloat32Array()
	dist.resize(g.v.size())
	for i in g.v.size():
		if on[i] != 1: continue
		var best := INF
		for k in range(0, edge.size(), 3):
			best = minf(best, g.v[i].distance_squared_to(edge[k]))
		dist[i] = sqrt(best) if edge.size() else 0.0
		dmax = maxf(dmax, dist[i])
	for i in g.v.size():
		if on[i] == 1: g.col[i].g = clampf(dist[i] / dmax, 0.0, 1.0)
	var face := _face_mat(1, fc, n, rmax)
	var bc := col
	# its kind (own stream): striped like the Krzemionki flint, honey-translucent round a black heart, jet-black, or red
	var kind := int(Stones.pick_w([[0, 3.5], [1, 2.5], [2, 2.5], [3, 1.5]], Rng32.new(int(rng.next() * 100000.0))))
	var KINDS := [[0x1a1a20, 0x6a6a70, 0xc8c8cc, 0.85, 26.0], [0x120a06, 0x8a4a14, 0xe0a040, 0.75, 16.0],
		[0x0c0c10, 0x34383e, 0x50545a, 0.25, 18.0], [0x2a0c08, 0xa83818, 0xe0a070, 0.7, 20.0]]
	var kd: Array = KINDS[kind]
	var ca := SpecMat.lin(int(kd[0]))
	var cb := SpecMat.lin(int(kd[1]))
	var cc := SpecMat.lin(int(kd[2]))
	face.set_shader_parameter("c_a", Vector3(ca.r, ca.g, ca.b))
	face.set_shader_parameter("c_b", Vector3(cb.r, cb.g, cb.b))
	face.set_shader_parameter("c_vein", Vector3(cc.r, cc.g, cc.b))
	face.set_shader_parameter("band_k", float(kd[3]))
	face.set_shader_parameter("band_f", float(kd[4]))
	var a0 := rng.next() * TAU
	face.set_shader_parameter("hit", Vector2(cos(a0), sin(a0)) * (0.6 + rng.next() * 0.3))
	face.set_shader_parameter("rind_scan", SpecMat.scan_tex(0, "diff"))
	face.set_shader_parameter("c_rind", Color(0.8, 0.76, 0.67))
	var main := U.mesh(g, face, root)
	_rind_as_rock(main, g, n, fc.dot(n), 0.1)
	if lining.size():
		# the geode inside: real quartz points of every size, clear glass, pointing out of the cave
		var qm := SpecMat.make({col = Color(1, 1, 1), flat = true, glass = true, ir = 0.25, rf = 0.3, thick = 1.2, frost = 0.04, holo = 0.15, seed = 5.0, prio = 2})
		for k in 18 + int(rng.next() * 14):
			var p: Vector3 = lining[int(rng.next() * lining.size())]
			var out := (n * 1.2 + (fc - p).normalized() * 0.0 + _rv() * 0.9).normalized()
			var f := pow(rng.next(), 1.8)
			crystal.call(0.12 + f * 0.22, 0.18 + f * 0.2, p - out * 0.01, out, {habit = "prism", blunt = false}, qm)
	return main

# hyalite (F14): glassy beads and drops of water-clear opal over a dark rock, clustered, glowing green
func _beads(col: Color, use_rock: Callable, st: Dictionary, gs: float) -> MeshInstance3D:
	var rk: MeshInstance3D = use_rock.call("chunk")
	var bc := col
	bc.a = 1.0
	# (water-clear: the dark rock seen through each drop, a hard glint on top, a breath of green)
	var gm := SpecMat.make({col = bc, glass = true, thick = 0.45, ir = 0.05, prio = 2, tint_body = 0.1, tint_glow = 0.75})
	var spots := []
	for k in 4 + int(rng.next() * 4):
		var best: Vector3 = st.pick.call()
		for t in 8:
			var q: Vector3 = st.pick.call()
			if (st.nrm.call(q) as Vector3).dot(VIEW_DIR) + q.y > (st.nrm.call(best) as Vector3).dot(VIEW_DIR) + best.y: best = q
		spots.append(best)
	var beads := []
	for p: Vector3 in spots:
		keep_out.append([p, 0.22 * gs])
		var nn: Vector3 = st.nrm.call(p)
		var t1 := nn.cross(UP if absf(nn.y) < 0.9 else Vector3.RIGHT).normalized()
		var t2 := nn.cross(t1)
		for k in 6 + int(rng.next() * 16):
			var a := rng.next() * TAU
			var rr := sqrt(rng.next()) * 0.16 * gs
			var s := (0.022 + pow(rng.next(), 2.0) * 0.08) * gs
			var q := p + (t1 * cos(a) + t2 * sin(a)) * rr
			beads.append(Transform3D(Basis(quat_to_l(UP, nn)) * Basis.from_scale(Vector3(s, s * 0.62, s)), q + nn * s * 0.2))
	U.inst(Geo.sphere(1, 18, 12), gm, beads.size(), func(i: int) -> Array: return [beads[i], Color(1, 1, 1)], root)
	return rk

# precious opal (F15; 19.11 after photographs): mostly boulder opal — a seam of it across the broken face of brown
# ironstone, the fire a mosaic of patches, with a few smaller patches about; or a piece of black opal, its window
# polished; or a milky "jelly" opal, soft blobs of colour in its white
func _opal_seam(_col: Color, use_rock: Callable, st: Dictionary, gs: float, seed_v: int) -> MeshInstance3D:
	var r2 := Rng32.new((seed_v * 3266489917 + 59) % 4294967296)
	var show: String = Stones.pick_w([["boulder", 6.0], ["black", 2.5], ["jelly", 2.0]], r2)
	if show != "boulder":
		# a loose piece: a rounded lump of opal, its face to the viewer — black with fire, or milky
		var gm2 := _opal_mat(r2, 4.5 if show == "black" else 2.4, 0 if show == "black" else 1)
		# (a domed piece, smooth as a polished stone: a lumpy potato in a mosaic read as a stained-glass ball)
		var L2 := RockKit.lump(rng, {r = 0.8, sx = 1.0, sy = 0.45, sz = 0.72, wave = 0.12, k = 40.0, bumps = [[4, 0.8, 0.07]], seg = 48})
		var holder := Node3D.new()
		root.add_child(holder)
		var face := (VIEW_DIR + UP * 0.6).normalized()
		holder.transform = Transform3D(Basis(quat_to_l(UP, face)) * Basis(UP, rng.next() * TAU) * Basis.from_scale(Vector3.ONE * 0.62 * gs), Vector3.ZERO)
		var pm := U.mesh(L2[0], gm2, holder)
		pm.set_meta("col", true)
		return pm
	var rk: MeshInstance3D = use_rock.call("chunk")
	var gm := _opal_mat(r2, 9.0, int(Stones.pick_w([[0, 3.0], [2, 1.0]], r2)))
	# the vein: the rock's own skin a hair out, shown only where a wavy layer of opal crosses it (the shader cuts
	# the rest away) — it runs over the stone as a band, pinching and swelling; sometimes a second, thinner one
	var rg: Geo = rk.get_meta("geo")
	var vg := Geo.new()
	vg.v = rg.v.duplicate()
	vg.idx = rg.idx.duplicate()
	var nr := rg.normals()
	var bb := rg.aabb()
	var sz := (bb.size.x + bb.size.y + bb.size.z) / 3.0
	for i in vg.v.size(): vg.v[i] += nr[i] * sz * 0.004
	var c := bb.get_center()
	# (19.11, "just a belt") mostly the stone broken along its seam: a flat face to the viewer, the opal over it in
	# a ragged field with islands of ironstone left in it; else the seam through the stone, swelling and pinching
	var face := r2.next() < 0.65
	var bn := (UP + Vector3(r2.next() - 0.5, 0, r2.next() - 0.5) * 0.9).normalized()
	var bd := bn.dot(c) + (r2.next() - 0.35) * bb.size.y * 0.3
	if face:
		bn = (rk.transform.basis.inverse() * (VIEW_DIR + UP * 0.45 + Vector3(r2.next() - 0.5, 0, r2.next() - 0.5) * 0.3)).normalized()
		var far := -INF
		for p in rg.v: far = maxf(far, p.dot(bn))
		bd = far - sz * (0.14 + r2.next() * 0.08)
		# the broken face: everything beyond the plane pressed (almost) flat onto it, rock and seam alike
		var fl := FastNoiseLite.new()
		fl.seed = int(r2.next() * 100000)
		fl.frequency = 2.5 / sz
		for g2: Geo in [rg, vg]:
			for i in g2.v.size():
				var dd := g2.v[i].dot(bn) - bd
				if dd > 0.0: g2.v[i] -= bn * (dd * 0.92 - fl.get_noise_3dv(g2.v[i]) * sz * 0.01)
		for i in vg.v.size(): vg.v[i] += bn * sz * 0.003 if vg.v[i].dot(bn) > bd - sz * 0.02 else Vector3.ZERO
		if rk.mesh: rk.mesh = rg.to_mesh()   # (a rock's mesh is made in _finish, with its rock coordinates: see SpecFossil)
		keep_out.append([rk.transform * (c + bn * (bd - bn.dot(c))), sz * 0.6])
	gm.set_shader_parameter("band_on", 1.0)
	gm.set_shader_parameter("band_face", 1.0 if face else 0.0)
	gm.set_shader_parameter("band_n", bn)
	gm.set_shader_parameter("band_d", bd)
	gm.set_shader_parameter("band_w", sz * (0.05 + r2.next() * 0.04))
	if not face and r2.next() < 0.5:
		var bn2 := (bn + Vector3(r2.next() - 0.5, r2.next() - 0.5, r2.next() - 0.5) * 1.2).normalized()
		gm.set_shader_parameter("band2_n", bn2)
		gm.set_shader_parameter("band2_d", bn2.dot(c) + (r2.next() - 0.5) * bb.size.y * 0.4)
	var vm := U.mesh(vg, gm, root)
	vm.transform = rk.transform
	vm.set_meta("col", true)
	vm.set_meta("seam", true)
	vm.set_meta("no_crumbs", true)
	return vm

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
	# (19.11) its scan laid on in its own space: the shell is turned to show its face, and the scan's three sides were
	# taken in the find's space but weighed by the shell's own normals — on part of it the scan ran along the surface,
	# stretched into streaks (every geode)
	outer_mesh.set_meta("local", true)
	# the cave's wall: the warped shell itself, a little in (a round bowl inside poked out through the shell where it
	# was warped in, and lit pale it read as a sheet of glass over the cave); dark, so what grows on it shows
	var wr := []
	for i in range(0, outer.v.size(), 3):
		if outer.v[i].length() > 0.05: wr.append([outer.v[i].normalized(), outer.v[i].length()])
	var wall_r := func(d: Vector3) -> float:
		var best := -2.0
		var r := 0.9
		for e: Array in wr:
			var dd := d.dot(e[0])
			if dd > best:
				best = dd
				r = float(e[1])
		return r * 0.9
	var ic := col.lerp(Color(0.12, 0.13, 0.15), 0.8) * 0.25
	ic.a = 1.0
	var inner_g := Geo.new()
	inner_g.v = outer.v.duplicate()
	inner_g.idx = outer.idx.duplicate()
	for i in inner_g.v.size(): inner_g.v[i] *= 0.9
	U.mesh(inner_g, SpecMat.make({col = ic, rough = 0.85, spec = 0.2, side = "back"}), shell)
	# a glittering carpet of tiny crystals over the cave wall
	var place := func(k: int) -> Array:
		var d := Vector3(rng.next() - 0.5, rng.next() * 0.98 + 0.02, rng.next() - 0.5).normalized()
		var e := Vector3(rng.next() * 3, rng.next() * 3, rng.next() * 3)
		var s := 0.008 + rng.next() * 0.014
		var c := col * (0.6 + rng.next() * 0.5)
		c.a = 1.0
		# (19.11) on the wall itself — a point of the wall's own mesh near that way: the wall's radius guessed from
		# the nearest of a sparse set left some floating in the cave
		var vi := int(rng.next() * inner_g.v.size()) % inner_g.v.size()
		var wp: Vector3 = inner_g.v[vi]
		if wp.length() < 0.05: wp = d * (wall_r.call(d) as float)
		return [_rot_inst(wp * 0.995, e, Vector3(s, s * 1.7, s)), c]
	U.inst(Geo.octa(1), SpecMat.make({rough = 0.08, coat = 1.0, flat = true, env = 2.4}), 800, place, shell)
	# agate rind: fine bands from the dark outer crust through grey and milky layers to a hint of the stone's own colour
	var hue := SpecMat.get_hsl(Color(sp.c)).x
	var ag: Array = st.agate
	var band := func(t: float) -> Color:
		var r := t * 40.0
		var j := sin(r * 2.1) * 0.5 + sin(r * 0.37) * 0.5
		if ag.size():
			# the species' own agate (Svalbard: blue): bands of its colours, uneven widths, a dark crust outside
			if t < 0.12: return SpecMat.hsl(0.07, 0.25, 0.14 + t)
			var u := fposmod(t * 5.3 + sin(t * 23.0) * 0.18, float(ag.size()))
			return Color.hex(int(ag[int(u)]) << 8 | 0xff).lerp(Color.hex(int(ag[(int(u) + 1) % ag.size()]) << 8 | 0xff), smoothstep(0.7, 1.0, fposmod(u, 1.0)))
		# (19.11) an opal egg: a thin rind of white and grey common opal round its fire; chrysocolla: turquoise bands
		if _sid == "opal":
			# (brown ironstone round it, mottled, and only at its inner edge a thin translucent milky line of common
			# opal: a wide even grey ring read as plastic)
			if t < 0.86: return SpecMat.hsl(0.06 + j * 0.015, 0.38 + j * 0.1, 0.16 + t * 0.12 + j * 0.05)
			return SpecMat.hsl(0.58, 0.06, 0.42 + (t - 0.86) * 1.2)
		if _sid == "chrysocolla":
			if t < 0.18: return SpecMat.hsl(0.07, 0.3, 0.14 + t)
			return SpecMat.hsl(0.52 + j * 0.03, 0.6 + j * 0.15, 0.18 + t * 0.18 + j * 0.06)
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
	# (an opal egg's rind: its ironstone, the rock's own scan over the bands — smooth it read as chocolate)
	var rim_m := SpecMat.make({col = Color(1, 1, 1), rough = 0.9, flat = true, side = "double", dirt = {h = 99.0, a = 0.45, col = ocol, fr = 0.0, scan = RockKit.SCAN_OF[rtype]}}) if _sid == "opal" else SpecMat.make({col = Color(1, 1, 1), rough = 0.8, flat = true, side = "double"})
	var rim := U.mesh(rg, rim_m, shell)
	rim.set_meta("no_crumbs", true)   # (its colour is in its points: crumbs of it came out white)
	rim.set_meta("local", true)
	if _sid == "opal":
		rim_m.set_meta("wet_rock", true)   # (SpecView._wet: the rind darkens as wet stone does)
		outer_mesh.material_override.set_meta("wet_rock", true)
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
	# an agate (SpecLooks agate) is lined with little clear quartz points, only a breath of its colour at their tips
	var inner: String = "prism" if (st.agate as Array).size() else habit
	if inner != habit:
		c_root = Color(0.95, 0.96, 0.98)
		c_tip = Color(0.95, 0.96, 0.98).lerp(col, 0.35)
	var prismy := elongated or habit == "cube"
	var main: MeshInstance3D = null
	if _sid == "opal":
		# (19.11) an opal egg broken open: no cave — the half filled to its lip with precious opal, its broken face
		# polished, the fire over the whole of it (a cave of a few bubbles in one corner read as unfinished)
		var om2 := _opal_mat(rng, 3.6, int(Stones.pick_w([[2, 3.0], [1, 2.0], [0, 1.5]], rng)))
		var raw := rng.next() < 0.5
		# the face in the mesh itself (19.11: a flat lid with a picture on it): a dome, and — on a raw break — a few
		# shallow conchoidal scoops, each a smooth dish with a lip, overlapping; polished, only the dome and a soft
		# unevenness
		var scoops := []
		for k in (3 + int(rng.next() * 3)) if raw else 0:
			scoops.append([Vector2(rng.next() - 0.5, rng.next() - 0.5) * 1.0, 0.18 + rng.next() * 0.22, 0.02 + rng.next() * 0.025])
		var acc_e: Array = gene_m.get("accents", [])
		# a pocket in its heart (rare): a bowl in the middle of the face, lined with little clear crystals
		var pr := (0.2 + rng.next() * 0.08) if "pocket" in acc_e else 0.0
		var fg := Geo.new()
		var nr := 24
		var na := 96
		for ri in nr + 1:
			for ai in na + 1:
				var a := TAU * ai / na
				var edge: Vector3 = outer.v[32 * 65 + roundi(fposmod(PI - a, TAU) / TAU * 64.0)]
				# (over the inner part of the rind: a thin rind round it, not a wide white ring)
				var u := float(ri) / nr
				var rr := Vector2(edge.x, edge.z).length() * 0.9 * u
				var p2 := Vector2(cos(a) * rr, sin(a) * rr)
				# (sunk a little under the rind at its edge: the opal seen into the stone, not a lid laid on it)
				var z := -0.012 + (0.09 if not raw else 0.06) * (1.0 - u * u)
				for sc: Array in scoops:
					var dd := p2.distance_to(sc[0]) / float(sc[1])
					if dd < 1.25:
						# a dish, its rim raised a hair: the light catches the ridge between two scoops
						z -= float(sc[2]) * (maxf(0.0, 1.0 - dd * dd) - 0.25 * exp(-pow((dd - 1.0) / 0.12, 2.0)))
				z *= smoothstep(1.0, 0.85, u) * 0.85 + 0.15   # (meets the rind at its edge)
				if pr > 0.0 and u < pr * 1.15:
					z -= 0.2 * pow(maxf(0.0, 1.0 - pow(u / (pr * 1.15), 2.0)), 0.6)
				fg.v.append(Vector3(p2.x, p2.y, z))
				fg.col.append(Color(u, 0, 0))
		for ri in nr:
			for ai in na:
				var i0 := ri * (na + 1) + ai
				var i1 := i0 + na + 1
				fg.idx.append_array([i0, i1, i0 + 1, i0 + 1, i1, i1 + 1])
		om2.set_shader_parameter("egg_on", 1.0)
		# half broken raw (conchoidal ripples), half polished
		om2.set_shader_parameter("egg_rough", 1.0 if raw else 0.0)
		om2.set_shader_parameter("egg_milk", Color(0.52, 0.52, 0.5) if rng.next() < 0.6 else Color(0.56, 0.47, 0.37))
		om2.set_shader_parameter("egg_pocket", pr)
		# hurt by the dig: the opal crazed — a net of fine cracks over its face, wider and more of it the worse
		om2.set_shader_parameter("egg_crack", float(hurt.get("k", 0.0)))
		var glow := "inner_light" in acc_e
		om2.set_shader_parameter("egg_glow", 1.0 if glow else 0.0)
		main = U.mesh(fg, om2, shell)
		main.rotation.x = PI / 2
		main.set_meta("local", true)
		if pr > 0.0:
			# the pocket's lining: little clear points standing out of its bowl
			var spots := []
			for i in fg.v.size():
				# (strewn, not on the mesh's rings: on its points they stood in circles, a fingerprint)
				if float(fg.col[i].r) < pr * 0.9 and rng.next() < 0.5:
					spots.append(fg.v[i] + Vector3((rng.next() - 0.5) * 0.06, (rng.next() - 0.5) * 0.06, -0.006))
			# (grey glassy points, few: white and dense they read as a blob of snow)
			var pm := SpecMat.make({col = Color(0.36, 0.38, 0.42), rough = 0.05, coat = 1.0, flat = true, env = 1.8})
			U.inst(Geo.octa(1), pm, spots.size(), func(i: int) -> Array:
				var dirc := (Vector3.BACK + Vector3(rng.next() - 0.5, rng.next() - 0.5, 0.0) * 0.9).normalized()
				var ss := 0.006 + pow(rng.next(), 2.0) * 0.012
				return [Transform3D(Basis(quat_to_l(UP, dirc)) * Basis.from_scale(Vector3(ss, ss * 2.0, ss)), spots[i] + dirc * ss * 0.3), Color(1, 1, 1)], main)
		if glow:
			# a light inside it: the core glows and lights the rind round it
			var fl := OmniLight3D.new()
			var fh := float(om2.get_shader_parameter("fire_h"))
			fl.light_color = Color.from_hsv(fposmod(fh * 0.8, 1.0), 0.6, 1.0)
			fl.light_energy = 0.9
			fl.omni_range = 1.2
			fl.shadow_enabled = false
			fl.position = Vector3(0, 0, 0.35)
			main.add_child(fl)
	elif habit == "botryoid" and inner == habit:
		# a lumpy species lines its cave with bubbles sunk half into the wall — a lining, not a cave filled with balls
		# of glass. (19.11) Chrysocolla: its whole cave under a turquoise crust, bubbles of every size crowding,
		# a sparkle of tiny clear quartz over them ("gem silica"); the rest: opal's play of colour flashing in them
		var chry := _sid == "chrysocolla"
		# (deep, opaque turquoise: glassy and pale it read as bath foam)
		var bm: Material = SpecMat.make({col = SpecMat.lin(0x0590b0), rough = 0.4, coat = 0.25, coat_r = 0.3, env = 0.5, bd = 0.35, ir = 0.0}) if chry else _opal_mat(rng, 2.5)
		var bub := []
		for k in (820 + int(rng.next() * 200)) if chry else (120 + int(rng.next() * 60)):
			# (kept off the lip and sunk only into the wall's inner half, so none shows through the outside)
			var d := Vector3(rng.next() - 0.5, (rng.next() * 0.86 + 0.14) if chry else (rng.next() * 0.8 + 0.2), rng.next() - 0.5).normalized()
			var s := (0.05 + pow(rng.next(), 2.0) * 0.11) * (0.5 + 0.5 * smoothstep(0.14, 0.35, d.y)) if chry else (0.04 + pow(rng.next(), 2.0) * 0.09)
			bub.append(Transform3D(Basis(quat_to_l(UP, -d)) * Basis.from_scale(Vector3(s, s * 0.55, s)), d * (wall_r.call(d) as float) * 0.97))
		main = U.mesh(Geo.sphere(1, 20, 14), bm, shell)
		main.transform = bub[0]
		main.set_meta("local", true)
		U.inst(Geo.sphere(1, 16, 12), bm, bub.size() - 1, func(i: int) -> Array: return [bub[i + 1], Color(1, 1, 1)], shell)
		if chry:
			# drusy quartz over the crust: tiny clear points on the crowns of the bubbles, glittering
			var spk := []
			for t0: Transform3D in bub:
				var top := t0.origin + t0.basis.y * 0.98
				for q in 2 + int(rng.next() * 3):
					var jit := (t0.basis.x * (rng.next() - 0.5) + t0.basis.z * (rng.next() - 0.5)) * 0.9
					var ss := 0.006 + rng.next() * 0.008
					spk.append(_rot_inst(top + jit * 0.5, Vector3(rng.next() * 3, rng.next() * 3, rng.next() * 3), Vector3(ss, ss * 1.8, ss)))
			U.inst(Geo.octa(1), SpecMat.make({col = Color(0.95, 0.97, 1.0), rough = 0.05, coat = 1.0, flat = true, env = 2.6}), spk.size(), func(i: int) -> Array: return [spk[i], Color(1, 1, 1)], shell)
	for k in (0 if main else 80 + int(floor(rng.next() * 40))):
		var d := Vector3(rng.next() - 0.5, rng.next() * 0.95 + 0.05, rng.next() - 0.5).normalized()
		var f := pow(rng.next(), 1.6)
		var dir := ((-d).lerp(UP, 0.15) + Vector3((rng.next() - 0.5) * 0.45, (rng.next() - 0.5) * 0.2, (rng.next() - 0.5) * 0.45)).normalized()
		var c: MeshInstance3D
		if prismy:
			var w := 0.05 + f * 0.13
			var h := w * 1.4 if habit == "cube" else minf(0.42, w * (2.4 + rng.next() * 2.2))
			var g := RockKit.prism(rng, {sides = 4 if habit == "cube" else 6, w = w, d = w * (0.8 + rng.next() * 0.3), h = h, point = habit != "cube", y0 = -w * 0.4}, {cA = c_root, cB = c_tip, zk = 1.0})
			c = U.mesh(g, gm, shell)
			_place(c, d * (wall_r.call(d) as float) * 0.96, dir, 1.0, rng.next() * 6.28)
		else:
			c = crystal.call(0.3 + f * 0.5, 0.4 + f * 0.5, d * (wall_r.call(d) as float) * 0.96, dir, {cA = c_root, cB = c_tip, zk = 1.0, habit = inner}, gm, shell)
		c.set_meta("local", true)
		if not main: main = c
	shell.transform = Transform3D(U.eul(-PI / 2 - 0.55, 0.35, 0), Vector3.ZERO)
	if _sid == "opal":
		var acc_h: Array = gene_m.get("accents", [])
		if "halves" in acc_h:
			# both halves of the egg (rare): side by side, mirrored as they came apart, faces up to the viewer
			var twin := shell.duplicate() as Node3D
			root.add_child(twin)
			shell.transform = Transform3D(U.eul(-PI / 2 - 0.5, 0.5, 0.08), Vector3(-1.05, 0, 0.05))
			twin.transform = Transform3D(Basis.from_scale(Vector3(-1, 1, 1)), Vector3.ZERO) * shell.transform
			twin.position.z -= 0.05
			_mark("halves", U.rel_xform(main, root) * Vector3(0, 0, 0.05))
		var fc := U.rel_xform(main, root) * Vector3(0, 0, 0.05)
		if "inner_light" in acc_h: _mark("inner_light", fc)
		if "pocket" in acc_h: _mark("pocket", fc)
	# moss, tufts and the rest settle on the outside of the shell
	st.rock = outer_mesh
	st.pick = func() -> Vector3:
		var pts := RockKit.surf_pts(outer_mesh, 1, rng, Callable(), root)
		return pts[0][0] if pts.size() else Vector3.ZERO
	st.nrm = func(v: Vector3) -> Vector3: return v.normalized()
	return main

# inside the main crystal: a ghost of an earlier crystal, golden rutile hairs, a milky core, inclusions and veils
func _inside(main: MeshInstance3D, mat: ShaderMaterial, habit: String, col: Color, gi: int, tr: Array, legend: bool, layout: String, seed_v: int) -> void:
	# (nothing "inside the crystal" in a lump, a pebble or a polished face: those are no crystal)
	var ok := main != null and mat != null and not (layout in ["botryoid", "sawn", "septaria", "balls", "fans", "staircase", "slice", "grapes"])
	var h := 1.2
	var g: Geo = main.get_meta("geo") if main else null
	var bb := g.aabb() if g else AABB()
	if ok and "trapiche" in (gene_m.accents as Array):
		# emerald's trapiche (a rare one): six dark spokes running the length of the crystal from a dark core, a wheel
		# seen in its flat end and through its sides
		# drawn in the glass itself (spec.gdshaderinc trap_k): six dark arms from a dark core through the crystal's whole
		# length — dark meshes inside were lost behind the frosted glass, never seen from the card's side
		# (the main crystal's own copy: the small ones beside it share the material and have no wheel)
		var tm: ShaderMaterial = SpecUtil.mat_copy(mat)
		main.material_override = tm
		tm.set_shader_parameter("frost_k", 0.0)
		tm.set_shader_parameter("holo_k", 0.0)
		tm.set_shader_parameter("thick", 0.6)
		tm.set_shader_parameter("trap_k", 1.0)
		tm.set_shader_parameter("trap_r", minf(bb.size.x, bb.size.z) * 0.5)
		var cx := Vector3(bb.get_center().x, bb.end.y, bb.get_center().z)
		_mark("trapiche", cx)
	if ok and "cats_eye" in (gene_m.accents as Array):
		# alexandrite's cat's eye: a line of light across the main crystal's top, sliding as it turns (spec.gdshaderinc
		# alex_eye) — its own copy of the glass, a little milky (the silk of fine needles that makes the eye)
		var em: ShaderMaterial = SpecUtil.mat_copy(main.material_override as ShaderMaterial if main.material_override is ShaderMaterial else mat)
		main.material_override = em
		em.set_shader_parameter("alex_eye", 1.0)
		em.set_shader_parameter("alex_ew", Vector2(maxf(bb.size.x, bb.size.z) * 0.022, maxf(bb.size.x, bb.size.z) * 0.2))
		_mark("cats_eye", Vector3(bb.get_center().x, bb.end.y, bb.get_center().z))
	if ok and "chlorite" in tr:
		# a ghost of green chlorite dust: an earlier crystal's faces, dusted over, inside the clear one (G2)
		var cm := SpecMat.make({col = SpecMat.lin(0x3a6a2a), rough = 0.8, grain = 0.6, flat = true})
		# (the crystal's own shape shrunk inside it, so it never pokes out)
		var cg := Geo.new()
		cg.v = g.v.duplicate()
		cg.idx = g.idx.duplicate()
		var c0 := Vector3(bb.get_center().x, maxf(0.0, bb.position.y), bb.get_center().z)
		for i in cg.v.size(): cg.v[i] = c0 + (cg.v[i] - c0) * Vector3(0.55, 0.62, 0.55)
		var ch := U.mesh(cg, cm, main)
		_mark("chlorite", _mid(ch))
	if ok and "phantom" in tr and not SpecLooks.of(_sid).get("phantom_core", false):
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
	if ok and "enhydro" in tr and not "enhydro" in (gene_m.get("lost", []) as Array):
		# a pocket of water in the crystal (G1), its gas bubble drifting up whichever way the stone is turned — drawn in
		# the glass itself (spec.gdshaderinc enh_*): the eye's ray, bent in at the face, finds the pocket and the bubble,
		# so they swim as the stone turns. (Meshes inside were lost behind the glass, and drawn over it they were a
		# sticker: an outline and a ball)
		var w := minf(bb.size.x, bb.size.z)
		var hh := bb.end.y - maxf(0.0, bb.position.y)
		var em: ShaderMaterial = SpecUtil.mat_copy(mat) if main.material_override == mat else main.material_override
		main.material_override = em
		em.set_shader_parameter("frost_k", 0.0)
		em.set_shader_parameter("ir_k", 0.0)   # (the rainbow film over the face hid what is inside)
		var cav := Enhydro.new()
		cav.mat = em
		# a long pocket along the crystal, as a negative crystal is, kept well inside it
		cav.rad = Vector3(w * 0.24, minf(hh * 0.26, w * 0.85), w * 0.2)
		cav.position = Vector3(bb.get_center().x, maxf(0.0, bb.position.y) + hh * (0.45 + rng.next() * 0.15), bb.get_center().z)
		cav.br = minf(cav.rad.x, cav.rad.z) * 0.42
		main.add_child(cav)
		em.set_shader_parameter("enh_k", 1.0)
		em.set_shader_parameter("enh_c", cav.position)
		em.set_shader_parameter("enh_r", cav.rad)
		cav.settle()
		_mark("enhydro", main.transform * cav.position)
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
## how far a fern frond reaches on average, in the find's body sizes (SpecAccents.fronds)
const FROND_REACH := 1.4
const FROND_SLIM := ["raven", "spoonbill", "hornbill"]

## the find's body: the box of what it is made of — its crystals, its rock, a skull's bone (not what grows on it)
func _body_box() -> AABB:
	var bb := AABB()
	var any := false
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		if not (n.get_meta("crystal", false) or n.has_meta("base")): continue
		var m := (n as MeshInstance3D).mesh
		if m == null: continue
		var box := SpecUtil.rel_xform(n as Node3D, root) * m.get_aabb()
		bb = bb.merge(box) if any else box
		any = true
	return bb if any else AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE)

func _accents(main: MeshInstance3D, mat: ShaderMaterial, gene: Dictionary, st: Dictionary, layout: String) -> void:
	_tag("growths")
	var acc: Array = gene.accents
	if acc.is_empty():
		return
	var pal: Dictionary = gene.palette
	var cols := []
	for c in root.get_children():
		if c is MeshInstance3D and c.get_meta("col", false):
			cols.append(c)
	# (a fossil leaf's main mesh is the film on the split face: nothing grows on that)
	# (nor on a nodule's face, a polished lump or a pebble: their main mesh is the stone itself, not a crystal)
	if main and not main in cols and layout != "fern" and not layout in ["botryoid", "sawn", "septaria"]:
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
			# (its room taken: nothing else of the rock's life grows up through it — keep_out, _free)
			keep_out.append([a[0], ln * 0.7])
			# the middle of the puff, not its root
			_mark("pompom", (a[0] as Vector3) + (a[1] as Vector3) * ln * 0.45, a[1])
	if "straw" in acc:
		var sc: Array = SpecAccents.STRAW[int(pal.straw)]
		for k in 2 + int(rng.next() * 3):
			# (on what faces up — the flat of the rock, a crystal's top: at the brink its fan hung out over nothing)
			var a: Array = spot.call(0.35)
			for t in 16:
				if a.is_empty() or ((a[1] as Vector3).y > 0.62 and _free(a[0])): break
				a = spot.call(0.35)
			if a.is_empty() or (a[1] as Vector3).y <= 0.62 or not _free(a[0]): continue
			# tangled hair: roots spread over a patch, long, strongly bent, every which way
			# swept a little one way, but standing up off the rock as grass does (swept hard, ×2.2, a tuft lay over on
			# its side, half of it in the air past the rock)
			var sweep: Vector3 = ((a[1] as Vector3).lerp(UP, 0.45) + Vector3(rng.next() - 0.5, rng.next() * 0.3, rng.next() - 0.5) * 0.7).normalized()
			_mark("straw", a[0], a[1])
			for bend in [1.4, 2.4]:
				SpecAccents.tuft(root, rng, a[0], sweep, 80 + int(rng.next() * 80), (0.2 + rng.next() * 0.2) * gs, 0.008, 0.32, bend, sc, 0.09 * gs, 0.6)
			_tag("straw")
			# (a tuft's room: flowers and mushrooms no longer grow up through the straw)
			keep_out.append([a[0], 0.17 * gs])
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
			# (a fern is a big bush: grown in front of a skull it hides it — a raven's went under a ball of fronds. So on a
			# skull the clumps root on its back and sides, away from the viewer (who looks along -Z), and everywhere a
			# frond reaches on average no farther than the body is across ×FROND_REACH — a small find, smaller ferns)
			# (the back of the find only on a skull: there the face is the thing; on a rock a fern in front is part of it)
			var skull := String(gene.form) == "skull"
			var body := _body_box()
			var bs := pow(maxf(body.size.x * body.size.y * body.size.z, 1e-6), 1.0 / 3.0)
			var fcap := FROND_REACH * bs / SpecAccents.FROND_MEAN
			# (a bird's skull is a thin shell round a long beak: its box is a mammal's, its bulk a third of it)
			if skull and String((gene.get("skull", {}) as Dictionary).get("beast", "")) in FROND_SLIM:
				fcap *= 0.55
			var back := green.filter(func(g: Array) -> bool:
				return (g[0] as Vector3).z < body.get_center().z and (g[1] as Vector3).z < 0.2) if skull else []
			var beds: Array = back if back.size() >= 3 else green
			for k in 1 + int(rng.next() * 3):
				var at: Array = beds[int(rng.next() * beds.size())]
				# (and the bush leans back, its fronds spreading behind and above the find rather than over its face)
				if skull: at = [at[0], ((at[1] as Vector3) + Vector3(0, 0.3, -0.7)).normalized()]
				var fn := 8 + int(rng.next() * 9)
				var fsz := minf((0.3 + rng.next() * 0.22) * gs, fcap)
				SpecAccents.fronds(root, rng, [at], fn, fsz, fp)
				_mark("fronds", at[0], at[1])
				keep_out.append([at[0], fsz * 0.45])
		if "flowers" in acc:
			# real plants (SpecFlora: the kind is the genome's), on their own random stream; on the open rock, the
			# mountain violets all over it
			var flr := Rng32.new((int(gene.shroom_seed) * 22695477 + 7) % 4294967296)
			var fk := int(gene.get("flora", 0))
			var open_rock := rock_spots.filter(func(q: Array) -> bool: return _free(q[0], 0.1 * gs))
			var beds: Array = open_rock if open_rock.size() > 12 else green.filter(func(q: Array) -> bool: return _free(q[0], 0.1 * gs))
			if beds.is_empty(): beds = green
			var had := root.get_child_count()
			for fm: Array in SpecFlora.grow(root, flr, beds, fk, gs, boxes, SpecFlora.find_look(int(gene.shroom_seed), fk)):
				_mark("flowers", fm[0], fm[1])
			_claim(had)
	# (the pits, and the open rock as well: on a lone crystal the pits all lie round its foot, under it, and a mushroom
	# found no room at all — or shrank to a speck)
	var shroom_beds: Array = (nest_spots + rock_spots).filter(func(q: Array) -> bool: return _free(q[0], 0.1 * gs))
	# (and the rock's sides: every spot above is on its top, and on a find whose top the crystals fill a grown one had
	# nowhere to stand — taken off the rock's own surface, on a stream of their own, the near sides first)
	if "mushrooms" in acc and st.rock and (st.rock as Node3D).has_meta("geo"):
		var sr := Rng32.new((int(gene.shroom_seed) * 1103515245 + 4321) % 4294967296)
		for q: Array in RockKit.surf_pts(st.rock, 160, sr, func(_p: Vector3, nn: Vector3) -> bool: return nn.y > -0.15 and nn.y <= 0.3 and nn.z > -0.3, root):
			if _free(q[0], 0.1 * gs): shroom_beds.append(q)
	if "mushrooms" in acc and shroom_beds.size():
		# their own random stream too: the rest of the stone stays as it was
		var fr := Rng32.new((int(gene.shroom_seed) * 69069 + 12345) % 4294967296)
		var kind: int = gene.shroom
		var tiny := kind == 3
		for k in 1 + int(fr.next() * (3.0 if tiny else 2.0)):
			var n := (5 + int(fr.next() * 6)) if tiny else (3 + int(fr.next() * 4))
			# (real mushrooms are slighter than the turned ones were: they stand taller to read on a card)
			var cap: Array = SpecFungi.cluster(root, fr, shroom_beds, kind, n, (0.38 + fr.next() * 0.22) * gs * (0.72 if tiny else 1.0) * SHROOM_K, boxes, SpecFungi.find_look(int(gene.shroom_seed), kind))
			if cap.size(): _mark("mushrooms", cap[0], cap[1])
	# butterflies (SpecButterfly.for_find: the kinds of the species' mine), on their own stream: resting on the rock where
	# a wing has room, or flying round the find; a skull places its own (SpecSkull)
	var fks: Array = gene.get("fly_kinds", [])
	var land: Array = rock_spots if rock_spots.size() else nest_spots
	if fks.size() and String(gene.form) != "skull":
		var fl := Rng32.new((int(gene.shroom_seed) * 1664525 + 1013904223) % 4294967296)
		var perches := land.filter(func(q: Array) -> bool: return (q[1] as Vector3).y > 0.45 and _free(q[0]))
		if perches.is_empty(): perches = land.filter(func(q: Array) -> bool: return (q[1] as Vector3).y > 0.2)
		# no room on the rock (a lone prism on a stub, a find without rock): they sit on the crystal itself — the genome
		# promised them, and the achievements count them
		if perches.is_empty() and main:
			perches = RockKit.surf_pts(main, 24, fl, func(_p: Vector3, nn: Vector3) -> bool: return nn.y > 0.25, root)
		var seen := {}
		for id: String in fks:
			if perches.is_empty(): break
			var style := SpecButterfly.style(id)
			var flying := fl.next() < (0.7 if style in ["hover", "flit"] else 0.45)
			if SpecButterfly.fly_in != Vector3.INF: flying = true   # (a trailer's test key: it flies in from outside)
			var q: Array = perches[int(fl.next() * perches.size())]
			SpecButterfly.put(root, fl, id, q[0], q[1], (0.28 + fl.next() * 0.1) * gs, flying, perches)
			# (the callout points at a fixed spot — where the first of this kind came to the find — not at the
			# butterfly, which flies about)
			if not seen.has(id):
				seen[id] = true
				_mark("fly_" + id, (q[0] as Vector3) + (q[1] as Vector3) * 0.04 * gs, q[1])
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
			# (where the find says its crystals break out — a skull's breach — or anywhere on the rock)
			var foot: Callable = st.get("foot_pick", pick)
			for k in 22:
				var q: Vector3 = foot.call()
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
	# (not on a fossil leaf: its main mesh is the film itself, and the grains stood on it in white lumps)
	if main and "druzy" in tr and layout != "fern":
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
	var has_base: bool = not (layout in ["floater", "radial", "columnar", "geode", "nugget", "botryoid", "vein", "obsidian", "sawn", "septaria", "slice"]) and not (gene_m.lustre == "fossil" and not st.rock)
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
		# (19.11) a sea floor's fossil (a trilobite's, an ammonite's slab): the bubbles cling to its rock, small — its
		# slab is moved and turned after its rock was laid (SpecTrilobite), and picked in the rock's own space, lifted
		# up to half a unit they hung off the slab in the air, big as marbles
		var sea_f: bool = Data.HABIT.get(sid, "") == "fossil" and st.rock is Node3D
		var rt: Transform3D = U.rel_xform(st.rock, root) if sea_f and (st.rock as Node3D).is_inside_tree() else Transform3D.IDENTITY
		var place := func(k: int) -> Array:
			var v: Vector3 = (pick.call() as Vector3) * 1.02
			if sea_f:
				v = rt * (pick.call() as Vector3)
				var s0 := (0.008 + rng.next() * 0.022) * rt.basis.get_scale().x
				made.append([s0, v])
				return [Transform3D(Basis.from_scale(Vector3(s0, s0 * 0.7, s0)), v), Color(1, 1, 1)]
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
var parts_i := 0
const PARTS_K := 0.55   # how far the plain clear species cloud by parts (0 — none, as they were before 12.11)

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
		var local: bool = n.get_meta("local", false)
		var bb := gg.aabb()
		var hgt := maxf(0.001, bb.size.y)
		var t := U.rel_xform(n, root)
		if crusty and gg.tri_count() < 2500:
			# finer only where the crust moves the surface (rock-line height below dt.h + 0.1); the rest of the crystal
			# stays as it was — splitting it whole made a skull's ~100 crystals 7x the vertices
			var top: float = dt.h + 0.1 + 0.001
			# (a skull's crystals stand in soil, their feet hidden: once is as good as twice there, at a third of the points)
			var lv := 1 if gg.tri_count() > 500 or crust_once else 2
			if local:
				gg.subdivide(lv, Vector3.UP, bb.position.y + top * hgt)
			else:
				gg.subdivide(lv, Vector3(t.basis.x.y, t.basis.y.y, t.basis.z.y), top - t.origin.y)
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
			# (a split crystal is a plain triangle list: each corner is there about six times over — its noise once)
			var seen := {}
			for i in gg.v.size():
				var w := 1.0 - smoothstep(line - 0.14, line + 0.1, rp[i].y)
				if w > 0.0:
					var p := gg.v[i]
					var d: Variant = seen.get(p)
					if d == null:
						var q := p * 9.0
						d = Vector3(fn.get_noise_3dv(q), fn.get_noise_3dv(q + Vector3(19, 0, 0)), fn.get_noise_3dv(q + Vector3(0, 0, 41)))
						seen[p] = d
					gg.v[i] = p + (d as Vector3) * amp * w
		gg.rp = rp
		# clarity by parts (SpecLooks glass.parts): every crystal its own number, spread evenly over 0..1
		var mo: Material = (n as MeshInstance3D).material_override
		if mo and mo.has_meta("parts"):
			parts_i += 1
			gg.tag = float(n.get_meta("part", 0.04 + 0.96 * fposmod(parts_i * 0.6180339 + 0.37, 1.0)))
		(n as MeshInstance3D).mesh = gg.to_mesh()

## an enhydro's pocket (G1): the gas bubble keeps to the top of its water, the top being wherever "up" is now; it is
## drawn by the crystal's glass (spec.gdshaderinc enh_b), this only moves it (in the crystal's own space)
class Enhydro extends Node3D:
	var rad := Vector3.ONE
	var br := 0.05
	var mat: ShaderMaterial
	var at := Vector3.ZERO    # the bubble, in the pocket's space
	var vel := Vector3.ZERO
	var _last := Basis()
	var _has_last := false
	## "up" for the bubble: away from the pull of the earth as the phone feels it (19.11 — tilt the phone, the bubble
	## goes to its new top: a real stone with water in it, held), turned into the card's camera; on a desk (no
	## sensor) the studio's own up
	static func world_up(node: Node3D) -> Vector3:
		var g := Input.get_gravity()
		var cam := node.get_viewport().get_camera_3d() if node.is_inside_tree() else null
		if g.length() > 1.0 and cam:
			# (device space: x right, y up the screen, z out of it — as the camera's own axes)
			return (cam.global_transform.basis * (-g.normalized())).normalized()
		return Vector3.UP
	func jolt(k: float) -> void:
		vel += Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * (rad.length() * 6.0 * k)
	func _target() -> Vector3:
		var up := (global_transform.basis.inverse() * world_up(self)) if is_inside_tree() else Vector3.UP
		if up.length() < 1e-5: up = Vector3.UP
		var d := up.normalized()
		# the point of the pocket's wall that way, the bubble's own radius in from it
		var k := 1.0 / sqrt(pow(d.x / rad.x, 2.0) + pow(d.y / rad.y, 2.0) + pow(d.z / rad.z, 2.0))
		return d * maxf(0.0, k - br * 1.1)
	func _put() -> void:
		if mat: mat.set_shader_parameter("enh_b", Vector4(position.x + at.x, position.y + at.y, position.z + at.z, br))
	func settle() -> void:
		at = _target()
		vel = Vector3.ZERO
		_put()
	func _ready() -> void:
		settle()
	## (19.11) alive: it floats to the top on a spring — overshoots and rocks a little before it settles; and when the
	## stone is turned the water lags behind the turning glass, so the bubble slides back along the pocket's top and
	## then rolls home (a finger dragging the stone sends it running)
	func _process(dt: float) -> void:
		dt = minf(dt, 0.05)
		var gb := global_transform.basis.orthonormalized()
		if _has_last and dt > 0.0:
			# the turn since the last frame, in the pocket's own space: the water stays behind it
			var dq := (gb.inverse() * _last).get_rotation_quaternion()
			var ang := dq.get_angle()
			if ang > 1e-5 and ang < 1.0:
				var ax := dq.get_axis()
				vel += ax.cross(at) * (ang / dt) * 0.9
		_last = gb
		_has_last = true
		var tgt := _target()
		vel += (tgt - at) * 26.0 * dt
		vel *= exp(-dt * 3.2)
		at += vel * dt
		# kept inside the pocket
		var q := at / (rad - Vector3.ONE * br * 1.05).max(Vector3.ONE * 1e-4)
		if q.length() > 1.0:
			at = at / q.length()
			var nrm := (at / ((rad - Vector3.ONE * br) * (rad - Vector3.ONE * br)).max(Vector3.ONE * 1e-6)).normalized()
			# (against the wall: it stops going out, a small bounce back)
			if vel.dot(nrm) > 0.0: vel -= nrm * vel.dot(nrm) * 1.3
		_put()
