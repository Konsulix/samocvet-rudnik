class_name Geo
extends RefCounted
## A small mesh under construction: positions, optional triangle indices (none = a plain triangle list),
## optional vertex colours. The generators follow three.js's geometry classes vertex for vertex,
## so the specimen code ports over line by line. Winding is three.js's (counter-clockwise);
## to_mesh() flips it for Godot.

var v := PackedVector3Array()
var idx := PackedInt32Array()
var col := PackedColorArray()
var rp := PackedVector3Array()   # rock-line coordinates for the DIRT shader
var bary := PackedVector3Array() # distance to the real edges of each face (for the silver rims)
var _mesh: ArrayMesh

func indexed() -> bool:
	return idx.size() > 0

func tri_count() -> int:
	return idx.size() / 3 if indexed() else v.size() / 3

func translate(x: float, y: float, z: float) -> Geo:
	var d := Vector3(x, y, z)
	for i in v.size():
		v[i] += d
	return self

func scale(x: float, y: float, z: float) -> Geo:
	var s := Vector3(x, y, z)
	for i in v.size():
		v[i] *= s
	return self

func xform(t: Transform3D) -> Geo:
	for i in v.size():
		v[i] = t * v[i]
	return self

func to_soup() -> Geo:
	if not indexed():
		return self
	var nv := PackedVector3Array()
	var nc := PackedColorArray()
	nv.resize(idx.size())
	if col.size():
		nc.resize(idx.size())
	for k in idx.size():
		nv[k] = v[idx[k]]
		if col.size():
			nc[k] = col[idx[k]]
	v = nv
	col = nc
	idx = PackedInt32Array()
	return self

func aabb() -> AABB:
	if v.is_empty():
		return AABB()
	var lo := v[0]
	var hi := v[0]
	for p in v:
		lo = lo.min(p)
		hi = hi.max(p)
	return AABB(lo, hi - lo)

func tri(k: int) -> Array[Vector3]:
	if indexed():
		return [v[idx[k * 3]], v[idx[k * 3 + 1]], v[idx[k * 3 + 2]]]
	return [v[k * 3], v[k * 3 + 1], v[k * 3 + 2]]

## make every triangle face away from `c` (for closed convex shapes)
func orient_out(c := Vector3.ZERO) -> Geo:
	for k in tri_count():
		var t := tri(k)
		var nrm := (t[1] - t[0]).cross(t[2] - t[0])
		if nrm.dot((t[0] + t[1] + t[2]) / 3.0 - c) < 0.0:
			if indexed():
				var s := idx[k * 3 + 1]
				idx[k * 3 + 1] = idx[k * 3 + 2]
				idx[k * 3 + 2] = s
			else:
				var s2 := v[k * 3 + 1]
				v[k * 3 + 1] = v[k * 3 + 2]
				v[k * 3 + 2] = s2
				if col.size():
					var c2 := col[k * 3 + 1]
					col[k * 3 + 1] = col[k * 3 + 2]
					col[k * 3 + 2] = c2
	return self

func normals() -> PackedVector3Array:
	var n := PackedVector3Array()
	n.resize(v.size())
	if indexed():
		for k in range(0, idx.size(), 3):
			var a := idx[k]
			var b := idx[k + 1]
			var c := idx[k + 2]
			var f := (v[c] - v[b]).cross(v[a] - v[b])
			n[a] += f
			n[b] += f
			n[c] += f
	else:
		for k in range(0, v.size(), 3):
			var f := (v[k + 2] - v[k + 1]).cross(v[k] - v[k + 1])
			n[k] = f
			n[k + 1] = f
			n[k + 2] = f
	for i in n.size():
		n[i] = n[i].normalized() if n[i].length_squared() > 0.0 else Vector3.UP
	return n

func fill_color(c: Color) -> Geo:
	col.resize(v.size())
	col.fill(c)
	return self

