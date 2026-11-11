# the build speedups, applied to a project root given as argv[1]; argv[2:] picks which (default all)
import sys, io
root = sys.argv[1]
which = set(sys.argv[2:]) or {"fern", "surf", "edges", "subdiv", "free"}


def rw(rel, fn):
    p = root + "/" + rel
    s = io.open(p, encoding="utf-8", newline="").read()
    nl = "\r\n" if "\r\n" in s else "\n"
    s0 = s.replace("\r\n", "\n")
    s2 = fn(s0)
    assert s2 != s0, rel + ": nothing changed"
    io.open(p, "w", encoding="utf-8", newline="").write(s2.replace("\n", nl))
    print("patched", rel)


def swap(s, a, b, n=1):
    assert s.count(a) == n, "expected %d of: %s (found %d)" % (n, a[:60], s.count(a))
    return s.replace(a, b)


FERN_OLD = """	var sum := 0.0
	var wsum := 0.0
	for c in [[0, 0, (1.0 - tx) * (1.0 - tz)], [1, 0, tx * (1.0 - tz)], [0, 1, (1.0 - tx) * tz], [1, 1, tx * tz]]:
		var v := arr[(j + int(c[1])) * nx + i + int(c[0])]
		if v > -1e8:
			sum += v * float(c[2])
			wsum += float(c[2])
	return sum / wsum if wsum > 0.0001 else float(H.fall)
"""
FERN_NEW = """	# (the four corners in turn, written out: a list of lists here was twenty small arrays made per point of the film,
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
"""

SURF_VARS_OLD = "var nc := PackedVector3Array()\nvar cells := {}\n"
SURF_VARS_NEW = """var nc := PackedVector3Array()
var cells := {}
## each triangle's bounding ball (centre, radius): closest() passes over one that cannot be nearer than what it has
var tm := PackedVector3Array()
var tr := PackedFloat32Array()
"""
SURF_ADD_OLD = "		tc.append(p2)\n"
SURF_ADD_NEW = """		tc.append(p2)
		var mid := (p0 + p1 + p2) / 3.0
		tm.append(mid)
		tr.append(sqrt(maxf(mid.distance_squared_to(p0), maxf(mid.distance_squared_to(p1), mid.distance_squared_to(p2)))) * 1.001 + 1e-5)
"""
SURF_LOOP_OLD = """	for r in [1, 2]:
		var seen := {}
		for x in range(-r, r + 1):
			for y in range(-r, r + 1):
				for z in range(-r, r + 1):
					var key := c0 + Vector3i(x, y, z)
					if not cells.has(key): continue
					for ti: int in cells[key]:
						if seen.has(ti): continue
						seen[ti] = true
						var q := _on_tri(p, ta[ti], tb[ti], tc[ti])
"""
SURF_LOOP_NEW = """	# (a dense scan has a thousand triangles in these cells: most are passed over by their bounding ball - farther
	# than the best so far, they cannot win; one met again in another cell is no nearer than itself, so no list of
	# those seen is kept. The answer is the same triangle as before.)
	var reach := INF
	for r in [1, 2]:
		for x in range(-r, r + 1):
			for y in range(-r, r + 1):
				for z in range(-r, r + 1):
					var key := c0 + Vector3i(x, y, z)
					var list: Variant = cells.get(key)
					if list == null: continue
					for ti: int in list:
						if p.distance_to(tm[ti]) - tr[ti] > reach: continue
						var q := _on_tri(p, ta[ti], tb[ti], tc[ti])
"""
SURF_BEST_OLD = """						if d < best:
							best = d
							bp = q[0]
"""
SURF_BEST_NEW = """						if d < best:
							best = d
							reach = sqrt(d) * 1.0001 + 1e-6
							bp = q[0]
"""

EDGES_NEW = """func mark_edges(angle_deg := 14.0) -> Geo:
	to_soup()
	var n := v.size()
	var nt := n / 3
	# (corners that share a place get one number, an edge is the pair of its ends' numbers: whole numbers as keys -
	# they used to be text made from the two places, six strings a triangle)
	var ids := PackedInt32Array()
	ids.resize(n)
	var places := {}
	for i in n:
		var p := v[i]
		var pk := Vector3i(roundi(p.x * 5000.0), roundi(p.y * 5000.0), roundi(p.z * 5000.0))
		var id: int = places.get(pk, -1)
		if id < 0:
			id = places.size()
			places[pk] = id
		ids[i] = id
	var fn := PackedVector3Array()
	fn.resize(nt)
	var ek := PackedInt64Array()
	ek.resize(n)
	var edges := {}
	for t in nt:
		var i0 := t * 3
		fn[t] = (v[i0 + 1] - v[i0]).cross(v[i0 + 2] - v[i0]).normalized()
		for e in 3:
			var a := ids[i0 + (e + 1) % 3]
			var b := ids[i0 + (e + 2) % 3]
			var k := a * n + b if a < b else b * n + a
			ek[i0 + e] = k
			var ts: Variant = edges.get(k)
			if ts == null: edges[k] = [t]
			else: (ts as Array).append(t)
	var cos_lim := cos(deg_to_rad(angle_deg))
	bary.resize(v.size())
	for t in nt:
		var add := Vector3.ZERO
		for e in 3:
			var ts: Array = edges[ek[t * 3 + e]]
			var real := ts.size() < 2
			for o: int in ts:
				if o != t and absf(fn[o].dot(fn[t])) < cos_lim:
					real = true
			if not real:
				add[e] = 10.0
"""

