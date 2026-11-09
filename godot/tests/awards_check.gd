extends Node
## after selling in the game (on a save copy): every gene no kept stone shows must remember a stone that was sold
## in that run — the last one with it — and the awards must show it grey. `-- save=awtest` (awbefore.json: before)

func _ready() -> void:
	await get_tree().process_frame
	var before: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://awbefore.json"))
	var now_ids := {}
	for s in Save.d.coll: now_ids[int(s.id)] = true
	var sold := {}
	for s in before.coll: if not now_ids.has(int(s.id)): sold[int(s.id)] = s
	print("sold in the game: ", sold.size(), " stones, coins ", int(before.coins), " -> ", int(Save.d.coins))
	var had := {}       # tag -> kept before
	for s in before.coll:
		for t in Awards.genes_of(s): had[t] = true
	var aw := Awards.new()
	Awards._kept = {}
	var kept: Dictionary = Awards.kept_best()
	var ok := true
	var gone := 0
	for t in had:
		var sh: Array = aw._shown("g:" + t)
		if kept.has(t):
			if not bool(sh[1]) or not now_ids.has(int(sh[0].id)): ok = false; print("WRONG kept ", t)
			continue
		gone += 1
		var id := int(sh[0].id)
		var good: bool = sold.has(id) and not bool(sh[1]) and Awards.genes_of(sold[id]).has(t)
		print("%-22s grey: %d %s %s" % [t, id, Stones.name_of(sold[id]) if sold.has(id) else "?", "ok" if good else "WRONG"])
		ok = ok and good
	print("genes with no stone left: ", gone)
	print("RESULT ", "PASS" if ok else "FAIL")
	aw.free()
	get_tree().quit()
