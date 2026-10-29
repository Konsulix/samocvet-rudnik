class_name BoardModel
extends RefCounted
## The match-3 board as pure data and rules, with no drawing.
## A move is resolved as one time-ordered blast; everything the view needs to show is appended to `fx`
## as {t (ms after the blast starts), type, ...}. The view plays those; the model is already in its final state.

## the board's size: from the level's map (rows x the longest row), at most MAX_R x MAX_C; 9 x 8 without a map
var R := 9
var C := 8
const MAX_R := 11
const MAX_C := 9
const DIRS4 := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const QUAD := [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 1)]

class Gem:
	var id: int
	var t: int = -1            # colour, -1 for specials and items
	var sp: String = ""        # "", rh, rv, bomb, drill, orb
	var item: String = ""      # "", nug
	var ore: String = ""       # "", iron (the common ore), ore (the mine's own): one unit when it breaks
	var die_t: float = -1.0    # blast time it was destroyed at, -1 while alive
	var merge := Vector2i(-1, -1)   # cell it slides into when it melts into a new special
	var carry: String = ""     # a drill carrying another special to its target
	var spawn_y: float = 0.0   # where a freshly dropped stone starts, in rows (negative = above)
	var convert_t: float = -1.0
	var convert_sp: String = ""
	func _init(i: int, colour: int) -> void:
		id = i
		t = colour
	func alive() -> bool:
		return die_t < 0.0

var rng := RandomNumberGenerator.new()
var uid := 1
var G := []
var ROCK := []
var ROCK_MAX := []   # how hard each rock started: a granite (2) stays granite, cracked, once hit
var MUD := []
var GAS := []
var LOCK := []      # 1: timber, 2: malachite crust (Copper Mountain: cracks off from a match beside it too), 3: a tentacle's grip
var NOD := []       # a malachite nodule's layers, 0 = none (Copper Mountain): cut off, it gives its layers as ore
var NOD_T := []     # moves until it grows its next layer
var FLW := []       # the cells of the Mistress' stone flower (2x2, "F" on her board's map: its top left)
## her stone flower: {r, c, st (rings out, 1..3)}; a match beside it or a hit tears its outer ring off, her turn grows
## one back, and in full bloom it heals her and crusts the stones round it
var flower := {}
## the Kraken (Whalebone Cove): ink hides stones, still playable (moves left before it thins away); the tide floods the
## bottom rows (moves left: its stones can't move, match or be hit); SEA: 1 the maelstrom's water in the middle of its
## ring (3x3, "O" on the map: its top left), 2 his eye (3x3, "E")
var INK := []
var TIDE := []
var SEA := []
## his tentacles: [{id, cells: from the rim to the tip}], their stones gripped (LOCK 3); a hit cuts one there, a match
## beside its tip cuts the tip; left on the board, each drags the stone at its tip into the deep when he acts, and heals him
var tentacles := []
var _tid := 0
## the maelstrom's ring round its water, clockwise: its stones go round a cell after every move
var ring := []
## his eye on the last board: {r, c, shut (moves it stays shut after a hit)}
var eye := {}
var GEOC := []
var VOID := []
var FIND := []

var n := 1
var depth := 0
var moves := 0
var hard := false
var colors := 5
var goals := []      # {k, t, left}
var over := false
var coins_won := 0
var bonus := []      # stones freed from geodes, opened after the level
var geos := []       # {r, c, w, h, hp, hp_max, done}: a done geode stays on the board, an empty shell of rock
var gas_hit := false
var find := {}       # the sealed specimen: {r, c, w, h, hp, hp_max, integ, stone, done}
## the boss fight (empty in an ordinary level): {B (the boss's data), stage, k (actions so far), timer,
## intent {act, cells}, clear (this board's share of health is gone)}. Its health is the "boss" goal.
var boss := {}
## a colour new stones are not made of (-1: any): the Mistress' lizards carry off the greens and none come back
var skip_colour := -1
var area_i := 0
## ore: which colour holds which kind, how often a stone of that colour holds it, what this level has broken
var ore_col := {}    # colour -> "iron" | "ore"
var ore_p := {}      # kind -> chance a new stone of its colour is ore-bearing
var mined := {iron = 0, ore = 0}
## a stone of an ore colour holds ore about one time in 3 (~12 of each ore a win); a vein worked down to its last tenth, a third as often
const ORE_P := 0.33
const NOD_EVERY := 3    # a nodule grows a layer every this many moves
const NOD_SPREAD := 2   # a full nodule that grows on crusts this many stones round it and starts again
const ORE_POOR := 1.0 / 3.0
## the shapes a find comes sealed in, [w, h, weight]
const FIND_SHAPES := [[2, 2, 4.0], [2, 1, 2.0], [1, 2, 2.0], [3, 1, 1.0], [1, 3, 1.0]]

## how many hits a big block takes: more the deeper the mine and the later the level, 3 to 8
static func block_hp(level_n: int, dl: int) -> int:
	return clampi(3 + level_n / 10 + dl, 3, 8)

static func cells_of(b: Dictionary) -> Array:
	var out := []
	for dr in int(b.get("h", 2)):
		for dc in int(b.get("w", 2)):
			out.append(Vector2i(int(b.r) + dr, int(b.c) + dc))
	return out
var lift := 0        # equipment levels the rules care about
var vent := 0

var fx := []
var _cleared := {}
var _rock_hit := {}
var _geo_hit := {}
var _find_hit := false
var _max_t := 0.0
var _q := []

# ------------------------------------------------------------------ setup

func _grid(v) -> Array:
	var a := []
	for r in R:
		var row := []
		row.resize(C)
		row.fill(v)
		a.append(row)
	return a

func new_gem(colour: int = -2) -> Gem:
	if colour == -2:
		colour = rng.randi_range(0, colors - 1)
		if colour == skip_colour and colors > 1:
			colour = (colour + rng.randi_range(1, colors - 1)) % colors
	var g := Gem.new(uid, colour)
	uid += 1
	var kind: String = ore_col.get(colour, "")
	if kind != "" and rng.randf() < float(ore_p.get(kind, 0.0)):
		g.ore = kind
	return g

## how rich this level's ore is: the mine picks the colours, the depth's veins the density
## (vein = [iron left, own ore left] or [] for none; poor once it is down to its unminable last tenth)
func set_ore(area: int, dl: int, vein: Array, rich := false, iron := true) -> void:
	var O: Dictionary = Data.ore(area)
	var D: Dictionary = Data.depth(area, dl)
	ore_col = {int(O.iron): "iron", int(O.local): "ore"}
	var own_k := float(O.get("p", 1.0))   # a mine whose ore also comes from elsewhere (nodules) has fewer ore stones
	ore_p = {}
	for i in 2:
		var kind: String = ["iron", "ore"][i]
		var stock: int = int(D.fe) if i == 0 else int(D.au)
		var left: int = int(vein[i]) if vein.size() > i else stock
		var p := ORE_P * (ORE_POOR if left <= vein_floor(stock) else 2.0 if rich else 1.0) * (own_k if i == 1 else 1.0)
		ore_p[kind] = p if iron or kind == "ore" else 0.0

# ------------------------------------------------------------------ the boss

func boss_on() -> bool:
	return not boss.is_empty()

## the health this board starts from and the line it can't be pushed past: each board is a third of it
func boss_top() -> int:
	return roundi(_boss_hp_max() * (3 - int(boss.stage)) / 3.0)

func boss_floor() -> int:
	return roundi(_boss_hp_max() * (2 - int(boss.stage)) / 3.0)

func _boss_hp_max() -> int:
	return int(boss.get("hp_max", int(boss.B.hp)))

func boss_hp() -> int:
	var gi := goal_index("boss")
	return int(goals[gi].left) if gi >= 0 else 0

