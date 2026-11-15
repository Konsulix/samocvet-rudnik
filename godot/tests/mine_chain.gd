extends Node
## A whole mine played through by the smart autoplayer, as a player who builds and digs as soon as he can: he plays
## the deepest open depth, builds its task when the mine's ore is enough (a task at once, all its steps), sinks the
## shaft when the task is built and iron and coins are enough. Prints a line per build and per dig (the win it came on,
## what was in hand), then wins and levels played to the boss, and the ore, iron and coins of a win by depth.
##   "$G" --headless --path godot res://tests/mine_chain.tscn -- smart area=1 [lvl=30] [seed=1]
## Veins: a depth's stock (Data.depth fe/au) runs down with what is mined; past its floor (BoardModel.vein_floor) a win
## brings a third. Coins: the win's pay as Level._win counts it; `sell` — every find and geode sold too.

func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var area := int(args.get("area", "1"))
	var lvl := int(args.get("lvl", "30"))
	var seed_v := int(args.get("seed", "1"))
	var A: Dictionary = Data.AREAS[area]
	var depths: Array = Data.depths(area)
	var tasks: Array = A.tasks
	var last := depths.size() - 1
	var dl := 0
	var built := 0          # tasks built (task i needs depth i open)
	var ore := 0
	var fe := 0
	var coins := int(args.get("coins", "0"))   # coins brought from the mine before
	var wins := 0
	var played := 0
	var dwins := []
	var vein := []          # [iron used, ore used] per depth
	var per := {}           # dl -> [wins, iron, ore, coins]
	for d in depths.size():
		dwins.append(0)
		vein.append([0, 0])
	print("CHAIN %s: tasks %s | drills %s" % [A.n, str(tasks.map(func(t: Array) -> int: return int(t[2]))), str(depths.map(func(d: Dictionary) -> Array: return d.drill))])
	while played < 400:
		# act while he can: build, then dig
		var acted := true
		while acted:
			acted = false
			if built <= dl and built < tasks.size() and ore >= int(tasks[built][2]):
				ore -= int(tasks[built][2])
				print("CHAIN build %-10s after win %2d (levels %2d) | left: ore %d, iron %d, coins %d" % [String(tasks[built][0]), wins, played, ore, fe, coins])
				var ch: Dictionary = Data.CHEST[built] if built < Data.CHEST.size() else {coins = 100}
				coins += int(ch.get("coins", 0))
				built += 1
				acted = true
			elif built > dl and dl < last:
				var D: Dictionary = depths[dl + 1]
				if fe >= int(D.drill[0]) and coins >= int(D.drill[1]):
					fe -= int(D.drill[0])
					coins -= int(D.drill[1])
					dl += 1
					print("CHAIN dig to %3d m    after win %2d (levels %2d) | left: ore %d, iron %d, coins %d" % [int(D.m), wins, played, ore, fe, coins])
					acted = true
		if built >= tasks.size() and dl >= last: break
		var beat := LevelGen.beat_of(lvl)
		var def := LevelGen.make(area, dl, seed_v * 100003 + played * 7919, false, int(dwins[dl]), beat)
		var r := SimEconomy.play(lvl, dl, seed_v * 7777 + played, def, area)
		played += 1
		if not r.won: continue
		wins += 1
		lvl += 1
		dwins[dl] = int(dwins[dl]) + 1
		var D2: Dictionary = depths[dl]
		var got := [0, 0]
		var stock := [int(D2.fe), int(D2.au)]
		var mined := [int(r.mined.iron), int(r.mined.ore)]
		for k in 2:
			var room := maxi(0, stock[k] - BoardModel.vein_floor(stock[k]) - int(vein[dl][k]))
			var full := mini(mined[k], room)
			vein[dl][k] = int(vein[dl][k]) + full
			got[k] = full + (mined[k] - full) / 3
		var pay := roundi((20 + int(r.coins_won)) * Data.depth_pay(dl) * float(Level.HARD_PAY.get(beat, 1.0)))
		# sell: every find and geode of the level sold too (a player who keeps them gets the level's pay alone)
		if args.has("sell"): pay += int(r.sold)
		fe += got[0]
		ore += got[1]
		coins += pay
		var pd: Array = per.get(dl, [0, 0, 0, 0])
		per[dl] = [int(pd[0]) + 1, int(pd[1]) + got[0], int(pd[2]) + got[1], int(pd[3]) + pay]
	print("CHAIN %s done: %d wins, %d levels played (to the boss) | left: ore %d, iron %d, coins %d" % [A.n, wins, played, ore, fe, coins])
	for d in per:
		var p: Array = per[d]
		print("CHAIN   %3d m: %2d wins | a win: iron %.1f, ore %.1f, coins %.0f" % [int(depths[d].m), int(p[0]), float(p[1]) / p[0], float(p[2]) / p[0], float(p[3]) / p[0]])
	get_tree().quit()
