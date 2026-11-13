extends Node
## Do the things that stand on a find stand on something? Builds finds of a mine with flowers (and butterflies) pinned
## and measures, for every flower plant's foot (SpecFlora: a MultiMesh copy's origin) and every butterfly's perch (its
## mark), how far it is from the nearest real surface of the find (rock, moss, crystals: every mesh with its Geo).
## Over GAP — standing on air. Prints the worst and the share.
##   "$G" --headless --path godot res://tests/rest_audit.tscn -- [area=0] [n=30] [sp=a,b] [form=single] [gap=0.03]
## size: also how tall the mushrooms and flowers stand, of the find's height (acc=mushrooms|flowers, shroom=N)

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
	var sizes := []
	var stems := []
	for i in n:
		var sid: String = sids[i % sids.size()]
		var o := {seed = 9000 + i * 13, sid = sid, kind = "crystal", gi = 2, traits = [], accents = Array(String(args.get("acc", "flowers")).split(",")), flies = 2}
		if args.has("shroom"): o.shroom = int(args.shroom)
		if args.has("form"): o.form = args.form
		var o_seed := int(o.seed)
		var root: Node3D = SpecimenBuilder.build(o)
		add_child(root)
		var surf := SpecSurf.new()
		for m in root.find_children("*", "MeshInstance3D", true, false):
			if not m.has_meta("geo"): continue
			var g: Geo = m.get_meta("geo")
			if g.v.is_empty(): continue
			surf.add(g, g.normals(), SpecUtil.rel_xform(m, root))
		var feet := []
		var body := AABB()
		var nb := 0
		for m in root.find_children("*", "MeshInstance3D", true, false):
			if m.has_meta("geo") and (m.get_meta("crystal", false) or m.has_meta("base")):
				var bb := SpecUtil.rel_xform(m, root) * (m.get_meta("geo") as Geo).aabb()
				body = bb if nb == 0 else body.merge(bb)
				nb += 1
		for mi in root.find_children("*", "MultiMeshInstance3D", true, false):
			if args.has("size") and (mi as MultiMeshInstance3D).multimesh and (mi as MultiMeshInstance3D).multimesh.mesh and (mi.has_meta("stand") or String(mi.get_meta("gene", "")) == "mushrooms" or _gene(mi, root) == "mushrooms"):
				var mm2 := (mi as MultiMeshInstance3D).multimesh
				var key := "ibuf" if mi.has_meta("ibuf") else "mmbuf"
				if mi.has_meta(key):
					var b2: PackedFloat32Array = mi.get_meta(key)
					var st2 := 12 + (4 if mm2.use_colors else 0) + (4 if mm2.use_custom_data else 0)
					var hm := mm2.mesh.get_aabb().size.y
					for k in b2.size() / st2:
						var sy := Vector3(b2[k * st2 + 1], b2[k * st2 + 5], b2[k * st2 + 9]).length() * hm
						sizes.append(sy / maxf(body.size.y, 0.01))
			if not mi.has_meta("stand"): continue
			# (the copies' transforms from the buffer the builder keeps: a headless run gives no GPU to read them back)
			var mm := (mi as MultiMeshInstance3D).multimesh
			var buf: PackedFloat32Array = mi.get_meta("ibuf")
			var stride := 12 + (4 if mm.use_colors else 0) + (4 if mm.use_custom_data else 0)
			var t := SpecUtil.rel_xform(mi, root)
			# the stem's foot: the model's lowest eighth (a plant is one unit tall, its foot at the origin), copy by copy
			var low := PackedVector3Array()
			var mv: PackedVector3Array = (mm.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX] if mm.mesh is ArrayMesh else PackedVector3Array()
			for v in mv:
				if v.y < 0.12 and Vector2(v.x, v.z).length() < 0.04: low.append(v)
			for k in buf.size() / stride:
				var bo := k * stride
				var xf := t * Transform3D(Basis(Vector3(buf[bo], buf[bo + 4], buf[bo + 8]), Vector3(buf[bo + 1], buf[bo + 5], buf[bo + 9]), Vector3(buf[bo + 2], buf[bo + 6], buf[bo + 10])), Vector3(buf[bo + 3], buf[bo + 7], buf[bo + 11]))
				feet.append(["flowers", xf.origin])
				# how far the foot of its stem stands out of the find: the worst of its low points, out along the surface's normal
				var out := 0.0
				for v in low:
					var w := xf * v
					var c: Array = surf.closest(w)
					var d := 0.2 if c.is_empty() else (w - (c[0] as Vector3)).dot(c[1])
					out = maxf(out, d)
				stems.append([out, sid, int(o_seed), int(k)])
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
	if stems.size():
		stems.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
		var over := stems.filter(func(q: Array) -> bool: return q[0] > gap).size()
		print("STEM out of the find over %.2f: %d of %d; worst %s" % [gap, over, stems.size(), str(stems.slice(0, 5))])
	if sizes.size():
		sizes.sort()
		var sm := 0.0
		for v: float in sizes: sm += v
		print("SIZE n=%d mean %.3f median %.3f p90 %.3f max %.3f" % [sizes.size(), sm / sizes.size(), sizes[sizes.size() / 2], sizes[int(sizes.size() * 0.9)], sizes[-1]])
	get_tree().quit()

func _gene(n: Node, root: Node) -> String:
	var p := n
	while p and p != root:
		if p.has_meta("gene"): return String(p.get_meta("gene"))
		p = p.get_parent()
	return ""
