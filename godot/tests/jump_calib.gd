extends Node
## (22.11) what a won level brings, depth by depth, for the admin's "start at mine N" (Jump): the smart autoplayer
## plays `n` generated levels at each depth of a mine, as the chain does (mine_chain), and prints one line a depth —
## the share won, and of a won one: iron, the mine's ore, the board's coins, a find there / dug out, its wholeness,
## geodes there / opened. `-- area=N n=4 [lvl=30]`, a line per depth, then the GDScript table row for Jump.CAL

func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var area := int(args.get("area", "0"))
	var n := int(args.get("n", "4"))
	var lvl := int(args.get("lvl", "30"))
	var rows: Array = []
	var played := 0
	for dl in Data.depths(area).size():
		var won := 0
		var acc := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]   # iron, ore, coins_won, find_on, find_done, integ, geos, geos_open
		for k in n:
			var beat := LevelGen.beat_of(lvl + played)
			var def := LevelGen.make(area, dl, 7919 * (area + 1) + played * 104729, false, 4, beat)
			var r := SimEconomy.play(lvl + played, dl, 31337 + played * 17, def, area)
			played += 1
			if not r.won: continue
			won += 1
			var v := [float(r.mined.iron), float(r.mined.ore), float(r.coins_won), 1.0 if r.find_on else 0.0, 1.0 if r.find_done else 0.0,
				float(r.find_integ) if r.find_done else 0.0, float(r.geos), float(r.geos_open)]
			for i in v.size(): acc[i] += v[i]
		var w := maxi(won, 1)
		var row := [snappedf(float(won) / n, 0.01)]
		for i in acc.size(): row.append(snappedf(acc[i] / w, 0.01))
		# integ: an average over the dug ones only
		row[6] = snappedf(acc[5] / maxf(acc[4], 1.0), 0.1)
		rows.append(row)
		print("CALIB %d %3d m: won %.2f | iron %.1f ore %.1f coins %.0f | find %.2f dug %.2f integ %.0f | geos %.2f open %.2f" % [area, int(Data.depths(area)[dl].m), row[0], row[1], row[2], row[3], row[4], row[5], row[6], row[7], row[8]])
	print("CALROW %d: %s" % [area, str(rows)])
	get_tree().quit()
