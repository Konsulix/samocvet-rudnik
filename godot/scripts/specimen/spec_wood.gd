class_name SpecWood
extends RefCounted
## Petrified wood: a fossil (SpecFossil hands it its genes and its card names). A tree turned to stone cell by cell —
## jasper and chalcedony stained red, yellow, purple, black by iron and manganese; sometimes opal instead, milky,
## with play of colour running along the grain. Shown as
##   slice — a polished round standing on its edge: growth rings, rays, bark on the rim (knocked off in places),
##           radial cracks (checks) healed with white quartz or opal or left open, a rare hollow heart lined with
##           amethyst or quartz crystals;
##   log   — a piece of the trunk: fissured bark, one end sawn and polished, the other broken off.
## The wood is a solid pattern in the trunk's own space (shaders/wood.gdshader reads the model position): the rings
## and cracks on the polished face run on into the bark and the break. The mesh tells it, per vertex: UV.x = the
## trunk's outline radius there, UV.y = how thick its bark is (0 where it is gone), COLOR.r = polish (1 the polished
## face, ~0.3 the sawn back, 0 broken or bark), COLOR.b = how deep in the hollow heart.

const U := preload("res://scripts/specimen/spec_util.gd")
const SHADER := preload("res://shaders/wood.gdshader")

## jasper palettes: earlywood, latewood, two stains crossing the rings, the bark
const PAL := [
	{early = 0xc8743a, late = 0x6e2a1c, st1 = 0xe0b850, st2 = 0x6e3e6a, bark = 0x5e4a3c},   # rainbow (Arizona): orange, red, yellow, purple
	{early = 0xa88c6a, late = 0x56402c, st1 = 0xcbb492, st2 = 0x3c3024, bark = 0x584a3c},   # brown, the plain kind
	{early = 0x8a8680, late = 0x2c2826, st1 = 0xb8b0a4, st2 = 0x4c3c30, bark = 0x3e3834},   # black and grey
	{early = 0xd6a868, late = 0x8a5428, st1 = 0xf0d8a8, st2 = 0xa86030, bark = 0x6a5038},   # honey chalcedony
	{early = 0xa63c2a, late = 0x4a1810, st1 = 0xd8803e, st2 = 0x2a1a18, bark = 0x543a2e},   # red jasper
	{early = 0x6c8a7c, late = 0x2a4038, st1 = 0xa8c8b0, st2 = 0x4a5a6c, bark = 0x464c44},   # blue-green, rare
	{early = 0xb4ada2, late = 0x6e675c, st1 = 0xd2cbbd, st2 = 0x9a7c56, bark = 0x5a5248},   # opal: grey potch, honey
]
const HEART := {amethyst = 0x9a62c8, quartz = 0xe4e2dc, citrine = 0xe0a848}
const CK_FILL := {empty = 0, quartz = 1, opal = 2}
const FIRE := {red = 0.02, green = 0.3, blue = 0.58, violet = 0.74}

