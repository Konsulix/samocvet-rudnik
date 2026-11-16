extends Node
## Are the pieces of a broken lump (SpecimenBuilder._shatter) closed? Counts the open edges (an edge only one triangle
## of the mesh has, by position) of every mesh of a find, whole (integ 100) and broken (integ 30/60): a broken piece
## open where its fracture should close it shows as a hollow shell, "a thin leaf".
##   "$G" --headless --path godot res://tests/shatter_check.tscn -- [n=6] [integ=30]

func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var n := int(args.get("n", "6"))
	var ig := int(args.get("integ", "30"))
	for want: Array in [["nativecu", "vein"], ["nativecu", "nugget"], ["malachite", "botryoid"], ["malachite", "sawn"]]:
		if args.has("only") and String(args.only) != want[0] + "_" + want[1]: continue
		var found := 0
		var sd := 170000
		while found < n and sd < 190000:
			sd += 1
			var st := Stones.roll(sd, 1, 1.2, 2)
			st.sid = want[0]
			st.kind = "crystal"
			st.legend = false
			if String(SpecGenome.of(Spec.of_stone(st)).form) != String(want[1]): continue
			found += 1
			var line := "%s %s %d:" % [want[0], want[1], sd]
			for i in [100, ig]:
				st.integ = i
				SpecimenBuilder.fallbacks = 0
				var r := SpecimenBuilder.build(Spec.of_stone(st))
				# all meshes together in the find's space: a piece's skin and its fracture are two meshes, one open edge each
				var cnt := {}
				var ms := _meshes(r)
				for m: MeshInstance3D in ms:
					_count(m.get_meta("geo"), SpecUtil.rel_xform(m, r), cnt)
				var open := 0
				for k in cnt:
					if int(cnt[k]) == 1: open += 1
				# spikes: triangles of a fracture turned hard away from the fracture's own facing (it should lie near flat)
				var steep := 0
				var ftris := 0
				for m: MeshInstance3D in ms:
					if not m.get_meta("is_face", false): continue
					var g: Geo = m.get_meta("geo")
					var avg := Vector3.ZERO
					var fns := []
					for tt in g.tri_count():
						var a := g.v[g.idx[tt * 3]]
						var b := g.v[g.idx[tt * 3 + 1]]
						var c := g.v[g.idx[tt * 3 + 2]]
						var fn := (c - b).cross(a - b)
						avg += fn
						fns.append(fn.normalized())
					avg = avg.normalized()
					for fn: Vector3 in fns:
						ftris += 1
						if fn.dot(avg) < 0.25: steep += 1
				# (all meshes together in the find's space: a skin's rim point has its ring completed by the fracture)
				var all_g := Geo.new()
				for m: MeshInstance3D in ms:
					if m.material_override is ShaderMaterial and float((m.material_override as ShaderMaterial).get_shader_parameter("metal")) > 0.5: continue
					var g: Geo = m.get_meta("geo")
					var tf := SpecUtil.rel_xform(m, r)
					var ind := g.indexed()
					for tt in g.tri_count():
						for c in 3: all_g.v.append(tf * g.v[g.idx[tt * 3 + c] if ind else tt * 3 + c])
				var peaks := _peaks(all_g)
				line += "  integ %d: %d meshes, %d open edges, %d/%d steep, %d peaks, %d fallbacks" % [i, ms.size(), open, steep, ftris, peaks, SpecimenBuilder.fallbacks]
				if args.has("who") and i != 100:
					# per piece (a skin and its fracture share their points): which are open
					var groups := {}
					for m: MeshInstance3D in ms:
						var g: Geo = m.get_meta("geo")
						var gk := "%d|%s" % [g.v.size(), str(g.v[0])]
						if not groups.has(gk): groups[gk] = []
						(groups[gk] as Array).append(m)
					for gk in groups:
						var c2 := {}
						for m: MeshInstance3D in groups[gk]: _count(m.get_meta("geo"), SpecUtil.rel_xform(m, r), c2)
						var o2 := 0
						for k in c2:
							if int(c2[k]) == 1: o2 += 1
						if o2 > 0:
							var m0: MeshInstance3D = groups[gk][0]
							var g0: Geo = m0.get_meta("geo")
							var tri_n := 0
							for m: MeshInstance3D in groups[gk]: tri_n += (m.get_meta("geo") as Geo).tri_count()
							print("   open ", o2, " in ", (groups[gk] as Array).size(), " meshes, ", g0.v.size(), " points, ", tri_n, " tris, shader ", (m0.material_override as ShaderMaterial).shader.resource_path.get_file() if m0.material_override is ShaderMaterial else "-")
				r.free()
			print(line)
	get_tree().quit()

func _meshes(r: Node) -> Array:
	var out := []
	var stack: Array[Node] = [r]
	while stack.size():
		var x: Node = stack.pop_back()
		stack.append_array(x.get_children())
		if x is MeshInstance3D and x.has_meta("geo") and (x.get_meta("geo") as Geo).v.size() > 200: out.append(x)
	return out

func _count(g: Geo, t: Transform3D, cnt: Dictionary) -> void:
	var key := func(p: Vector3) -> Vector3i: return Vector3i(roundi(p.x * 2000.0), roundi(p.y * 2000.0), roundi(p.z * 2000.0))
	var ind := g.indexed()
	for tt in g.tri_count():
		var ids := []
		for c in 3:
			ids.append(key.call(t * g.v[g.idx[tt * 3 + c] if ind else tt * 3 + c]))
		for c in 3:
			var a: Vector3i = ids[c]
			var b: Vector3i = ids[(c + 1) % 3]
			if a == b: continue
			var ks := str([a, b] if str(a) < str(b) else [b, a])
			cnt[ks] = int(cnt.get(ks, 0)) + 1

## points standing out of the ring of their neighbours by more than the ring's own size: spikes
func _peaks(g: Geo) -> int:
	var key := func(p: Vector3) -> Vector3i: return Vector3i(roundi(p.x * 20000.0), roundi(p.y * 20000.0), roundi(p.z * 20000.0))
	var nb := {}
	var ind := g.indexed()
	for tt in g.tri_count():
		var ps := []
		for c in 3: ps.append(g.v[g.idx[tt * 3 + c] if ind else tt * 3 + c])
		for c in 3:
			var k: Vector3i = key.call(ps[c])
			if not nb.has(k): nb[k] = [ps[c], {}]
			for o in 3:
				if o != c: (nb[k][1] as Dictionary)[key.call(ps[o])] = ps[o]
	var out := 0
	for k in nb:
		var p: Vector3 = nb[k][0]
		var ring: Dictionary = nb[k][1]
		if ring.size() < 3: continue
		var c := Vector3.ZERO
		var el := 0.0
		for q: Vector3 in ring.values():
			c += q
			el += p.distance_to(q)
		c /= ring.size()
		el /= ring.size()
		if p.distance_to(c) > el * 0.9 and el > 1e-4: out += 1
	return out
