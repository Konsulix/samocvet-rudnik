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
	Atlas.release()
	BoardMech.release()
	FxLayer.release()

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
	# the tutorial: `tut` shows it from the start; test runs (shots, autoplay, sims) go without it
	# (`tut=swap,goals` starts as if those tips were already shown, to see the next ones; `quiet` - none, for recordings)
	if args.has("tut"): Save.d.tut = [] if args.tut == "1" else Array(String(args.tut).split(","))
	elif args.has("shot") or args.has("quiet") or args.has("autoplay") or args.keys().any(func(k): return String(k).begins_with("sim")):
		Coach.off = true
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
	if args.has("streak"): Save.d.streak = int(args.streak)
	if args.has("lseed"): Save.d.lseed = int(args.lseed)
	# feat=cart,dark: a generated level with exactly these works (LevelGen.FEATURES)
	if args.has("feat"): LevelGen.force_feats = Array(String(args.feat).split(","))
	if args.has("fe"): Save.d.fe = int(args.fe)
	if args.has("au"): Save.d.ore = int(args.au)
	if args.has("built"):
		Save.d.built[Save.area()] = Array(args.built.split(","))
		Save.d.depth[Save.area()] = int(args.get("open", "1"))
	if args.has("beaten"): Save.d.boss_won[Save.area()] = true   # the mine's boss beaten (its flags fly)
	if args.has("wins"):   # wins per depth, e.g. wins=3,2,0 (the drawn mine fills a depth with people after two)
		var ws: PackedStringArray = String(args.wins).split(",")
		for i in ws.size():
			while Save.d.dwins.size() <= i: Save.d.dwins.append(0)   # a new save is sized for the first mine
			Save.d.dwins[i] = int(ws[i])
	if args.has("steps"):  # job steps paid, e.g. steps=camp:2,chamber:1
		for kv in String(args.steps).split(","):
			var p: PackedStringArray = kv.split(":")
			Save.d.jstep["%d:%s" % [Save.area(), p[0]]] = int(p[1])
	if args.has("scroll"): Home.start_scroll = float(args.scroll)
	if args.has("rise"): Home.rise = true
	if args.has("dive"): Home.dive = float(args.dive)
	if args.has("card_h"): Reveal.info_h = float(args.card_h)
	if args.has("chips"): Reveal.chips_max = int(args.chips)
	if args.has("story_auto"): StoryScene.auto = true   # the home screen as after the prologue: up from the bottom to the guide
	if args.has("mine_event"):
		if args.mine_event == "maiden": MineView.force_maiden = true    # (comes with the next event, ~10-16 s)
		else: MineView.force_event = args.mine_event
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
		Save.d.atlas = {}
		for st in Save.d.coll: Save.note_find(st, int(st.area), int(st.dl))
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
	if args.has("skulls"):
		# test data: skulls (SpecSkull, docs/skulls.md) with their genes mixed, `-- save=skulls screen=stones skulls[=N]`;
		# marked test, old ones from a previous run are replaced. Every few is pinned to show one gene clearly.
		Save.d.coll = Save.d.coll.filter(func(c: Dictionary) -> bool: return c.get("form", "") != "skull")
		var sps := ["amethyst", "venom", "morion", "cinnabar", "celestine", "smoky", "quartz", "fluorite"]
		var pins := [{}, {show = "rock"}, {moss = "cap", trees = 3}, {flies = 3}, {eyes = "both", crown = false}, {fangs = "all"},
			{milk = "wax", tone = "grave"}, {dmg = "broken"}, {show = "rock", rock_kind = "boulder"}, {tone = "ash"},
			{milk = "frost"}, {moss = "patches", flies = 2}, {show = "rock", rock_kind = "perched"}, {lie = "side", show = "rock"},
			{fangs = "some", eyes = "one"}, {}, {flies = 2, fly_kind = "comet"}, {moss = "cap", show = "rock"}, {}, {flies = 3, fly_kind = "blue"},
			{skin = "glass"}, {skin = "gold", crown = false, eyes = "none"}, {skin = "kintsugi", crown = false, eyes = "none"},
			{skin = "gilt", tone = "ash"}, {skin = "silver", crown = false, eyes = "both"}, {skin = "copper", show = "rock"}, {skin = "nacre"}, {skin = "nacre", flies = 2}, {moss = "cap", trees = 3, stream = true, tone = "ash", crown = false, eyes = "none"},
			{roots = true, crown = false, eyes = "none", moss = "none"}, {bloom = true, bloom_pal = 0, crown = true, moss = "none"}, {bloom = true, bloom_pal = 1, crown = true},
			{moss = "cap", trees = 3, tree_kind = "blossom"}, {moss = "cap", trees = 2, tree_kind = "autumn", show = "rock"}, {roots = true, tree_kind = "leaves", show = "rock", rock_kind = "slab"}]
		# skulls=water: only skulls with a stream from the eye (bone, nacre, gilt; on a rock, with moss, plain)
		if String(args.skulls) == "water":
			pins = [{}, {show = "rock"}, {moss = "cap"}, {skin = "nacre"}, {skin = "gilt"}, {crown = false, eyes = "none"},
				{show = "rock", rock_kind = "boulder"}, {lie = "side", show = "rock"}, {moss = "patches", trees = 2}, {tone = "ash", crown = false}]
			for k in pins.size():
				pins[k].stream = true
				pins[k].wine = k % 3 == 1   # (every third a scarlet spring)
		# skulls=new: the stone bones, the dressings and the skull's own legends (one each, bare enough to see them)
		if String(args.skulls) == "new":
			var nb := {moss = "none", trees = 0, flies = 0, stream = false, roots = false, pile = 0, coins = false, diadem = false, lantern = false, show = "loose"}
			pins = [{skin = "agate"}, {skin = "opal"}, {skin = "pyrite"}, {skin = "geode"}, {skin = "bone", coins = true},
				{skin = "bone", diadem = true, eyes = "both"}, 
				{skin = "bone", legend = true, fx = "yaga"}, {skin = "bone", legend = true, fx = "candle"}, {skin = "bone", legend = true, fx = "watching"},
				{skin = "bone", legend = true, fx = "deathless"}, {skin = "bone", legend = true, fx = "flutter"}, {skin = "bone", legend = true, fx = "fireflies"}]
			for k in pins.size():
				var pn: Dictionary = nb.duplicate()
				pn.merge(pins[k], true)
				pins[k] = pn
		# skulls=metal: cast in gold, copper and silver, two of each (one on a rock)
		if String(args.skulls) == "metal":
			pins = [{skin = "gold"}, {skin = "copper"}, {skin = "silver"}, {skin = "gold", show = "rock"}, {skin = "copper", show = "rock"}, {skin = "silver", show = "rock"}]
		var n := int(args.skulls) if String(args.skulls).is_valid_int() and int(args.skulls) > 1 else pins.size()
		for i in n:
			var st := Stones.roll(90000 + i * 13, 0, 1.2, i % 6)
			st.sid = sps[i % sps.size()]
			st.kind = "druse"
			st.traits = []
			st.legend = false
			st.form = "skull"
			st.test = true
			st.merge(pins[i % pins.size()], true)
			st.tier = Stones.tier_of(st.sid, int(st.gi), false)
			st.area = 0
			st.dl = i % 6
			Save.d.coll.append(st)
		Save.persist()
	if args.has("mine4"):
		# test data: Fire Horizon's finds, a few of each species as the mine rolls them: `-- screen=stones mine4`;
		# marked test (admin → Remove test finds), old ones from a previous run are replaced
		var want := {sulphur = 3, aragonite = 3, obsidian = 5, fulgurite = 2, olivine = 3, realgar = 3, hematite = 4, simetite = 2}
		Save.d.coll = Save.d.coll.filter(func(c: Dictionary) -> bool: return not (c.get("test", false) and int(c.get("area", 0)) == 3))
		var sd := 81000
		while want.size():
			var st := Stones.roll(sd, 3, 1.2, sd % 6)
			sd += 1
			if not want.has(st.sid): continue
			want[st.sid] = int(want[st.sid]) - 1
			if int(want[st.sid]) <= 0: want.erase(st.sid)
			st.area = 3
			st.dl = sd % 6
			st.test = true
			Save.d.coll.append(st)
			if not st.sid in Save.d.seen: Save.d.seen.append(st.sid)
			Save.note_find(st, 3, int(st.dl))
		Save.persist()
	if args.has("tab"):
		Museum.start_tab = args.tab
	if args.has("atlas"):
		Atlas.start_area = int(args.atlas)
	if args.has("screen"):
		go(args.screen)
	elif args.has("maiden"):   # the Fire Maiden's chase (docs/fire-maiden.md): her card first, `go` - straight to the board
		_play_maiden(not args.has("go"))
	elif args.has("level"):
		var dl := int(args.get("depth", "0"))
		show_level(int(args.level), [], dl, LevelGen.current(dl) if args.has("gen") else {})
	else:
		_boot()
	if args.has("ui"):
		await get_tree().create_timer(float(args.get("ui_after", "0"))).timeout
		if screen.has_method("_" + args.ui): screen.call("_" + args.ui)
		# the end-of-level card and a toast, without playing (playtest 31.10)
		elif args.ui == "win_card": _win_card({n = Save.d.level, coins = 152, mined = {iron = 11, ore = 9}})
		elif args.ui == "kit_toast": Ov.toast("Added to the inventory")
	if args.has("tap"):
		# real taps at points of the screen (pt), ui_after s apart: `-- screen=museum tap=370,400` or `tap=200,300;180,700`
		for pt in String(args.tap).split(";"):
			await get_tree().create_timer(float(args.get("ui_after", "1"))).timeout
			var xy: PackedStringArray = pt.split(",")
			for down in [true, false]:
				var ev := InputEventMouseButton.new()
				ev.button_index = MOUSE_BUTTON_LEFT
				ev.pressed = down
				ev.position = Vector2(float(xy[0]), float(xy[1]))
				ev.global_position = ev.position
				Input.parse_input_event(ev)
				await get_tree().process_frame
	if args.has("lens"): Save.d.eq.lens = int(args.lens)
	if args.has("alive"):
		# the admin's "All animations on" for the current mine: `-- screen=home area=1 alive`
		Admin._alive()
	if args.has("story_card"):
		# settings → Story so far, for a look: `-- screen=home tut=prologue,s_knock story_card`
		get_tree().create_timer(float(args.get("ui_after", "1"))).timeout.connect(Chrome.story_card)
	if args.has("admin"):
		# the tester's panel, for a look: `-- screen=home admin`
		get_tree().create_timer(float(args.get("ui_after", "1"))).timeout.connect(Admin.open)
	if args.has("hoard"):
		# a look at the boss's reward: `-- screen=home hoard lens=2` (not awaited: the other keys go on)
		_hoard_demo()
	if args.has("find_seeds"):   # find_seeds=pyrite,400: the seeds whose stone (as `reveal` rolls it) is that species
		var fs := String(args.find_seeds).split(",")
		for sd in range(1, int(fs[1]) + 1):
			var st := Stones.roll(sd, Save.area(), 0.8, 1)
			if st.sid == fs[0]: print("seed ", sd, " tier ", st.tier, " value ", st.value, " traits ", st.get("traits", []))
		get_tree().quit()
		return
	if args.has("reveal"):
		var st := Stones.roll(int(args.reveal), Save.area(), 0.8, 1)
		st.integ = 86
		if args.has("sid"): st.sid = args.sid
		if args.has("kind"): st.kind = args.kind
		if args.has("gi"): st.gi = int(args.gi)
		if args.has("shroom"): st.shroom = int(args.shroom)
		if args.has("traits"): st.traits = Array(args.traits.split(","))
		# a skull and its genes: form=skull skin=gold moss=cap ...
		if args.get("form", "") == "skull":
			st.form = "skull"
			for k in ["skin", "moss", "eyes", "milk", "tone", "show", "rock_kind", "dmg", "fangs", "tree_kind"]:
				if args.has(k): st[k] = args[k]
			for k in ["trees", "flies", "bloom_pal"]:
				if args.has(k): st[k] = int(args[k])
			for k in ["stream", "roots", "bloom", "crown"]:
				if args.has(k): st[k] = args[k] == "1"
		if args.has("legend"):
			st.legend = true
			st.tier = 4
			if args.legend != "1": st.fx = args.legend
		# open the callouts as soon as the stone is built: `callouts` (all) or `callouts=<gene id>` (that one picked)
		if args.has("callouts"): Reveal.auto_callouts = args.callouts
		if args.has("callouts_at"): SpecCallouts.freeze = float(args.callouts_at)
		if args.has("crack"): GeodeOpen.run([st])
		else: Reveal.new().show_stone(st)
	if args.has("geodes"):   # geodes=N [tiers=0,2,4] [auto] [short]: the opening of N geodes (GeodeOpen), `auto` plays it through
		GeodeOpen.auto = args.has("auto")
		var opts := {short = true, title = "Your find"} if args.has("short") else {}
		var tiers := Array(String(args.get("tiers", "")).split(",", false))
		var list := []
		for i in int(args.geodes):
			var st := Stones.roll(Save.next_uid(), Save.area(), 0.6, 1)
			if i < tiers.size():
				st.tier = int(tiers[i])
				if st.tier >= 4: st.legend = true
			list.append(st)
		get_tree().create_timer(0.6).timeout.connect(func(): GeodeOpen.run(list, opts))
	if args.has("story"):   # story=poloz_after [story_at=N]: a story scene over the screen, N lines on (StoryScene.SCENES)
		get_tree().create_timer(0.8).timeout.connect(func():
			var s := StoryScene.play(self, args.story)
			for i in int(args.get("story_at", "0")): s.call_deferred("_next"))
	if args.has("taps"):   # taps=S1,S2,...: a tap at the middle of the screen at those seconds, as a finger would
		for t in args.taps.split(","):
			get_tree().create_timer(float(t)).timeout.connect(func():
				var at := get_viewport().get_visible_rect().size / 2
				for down in [true, false]:
					var e := InputEventScreenTouch.new()
					e.position = at
					e.pressed = down
					Input.parse_input_event(e)
				print("tap ", t))
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
	if args.has("sim_maiden"):
		# sim_maiden=N [moves=M] [smart]: the Fire Maiden's chase played N times (tests/sim_economy.gd)
		print(SimEconomy.maiden_report(int(args.sim_maiden), int(args.get("moves", "-1"))))
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
	# achievements done since the last screen: a toast each time one is noticed (not over a board)
	if not n is Level: Awards.check.call_deferred()
	if Reveal.chips_max > 0 and n is CanvasItem: (n as CanvasItem).visible = false   # the showcase: the card alone, its glow whole
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
	# a newcomer does not start on the empty mine: the prologue's cave-in first (docs/onboarding.md)
	if _prologue_due():
		show_level(0, [], 0, Level.PROLOGUE)
		return
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
		"atlas":
			var at := Atlas.new()
			_swap(at)
			at.go.connect(go)
			at.replay.connect(_replay_boss)
		"museum":
			var cb := Cabinet.new()
			_swap(cb)
			cb.go.connect(go)
		"stones":
			var m := Museum.new()
			_swap(m)
			m.go.connect(go)
		"maiden": _play_maiden()
		"awards":
			var aw := Awards.new()
			_swap(aw)
			aw.go.connect(go)

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
	if args.has("lab"):
		_lab(lv, String(args.lab))
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

