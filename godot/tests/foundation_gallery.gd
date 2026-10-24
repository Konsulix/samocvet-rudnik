extends Control
## -- phase=before|after page=0|1|2 shot=<absolute.png>

const CASES := [
	{seed = 111, sid = "quartz", form = "single"},
	{seed = 86, sid = "calcite", form = "columnar", kind = "druse"},
	{seed = 338, sid = "calcite", form = "slabs", lustre = "dark", traits = ["phantom", "goldfleck"]},
	{seed = 83, sid = "fluorite", form = "cluster", kind = "druse"},
	{seed = 102, sid = "gypsum", form = "rosette"},
	{seed = 71, sid = "fluorite", form = "hopper"},
	{seed = 52, sid = "garnet", form = "pile"},
	{seed = 74, sid = "beryl", form = "hexplates"},
	{seed = 81, sid = "quartz", form = "radial", traits = ["irid", "scepter"]},
	{seed = 124, sid = "quartz", form = "columnar", legend = true, fx = "levitate"},
	{seed = 83, sid = "beryl", kind = "geode", legend = true, fx = "levitate"},
	{seed = 84, sid = "cuprite", kind = "geode", legend = true, fx = "fluor"},
	{seed = 122, sid = "quartz", form = "single", legend = true, fx = "heart"},
	{seed = 126, sid = "aquamarine", form = "single", legend = true, fx = "lightning"},
	{seed = 127, sid = "fluorite", form = "cluster", legend = true, fx = "chameleon"},
	{seed = 128, sid = "opal", form = "single", legend = true, fx = "opal"},
	{seed = 129, sid = "amethyst", form = "single", legend = true, fx = "kintsugi"},
	{seed = 130, sid = "quartz", form = "columnar", legend = true, fx = "starry"},
	{seed = 121, sid = "quartz", form = "cluster", legend = true, fx = "lava"},
	{seed = 123, sid = "fluorite", form = "cluster", legend = true, fx = "fluor"},
	{seed = 85, sid = "quartz", form = "floater"},
	{seed = 33, sid = "gold", form = "nugget"},
	{seed = 34, sid = "nativecu", form = "vein"},
	{seed = 35, sid = "malachite", form = "botryoid"},
	{seed = 51, sid = "ruby", cut = "facet"},
	{seed = 83, sid = "beryl", kind = "geode"},
	{seed = 84, sid = "cuprite", kind = "geode", traits = ["aurora"]},
]

func _ready() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var pair := arg.split("=", true, 1)
		args[pair[0]] = pair[1] if pair.size() > 1 else "1"
	var before: bool = args.get("phase", "after") == "before"
	var page := int(args.get("page", "0"))
	get_window().content_scale_size = Vector2i(1500, 1200)
	var bg := ColorRect.new()
	bg.color = Color("#101823")
	bg.size = Vector2(1500, 1200)
	add_child(bg)
	for i in 9:
		var item := description(CASES[page * 9 + i])
		var view := SpecView.new(600)
		view.position = Vector2((i % 3) * 500, (i / 3) * 400 + 44)
		view.size = Vector2(500, 350)
		view.still = true
		add_child(view)
		if before:
			var specimen: Node3D = load("res://build/foundation_before.gd").new()._specimen(item)
			view.studio.stage.add_child(SpecStudio.seat(specimen))
			view.live = view.studio.stage.get_child(0)
			view.live.rotation = Vector3(0.12, 0.6, 0)
			view.studio.set_glow(view.live.get_meta("glow"))
		else:
			await view.show_spec(item)
		var label := Label.new()
		label.position = view.position + Vector2(10, -35)
		label.text = "%s | %s / %s / %s #%d" % ["BEFORE" if before else "AFTER", item.sid, SpecGenome.of(item).form, item.get("fx", "normal"), item.seed]
		label.add_theme_font_size_override("font_size", 17)
		add_child(label)
	await get_tree().create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	if args.has("shot"): get_viewport().get_texture().get_image().save_png(args.shot)
	print("FOUNDATION GALLERY: ", args.get("phase", "after"), " page=", page)
	get_tree().quit()

static func description(source: Dictionary) -> Dictionary:
	var result := {kind = "crystal", gi = 3, traits = [], accents = [], shroom = -1}
	result.merge(source, true)
	return result
