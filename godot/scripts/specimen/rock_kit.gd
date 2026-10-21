class_name RockKit
extends RefCounted
## Shapes the specimens are built from: crystals of each habit, chunky columns, soft lumps,
## host rock and cut stones. Ported from the prototype's specimen.js (crystalGeo, prismGeo, lumpGeo, makeRock, gemGeo).

static func rd(rng: Rng32) -> Vector3:
	return Vector3(rng.next() - 0.5, rng.next() - 0.5, rng.next() - 0.5).normalized()

static func _frac(x: float) -> float:
	return x - floor(x)

## wobble every vertex by a function of its position, so shared corners stay together
static func warp(g: Geo, rng: Rng32, amt: float, freq := 1.0) -> Geo:
	var ks := []
	for k in 5:
		ks.append([rd(rng) * (2.0 + rng.next() * 5.0) * freq, rng.next() * 6.3])
	for i in g.v.size():
		var p := g.v[i]
		var n := 0.0
		for kk in ks:
			n += sin(p.dot(kk[0]) + kk[1])
		g.v[i] = p * (1.0 + n * amt / 5.0)
	return g

## cfg: {h, tip, scepter, dt (both ends), cA, cB, zk (colour zoning)}
static func crystal(habit: String, rng: Rng32, cfg: Dictionary) -> Geo:
	var r := 0.32
	var h: float = cfg.get("h", 1.1)
	var tip: float = cfg.tip if cfg.get("tip") != null else 1.1 + rng.next() * 0.8
	var scep: bool = cfg.get("scepter", false)
	var dt: bool = cfg.get("dt", false)
	var sc := 1.45 if scep else 1.0
	var low := -r * tip if dt else 0.0
	var g: Geo
	if habit == "prism" or habit == "blade":
		g = Geo.lathe([Vector2(0, low), Vector2(r * 0.08 if dt else r, low if dt else 0.0), Vector2(r, 0), Vector2(r * (0.75 if scep else 1.0), h * 0.62),
			Vector2(r * sc, h * 0.72), Vector2(r * sc, h), Vector2(r * 0.08, h + r * tip), Vector2(0, h + r * tip)], 6)
	elif habit == "barrel":
		g = Geo.lathe([Vector2(0, 0), Vector2(r * 0.75, 0), Vector2(r * 1.05, h * 0.3), Vector2(r * 1.05, h * 0.7), Vector2(r * 0.8, h), Vector2(0, h)], 6)
	elif habit == "scaleno":
		g = Geo.octa(0.3).scale(1, 2.4, 1).translate(0, 0.65, 0)
	elif habit == "cube":
		var s := 0.32 + rng.next() * 0.1
		g = Geo.box(s, s * (0.9 + rng.next() * 0.3), s).translate(0, s * 0.5, 0)
	elif habit == "octa":
		g = Geo.octa(0.32).translate(0, 0.3, 0)
	elif habit == "dodeca":
		g = Geo.dodeca(0.3).translate(0, 0.28, 0)
	else:
		g = Geo.sphere(0.2, 20, 14).translate(0, 0.15, 0)
	if habit == "blade":
		g.scale(1.3, 1, 0.38)
	g.to_soup()
	# small irregularities and a few knocked-off corners near the tips
	var top := h * 0.82
	var y0 := 1e9
	var y1 := -1e9
	for i in g.v.size():
		var p := g.v[i]
		var n := sin(p.x * 37.0 + p.y * 13.0) * sin(p.z * 29.0 - p.y * 7.0)
		var chip := 1.0
		if (p.y > top or (dt and p.y < low * 0.6)) and _frac(sin(p.x * 127.1 + p.y * 311.7 + p.z * 74.7) * 43758.5453) > 0.72:
			chip = 0.78
		var sy := signf(p.y) if p.y != 0.0 else 1.0
		g.v[i] = Vector3(p.x * (1.0 + n * 0.05) * chip, p.y - (0.03 * sy if chip < 1.0 else 0.0), p.z * (1.0 + n * 0.05) * chip)
		y0 = minf(y0, p.y)
		y1 = maxf(y1, p.y)
	# hand-made glass: faces that are not quite flat, so what shows through them ripples
	g.mark_edges()
	var det: int = cfg.get("detail", 0)
	if det > 0:
		g.subdivide(det).jitter(0.009, 6.0, int(rng.next() * 100000))
	# colour along the length: plain, smoky base, coloured tip or two-tone
	var cA: Color = cfg.get("cA", Color(1, 1, 1))
	var cB: Color = cfg.get("cB", cA)
	var zk: float = cfg.get("zk", 0.0)
	g.col.resize(g.v.size())
	for i in g.v.size():
		var t := (g.v[i].y - y0) / maxf(0.001, y1 - y0)
		var c := cA.lerp(cB, zk * (t * t * (3.0 - 2.0 * t)))
		c.a = 1.0
		g.col[i] = c
	return g

