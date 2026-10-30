class_name SpecMask
extends RefCounted

## The shaders' own noise (shaders/opal.gdshaderinc: h3, vn, fbm, vor2) in GDScript, so a builder can find where a
## shader paints a gene (lichen, moss, galleries, froth, opal pools) and point its callout there, not at bare stone.

const U := preload("res://scripts/specimen/spec_util.gd")

static func _fr(x: float) -> float:
	return x - floor(x)

## the hash. It multiplies numbers up to ~250 000 and keeps the fraction, so in doubles it drifts from the video
## card's float32 by a few hundredths — fine for smooth noise and cell centres; where a hash decides yes or no (is
## this cell lichen?) use h3x, which rounds every step the way the card does
static func h3(p: Vector3) -> float:
	var x := _fr(p.x * 0.3183099 + 0.1) * 17.0
	var y := _fr(p.y * 0.3183099 + 0.1) * 17.0
	var z := _fr(p.z * 0.3183099 + 0.1) * 17.0
	return _fr(x * y * z * (x + y + z))

static var _f := PackedFloat32Array([0.0])
static func f32(x: float) -> float:
	_f[0] = x
	return _f[0]

static func _h1(x: float) -> float:
	var t := f32(f32(f32(x) * 0.3183099) + 0.1)
	return f32(f32(t - floor(t)) * 17.0)

static func h3x(p: Vector3) -> float:
	var x := _h1(p.x)
	var y := _h1(p.y)
	var z := _h1(p.z)
	var t := f32(f32(f32(x * y) * z) * f32(f32(x + y) + z))
	return t - floor(t)

static func vn(x: Vector3) -> float:
	var i := x.floor()
	var f := x - i
	f = f * f * (Vector3(3, 3, 3) - 2.0 * f)
	var a := lerpf(lerpf(h3(i), h3(i + Vector3(1, 0, 0)), f.x), lerpf(h3(i + Vector3(0, 1, 0)), h3(i + Vector3(1, 1, 0)), f.x), f.y)
	var b := lerpf(lerpf(h3(i + Vector3(0, 0, 1)), h3(i + Vector3(1, 0, 1)), f.x), lerpf(h3(i + Vector3(0, 1, 1)), h3(i + Vector3(1, 1, 1)), f.x), f.y)
	return lerpf(a, b, f.z)

static func fbm(p: Vector3) -> float:
	return vn(p) * 0.5 + vn(p * 2.03) * 0.25 + vn(p * 4.01) * 0.125 + vn(p * 8.02) * 0.0625

## cells: x = distance to the nearest centre, y = distance to the edge between cells, z = the cell's own random
static func vor2(q: Vector2) -> Vector3:
	var c := q.floor()
	var d1 := 9.0
	var d2 := 9.0
	var id := 0.0
	for y in range(-1, 2):
		for x in range(-1, 2):
			var g := c + Vector2(x, y)
			var pt := g + Vector2(h3(Vector3(g.x, g.y, 1.0)), h3(Vector3(g.x, g.y, 7.0))) * 0.8 + Vector2(0.1, 0.1)
			var d := pt.distance_to(q)
			if d < d1:
				d2 = d1
				d1 = d
				id = h3x(Vector3(g.x, g.y, 13.0))
			elif d < d2:
				d2 = d
	return Vector3(d1, d2 - d1, id)

## the same, wrapping round: q.y in cells, period n cells
static func vor2w(q: Vector2, n: float) -> Vector3:
	var c := q.floor()
	var d1 := 9.0
	var d2 := 9.0
	var id := 0.0
	for y in range(-1, 2):
		for x in range(-1, 2):
			var g := c + Vector2(x, y)
			var gw := Vector2(g.x, fposmod(g.y, n))
			var pt := g + Vector2(h3(Vector3(gw.x, gw.y, 1.0)), h3(Vector3(gw.x, gw.y, 7.0))) * 0.8 + Vector2(0.1, 0.1)
			var d := pt.distance_to(q)
			if d < d1:
				d2 = d1
				d1 = d
				id = h3x(Vector3(gw.x, gw.y, 13.0))
			elif d < d2:
				d2 = d
	return Vector3(d1, d2 - d1, id)

