class_name Board3D
extends SubViewportContainer
## The 3D layer of the board: a transparent viewport over the tray, an orthographic camera looking
## straight down, the stones as faceted 3D gems lit by the specimens' studio. One cell is one unit;
## board pixel (x, y) is world (x / TS, 0, y / TS), so the 2D nodes that run the animations simply
## carry their 3D stones along (see GemNode).

const SKY := preload("res://shaders/studio_sky.gdshader")
const GEM_SHADER := preload("res://shaders/board_gem.gdshader")
const SS := 2.0   # supersampling for crisp edges

var vp: SubViewport
var cam: Camera3D
var root: Node3D
var TS := 46.0
var _mats := {}

func _init() -> void:
	stretch = true
	stretch_shrink = 1
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var env := Environment.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = SKY
	sky_mat.set_shader_parameter("hdri", load("res://assets/hdri/studio_small_09_1k.hdr"))
	sky_mat.set_shader_parameter("hdri_k", 1.0)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	env.sky = sky
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.25
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.95
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.near = 0.1
	cam.far = 40.0
	cam.environment = env
	vp.add_child(cam)
	# lamplight from the upper left, casting short soft shadows onto the tray
	var key := DirectionalLight3D.new()
	key.light_color = Color("#ffe6c4")
	key.light_energy = 1.3
	key.shadow_enabled = true
	key.shadow_blur = 2.0
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	key.directional_shadow_max_distance = 30.0
	vp.add_child(key)
	key.look_at_from_position(Vector3(-3, 10, -4), Vector3.ZERO)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color("#9fc0ff")
	rim.light_energy = 0.5
	vp.add_child(rim)
	rim.look_at_from_position(Vector3(4, 3, 5), Vector3.ZERO)
	root = Node3D.new()
	vp.add_child(root)
	# an invisible floor that only shows the stones' shadows
	var catcher := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	catcher.mesh = pm
	var cm := ShaderMaterial.new()
	var cs := Shader.new()
	cs.code = "shader_type spatial;\nrender_mode shadow_to_opacity, unshaded;\nvoid fragment(){ ALBEDO = vec3(0.0); ALPHA = 0.0; }\n"
	cm.shader = cs
	catcher.material_override = cm
	catcher.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	vp.add_child(catcher)

## match the 2D board: `px` its size in pixels, `ts` the cell size
func layout(px: Vector2, ts: float) -> void:
	TS = ts
	size = px
	vp.size = Vector2i(px * SS)
	stretch_shrink = 1
	cam.size = px.y / TS
	var c := Vector3(px.x / TS * 0.5, 10.0, px.y / TS * 0.5)
	cam.look_at_from_position(c, Vector3(c.x, 0, c.z), Vector3(0, 0, -1))

func to_world(p: Vector2, lift := 0.0) -> Vector3:
	return Vector3(p.x / TS, lift, p.y / TS)

func gem_material(t: int) -> ShaderMaterial:
	if _mats.has(t):
		return _mats[t]
	var g: Dictionary = Data.GEMS[t]
	var m := ShaderMaterial.new()
	m.shader = GEM_SHADER
	var lin := func(s: String) -> Vector3:
		var c := Color.html(s).srgb_to_linear()
		return Vector3(c.r, c.g, c.b)
	m.set_shader_parameter("col_c", lin.call(g.c))
	m.set_shader_parameter("col_d", lin.call(g.d))
	m.set_shader_parameter("col_l", lin.call(g.l))
	m.set_shader_parameter("milky", 1.0 if g.shape == "hex" else 0.0)
	_mats[t] = m
	return m

# ---------------------------------------------------------------- blockers

var _blocks := {}     # Vector2i -> [key, node]
var _block_mats := {}

## rock (1: soft sandstone, 2: hard dark basalt) and mud, kept in step with the model; cheap when nothing changed
func set_block(r: int, c: int, rock: int, mud: int, centre: Vector2) -> void:
	var cell := Vector2i(r, c)
	var key := rock * 10 + mud
	var cur: Array = _blocks.get(cell, [0, null])
	if cur[0] == key:
		return
	if cur[1]:
		var old: Node3D = cur[1]
		_crumble_away(old)
	var node: Node3D = null
	if rock: node = _rock(rock, r * 31 + c * 7)
	elif mud: node = _mud(r * 17 + c * 5)
	if node:
		node.position = to_world(centre)
		root.add_child(node)
	_blocks[cell] = [key, node]

