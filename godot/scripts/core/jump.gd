class_name Jump
## (22.11) the admin's "Start at mine N": a save as a player's who has just come through mines 1…N−1 honestly — a
## collector, who keeps what is new to him and sells the rest. Not a list of things set by hand: the career is played
## out level by level through the game's own code. Each level is the one the game would make (LevelGen, BoardModel —
## its find, its geodes, the collector's luck, its obstacles, its banner), only its play is not played: whether it is
## won and what it brings (iron, ore, the board's coins, the find dug out and how whole, the geodes opened) come from
## the smart autoplayer's averages on real boards (CAL, tests/jump_calib.tscn). Then as in the game: the coins of a
## win, the veins running down, a find noted in the atlas and the awards' collections (Save.note_find) and kept or
## sold, building a job step by step as soon as the ore pays for it and its chest, the drill as soon as iron and coins
## do, the boss beaten and a stone from his hoard, the awards claimed as they come, the next mine (Save.open_mine).
## What the player would have seen on the way — the story's scenes, the guide's lines, the board's tips and banners —
## is marked as seen; the mine jumped to starts fresh, its own lines still to come.
##
## Not played: what only a played board knows (a cascade of ten, a win on the last move, a boss's own feats — the
## awards from those stay to be earned), boosters spent, lives lost.

## per mine: [won share, iron, ore, the board's coins, a find there, dug out, its wholeness, geodes there, opened] — a
## won level's means over the mine's depths (tests/jump_calib -- area=N n=8 smart, 22.11: 8 levels a depth is too few
## to tell the depths apart, the mine's mean is steadier). A mine not measured takes the last one's
const CAL := {
	0: [0.79, 10.98, 9.6, 38.06, 0.4, 0.4, 70.0, 0.13, 0.13],
	1: [0.85, 10.54, 10.48, 44.59, 0.6, 0.6, 71.0, 0.01, 0.01],
	2: [0.81, 10.18, 9.79, 41.06, 0.53, 0.53, 80.0, 0.15, 0.15],
	3: [0.81, 10.41, 10.18, 39.54, 0.57, 0.57, 77.0, 0.15, 0.15],
	4: [0.72, 10.58, 11.64, 35.42, 0.43, 0.43, 73.0, 0.27, 0.27],
}

## the stones the old man gives and the first one dug up are the game's own (Stones.PICKED), as in a real start
## cap_wins > 0 (26.11, the admin's «24 wins»): Old Adit only, played till that many wins — no boss, nothing after
static func career(to_area: int, seed_v := 1, cap_wins := 0) -> Dictionary:
	var t0 := Time.get_ticks_msec()
	var keep_prefs := {}
	for k in ["mute", "no_music", "no_buzz", "gem_style", "ore_look", "lock_style", "zone_style", "prof"]:
		if Save.d.has(k): keep_prefs[k] = Save.d[k]
	Save.d = Save.blank()
	for k in keep_prefs: Save.d[k] = keep_prefs[k]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var was_off := Coach.off
	Coach.off = false     # (the first stone of one's own, the collector's luck: as a real game has them)
	var log := {levels = 0, wins = 0, kept = 0, sold = 0, claimed = [], mines = []}
	# the prologue: the cave-in, the old man, his gift kept (Home._rise)
	for id in ["prologue", "g_hello_0", "swap", "goals"]: Save.tell(id)
	var gift := Stones.picked("gift", 0, 0.8, 1)
	gift.gift = true
	_take(gift, 0, 0, true, log)
	Save.tell("gift_got")
	for a in to_area:
		var m := _mine(a, rng, log, cap_wins)
		if cap_wins > 0:
			log.mines.append(m)
			_claim_all(log)
			break
		log.mines.append(m)
		_claim_all(log)
		if a + 1 < Data.AREAS.size():
			Save.open_mine(a + 1)
	# what the guide and the board's tips have said by now
	for id in ["g_ore", "g_build", "g_drill", "g_deeper", "g_rich", "c_next", "c_build", "c_atlas", "t_inv", "t_geode", "find",
			"sp_rocket", "sp_bomb", "sp_drill", "sp_orb"]:
		Save.tell(id)
	for n: String in Awards.said_ready(): Save.tell("say:" + n)
	Save.d.lives = Save.MAX_LIVES
	Save.d.streak = 0
	Save.d.owed = []
	Save.d.hoard_due = -1
	Save.d.in_level = false
	Coach.off = was_off
	Awards.check(true)
	Save.persist()
	log.ms = Time.get_ticks_msec() - t0
	return log

