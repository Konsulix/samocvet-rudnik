extends Node
## The app: switches between screens (home, level, depot, museum) and owns the HDR glow pass.
## Command-line extras after `--` for testing:  level=5  depth=2  shot=user://shot.png  after=3.5  autoplay=6

var screen: Node
var args := {}

## the game is closing (the level, a child, has already left the tree): free what outlives levels (Level.release_pool)
func _exit_tree() -> void:
	if args.has("diag"): print(Diag.text())
	Level.release_pool()
	MineView.release()

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if args.has("slow"): Diag.slow_ms = int(args.slow)
	if args.has("bake_shaders"):
		# the shaders written as text, as files for the export's shader baker (ShaderFiles); the iOS build runs this
		print("baked %d shaders into %s" % [ShaderFiles.bake(), ShaderFiles.DIR])
		get_tree().quit()
		return
	# the 2D glow pass: off, it showed nothing (no HDR 2D, so nothing passes its threshold) and cost a full-screen
	# blur every frame; `glow` turns it back on to compare
	if args.has("glow"): _setup_glow()
	if args.has("uv"): Spec.force_uv = float(args.uv)
	if args.has("boot_seed"): Boot.seed_v = int(args.boot_seed)
	if args.has("notch"):
		var ins: PackedStringArray = String(args.notch).split(",")
		UI.fake_insets = Vector2(float(ins[0]), float(ins[1]) if ins.size() > 1 else 0.0)
	if args.has("style"): Board3D.STYLE = int(args.style)
	if args.has("rock"): BoardKit.force_rock = args.rock
	if args.has("gems"): BoardSprites.gem_style = "" if args.gems == "classic" else args.gems
	if args.has("ore_look"): BoardSprites.ore_look = args.ore_look
	if args.has("locks"): BoardSprites.lock_style = args.locks
	if args.has("zones"): BoardSprites.zone_style = args.zones
	if args.has("area"): Save.d.area = int(args.area)
	if args.has("rich"): Save.d.lrich = true
	if args.has("lseed"): Save.d.lseed = int(args.lseed)
	if args.has("fe"): Save.d.fe = int(args.fe)
	if args.has("au"): Save.d.ore = int(args.au)
	if args.has("built"):
		Save.d.built[Save.area()] = Array(args.built.split(","))
		Save.d.depth[Save.area()] = int(args.get("open", "1"))
	if args.has("wins"):   # wins per depth, e.g. wins=3,2,0 (the drawn mine fills a depth with people after two)
	if args.has("beaten"): Save.d.boss_won[Save.area()] = true   # the mine's boss beaten (its flags fly)
		var ws: PackedStringArray = String(args.wins).split(",")
		for i in ws.size(): Save.d.dwins[i] = int(ws[i])
	if args.has("steps"):  # job steps paid, e.g. steps=camp:2,chamber:1
		for kv in String(args.steps).split(","):
			var p: PackedStringArray = kv.split(":")
			Save.d.jstep["%d:%s" % [Save.area(), p[0]]] = int(p[1])
	if args.has("scroll"): Home.start_scroll = float(args.scroll)
	if args.has("mine_event"): MineView.force_event = args.mine_event
	if args.has("mine_result"):   # mine_result=win|lose[,depth[,ore[,iron]]]: the home screen plays the level's reaction
		var r: PackedStringArray = String(args.mine_result).split(",")
		MineView.last_result = {area = Save.area(), won = r[0] == "win", k = int(r[1]) if r.size() > 1 else 0,
			ore = int(r[2]) if r.size() > 2 else 9, iron = int(r[3]) if r.size() > 3 else 8}
	if args.has("fill"):
		# test data: a museum full of stones, a few of them cut, and one jewel
		Save.d.coll = []
		for i in int(args.fill):
			var st := Stones.roll(5000 + i, i % 3, 0.6 + (i % 5) * 0.3, i % 3)
			if i % 4 == 0: st.cut = ["cab", "facet", "master"][i % 3]
			st.area = Save.area()
			st.dl = i % Data.depths(Save.area()).size()   # spread over the mine's depths: its pedestals show the best of each
			Save.d.coll.append(st)
			if not st.sid in Save.d.seen: Save.d.seen.append(st.sid)
		Save.d.jewels = [{id = 77, rid = "crown", cols = ["#e0115f", "#0f52ba", "#50c878", "#e8f4ff", "#ffd700"], names = ["ruby", "sapphire"], value = 9000}]
		Save.d.coins = 5000
	if args.has("fossils"):
		# test data: ammonites in the collection (they are in no mine's pool yet): `-- screen=museum fossils=8`;
		# the ones a previous run left in the save are replaced, not added to
		Save.d.coll = Save.d.coll.filter(func(c: Dictionary) -> bool: return c.get("sid", "") != "ammonite")
		var seed_h := 30000
		for i in int(args.fossils):
			var sd := 9100 + i
			var tr := ["irid"] if i % 3 == 0 else []
			# every fourth a heteromorph (they are rare: look for a seed that grows one)
			if i % 4 == 3:
				while String(SpecFossil.genes(seed_h, "ammonite", tr).hetero) == "": seed_h += 1
				sd = seed_h
				seed_h += 1
			var st := Stones.roll(sd, 0, 1.2, 2)
			st.sid = "ammonite"
			st.kind = "fossil"
			st.traits = tr
			if i == 5: st.legend = true
			st.tier = Stones.tier_of(st.sid, int(st.gi), bool(st.legend))
			st.area = 0
			st.dl = i % 6
			Save.d.coll.append(st)
		if not "ammonite" in Save.d.seen: Save.d.seen.append("ammonite")
	if args.has("newfinds"):
		# test data: every kind of petrified wood, fulgurite, flower in quartz and amber (in no mine's pool yet):
		# `-- screen=museum newfinds`; a seed is looked up for each kind, old ones from a previous run are replaced
		var sids := ["petrified_wood", "fulgurite", "flower_quartz", "amber"]
		Save.d.coll = Save.d.coll.filter(func(c: Dictionary) -> bool: return not c.get("sid", "") in sids)
		var want := [
			["petrified_wood", func(g: Dictionary) -> bool: return g.show == "slice" and float(g.opal) < 0.2],
			["petrified_wood", func(g: Dictionary) -> bool: return g.show == "slice" and float(g.opal) >= 0.5],
			["petrified_wood", func(g: Dictionary) -> bool: return g.show == "slice" and String(g.heart) != ""],
			["petrified_wood", func(g: Dictionary) -> bool: return g.show == "log"],
			["petrified_wood", func(g: Dictionary) -> bool: return g.show == "twig"],
			["petrified_wood", func(g: Dictionary) -> bool: return g.show == "driftwood" and g.core == "opal"],
			["petrified_wood", func(g: Dictionary) -> bool: return g.show == "driftwood" and g.core == "crystal"],
			["fulgurite", func(g: Dictionary) -> bool: return int(g.glass) == 0],
			["fulgurite", func(g: Dictionary) -> bool: return int(g.glass) != 0]]
		for b in ["star", "rose", "daisy", "bell", "blossom", "poppy"]:
			want.append(["flower_quartz", func(g: Dictionary) -> bool: return g.bloom == b])
		for c in ["ant", "beetle", "fly", "mosquito", "spider"]:
			want.append(["amber", func(g: Dictionary) -> bool: return g.content == "insect" and g.insect == c])
		for c in ["flower", "fern", "feather"]:
			want.append(["amber", func(g: Dictionary) -> bool: return g.content == c])
		var sd := 40000
		for i in want.size():
			var sid: String = want[i][0]
			var ok: Callable = want[i][1]
			while not ok.call(SpecFossil.genes(sd, sid, [])): sd += 1
			var st := Stones.roll(sd, 0, 1.2, 2)
			sd += 1
			st.sid = sid
			st.kind = "fossil"
			st.traits = []
			st.legend = false
			st.tier = Stones.tier_of(st.sid, int(st.gi), false)
			st.area = 0
			st.dl = i % 6
			Save.d.coll.append(st)
			if not sid in Save.d.seen: Save.d.seen.append(sid)
	if args.has("trilobites"):
		# test data: a trilobite of every kind and rarity in the collection: `-- screen=stones trilobites`;
		# a seed is looked up for each, old ones from a previous run are replaced
		Save.d.coll = Save.d.coll.filter(func(c: Dictionary) -> bool: return c.get("sid", "") != "trilobite")
		var want := []
		for gn in ["elrathia", "phacops", "asaphus", "dicranurus", "walliserops", "isotelus"]:
			want.append(func(g: Dictionary) -> bool: return g.genus == gn and int(g.oysters) == 0)
		want.append(func(g: Dictionary) -> bool: return g.show == "enrolled")
		want.append(func(g: Dictionary) -> bool: return g.show == "nodule")
		want.append(func(g: Dictionary) -> bool: return g.show == "mass")
		want.append(func(g: Dictionary) -> bool: return int(g.pal) == 6)
		want.append(func(g: Dictionary) -> bool: return int(g.pal) == 4 and g.show == "matrix")
		for n in [1, 2, 3]:
			want.append(func(g: Dictionary) -> bool: return int(g.oysters) == n)
		want.append(func(g: Dictionary) -> bool: return g.moult)
		want.append(func(g: Dictionary) -> bool: return g.bite)
		var sd := 70000
		var fxs := ["awaken", "moon", "hunter", "glow"]
		for i in want.size() + fxs.size():
			var legend := i >= want.size()
			var st := {}
			while true:
				st = Stones.roll(sd, 2, 1.2, 2)
				st.sid = "trilobite"
				st.kind = "fossil"
				st.traits = []
				st.legend = legend
				sd += 1
				if legend:
					# the legendary ones: a seed for each living effect a trilobite can have
					if SpecGenome.of(Spec.of_stone(st)).fx == fxs[i - want.size()]: break
				elif (want[i] as Callable).call(SpecFossil.genes(int(st.id), "trilobite", [])): break
			st.tier = Stones.tier_of(st.sid, int(st.gi), legend)
			st.area = 2
			st.dl = i % 6
			Save.d.coll.append(st)
		if not "trilobite" in Save.d.seen: Save.d.seen.append("trilobite")
		# kept in the save, so a later run without the key still has them (and the atlas knows them)
		for st: Dictionary in Save.d.coll:
			if st.get("sid", "") == "trilobite": Save.note_find(st, 2, int(st.dl))
		Save.persist()
	if args.has("tab"):
		Museum.start_tab = args.tab
	if args.has("screen"):
		go(args.screen)
	elif args.has("level"):
		var dl := int(args.get("depth", "0"))
		show_level(int(args.level), [], dl, LevelGen.current(dl) if args.has("gen") else {})
	else:
		_boot()
	if args.has("ui"):
		await get_tree().create_timer(float(args.get("ui_after", "0"))).timeout
		if screen.has_method("_" + args.ui): screen.call("_" + args.ui)
	if args.has("lens"): Save.d.eq.lens = int(args.lens)
	if args.has("alive"):
		# the admin's "All animations on" for the current mine: `-- screen=home area=1 alive`
		Admin._alive()
	if args.has("admin"):
		# the tester's panel, for a look: `-- screen=home admin`
		get_tree().create_timer(float(args.get("ui_after", "1"))).timeout.connect(Admin.open)
	if args.has("hoard"):
		# a look at the boss's reward: `-- screen=home hoard lens=2` (not awaited: the other keys go on)
		_hoard_demo()
	if args.has("reveal"):
		var st := Stones.roll(int(args.reveal), Save.area(), 0.8, 1)
		st.integ = 86
		if args.has("sid"): st.sid = args.sid
		if args.has("kind"): st.kind = args.kind
		if args.has("shroom"): st.shroom = int(args.shroom)
		if args.has("traits"): st.traits = Array(args.traits.split(","))
		if args.has("legend"):
			st.legend = true
			st.tier = 4
			if args.legend != "1": st.fx = args.legend
		# open the callouts as soon as the stone is built: `callouts` (all) or `callouts=<gene id>` (that one picked)
		if args.has("callouts"): Reveal.auto_callouts = args.callouts
		if args.has("callouts_at"): SpecCallouts.freeze = float(args.callouts_at)
		if args.has("crack"): Reveal.new().crack(st)
		else: Reveal.new().show_stone(st)
	if args.has("shot"):
		_take_shot()
	if args.has("enter"):
		# enter=SECONDS: open the current level from the home screen after a while, as a tap on Play would
		await get_tree().create_timer(float(args.enter)).timeout
		print("enter level")
		show_level(Save.d.level, [], 0, LevelGen.current(0))
	if args.has("sim_min"):
		print(SimEconomy.minerals(int(args.sim_min)))
		get_tree().quit()
		return
	if args.has("sim_boss"):
		# sim_boss=N: the first mine's boss fought N times by the autoplayer (tests/sim_economy.gd)
		print(SimEconomy.boss_report(int(args.get("area", 0)), int(args.sim_boss)))
		get_tree().quit()
	if args.has("sim_gen"):
		# sim_gen=N: N generated levels per depth played inside the board model: wins, moves, ore (tests/sim_economy.gd)
		print(SimEconomy.gen_report(int(args.sim_gen), int(args.get("area", 0))))
		get_tree().quit()
	if args.has("sim"):
		# sim=N: N levels per depth played inside the board model, stones broken per colour (tests/sim_economy.gd)
		print(SimEconomy.report(int(args.sim)))
		get_tree().quit()
		return
	if args.has("bake_boot"):
		# the loading screen's stone as a flipbook: one full turn in FRAMES pictures, a sheet of 8 per row,
		# so the loading screen shows it without any 3D (nothing to compile while it is up)
		var studio := SpecStudio.make(Boot.CELL, Viewport.MSAA_4X, true)
		add_child(studio.vp)
		studio.vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		var stone: Dictionary = Boot.STONE.duplicate()
		stone.seed = Boot.seed_v
		var piv: Node3D = await studio.show_async(stone)
		await get_tree().create_timer(1.0).timeout
		var sheet := Image.create(Boot.CELL * 8, Boot.CELL * ceili(Boot.FRAMES / 8.0), false, Image.FORMAT_RGBA8)
		for i in Boot.FRAMES:
			piv.rotation = Vector3(0.12, float(i) / Boot.FRAMES * TAU, 0)
			for k in 2:
				studio.vp.render_target_update_mode = SubViewport.UPDATE_ONCE
				await RenderingServer.frame_post_draw
			var img := studio.vp.get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			sheet.blit_rect(img, Rect2i(0, 0, Boot.CELL, Boot.CELL), Vector2i((i % 8) * Boot.CELL, (i / 8) * Boot.CELL))
		sheet.save_png(ProjectSettings.globalize_path(Boot.SHEET))
		print("baked boot flipbook")
		get_tree().quit()
	if args.has("bake_thumbs"):
		# render every machine's picture once and save it into the project (Spec.BAKED)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/thumbs"))
		var ids := ["hammer", "rig", "tbm", "deep"]
		for e in Data.EQUIP: ids.append(e.id)
		# bake_thumbs=lens,vent: only those
		if String(args.bake_thumbs) != "1":
			ids = Array(String(args.bake_thumbs).split(","))
		for id in ids:
			var got := [null]
			Spec.thumb({machine = id, bake = true}, func(t: Texture2D): got[0] = t)
			while got[0] == null: await get_tree().process_frame
			(got[0] as Texture2D).get_image().save_png(ProjectSettings.globalize_path(Spec.BAKED % id))
			print("baked ", id)
		get_tree().quit()
	if args.has("stress"):
		# stress=N: build N random finds one after another and print the diagnostics log
		await get_tree().create_timer(2.0).timeout
		for i in int(args.stress):
			var st := Stones.roll(randi() % 1000000, randi() % Data.AREAS.size(), randf() * 2.0, randi() % 4)
			if randf() < 0.3: st.legend = true
			var p := await SpecStudio.build_async(Spec.of_stone(st))
			if p: p.free()
		print(Diag.text())
		get_tree().quit()
	if args.has("hitch"):
		_hitch(float(args.hitch))
	if args.has("perf"):
		_perf(int(args.perf))

