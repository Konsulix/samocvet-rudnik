extends Node
## The collector's luck (Awards.pity_roll) on a player's way: F finds a mine, down its depths, through all eight
## mines; the collections' pieces in hand at the end, with the luck and without (the same rolls otherwise).
## Runs on its own save, kept in memory only:
##   godot --headless --path godot res://tests/award_pity.tscn -- save=pitysim [f=15] [runs=3]

func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var f := int(args.get("f", "15"))
	var runs := int(args.get("runs", "3"))
	var tot := {}
	for pity in [false, true]:
		for run in runs:
			Save.d.genes = []
			Save.d.atlas = {}
			Save.d.aw_ev = {}
			Save.d.uid = 1000 + run * 7777777
			var slow := 0
			var fired := 0
			var hit := 0
			for area in Data.AREAS.size():
				var last := Data.depths(area).size()
				for i in f:
					var dl := mini(last - 1, i * last / f)
					var luck := 0.2 + dl * 0.35
					var st := Stones.roll(Save.next_uid(), area, luck, dl)
					if pity:
						var t0 := Time.get_ticks_msec()
						var due := int(Save.d.aw_ev.get("pity", 0)) >= Awards.PITY and not Awards.brings(st, Awards.wanted())
						st = Awards.pity_roll(st, area, luck, dl)
						if due:
							fired += 1
							if Awards.brings(st, Awards.wanted()): hit += 1
						slow = maxi(slow, Time.get_ticks_msec() - t0)
					var gs: Array = Awards.genes_of(st)
					Awards.note_pity(st, gs)
					for t in gs:
						if not (Save.d.genes as Array).has(t): Save.d.genes.append(t)
					var aid := Stones.atlas_id(st)
					var e: Dictionary = Save.d.atlas.get(aid, {n = 0, legend = false})
					e.n = int(e.n) + 1
					if bool(st.get("legend", false)): e.legend = true
					Save.d.atlas[aid] = e
			for e: Dictionary in Awards.LIST:
				if e.get("one", false) or e.has("evs") or e.get("lords", false): continue
				if not (e.has("tags") or e.get("legends", false) or e.has("items")): continue
				var c := Awards._count(e)
				if c.y == 0: continue
				var k := "%s|%s" % [e.n, pity]
				tot[k] = int(tot.get(k, 0)) + c.x
				tot["%s|n" % e.n] = c.y
			if pity: print("run %d: longest search %d ms, luck due %d, found %d" % [run, slow, fired, hit])
	print("%-26s %8s %8s  (of)" % ["collection", "no luck", "luck"])
	for e: Dictionary in Awards.LIST:
		if not tot.has("%s|n" % e.n): continue
		print("%-26s %8.1f %8.1f  %d" % [e.n, tot["%s|false" % e.n] / float(runs), tot["%s|true" % e.n] / float(runs), tot["%s|n" % e.n]])
	get_tree().quit()
