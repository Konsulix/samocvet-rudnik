extends Control
## Run with a rendering device: res://tests/render_regressions.tscn -- shot=<absolute.png>
## Exercises timber with/without a level goal, then renders gold/copper veins and nuggets.

var failed := false

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)

func _ready() -> void:
	get_window().content_scale_size = Vector2i(1000, 800)
	var bg := ColorRect.new()
	bg.color = Color("#101823")
	bg.size = Vector2(1000, 800)
	add_child(bg)
	# A depth-added lock is an obstacle even when clearing timber isn't a goal.
	var m := BoardModel.new()
	m.rng.seed = 47
	m.setup(1, [], 3, {}, 0, false)
	check(m.goal_index("lock") == -1, "Expected a level without a timber goal")
	var count := 0
	var first := Vector2i(-1, -1)
	for r in BoardModel.R:
		for c in BoardModel.C:
			if m.LOCK[r][c]:
				count += 1
				first = Vector2i(r, c)
	check(count == 6, "Depth 3 must place six timber obstacles")
	if first.x >= 0:
		var gem: BoardModel.Gem = m.G[first.x][first.y]
		check(m.swap(first.x, first.y, first.x, first.y + (-1 if first.y > 0 else 1)) == null, "Timber must prevent swapping")
		m.hit(first.x, first.y, 0.0, "pick")
		check(m.LOCK[first.x][first.y] == 0 and m.G[first.x][first.y] == gem, "Breaking timber must free and preserve its gem")
		m.LOCK[first.x][first.y] = 1
	# Also exercise a hand-authored level that explicitly asks for timber.
	var goal_level := BoardModel.new()
	goal_level.setup(17, [], 0, {}, 0, false)
	check(goal_level.goal_index("lock") >= 0, "Level 17 must have a timber goal")
	var goal_i := goal_level.goal_index("lock")
	if goal_i >= 0:
		var before: int = goal_level.goals[goal_i].left
		for r in BoardModel.R:
			for c in BoardModel.C:
				if goal_level.LOCK[r][c]: goal_level.hit(r, c, 0.0, "pick")
		check(before > 0 and goal_level.goals[goal_i].left == 0, "Broken timber must count towards its goal")
	var board := BoardView.new()
	board.layout(Vector2(380, 650))
	board.position = Vector2(8, 140)
	add_child(board)
	board.rebuild(m)
	# Neutral cavity shading must preserve the material's gold/copper hue.
	for seed_v in [91, 92, 95, 98]:
		var geo := RockKit.crumble(Rng32.new(seed_v), 0.3)
		for color in geo.col:
			check(is_equal_approx(color.r, color.g) and is_equal_approx(color.g, color.b), "Metal cavity shading must be neutral")
	var examples := [
		{seed = 91, sid = "gold", kind = "nugget", gi = 3, traits = [], form = "vein"},
		{seed = 92, sid = "nativecu", kind = "nugget", gi = 2, traits = [], form = "vein"},
		{seed = 107, sid = "gold", kind = "nugget", gi = 2, traits = [], form = "nugget"},
		{seed = 108, sid = "nativecu", kind = "nugget", gi = 2, traits = [], form = "nugget"}]
	for i in examples.size():
		var view := SpecView.new(300)
		view.position = Vector2(400 + (i % 2) * 300, 60 + (i / 2) * 360)
		view.size = Vector2(300, 340)
		view.still = true
		add_child(view)
		await view.show_spec(examples[i])
		var label := Label.new()
		label.text = examples[i].sid + " / " + examples[i].form
		label.position = view.position - Vector2(0, 24)
		add_child(label)
	await get_tree().create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("shot="):
			check(get_viewport().get_texture().get_image().save_png(arg.substr(5)) == OK, "Screenshot must save")
	print("RENDER REGRESSIONS: ", "FAILED" if failed else "PASS")
	get_tree().quit(1 if failed else 0)
