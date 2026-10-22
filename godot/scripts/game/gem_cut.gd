class_name GemCut
extends RefCounted
## Faceted stones for the board, one cut per colour so each reads by its outline from straight above:
## ruby — cushion, sapphire — round brilliant, emerald — step-cut octagon, citrine — pear,
## amethyst — trillion, moonstone — a domed cabochon. One unit is one cell; the stone sits on y = 0.

static var _cache := {}

static func outline(shape: String, R: float) -> PackedVector2Array:
	var o := PackedVector2Array()
	match shape:
		"round":
			for k in 16: o.append(Vector2(cos(k / 16.0 * TAU), sin(k / 16.0 * TAU)) * R)
		"cushion":
			# a softly squared outline (superellipse)
			for k in 20:
				var a := k / 20.0 * TAU
				var c := cos(a)
				var s := sin(a)
				o.append(Vector2(signf(c) * pow(absf(c), 0.55), signf(s) * pow(absf(s), 0.55)) * R * 0.9)
		"octagon":
			var w := R * 0.74
			var h := R * 0.95
			var cc := R * 0.26
			o = PackedVector2Array([Vector2(-w + cc, -h), Vector2(w - cc, -h), Vector2(w, -h + cc), Vector2(w, h - cc), Vector2(w - cc, h), Vector2(-w + cc, h), Vector2(-w, h - cc), Vector2(-w, -h + cc)])
		"kite":
			# a pear: round below, drawn to a point above
			for k in 18:
				var a := k / 18.0 * TAU
				var p := Vector2(sin(a), -cos(a))
				var t := (p.y + 1.0) * 0.5
				p.x *= 0.62 + 0.28 * t - 0.25 * (1.0 - t) * (1.0 - t)
				o.append(Vector2(p.x, p.y * 1.02 + 0.06) * R)
		"trillion":
			for k in 15:
				var side := k / 5
				var f := (k % 5) / 5.0
				var a0 := -PI / 2 + side * TAU / 3.0
				var a1 := a0 + TAU / 3.0
				var p := Vector2(cos(a0), sin(a0)).lerp(Vector2(cos(a1), sin(a1)), f)
				p *= 1.0 + 0.12 * sin(f * PI)   # slightly bowed sides
				o.append((p + Vector2(0, 0.12)) * R * 1.02)
		_:
			for k in 24: o.append(Vector2(cos(k / 24.0 * TAU), sin(k / 24.0 * TAU)) * R * 0.92)
	return o

static func mesh(shape: String) -> ArrayMesh:
	if _cache.has(shape):
		return _cache[shape]
	var R := 0.43
	var P := outline(shape, R)
	var n := P.size()
	var g := Geo.new()
	var tri := func(a: Vector3, b: Vector3, c: Vector3) -> void:
		g.v.append_array([a, b, c])
	var at := func(p: Vector2, y: float, s := 1.0) -> Vector3: return Vector3(p.x * s, y, p.y * s)
	var girdle := 0.04
	var y_g := 0.12
	if shape == "hex":
		# moonstone: a smooth dome over a thin girdle
		var rings := 6
		for i in rings:
			var t0 := float(i) / rings
			var t1 := float(i + 1) / rings
			for k in n:
				var j := (k + 1) % n
				var a: Vector3 = at.call(P[k], y_g + girdle + sin(t0 * PI / 2) * 0.24, cos(t0 * PI / 2) * 0.999 + 0.001)
				var b: Vector3 = at.call(P[j], y_g + girdle + sin(t0 * PI / 2) * 0.24, cos(t0 * PI / 2) * 0.999 + 0.001)
				var c: Vector3 = at.call(P[j], y_g + girdle + sin(t1 * PI / 2) * 0.24, cos(t1 * PI / 2) * 0.999 + 0.001)
				var d: Vector3 = at.call(P[k], y_g + girdle + sin(t1 * PI / 2) * 0.24, cos(t1 * PI / 2) * 0.999 + 0.001)
				tri.call(a, b, c)
				tri.call(a, c, d)
	elif shape == "octagon":
		# step cut: terraces climbing to a broad flat table
		var steps := [[1.0, 0.0], [0.88, 0.06], [0.76, 0.11], [0.64, 0.14]]
		for i in steps.size() - 1:
			for k in n:
				var j := (k + 1) % n
				var s0: float = steps[i][0]
				var s1: float = steps[i + 1][0]
				var h0: float = y_g + girdle + float(steps[i][1])
				var h1: float = y_g + girdle + float(steps[i + 1][1])
				tri.call(at.call(P[k], h0, s0), at.call(P[j], h0, s0), at.call(P[j], h1, s1))
				tri.call(at.call(P[k], h0, s0), at.call(P[j], h1, s1), at.call(P[k], h1, s1))
		var ht: float = y_g + girdle + float(steps[-1][1])
		for k in n:
			tri.call(Vector3(0, ht, 0), at.call(P[k], ht, 0.64), at.call(P[(k + 1) % n], ht, 0.64))
	else:
		# brilliant-style crown: table, star facets and kite-shaped main facets down to the girdle
		var ts := 0.52
		var hc := 0.13
		var ht := y_g + girdle + hc
		for k in n:
			var j := (k + 1) % n
			var pk: Vector3 = at.call(P[k], y_g + girdle)
			var pj: Vector3 = at.call(P[j], y_g + girdle)
			var tk: Vector3 = at.call(P[k], ht, ts)
			var tj: Vector3 = at.call(P[j], ht, ts)
			# a star point between table corners, pushed out and down
			var mid := (P[k] + P[j]) * 0.5
			var star: Vector3 = at.call(mid, y_g + girdle + hc * 0.55, 0.78)
			tri.call(tk, tj, star)
			tri.call(pk, pj, star)
			tri.call(pk, star, tk)
			tri.call(pj, tj, star)
			tri.call(Vector3(0, ht, 0), tj, tk)
	# girdle band and the pavilion down to a point below
	for k in n:
		var j := (k + 1) % n
		var a: Vector3 = at.call(P[k], y_g)
		var b: Vector3 = at.call(P[j], y_g)
		var c: Vector3 = at.call(P[j], y_g + girdle)
		var d: Vector3 = at.call(P[k], y_g + girdle)
		tri.call(a, c, b)
		tri.call(a, d, c)
		tri.call(Vector3(0, -0.12, 0), b, a)
	g.orient_out(Vector3(0, 0.12, 0))
	var m := g.to_mesh()
	_cache[shape] = m
	return m
