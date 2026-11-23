extends Node
## a geode's weight by its shape (SpecGenome gshape): godot --headless --path godot res://tests/geo_mass.tscn -- [n=6] [soap] [integ=N] [rock]
func _ready() -> void:
	await get_tree().process_frame
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	var n := int(args.get("n", "6"))
	# soap: SpecimenBuilder.soap_audit — a rock mesh with no scan coordinates prints SOAP; integ=N, rock=all
	SpecimenBuilder.soap_audit = args.has("soap")
	var rts := ["limestone", "ironstone", "basalt", "slate", "quartzite", "gypsum", "lava"]
	for sid in ["amethyst", "chrysocolla", "chalcedony"]:
		for gs in ["half", "window", "cathedral", "slab"]:
			var tot := 0.0
			for i in n:
				var st := {id = 9100 + i * 13, seed = 9100 + i * 13, sid = sid, kind = "geode", gi = 2, traits = [], dl = 0, area = 0, g = 900, value = 300, gshape = gs, integ = int(args.get("integ", "100"))}
				if args.has("rock"): st.rock_t = rts[i % rts.size()]
				var o := Spec.of_stone(st)
				o.gshape = gs
				if st.has("rock_t"): o.rock_t = st.rock_t
				var r := SpecimenBuilder.build(o)
				var m: Dictionary = r.get_meta("mass", {})
				var d := float(Stones.DENSITY.get(sid, 2.7))
				var mass := (float(m.rock) * Stones.ROCK_D + float(m.min) * d) / pow(float(m.span), 3.0)
				tot += Stones.MASS_K * mass
				r.free()
			print("MASS %s %s %.0f g" % [sid, gs, tot / n])
	get_tree().quit()