func _boss_damage(dmg: int, r: int, c: int, t: float) -> void:
	if boss.clear: return
	var gi := goal_index("boss")
	var g: Dictionary = goals[gi]
	var fl := boss_floor()
	g.left = maxi(fl, int(g.left) - dmg)
	if g.left <= fl and fl > 0: boss.clear = true
	_fx(t, "boss_hit", {dmg = dmg, r = r, c = c, left = g.left})

## this board's share of health is gone: the next board comes in
func boss_stage_clear() -> bool:
	return boss_on() and bool(boss.clear)

## the next board of the fight: a new shape, the health and moves carried over, a few moves more
func next_stage() -> void:
	var keep := boss.duplicate()
	var hp := boss_hp()
	var mv := moves + int(keep.B.stage_moves)
	var st: int = int(keep.stage) + 1
	setup(n, [], depth, {lift = lift, vent = vent}, area_i, false, boss_level(keep.B, st, keep.get("hp_max", int(keep.B.hp))))
	boss = keep
	boss.stage = st
	boss.clear = false
	goals[goal_index("boss")].left = hp
	moves = mv
	boss_plan()

## a board of the fight as a level def
static func boss_level(B: Dictionary, stage: int, hp_max: int) -> Dictionary:
	return {boss = B, stage = stage, hp = hp_max, map = B.stages[stage].map, goals = [["boss"]], moves = int(B.moves),
		gen = true, colors = 5, m = int(B.m)}

## what the boss does next and where, shown ahead: the board's actions in turn
func boss_plan() -> void:
	var S: Dictionary = boss.B.stages[boss.stage]
	var acts: Array = S.acts
	var act: String = acts[int(boss.k) % acts.size()]
	boss.k = int(boss.k) + 1
	boss.timer = int(S.every)
	var cells := []
	var A: Dictionary = boss.B.act.get(act, {})
	if act in ["coils", "rockfall", "breath", "crust"]:
		var cand := []
		for r in range(1, R - 1):
			for c in C:
				var g: Gem = G[r][c]
				if playable(r, c) and g and g.sp == "" and g.item == "" and not LOCK[r][c] and not MUD[r][c]:
					cand.append(Vector2i(r, c))
		for k in mini(int(A.get("n", 4)), cand.size()):
			cells.append(cand.pop_at(rng.randi_range(0, cand.size() - 1)))
	if act == "lizards":
		cells = lizard_marks()
	if act == "flower" and not flower.is_empty():
		cells = cells_of(flower) if int(flower.st) >= 3 else []
	if act == "tentacle":
		cells = _tentacle_path(A) if tentacles.size() < int(A.get("max", 3)) else []
	if act == "ink":
		cells = _ink_cells()
	if act == "tide":
		cells = _tide_cells(int(A.get("rows", 2)))
	boss.intent = {act = act, cells = cells}

## a stone a tentacle can take hold of
func _grip_ok(r: int, c: int) -> bool:
	if not open(r, c) or LOCK[r][c] or Vector2i(r, c) in ring: return false
	var g: Gem = G[r][c]
	return g != null and g.sp == "" and g.item == ""

## a tentacle's way onto the board: from a cell on the rim inwards, mostly straight, now and then turning;
## its length from the act's "len" [min, max]. [] when none fits
func _tentacle_path(A: Dictionary) -> Array:
	var L: Array = A.get("len", [3, 5])
	var starts := []
	for r in R:
		for c in C:
			if not _grip_ok(r, c): continue
			for d: Vector2i in DIRS4:
				if not playable(r - d.x, c - d.y): starts.append([Vector2i(r, c), d])
	for k in mini(30, starts.size()):
		var s: Array = starts.pop_at(rng.randi_range(0, starts.size() - 1))
		var want := rng.randi_range(int(L[0]), int(L[1]))
		var path: Array = [s[0]]
		var dir: Vector2i = s[1]
		while path.size() < want:
			var opts := []
			for nd: Vector2i in [dir, dir, dir, Vector2i(dir.y, dir.x), Vector2i(-dir.y, -dir.x)]:
				var q: Vector2i = path[-1] + nd
				if _grip_ok(q.x, q.y) and q not in path: opts.append(nd)
			if opts.is_empty(): break
			dir = opts[rng.randi_range(0, opts.size() - 1)]
			path.append(path[-1] + dir)
		if path.size() >= int(L[0]): return path
	return []

## a 3x3 patch of the board for the ink, away from the clouds already there
func _ink_cells() -> Array:
	var best := []
	var best_v := -INF
	for k in 24:
		var r := rng.randi_range(1, R - 2)
		var c := rng.randi_range(1, C - 2)
		var cells := []
		var inked := 0
		for dr in range(-1, 2):
			for dc in range(-1, 2):
				if playable(r + dr, c + dc) and not SEA[r + dr][c + dc]:
					cells.append(Vector2i(r + dr, c + dc))
					if INK[r + dr][c + dc]: inked += 1
		var v := cells.size() - inked * 2.0 + rng.randf()
		if v > best_v:
			best_v = v
			best = cells
	return best

## the lowest rows of the board that have cells
func _tide_cells(rows: int) -> Array:
	var out := []
	var got := 0
	for r in range(R - 1, -1, -1):
		var any := false
		for c in C:
			if playable(r, c) and not SEA[r][c]:
				out.append(Vector2i(r, c))
				any = true
		if any: got += 1
		if got >= rows: break
	return out

## the greens the lizards will take: a share of the boss' weak colour on the board, at random
func lizard_marks(prefer: Array = []) -> Array:
	var A: Dictionary = boss.B.act.get("lizards", {})
	var greens := []
	for r in R:
		for c in C:
			var g: Gem = G[r][c]
			if g and g.t == int(boss.B.weak) and g.sp == "" and g.item == "" and not LOCK[r][c]:
				greens.append(Vector2i(r, c))
	var n := roundi(greens.size() * float(A.get("share", 0.5)))
	var out := []
	for p in prefer:
		if p in greens and out.size() < n:
			out.append(p)
			greens.erase(p)
	while out.size() < n and not greens.is_empty():
		out.append(greens.pop_at(rng.randi_range(0, greens.size() - 1)))
	return out

