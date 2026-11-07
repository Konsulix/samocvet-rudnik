extends Node3D
## The little trees of SpecSkull close up, each crown kind: godot --path godot res://tests/tree_view.tscn -- shot=user://tv.png

func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.08, 0.07, 0.1)
	env.environment.ambient_light_color = Color(0.45, 0.45, 0.5)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.8, 0.6, 0)
	add_child(sun)
	var kinds := ["leaves", "blossom", "autumn", "moss"]
	for k in kinds.size():
		var r := Rng32.new(11 + k)
		var h := Node3D.new()
		add_child(h)
		h.position = Vector3((k - 1.5) * 0.7, 0, 0)
		SpecSkull._tree(h, r, Vector3.ZERO, Vector3.UP, Color(0.6, 1.0, 0.4), kinds[k])
	var cam := Camera3D.new()
	add_child(cam)
	var cx := float(args.get("cx", "0"))
	var cd := float(args.get("cd", "1.6"))
	cam.look_at_from_position(Vector3(cx, 0.45, cd), Vector3(cx, 0.35, 0))
	cam.fov = 50
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(String(args.get("shot", "user://tv.png")))
	get_tree().quit()