## one mine played through: levels at its deepest open depth till every job is built and the last depth dug, then its boss
static func _mine(a: int, rng: RandomNumberGenerator, log: Dictionary, cap_wins := 0) -> Dictionary:
	var A: Dictionary = Data.AREAS[a]
	var tasks: Array = A.tasks
	var depths: Array = Data.depths(a)
	var last := depths.size() - 1
	var m := {n = String(A.n), levels = 0, wins = 0, finds = 0, ore = 0, fe = 0}
	if a > 0: Save.tell("g_hello_%d" % a)
	var guard := 0
	while guard < 600:
		guard += 1
		if cap_wins > 0 and int(m.wins) >= cap_wins: return m
		_spend(a)
		var dl := int(Save.d.depth[a])
		var all_built := tasks.all(func(t: Array) -> bool: return (Save.d.built[a] as Array).has(t[0]))
		if all_built and dl >= last: break
		# what holds him up this level: the job's ore, or the drill's iron or coins
		var why := "ore"
		if dl < tasks.size() and String(tasks[dl][0]) in Save.d.built[a] and dl < last:
			var D: Dictionary = depths[dl + 1]
			why = "iron" if Save.d.fe < int(D.drill[0]) else "coins"
		m[why + "_wait"] = int(m.get(why + "_wait", 0)) + 1
		_level(a, dl, rng, log, m)
	_story(a)
	if A.has("boss"): _boss(a, rng, log)
	return m

## build and dig while the player can, as he would: a job's step as soon as the ore pays for it, the drill as soon as
## the job is built and iron and coins are there (Home._build, Home._dig)
static func _spend(a: int) -> void:
	var tasks: Array = Data.AREAS[a].tasks
	var acted := true
	while acted:
		acted = false
		var dl := int(Save.d.depth[a])
		for i in tasks.size():
			var t: Array = tasks[i]
			var tid := String(t[0])
			if tid in Save.d.built[a] or i > dl: continue
			var price := MineView.step_cost(a, tid, int(t[2]))
			if Save.d.ore < price: break
			Save.d.ore -= price
			var done := MineView.job_step(a, tid) + 1
			if done < MineView.job_steps(a):
				Save.d.jstep["%d:%s" % [a, tid]] = done
			else:
				Save.d.jstep.erase("%d:%s" % [a, tid])
				Save.d.built[a].append(tid)
				var ch: Dictionary = Data.CHEST[i] if i < Data.CHEST.size() else {coins = 100}
				if ch.get("coins", 0): Save.d.coins += Data.priced(int(ch.coins), a)
				if ch.get("pick", 0): Save.d.boost.pick += int(ch.pick)
				if ch.get("bore_h", 0): Save.d.boost.bore_h += int(ch.bore_h)
				if ch.has("pre"): Save.d.pre[ch.pre] += 1
			acted = true
			break
		if acted: continue
		var depths: Array = Data.depths(a)
		if dl < depths.size() - 1 and dl < tasks.size() and String(tasks[dl][0]) in Save.d.built[a]:
			var D: Dictionary = depths[dl + 1]
			var fe := int(D.drill[0])
			var cn := Data.drill_coins(a, int(D.drill[1]))
			# short of coins only: he sells his duplicates (the inventory's button: the best of every species stays, and
			# the last with every gene the awards show)
			if Save.d.fe >= fe and Save.d.coins < cn:
				var dup := Museum.dupes()
				if dup.size():
					for st: Dictionary in dup:
						Save.d.coins += roundi(float(st.value) * Save.coin_mul())
						Save.gone(st)
						Save.d.aw_sold[String(st.sid)] = Save.now_ms() - 3600000
						Save.d.coll.erase(st)
			if Save.d.fe >= fe and Save.d.coins >= cn:
				Save.d.fe -= fe
				Save.d.coins -= cn
				Save.d.depth[a] = dl + 1
				Save.d.depth_sel[a] = dl + 1
				acted = true

