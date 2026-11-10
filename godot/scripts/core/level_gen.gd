class_name LevelGen
extends RefCounted
## Levels made on the spot for a depth of a mine. The board is up to 11 rows by 9 (BoardModel.MAX_R/MAX_C); its shape
## is drawn here as parts with a part each to play (_scheme: an open window to match in, a wall of blocks to break
## through, a pocket behind it, shafts down the sides, a second tier), mirrored left to right, now and then taken from
## a hand-made level (9 x 8). What fills the block cells, how much of it, the goals and the moves come from the depth.
## A level is new each time one is played (Save.d.lseed); the first level at a depth that brings a new obstacle shows
## that obstacle alone. The result is a level def like Data.LEVELS' ones, plus {gen, colors, rich, intro, scheme}.

## the size of the board being made (make picks it; the helpers below read it)
static var R := 11
static var C := 9
## testing: the works every level gets, instead of its own pick (main: `feat=`)
static var force_feats: Array = []
## the boards' sizes, [rows, cols, weight]: mostly the whole 11 x 9
const SIZES := [[11, 9, 5.0], [10, 9, 3.0], [11, 8, 2.0], [10, 8, 1.0]]
## the parts a board is drawn as (_scheme), [name, weight]; the old patterns (drawn) and hand-made shapes now and then
const SCHEMES := [["wall", 3.0], ["tiers", 2.5], ["shafts", 2.0], ["pocket", 2.0], ["frame", 1.5], ["pillars", 1.5],
	["field", 1.5], ["drawn", 1.0], ["hand", 1.0]]
## a board's obstacles grow with its cells: TIERS' load is for 9 x 8, a bigger board takes more, LOAD_K more again
const LOAD_K := 2.0
## what each depth puts on the board (Old Adit, and any mine without its own AREA_TIERS): the obstacles it may use and
## about how many cells they take, and how often a nugget to bring down comes (`nug`; none where it is not said).
## Each mine has one sign of its own and one helper (docs/backlog.md, «Механики поля по рудникам», 6.11): Old Adit's
## is the nugget (from 150 m) and timber (the Serpent's coils, from 250 m); gas has a mine of its own later
const TIERS := [
	{kinds = ["sand", "mud"], load = 10, nug = 0.0},
	{kinds = ["sand", "mud", "granite"], load = 12, nug = 0.0},
	{kinds = ["sand", "mud", "granite"], load = 14, nug = 0.45},
	{kinds = ["sand", "mud", "granite"], load = 16, nug = 0.35},
	{kinds = ["sand", "mud", "granite", "lock"], load = 16, nug = 0.3},
	{kinds = ["sand", "mud", "granite", "lock"], load = 18, nug = 0.3},
]
## Copper Mountain (9 depths): sand and mud with the nodules from the start, serpentine from 150 m, malachite crust from
## 250 m; no timber and no gas - her fight asks for crust and fallen rock
const AREA_TIERS := {1: [
	{kinds = ["sand", "mud"], load = 9},
	{kinds = ["sand", "mud"], load = 11},
	{kinds = ["sand", "mud", "granite"], load = 12},
	{kinds = ["sand", "mud", "granite"], load = 13},
	{kinds = ["sand", "mud", "granite", "crust"], load = 14},
	{kinds = ["sand", "mud", "granite", "crust"], load = 15},
	{kinds = ["sand", "mud", "granite", "crust"], load = 15},
	{kinds = ["sand", "mud", "granite", "crust"], load = 16},
	{kinds = ["sand", "mud", "granite", "crust"], load = 17},
],
## Whalebone Cove (9 depths): plain rock; the station's crane (the bucket) is its helper, from 150 m
2: [
	{kinds = ["sand", "mud"], load = 10},
	{kinds = ["sand", "mud", "granite"], load = 12},
	{kinds = ["sand", "mud", "granite"], load = 13},
	{kinds = ["sand", "mud", "granite"], load = 14},
	{kinds = ["sand", "mud", "granite"], load = 15},
	{kinds = ["sand", "mud", "granite"], load = 16},
	{kinds = ["sand", "mud", "granite"], load = 16},
	{kinds = ["sand", "mud", "granite"], load = 17},
	{kinds = ["sand", "mud", "granite"], load = 18},
],
## Fire Horizon (9 depths): pumice and ash, basalt from 100 m, powder kegs (sulphur makes powder) from 150 m, iron
## staples (timber) from 300 m
3: [
	{kinds = ["sand", "mud"], load = 10},
	{kinds = ["sand", "mud", "granite"], load = 12},
	{kinds = ["sand", "mud", "granite"], load = 13},
	{kinds = ["sand", "mud", "granite"], load = 14},
	{kinds = ["sand", "mud", "granite"], load = 15},
	{kinds = ["sand", "mud", "granite", "lock"], load = 15},
	{kinds = ["sand", "mud", "granite", "lock"], load = 16},
	{kinds = ["sand", "mud", "granite", "lock"], load = 17},
	{kinds = ["sand", "mud", "granite", "lock"], load = 18},
],
## Proval (9 depths) - the exam before the brother: snow and frozen mud, permafrost from 100 m, its own ice from 150 m,
## then the depths bring back what the four mines taught, one at a time (docs/mine5-proval.md §6): the Serpent's nuggets
## to bring down at 200 m, the Mistress's nodules at 250 m, the cove's bucket at 300 m (AREA_FEATS), her crust at 350 m,
## the fire's kegs at 400 m, timber at 450 m with all of it
4: [
	{kinds = ["sand", "mud"], load = 10},
	{kinds = ["sand", "mud", "granite"], load = 12},
	{kinds = ["sand", "mud", "granite", "ice"], load = 13},
	{kinds = ["sand", "mud", "granite", "ice"], load = 11, nug = 0.5},
	{kinds = ["sand", "mud", "granite", "ice"], load = 12, nod = true},
	{kinds = ["sand", "mud", "granite", "ice"], load = 13},
	{kinds = ["sand", "mud", "granite", "ice", "crust"], load = 14},
	{kinds = ["sand", "mud", "granite", "ice", "crust"], load = 15},
	{kinds = ["sand", "mud", "granite", "ice", "crust", "lock"], load = 16, nug = 0.4, nod = true},
],
## Spider Hollow (9 depths): clay, tuff, quartz from 100 m; the web, the cocoon and the thread are its own (not made yet)
5: [
	{kinds = ["sand", "mud"], load = 10},
	{kinds = ["sand", "mud", "granite"], load = 12},
	{kinds = ["sand", "mud", "granite"], load = 13},
	{kinds = ["sand", "mud", "granite"], load = 14},
	{kinds = ["sand", "mud", "granite"], load = 15},
	{kinds = ["sand", "mud", "granite"], load = 16},
	{kinds = ["sand", "mud", "granite"], load = 16},
	{kinds = ["sand", "mud", "granite"], load = 17},
	{kinds = ["sand", "mud", "granite"], load = 18},
],
## Whispering Seam (9 depths, docs/mine8-shubin.md): chalk and coal dust, rock from 100 m, and its own FIREDAMP from 150 m
## (no other mine has gas any more: it waits for the canary's mine); the canary's cage and the air doors are not made yet
7: [
	{kinds = ["sand", "mud"], load = 10},
	{kinds = ["sand", "mud", "granite"], load = 12},
	{kinds = ["sand", "mud", "granite", "gas"], load = 12},
	{kinds = ["sand", "mud", "granite", "gas"], load = 13},
	{kinds = ["sand", "mud", "granite", "gas"], load = 14},
	{kinds = ["sand", "mud", "granite", "gas"], load = 15},
	{kinds = ["sand", "mud", "granite", "gas", "lock"], load = 15},
	{kinds = ["sand", "mud", "granite", "gas", "lock"], load = 16},
	{kinds = ["sand", "mud", "granite", "gas", "lock"], load = 17},
]}
const CH := {sand = "r", granite = "R", mud = "m", gas = "g", lock = "l", crust = "c", ice = "i"}
## gas spreads and timber pins stones: a little of either goes a long way
const CAP := {gas = 6, lock = 10, crust = 10, ice = 14, granite = 6}
## Copper Mountain's malachite nodules (mine -> how many at the first depth, one more every other depth, at most):
## the mine's own ore grows in them, so its boards carry less of the other obstacles (NOD_LOAD)
const NODULES := {1: Vector2i(2, 4), 4: Vector2i(2, 3)}
const NOD_LOAD := 0.7
## the moves a level needs: BASE + WORK of each obstacle cell (a nugget, the geode, a stone of a colour goal), fitted
## on the smart autoplayer (it looks a move ahead for its goals) by the moves it needs with no limit (`-- sim_gen=N
## sim_depth=D smart streak=0 sim_rows sim_free`); what a level asks for is kept within NEED_MAX
## the gallery's works (BoardModel: cart, keg, dark, belt, bucket) - one of them on most levels, two now and then
## deeper down. Each mine has only its own (AREA_FEATS: work -> the depth it comes in at, shown alone on the second
## level played there): Copper Mountain the belt, the cove the bucket, the fire the kegs, Proval brings the cove's and
## the fire's back. The cart (a ghost-cart mine) and the dark (a boss of its own) wait for their mines
const FEATURES := ["cart", "keg", "dark", "belt", "bucket"]
const AREA_FEATS := {1: {belt = 3}, 2: {bucket = 2}, 3: {keg = 2}, 4: {bucket = 5, keg = 7}}
const FEATURE_P := 0.8
## a feature takes over part of a level's work: the plain obstacles shrink to this share of their load
const FEATURE_LOAD := {cart = 0.75, keg = 0.95, dark = 0.85, belt = 1.0, bucket = 0.8}
## 10.11 refitted WITHOUT the streak's gifts (smart bot, no move limit, 408 levels of mines 1-5): the gifts are a
## reward that makes a level easier, not something it is built to need - a lost level resets the streak, and the
## retry was near hopeless without them (playtest 10.11). Granite was far underpriced (0.35 a cell, 16 of them took
## the bot ~40 moves): a cell costs 0.51, and each layer it lies behind the face of its wall 0.48 more (`*_deep`,
## _deep); cart, dark and gas are not in the data (no mine has them) and keep their old prices
const WORK := {sand = 0.18, granite = 0.51, sand_deep = 0.03, granite_deep = 0.48, mud = 0.07, gas = 0.12, lock = 0.3, crust = 0.04, ice = 0.3, nod = 0.2, nug = 1.57, geo = 3.16, colour = 0.055, cart = 0.39, keg = 0.25, kegs = -0.2, dark = 0.0, belt = -1.97, bucket = 1.46}
const BASE := 6.4
## a shape that is slower to work through than its cells say: a lower tier behind a throat
const SCHEME_WORK := {tiers = 5.4}
## the moves given are the need times the beat's k (BEAT): the bot's spread grows with the need (sd 3 moves on a
## 10-move level, 8.5 on a 22-move one), so a margin of a fixed few moves was generous on small levels and cruel on
## big ones. A move less every ~3 depths (TIGHT)
const TIGHT := 0.3
const FIRST_EASE := 0.0
const NEED_MAX := 28.0
const MOVES := Vector2i(10, 34)

