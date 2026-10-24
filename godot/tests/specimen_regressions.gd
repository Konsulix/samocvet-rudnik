extends Control
## Run with a rendering device: res://tests/specimen_regressions.tscn -- shot=<absolute.png>

const CASES := [
	{seed = 4, sid = "calcite", kind = "druse", gi = 3, traits = ["phantom", "goldfleck"], form = "columnar", lustre = "dark", shroom = -1},
	{seed = 4, sid = "calcite", kind = "crystal", gi = 3, traits = ["phantom", "goldfleck"], form = "slabs", lustre = "dark", shroom = -1},
	{seed = 85, sid = "quartz", kind = "crystal", gi = 3, traits = ["floater"], shroom = -1},
	{seed = 83, sid = "fluorite", kind = "druse", gi = 3, traits = ["irid"], form = "cluster", accents = ["mushrooms"], shroom = 0},
	{seed = 84, sid = "fluorite", kind = "druse", gi = 3, traits = [], form = "cluster", accents = ["mushrooms"], shroom = 2},
	{seed = 86, sid = "calcite", kind = "druse", gi = 3, traits = [], form = "columnar", accents = ["mushrooms"], shroom = 1},
	{seed = 81, sid = "quartz", kind = "crystal", gi = 3, traits = ["irid", "scepter"], form = "radial"},
	{seed = 83, sid = "beryl", kind = "geode", gi = 3, traits = [], accents = ["pompom", "straw"]},
	{seed = 84, sid = "cuprite", kind = "geode", gi = 3, traits = ["aurora"], accents = ["pompom"]},
]

var failed := false

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)

func _ready() -> void:
	check_blocked_mushrooms()
	get_window().content_scale_size = Vector2i(1260, 1080)
	var bg := ColorRect.new()
	bg.color = Color("#101823")
	bg.size = Vector2(1260, 1080)
	add_child(bg)
	for i in CASES.size():
		var item: Dictionary = CASES[i]
		var view := SpecView.new(480)
		view.position = Vector2((i % 3) * 420, 35 + (i / 3) * 355)
		view.size = Vector2(420, 320)
		view.still = true
		add_child(view)
		await view.show_spec(item)
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("angle="):
				view.live.rotation.y = float(arg.substr(6))
		var label := Label.new()
		var form: String = SpecGenome.of(item).form
		var mushroom_count := check_mushrooms(view.live, item)
		if form in ["columnar", "slabs"]:
			print("ROCK CONNECTIONS: ", form, " #", item.seed, " ", rock_connections(view.live))
		label.text = item.sid + " / " + form + (" / fungi: %d" % mushroom_count if item.has("shroom") and item.shroom >= 0 else "")
		label.position = view.position + Vector2(12, -24)
		add_child(label)
		if form != "floater":
			var found_rock := false
			for node in view.live.find_children("*", "MeshInstance3D", true, false):
				var material := (node as MeshInstance3D).material_override
				if material and material.has_meta("rock"):
					found_rock = true
			check(found_rock, form + " must include host rock")
		if i in [3, 4]:
			check(mushroom_count > 0, "Dense clusters must still have mushrooms on exposed rock")
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("baseline="):
				var previous: Node3D = load(arg.substr(9)).new()._specimen(item)
				var current: Node3D = SpecimenBuilder.build(item)
				if current.has_meta("foundation_growth"):
					check(bodies_equal(previous, current), "Keep crystal geometry while adapting the matrix: " + form)
				else:
					check(geometry_signature(previous) == geometry_signature(current), "Keep exception geometry: " + form)
				previous.free()
				current.free()
	await get_tree().create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("shot="):
			check(get_viewport().get_texture().get_image().save_png(arg.substr(5)) == OK, "Screenshot must save")
	print("SPECIMEN REGRESSIONS: ", "FAILED" if failed else "PASS")
	get_tree().quit(1 if failed else 0)

func geometry_signature(specimen: Node3D) -> Array:
	var result := []
	for node: MeshInstance3D in specimen.find_children("*", "MeshInstance3D", true, false):
		result.append([SpecUtil.rel_xform(node, specimen), node.mesh.surface_get_arrays(0)])
	return result

func body_signature(specimen: Node3D) -> Array:
	var result := []
	for child in specimen.get_children():
		if not (child is MeshInstance3D) or not child.has_meta("geo"): continue
		if child.material_override and child.material_override.get_meta("rock", false): continue
		result.append([child.transform, (child.get_meta("geo") as Geo).v])
	return result

func bodies_equal(previous: Node3D, current: Node3D) -> bool:
	var a := body_signature(previous)
	var b := body_signature(current)
	if a.size() != b.size(): return false
	for i in a.size():
		# Normalizing transformed surface normals can change the last float bits.
		if not (a[i][0] as Transform3D).is_equal_approx(b[i][0]) or a[i][1] != b[i][1]: return false
	return true

