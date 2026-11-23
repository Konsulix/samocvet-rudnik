extends Node
## The app: switches between screens (home, level, depot, museum) and owns the HDR glow pass.
## Command-line extras after `--` for testing:  level=5  depth=2  shot=user://shot.png  after=3.5  autoplay=6

var screen: Node
var args := {}

## the game is closing (the level, a child, has already left the tree): free what outlives levels (Level.release_pool)
func _taps(spec: String, gap: float) -> void:
	for pt in spec.split(";"):
		await get_tree().create_timer(gap).timeout
		# (`x,y@S`: the finger held S s before it lets go — a press that straddles something coming up)
		var hold := float(pt.get_slice("@", 1)) if "@" in pt else 0.0
		var xy: PackedStringArray = pt.get_slice("@", 0).split(",")
		for down in [true, false]:
			if not down and hold > 0.0: await get_tree().create_timer(hold).timeout
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = down
			ev.position = Vector2(float(xy[0]), float(xy[1]))
			ev.global_position = ev.position
			Input.parse_input_event(ev)
			await get_tree().process_frame

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
	if args.has("winsize"):
		# a test key (-- winsize=1320x2868): the window that size even past the screen (the OS caps it at start) - App Store
		# screenshots at the store's own size, not a small window scaled up
		var wh := String(args.winsize).split("x")
		get_window().size = Vector2i(int(wh[0]), int(wh[1]))
	if args.has("bake_skulls"):
		# the skull bodies (human and beasts) shaded once and stored as .res: the phone skips the json and the smoothing
		print("baked %d skull bodies" % SpecSkull.bake())
		get_tree().quit()
		return
	if args.has("bake_shaders"):
		# the shaders written as text, as files for the export's shader baker (ShaderFiles); the iOS build runs this
		print("baked %d shaders into %s" % [ShaderFiles.bake(), ShaderFiles.DIR])
		get_tree().quit()
		return
	# the 2D glow pass: off, it showed nothing (no HDR 2D, so nothing passes its threshold) and cost a full-screen
	# blur every frame; `glow` turns it back on to compare
	if args.has("glow"): _setup_glow()
	if args.has("nomusic"): Sfx.no_music = true
	if args.has("uv"): Spec.force_uv = float(args.uv)
	# the tutorial: `tut` shows it from the start; test runs (shots, autoplay, sims) go without it
	# (`tut=swap,goals` starts as if those tips were already shown, to see the next ones; `quiet` - none, for recordings)
	if args.has("jump_point"):
		# the admin's point to come back to: `-- save=x jump_point=save|load` (then quits)
		if args.jump_point == "save": Jump.save_point()
		else: print("JUMP point loaded: ", Jump.load_point())
		print("JUMP point: area %d, level %d, inventory %d" % [Save.area(), int(Save.d.level), (Save.d.coll as Array).size()])
		get_tree().quit()
		return
	if args.has("jump"):
		# (22.11) the admin's "Start at a mine" from the command line: `-- save=j jump=3 [jseed=1] [screen=home]`
		var lg := Jump.career(int(args.jump), int(args.get("jseed", "1")))
		print("JUMP ", JSON.stringify({levels = lg.levels, wins = lg.wins, kept = lg.kept, sold = lg.sold, ms = lg.ms, mines = lg.mines, claimed = lg.claimed}))
		print("JUMP state: area %d, level %d, coins %d, iron %d, ore %d, inventory %d, atlas %d, genes %d, awards %d" % [Save.area(), int(Save.d.level), int(Save.d.coins), int(Save.d.fe), int(Save.d.ore), (Save.d.coll as Array).size(), Save.d.atlas.size(), (Save.d.genes as Array).size(), (Save.d.aw_got as Array).size()])
		if args.has("jump_quit"):
			get_tree().quit()
			return
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
	if args.has("fly_big"): SpecButterfly.fly_big = float(args.fly_big)
	if args.has("fly_in"):
		var q := String(args.fly_in).split(",")
		SpecButterfly.fly_in = Vector3(float(q[0]), float(q[1]), float(q[2]))
	if args.has("chips"): Reveal.chips_max = int(args.chips)
	if args.has("gulp_test"): Reveal.gulp_test = true
	# (the lightning's leap out of a find into its card, CardBolt: the first S s after the stone is built, then every 3 s)
	if args.has("card_bolt"): CardBolt.test_at = float(args.card_bolt)
	# (the frost bloom's card, CardFrost: frost_period=S — its cycle S s long, starting at once)
	if args.has("frost_period"): CardFrost.test_period = float(args.frost_period)
	if args.has("lava_every"): CardLava.test_every = float(args.lava_every)
	if args.has("kin_every"): CardKintsugi.test_every = float(args.kin_every)
	if args.has("kin_flip"): CardKintsugi.test_flip = float(args.kin_flip)
	if args.has("kin_mend"): CardKintsugi.test_mend = true
	if args.has("flies_every"): CardFlies.test_every = float(args.flies_every)
	if args.has("aurora_pal"): SpecPolar.test_pal = int(args.aurora_pal)
	if args.has("lev_tap"): CardLevitate.test_tap = float(args.lev_tap)
	if args.has("flies_spot"): CardFlies.test_spot = int(args.flies_spot)
	if args.has("frost_code"): CardFrost.photo = false
	# (the hunt's ribbon in a state, for pictures: hunt=N fights won, +g the geode opened, +x just lost — hunt=3, hunt=4g, hunt=4gx)
	if args.has("hunt_step"):
		HuntRibbon.step = true
		HuntRibbon.test = {won = 0, geode = false, lost = false}
	if args.has("hunt"):
		var hv := String(args.hunt)
		HuntRibbon.test = {won = int(hv), geode = "g" in hv, lost = "x" in hv}
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
		for b in SpecFlower.SPRIGS.flower:
			want.append(["flower_quartz", func(g: Dictionary) -> bool: return g.sprig == b[0]])
		for c in ["wasp", "spider", "beetle", "cicada", "dragonfly", "moth", "mantis", "other"]:
			want.append(["amber", func(g: Dictionary) -> bool: return g.content == "insect" and g.insect == c])
		for c in ["flower", "fern"]:
			for e: Array in SpecFlower.SPRIGS[c]:
				want.append(["amber", func(g: Dictionary) -> bool: return g.get("sprig", "") == e[0]])
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
			st.tier = Stones.tier_of(st.sid, int(st.gi), bool(st.get("legend", false)))
			st.area = 0
			st.dl = i % 6
			Save.d.coll.append(st)
			if not sid in Save.d.seen: Save.d.seen.append(sid)
	# (tests: the swallowed find given back as it was)
	if args.has("ungulp"):
		for st: Dictionary in Save.d.coll: st.erase("gulp")
	if args.has("seafloor"):
		# test data: a sea find on its slab for each swimmer and each small fish of the living sea floor (SpecReef), ammonites and trilobites
		# in turn: `-- save=<name> screen=stones seafloor`; old ones from a previous run are replaced
		Save.d.coll = Save.d.coll.filter(func(c: Dictionary) -> bool: return not c.get("seafloor", false))
		var sd := 90000
		var i := 0
		for sw: String in SpecReef.group("swim") + SpecReef.group("fish"):
			var sid := "ammonite" if i % 2 == 0 else "trilobite"
			var st := {}
			while true:
				st = Stones.roll(sd, 2, 1.2, 2)
				st.sid = sid
				st.kind = "fossil"
				st.traits = []
				st.legend = false
				sd += 1
				var fg := SpecFossil.genes(int(st.id), sid, [])
				var rf: Dictionary = fg.get("reef", {})
				if fg.get("show", "") == "matrix" and (String(rf.get("swim", "")) == sw or String(rf.get("fish", "")) == sw): break
			st.tier = Stones.tier_of(st.sid, int(st.gi), false)
			st.area = 2
			st.dl = i % 6
			st.seafloor = true
			# (its card by itself: reveal=<id> sid=<sid> kind=fossil gi=<gi>)
			print("SEAFLOOR %s: reveal=%d sid=%s kind=fossil gi=%d" % [sw, int(st.id), sid, int(st.gi)])
			Save.d.coll.append(st)
			Save.note_find(st, 2, int(st.dl))
			i += 1
		Save.persist()
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
			{fangs = "some", eyes = "one"}, {}, {flies = 2, fly_kind = "bluebottle"}, {moss = "cap", show = "rock"}, {}, {flies = 3, fly_kind = "peacock"},
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
		# skulls=beasts: an animal's skull of every kind (SpecSkull.BEASTS), their genes as they fall
		if String(args.skulls) == "beasts":
			pins = []
			var skins := ["bone", "lapis", "bone", "feathers", "sugar", "bone", "rhodo", "gilt", "bone", "kintsugi", "nacre", "bone", "gold", "agate", "bone", "opal"]
			for k in SpecSkull.BEASTS.size(): pins.append({beast = SpecSkull.BEASTS[k], skin = skins[k % skins.size()]})
			# (the open-mouthed and the jawed ones with a druse in the maw)
			for pn: Dictionary in pins:
				if pn.beast in ["wolf", "alligator", "trex"]: pn.maw = true
		# skulls=feathers: feathered beasts, every bird's coat twice (magpie, starling, pheasant, peacock, owl)
		if String(args.skulls) == "feathers":
			pins = []
			var who := ["raven", "fox", "mouflon", "wolf", "hornbill", "deer", "lion", "spoonbill", "ram", "horse"]
			for k in who.size(): pins.append({beast = who[k], skin = "feathers", feather_pal = k % 5})
		# skulls=flies: a skull for every kind of butterfly, three on each
		if String(args.skulls) == "flies":
			pins = []
			for fk: String in SpecButterfly.KINDS: pins.append({flies = 3, fly_kind = fk, fly_mode = 0})
		# skulls=flock: the legend "butterfly cloud" — seven of a kind resting on the skull, all up at once, round it and
		# down again — one skull for each of a few kinds (no bouquet: they would sit hidden under the flowers)
		if String(args.skulls) == "flock":
			pins = []
			for fk: String in ["peacock", "monarch", "bluebottle", "apollo", "bluetiger", "swallowtail"]:
				pins.append({legend = true, fx = "flutter", fly_kind = fk, bloom = false, moss = "none", trees = 0})
		# skulls=fireflies: the legend "firefly swarm" on a few skulls (a man's and beasts')
		if String(args.skulls) == "fireflies":
			pins = [{legend = true, fx = "fireflies", bloom = false}, {legend = true, fx = "fireflies", beast = "fox"},
				{legend = true, fx = "fireflies", beast = "deer"}, {legend = true, fx = "fireflies", skin = "nacre"}]
		# skulls=monarchs: skulls with monarch butterflies (an animated model, SpecButterfly.MODELS), some sitting, some flying
		if String(args.skulls) == "monarchs":
			pins = []
			for b: String in ["", "fox", "wolf", "deer", "", "horse"]:
				var pn := {flies = 3, fly_kind = "monarch", fly_mode = 0}
				if b != "": pn.beast = b
				pins.append(pn)
		# skulls=legends: an animal's skull with each of its own legends (SpecBeastFx), and the ghost of several
		if String(args.skulls) == "legends":
			pins = []
			for pr: Array in [["deer", "blossom"], ["ram", "starhorn"], ["longhorn", "thunder"], ["fox", "foxfire"], ["wolf", "wolfmoon"],
				["bear", "breath"], ["raven", "phoenix"], ["raven", "raveneye"], ["trex", "lavaborn"], ["triceratops", "amberdrop"],
				["horse", "ghost"], ["fox", "ghost"], ["longhorn", "ghost"], ["trex", "ghost"]]:
				pins.append({beast = pr[0], legend = true, fx = pr[1]})
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
			st.tier = Stones.tier_of(st.sid, int(st.gi), bool(st.get("legend", false)))
			st.area = 0
			st.dl = i % 6
			Save.d.coll.append(st)
		Save.persist()
	if args.has("shrooms"):
		# test data: a find with every kind of mushroom and every look of it (SpecFungi.KINDS; the honey fungus on its
		# driftwood): `-- save=shrooms screen=stones shrooms`; marked test, old ones from a previous run are replaced
		Save.d.coll = Save.d.coll.filter(func(c: Dictionary) -> bool: return not c.get("shrooms", false))
		# (a lone crystal or a small pile on open rock: the mushrooms have room and are plain to see)
		var hosts := ["garnet", "quartz", "fluorite", "calcite", "amethyst"]
		var sd := 120000
		var made := 0
		for kind in SpecFungi.KINDS.size():
			for look in (SpecFungi.KINDS[kind].looks as Array).size():
				var st := {}
				while true:
					st = Stones.roll(sd, 0, 1.2, 2)
					sd += 1
					st.traits = []
					st.legend = false
					if kind == 4:
						st.sid = "petrified_wood"
						st.kind = "fossil"
						var wg := SpecFossil.genes(int(st.id), "petrified_wood", [])
						if String(wg.show) == "driftwood" and bool(wg.fungi): break
						continue
					st.sid = hosts[sd % hosts.size()]   # (a host that never grows them alone would hang the search)
					st.kind = "crystal"
					st.shroom = kind
					if SpecFungi.find_look(int(st.id), kind) != look: continue
					var gn := SpecGenome.of(Spec.of_stone(st))
					if "mushrooms" in (gn.accents as Array) and String(gn.form) in ["single", "pile"]: break
				st.tier = Stones.tier_of(st.sid, int(st.gi), false)
				st.area = 0
				st.dl = made % 6
				st.value = Stones.price(st, 0, int(st.dl))
				st.test = true
				st.shrooms = true
				Save.d.coll.append(st)
				if not st.sid in Save.d.seen: Save.d.seen.append(st.sid)
				Save.note_find(st, 0, int(st.dl))   # (the atlas and the achievements know them, as finds of a level)
				made += 1
		Save.persist()
	if args.has("kin_inv"):
		# test data: a kintsugi amethyst and four broken stones for it to mend (CardKintsugi): `-- save=kin screen=stones
		# kin_inv ui=open_n card=0 ui_after=2`; marked test, the old ones replaced
		Save.d.coll = Save.d.coll.filter(func(c: Dictionary) -> bool: return not c.get("kin_inv", false))
		var ks := Stones.roll(301, 0, 0.8, 1)
		ks.sid = "amethyst"
		ks.kind = "crystal"
		ks.legend = true
		ks.fx = "kintsugi"
		ks.tier = 4
		ks.integ = 100
		ks.area = 0
		ks.dl = 1
		ks.value = Stones.price(ks, 0, 1)
		ks.test = true
		ks.kin_inv = true
		Save.d.coll.append(ks)
		var k := 0
		for sd in [4101, 4202, 4303, 4404]:
			var st := Stones.roll(sd, 0, 0.8, 1)
			st.legend = false
			st.erase("fx")
			st.integ = [30, 45, 62, 76][k]
			st.tier = Stones.tier_of(st.sid, int(st.gi), false)
			st.area = 0
			st.dl = 1
			st.value = roundi(Stones.price(st, 0, 1) * float(Stones.condition(int(st.integ))[2]))
			st.test = true
			st.kin_inv = true
			Save.d.coll.append(st)
			k += 1
		Save.persist()
	if args.has("lumps"):
		# test data: the lumps that are no crystals, hurt by a careless dig (RockKit.chip) — copper in vein quartz, a copper
		# nugget, malachite's lump and its sawn slab, each the same stone at integrity 100, 60 and 30:
		# `-- save=lumps screen=stones lumps`; marked test, old ones from a previous run are replaced
		Save.d.coll = Save.d.coll.filter(func(c: Dictionary) -> bool: return not c.get("lumps", false))
		var want := [["nativecu", "vein"], ["nativecu", "vein"], ["nativecu", "nugget"], ["malachite", "botryoid"], ["malachite", "sawn"]]
		var sd := 170000
		var made := 0
		for w: Array in want:
			var base := {}
			for t in 4000:
				sd += 1
				var st := Stones.roll(sd, 1, 1.2, 2)
				st.sid = w[0]
				st.kind = "crystal"
				st.legend = false
				if String(SpecGenome.of(Spec.of_stone(st)).form) == String(w[1]):
					base = st
					break
			if base.is_empty(): continue
			for ig in [100, 60, 30]:
				var st: Dictionary = base.duplicate(true)
				st.integ = ig   # (the same id: the same stone, only hurt more — sell one and its twins may go with it, test only)
				st.tier = Stones.tier_of(st.sid, int(st.gi), false)
				st.area = 1
				st.dl = 2
				st.value = Stones.price(st, 1, 2)
				st.test = true
				st.lumps = true
				Save.d.coll.append(st)
				if not st.sid in Save.d.seen: Save.d.seen.append(st.sid)
				made += 1
		print("lumps: ", made, " finds")
		Save.persist()
	if args.has("hugs"):
		# test data: lone crystals half sunk in a side of their rock (SpecimenBuilder._hug_rock), a few of each species:
		# `-- save=hugs screen=stones hugs`; marked test, old ones from a previous run are replaced
		Save.d.coll = Save.d.coll.filter(func(c: Dictionary) -> bool: return not c.get("hugs", false))
		var hosts := ["quartz", "amethyst", "smoky", "calcite", "garnet", "fluorite", "beryl", "aquamarine"]
		var sd := 160000
		var made := 0
		for h in hosts.size() * 2:
			var st := {}
			for t in 4000:
				sd += 1
				if Rng32.new((sd * 1812433253 + 97) % 4294967296).next() >= SpecimenBuilder.HUG_P: continue
				st = Stones.roll(sd, 0, 1.2, 2)
				st.sid = hosts[h % hosts.size()]
				st.kind = "crystal"
				st.legend = false
				if String(SpecGenome.of(Spec.of_stone(st)).form) == "single": break
				st = {}
			if st.is_empty(): continue
			st.tier = Stones.tier_of(st.sid, int(st.gi), false)
			st.area = 0
			st.dl = made % 6
			st.value = Stones.price(st, 0, int(st.dl))
			st.test = true
			st.hugs = true
			Save.d.coll.append(st)
			if not st.sid in Save.d.seen: Save.d.seen.append(st.sid)
			made += 1
		print("hugs: ", made, " finds")
		Save.persist()
	if args.has("tourmalines"):
		# test data: a tourmaline of every colour (SpecForms.TOURM), and a polished slice of each: `-- save=tm screen=stones tourmalines`
		Save.d.coll = Save.d.coll.filter(func(c: Dictionary) -> bool: return not c.get("tourmalines", false))
		var sd := 330000
		for form: String in ["pencils", "slice"]:
			for e: Array in SpecForms.TOURM:
				while String(SpecForms.tourm_of(sd)[0]) != String(e[0]): sd += 1
				var st := Stones.roll(sd, 0, 1.2, 2)
				st.sid = "tourmaline"
				st.kind = "crystal"
				st.form = form
				st.traits = []
				st.area = 0
				st.dl = 2
				st.integ = 100
				st.tourmalines = true
				st.test = true
				st.value = Stones.price(st, 0, 2)
				Save.d.coll.append(st)
				sd += 1
	if args.has("enhydros"):
		# test data: clear crystals with a water pocket (the "enhydro" trait), whole: `-- save=enh screen=stones enhydros`
		Save.d.coll = Save.d.coll.filter(func(c: Dictionary) -> bool: return not c.get("enhydros", false))
		var sd := 210000
		var made := 0
		while made < 10 and sd < 260000:
			sd += 1
			var st := Stones.roll(sd, 0, 1.2, 2)
			if not st.sid in ["quartz", "amethyst", "calcite", "fluorite"] or st.get("kind", "") != "crystal": continue
			var tr: Array = st.get("traits", [])
			# (as the game has them: not in a dark crystal, nor with a phantom)
			if "phantom" in tr or String(SpecGenome.of(st).lustre) == "dark": continue
			if not "enhydro" in tr: tr.append("enhydro")
			st.traits = tr
			st.area = 0
			st.dl = 2
			st.integ = 100
			st.enhydros = true
			st.test = true
			Save.d.coll.append(st)
			made += 1
		print("enhydros: ", made)
	if args.has("opals"):
		# test data: a dozen opals as Whalebone Cove gives them (boulder, black, jelly, pseudomorphs, geodes), whole:
		# `-- save=opals screen=stones opals`; marked test, old ones from a previous run are replaced
		Save.d.coll = Save.d.coll.filter(func(c: Dictionary) -> bool: return not c.get("opals", false))
		var sd := 190000
		var made := 0
		var geodes := 0
		while made < 12 and sd < 400000:
			sd += 1
			var st := Stones.roll(sd, 2, 1.2, 8)
			if st.sid != "opal": continue
			# (geodes are rare — 0.6 to 5 — but are what is being looked at: four of them, the rest as they come)
			var geo := String(st.get("kind", "")) == "geode"
			if geo and geodes >= 4: continue
			if not geo and made - geodes >= 8: continue
			if geo:
				# (each rare side of an egg shown once — rolled they are a 20–25% chance — and one crazed by the dig)
				var extra: Array = [[], ["halves"], ["inner_light"], ["pocket"]][geodes]
				if extra.size(): st.accents = extra
				geodes += 1
			st.area = 2
			st.dl = 8
			# (the first egg and the first two others hurt by the dig: crazing, broken pieces)
			st.integ = 35 if (geo and geodes == 1) or (not geo and made - geodes < 2) else 100
			st.opals = true
			st.test = true
			Save.d.coll.append(st)
			made += 1
		print("opals: ", made, " geodes: ", geodes)
	if args.has("flowers"):
		# test data: two finds with every kind of flower (SpecFlora.KINDS), on open rock: `-- save=flowers screen=stones
		# flowers`; marked test, old ones from a previous run are replaced (the kind is the stone's seed's: searched for)
		Save.d.coll = Save.d.coll.filter(func(c: Dictionary) -> bool: return not c.get("flowers", false))
		var hosts := ["garnet", "quartz", "fluorite", "calcite", "amethyst"]
		var sd := 140000
		var made := 0
		for kind in SpecFlora.KINDS.size():
			for k in 2:
				var st := {}
				var tries := 0
				while tries < 20000:
					tries += 1
					sd += 1
					if SpecFlora.roll(sd) != kind: continue
					st = Stones.roll(sd, 0, 1.2, 2)
					st.traits = []
					st.legend = false
					st.sid = hosts[sd % hosts.size()]
					st.kind = "crystal"
					var gn := SpecGenome.of(Spec.of_stone(st))
					if "flowers" in (gn.accents as Array) and String(gn.form) in ["single", "pile"]: break
					st = {}
				if st.is_empty(): continue
				st.tier = Stones.tier_of(st.sid, int(st.gi), false)
				st.area = 0
				st.dl = made % 6
				st.value = Stones.price(st, 0, int(st.dl))
				st.test = true
				st.flowers = true
				Save.d.coll.append(st)
				if not st.sid in Save.d.seen: Save.d.seen.append(st.sid)
				made += 1
		print("flowers: ", made, " finds")
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
	if args.has("aw_tab"):   # the awards' tab (screen=awards): tales, coll, mines, boss, mastery, secrets
		Awards.tab = args.aw_tab
	if args.has("aw_scroll"): Awards.start_scroll = int(args.aw_scroll)   # (its list scrolled down by N, for a shot)
	if args.has("atlas"):
		Atlas.start_area = int(args.atlas)
	if args.has("screen"):
		go(args.screen)
	elif args.has("hunt_next"):    # the hunt's next step as the card's button plays it: `-- save=x hunt_next [autoplay=N smart]`
		go("stones")
		hunt_next()
	elif args.has("gulp"):     # the plesiosaur's hunt for a swallowed find (Level.GULP): `-- gulp [autoplay=N smart]`
		play_hunt()
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
		# real taps at points of the screen (pt), ui_after s apart: `-- screen=museum tap=370,400` or `tap=200,300;180,700`;
		# with tap_bg they go on by themselves and the keys after (reveal=…) are not held up till they are done
		if args.has("tap_bg"): _taps(String(args.tap), float(args.get("ui_after", "1")))
		else: await _taps(String(args.tap), float(args.get("ui_after", "1")))
	if args.has("lens"): Save.d.eq.lens = int(args.lens)
	if args.has("alive"):
		# the admin's "All animations on" for the current mine: `-- screen=home area=1 alive`
		Admin._alive()
	if args.has("story_card"):
		# settings → Story so far, for a look: `-- screen=home tut=prologue,s_knock story_card`
		get_tree().create_timer(float(args.get("ui_after", "1"))).timeout.connect(Chrome.story_card)
	# the admin's "+16 beast skulls" at once (`-- save=x adm_beasts screen=stones`)
	# (with adm_count they count as found: the atlas's rows of bones fill)
	if args.has("adm_count"): Save.d.adm_count = true
	if args.has("adm_beasts"): Admin._beast_set()
	if args.has("admin"):
		# the tester's panel, for a look: `-- screen=home admin`
		# (admin=species|legend|traits: one of its lists; adm_scroll=N: the panel scrolled down; adm_add: the species
		# list in its add-at-a-tap way)
		if args.has("adm_scroll"): Admin._keep = int(args.adm_scroll)
		if args.has("adm_add"): Admin.add_now = true
		var what: Callable = {species = Admin.pick_species, legend = Admin.pick_legend, traits = Admin.pick_traits}.get(String(args.admin), Admin.open)
		get_tree().create_timer(float(args.get("ui_after", "1"))).timeout.connect(what)
		# (adm_tap=x,y[;x,y]: taps on the panel once it is open, 0.8 s apart — the plain `tap` comes before it opens)
		if args.has("adm_tap"):
			var at := float(args.get("ui_after", "1"))
			for pt in String(args.adm_tap).split(";"):
				at += 0.8
				var xy: PackedStringArray = pt.split(",")
				get_tree().create_timer(at).timeout.connect(func():
					for down in [true, false]:
						var ev := InputEventMouseButton.new()
						ev.button_index = MOUSE_BUTTON_LEFT
						ev.pressed = down
						ev.position = Vector2(float(xy[0]), float(xy[1]))
						ev.global_position = ev.position
						Input.parse_input_event(ev)
						await get_tree().process_frame)
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
		if args.has("acc"): st.accents = Array(String(args.acc).split(","))
		if args.has("flora"): st.flora = int(args.flora)
		if args.get("form", "") != "skull":
			if args.has("flies"): st.flies = int(args.flies)
			if args.has("fly_kind"): st.fly_kind = args.fly_kind
			if args.has("fly_mode"): st.fly_mode = int(args.fly_mode)
		# a skull and its genes: form=skull skin=gold moss=cap ...
		if args.get("form", "") == "skull":
			st.form = "skull"
			for k in ["skin", "moss", "eyes", "milk", "tone", "show", "rock_kind", "dmg", "fangs", "tree_kind", "beast", "horn", "fly_kind"]:
				if args.has(k): st[k] = args[k]
			for k in ["trees", "flies", "bloom_pal"]:
				if args.has(k): st[k] = int(args[k])
			for k in ["stream", "roots", "bloom", "crown", "maw"]:
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
	if args.has("sim_hunt"):
		# sim_hunt=N [smart] [sloppy=P] [hunt_only=i] [sim_seed=S]: the hunt's five levels, N boards each
		print(SimEconomy.hunt_report(int(args.sim_hunt)))
	if args.has("sim_gulp"):
		# sim_gulp=N [smart] [sloppy=P]: the plesiosaur's hunt played N times
		print(SimEconomy.gulp_report(int(args.sim_gulp)))
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
	if not n is Level and Reveal.chips_max == 0: Awards.check.call_deferred()   # no award toast over a showcase card
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
	b.done.connect(func():
		show_home()
		_settle())
	b.tree_exited.connect(layer.queue_free)