## the boss's turn after the player's: counts down; at zero it acts and plans the next.
## Returns {} while it waits, else {act, cells (where it landed), removed (stone ids gone), heal}
func boss_turn() -> Dictionary:
	if not boss_on() or over or boss.clear: return {}
	boss.timer = int(boss.timer) - 1
	if boss.timer > 0: return {}
	var it: Dictionary = boss.intent
	var out := {act = it.act, cells = [], removed = [], heal = 0, drag = []}
	var A: Dictionary = boss.B.act.get(it.act, {})
	# whatever he does, the tentacles left on the board first drag the stones at their tips into the deep
	if not tentacles.is_empty(): _drag(out, boss.B.act.get("tentacle", {}))
	if it.act == "tentacle":
		var path: Array = it.cells
		if path.is_empty() or not path.all(func(p: Vector2i) -> bool: return _grip_ok(p.x, p.y)):
			path = _tentacle_path(A)
		if tentacles.size() < int(A.get("max", 3)) and path.size():
			_tid += 1
			for p: Vector2i in path: LOCK[p.x][p.y] = 3
			tentacles.append({id = _tid, cells = path})
			out.cells = path
			out.tid = _tid
		boss_plan()
		return out
	if it.act in ["ink", "tide"]:
		var grid: Array = INK if it.act == "ink" else TIDE
		for p: Vector2i in it.cells:
			if not playable(p.x, p.y) or SEA[p.x][p.y]: continue
			grid[p.x][p.y] = int(A.get("moves", 3 if it.act == "ink" else 2))
			out.cells.append(p)
		boss_plan()
		return out
	if it.act == "lizards":
		# the stones moved since the cells were marked: the share of the greens there are now, the marked ones first.
		# They are left on the board for the show to carry off; the level removes them, refills without green
		# (skip_colour, cleared by the level after the refill) - no damage, no defence
		for p: Vector2i in lizard_marks(it.cells):
			out.cells.append(p)
			out.removed.append(G[p.x][p.y].id)
		skip_colour = int(boss.B.weak)
		boss_plan()
		return out
	if it.act == "flower":
		_flower_turn(out, A)
		boss_plan()
		return out
	for p: Vector2i in it.cells:
		var g: Gem = G[p.x][p.y]
		if g == null or g.sp != "" or g.item != "" or LOCK[p.x][p.y]: continue
		match String(it.act):
			"coils":
				LOCK[p.x][p.y] = 1
			"crust":
				LOCK[p.x][p.y] = 2
			"rockfall":
				out.removed.append(g.id)
				G[p.x][p.y] = null
				ROCK[p.x][p.y] = int(A.get("hard", 2 if int(boss.stage) >= 2 else 1))
				ROCK_MAX[p.x][p.y] = ROCK[p.x][p.y]
			"breath":
				out.removed.append(g.id)
				G[p.x][p.y] = null
				GAS[p.x][p.y] = 1
		out.cells.append(p)
	if it.act == "hoard":
		# every gold-bearing stone of its colour left on the board feeds it, never past this board's share
		var cnt := 0
		for r in R:
			for c in C:
				var g: Gem = G[r][c]
				if g and g.t == int(boss.B.weak) and g.ore == "ore": cnt += 1
		var gi := goal_index("boss")
		var before := int(goals[gi].left)
		goals[gi].left = mini(boss_top(), before + mini(int(A.cap), cnt * int(A.per)))
		out.heal = int(goals[gi].left) - before
	boss_plan()
	return out

## every tentacle on the board takes the stone at its tip down into the deep: he heals (never past this board's share).
## The cell stays gripped, empty; out.drag gets {tid, r, c, id}
func _drag(out: Dictionary, A: Dictionary) -> void:
	var gi := goal_index("boss")
	var before := int(goals[gi].left)
	for tn: Dictionary in tentacles:
		var p: Vector2i = tn.cells[-1]
		var g: Gem = G[p.x][p.y]
		if g == null or g.item != "": continue
		out.drag.append({tid = tn.id, r = p.x, c = p.y, id = g.id})
		G[p.x][p.y] = null
		goals[gi].left = mini(boss_top(), int(goals[gi].left) + int(A.get("drag", 20)))
	out.heal = int(out.heal) + int(goals[gi].left) - before

## cut the tentacle gripping (r, c) there: the cell and all of it out to the tip let go. A match beside it cuts only
## its tip (tip_only). Each cell cut hurts him a little. Returns whether anything was cut
func _cut_tentacle(r: int, c: int, t: float, tip_only: bool) -> bool:
	var p := Vector2i(r, c)
	for i in tentacles.size():
		var tn: Dictionary = tentacles[i]
		var j: int = tn.cells.find(p)
		if j < 0: continue
		if tip_only and j != tn.cells.size() - 1: return false
		var cut: Array = tn.cells.slice(j)
		tn.cells = tn.cells.slice(0, j)
		for q: Vector2i in cut: LOCK[q.x][q.y] = 0
		_fx(t, "tentacle_cut", {tid = tn.id, r = r, c = c, cells = cut, left = tn.cells.size()})
		if tn.cells.is_empty(): tentacles.remove_at(i)
		var A: Dictionary = boss.B.act.get("tentacle", {}) if boss_on() else {}
		if int(A.get("cut", 0)): _boss_damage(int(A.cut) * cut.size(), r, c, t)
		return true
	LOCK[r][c] = 0
	return true

## the sea's own move after each of the player's (the Kraken's boards): the maelstrom turns its ring a cell
## clockwise, stones and all; ink thins, the tide ebbs, the eye opens. Returns {turned: [[id, from, to]]}
func sea_turn() -> Dictionary:
	var out := {turned = []}
	for r in R:
		for c in C:
			if INK[r][c]: INK[r][c] -= 1
			if TIDE[r][c]: TIDE[r][c] -= 1
	if not eye.is_empty(): eye.shut = maxi(0, int(eye.shut) - 1)
	if ring.size():
		var gs := []
		for p: Vector2i in ring: gs.append(G[p.x][p.y])
		for i in ring.size():
			var to: Vector2i = ring[(i + 1) % ring.size()]
			G[to.x][to.y] = gs[i]
			if gs[i]: out.turned.append([(gs[i] as Gem).id, ring[i], to])
	return out

## the ring of cells round a w x h block at (r, c), clockwise from its top-left corner
func _ring_round(r: int, c: int, w: int, h: int) -> Array:
	var out := []
	var r0 := r - 1
	var c0 := c - 1
	var r1 := r + h
	var c1 := c + w
	for x in range(c0, c1): out.append(Vector2i(r0, x))
	for y in range(r0, r1): out.append(Vector2i(y, c1))
	for x in range(c1, c0, -1): out.append(Vector2i(r1, x))
	for y in range(r1, r0, -1): out.append(Vector2i(y, c0))
	return out

## her flower grows a ring back; already full, it blooms: heals her (never past this board's share), crusts the stones
## round it and closes to its buds again. out gets {grow: the new ring count | bloom, heal, cells: the crusted ones}
func _flower_turn(out: Dictionary, A: Dictionary) -> void:
	if flower.is_empty(): return
	if int(flower.st) < 3:
		flower.st = int(flower.st) + 1
		out.grow = flower.st
		return
	out.bloom = true
	var gi := goal_index("boss")
	var before := int(goals[gi].left)
	goals[gi].left = mini(boss_top(), before + int(A.get("heal", 60)))
	out.heal = int(goals[gi].left) - before
	var cand := []
	for dr in range(-1, 3):
		for dc in range(-1, 3):
			var p := Vector2i(int(flower.r) + dr, int(flower.c) + dc)
			if not playable(p.x, p.y) or FLW[p.x][p.y]: continue
			var g: Gem = G[p.x][p.y]
			if g and g.sp == "" and g.item == "" and not LOCK[p.x][p.y]: cand.append(p)
	for i in mini(int(A.get("crust", 6)), cand.size()):
		var p: Vector2i = cand.pop_at(rng.randi_range(0, cand.size() - 1))
		LOCK[p.x][p.y] = 2
		out.cells.append(p)
	flower.st = 1

## the moves a level starts with: a generated level has them counted for its depth already
static func start_moves(def: Dictionary, dl: int, eq: Dictionary) -> int:
	return int(def.moves) - (0 if def.get("gen", false) else dl / 2) + int(eq.get("food", 0))

## the part of a vein that never runs out
static func vein_floor(stock: int) -> int:
	return int(ceil(stock * 0.1))

