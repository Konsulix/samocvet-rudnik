class_name SpecStudio
extends RefCounted
## The dark photo studio the specimens are shown in, built inside a SubViewport:
## softbox reflections (from the sky shader), a warm key light with soft shadows, a cold and a warm rim,
## a faint fill from below, and a coloured haze behind the stone. Same rig as the prototype's specInit().

const SKY := preload("res://shaders/studio_sky.gdshader")

var vp: SubViewport
var cam: Camera3D
var sky_mat: ShaderMaterial
var stage: Node3D

static func make(size: int, msaa := Viewport.MSAA_4X) -> SpecStudio:
	var s := SpecStudio.new()
	s._build(size, msaa)
	return s

func _build(size: int, msaa: Viewport.MSAA) -> void:
	vp = SubViewport.new()
	vp.size = Vector2i(size, size)
	vp.own_world_3d = true
	vp.msaa_3d = msaa
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var env := Environment.new()
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = SKY
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	sky.process_mode = Sky.PROCESS_MODE_QUALITY
	env.sky = sky
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
	return l

## the coloured haze behind the stone, in the stone's own colour
func set_glow(c: Color) -> void:
	sky_mat.set_shader_parameter("haze", Vector3(c.r, c.g, c.b) * 0.17)

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
	return pivot

func show(o: Dictionary) -> Node3D:
	clear()
	var p := seat(SpecimenBuilder.build(o))
	stage.add_child(p)
	set_glow(p.get_meta("glow"))
	return p

func clear() -> void:
	for c in stage.get_children():
		stage.remove_child(c)
		c.queue_free()