func to_mesh() -> ArrayMesh:
	if _mesh and rp.is_empty():
		return _mesh
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = normals()
	if col.size() == v.size():
		arr[Mesh.ARRAY_COLOR] = col
	if rp.size() == v.size():
		var uv := PackedVector2Array()
		var uv2 := PackedVector2Array()
		uv.resize(v.size())
		uv2.resize(v.size())
		for i in v.size():
			uv[i] = Vector2(rp[i].x, rp[i].y)
			uv2[i] = Vector2(rp[i].z, 0.0)
		arr[Mesh.ARRAY_TEX_UV] = uv
		arr[Mesh.ARRAY_TEX_UV2] = uv2
	var flags := 0
	if bary.size() == v.size():
		var c0 := PackedFloat32Array()
		c0.resize(v.size() * 4)
		for i in v.size():
			c0[i * 4] = bary[i].x
			c0[i * 4 + 1] = bary[i].y
			c0[i * 4 + 2] = bary[i].z
			c0[i * 4 + 3] = 1.0
		arr[Mesh.ARRAY_CUSTOM0] = c0
		flags = Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
	# three.js winds counter-clockwise, Godot's front faces are clockwise
	if indexed():
		var f := idx.duplicate()
		for k in range(0, f.size(), 3):
			var s := f[k + 1]
			f[k + 1] = f[k + 2]
			f[k + 2] = s
		arr[Mesh.ARRAY_INDEX] = f
	else:
		var order := PackedInt32Array()
		order.resize(v.size())
		for k in range(0, v.size(), 3):
			order[k] = k
			order[k + 1] = k + 2
			order[k + 2] = k + 1
		arr[Mesh.ARRAY_INDEX] = order
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, flags)
	if rp.is_empty():
		_mesh = m
	return m

## merge vertices that share a position, so normals come out smooth
func weld() -> Geo:
	to_soup()
	var map := {}
	var nv := PackedVector3Array()
	var nc := PackedColorArray()
	var ni := PackedInt32Array()
	ni.resize(v.size())
	for i in v.size():
		var p := v[i]
		var key := Vector3i(roundi(p.x * 20000.0), roundi(p.y * 20000.0), roundi(p.z * 20000.0))
		var k: int = map.get(key, -1)
		if k < 0:
			k = nv.size()
			map[key] = k
			nv.append(p)
			if col.size(): nc.append(col[i])
		ni[i] = k
	v = nv
	col = nc
	idx = ni
	return self

## split every triangle into four (a plain triangle list); shared edges split at the same points
func subdivide(levels := 1) -> Geo:
	to_soup()
	for l in levels:
		var nv := PackedVector3Array()
		var nc := PackedColorArray()
		var has_c := col.size() == v.size()
		var has_b := bary.size() == v.size()
		var nb := PackedVector3Array()
		for k in range(0, v.size(), 3):
			var a := v[k]
			var b := v[k + 1]
			var c := v[k + 2]
			var ab := (a + b) * 0.5
			var bc := (b + c) * 0.5
			var ca := (c + a) * 0.5
			nv.append_array([a, ab, ca, ab, b, bc, ca, bc, c, ab, bc, ca])
			if has_c:
				var x := col[k]
				var y := col[k + 1]
				var z := col[k + 2]
				var xy := x.lerp(y, 0.5)
				var yz := y.lerp(z, 0.5)
				var zx := z.lerp(x, 0.5)
				nc.append_array([x, xy, zx, xy, y, yz, zx, yz, z, xy, yz, zx])
			if has_b:
				var x2 := bary[k]
				var y2 := bary[k + 1]
				var z2 := bary[k + 2]
				var xy2 := (x2 + y2) * 0.5
				var yz2 := (y2 + z2) * 0.5
				var zx2 := (z2 + x2) * 0.5
				nb.append_array([x2, xy2, zx2, xy2, y2, yz2, zx2, yz2, z2, xy2, yz2, zx2])
		v = nv
		col = nc
		bary = nb
	return self

