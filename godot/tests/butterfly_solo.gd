extends Node3D
## One butterfly alone on near-black (the card backdrop's colour), sitting and slowly working its wings — the trailer's
## opening and closing shot (art/trailer/record.sh rows bf_solo*).
##   godot --path godot --resolution 664x1440 res://tests/butterfly_solo.tscn -- kind=monarch [size=0.45] [pitch=0.6]
##   [shot=user://solo.png t=2]
func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color8(5, 6, 10)
	env.environment.ambient_light_color = Color(0.45, 0.45, 0.5)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	add_child(env)
	var key := DirectionalLight3D.new()            # a warm key from above-left, a cool rim from behind
	key.rotation = Vector3(-0.9, 0.5, 0)
	key.light_color = Color(1.0, 0.93, 0.82)
	key.light_energy = 1.3
	add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation = Vector3(-0.3, PI + 0.4, 0)
	rim.light_color = Color(0.6, 0.75, 1.0)
	rim.light_energy = 0.8
	add_child(rim)
	var id := String(args.get("kind", "monarch"))
	var hold := Node3D.new()
	hold.rotation = Vector3(0, float(args.get("yaw", "0.5")), 0)
	hold.set_meta("grown", {})
	add_child(hold)
	var fb: SpecButterfly.Fly = SpecButterfly.put(hold, Rng32.new(int(args.get("seed", "7"))), id, Vector3.ZERO, Vector3.UP,
			1.0 / float(SpecButterfly.KINDS[id].span), false, [[Vector3.ZERO, Vector3.UP]])
	# it sits till off=S (then takes off out of the frame), else for good
	await get_tree().process_frame
	await get_tree().process_frame
	# (no find under it, so it found nowhere to sit and took to the air: set it down by hand)
	fb.state = SpecButterfly.Fly.SIT
	fb.spot = [Vector3.ZERO, Vector3.UP]
	fb.pos = Vector3.ZERO
	fb.heading = Vector3(1, 0, 0)
	fb._m_play("sit", 0.0, 0.0)
	fb.timer = float(args.get("off", "999"))
	var cam := Camera3D.new()
	cam.fov = 30.0
	var pitch := float(args.get("pitch", "0.6"))
	var dist := 1.0 / float(args.get("size", "0.28"))
	cam.position = Vector3(0, sin(pitch), cos(pitch)) * dist
	add_child(cam)
	cam.look_at(Vector3(0, float(args.get("aim", "0.3")), 0))
	if args.has("shot"):
		await get_tree().create_timer(float(args.get("t", "2.0"))).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(String(args.shot))
		get_tree().quit()