## (14.11) what a close left behind, settled at the start: a level left by closing the game is lost (a life, the
## streak); a beaten boss's hoard whose crystal was not picked comes again; stones earned and never kept or sold open
## again. Each of these lived only on its screen and was lost with it
func _settle() -> void:
	if Coach.off: return
	if bool(Save.d.in_level):
		Save.d.in_level = false
		Save.tick_lives()
		Save.d.streak = 0
		Save.d.lives = maxi(0, Save.d.lives - 1)
		if not Save.d.life_at: Save.d.life_at = Save.now_ms()
		Save.persist()
		Ov.toast("The level you left counts as a loss: −1 life")
	if int(Save.d.hoard_due) < 0 and Save.d.owed.is_empty(): return
	await get_tree().create_timer(1.2).timeout
	var ha := int(Save.d.hoard_due)
	if ha >= 0 and ha < Data.AREAS.size() and Data.AREAS[ha].has("boss"):
		var hs := await Hoard.pick(ha)
		Save.d.hoard_due = -1
		Save.owe(hs)
		Save.persist()
		Ov.close(false)
	elif ha >= 0:
		Save.d.hoard_due = -1
		Save.persist()
	if Save.d.owed.size():
		await GeodeOpen.run((Save.d.owed as Array).duplicate(true), {title = "Left unopened", short = (Save.d.owed as Array).size() == 1})

