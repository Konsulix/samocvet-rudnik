extends Node3D
## the feather coat (bone.gdshader skin 9) on a beast's bare skull, every bird side by side, and a close-up
## -- shot=user://fe.png [beast=fox] [yaw=0.6] [close=1]
func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.06, 0.05, 0.06)
	env.environment.ambient_light_color = Color(0.45, 0.45, 0.5)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(env)
	var key := DirectionalLight3D.new()
	key.light_color = Color("#fff0dc")
	key.light_energy = 1.45
	add_child(key)
	key.look_at_from_position(Vector3(2.5, 3.5, 3), Vector3.ZERO)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color("#8fb8ff")
	rim.light_energy = 1.4
	add_child(rim)
	rim.look_at_from_position(Vector3(-3.5, 1.5, -2.5), Vector3.ZERO)
	var bd := SpecSkull.body(String(args.get("beast", "fox")))
	var g: Geo = bd.cranium
	var bb := g.aabb()
	var close := args.has("close")
	var n := 1 if close else 5
	for i in n:
		var mi := MeshInstance3D.new()
		mi.mesh = g.to_mesh()
		var m := ShaderMaterial.new()
		m.shader = SpecSkull.BONE
		m.set_shader_parameter("skin", 9)
		m.set_shader_parameter("skin_k", 0.8)
		m.set_shader_parameter("feather_pal", int(args.get("pal", "0")) if close else i)
		mi.material_override = m
		var h := Node3D.new()
		add_child(h)
		h.add_child(mi)
		var sz := maxf(bb.size.x, maxf(bb.size.y, bb.size.z))
		mi.position = -bb.get_center()
		h.scale = Vector3.ONE * ((3.6 if close else 1.7) / sz)
		h.rotation = Vector3(0.25, float(args.get("yaw", "0.6")) - 0.9, 0)
		h.position = Vector3(0, 0, 0) if close else Vector3((i % 3) * 2.0 - 2.0, 1.0 - (i / 3) * 2.0, 0)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 4.2
	cam.position = Vector3(0, 0, 10)
	add_child(cam)
	for k in 3: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(String(args.get("shot", "user://fe.png")))
	get_tree().quit()
