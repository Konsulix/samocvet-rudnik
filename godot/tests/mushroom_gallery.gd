extends "res://tests/specimen_regressions.gd"
## Real specimens, all mushroom species: full views from two sides and a detail view.

const HOSTS := [
	{seed = 83, sid = "fluorite", kind = "druse", gi = 3, traits = ["irid"], form = "cluster"},
	{seed = 111, sid = "quartz", kind = "crystal", gi = 3, traits = [], form = "single"},
	{seed = 86, sid = "calcite", kind = "druse", gi = 3, traits = [], form = "columnar"},
]
const SPECIES := ["Fly agaric", "Chanterelle", "Porcini", "Glowing mycena"]

func _ready() -> void:
	check_blocked_mushrooms()
	var host_index := 0
	var shot := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("host="): host_index = int(arg.substr(5))
		if arg.begins_with("shot="): shot = arg.substr(5)
	get_window().content_scale_size = Vector2i(1920, 1320)
	var bg := ColorRect.new()
	bg.color = Color("#101823")
	bg.size = Vector2(1920, 1320)
	add_child(bg)
	for row in 3:
		for kind in 4:
			var item: Dictionary = HOSTS[host_index].duplicate(true)
			item.accents = ["mushrooms"]
			item.shroom = kind
			var view := SpecView.new(640)
			view.position = Vector2(kind * 480, row * 440 + 55)
			view.size = Vector2(480, 380)
			view.still = true
			add_child(view)
			await view.show_spec(item)
			view.live.rotation.y = 3.7 if row == 1 else 0.6
			var count := check_mushrooms(view.live, item)
			if host_index < 2: check(count > 0, "All mushroom species must remain present on the regression hosts")
			if row == 0:
				print("MUSHROOM SAMPLE: ", JSON.stringify({host = host_index, seed = item.seed, form = item.form, species = SPECIES[kind], count = count}))
			if row == 2 and count:
				focus_mushroom(view, kind)
			var label := Label.new()
			label.position = view.position + Vector2(10, -48)
			label.text = "%s | %s #%d | %d fungi\n%s" % [SPECIES[kind], item.form, item.seed, count, ["Front", "Back", "Detail (all geometry retained)"][row]]
			label.add_theme_font_size_override("font_size", 18)
			add_child(label)
	await get_tree().create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	if shot != "":
		check(get_viewport().get_texture().get_image().save_png(shot) == OK, "Screenshot must save")
	print("MUSHROOM ROCK/CRYSTAL CLEARANCE: ", "FAILED" if failed else "PASS")
	get_tree().quit(1 if failed else 0)

func focus_mushroom(view: SpecView, kind: int) -> void:
	var biggest := AABB()
	for node: MultiMeshInstance3D in view.live.find_children("*", "MultiMeshInstance3D", true, false):
		if node.material_override != SpecFungi.material(kind): continue
		var mm := node.multimesh
		for k in mm.instance_count:
			var box: AABB = node.global_transform * mm.get_instance_transform(k) * mm.mesh.get_aabb()
			if box.size.length_squared() > biggest.size.length_squared(): biggest = box
	var focus := biggest.get_center()
	var direction := focus - (view.live.get_child(0) as Node3D).global_position
	direction.y = clampf(direction.y, -0.35, 0.35)
	direction = direction.normalized()
	view.studio.cam.near = 0.02
	view.studio.cam.fov = 40.0
	view.studio.cam.look_at_from_position(focus + direction * maxf(0.6, biggest.size.length() * 2.2), focus)
