class_name SpecPlants
extends RefCounted
## Living things on the host rock, from photo-scanned plant models (Poly Haven, CC0):
## a carpet of moss sprigs, grass blades and seedlings poking out of it, now and then a young fern.
## Each model variant becomes one MultiMesh, so thousands of sprigs cost a handful of draw calls.

const SHADER := """
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;
uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform sampler2D nrm : hint_normal, filter_linear_mipmap;
void fragment() {
	vec4 t = texture(tex, UV);
	ALBEDO = t.rgb * COLOR.rgb;
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = 0.4;
	NORMAL_MAP = texture(nrm, UV).rgb;
	ROUGHNESS = 0.72;
	SPECULAR = 0.3;
	BACKLIGHT = t.rgb * COLOR.rgb * 0.7;
}
"""

## which models of a pack to use for each kind of growth
const KINDS := {
	moss = ["moss_01", ["moss_01_a_LOD0", "moss_01_b_LOD0", "moss_01_c_LOD0", "moss_01_d_LOD0", "moss_01_e_LOD0", "moss_01_f_LOD0", "moss_01_g_LOD0", "moss_01_h_LOD0", "moss_01_i_LOD0", "moss_01_j_LOD0", "moss_01_tall_a_LOD0", "moss_01_tall_b_LOD0"]],
	grass = ["grass_bermuda_01", ["grass_bermuda_01_single_a", "grass_bermuda_01_single_b", "grass_bermuda_01_medium_a", "grass_bermuda_01_medium_d", "grass_bermuda_01_medium_f", "grass_bermuda_01_seedling_a", "grass_bermuda_01_seedling_c", "grass_bermuda_01_small_e"]],
	tuft = ["grass_medium_02", ["grass_medium_02_a", "grass_medium_02_b"]],
	fern = ["fern_02", ["fern_02_a", "fern_02_d"]],
}

