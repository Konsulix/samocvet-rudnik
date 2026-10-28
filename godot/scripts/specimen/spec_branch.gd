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
	# splits along the wood: [round it 0..1, from, to (0..1 along), half-width round, depth]
	var splits: Array = []
	if fibre > 0.0:
		var srng := Rng32.new(int(o.get("seed", 1)) * 3 + int(float(br.rnd) * 977.0))
		for k in 1 + int(srng.next() * 3.0):
			var s0 := srng.next() * 0.5
			splits.append([srng.next(), s0, minf(1.0, s0 + 0.3 + srng.next() * 0.5), 0.015 + srng.next() * 0.02, 0.25 + srng.next() * 0.35])
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
	# the broken tip: the last rings close in fast and unevenly (unless the ends are grown out of the tube, `ends`)
	var ends: Dictionary = o.get("ends", {})
	var tip := 0 if not ends.is_empty() else mini(4, nr - 2)
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
				fv = clampf(fz.get_noise_3d(cos(at) * 4.5, sin(at) * 4.5, u * 0.05 + rid * 20.0) * 0.5 + 0.5, 0.0, 1.0)
				# finer strands over the ropes, peeling in places
				var fine := nz.get_noise_3d(cos(at) * 9.0 + 30.0, sin(at) * 9.0, u * 0.03 + rid * 20.0) * 0.5 + 0.5
				fv = clampf(fv * 0.82 + fine * 0.18, 0.0, 1.0)
				l += (fv - 0.5) * fibre
				# splits: deep narrow cracks running along the wood, opening and closing
				for sp: Array in splits:
					var sa := absf(wrapf(float(j % m) / m - float(sp[0]) - u * twist * 0.1 / TAU, -0.5, 0.5))
					var tt2 := float(i) / (nr - 1)
					var on := smoothstep(float(sp[1]), float(sp[1]) + 0.08, tt2) * (1.0 - smoothstep(float(sp[2]) - 0.08, float(sp[2]), tt2))
					var cut := (1.0 - smoothstep(0.0, float(sp[3]), sa)) * on
					l -= cut * float(sp[4])
					fv = minf(fv, 1.0 - cut)
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
			if i == nr - 1 and ends.is_empty():
				pos += t2 * r * (nz.get_noise_2d(a * 2.0, 7.0 + rid * 10.0)) * 0.9
			g.v.append(pos)
			grid.append(pos)
			g.rp.append(Vector3(u, float(j) / m, r * close))
			g.col.append(Color(1.0 if i == nr - 1 and ends.is_empty() else 0.0, rid, dm, fv))
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
	if not ends.is_empty():
		_wind(g)
		# the ends grow out of the tube itself: the tip, and the trunk's foot
		_end(g, nr - 1, m, cs[nr - 1], (cs[nr - 1] - cs[nr - 2]).normalized(), rs[nr - 1], String(ends.get("tip", "torn")) if root else String(ends.get("kid_tip", "taper")), fz, nz, rid, u, twist)
		if root:
			_end(g, 0, m, cs[0], -(cs[1] - cs[0]).normalized(), rs[0], String(ends.get("root", "worn")), fz, nz, rid, 0.0, twist)
		return g
	# the broken end: a jagged cap, fibrous (COLOR.r 1); the trunk's foot: closed flat
	_cap(g, nr - 1, row, m, cs[nr - 1] + (cs[nr - 1] - cs[nr - 2]).normalized() * rs[nr - 1] * 0.15, (cs[nr - 1] - cs[nr - 2]).normalized(), u, rid)
	if root:
		_cap(g, 0, row, m, cs[0], -(cs[1] - cs[0]).normalized(), 0.0, rid)
	_wind(g)
	return g

