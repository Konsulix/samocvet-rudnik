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
		fe = 0, ore = 0, vein = [], rich = 0,
		built = [[], [], []], boost = {pick = 2, dyn = 2}, pre = {rocket = 1, bomb = 1, orb = 0}, streak = 0,
		eq = {lift = 0, crush = 0, food = 0, vent = 0}, depth = [0, 0, 0], depth_sel = [0, 0, 0],
		jewels = [], seen = [], coll = [], sets = [], uid = 1000, lab = 0, mute = false,
		gem_style = "natural", ore_look = "rendered", lock_style = "rendered", ore_preview = false, zone_style = "hewn",
	}
	b.vein = fresh_veins(0)
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
	for k in ["ver", "level", "coins", "lives", "life_at", "area", "fe", "ore", "rich", "streak", "uid", "lab"]:
		d[k] = int(d[k])
	for k in ["boost", "pre", "eq"]:
		for kk in d[k]:
			d[k][kk] = int(d[k][kk])
	for k in ["depth", "depth_sel"]:
		for i in d[k].size():
			d[k][i] = int(d[k][i])
	for v in d.vein:
		for i in v.size():
			v[i] = int(v[i])
	while d.built.size() < 3:
		d.built.append([])
	looks_to_board()

## the board's looks from the save (the level's look panel writes them back)
func looks_to_board() -> void:
	BoardSprites.gem_style = d.gem_style if BoardSprites.GEM_STYLES.has(d.gem_style) else "natural"
	BoardSprites.ore_look = d.ore_look if BoardSprites.ORE_LOOKS.has(d.ore_look) else "rendered"
	BoardSprites.lock_style = d.lock_style if BoardSprites.LOCK_STYLES.has(d.lock_style) else "rendered"
	BoardSprites.zone_style = d.zone_style if BoardSprites.ZONE_STYLES.has(d.zone_style) else "hewn"
	# ore is not in the rules yet: shown on red (iron) and green (the mine's own) for a look
	BoardSprites.ore_demo = {0: "iron", 2: "ore"} if d.ore_preview else {}

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
	d.rich = 0
	return sold

func has_jewel(rid: String) -> bool:
	for j in d.jewels:
		if j.rid == rid:
			return true
	return false

## brooch +5%, crown +10% to every coin earned
func coin_mul() -> float:
	return 1.0 + (0.05 if has_jewel("brooch") else 0.0) + (0.1 if has_jewel("crown") else 0.0)