static func tier(dl: int, area := 0) -> Dictionary:
	var T: Array = AREA_TIERS.get(area, TIERS)
	return T[clampi(dl, 0, T.size() - 1)]

## the obstacle a depth brings that the one above did not have, or ""
static func new_kind(dl: int, area := 0) -> String:
	if dl <= 0: return ""
	var above: Array = tier(dl - 1, area).kinds
	for k in tier(dl, area).kinds:
		if not k in above: return k
	return ""

## the level waiting at a depth of the current mine; one below the last depth: the boss's fight
static func current(dl: int) -> Dictionary:
	if dl >= Data.depths(Save.area()).size():
		return boss_fight(Save.area())
	var dw: Array = Save.d.dwins
	var wins: int = int(dw[dl]) if dl < dw.size() else 0
	var beat := beat_of(int(Save.d.level))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("beat="): beat = arg.get_slice("=", 1)   # testing: `-- beat=hard`
	return make(Save.area(), dl, int(Save.d.lseed) + dl * 7919, bool(Save.d.lrich) and not _veins_poor(dl), wins, beat)

## the mine's boss fight from its first board, with its health lowered 5% for every fight lost (to 70% at most)
## tier: 1 the first fight, 2-3 a beaten boss fought again (Awards.TIERS): more health, fewer moves, and at 3
## he acts a move sooner
const TIER_HP := [1.0, 1.0, 1.35, 1.7]
const TIER_MOVES := [0, 0, 3, 6]
static func boss_fight(area: int, tier := 1) -> Dictionary:
	var B: Dictionary = Data.AREAS[area].get("boss", {})
	if B.is_empty(): return {}
	tier = clampi(tier, 1, 3)
	var tries: int = int(Save.d.boss_tries[area]) if area < Save.d.boss_tries.size() else 0
	var hp := roundi(int(B.hp) * maxf(0.7, 1.0 - 0.05 * tries) / 3.0) * 3
	if tier > 1:
		B = B.duplicate()
		B.tier = tier
		B.moves = int(B.moves) - TIER_MOVES[tier]
		hp = roundi(int(B.hp) * TIER_HP[tier] / 3.0) * 3
	return BoardModel.boss_level(B, 0, hp)