## a chunky column: uneven polygon section, slanted broken top or a point, foot sunk into the rock
## o: {sides, w, d, h, point, slope, taper, y0}; zc: colour zoning as in crystal()
static func prism(rng: Rng32, o: Dictionary, zc: Dictionary) -> Geo:
	var n: int = o.sides
	var w: float = o.w
	var d: float = o.d
	var h: float = o.h
	var a0 := 0.785 + (rng.next() - 0.5) * 0.2 if n == 4 else rng.next() * 6.28
	var ring := []
	for k in n:
		var a := a0 + float(k) / n * 6.2832 + (rng.next() - 0.5) * (0.12 if n == 4 else 0.3)
		var rr := 1.0 + (rng.next() - 0.5) * 0.3
		ring.append(Vector2(cos(a) * w * rr, sin(a) * d * rr))
	var b := rng.next() * 6.28
	var slope: float = o.get("slope", 0.0)
	var sx := cos(b) * slope
	var sz := sin(b) * slope
	var tp: float = o.taper if o.get("taper") != null else 0.9 + rng.next() * 0.12
	var y0: float = o.get("y0", -0.3)
	var point: bool = o.get("point", false)
	var bot := []
	var top := []
	for q: Vector2 in ring:
		bot.append(Vector3(q.x, y0, q.y))
		top.append(Vector3(q.x * tp, h if point else h + sx * q.x * tp + sz * q.y * tp, q.y * tp))
	var tris := []
	for k in n:
		var j := (k + 1) % n
		tris.append([bot[k], bot[j], top[j]])
		tris.append([bot[k], top[j], top[k]])
	if point:
		var ap := Vector3((rng.next() - 0.5) * w * 0.3, h + maxf(w, d) * (1.1 + rng.next() * 0.9), (rng.next() - 0.5) * d * 0.3)
		for k in n:
			tris.append([top[k], top[(k + 1) % n], ap])
	else:
		var c := Vector3.ZERO
		for p: Vector3 in top:
			c += p / n
		for k in n:
			tris.append([top[k], top[(k + 1) % n], c])
	var cb := Vector3(0, y0, 0)
	for k in n:
		tris.append([bot[k], bot[(k + 1) % n], cb])
	# wind every face outward, so double-sided shading knows which side is the front
	var ctr := Vector3.ZERO
	for t in tris:
		ctr += (t[0] + t[1] + t[2]) / (3.0 * tris.size())
	var g := Geo.new()
	for t in tris:
		var A: Vector3 = t[0]
		var B: Vector3 = t[1]
		var C: Vector3 = t[2]
		var N := (B - A).cross(C - A)
		if N.dot((A + B + C) / 3.0 - ctr) < 0.0:
			g.v.append_array([A, C, B])
		else:
			g.v.append_array([A, B, C])
	g.mark_edges()
	var det: int = o.get("detail", 0)
	if det > 0:
		g.subdivide(det).jitter(minf(w, d) * 0.035, 2.5 / maxf(0.05, w), int(rng.next() * 100000))
	var cA: Color = zc.get("cA", Color(1, 1, 1))
	var cB: Color = zc.get("cB", cA)
	var zk: float = zc.get("zk", 0.0)
	var h_tot := h + w * 2.0 - y0
	g.col.resize(g.v.size())
	for i in g.v.size():
		var t := clampf((g.v[i].y - y0) / h_tot, 0.0, 1.0)
		var c := cA.lerp(cB, zk * t * t * (3.0 - 2.0 * t))
		c.a = 1.0
		g.col[i] = c
	return g

