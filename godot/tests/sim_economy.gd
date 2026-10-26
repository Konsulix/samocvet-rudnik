class_name SimEconomy
extends RefCounted
## Plays levels to the end inside the board model, no graphics, and counts what was broken:
## stones of each colour per level, wins, moves used. The numbers behind the ore economy
## (how many red stones a win yields, so how dense ore must be). Run with the main key sim=N.
## The player: fires a special when it has one (70%), otherwise a random legal swap — a weak player, the one the
## ore economy and LevelGen.WORK were tuned on. With `-- smart`: one that looks a move ahead for its goals (_choose_smart).

static func play(n: int, dl: int, seed_v: int, level: Dictionary = {}, area := 0) -> Dictionary:
	var m := BoardModel.new()
	m.rng.seed = seed_v
	m.setup(n, [], dl, Save.d.eq, area, true, level)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v * 7 + 1
	var broken := [0, 0, 0, 0, 0, 0]
	var used := 0
	var won := false
	var guard := 0
	var smart := OS.get_cmdline_user_args().has("smart")
	while not m.over and guard < 400:
		guard += 1
		var first := []
		var sw := []
		var mv := _choose_smart(m, rng) if smart else _choose(m, rng)
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
		if m.boss_stage_clear():
			m.next_stage()
			continue
		m.gas_spread()
		m.nodule_grow()
		if m.boss_on():
			var bt := m.boss_turn()
			if bt.get("act", "") == "lizards":
				# the raid: the marked greens go, the holes fill with anything but green, what that matches goes
				for p: Vector2i in bt.cells: m.G[p.x][p.y] = null
				m.collapse()
				m.skip_colour = -1
				_resolve(m, [], [], broken)
			if not m.has_moves(): m.shuffle()
		if m.moves <= 0:
			break
	return {won = won, used = used, broken = broken, colors = m.colors, mined = m.mined.duplicate(), moves = used + maxi(0, m.moves),
		stage = int(m.boss.get("stage", 0)), hp = m.boss_hp() if m.boss_on() else 0}

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

## the smart player (`-- smart`): tries every move on a copy of the board and keeps the one that does the most for the
## level's goals (_worth), as a player who looks at what the level asks for would. It doesn't see the stones about
## to fall in: each copy throws its own dice
static func _choose_smart(m: BoardModel, rng: RandomNumberGenerator) -> Array:
	var list := Sim.moves_list(m)
	if list.is_empty(): return []
	var best: Array = list[0]
	var best_v := -INF
	for mv in list:
		var t := _clone(m, rng.randi())
		t.fx = []
		if not Sim.play(t, mv): continue
		var v := _worth(t) + rng.randf() * 0.3
		if v > best_v:
			best_v = v
			best = mv
	return best

## how good a board is for the level: what its goals still want (less is better, a hit at a time), specials in hand,
## nuggets on their way down, gas not spreading
static func _worth(m: BoardModel) -> float:
	if m.goals_done(): return 1e6
	var v := 0.0
	for g in m.goals:
		var w := 1.0
		match String(g.k):
			"nug": w = 8.0
			"geo", "find": w = 6.0
			"boss": w = 0.08
			"gas": w = 1.5
		v -= float(g.left) * w
	# the big blocks: every hit counts, not only the last one
	for b in m.geos:
		if not b.done: v -= float(b.hp) * 0.8
	if not m.find.is_empty() and not m.find.done: v -= float(m.find.hp) * 0.8
	for r in m.R:
		for c in m.C:
			var g: BoardModel.Gem = m.G[r][c]
			if g == null: continue
			if g.sp != "": v += 2.5 if g.sp in ["bomb", "orb"] else 1.8
			if g.item == "nug": v += 3.0 * r / float(m.R)
			if m.GAS[r][c]: v -= 0.3
	return v