## a beaten boss fought again from the atlas: the fight is that mine's (its board, frame, music), so the mine is
## switched for it and switched back after (Save.d.area_back brings it back if the game closes mid-fight)
var _replay := -1
var _replay_tier := 1
func _replay_boss(a: int) -> void:
	Save.tick_lives()
	if Save.d.lives <= 0:
		Ov.toast("No lives: next in %d min" % Save.minutes_to_life())
		return
	_replay = a
	_replay_tier = mini(Awards.TIERS, Awards.tier_of(a) + 1)
	Save.d.area_back = Save.d.area
	Save.d.area = a
	Save.persist()
	show_level(Save.d.level, [], Data.depths(a).size(), LevelGen.boss_fight(a, _replay_tier))
	if _replay_tier > 1:
		Ov.toast("%s %s: more health, fewer moves" % [Awards.TIER_N[_replay_tier], Data.AREAS[a].boss.n])

## the prologue plays once, for a new game in the first mine (`prologue` shows it anyway; test runs go without it)
func _prologue_due() -> bool:
	if args.has("prologue") and not Save.told("prologue"): return true
	if Coach.off or Save.told("prologue") or Save.area() != 0 or int(Save.d.level) > 1: return false
	for w in Save.d.dwins:
		if int(w) > 0: return false
	return true

