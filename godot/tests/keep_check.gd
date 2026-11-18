extends Node
## Does a kept find keep what it is? A find (integrity 86 — Fine) is shown on its card (Reveal.show_stone), Keep is
## pressed, and the stone that went into the inventory is printed against the one that was found:
##   "$G" --headless --path godot res://tests/keep_check.tscn -- save=keepchk [seed=301] [sid=sulphur] [area=3]
## (16.11 a kept Fine sulphur came back from the inventory Pristine: Keep built a new entry from a list of fields that
## left integ out)

func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	Coach.off = true
	var st := Stones.roll(int(args.get("seed", "301")), int(args.get("area", "3")), 0.8, 1)
	if args.has("beast"):
		# (a beast's skull as a mine rolls it: the first seed of Old Adit's deepest depth that gives one)
		for sd in range(1000, 60000):
			st = Stones.roll(sd, 0, 0.8, 5)
			if st.has("beast"): break
		print("KEEPCHK rolled ", Stones.name_of(st), " (", st.sid, ", beast ", st.get("beast", "-"), ")")
	else:
		st.sid = args.get("sid", "sulphur")
	st.integ = 86
	var n0: int = Save.d.coll.size()
	var r := Reveal.new()
	r.show_stone(st)
	await get_tree().create_timer(3.0).timeout
	var keep := _button(get_tree().root, "Keep")
	if keep == null:
		print("KEEPCHK no Keep button")
		get_tree().quit()
		return
	keep.pressed.emit()
	await get_tree().create_timer(1.0).timeout
	if Save.d.coll.size() <= n0:
		print("KEEPCHK nothing kept")
		get_tree().quit()
		return
	var kept: Dictionary = Save.d.coll[Save.d.coll.size() - 1]
	var lost := []
	for k in st:
		if not kept.has(k): lost.append(k)
	var aid := Stones.atlas_id(st)
	var best: Dictionary = (Save.d.atlas.get(aid, {}) as Dictionary).get("best", {})
	print("KEEPCHK atlas page ", aid, ": its best is ", Stones.name_of(best) if best.has("sid") else "-", " (beast ", best.get("beast", "-"), "), kept: ", Atlas.best_kept(aid),
		"; inventory: ", Stones.name_of(kept), " (beast ", kept.get("beast", "-"), ")")
	print("KEEPCHK found integ ", st.get("integ"), " (", Stones.condition(int(st.integ))[1], ") -> kept integ ", kept.get("integ"),
		" (", Stones.condition(int(kept.get("integ", 100)))[1], "); fields of the find not kept: ", lost)
	get_tree().quit()

func _button(n: Node, text: String) -> BaseButton:
	if n is BaseButton and _has_text(n, text): return n
	for c in n.get_children():
		var b := _button(c, text)
		if b: return b
	return null

func _has_text(n: Node, text: String) -> bool:
	if (n is Label and (n as Label).text == text) or (n is Button and (n as Button).text == text): return true
	for c in n.get_children():
		if _has_text(c, text): return true
	return false
