class_name LevelGen
extends RefCounted
## Levels made on the spot for a depth of a mine. The shape of the board comes from a hand-made level (its holes and
## where its blocks lie) or is drawn here, mirrored left to right; what fills the block cells, how much of it, the
## goals and the moves come from the depth. A level is new each time one is played (Save.d.lseed); the first level at
## a depth that brings a new obstacle shows that obstacle alone. The result is a level def like Data.LEVELS' ones,
## plus {gen, colors, rich, intro}.

const R := BoardModel.R
const C := BoardModel.C
## what each depth puts on the board (Old Adit; the other mines use the same for now): the obstacles it may use and
## about how many cells they take. A new obstacle every other depth: 100 m granite, 200 m gas, 300 m timber
const TIERS := [
	{kinds = ["sand", "mud"], load = 10},
	{kinds = ["sand", "mud", "granite"], load = 12},
	{kinds = ["sand", "mud", "granite"], load = 15},
	{kinds = ["sand", "mud", "granite", "gas"], load = 14},
	{kinds = ["sand", "mud", "granite", "gas"], load = 17},
	{kinds = ["sand", "mud", "granite", "gas", "lock"], load = 18},
]
const CH := {sand = "r", granite = "R", mud = "m", gas = "g", lock = "l"}
## gas spreads and timber pins stones: a little of either goes a long way
const CAP := {gas = 6, lock = 10}
## the moves a level needs: BASE + WORK of each obstacle cell (a nugget, the geode, a stone of a colour goal),
## fitted to the autoplayer's wins on 180 generated levels (`-- sim_gen=30 sim_rows`, logistic fit 25.10).
## A level gets MARGIN more than it needs, a little less at every depth (TIGHT); the autoplayer then wins ~60%,
## a live player more. What a level asks for is kept within NEED_MAX, so no level wants 50 moves.
const WORK := {sand = 0.65, granite = 1.2, mud = 0.6, gas = 2.2, lock = 1.9, nug = 4.0, geo = 2.5, colour = 0.11}
const BASE := 10.4
const MARGIN := 2.5
const TIGHT := 0.0
const NEED_MAX := 31.0
const MOVES := Vector2i(16, 34)

static func tier(dl: int) -> Dictionary:
	return TIERS[clampi(dl, 0, TIERS.size() - 1)]

## the obstacle a depth brings that the one above did not have, or ""
static func new_kind(dl: int) -> String:
	if dl <= 0: return ""
	var above: Array = tier(dl - 1).kinds
	for k in tier(dl).kinds:
		if not k in above: return k
	return ""

## the level waiting at a depth of the current mine
static func current(dl: int) -> Dictionary:
	var dw: Array = Save.d.dwins
	var wins: int = int(dw[dl]) if dl < dw.size() else 0
	return make(Save.area(), dl, int(Save.d.lseed) + dl * 7919, bool(Save.d.lrich) and not _veins_poor(dl), wins)

## a rich level doubles the ore stones, so it is not handed out on veins worked down to their last tenth
static func _veins_poor(dl: int) -> bool:
	if dl >= Save.d.vein.size(): return false
	var D: Dictionary = Data.depth(Save.area(), dl)
	var v: Array = Save.d.vein[dl]
	return int(v[0]) <= BoardModel.vein_floor(int(D.fe)) and int(v[1]) <= BoardModel.vein_floor(int(D.au))

static func make(area: int, dl: int, seed_v: int, rich: bool, wins: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v * 31 + area
	var T := tier(dl)
	var nk := new_kind(dl)
	var intro := nk != "" and wins == 0
	var grid := []
	for r in R:
		var row := []
		row.resize(C)
		row.fill(".")
		grid.append(row)
	# block cells in two groups, each filled with one obstacle; spots for nuggets and a geode
	var groups := {a = [], b = []}
	var nugs := []
	var geo_at := []
	if rng.randf() < 0.6:
		_from_hand(rng, grid, groups, nugs, geo_at)
	else:
		_drawn(rng, grid, groups)
	# what goes where
	var kinds: Array = T.kinds
	var ka: String = nk if intro else _pick(rng, kinds, nk)
	var kb: String = "" if intro else _pick(rng, kinds, "")
	if kb == ka and rng.randf() < 0.5: kb = ""
	if kb == "":
		groups.a.append_array(groups.b)
		groups.b = []
	var load: int = int(T.load) + mini(wins, 4) + rng.randi_range(-2, 2)
	if intro: load = roundi(T.load * 0.6)
	var want := {a = ka, b = kb}
	for g in ["a", "b"]:
		var cap: int = int(CAP.get(want[g], 99))
		_trim(rng, groups[g], cap)
	var total: int = groups.a.size() + groups.b.size()
	while total > roundi(load * 1.25):
		var g: String = "a" if groups.a.size() >= groups.b.size() else "b"
		total -= _drop_pair(rng, groups[g])
	if total < roundi(load * 0.7):
		var g: String = "a" if groups.b.is_empty() or rng.randf() < 0.5 else "b"
		var cap2: int = int(CAP.get(want[g], 99))
		while total < roundi(load * 0.8) and groups[g].size() < cap2:
			var added := _add_pair(rng, grid, groups)
			if added == 0: break
			total += added
	# no more work than a level may ask for: the heavier group gives up a pair at a time
	var est := func() -> float:
		var w := 0.0
		for g in ["a", "b"]:
			if want[g] != "": w += groups[g].size() * float(WORK[want[g]])
		return w
	while BASE + float(est.call()) > NEED_MAX:
		var ga: float = groups.a.size() * float(WORK.get(want.a, 0.0))
		var gb: float = groups.b.size() * float(WORK.get(want.b, 0.0))
		if _drop_pair(rng, groups["a" if ga >= gb else "b"]) == 0: break
	var work := 0.0
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
	for k in ["mud", "gas", "lock"]:
		if used.has(k): goals.append([k])
	# a nugget to bring down, a geode to crack: now and then, never on a first look at something new
	if not intro and rng.randf() < 0.25 and BASE + work + WORK.nug <= NEED_MAX:
		if nugs.is_empty(): nugs = [Vector2i(0, 2), Vector2i(0, 5)]
		var put := 0
		for p: Vector2i in nugs:
			if put < 2 and grid[p.x][p.y] == "." and BASE + work + WORK.nug * (put + 1) <= NEED_MAX:
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
	var rows := PackedStringArray()
	for r in R:
		rows.append("".join(grid[r]).replace("+", "."))
	var moves := clampi(roundi(BASE + work + MARGIN - TIGHT * dl) + (3 if intro else 0), MOVES.x, MOVES.y)
	return {map = "|".join(rows), goals = goals, moves = moves, hard = false, gen = true, colors = 5,
		rich = rich, intro = intro, kinds = used.keys(), count = count}

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

## drop a cell and its mirror image; returns how many went
static func _drop_pair(rng: RandomNumberGenerator, cells: Array) -> int:
	if cells.is_empty(): return 0
	var p: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
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
