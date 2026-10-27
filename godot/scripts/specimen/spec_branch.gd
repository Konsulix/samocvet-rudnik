class_name SpecBranch
extends RefCounted
## Branching wood: a skeleton of branches grown from a seed — each bends and wanders, pulled up, forking a few times,
## thinning to broken tips — and a tube round each branch. The tube carries its own coordinates for
## shaders/branch.gdshader: UV.x = the distance along the branch in its own thicknesses (so a pattern keeps its size
## relative to the branch however thin it gets), UV.y = round it (0..1), UV2.x = its radius there;
## COLOR.r = 1 on the broken ends, COLOR.g = the branch's own random.
## Used by petrified wood (opal twigs, driftwood) and fulgurites.

const U := preload("res://scripts/specimen/spec_util.gd")
const SHADER := preload("res://shaders/branch.gdshader")

## the skeleton: [{pts, rad, depth}], grown from the origin upwards.
## o: r0 base radius, len0 trunk length, levels, kids [min, max] per branch (kids2: for the branches' own), kid_r / kid_len (share of the parent's),
##    spread (how far a fork turns, radians), gnarl (how much it wanders), up (pull upwards), taper (end radius share)
static func skeleton(rng: Rng32, o: Dictionary) -> Array:
	var out := []
	_grow(out, rng, o, Vector3.ZERO, Vector3.UP, float(o.r0), float(o.len0), 0)
	return out

static func _grow(out: Array, rng: Rng32, o: Dictionary, p0: Vector3, d0: Vector3, r0: float, ln: float, depth: int) -> void:
	var step := maxf(r0 * 0.55, 0.02)
	var n := maxi(5, int(ln / step))
	step = ln / n
	var pts: Array[Vector3] = [p0]
	var rad: Array[float] = [r0]
	var dirs: Array[Vector3] = [d0]
	var d := d0
	var p := p0
	var r_end := r0 * float(o.taper)
	# the wander turns smoothly: a heading that itself drifts
	var drift := Vector3(rng.next() - 0.5, rng.next() - 0.5, rng.next() - 0.5)
	for i in n:
		drift = (drift + Vector3(rng.next() - 0.5, rng.next() - 0.5, rng.next() - 0.5) * 0.7).limit_length(0.6)
		d = (d + drift * float(o.gnarl) * 0.35 + Vector3.UP * float(o.up) * 0.15).normalized()
		p += d * step
		var t := float(i + 1) / n
		pts.append(p)
		rad.append(lerpf(r0, r_end, pow(t, 0.8)))
		dirs.append(d)
	out.append({pts = pts, rad = rad, depth = depth, rnd = rng.next()})
	if depth >= int(o.levels):
		return
	var kids: Array = o.kids if depth == 0 else o.get("kids2", o.kids)
	var kmin: int = kids[0]
	var kmax: int = kids[1]
	var nk := kmin + int(rng.next() * (kmax - kmin + 1))
	for k in nk:
		var i := clampi(int(lerpf(0.35, 0.85, (float(k) + rng.next()) / nk) * n), 1, n - 1)
		var dd: Vector3 = dirs[i]
		# forks spread round the branch, each its own way round
		var perp := dd.cross(Vector3.RIGHT if absf(dd.x) < 0.9 else Vector3.FORWARD).normalized()
		var side := perp.rotated(dd, (float(k) + rng.next() * 0.6) / nk * TAU)
		var dc := dd.rotated(side, float(o.spread) * (0.6 + rng.next() * 0.6))
		_grow(out, rng, o, pts[i] - dd * rad[i] * 0.5, dc, rad[i] * float(o.kid_r), ln * float(o.kid_len) * (0.7 + rng.next() * 0.5), depth + 1)

## a smooth point along the polyline (Catmull-Rom), k in [0, n-1]
static func _cr(pts: Array, k: float) -> Vector3:
	var i := clampi(int(floor(k)), 0, pts.size() - 2)
	var t := k - i
	var p0: Vector3 = pts[maxi(i - 1, 0)]
	var p1: Vector3 = pts[i]
	var p2: Vector3 = pts[i + 1]
	var p3: Vector3 = pts[mini(i + 2, pts.size() - 1)]
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t)