func show_home() -> void:
	# a newcomer does not start on the empty mine: the prologue's cave-in first (docs/onboarding.md)
	if _prologue_due():
		show_level(0, [], 0, Level.PROLOGUE)
		return
	var h := Home.new()
	_swap(h)
	h.play.connect(func(n: int, pre: Array, dl: int): show_level(n, pre, dl, LevelGen.current(dl)))
	h.go.connect(go)

## back to a mine already dug, or on to the furthest one (the Mines tab): its own ore, veins and depths come back
func _go_mine(a: int) -> void:
	var sold := Save.open_mine(a)
	Save.persist()
	show_home()
	Ov.toast("Back in %s" % Data.AREAS[a].n + (" · leftover ore sold for %s" % UI.coins(sold) if sold else ""))
	Stones.tell_legends(self)

func go(id: String) -> void:
	match id:
		"map": Chrome.mines_card(_go_mine)
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
		"hunt": play_hunt()
		"awards":
			var aw := Awards.new()
			_swap(aw)
			aw.go.connect(go)

func show_level(n: int, pre: Array, dl: int, level: Dictionary = {}) -> void:
	var lv := Level.new()
	_swap(lv)
	lv.finished.connect(_on_level_finished)
	# (14.11) a level being played: left by closing the game it counts as lost, a life and the streak, as the Leave
	# button does — not a free retry (the prologue and the Fire Maiden's chase cost no life either way)
	if level != Level.PROLOGUE and not level.get("maiden", false) and not level.get("gulp", false) and not level.has("hunt_lv") and not Coach.off:
		Save.d.in_level = true
		Save.persist()
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
	if args.has("finale"):
		# for a look: the level won as it stands - the specials left go off, then the moves left (`specials` puts some)
		await get_tree().create_timer(1.5).timeout
		lv.busy = true
		lv.model.over = true
		await lv._finale()
		print("finale done, coins ", lv.model.coins_won, ", specials left ",
			lv.model.G.reduce(func(n: int, row: Array) -> int: return n + row.filter(func(g) -> bool: return g != null and g.sp != "").size(), 0))
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
	MaidenCard.show(["She leaps out of the prospectors' fire and dances. Wherever she lands, the stone turns to gold."],
		"",
		[["Dance!", "green", func():
			_maiden_go = true
			Ov.close()], ["Not now", "dark", func(): Ov.close()]])
	await Ov.closed

