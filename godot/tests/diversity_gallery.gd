extends "res://tests/specimen_regressions.gd"
## Targeted coverage after the rock-size rollback. -- page=0|1|2 out=<absolute directory>
## Each run saves front/back views of six specimens. Recipes deliberately pin genes.

const SAMPLES := [
	{seed = 83, sid = "fluorite", kind = "druse", gi = 2, form = "cluster", traits = ["moss", "irid", "zoned", "goldfleck"], accents = ["mushrooms", "fronds", "flowers", "lichen"], shroom = 0},
	{seed = 111, sid = "quartz", form = "single", legend = true, fx = "heart", traits = ["phantom", "rutile", "twin", "bubbles"], accents = ["mushrooms", "straw", "inkspots", "clouds"], shroom = 2},
	{seed = 112, sid = "amethyst", kind = "druse", form = "cluster", legend = true, fx = "lightning", lustre = "glass", traits = ["moss", "silver", "eroded", "zoned"], accents = ["mushrooms", "flowers", "fronds", "lichen"], shroom = 1},
	{seed = 61, sid = "aquamarine", kind = "druse", form = "cluster", legend = true, fx = "opal", traits = ["coral", "anomaly", "eroded", "aurora"], accents = ["mushrooms", "fronds", "flowers", "lichen"], shroom = 3},
	{seed = 338, sid = "calcite", gi = 2, form = "slabs", lustre = "dark", traits = ["phantom", "goldfleck", "silver", "zoned"], accents = ["pompom", "straw", "lichen"]},
	{seed = 81, sid = "quartz", form = "radial", legend = true, fx = "starry", traits = ["irid", "bubbles", "silver", "zoned"], accents = ["pompom", "straw"]},
	{seed = 102, sid = "gypsum", form = "rosette", legend = true, fx = "kintsugi", lustre = "glass", traits = ["eroded", "zoned", "silver", "moss"], accents = ["fronds", "flowers", "pompom"], loose = 0.7},
	{seed = 71, sid = "fluorite", form = "hopper", legend = true, fx = "chameleon", traits = ["irid", "druzy", "goldfleck", "silver"], accents = ["needles", "crust", "lichen"]},
	{seed = 91, sid = "gold", kind = "nugget", form = "vein", traits = ["goldfleck", "silver", "zoned"], accents = ["pompom", "straw"]},
	{seed = 92, sid = "nativecu", kind = "nugget", form = "nugget", legend = true, fx = "levitate", traits = ["silver", "eroded"], accents = ["pompom", "straw"]},
	{seed = 83, sid = "beryl", kind = "geode", legend = true, fx = "levitate", traits = ["aurora", "scepter", "phantom", "goldfleck"], accents = ["pompom", "straw"]},
	{seed = 121, sid = "quartz", kind = "druse", form = "cluster", legend = true, fx = "lava", traits = ["goldfleck", "eroded", "moss", "zoned"], accents = ["needles", "pompom", "flowers"]},
	{seed = 4, sid = "calcite", kind = "druse", form = "columnar", lustre = "dark", traits = ["phantom", "goldfleck", "silver", "eroded"], accents = ["pompom", "straw", "lichen"]},
	{seed = 85, sid = "quartz", form = "floater", traits = ["floater", "scepter", "irid", "silver"], accents = ["pompom", "straw"]},
	{seed = 52, sid = "garnet", form = "pile", traits = ["eroded", "goldfleck", "druzy", "moss"], accents = ["dust", "lichen", "fronds"], nest = "hollows", loose = 0.8},
	{seed = 74, sid = "ruby", form = "hexplates", traits = ["moss", "irid", "zoned", "goldfleck"], accents = ["fronds", "flowers", "straw"]},
	{seed = 35, sid = "malachite", form = "botryoid", gi = 1, traits = ["coral", "silver", "goldfleck"], accents = ["pompom", "straw"]},
	{seed = 84, sid = "cuprite", kind = "geode", legend = true, fx = "fluor", traits = ["aurora", "silver", "zoned", "goldfleck"], accents = ["pompom", "straw"]},
]

