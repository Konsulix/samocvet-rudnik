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
## the boards' sizes, [rows, cols, weight]: mostly the whole 11 x 9
const SIZES := [[11, 9, 5.0], [10, 9, 3.0], [11, 8, 2.0], [10, 8, 1.0]]
## the parts a board is drawn as (_scheme), [name, weight]; the old patterns (drawn) and hand-made shapes now and then
const SCHEMES := [["wall", 3.0], ["tiers", 2.5], ["shafts", 2.0], ["pocket", 2.0], ["frame", 1.5], ["pillars", 1.5],
	["field", 1.5], ["drawn", 1.0], ["hand", 1.0]]
## a board's obstacles grow with its cells: TIERS' load is for 9 x 8, a bigger board takes more, LOAD_K more again
const LOAD_K := 2.0
## what each depth puts on the board (Old Adit, and any mine without its own AREA_TIERS): the obstacles it may use and
## about how many cells they take. A new obstacle every other depth: 100 m granite, 200 m gas, 300 m timber
const TIERS := [
	{kinds = ["sand", "mud"], load = 10},
	{kinds = ["sand", "mud", "granite"], load = 12},
	{kinds = ["sand", "mud", "granite"], load = 15},
	{kinds = ["sand", "mud", "granite", "gas"], load = 14},
	{kinds = ["sand", "mud", "granite", "gas"], load = 17},
	{kinds = ["sand", "mud", "granite", "gas", "lock"], load = 18},
]
## Copper Mountain (9 depths): sand and mud, serpentine from 150 m, malachite crust from 250 m, gas from 350 m;
## no timber - her fight asks for crust and fallen rock, not for timber
const AREA_TIERS := {1: [
	{kinds = ["sand", "mud"], load = 9},
	{kinds = ["sand", "mud"], load = 11},
	{kinds = ["sand", "mud", "granite"], load = 12},
	{kinds = ["sand", "mud", "granite"], load = 13},
	{kinds = ["sand", "mud", "granite", "crust"], load = 14},
	{kinds = ["sand", "mud", "granite", "crust"], load = 15},
	{kinds = ["sand", "mud", "granite", "crust", "gas"], load = 14},
	{kinds = ["sand", "mud", "granite", "crust", "gas"], load = 15},
	{kinds = ["sand", "mud", "granite", "crust", "gas"], load = 17},
],
## Proval (9 depths) - the exam before the brother: snow and frozen mud, permafrost from 100 m, its own ice from 150 m,
## then the depths bring back what the four mines taught, one at a time (docs/mine5-proval.md §6): the Serpent's nuggets
## to bring down at 200 m, the Mistress's nodules at 250 m, methane at 300 m, her crust at 350 m, timber at 400 m; all
## of it at 450 m
4: [
	{kinds = ["sand", "mud"], load = 10},
	{kinds = ["sand", "mud", "granite"], load = 12},
	{kinds = ["sand", "mud", "granite", "ice"], load = 13},
	{kinds = ["sand", "mud", "granite", "ice"], load = 11, nug = 0.5},
	{kinds = ["sand", "mud", "granite", "ice"], load = 12, nod = true},
	{kinds = ["sand", "mud", "granite", "ice", "gas"], load = 14},
	{kinds = ["sand", "mud", "granite", "ice", "gas", "crust"], load = 15},
	{kinds = ["sand", "mud", "granite", "ice", "gas", "crust", "lock"], load = 16},
	{kinds = ["sand", "mud", "granite", "ice", "gas", "crust", "lock"], load = 17, nug = 0.4, nod = true},
]}
const CH := {sand = "r", granite = "R", mud = "m", gas = "g", lock = "l", crust = "c", ice = "i"}
## gas spreads and timber pins stones: a little of either goes a long way
const CAP := {gas = 6, lock = 10, crust = 10, ice = 14}
## Copper Mountain's malachite nodules (mine -> how many at the first depth, one more every other depth, at most):
## the mine's own ore grows in them, so its boards carry less of the other obstacles (NOD_LOAD)
const NODULES := {1: Vector2i(2, 4), 4: Vector2i(2, 3)}
const NOD_LOAD := 0.7
## the moves a level needs: BASE + WORK of each obstacle cell (a nugget, the geode, a stone of a colour goal),
## fitted 26.10 on the smart autoplayer (`-- sim_gen=30 sim_rows sim_free smart`: it looks a move ahead for its goals,
## as a player who plays the level's goals would) by the moves it needs with no limit, 270 levels of both mines,
## the shafts left out. A level gets MARGIN more than that: the smart player then wins ~80% and uses most of its moves
## (the random one of the economy runs loses most). What a level asks for is kept within NEED_MAX
const WORK := {sand = 0.25, granite = 0.9, mud = 0.15, gas = 0.55, lock = 0.55, crust = 0.3, ice = 0.7, nod = 0.45, nug = 1.2, geo = 3.0, colour = 0.07}
const BASE := 5.1
## a shape that is slower to work through than its cells say: shafts dug from the top, a lower tier behind a throat
const SCHEME_WORK := {shafts = 6.0, tiers = 4.0}
const MARGIN := 4.5
const TIGHT := 0.0
const NEED_MAX := 28.0
const MOVES := Vector2i(12, 34)

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
	return make(Save.area(), dl, int(Save.d.lseed) + dl * 7919, bool(Save.d.lrich) and not _veins_poor(dl), wins)

