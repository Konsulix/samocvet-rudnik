extends Node
## How long the cascades run (Avalanche's bar): the smart player plays the generator's levels of Old Adit's first depths,
## and for each level the longest cascade of one move (steps, as Level counts them) is kept.
##   "$G" --headless --path godot res://tests/cascade_odds.tscn -- smart [n=60] [depths=0,1,2]
## Prints the share of levels whose longest cascade reached 8, 10, 12, 14, 16.

func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var n := int(args.get("n", "60"))
	var depths: Array = Array(String(args.get("depths", "0,1,2")).split(",")).map(func(x: String) -> int: return int(x))
	var maxes: Array[int] = []
	for i in n:
		var dl: int = depths[i % depths.size()]
		var lv := LevelGen.make(0, dl, 5000 + i * 31, false, i / depths.size())
		SimEconomy.play(1 + i, dl, 9000 + i, lv)
		maxes.append(SimEconomy.cascade_max)
	var line := "CASCADE %d levels:" % n
	for bar in [6, 8, 10, 12, 14, 16]:
		line += "  ≥%d: %.0f%%" % [bar, 100.0 * maxes.filter(func(x: int) -> bool: return x >= bar).size() / n]
	print(line)
	maxes.sort()
	print("CASCADE max per level: ", maxes)
	get_tree().quit()