func _crumble_away(n: Node3D) -> void:
	var tw := n.create_tween().set_parallel(true)
	tw.tween_property(n, "scale", Vector3(1.15, 0.2, 1.15), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(n, "transparency", 1.0, 0.18)
	tw.chain().tween_callback(n.queue_free)

func _block_mat(kind: String) -> ShaderMaterial:
	if _block_mats.has(kind):
		return _block_mats[kind]
	var m: ShaderMaterial
	match kind:
		"rock1":
			m = SpecMat.make({col = Color(1, 1, 1), rough = 0.9, grain = 0.3, ao = 1.0, flat = true,
				dirt = {h = 99.0, a = 0.3, col = SpecMat.lin(0x5e4c38), fr = 0.0, scan = 0}})
		"rock2":
			m = SpecMat.make({col = Color(1, 1, 1), rough = 0.7, grain = 0.3, ao = 1.0, flat = true,
				dirt = {h = 99.0, a = 0.3, col = SpecMat.lin(0x3a3e46), fr = 0.0, scan = 2}})
		_:
			# wet mud: dark, glossy, a little lumpy
			m = SpecMat.make({col = SpecMat.lin(0x3a2616), rough = 0.22, coat = 1.0, coat_r = 0.1, grain = 0.5, ao = 1.0})
	_block_mats[kind] = m
	return m

## a cell of rubble: a few angular boulders packed into it, each with its own scan relief and shading
func _rock(hp: int, seed_v: int) -> Node3D:
	var node := Node3D.new()
	var rng := Rng32.new(seed_v * 7 + hp)
	var n := 3 if hp == 1 else 2
	var spots := [[Vector2(-0.2, -0.18), 0.27], [Vector2(0.2, -0.12), 0.25], [Vector2(-0.05, 0.22), 0.28]] if n == 3 else [[Vector2(-0.14, -0.1), 0.34], [Vector2(0.18, 0.16), 0.3]]
	for k in n:
		var sp: Array = spots[k]
		var r: float = sp[1] * (0.95 + rng.next() * 0.15)
		var g := Geo.icosa(1.0, 1)
		g.jitter(0.22, 1.6, int(rng.next() * 100000))
		g.scale(r * (1.0 + rng.next() * 0.3), r * (0.75 if hp == 1 else 0.9), r * (1.0 + rng.next() * 0.3))
		# flat cut faces here and there, so they read as broken stone
		var cut := Vector3(rng.next() - 0.5, rng.next() * 0.5 + 0.3, rng.next() - 0.5).normalized()
		for i in g.v.size():
			var d := g.v[i].dot(cut) - r * 0.55
			if d > 0.0: g.v[i] -= cut * d
		g.col.resize(g.v.size())
		var fn := FastNoiseLite.new()
		fn.seed = int(rng.next() * 100000)
		fn.frequency = 6.0
		for i in g.v.size():
			var k2 := clampf(0.8 + fn.get_noise_3dv(g.v[i]) * 0.5, 0.35, 1.0) * (0.5 if hp == 1 else 0.8)
			g.col[i] = Color(k2, k2, k2)
		g.rp = g.v.duplicate()
		for i in g.rp.size():
			g.rp[i] = g.rp[i] * 1.6 + Vector3(seed_v * 0.37 + k, 0, seed_v * 0.11)
		var mi := MeshInstance3D.new()
		mi.mesh = g.to_mesh()
		mi.material_override = _block_mat("rock%d" % hp)
		var off: Vector2 = sp[0]
		mi.position = Vector3(off.x, r * 0.5, off.y)
		mi.rotation.y = rng.next() * TAU
		node.add_child(mi)
	return node

func _mud(seed_v: int) -> MeshInstance3D:
	var g := Geo.box(0.94, 0.08, 0.94).translate(0, 0.0, 0)
	g.subdivide(3)
	g.jitter(0.025, 5.0, seed_v)
	var mi := MeshInstance3D.new()
	mi.mesh = g.to_mesh()
	mi.material_override = _block_mat("mud")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

func make_stone(t: int) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = GemCut.mesh(Data.GEMS[t].shape)
	mi.material_override = gem_material(t)
	root.add_child(mi)
	return mi