func _setup_glow() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_strength = 1.0
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.05
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
	Diag.where = n.get_script().get_global_name() if n.get_script() else String(n.name)
	# a boss fight has started its own theme while mounting
	if n is Level and (n as Level).model.boss_on(): return
	Sfx.music("level" if n is Level else "home")

## the loading screen over everything; the home screen appears under it as it fades
func _boot() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	var b := Boot.new()
	if args.has("boot_seed"): b.set_meta("hold", true)
	layer.add_child(b)
	b.done.connect(show_home)
	b.tree_exited.connect(layer.queue_free)

func show_home() -> void:
	var h := Home.new()
	_swap(h)
	h.play.connect(func(n: int, pre: Array, dl: int): show_level(n, pre, dl, LevelGen.current(dl)))
	h.go.connect(go)

func go(id: String) -> void:
	match id:
		"map": Chrome.mines_card()
		"home": show_home()
		"depot":
			var d := Depot.new()
			_swap(d)
			d.go.connect(go)
		"museum":
			var m := Museum.new()
			_swap(m)
			m.go.connect(go)

func show_level(n: int, pre: Array, dl: int, level: Dictionary = {}) -> void:
	var lv := Level.new()
	_swap(lv)
	lv.finished.connect(_on_level_finished)
	lv.start(n, pre, dl, level)
	if args.has("specials"):
		# for a look: one of each special on the second row
		var row := 1
		for k in ["rh", "rv", "bomb", "drill", "orb"].size():
			var g: BoardModel.Gem = lv.model.G[row][k + 1]
			if g:
				g.sp = ["rh", "rv", "bomb", "drill", "orb"][k]
				g.t = -1
		lv.board.rebuild(lv.model)
	if args.has("strike"):
		# for a look: a booster (`booster=pick|bore_h|bore_v|pan`, the pickaxe if none) on cell r,c a moment after the board has settled
		await get_tree().create_timer(1.5).timeout
		var rc := String(args.strike).split(",")
		lv.booster = String(args.get("booster", "pick"))
		lv.busy = false
		if lv.booster == "pan": lv._use_pan()
		else: lv._use_booster(int(rc[0]), int(rc[1]))
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