## the plesiosaur's hunt (Level.GULP): the fight for the find he swallowed; its light is the find's own colour
func play_hunt() -> void:
	var def: Dictionary = Level.GULP.duplicate(true)
	for st: Dictionary in Save.d.coll:
		if st.get("gulp", false): def.glow = Data.rarity_color(int(st.get("tier", 1))).lerp(Color.WHITE, 0.35)
	if args.has("gulp_stage"): def.gulp_cfg = {stage0 = int(args.gulp_stage)}      # a test key: the board it starts on (0..2)
	if args.has("gk"):
		# gk=kelp_every:0/1/1,moves:30: the rules' numbers tried without touching the code (as in sim_gulp)
		var gcfg: Dictionary = def.get("gulp_cfg", {})
		for kv in String(args.gk).split(","):
			var v := kv.get_slice(":", 1)
			gcfg[kv.get_slice(":", 0)] = Array(v.split("/")).map(func(x: String) -> float: return float(x)) if "/" in v else float(v)
		def.gulp_cfg = gcfg
	if args.has("gulp_at"): def.gulp_cfg = (def.get("gulp_cfg", {}) as Dictionary).merged({start = float(args.gulp_at)})    # a test key: where the lump starts (0 mouth .. 1 belly)
	show_level(Save.d.level, [], 0, def)

