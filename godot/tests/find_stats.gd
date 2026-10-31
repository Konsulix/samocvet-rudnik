extends Node
## The finds of each mine as the levels roll them (Stones.roll, the luck BoardModel gives a find, a find in
## LevelGen.FIND_P of the levels, the first level of each depth always): how many levels until every species is in the
## atlas, and the prices - median, the top 1%, the most, legendary share. No board is played.
##   "$G" --headless --path godot res://tests/find_stats.tscn -- [runs=200] [wins=4]
## `wins`: levels won per depth (the economy's ~3-4).

func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	var runs := int(args.get("runs", "200"))
	var per := int(args.get("wins", "4"))
	var uid := 900000
	for area in Data.AREAS.size():
		var depths := Data.depths(area).size()
		var pool: Dictionary = Data.AREAS[area].pool
		var full_at := []
		var never := 0
		var prices := []
		var legends := 0
		var finds := 0
		for run in runs:
			var rng := RandomNumberGenerator.new()
			rng.seed = run * 7 + area * 1000
			var seen := {}
			var lv := 0
			var got_all := -1
			for dl in depths:
				for w in per:
					lv += 1
					if w > 0 and rng.randf() >= LevelGen.FIND_P: continue
					uid += 1
					var st := Stones.roll(uid, area, 0.2 + dl * 0.35, dl)
					finds += 1
					seen[st.sid] = true
					prices.append(int(st.value))
					if st.legend: legends += 1
					if got_all < 0 and seen.size() >= pool.size(): got_all = lv
			if got_all < 0:
				never += 1
				# one short: the rarest - how many had all but one
			else:
				full_at.append(got_all)
		prices.sort()
		var n := prices.size()
		var opens := Stones.opens_at(area)
		var order := []
		for s in opens: order.append("%s@%d" % [s, int(opens[s])])
		full_at.sort()
		print("%s (%d depths × %d levels = %d): opens %s" % [Data.AREAS[area].n, depths, per, depths * per, ", ".join(order)])
		print("  atlas full by level: median %s, never %d%%; finds %.1f a run; price median %d, 90%% %d, 99%% %d, max %d; legendary %.2f%%" % [
			str(full_at[full_at.size() / 2]) if full_at.size() else "-", roundi(100.0 * never / runs), float(finds) / runs,
			prices[n / 2], prices[n * 9 / 10], prices[n * 99 / 100], prices[n - 1], 100.0 * legends / maxi(1, finds)])
	get_tree().quit()
