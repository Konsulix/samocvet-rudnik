extends Node
## The app: switches between screens (home, level, depot, museum) and owns the HDR glow pass.
## Command-line extras after `--` for testing:  level=5  depth=2  shot=user://shot.png  after=3.5  autoplay=6

var screen: Node
var args := {}

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if not args.has("noglow"): _setup_glow()
	if args.has("built"):
		Save.d.built[Save.area()] = Array(args.built.split(","))
		Save.d.depth[Save.area()] = int(args.get("open", "1"))
	if args.has("fill"):
		# test data: a museum full of stones, a few of them cut, and one jewel
		Save.d.coll = []
		for i in int(args.fill):
			var st := Stones.roll(5000 + i, i % 3, 0.6 + (i % 5) * 0.3, i % 3)
			if i % 4 == 0: st.cut = ["cab", "facet", "master"][i % 3]
			Save.d.coll.append(st)
			if not st.sid in Save.d.seen: Save.d.seen.append(st.sid)
		Save.d.jewels = [{id = 77, rid = "crown", cols = ["#e0115f", "#0f52ba", "#50c878", "#e8f4ff", "#ffd700"], names = ["рубин", "сапфир"], value = 9000}]
		Save.d.coins = 5000
	if args.has("tab"):
		Museum.start_tab = args.tab
	if args.has("screen"):
		go(args.screen)
	elif args.has("level"):
		show_level(int(args.level), [], int(args.get("depth", "0")))
	else:
		show_home()
	if args.has("ui"):
		await get_tree().process_frame
		if screen.has_method("_" + args.ui): screen.call("_" + args.ui)
	if args.has("reveal"):
		var st := Stones.roll(int(args.reveal), Save.area(), 0.8, 1)
		st.integ = 86
		if args.has("legend"):
			st.legend = true
			st.tier = 4
			if args.legend != "1": st.fx = args.legend
		if args.has("crack"): Reveal.new().crack(st)
		else: Reveal.new().show_stone(st)
	if args.has("shot"):
		_take_shot()

func _setup_glow() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_strength = 1.0
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 0.97
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.set_glow_level(0, 0.0)
	env.set_glow_level(1, 1.0)
	env.set_glow_level(2, 1.0)
	env.set_glow_level(3, 0.6)
	env.set_glow_level(4, 0.3)
	we.environment = env
	add_child(we)

func _swap(n: Node) -> void:
	if screen: screen.queue_free()
	screen = n
	add_child(n)

func show_home() -> void:
	var h := Home.new()
	_swap(h)
	h.play.connect(func(n: int, pre: Array, dl: int): show_level(n, pre, dl))
	h.go.connect(go)

func go(id: String) -> void:
	match id:
		"home": show_home()
		"depot":
			var d := Depot.new()
			_swap(d)
			d.go.connect(go)
		"museum":
			var m := Museum.new()
			_swap(m)
			m.go.connect(go)

func show_level(n: int, pre: Array, dl: int) -> void:
	var lv := Level.new()
	_swap(lv)
	lv.finished.connect(_on_level_finished)
	lv.start(n, pre, dl)
	if args.has("autoplay"):
		_autoplay(lv, int(args.autoplay))
	if args.has("win"):
		# jump to the end of the level: the find dug out, a geode stone waiting
		await get_tree().create_timer(1.5).timeout
		if not lv.model.find.is_empty():
			lv.model.find.done = true
			lv.model.find.integ = 92
		lv.model.bonus.append(Stones.roll(Save.next_uid(), Save.area(), 0.6, 0))
		lv.model.over = true
		lv._win()

func _on_level_finished(res: Dictionary) -> void:
	if res.won:
		if not res.stone.is_empty():
			var rv := Reveal.new()
			rv.show_stone(res.stone)
			await rv.finished
		for s in res.bonus:
			await Reveal.new().crack(s, "Камень из жеоды на поле")
		await _win_card(res)
	show_home()

## the end-of-level card: stars, coins, the win streak
func _win_card(res: Dictionary) -> void:
	var v := Ov.card()
	var star := UI.label("★", 54, UI.display, UI.GOLD)
	star.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(star)
	v.add_child(UI.title("Уровень %d пройден!" % res.n, 22))
	if res.depth:
		v.add_child(Ov.text("Глубина %d м: монеты ×%s" % [int(Data.DEPTHS[res.depth].m), str(Data.depth_pay(res.depth)).replace(".", ",")]))
	var line := HBoxContainer.new()
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	line.add_theme_constant_override("separation", 10)
	line.add_child(Reveal.chip("★ +1", true))
	line.add_child(Reveal.chip("$ +%s" % UI.fmt(res.coins), true))
	v.add_child(line)
	if Save.d.streak >= 2:
		v.add_child(Ov.text("Серия побед: %d. %s" % [Save.d.streak, Data.streak_text(Save.d.streak)]))
	else:
		v.add_child(Ov.text("Звёзды тратятся на обустройство рудника."))
	var go := Ov.btn("Дальше", "green", func(): Ov.close())
	v.add_child(go)
	await Ov.closed

## plays a few moves by itself, for screenshots of a level in motion
func _autoplay(lv: Level, turns: int) -> void:
	await get_tree().create_timer(1.2).timeout
	for i in turns:
		while lv.busy: await get_tree().create_timer(0.1).timeout
		var mv := lv.model.find_move()
		if mv.is_empty(): return
		if mv[0] == mv[2] and mv[1] == mv[3]: lv._on_tap(mv[0], mv[1])
		else: lv._on_swipe(mv[0], mv[1], mv[2], mv[3])
		await get_tree().create_timer(0.3).timeout

func _take_shot() -> void:
	await get_tree().create_timer(float(args.get("after", "3"))).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(args.shot)
	print("shot saved: ", ProjectSettings.globalize_path(args.shot))
	get_tree().quit()
