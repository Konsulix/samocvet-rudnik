extends Node
## Can every achievement's collection be finished? Rolls finds of each mine as the board does (Stones.roll over its
## depths) and, from the same finds made legendary, their living effects; then for every collection of genes or
## species (Awards.LIST) prints what turns up only in the reserve mines (6–8) and what turns up nowhere, with how
## rare each item is in the chain (mines 1–5: share of finds; a legend — share of legendary finds).
##   godot --headless --path godot res://tests/award_reach.tscn -- [n=1500] [leg=300]

const CHAIN := 5

func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var n := int(args.get("n", "1500"))
	var nl := int(args.get("leg", "300"))
	var chain := {}     # tag -> finds in mines 1–5
	var chain_l := {}   # fx tag -> legendary finds in mines 1–5
	var any := {}       # tag -> seen anywhere
	for area in Data.AREAS.size():
		var last := maxi(1, Data.depths(area).size())
		var sigs := {}
		var twin_at := -1
		for i in n + nl:
			var dl := i % last
			var s := Stones.roll(700000 + area * 1000003 + i * 7919, area, 0.8, dl)
			var leg := i >= n
			if leg: s.legend = true
			var tags: Array = Awards.genes_of(s)
			tags.append("sp:" + Stones.atlas_id(s))
			for m in Awards.find_marks(s, tags): tags.append("ev:" + String(m))
			# Twin Peaks (Save.note_find): the same species with the same genes (two or more) once more
			if not leg and twin_at < 0:
				var gs: Array = Awards.genes_of(s)
				gs.sort()
				var sig := String(s.sid) + "|" + ",".join(gs)
				if gs.size() >= 2 and sigs.has(sig): twin_at = i
				elif gs.size() >= 2: sigs[sig] = true
			for t: String in tags:
				if leg and not t.begins_with("fx:"): continue
				any[t] = true
				if area < CHAIN:
					var d: Dictionary = chain_l if leg else chain
					d[t] = int(d.get(t, 0)) + 1
			if i == n - 1: print("mine %d: Twin Peaks at find %d (%s)" % [area + 1, twin_at, "same sig" if twin_at >= 0 else "none"])
	var nc := float(n * CHAIN)
	var ncl := float(nl * CHAIN)
	for e: Dictionary in Awards.LIST:
		var items: Array = []
		if e.has("tags"): items = e.tags
		elif e.get("legends", false): items = SpecLegend.FX_N.keys().map(func(k: String) -> String: return "fx:" + k)
		elif e.has("items"):
			for it in e.items:
				var s := String(it)
				if s.begins_with("sp:"): items.append(s)
				elif s.begins_with("mine:"):
					for id in Data.AREAS[int(s.trim_prefix("mine:"))].pool: items.append("sp:" + String(id))
		if e.get("one", false) and String(e.get("ev", "")) in ["five_genes", "same_rock", "moth_flame", "overgrown", "maw", "fledged"]:
			items = ["ev:" + String(e.ev)]
		if items.is_empty(): continue
		var reserve: Array = []
		var never: Array = []
		var rare: Array = []
		for t: String in items:
			var k := int(chain_l.get(t, 0)) if t.begins_with("fx:") else int(chain.get(t, 0))
			if k == 0:
				if any.has(t): reserve.append(t)
				else: never.append(t)
			else:
				var p := k / (ncl if t.begins_with("fx:") else nc)
				rare.append([t, p])
		rare.sort_custom(func(a: Array, b: Array) -> bool: return float(a[1]) < float(b[1]))
		var line := "%-26s" % String(e.n)
		if rare.size(): line += " rarest " + ", ".join(rare.slice(0, 3).map(func(r: Array) -> String: return "%s %.3f%%" % [r[0], float(r[1]) * 100.0]))
		if reserve.size(): line += " | ONLY 6–8: " + ", ".join(reserve)
		if never.size(): line += " | NEVER: " + ", ".join(never)
		print(line)
	get_tree().quit()
