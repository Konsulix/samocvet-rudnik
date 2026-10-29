class_name Bend
## ONE straight drawing (a tentacle, a snake, an eel, a pennant, a tail...) bent along a curve that code moves, so the motion
## is continuous instead of a handful of frames. The drawing lies along its texture's x: u 0 at its left end, 1 at its right.
## `chain` walks a centreline from an angle per point; `draw` lays the strip on it as one triangle array (one draw call),
## one normal per point from its neighbours - quads over a sharp bend fold over and fail.

## a centreline of n segments, `length` long from `at`; angle(q) - the direction (radians) at q = 0..1 along it
static func chain(at: Vector2, length: float, n: int, angle: Callable) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var p := at
	for i in n + 1:
		pts.append(p)
		var a: float = angle.call(float(i) / n)
		p += Vector2(cos(a), sin(a)) * length / n
	return pts

## a smooth line through control points (Catmull-Rom), `per` points per span
static func smooth(ctrl: PackedVector2Array, per := 10) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := ctrl.size()
	for i in n - 1:
		var p0 := ctrl[maxi(i - 1, 0)]
		var p1 := ctrl[i]
		var p2 := ctrl[i + 1]
		var p3 := ctrl[mini(i + 2, n - 1)]
		for j in per:
			var t := float(j) / per
			out.append(0.5 * (2.0 * p1 + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t
				+ (3.0 * p1 - p0 - 3.0 * p2 + p3) * t * t * t))
	out.append(ctrl[n - 1])
	return out

static func length(line: PackedVector2Array) -> float:
	var l := 0.0
	for i in line.size() - 1: l += line[i].distance_to(line[i + 1])
	return l

## the point at arc length `s` along a line (held at its ends)
static func at(line: PackedVector2Array, s: float) -> Vector2:
	if s <= 0.0: return line[0]
	for i in line.size() - 1:
		var d := line[i].distance_to(line[i + 1])
		if s <= d: return line[i].lerp(line[i + 1], s / maxf(d, 0.0001))
		s -= d
	return line[line.size() - 1]

## n + 1 points from arc length a to b along a line: a body sliding along a path keeps to it, as a snake does
static func sample(line: PackedVector2Array, a: float, b: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n + 1:
		pts.append(at(line, lerpf(a, b, float(i) / n)))
	return pts

## lays the texture's [u0, u1] stretch on pts (pts[0] gets u0); width(q) - the half width at q = 0..1 along pts;
## flip - the texture's top on the curve's right (as seen going along it) instead of its left; col - a Color or
## a Callable(q) -> Color (a body darkening into its hole)
static func draw(c: CanvasItem, pts: PackedVector2Array, width: Callable, tex: Texture2D, u0 := 0.0, u1 := 1.0,
		flip := false, col: Variant = Color.WHITE, v0 := 0.0, v1 := 1.0) -> void:
	var n := pts.size() - 1
	if n < 1 or tex == null:
		return
	var verts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var sg := -1.0 if flip else 1.0
	for i in n + 1:
		var q := float(i) / n
		var d := (pts[mini(i + 1, n)] - pts[maxi(i - 1, 0)]).normalized()
		var s := d.orthogonal() * float(width.call(q)) * sg
		var u := lerpf(u0, u1, q)
		verts.append(pts[i] + s)
		verts.append(pts[i] - s)
		uvs.append(Vector2(u, v0))
		uvs.append(Vector2(u, v1))
		var cq: Color = col.call(q) if col is Callable else col
		cols.append(cq)
		cols.append(cq)
		if i < n:
			var k := i * 2
			idx.append_array([k, k + 2, k + 3, k, k + 3, k + 1])
	RenderingServer.canvas_item_add_triangle_array(c.get_canvas_item(), idx, verts, cols, uvs,
		PackedInt32Array(), PackedFloat32Array(), tex.get_rid())