## an end grown out of the tube's ring `ring` (its m corners), going on along `axis`: "torn" — snapped across the
## grain, each fibre (a column round the ring) breaking off at its own length, so long splinters stand out of a
## ragged stump, the inner wood torn at other lengths; "worn" — rubbed round by water and sand, a blunt dome whose
## fibre ridges run on over it. Weathered all over, like the rest (COLOR.r 0); the fibre height carried on (COLOR.a)
static func _end(g: Geo, ring: int, m: int, ctr: Vector3, axis: Vector3, r: float, mode: String, fz: FastNoiseLite, nz: FastNoiseLite, rid: float, u0: float, twist: float) -> void:
	var row := m + 1
	var K := 16
	# a worn end: a blunt dome on a stump; "taper" — a worn limb's tip, long, narrowing to a rounded point
	var wl := 0.38
	if mode == "taper":
		mode = "worn"
		wl = 1.3
	if mode == "spear":
		_spear(g, ring, m, ctr, axis, r, nz, rid)
		return
	var torn := mode == "torn"
	var lens: Array[float] = []
	for j in m:
		var a := TAU * float(j) / m
		if torn:
			# a few splinters standing out of the rim, the rest of the break low
			var sp := nz.get_noise_2d(cos(a) * 1.3 + rid * 40.0, sin(a) * 1.3) * 0.5 + 0.5
			lens.append(r * 1.3 * pow(smoothstep(0.58, 0.9, sp), 1.4))
		else:
			lens.append(r * (wl + 0.25 * nz.get_noise_2d(a * 2.0, rid * 9.0 + 4.0)))
	# a torn end breaks slant: a tilted, uneven face
	var tilt_a := rid * 37.0
	var tilt_k := 0.45 + 0.5 * (nz.get_noise_2d(rid * 11.0, 3.0) * 0.5 + 0.5)
	var first := g.v.size()
	var prev: Array[int] = []
	for j in m + 1:
		prev.append(ring * row + j)
	var rings: Array = [prev]
	for k in range(1, K + 1):
		var t := float(k) / K
		var cur: Array[int] = []
		for j in m + 1:
			var jj := j % m
			var b: Vector3 = g.v[ring * row + jj]
			var off := b - ctr
			off -= axis * off.dot(axis)
			var a := TAU * float(jj) / m
			# the fibre ridges die out inwards: no star of them meeting in the middle
			off = off.lerp(off.normalized() * r, smoothstep(0.0, 0.45, t))
			var radial: float
			var along: float
			if torn:
				# the face: tilted, rough, stepped a little; the splinters rise from the rim and taper inwards
				radial = 1.0 - t
				var d2 := Vector2(cos(a), sin(a)) * radial
				along = r * tilt_k * (d2.x * cos(tilt_a) + d2.y * sin(tilt_a) + 1.0) * 0.6
				# snapped in steps along the grain: two or three ledges, their edges ragged, rough all over
				var lv := nz.get_noise_3d(d2.x * 1.6 + 5.0, d2.y * 1.6, rid * 17.0) * 0.5 + 0.5
				var ls := lv * 3.0
				along += r * 0.5 * (floor(ls) + smoothstep(0.75, 1.0, ls - floor(ls))) / 3.0
				along += r * 0.2 * nz.get_noise_3d(d2.x * 4.0, d2.y * 4.0, rid * 13.0)
				along += lens[jj] * pow(1.0 - t, 1.2) * (1.0 - 0.4 * t)
				# a splinter thins as it rises
				if lens[jj] > r * 0.1: radial *= lerpf(1.0, 0.82, smoothstep(0.0, 0.4, t))
			else:
				radial = cos(t * PI * 0.5)
				along = lens[jj] * sin(t * PI * 0.5)
			var pos := ctr + off * radial + axis * along
			if not torn:
				# its fibre ridges run on over the dome, fading towards the middle
				var at := a + (u0 + along / maxf(r, 0.01)) * twist * 0.1
				pos += off.normalized() * (fz.get_noise_3d(cos(at) * 3.2, sin(at) * 3.2, rid * 20.0)) * r * 0.25 * radial
			g.v.append(pos)
			var src_rp := g.rp[ring * row + jj]
			g.rp.append(Vector3(src_rp.x + along / maxf(r, 0.01) * signf(1.0), src_rp.y, r * maxf(radial, 0.15)))
			var fv := g.col[ring * row + jj].a
			# a torn face shows its end grain (COLOR.r 1, the shader's broken wood) inside its weathered rim
			var face := smoothstep(0.12, 0.3, t) if torn else 0.0
			g.col.append(Color(face, rid, 0.0, lerpf(fv, 0.5, smoothstep(0.0, 0.4, t))))
			g.own_n.append(Vector3.ZERO)
			cur.append(g.v.size() - 1)
		rings.append(cur)
	_bridge(g, rings, first, ctr - axis * r, axis)

