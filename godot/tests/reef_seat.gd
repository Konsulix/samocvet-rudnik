extends Node
## the sea floor's small lying things (crabs, stars, shells) on an ammonite's or a trilobite's slab: how many found a
## seat, and how far each is tipped from level (before the slab is held up to the eye) and how much of it is off the rock
## godot --headless --path godot res://tests/reef_seat.tscn -- [n=4] [groups=crab,star,shell]
func _ready() -> void:
	await get_tree().process_frame
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	var n := int(args.get("n", "4"))
	for grp: String in String(args.get("groups", "crab,star,shell")).split(","):
		var tot := 0
		var got := 0
		var tips: Array = []
		for id: String in SpecReef.group(grp):
			for sid in ["ammonite", "trilobite"]:
				for i in n:
					var sd := 4000 + i * 37 + tot
					var o := Spec.of_stone({id = sd, seed = sd, sid = sid, kind = "fossil", gi = 2, traits = [], dl = 0, area = 2, g = 300, value = 300})
					o.show = "matrix"
					o.reef = {tall = [], near = [id], swim = "", fish = "", fish_n = 1}
					var r := SpecimenBuilder.build(o)
					tot += 1
					var floor_n: Node3D = r.get_meta("sea_floor") if r.has_meta("sea_floor") else r
					for mi in r.find_children("*", "MeshInstance3D", true, false):
						var m := mi as MeshInstance3D
						if m.mesh != SpecReef.mesh(id): continue
						got += 1
						# its up, in the slab's own space (before the slab is held up)
						var tf := Transform3D.IDENTITY
						var nd: Node = m
						while nd and nd != floor_n:
							if nd is Node3D: tf = (nd as Node3D).transform * tf
							nd = nd.get_parent()
						var up := tf.basis.y.normalized()
						tips.append(rad_to_deg(up.angle_to(Vector3.UP)))
						break
					r.free()
		tips.sort()
		var med: float = tips[tips.size() / 2] if tips.size() else 0.0
		var mx: float = tips[-1] if tips.size() else 0.0
		print("SEAT %s seated %d of %d, tipped median %.0f°, worst %.0f°" % [grp, got, tot, med, mx])
	get_tree().quit()
