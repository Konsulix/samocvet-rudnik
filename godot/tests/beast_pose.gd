extends Node3D
## every beast's bare body as the generator poses it (lean_basis, lie_a 0): is it the right way up?
## -- shot=user://pose.png [yaw=0.6] [show=loose|rock] [pitch=0 roll=0]
func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var ids: Array = SpecSkull.BEASTS if not args.has("ids") else Array(String(args.ids).split(","))
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.08, 0.08, 0.1)
	env.environment.ambient_light_color = Color(0.5, 0.5, 0.55)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.5, 0)
	add_child(sun)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.8, 0.7)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var hmat := StandardMaterial3D.new()
	hmat.albedo_color = Color(0.4, 0.3, 0.2)
	hmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i in ids.size():
		var id: String = ids[i]
		var bd := SpecSkull.body(id)
		var sk := {beast = id, show = String(args.get("show", "loose")), lie_a = [0.0, float(args.get("roll", "0")), float(args.get("pitch", "0"))]}
		var root := Node3D.new()
		add_child(root)
		var holder := Node3D.new()
		root.add_child(holder)
		holder.basis = SpecSkull.pose_basis(sk)
		var bb := AABB()
		var first := true
		for k in ["cranium", "mandible", "horns"]:
			if not bd.has(k): continue
			var g: Geo = bd[k]
			if g.v.is_empty(): continue
			var mi := MeshInstance3D.new()
			mi.mesh = g.to_mesh()
			mi.material_override = hmat if k == "horns" else mat
			holder.add_child(mi)
			var b := g.aabb()
			bb = b if first else bb.merge(b)
			first = false
		var sz := maxf(bb.size.x, maxf(bb.size.y, bb.size.z))
		holder.scale = Vector3.ONE * (1.6 / sz)
		holder.position = -(holder.basis * bb.get_center())
		root.rotation.y = float(args.get("yaw", "0.6"))
		var cols := ceili(sqrt(float(ids.size())))
		var step := 8.8 / cols
		root.scale = Vector3.ONE * (step / 2.2)
		root.position = Vector3((i % cols) * step - 4.4 + step * 0.5, 4.4 - step * 0.5 - (i / cols) * step, 0)
		var l := Label3D.new()
		l.text = id
		l.font_size = 48
		l.position = root.position + Vector3(0, -0.95 * step / 2.2, 1)
		add_child(l)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 9.0
	cam.position = Vector3(0, 0, 10)
	add_child(cam)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(String(args.get("shot", "user://pose.png")))
	get_tree().quit()