## The hunt (HuntRibbon: three levels, a geode - a reward and the save point, two levels, the plesiosaur): the card's
## button plays what comes next. Save.d.hunt = {won: fights won 0..5, geode: opened, lost: the last one lost}
var _hunt_lv := -1
func hunt_next() -> void:
	var hs := HuntRibbon.state()
	if not Save.d.has("hunt"): Save.d.hunt = {won = 0, geode = false, lost = false, clean = true}
	Save.d.hunt.lost = false
	if HuntRibbon.at_geode(hs):
		await _hunt_geode()
		return
	if int(hs.won) >= HuntRibbon.FIGHTS - 1:
		play_hunt()
		return
	Save.tick_lives()
	if Save.d.lives <= 0:
		Ov.toast("No lives: next in %d min" % Save.minutes_to_life())
		return
	_hunt_lv = int(hs.won)
	# the cove's boards whatever mine you are in (switched back after, as for a boss replayed)
	if int(Save.d.area_back) < 0: Save.d.area_back = Save.d.area
	Save.d.area = 2
	Save.persist()
	var H: Dictionary = LevelGen.HUNT[_hunt_lv]
	show_level(Save.d.level, [], int(H.dl), LevelGen.hunt_level(_hunt_lv, randi()))

## halfway: a geode washed up (a deep cove's luck) - and the save point
func _hunt_geode() -> void:
	var st := Stones.roll(Save.next_uid(), 2, 2.2, Data.depths(2).size() - 1)
	Save.owe(st)
	Save.d.hunt.geode = true
	Save.persist()
	await GeodeOpen.run([st], {title = "Washed up on the hunt", short = true})
	Ov.panel("A save point", "Lose from here on and the hunt picks up at this geode, not from the start.", [
		["Hunt on", "green", func():
			Ov.close()
			hunt_next()],
		["Later", "dark", func():
			Ov.close()
			go("stones")]])