## the Fire Maiden's chase (Level.MAIDEN, docs/fire-maiden.md): in Old Adit's gold whatever mine you are in (the mine
## is switched for the chase, as for a boss replayed), no life spent; once a week
var _maiden_back := -1
func _play_maiden(card := true) -> void:
	# her card first: who she is and how to catch her
	if card: await _maiden_intro()
	if not _maiden_go: return
	_maiden_back = Save.d.area
	Save.d.area_back = Save.d.area
	Save.d.area = 0
	Save.d.maiden_day = int(Time.get_unix_time_from_system() / 86400.0)
	Save.persist()
	show_level(Save.d.level, [], 0, Level.MAIDEN)

var _maiden_go := true
func _maiden_intro() -> void:
	_maiden_go = false
	var v := Ov.card(330, Color(1.0, 0.6, 0.2))
	v.add_child(_maiden_portrait(230))
	v.add_child(UI.title("The Fire Maiden", 22))
	v.add_child(Ov.text("She leaps out of the prospectors' fire and dances. Wherever she lands, the stone turns to gold.", 14))
	v.add_child(Ov.text("Break the stone she dances on to catch her. Five times - and she leaves you her own gold.", 13, Kit.AMBER))
	v.add_child(Ov.btn("Dance!", "green", func():
		_maiden_go = true
		Ov.close()))
	v.add_child(Ov.btn("Not now", "glass", func(): Ov.close()))
	await Ov.closed

