class_name SpecStudio
extends RefCounted
## The dark photo studio the specimens are shown in, built inside a SubViewport:
## softbox reflections (from the sky shader), a warm key light with soft shadows, a cold and a warm rim,
## a faint fill from below, and a coloured haze behind the stone. Same rig as the prototype's specInit().

const SKY := preload("res://shaders/studio_sky.gdshader")
const HDRI := preload("res://assets/hdri/studio_small_09_1k.hdr")

var vp: SubViewport
var cam: Camera3D
var stage: Node3D
var _haze: ShaderMaterial
var _haze_c := Vector3.ZERO
var env: Environment
var _lights: Array[DirectionalLight3D] = []
var _uv := 0.0

## One sky for every studio, never changed after it is made: its filtered reflections (radiance) are
## computed once. Changing a sky uniform per stone used to redo them on every specimen, a visible hitch.
static var _sky: Sky

const HAZE := "shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, shadows_disabled, depth_draw_never;
uniform vec3 haze = vec3(0.0);
void fragment() {
	float h = length(SCREEN_UV - vec2(0.5)) / 0.62;
	float g = h < 0.4 ? mix(1.0, 0.35, h / 0.4) : mix(0.35, 0.0, clamp((h - 0.4) / 0.6, 0.0, 1.0));
	ALBEDO = haze * g;
}
"
static var _haze_shader: Shader

static func _shared_sky() -> Sky:
	if not _sky:
		var sm := ShaderMaterial.new()
		sm.shader = SKY
		sm.set_shader_parameter("hdri", HDRI)
		sm.set_shader_parameter("hdri_k", 1.0)
		sm.set_shader_parameter("haze_k", 0.0)
		_sky = Sky.new()
		_sky.sky_material = sm
		_sky.radiance_size = Sky.RADIANCE_SIZE_128
		_sky.process_mode = Sky.PROCESS_MODE_QUALITY
	return _sky

## transparent: no studio backdrop, the object floats over whatever the screen draws behind it
static func make(size: int, msaa := Viewport.MSAA_4X, transparent := false) -> SpecStudio:
	var s := SpecStudio.new()
	s._build(size, msaa, transparent)
	return s

func _build(size: int, msaa: Viewport.MSAA, transparent: bool) -> void:
	vp = SubViewport.new()
	vp.size = Vector2i(size, size)
	vp.own_world_3d = true
	vp.msaa_3d = msaa
	vp.transparent_bg = transparent
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	env = Environment.new()
	env.sky = _shared_sky()
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.45
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	cam = Camera3D.new()
	cam.fov = 28
	cam.near = 0.1
	cam.far = 50
	cam.environment = env
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(0, 0.3, 6.6), Vector3.ZERO)
	# the coloured haze behind the stone: a far additive card on the camera, not part of the sky
	if not transparent:
		if not _haze_shader:
			_haze_shader = Shader.new()
			_haze_shader.code = HAZE
		_haze = ShaderMaterial.new()
		_haze.shader = _haze_shader
		var card := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(80, 80)
		card.mesh = q
		card.material_override = _haze
		card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		card.position = Vector3(0, 0, -40)
		cam.add_child(card)
	var key := _light(Color("#fff0dc"), 1.45, Vector3(2.5, 3.5, 3))
	key.shadow_enabled = true
	key.shadow_bias = 0.03
	key.shadow_normal_bias = 1.0
	key.shadow_blur = 2.0
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	key.directional_shadow_max_distance = 12.0
	# two rims, cold and warm, cut the silhouette out of the dark
	_light(Color("#8fb8ff"), 1.4, Vector3(-3.5, 1.5, -2.5))
	_light(Color("#ffc890"), 0.9, Vector3(3.5, 0.4, -3))
	_light(Color(1, 1, 1), 0.25, Vector3(0, -2, 4))
	stage = Node3D.new()
	vp.add_child(stage)
	set_glow(Color(0.2, 0.27, 0.33))

func _light(c: Color, e: float, at: Vector3) -> DirectionalLight3D:
	var l := DirectionalLight3D.new()
	l.light_color = c
	l.light_energy = e
	vp.add_child(l)
	l.look_at_from_position(at, Vector3.ZERO)
	l.set_meta("e", e)
	_lights.append(l)
	return l

## the coloured haze behind the stone, in the stone's own colour
func set_glow(c: Color) -> void:
	_haze_c = Vector3(c.r, c.g, c.b) * 0.17
	if _haze:
		_haze.set_shader_parameter("haze", _haze_c * (1.0 - _uv * 0.85))

## dark (0..1): the room lights go out — lamps, ambient light, reflections and the haze fade,
## and the bloom opens up so whatever glows gets a halo. Ultraviolet goes all the way, a star heart part way.
func set_uv(k: float) -> void:
	if is_equal_approx(k, _uv):
		return
	_uv = k
	for l in _lights:
		l.light_energy = float(l.get_meta("e")) * (1.0 - k * 0.9)
	env.ambient_light_energy = 0.45 * (1.0 - k * 0.85)
	env.background_energy_multiplier = 1.0 - k * 0.85
	env.glow_intensity = 0.55 + k * 1.6
	env.glow_hdr_threshold = 1.0 - k * 0.65
	env.glow_bloom = k * 0.3
	if _haze:
		_haze.set_shader_parameter("haze", _haze_c * (1.0 - k * 0.85))

## centre the specimen in the void, inside a pivot that we turn
static func seat(g: Node3D) -> Node3D:
	var base_xf := g.transform
	var b := base_xf * SpecUtil.box_of(g)
	var sz := b.size
	var s := minf(2.5 / maxf(0.01, sz.y), 2.35 / maxf(0.01, maxf(sz.x, sz.z)))
	g.transform = Transform3D(base_xf.basis.scaled(Vector3.ONE * s), base_xf.origin * s)
	var c := (g.transform * SpecUtil.box_of(g)).get_center()
	g.position -= c
	var pivot := Node3D.new()
	pivot.add_child(g)
	pivot.set_meta("glow", g.get_meta("glow", Color(0.2, 0.27, 0.33)))
	if g.has_meta("anim"):
		pivot.set_meta("anim", g.get_meta("anim"))
	for k in ["fluor", "heart_light"]:
		if g.has_meta(k):
			pivot.set_meta(k, g.get_meta(k))
	return pivot

func show(o: Dictionary) -> Node3D:
	clear()
	var p := seat(SpecimenBuilder.build(o))
	stage.add_child(p)
	set_glow(p.get_meta("glow"))
	return p

static var _build_lock := Mutex.new()

## build a specimen on a worker thread so the screen keeps moving; await it from the main thread
static func build_async(o: Dictionary) -> Node3D:
	var out := [null]
	var id := WorkerThreadPool.add_task(func():
		_build_lock.lock()
		out[0] = seat(SpecimenBuilder.build(o))
		_build_lock.unlock())
	var tree := Engine.get_main_loop() as SceneTree
	while not WorkerThreadPool.is_task_completed(id):
		await tree.process_frame
	WorkerThreadPool.wait_for_task_completion(id)
	return out[0]

func show_async(o: Dictionary) -> Node3D:
	var p: Node3D = await build_async(o)
	if not is_instance_valid(stage):
		p.free()
		return null
	clear()
	stage.add_child(p)
	set_glow(p.get_meta("glow"))
	return p

func clear() -> void:
	for c in stage.get_children():
		stage.remove_child(c)
		c.queue_free()