## its genes, on its own random stream; o: showcases may pin show, opal, fire, pal, checks, ck_fill, heart
static func genes(seed_v: int, tr: Array, o: Dictionary = {}) -> Dictionary:
	var rng := Rng32.new((seed_v * 2654435761 + 23) % 4294967296)
	var g := {kind = "petrified_wood"}
	g.show = Stones.pick_w([["slice", 5.0], ["log", 4.0]], rng)
	# opal in place of the jasper: most none, some a little (in the cracks first), a rare one all opal
	g.opal = 0.0 if rng.next() < 0.7 else 0.05 + pow(rng.next(), 1.6) * 0.95
	if "irid" in tr or "aurora" in tr:
		g.opal = maxf(float(g.opal), 0.4 + rng.next() * 0.6)
	g.fire = Stones.pick_w([["red", 25.0], ["green", 35.0], ["blue", 25.0], ["violet", 15.0]], rng)
	g.pal = int(Stones.pick_w([[0, 3.0], [1, 4.0], [2, 2.5], [3, 2.0], [4, 2.0], [5, 0.6]], rng))
	g.rings = 16.0 + floor(rng.next() * 44.0)
	# the pith off the middle (the tree grew leaning), the trunk a little oval and lumpy
	var ea := rng.next() * TAU
	g.ecc = Vector2(cos(ea), sin(ea)) * rng.next() * 0.3
	g.oval = 0.8 + rng.next() * 0.2
	g.lobe = 0.03 + rng.next() * 0.07
	g.bark = 0.0 if rng.next() < 0.15 else 0.3 + rng.next() * 0.7
	g.bark_t = 0.07 + rng.next() * 0.07
	g.checks = int(Stones.pick_w([[0, 2.0], [1, 3.0], [2, 3.0], [3, 2.0], [4, 1.0], [5, 0.6]], rng))
	g.ck_fill = Stones.pick_w([["quartz", 4.0], ["empty", 3.0]], rng)
	g.heart = Stones.pick_w([["amethyst", 2.0], ["quartz", 2.0], ["citrine", 0.7]], rng) if rng.next() < 0.18 else ""
	g.heart_r = 0.14 + rng.next() * 0.12
	g.len = 1.8 + rng.next() * 1.2      # a log's length, in trunk radii
	g.thick = 0.17 + rng.next() * 0.09  # a slice's thickness
	g.seed = int(rng.next() * 100000.0)
	for k in ["show", "opal", "fire", "pal", "checks", "ck_fill", "heart"]:
		if o.has(k): g[k] = o[k]
	if o.get("legend", false): g.opal = maxf(float(g.opal), 0.6)
	# a hollow heart is a slice's (a log shows its ends too small for it)
	if g.show != "slice": g.heart = ""
	# where there is opal, it healed the cracks first
	if float(g.opal) > 0.0: g.ck_fill = "opal"
	if float(g.opal) >= 0.5: g.pal = 6
	return g

static func accents(g: Dictionary) -> Array:
	var out := ["rings"]
	if float(g.opal) >= 0.03: out.append("opal")
	if float(g.bark) > 0.0: out.append("bark")
	if int(g.checks) > 0: out.append("checks_" + String(g.ck_fill))
	if String(g.heart) != "": out.append("heart_" + String(g.heart))
	return out

static func gene_name(id: String, g: Dictionary) -> String:
	match id:
		"opal": return "opalized %d%%" % roundi(float(g.opal) * 100.0) if float(g.opal) >= 0.5 else "opal %d%%" % roundi(float(g.opal) * 100.0)
		"rings": return "%d growth rings" % int(g.rings)
		"bark": return "bark"
		"checks_quartz": return "quartz-healed cracks"
		"checks_opal": return "opal-healed cracks"
		"checks_empty": return "open cracks"
		"heart_amethyst": return "amethyst heart"
		"heart_quartz": return "quartz heart"
		"heart_citrine": return "citrine heart"
	return ""

# ---------------------------------------------------------------- shape

## the radial cracks: [angle, depth (share of the radius, from the rim in), width at the rim, seed]
static func _checks(f: Dictionary) -> Array:
	var out := []
	var r := Rng32.new(int(f.seed) * 5 + 3)
	for k in int(f.checks):
		out.append([r.next() * TAU, 0.35 + r.next() * 0.5, 0.012 + r.next() * 0.03, r.next() * 100.0])
	return out

## the noises the outline is made of, built once per piece
static func _noises(f: Dictionary) -> Dictionary:
	var lump := FastNoiseLite.new()
	lump.seed = int(f.seed)
	lump.frequency = 0.9
	lump.fractal_octaves = 3
	var bark := FastNoiseLite.new()
	bark.seed = int(f.seed) + 5
	bark.frequency = 1.1
	bark.fractal_octaves = 2
	var fis := FastNoiseLite.new()
	fis.seed = int(f.seed) + 9
	fis.frequency = 1.0
	fis.fractal_octaves = 3
	var brk := FastNoiseLite.new()
	brk.seed = int(f.seed) + 13
	brk.frequency = 1.6
	brk.fractal_octaves = 3
	return {lump = lump, bark = bark, fis = fis, brk = brk}