## her portrait by the campfire (art/maiden), `h` points high
static func _maiden_portrait(h: float) -> Control:
	var t := TextureRect.new()
	t.texture = load(MaidenView.DIR + "portrait.png")
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	t.custom_minimum_size = Vector2(0, h)
	t.clip_contents = true
	return t

func _maiden_done(res: Dictionary) -> void:
	Save.d.area = int(Save.d.area_back)
	Save.d.area_back = -1
	Save.d.coins += int(res.coins)
	Save.persist()
	if not (res.stone as Dictionary).is_empty():
		await GeodeOpen.run([res.stone], {title = "Where she danced", short = true})
	var v := Ov.card(330, Color(1.0, 0.6, 0.2))
	v.add_child(_maiden_portrait(150))
	v.add_child(UI.title("The Fire Maiden", 22))
	var all := int(res.caught) >= BoardModel.MAIDEN_CATCH
	v.add_child(Ov.text("Caught all five times! She left her gold where she danced." if all else
		"Caught %d of %d times. She ran off laughing - but the gold is yours." % [int(res.caught), BoardModel.MAIDEN_CATCH], 14))
	var got := HBoxContainer.new()
	got.alignment = BoxContainer.ALIGNMENT_CENTER
	got.add_child(_res_chip("coin", int(res.coins)))
	v.add_child(got)
	v.add_child(Ov.text("%d gold stones broken. She'll dance again in a week." % int(res.gold), 12, Kit.DIM))
	v.add_child(Ov.btn("Continue", "green", func(): Ov.close()))
	await Ov.closed
	go("awards")

