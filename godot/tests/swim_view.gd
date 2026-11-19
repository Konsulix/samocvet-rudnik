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
var group := "swim"
var cut := false
var jaw_force := 0.0
var hx := 0.3
var hy := 0.0
var hsize := 0.4
var only := ""
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
	# g=fish: the small fish, not the giants
	group = String(args.get("g", "swim"))
	var ids := SpecReef.group(group)
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
		mi.position = Vector3((i % 4) * 1.15 - 1.72, -(i / 4) * 0.75 + 0.3 + (0.35 if ids.size() > 8 else 0.0), (i / 4) * 0.75 - 0.3 - (0.35 if ids.size() > 8 else 0.0))
	# solo=<id>: that one alone, large (size=1.3 across the view's height), from `from=x,y,z`
	if args.has("solo"):
		for i in ids.size():
			var mi := get_child(2 + i) as MeshInstance3D
			mi.visible = ids[i] == String(args.solo)
			mi.position = Vector3.ZERO
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.size = 4.8
	cam.position = Vector3(0, 3.0, 0.01) if args.has("top") else Vector3(0, 0.9, 3.0)
	add_child(cam)
	cam.look_at(Vector3(0, 0, 0))
	if args.has("solo"):
		cam.keep_aspect = Camera3D.KEEP_HEIGHT
		cam.size = float(args.get("size", "1.3"))
		var fr := String(args.get("from", "0,0.9,3")).split_floats(",")
		cam.position = Vector3(fr[0], fr[1], fr[2])
		cam.look_at(Vector3(0, 0.08, 0))
	if args.has("heads"):
		heads = true
		cut = args.has("cut")
		jaw_force = float(args.get("jaw", "0"))
		hx = float(args.get("hx", "0.3"))
		hy = float(args.get("hy", "0"))
		hsize = float(args.get("hsize", "0.4"))
		only = String(args.get("only", ""))
		_heads.call_deferred()

## heads: each swimmer's head alone, large, side on, with a grid of model units (0.02) — to find its eyes and jaw
func _heads() -> void:
	var ids := SpecReef.group(group)
	for c in get_children():
		if c is MeshInstance3D: c.visible = false
	var cam := get_viewport().get_camera_3d()
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.size = hsize
	for i in ids.size():
		if only != "" and ids[i] != only: continue
		var mi := get_child(2 + i) as MeshInstance3D
		mi.visible = true
		mi.position = Vector3.ZERO
		(mi.material_override as ShaderMaterial).set_shader_parameter("swim", 0.0)
		var b := mi.mesh.get_aabb()
		cam.position = Vector3(hx, b.get_center().y + hy, 3.0)
		cam.rotation = Vector3.ZERO
		# (cut: the near half sliced away down the middle — the inside of the mouth, if the model has one)
		cam.near = 3.0 if cut else 0.05
		for q in ["flip", "neck", "jet"]: (mi.material_override as ShaderMaterial).set_shader_parameter(q, 0.0)
		(mi.material_override as ShaderMaterial).set_shader_parameter("jaw_force", jaw_force)
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
		# (the jaw's hinge and the mouth's line, as SpecReef.MODELS has them: red)
		var an: Dictionary = (SpecReef.MODELS[ids[i]] as Dictionary).get("anim", {})
		if an.has("jaw_x"):
			for q in 260:
				var mx := float(an.jaw_x) + q * 0.001
				var my := float(an.jaw_y) + q * 0.001 * float(an.get("jaw_s", 0.0))
				var ix := int(img.get_width() * 0.5 + (mx - hx) * px)
				var iy := int(img.get_height() * 0.5 - (my - b.get_center().y - hy) * px)
				for e in (5 if q < 4 else 1):
					if ix >= 0 and ix < img.get_width() and iy + e >= 0 and iy + e < img.get_height(): img.set_pixel(ix, iy + e, Color(1, 0.1, 0.1))
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
