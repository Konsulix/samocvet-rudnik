extends Node
## The player's progress, kept in user://save.json. Same fields as the prototype's save.

signal changed

const PATH := "user://save.json"
## where this run keeps its progress: `-- save=NAME` plays on user://NAME.json instead (a fresh game, e.g. to walk
## through the start, leaves the real save alone)
var path := PATH
const LIFE_MS := 8 * 60 * 1000
const MAX_LIVES := 5
## the save's format; a save of another one is dropped
const VER := 2
## coins for each unit of a mine's own ore left over when the mine is done (a first guess)
const ORE_PRICE := 10

var d: Dictionary

func blank() -> Dictionary:
	var b := {
		ver = VER, level = 1, coins = 400, lives = 5, life_at = 0, area = 0,
		fe = 0, ore = 0, vein = [], rich = 0, lseed = 1 + randi() % 999999, lrich = false, dwins = [],
		boss_tries = [0, 0, 0], boss_won = [false, false, false],
		built = [[], [], []], jstep = {}, boost = {pick = 2, bore_h = 2, bore_v = 2, pan = 2}, btold = ["pick"], pre = {rocket = 1, bomb = 1, orb = 0}, streak = 0,
		eq = {lift = 0, crush = 0, food = 0, vent = 0, lens = 0}, depth = [0, 0, 0], depth_sel = [0, 0, 0],
		jewels = [], seen = [], coll = [], sets = [], atlas = {}, area_back = -1, uid = 1000, lab = 0, mute = false, no_music = false,
		gem_style = "natural", ore_look = "rendered", lock_style = "rendered", zone_style = "hewn",
		tut = [],
		# genes ever seen on a find (Awards.genes_of), and the find each first showed on (its niche on the awards
		# screen, the same summary as the atlas's best); gver 3 — the old finds read in
		genes = [], gfirst = {}, gver = 0,
		# the achievements (Awards): events counted as they happen, the ones noticed (toast given), the ones claimed,
		# rewards that are a thing to come (a series, a frame, a title), the last species found (Déjà vu)
		aw_ev = {}, aw_seen = [], aw_got = [], unlocks = [], aw_last = "", aw_sold = {}, aw_sig = [],
		# the highest tier each boss was beaten at (a replay from the atlas fights the next one)
		boss_tier = [],
		maiden_day = -100,   # the day the Fire Maiden last danced (once a week)
		# the mines: the furthest one reached, and what each mine left behind keeps till the player comes back to it
		# (its own ore, its veins, its wins by depth: open_mine)
		reached = 0, mines = {},
	}
	b.vein = fresh_veins(0)
	b.dwins = fresh_wins(0)
	_pad_areas(b)
	return b

## the lists kept per mine grow with the mines in the data (a save made before a mine was added gets its entries)
static func _pad_areas(x: Dictionary) -> void:
	var n := Data.AREAS.size()
	while x.built.size() < n: x.built.append([])
	while x.boss_tries.size() < n: x.boss_tries.append(0)
	while x.boss_won.size() < n: x.boss_won.append(false)
	while x.depth.size() < n: x.depth.append(0)
	while x.depth_sel.size() < n: x.depth_sel.append(0)

