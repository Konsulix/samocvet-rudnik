class_name SpecBolt
extends MeshInstance3D
## Lightning trapped in a crystal. The main bolt is grown deep inside by midpoint displacement
## (a jagged channel with forking branches); short arcs crackle over the crystal's surface.
## Every channel is a camera-facing ribbon textured with real ragged discharge filaments
## (OpenGameArt "lightnings" by hdst, CC0) that jump to new filaments a dozen times a second,
## so the core is never a clean line: it frays, breaks and flickers. Strike, flicker, afterglow,
## new path; each flash lights the crystal from inside.

const STRANDS := preload("res://assets/fx/lightning_strands.png")

const SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_test_disabled, depth_draw_never;
uniform sampler2D strands : filter_linear_mipmap, repeat_enable;
uniform vec3 glow_col = vec3(0.35, 0.6, 2.2);
uniform float flash = 1.0;
uniform float fps = 14.0;
float hash(float n) { return fract(sin(n * 12.9898) * 43758.5453); }
void vertex() {
	// UV.x: -1..1 across; UV.y: distance along the branch; UV2.x: half-width; NORMAL: segment direction
	vec3 dir = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 pv = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 side = normalize(cross(dir, normalize(-pv)));
	pv += side * UV.x * UV2.x;
	POSITION = PROJECTION_MATRIX * vec4(pv, 1.0);
}
void fragment() {
	float x = UV.x;
	float a = COLOR.a * flash;
	// COLOR.g: which branch; each branch picks a fresh filament every frame
	float frame = floor(TIME * fps);
	float pick = floor(hash(COLOR.g * 91.7 + frame * 3.1) * 16.0);
	float off = hash(COLOR.g * 13.3 + frame * 7.7);
	// the core: overexposed white, its thickness flickering along the channel; a violet-blue glow round it
	float wob = 0.65 + 0.35 * sin(UV.y * 9.0 + COLOR.g * 40.0 + frame * 1.7) * sin(UV.y * 23.0 + frame);
	// filament texture (CC0) breaks the core into strands and leaves ragged edges on the glow
	float fil = texture(strands, vec2((pick + 0.5 + x * 0.25) / 16.0, UV.y * 0.3 + off)).a;
	float edge = 1.0 - smoothstep(0.8, 1.0, abs(x));
	vec3 c;
	if (COLOR.r > 0.5) {
		float core = exp(-x * x / (0.012 * wob));
		c = vec3(5.0, 5.2, 6.0) * core * (0.75 + 0.5 * fil)
			+ glow_col * 1.4 * exp(-x * x * 9.0) * (0.6 + 0.6 * fil)
			+ glow_col * 0.5 * exp(-abs(x) * 3.5);
	} else {
		c = glow_col * 0.45 * pow(1.0 - abs(x), 3.0) * (0.7 + 0.5 * fil);
	}
	c *= edge;
	ALBEDO = c * a;
}
"""

var bounds := AABB()
var col := Color(0.35, 0.6, 2.2)
var rng := RandomNumberGenerator.new()
var light: OmniLight3D
var arcs: MeshInstance3D
var surface := PackedVector3Array()
var _t := 0.0
var _next := 0.0
var _arc_t := 0.0
var _mat: ShaderMaterial
var _arc_mat: ShaderMaterial
var glass: ShaderMaterial
var sparks: CPUParticles3D
var fizz: CPUParticles3D

func setup(bb: AABB, seed_v: int, glow: Color, surf := PackedVector3Array()) -> SpecBolt:
	bounds = bb
	col = glow
	surface = surf
	rng.seed = seed_v
	_mat = ShaderMaterial.new()
	_mat.shader = ShaderFiles.get_shader("bolt", SHADER)
	_mat.set_shader_parameter("strands", STRANDS)
	_mat.set_shader_parameter("glow_col", Vector3(col.r, col.g, col.b))
	_mat.render_priority = 100
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 4.0
	arcs = MeshInstance3D.new()
	_arc_mat = _mat.duplicate() as ShaderMaterial
	_arc_mat.set_shader_parameter("fps", 20.0)
	arcs.material_override = _arc_mat
	arcs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arcs.extra_cull_margin = 4.0
	add_child(arcs)
	light = OmniLight3D.new()
	light.light_color = Color(0.6, 0.75, 1.0)
	light.omni_range = bb.size.length() * 1.6
	light.position = bb.get_center()
	add_child(light)
	# sparks: a burst flying off with every strike, and a constant faint crackle around
	sparks = _spark_emitter(40, 0.5, 0.9, true)
	fizz = _spark_emitter(16, 0.7, 0.35, false)
	_strike()
	_crackle()
	return self

func _spark_emitter(n: int, life: float, speed: float, burst: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = n
	p.lifetime = life
	p.one_shot = burst
	p.explosiveness = 0.9 if burst else 0.0
	p.emitting = not burst
	if surface.size():
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINTS
		p.emission_points = surface
	else:
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		p.emission_box_extents = bounds.size * 0.4
	p.direction = Vector3.UP
	p.spread = 180
	p.gravity = Vector3(0, -0.6, 0)
	p.initial_velocity_min = speed * bounds.size.y * 0.4
	p.initial_velocity_max = speed * bounds.size.y
	p.damping_min = 1.0
	p.damping_max = 2.0
	p.scale_amount_min = 0.012 * bounds.size.y
	p.scale_amount_max = 0.028 * bounds.size.y
	p.local_coords = true
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	var m := SphereMesh.new()
	m.radius = 0.5
	m.height = 1.0
	m.radial_segments = 6
	m.rings = 3
	m.material = SpecLegend.glow_mat(Color(1.6, 2.2, 5.0))
	p.mesh = m
	add_child(p)
	return p

func _process(dt: float) -> void:
	_t += dt
	_arc_t += dt
	if _t >= _next:
		_strike()
	if _arc_t >= 0.09 + rng.randf() * 0.15:
		_crackle()
	# a strike: bright, a couple of flickers, then an afterglow that dies away
	var k := _t / maxf(0.001, _next)
	var f := 0.0
	if _t < 0.06: f = 1.0
	elif _t < 0.1: f = 0.25
	elif _t < 0.16: f = 0.95
	else: f = 0.3 + 0.5 * exp(-(_t - 0.16) * 3.0)
	f *= 1.0 - smoothstep(0.88, 1.0, k) * 0.7
	_mat.set_shader_parameter("flash", f)
	_arc_mat.set_shader_parameter("flash", 0.35 + f * 0.65)
	light.light_energy = f * 3.0
	# the storm lights the crystal's own body with each flash
	if glass:
		glass.set_shader_parameter("emis", Vector3(col.r, col.g, col.b) * (0.015 + f * 0.1))

## the main bolt, deep inside, top to bottom or bottom to top
func _strike() -> void:
	_t = 0.0
	_next = 0.8 + rng.randf() * 1.6
	var b := bounds
	var lo := b.position + b.size * Vector3(0.3, 0.1, 0.3)
	var hi := b.end - b.size * Vector3(0.3, 0.22, 0.3)
	var a := Vector3(rng.randf_range(lo.x, hi.x), lo.y, rng.randf_range(lo.z, hi.z))
	var z := Vector3(rng.randf_range(lo.x, hi.x), hi.y, rng.randf_range(lo.z, hi.z))
	if rng.randf() < 0.5:
		var s := a
		a = z
		z = s
	var segs := []
	var halo := []
	var wl := b.position + b.size * Vector3(0.22, 0.06, 0.22)
	var wh := b.end - b.size * Vector3(0.22, 0.12, 0.22)
	_bolt(a, z, b.size.y * 0.22, 7, segs, halo, 1.0, 0.05 * b.size.y + 0.012, wl, wh, rng.randf())
	# now and then the discharge leaps out of the crystal into the air around it
	if surface.size() and rng.randf() < 0.65:
		var big := AABB(b.position - b.size * 1.2, b.size * 3.4)
		for k in 1 + rng.randi() % 2:
			var p0 := surface[rng.randi() % surface.size()]
			var c := b.get_center()
			var out := (p0 - Vector3(c.x, b.position.y, c.z)).normalized()
			out = (out + Vector3(rng.randf() - 0.5, rng.randf() * 0.6, rng.randf() - 0.5) * 0.8).normalized()
			var p1 := p0 + out * b.size.y * rng.randf_range(0.45, 0.8)
			_bolt(p0, p1, p0.distance_to(p1) * 0.22, 6, segs, halo, 0.85, 0.035 * b.size.y + 0.008, big.position, big.end, rng.randf())
	mesh = _build(segs, halo)
	if sparks:
		sparks.restart()

## arcs crackling over the outside: short jagged sparks between nearby points of the surface
func _crackle() -> void:
	_arc_t = 0.0
	if surface.size() < 4:
		arcs.mesh = null
		return
	var segs := []
	var c := bounds.get_center()
	for k in 2 + rng.randi() % 4:
		var p0 := surface[rng.randi() % surface.size()]
		var p1 := p0
		for t in 12:
			var q := surface[rng.randi() % surface.size()]
			var d := q.distance_to(p0)
			if d > bounds.size.y * 0.08 and d < bounds.size.y * 0.3:
				p1 = q
				break
		if p1 == p0:
			continue
		# bow the arc outward, away from the crystal
		var mid := (p0 + p1) * 0.5
		var out := (mid - Vector3(c.x, mid.y, c.z)).normalized()
		var m := mid + out * p0.distance_to(p1) * 0.35
		var br := rng.randf()
		var w := 0.02 * bounds.size.y + 0.006
		var big := AABB(bounds.position - bounds.size, bounds.size * 3.0)
		_bolt(p0, m, p0.distance_to(m) * 0.3, 4, segs, [], 0.6, w, big.position, big.end, br)
		_bolt(m, p1, p0.distance_to(m) * 0.3, 4, segs, [], 0.6, w, big.position, big.end, br)
	arcs.mesh = _build(segs, []) if segs.size() else null

## midpoint displacement: split the line, push the middle sideways, recurse; fork now and then.
## segs entries: [p0, p1, half-width, brightness, branch id]
func _bolt(p0: Vector3, p1: Vector3, disp: float, depth: int, segs: Array, halo: Array, bright: float, w: float, lo: Vector3, hi: Vector3, br: float) -> void:
	if depth == 3:
		halo.append([p0, p1, w * 2.6, bright * 0.7, br])
	if depth == 0:
		segs.append([p0, p1, w, bright, br])
		return
	var d := p1 - p0
	var perp := d.cross(Vector3(rng.randf() - 0.5, rng.randf() - 0.5, rng.randf() - 0.5)).normalized()
	var m := ((p0 + p1) * 0.5 + perp * rng.randf_range(-disp, disp)).clamp(lo, hi)
	_bolt(p0, m, disp * 0.5, depth - 1, segs, halo, bright, w, lo, hi, br)
	_bolt(m, p1, disp * 0.5, depth - 1, segs, halo, bright, w, lo, hi, br)
	if depth >= 2 and rng.randf() < 0.35 and bright > 0.2:
		var bd := (d.normalized() + perp * rng.randf_range(0.6, 1.4)).normalized()
		var end := (m + bd * d.length() * rng.randf_range(0.4, 0.8)).clamp(lo, hi)
		_bolt(m, end, disp * 0.5, depth - 1, segs, halo, bright * 0.55, w * 0.6, lo, hi, rng.randf())

func _build(segs: Array, halo: Array) -> ArrayMesh:
	var v := PackedVector3Array()
	var nrm := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var cl := PackedColorArray()
	var idx := PackedInt32Array()
	var all := []
	for s in halo: all.append([s, 0.0])
	for s in segs: all.append([s, 1.0])
	var run := 0.0
	var last := Vector3(INF, INF, INF)
	for item in all:
		var s: Array = item[0]
		var kind: float = item[1]
		var p0: Vector3 = s[0]
		var p1: Vector3 = s[1]
		var w: float = s[2]
		var bright: float = s[3]
		var br: float = s[4]
		# the texture runs on continuously along a branch
		if p0.distance_squared_to(last) > 1e-10: run = 0.0
		var len := p0.distance_to(p1)
		var v0 := run / maxf(0.01, bounds.size.y * 0.25)
		run += len
		var v1 := run / maxf(0.01, bounds.size.y * 0.25)
		last = p1
		var dir := (p1 - p0).normalized()
		var o := v.size()
		for p in [p0, p0, p1, p1]:
			v.append(p)
			nrm.append(dir)
			uv2.append(Vector2(w, 0))
		cl.append_array([Color(kind, br, 0.0, bright), Color(kind, br, 0.0, bright), Color(kind, br, 1.0, bright), Color(kind, br, 1.0, bright)])
		uv.append_array([Vector2(-1, v0), Vector2(1, v0), Vector2(-1, v1), Vector2(1, v1)])
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
	return m