## a rich level doubles the ore stones, so it is not handed out on veins worked down to their last tenth
static func _veins_poor(dl: int) -> bool:
	if dl >= Save.d.vein.size(): return false
	var D: Dictionary = Data.depth(Save.area(), dl)
	var v: Array = Save.d.vein[dl]
	return int(v[0]) <= BoardModel.vein_floor(int(D.fe)) and int(v[1]) <= BoardModel.vein_floor(int(D.au))

## how often a level has a find sealed in it (always the first level of a depth and a rich one): a find in every level
## filled a mine's atlas in two depths (playtest 31.10)
const FIND_P := 0.6
## the rhythm of the levels (Royal Match's way, docs: research 2.11): mostly normal, a breather now and then, a hard one
## every seventh level, every third of those super hard. Save.d.level only grows on a win, so a hard level stays hard
## until it is beaten. BEAT: k - the moves given over the need, and how much work the level carries. k is the
## quantile of the bot's need over the fitted one (10.11, no gifts): easy ~93% of levels won, normal ~80%, hard ~55%,
## super ~35% - with the streak's gifts and the boosters a player does better
const BEATS := ["normal", "normal", "easy", "normal", "normal", "hard", "easy"]
## (super hard: fewer moves than the usual floor, MOVES.x - more cheap work alone hardly makes it harder)
const BEAT := {"easy": {k = 1.55, load = 0.85}, "normal": {k = 1.32, load = 1.0},
	"hard": {k = 1.02, load = 1.15}, "super": {k = 0.86, load = 1.3, floor = 8}}
const HARD_FROM := 12    # no hard level before this one (Royal Match's first is level 39)
const SUPER_FROM := 30
## the level's idea: one main work over a good part of the board, at most a little of another beside it. A soft
## obstacle (one hit) can cover this share of the board's cells; the other kind, if any, takes a few cells
const SOFT := ["sand", "mud"]
const SOFT_SHARE := Vector2(0.38, 0.55)
const SIDE_CELLS := Vector2i(4, 10)

## the beat of level n of the game (BEATS): easy | normal | hard | super
static func beat_of(level_n: int) -> String:
	var b: String = BEATS[level_n % BEATS.size()]
	if b == "hard":
		if level_n < HARD_FROM: return "normal"
		if level_n >= SUPER_FROM and (level_n / BEATS.size()) % 3 == 2: return "super"
	return b

