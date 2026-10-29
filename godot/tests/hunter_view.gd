extends Node3D
## Anomalocaris alone, side on and from above, for comparing with its reconstructions:
## `"$G" --path godot --resolution 1200x500 res://tests/hunter_view.tscn -- shot=user://hunter.png`

func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.92, 0.92, 0.9)
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.7)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.5, 0)
	add_child(sun)
	var geo := SpecTrilobite.hunter_geo(Rng32.new(77))
	var mat := SpecSea.life_mat(3, 1.0, 0.0, 0.8, 0.6, 0.12)
	for k in 3:
		var mi := MeshInstance3D.new()
		mi.mesh = geo.to_mesh()
		mi.material_override = mat
		mi.position = Vector3(-1.25 + 1.25 * k, 0, 0)
		# side on, head to the left; three-quarters from above, as the reconstructions are drawn; from above
		var views := [Basis(Vector3.UP, -PI / 2), Basis(Vector3.RIGHT, 0.55) * Basis(Vector3.UP, -PI / 2 - 0.35), Basis(Vector3.RIGHT, PI / 2) * Basis(Vector3.UP, -PI / 2)]
		mi.basis = views[k]
		add_child(mi)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0.05, 3.6)
	cam.fov = 30
	add_child(cam)
	if args.has("shot"):
		await get_tree().create_timer(1.0).timeout
		get_viewport().get_texture().get_image().save_png(args.shot)
		get_tree().quit()
