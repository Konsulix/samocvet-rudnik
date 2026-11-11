extends Node
## how often a find brings the find achievements: -- n=300 (rolls finds in mines 1–5 at all depths, counts genes_of
## and find_marks, prints the gene-count spread and each mark's share)
func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var n := int(args.get("n", "300"))
	for area in 5:
		var hist := {}
		var marks := {}
		var tags := {}
		for i in n:
			var dl := i % 9
			var s := Stones.roll(100000 + area * 7777 + i, area, 0.8, dl)
			var gs: Array = Awards.genes_of(s)
			var real: Array = Awards.odd_genes(gs)
			hist[real.size()] = int(hist.get(real.size(), 0)) + 1
			for t: String in real: tags[t] = int(tags.get(t, 0)) + 1
			for m: String in Awards.find_marks(s, gs): marks[m] = int(marks.get(m, 0)) + 1
			# the beasts' skulls: how many, and their feathers and legends
			if String(s.get("beast", "")) != "":
				marks["beast"] = int(marks.get("beast", 0)) + 1
				for t: String in gs:
					if t.begins_with("feather:") or (t.begins_with("fx:") and bool(s.get("legend", false))): marks[t] = int(marks.get(t, 0)) + 1
		var ks := hist.keys(); ks.sort()
		print("area %d genes: %s" % [area, ", ".join(ks.map(func(k: int) -> String: return "%d:%d" % [k, hist[k]]))])
		print("   marks: %s" % str(marks))
		var top := tags.keys(); top.sort_custom(func(a: String, b: String) -> bool: return tags[a] > tags[b])
		print("   top: %s" % ", ".join(top.slice(0, 14).map(func(t: String) -> String: return "%s %d" % [t, tags[t]])))
	get_tree().quit()