## level n at depth dl; pre: specials bought before the level; eq: {lift, vent, food};
## level: a def made by LevelGen (empty: the hand-made level n, hardened by depth the old way)
func setup(level_n: int, pre: Array = [], dl: int = 0, eq: Dictionary = {}, area: int = 0, roll_find := true, level: Dictionary = {}) -> void:
	var def: Dictionary = level if not level.is_empty() else Data.level_def(level_n)
	var gen := bool(def.get("gen", false))
	area_i = area
	boss = {}
	if def.has("boss"):
		boss = {B = def.boss, stage = int(def.get("stage", 0)), hp_max = int(def.hp), k = 0, timer = 0, intent = {}, clear = false}
		roll_find = false
	n = level_n
	depth = dl
	var vein: Array = Save.d.vein[dl] if area == Save.area() and dl < Save.d.vein.size() else []
	# no ore is mined at the boss: only the stones of its weak colour carry gold, and hurt it more
	set_ore(area, dl, vein, bool(def.get("rich", false)), not def.has("boss"))
	lift = int(eq.get("lift", 0))
	vent = int(eq.get("vent", 0))
	moves = start_moves(def, dl, eq)
	hard = bool(def.get("hard", false))
	colors = int(def.colors) if gen else 6 if dl >= 4 else 5
	goals = []
	over = false
	coins_won = 0
	mined = {iron = 0, ore = 0}
	bonus = []
	geos = []
	find = {}
	flower = {}
	tentacles = []
	ring = []
	eye = {}
	var rows: PackedStringArray = String(def.get("map", "")).split("|") if def.get("map", "") != "" else PackedStringArray()
	R = 9
	C = 8
	if rows.size():
		R = mini(rows.size(), MAX_R)
		C = 0
		for row in rows: C = mini(maxi(C, row.length()), MAX_C)
	# ORE_P is for a 9 x 8 board played in ~26 moves: a bigger board and a longer level break more stones, each of
	# them less often ore (a generated level; the boss' gold and the hand-made levels stay as they were)
	if gen and boss.is_empty():
		for k in ore_p: ore_p[k] = float(ore_p[k]) * minf(1.0, 72.0 / (R * C)) * minf(1.0, 26.0 / maxi(1, moves))
	G = _grid(null); ROCK = _grid(0); MUD = _grid(0); GAS = _grid(0); LOCK = _grid(0); NOD = _grid(0); NOD_T = _grid(0); FLW = _grid(false); INK = _grid(0); TIDE = _grid(0); SEA = _grid(0); GEOC = _grid(-1); VOID = _grid(false); FIND = _grid(false)
	var rocks := 0; var muds := 0; var nugs := 0; var gas := 0; var locks := 0
	for r in R:
		var row: String = rows[r] if r < rows.size() else ""
		for c in C:
			var ch := row[c] if c < row.length() else "."
			match ch:
				"#": VOID[r][c] = true
				"r", "R":
					ROCK[r][c] = 2 if ch == "R" else 1
					rocks += 1
				"m":
					MUD[r][c] = 1
					muds += 1
				"n":
					var g := new_gem(-1)
					g.item = "nug"
					G[r][c] = g
					nugs += 1
				"g":
					GAS[r][c] = 1
					gas += 1
				"l":
					LOCK[r][c] = 1
					locks += 1
				"c":
					LOCK[r][c] = 2
				"F":
					flower = {r = r, c = c, st = 1}
					for d in QUAD:
						FLW[r + d.x][c + d.y] = true
				"O", "E":
					for dr in 3:
						for dc in 3: SEA[r + dr][c + dc] = 1 if ch == "O" else 2
					if ch == "O": ring = _ring_round(r, c, 3, 3)
					else: eye = {r = r, c = c, shut = 0}
				"k":
					NOD[r][c] = 1
					NOD_T[r][c] = NOD_EVERY - (r + c) % 2   # neighbours a move apart, not all in step
				"G":
					var gi := geos.size()
					var ghp := block_hp(level_n, dl)
					geos.append({r = r, c = c, w = 2, h = 2, hp = ghp, hp_max = ghp, done = false})
					for d in QUAD:
						GEOC[r + d.x][c + d.y] = gi
	# the find: a specimen sealed in a 2x2 block of rock, somewhere in the lower half
	if roll_find:
		var shape: Array = Stones.pick_w(FIND_SHAPES.map(func(sh): return [sh, sh[2]]), Rng32.new(rng.randi()))
		var fw: int = shape[0]
		var fh: int = shape[1]
		var spots := []
		for r in range(3, R - fh):
			for c in range(1, C - fw):
				var ok := true
				for d in cells_of({r = 0, c = 0, w = fw, h = fh}):
					var rr: int = r + d.x
					var cc: int = c + d.y
					if not playable(rr, cc) or ROCK[rr][cc] or GAS[rr][cc] or GEOC[rr][cc] >= 0 or LOCK[rr][cc] or MUD[rr][cc] or NOD[rr][cc] or FLW[rr][cc] or G[rr][cc] != null:
						ok = false
				if ok:
					spots.append([r, c, absf(r + fh * 0.5 - R * 0.72) + absf(c + fw * 0.5 - C / 2.0) * 0.7])
		spots.sort_custom(func(a, b): return a[2] < b[2])
		if spots.size():
			var s: Array = spots[rng.randi_range(0, mini(5, spots.size() - 1))]
			var hp := block_hp(level_n, dl)
			var stone := Stones.roll(Save.next_uid(), area, (0.6 if hard else 0.2) + dl * 0.35, dl)
			find = {r = s[0], c = s[1], w = fw, h = fh, hp = hp, hp_max = hp, integ = 100, stone = stone, done = false}
			for p in cells_of(find):
				FIND[p.x][p.y] = true
	# the deeper you dig, the harder the board (a generated level is already made for its depth)
	if dl >= 1 and not gen:
		for r in R:
			for c in C:
				if ROCK[r][c] == 1:
					ROCK[r][c] = 2
	if dl >= 2 and not gen:
		var f := _free_cells()
		for k in dl + 1:
			if f.is_empty(): break
			var p: Vector2i = f.pop_at(rng.randi_range(0, f.size() - 1))
			GAS[p.x][p.y] = 1
	if dl >= 3 and not gen:
		var f := _free_cells()
		for k in dl * 2:
			if f.is_empty(): break
			var p: Vector2i = f.pop_at(rng.randi_range(0, f.size() - 1))
			LOCK[p.x][p.y] = 1
	ROCK_MAX = ROCK.duplicate(true)
	rocks = 0; gas = 0; locks = 0
	for r in R:
		for c in C:
			if ROCK[r][c]: rocks += 1
			if GAS[r][c]: gas += 1
			if LOCK[r][c] == 1: locks += 1
	if not find.is_empty():
		goals.append({k = "find", t = -1, left = 1})
	for gd in def.goals:
		match String(gd[0]):
			"c": goals.append({k = "c", t = int(gd[1]), left = int(gd[2])})
			"rock": goals.append({k = "rock", t = -1, left = rocks + _count_granite()})
			"mud": goals.append({k = "mud", t = -1, left = muds})
			"nug": goals.append({k = "nug", t = -1, left = nugs})
			"gas": goals.append({k = "gas", t = -1, left = gas})
			"lock": goals.append({k = "lock", t = -1, left = locks})
			"crust": goals.append({k = "crust", t = -1, left = _count_lock(2)})
			"geo": goals.append({k = "geo", t = -1, left = geos.size()})
			"boss": goals.append({k = "boss", t = int(boss.B.weak), left = int(def.hp)})
	# fill without ready-made matches, and make sure a move exists
	for tries in 40:
		for r in R:
			for c in C:
				if open(r, c) and not (G[r][c] != null and G[r][c].item != ""):
					var t := 0
					while true:
						t = rng.randi_range(0, colors - 1)
						if not ((c >= 2 and col(r, c - 1) == t and col(r, c - 2) == t) or (r >= 2 and col(r - 1, c) == t and col(r - 2, c) == t)):
							break
					G[r][c] = new_gem(t)
		if find_groups().is_empty() and has_moves():
			break
	# boosters chosen before the level land on the board as ready specials
	var cand := []
	for r in range(1, R - 1):
		for c in C:
			var g: Gem = G[r][c]
			if g and g.t >= 0 and not LOCK[r][c]:
				cand.append(g)
	for sp in pre:
		if cand.is_empty(): break
		var g: Gem = cand.pop_at(rng.randi_range(0, cand.size() - 1))
		g.sp = sp
		g.t = -1
		g.ore = ""
	if boss_on(): boss_plan()