func check_blocked_mushrooms() -> void:
	var parent := Node3D.new()
	var rock_node := SpecUtil.mesh(Geo.box(2.0, 2.0, 2.0), StandardMaterial3D.new(), parent)
	var rock := SpecFungi.rock_surface(rock_node, parent)
	for kind in 4:
		check(SpecFungi.clears_rock(Transform3D(Basis.IDENTITY, Vector3(0, 1.0, 0)), kind, rock), "A mushroom above the rock must fit")
		check(not SpecFungi.clears_rock(Transform3D.IDENTITY, kind, rock), "A cap buried completely inside rock must be rejected")
		check(SpecFungi.clears_rock(Transform3D(Basis.IDENTITY, Vector3(0, -2.1, 0)), kind, rock), "A clear cap beneath an overhang must not be rejected")
	parent.remove_child(rock_node)
	rock_node.free()
	var spots := [[Vector3.ZERO, Vector3.UP]]
	var blockers: Array[Dictionary] = [{bounds = AABB(Vector3(-2, -2, -2), Vector3(4, 4, 4)), inverse = Transform3D.IDENTITY}]
	for kind in 4:
		SpecFungi.cluster(parent, Rng32.new(81), spots, kind, 4, 0.3, blockers)
		check(parent.get_child_count() == 0, "A blocked matrix must not produce embedded mushrooms or empty instances")
		SpecFungi.cluster(parent, Rng32.new(81), spots, kind, 4, 0.3)
		check(parent.get_child_count() == 1, "Every mushroom species must still spawn when space is available")
		if parent.get_child_count():
			var cluster := parent.get_child(0) as MultiMeshInstance3D
			check(cluster.multimesh.instance_count == 4, "All unblocked mushrooms must be present")
			parent.remove_child(cluster)
			cluster.free()
	parent.free()

func check_mushrooms(pivot: Node3D, item: Dictionary) -> int:
	var specimen := pivot.get_child(0) as Node3D
	var crystals: Array[MeshInstance3D] = []
	var host: MeshInstance3D
	for node: MeshInstance3D in specimen.find_children("*", "MeshInstance3D", true, false):
		var material: Material = node.material_override
		if not host and material and material.get_meta("rock", false): host = node
		if node.has_meta("geo") and material and material.get_meta("dirt", false) and not material.get_meta("rock", false):
			crystals.append(node)
	var rock := TriangleMesh.new()
	var rock_bounds := AABB()
	if host:
		var faces := host.mesh.get_faces()
		var transform := SpecUtil.rel_xform(host, specimen)
		for k in faces.size(): faces[k] = transform * faces[k]
		rock.create_from_faces(faces)
		rock_bounds = transform * host.mesh.get_aabb()
	var total := 0
	for node: MultiMeshInstance3D in specimen.find_children("*", "MultiMeshInstance3D", true, false):
		if not item.has("shroom") or item.shroom < 0 or node.material_override != SpecFungi.material(item.shroom):
			continue
		var mm := node.multimesh
		total += mm.instance_count
		for k in mm.instance_count:
			var placement: Transform3D = SpecUtil.rel_xform(node, specimen) * mm.get_instance_transform(k)
			if host:
				check(cap_clears_actual_rock(placement, mm.mesh, rock, rock_bounds), "Cap/visible stem must not penetrate the actual rock: " + item.sid)
			for crystal in crystals:
				var relative := SpecUtil.rel_xform(crystal, specimen).affine_inverse() * placement
				var mushroom_box: AABB = relative * mm.mesh.get_aabb()
				check(not mushroom_box.intersects(crystal.mesh.get_aabb()), "A mushroom must clear the finished crystal and its rocky crust: " + item.sid)
	return total

## Independent check on final rendered faces: surface crossings plus ray parity
## for a cap wholly enclosed by the rock (which has no crossing edges).
func cap_clears_actual_rock(placement: Transform3D, mushroom: Mesh, rock: TriangleMesh, bounds: AABB) -> bool:
	var faces := mushroom.get_faces()
	for k in range(0, faces.size(), 3):
		for j in 3:
			var a := faces[k + j]
			var b := faces[k + (j + 1) % 3]
			if a.y < 0.12 or b.y < 0.12: continue
			a = placement * a
			b = placement * b
			if not rock.intersect_segment(a, b).is_empty():
				print("ROCK CROSSING: ", a, " -> ", b)
				return false
	var arrays := mushroom.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var direction := Vector3(0.623, 0.227, 0.749).normalized()
	for vertex in vertices:
		if vertex.y < 0.12: continue
		var point := placement * vertex
		if not bounds.has_point(point): continue
		var crossings := 0
		for guard in 128:
			var hit := rock.intersect_ray(point, direction)
			if hit.is_empty(): break
			crossings += 1
			point = (hit.position as Vector3) + direction * 0.00001
		if crossings % 2 == 1:
			print("ROCK INSIDE: ", placement * vertex, " crossings=", crossings)
			return false
	return true

func rock_connections(pivot: Node3D) -> Dictionary:
	var specimen := pivot.get_child(0) as Node3D
	var host: MeshInstance3D
	for node: MeshInstance3D in specimen.find_children("*", "MeshInstance3D", true, false):
		if node.material_override and node.material_override.get_meta("rock", false):
			host = node
			break
	var count := 0
	var touching := 0
	if not host: return {crystals = count, touching_host = touching}
	var rock := TriangleMesh.new()
	var faces := host.mesh.get_faces()
	var host_transform := SpecUtil.rel_xform(host, specimen)
	for k in faces.size(): faces[k] = host_transform * faces[k]
	rock.create_from_faces(faces)
	for node: MeshInstance3D in specimen.find_children("*", "MeshInstance3D", true, false):
		if not node.get_meta("col", false): continue
		count += 1
		var points := node.mesh.get_faces()
		var transform := SpecUtil.rel_xform(node, specimen)
		var contact := false
		for k in range(0, points.size(), 3):
			for j in 3:
				if not rock.intersect_segment(transform * points[k + j], transform * points[k + (j + 1) % 3]).is_empty():
					contact = true
					break
			if contact: break
		if contact: touching += 1
	return {crystals = count, touching_host = touching}