## the tube round one branch. o: m (sides), sub (rings per skeleton step), lump (bulges), ridge (lengthwise ridges),
## flat (how flattened), seed, dent ({t0, t1 along the branch 0..1, a0 round it 0..1, wa half-width round it,
## depth}: a hollow worn into it, COLOR.b = how deep in it); root: the trunk's foot closed flat (COLOR.r 1)
static func tube(br: Dictionary, o: Dictionary, root: bool) -> Geo:
	var pts: Array = br.pts
	var rad: Array = br.rad
	var m: int = o.get("m", 16)
	var sub: int = o.get("sub", 3)
	var nz := FastNoiseLite.new()
	nz.seed = int(o.get("seed", 1)) + int(float(br.rnd) * 1000.0)
	nz.frequency = 1.0
	nz.fractal_octaves = 3
	var lump: float = o.get("lump", 0.15)
	var ridge: float = o.get("ridge", 0.06)
	var flat: float = o.get("flat", 0.85)
	var rid: float = br.rnd
	var dent: Dictionary = o.get("dent", {})
	# stretches [i0, i1] (in skeleton steps) where the tube is to be broken away (COLOR.b 1): a fulgurite's glass
	var glass: Array = o.get("glass", [])
	# fibres: sharp ridges twisting round the branch (weathered wood), their height in COLOR.a for the shader
	var fibre: float = o.get("fibre", 0.0)
	var twist: float = o.get("twist", 0.0)
	var fz := FastNoiseLite.new()
	fz.seed = nz.seed + 5
	fz.frequency = 1.0
	fz.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	fz.fractal_octaves = 3
	var g := Geo.new()
	var nr := (pts.size() - 1) * sub + 1
	var cs: Array[Vector3] = []
	var rs: Array[float] = []
	for i in nr:
		var k := float(i) / sub
		cs.append(_cr(pts, k))
		var i0 := mini(int(floor(k)), rad.size() - 2)
		rs.append(lerpf(rad[i0], rad[i0 + 1], k - i0))
	# the broken tip: the last rings close in fast and unevenly
	var tip := mini(4, nr - 2)
	# frames carried along (parallel transport), so the tube never twists by itself
	var tg := (cs[1] - cs[0]).normalized()
	if not tg.is_normalized():
		tg = Vector3.UP
	var nn := tg.cross(Vector3.RIGHT if absf(tg.x) < 0.9 else Vector3.FORWARD).normalized()
	var u := 0.0
	var grid: Array[Vector3] = []
	for i in nr:
		var t2 := (cs[mini(i + 1, nr - 1)] - cs[maxi(i - 1, 0)]).normalized()
		if not t2.is_normalized():
			t2 = tg
		nn = (nn - t2 * nn.dot(t2)).normalized()
		var bn := t2.cross(nn)
		var r: float = rs[i]
		if i > 0:
			u += cs[i].distance_to(cs[i - 1]) / maxf(r, 0.005)
		var close := 1.0
		if i >= nr - tip:
			close = lerpf(1.0, 0.35, float(i - (nr - tip) + 1) / tip)
		for j in m + 1:
			var a := TAU * float(j % m) / m
			var dv := nn * cos(a) + bn * sin(a) * flat
			var q := cs[i] + dv * r
			var l := 1.0 + nz.get_noise_3dv(q / maxf(r, 0.01) * 0.35 + Vector3(rid * 50.0, 0, 0)) * lump * 2.0
			l += nz.get_noise_2d(a * 3.0 / TAU * 6.0, u * 0.15 + rid * 30.0) * ridge
			var fv := 0.5
			if fibre > 0.0:
				var at := a + u * twist * 0.1
				fv = clampf(fz.get_noise_3d(cos(at) * 3.2, sin(at) * 3.2, u * 0.05 + rid * 20.0) * 0.5 + 0.5, 0.0, 1.0)
				l += (fv - 0.5) * fibre
			var dm := 0.0
			for gs: Array in glass:
				var kk := float(i) / sub
				dm = maxf(dm, smoothstep(float(gs[0]) - 0.4, float(gs[0]) + 0.2, kk) * (1.0 - smoothstep(float(gs[1]) - 0.2, float(gs[1]) + 0.4, kk)))
			if not dent.is_empty():
				var tt := float(i) / (nr - 1)
				var da := absf(wrapf(float(j % m) / m - float(dent.a0), -0.5, 0.5))
				var edge := nz.get_noise_2d(a * 4.0, tt * 9.0) * 0.25
				dm = smoothstep(float(dent.t0) - 0.04, float(dent.t0) + 0.06, tt + edge * 0.1) * (1.0 - smoothstep(float(dent.t1) - 0.06, float(dent.t1) + 0.04, tt + edge * 0.1))
				dm *= 1.0 - smoothstep(float(dent.wa) * 0.6, float(dent.wa), da + edge * 0.05)
				l *= 1.0 - float(dent.depth) * dm
			var pos := cs[i] + dv * r * l * close
			# the very end breaks off ragged: its last ring pushed in and out along the branch
			if i == nr - 1:
				pos += t2 * r * (nz.get_noise_2d(a * 2.0, 7.0 + rid * 10.0)) * 0.9
			g.v.append(pos)
			grid.append(pos)
			g.rp.append(Vector3(u, float(j) / m, r * close))
			g.col.append(Color(1.0 if i == nr - 1 else 0.0, rid, dm, fv))
	var row := m + 1
	for i in nr - 1:
		for j in m:
			var p0 := i * row + j
			g.idx.append_array([p0, p0 + row, p0 + 1, p0 + 1, p0 + row, p0 + row + 1])
	# normals from the grid's neighbours, wrapping round (the seam's two copies get the same one)
	g.own_n.resize(g.v.size())
	for i in nr:
		for j in m + 1:
			var jj := j % m
			var a := grid[i * row + (jj + 1) % m]
			var b := grid[i * row + (jj + m - 1) % m]
			var c := grid[mini(i + 1, nr - 1) * row + jj]
			var d := grid[maxi(i - 1, 0) * row + jj]
			var n := (c - d).cross(a - b).normalized()
			# outward: away from the axis
			if n.dot(grid[i * row + jj] - cs[i]) < 0.0:
				n = -n
			g.own_n[i * row + j] = n
	# the broken end: a jagged cap, fibrous (COLOR.r 1); the trunk's foot: closed flat
	_cap(g, nr - 1, row, m, cs[nr - 1] + (cs[nr - 1] - cs[nr - 2]).normalized() * rs[nr - 1] * 0.15, (cs[nr - 1] - cs[nr - 2]).normalized(), u, rid)
	if root:
		_cap(g, 0, row, m, cs[0], -(cs[1] - cs[0]).normalized(), 0.0, rid)
	_wind(g)
	return g