## random points on a mesh's surface in its parent's space, with outward normals
static func surf_pts(node: Node3D, n: int, rng: Rng32, keep := Callable()) -> Array:
	var g: Geo = node.get_meta("geo")
	var tris := g.tri_count()
	var out := []
	var guard := 0
	var xf := node.transform
	while out.size() < n and guard < n * 30:
		guard += 1
		var t := g.tri(int(floor(rng.next() * tris)))
		var u := rng.next()
		var w := rng.next()
		if u + w > 1.0:
			u = 1.0 - u
			w = 1.0 - w
		var pt: Vector3 = xf * (t[0] + (t[1] - t[0]) * u + (t[2] - t[0]) * w)
		var nw: Vector3 = (xf.basis * (t[1] - t[0]).cross(t[2] - t[0])).normalized()
		if keep.is_valid() and not keep.call(pt, nw):
			continue
		out.append([pt, nw])
	return out

static func gem(cut: String) -> Geo:
	if cut == "cab":
		return Geo.lathe([Vector2(0, 0), Vector2(0.6, 0), Vector2(0.56, 0.16), Vector2(0.38, 0.34), Vector2(0, 0.4)], 40)
	var n := 16 if cut == "master" else 8
	return Geo.lathe([Vector2(0, 0), Vector2(0.58, 0.46), Vector2(0.62, 0.5), Vector2(0.44, 0.66), Vector2(0, 0.7)], n)

# ---------------------------------------------------------------- host rock

const ROCKS := {
	"basalt": {h = [0.07, 0.05], s = [0.08, 0.1], l = [0.12, 0.08], crust = [0.1, 0.12, 0.55], rust = 0x7a4a2a},
	"quartzite": {h = [0.1, 0.03], s = [0.03, 0.04], l = [0.6, 0.1], crust = [0.1, 0.05, 0.85], rust = 0x9a7a5a},
	"ironstone": {h = [0.03, 0.02], s = [0.4, 0.15], l = [0.22, 0.06], crust = [0.09, 0.5, 0.45], rust = 0x4a2010},
	"limestone": {h = [0.1, 0.03], s = [0.15, 0.08], l = [0.5, 0.08], crust = [0.12, 0.1, 0.82], rust = 0xa07a40},
}
const ROCK_SHAPES := {slab = [1.35, 0.42, 1.05], chunk = [1.05, 0.72, 0.95], long = [1.55, 0.5, 0.75], small = [0.8, 0.55, 0.75]}