func _free_cells() -> Array:
	var a := []
	for r in range(1, R - 1):
		for c in C:
			if playable(r, c) and not ROCK[r][c] and not GAS[r][c] and GEOC[r][c] < 0 and not FIND[r][c] and G[r][c] == null and not LOCK[r][c] and not MUD[r][c] and not NOD[r][c] and not FLW[r][c]:
				a.append(Vector2i(r, c))
	return a

func _count_lock(v: int) -> int:
	var k := 0
	for r in R:
		for c in C:
			if LOCK[r][c] == v: k += 1
	return k

func _count_granite() -> int:
	var k := 0
	for r in R:
		for c in C:
			if ROCK[r][c] == 2: k += 1
	return k

# ------------------------------------------------------------------ queries

func playable(r: int, c: int) -> bool:
	return r >= 0 and c >= 0 and r < R and c < C and not VOID[r][c]

func open(r: int, c: int) -> bool:
	return playable(r, c) and not ROCK[r][c] and not GAS[r][c] and GEOC[r][c] < 0 and not FIND[r][c] and not NOD[r][c] and not FLW[r][c] and not SEA[r][c] and not TIDE[r][c]

## the colour a cell counts as for matching, -1 if it can't match
func col(r: int, c: int) -> int:
	if r < 0 or c < 0 or r >= R or c >= C: return -1
	var g: Gem = G[r][c]
	if g == null or g.sp != "" or g.item != "" or not g.alive() or TIDE[r][c]: return -1
	return g.t

func gem_at(r: int, c: int) -> Gem:
	return G[r][c] if playable(r, c) else null

func goals_done() -> bool:
	for g in goals:
		if g.left > 0: return false
	return true

func goal_index(k: String) -> int:
	for i in goals.size():
		if goals[i].k == k: return i
	return -1

# ------------------------------------------------------------------ matching

## connected groups of 3+ in a row or 2x2 squares, each with the special it makes
func find_groups() -> Array:
	var runs := []
	for r in R:
		var c := 0
		while c < C:
			var t := col(r, c)
			var e := c + 1
			if t >= 0:
				while e < C and col(r, e) == t: e += 1
			if t >= 0 and e - c >= 3:
				var ks := []
				for i in e - c: ks.append(r * C + c + i)
				runs.append({d = "h", len = e - c, ks = ks})
			c = e
	for c in C:
		var r := 0
		while r < R:
			var t := col(r, c)
			var e := r + 1
			if t >= 0:
				while e < R and col(e, c) == t: e += 1
			if t >= 0 and e - r >= 3:
				var ks := []
				for i in e - r: ks.append((r + i) * C + c)
				runs.append({d = "v", len = e - r, ks = ks})
			r = e
	var squares := []
	for r in R - 1:
		for c in C - 1:
			var t := col(r, c)
			if t >= 0 and col(r, c + 1) == t and col(r + 1, c) == t and col(r + 1, c + 1) == t:
				squares.append({ks = [r * C + c, r * C + c + 1, (r + 1) * C + c, (r + 1) * C + c + 1]})
	# union-find over every matched cell
	var parent := {}
	var find_root := func(k: int) -> int:
		while parent[k] != k:
			parent[k] = parent[parent[k]]
			k = parent[k]
		return k
	for set_ in runs + squares:
		for k in set_.ks:
			if not parent.has(k): parent[k] = k
		for k in set_.ks:
			var a: int = find_root.call(set_.ks[0])
			var b: int = find_root.call(k)
			if a != b: parent[b] = a
	var groups := {}
	for k in parent:
		var root: int = find_root.call(k)
		if not groups.has(root):
			groups[root] = {cells = [], max_h = 0, max_v = 0, squares = 0}
		groups[root].cells.append(k)
	for ru in runs:
		var g: Dictionary = groups[find_root.call(ru.ks[0])]
		if ru.d == "h": g.max_h = maxi(g.max_h, ru.len)
		else: g.max_v = maxi(g.max_v, ru.len)
	for sq in squares:
		groups[find_root.call(sq.ks[0])].squares += 1
	var out := []
	for g in groups.values():
		var mh: int = g.max_h
		var mv: int = g.max_v
		g.special = "orb" if mh >= 5 or mv >= 5 else "bomb" if mh >= 3 and mv >= 3 else "rh" if mh == 4 else "rv" if mv == 4 else "drill" if g.squares else ""
		out.append(g)
	return out

func _try_swap_matches(r1: int, c1: int, r2: int, c2: int) -> bool:
	if not open(r1, c1) or not open(r2, c2) or G[r1][c1] == null or G[r2][c2] == null or LOCK[r1][c1] or LOCK[r2][c2]:
		return false
	var a = G[r1][c1]
	G[r1][c1] = G[r2][c2]
	G[r2][c2] = a
	var ok := not find_groups().is_empty()
	G[r2][c2] = G[r1][c1]
	G[r1][c1] = a
	return ok

func has_moves() -> bool:
	for r in R:
		for c in C:
			var g: Gem = G[r][c]
			if g and g.sp != "": return true
	for r in R:
		for c in C:
			if open(r, c) and (_try_swap_matches(r, c, r, c + 1) or _try_swap_matches(r, c, r + 1, c)):
				return true
	return false

## a move that works, as [r1, c1, r2, c2]; a special is tapped in place (r1 == r2, c1 == c2)
func find_move() -> Array:
	for r in R:
		for c in C:
			var g: Gem = G[r][c]
			if g and g.sp != "": return [r, c, r, c]
	for r in R:
		for c in C:
			for d in [Vector2i(0, 1), Vector2i(1, 0)]:
				if _try_swap_matches(r, c, r + d.x, c + d.y):
					return [r, c, r + d.x, c + d.y]
	return []

# ------------------------------------------------------------------ blasts

func _push(r: int, c: int, t: float, kind := "fx") -> void:
	_q.append({t = t, r = r, c = c, kind = kind})

func _push_fn(t: float, fn: Callable) -> void:
	_q.append({t = t, fn = fn})

func _fx(t: float, type: String, extra := {}) -> void:
	var e := {t = t, type = type}
	e.merge(extra)
	fx.append(e)

## run every hit a move causes, in time order; returns when the last one lands (ms)
func run_blast(events: Array) -> float:
	_cleared = {}
	_rock_hit = {}
	_geo_hit = {}
	_find_hit = false
	_max_t = 0.0
	_q = events.duplicate()
	while not _q.is_empty():
		_q.sort_custom(func(a, b): return a.t < b.t)
		var e: Dictionary = _q.pop_front()
		if e.has("fn"):
			e.fn.call(e.t)
		else:
			hit(e.r, e.c, e.t, e.kind)
	return _max_t

func _goal_hit(k: String, colour: int, r: float, c: float, at: float) -> void:
	for i in goals.size():
		var g: Dictionary = goals[i]
		if g.k == k and (k != "c" or g.t == colour) and g.left > 0:
			g.left -= 1
			_fx(at, "goal", {gi = i, k = k, color = colour, r = r, c = c})
			return