## the trunk's outline at (phi, z): its radius before the bark is worn (the shader's reference) and how much bark
## is there (0..1)
static func _outline(f: Dictionary, nz: Dictionary, phi: float, z: float) -> Vector2:
	var c := cos(phi)
	var s := sin(phi)
	var o: float = f.oval
	var r := 1.0 / sqrt(c * c + s * s / (o * o))
	r *= 1.0 + (nz.lump as FastNoiseLite).get_noise_3d(c * 1.4, s * 1.4, z * 0.5) * float(f.lobe) * 2.0
	# a log thins a little to one end and swells here and there
	if f.show == "log":
		r *= 1.0 - 0.07 * z / float(f.len) + 0.04 * (nz.lump as FastNoiseLite).get_noise_2d(z * 1.3, 40.0)
	var keep := 0.0
	if float(f.bark) > 0.0:
		var n := (nz.bark as FastNoiseLite).get_noise_3d(c * 1.6, s * 1.6, z * 0.7)
		keep = smoothstep(-0.06, 0.06, n - lerpf(0.45, -0.45, float(f.bark)))
	return Vector2(r, keep)

## where the surface stands at (phi, z): bark with its fissures, or the wood below where the bark is gone; open
## cracks notch the rim
static func _rim(f: Dictionary, nz: Dictionary, ck: Array, phi: float, z: float) -> float:
	var ol := _outline(f, nz, phi, z)
	var bt: float = f.bark_t
	var c := cos(phi)
	var s := sin(phi)
	# fissures: long grooves along the trunk, sharp-bottomed (ridged noise), only in the bark
	var fn := absf((nz.fis as FastNoiseLite).get_noise_3d(c * 4.0, s * 4.0, z * 0.35))
	var groove := (1.0 - smoothstep(0.0, 0.25, fn)) * 0.6 + (nz.fis as FastNoiseLite).get_noise_3d(c * 9.0, s * 9.0, z * 2.0) * 0.15
	var r := ol.x * (1.0 - bt * (1.0 - ol.y) - 0.004) - ol.x * bt * ol.y * maxf(0.0, groove) * 0.55
	if f.ck_fill == "empty":
		for k in ck:
			var da := absf(wrapf(phi - float(k[0]), -PI, PI)) * r
			r -= float(k[1]) * 0.25 * maxf(0.0, 1.0 - da / (float(k[2]) * 1.6))
	return r

## a grid is wound one way throughout: turn the whole of it to face along out(centre), as most of its triangles say
static func _orient(g: Geo, out: Callable) -> Geo:
	var vote := 0.0
	for k in g.idx.size() / 3:
		var a := g.v[g.idx[k * 3]]
		var b := g.v[g.idx[k * 3 + 1]]
		var c := g.v[g.idx[k * 3 + 2]]
		vote += signf((b - a).cross(c - a).dot(out.call((a + b + c) / 3.0)))
	if vote < 0.0:
		for k in g.idx.size() / 3:
			var t := g.idx[k * 3 + 1]
			g.idx[k * 3 + 1] = g.idx[k * 3 + 2]
			g.idx[k * 3 + 2] = t
	return g

## a polar grid filling the outline at z: face (+1 facing +z, -1 facing -z), polish, how it bends (zf(phi, s) → z)
static func _disc(f: Dictionary, nz: Dictionary, ck: Array, z: float, face: float, polish: float, zf: Callable, na: int, nr: int) -> Geo:
	var g := Geo.new()
	for i in na + 1:
		var phi := TAU * float(i) / na
		var ol := _outline(f, nz, phi, z)
		var rim := _rim(f, nz, ck, phi, z)
		var d := Vector3(cos(phi), sin(phi), 0)
		for j in nr + 1:
			var s := float(j) / nr
			var p := d * rim * s
			var zz: Vector2 = zf.call(p, s)   # (z, depth in the heart 0..1)
			g.v.append(Vector3(p.x, p.y, zz.x))
			g.rp.append(Vector3(ol.x, float(f.bark_t) * ol.y, 0))
			g.col.append(Color(polish, 1, zz.y, 1))
	for i in na:
		for j in nr:
			var p0 := i * (nr + 1) + j
			var p1 := p0 + nr + 1
			g.idx.append_array([p0, p1, p0 + 1, p0 + 1, p1, p1 + 1])
	return _orient(g, func(_c: Vector3) -> Vector3: return Vector3(0, 0, face))