## a hunt level over: a step along the ribbon, or back to the start (or to the geode, once it is opened)
func _hunt_level_done(res: Dictionary) -> void:
	var i := _hunt_lv
	_hunt_lv = -1
	if int(Save.d.area_back) >= 0:
		Save.d.area = int(Save.d.area_back)
		Save.d.area_back = -1
	if not Save.d.has("hunt"): Save.d.hunt = {won = 0, geode = false, lost = false, clean = true}
	if res.won:
		Save.d.hunt.won = maxi(int(Save.d.hunt.won), i + 1)
		Save.d.hunt.lost = false
	else:
		Save.d.hunt.lost = true
		Save.d.hunt.clean = false        # (Never Let Go: the whole hunt without a loss)
		Save.d.hunt.won = 3 if bool(Save.d.hunt.get("geode", false)) else 0
	Save.persist()
	if res.won:
		if not (res.get("stone", {}) as Dictionary).is_empty(): await GeodeOpen.run([res.stone], {title = "Your find", short = true})
		await GeodeOpen.run(res.get("bonus", []))
	var hs := HuntRibbon.state()
	var later := ["Later", "dark", func():
		Ov.close()
		go("stones")]
	if not res.won:
		Ov.panel("It slipped away", HuntRibbon.line_text(hs), [["Hunt again", "green", func():
			Ov.close()
			hunt_next()], later])
	elif HuntRibbon.at_geode(hs):
		Ov.panel("Halfway", "Something washed up in his wake - a geode. And a save point.", [["Open the geode", "gold", func():
			Ov.close()
			hunt_next()], later])
	elif int(hs.won) >= HuntRibbon.FIGHTS - 1:
		Ov.panel("He is close", "+%s coins. The water stirs: the plesiosaur himself." % UI.fmt(int(res.get("coins", 0))), [["Face the plesiosaur", "ruby", func():
			Ov.close()
			hunt_next()], later])
	else:
		Ov.panel("On his trail", "+%s coins. %s" % [UI.fmt(int(res.get("coins", 0))), HuntRibbon.line_text(hs)], [["Hunt on", "green", func():
			Ov.close()
			hunt_next()], later])