func hit(r: int, c: int, t: float, kind: String) -> void:
	if not playable(r, c): return
	_max_t = maxf(_max_t, t)
	var k := r * C + c
	if TIDE[r][c]: return   # under water: out of reach
	if SEA[r][c]:    # the maelstrom's water takes nothing; his eye, open, takes a hit hard and shuts
		if SEA[r][c] == 2 and not eye.is_empty() and not _rock_hit.has(-2):
			_rock_hit[-2] = true
			if int(eye.shut) <= 0 and boss_on():
				var A: Dictionary = boss.B.act.get("eye", {})
				eye.shut = int(A.get("shut", 2)) + 1
				_fx(t, "eye_hit", {r = int(eye.r) + 1, c = int(eye.c) + 1})
				_boss_damage(int(A.get("dmg", 60)), int(eye.r) + 1, int(eye.c) + 1, t)
		return
	if ROCK[r][c]:   # rocks soak a hit
		if kind == "adj" and _rock_hit.has(k): return
		_rock_hit[k] = true
		ROCK[r][c] -= 1
		_goal_hit("rock", -1, r, c, t)
		_fx(t, "rock", {r = r, c = c, left = ROCK[r][c], granite = ROCK_MAX[r][c] >= 2})
		return
	if GAS[r][c]:    # gas pops with one hit
		if kind == "adj" and _rock_hit.has(k): return
		_rock_hit[k] = true
		GAS[r][c] = 0
		gas_hit = true
		_goal_hit("gas", -1, r, c, t)
		_fx(t, "gas", {r = r, c = c})
		return
	if FLW[r][c]:    # the stone flower loses its outer ring, once a blast, and never below its buds
		if _rock_hit.has(-1): return
		_rock_hit[-1] = true
		if int(flower.st) > 1:
			flower.st = int(flower.st) - 1
			_fx(t, "flower_tear", {r = flower.r, c = flower.c, st = flower.st})
		return
	if NOD[r][c]:    # a nodule is cut off whole by any hit or a match beside it: its layers are ore
		if _rock_hit.has(k): return
		_rock_hit[k] = true
		var layers: int = NOD[r][c]
		NOD[r][c] = 0
		_fx(t, "nodule", {r = r, c = c, stage = layers})
		if boss.is_empty():
			mined.ore += layers
			for i in layers: _fx(t + i * 90.0, "ore", {kind = "ore", r = r, c = c})
		return
	if GEOC[r][c] >= 0:   # a geode block takes one hit per blast; once open its empty shell stays, taking no more
		var gi: int = GEOC[r][c]
		var geo: Dictionary = geos[gi]
		if _geo_hit.has(gi) or geo.done: return
		_geo_hit[gi] = true
		geo.hp -= 1
		_fx(t, "geo_hit", {gi = gi, hp = geo.hp})
		if geo.hp <= 0:
			geo.done = true
			_goal_hit("geo", -1, geo.r + 0.5, geo.c + 0.5, t)
			bonus.append(Stones.roll(Save.next_uid(), Save.area(), 0.5 + depth * 0.35, depth))
			_fx(t, "geo_open", {gi = gi, r = geo.r, c = geo.c})
		return
	if FIND[r][c]:   # careful work peels the rock, blasts chip the stone itself
		if find.is_empty() or find.done or _find_hit: return
		_find_hit = true
		find.hp -= 1
		var rough := kind != "adj" and kind != "pick"
		var chip := 0
		if rough:
			chip = roundi(12.0 * (1.0 - lift * 0.25))
			find.integ = maxi(10, find.integ - chip)
		_fx(t, "find_hit", {rough = rough, chip = chip, hp = find.hp, integ = find.integ})
		if find.hp <= 0:
			find.done = true
			# the stone comes out and the block with it, whether it was dug out with care or blasted apart
			for p in cells_of(find): FIND[p.x][p.y] = false
			_goal_hit("find", -1, find.r + (find.h - 1) * 0.5, find.c + (find.w - 1) * 0.5, t)
			_fx(t, "find_done", {r = find.r + (find.h - 2) * 0.5, c = find.c + (find.w - 2) * 0.5})
		return
	if LOCK[r][c] == 3:   # a tentacle is cut where it is hit; from beside, only at its tip
		if _rock_hit.has(k) or not _cut_tentacle(r, c, t, kind == "adj"): return
		_rock_hit[k] = true
		_cleared[k] = true
		return
	if LOCK[r][c]:   # the timber breaks, the stone under it stays; a crust also cracks off from a match beside it
		var crust: bool = LOCK[r][c] == 2
		if kind == "adj" and (not crust or _rock_hit.has(k)): return
		_rock_hit[k] = true
		LOCK[r][c] = 0
		_goal_hit("crust" if crust else "lock", -1, r, c, t)
		_fx(t, "crust" if crust else "lock", {r = r, c = c})
		_cleared[k] = true
		return
	var g: Gem = G[r][c]
	if g == null or g.item != "" or _cleared.has(k): return
	_cleared[k] = true
	g.die_t = t
	_fx(t, "clear", {id = g.id, r = r, c = c, sp = g.sp, color = g.t})
	if g.ore != "" and g.sp == "":
		mined[g.ore] += 1
		if boss.is_empty(): _fx(t, "ore", {kind = g.ore, r = r, c = c})
	if not boss.is_empty():
		var D: Dictionary = boss.B.dmg
		var dmg := int(D.special) if g.sp != "" else (int(D.ore) if g.ore == "ore" else int(D.weak)) if g.t == int(boss.B.weak) else 0
		if dmg: _boss_damage(dmg, r, c, t)
	if INK[r][c]:
		INK[r][c] = 0
		_fx(t, "ink", {r = r, c = c})
	if MUD[r][c]:
		MUD[r][c] = 0
		_goal_hit("mud", -1, r, c, t)
		_fx(t, "mud", {r = r, c = c})
	if g.t >= 0 and g.sp == "":
		_goal_hit("c", g.t, r, c, t)
	if g.sp != "":
		activate(g.sp, r, c, t + 70.0, g)
	if kind == "match":
		for d in DIRS4:
			var rr: int = r + d.x
			var cc: int = c + d.y
			if playable(rr, cc) and (ROCK[rr][cc] or GAS[rr][cc] or GEOC[rr][cc] >= 0 or FIND[rr][cc] or NOD[rr][cc] or LOCK[rr][cc] >= 2 or FLW[rr][cc] or SEA[rr][cc] == 2):
				hit(rr, cc, t, "adj")

func activate(sp: String, r: int, c: int, t: float, g: Gem = null) -> void:
	match sp:
		"rh", "rv":
			_fx(t, "rocket", {sp = sp, r = r, c = c})
			if sp == "rh":
				for d in range(1, C):
					_push(r, c - d, t + d * 32)
					_push(r, c + d, t + d * 32)
			else:
				for d in range(1, R):
					_push(r - d, c, t + d * 32)
					_push(r + d, c, t + d * 32)
		"bomb":
			blast_area(r, c, 2, t)
		"drill":
			for d in DIRS4: _push(r + d.x, c + d.y, t + 20)
			var tgt := drill_target(r, c)
			if tgt.x >= 0:
				_fx(t, "drill", {r = r, c = c, tr = tgt.x, tc = tgt.y})
				_push(tgt.x, tgt.y, t + 420)
				if g and g.carry != "":
					_push_fn(t + 430, _drill_carry.bind(g.carry, tgt.x, tgt.y))
		"orb":
			orb_color(r, c, most_color(), t)

func blast_area(r: int, c: int, rad: int, t: float) -> void:
	_fx(t, "boom", {r = r, c = c, rad = rad})
	for dr in range(-rad, rad + 1):
		for dc in range(-rad, rad + 1):
			_push(r + dr, c + dc, t + maxi(absi(dr), absi(dc)) * 40)

## the resonator hits every stone of one colour, or turns them into specials first
func orb_color(r: int, c: int, colour: int, t: float, make_sp := "") -> void:
	var i := 0
	_fx(t, "orb", {r = r, c = c})
	for rr in R:
		for cc in C:
			if col(rr, cc) != colour: continue
			var tt := t + i * 28.0
			i += 1
			_fx(tt, "zap", {r = r, c = c, tr = rr, tc = cc})
			if make_sp != "":
				var g: Gem = G[rr][cc]
				g.convert_sp = (("rh" if rng.randf() < 0.5 else "rv") if make_sp == "rocket" else make_sp)
				g.convert_t = tt
				_fx(tt, "convert", {id = g.id, sp = g.convert_sp})
				_push_fn(tt + 260 + i * 20, _fire_converted.bind(g, rr, cc))
			else:
				_push(rr, cc, tt + 150)

