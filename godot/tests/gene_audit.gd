extends Control
## Gene audit: is each gene actually seen on the stone? For every gene, a few species that may carry it (SpecLooks.never
## respected), each built twice from the same seed — without the gene and with it pinned — in the same still pose.
## Saves both pictures (user://audit/<gene>_<k>_a.png / _b.png) and a line per pair in user://audit/audit.jsonl:
## gene, species, seed, whether the gene grew (a chip would show). tools: art/refs/genes/audit_report.py makes the
## numbers (how much of the stone changed) and the sheets to judge by eye.
##   godot --path godot --resolution 800x420 res://tests/gene_audit.tscn -- [genes=irid,twin] [k=4] [px=360] [base=7]

const TRAITS := ["irid", "aurora", "zoned", "phantom", "chlorite", "anomaly", "twin", "druzy", "bubbles", "enhydro",
	"rutile", "goldfleck", "floater", "scepter", "eroded", "silver", "limonite", "moss", "coral", "atypical"]
const ACCENTS := ["pompom", "straw", "lichen", "needles", "crust", "dust", "inkspots", "clouds", "fronds", "flowers", "mushrooms"]

func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var genes: Array = Array(String(args.genes).split(",")) if args.has("genes") else TRAITS + ACCENTS
	var K := int(args.get("k", "4"))
	var px := int(args.get("px", "360"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://audit"))
	var log := FileAccess.open("user://audit/audit.jsonl", FileAccess.WRITE if not args.has("append") else FileAccess.READ_WRITE)
	if args.has("append"): log.seek_end()
	# the crystal species of every mine (no fossils, nuggets or the generator's own bodies)
	var pool := []
	for a: Dictionary in Data.AREAS:
		for sid: String in a.get("pool", {}):
			var h: String = Data.HABIT.get(sid, "prism")
			if h in ["fossil", "obsidian"] or sid in Data.NUGGETY or sid in pool: continue
			pool.append(sid)
	var rng := Rng32.new(int(args.get("base", "7")))
	var views: Array[SpecView] = []
	for i in 2:
		var v := SpecView.new(px)
		v.position = Vector2(i * px, 0)
		v.size = Vector2(px, px)
		v.still = true
		v.zoomable = false
		add_child(v)
		views.append(v)
	for g: String in genes:
		var is_acc := g in ACCENTS
		var ok := pool.filter(func(s: String) -> bool: return not g in SpecLooks.never(s))
		for k in K:
			var sid: String = ok[int(rng.next() * ok.size())]
			var sd := 1000 + int(rng.next() * 900000)
			var kinds: Array = SpecLooks.kinds(sid)
			var kind := String(Stones.pick_w(kinds, Rng32.new(sd * 977)))
			var base := {seed = sd, sid = sid, kind = kind, gi = 2, traits = [], accents = []}
			var with := base.duplicate(true)
			if is_acc: with.accents = [g]
			else: with.traits = [g]
			var grown := false
			for i in 2:
				await views[i].show_spec(base if i == 0 else with)
			for f in 20: await get_tree().process_frame
			for i in 2:
				var v := views[i]
				if i == 1 and v.live: grown = (v.live.get_meta("grown", {}) as Dictionary).has(g)
				v.studio.vp.render_target_update_mode = SubViewport.UPDATE_ONCE
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			for i in 2:
				views[i].studio.vp.get_texture().get_image().save_png("user://audit/%s_%d_%s.png" % [g, k, "a" if i == 0 else "b"])
			log.store_line(JSON.stringify({gene = g, k = k, sid = sid, seed = sd, kind = kind, grown = grown}))
			log.flush()
			print("AUDIT ", g, " ", k, " ", sid, " grown=", grown)
	get_tree().quit()