## the board as it is between moves, to try a move on: every field, the stones copied, its own dice
static func _clone(m: BoardModel, seed_v: int) -> BoardModel:
	var t := BoardModel.new()
	for p in m.get_property_list():
		if not (int(p.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE): continue
		var v = m.get(p.name)
		if v is Array or v is Dictionary: v = v.duplicate(true)
		t.set(p.name, v)
	t.rng = RandomNumberGenerator.new()
	t.rng.seed = seed_v
	for r in t.R:
		var row: Array = t.G[r]
		for c in t.C:
			var g: BoardModel.Gem = m.G[r][c]
			if g == null: continue
			var k := BoardModel.Gem.new(g.id, g.t)
			for p in g.get_property_list():
				if int(p.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE: k.set(p.name, g.get(p.name))
			row[c] = k
	return t

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
	var lines := PackedStringArray(["depth | levels | win% | moves used | stones/level by colour (0..4) | all | per win: colour 0 | per win: iron, own ore"])
	for dl in Data.depths(0).size():
		var wins := 0
		var used := 0
		var tot := [0, 0, 0, 0, 0, 0]
		var c0_win := 0
		var ore_win := [0, 0]
		for i in per_depth:
			var n := 1 + (i % 40)
			var r := play(n, dl, 1000 + dl * 100000 + i)
			used += int(r.used)
			for k in 6: tot[k] += int(r.broken[k])
			if r.won:
				wins += 1
				c0_win += int(r.broken[0])
				ore_win[0] += int(r.mined.iron)
				ore_win[1] += int(r.mined.ore)
		var per := []
		var all := 0
		for k in 5:
			per.append("%.0f" % (tot[k] / float(per_depth)))
			all += tot[k]
		lines.append("%d | %d | %.0f | %.1f | %s | %.0f | %.1f | %.1f, %.1f" % [dl, per_depth, 100.0 * wins / per_depth, used / float(per_depth),
			" ".join(per), all / float(per_depth), c0_win / maxf(1.0, wins), ore_win[0] / maxf(1.0, wins), ore_win[1] / maxf(1.0, wins)])
	return "\n".join(lines)

## the boss fight of mine `area` played N times by the autoplayer, at full health and at each 5% step lower
## (one more lost fight each): wins, the board it got to, the health left
static func boss_report(area: int, n: int) -> String:
	var B: Dictionary = Data.AREAS[area].boss
	var lines := PackedStringArray(["%s: hp %d, moves %d (+%d a board) | lost before | win%% | board reached 1/2/3 | hp left when lost | moves used when won" % [B.n, int(B.hp), int(B.moves), int(B.stage_moves)]])
	for tries in [0, 2, 4, 6]:
		var hp := roundi(int(B.hp) * maxf(0.7, 1.0 - 0.05 * tries) / 3.0) * 3
		var wins := 0
		var reach := [0, 0, 0]
		var hp_left := 0
		var used := 0
		for i in n:
			var r := play(1, Data.depths(area).size(), 900 + i * 13 + tries, BoardModel.boss_level(B, 0, hp), area)
			reach[int(r.stage)] += 1
			if r.won:
				wins += 1
				used += int(r.used)
			else:
				hp_left += int(r.hp)
		lines.append("hp %d | %d | %.0f | %d/%d/%d | %.0f | %.1f" % [hp, tries, 100.0 * wins / n, reach[0], reach[1], reach[2],
			hp_left / maxf(1.0, n - wins), used / maxf(1.0, wins)])
	return "\n".join(lines)

## generated levels (LevelGen) at every depth of the first mine: how often the autoplayer wins, the moves given and
## used, ore per win. The moves formula in LevelGen is tuned on this.
static func gen_report(per_depth: int, area := 0) -> String:
	var lines := PackedStringArray(["depth | levels | win% | moves given | moves used | per win: iron, own ore | intro win%"])
	for dl in Data.depths(area).size():
		var wins := 0
		var given := 0
		var used := 0
		var ore := [0, 0]
		var iw := 0
		var ii := 0
		for i in per_depth:
			var def := LevelGen.make(area, dl, 5000 + dl * 1000 + i, false, 1 + i % 4 if i else 0)
			# sim_free: moves without end, so `used` is what the level really needs (for fitting LevelGen.WORK)
			if OS.get_cmdline_user_args().has("sim_free"): def.moves = 120
			var r := play(1 + i % 20, dl, 77 + dl * 1000 + i, def, area)
			given += int(def.moves)
			if OS.get_cmdline_user_args().has("sim_rows"):
				print("ROW ", JSON.stringify({dl = dl, moves = def.moves, count = def.count, won = r.won, used = r.used, scheme = def.get("scheme", ""), cells = String(def.map).replace("|", "").length() - String(def.map).count("#")}))
			used += int(r.used)
			if def.intro:
				ii += 1
				if r.won: iw += 1
			if r.won:
				wins += 1
				ore[0] += int(r.mined.iron)
				ore[1] += int(r.mined.ore)
		lines.append("%d | %d | %.0f | %.1f | %.1f | %.1f, %.1f | %s" % [dl, per_depth, 100.0 * wins / per_depth, given / float(per_depth),
			used / float(per_depth), ore[0] / maxf(1.0, wins), ore[1] / maxf(1.0, wins), ("%d/%d" % [iw, ii]) if ii else "-"])
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
