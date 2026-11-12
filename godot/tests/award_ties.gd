extends Node
## how often a find brings the pieces of the awards about pseudomorphs, pairs and the showy minerals:
## -- n=2000 [sp=wulfenite,tourmaline,...] (rolls finds in every mine at all depths, or of the given species, and counts
## the "pseudo:", "pair:", "perched:" and "acc:tm_" genes and the marks they bring; then says which pieces of each
## collection never turned up)
func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var n := int(args.get("n", "2000"))
	var seen := {}
	var total := 0
	var count := func(s: Dictionary, into: Dictionary) -> void:
		var gs: Array = Awards.genes_of(s)
		for t: String in gs:
			if t.begins_with("pseudo:") or t.begins_with("pair:") or t.begins_with("perched:") or t.begins_with("acc:tm_"):
				into[t] = int(into.get(t, 0)) + 1
		for m: String in Awards.find_marks(s, gs):
			if m in ["tm_slice", "gold_pyrite", "perched_gold"]: into["mark " + m] = int(into.get("mark " + m, 0)) + 1
	if args.has("sp"):
		for sid: String in String(args.sp).split(","):
			var got := {}
			for i in n:
				var s := Stones.roll(500000 + i, 0, 0.8, i % 9)
				s.sid = sid
				s.kind = String(Stones.pick_w(SpecLooks.kinds(sid), Rng32.new(i * 7919 + 13))) if SpecLooks.of(sid).has("kinds") else "crystal"
				for k in ["fx", "form", "skin", "beast"]: s.erase(k)
				count.call(s, got)
			for t: String in got: seen[t] = int(seen.get(t, 0)) + int(got[t])
			total += n
			print("%s (%d): %s" % [sid, n, _line(got, n)])
	else:
		for area in Data.AREAS.size():
			var got := {}
			for i in n:
				count.call(Stones.roll(300000 + area * 7777 + i, area, 0.8, i % 9), got)
			for t: String in got: seen[t] = int(seen.get(t, 0)) + int(got[t])
			total += n
			print("mine %d %s (%d): %s" % [area + 1, Data.AREAS[area].n, n, _line(got, n)])
	# the collections: which pieces never came
	for e: Dictionary in Awards.LIST:
		if not e.has("tags"): continue
		var tags: Array = e.tags
		if not tags.any(func(t: String) -> bool: return t.begins_with("pseudo:") or t.begins_with("pair:") or t.begins_with("acc:tm_")): continue
		var miss := tags.filter(func(t: String) -> bool: return not seen.has(t))
		print("%s: %d of %d seen; never: %s" % [e.n, tags.size() - miss.size(), tags.size(), ", ".join(miss) if miss.size() else "-"])
	print("different pairs seen: %d" % seen.keys().filter(func(t: String) -> bool: return t.begins_with("pair:")).size())
	get_tree().quit()

func _line(got: Dictionary, n: int) -> String:
	var ks := got.keys()
	ks.sort_custom(func(a: String, b: String) -> bool: return got[a] > got[b])
	return ", ".join(ks.map(func(t: String) -> String: return "%s %.2f%%" % [t, 100.0 * got[t] / n]))
