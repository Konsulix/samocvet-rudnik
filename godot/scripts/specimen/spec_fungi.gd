class_name SpecFungi
extends RefCounted
## Mushrooms on the host rock (the "mushrooms" gene), four kinds built from lathe profiles and shaded by one
## shader: fly agaric (red, white warts, a ring on the stem), chanterelle (a golden funnel with a wavy rim and
## ridges running down the stem), porcini (a brown bun on a fat stem, sponge underneath) and glowing mycena
## (slender bells in clusters that glow softly, more so when the studio goes dark).
## A cluster grows from one spot on the rock: a couple of grown caps and young ones of every size around them.
## Decisions and placement use their own random stream (seeded from the stone), so stones that already
## existed keep every other gene exactly as they were.

const NAMES := ["fly agarics", "chanterelles", "porcini", "glowing mycena"]

## profile points [r, y, region]: region 0 stem, 0.5 underside (gills or sponge), 1 cap.
## Bottom to top, out along the underside, then over the cap back to the axis.
const KINDS := [
	{prof = [[0.0, 0.0, 0], [0.13, 0.0, 0], [0.12, 0.06, 0], [0.085, 0.16, 0], [0.075, 0.42, 0], [0.11, 0.47, 0], [0.072, 0.5, 0], [0.068, 0.6, 0],
		[0.07, 0.6, 0.5], [0.25, 0.6, 0.5], [0.42, 0.58, 0.5], [0.44, 0.61, 1], [0.42, 0.7, 1], [0.34, 0.81, 1], [0.2, 0.88, 1], [0.0, 0.9, 1]],
		cap_a = Color(0.55, 0.012, 0.008), cap_b = Color(0.82, 0.08, 0.015), gill = Color(0.93, 0.9, 0.82), stem = Color(0.92, 0.9, 0.84),
		cap_r = 0.44, spots = 1.0, gills = 70.0, pores = 0.0, glow = 0.0, rough = 0.32, wave = 0.0},
	{prof = [[0.0, 0.0, 0], [0.07, 0.0, 0], [0.065, 0.12, 0], [0.075, 0.26, 0.5], [0.12, 0.38, 0.5], [0.24, 0.48, 0.5], [0.38, 0.55, 0.5], [0.4, 0.58, 1],
		[0.36, 0.6, 1], [0.22, 0.56, 1], [0.08, 0.5, 1], [0.0, 0.48, 1]],
		cap_a = Color(0.72, 0.28, 0.02), cap_b = Color(0.85, 0.42, 0.05), gill = Color(0.8, 0.4, 0.06), stem = Color(0.78, 0.42, 0.1),
		cap_r = 0.4, spots = 0.0, gills = 26.0, pores = 0.0, glow = 0.0, rough = 0.6, wave = 0.09},
	{prof = [[0.0, 0.0, 0], [0.15, 0.0, 0], [0.19, 0.1, 0], [0.19, 0.2, 0], [0.15, 0.33, 0], [0.12, 0.44, 0],
		[0.12, 0.44, 0.5], [0.3, 0.45, 0.5], [0.42, 0.47, 0.5], [0.44, 0.5, 1], [0.42, 0.6, 1], [0.33, 0.7, 1], [0.18, 0.76, 1], [0.0, 0.78, 1]],
		cap_a = Color(0.1, 0.04, 0.015), cap_b = Color(0.24, 0.11, 0.045), gill = Color(0.72, 0.66, 0.3), stem = Color(0.82, 0.74, 0.55),
		cap_r = 0.44, spots = 0.0, gills = 0.0, pores = 1.0, glow = 0.0, rough = 0.42, wave = 0.0},
	{prof = [[0.0, 0.0, 0], [0.03, 0.0, 0], [0.024, 0.3, 0], [0.02, 0.7, 0], [0.02, 0.74, 0.5], [0.08, 0.76, 0.5], [0.15, 0.74, 0.5], [0.16, 0.76, 1],
		[0.14, 0.84, 1], [0.09, 0.93, 1], [0.04, 0.98, 1], [0.0, 1.0, 1]],
		cap_a = Color(0.5, 0.52, 0.38), cap_b = Color(0.72, 0.72, 0.55), gill = Color(0.75, 0.82, 0.6), stem = Color(0.7, 0.72, 0.6),
		cap_r = 0.16, spots = 0.0, gills = 18.0, pores = 0.0, glow = 1.0, rough = 0.5, wave = 0.0},
]

const SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform vec3 cap_a;
uniform vec3 cap_b;
uniform vec3 gill;
uniform vec3 stem;
uniform float cap_r = 0.4;
uniform float spots = 0.0;
uniform float gills_n = 40.0;
uniform float pores = 0.0;
uniform float glow = 0.0;
uniform float rough_cap = 0.5;
global uniform float fluor_uv;
varying vec3 v_op;
varying float v_reg;
float h3(vec3 p) { p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float vn(vec3 x) {
	vec3 i = floor(x), f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h3(i), h3(i + vec3(1, 0, 0)), f.x), mix(h3(i + vec3(0, 1, 0)), h3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(h3(i + vec3(0, 0, 1)), h3(i + vec3(1, 0, 1)), f.x), mix(h3(i + vec3(0, 1, 1)), h3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
void vertex() { v_op = VERTEX; v_reg = UV2.x; }
void fragment() {
	float capk = step(0.75, v_reg);
	float underk = step(0.25, v_reg) * (1.0 - capk);
	float stemk = 1.0 - capk - underk;
	float rr = length(v_op.xz);
	float ang = atan(v_op.z, v_op.x);
	// cap: dark centre to a paler rim, mottled, with raised white warts on the agaric
	vec3 cc = mix(cap_a, cap_b, smoothstep(0.15, 1.0, rr / cap_r)) * (0.82 + 0.3 * vn(v_op * 14.0));
	float wart = smoothstep(0.66, 0.72, vn(v_op * 15.0)) * spots;
	cc = mix(cc, vec3(0.94, 0.9, 0.82), wart);
	// underside: fine radial gills or a sponge of pores
	float g = 0.5 + 0.5 * sin(ang * gills_n);
	vec3 uc = gill * mix(1.0, mix(0.5, 1.0, smoothstep(0.15, 0.85, g)), step(1.0, gills_n));
	uc *= mix(1.0, 0.55 + 0.45 * smoothstep(0.35, 0.6, vn(v_op * 110.0)), pores);
	// stem: lengthwise fibres
	vec3 sc = stem * (0.82 + 0.25 * vn(vec3(v_op.x * 45.0, v_op.y * 5.0, v_op.z * 45.0)));
	vec3 c = sc * stemk + uc * underk + cc * capk;
	ALBEDO = c * COLOR.rgb;
	ROUGHNESS = mix(0.78, rough_cap, capk) - wart * 0.2;
	SPECULAR = 0.35;
	BACKLIGHT = c * 0.15;
	// mycena glow: the gills brightest, breathing slowly; brighter still when the room goes dark
	float br = (0.8 + 0.2 * sin(TIME * 1.3 + v_op.y * 4.0)) * (1.0 + fluor_uv * 1.5);
	EMISSION = glow * vec3(0.25, 0.95, 0.35) * (underk * 0.9 + capk * 0.3 + stemk * 0.15) * br;
}
"""

static var _shader: Shader
static var _meshes := {}
static var _mats := {}

## does this stone grow mushrooms, and which kind (-1: none). Its own random stream, not the genome's.
static func roll(seed_v: int) -> int:
	var r := Rng32.new((seed_v * 2654435 + 4093) % 4294967296)
	if r.next() > 0.14:
		return -1
	return int(Stones.pick_w([[0, 3.0], [1, 2.5], [2, 2.0], [3, 1.4]], r))

static func mesh(kind: int) -> ArrayMesh:
	if _meshes.has(kind):
		return _meshes[kind]
	var K: Dictionary = KINDS[kind]
	var prof: Array = K.prof
	var n := prof.size()
	var segs := 28
	var wave: float = K.wave
	var cap_r: float = K.cap_r
	var g := Geo.new()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	for i in segs + 1:
		var phi := float(i) / segs * TAU
		for j in n:
			var p: Array = prof[j]
			var r: float = p[0]
			# a wavy, lobed rim (chanterelle): the more so the further out
			if wave > 0.0 and float(p[2]) > 0.25:
				r *= 1.0 + wave * sin(phi * 5.0 + sin(phi * 2.0) * 1.3) * smoothstep(0.3, 1.0, r / cap_r)
			g.v.append(Vector3(r * sin(phi), float(p[1]), r * cos(phi)))
			uv.append(Vector2(float(i) / segs, float(j) / (n - 1)))
			uv2.append(Vector2(float(p[2]), 0.0))
	for i in segs:
		for j in n - 1:
			var a := i * n + j
			g.idx.append_array([a, a + n, a + 1, a + n + 1, a + 1, a + n])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = g.v
	arr[Mesh.ARRAY_NORMAL] = g.normals()
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_TEX_UV2] = uv2
	var f := g.idx.duplicate()
	for k in range(0, f.size(), 3):
		var s := f[k + 1]
		f[k + 1] = f[k + 2]
		f[k + 2] = s
	arr[Mesh.ARRAY_INDEX] = f
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_meshes[kind] = m
	return m

static func material(kind: int) -> ShaderMaterial:
	if _mats.has(kind):
		return _mats[kind]
	if not _shader:
		_shader = Shader.new()
		_shader.code = SHADER
	var K: Dictionary = KINDS[kind]
	var m := ShaderMaterial.new()
	m.shader = _shader
	for k in ["cap_a", "cap_b", "gill", "stem"]:
		var c: Color = K[k]
		m.set_shader_parameter(k, Vector3(c.r, c.g, c.b))
	m.set_shader_parameter("cap_r", K.cap_r)
	m.set_shader_parameter("spots", K.spots)
	m.set_shader_parameter("gills_n", K.gills)
	m.set_shader_parameter("pores", K.pores)
	m.set_shader_parameter("glow", K.glow)
	m.set_shader_parameter("rough_cap", K.rough)
	_mats[kind] = m
	return m

## one cluster of `kind` round a spot of `spots` ([pos, normal]); size: the height of a grown one
## blockers: the crystals ({bounds, inverse}: their box in their own axes, and the way into them) no cap may grow into.
## Gives the spot of the biggest cap, or an empty array when none found room
static func cluster(parent: Node3D, rng: Rng32, spots: Array, kind: int, count: int, size: float, blockers: Array = []) -> Array:
	if spots.is_empty():
		return []
	var c0: Array = spots[int(rng.next() * spots.size())]
	var reach := size * (0.9 if kind == 3 else 1.4)
	var near := []
	for s in spots:
		if (s[0] as Vector3).distance_to(c0[0]) < reach: near.append(s)
	if near.is_empty(): near = [c0]
	var box := mesh(kind).get_aabb()
	var placed: Array[Transform3D] = []
	var tints: Array[Color] = []
	for k in count:
		# a few tries for a spot clear of the crystals; none clear, and this one never comes up
		for attempt in 12:
			var pool: Array = near if attempt < 6 else spots
			var at: Array = c0 if k == 0 and attempt == 0 else pool[int(rng.next() * pool.size())]
			var p: Vector3 = at[0]
			var nrm: Vector3 = at[1]
			# mostly upright, leaning a little off the rock face
			var up := (nrm.lerp(Vector3.UP, 0.7) + Vector3(rng.next() - 0.5, 0, rng.next() - 0.5) * 0.35).normalized()
			# a grown one or two, then young ones of every size, down to buttons
			var grow := 1.0 if k == 0 else 0.25 + 0.75 * pow(rng.next(), 1.4)
			var s := size * grow
			var b := Basis(SpecUtil.quat_to(Vector3.UP, up)) * Basis(Vector3.UP, rng.next() * TAU)
			b = b * Basis.from_scale(Vector3(s * (0.9 + rng.next() * 0.25), s * (0.85 + rng.next() * 0.3), s * (0.9 + rng.next() * 0.25)))
			var xf := Transform3D(b, p - nrm * s * 0.04)
			var hit := false
			for bl: Dictionary in blockers:
				if ((bl.inverse as Transform3D) * xf * box).intersects(bl.bounds):
					hit = true
					break
			if hit:
				continue
			var v := 0.85 + rng.next() * 0.25
			placed.append(xf)
			tints.append(Color(v, v * (0.96 + rng.next() * 0.06), v))
			break
	if placed.is_empty():
		return []
	var buf := SpecUtil.mm_buf(placed.size())
	for k in placed.size():
		SpecUtil.put(buf, k, placed[k], tints[k])
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh(kind)
	mm.instance_count = placed.size()
	mm.buffer = buf
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = material(kind)
	parent.add_child(mi)
	return [placed[0].origin, placed[0].basis.y.normalized()]
