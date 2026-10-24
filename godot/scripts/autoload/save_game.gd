extends Node
## The player's progress, kept in user://save.json. Same fields as the prototype's save.

signal changed
signal gem_style_changed

const PATH := "user://save.json"
const LIFE_MS := 8 * 60 * 1000
const MAX_LIVES := 5

var d: Dictionary

func blank() -> Dictionary:
	return {
		level = 1, coins = 400, stars = 0, lives = 5, life_at = 0, area = 0,
		built = [[], [], []], boost = {pick = 2, dyn = 2}, pre = {rocket = 1, bomb = 1, orb = 0}, streak = 0,
		eq = {lift = 0, crush = 0, food = 0, vent = 0}, depth = [0, 0, 0], depth_sel = [0, 0, 0],
		jewels = [], seen = [], coll = [], sets = [], uid = 1000, lab = 0, mute = false, gem_style = "natural",
	}

func _init() -> void:
	d = blank()
	if FileAccess.file_exists(PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary:
			for k in parsed:
				if d.has(k) and d[k] is Dictionary and parsed[k] is Dictionary:
					d[k].merge(parsed[k], true)
				else:
					d[k] = parsed[k]
	# JSON brings numbers back as floats; the game counts in whole numbers
	for k in ["level", "coins", "stars", "lives", "life_at", "area", "streak", "uid", "lab"]:
		d[k] = int(d[k])
	for k in ["boost", "pre", "eq"]:
		for kk in d[k]:
			d[k][kk] = int(d[k][kk])
	for k in ["depth", "depth_sel"]:
		for i in d[k].size():
			d[k][i] = int(d[k][i])
	while d.built.size() < 3:
		d.built.append([])
	if not d.gem_style is String or not BoardSprites.GEM_STYLES.has(d.gem_style):
		d.gem_style = "natural"
	BoardSprites.gem_style = d.gem_style

func set_gem_style(style: String) -> void:
	if not BoardSprites.GEM_STYLES.has(style): return
	d.gem_style = style
	BoardSprites.gem_style = style
	persist()
	gem_style_changed.emit()

func persist() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))
	changed.emit()

func reset() -> void:
	d = blank()
	BoardSprites.gem_style = d.gem_style
	persist()
	gem_style_changed.emit()

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

func has_jewel(rid: String) -> bool:
	for j in d.jewels:
		if j.rid == rid:
			return true
	return false

## brooch +5%, crown +10% to every coin earned
func coin_mul() -> float:
	return 1.0 + (0.05 if has_jewel("brooch") else 0.0) + (0.1 if has_jewel("crown") else 0.0)
