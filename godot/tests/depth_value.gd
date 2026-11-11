extends Node
## Mean price of a find at each depth of each mine (as the board rolls them), and how many genes it carries:
## the deeper, the finer the stones should be. Out: printed rows "DV area dl mean genes".
##   godot --headless --path godot res://tests/depth_value.tscn -- [n=400]

func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var n := int(args.get("n", "400"))
	for area in Data.AREAS.size():
		var line := PackedStringArray()
		var gl := PackedStringArray()
		for dl in Data.depths(area).size():
			var sum := 0
			var genes := 0
			for i in n:
				var s := Stones.roll(800000 + area * 100003 + dl * 10007 + i * 7919, area, 0.2 + dl * 0.35, dl)
				sum += int(s.value)
				genes += (s.traits as Array).size()
			line.append(str(sum / n))
			gl.append("%.2f" % (float(genes) / n))
		print("DV %d  %s   genes %s" % [area, " ".join(line), " ".join(gl)])
	get_tree().quit()
