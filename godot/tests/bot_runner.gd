extends Node
## Headless check of every level: a simple goal-minded bot plays each level a few times at several depths
## and prints how often it wins. Also catches script errors anywhere in the rules.
## Run: godot --headless --path godot res://tests/bot_runner.tscn

const LEVELS := 30
const RUNS := 6
const DEPTHS := [0, 2, 4]

## prefers specials and moves next to whatever the level still needs
func pick(m: BoardModel, list: Array) -> Array:
	var need := {}
	for g in m.goals:
		if g.left > 0: need[("c%d" % g.t) if g.k == "c" else g.k] = true
	var best: Array = list[0]
	var best_score := -1.0
	for mv in list:
		var score := randf() * 0.5
		for p in [Vector2i(mv[0], mv[1]), Vector2i(mv[2], mv[3])]:
			var g: BoardModel.Gem = m.G[p.x][p.y]
			if g and g.sp != "": score += 4.0
			if g and g.t >= 0 and need.has("c%d" % g.t): score += 1.0
			for d in BoardModel.DIRS4:
				var r: int = p.x + d.x
				var c: int = p.y + d.y
				if not m.playable(r, c): continue
				if m.FIND[r][c] and need.has("find"): score += 2.0
				if m.ROCK[r][c] and need.has("rock"): score += 1.5
				if m.GAS[r][c] and need.has("gas"): score += 1.5
				if m.GEOC[r][c] >= 0 and need.has("geo"): score += 1.5
				if m.MUD[r][c] and need.has("mud"): score += 1.0
		score += (mv[0] + mv[2]) * 0.05   # lower moves shake up more of the board
		if score > best_score:
			best_score = score
			best = mv
	return best

func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	var rows := []
	var weak := []
	for dl in DEPTHS:
		var line := "depth %d:" % dl
		for n in range(1, LEVELS + 1):
			var wins := 0
			var stuck := 0
			for k in RUNS:
				var res := Sim.play_level(n, dl, pick, n * 1000 + k * 17 + dl)
				if res.won: wins += 1
				if res.stuck: stuck += 1
			line += " %d:%d%s" % [n, wins, "!" if stuck else ""]
			if wins == 0 and dl == 0: weak.append(n)
		rows.append(line)
	for r in rows: print(r)
	print("never won at 50 m: ", weak)
	print("took %d ms" % (Time.get_ticks_msec() - t0))
	get_tree().quit()
