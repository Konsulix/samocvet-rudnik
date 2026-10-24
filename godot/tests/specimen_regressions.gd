extends Control
## Run with a rendering device: res://tests/specimen_regressions.tscn -- shot=<absolute.png>

const CASES := [
	{seed = 81, sid = "quartz", kind = "crystal", gi = 3, traits = ["irid", "scepter"], form = "radial"},
	{seed = 82, sid = "quartz", kind = "crystal", gi = 3, traits = ["irid"], form = "columnar"},
	{seed = 83, sid = "beryl", kind = "geode", gi = 3, traits = [], accents = ["pompom", "straw"]},
	{seed = 84, sid = "cuprite", kind = "geode", gi = 3, traits = ["aurora"], accents = ["pompom"]},
]

var failed := false

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)

func _ready() -> void:
	get_window().content_scale_size = Vector2i(1000, 720)
	var bg := ColorRect.new()
	bg.color = Color("#101823")
	bg.size = Vector2(1000, 720)
	add_child(bg)
	for i in CASES.size():
		var item: Dictionary = CASES[i]
		var view := SpecView.new(480)
		view.position = Vector2((i % 2) * 500, 40 + (i / 2) * 340)
		view.size = Vector2(500, 320)
		view.still = true
		add_child(view)
		await view.show_spec(item)
		var label := Label.new()
		label.text = item.sid + " / " + item.get("form", "geode")
		label.position = view.position + Vector2(12, -24)
		add_child(label)
		if i < 2:
			var found_rock := false
			for node in view.live.find_children("*", "MeshInstance3D", true, false):
				var material := (node as MeshInstance3D).material_override
				if material and material.has_meta("rock"):
					found_rock = true
			check(found_rock, item.form + " must include host rock")
	await get_tree().create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("shot="):
			check(get_viewport().get_texture().get_image().save_png(arg.substr(5)) == OK, "Screenshot must save")
	print("SPECIMEN REGRESSIONS: ", "FAILED" if failed else "PASS")
	get_tree().quit(1 if failed else 0)
