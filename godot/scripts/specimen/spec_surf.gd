class_name SpecSurf
extends RefCounted
## A mesh surface for things that run over it (SpecSkull's water): its triangles sorted into a grid of cells, so the
## nearest point on the real surface (not the nearest vertex — that let water sink into a coarse rock) and the first
## hit of a ray (where a falling drop lands) are quick to find. Normals are the meshes' own, interpolated.

const CS := 0.04

var ta := PackedVector3Array()
var tb := PackedVector3Array()
var tc := PackedVector3Array()
var na := PackedVector3Array()
var nb := PackedVector3Array()
var nc := PackedVector3Array()
var cells := {}

## adds a mesh (its vertex normals; t: into the surface's space); a skull's dead vertices (meta "alive") are left out
func add(g: Geo, nr: PackedVector3Array, t := Transform3D.IDENTITY) -> void:
	var alive: PackedByteArray = g.get_meta("alive") if g.has_meta("alive") else PackedByteArray()
	var ix := g.idx
	var ind := g.indexed()
	for k in g.tri_count():
		var i0 := ix[k * 3] if ind else k * 3
		var i1 := ix[k * 3 + 1] if ind else k * 3 + 1
		var i2 := ix[k * 3 + 2] if ind else k * 3 + 2
		if alive.size() and (alive[i0] == 0 or alive[i1] == 0 or alive[i2] == 0): continue
		var p0 := t * g.v[i0]
		var p1 := t * g.v[i1]
		var p2 := t * g.v[i2]
		var ti := ta.size()
		ta.append(p0)
		tb.append(p1)
		tc.append(p2)
		na.append((t.basis * nr[i0]).normalized())
		nb.append((t.basis * nr[i1]).normalized())
		nc.append((t.basis * nr[i2]).normalized())
		var lo := p0.min(p1).min(p2)
		var hi := p0.max(p1).max(p2)
		for x in range(floori(lo.x / CS), floori(hi.x / CS) + 1):
			for y in range(floori(lo.y / CS), floori(hi.y / CS) + 1):
				for z in range(floori(lo.z / CS), floori(hi.z / CS) + 1):
					var key := Vector3i(x, y, z)
					if not cells.has(key): cells[key] = []
					(cells[key] as Array).append(ti)

func _cell(p: Vector3) -> Vector3i:
	return Vector3i(floori(p.x / CS), floori(p.y / CS), floori(p.z / CS))

## the nearest point of the surface to p (within two cells): [point, normal, distance], or [] if none that near
func closest(p: Vector3) -> Array:
	var c0 := _cell(p)
	var best := INF
	var bp := Vector3.ZERO
	var bn := Vector3.UP
	for r in [1, 2]:
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
						var d := p.distance_squared_to(q[0])
						if d < best:
							best = d
							bp = q[0]
							var w: Vector3 = q[1]
							bn = (na[ti] * w.x + nb[ti] * w.y + nc[ti] * w.z).normalized()
		if best < INF: return [bp, bn, sqrt(best)]
	return []

## the first surface a ray from o along d meets within maxd, facing against it: [point, normal, distance] or []
func ray(o: Vector3, d: Vector3, maxd: float) -> Array:
	var seen := {}
	var best := INF
	var bp := Vector3.ZERO
	var bn := Vector3.UP
	# (only the cells the ray passes through: every triangle is in each cell its box touches, so none is missed; the
	# steps are a quarter cell, so a ray cutting a cell's corner still looks in it)
	var t := 0.0
	var last := Vector3i(1 << 30, 0, 0)
	while t <= maxd + CS:
		var key := _cell(o + d * t)
		t += CS * 0.25
		if key == last: continue
		last = key
		if not cells.has(key): continue
		for ti: int in cells[key]:
			if seen.has(ti): continue
			seen[ti] = true
			var h := _hit(o, d, ta[ti], tb[ti], tc[ti])
			if h.x > 0.0005 and h.x < best and h.x <= maxd:
				var nn: Vector3 = (na[ti] * (1.0 - h.y - h.z) + nb[ti] * h.y + nc[ti] * h.z).normalized()
				if nn.dot(d) < 0.0:
					best = h.x
					bp = o + d * h.x
					bn = nn
		if best <= t: break
	return [bp, bn, best] if best < INF else []