func _init() -> void:
	d = blank()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("save="): path = "user://%s.json" % a.substr(5)
	if FileAccess.file_exists(path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		# a save from before ore replaced stars starts over: there are no players yet to keep it for
		if parsed is Dictionary and int(parsed.get("ver", 0)) == VER:
			for k in parsed:
				if d.has(k) and d[k] is Dictionary and parsed[k] is Dictionary:
					d[k].merge(parsed[k], true)
				else:
					d[k] = parsed[k]
	# JSON brings numbers back as floats; the game counts in whole numbers
	for k in ["ver", "level", "coins", "lives", "life_at", "area", "fe", "ore", "rich", "lseed", "streak", "uid", "lab"]:
		d[k] = int(d[k])
	# the dynamite booster became the rock drill
	if d.boost.has("dyn"):
		d.boost.bore_h = int(d.boost.bore_h) + int(d.boost.dyn)
		d.boost.erase("dyn")
	for k in ["boost", "pre", "eq"]:
		for kk in d[k]:
			d[k][kk] = int(d[k][kk])
	for k in ["depth", "depth_sel"]:
		for i in d[k].size():
			d[k][i] = int(d[k][i])
	for i in d.dwins.size():
		d.dwins[i] = int(d.dwins[i])
	for i in d.boss_tries.size():
		d.boss_tries[i] = int(d.boss_tries[i])
	for v in d.vein:
		for i in v.size():
			v[i] = int(v[i])
	_pad_areas(d)
	# a mine that has grown deeper since the save was made: its new depths start with full veins
	var fv := fresh_veins(area())
	while d.vein.size() < fv.size(): d.vein.append(fv[d.vein.size()])
	while d.dwins.size() < fv.size(): d.dwins.append(0)
	# a boss fight replayed from the atlas switches the mine for the fight; closed during it, the game comes back here
	if int(d.area_back) >= 0:
		d.area = int(d.area_back)
		d.area_back = -1
	d.reached = maxi(int(d.reached), int(d.area))
	# the atlas came after the collection: the stones already kept are its first entries
	if d.atlas.is_empty():
		for s in d.coll:
			note_find(s, int(s.get("area", 0)), int(s.get("dl", 0)))
	looks_to_board()

## the atlas remembers every species ever found, whatever became of the stone: sid -> {best = the most valuable
## find of it (enough to build it again), n = how many were found, max_g, max_v, legend = a legendary one was found}
func note_find(s: Dictionary, a: int, dl: int) -> void:
	if s.has("first_of"): tell("first_find_%d" % int(s.first_of))
	if String(s.sid) == String(d.aw_last) and not d.aw_ev.has("twins"): d.aw_ev.twins = 1    # Awards: Déjà vu
	d.aw_last = String(s.sid)
	# the achievements' collections (docs/achievements.md): every gene this find shows
	var gs: Array = Awards.genes_of(s)
	Awards.note_pity(s, gs)   # (before its genes count as seen: did it bring a missing piece?)
	for t in gs:
		if not d.genes.has(t):
			d.genes.append(t)
			if String(t).begins_with("pair:"): d.aw_ev.pairs = int(d.aw_ev.get("pairs", 0)) + 1    # Awards: Matchmaker
		if not d.gfirst.has(t): d.gfirst[t] = Awards.summary(s, a, dl)
	# the achievements a find itself can bring (set straight in the save: this runs while the save loads too)
	var mk: Array = Awards.find_marks(s, gs)
	var sorted_g := gs.duplicate()
	sorted_g.sort()
	var sig := String(s.sid) + "|" + ",".join(sorted_g)
	if gs.size() >= 2 and (d.aw_sig as Array).has(sig): mk.append("twin_genes")
	elif gs.size() >= 2:
		d.aw_sig.append(sig)
		if d.aw_sig.size() > 500: d.aw_sig.pop_front()
	if d.aw_sold.has(String(s.sid)) and now_ms() - int(d.aw_sold[String(s.sid)]) <= 60000: mk.append("second")
	for m in mk:
		if not d.aw_ev.has(m): d.aw_ev[m] = 1
	var aid := Stones.atlas_id(s)
	var e: Dictionary = d.atlas.get(aid, {n = 0, max_g = 0, max_v = 0, legend = false})
	e.n = int(e.n) + 1
	e.max_g = maxi(int(e.max_g), int(s.g))
	e.max_v = maxi(int(e.max_v), int(s.value))
	e.legend = bool(e.legend) or bool(s.get("legend", false))
	if not e.has("best") or int(s.value) > int(e.best.value):
		var b := {id = s.id, sid = s.sid, kind = s.get("kind", "crystal"), gi = s.gi, traits = s.get("traits", []), legend = s.get("legend", false),
			g = s.g, value = s.value, tier = s.tier, area = a, dl = dl}
		for k in ["fx", "shroom", "form", "skin", "moss", "tree_kind", "stream", "wine", "flies", "fly_kind"]:
			if s.has(k): b[k] = s[k]
		e.best = b
	d.atlas[aid] = e

## a stone leaves the inventory (sold): for every gene it shows, it becomes the one the awards remember — once no
## stone with the gene is kept, its niche shows the last one that went, grey (not an older one popping back)
func gone(s: Dictionary) -> void:
	if bool(s.get("legend", false)): Awards.once("sold_legend")
	if is_gift(s): Awards.once("sold_gift")
	d.aw_sold[String(s.sid)] = now_ms()
	for t in Awards.genes_of(s):
		d.gfirst[t] = Awards.summary(s, int(s.get("area", 0)), int(s.get("dl", 0)))

## the old man's gift (the prologue's pyrite, Home.GIFTS): never a duplicate, sold only from its own card after he asks
static func is_gift(s: Dictionary) -> bool:
	return bool(s.get("gift", false)) or (int(s.get("id", 0)) in Home.GIFTS and String(s.get("sid", "")) == "pyrite")

## the tutorial (docs/onboarding.md): has this tip been shown
func told(id: String) -> bool:
	return d.tut.has(id)

func tell(id: String) -> void:
	if not d.tut.has(id):
		d.tut.append(id)
		persist()

## the board's looks from the save (the level's look panel writes them back)
func looks_to_board() -> void:
	BoardSprites.gem_style = d.gem_style if BoardSprites.GEM_STYLES.has(d.gem_style) else "natural"
	BoardSprites.ore_look = d.ore_look if BoardSprites.ORE_LOOKS.has(d.ore_look) else "rendered"
	BoardSprites.lock_style = d.lock_style if BoardSprites.LOCK_STYLES.has(d.lock_style) else "rendered"
	BoardSprites.zone_style = d.zone_style if BoardSprites.ZONE_STYLES.has(d.zone_style) else "hewn"

func persist() -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))
	changed.emit()

