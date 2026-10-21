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
	var sh := Shader.new()
	sh.code = SHADER
	m.shader = sh
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
		for i in list.size():
			var pn: Array = near[int(rng.next() * near.size())]
			var p: Vector3 = pn[0]
			var nrm: Vector3 = pn[1]
			var d := p.distance_to(center) / radius
			var up := (nrm.lerp(Vector3.UP, 0.35) + Vector3(rng.next() - 0.5, rng.next() * 0.2, rng.next() - 0.5) * lean * 2.0).normalized()
			var s := size * (0.6 + rng.next() * 0.7) * (1.2 - d * 0.5)
			var b := Basis(SpecUtil.quat_to(Vector3.UP, up)) * Basis(Vector3.UP, rng.next() * TAU) * Basis.from_scale(Vector3.ONE * s)
			mm.set_instance_transform(i, Transform3D(b, p - nrm * s * 0.004))
			var v := 0.75 + rng.next() * 0.45
			mm.set_instance_color(i, Color(tint.r * v, tint.g * v * (0.95 + rng.next() * 0.1), tint.b * v))
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = material(kind)
		parent.add_child(mi)
