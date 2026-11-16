extends Node3D
## The sea's swimmers (SpecReef) side by side, large, seen from the side and a little above, moving as they do in a
## find (sea_swim.gdshader): `-- shot=user://swim.png [n=4] [every=0.8] [haze] [top]` — n shots, every seconds apart
## (user://swim_0.png ...), to see the tail beat, the flippers row, the neck sway, the jaw open
var shots := 4
var every := 0.8
var path := "user://swim.png"
var t := 0.0
var k := 0

func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	shots = int(args.get("n", "4"))
	every = float(args.get("every", "0.8"))
	path = String(args.get("shot", path))
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
		mi.material_override = m
		add_child(mi)
		mi.position = Vector3((i % 4) * 1.15 - 1.7, -(i / 4) * 0.75 + 0.3, (i / 4) * 0.75 - 0.3)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 2.0
	cam.position = Vector3(0, 3.0, 0.01) if args.has("top") else Vector3(0, 0.9, 3.0)
	add_child(cam)
	cam.look_at(Vector3(0, 0, 0))

func _process(dt: float) -> void:
	t += dt
	if t >= 1.0 + k * every:
		var img := get_viewport().get_texture().get_image()
		img.save_png(path.replace(".png", "_%d.png" % k))
		k += 1
		if k >= shots:
			get_tree().quit()
