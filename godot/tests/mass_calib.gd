extends Node
## the weights and prices of the finds by depth, rolled (old) and from their models (Stones.settle):
## (formonly: no build — the kinds and layouts alone, fast)
## godot --headless --path godot res://tests/mass_calib.tscn -- [n=20] [area=0] [depths=0,2,4,6]
func _ready() -> void:
	await get_tree().process_frame
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	var n := int(args.get("n", "20"))
	var area := int(args.get("area", "0"))
	var depths := String(args.get("depths", "0,2,4,6")).split(",")
	for ds in depths:
		var dl := int(ds)
		for i in n:
			var st := Stones.roll(700000 + dl * 1000 + i, area, 0.2 + dl * 0.35, dl)
			st.area = area
			if args.has("formonly"):
				var gf := SpecGenome.of(Spec.of_stone(st))
				print("ROW %d %s %s %s 0 0 0 0 0 0" % [dl, st.sid, st.kind, String(gf.form)])
				continue
			var g0 := int(st.g)
			var v0 := int(st.value)
			var r := SpecimenBuilder.build(Spec.of_stone(st))
			var m: Dictionary = r.get_meta("mass", {})
			var form := String((r.get_meta("genome", {}) as Dictionary).get("form", ""))
			Stones.settle(st, r)
			print("ROW %d %s %s %s %d %d %.5f %.5f %d %d %.4f" % [dl, st.sid, st.kind, form, g0, v0, float(m.get("rock", 0)), float(m.get("min", 0)), int(st.g), int(st.value), float(m.get("span", 1))])
			r.free()
	get_tree().quit()