static func make(area: int, dl: int, seed_v: int, rich: bool, wins: int, beat := "normal") -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v * 31 + area
	var T := tier(dl, area)
	var nk := new_kind(dl, area)
	var intro := nk != "" and wins == 0
	# the works this level gets: the one new at this depth alone on its second level here, else now and then one or two
	var feats := _features(rng, area, dl, wins, intro)
	var feat_intro := wins == 1 and feats.size() == 1 and int(feats_at(area).get(feats[0], -1)) == dl
	# a first look at something, and the first depth of the game, are never hard
	if beat in ["hard", "super"] and (intro or feat_intro or (area == 0 and dl == 0)): beat = "normal"
	var bk: Dictionary = BEAT[beat]
	var scheme := String(Stones.pick_w(SCHEMES.map(func(e): return [e[0], e[1]]), Rng32.new(rng.randi())))
	var size: Array = [9, 8] if scheme == "hand" else Stones.pick_w(SIZES.map(func(e): return [e, e[2]]), Rng32.new(rng.randi()))
	R = int(size[0])
	C = int(size[1])
	var grid := []
	for r in R:
		var row := []
		row.resize(C)
		row.fill(".")
		grid.append(row)
	# block cells in two groups, each filled with one obstacle, the ones that matter most first (trimming takes
	# from the end); spots for nuggets and a geode
	var groups := {a = [], b = []}
	var nugs := []
	var geo_at := []
	match scheme:
		"hand": _from_hand(rng, grid, groups, nugs, geo_at)
		"drawn": _drawn(rng, grid, groups)
		_: _scheme(rng, scheme, grid, groups, nugs, geo_at)
	_fill_specks(grid, groups)
	# what goes where
	var kinds: Array = T.kinds
	var ka: String = nk if intro else _pick(rng, kinds, nk)
	var kb: String = "" if intro else _pick(rng, kinds, "")
	# one idea a level: a work of the gallery already makes the second obstacle one thing too many, most of the time
	if kb == ka or (not feats.is_empty() and rng.randf() < 0.6): kb = ""
	if kb == "":
		groups.a.append_array(groups.b)
		groups.b = []
	elif groups.b.size() > groups.a.size():
		# the main obstacle takes the bigger part of the shape
		var t: Array = groups.a
		groups.a = groups.b
		groups.b = t
	var big := float(R * C) / 72.0 * (LOAD_K if scheme != "hand" else 1.0)
	var load: int = roundi((int(T.load) + mini(wins, 4) + rng.randi_range(-2, 2)) * big * float(bk.load))
	if intro: load = roundi(T.load * 0.6 * big)
	var ffac := 1.0
	for f: String in feats: ffac *= float(FEATURE_LOAD[f]) * (0.7 if feat_intro else 1.0)
	load = roundi(load * ffac)
	# the works go down first, on the shape's free cells, and the block groups give way to them
	var fdef := {}
	var fwork := _place_features(rng, grid, groups, feats, dl, scheme, fdef)
	var nods := NODULES.has(area) and bool(T.get("nod", area == 1))   # Proval: only the depths that bring them
	if nods: load = roundi(load * NOD_LOAD)
	var want := {a = ka, b = kb}
	# how much of each: a soft main obstacle covers a good part of the board (every match does something), the side one
	# a few cells - its goal reads small beside the main one
	var cells := 0
	for r in R:
		for c in C:
			if grid[r][c] != "#": cells += 1
	var aim := {a = load, b = 0}
	if ka in SOFT and not intro:
		aim.a = maxi(load, roundi(cells * rng.randf_range(SOFT_SHARE.x, SOFT_SHARE.y) * float(bk.load) * ffac))
	if kb != "":
		aim.a = roundi(aim.a * 0.85)
		aim.b = roundi(clampf(load * 0.25, SIDE_CELLS.x, SIDE_CELLS.y))
	for g in ["a", "b"]:
		if want[g] == "": continue
		var cap: int = mini(roundi(int(CAP.get(want[g], 99)) * big), roundi(int(aim[g]) * 1.15))
		_trim(rng, groups[g], cap)
		while groups[g].size() < roundi(int(aim[g]) * 0.9) and groups[g].size() < cap:
			if _add_pair(rng, grid, groups, g) == 0: break
	# a mine with nodules keeps room for them in the work a level may ask for
	var nod_want := 0
	if nods:
		var nn: Vector2i = NODULES[area]
		nod_want = mini(nn.x + dl / 2, nn.y)
	var reserve := nod_want * float(WORK.nod) + float(SCHEME_WORK.get(scheme, 0.0)) + fwork
	# no more work than a level may ask for: the heavier group gives up a pair at a time
	var est := func() -> float:
		var g2: Array = grid.duplicate(true)
		var w := 0.0
		for g in ["a", "b"]:
			if want[g] == "": continue
			for p: Vector2i in groups[g]:
				if g2[p.x][p.y] != ".": continue
				g2[p.x][p.y] = CH[want[g]]
				w += float(WORK[want[g]])
		var dp := _deep(g2)
		return w + int(dp.sand) * float(WORK.sand_deep) + int(dp.granite) * float(WORK.granite_deep)
	while BASE + reserve + float(est.call()) > NEED_MAX:
		var ga: float = groups.a.size() * float(WORK.get(want.a, 0.0))
		var gb: float = groups.b.size() * float(WORK.get(want.b, 0.0))
		if _drop_pair(rng, groups["a" if ga >= gb else "b"]) == 0: break
	var work := reserve
	var used := {}
	var count := {}   # cells of each obstacle, nuggets, geode, colour goal: for tuning the moves
	for g in ["a", "b"]:
		var kind: String = want[g]
		if kind == "": continue
		for p: Vector2i in groups[g]:
			if grid[p.x][p.y] != ".": continue
			grid[p.x][p.y] = CH[kind]
			work += float(WORK[kind])
			used[kind] = true
			count[kind] = int(count.get(kind, 0)) + 1
	# a wall is broken from its face inwards: the layers behind the face cost moves of their own
	var deep := _deep(grid)
	for k in ["sand", "granite"]:
		if int(deep[k]) > 0:
			count[k + "_deep"] = int(deep[k])
			work += int(deep[k]) * float(WORK[k + "_deep"])
	var goals := []
	if used.has("sand") or used.has("granite"): goals.append(["rock"])
	for k in ["mud", "gas", "lock", "crust", "ice"]:
		if used.has(k): goals.append([k])
	for k in ["cart", "dark", "keg"]:
		if fdef.get("goal_" + k, false): goals.push_front([k])
	if fdef.has("bucket"): goals.append(["nug"])
	# a nugget to bring down, a geode to crack: now and then, never on a first look at something new, and not as a
	# fourth thing on a level that has its three
	var things := (1 if ka != "" else 0) + (1 if kb != "" else 0) + feats.size() + (1 if nods else 0)
	if not intro and things < 3 and not fdef.has("bucket") and rng.randf() < float(T.get("nug", 0.0)) and BASE + work + WORK.nug <= NEED_MAX:
		if nugs.is_empty(): nugs = [Vector2i(0, 2), Vector2i(0, C - 3)]
		var put := 0
		for p: Vector2i in nugs:
			if put < 2 and grid[p.x][p.y] == "." and _falls_out(grid, p) and BASE + work + WORK.nug * (put + 1) <= NEED_MAX:
				grid[p.x][p.y] = "n"
				put += 1
		if put:
			goals.append(["nug"])
			work += WORK.nug * put
			count.nug = put
	if not intro and things < 3 and goals.size() < 3 and feats.size() < 2 and rng.randf() < 0.2 and BASE + work + WORK.geo <= NEED_MAX:
		var spot := _geo_spot(rng, grid, geo_at)
		if spot.x >= 0:
			grid[spot.x][spot.y] = "G"
			for d: Vector2i in BoardModel.QUAD:
				if d != Vector2i.ZERO: grid[spot.x + d.x][spot.y + d.y] = "+"
			goals.append(["geo"])
			work += WORK.geo
			count.geo = 1
	# a colour to collect: when the board is bare, or now and then beside one obstacle
	if goals.is_empty() or (goals.size() == 1 and not intro and feats.is_empty() and rng.randf() < 0.3):
		var n := (18 if goals.is_empty() else 12) + dl * 2
		goals.append(["c", rng.randi_range(0, 4), n])
		work += n * WORK.colour
		count.colour = n
	if nod_want:
		count.nod = _nodules(rng, grid, nod_want)
		# a nodule takes a cell and overgrows onto the stones round it: some moves go on it (kept in reserve above)
		work += (int(count.nod) - nod_want) * float(WORK.nod)
	var rows := PackedStringArray()
	for r in R:
		rows.append("".join(grid[r]).replace("+", ".").replace("=", "."))
	for f: String in feats: count[f] = fdef.get("n_" + f, 1)
	# two works at once ask for more thought than their sum: a couple of moves more
	var moves := clampi(roundi((BASE + work - TIGHT * dl + (FIRST_EASE if dl == 0 else 0.0)) * float(bk.k)) + (3 if intro or feat_intro else 0) + (2 if feats.size() > 1 else 0) + (2 if area > 0 and not feats.is_empty() else 0), int(bk.get("floor", MOVES.x)), MOVES.y)
	var out := {map = "|".join(rows), goals = goals, moves = moves, hard = beat in ["hard", "super"], beat = beat, gen = true, colors = 5,
		rich = rich, intro = intro, kinds = used.keys(), count = count, scheme = scheme, feats = feats, feat_intro = feat_intro,
		find = wins == 0 or rich or beat in ["hard", "super"] or rng.randf() < FIND_P}
	for k in ["carts", "dark", "belts", "bucket"]:
		if fdef.has(k): out[k] = fdef[k]
	return out

## a mine's works and the depths they come in at (AREA_FEATS)
static func feats_at(area: int) -> Dictionary:
	return AREA_FEATS.get(area, {})