## where on these meshes a shader paints something: score(pos, uv, uv2, colour) → 0..1 for a vertex (in the mesh's
## own space, as the shader sees it). Returns up to n [point, normal] in root's space: in the patches the shader paints
## most fully (the share of a little cell's vertices in it — a lone vertex where the card's rounding and ours differ
## never wins, and a finely meshed twig no more than a coarse trunk), facing the viewer (every find is shown turned
## 0.6 about y), spread apart. Big meshes are sampled, not read whole.
static func spots(meshes: Array, root: Node3D, score: Callable, n := 3, budget := 8000) -> Array:
	var view := Basis(Vector3.UP, -0.6) * Vector3.BACK
	var cells := {}
	var total := 0
	for mi: MeshInstance3D in meshes:
		if mi.mesh: total += mi.mesh.surface_get_array_len(0)
		elif mi.has_meta("geo"): total += (mi.get_meta("geo") as Geo).v.size()
	var step := maxi(1, total / budget)
	for mi: MeshInstance3D in meshes:
		var xf := U.rel_xform(mi, root)
		var vs: PackedVector3Array
		var ns: PackedVector3Array
		var uvs := PackedVector2Array()
		var uv2s := PackedVector2Array()
		var cols := PackedColorArray()
		if mi.mesh:
			var arr := mi.mesh.surface_get_arrays(0)
			vs = arr[Mesh.ARRAY_VERTEX]
			ns = arr[Mesh.ARRAY_NORMAL]
			if arr[Mesh.ARRAY_TEX_UV] != null: uvs = arr[Mesh.ARRAY_TEX_UV]
			if arr[Mesh.ARRAY_TEX_UV2] != null: uv2s = arr[Mesh.ARRAY_TEX_UV2]
			if arr[Mesh.ARRAY_COLOR] != null: cols = arr[Mesh.ARRAY_COLOR]
		elif mi.has_meta("geo"):
			# a mesh the builder only makes at the end (rock under the dirt shader): its geometry, and the rock-line
			# coordinates SpecimenBuilder._finish will give it (the specimen-space position, or 0..1 up a "local" one)
			var g: Geo = mi.get_meta("geo")
			vs = g.v
			ns = g.own_n if g.own_n.size() == g.v.size() else g.normals()
			cols = g.col
			var bb := g.aabb()
			var local: bool = mi.get_meta("local", false)
			uvs.resize(vs.size())
			uv2s.resize(vs.size())
			for i in range(0, vs.size(), step):
				var rp: Vector3 = (vs[i] - bb.position) / maxf(0.001, bb.size.y) if local else xf * vs[i]
				uvs[i] = Vector2(rp.x, rp.y)
				uv2s[i] = Vector2(rp.z, 0.0)
		else:
			continue
		for i in range(0, vs.size(), step):
			var nw := (xf.basis * ns[i]).normalized()
			var face := nw.dot(view)
			if face < 0.3: continue
			var p := xf * vs[i]
			var key := Vector3i((p / 0.09).floor())
			if not cells.has(key): cells[key] = [0, []]
			var cell: Array = cells[key]
			cell[0] = int(cell[0]) + 1
			var s: float = score.call(vs[i], uvs[i] if i < uvs.size() else Vector2.ZERO, uv2s[i] if i < uv2s.size() else Vector2.ZERO,
				cols[i] if i < cols.size() else Color(1, 1, 1))
			if s < 0.5: continue
			(cell[1] as Array).append([s * face, p, nw])
	# each cell's worth: how much of it is painted, how fully, how square to the viewer; its spot the painted vertex
	# nearest the painted ones' middle
	var picks := []
	for key: Vector3i in cells:
		var cell: Array = cells[key]
		var ins: Array = cell[1]
		if ins.size() < 2: continue
		var mid := Vector3.ZERO
		var sum := 0.0
		for c: Array in ins:
			mid += c[1]
			sum += float(c[0])
		mid /= ins.size()
		var best: Array = ins[0]
		for c: Array in ins:
			if (c[1] as Vector3).distance_squared_to(mid) < (best[1] as Vector3).distance_squared_to(mid): best = c
		picks.append([sum / int(cell[0]) * minf(1.0, ins.size() / 4.0), best[1], best[2]])
	picks.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	# spread: no two picked closer than a tenth of the find
	var out := []
	for c: Array in picks:
		var far := true
		for o: Array in out:
			if (o[0] as Vector3).distance_to(c[1]) < 0.2: far = false
		if far: out.append([c[1], c[2]])
		if out.size() >= n: break
	return out