func _hoard_demo() -> void:
	await get_tree().create_timer(float(args.get("ui_after", "1"))).timeout
	var hs := await Hoard.pick(Save.area())
	Reveal.new().show_stone(hs)

func _on_level_finished(res: Dictionary) -> void:
	Save.level_played(res.won, int(res.get("depth", 0)))
	if not res.get("boss", false):
		var mined: Dictionary = res.get("mined", {})
		MineView.last_result = {area = Save.area(), won = res.won, k = int(res.get("depth", 0)), iron = int(mined.get("iron", 0)), ore = int(mined.get("ore", 0))}
	if res.get("boss", false) and not res.won:
		Save.d.boss_tries[Save.area()] += 1
	Save.persist()
	if res.won:
		if res.get("boss", false):
			# the boss's hoard: nine geodes, one to keep
			var hs := await Hoard.pick(Save.area())
			var hr := Reveal.new()
			hr.show_stone(hs)
			await hr.finished
		if not res.stone.is_empty():
			var rv := Reveal.new()
			rv.show_stone(res.stone)
			await rv.finished
		for s in res.bonus:
			await Reveal.new().crack(s, "A stone from a geode on the board")
		await _win_card(res)
	show_home()

## the end-of-level card: coins, the win streak
func _win_card(res: Dictionary) -> void:
	var v := Ov.card()
	var badge := UI.icon(56, func(ci: Control): Chrome.coin_icon(ci, "coin", Vector2(28, 28), 26))
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(badge)
	v.add_child(UI.title("Level %d complete!" % res.n, 22))
	if res.get("boss", false):
		v.add_child(Ov.text("%s is beaten. The way to the next mine is open." % Data.AREAS[Save.area()].boss.n))
	elif res.depth:
		v.add_child(Ov.text("Depth %d m: coins ×%s" % [Data.depth_m(Save.area(), res.depth), str(Data.depth_pay(res.depth))]))
	var line := HBoxContainer.new()
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	line.add_theme_constant_override("separation", 10)
	line.add_child(Reveal.chip("$ +%s" % UI.fmt(res.coins), true))
	var mined: Dictionary = res.get("mined", {})
	if int(mined.get("iron", 0)): line.add_child(Reveal.chip("+%d iron" % int(mined.iron), true))
	if int(mined.get("ore", 0)): line.add_child(Reveal.chip("+%d %s" % [int(mined.ore), String(Data.ore(Save.area()).n).to_lower()], true))
	v.add_child(line)
	if Save.d.streak >= 2:
		v.add_child(Ov.text("Win streak: %d. %s" % [Save.d.streak, Data.streak_text(Save.d.streak)]))
	else:
		v.add_child(Ov.text("Iron sinks the shaft deeper, %s fits out the mine." % String(Data.ore(Save.area()).n).to_lower()))
	var go := Ov.btn("Continue", "green", func(): Ov.close())
	v.add_child(go)
	await Ov.closed

