extends Node
## The player's progress, kept in user://save.json. Same fields as the prototype's save.

signal changed

const PATH := "user://save.json"
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
		jewels = [], seen = [], coll = [], sets = [], atlas = {}, area_back = -1, uid = 1000, lab = 0, mute = false,
		gem_style = "natural", ore_look = "rendered", lock_style = "rendered", zone_style = "hewn",
	}
	b.vein = fresh_veins(0)
	b.dwins = fresh_wins(0)
	return b

func _init() -> void:
	d = blank()
	if FileAccess.file_exists(PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
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
	while d.built.size() < 3:
		d.built.append([])
	# a mine that has grown deeper since the save was made: its new depths start with full veins
	var fv := fresh_veins(area())
	while d.vein.size() < fv.size(): d.vein.append(fv[d.vein.size()])
	while d.dwins.size() < fv.size(): d.dwins.append(0)
	# a boss fight replayed from the atlas switches the mine for the fight; closed during it, the game comes back here
	if int(d.area_back) >= 0:
		d.area = int(d.area_back)
		d.area_back = -1
	# the atlas came after the collection: the stones already kept are its first entries
	if d.atlas.is_empty():
		for s in d.coll:
			note_find(s, int(s.get("area", 0)), int(s.get("dl", 0)))
	looks_to_board()

## the atlas remembers every species ever found, whatever became of the stone: sid -> {best = the most valuable
## find of it (enough to build it again), n = how many were found, max_g, max_v, legend = a legendary one was found}
func note_find(s: Dictionary, a: int, dl: int) -> void:
	var e: Dictionary = d.atlas.get(s.sid, {n = 0, max_g = 0, max_v = 0, legend = false})
	e.n = int(e.n) + 1
	e.max_g = maxi(int(e.max_g), int(s.g))
	e.max_v = maxi(int(e.max_v), int(s.value))
	e.legend = bool(e.legend) or bool(s.get("legend", false))
	if not e.has("best") or int(s.value) > int(e.best.value):
		var b := {id = s.id, sid = s.sid, kind = s.get("kind", "crystal"), gi = s.gi, traits = s.get("traits", []), legend = s.get("legend", false),
			g = s.g, value = s.value, tier = s.tier, area = a, dl = dl}
		for k in ["fx", "shroom"]:
			if s.has(k): b[k] = s[k]
		e.best = b
	d.atlas[s.sid] = e

## the board's looks from the save (the level's look panel writes them back)
func looks_to_board() -> void:
	BoardSprites.gem_style = d.gem_style if BoardSprites.GEM_STYLES.has(d.gem_style) else "natural"
	BoardSprites.ore_look = d.ore_look if BoardSprites.ORE_LOOKS.has(d.ore_look) else "rendered"
	BoardSprites.lock_style = d.lock_style if BoardSprites.LOCK_STYLES.has(d.lock_style) else "rendered"
	BoardSprites.zone_style = d.zone_style if BoardSprites.ZONE_STYLES.has(d.zone_style) else "hewn"

func persist() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
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

## the next mine: what is left of this one's own ore is sold, the new one starts with full veins
func open_mine(a: int) -> int:
	var sold := int(d.ore) * ORE_PRICE
	d.coins += sold
	d.ore = 0
	d.area = a
	d.vein = fresh_veins(a)
	d.dwins = fresh_wins(a)
	d.rich = 0
	d.lrich = false
	return sold

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
