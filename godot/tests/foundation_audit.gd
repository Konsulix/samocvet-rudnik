extends Node

const Gallery := preload("res://tests/foundation_gallery.gd")
const SUPPORTED := ["single", "cluster", "columnar", "slabs", "rosette", "hopper", "pile", "hexplates"]
var failed := false
var count := 0
var before_overhangs := 0
var after_overhangs := 0
var unchanged_exceptions := 0
var grown_matrices := 0
var kept_matrices := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)

func _ready() -> void:
	var reference: GDScript = load("res://scripts/specimen/specimen_builder.gd")
	var reference_name := "current (determinism)"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("baseline="):
			reference = load(arg.substr(9))
			reference_name = arg.substr(9)
	var descriptions: Array = Gallery.CASES.duplicate(true)
	for i in 8:
		for seed_v in [11, 28, 90, 183]:
			var sample: Dictionary = Gallery.CASES[i].duplicate(true)
			sample.seed = seed_v
			descriptions.append(sample)
	for source: Dictionary in descriptions:
		var item := Gallery.description(source)
		var before: Node3D = reference.new()._specimen(item)
		var after := SpecimenBuilder.build(item)
		count += 1
		var form: String = SpecGenome.of(item).form
		check(before.get_meta("genome") == after.get_meta("genome"), "Genes must not change: " + str(item.seed))
		if form in SUPPORTED and item.get("cut", "") == "":
			if after.get_meta("foundation_growth", 1.0) > 1.00001: grown_matrices += 1
			else: kept_matrices += 1
			var old_host := host_of(before)
			var new_host := host_of(after)
			check(old_host != null and new_host != null, "Mounted forms need a matrix: " + form)
			if old_host and new_host:
				check((old_host.get_meta("geo") as Geo).v == (new_host.get_meta("geo") as Geo).v, "Keep the rock's original shape: " + form)
				var old_box: AABB = old_host.transform * old_host.mesh.get_aabb()
				var new_box: AABB = new_host.transform * new_host.mesh.get_aabb()
				check(absf(old_box.end.y - new_box.end.y) < 0.0001, "Keep the matrix's top fixed: " + form)
			var previous_bodies := bodies_of(before)
			var current_bodies := bodies_of(after)
			check(previous_bodies.size() == current_bodies.size(), "Keep crystal count: " + form)
			for i in mini(previous_bodies.size(), current_bodies.size()):
				var a: MeshInstance3D = previous_bodies[i]
				var b: MeshInstance3D = current_bodies[i]
				check(a.transform.is_equal_approx(b.transform), "Keep crystal size/placement: " + form)
				check((a.get_meta("geo") as Geo).v == (b.get_meta("geo") as Geo).v, "Keep crystal proportions: " + form)
			var old_bad := overhangs(before)
			var new_bad := overhangs(after)
			before_overhangs += old_bad
			after_overhangs += new_bad
			check(new_bad == 0, "Final crystal feet must fit matrix: %s #%d (%d bodies)" % [form, item.seed, new_bad])
		else:
			check(signature(before) == signature(after), "Exception geometry must match exactly: " + form)
			unchanged_exceptions += 1
		if item.get("fx", "") == "levitate":
			check(before.get_meta("anim", []).size() == 2 and after.get_meta("anim", []).size() == 2, "Keep both levitating orbits")
			for orbit: Array in after.get_meta("anim", []):
				check(orbit[0].get_child_count() >= 3, "Keep levitating crystal satellites")
		before.free()
		after.free()
		if count % 8 == 0: await get_tree().process_frame
	print("FOUNDATION AUDIT: ", "FAILED" if failed else "PASS", " cases=", count, " reference=", reference_name, " overhanging bodies before=", before_overhangs, " after=", after_overhangs, " unchanged exceptions=", unchanged_exceptions, " grown matrices=", grown_matrices, " kept matrices=", kept_matrices)
	get_tree().quit(1 if failed else 0)

func host_of(root: Node3D) -> MeshInstance3D:
	for child in root.get_children():
		if child is MeshInstance3D and child.material_override and child.material_override.get_meta("rock", false): return child
	return null

func bodies_of(root: Node3D) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for child in root.get_children():
		if child is MeshInstance3D and child.has_meta("geo") and not (child.material_override and child.material_override.get_meta("rock", false)):
			result.append(child)
	return result

## Independent check on rendered vertices against the actual rock's projected hull.
func overhangs(root: Node3D) -> int:
	var host := host_of(root)
	if not host: return 0
	var points := PackedVector2Array()
	var host_vertices: PackedVector3Array = host.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for vertex in host_vertices:
		var p := host.transform * vertex
		points.append(Vector2(p.x, p.z))
	var hull := Geometry2D.convex_hull(points)
	var bad := 0
	for body in bodies_of(root):
		var vertices: PackedVector3Array = body.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var box := body.mesh.get_aabb()
		var cutoff := box.position.y + box.size.y * 0.18
		for vertex in vertices:
			if vertex.y > cutoff: continue
			var p := body.transform * vertex
			if not Geometry2D.is_point_in_polygon(Vector2(p.x, p.z), hull):
				bad += 1
				break
	return bad

func signature(root: Node3D) -> Array:
	var result := []
	for node: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		result.append([SpecUtil.rel_xform(node, root), node.mesh.surface_get_arrays(0)])
	return result