## hitch=SECONDS: watch every frame for that long, log the slow ones (wall time and script time), then quit
func _hitch(secs: float) -> void:
	var t0 := Time.get_ticks_msec()
	var last := Time.get_ticks_usec()
	var n := 0
	var sum := 0.0
	var worst := 0.0
	var slow := 0
	var proc_sum := 0.0
	while Time.get_ticks_msec() - t0 < secs * 1000.0:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		var ms := (now - last) / 1000.0
		last = now
		var pr := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		n += 1
		sum += ms
		proc_sum += pr
		worst = maxf(worst, ms)
		if ms > 20.0:
			slow += 1
			print("hitch at %.2f s: frame %.1f ms, script %.1f ms, objects %d, draws %d" % [(Time.get_ticks_msec() - t0) / 1000.0, ms, pr,
				Performance.get_monitor(Performance.OBJECT_COUNT), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
	print("hitch summary: %d frames, avg %.1f ms, script avg %.2f ms, worst %.1f ms, slow %d, objects %d, nodes %d" % [n, sum / n, proc_sum / n, worst, slow,
		Performance.get_monitor(Performance.OBJECT_COUNT), Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
	get_tree().quit()

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

## perf=N: open N reveals in a row and log every frame slower than 20 ms (hitches while a specimen loads)
func _perf(n: int) -> void:
	await get_tree().create_timer(2.0).timeout
	var worst := 0.0
	for i in n:
		Reveal.new().show_stone(Stones.roll(100 + i * 7, Save.area(), 0.8, 1))
		var t0 := Time.get_ticks_msec()
		var last := Time.get_ticks_usec()
		while Time.get_ticks_msec() - t0 < 1500:
			await get_tree().process_frame
			var now := Time.get_ticks_usec()
			var ms := (now - last) / 1000.0
			last = now
			worst = maxf(worst, ms)
			if ms > 20.0: print("perf hitch: stone %d at +%d ms: %.1f ms" % [i, Time.get_ticks_msec() - t0, ms])
		Ov.close()
	print("perf worst frame: %.1f ms" % worst)
	get_tree().quit()

## `shot=user://x.png after=S`; with `frames=N every=S` a strip of N shots (x_0.png, x_1.png...) to see a motion
func _take_shot() -> void:
	await get_tree().create_timer(float(args.get("after", "3"))).timeout
	var n := int(args.get("frames", "1"))
	for i in n:
		if i > 0: await get_tree().create_timer(float(args.get("every", "0.1"))).timeout
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var path: String = args.shot if n == 1 else String(args.shot).get_basename() + "_%d.png" % i
		img.save_png(path)
		print("shot saved: ", ProjectSettings.globalize_path(path))
	get_tree().quit()
