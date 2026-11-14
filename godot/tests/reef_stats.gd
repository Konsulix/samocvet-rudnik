extends SceneTree
## how often each part of the living sea floor comes (SpecReef.genes over many seeds), and what it adds to the price
## points:  godot --headless --path godot -s res://tests/reef_stats.gd
func _init() -> void:
	var n := 5000
	var cnt := {}
	var items := 0
	var pts := 0.0
	for i in n:
		var g := SpecReef.genes(i * 7 + 1, 29)
		var all: Array = (g.tall as Array) + (g.near as Array)
		if String(g.swim) != "": all.append(g.swim)
		items += all.size()
		for k: String in all:
			var gp := String((SpecReef.MODELS[k] as Dictionary).g)
			cnt[gp] = int(cnt.get(gp, 0)) + 1
			cnt[k] = int(cnt.get(k, 0)) + 1
			pts += SpecReef.points("sea:" + k)
	print("REEF finds %d, things per find %.2f, points per find %.2f" % [n, float(items) / n, pts / n])
	for gp in ["weed", "coral", "star", "shell", "crab", "swim"]:
		print("REEF %-6s %5.1f%% of finds" % [gp, 100.0 * int(cnt.get(gp, 0)) / n])
	var rare := []
	for k: String in SpecReef.MODELS:
		rare.append([int(cnt.get(k, 0)), k])
	rare.sort()
	print("REEF rarest: ", rare.slice(0, 5))
	quit()