## the side: the bark round the trunk from z0(phi) to z1(phi); its outline looked up from r0 to r1 along the trunk
## (the same z the end faces use, so their edges meet)
static func _side(f: Dictionary, nz: Dictionary, ck: Array, z0: Callable, z1: Callable, r0: float, r1: float, na: int, nzs: int) -> Geo:
	var g := Geo.new()
	for i in na + 1:
		var phi := TAU * float(i) / na
		var a: float = z0.call(phi)
		var b: float = z1.call(phi)
		var d := Vector3(cos(phi), sin(phi), 0)
		for j in nzs + 1:
			var z := lerpf(a, b, float(j) / nzs)
			var zr := lerpf(r0, r1, float(j) / nzs)
			var ol := _outline(f, nz, phi, zr)
			g.v.append(d * _rim(f, nz, ck, phi, zr) + Vector3(0, 0, z))
			g.rp.append(Vector3(ol.x, float(f.bark_t) * ol.y, 0))
			g.col.append(Color(0, 0, 0, 1))
	for i in na:
		for j in nzs:
			var p0 := i * (nzs + 1) + j
			var p1 := p0 + nzs + 1
			g.idx.append_array([p0, p1, p0 + 1, p0 + 1, p1, p1 + 1])
	return _orient(g, func(c: Vector3) -> Vector3: return Vector3(c.x, c.y, 0))

# ---------------------------------------------------------------- material

static func material(f: Dictionary) -> ShaderMaterial:
	var pal: Dictionary = PAL[int(f.pal)]
	var m := ShaderMaterial.new()
	m.shader = SHADER
	for k in ["early", "late", "st1", "st2", "bark"]:
		m.set_shader_parameter("c_" + k, Color.hex(int(pal[k]) << 8 | 0xff))
	m.set_shader_parameter("rings_n", f.rings)
	m.set_shader_parameter("ecc", f.ecc)
	m.set_shader_parameter("seed", float(int(f.seed) % 997) * 0.37)
	var ck := _checks(f)
	var arr := PackedVector4Array()
	for k in 6:
		arr.append(Vector4(ck[k][0], ck[k][1], ck[k][2], ck[k][3]) if k < ck.size() else Vector4(0, 0, 0, 0))
	m.set_shader_parameter("ck", arr)
	m.set_shader_parameter("ck_n", ck.size())
	m.set_shader_parameter("ck_fill", CK_FILL.get(f.ck_fill, 0))
	m.set_shader_parameter("opal_k", f.opal)
	m.set_shader_parameter("fire_h", FIRE.get(f.fire, 0.3))
	if String(f.heart) != "":
		m.set_shader_parameter("heart_col", Color.hex(int(HEART[f.heart]) << 8 | 0xff))
		m.set_shader_parameter("heart_r", f.heart_r)
		m.set_shader_parameter("heart_s", float(int(f.seed) % 97))
	return m

# ---------------------------------------------------------------- the piece

