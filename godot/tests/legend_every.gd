extends Node
## the sure legendary (Stones.LEGEND_EVERY): levels won with none counted; at the hundredth win the level's find is
## legendary, and once it comes to hand (Save.note_find) the count starts again. Also how far apart legendaries fall
## by the dice alone, levels won (finds in about 60% of levels)
## godot --headless --path godot res://tests/legend_every.tscn -- save=legtest2 [n=40]
func _ready() -> void:
	await get_tree().process_frame
	Coach.off = false
	Save.d.told = Save.d.get("told", [])
	var sure := 0
	var lv := 0
	for a in [0, 2]:
		Save.d.area = a
		for i in 6:
			# (the first legendary: due at the 25th win; after it, at the 150th)
			Save.d.leg_any = a == 2
			Save.d.leg_lv = (149 if a == 2 else 24) if i % 2 == 0 else (100 if a == 2 else 10)
			var def: Dictionary = LevelGen.make(a, 2, 5000 + i * 31, false, i % 6, "normal")
			var m := BoardModel.new()
			m.setup(1 + i, [], 2, {}, a, true, def)
			if m.find.is_empty(): continue
			var st: Dictionary = m.find.stone
			lv += 1
			print("LEVEL mine %d count %d: find %s legend=%s fx=%s" % [a, int(Save.d.leg_lv), st.sid, st.get("legend", false), st.get("fx", SpecGenome.of(Spec.of_stone(st)).fx)])
			if bool(st.get("legend", false)): sure += 1
			Save.note_find(st, a, 2)
			print("   after it came to hand: count %d" % int(Save.d.leg_lv))
	# the dice alone: in how many levels won does a legendary fall (finds in ~60% of levels)
	var n := 20000
	for x: String in OS.get_cmdline_user_args():
		if x.begins_with("n="): n = int(x.substr(2))
	var hits := 0
	for k in n:
		if bool(Stones.roll(800000 + k, k % 5, 0.2 + (k % 6) * 0.35, k % 6).legend): hits += 1
	print("DICE %d finds: %d legendary — one in %d finds, about one in %d levels" % [n, hits, n / maxi(1, hits), int(n / maxi(1, hits) / 0.6)])
	get_tree().quit()