## a level at depth dl: the game's board, played by the averages
static func _level(a: int, dl: int, rng: RandomNumberGenerator, log: Dictionary, m: Dictionary) -> void:
	Save.d.depth_sel[a] = dl
	var def := LevelGen.current(dl)
	var model := BoardModel.new()
	model.rng.seed = int(Save.d.lseed)
	model.setup(int(Save.d.level), [], dl, Save.d.eq, a, true, def)
	log.levels += 1
	m.levels += 1
	_seen(model, a, dl)
	var c: Array = _cal(a, dl)
	if rng.randf() >= float(c[0]):
		Save.d.streak = 0
		Save.level_played(false, dl)
		return
	log.wins += 1
	m.wins += 1
	var coins_won := maxf(0.0, float(c[3]) * rng.randf_range(0.5, 1.5))
	Save.d.coins += roundi((20 + coins_won) * Data.depth_pay(dl) * Save.coin_mul() * float(Level.HARD_PAY.get(model.beat, 1.0)) * Data.mine_k(a))
	var mined := [maxi(0, roundi(float(c[1]) * rng.randf_range(0.7, 1.3))), maxi(0, roundi(float(c[2]) * rng.randf_range(0.7, 1.3)))]
	# a vein worked down to its last tenth gives a third (the board's ore is that much thinner — BoardModel, mine_chain)
	var got := [0, 0]
	for i in 2:
		var left: int = int(Save.d.vein[dl][i]) if dl < Save.d.vein.size() else 0
		var stock := Level.vein_stock(dl, i)
		var room := maxi(0, left - BoardModel.vein_floor(stock))
		var full := mini(int(mined[i]), room)
		got[i] = full + (int(mined[i]) - full) / 3
	Save.d.fe += got[0]
	Save.d.ore += got[1]
	m.fe = int(m.fe) + got[0]
	m.ore = int(m.ore) + got[1]
	if dl < Save.d.vein.size():
		for i in 2: Save.d.vein[dl][i] = Level.vein_after(dl, i, int(mined[i]))
	Save.d.level = int(Save.d.level) + 1
	Save.d.streak += 1
	# the find: dug out as often as the autoplayer digs one out of a board that has it, as whole as his
	if not model.find.is_empty() and rng.randf() < float(c[5]) / maxf(float(c[4]), 0.01):
		model.find.integ = clampi(roundi(float(c[6]) + rng.randf_range(-18, 18)), 30, 100)
		if rng.randf() < 0.25: model.find.integ = 100
		model.find.done = true
		var st := model.extracted_stone()
		m.finds += 1
		_take(st, a, dl, false, log)
	# the geodes cracked open (BoardModel: a stone each)
	var share := float(c[8]) / maxf(float(c[7]), 0.01)
	for g in model.geos.size():
		if rng.randf() >= share: continue
		var gs := Stones.roll(Save.next_uid(), a, 0.5 + dl * 0.35, dl)
		if a == 0 and BoardModel.first_own_due(): gs = Stones.picked("first_own", 0, 0.5 + dl * 0.35, dl)
		_take(gs, a, dl, false, log)
	Save.level_played(true, dl)
	Awards.check(true)
	_claim_all(log)

## the board's tips and banner as a player sees them the first time (Level._coach_next, Level._banner)
static func _seen(model: BoardModel, a: int, dl: int) -> void:
	var th := Level.board_theme(model)
	if String(th[0]) != "": Save.tell("ban:" + String(th[0]))
	var kind := LevelGen.new_kind(dl, a)
	if Home.ROCK_LINE.has(kind): Save.tell("g_rock_" + kind)
	for r in model.R:
		for c in model.C:
			if model.ROCK[r][c] > 0: Save.tell("sand" if model.ROCK_MAX[r][c] < 2 else "granite")
			if model.MUD[r][c] > 0: Save.tell("mud")
			if model.GAS[r][c] > 0: Save.tell("gas")
			var lk: int = model.LOCK[r][c]
			if lk == 1: Save.tell("lock")
			elif lk == 2: Save.tell("crust")
			elif lk == 3: Save.tell("tentacle")
			elif lk == 4 or lk == 5: Save.tell("ice")
			elif lk == 6: Save.tell("metal")
			elif lk == 7: Save.tell("ink")
			if model.CART[r][c] >= 0: Save.tell("cart")
			if model.KEG[r][c] > 0: Save.tell("keg")
			if model.DARK[r][c] > 0: Save.tell("dark")
			if model.BELT[r][c] >= 0: Save.tell("belt")
			if model.BUCKET[r][c] > 0: Save.tell("bucket")
			if model.NOD[r][c] > 0: Save.tell("nod")
			if model.POT[r][c] > 0: Save.tell("pot")
			if model.TUBE[r][c] >= 0: Save.tell("tube")
	if not model.tide.is_empty(): Save.tell("t_tide")

