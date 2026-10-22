class_name SpecBolt
extends MeshInstance3D
## Lightning trapped in a crystal. A bolt is grown by midpoint displacement (a jagged main channel
## with forking side branches), drawn as camera-facing ribbons with a white-hot core and a wide
## coloured glow. It strikes, flickers, fades to an afterglow and strikes again along a new path,
## lighting the crystal from inside with each flash.

const SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_test_disabled, depth_draw_never;
uniform vec3 glow_col = vec3(0.35, 0.6, 2.2);
uniform float flash = 1.0;
void vertex() {
	// UV.x: -1..1 across the ribbon; UV2.x: half-width; NORMAL holds the segment direction
	vec3 dir = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 pv = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 side = normalize(cross(dir, normalize(-pv)));
	pv += side * UV.x * UV2.x;
	POSITION = PROJECTION_MATRIX * vec4(pv, 1.0);
}
void fragment() {
	float x = abs(UV.x);
	// COLOR.r = 1: the thin white-hot channel; 0: the soft halo around a smoothed copy of the path
	float a = COLOR.a * flash;
	vec3 c = COLOR.r > 0.5
		? vec3(4.0, 4.2, 4.8) * exp(-x * x * 6.0) + glow_col * 0.6 * exp(-x * x * 1.5)
		: glow_col * 0.7 * pow(1.0 - x, 2.5) * pow(sin(UV.y * 3.14159), 0.7);
	ALBEDO = c * a;
}
"""

var bounds := AABB()
var col := Color(0.35, 0.6, 2.2)
var rng := RandomNumberGenerator.new()
var light: OmniLight3D
var _t := 0.0
var _next := 0.0
var _mat: ShaderMaterial
var coarse := []

func setup(bb: AABB, seed_v: int, glow: Color) -> SpecBolt:
	bounds = bb
	col = glow
	rng.seed = seed_v
	_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER
	_mat.shader = sh
	_mat.set_shader_parameter("glow_col", Vector3(col.r, col.g, col.b))
	_mat.render_priority = 100
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 4.0
	light = OmniLight3D.new()
	light.light_color = Color(0.6, 0.75, 1.0)
	light.omni_range = bb.size.length() * 1.6
	light.position = bb.get_center()
	add_child(light)
	_strike()
	return self

func _process(dt: float) -> void:
	_t += dt
	if _t >= _next:
		_strike()
	# a strike: bright, a couple of flickers, then an afterglow that dies away
	var k := _t / maxf(0.001, _next)
	var f := 0.0
	if _t < 0.06: f = 1.0
	elif _t < 0.1: f = 0.25
	elif _t < 0.16: f = 0.9
	else: f = 0.18 + 0.5 * exp(-(_t - 0.16) * 4.0)
	f *= 1.0 - smoothstep(0.85, 1.0, k)
	_mat.set_shader_parameter("flash", f)
	light.light_energy = f * 2.5

func _strike() -> void:
	_t = 0.0
	_next = 0.9 + rng.randf() * 1.6
	var b := bounds
	var lo := b.position + b.size * Vector3(0.32, 0.1, 0.32)
	var hi := b.end - b.size * Vector3(0.32, 0.12, 0.32)
	var a := Vector3(rng.randf_range(lo.x, hi.x), lo.y, rng.randf_range(lo.z, hi.z))
	var z := Vector3(rng.randf_range(lo.x, hi.x), hi.y, rng.randf_range(lo.z, hi.z))
	if rng.randf() < 0.5:
		var s := a
		a = z
		z = s
	var segs := []   # [p0, p1, half-width, brightness]
	coarse = []
	_bolt(a, z, b.size.y * 0.22, 7, segs, 1.0, 0.012 * b.size.y + 0.004, b.position + b.size * Vector3(0.18, 0.06, 0.18), b.end - b.size * Vector3(0.18, 0.08, 0.18))
	_build(segs, coarse)

## midpoint displacement: split the line, push the middle sideways, recurse; fork now and then
func _bolt(p0: Vector3, p1: Vector3, disp: float, depth: int, segs: Array, bright: float, w: float, lo: Vector3, hi: Vector3) -> void:
	if depth == 3:
		coarse.append([p0, p1, w * 9.0, bright * 0.8])
	if depth == 0:
		segs.append([p0, p1, w, bright])
		return
	var d := p1 - p0
	var perp := d.cross(Vector3(rng.randf() - 0.5, rng.randf() - 0.5, rng.randf() - 0.5)).normalized()
	var m := (p0 + p1) * 0.5 + perp * rng.randf_range(-disp, disp)
	m = m.clamp(lo, hi)
	_bolt(p0, m, disp * 0.5, depth - 1, segs, bright, w, lo, hi)
	_bolt(m, p1, disp * 0.5, depth - 1, segs, bright, w, lo, hi)
	if depth >= 2 and rng.randf() < 0.3 and bright > 0.2:
		var bd := (d.normalized() + perp * rng.randf_range(0.6, 1.4)).normalized()
		var end := (m + bd * d.length() * rng.randf_range(0.3, 0.6)).clamp(lo, hi)
		_bolt(m, end, disp * 0.45, depth - 2, segs, bright * 0.5, w * 0.55, lo, hi)

func _build(segs: Array, halo: Array) -> void:
	var v := PackedVector3Array()
	var nrm := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var cl := PackedColorArray()
	var idx := PackedInt32Array()
	var all := []
	for s in halo: all.append([s, 0.0])
	for s in segs: all.append([s, 1.0])
	for item in all:
		var s: Array = item[0]
		var kind: float = item[1]
		var p0: Vector3 = s[0]
		var p1: Vector3 = s[1]
		var w: float = s[2]
		var br: float = s[3]
		var dir := (p1 - p0).normalized()
		var o := v.size()
		# a little past each end so joints overlap smoothly
		var e0 := p0
		var e1 := p1
		for p in [e0, e0, e1, e1]:
			v.append(p)
			nrm.append(dir)
			uv2.append(Vector2(w * (1.0 if kind > 0.5 else 1.0), 0))
			cl.append(Color(kind, 1, 1, br))
		uv.append_array([Vector2(-1, 0), Vector2(1, 0), Vector2(-1, 1), Vector2(1, 1)])
		idx.append_array([o, o + 2, o + 1, o + 1, o + 2, o + 3])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = nrm
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_TEX_UV2] = uv2
	arr[Mesh.ARRAY_COLOR] = cl
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	mesh = m
