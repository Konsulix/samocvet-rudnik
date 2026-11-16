extends Node3D
## The sea's swimmers (SpecReef) side by side, large, seen from the side and a little above, moving as they do in a
## find (sea_swim.gdshader): `-- shot=user://swim.png [n=4] [every=0.8] [start=1] [haze] [top]` — n shots, every seconds apart
## (user://swim_0.png ...), to see the tail beat, the flippers row, the neck sway, the jaw open
var shots := 4
var every := 0.8
var path := "user://swim.png"
var t := 0.0
var k := 0
var heads := false
var start := 1.0

func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	shots = int(args.get("n", "4"))
	every = float(args.get("every", "0.8"))
	path = String(args.get("shot", path))
	start = float(args.get("start", "1.0"))
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.05, 0.06, 0.08)
	env.environment.ambient_light_color = Color(0.5, 0.55, 0.6)
	env.environment.ambient_light_energy = 0.6
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.5, 0)
	add_child(sun)
	var ids := SpecReef.group("swim")
	for i in ids.size():
		var id: String = ids[i]
		var mi := MeshInstance3D.new()
		mi.mesh = SpecReef.mesh(id)
		var m := (SpecReef.mat(id) as ShaderMaterial).duplicate() as ShaderMaterial
		if not args.has("haze"): m.set_shader_parameter("haze", 0.0)
		m.set_shader_parameter("phase", 0.0)
		if args.has("shut"): m.set_shader_parameter("blink_force", float(args.shut) if args.shut != "" else 1.0)
		mi.material_override = m
		add_child(mi)
		mi.position = Vector3((i % 4) * 1.15 - 1.72, -(i / 4) * 0.75 + 0.3, (i / 4) * 0.75 - 0.3)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.size = 4.8
	cam.position = Vector3(0, 3.0, 0.01) if args.has("top") else Vector3(0, 0.9, 3.0)
	add_child(cam)
	cam.look_at(Vector3(0, 0, 0))
	if args.has("heads"):
		heads = true
		_heads.call_deferred()

## heads: each swimmer's head alone, large, side on, with a grid of model units (0.02) — to find its eyes and jaw
func _heads() -> void:
	var ids := SpecReef.group("swim")
	for c in get_children():
		if c is MeshInstance3D: c.visible = false
	var cam := get_viewport().get_camera_3d()
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.size = 0.4
	for i in ids.size():
		var mi := get_child(2 + i) as MeshInstance3D
		mi.visible = true
		mi.position = Vector3.ZERO
		(mi.material_override as ShaderMaterial).set_shader_parameter("swim", 0.0)
		var b := mi.mesh.get_aabb()
		cam.position = Vector3(0.3, b.get_center().y, 3.0)
		cam.rotation = Vector3.ZERO
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		# the grid: a line every 0.02, a stronger one every 0.1, in model units round the camera's middle
		var px := float(img.get_height()) / cam.size
		for g in range(-12, 13):
			var col := Color(1, 1, 0, 0.9) if g % 5 == 0 else Color(1, 1, 1, 0.25)
			var xx := int(img.get_width() * 0.5 + g * 0.02 * px)
			var yy := int(img.get_height() * 0.5 + g * 0.02 * px)
			for q in img.get_height():
				if xx >= 0 and xx < img.get_width(): img.set_pixel(xx, q, img.get_pixel(xx, q).lerp(col, col.a))
			for q in img.get_width():
				if yy >= 0 and yy < img.get_height(): img.set_pixel(q, yy, img.get_pixel(q, yy).lerp(col, col.a))
		img.save_png(path.replace(".png", "_%s.png" % ids[i]))
		print("HEAD ", ids[i], " centre x 0.3 y ", b.get_center().y)
		mi.visible = false
	get_tree().quit()

func _process(dt: float) -> void:
	if heads:
		return
	t += dt
	if t >= start + k * every:
		var img := get_viewport().get_texture().get_image()
		img.save_png(path.replace(".png", "_%d.png" % k))
		k += 1
		if k >= shots:
			get_tree().quit()
