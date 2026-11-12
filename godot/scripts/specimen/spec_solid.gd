class_name SpecSolid
extends RefCounted
## Nothing that grows on a find sits inside a crystal. The builder keeps growths off the crystals by their boxes and
## by the one point a thing is rooted at; a cap, a bush, a spray of needles can still reach into a crystal beside it,
## and a crowded rock leaves no free point at all. So when a find is built, every growth is looked at against the
## crystals' real shapes (clear): a mushroom, a flower, a frond or a cushion of lichen with too much of itself in the
## glass is taken away; a tuft loses the needles that run into a crystal, a dusting its specks under one. A gene left with nothing is no longer
## "grown" (no badge, no achievement for it).
## The crystal's shape, cheaply: a grid of upright columns over its box, each with the heights where its surface
## crosses the column (made only for the crystals something comes near).

## the genes whose things are looked at; the rest are part of the body or lie on the crystals on purpose (moss and
## coral under them, the druse on their faces, the crust at their feet, a second mineral)
const GENES := ["mushrooms", "flowers", "fronds", "lichen", "needles", "pompom", "straw", "dust", "bubbles"]
const N := 10
static var on := true   # (tests/overlap_audit `noclear`: the finds as they would be without the pass)

## the columns of a crystal's shape: {box, sx, sz, cols: cell -> heights}
static func grid(geo: Geo) -> Dictionary:
	var bb := geo.aabb()
	var sx := maxf(bb.size.x / N, 1e-6)
	var sz := maxf(bb.size.z / N, 1e-6)
	var cols := {}
	var ind := geo.indexed()
	for t in geo.tri_count():
		var a: Vector3 = geo.v[geo.idx[t * 3]] if ind else geo.v[t * 3]
		var b: Vector3 = geo.v[geo.idx[t * 3 + 1]] if ind else geo.v[t * 3 + 1]
		var c: Vector3 = geo.v[geo.idx[t * 3 + 2]] if ind else geo.v[t * 3 + 2]
		var d := (b.z - c.z) * (a.x - c.x) + (c.x - b.x) * (a.z - c.z)
		if absf(d) < 1e-14: continue
		var ix0 := maxi(0, int(ceil((minf(a.x, minf(b.x, c.x)) - bb.position.x) / sx - 0.5)))
		var ix1 := mini(N - 1, int(floor((maxf(a.x, maxf(b.x, c.x)) - bb.position.x) / sx - 0.5)))
		var iz0 := maxi(0, int(ceil((minf(a.z, minf(b.z, c.z)) - bb.position.z) / sz - 0.5)))
		var iz1 := mini(N - 1, int(floor((maxf(a.z, maxf(b.z, c.z)) - bb.position.z) / sz - 0.5)))
		for ix in range(ix0, ix1 + 1):
			var px := bb.position.x + (ix + 0.5) * sx
			for iz in range(iz0, iz1 + 1):
				var pz := bb.position.z + (iz + 0.5) * sz
				var l1 := ((b.z - c.z) * (px - c.x) + (c.x - b.x) * (pz - c.z)) / d
				var l2 := ((c.z - a.z) * (px - c.x) + (a.x - c.x) * (pz - c.z)) / d
				var l3 := 1.0 - l1 - l2
				if l1 < 0.0 or l2 < 0.0 or l3 < 0.0: continue
				var k := ix * N + iz
				# (plain lists: a packed one taken out of the dictionary is a copy, and what is added to it is lost)
				if not cols.has(k): cols[k] = []
				(cols[k] as Array).append(l1 * a.y + l2 * b.y + l3 * c.y)
	return {box = bb, sx = sx, sz = sz, cols = cols}

## is the point (in the crystal's own space) inside it
static func has(g: Dictionary, q: Vector3) -> bool:
	var bb: AABB = g.box
	if not bb.has_point(q): return false
	var ix := clampi(int((q.x - bb.position.x) / float(g.sx)), 0, N - 1)
	var iz := clampi(int((q.z - bb.position.z) / float(g.sz)), 0, N - 1)
	var ys: Variant = (g.cols as Dictionary).get(ix * N + iz)
	if ys == null: return false
	var above := 0
	for y: float in (ys as Array):
		if y > q.y: above += 1
	return above % 2 == 1

## the crystals of a built find (SpecimenBuilder marks them): [{inv, c, r, geo, grid (made when first asked)}]
static func crystals(root: Node3D) -> Array:
	var out := []
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		if not n.get_meta("crystal", false) or not n.has_meta("geo"): continue
		var geo: Geo = n.get_meta("geo")
		var xf := SpecUtil.rel_xform(n as Node3D, root)
		var bb := geo.aabb()
		out.append({inv = xf.affine_inverse(), c = xf * bb.get_center(), r = bb.size.length() * 0.5 * xf.basis.get_scale().x, geo = geo, box = bb})
	return out

## is the point (in the find's space) inside any of `near` (the crystals worth asking)
static func inside(p: Vector3, near: Array) -> bool:
	for cr: Dictionary in near:
		if p.distance_squared_to(cr.c) > float(cr.r) * float(cr.r): continue
		var q: Vector3 = (cr.inv as Transform3D) * p
		if not (cr.box as AABB).has_point(q): continue
		if not cr.has("grid"): cr.grid = grid(cr.geo)
		if has(cr.grid, q): return true
	return false

## the points a thing is tried by, in its own mesh's space: a thin tall one (a needle of a tuft) along its length, any
## other up its middle and round its upper part
static func probe(mb: AABB, thin: bool) -> PackedVector3Array:
	var out := PackedVector3Array()
	var c := mb.get_center()
	if thin:
		for f: float in [0.14, 0.4, 0.7, 0.97]: out.append(Vector3(c.x, mb.position.y + mb.size.y * f, c.z))
		return out
	for f: float in [0.35, 0.6, 0.85]: out.append(Vector3(c.x, mb.position.y + mb.size.y * f, c.z))
	for k in 6:
		var a := TAU * k / 6.0
		out.append(Vector3(c.x + cos(a) * mb.size.x * 0.3, mb.position.y + mb.size.y * 0.8, c.z + sin(a) * mb.size.z * 0.3))
	return out

