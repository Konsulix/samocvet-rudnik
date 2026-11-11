extends Node
## where a stone's build time goes: -- set=beasts|skulls|finds n=N [thread] [noprof]
var args := {}
func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var list := []
	var what := String(args.get("set", "finds"))
	var n := int(args.get("n", "8"))
	if what == "beasts":
		list = Admin.beast_stones().slice(int(args.get("from", "0"))).slice(0, n)
	elif what == "skulls":
		var sps := ["amethyst", "venom", "morion", "cinnabar", "celestine", "smoky", "quartz", "fluorite"]
		var pins := [{}, {show = "rock"}, {moss = "cap", trees = 3}, {flies = 3}, {eyes = "both", crown = false}, {fangs = "all"},
			{milk = "wax", tone = "grave"}, {dmg = "broken"}, {show = "rock", rock_kind = "boulder"}, {tone = "ash"}, {skin = "gold", crown = false, eyes = "none"}, {skin = "nacre"}]
		for i in n:
			var st := Stones.roll(90000 + i * 13, 0, 1.2, i % 6)
			st.sid = sps[i % sps.size()]
			st.kind = "druse"
			st.traits = []
			st.legend = false
			st.form = "skull"
			st.merge(pins[i % pins.size()], true)
			list.append(st)
	else:
		for i in n:
			list.append(Stones.roll(70000 + i * 7, i % 5, 1.2, i % 6))
	await get_tree().process_frame
	Prof.on = not args.has("noprof") and not args.has("thread")
	Prof.acc.clear()
	for rep in int(args.get("reps", "1")):
		var total := 0
		for st: Dictionary in list:
			var o := Spec.of_stone(st)
			var t0 := Time.get_ticks_msec()
			var p: Node3D
			var frames := 0
			if args.has("thread"):
				var out := [null]
				var id := WorkerThreadPool.add_task(func(): out[0] = SpecStudio.seat(SpecimenBuilder.build(o)), true, "specimen")
				while not WorkerThreadPool.is_task_completed(id):
					await get_tree().process_frame
					frames += 1
				WorkerThreadPool.wait_for_task_completion(id)
				p = out[0]
			else:
				p = SpecStudio.seat(SpecimenBuilder.build(o))
			var bt := Time.get_ticks_msec() - t0
			total += bt
			var meshes := 0
			var hc := HashingContext.new()
			hc.start(HashingContext.HASH_MD5)
			var vn := 0
			if args.has("hash"):
				for mi in p.find_children("*", "GeometryInstance3D", true, false):
					hc.update(var_to_bytes((mi as Node3D).transform))
					if mi is MultiMeshInstance3D and (mi as MultiMeshInstance3D).multimesh:
						hc.update((mi as MultiMeshInstance3D).multimesh.buffer.to_byte_array())
					if not (mi is MeshInstance3D): continue
					var m: Mesh = (mi as MeshInstance3D).mesh
					if m == null: continue
					meshes += 1
					for si in m.get_surface_count():
						var arrs := m.surface_get_arrays(si)
						vn += (arrs[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
						for a in arrs:
							if a != null: hc.update(var_to_bytes(a))
			var hs := hc.finish().hex_encode().substr(0, 10) if args.has("hash") else ""
			print("BUILD %-12s %-10s %-8s seed %-7s %5d ms  %s v%dk m%d" % [st.get("beast", st.get("form", "-")), st.sid, st.get("skin", "."), st.id, bt, hs, vn / 1000, meshes])
			p.free()
			if args.has("each") and Prof.on: Prof.dump("%s %s" % [st.get("beast", st.sid), st.get("skin", "")], int(args.get("top", "14")))
			await get_tree().process_frame
		print("BUILD total %d ms for %d" % [total, list.size()])
		if Prof.on: Prof.dump(what + " pass %d" % rep, int(args.get("top", "45")))
	get_tree().quit()
