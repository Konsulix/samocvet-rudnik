extends RefCounted
## Grow an undersized matrix to support the existing crystal feet. No random draws,
## no changes to crystal geometry/count, rock type, or later legendary satellites.

static func footprint(host: MeshInstance3D, root: Node3D) -> Dictionary:
	var transform := SpecUtil.rel_xform(host, root)
	var geo: Geo = host.get_meta("geo")
	var points := PackedVector2Array()
	for vertex in geo.v:
		var p := transform * vertex
		points.append(Vector2(p.x, p.z))
	var hull := Geometry2D.convex_hull(points)
	var center := Vector2.ZERO
	for i in hull.size() - 1: center += hull[i]
	center /= maxf(1.0, hull.size() - 1)
	var planes: Array[Vector3] = []
	for i in hull.size() - 1:
		var edge := hull[i + 1] - hull[i]
		if edge.length_squared() < 0.00000001: continue
		var normal := Vector2(edge.y, -edge.x).normalized()
		if normal.dot(center - hull[i]) > 0.0: normal = -normal
		planes.append(Vector3(normal.x, normal.y, normal.dot(hull[i] - center)))
	return {center = center, planes = planes}

## Clip the lower 18% of the crystal, including edge intersections at the cutoff.
## This measures the foot rather than the leaning tip or a scepter's crown.
static func foot_points(geo: Geo, transform: Transform3D) -> PackedVector2Array:
	var bounds := geo.aabb()
	var height := bounds.position.y + bounds.size.y * 0.18
	var points := PackedVector2Array()
	for vertex in geo.v:
		if vertex.y <= height:
			var p := transform * vertex
			points.append(Vector2(p.x, p.z))
	for k in geo.tri_count():
		var triangle := geo.tri(k)
		for j in 3:
			var a := triangle[j]
			var b := triangle[(j + 1) % 3]
			if (a.y < height and b.y > height) or (b.y < height and a.y > height):
				var p := transform * a.lerp(b, (height - a.y) / (b.y - a.y))
				points.append(Vector2(p.x, p.z))
	return points

static func fit(root: Node3D, host: MeshInstance3D, crystals: Array[MeshInstance3D], dirt_materials: Array, parts: Array) -> void:
	if not host or crystals.is_empty(): return
	var support := footprint(host, root)
	var center: Vector2 = support.center
	var factor := 1.0
	for crystal in crystals:
		var geo: Geo = crystal.get_meta("geo")
		var points := foot_points(geo, crystal.transform)
		var basis := crystal.basis
		var amplitude := 0.0
		if crystal.material_override in dirt_materials:
			var height := maxf(0.001, geo.aabb().size.y) if crystal.get_meta("local", false) else 1.0
			amplitude = 0.05 * height / maxf(0.2, basis.get_scale().x)
		for plane: Vector3 in support.planes:
			var normal := Vector2(plane.x, plane.y)
			var extent := -INF
			for point in points: extent = maxf(extent, normal.dot(point - center))
			var direction := Vector3(plane.x, 0, plane.y)
			var jitter := amplitude * (absf(direction.dot(basis.x)) + absf(direction.dot(basis.y)) + absf(direction.dot(basis.z)))
			factor = maxf(factor, (extent + jitter) / maxf(0.0001, plane.z * 0.97))
	if factor > 1.00001:
		# Preserve the rock's proportions, extending it downwards from its old top.
		# Crystal bodies, their anchors and their shared dirt line stay untouched.
		var rock_box: AABB = SpecUtil.rel_xform(host, root) * (host.get_meta("geo") as Geo).aabb()
		var pivot := Vector3(center.x, rock_box.end.y, center.y)
		var transform := Transform3D(Basis.from_scale(Vector3.ONE * factor), pivot * (1.0 - factor))
		host.transform = transform * host.transform
		for part: Node3D in parts:
			if part != host: part.transform = transform * part.transform
	root.set_meta("foundation_growth", factor)
