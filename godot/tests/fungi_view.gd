extends Node3D
## The mushrooms alone, big: a cluster of every kind and every look of it on a dark stone, lit as a find is.
## `"$G" --path godot --resolution 1560x780 res://tests/fungi_view.tscn -- shot=user://fungi.png [count=6] [dark]`
## (dark: the room goes dark, as under a fluorescent find's ultraviolet — the mycena's glow)

func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var dark := args.has("dark")
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.03, 0.035, 0.045)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.5, 0.52, 0.56)
	env.environment.ambient_light_energy = 0.12 if dark else 0.55
	env.environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.environment.tonemap_exposure = 1.05
	env.environment.tonemap_white = 6.0
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.85, -0.6, 0)
	sun.light_energy = 0.25 if dark else 1.5
	sun.shadow_enabled = true
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(-0.3, 2.4, 0)
	fill.light_energy = 0.0 if dark else 0.45
	add_child(fill)
	var cells := []
	for kind in SpecFungi.KINDS.size():
		for look in (SpecFungi.KINDS[kind].looks as Array).size():
			cells.append([kind, look])
	var cols := 6
	var rows := int(ceil(cells.size() / float(cols)))
	var rock := SphereMesh.new()
	rock.radius = 0.62
	rock.height = 0.36
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(0.085, 0.075, 0.07)
	rm.roughness = 0.95
	var count := int(args.get("count", "6"))
	for i in cells.size():
		var kind: int = cells[i][0]
		var look: int = cells[i][1]
		var at := Vector3((i % cols - (cols - 1) * 0.5) * 1.5, -((i / cols) - (rows - 1) * 0.5) * 1.55, 0)
		var holder := Node3D.new()
		holder.position = at
		add_child(holder)
		var r := MeshInstance3D.new()
		r.mesh = rock
		r.material_override = rm
		r.position = Vector3(0, -0.17, 0)
		holder.add_child(r)
		var rng := Rng32.new(1000 + i * 77)
		var spots := []
		for k in 60:
			var a := rng.next() * TAU
			var d := sqrt(rng.next()) * 0.42
			spots.append([Vector3(cos(a) * d, 0.0, sin(a) * d), Vector3.UP])
		SpecFungi.look_pin = look
		SpecFungi.cluster(holder, rng, spots, kind, count, 0.62)
		SpecFungi.look_pin = -1
		var lab := Label3D.new()
		lab.text = "%d %s%s" % [kind, SpecFungi.NAMES[kind], (" · %d" % look) if (SpecFungi.KINDS[kind].looks as Array).size() > 1 else ""]
		lab.font_size = 28
		lab.pixel_size = 0.0035
		lab.position = Vector3(0, -0.5, 0.3)
		lab.modulate = Color(0.8, 0.75, 0.6)
		holder.add_child(lab)
	if dark:
		RenderingServer.global_shader_parameter_set("fluor_uv", 1.0)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.6, 9.5)
	cam.rotation = Vector3(-0.15, 0, 0)
	cam.fov = 30
	add_child(cam)
	if args.has("shot"):
		await get_tree().create_timer(1.2).timeout
		get_viewport().get_texture().get_image().save_png(args.shot)
		get_tree().quit()