func _ready() -> void:
	check_blocked_mushrooms()
	var page := 0
	var output := ProjectSettings.globalize_path("res://build")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("page="): page = int(arg.substr(5))
		if arg.begins_with("out="): output = arg.substr(4)
	get_window().content_scale_size = Vector2i(1800, 1200)
	var bg := ColorRect.new()
	bg.color = Color("#101823")
	bg.size = Vector2(1800, 1200)
	add_child(bg)
	var views: Array[SpecView] = []
	var manifest := []
	for i in 6:
		var number := page * 6 + i
		var item := recipe(SAMPLES[number])
		var gene := SpecGenome.of(item)
		var view := SpecView.new(720)
		view.position = Vector2((i % 3) * 600, (i / 3) * 600 + 115)
		view.size = Vector2(600, 480)
		view.still = true
		add_child(view)
		var begin := Time.get_ticks_msec()
		await view.show_spec(item)
		check(view.live != null, "Build must succeed: " + item.sid)
		if not view.live: continue
		views.append(view)
		var count := check_mushrooms(view.live, item)
		check_legend(view.live, gene.fx)
		if item.shroom >= 0: check(count > 0, "Pinned mushroom species must spawn: " + item.sid)
		check(not (view.live.get_child(0) as Node3D).has_meta("foundation_growth"), "Rock enlargement must stay rolled back")
		for trait_id: String in item.traits: check(Data.TR.has(trait_id), "Unknown trait: " + trait_id)
		for accent: String in item.accents: check(SpecGenome.ACC_N.has(accent), "Unknown accent: " + accent)
		var animations: Array = view.live.get_meta("anim", [])
		if item.get("fx", "") == "levitate":
			check(animations.size() == 2, "Levitation needs both orbits")
			for animation: Array in animations:
				check(animation[0].get_child_count() >= 3, "Levitation needs orbiting shards")
		var label := Label.new()
		label.position = view.position + Vector2(12, -105)
		label.add_theme_font_size_override("font_size", 18)
		label.text = "%02d  %s | %s | %s | seed %d\n%s\n%s" % [number + 1, item.sid, gene.form, gene.fx if gene.fx else "normal", item.seed, ", ".join(item.traits), ", ".join(item.accents)]
		if item.shroom >= 0: label.text += "\n" + SpecFungi.NAMES[item.shroom] + ": " + str(count)
		add_child(label)
		var record := {number = number + 1, recipe = item, genes = gene, mushrooms = count, animations = animations.size(), build_and_check_ms = Time.get_ticks_msec() - begin}
		manifest.append(record)
		print("DIVERSITY SAMPLE: ", JSON.stringify({number = number + 1, sid = item.sid, form = gene.form, fx = gene.fx, mushrooms = count, ms = record.build_and_check_ms}))
	var initial_orbits := []
	for view in views:
		for animation: Array in view.live.get_meta("anim", []): initial_orbits.append([animation[0], animation[0].transform])
	await get_tree().create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(output.path_join("diversity-%d-front.png" % (page + 1))) == OK, "Front screenshot must save")
	for view in views:
		view.live.rotation.y = 3.7
		for animation: Array in view.live.get_meta("anim", []):
			match animation[1]:
				"x": animation[0].rotate_x(float(animation[2]))
				"y": animation[0].rotate_y(float(animation[2]))
				"z": animation[0].rotate_z(float(animation[2]))
	for orbit: Array in initial_orbits: check(not (orbit[1] as Transform3D).is_equal_approx(orbit[0].transform), "Legendary orbit must move")
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(output.path_join("diversity-%d-back.png" % (page + 1))) == OK, "Back screenshot must save")
	if page == 0:
		var detail := preload("res://tests/mushroom_gallery.gd").new()
		for index in 4:
			detail.focus_mushroom(views[index], int(manifest[index].recipe.shroom))
		detail.free()
		await get_tree().create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		check(get_viewport().get_texture().get_image().save_png(output.path_join("diversity-mushroom-details.png")) == OK, "Mushroom detail screenshot must save")
	var file := FileAccess.open(output.path_join("diversity-recipes-%d.json" % (page + 1)), FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "\t"))
	print("DIVERSITY GALLERY: ", "FAILED" if failed else "PASS", " page=", page + 1, " specimens=", views.size())
	get_tree().quit(1 if failed else 0)

static func recipe(source: Dictionary) -> Dictionary:
	var item := {kind = "crystal", gi = 3, traits = [], accents = [], shroom = -1}
	item.merge(source, true)
	return item

func check_legend(specimen: Node3D, fx: String) -> void:
	if fx == "" or fx == "levitate": return # Orbits are checked at construction and after rotation.
	if fx == "heart":
		check(specimen.has_meta("heart_light"), "Heart light must exist")
		return
	if fx == "lightning":
		var bolts := 0
		for node in specimen.find_children("*", "MeshInstance3D", true, false):
			if node is SpecBolt: bolts += 1
		check(bolts > 0, "Lightning must contain actual bolts")
		return
	var parameter: String = {lava = "lava_k", fluor = "fluor_k", chameleon = "cham_k", starry = "star_k", opal = "opal_k", kintsugi = "kin_k"}[fx]
	var active := false
	for node: GeometryInstance3D in specimen.find_children("*", "GeometryInstance3D", true, false):
		var material := node.material_override as ShaderMaterial
		if not material: continue
		var value: Variant = material.get_shader_parameter(parameter)
		if value != null and float(value) > 0.0: active = true
	check(active, "Legendary shader must be active: " + fx)