## o: {r, sx, sy, sz, wave, bumps:[[n, size, h]], pits:[n, size, depth], seg, k}; returns [geo, cav]
static func lump(rng: Rng32, o: Dictionary) -> Array:
	var seg: int = o.get("seg", 96)
	var g := Geo.sphere(1.0, seg, roundi(seg * 0.66))
	var cav := PackedFloat32Array()
	cav.resize(g.v.size())
	var kk: float = o.get("k", 60.0)
	var bumps := []
	for bb in o.get("bumps", []):
		for i in int(bb[0]):
			var ar := minf(1.5, float(bb[1]) * (0.55 + rng.next() * 0.9))
			bumps.append([rd(rng), ar, float(bb[2]) * (0.5 + rng.next() * 0.9), cos(ar)])
	var pits := []
	if o.has("pits"):
		for i in int(o.pits[0]):
			var ar := float(o.pits[1]) * (0.5 + rng.next())
			pits.append([rd(rng), ar, float(o.pits[2]) * (0.5 + rng.next()), cos(ar)])
	var ks := []
	for k in 5:
		ks.append([rd(rng) * ((1.5 + rng.next() * 2.0) * (1.0 + k * 0.9)), rng.next() * 6.3, float(o.get("wave", 0.0)) / (1.0 + k * 1.1)])
	var hmax := 0.001
	for b in bumps:
		hmax = maxf(hmax, b[2])
	var r: float = o.r
	var sv := Vector3(o.get("sx", 1.0), o.get("sy", 1.0), o.get("sz", 1.0))
	for i in g.v.size():
		var p := g.v[i].normalized()
		# smooth maximum of the caps, so neighbouring grapes melt into each other
		var b := 0.0
		var sum := 0.0
		for bp in bumps:
			var dd: float = p.dot(bp[0])
			if dd <= bp[3]:
				continue
			var t := minf(1.0, acos(minf(1.0, dd)) / bp[1])
			var hh: float = bp[2] * sqrt(1.0 - t * t)
			sum += exp(hh * kk)
			b = maxf(b, hh)
		if sum > 0.0:
			b = log(sum) / kk
		var pit := 0.0
		for pp in pits:
			var dd: float = p.dot(pp[0])
			if dd <= pp[3]:
				continue
			var a := acos(minf(1.0, dd))
			if a < pp[1]:
				pit = maxf(pit, pp[2] * (1.0 - (a / pp[1]) * (a / pp[1])))
		var n := 0.0
		for kq in ks:
			n += sin(p.dot(kq[0]) + kq[1]) * kq[2]
		cav[i] = clampf((1.0 - b / hmax if bumps.size() else 0.0) * 0.6 + pit * 8.0 + maxf(0.0, -n) * 2.0, 0.0, 1.0)
		g.v[i] = p * (r * (1.0 + n + b - pit)) * sv
	return [g, cav]

static func tint_cav(g: Geo, cav: PackedFloat32Array, k: float, base := Color(1, 1, 1)) -> Geo:
	g.col.resize(g.v.size())
	for i in cav.size():
		var f := 1.0 - cav[i] * k
		g.col[i] = Color(base.r * f, base.g * f, base.b * f)
	return g

static var _sphere_cache := {}
static var _disp := {}

## which photo scan dresses which rock
const SCAN_OF := {limestone = 0, ironstone = 1, basalt = 2, quartzite = 3}

## height map of a scan, for pressing its relief into the geometry
static func disp_img(i: int) -> Image:
	if not _disp.has(i):
		var nm: String = SpecMat.SCANS[i]
		var img := (load("res://assets/textures/%s/%s_disp_1k.jpg" % [nm, nm]) as Texture2D).get_image()
		if img.is_compressed(): img.decompress()
		img.resize(256, 256)
		_disp[i] = img
	return _disp[i]

static func disp_at(img: Image, uv: Vector2) -> float:
	var S := img.get_width()
	return img.get_pixel(posmod(int(uv.x * S), S), posmod(int(uv.y * S), S)).r

## a smooth, finely divided ball to carve rocks from (cached; callers get a copy)
static func ball(detail: int) -> Geo:
	if not _sphere_cache.has(detail):
		_sphere_cache[detail] = Geo.icosa(1.0, detail).weld()
	var src: Geo = _sphere_cache[detail]
	var g := Geo.new()
	g.v = src.v.duplicate()
	g.idx = src.idx.duplicate()
	return g

