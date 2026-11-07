extends Node3D
## Every kind of SpecButterfly side by side, seen from above and in front, for checking the wings:
##   godot --path godot --resolution 1600x400 res://tests/butterfly_view.tscn -- shot=user://bf.png [t=1.5]

func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var w := Node3D.new()
	add_child(w)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.08, 0.07, 0.1)
	env.environment.ambient_light_color = Color(0.5, 0.5, 0.55)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	w.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.5, 0)
	w.add_child(sun)
	var rng := Rng32.new(7)
	var ids: Array = SpecButterfly.KINDS.keys()
	var n := ids.size()
	for k in n:
		var b := SpecButterfly.put(w, rng, ids[k], Vector3((k - (n - 1) * 0.5) * 1.05, 0, 0), Vector3.UP, 1.0, false)
		b.set_process(false)
		b.rotation.y = PI * 0.5
		(b.mat as ShaderMaterial).set_shader_parameter("ang", float(args.get("ang", "0.05")))
	var cam := Camera3D.new()
	w.add_child(cam)
	cam.look_at_from_position(Vector3(float(args.get("cx", "0")), float(args.get("cy", "4.2")), float(args.get("cz", "0.4"))), Vector3(float(args.get("tx", "0")), 0, 0))
	cam.fov = float(args.get("fov", "60"))
	await get_tree().create_timer(float(args.get("t", "1.5"))).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(String(args.get("shot", "user://bf.png")))
	get_tree().quit()
