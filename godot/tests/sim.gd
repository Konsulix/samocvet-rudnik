class_name Sim
extends RefCounted
## Plays a level with no drawing and no waiting: the same steps the game runs, back to back.
## Used by the bot test and by the in-game level checker.

## resolve a move completely: blasts, cascades, gravity, nuggets
static func resolve(m: BoardModel, events: Array, swap_cells: Array) -> void:
	var first := events
	var sw := swap_cells
	var guard := 0
	while guard < 60:
		guard += 1
		var groups := m.find_groups()
		var ev := first
		first = []
		if groups.is_empty() and ev.is_empty():
			break
		var created := m.groups_to_blast(groups, sw, ev)
		m.fx = []
		m.run_blast(ev)
		m.remove_dead()
		m.place_specials(created)
		m.collapse()
		while not m.collect_nuggets().is_empty():
			m.collapse()
		sw = []
	if not m.has_moves():
		m.shuffle()

## every move worth making: specials to tap, swaps that match or fire a special
static func moves_list(m: BoardModel) -> Array:
	var out := []
	for r in m.R:
		for c in m.C:
			var g: BoardModel.Gem = m.G[r][c]
			if g and g.sp != "" and not m.LOCK[r][c]:
				out.append([r, c, r, c])
	for r in m.R:
		for c in m.C:
			for d in [Vector2i(0, 1), Vector2i(1, 0)]:
				var r2: int = r + d.x
				var c2: int = c + d.y
				if not m.open(r, c) or not m.open(r2, c2): continue
				var a: BoardModel.Gem = m.G[r][c]
				var b: BoardModel.Gem = m.G[r2][c2]
				if a == null or b == null or m.LOCK[r][c] or m.LOCK[r2][c2]: continue
				if a.sp != "" or b.sp != "" or m._try_swap_matches(r, c, r2, c2):
					out.append([r, c, r2, c2])
	return out

## one turn with the given move; returns false if the move did nothing
static func play(m: BoardModel, mv: Array) -> bool:
	var r1: int = mv[0]; var c1: int = mv[1]; var r2: int = mv[2]; var c2: int = mv[3]
	if r1 == r2 and c1 == c2:
		m.use_move()
		resolve(m, [{t = 0.0, r = r1, c = c1, kind = "fx"}], [])
	else:
		var res = m.swap(r1, c1, r2, c2)
		if res == null or res.get("undone", false):
			return false
		m.use_move()
		resolve(m, res.events, res.swap_cells)
	if not m.goals_done():
		m.gas_spread()
	return true

## plays until the level is won or out of moves; picks moves with `pick(m, moves) -> move`
static func play_level(n: int, dl: int, pick: Callable, seed_value: int) -> Dictionary:
	var m := BoardModel.new()
	m.rng.seed = seed_value
	m.setup(n, [], dl, {}, 0)
	var turns := 0
	while m.moves > 0 and not m.goals_done() and turns < 200:
		var list := moves_list(m)
		if list.is_empty():
			m.shuffle()
			list = moves_list(m)
			if list.is_empty():
				return {won = false, stuck = true, moves_left = m.moves, model = m}
		play(m, pick.call(m, list))
		turns += 1
	return {won = m.goals_done(), stuck = false, moves_left = m.moves, model = m}