## the plesiosaur beaten: the find back, his mark on it, coins and a geode of the cove's best luck
const HUNT_COINS := 1200
## won: the find is the player's again (its card as any stone's, and his mark on it); lost: it stays his, to be hunted again
func _hunt_done(res: Dictionary) -> void:
	var back := {}
	var coins := 0
	if not res.won and Save.d.has("hunt"):
		# back to the save point (the geode opened) or to the start
		Save.d.hunt.lost = true
		Save.d.hunt.clean = false
		Save.d.hunt.won = 3 if bool(Save.d.hunt.get("geode", false)) else 0
		Save.persist()
	if res.won:
		for st: Dictionary in Save.d.coll:
			if st.get("gulp", false):
				st.erase("gulp")
				st.gulped = true      # (it has been in his belly: a mark for later - its own trait, an award)
				back = st
		# the hunt's one award: all six fights in a row, not one lost
		if bool((Save.d.get("hunt", {}) as Dictionary).get("clean", true)): Awards.once("hunt_clean")
		Save.d.erase("hunt")
		coins = HUNT_COINS * Data.mine_k(2)
		Save.d.coins += coins
		var st := Stones.roll(Save.next_uid(), 2, 3.0, Data.depths(2).size() - 1)
		Save.owe(st)
		Save.persist()
		Sfx.play("coin")
		await GeodeOpen.run([st], {title = "From the plesiosaur's belly", short = true})
	if res.won:
		Ov.panel("He gave it back!", (("Your %s is yours again - a little wet." % Stones.name_of(back)) if not back.is_empty() else "The plesiosaur coughed it up and went under.") + " +%s coins." % UI.fmt(coins), [
			["To the inventory", "green", func():
				Ov.close()
				go("stones")]])
	else:
		Ov.panel("It went down", "The light went out in his belly. He is still out there - and so is your find.", [
			["Hunt again", "green", func():
				Ov.close()
				hunt_next()],
			["Later", "dark", func():
				Ov.close()
				go("stones")]])

