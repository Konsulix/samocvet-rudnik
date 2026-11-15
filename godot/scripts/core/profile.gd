class_name Profile
## The player's profile: the frame round the portrait, the portrait in it, the title under it — what is owned is read
## from the save (bosses beaten, story met, achievements claimed), what is worn is `Save.d.prof`. Earned, never given:
## a new player has the starter frame, the miner and the first title; a boss beaten gives its frame (15.11).

## the frames: id -> {n = the name, how = what earns it, area = its boss's mine (beaten: owned), win = the window
## [offset, size] as shares of the frame}; the picture is assets/ui/kit/portrait/<id>.png
const FRAMES := [
	{id = "timber", n = "Pit Props", how = "", win = [0.2731, 0.4537]},
	{id = "poloz", n = "The Serpent's Coil", area = 0, win = [0.25, 0.5]},
	{id = "mistress", n = "Malachite and Copper", area = 1, win = [0.2778, 0.4444]},
	{id = "kraken", n = "Shipwreck Timber", area = 2, win = [0.2778, 0.4444]},
	{id = "brontes", n = "Forged Iron", area = 3, win = [0.2778, 0.4444]},
	{id = "shubin", n = "The Seam's Props", area = 7, win = [0.2778, 0.4444]},
]
## the portraits: id -> {n, how, told = a story beat that opens it (Save.told), award = an achievement claimed};
## the picture is assets/ui/kit/face/<id>.png
const FACES := [
	{id = "miner", n = "The Miner", how = ""},
	{id = "miner_w", n = "The Miner", how = ""},          # (her: both are the player's from the start)
	{id = "guide", n = "The Old Miner", how = "Dig your way out of the old adit", told = "prologue"},
	{id = "sister", n = "The Scholar", how = "Meet the one with the atlas", told = "s_sister_meet"},
	{id = "brother", n = "The Apprentice", how = "Find him at the bottom of Proval", told = "s_proval_gate"},
	{id = "trilobite", n = "Crystal Eyes", how = "Award: Crystal Eyes", award = "Crystal Eyes"},
]
## the titles: by bosses beaten, and the ones an achievement gives ("the title X" in Save.d.unlocks)
const RANKS := [[0, "Greenhorn"], [1, "Digger"], [3, "Foreman"], [5, "Mine Captain"]]
const AWARD_TITLES := [["Curator", "Alas, Poor Yorick"], ["Naturalist", "Noah's Ark"], ["Colourist", "Paintbox"], ["Slayer", "Giant Slayer"]]

static func bosses_beaten() -> int:
	var k := 0
	for w in Save.d.boss_won:
		if bool(w): k += 1
	return k

static func has_frame(f: Dictionary) -> bool:
	if not f.has("area"): return true
	var a := int(f.area)
	return a < Save.d.boss_won.size() and bool(Save.d.boss_won[a])

static func has_face(f: Dictionary) -> bool:
	if f.has("told"): return Save.told(String(f.told))
	if f.has("award"): return (Save.d.aw_got as Array).has(String(f.award))
	return true

## the frame's hint while it is locked
static func frame_how(f: Dictionary) -> String:
	if f.has("area"): return "Beat %s" % String(Data.AREAS[int(f.area)].boss.n)
	return String(f.get("how", ""))

## every title: [name, owned, how]
static func titles() -> Array:
	var out := []
	var nb := bosses_beaten()
	for r: Array in RANKS:
		var k := int(r[0])
		out.append([String(r[1]), nb >= k, "Beat %d boss%s" % [k, "" if k == 1 else "es"]])
	for t: Array in AWARD_TITLES:
		out.append([String(t[0]), (Save.d.unlocks as Array).has("the title " + String(t[0])), "Award: " + String(t[1])])
	return out

static func _prof() -> Dictionary:
	if not Save.d.has("prof") or not (Save.d.prof is Dictionary): Save.d.prof = {}
	return Save.d.prof

static func _find(list: Array, id: String) -> Dictionary:
	for e: Dictionary in list:
		if String(e.id) == id: return e
	return {}

## what is worn (an id no longer owned, or never chosen: the starter one)
static func frame() -> Dictionary:
	var f := _find(FRAMES, String(_prof().get("frame", "")))
	return f if not f.is_empty() and has_frame(f) else FRAMES[0]

static func face() -> Dictionary:
	var f := _find(FACES, String(_prof().get("face", "")))
	return f if not f.is_empty() and has_face(f) else FACES[0]

static func title() -> String:
	var want := String(_prof().get("title", ""))
	var best := String(RANKS[0][1])
	for t: Array in titles():
		if not bool(t[1]): continue
		if String(t[0]) == want: return want
		# not chosen: the highest rank held
		if (RANKS.map(func(r): return String(r[1])) as Array).has(String(t[0])): best = String(t[0])
	return best

static func wear(kind: String, id: String) -> void:
	_prof()[kind] = id
	Save.persist()
	Save.changed.emit()

## what was earned and not yet looked at: "frame:<id>", "face:<id>", "title:<name>" (the card marks them new, the
## portrait in the bar glows)
static func fresh() -> Array:
	var seen: Array = Save.d.get("prof_seen", [])
	var out := []
	for f: Dictionary in FRAMES:
		if f.has("area") and has_frame(f) and not seen.has("frame:" + String(f.id)): out.append("frame:" + String(f.id))
	for f: Dictionary in FACES:
		if f.has("how") and String(f.how) != "" and has_face(f) and not seen.has("face:" + String(f.id)): out.append("face:" + String(f.id))
	for t: Array in titles():
		if bool(t[1]) and String(t[0]) != String(RANKS[0][1]) and not seen.has("title:" + String(t[0])): out.append("title:" + String(t[0]))
	return out

static func mark_seen(keys: Array) -> void:
	if not Save.d.has("prof_seen"): Save.d.prof_seen = []
	for k in keys:
		if not (Save.d.prof_seen as Array).has(k): Save.d.prof_seen.append(k)
	Save.persist()

## the stone in the profile's card: the most valuable kept; {} - none yet
static func showcase() -> Dictionary:
	var best := {}
	for s: Dictionary in Save.d.coll:
		if best.is_empty() or int(s.value) > int(best.value): best = s
	return best

## the records on the miner's card: [icon, label, value]
static func records() -> Array:
	var depth_m := 0
	for a in Data.AREAS.size():
		if a < Save.d.depth.size() and a <= Save.reached(): depth_m = maxi(depth_m, Data.depth_m(a, int(Save.d.depth[a])))
	var best := 0
	var best_n := ""
	for id in Save.d.atlas:
		var e: Dictionary = Save.d.atlas[id]
		if int(e.get("max_v", 0)) > best:
			best = int(e.max_v)
			var b: Dictionary = e.get("best", {})
			best_n = Stones.name_of(b) if b.has("sid") else String(id)
	var nb := 0
	for a in Data.AREAS:
		if a.has("boss"): nb += 1
	return [
		["check", "Wins", str(maxi(0, int(Save.d.level) - 1))],
		["pick", "Deepest", "%d m" % depth_m],
		["collection", "Species", "%d / %d" % [Save.d.atlas.size(), Data.minable().size()]],
		["res://assets/atlas/emblem_poloz.png", "Bosses", "%d / %d" % [bosses_beaten(), nb]],
		["coin", "Best find", "%s · %d" % [best_n, best] if best > 0 else "-"],
	]