static func _cap(g: Geo, i: int, row: int, m: int, ctr: Vector3, out: Vector3, u: float, rid: float) -> void:
	var c := g.v.size()
	g.v.append(ctr)
	g.rp.append(Vector3(u, 0, 0))
	g.col.append(Color(1, rid, 0, 1))
	g.own_n.append(out)
	var base := g.v.size()
	for j in m:
		g.v.append(g.v[i * row + j])
		g.rp.append(g.rp[i * row + j])
		g.col.append(Color(1, rid, 0, 1))
		g.own_n.append(out)
	for j in m:
		g.idx.append_array([c, base + j, base + (j + 1) % m])
	# the cap's triangles are wound whichever way; turn each to face `out`
	var k0 := g.idx.size() - m * 3
	for k in range(k0, g.idx.size(), 3):
		var a := g.v[g.idx[k]]
		var b := g.v[g.idx[k + 1]]
		var cc := g.v[g.idx[k + 2]]
		if (b - a).cross(cc - a).dot(out) < 0.0:
			var t := g.idx[k + 1]
			g.idx[k + 1] = g.idx[k + 2]
			g.idx[k + 2] = t

## the tube's quads were wound by grid order: turn the whole tube (not its caps) to face along its own normals
static func _wind(g: Geo) -> void:
	var vote := 0.0
	var nq := mini(g.idx.size(), 600)
	for k in range(0, nq, 3):
		var a := g.v[g.idx[k]]
		var b := g.v[g.idx[k + 1]]
		var c := g.v[g.idx[k + 2]]
		vote += signf((b - a).cross(c - a).dot(g.own_n[g.idx[k]]))
	if vote >= 0.0:
		return
	# flip every triangle that is not a cap's (caps were turned on their own)
	for k in range(0, g.idx.size(), 3):
		if g.col[g.idx[k]].r > 0.5 and g.col[g.idx[k + 1]].r > 0.5 and g.col[g.idx[k + 2]].r > 0.5:
			continue
		var t := g.idx[k + 1]
		g.idx[k + 1] = g.idx[k + 2]
		g.idx[k + 2] = t

## the whole branching piece as meshes under parent, one material; returns the meshes (trunk first; only the trunk
## takes o.dent)
static func build(parent: Node3D, sk: Array, o: Dictionary, mat: Material) -> Array:
	var out := []
	var o2 := o.duplicate()
	o2.erase("dent")
	for k in sk.size():
		var br: Dictionary = sk[k]
		var mi := U.mesh(tube(br, o if k == 0 else o2, k == 0), mat, parent)
		mi.set_meta("col", true)
		out.append(mi)
	return out