## find which triangle edges are real edges of the shape (a crease or an open border), as opposed to
## diagonals that split a flat face; store per-vertex barycentrics where only real edges reach zero
func mark_edges(angle_deg := 14.0) -> Geo:
	to_soup()
	var key := func(p: Vector3) -> Vector3i: return Vector3i(roundi(p.x * 5000.0), roundi(p.y * 5000.0), roundi(p.z * 5000.0))
	var nt := v.size() / 3
	var fn := PackedVector3Array()
	fn.resize(nt)
	var edges := {}
	for t in nt:
		fn[t] = (v[t * 3 + 1] - v[t * 3]).cross(v[t * 3 + 2] - v[t * 3]).normalized()
		for e in 3:
			var a: Vector3i = key.call(v[t * 3 + (e + 1) % 3])
			var b: Vector3i = key.call(v[t * 3 + (e + 2) % 3])
			var k2 := [a, b] if (a.x < b.x or (a.x == b.x and (a.y < b.y or (a.y == b.y and a.z < b.z)))) else [b, a]
			var ks := str(k2)
			if not edges.has(ks): edges[ks] = []
			edges[ks].append(t)
	var cos_lim := cos(deg_to_rad(angle_deg))
	bary.resize(v.size())
	for t in nt:
		var add := Vector3.ZERO
		for e in 3:
			var a: Vector3i = key.call(v[t * 3 + (e + 1) % 3])
			var b: Vector3i = key.call(v[t * 3 + (e + 2) % 3])
			var k2 := [a, b] if (a.x < b.x or (a.x == b.x and (a.y < b.y or (a.y == b.y and a.z < b.z)))) else [b, a]
			var ts: Array = edges[str(k2)]
			var real := ts.size() < 2
			for o in ts:
				if o != t and absf(fn[o].dot(fn[t])) < cos_lim:
					real = true
			if not real:
				add[e] = 10.0
		# each corner carries its height above the opposite edge, so the interpolated values are true distances
		var A := v[t * 3]
		var Bv := v[t * 3 + 1]
		var C := v[t * 3 + 2]
		var area2 := (Bv - A).cross(C - A).length()
		var ha := area2 / maxf(0.0001, Bv.distance_to(C))
		var hb := area2 / maxf(0.0001, C.distance_to(A))
		var hc := area2 / maxf(0.0001, A.distance_to(Bv))
		bary[t * 3] = Vector3(ha, 0, 0) + add
		bary[t * 3 + 1] = Vector3(0, hb, 0) + add
		bary[t * 3 + 2] = Vector3(0, 0, hc) + add
	return self

## nudge every vertex by a smooth function of where it is (shared corners move together)
func jitter(amp: float, freq: float, seed_v: int) -> Geo:
	var fn := FastNoiseLite.new()
	fn.seed = seed_v
	fn.frequency = freq
	for i in v.size():
		var p := v[i]
		v[i] = p + Vector3(fn.get_noise_3dv(p), fn.get_noise_3dv(p + Vector3(31.7, 0, 0)), fn.get_noise_3dv(p + Vector3(0, 0, 57.3))) * amp
	return self

# ---------------------------------------------------------------- generators (three.js r128 layouts)

static func lathe(pts: Array, segs: int, phi_len := TAU) -> Geo:
	var g := Geo.new()
	var n := pts.size()
	for i in segs + 1:
		var phi := float(i) / segs * phi_len
		var s := sin(phi)
		var c := cos(phi)
		for p: Vector2 in pts:
			g.v.append(Vector3(p.x * s, p.y, p.x * c))
	for i in segs:
		for j in n - 1:
			var a := i * n + j
			var b := a + n
			var c2 := a + n + 1
			var d := a + 1
			g.idx.append_array([a, b, d, c2, d, b])
	return g

static func sphere(r: float, ws: int, hs: int, phi0 := 0.0, phi_len := TAU, th0 := 0.0, th_len := PI) -> Geo:
	var g := Geo.new()
	var th_end := minf(th0 + th_len, PI)
	var grid := []
	for iy in hs + 1:
		var row := []
		var vv := float(iy) / hs
		for ix in ws + 1:
			var u := float(ix) / ws
			g.v.append(Vector3(-r * cos(phi0 + u * phi_len) * sin(th0 + vv * th_len), r * cos(th0 + vv * th_len), r * sin(phi0 + u * phi_len) * sin(th0 + vv * th_len)))
			row.append(g.v.size() - 1)
		grid.append(row)
	for iy in hs:
		for ix in ws:
			var a: int = grid[iy][ix + 1]
			var b: int = grid[iy][ix]
			var c: int = grid[iy + 1][ix]
			var d: int = grid[iy + 1][ix + 1]
			if iy != 0 or th0 > 0.0:
				g.idx.append_array([a, b, d])
			if iy != hs - 1 or th_end < PI:
				g.idx.append_array([b, c, d])
	return g

