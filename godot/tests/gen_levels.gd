extends Node
## Generated levels (LevelGen) of every mine and depth: every goal can be met. A goal with nothing on the board to do,
## a nugget that can't reach the bottom, fewer nodules than asked for, a part of the board that never gets stones
## (all blocks cleared, geodes opened, refilled as the game does).  res://tests/gen_levels.tscn [-- n=40]
func _ready() -> void:
	var per := 40
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("n="): per = int(arg.get_slice("=", 1))
	var bad := 0
	var made := 0
	var by_scheme := {}
	for area in Data.AREAS.size():
		for dl in Data.depths(area).size():
			for i in per:
				var def := LevelGen.make(area, dl, 9000 + area * 100000 + dl * 1000 + i, false, i % 5)
				var m := BoardModel.new()
				m.rng.seed = i
				m.setup(1, [], dl, {}, area, false, def)
				made += 1
				var s: String = def.scheme
				var st: Array = by_scheme.get(s, [0, 0, 0])
				st[0] += 1
				st[1] += _blocks(m)
				var why := _check(m, def)
				if why != "":
					bad += 1
					st[2] += 1
					print("BAD area %d depth %d #%d %s: %s\n  %s" % [area, dl, i, s, why, String(def.map).replace("|", "\n  ")])
				by_scheme[s] = st
	for s in by_scheme:
		var st: Array = by_scheme[s]
		print("%-8s levels %3d  block cells avg %4.1f  bad %d" % [s, st[0], float(st[1]) / st[0], st[2]])
	print("GEN_LEVELS ", ("FAIL %d of %d" % [bad, made]) if bad else "PASS %d" % made)
	get_tree().quit()

func _blocks(m: BoardModel) -> int:
	var n := 0
	for r in m.R:
		for c in m.C:
			if m.ROCK[r][c] or m.MUD[r][c] or m.GAS[r][c] or m.LOCK[r][c] or m.NOD[r][c]: n += 1
	return n

func _check(m: BoardModel, def: Dictionary) -> String:
	for g in m.goals:
		if int(g.left) <= 0: return "goal %s with nothing to do" % g.k
	var nod_asked: int = int(def.count.get("nod", -1))
	if def.count.has("nod") and nod_asked < 2: return "%d nodules" % nod_asked
	# nuggets: straight down to the bottom, blocks aside (they get cleared), never over a hole with board below it
	for r in m.R:
		for c in m.C:
			var g: BoardModel.Gem = m.G[r][c]
			if g == null or g.item != "nug": continue
			var gap := false
			for rr in range(r + 1, m.R):
				if not m.playable(rr, c): gap = true
				elif gap: return "nugget at %d,%d stuck over a hole" % [r, c]
	# clear everything, open the geodes, empty the board and refill: no open cell may stay empty
	for g in m.geos: g.done = true
	for r in m.R:
		for c in m.C:
			m.ROCK[r][c] = 0; m.MUD[r][c] = 0; m.GAS[r][c] = 0; m.LOCK[r][c] = 0; m.NOD[r][c] = 0
			m.FIND[r][c] = false
			if m.open(r, c) and m.G[r][c] and m.G[r][c].item == "": m.G[r][c] = null
	for k in 4: m.collapse()
	for r in m.R:
		for c in m.C:
			if m.open(r, c) and m.G[r][c] == null: return "cell %d,%d never fills" % [r, c]
	return ""