func _on_level_finished(res: Dictionary) -> void:
	if res.get("maiden", false):
		await _maiden_done(res)
		return
	if res.get("prologue", false):
		# dug out: the camera rises through the mine to the one with the lantern (Home.rise)
		Save.tell("prologue")
		# (lost - hardly possible with its moves - the mine opens plainly)
		Home.rise = res.won
		show_home()
		return
	if _replay >= 0:
		await _replay_done(res)
		return
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
			Ov.close(false)
			await GeodeOpen.run([hs], {title = "From the hoard of %s" % String(Data.AREAS[Save.area()].boss.n), short = true})
		if not res.stone.is_empty():
			# the find dug out on the board: the same opening as a geode's, one tap
			await GeodeOpen.run([res.stone], {title = "Your find", short = true})
		await GeodeOpen.run(res.bonus)
		await _win_card(res)
	show_home()

func _replay_done(res: Dictionary) -> void:
	var a := _replay
	_replay = -1
	Save.d.area = int(Save.d.area_back)
	Save.d.area_back = -1
	Save.persist()
	if res.won:
		var bt: Array = Save.d.boss_tier
		while bt.size() <= a: bt.append(0)
		bt[a] = maxi(int(bt[a]), _replay_tier)
		Save.persist()
		var v := Ov.card()
		v.add_child(UI.title("%s is beaten again" % Data.AREAS[a].boss.n, 22))
		if _replay_tier > 1: v.add_child(Ov.text("%s · %d of %d" % [Awards.TIER_N[_replay_tier], _replay_tier, Awards.TIERS], 15, Kit.AMBER))
		var got := HBoxContainer.new()
		got.alignment = BoxContainer.ALIGNMENT_CENTER
		got.add_child(_res_chip("coin", int(res.coins)))
		v.add_child(got)
		v.add_child(Ov.btn("Continue", "green", func(): Ov.close()))
		await Ov.closed
	Atlas.start_area = -1
	go("atlas")