static func torus(R: float, tube: float, rs: int, ts: int, arc := TAU) -> Geo:
	var g := Geo.new()
	for j in rs + 1:
		for i in ts + 1:
			var u := float(i) / ts * arc
			var w := float(j) / rs * TAU
			g.v.append(Vector3((R + tube * cos(w)) * cos(u), (R + tube * cos(w)) * sin(u), tube * sin(w)))
	for j in range(1, rs + 1):
		for i in range(1, ts + 1):
			var a := (ts + 1) * j + i - 1
			var b := (ts + 1) * (j - 1) + i - 1
			var c := (ts + 1) * (j - 1) + i
			var d := (ts + 1) * j + i
			g.idx.append_array([a, b, d, b, c, d])
	return g

static func cylinder(rt: float, rb: float, h: float, rseg: int, hseg := 1, open := false, th0 := 0.0, th_len := TAU) -> Geo:
	var g := Geo.new()
	var rows := []
	var hh := h / 2.0
	for y in hseg + 1:
		var row := []
		var vv := float(y) / hseg
		var rad := vv * (rb - rt) + rt
		for x in rseg + 1:
			var th := float(x) / rseg * th_len + th0
			g.v.append(Vector3(rad * sin(th), -vv * h + hh, rad * cos(th)))
			row.append(g.v.size() - 1)
		rows.append(row)
	for x in rseg:
		for y in hseg:
			var a: int = rows[y][x]
			var b: int = rows[y + 1][x]
			var c: int = rows[y + 1][x + 1]
			var d: int = rows[y][x + 1]
			g.idx.append_array([a, b, d, b, c, d])
	if not open:
		for top in [true, false]:
			var rad := rt if top else rb
			if rad <= 0.0:
				continue
			var yy := hh if top else -hh
			var c0 := g.v.size()
			g.v.append(Vector3(0, yy, 0))
			var r0 := g.v.size()
			for x in rseg + 1:
				var th := float(x) / rseg * th_len + th0
				g.v.append(Vector3(rad * sin(th), yy, rad * cos(th)))
			for x in rseg:
				if top:
					g.idx.append_array([r0 + x, r0 + x + 1, c0])
				else:
					g.idx.append_array([r0 + x + 1, r0 + x, c0])
	return g

static func cone(r: float, h: float, seg: int) -> Geo:
	return cylinder(0.0, r, h, seg)

static func box(w: float, h: float, d: float) -> Geo:
	var g := Geo.new()
	var x := w / 2.0
	var y := h / 2.0
	var z := d / 2.0
	var c := [Vector3(-x, -y, -z), Vector3(x, -y, -z), Vector3(x, y, -z), Vector3(-x, y, -z), Vector3(-x, -y, z), Vector3(x, -y, z), Vector3(x, y, z), Vector3(-x, y, z)]
	for q in [[0, 1, 2, 3], [5, 4, 7, 6], [4, 0, 3, 7], [1, 5, 6, 2], [3, 2, 6, 7], [4, 5, 1, 0]]:
		g.v.append_array([c[q[0]], c[q[1]], c[q[2]], c[q[0]], c[q[2]], c[q[3]]])
	return g.orient_out()

