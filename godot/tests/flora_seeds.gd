extends Node
## Seeds whose find grows flowers, of every kind (SpecFlora) — for a look at them on a real find card:
##   "$G" --headless --path godot res://tests/flora_seeds.tscn -- [sid=garnet] [kind=crystal] [upto=4000]
## then `-- reveal=<seed> sid=<sid> kind=<kind>` (the stone as `reveal` rolls it).
## With `put` (and `save=<name>`, so the player's own save is left alone): two finds of every kind of flower, on
## different minerals, are laid in that save's inventory (marked test; the ones of an earlier run are replaced):
##   "$G" --headless --path godot res://tests/flora_seeds.tscn -- save=flowers put
##   "$G" --path godot --resolution 390x844 -- save=flowers screen=stones

func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var put := args.has("put")
	var hosts := ["garnet", "calcite", "fluorite", "amethyst", "quartz", "pyrite"] if put else [String(args.get("sid", "garnet"))]
	var kind := String(args.get("kind", "crystal"))
	var per := 2 if put else 1
	var found := {}     # kind of flower -> [the hosts it has]
	var done := 0
	if put:
		Save.d.coll = Save.d.coll.filter(func(c: Dictionary) -> bool: return not c.get("flora_test", false))
	for sd in range(1, int(args.get("upto", "6000")) + 1):
		var st := Stones.roll(sd, 0, 0.8, 1)
		st.sid = hosts[sd % hosts.size()]
		st.kind = kind
		var g := SpecGenome.of(Spec.of_stone(st))
		if not (g.accents as Array).has("flowers") or not String(g.form) in ["single", "pile", "cluster"]: continue
		var fk := int(g.flora)
		var have: Array = found.get(fk, [])
		if have.size() >= per or have.has(st.sid): continue
		have.append(st.sid)
		found[fk] = have
		done += 1
		print("flora ", fk, " ", SpecFlora.NAMES[fk], ": reveal=", sd, " sid=", st.sid, " form ", g.form)
		if put:
			st.legend = false
			st.tier = Stones.tier_of(st.sid, int(st.gi), false)
			st.area = 0
			st.dl = done % 6
			st.value = Stones.price(st, 0, int(st.dl))
			st.test = true
			st.flora_test = true
			Save.d.coll.append(st)
			if not st.sid in Save.d.seen: Save.d.seen.append(st.sid)
			Save.note_find(st, 0, int(st.dl))
		if done == SpecFlora.KINDS.size() * per: break
	if put:
		Save.persist()
		print("put ", done, " finds")
	get_tree().quit()