func _fire_converted(t: float, g: Gem, r: int, c: int) -> void:
	g.sp = g.convert_sp
	g.t = -1
	hit(r, c, t, "fx")

func _start_combo(t: float, a: Gem, b: Gem, r1: int, c1: int, r2: int, c2: int) -> void:
	_cleared[r1 * C + c1] = true
	_cleared[r2 * C + c2] = true
	a.die_t = t
	b.die_t = t
	_fx(t, "clear", {id = a.id, r = r2, c = c2, sp = a.sp, color = -1})
	_fx(t, "clear", {id = b.id, r = r1, c = c1, sp = b.sp, color = -1})
	_fx(t, "combo", {r = r2, c = c2, a = a.sp, b = b.sp})
	combo(a, b, r2, c2, t + 60)

func _start_orb(t: float, orb: Gem, r: int, c: int, colour: int) -> void:
	_cleared[r * C + c] = true
	orb.die_t = t
	_fx(t, "clear", {id = orb.id, r = r, c = c, sp = "orb", color = -1})
	orb_color(r, c, colour, t + 40)

func _drill_carry(t: float, sp: String, r: int, c: int) -> void:
	activate(sp, r, c, t)

func most_color() -> int:
	var cnt := [0, 0, 0, 0, 0, 0]
	for r in R:
		for c in C:
			var t := col(r, c)
			if t >= 0: cnt[t] += 1
	var best := 0
	for i in cnt.size():
		if cnt[i] > cnt[best]: best = i
	return best

## the drill flies to whatever the level still needs most
func drill_target(r: int, c: int) -> Vector2i:
	var need := {}
	for g in goals:
		if g.left > 0: need[("c%d" % g.t) if g.k == "c" else g.k] = true
	var cand := []
	var best := 0
	for rr in R:
		for cc in C:
			if not playable(rr, cc) or absi(rr - r) + absi(cc - c) <= 1 or _cleared.has(rr * C + cc): continue
			var w := 0
			if FIND[rr][cc] and need.has("find"): w = 7
			elif GAS[rr][cc] and need.has("gas"): w = 6
			elif GEOC[rr][cc] >= 0 and not geos[GEOC[rr][cc]].done and need.has("geo"): w = 6
			elif LOCK[rr][cc] == 1 and need.has("lock"): w = 5
			elif LOCK[rr][cc] == 2 and need.has("crust"): w = 5
			elif ROCK[rr][cc] and need.has("rock"): w = 6
			elif MUD[rr][cc] and need.has("mud"): w = 5
			elif col(rr, cc) >= 0 and need.has("c%d" % col(rr, cc)): w = 4
			elif SEA[rr][cc] == 2 and int(eye.get("shut", 1)) <= 0: w = 6
			elif LOCK[rr][cc] == 3: w = 4
			elif NOD[rr][cc] >= 3: w = 3
			elif G[rr][cc] != null and G[rr][cc].item == "": w = 1
			if w:
				cand.append([Vector2i(rr, cc), w])
				best = maxi(best, w)
	var top := cand.filter(func(x): return x[1] == best)
	if top.is_empty(): return Vector2i(-1, -1)
	return top[rng.randi_range(0, top.size() - 1)][0]

## two specials swapped together
func combo(a: Gem, b: Gem, r: int, c: int, t: float) -> void:
	var s := {a.sp: true, b.sp: true}
	var rk := func(x: String) -> bool: return x == "rh" or x == "rv"
	if a.sp == "orb" and b.sp == "orb":
		_fx(t, "boom", {r = r, c = c, rad = 6})
		for rr in R:
			for cc in C:
				_push(rr, cc, t + (absi(rr - r) + absi(cc - c)) * 25)
		return
	if s.has("orb"):
		var other := b.sp if a.sp == "orb" else a.sp
		orb_color(r, c, most_color(), t, "rocket" if rk.call(other) else other)
		return
	if rk.call(a.sp) and rk.call(b.sp):
		activate("rh", r, c, t)
		activate("rv", r, c, t)
		return
	if s.has("bomb") and (rk.call(a.sp) or rk.call(b.sp)):
		_fx(t, "boom", {r = r, c = c, rad = 1})
		for d in [-1, 0, 1]:
			activate("rh", r + d, c, t + 40)
			activate("rv", r, c + d, t + 40)
		return
	if a.sp == "bomb" and b.sp == "bomb":
		blast_area(r, c, 4, t)
		return
	if s.has("drill"):
		var other := b.sp if a.sp == "drill" else a.sp
		if other == "drill":
			for k in 3: activate("drill", r, c, t + k * 60)
		else:
			var carrier := Gem.new(0, -1)
			carrier.carry = other
			activate("drill", r, c, t, carrier)

# ------------------------------------------------------------------ turn steps

## turn matched groups into blast events; returns {events, created}. swap_cells decides where a new special appears
func groups_to_blast(groups: Array, swap_cells: Array, events: Array) -> Array:
	var created := []
	for g in groups:
		var pos := Vector2i(-1, -1)
		if g.special != "":
			var key := -1
			for sc in swap_cells:
				var kk: int = sc.x * C + sc.y
				if kk in g.cells:
					key = kk
					break
			if key < 0: key = g.cells[g.cells.size() / 2]
			pos = Vector2i(key / C, key % C)
			created.append({r = pos.x, c = pos.y, sp = g.special})
		for k in g.cells:
			var r: int = k / C
			var c: int = k % C
			events.append({t = 0.0, r = r, c = c, kind = "match"})
			if pos.x >= 0 and G[r][c] and not LOCK[r][c]:
				G[r][c].merge = pos
	return created

## drop destroyed stones from the grid; returns their ids
func remove_dead() -> Array:
	var ids := []
	for r in R:
		for c in C:
			var g: Gem = G[r][c]
			if g and not g.alive():
				ids.append(g.id)
				G[r][c] = null
	return ids

func place_specials(created: Array) -> Array:
	var out := []
	for s in created:
		var g := new_gem(-1)
		g.sp = s.sp
		G[s.r][s.c] = g
		out.append(g)
	return out

## gravity: straight down first, then sideways around rocks; new stones appear where nothing can fall in
## (see _is_spawn). Returns the stones that spawned.
func collapse() -> Array:
	var spawned := []
	var spawn_n := []
	spawn_n.resize(C)
	spawn_n.fill(0)
	var moved := true
	while moved:
		moved = false
		for r in range(R - 1, -1, -1):
			for c in C:
				if not open(r, c) or G[r][c] != null: continue
				if r > 0 and open(r - 1, c) and G[r - 1][c] != null and not LOCK[r - 1][c]:
					G[r][c] = G[r - 1][c]
					G[r - 1][c] = null
					moved = true
					continue
				if _is_spawn(r, c):
					var g := new_gem()
					spawn_n[c] += 1
					g.spawn_y = r - spawn_n[c] - 0.3
					G[r][c] = g
					spawned.append(g)
					moved = true
					continue
				var from_above: bool = r > 0 and open(r - 1, c) and not LOCK[r - 1][c]
				if not from_above:
					var dcs := [-1, 1] if rng.randf() < 0.5 else [1, -1]
					for dc in dcs:
						var sr := r - 1
						var sc: int = c + dc
						if sr >= 0 and open(sr, sc) and G[sr][sc] != null and not LOCK[sr][sc] and not (open(r, sc) and G[r][sc] == null):
							G[r][c] = G[sr][sc]
							G[sr][sc] = null
							moved = true
							break
	return spawned

## a cell gets new stones when nothing can fall into it: the cell above and both upper diagonals are walled off
## (rock, gas, a geode, the find, a timber-locked stone or the edge). A lone rock is flowed around;
## a whole wall of them has stones seeping in underneath, so no part of the board starves.
func _is_spawn(r: int, c: int) -> bool:
	if r == 0: return true
	return _walled(r - 1, c) and _walled(r - 1, c - 1) and _walled(r - 1, c + 1)

