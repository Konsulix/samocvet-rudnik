extends Node
## prints the generated levels of a depth whose goals include the dark (map, mask), to look at the ones the bot could
## not light:  godot --headless --path godot res://tests/dark_check.tscn -- dl=2 n=14
func _ready() -> void:
	var dl := 2
	var n := 14
	for a in OS.get_cmdline_user_args():
		if a.begins_with("dl="): dl = int(a.get_slice("=", 1))
		if a.begins_with("n="): n = int(a.get_slice("=", 1))
	for i in n:
		var def := LevelGen.make(0, dl, 5000 + dl * 1000 + i, false, 1 + i % 4 if i else 0)
		if not def.has("dark"): continue
		print("#%d %s %s" % [i, def.scheme, def.count])
		var m: PackedStringArray = String(def.map).split("|")
		var d: PackedStringArray = String(def.dark).split("|")
		for r in m.size(): print("  ", m[r], "   ", d[r])
	get_tree().quit()