func reset() -> void:
	d = blank()
	persist()

## ids double as the seeds of finds: step by a random amount so every new game digs up different stones
func next_uid() -> int:
	d.uid += 1 + randi() % 9973
	return d.uid

func now_ms() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)

func tick_lives() -> void:
	if d.lives >= MAX_LIVES:
		d.life_at = 0
		return
	var t := now_ms()
	if not d.life_at:
		d.life_at = t
	while d.lives < MAX_LIVES and t - d.life_at >= LIFE_MS:
		d.lives += 1
		d.life_at += LIFE_MS
	if d.lives >= MAX_LIVES:
		d.life_at = 0

func minutes_to_life() -> int:
	if d.lives >= MAX_LIVES:
		return 0
	return int(ceil((LIFE_MS - (now_ms() - d.life_at)) / 60000.0))

func area() -> int:
	return mini(d.area, Data.AREAS.size() - 1)

## what is left in each depth's veins, [iron, the mine's own ore], full at the start of a mine
func fresh_veins(a: int) -> Array:
	var out := []
	for D in Data.depths(a):
		out.append([int(D.fe), int(D.au)])
	return out

## another mine, the next one or one already dug (the Mines tab): the one left keeps its ore, veins and wins for when
## the player comes back (d.mines); a mine come to for the first time starts with full veins. Ore left in a mine with
## every job built has nothing to buy there any more: it is sold (the coins returned)
func open_mine(a: int) -> int:
	var was := area()
	if a == was: return 0
	d.reached = reached()   # (the mine being left counts as reached: set straight by a test key, it may not be yet)
	var sold := 0
	var jobs: Array = Data.AREAS[was].get("tasks", [])
	if jobs.size() and jobs.all(func(t: Array) -> bool: return (d.built[was] as Array).has(t[0])):
		sold = int(d.ore) * ORE_PRICE
		d.coins += sold
		d.ore = 0
	d.mines[str(was)] = {ore = int(d.ore), vein = d.vein, dwins = d.dwins}
	var m: Dictionary = d.mines.get(str(a), {})
	d.mines.erase(str(a))
	d.area = a
	d.reached = maxi(int(d.reached), a)
	d.ore = int(m.get("ore", 0))
	var fv := fresh_veins(a)
	var vs: Array = []
	for i in fv.size():
		var old: Array = (m.vein as Array)[i] if m.has("vein") and i < (m.vein as Array).size() else fv[i]
		vs.append([int(old[0]), int(old[1])])
	d.vein = vs
	var ws: Array = []
	for i in fv.size():
		ws.append(int((m.dwins as Array)[i]) if m.has("dwins") and i < (m.dwins as Array).size() else 0)
	d.dwins = ws
	d.rich = 0
	d.lrich = false
	return sold

## the mines the player can go to (the Mines tab): every one up to the furthest reached
func reached() -> int:
	return maxi(int(d.get("reached", 0)), area())

func fresh_wins(a: int) -> Array:
	var out := []
	for D in Data.depths(a): out.append(0)
	return out

## a level played to its end, won or not: the next one is a new one; now and then it is rich — about one in five or
## six, the chance growing with every plain level (none for the first three, certain by the eighth)
func level_played(won: bool, dl: int) -> void:
	if won and dl < d.dwins.size():
		d.dwins[dl] += 1
	d.rich = 0 if d.lrich else d.rich + 1
	d.lrich = randf() < clampf((d.rich - 3) / 4.0, 0.0, 1.0)
	d.lseed = 1 + randi() % 999999

func has_jewel(rid: String) -> bool:
	for j in d.jewels:
		if j.rid == rid:
			return true
	return false

## brooch +5%, crown +10% to every coin earned
func coin_mul() -> float:
	return 1.0 + (0.05 if has_jewel("brooch") else 0.0) + (0.1 if has_jewel("crown") else 0.0)
