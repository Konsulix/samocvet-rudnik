extends Node
## Every level with geodes: open all of them (their empty shells stay), clear the board below and let it refill.
## Any playable open cell left empty means the shell starves part of the board.  res://tests/zone_levels.tscn
func _ready() -> void:
	var bad := 0
	for n in range(1, Data.LEVELS.size() + 1):
		var m := BoardModel.new()
		m.rng.seed = n
		m.setup(n, [], 0, {}, 0, false)
		if m.geos.is_empty(): continue
		for g in m.geos: g.done = true
		# empty every open cell, then fill as the game does
		for r in BoardModel.R:
			for c in BoardModel.C:
				if m.open(r, c) and m.G[r][c] and m.G[r][c].item == "": m.G[r][c] = null
		for k in 3: m.collapse()
		var empty := []
		for r in BoardModel.R:
			for c in BoardModel.C:
				if m.open(r, c) and not m.LOCK[r][c] and m.G[r][c] == null: empty.append(Vector2i(r, c))
		print("LEVEL ", n, " geodes ", m.geos.size(), " empty ", empty)
		if empty.size(): bad += 1
	print("ZONE_LEVELS ", "FAIL " + str(bad) if bad else "PASS")
	get_tree().quit()
