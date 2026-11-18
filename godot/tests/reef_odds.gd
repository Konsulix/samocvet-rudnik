extends Node
## how long the sea's achievements take: what share of the cove's finds are sea slabs (a trilobite's or an ammonite's on
## its matrix: the living floor grows only there), how often each fish, giant and crab comes on one, and how many finds
## (all the cove's, and slabs) it takes to have every one of a set — simulated over many players
##   godot --headless --path godot res://tests/reef_odds.tscn
func _ready() -> void:
	var n := 4000
	var slab := 0
	var sid_n := {}
	var floors: Array = []
	for i in n:
		var st := Stones.roll(700000 + i * 13, 2, 1.0, i % 9)
		var sid := String(st.sid)
		sid_n[sid] = int(sid_n.get(sid, 0)) + 1
		if not sid in ["ammonite", "trilobite"] or String(st.get("kind", "")) != "fossil":
			continue
		var fg := SpecFossil.genes(int(st.id), sid, [])
		var ok: bool = fg.get("show", "") == "matrix" or (sid == "trilobite" and fg.get("show", "") == "mass")
		if not ok: continue
		slab += 1
		floors.append(fg.get("reef", {}))
	var ps := float(slab) / n
	print("ODDS cove finds %d: ammonites %d, trilobites %d; on a sea slab %d (%.1f%%)" % [n, int(sid_n.get("ammonite", 0)), int(sid_n.get("trilobite", 0)), slab, ps * 100.0])
	var sets := {
		fish = ["swim_coelacanth", "fish_parrot", "fish_stingray", "fish_puffer", "fish_bream", "fish_balloon", "fish_coralfish", "fish_goatfish", "fish_gurnard", "fish_squid"],
		giants = ["swim_cretoxyrhina", "swim_octopus", "swim_mosasaurus", "swim_ophthalmosaurus", "swim_styxosaurus", "swim_tylosaurus", "swim_dallasaurus"],
		crabs = SpecReef.group("crab"),
		corals = SpecReef.group("coral"),
		stars = SpecReef.group("star"),
		shells = SpecReef.group("shell"),
	}
	for key: String in sets:
		var ids: Array = sets[key]
		var per := {}
		for f: Dictionary in floors:
			var have: Array = (f.get("tall", []) as Array) + (f.get("near", []) as Array) + [f.get("swim", ""), f.get("fish", "")]
			for k: String in ids:
				if k in have: per[k] = int(per.get(k, 0)) + 1
		var tot := 0
		for k in per: tot += int(per[k])
		var lo := 1e9
		for k: String in ids: lo = minf(lo, float(per.get(k, 0)) / maxf(1, slab))
		# a player: finds one by one (each a slab with ps), until every one of the set is had
		var runs := 300
		var need: Array[int] = []
		var rr := RandomNumberGenerator.new()
		rr.seed = 7
		for run in runs:
			var got := {}
			var k := 0
			while got.size() < ids.size() and k < 100000:
				k += 1
				if rr.randf() >= ps: continue
				var f: Dictionary = floors[rr.randi() % floors.size()]
				var have2: Array = (f.get("tall", []) as Array) + (f.get("near", []) as Array) + [f.get("swim", ""), f.get("fish", "")]
				for id: String in ids:
					if id in have2: got[id] = true
			need.append(k)
		need.sort()
		print("ODDS %-7s %d kinds: on a slab %.1f%% (one kind %.1f%%, rarest %.1f%%); all of them: median %d cove finds (%d slabs), one in ten players over %d" % [key, ids.size(), 100.0 * tot / maxf(1, slab), 100.0 * tot / maxf(1, slab) / ids.size(), lo * 100.0, need[runs / 2], int(need[runs / 2] * ps), need[runs * 9 / 10]])
	get_tree().quit()