## the end-of-level card: coins, iron and ore as the kit's badges, the win streak with the specials it gives
func _win_card(res: Dictionary) -> void:
	var v := Ov.card()
	var badge := Kit.res_icon("coin", 56)
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(badge)
	v.add_child(UI.title("Level %d complete!" % res.n, 22))
	if res.get("boss", false):
		v.add_child(Ov.text("%s is beaten. The way to the next mine is open." % Data.AREAS[Save.area()].boss.n))
	var line := HBoxContainer.new()
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	line.add_theme_constant_override("separation", 18)
	line.add_child(_res_chip("coin", int(res.coins)))
	var mined: Dictionary = res.get("mined", {})
	if int(mined.get("iron", 0)): line.add_child(_res_chip("iron", int(mined.iron)))
	if int(mined.get("ore", 0)): line.add_child(_res_chip("ore", int(mined.ore)))
	v.add_child(line)
	if Save.d.streak >= 1:
		v.add_child(Kit.rule(200))
		v.add_child(streak_row(Save.d.streak))
	else:
		v.add_child(Ov.text("Iron sinks the shaft deeper, %s fits out the mine." % String(Data.ore(Save.area()).n).to_lower()))
	var go := Ov.btn("Continue", "green", func(): Ov.close())
	v.add_child(go)
	await Ov.closed

## "+N" after a resource's badge, as in the top bar
static func _res_chip(kind: String, n: int) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	var ic := Kit.res_icon(kind, 30)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	h.add_child(Kit.label("+" + UI.fmt(n), 20, UI.display, Kit.AMBER))
	return h

## the win streak in one short line: the count, then the specials the next level starts with as the board draws
## them; before the first gift, how many wins are left for it
static func streak_row(streak: int) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	var t := Kit.label("Win streak %d" % streak, 17, UI.display, Kit.AMBER)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 6)
	v.add_child(h)
	var free := Data.streak_free(streak)
	var sps := []
	var say := ""
	if free.is_empty():
		var left := int(Data.STREAK_AT.rocket) - streak
		say = "%s more and the level starts with" % ("1 win" if left == 1 else "%d wins" % left)
		sps = ["rh"]
	else:
		say = "The next level starts with"
		for p in Data.PRE:
			if p.id in free: sps.append(String(p.sp[0]))
	h.add_child(Kit.label(say, 13, UI.body, Kit.CREAM))
	for sp: String in sps:
		var ic := UI.icon(34, func(ci: Control): BoardSprites.draw(ci, BoardSprites.tex(sp), Vector2(17, 17), 34))
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(ic)
	return v

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

## lab=<what>: a special set off in the middle of the board a moment after it settles, to film it frame by frame
## (`shot=... frames=N every=S`): rh, rv, bomb, drill, orb (a single special), or two side by side swapped together:
## rh+rv, bomb+rh, bomb+bomb, orb+bomb, orb+orb, drill+bomb...
func _lab(lv: Level, what: String) -> void:
	await get_tree().create_timer(1.6).timeout
	while lv.busy: await get_tree().create_timer(0.05).timeout
	var r := lv.model.R / 2
	var c := lv.model.C / 2 - 1
	var sps := what.split("+")
	for i in sps.size():
		var g: BoardModel.Gem = lv.model.G[r][c + i]
		if g == null: return
		g.sp = sps[i]
		g.t = -1
		g.ore = ""
		lv.board.convert_gem(g.id, g.sp)
	await get_tree().create_timer(0.5).timeout
	if sps.size() == 1: lv._on_tap(r, c)
	else: lv._on_swipe(r, c, r, c + 1)

## plays a few moves by itself, for screenshots of a level in motion
func _autoplay(lv: Level, turns: int) -> void:
	await get_tree().create_timer(1.2).timeout
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in turns:
		while lv.busy: await get_tree().create_timer(0.1).timeout
		if lv.model.over: return
		# `smart`: the moves the smart autoplayer would make (tests/sim_economy.gd), to see a level played for its goals
		var mv: Array = SimEconomy._choose_smart(lv.model, rng) if args.has("smart") else lv.model.find_move()
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
		if i > 0: await get_tree().create_timer(float(args.get("every", "0.1")), true, false, true).timeout
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var path: String = args.shot if n == 1 else String(args.shot).get_basename() + "_%d.png" % i
		img.save_png(path)
		print("shot saved: ", ProjectSettings.globalize_path(path))
	get_tree().quit()
