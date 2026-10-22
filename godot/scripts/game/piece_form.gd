class_name PieceForm
extends RefCounted
## The board's pieces: six silhouettes that can't be confused even in one colour, each a simple
## sculpted solid seen from straight above. One unit is one cell; the piece sits on y = 0.
##   0 prism  — a tall hexagon with a roof ridge     1 tri — a pyramid on a triangle
##   2 drop   — a smooth teardrop dome              3 cube — a square with a bevelled top
##   4 rhomb  — a diamond with a ridge               5 round — a faceted disc

const SHAPES := ["prism", "tri", "drop", "cube", "rhomb", "round"]

static var _cache := {}

static func outline(shape: String) -> PackedVector2Array:
	var o := PackedVector2Array()
	match shape:
		"prism":
			o = PackedVector2Array([Vector2(0, -0.47), Vector2(0.27, -0.29), Vector2(0.27, 0.29), Vector2(0, 0.47), Vector2(-0.27, 0.29), Vector2(-0.27, -0.29)])
		"tri":
			for k in 3: o.append(Vector2(cos(-PI / 2 + k * TAU / 3), sin(-PI / 2 + k * TAU / 3)) * 0.5 + Vector2(0, 0.08))
		"drop":
			for k in 24:
				var a := k / 24.0 * TAU
				var p := Vector2(sin(a), -cos(a))
				var f := (p.y + 1.0) * 0.5
				p.x *= 0.5 + 0.42 * sqrt(f)
				o.append(p * 0.45 + Vector2(0, 0.02))
		"cube":
			o = PackedVector2Array([Vector2(-0.37, -0.37), Vector2(0.37, -0.37), Vector2(0.37, 0.37), Vector2(-0.37, 0.37)])
		"rhomb":
			o = PackedVector2Array([Vector2(0, -0.47), Vector2(0.36, 0), Vector2(0, 0.47), Vector2(-0.36, 0)])
		_:
			for k in 10: o.append(Vector2(cos(k / 10.0 * TAU), sin(k / 10.0 * TAU)) * 0.42)
	return o

static func mesh(kind: int) -> ArrayMesh:
	var shape: String = SHAPES[kind % SHAPES.size()]
	if _cache.has(shape):
		return _cache[shape]
	var P := outline(shape)
	var n := P.size()
	var g := Geo.new()
	var tri := func(a: Vector3, b: Vector3, c: Vector3) -> void: g.v.append_array([a, b, c])
	var at := func(p: Vector2, y: float, s := 1.0) -> Vector3: return Vector3(p.x * s, y, p.y * s)
	var y0 := 0.0
	var y1 := 0.06      # straight side wall
	var y2 := 0.26      # top of the bevel
	match shape:
		"tri", "round":
			# a low pyramid / faceted cone up to a point
			var apex := Vector3(0, 0.42 if shape == "tri" else 0.3, 0.0 if shape == "round" else 0.07)
			for k in n:
				var j := (k + 1) % n
				tri.call(at.call(P[k], y1), at.call(P[j], y1), apex)
		"prism", "rhomb":
			# a roof: every side slopes up to a narrow ridge along the long axis
			var sc := Vector2(0.1, 0.62)
			var hr := 0.4
			for k in n:
				var j := (k + 1) % n
				var rk := Vector3(P[k].x * sc.x, hr, P[k].y * sc.y)
				var rj := Vector3(P[j].x * sc.x, hr, P[j].y * sc.y)
				tri.call(at.call(P[k], y1), at.call(P[j], y1), rj)
				tri.call(at.call(P[k], y1), rj, rk)
			for k in n:
				var j := (k + 1) % n
				tri.call(Vector3(0, hr, 0), Vector3(P[k].x * sc.x, hr, P[k].y * sc.y), Vector3(P[j].x * sc.x, hr, P[j].y * sc.y))
		"drop":
			for i in 5:
				var t0 := float(i) / 5
				var t1 := float(i + 1) / 5
				var s0 := cos(t0 * PI / 2)
				var s1 := maxf(cos(t1 * PI / 2), 0.001)
				var h0 := y1 + sin(t0 * PI / 2) * 0.28
				var h1 := y1 + sin(t1 * PI / 2) * 0.28
				for k in n:
					var j := (k + 1) % n
					tri.call(at.call(P[k], h0, s0), at.call(P[j], h0, s0), at.call(P[j], h1, s1))
					tri.call(at.call(P[k], h0, s0), at.call(P[j], h1, s1), at.call(P[k], h1, s1))
		_:
			# cube: a bevel ring, then a flat table
			for k in n:
				var j := (k + 1) % n
				tri.call(at.call(P[k], y1), at.call(P[j], y1), at.call(P[j], y2, 0.62))
				tri.call(at.call(P[k], y1), at.call(P[j], y2, 0.62), at.call(P[k], y2, 0.62))
			for k in n:
				tri.call(Vector3(0, y2, 0), at.call(P[k], y2, 0.62), at.call(P[(k + 1) % n], y2, 0.62))
	# side walls and a flat base
	for k in n:
		var j := (k + 1) % n
		tri.call(at.call(P[k], y0), at.call(P[j], y0), at.call(P[j], y1))
		tri.call(at.call(P[k], y0), at.call(P[j], y1), at.call(P[k], y1))
		tri.call(Vector3(0, y0, 0), at.call(P[j], y0), at.call(P[k], y0))
	g.orient_out(Vector3(0, 0.1, 0))
	var m := g.to_mesh()
	_cache[shape] = m
	return m
