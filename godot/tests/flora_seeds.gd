extends Node
## Seeds whose find grows flowers, one of every kind (SpecFlora) — for a look at them on a real find card:
##   "$G" --headless --path godot res://tests/flora_seeds.tscn -- [sid=garnet] [kind=crystal] [upto=4000]
## then `-- reveal=<seed> sid=<sid> kind=<kind>` (the stone as `reveal` rolls it)

func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var sid := String(args.get("sid", "garnet"))
	var kind := String(args.get("kind", "crystal"))
	var found := {}
	for sd in range(1, int(args.get("upto", "4000")) + 1):
		var st := Stones.roll(sd, 0, 0.8, 1)
		st.sid = sid
		st.kind = kind
		var g := SpecGenome.of(Spec.of_stone(st))
		if not (g.accents as Array).has("flowers") or not String(g.form) in ["single", "pile", "cluster"]: continue
		var fk := int(g.flora)
		if found.has(fk): continue
		found[fk] = sd
		print("flora ", fk, " ", SpecFlora.NAMES[fk], ": reveal=", sd, " form ", g.form)
		if found.size() == SpecFlora.KINDS.size(): break
	get_tree().quit()
