extends Node3D
## Every kind of butterfly (SpecButterfly.KINDS) up close: sitting (top row), and held at three moments of its stroke —
## wings up, level, down (the rows below).
##   godot --path godot --resolution 1600x1000 res://tests/butterfly_view.tscn -- shot=user://bf.png
func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.1, 0.1, 0.13)
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.72)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-1.0, 0.4, 0)
	add_child(sun)
	var ids: Array = SpecButterfly.KINDS.keys()
	var held := []
	for i in ids.size():
		for row in 4:
			var hold := Node3D.new()
			hold.position = Vector3(i * 1.25 - (ids.size() - 1) * 0.625, 1.9 - row * 1.25, 0)
			hold.rotation = Vector3(0.55, 0.6, 0)
			hold.set_meta("grown", {})
			add_child(hold)
			var fb: SpecButterfly.Fly = SpecButterfly.put(hold, Rng32.new(7 + i), String(ids[i]), Vector3.ZERO, Vector3.UP, 1.0 / float(SpecButterfly.KINDS[ids[i]].span), false, [[Vector3.ZERO, Vector3.UP]])
			if row > 0: held.append([fb, [1.5, 0.3, -0.5][row - 1]])
		var l := Label3D.new()
		l.text = String(ids[i])
		l.font_size = 36
		l.position = Vector3(i * 1.25 - (ids.size() - 1) * 0.625, 2.75, 1)
		add_child(l)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 6.4
	cam.position = Vector3(0, 0.1, 20)
	add_child(cam)
	await get_tree().create_timer(float(args.get("t", "1.0"))).timeout
	for h: Array in held:
		var fb: SpecButterfly.Fly = h[0]
		fb.set_process(false)
		if fb.full:
			fb._m_play("fly", 0.0, 0.0, 0.0)
			fb.ap.seek([0.0, 0.03, 0.05][[1.5, 0.3, -0.5].find(h[1])], true)
		else:
			fb._m_play("fly", 0.0, 0.0, 0.0)
			fb.last_a = 9.0
			fb._wings(float(fb.st.dn) + (float(fb.st.up) - float(fb.st.dn)) * [1.0, 0.45, 0.0][[1.5, 0.3, -0.5].find(h[1])], 0.0)
	for k in 3: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(String(args.get("shot", "user://bf.png")))
	get_tree().quit()