## builds the wood into the builder's root
static func build(b: RefCounted, gene: Dictionary) -> MeshInstance3D:
	var f: Dictionary = gene.fossil
	var rng: Rng32 = b.rng
	var root: Node3D = b.root
	var gs: float = gene.scale
	var nz := _noises(f)
	var ck := _checks(f)
	var m := material(f)
	var main: MeshInstance3D
	var flat := func(z: float) -> Callable: return func(_p: Vector3, _s: float) -> Vector2: return Vector2(z, 0)
	var parts: Array[Geo] = []
	if f.show == "slice":
		var h: float = f.thick
		var zf := h * 0.5
		# the hollow heart: a bowl sunk into the face round the pith, its rim lumpy
		var hr: float = f.heart_r
		var ecc: Vector2 = f.ecc
		var bowl := func(p: Vector3, _s: float) -> Vector2:
			if String(f.heart) == "":
				return Vector2(zf, 0)
			var q := Vector2(p.x, p.y) - ecc
			var a := atan2(q.y, q.x)
			var t := q.length() / _heart_r(f, a)
			if t >= 1.0:
				return Vector2(zf, 0)
			# a flat rind of chalcedony round the rim, then the walls going down
			var dep := h * 0.62 * smoothstep(0.86, 0.5, t) * (0.85 + 0.15 * (1.0 - t * t))
			return Vector2(zf - dep, maxf(0.03, smoothstep(1.0, 0.6, t)))
		parts.append(_disc(f, nz, ck, 0.0, 1.0, 1.0, bowl, 160, 56))
		parts.append(_disc(f, nz, ck, 0.0, -1.0, 0.3, flat.call(-zf), 160, 20))
		parts.append(_side(f, nz, ck, func(_a: float) -> float: return -zf, func(_a: float) -> float: return zf, 0.0, 0.0, 160, 6))
	else:
		var L: float = f.len
		# the broken end: stepped along the grain, rough, with a splinter or two standing out
		var bn := nz.brk as FastNoiseLite
		var brk := func(p: Vector3) -> float:
			var n := bn.get_noise_2d(p.x * 1.2, p.y * 1.2)
			var steps: float = floor((n * 0.5 + 0.5) * 4.0) / 4.0
			return -0.22 * steps - 0.05 * bn.get_noise_2d(p.x * 5.0, p.y * 5.0) - 0.12 * maxf(0.0, p.x * 0.4 + p.y * 0.2)
		var z0 := func(a: float) -> float: return brk.call(Vector3(cos(a), sin(a), 0) * _rim(f, nz, ck, a, 0.0))
		var broken := func(p: Vector3, _s: float) -> Vector2: return Vector2(brk.call(p), 0)
		parts.append(_disc(f, nz, ck, L, 1.0, 1.0, flat.call(L), 128, 40))
		parts.append(_disc(f, nz, ck, 0.0, -1.0, 0.0, broken, 128, 40))
		parts.append(_side(f, nz, ck, z0, func(_a: float) -> float: return L, 0.0, L, 128, int(L * 40.0)))
	var holder := Node3D.new()
	root.add_child(holder)
	for k in parts.size():
		var mi := U.mesh(parts[k], m, holder)
		mi.set_meta("col", true)
		if k == 0: main = mi
	var len_z: float = f.thick if f.show == "slice" else f.len
	if f.show == "slice":
		# stands on its edge, the polished face to the viewer, leaning back a little
		holder.transform = Transform3D(Basis(Vector3.UP, -0.35 + (rng.next() - 0.5) * 0.4) * Basis(Vector3.RIGHT, -0.22) * Basis(Vector3.BACK, rng.next() * TAU) * Basis.from_scale(Vector3.ONE * gs), Vector3.ZERO)
	else:
		# lies on its side, the polished end turned towards the viewer
		# (the viewer turns every specimen 0.6 about y: the end then faces it at about 35 degrees, left or right)
		var yaw := (0.0 if rng.next() < 0.5 else -1.2) + (rng.next() - 0.5) * 0.3
		var bs := Basis(Vector3.RIGHT, 0.25) * Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, rng.next() * TAU) * Basis.from_scale(Vector3.ONE * gs * 0.62)
		holder.transform = Transform3D(bs, bs * Vector3(0, 0, -len_z * 0.5))
	# the heart's crystals
	if String(f.heart) != "":
		_heart(b, f, holder, main)
	if gene.fx == "dragonfire":
		root.set_meta("dim", true)
		m.set_shader_parameter("flow_k", 1.0)
	_marks(b, f, nz, ck, holder)
	return main

## the hollow heart's rim at angle a round the pith — a few smooth lobes; the shader draws the same line
static func _heart_r(f: Dictionary, a: float) -> float:
	var s := float(int(f.seed) % 97)
	return float(f.heart_r) * (1.0 + 0.12 * sin(3.0 * a + s) + 0.08 * sin(5.0 * a + s * 1.7) + 0.04 * sin(9.0 * a + s * 2.3))