func _walled(r: int, c: int) -> bool:
	return c < 0 or c >= C or not open(r, c) or LOCK[r][c]

## nuggets that reached the bottom of their column are collected; returns [{id, r, c}]
func collect_nuggets() -> Array:
	var out := []
	for c in C:
		for r in R:
			var g: Gem = G[r][c]
			if g == null or g.item != "nug": continue
			# it has come as far down as it can: the bottom of the board below it, or an opened geode's shell
			var below := r + 1
			while below < R and not playable(below, c): below += 1
			var shell: bool = below < R and GEOC[below][c] >= 0 and geos[GEOC[below][c]].done
			if below < R and not shell: continue
			G[r][c] = null
			fx = []
			_goal_hit("nug", -1, r, c, 0.0)
			out.append({id = g.id, r = r, c = c, goal_fx = fx.duplicate()})
	fx = []
	return out

## reshuffle loose stones until there is a move and nothing is pre-matched
func shuffle() -> void:
	var cells := []
	var gems := []
	for r in R:
		for c in C:
			var g: Gem = G[r][c]
			if g and g.sp == "" and g.item == "" and not LOCK[r][c] and not TIDE[r][c]:
				cells.append(Vector2i(r, c))
				gems.append(g)
	for tries in 60:
		for i in range(gems.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp = gems[i]; gems[i] = gems[j]; gems[j] = tmp
		for i in cells.size():
			G[cells[i].x][cells[i].y] = gems[i]
		if find_groups().is_empty() and has_moves():
			break

## swap two neighbours; returns null if the swap isn't allowed, otherwise
## {special: bool, events, swap_cells} — for a plain swap with no match, events is empty and the swap is undone
func swap(r1: int, c1: int, r2: int, c2: int) -> Variant:
	if not open(r1, c1) or not open(r2, c2): return null
	var a: Gem = G[r1][c1]
	var b: Gem = G[r2][c2]
	if a == null or b == null or LOCK[r1][c1] or LOCK[r2][c2]: return null
	G[r1][c1] = b
	G[r2][c2] = a
	var cells := [Vector2i(r1, c1), Vector2i(r2, c2)]
	if a.sp != "" or b.sp != "":
		if a.sp != "" and b.sp != "":
			return {special = true, swap_cells = [], events = [{t = 0.0, fn = _start_combo.bind(a, b, r1, c1, r2, c2)}]}
		var spg := a if a.sp != "" else b
		var other := b if a.sp != "" else a
		var sr := r2 if a.sp != "" else r1
		var sc := c2 if a.sp != "" else c1
		if spg.sp == "orb" and other.t >= 0:
			return {special = true, swap_cells = [], events = [{t = 0.0, fn = _start_orb.bind(spg, sr, sc, other.t)}]}
		return {special = true, swap_cells = cells, events = [{t = 0.0, r = sr, c = sc, kind = "fx"}]}
	if find_groups().is_empty():
		G[r1][c1] = a
		G[r2][c2] = b
		return {special = false, swap_cells = cells, events = [], undone = true}
	return {special = false, swap_cells = cells, events = []}

func use_move() -> void:
	moves -= 1
	gas_hit = false

## gas creeps onto a neighbouring stone if nobody touched it this turn; returns the cell or (-1,-1)
func gas_spread() -> Vector2i:
	if gas_hit:
		gas_hit = false
		return Vector2i(-1, -1)
	if vent and rng.randf() < 0.5:
		return Vector2i(-1, -1)
	var cand := []
	for r in R:
		for c in C:
			if not GAS[r][c]: continue
			for d in DIRS4:
				var rr: int = r + d.x
				var cc: int = c + d.y
				if not playable(rr, cc): continue
				var g: Gem = G[rr][cc]
				if g and g.t >= 0 and g.sp == "" and g.item == "" and not LOCK[rr][cc]:
					cand.append(Vector2i(rr, cc))
	if cand.is_empty():
		return Vector2i(-1, -1)
	var p: Vector2i = cand[rng.randi_range(0, cand.size() - 1)]
	G[p.x][p.y] = null
	GAS[p.x][p.y] = 1
	var gi := goal_index("gas")
	if gi >= 0: goals[gi].left += 1
	return p

## the nodules grow a layer every NOD_EVERY moves; a full one overgrows instead: malachite crusts the stones round it
## and it starts again from its core. Returns what changed: [{r, c, from, stage, crust: [cells]}]
func nodule_grow() -> Array:
	var out := []
	for r in R:
		for c in C:
			if not NOD[r][c]: continue
			NOD_T[r][c] -= 1
			if NOD_T[r][c] > 0: continue
			NOD_T[r][c] = NOD_EVERY
			var e := {r = r, c = c, from = NOD[r][c], crust = []}
			if NOD[r][c] < 3:
				NOD[r][c] += 1
			else:
				var cand := []
				for d in DIRS4:
					var rr: int = r + d.x
					var cc: int = c + d.y
					if not playable(rr, cc): continue
					var g: Gem = G[rr][cc]
					if g and g.t >= 0 and g.sp == "" and g.item == "" and not LOCK[rr][cc]:
						cand.append(Vector2i(rr, cc))
				for i in mini(NOD_SPREAD, cand.size()):
					var p: Vector2i = cand.pop_at(rng.randi_range(0, cand.size() - 1))
					LOCK[p.x][p.y] = 2
					e.crust.append(p)
				NOD[r][c] = 1
			e.stage = NOD[r][c]
			out.append(e)
	return out

## leftover moves turn into dynamite across the board: returns the cells that got it
func finale_picks() -> Array:
	var k := mini(moves, 15)
	var cand := []
	for r in R:
		for c in C:
			var g: Gem = G[r][c]
			if g and g.t >= 0 and g.sp == "" and not LOCK[r][c]:
				cand.append(Vector2i(r, c))
	var picks := []
	for i in k:
		if cand.is_empty(): break
		var p: Vector2i = cand.pop_at(rng.randi_range(0, cand.size() - 1))
		var g: Gem = G[p.x][p.y]
		g.sp = "rh" if rng.randf() < 0.5 else "rv"
		g.t = -1
		moves -= 1
		coins_won += 5
		picks.append(p)
	return picks

func booster_events(id: String, r: int, c: int) -> Array:
	if id == "pick":
		return [{t = 0.0, r = r, c = c, kind = "pick"}]
	return [{t = 0.0, fn = _bore_at.bind(id, r, c)}]

## the drill boosters: the drill comes in from the board's edge (left, or the top) and bores through the whole
## row or column, one cell after another as its tip reaches it
func _bore_at(t: float, id: String, r: int, c: int) -> void:
	_fx(t, "bore", {sp = id, r = r, c = c})
	var n := C if id == "bore_h" else R
	for k in n:
		if id == "bore_h": _push(r, k, t + BORE_IN + k * BORE_STEP)
		else: _push(k, c, t + BORE_IN + k * BORE_STEP)

const BORE_IN := 340.0     # ms until the tip reaches the first cell (the drill comes up to the rim and revs first)
const BORE_STEP := 55.0    # ms a cell

## the find as it comes out of the rock: quality drops a step for every 20% chipped off
func extracted_stone(diadem := false) -> Dictionary:
	var s: Dictionary = find.stone.duplicate(true)
	var loss: int = (100 - find.integ) / 20
	var gi := maxi(0, int(s.gi) - loss)
	s.value = roundi(s.value * Data.GR[gi].m / Data.GR[s.gi].m * (1.1 if diadem else 1.0))
	s.gi = gi
	s.integ = find.integ
	s.tier = Stones.tier_of(s.sid, gi, s.legend)
	return s