## the mine's boss fight from its first board, with its health lowered 5% for every fight lost (to 70% at most)
static func boss_fight(area: int) -> Dictionary:
	var B: Dictionary = Data.AREAS[area].get("boss", {})
	if B.is_empty(): return {}
	var tries: int = int(Save.d.boss_tries[area]) if area < Save.d.boss_tries.size() else 0
	var hp := roundi(int(B.hp) * maxf(0.7, 1.0 - 0.05 * tries) / 3.0) * 3
	return BoardModel.boss_level(B, 0, hp)

## a rich level doubles the ore stones, so it is not handed out on veins worked down to their last tenth
static func _veins_poor(dl: int) -> bool:
	if dl >= Save.d.vein.size(): return false
	var D: Dictionary = Data.depth(Save.area(), dl)
	var v: Array = Save.d.vein[dl]
	return int(v[0]) <= BoardModel.vein_floor(int(D.fe)) and int(v[1]) <= BoardModel.vein_floor(int(D.au))

static func make(area: int, dl: int, seed_v: int, rich: bool, wins: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v * 31 + area
	var T := tier(dl, area)
	var nk := new_kind(dl, area)
	var intro := nk != "" and wins == 0
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
	# what goes where
	var kinds: Array = T.kinds
	var ka: String = nk if intro else _pick(rng, kinds, nk)
	var kb: String = "" if intro else _pick(rng, kinds, "")
	if kb == ka and rng.randf() < 0.5: kb = ""
	if kb == "":
		groups.a.append_array(groups.b)
		groups.b = []
	var big := float(R * C) / 72.0 * (LOAD_K if scheme != "hand" else 1.0)
	var load: int = roundi((int(T.load) + mini(wins, 4) + rng.randi_range(-2, 2)) * big)
	if intro: load = roundi(T.load * 0.6 * big)
	var nods := NODULES.has(area) and bool(T.get("nod", area == 1))   # Proval: only the depths that bring them
	if nods: load = roundi(load * NOD_LOAD)
	var want := {a = ka, b = kb}
	for g in ["a", "b"]:
		var cap: int = roundi(int(CAP.get(want[g], 99)) * big)
		_trim(rng, groups[g], cap)
	var total: int = groups.a.size() + groups.b.size()
	while total > roundi(load * 1.25):
		var g: String = "a" if groups.a.size() >= groups.b.size() else "b"
		total -= _drop_pair(rng, groups[g])
	if total < roundi(load * 0.7):
		var g: String = "a" if groups.b.is_empty() or rng.randf() < 0.5 else "b"
		var cap2: int = roundi(int(CAP.get(want[g], 99)) * big)
		while total < roundi(load * 0.8) and groups[g].size() < cap2:
			var added := _add_pair(rng, grid, groups)
			if added == 0: break
			total += added
	# a mine with nodules keeps room for them in the work a level may ask for
	var nod_want := 0
	if nods:
		var nn: Vector2i = NODULES[area]
		nod_want = mini(nn.x + dl / 2, nn.y)
	var reserve := nod_want * float(WORK.nod) + float(SCHEME_WORK.get(scheme, 0.0))
	# no more work than a level may ask for: the heavier group gives up a pair at a time
	var est := func() -> float:
		var w := 0.0
		for g in ["a", "b"]:
			if want[g] != "": w += groups[g].size() * float(WORK[want[g]])
		return w
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
	var goals := []
	if used.has("sand") or used.has("granite"): goals.append(["rock"])
	for k in ["mud", "gas", "lock", "crust", "ice"]:
		if used.has(k): goals.append([k])
	# a nugget to bring down, a geode to crack: now and then, never on a first look at something new
	if not intro and rng.randf() < float(T.get("nug", 0.25)) and BASE + work + WORK.nug <= NEED_MAX:
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
	if not intro and goals.size() < 3 and rng.randf() < 0.2 and BASE + work + WORK.geo <= NEED_MAX:
		var spot := _geo_spot(rng, grid, geo_at)
		if spot.x >= 0:
			grid[spot.x][spot.y] = "G"
			for d: Vector2i in BoardModel.QUAD:
				if d != Vector2i.ZERO: grid[spot.x + d.x][spot.y + d.y] = "+"
			goals.append(["geo"])
			work += WORK.geo
			count.geo = 1
	# a colour to collect: when the board is bare, or now and then beside one obstacle
	if goals.is_empty() or (goals.size() == 1 and not intro and rng.randf() < 0.3):
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
		rows.append("".join(grid[r]).replace("+", "."))
	var moves := clampi(roundi(BASE + work + MARGIN - TIGHT * dl) + (3 if intro else 0), MOVES.x, MOVES.y)
	return {map = "|".join(rows), goals = goals, moves = moves, hard = false, gen = true, colors = 5,
		rich = rich, intro = intro, kinds = used.keys(), count = count, scheme = scheme}

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
			# two boards, one over the other, joined by a throat in the middle (or not at all: each fills from its
			# top); the lower one mostly blocks
			var rt := rng.randi_range(R / 2 - 1, R / 2)
			var throat := rng.randi_range(0, 2)
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
			# shafts two wide down both sides behind a wall of holes, packed with blocks; a band across the middle between
			# them, in the lower half. The wall has a window every other row: a shaft walled off whole is dug out one
			# layer at a time from its top only (+24 moves for the smart player)
			var sw := 2
			var rs := rng.randi_range(R / 2 - 1, R / 2 + 1)
			for r in range(rs, R):
				if (r - rs) % 2 == 0: _hole(grid, r, sw)
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

## a hole and its mirror image
static func _hole(grid: Array, r: int, c: int) -> void:
	grid[r][c] = "#"
	grid[r][C - 1 - c] = "#"

## a block cell of group g and its mirror image (on an open cell, once)
static func _put(grid: Array, groups: Dictionary, g: String, r: int, c: int) -> void:
	for q in [Vector2i(r, c), Vector2i(r, C - 1 - c)]:
		if q.x >= 0 and q.x < R and grid[q.x][q.y] == "." and not q in groups.a and not q in groups.b:
			groups[g].append(q)

## a nugget here reaches the bottom: no hole under it with board below the hole (it would sit over it for ever)
static func _falls_out(grid: Array, p: Vector2i) -> bool:
	var gap := false
	for r in range(p.x + 1, R):
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
static func _add_pair(rng: RandomNumberGenerator, grid: Array, groups: Dictionary) -> int:
	var g: String = "a" if groups.b.is_empty() or rng.randf() < 0.5 else "b"
	for tries in 30:
		var p := Vector2i(rng.randi_range(1, R - 2), rng.randi_range(0, C / 2 - 1))
		var near: bool = groups[g].is_empty()
		for d: Vector2i in BoardModel.DIRS4:
			if p + d in groups[g]: near = true
		if not near: continue
		var n := 0
		for q in [p, Vector2i(p.x, C - 1 - p.y)]:
			if grid[q.x][q.y] == "." and not q in groups.a and not q in groups.b:
				groups[g].append(q)
				n += 1
		if n: return n
	return 0

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