## crystals lining the hollow heart, pointing in and up out of the bowl, below the face
static func _heart(b: RefCounted, f: Dictionary, holder: Node3D, face: MeshInstance3D) -> void:
	var g: Geo = face.get_meta("geo")
	var rng := Rng32.new(int(f.seed) * 11 + 7)
	var zf: float = float(f.thick) * 0.5
	var ecc: Vector2 = f.ecc
	var pts := []
	for i in g.v.size():
		if g.col[i].b > 0.35:
			pts.append(g.v[i])
	if pts.is_empty():
		return
	var col := SpecMat.lin(HEART[f.heart])
	var gl := SpecMat.make({col = Color(1, 1, 1), flat = true, glass = true, ir = 0.05, rf = 0.25, holo = 0.15,
		frost = 0.08, thick = 1.2, seed = 3.0})
	var axis := Vector3(ecc.x, ecc.y, zf)
	for k in 14:
		var p: Vector3 = pts[int(rng.next() * pts.size())]
		var room := zf - p.z
		if room < 0.02:
			continue
		var d := ((axis - p).normalized() * 0.6 + Vector3(0, 0, 1) + Vector3(rng.next() - 0.5, rng.next() - 0.5, 0) * 0.5).normalized()
		var hh := 0.8 + rng.next() * 0.5
		var s := minf(room * 0.85 / (hh * d.z + 0.001), float(f.heart_r) * (0.25 + rng.next() * 0.2))
		var geo := RockKit.crystal("prism", rng, {h = hh, detail = 1, cA = col.lerp(Color(1, 1, 1), 0.45), cB = col, zk = 0.6})
		U.mesh(geo, gl, holder, p - d * s * 0.1, Basis(U.quat_to(Vector3.UP, d)) * Basis(Vector3.UP, rng.next() * TAU) * Basis.from_scale(Vector3.ONE * s))

## the callouts' points, each where the shader really draws its gene
static func _marks(b: RefCounted, f: Dictionary, nz: Dictionary, ck: Array, holder: Node3D) -> void:
	var xf := U.rel_xform(holder, b.root)
	var zf: float = float(f.thick) * 0.5 if f.show == "slice" else float(f.len)
	var fz := Vector3(0, 0, zf)
	var on_face := func(phi: float, s: float) -> Vector3:
		return Vector3(cos(phi), sin(phi), 0) * _rim(f, nz, ck, phi, zf if f.show == "log" else 0.0) * s + fz
	var nrm := (xf.basis * Vector3.BACK).normalized()
	var mk := func(id: String, p: Vector3, n: Vector3) -> void: b._mark(id, xf * p, n)
	var ecc: Vector2 = f.ecc
	mk.call("rings", on_face.call(0.7, 0.55) + Vector3(ecc.x, ecc.y, 0) * 0.3, nrm)
	for k in ck.size():
		var c: Array = ck[k]
		var rel := 1.0 - float(c[1]) * 0.3
		mk.call("checks_" + String(f.ck_fill), on_face.call(float(c[0]), rel), nrm)
		if f.ck_fill == "opal": mk.call("opal", on_face.call(float(c[0]), rel - 0.04), nrm)
	if float(f.opal) >= 0.4:
		for k in 3:
			mk.call("opal", on_face.call(1.3 + k * 2.1, 0.35 + 0.15 * k), nrm)
	if String(f.heart) != "":
		mk.call("heart_" + String(f.heart), Vector3(ecc.x, ecc.y, zf - float(f.thick) * 0.3), nrm)
	if float(f.bark) > 0.0:
		var found := 0
		for i in 24:
			var phi := TAU * i / 24.0
			var z := 0.0 if f.show == "slice" else float(f.len) * 0.6
			if _outline(f, nz, phi, z).y > 0.9:
				var p := Vector3(cos(phi), sin(phi), 0) * _rim(f, nz, ck, phi, z) + Vector3(0, 0, z)
				mk.call("bark", p, (xf.basis * Vector3(cos(phi), sin(phi), 0)).normalized())
				found += 1
				if found >= 3: break