## host rock: a weathered chunk, eaten into by pores and pockets, ridged, darker in every hollow.
## Returns {geo, top, scale, base, rough}
static func rock(rng: Rng32, type: String, shape: String, detail := 32) -> Dictionary:
	var R: Dictionary = ROCKS[type]
	var S: Array = ROCK_SHAPES[shape]
	var g := ball(detail)
	var sd := int(rng.next() * 1000000)
	var form := FastNoiseLite.new()
	form.seed = sd
	form.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	form.frequency = 0.9
	form.fractal_octaves = 4
	var ridge := FastNoiseLite.new()
	ridge.seed = sd + 1
	ridge.frequency = 2.4
	ridge.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	ridge.fractal_octaves = 3
	var pores := FastNoiseLite.new()
	pores.seed = sd + 2
	pores.noise_type = FastNoiseLite.TYPE_CELLULAR
	pores.frequency = 4.6 if type != "quartzite" else 3.0
	pores.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
	pores.cellular_jitter = 1.0
	var fine := FastNoiseLite.new()
	fine.seed = sd + 3
	fine.noise_type = FastNoiseLite.TYPE_CELLULAR
	fine.frequency = 9.0
	fine.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
	var where := FastNoiseLite.new()
	where.seed = sd + 4
	where.frequency = 1.3
	var spongy := 0.6 if type == "basalt" else 0.75 if type == "ironstone" else 0.35 if type == "limestone" else 0.2
	var cav := PackedFloat32Array()
	cav.resize(g.v.size())
	for i in g.v.size():
		var u := g.v[i]
		var p := u * 0.62
		var f := form.get_noise_3dv(p) * 0.22
		var rd2 := ridge.get_noise_3dv(p) * 0.05
		# pockets cluster in eroded zones; tiny pores everywhere
		var zone := clampf(where.get_noise_3dv(p) * 1.4 + spongy, 0.0, 1.0)
		var cd := (pores.get_noise_3dv(p) + 1.0) * 0.5
		var pit := pow(clampf((0.44 - cd) / 0.44, 0.0, 1.0), 1.3) * 0.24 * zone
		var fd := (fine.get_noise_3dv(p) + 1.0) * 0.5
		var pit2 := clampf((0.3 - fd) / 0.3, 0.0, 1.0) * 0.045 * (0.3 + zone)
		g.v[i] = u * 0.62 * (1.0 + f + rd2 - pit - pit2)
		cav[i] = clampf(pit * 5.0 + pit2 * 12.0 + maxf(0.0, -f) * 1.6 - maxf(0.0, rd2) * 4.0, 0.0, 1.0)
	g.scale(S[0], S[1], S[2])
	# the scanned rock's own relief, pressed in from three sides like the texture laid on it
	var dimg := disp_img(SCAN_OF[type])
	var sc := 1.3
	for i in g.v.size():
		var p := g.v[i]
		var no := p.normalized()
		var w := Vector3(pow(absf(no.x), 4.0), pow(absf(no.y), 4.0), pow(absf(no.z), 4.0))
		w /= (w.x + w.y + w.z)
		var q := p * sc
		var h := disp_at(dimg, Vector2(q.z, q.y)) * w.x + disp_at(dimg, Vector2(q.x, q.z)) * w.y + disp_at(dimg, Vector2(q.x, q.y)) * w.z
		g.v[i] = p + no * (h - 0.5) * 0.07
		cav[i] = clampf(cav[i] + (0.5 - h) * 0.9, 0.0, 1.0)
	var base := SpecMat.hsl(R.h[0] + rng.next() * R.h[1], R.s[0] + rng.next() * R.s[1], R.l[0] + rng.next() * R.l[1]).srgb_to_linear()
	g.col.resize(g.v.size())
	for i in g.v.size():
		var k := clampf(1.0 - cav[i], 0.06, 1.0)
		g.col[i] = Color(k, k, k)
	var top := []
	var ymax: float = S[1] * 0.62
	for i in g.v.size():
		if g.v[i].y > ymax * 0.25:
			top.append(g.v[i])
	return {geo = g, top = top, scale = Vector3(S[0], S[1], S[2]), base = base, rough = 0.7 if type == "quartzite" else 0.96}

static func rock_nrm(sc: Vector3, w: Vector3) -> Vector3:
	return Vector3(w.x / (sc.x * sc.x), w.y / (sc.y * sc.y), w.z / (sc.z * sc.z)).normalized()
