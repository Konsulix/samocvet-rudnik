class_name SimEconomy
extends RefCounted
## Plays levels to the end inside the board model, no graphics, and counts what was broken:
## stones of each colour per level, wins, moves used. The numbers behind the ore economy
## (how many red stones a win yields, so how dense ore must be). Run with the main key sim=N.
## The player: fires a special when it has one (70%), otherwise a random legal swap — an average player,
## not a perfect one.

static func play(n: int, dl: int, seed_v: int) -> Dictionary:
	var m := BoardModel.new()
	m.rng.seed = seed_v
	m.setup(n, [], dl, Save.d.eq, 0)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v * 7 + 1
	var broken := [0, 0, 0, 0, 0, 0]
	var used := 0
	var won := false
	var guard := 0
	while not m.over and guard < 400:
		guard += 1
		var first := []
		var sw := []
		var mv := _choose(m, rng)
		if mv.is_empty():
			m.shuffle()
			continue
		if mv[0] == mv[2] and mv[1] == mv[3]:
			first = [{t = 0.0, r = mv[0], c = mv[1], kind = "fx"}]
		else:
			var res = m.swap(mv[0], mv[1], mv[2], mv[3])
			if res == null or res.get("undone", false):
				continue
			first = res.events
			sw = res.swap_cells
		m.use_move()
		used += 1
		_resolve(m, first, sw, broken)
		if m.goals_done():
			won = true
			break
		m.gas_spread()
		if m.moves <= 0:
			break
	return {won = won, used = used, broken = broken, colors = m.colors}

static func _choose(m: BoardModel, rng: RandomNumberGenerator) -> Array:
	var specials := []
	var swaps := []
	for r in m.R:
		for c in m.C:
			var g: BoardModel.Gem = m.G[r][c]
			if g == null or not m.open(r, c) or m.LOCK[r][c]: continue
			if g.sp != "": specials.append([r, c, r, c])
			for d in [Vector2i(0, 1), Vector2i(1, 0)]:
				if m._try_swap_matches(r, c, r + d.x, c + d.y):
					swaps.append([r, c, r + d.x, c + d.y])
	if specials.size() and (swaps.is_empty() or rng.randf() < 0.7):
		return specials[rng.randi_range(0, specials.size() - 1)]
	if swaps.is_empty():
		return []
	return swaps[rng.randi_range(0, swaps.size() - 1)]

## the level's turn, without the show: blasts, removals, specials, falls, nuggets, until the board is still
static func _resolve(m: BoardModel, first: Array, sw: Array, broken: Array) -> void:
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
		for r in m.R:
			for c in m.C:
				var g: BoardModel.Gem = m.G[r][c]
				if g and not g.alive() and g.t >= 0 and g.t < broken.size():
					broken[g.t] += 1
		m.remove_dead()
		m.place_specials(created)
		m.collapse()
		while not m.collect_nuggets().is_empty():
			m.collapse()
		sw = []
	if not m.over and not m.has_moves():
		m.shuffle()

## many levels at every depth: averages per level and per win
static func report(per_depth: int) -> String:
	var lines := PackedStringArray(["depth | levels | win% | moves used | stones/level by colour (0..4) | all | per win: colour 0"])
	for dl in 4:
		var wins := 0
		var used := 0
		var tot := [0, 0, 0, 0, 0, 0]
		var c0_win := 0
		for i in per_depth:
			var n := 1 + (i % 40)
			var r := play(n, dl, 1000 + dl * 100000 + i)
			used += int(r.used)
			for k in 6: tot[k] += int(r.broken[k])
			if r.won:
				wins += 1
				c0_win += int(r.broken[0])
		var per := []
		var all := 0
		for k in 5:
			per.append("%.0f" % (tot[k] / float(per_depth)))
			all += tot[k]
		lines.append("%d | %d | %.0f | %.1f | %s | %.0f | %.1f" % [dl, per_depth, 100.0 * wins / per_depth, used / float(per_depth),
			" ".join(per), all / float(per_depth), c0_win / maxf(1.0, wins)])
	return "\n".join(lines)

## what minerals bring in: how often a level has a sealed find and geodes, and what those stones sell for.
## Only builds levels (no play), so it is quick.
static func minerals(per_depth: int) -> String:
	var lines := PackedStringArray(["depth | find in level % | find value avg / median / max | geodes per level | geode stone avg"])
	for dl in 4:
		var finds := []
		var geodes := 0
		var gvals := []
		for i in per_depth:
			var m := BoardModel.new()
			m.rng.seed = 5000 + dl * 100000 + i
			m.setup(1 + (i % 40), [], dl, Save.d.eq, 0)
			if not m.find.is_empty(): finds.append(int(m.find.stone.value))
			geodes += m.geos.size()
			for k in m.geos.size():
				gvals.append(int(Stones.roll(Save.next_uid(), 0, 0.5 + dl * 0.35, dl).value))
		finds.sort()
		var avg := 0.0
		for v in finds: avg += v
		avg /= maxf(1.0, finds.size())
		var gavg := 0.0
		for v in gvals: gavg += v
		gavg /= maxf(1.0, gvals.size())
		lines.append("%d | %.0f | %.0f / %d / %d | %.2f | %.0f" % [dl, 100.0 * finds.size() / per_depth, avg,
			finds[finds.size() / 2] if finds.size() else 0, finds[-1] if finds.size() else 0, geodes / float(per_depth), gavg])
	return "\n".join(lines)