## the works a level gets (FEATURES): none on an obstacle's first showing; the one new at this depth alone on the
## second level played there; otherwise one most of the time, deeper now and then two
static func _features(rng: RandomNumberGenerator, area: int, dl: int, wins: int, intro: bool) -> Array:
	if not force_feats.is_empty(): return force_feats.duplicate()
	if intro: return []
	var at := feats_at(area)
	var open_f := []
	for f: String in at:
		if int(at[f]) <= dl: open_f.append(f)
	if open_f.is_empty(): return []
	var fresh := ""
	for f: String in open_f:
		if int(at[f]) == dl: fresh = f
	if fresh != "" and wins == 1: return [fresh]
	if rng.randf() > FEATURE_P: return []
	var w := []
	for f: String in open_f: w.append([f, 2.0 if f == fresh else 1.0])
	var first := String(Stones.pick_w(w, Rng32.new(rng.randi())))
	var out := [first]
	if dl >= 3 and open_f.size() > 1 and rng.randf() < 0.3:
		var w2 := []
		for f: String in open_f:
			# the dark with another big work is too much at once; the belt goes with anything
			if f != first and not (f == "dark" and first == "bucket") and not (f == "bucket" and first == "dark"): w2.append([f, 1.0])
		if not w2.is_empty(): out.append(String(Stones.pick_w(w2, Rng32.new(rng.randi()))))
	return out