SUBDIV_NEW = """	for l in levels:
		var nv := PackedVector3Array()
		var nc := PackedColorArray()
		var has_c := col.size() == v.size()
		var has_b := bary.size() == v.size()
		var nb := PackedVector3Array()
		# (room for every triangle split, cut back at the end: adding twelve points at a time through a list was the slow part)
		var n := v.size()
		nv.resize(n * 4)
		if has_c: nc.resize(n * 4)
		if has_b: nb.resize(n * 4)
		var w := 0
		for k in range(0, n, 3):
			var a := v[k]
			var b := v[k + 1]
			var c := v[k + 2]
			if some and dir.dot(a) >= lim and dir.dot(b) >= lim and dir.dot(c) >= lim:
				nv[w] = a; nv[w + 1] = b; nv[w + 2] = c
				if has_c:
					nc[w] = col[k]; nc[w + 1] = col[k + 1]; nc[w + 2] = col[k + 2]
				if has_b:
					nb[w] = bary[k]; nb[w + 1] = bary[k + 1]; nb[w + 2] = bary[k + 2]
				w += 3
				continue
			var ab := (a + b) * 0.5
			var bc := (b + c) * 0.5
			var ca := (c + a) * 0.5
			nv[w] = a; nv[w + 1] = ab; nv[w + 2] = ca
			nv[w + 3] = ab; nv[w + 4] = b; nv[w + 5] = bc
			nv[w + 6] = ca; nv[w + 7] = bc; nv[w + 8] = c
			nv[w + 9] = ab; nv[w + 10] = bc; nv[w + 11] = ca
			if has_c:
				var x := col[k]
				var y := col[k + 1]
				var z := col[k + 2]
				var xy := x.lerp(y, 0.5)
				var yz := y.lerp(z, 0.5)
				var zx := z.lerp(x, 0.5)
				nc[w] = x; nc[w + 1] = xy; nc[w + 2] = zx
				nc[w + 3] = xy; nc[w + 4] = y; nc[w + 5] = yz
				nc[w + 6] = zx; nc[w + 7] = yz; nc[w + 8] = z
				nc[w + 9] = xy; nc[w + 10] = yz; nc[w + 11] = zx
			if has_b:
				var x2 := bary[k]
				var y2 := bary[k + 1]
				var z2 := bary[k + 2]
				var xy2 := (x2 + y2) * 0.5
				var yz2 := (y2 + z2) * 0.5
				var zx2 := (z2 + x2) * 0.5
				nb[w] = x2; nb[w + 1] = xy2; nb[w + 2] = zx2
				nb[w + 3] = xy2; nb[w + 4] = y2; nb[w + 5] = yz2
				nb[w + 6] = zx2; nb[w + 7] = yz2; nb[w + 8] = z2
				nb[w + 9] = xy2; nb[w + 10] = yz2; nb[w + 11] = zx2
			w += 12
		nv.resize(w)
		if has_c: nc.resize(w)
		if has_b: nb.resize(w)
"""

FREE_OLD = """	for b: Dictionary in boxes:
		if (b.bounds as AABB).has_point((b.inverse as Transform3D) * p):
			return false
	return true
"""
FREE_NEW = """	# (asked tens of thousands of times a stone: each box's ball in root space is tried first - a point outside it
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
"""

if "fern" in which:
    rw("scripts/specimen/spec_fern.gd", lambda s: swap(s, FERN_OLD, FERN_NEW))

if "surf" in which:
    def f(s):
        s = swap(s, SURF_VARS_OLD, SURF_VARS_NEW)
        s = swap(s, SURF_ADD_OLD, SURF_ADD_NEW)
        s = swap(s, SURF_LOOP_OLD, SURF_LOOP_NEW)
        return swap(s, SURF_BEST_OLD, SURF_BEST_NEW)
    rw("scripts/specimen/spec_surf.gd", f)

if "edges" in which or "subdiv" in which:
    def f(s):
        if "edges" in which:
            a = s.index("func mark_edges(")
            b = s.index("		# each corner carries its height above the opposite edge")
            s = s[:a] + EDGES_NEW + s[b:]
        if "subdiv" in which:
            a = s.index("	for l in levels:\n		var nv := PackedVector3Array()")
            b = s.index("		v = nv\n		col = nc\n		bary = nb\n	return self", a)
            s = s[:a] + SUBDIV_NEW + s[b:]
        return s
    rw("scripts/specimen/geo.gd", f)

if "free" in which:
    rw("scripts/specimen/specimen_builder.gd", lambda s: swap(s, FREE_OLD, FREE_NEW))
