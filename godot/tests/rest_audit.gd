extends Node
## Do the things that stand on a find stand on something? Builds finds of a mine with flowers (and butterflies) pinned
## and measures, for every flower plant's foot (SpecFlora: a MultiMesh copy's origin) and every butterfly's perch (its
## mark), how far it is from the nearest real surface of the find (rock, moss, crystals: every mesh with its Geo).
## Over GAP — standing on air. Prints the worst and the share.
##   "$G" --headless --path godot res://tests/rest_audit.tscn -- [area=0] [n=30] [sp=a,b] [form=single] [gap=0.03]

func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var area := int(args.get("area", "0"))
	var n := int(args.get("n", "30"))
	var gap := float(args.get("gap", "0.03"))
	var pool: Dictionary = Data.AREAS[area].pool
	var sids: Array = Array(String(args.sp).split(",")) if args.has("sp") else pool.keys().filter(func(s: String) -> bool: return Data.HABIT.get(s, "") != "fossil")
	var tot := {flowers = 0, fly = 0}
	var bad := {flowers = 0, fly = 0}
	var worst := []
	for i in n:
		var sid: String = sids[i % sids.size()]
		var o := {seed = 9000 + i * 13, sid = sid, kind = "crystal", gi = 2, traits = [], accents = ["flowers"], flies = 2}
		if args.has("form"): o.form = args.form
		var root: Node3D = SpecimenBuilder.build(o)
		add_child(root)
		var surf := SpecSurf.new()
		for m in root.find_children("*", "MeshInstance3D", true, false):
			if not m.has_meta("geo"): continue
			var g: Geo = m.get_meta("geo")
			if g.v.is_empty(): continue
			surf.add(g, g.normals(), SpecUtil.rel_xform(m, root))
		var feet := []
		for mi in root.find_children("*", "MultiMeshInstance3D", true, false):
			if not mi.has_meta("stand"): continue
			# (the copies' transforms from the buffer the builder keeps: a headless run gives no GPU to read them back)
			var mm := (mi as MultiMeshInstance3D).multimesh
			var buf: PackedFloat32Array = mi.get_meta("ibuf")
			var stride := 12 + (4 if mm.use_colors else 0) + (4 if mm.use_custom_data else 0)
			var t := SpecUtil.rel_xform(mi, root)
			for k in buf.size() / stride:
				feet.append(["flowers", t * Vector3(buf[k * stride + 3], buf[k * stride + 7], buf[k * stride + 11])])
		var gr: Dictionary = root.get_meta("grown", {})
		for key: String in gr:
			if key.begins_with("fly_"):
				for mk: Array in gr[key]: feet.append(["fly", mk[0]])
		for f: Array in feet:
			var c: Array = surf.closest(f[1])
			var d := (f[1] as Vector3).distance_to(c[0]) if c.size() else 99.0
			tot[f[0]] += 1
			if d > gap:
				bad[f[0]] += 1
				worst.append([d, f[0], sid, int(o.seed), String((root.get_meta("genome") as Dictionary).form), int((root.get_meta("genome") as Dictionary).get("flora", -1))])
		root.queue_free()
		await get_tree().process_frame
	worst.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	for w: Array in worst.slice(0, 15):
		print("AIR %.3f %s %s seed=%d form=%s flora=%d" % w)
	for k: String in tot:
		print("REST %s: %d of %d over %.2f" % [k, bad[k], tot[k], gap])
	get_tree().quit()
