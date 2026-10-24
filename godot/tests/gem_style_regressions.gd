extends Node
## Exercise the real picker, persistent selection, texture cache, and board invariants.
var failed := false

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)

func click(button: Button) -> void:
	var point := button.get_global_rect().get_center()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.global_position = point
		event.pressed = pressed
		Input.parse_input_event(event)
		await get_tree().process_frame

func _ready() -> void:
	var original: String = Save.d.gem_style
	Save.set_gem_style("natural")
	var level := Level.new()
	add_child(level)
	await level.start(22)
	# Expose all six colours, including white (normally used on deeper levels).
	var colour := 0
	for node: GemNode in level.board.nodes.values():
		if node.sp == "" and node.item == "" and colour < 6:
			node.t = colour
			node.queue_redraw()
			colour += 1
	var moves: int = level.model.moves
	var goals := level.model.goals.duplicate(true)
	var find := level.model.find.duplicate(true)
	var nodes := level.board.nodes.duplicate()
	var textures := []
	for i in 6: textures.append(BoardSprites.gem(i))
	var button: Button = level.hud.find_child("GemStyleButton", true, false)
	await click(button)
	await get_tree().create_timer(0.35).timeout
	check(level.overlay.visible, "Gem button must open the style picker")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/gem-style-picker.png")
	var option: Button = level.overlay.find_child("Style_shaped", true, false)
	check(option != null, "Picker must offer the shaped set")
	if option: await click(option)
	check(not level.overlay.visible, "Selecting a style must close the picker")
	check(BoardSprites.gem_style == "shaped", "Picker must apply the new style")
	for i in 6:
		check(BoardSprites.gem(i) != textures[i], "Every colour must switch texture")
		check(BoardSprites.gem(i).resource_path.contains("gems_shaped"), "Every new sprite must resolve from the shaped set")
	check(level.model.moves == moves and level.model.goals == goals and level.model.find == find, "Changing appearance must not change gameplay progress")
	for id in nodes:
		check(level.board.nodes[id] == nodes[id], "Switching style must preserve live gem nodes")
	for goal: Dictionary in level.goal_boxes:
		check(goal.shown == goals[level.goal_boxes.find(goal)].left, "Switching must not reset goal counters")
	var reloaded := Node.new()
	reloaded.set_script(load("res://scripts/autoload/save_game.gd"))
	check(reloaded.d.gem_style == "shaped", "A fresh save instance must restore the selected style")
	reloaded.free()
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/gem-style-shaped.png")
	Save.set_gem_style("natural")
	for i in 6: check(BoardSprites.gem(i) == textures[i], "Switching back must reuse the correct cached textures")
	Save.set_gem_style("invalid-style")
	check(Save.d.gem_style == "natural", "Unknown style IDs must be ignored")
	Save.set_gem_style(original)
	print("GEM STYLE REGRESSIONS: ", "FAIL" if failed else "PASS")
	get_tree().quit(1 if failed else 0)