## a cell the works may take: open, not a block cell, not a hole
static func _free(grid: Array, groups: Dictionary, p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < R and p.y < C and grid[p.x][p.y] == "." and not p in groups.a and not p in groups.b

## put the works on the board (letters in the grid, their settings in fdef); returns the work they ask for
static func _place_features(rng: RandomNumberGenerator, grid: Array, groups: Dictionary, feats: Array, dl: int, scheme: String, fdef: Dictionary) -> float:
	var work := 0.0
	var order := feats.duplicate()
	order.sort_custom(func(x, y): return x == "belt" and y != "belt")
	for f: String in order:
		match f:
			"belt":
				# a conveyor two rows high across the board in its open part: its cells cleared of blocks
				var rows := []
				for r in range(1, R - 2):
					var ok := true
					for c in range(0, C):
						for rr in [r, r + 1]:
							if grid[rr][c] == "#": ok = false
					if ok: rows.append(r)
				if rows.is_empty(): continue
				var r0: int = rows[rng.randi_range(0, rows.size() - 1)]
				var c0 := 0 if rng.randf() < 0.6 else 1
				for rr in [r0, r0 + 1]:
					for c in range(c0, C - c0):
						var q := Vector2i(rr, c)
						groups.a.erase(q)
						groups.b.erase(q)
						grid[rr][c] = "="   # kept clear of everything else; "." again in the map
				fdef.belts = [[r0, c0, r0 + 1, C - 1 - c0]]
				work += float(WORK.belt)
			"cart":
				# one or two carts, mirrored, each wanting stones of its own colour from beside it
				var spots := []
				for r in range(2, R - 1):
					for c in range(0, C / 2):
						var a := Vector2i(r, c)
						var b := Vector2i(r, c + 1)
						if c + 1 >= C or not _free(grid, groups, a) or not _free(grid, groups, b): continue
						if not _free(grid, groups, Vector2i(r, C - 2 - c)) or not _free(grid, groups, Vector2i(r, C - 1 - c)): continue
						var room := 0
						for q: Vector2i in [a + Vector2i(-1, 0), b + Vector2i(-1, 0), a + Vector2i(1, 0), b + Vector2i(1, 0), a + Vector2i(0, -1), b + Vector2i(0, 1)]:
							if _free(grid, groups, q): room += 1
						if room >= 4: spots.append(a)
				if spots.is_empty(): continue
				var a: Vector2i = spots[rng.randi_range(0, spots.size() - 1)]
				var two := rng.randf() < 0.5 and a.y + 1 < C - 2 - a.y
				var at := [a]
				if two: at.append(Vector2i(a.x, C - 2 - a.y))
				var cols := [0, 1, 2, 3, 4]
				var list := []
				for p: Vector2i in at:
					grid[p.x][p.y] = "W"
					grid[p.x][p.y + 1] = "+"
					var need := rng.randi_range(5, 7) + dl / 2 + (0 if two else 3)
					list.append({t = cols.pop_at(rng.randi_range(0, cols.size() - 1)), need = need})
					work += need * float(WORK.cart)
				fdef.carts = list
				fdef.goal_cart = true
				fdef.n_cart = list.reduce(func(a, x): return a + int(x.need), 0)
			"keg":
				# powder kegs beside the blocks (to blow them up with), mirrored; now and then the goal is to set them off
				var spots := []
				for r in range(1, R):
					for c in range(0, (C + 1) / 2):
						var p := Vector2i(r, c)
						if not _free(grid, groups, p): continue
						var near := 0
						for d: Vector2i in BoardModel.DIRS4:
							if p + d in groups.a or p + d in groups.b: near += 1
						spots.append([p, near + rng.randf()])
				spots.sort_custom(func(x, y): return x[1] > y[1])
				var want := rng.randi_range(1, 2)
				var put := 0
				for sp in spots:
					if put >= want: break
					var p: Vector2i = sp[0]
					var ok := true
					for dr in range(-1, 2):
						for dc in range(-1, 2):
							var q := Vector2i(p.x + dr, p.y + dc)
							if q.x >= 0 and q.y >= 0 and q.x < R and q.y < C and grid[q.x][q.y] == "K": ok = false
					if not ok or not _free(grid, groups, p) or not _free(grid, groups, Vector2i(p.x, C - 1 - p.y)): continue
					grid[p.x][p.y] = "K"
					grid[p.x][C - 1 - p.y] = "K"
					put += 1
				var n := 0
				for r in R:
					for c in C:
						if grid[r][c] == "K": n += 1
				fdef.n_keg = n
				if rng.randf() < 0.45:
					fdef.goal_keg = true
					work += n * float(WORK.keg)
				else:
					work += n * float(WORK.kegs)
			"dark":
				# the gallery below is dark: the light comes from above (or from a lantern's pool) and has to be carried down
				var mask := []
				for r in R:
					var row := []
					row.resize(C)
					row.fill(".")
					mask.append(row)
				var lamps := []
				if rng.randf() < 0.7:
					# its edge wanders from column to column, mirrored, like the edge of the light on rough rock
					var rd := rng.randi_range(R / 2 - 2, R / 2)
					var edge := []
					var e := rd
					for c in (C + 1) / 2:
						edge.append(e)
						e = clampi(e + rng.randi_range(-1, 1), R / 2 - 3, R / 2 + 1)
					for c in C:
						for r in range(int(edge[mini(c, C - 1 - c)]), R): mask[r][c] = "d"
				else:
					# all dark but a lantern's pool, or two, high on the board
					for r in R:
						for c in C: mask[r][c] = "d"
					var lr := rng.randi_range(1, 3)
					var lc := rng.randi_range(1, C / 2 - 1)
					var two := rng.randf() < 0.75
					for p: Vector2i in ([Vector2i(lr, lc), Vector2i(lr, C - 1 - lc)] if two else [Vector2i(lr, C / 2)]):
						if grid[p.x][p.y] != ".": continue
						groups.a.erase(p)
						groups.b.erase(p)
						grid[p.x][p.y] = "L"
						lamps.append([p.x, p.y])
						# its pool: a diamond two cells out
						for dr in range(-2, 3):
							for dc in range(-2, 3):
								var q := Vector2i(p.x + dr, p.y + dc)
								if absi(dr) + absi(dc) <= 2 and q.x >= 0 and q.y >= 0 and q.x < R and q.y < C: mask[q.x][q.y] = "."
				# no lantern found room (a belt where it would hang): the light comes from the top rows instead
				if mask[0][0] == "d" and lamps.is_empty():
					for r in 2:
						for c in C: mask[r][c] = "."
				var n := 0
				var rows := PackedStringArray()
				for r in R:
					for c in C:
						if mask[r][c] == "d" and grid[r][c] != "#": n += 1
					rows.append("".join(mask[r]))
				fdef.dark = "|".join(rows)
				fdef.lamps = lamps
				fdef.goal_dark = true
				fdef.n_dark = n
				work += n * float(WORK.dark)
			"bucket":
				# an ore bucket hung high in the middle: each knock tips a nugget out, to be brought down
				var c := C / 2 if C % 2 == 1 or rng.randf() < 0.5 else C / 2 - 1
				var r := rng.randi_range(0, 1)
				if not _free(grid, groups, Vector2i(r, c)) or not _falls_out(grid, Vector2i(r, c)): continue
				grid[r][c] = "B"
				var n := rng.randi_range(2, 3) + (1 if dl >= 3 else 0)
				fdef.bucket = n
				fdef.n_bucket = n
				work += n * float(WORK.bucket)
	return work

## the shape as parts. Holes and block cells are mirrored left to right; a group's cells go in the order they matter
## (trimming to the level's load takes from the end, so a wall keeps its core and loses its ends)
static func _scheme(rng: RandomNumberGenerator, scheme: String, grid: Array, groups: Dictionary, nugs: Array, geo_at: Array) -> void:
	var half := (C + 1) / 2
	match scheme:
		"wall":
			# an open window over a wall of blocks across the board; under it more of the board, or a second wall
			var h := rng.randi_range(2, 3)
			var r0 := rng.randi_range(R / 2 - 1, R - h - 2)
			for c in range(half - 1, -1, -1):
				for r in range(r0, r0 + h): _put(grid, groups, "a", r, c)
			if rng.randf() < 0.5:
				for c in half: _put(grid, groups, "b", R - 1, c)
			if rng.randf() < 0.4: _hole(grid, R - 1, 0)
			geo_at.append(Vector2i(r0 + h, half - 1))
		"tiers":
			# two boards, one over the other, joined by a throat in the middle; the lower one mostly blocks. Always a
			# throat: two boards cut apart left the upper one with nothing to do (playtest 10.11)
			var rt := rng.randi_range(R / 2 - 1, R / 2)
			var throat := rng.randi_range(1, 2)
			for c in half - throat: _hole(grid, rt, c)
			if rng.randf() < 0.5: _hole(grid, rt - 1, 0)
			for r in range(rt + 1, R):
				for c in range(half - 1, -1, -1): _put(grid, groups, "a", r, c)
			if rng.randf() < 0.5:
				for r in range(1, rt - 1): _put(grid, groups, "b", r, 0)
			if throat:
				nugs.append_array([Vector2i(0, half - 1), Vector2i(0, C - half)])
			else:
				nugs.append(Vector2i(rt + 1, half - 1))
			geo_at.append(Vector2i(1, half - 2))
		"shafts":
			# shafts two wide down both sides of the lower half, packed with blocks, behind a wall of the other blocks
			# (a wall of holes cut the shafts off from matches, and its windows left single holes all over the board);
			# a band across the middle between them
			var sw := 2
			var rs := rng.randi_range(R / 2 - 1, R / 2 + 1)
			for r in range(rs, R): _put(grid, groups, "a", r, sw)
			for r in range(R - 1, rs - 1, -1):
				for c in sw: _put(grid, groups, "b", r, c)
			var r0 := rng.randi_range(R / 2, R - 3)
			for c in range(half - 1, sw, -1):
				for r in range(r0, r0 + 2): _put(grid, groups, "a", r, c)
			nugs.append(Vector2i(0, half - 1))
		"pocket":
			# a ring of blocks round a pocket low on the board: the geode, or the nuggets' way down, is inside
			var c0 := rng.randi_range(1, 2)
			var r0 := rng.randi_range(R / 2 - 1, R - 5)
			var r1 := mini(R - 1, r0 + rng.randi_range(3, 4))
			for c in range(half - 1, c0 - 1, -1): _put(grid, groups, "a", r0, c)
			for r in range(r0 + 1, r1 + 1): _put(grid, groups, "a", r, c0)
			if r1 < R - 1:
				for c in range(half - 1, c0, -1): _put(grid, groups, "a", r1, c)
			for r in range(r0, R):
				for c in c0: _put(grid, groups, "b", r, c)
			geo_at.append(Vector2i(r0 + 1, half - 1 if C % 2 == 0 else half - 2))
			nugs.append_array([Vector2i(0, half - 1), Vector2i(0, C - half)])
		"frame":
			# blocks up both sides and along the bottom; the top corners cut away
			var rs := rng.randi_range(2, R / 2)
			for r in range(R - 1, rs - 1, -1): _put(grid, groups, "a", r, 0)
			for c in range(1, half): _put(grid, groups, "a", R - 1, c)
			_hole(grid, 0, 0)
			if rng.randf() < 0.5: _hole(grid, 1, 0)
			if rng.randf() < 0.6:
				var rm := rng.randi_range(R / 2 - 1, R / 2 + 1)
				for c in range(half - 1, half - 3, -1):
					for r in range(rm, rm + 2): _put(grid, groups, "b", r, c)
			geo_at.append(Vector2i(R - 3, half - 1))
		"pillars":
			# columns of blocks every other column, over a band of the other blocks
			var r0 := rng.randi_range(1, 3)
			var h := rng.randi_range(3, 5)
			for c in range(half - 2 if C % 2 else half - 1, -1, -2):
				for r in range(r0, r0 + h): _put(grid, groups, "a", r, c)
			if rng.randf() < 0.6:
				for c in half: _put(grid, groups, "b", R - 2, c)
			if rng.randf() < 0.4:
				_hole(grid, R - 1, 0)
				_hole(grid, R - 1, 1)
		"field":
			# most of the lower board under blocks, the upper rows open
			var r0 := rng.randi_range(R / 2 - 1, R / 2 + 1)
			for r in range(r0, mini(r0 + 2, R)):
				for c in range(half - 1, -1, -1): _put(grid, groups, "a", r, c)
			for r in range(r0 + 2, R):
				for c in range(half - 1, -1, -1): _put(grid, groups, "b", r, c)
			if rng.randf() < 0.5:
				_hole(grid, R - 1, 0)
				_hole(grid, 0, 0)
			nugs.append_array([Vector2i(0, half - 1), Vector2i(0, C - half)])

## holes shape the board's outline (a notch, a cut corner, a gap between tiers), never a speck inside it: a patch of
## holes off the edge smaller than 2 x 2 goes back to board (to the blocks round it, if they are all of one group)
static func _fill_specks(grid: Array, groups: Dictionary) -> void:
	var seen := {}
	for r in R:
		for c in C:
			if grid[r][c] != "#" or seen.has(Vector2i(r, c)): continue
			var patch := [Vector2i(r, c)]
			seen[patch[0]] = true
			var edge := false
			var i := 0
			while i < patch.size():
				var p: Vector2i = patch[i]
				i += 1
				if p.x == 0 or p.y == 0 or p.x == R - 1 or p.y == C - 1: edge = true
				for d: Vector2i in BoardModel.DIRS4:
					var q := p + d
					if q.x >= 0 and q.y >= 0 and q.x < R and q.y < C and grid[q.x][q.y] == "#" and not seen.has(q):
						seen[q] = true
						patch.append(q)
			if edge or _has_square(grid, patch): continue
			for p: Vector2i in patch:
				grid[p.x][p.y] = "."
				var near := {}
				for d: Vector2i in BoardModel.DIRS4:
					for g in ["a", "b"]:
						if p + d in groups[g]: near[g] = true
				if near.size() == 1: groups[near.keys()[0]].append(p)

static func _has_square(grid: Array, patch: Array) -> bool:
	for p: Vector2i in patch:
		if p.x + 1 < R and p.y + 1 < C and grid[p.x + 1][p.y] == "#" and grid[p.x][p.y + 1] == "#" and grid[p.x + 1][p.y + 1] == "#":
			return true
	return false

## cells no match can be made in: holes, rock, the geode, the gallery's works
const SHUT := ["#", "r", "R", "G", "+", "W", "K", "L", "B"]
## how far rock lies behind the face of its wall: {sand, granite} = the sum over their cells of the layers in front of
## each (a cell touching the open board is 0, the one behind it 1...). A match only hits rock beside it, so a wall
## three deep needs its face broken before the next layer can be touched
static func _deep(grid: Array) -> Dictionary:
	var dist := {}
	var q := []
	for r in R:
		for c in C:
			if not grid[r][c] in ["r", "R"]: continue
			for d: Vector2i in BoardModel.DIRS4:
				var n := Vector2i(r, c) + d
				if n.x >= 0 and n.y >= 0 and n.x < R and n.y < C and not grid[n.x][n.y] in SHUT:
					dist[Vector2i(r, c)] = 0
					q.append(Vector2i(r, c))
					break
	var i := 0
	while i < q.size():
		var p: Vector2i = q[i]
		i += 1
		for d: Vector2i in BoardModel.DIRS4:
			var n := p + d
			if n.x >= 0 and n.y >= 0 and n.x < R and n.y < C and grid[n.x][n.y] in ["r", "R"] and not dist.has(n):
				dist[n] = int(dist[p]) + 1
				q.append(n)
	var out := {sand = 0, granite = 0}
	for r in R:
		for c in C:
			if grid[r][c] in ["r", "R"]:
				out["granite" if grid[r][c] == "R" else "sand"] += mini(int(dist.get(Vector2i(r, c), 4)), 4)
	return out

## a hole and its mirror image
static func _hole(grid: Array, r: int, c: int) -> void:
	grid[r][c] = "#"
	grid[r][C - 1 - c] = "#"

## a block cell of group g and its mirror image (on an open cell, once)
static func _put(grid: Array, groups: Dictionary, g: String, r: int, c: int) -> void:
	for q in [Vector2i(r, c), Vector2i(r, C - 1 - c)]:
		if q.x >= 0 and q.x < R and grid[q.x][q.y] == "." and not q in groups.a and not q in groups.b:
			groups[g].append(q)

## a nugget here reaches the bottom: no hole under it with board below the hole (it would sit over it for ever), no
## work standing in its way (a lantern, a keg, a cart, the bucket)
static func _falls_out(grid: Array, p: Vector2i) -> bool:
	var gap := false
	for r in range(p.x + 1, R):
		if grid[r][p.y] in ["L", "K", "W", "+", "B"]: return false
		if grid[r][p.y] == "#": gap = true
		elif gap: return false
	return true

## malachite nodules on free cells in the middle rows, none touching another, so each has stones round it to be cut
## off from; returns how many went down
static func _nodules(rng: RandomNumberGenerator, grid: Array, want: int) -> int:
	var spots := []
	for r in range(2, R - 2):
		for c in range(1, C - 1):
			spots.append(Vector2i(r, c))
	var put := 0
	while put < want and not spots.is_empty():
		var p: Vector2i = spots.pop_at(rng.randi_range(0, spots.size() - 1))
		if grid[p.x][p.y] != ".": continue
		var ok := true
		for dr in [-1, 0, 1]:
			for dc in [-1, 0, 1]:
				var q := Vector2i(p.x + dr, p.y + dc)
				if q.x >= 0 and q.x < R and q.y >= 0 and q.y < C and grid[q.x][q.y] == "k": ok = false
		if not ok: continue
		grid[p.x][p.y] = "k"
		put += 1
	return put

## the obstacle for a group: one the depth allows, the newest one more often
static func _pick(rng: RandomNumberGenerator, kinds: Array, prefer: String) -> String:
	var w := []
	for k in kinds:
		w.append([k, 2.5 if k == prefer or k == kinds[-1] else 1.0])
	return String(Stones.pick_w(w, Rng32.new(rng.randi())))

## shape from a hand-made level: its holes stay, its rock cells and its mud become the two groups of block cells
static func _from_hand(rng: RandomNumberGenerator, grid: Array, groups: Dictionary, nugs: Array, geo_at: Array) -> void:
	var src: Dictionary = Data.LEVELS[rng.randi_range(0, Data.LEVELS.size() - 1)]
	var rows: PackedStringArray = String(src.get("map", "")).split("|")
	var flip := rng.randf() < 0.3
	for r in R:
		var sr := R - 1 - r if flip else r
		var row: String = rows[sr] if sr < rows.size() else ""
		for c in C:
			var ch := row[c] if c < row.length() else "."
			var p := Vector2i(r, c)
			match ch:
				"#": grid[r][c] = "#"
				"r", "R", "g": groups.a.append(p)
				"m", "l": groups.b.append(p)
				"n": nugs.append(p)
				"G": geo_at.append(p)
	# a hand-made level with no blocks at all gets a drawn pattern on its shape
	if groups.a.is_empty() and groups.b.is_empty():
		_patterns(rng, grid, groups)

## a shape drawn here: a few holes, mirrored left to right, then the block patterns
static func _drawn(rng: RandomNumberGenerator, grid: Array, groups: Dictionary) -> void:
	var holes := []
	var x := rng.randf()
	if x < 0.4:
		pass
	elif x < 0.6:   # corners
		holes = [Vector2i(0, 0), Vector2i(R - 1, 0)]
		if rng.randf() < 0.5: holes.append_array([Vector2i(0, 1), Vector2i(1, 0), Vector2i(R - 1, 1), Vector2i(R - 2, 0)])
	elif x < 0.75:  # a notch in the top edge
		holes = [Vector2i(0, 3)]
		if rng.randf() < 0.5: holes.append(Vector2i(1, 3))
	elif x < 0.9:   # bites out of the sides
		var r0 := rng.randi_range(3, 4)
		holes = [Vector2i(r0, 0), Vector2i(r0 + 1, 0)]
	else:           # a pillar in the middle
		holes = [Vector2i(4, 3), Vector2i(5, 3)]
	for p: Vector2i in holes:
		grid[p.x][p.y] = "#"
		grid[p.x][C - 1 - p.y] = "#"
	_patterns(rng, grid, groups)

## one or two block patterns, mirrored: a band across, a box or a ring, columns, scattered pairs
static func _patterns(rng: RandomNumberGenerator, grid: Array, groups: Dictionary) -> void:
	for g in ["a", "b"]:
		if g == "b" and rng.randf() < 0.35: break
		var cells := []
		match rng.randi_range(0, 4):
			0:
				var r0 := rng.randi_range(2, 5)
				var c0 := rng.randi_range(0, 1)
				for c in range(c0, C / 2): cells.append(Vector2i(r0, c))
				if rng.randf() < 0.4:
					for c in range(c0, C / 2): cells.append(Vector2i(r0 + 1, c))
			1:
				var h := rng.randi_range(2, 4)
				var r0 := rng.randi_range(1, R - 1 - h - 2)
				var ring := rng.randf() < 0.5 and h >= 3
				for r in range(r0, r0 + h):
					for c in range(1, C / 2):
						if not ring or r == r0 or r == r0 + h - 1 or c == 1: cells.append(Vector2i(r, c))
			2:
				var c0 := rng.randi_range(0, 2)
				for r in range(rng.randi_range(1, 3), rng.randi_range(5, 7)): cells.append(Vector2i(r, c0))
			3:
				for k in rng.randi_range(3, 6): cells.append(Vector2i(rng.randi_range(1, R - 2), rng.randi_range(0, C / 2 - 1)))
			_:
				# a chevron
				var r0 := rng.randi_range(2, 4)
				for c in C / 2: cells.append(Vector2i(r0 + (C / 2 - 1 - c) / 2, c))
		for p: Vector2i in cells:
			for q in [p, Vector2i(p.x, C - 1 - p.y)]:
				if grid[q.x][q.y] == "." and not q in groups.a and not q in groups.b:
					groups[g].append(q)

## keep a group within its cap, a mirrored pair at a time
static func _trim(rng: RandomNumberGenerator, cells: Array, cap: int) -> void:
	while cells.size() > cap:
		if _drop_pair(rng, cells) == 0: break

## drop the last cell (the one that matters least) and its mirror image; returns how many went
static func _drop_pair(rng: RandomNumberGenerator, cells: Array) -> int:
	if cells.is_empty(): return 0
	var p: Vector2i = cells[-1]
	var n := 0
	for q in [p, Vector2i(p.x, C - 1 - p.y)]:
		if q in cells:
			cells.erase(q)
			n += 1
	return n

## one more mirrored pair of block cells next to the ones there are (or anywhere, on a bare board)
static func _add_pair(rng: RandomNumberGenerator, grid: Array, groups: Dictionary, g := "") -> int:
	if g == "": g = "a" if groups.b.is_empty() or rng.randf() < 0.5 else "b"
	# open cells of the left half (with the middle column) next to the group, or anywhere on a bare board
	var cand := []
	for r in range(1, R):
		for c in (C + 1) / 2:
			var p := Vector2i(r, c)
			if grid[r][c] != "." or p in groups.a or p in groups.b: continue
			var near: bool = groups[g].is_empty()
			for d: Vector2i in BoardModel.DIRS4:
				if p + d in groups[g]: near = true
			if near: cand.append(p)
	if cand.is_empty(): return 0
	var p: Vector2i = cand[rng.randi_range(0, cand.size() - 1)]
	var n := 0
	for q in [p, Vector2i(p.x, C - 1 - p.y)]:
		if not q in groups[g]:
			groups[g].append(q)
			n += 1
	return n

## a free 2x2 for a geode in the upper part of the board: the hand-made level's own spot when it had one
static func _geo_spot(rng: RandomNumberGenerator, grid: Array, geo_at: Array) -> Vector2i:
	var any := []
	for r in range(1, 5):
		for c in range(0, C - 1):
			any.append(Vector2i(r, c))
	for i in range(any.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Vector2i = any[i]; any[i] = any[j]; any[j] = tmp
	for s: Vector2i in geo_at + any:
		var ok := s.x + 1 < R and s.y + 1 < C
		for d: Vector2i in BoardModel.QUAD:
			if ok and grid[s.x + d.x][s.y + d.y] != ".": ok = false
		if ok: return s
	return Vector2i(-1, -1)