## faces between successive rings of corner indices (each ring m + 1, the last repeating the first), each turned to
## face out (away from `back`, a point inside the wood); smooth normals for the corners from `first` on
static func _bridge(g: Geo, rings: Array, first: int, back: Vector3, axis: Vector3) -> void:
	for k in rings.size() - 1:
		var r0: Array = rings[k]
		var r1: Array = rings[k + 1]
		for j in r0.size() - 1:
			for tri in [[r0[j], r1[j], r0[j + 1]], [r0[j + 1], r1[j], r1[j + 1]]]:
				var ia: int = tri[0]
				var ib: int = tri[1]
				var ic: int = tri[2]
				var n := (g.v[ib] - g.v[ia]).cross(g.v[ic] - g.v[ia])
				var mid := (g.v[ia] + g.v[ib] + g.v[ic]) / 3.0
				if n.dot(mid - back) < 0.0:
					var t := ib
					ib = ic
					ic = t
					n = -n
				g.idx.append_array([ia, ib, ic])
				for q in [ia, ib, ic]:
					if q >= first:
						g.own_n[q] += n
	for q in range(first, g.v.size()):
		g.own_n[q] = g.own_n[q].normalized() if g.own_n[q].length() > 1e-9 else axis

## a spear end: snapped on a long slant, so one side of the trunk runs on far past the other and ends in a point —
## its weathered wall climbing to the slant, then the slant itself (torn grain, COLOR.r 1) back across to the low side
static func _spear(g: Geo, ring: int, m: int, ctr: Vector3, axis: Vector3, r: float, nz: FastNoiseLite, rid: float) -> void:
	var row := m + 1
	var a0 := rid * 53.0
	var S := r * (2.8 + 1.6 * (nz.get_noise_2d(rid * 7.0, 11.0) * 0.5 + 0.5))
	var hs: Array[float] = []
	for j in m:
		var a := TAU * float(j) / m
		var w := pow((1.0 + cos(a - a0)) * 0.5, 2.4)
		# the slant's edge ragged: torn fibres stand a little above it here and there
		hs.append(S * w + r * 0.18 * absf(nz.get_noise_2d(a * 5.0, rid * 3.0)) + r * 0.06)
	var first := g.v.size()
	var rings: Array = []
	var prev: Array[int] = []
	for j in m + 1:
		prev.append(ring * row + j)
	rings.append(prev)
	var KW := 14
	var KF := 10
	for k in range(1, KW + KF + 1):
		var cur: Array[int] = []
		for j in m + 1:
			var jj := j % m
			var a := TAU * float(jj) / m
			var b: Vector3 = g.v[ring * row + jj]
			var off := b - ctr
			off -= axis * off.dot(axis)
			var pos: Vector3
			var face := 0.0
			if k <= KW:
				# the wall climbing to the slant; the high side thins as it rises, into a splinter
				var sw := float(k) / KW
				var h: float = hs[jj] * sw
				# the high side narrows into a splinter: squeezed in towards its own side of the trunk
				var thin := 1.0 - 0.55 * smoothstep(0.25, 1.0, h / S)
				pos = ctr + off * thin + axis * h
			else:
				# the slant: from the rim back to the trunk's middle line, low there, rough
				var t := float(k - KW) / KF
				var thin := 1.0 - 0.55 * smoothstep(0.25, 1.0, hs[jj] / S)
				var hc := S * 0.3
				# torn along the grain: ridges and grooves running down the slant, splinters lifting at its edge
				var gr := absf(nz.get_noise_2d(a * 7.0, rid * 5.0))
				var h := lerpf(hs[jj], hc, t) + r * 0.2 * nz.get_noise_3d(cos(a) * 2.5 * (1.0 - t), sin(a) * 2.5 * (1.0 - t), rid * 13.0 + t * 1.5) + r * 0.12 * gr * (1.0 - t)
				pos = ctr + off * thin * (1.0 - t) + axis * h
				face = smoothstep(0.0, 0.25, t)
			g.v.append(pos)
			var src_rp := g.rp[ring * row + jj]
			# on the slant, UV.y runs across it (square to the long side): the grain's streaks run down it in parallel
			var across := src_rp.y
			if k > KW:
				var sd := Vector3(cos(a0 + PI * 0.5), sin(a0 + PI * 0.5), 0.0)
				across = 0.5 + 0.5 * (cos(a) * sd.x + sin(a) * sd.y) * (1.0 - float(k - KW) / KF * 0.5)
			g.rp.append(Vector3(src_rp.x + (pos - ctr).dot(axis) / maxf(r, 0.01), across, r * (1.0 - (float(k - KW) / KF if k > KW else 0.0))))
			# COLOR.a 0.95 on the slant: the shader draws it as wood split along its grain, not an end's rings
			g.col.append(Color(face, rid, 0.0, g.col[ring * row + jj].a if face < 0.5 else 0.95))
			g.own_n.append(Vector3.ZERO)
			cur.append(g.v.size() - 1)
		rings.append(cur)
	_bridge(g, rings, first, ctr - axis * r, axis)

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