## Möller–Trumbore: (distance, u, v) — distance -1 if missed
static func _hit(o: Vector3, d: Vector3, a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var e1 := b - a
	var e2 := c - a
	var pv := d.cross(e2)
	var det := e1.dot(pv)
	if absf(det) < 1e-9: return Vector3(-1, 0, 0)
	var inv := 1.0 / det
	var tv := o - a
	var u := tv.dot(pv) * inv
	if u < 0.0 or u > 1.0: return Vector3(-1, 0, 0)
	var qv := tv.cross(e1)
	var v := d.dot(qv) * inv
	if v < 0.0 or u + v > 1.0: return Vector3(-1, 0, 0)
	return Vector3(e2.dot(qv) * inv, u, v)

## the nearest point of a triangle to p (Ericson, Real-Time Collision Detection 5.1.5): [point, barycentric weights]
static func _on_tri(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> Array:
	var ab := b - a
	var ac := c - a
	var ap := p - a
	var d1 := ab.dot(ap)
	var d2 := ac.dot(ap)
	if d1 <= 0.0 and d2 <= 0.0: return [a, Vector3(1, 0, 0)]
	var bp := p - b
	var d3 := ab.dot(bp)
	var d4 := ac.dot(bp)
	if d3 >= 0.0 and d4 <= d3: return [b, Vector3(0, 1, 0)]
	var vc := d1 * d4 - d3 * d2
	if vc <= 0.0 and d1 >= 0.0 and d3 <= 0.0:
		var v := d1 / (d1 - d3)
		return [a + ab * v, Vector3(1.0 - v, v, 0)]
	var cp := p - c
	var d5 := ab.dot(cp)
	var d6 := ac.dot(cp)
	if d6 >= 0.0 and d5 <= d6: return [c, Vector3(0, 0, 1)]
	var vb := d5 * d2 - d1 * d6
	if vb <= 0.0 and d2 >= 0.0 and d6 <= 0.0:
		var w := d2 / (d2 - d6)
		return [a + ac * w, Vector3(1.0 - w, 0, w)]
	var va := d3 * d6 - d5 * d4
	if va <= 0.0 and (d4 - d3) >= 0.0 and (d5 - d6) >= 0.0:
		var w2 := (d4 - d3) / ((d4 - d3) + (d5 - d6))
		return [b + (c - b) * w2, Vector3(0, 1.0 - w2, w2)]
	var den := 1.0 / (va + vb + vc)
	var v2 := vb * den
	var w3 := vc * den
	return [a + ab * v2 + ac * w3, Vector3(1.0 - v2 - w3, v2, w3)]

## water running over the surface from p0: each step slides downhill along it (gravity on the tangent plane, a little
## inertia, a sideways pull `drift`), stuck to the real surface. Where the surface turns under (faces down past
## `let_go`) or the next step finds no surface, it falls straight down (a ray) to what is below and runs on; with
## nothing below it pours off and stops. Returns {runs: [[points, normals], ...], drops: [[from, to, normal at to], ...],
## pour: true if it poured off at the end, end: [point, normal]}
func run(p0: Vector3, down: Vector3, step: float, maxlen: float, drift := Vector3.ZERO, let_go := 0.55) -> Dictionary:
	var c := closest(p0)
	if c.is_empty(): return {}
	var p: Vector3 = c[0]
	var nv: Vector3 = c[1]
	var runs := [[[p], [nv]]]
	var drops := []
	var pour := false
	var dir := Vector3.ZERO
	var length := 0.0
	var k := 0
	while length < maxlen and k < 400:
		k += 1
		var fall := nv.dot(down) > let_go
		var q := p
		if not fall:
			var g := down - nv * down.dot(nv)
			if g.length() < 0.1:
				# level: it keeps the way it was going, or (none yet) stays
				if dir == Vector3.ZERO: break
				g = dir
			g = g.normalized()
			if drift != Vector3.ZERO:
				var dd := drift - nv * drift.dot(nv)
				g = (g + dd * (0.8 + 0.4 * sin(float(k) * 0.7))).normalized()
			dir = (g + dir * 0.6).normalized() if dir != Vector3.ZERO else g
			dir = (dir - nv * dir.dot(nv)).normalized()
			q = p + dir * step
			var cq := closest(q)
			if cq.is_empty() or (cq[2] as float) > step * 1.5:
				fall = true
			else:
				p = cq[0]
				nv = cq[1]
				(runs[runs.size() - 1][0] as Array).append(p)
				(runs[runs.size() - 1][1] as Array).append(nv)
				length += step
		if fall:
			var h := ray(q + nv * 0.003 + down * 0.002, down, 0.6)
			if h.is_empty():
				pour = true
				break
			drops.append([p, h[0], h[1]])
			p = h[0]
			nv = h[1]
			runs.append([[p], [nv]])
			dir = Vector3.ZERO
			length += 0.02
	return {runs = runs, drops = drops, pour = pour, end = [p, nv]}