func _maiden_done(res: Dictionary) -> void:
	Save.d.area = int(Save.d.area_back)
	Save.d.area_back = -1
	Save.d.coins += int(res.coins)
	Save.owe(res.stone)
	Save.persist()
	if not (res.stone as Dictionary).is_empty():
		await GeodeOpen.run([res.stone], {title = "Where she danced", short = true})
	var all := int(res.caught) >= BoardModel.MAIDEN_CATCH
	var got := HBoxContainer.new()
	got.alignment = BoxContainer.ALIGNMENT_CENTER
	got.add_child(_res_chip("coin", int(res.coins)))
	MaidenCard.show(["Caught all five times! She left her gold where she danced." if all else
		"Caught %d of %d times. She ran off laughing - but the gold is yours." % [int(res.caught), BoardModel.MAIDEN_CATCH]],
		"%d gold stones broken. She'll dance again in a week." % int(res.gold),
		[["Continue", "green", func(): Ov.close()]], got)
	await Ov.closed
	go("awards")

func _on_level_finished(res: Dictionary) -> void:
	Save.d.in_level = false
	if res.get("gulp", false):
		_hunt_done(res)
		return
	if _hunt_lv >= 0:
		await _hunt_level_done(res)
		return
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
	if res.won and res.get("boss", false): Save.d.hoard_due = Save.area()   # (closed before a crystal is picked, the hoard comes again)
	Save.persist()
	if res.won:
		if res.get("boss", false):
			# the boss's hoard: nine geodes, one to keep
			var hs := await Hoard.pick(Save.area())
			Save.d.hoard_due = -1
			Save.owe(hs)
			Save.persist()
			Ov.close(false)
			await GeodeOpen.run([hs], {title = "From the hoard of %s" % String(Data.AREAS[Save.area()].boss.n), short = true})
		if not res.stone.is_empty():
			# the find dug out on the board: the same opening as a geode's, one tap
			await GeodeOpen.run([res.stone], {title = "Your find", short = true})
		await GeodeOpen.run(res.bonus)
		await _win_card(res)
		# a boss beaten for the first time: its portrait frame (Profile)
		if res.get("boss", false): await ProfileCard.award_frame(Save.area())
	show_home()

func _replay_done(res: Dictionary) -> void:
	var a := _replay
	_replay = -1
	Save.d.area = int(Save.d.area_back)
	Save.d.area_back = -1
	# (a replay pays coins only: what its board freed is not shown, so not owed either)
	Save.paid((res.get("stone", {}) as Dictionary).get("id", -1))
	for b: Dictionary in res.get("bonus", []): Save.paid(b.get("id", -1))
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