const BED_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D bed : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D bed_n : filter_linear_mipmap, repeat_enable;
uniform sampler2D bed_h : filter_linear_mipmap, repeat_enable;
uniform vec3 tint = vec3(1.0);
varying float v_r;
void vertex() { v_r = UV2.x; }
void fragment() {
	float h = texture(bed_h, UV).r;
	// the cushion frays at its rim: only the tallest sprigs reach out there
	ALPHA = step(smoothstep(0.55, 1.0, v_r) * 1.05, h);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	vec3 c = texture(bed, UV).rgb * 2.2 * tint;
	ALBEDO = c * mix(0.55, 1.15, h);
	vec3 nn = texture(bed_n, UV).rgb * 2.0 - 1.0;
	NORMAL_MAP = vec3(nn.x * 0.5 + 0.5, nn.y * 0.5 + 0.5, 1.0);
	NORMAL_MAP_DEPTH = 1.4;
	ROUGHNESS = 0.8;
	SPECULAR = 0.25;
	BACKLIGHT = c * 0.6;
}
"""

static var _bed_mat: ShaderMaterial
static var _meshes := {}
static var _mats := {}

static func meshes(kind: String) -> Array:
	if _meshes.has(kind):
		return _meshes[kind]
	var pack: String = KINDS[kind][0]
	var sc: PackedScene = load("res://assets/plants/%s/%s.gltf" % [pack, pack])
	var root := sc.instantiate()
	var out := []
	for nm in KINDS[kind][1]:
		var mi := root.find_child(nm, true, false) as MeshInstance3D
		if mi: out.append(mi.mesh)
	root.free()
	_meshes[kind] = out
	return out

static func material(kind: String) -> ShaderMaterial:
	var pack: String = KINDS[kind][0]
	if _mats.has(pack):
		return _mats[pack]
	var m := ShaderMaterial.new()
	m.shader = ShaderFiles.get_shader("plants", SHADER)
	m.set_shader_parameter("tex", load("res://assets/plants/%s/textures/%s_diff_1k.png" % [pack, pack]))
	m.set_shader_parameter("nrm", load("res://assets/plants/%s/textures/%s_nor_gl_1k.jpg" % [pack, pack]))
	_mats[pack] = m
	return m

## scatter `count` plants of a kind over the points of `pool` ([pos, normal]) within `radius` of `center`.
## size: how many times the real-world model size; lean: how far they tip away from the surface normal
static func scatter(parent: Node3D, rng: Rng32, pool: Array, center: Vector3, radius: float, count: int, kind: String, size: float, lean := 0.4, tint := Color(1, 1, 1)) -> void:
	var near := []
	for pn in pool:
		if (pn[0] as Vector3).distance_to(center) < radius:
			near.append(pn)
	if near.is_empty():
		return
	var ms := meshes(kind)
	if ms.is_empty():
		return
	var per := []
	for m in ms: per.append([])
	for k in count:
		per[int(rng.next() * ms.size())].append(k)
	for vi in ms.size():
		var list: Array = per[vi]
		if list.is_empty(): continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = ms[vi]
		mm.instance_count = list.size()
		var buf := SpecUtil.mm_buf(list.size())
		for i in list.size():
			var pn: Array = near[int(rng.next() * near.size())]
			var p: Vector3 = pn[0]
			var nrm: Vector3 = pn[1]
			var d := p.distance_to(center) / radius
			var up := (nrm.lerp(Vector3.UP, 0.35) + Vector3(rng.next() - 0.5, rng.next() * 0.2, rng.next() - 0.5) * lean * 2.0).normalized()
			var s := size * (0.6 + rng.next() * 0.7) * (1.2 - d * 0.5)
			var b := Basis(SpecUtil.quat_to(Vector3.UP, up)) * Basis(Vector3.UP, rng.next() * TAU) * Basis.from_scale(Vector3.ONE * s)
			var xf := Transform3D(b, p - nrm * s * 0.004)
			var v := 0.75 + rng.next() * 0.45
			SpecUtil.put(buf, i, xf, Color(tint.r * v, tint.g * v * (0.95 + rng.next() * 0.1), tint.b * v))
		mm.buffer = buf
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = material(kind)
		parent.add_child(mi)

static func bed_material(tint: Color) -> ShaderMaterial:
	if not _bed_mat:
		_bed_mat = ShaderMaterial.new()
		_bed_mat.shader = ShaderFiles.get_shader("plants_bed", BED_SHADER)
		_bed_mat.set_shader_parameter("bed", load("res://assets/plants/moss_bed/moss_bed_diff.png"))
		_bed_mat.set_shader_parameter("bed_n", load("res://assets/plants/moss_bed/moss_bed_nrm.png"))
		_bed_mat.set_shader_parameter("bed_h", load("res://assets/plants/moss_bed/moss_bed_height.png"))
	var m := _bed_mat.duplicate() as ShaderMaterial
	m.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
	return m

## a cushion of moss hugging the rock around `center`: a thin shell textured with the baked moss bed,
## fraying at its rim. Returns points on its top for sprigs and blades to stand on.
static func cushion(parent: Node3D, rng: Rng32, pool: Array, center: Vector3, rad: float, thick: float, tint := Color(1, 1, 1)) -> Array:
	var near := []
	for pn in pool:
		if (pn[0] as Vector3).distance_to(center) < rad * 1.4:
			near.append(pn)
	if near.size() < 4:
		return []
	var n0 := Vector3.ZERO
	for pn in near: n0 += pn[1]
	n0 = n0.normalized()
	var T := n0.cross(Vector3.FORWARD if absf(n0.y) > 0.9 else Vector3.UP).normalized()
	var B := n0.cross(T)
	var rings := 9
	var segs := 28
	var tile := 0.42
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var out := []
	var ph := rng.next() * 10.0
	for ri in rings + 1:
		var rr := float(ri) / rings
		for si in segs:
			var a := float(si) / segs * TAU
			var wob := 1.0 + sin(a * 3.0 + ph) * 0.12 + sin(a * 7.0 + ph * 2.0) * 0.06
			var u := cos(a) * rr * rad * wob
			var w := sin(a) * rr * rad * wob
			var q := center + T * u + B * w
			var best: Array = near[0]
			var bd := 1e9
			for pn in near:
				var d := (pn[0] as Vector3).distance_squared_to(q)
				if d < bd:
					bd = d
					best = pn
			var bp: Vector3 = best[0]
			var bn: Vector3 = best[1]
			var on := q - bn * (q - bp).dot(bn)
			var lift := thick * sqrt(maxf(0.0, 1.0 - rr * rr)) + 0.004
			var pos := on + bn * lift
			v.append(pos)
			uv.append(Vector2(u, w) / tile + Vector2(ph, ph * 0.7))
			uv2.append(Vector2(rr, 0))
			if rr < 0.8:
				out.append([pos, bn])
			if ri == 0:
				break
	var idx := PackedInt32Array()
	# centre fan, then quads between rings (ring 0 is a single centre vertex)
	for si in segs:
		idx.append_array([0, 1 + si, 1 + (si + 1) % segs])
	for ri in range(1, rings):
		var a0 := 1 + (ri - 1) * segs
		var a1 := 1 + ri * segs
		for si in segs:
			var j := (si + 1) % segs
			idx.append_array([a0 + si, a1 + si, a1 + j, a0 + si, a1 + j, a0 + j])
	var g := Geo.new()
	g.v = v
	g.idx = idx
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = g.normals()
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_TEX_UV2] = uv2
	# tangents along the projected u axis for the normal map
	var tan := PackedFloat32Array()
	for i in v.size():
		tan.append_array([T.x, T.y, T.z, 1.0])
	arr[Mesh.ARRAY_TANGENT] = tan
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = bed_material(tint)
	parent.add_child(mi)
	return out
