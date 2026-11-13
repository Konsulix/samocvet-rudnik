extends Node
## Does the level window promise what the board has? For many generated levels (mines, depths, seeds): the window's
## preview (BoardModel.setup with roll_find false — Home._level_panel) against the board as the level sets it up
## (roll_find true): a find promised and none on the board, or the other way, or another shape.
##   "$G" --headless --path godot res://tests/find_promise.tscn -- save=findtest [n=40] [areas=0,1,2,3,4]
## (old: the window promised a find from the map alone, `find` — the board had none where no spot fit it)

func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var n := int(args.get("n", "40"))
	var areas: Array = Array(String(args.get("areas", "0,1,2,3,4")).split(",")).map(func(x: String) -> int: return int(x))
	var total := 0
	var bad := {missing = 0, extra = 0, shape = 0, old_missing = 0}
	for a: int in areas:
		Save.d.area = a
		var depths := (Data.AREAS[a].depths as Array).size()
		for dl in depths:
			for i in n:
				Save.d.lseed = 1000 + i * 37 + dl * 7
				var lv := 1 + i
				var def: Dictionary = LevelGen.make(a, dl, 1000 + i * 37 + dl * 7, i % 9 == 4, i % 6, ["normal", "easy", "hard", "super"][i % 4])
				var pv := BoardModel.new()
				pv.setup(lv, [], dl, {}, a, false, def)
				var real := BoardModel.new()
				real.setup(lv, [], dl, {}, a, true, def)
				total += 1
				var said := not pv.find_plan.is_empty()
				var has := not real.find.is_empty()
				if bool(def.get("find", true)) and not has: bad.old_missing += 1
				if said and not has: bad.missing += 1
				elif has and not said: bad.extra += 1
				elif said and has and (int(pv.find_plan.w) != int(real.find.w) or int(pv.find_plan.h) != int(real.find.h)): bad.shape += 1
	print("FIND %d levels: promised and missing %d, there and not promised %d, other shape %d; by the old rule promised and missing %d" % [total, bad.missing, bad.extra, bad.shape, bad.old_missing])
	get_tree().quit()
