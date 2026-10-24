extends Node
## Visual checks: -- shot=res://build/blockers.png [animate] [keep]
var failed := false

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)

func _ready() -> void:
	var hardness := BoardModel.new()
	hardness.setup(5, [], 1, {}, 0, false)
	for r in BoardModel.R:
		for c in BoardModel.C:
			if hardness.ROCK[r][c] > 0:
				check(hardness.ROCK_MAX[r][c] == 2, "Depth-hardened rocks must render as granite")
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var kv := arg.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var level := Level.new()
	add_child(level)
	await level.start(1)
	var m := level.model
	for r in BoardModel.R:
		for c in BoardModel.C:
			m.VOID[r][c] = false
			m.ROCK[r][c] = 0
			m.ROCK_MAX[r][c] = 0
			m.MUD[r][c] = 0
			m.GAS[r][c] = 0
			m.LOCK[r][c] = 0
			m.FIND[r][c] = false
			m.GEOC[r][c] = -1
			m.G[r][c] = m.new_gem((r * 2 + c) % 5)
	m.geos.clear()
	m.find.clear()
	m.goals = [{k = "rock", t = -1, left = 5}, {k = "mud", t = -1, left = 1}, {k = "gas", t = -1, left = 1}, {k = "lock", t = -1, left = 1}]
	for c in [1, 3, 5]:
		m.ROCK[2][c] = 1 if c == 1 else 2
		m.ROCK_MAX[2][c] = m.ROCK[2][c]
		m.G[2][c] = null
	m.GAS[4][1] = 1
	m.G[4][1] = null
	m.LOCK[4][3] = 1
	m.MUD[4][5] = 1
	# Granite retains its identity after the first hit and while the view is rebuilt.
	m.run_blast([{r = 2, c = 5, t = 0.0, kind = "fx"}])
	check(m.fx.any(func(event: Dictionary): return event.type == "rock" and event.get("strong", false)), "Rock hit animation must receive the granite identity")
	check(m.ROCK[2][5] == 1 and m.ROCK_MAX[2][5] == 2, "First contact must preserve granite identity")
	check(BoardSprites.rock_name(m.ROCK[2][5], m.ROCK_MAX[2][5] == 2) == "rock_cracked", "Damaged granite must use the supplied cracked sprite")
	m.fx.clear()
	level.board.rebuild(m)
	level._render_hud()
	await get_tree().create_timer(0.3).timeout
	for goal: Dictionary in level.goal_boxes:
		var icon: Control = goal.icon
		var label: Label = goal.label
		check(absf(icon.get_global_rect().get_center().x - label.get_global_rect().get_center().x) < 1.0, "Goal icon and counter must share their horizontal center")
		check(icon.get_global_rect().end.y <= label.get_global_rect().position.y + 1, "Goal icon must not overlap its counter")
	if args.has("animate"):
		var events := []
		for c in [1, 3, 5]: events.append({r = 2, c = c, t = 0.0, kind = "fx"})
		for c in [1, 3, 5]: events.append({r = 4, c = c, t = 0.0, kind = "fx"})
		m.run_blast(events)
		for event: Dictionary in m.fx:
			if event.type in ["rock", "gas", "mud", "lock"]: level._fx_one(event, {})
		check(m.ROCK[2][1] == 0 and m.ROCK[2][3] == 1 and m.ROCK[2][5] == 0, "Sandstone breaks once and granite needs exactly two contacts")
		await get_tree().create_timer(0.13).timeout
	if args.has("shot"):
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(args.shot)
	await get_tree().create_timer(0.9).timeout
	check(level.board.rock_transitions.is_empty(), "Rock hit transitions must expire")
	check(level.fx.get_child_count() == 0, "All one-shot blocker fragments and gas sprites must be freed")
	print("BLOCKER VISUAL REGRESSIONS: ", "FAIL" if failed else "PASS")
	if not args.has("keep"): get_tree().quit(1 if failed else 0)