## the pass: `grown` is the builder's (gene -> marks); a gene left with nothing is erased from it
static func clear(root: Node3D, grown: Dictionary) -> void:
	if not on: return
	var all := crystals(root)
	if all.is_empty(): return
	var had := {}
	var left := {}
	for n: Node in root.find_children("*", "GeometryInstance3D", true, false):
		var gene := _gene_of(n, root)
		if not gene in GENES: continue
		if n.get_meta("crystal", false) or n.has_meta("base") or n.has_meta("box"): continue
		had[gene] = true
		var keep := true
		if n is MultiMeshInstance3D:
			keep = _thin(n as MultiMeshInstance3D, root, all, gene)
		elif n is MeshInstance3D and gene == "lichen" and n.has_meta("geo"):
			keep = _whole(n as MeshInstance3D, root, all)
		if keep: left[gene] = true
		else:
			n.get_parent().remove_child(n)
			n.free()
	for gene: String in had:
		if not left.has(gene): grown.erase(gene)

static func _gene_of(n: Node, root: Node) -> String:
	var p := n
	while p and p != root:
		if p.has_meta("gene"): return String(p.get_meta("gene"))
		p = p.get_parent()
	return ""

## the crystals a ball in the find's space comes near
static func _near(all: Array, c: Vector3, r: float) -> Array:
	var out := []
	for cr: Dictionary in all:
		var rr := r + float(cr.r)
		if c.distance_squared_to(cr.c) <= rr * rr: out.append(cr)
	return out

## a cushion: gone when a third of it is in the glass
static func _whole(m: MeshInstance3D, root: Node3D, all: Array) -> bool:
	var geo: Geo = m.get_meta("geo")
	if geo.v.is_empty(): return true
	var xf := SpecUtil.rel_xform(m, root)
	var bb := geo.aabb()
	var near := _near(all, xf * bb.get_center(), bb.size.length() * 0.5 * xf.basis.get_scale().x)
	if near.is_empty(): return true
	var step := maxi(1, geo.v.size() / 12)
	var n := 0
	var hit := 0
	for i in range(0, geo.v.size(), step):
		n += 1
		if inside(xf * geo.v[i], near): hit += 1
	return hit * 3 < n

## many copies of one mesh: the copies in the glass are dropped (false: none is left)
static func _thin(mi: MultiMeshInstance3D, root: Node3D, all: Array, gene: String) -> bool:
	var mm := mi.multimesh
	if mm == null or mm.mesh == null or mm.instance_count == 0: return true
	var key := "ibuf" if mi.has_meta("ibuf") else "mmbuf" if mi.has_meta("mmbuf") else ""
	if key == "" or mm.transform_format != MultiMesh.TRANSFORM_3D: return true
	var buf: PackedFloat32Array = mi.get_meta(key)
	var stride := 12 + (4 if mm.use_colors else 0) + (4 if mm.use_custom_data else 0)
	var count := buf.size() / stride
	if count == 0: return true
	# (a needle is a unit mesh made thin by its copy's scale: told by the first copy)
	var mb := mm.mesh.get_aabb()
	var sx := Vector3(buf[0], buf[4], buf[8]).length() * mb.size.x
	var sy := Vector3(buf[1], buf[5], buf[9]).length() * mb.size.y
	var sz := Vector3(buf[2], buf[6], buf[10]).length() * mb.size.z
	var pts := probe(mb, sy > 3.5 * maxf(sx, sz))
	# (a needle with any of it in a crystal goes; a plant may brush one)
	var most := 0 if pts.size() == 4 else 1
	var base := SpecUtil.rel_xform(mi, root)
	# the crystals near any of it at all
	var lo := Vector3(1e9, 1e9, 1e9)
	var hi := Vector3(-1e9, -1e9, -1e9)
	var reach := 0.0
	var mr := mm.mesh.get_aabb().size.length()
	for k in count:
		var i := k * stride
		var o := base * Vector3(buf[i + 3], buf[i + 7], buf[i + 11])
		lo = lo.min(o)
		hi = hi.max(o)
		reach = maxf(reach, mr * Vector3(buf[i], buf[i + 4], buf[i + 8]).length())
	var near := _near(all, (lo + hi) * 0.5, (hi - lo).length() * 0.5 + reach * base.basis.get_scale().x)
	if near.is_empty(): return true
	var out := PackedFloat32Array()
	var kept := 0
	for k in count:
		var i := k * stride
		var xf := base * Transform3D(Basis(Vector3(buf[i], buf[i + 4], buf[i + 8]), Vector3(buf[i + 1], buf[i + 5], buf[i + 9]), Vector3(buf[i + 2], buf[i + 6], buf[i + 10])),
			Vector3(buf[i + 3], buf[i + 7], buf[i + 11]))
		var hit := 0
		for q: Vector3 in pts:
			if inside(xf * q, near):
				hit += 1
				if hit > most: break
		if hit > most: continue
		out.append_array(buf.slice(i, i + stride))
		kept += 1
	if kept == count: return true
	if kept == 0: return false
	var nm := MultiMesh.new()
	nm.transform_format = mm.transform_format
	nm.use_colors = mm.use_colors
	nm.use_custom_data = mm.use_custom_data
	nm.mesh = mm.mesh
	nm.instance_count = kept
	nm.buffer = out
	mi.multimesh = nm
	mi.set_meta(key, out)
	return true