static func _poly(verts: Array, faces: Array, r: float, detail: int) -> Geo:
	var g := Geo.new()
	for f in range(0, faces.size(), 3):
		var a: Vector3 = verts[faces[f]]
		var b: Vector3 = verts[faces[f + 1]]
		var c: Vector3 = verts[faces[f + 2]]
		var cols := detail + 1
		var grid := []
		for i in cols + 1:
			var aj := a.lerp(c, float(i) / cols)
			var bj := b.lerp(c, float(i) / cols)
			var rows := cols - i
			var row := []
			for j in rows + 1:
				row.append(aj if j == 0 and rows == 0 else aj.lerp(bj, float(j) / rows))
			grid.append(row)
		for i in cols:
			for j in 2 * (cols - i) - 1:
				var k := j / 2
				if j % 2 == 0:
					g.v.append_array([grid[i][k + 1], grid[i + 1][k], grid[i][k]])
				else:
					g.v.append_array([grid[i][k + 1], grid[i + 1][k + 1], grid[i + 1][k]])
	for i in g.v.size():
		g.v[i] = g.v[i].normalized() * r
	return g.orient_out()

static func octa(r: float) -> Geo:
	return _poly([Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, -1, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)],
		[0, 2, 4, 0, 4, 3, 0, 3, 5, 0, 5, 2, 1, 2, 5, 1, 5, 3, 1, 3, 4, 1, 4, 2], r, 0)

static func icosa(r: float, detail := 0) -> Geo:
	var t := (1.0 + sqrt(5.0)) / 2.0
	return _poly([Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0), Vector3(0, -1, t), Vector3(0, 1, t),
		Vector3(0, -1, -t), Vector3(0, 1, -t), Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)],
		[0, 11, 5, 0, 5, 1, 0, 1, 7, 0, 7, 10, 0, 10, 11, 1, 5, 9, 5, 11, 4, 11, 10, 2, 10, 7, 6, 7, 1, 8,
		3, 9, 4, 3, 4, 2, 3, 2, 6, 3, 6, 8, 3, 8, 9, 4, 9, 5, 2, 4, 11, 6, 2, 10, 8, 6, 7, 9, 8, 1], r, detail)

static func dodeca(r: float) -> Geo:
	var t := (1.0 + sqrt(5.0)) / 2.0
	var q := 1.0 / t
	return _poly([Vector3(-1, -1, -1), Vector3(-1, -1, 1), Vector3(-1, 1, -1), Vector3(-1, 1, 1), Vector3(1, -1, -1), Vector3(1, -1, 1), Vector3(1, 1, -1), Vector3(1, 1, 1),
		Vector3(0, -q, -t), Vector3(0, -q, t), Vector3(0, q, -t), Vector3(0, q, t), Vector3(-q, -t, 0), Vector3(-q, t, 0), Vector3(q, -t, 0), Vector3(q, t, 0),
		Vector3(-t, 0, -q), Vector3(t, 0, -q), Vector3(-t, 0, q), Vector3(t, 0, q)],
		[3, 11, 7, 3, 7, 15, 3, 15, 13, 7, 19, 17, 7, 17, 6, 7, 6, 15, 17, 4, 8, 17, 8, 10, 17, 10, 6, 8, 0, 16, 8, 16, 2, 8, 2, 10,
		0, 12, 1, 0, 1, 18, 0, 18, 16, 6, 10, 2, 6, 2, 13, 6, 13, 15, 2, 16, 18, 2, 18, 3, 2, 3, 13, 18, 1, 9, 18, 9, 11, 18, 11, 3,
		4, 14, 12, 4, 12, 0, 4, 0, 8, 11, 9, 5, 11, 5, 19, 11, 19, 7, 19, 5, 14, 19, 14, 4, 19, 4, 17, 1, 12, 14, 1, 14, 5, 1, 5, 9], r, 0)

static func ring(inner: float, outer: float, ts: int, ps: int) -> Geo:
	var g := Geo.new()
	for j in ps + 1:
		var rad := inner + float(j) * (outer - inner) / ps
		for i in ts + 1:
			var a := float(i) / ts * TAU
			g.v.append(Vector3(rad * cos(a), rad * sin(a), 0))
	for j in ps:
		var lvl := j * (ts + 1)
		for i in ts:
			var s := i + lvl
			var a2 := s
			var b := s + ts + 1
			var c := s + ts + 2
			var d := s + 1
			g.idx.append_array([a2, b, d, b, c, d])
	return g