## a stone that came the player's way: noted (the atlas, the awards' collections), then kept if it is new to the
## collector — a species, a gene not seen yet, a record of its kind, a legendary — else sold (Reveal: Keep / Sell)
static func _take(st: Dictionary, a: int, dl: int, always: bool, log: Dictionary) -> void:
	var aid := Stones.atlas_id(st)
	var gs: Array = Awards.genes_of(st)
	var fresh: bool = not Save.d.atlas.has(aid) or bool(st.get("legend", false))
	for g in gs:
		if not (Save.d.genes as Array).has(g): fresh = true
	if Save.d.atlas.has(aid) and int(st.value) > int((Save.d.atlas[aid] as Dictionary).get("max_v", 0)): fresh = true
	Save.note_find(st, a, dl)
	if always or fresh:
		Save.d.coll.append(Reveal.kept_entry(st, {id = st.id, sid = st.sid, kind = st.get("kind", "crystal"), gi = st.gi,
			traits = st.get("traits", []), legend = st.get("legend", false), g = st.g, value = st.value, tier = st.tier, area = a, dl = dl}))
		log.kept += 1
	else:
		Save.d.coins += roundi(float(st.value) * Save.coin_mul())
		Save.gone(st)
		# (a career played in a moment: every sale "a minute ago" would make Second Thoughts of any find after it)
		Save.d.aw_sold[String(st.sid)] = Save.now_ms() - 3600000
		log.sold += 1
	# the Scholar comes for the first stone of his own; her atlas shown
	if not Save.told("s_sister_meet") and a == 0 and String(st.sid) != "pyrite":
		Save.tell("s_sister_meet")
		Save.tell("c_atlas")

## the story's scenes the mine has shown by the time its boss is beaten (Home._story_beat)
static func _story(a: int) -> void:
	if a == 0:
		for id in ["s_sister_meet", "s_knock", "s_notebook", "s_poloz_before"]: Save.tell(id)
	if a == 4:
		for id in ["s_proval_arrive", "s_proval_letter", "s_proval_heart", "s_proval_dwarf", "s_proval_voice", "s_proval_gate"]: Save.tell(id)

## the boss: beaten (a fight or two lost first, as it goes), his hoard's stone, the scene after
static func _boss(a: int, rng: RandomNumberGenerator, log: Dictionary) -> void:
	var lost := rng.randi_range(0, 2)
	Save.d.boss_tries[a] = lost
	log.levels += lost + 1
	log.wins += 1
	Save.d.boss_won[a] = true
	var bt: Array = Save.d.boss_tier
	while bt.size() <= a: bt.append(0)
	bt[a] = maxi(int(bt[a]), 1)
	var last := Data.depths(a).size() - 1
	Save.d.coins += roundi((20 + 60) * Data.depth_pay(last) * Data.mine_k(a))
	Save.d.level = int(Save.d.level) + 1
	# the hoard (Hoard.pick): nine stones of its luck; the lens shows a few — the best of three is taken
	var best := {}
	for k in 3:
		var s := Stones.roll(Save.next_uid(), a, [0.6, 1.2, 2.2][k], Data.depths(a).size())
		if best.is_empty() or int(s.value) > int(best.value): best = s
	_take(best, a, last, true, log)
	if a == 0: Save.tell("s_poloz_after")
	# the frame he gives (ProfileCard.award_frame): looked at
	for e: Dictionary in Profile.FRAMES:
		if int(e.get("area", -1)) == a: (Save.d.prof_seen as Array).append("frame:" + String(e.id))
	Awards.check(true)
	_claim_all(log)

## every award that is ready, claimed as the player would (Awards.claim), without its show: a geode's stone goes the
## way of any find
static func _claim_all(log: Dictionary) -> void:
	for round_n in 4:
		var any := false
		for e: Dictionary in Awards.LIST:
			if Awards._state(e) != "ready": continue
			any = true
			var gv := Awards.give_of(e)
			Save.d.aw_got.append(String(e.n))
			log.claimed.append(String(e.n))
			Save.d.coins += int(gv.get("coins", 0))
			Save.d.lives += int(gv.get("lives", 0))
			var bo: Dictionary = gv.get("boost", {})
			for id in bo: Save.d.boost[id] = int(Save.d.boost.get(id, 0)) + int(bo[id])
			if gv.has("unlock") and not (Save.d.unlocks as Array).has(String(gv.unlock)): Save.d.unlocks.append(String(gv.unlock))
			if gv.has("geode"):
				var a := Save.area()
				var dl := int(Save.d.depth[a])
				_take(Stones.roll(Save.next_uid(), a, [0.6, 1.2, 2.2][clampi(int(gv.geode), 0, 2)], dl), a, dl, false, log)
		if not any: break
		Awards.check(true)

static func _cal(a: int, _dl: int) -> Array:
	return CAL.get(a, CAL[CAL.keys().max()])

# ---------------------------------------------------------------- a point to come back to
const POINT := "user://jump_point.json"

## the save as it is now, put by (one point: a new one replaces it)
static func save_point() -> void:
	Save.persist()
	var f := FileAccess.open(POINT, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(Save.d))

static func has_point() -> bool:
	return FileAccess.file_exists(POINT)

## back to the point put by: the save replaced by it (the game then starts again from its loading screen)
static func load_point() -> bool:
	if not has_point(): return false
	var j: Variant = JSON.parse_string(FileAccess.get_file_as_string(POINT))
	if not (j is Dictionary): return false
	Save.d = j
	Save.persist()
	return true
