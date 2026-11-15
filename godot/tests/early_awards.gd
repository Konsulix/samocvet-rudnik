extends Node
## How many achievements a newcomer collects in the first levels: the real game from a fresh save (the prologue, the
## old man's gift, the finds, the geodes), the boards played by the smart autoplayer, every find kept, the story lines
## going on by themselves. No building between levels, no taps on the mine's events, no stares at a card.
##   "$G" --path godot --resolution 390x844 res://tests/early_awards.tscn -- save=early_1 levels=5 [seed=1]
## Prints the achievements done after each level, and at the end.

var main: Node
var levels := 5
var played := 0
var in_level := false
var idle := 0.0
var rng := RandomNumberGenerator.new()
var t_start := 0
var fast := 1.0
var dbg := false
var hint := false

func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	levels = int(args.get("levels", "5"))
	dbg = args.has("dbg")
	hint = args.has("hint")
	rng.seed = int(args.get("seed", "1"))
	# the board's tips skipped (they wait on a tap in their hole); the rest of the guiding plays
	for k in Level.TIP: Save.tell(String(k))
	StoryScene.auto = true
	# fast=K: the game's clock K times faster (the autoplayer's thinking is not)
	fast = float(args.get("fast", "1"))
	Engine.time_scale = fast
	GeodeOpen.auto = true
	t_start = Time.get_ticks_msec()
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	_drive()

func _seen() -> Array:
	return (Save.d.aw_seen as Array).duplicate()

func _done_now() -> Array:
	var out: Array = []
	for e in Awards.LIST:
		var c := Awards._count(e)
		if c.y > 0 and c.x >= c.y: out.append(String(e.n))
	return out

func _drive() -> void:
	while true:
		await get_tree().create_timer(0.25).timeout
		if Engine.time_scale == 1.0: Engine.time_scale = fast   # (a hitstop puts the clock back to 1)
		if Time.get_ticks_msec() - t_start > 2400000:
			print("EA timeout")
			break
		var scr: Node = main.get("screen")
		# a board: the smart autoplayer's move whenever it may move
		if scr is Level:
			var lv := scr as Level
			if not lv.prologue: in_level = true
			idle = 0.0
			_press_any()
			if not lv.busy and not lv.model.over and not Ov.is_open():
				# (the smart autoplayer, ~2 s a move; `hint`: the game's own hint instead — fast, but it loses even the first levels)
				var mv: Array = lv.model.best_move() if hint else SimEconomy._choose_smart(lv.model, rng)
				if mv.is_empty(): continue
				if mv[0] == mv[2] and mv[1] == mv[3]: lv._on_tap(mv[0], mv[1])
				else: lv._on_swipe(mv[0], mv[1], mv[2], mv[3])
			continue
		if in_level and not (scr is Level):
			in_level = false
			# (levels counted as won: a lost one is played again, as a player would — levels=5 is five wins)
			var won_now := int(Save.d.level) - 1
			if won_now > played: played = won_now
			else: print("EA lost a level (n=%d)" % int(Save.d.level))
			await get_tree().create_timer(0.5).timeout
		if _press_any():
			idle = 0.0
			continue
		if _find(get_tree().root, func(n: Node) -> bool: return n is StoryScene or n is GeodeOpen):
			idle = 0.0
			continue
		idle += 0.25
		if dbg and int(idle * 4) % 40 == 1:
			var gw: Variant = (scr as Home).get("_guide_waits") if scr is Home else null
			print("EA dbg screen=%s idle=%.1f guide_waits=%s ov=%s bubble=%s" % [scr.get_script().get_global_name() if scr else "-", idle, str(gw), str(Ov.is_open()), str(_find(get_tree().root, func(n: Node) -> bool: return n is GuideBubble) != null)])
		# (not while the guide's own scene plays: the rise to him, the gift, his first beams)
		if scr is Home and bool((scr as Home).get("_guide_waits")): idle = 0.0
		if scr is Home and idle >= 3.0:
			idle = 0.0
			if played > 0 and not has_meta("rep%d" % played):
				set_meta("rep%d" % played, true)
				Awards.check(true)
				print("EA after level %d (level n=%d, wins=%s): %d done — %s" % [played, int(Save.d.level), str(Save.d.dwins), _done_now().size(), ", ".join(_done_now())])
			if played >= levels: break
			var dl := mini(int(Save.d.depth_sel[Save.area()]), int(Save.d.depth[Save.area()]))
			main.show_level(int(Save.d.level), [], dl, LevelGen.current(dl))
	Awards.check(true)
	var d := _done_now()
	print("EA final after %d levels: %d achievements done — %s" % [played, d.size(), ", ".join(d)])
	print("EA claimable now: %d" % Awards.waiting())
	get_tree().quit()

## the buttons a player would press to go on: the gift's thanks, Keep, Continue; a coach's note closed
func _press_any() -> bool:
	var c: Node = _find(get_tree().root, func(n: Node) -> bool: return n is Coach and (n as Coach).visible)
	if c:
		(c as Coach).close()
		(c as Coach).dismissed.emit()
		return true
	# the guide's line read and tapped away (he waits on it: "help me raise the headframe")
	var gb: Node = _find(get_tree().root, func(n: Node) -> bool: return n is GuideBubble and (n as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE)
	if gb:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = true
		gb.call("_gui_input", ev)
		return true
	# (out of moves: given up, a life spent — the window waited for ever, 15.11)
	for want in ["Gold! Thank you!", "Keep", "Continue", "Take this one", "Pick a crystal", "Give up"]:
		var b: Node = _find(get_tree().root, func(n: Node) -> bool: return n is Button and (n as Button).is_visible_in_tree() and not (n as Button).disabled and (n as Button).text.begins_with(want))
		if b:
			(b as Button).pressed.emit()
			return true
	return false

func _find(n: Node, f: Callable) -> Node:
	if f.call(n): return n
	for ch in n.get_children():
		var r := _find(ch, f)
		if r: return r
	return null