## a hopper crystal: a cube whose faces sink in steps towards the middle, as salt and bismuth grow
static func hopper(h: float, steps := 3, depth := 0.26) -> Geo:
	var g := Geo.new()
	var axes := [[Vector3.RIGHT, Vector3.UP, Vector3.BACK], [Vector3.LEFT, Vector3.UP, Vector3.FORWARD], [Vector3.UP, Vector3.BACK, Vector3.RIGHT],
		[Vector3.DOWN, Vector3.FORWARD, Vector3.RIGHT], [Vector3.BACK, Vector3.UP, Vector3.LEFT], [Vector3.FORWARD, Vector3.UP, Vector3.RIGHT]]
	var quad := func(a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
		g.v.append_array([a, b, c, a, c, d])
	for ax in axes:
		var N: Vector3 = ax[0]
		var T: Vector3 = ax[1]
		var B: Vector3 = ax[2]
		var P := func(u: float, w: float, dep: float) -> Vector3: return N * (h - dep) + T * u + B * w
		for i in steps:
			var r0 := h * (1.0 - float(i) / (steps + 0.4))
			var r1 := h * (1.0 - float(i + 1) / (steps + 0.4))
			var d0 := h * depth * pow(float(i) / steps, 0.8)
			var d1 := h * depth * pow(float(i + 1) / steps, 0.8)
			var corners := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
			for k in 4:
				var c0: Vector2 = corners[k]
				var c1: Vector2 = corners[(k + 1) % 4]
				# the terrace at this depth, then the riser down to the next one
				quad.call(P.call(c0.x * r0, c0.y * r0, d0), P.call(c1.x * r0, c1.y * r0, d0), P.call(c1.x * r1, c1.y * r1, d0), P.call(c0.x * r1, c0.y * r1, d0))
				quad.call(P.call(c0.x * r1, c0.y * r1, d0), P.call(c1.x * r1, c1.y * r1, d0), P.call(c1.x * r1, c1.y * r1, d1), P.call(c0.x * r1, c0.y * r1, d1))
			if i == steps - 1:
				quad.call(P.call(-r1, -r1, d1), P.call(r1, -r1, d1), P.call(r1, r1, d1), P.call(-r1, r1, d1))
	return g

static func plane(w: float, h: float) -> Geo:
	var g := Geo.new()
	g.v.append_array([Vector3(-w / 2, h / 2, 0), Vector3(w / 2, h / 2, 0), Vector3(-w / 2, -h / 2, 0), Vector3(w / 2, -h / 2, 0)])
	g.idx.append_array([0, 2, 1, 2, 3, 1])
	return g

## a tube along a Catmull-Rom curve through `pts`
static func tube(pts: Array, segs: int, r: float, rseg: int) -> Geo:
	var g := Geo.new()
	var path := []
	for k in segs + 1:
		var t := float(k) / segs * (pts.size() - 1)
		var i := mini(int(t), pts.size() - 2)
		var f := t - i
		var p0: Vector3 = pts[maxi(i - 1, 0)]
		var p1: Vector3 = pts[i]
		var p2: Vector3 = pts[i + 1]
		var p3: Vector3 = pts[mini(i + 2, pts.size() - 1)]
		path.append(p1.cubic_interpolate(p2, p0, p3, f))
	var nrm := Vector3.UP
	for k in segs + 1:
		var a: Vector3 = path[maxi(k - 1, 0)]
		var b: Vector3 = path[mini(k + 1, segs)]
		var tg := (b - a).normalized()
		nrm = (nrm - tg * nrm.dot(tg)).normalized()
		if nrm.length_squared() < 0.5:
			nrm = tg.cross(Vector3.RIGHT).normalized()
		var bi := tg.cross(nrm)
		for j in rseg + 1:
			var w := float(j) / rseg * TAU
			g.v.append(path[k] + (nrm * cos(w) + bi * sin(w)) * r)
	for k in segs:
		for j in rseg:
			var a2 := k * (rseg + 1) + j
			var b2 := a2 + rseg + 1
			g.idx.append_array([a2, b2, a2 + 1, b2, b2 + 1, a2 + 1])
	return g
