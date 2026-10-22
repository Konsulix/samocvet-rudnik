class_name GemArt
extends RefCounted
## Vector art for everything on the board, drawn with a CanvasItem's draw_* calls around (0, 0) in a cell of size S.
## Ported from the prototype's canvas drawings; gradients are done with vertex colours and triangle fans.

const NODULE := preload("res://assets/img/nodule.webp")

## transform the art is drawn under; internal rotations compose with it
static var base := Transform2D.IDENTITY

static func begin(ci: CanvasItem, xf: Transform2D) -> void:
	base = xf
	ci.draw_set_transform_matrix(xf)

static func end(ci: CanvasItem) -> void:
	base = Transform2D.IDENTITY
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)

static func _xf(ci: CanvasItem, pos: Vector2, rot := 0.0, sc := Vector2.ONE) -> void:
	ci.draw_set_transform_matrix(base * Transform2D(rot, sc, 0.0, pos))

# ---------------------------------------------------------------- helpers

static func ellipse_pts(c: Vector2, rx: float, ry: float, rot := 0.0, n := 24) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in n:
		var a := k / float(n) * TAU
		out.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	return out

## corners cut into small arcs, like canvas arcTo rounding
static func rounded(pts: PackedVector2Array, rad: float, steps := 4) -> PackedVector2Array:
	if rad <= 0.0: return pts
	var out := PackedVector2Array()
	var n := pts.size()
	for k in n:
		var p := pts[k]
		var a := pts[(k - 1 + n) % n]
		var b := pts[(k + 1) % n]
		var da := (a - p).normalized()
		var db := (b - p).normalized()
		var r := minf(rad, minf(p.distance_to(a), p.distance_to(b)) * 0.45)
		var p0 := p + da * r
		var p1 := p + db * r
		for s in steps + 1:
			var t := s / float(steps)
			out.append(p0.lerp(p, t).lerp(p.lerp(p1, t), t))   # quadratic bezier through the corner
	return out

static func rrect(pos: Vector2, size: Vector2, rad: float) -> PackedVector2Array:
	return rounded(PackedVector2Array([pos, pos + Vector2(size.x, 0), pos + size, pos + Vector2(0, size.y)]), rad)

## polygon shaded along a direction: colours at t=0, 0.35 and 1
static func grad_poly(ci: CanvasItem, pts: PackedVector2Array, from: Vector2, to: Vector2, c0: Color, c1: Color, c2: Color) -> void:
	var cols := PackedColorArray()
	var d := to - from
	var len2 := maxf(d.length_squared(), 0.0001)
	for p in pts:
		var t := clampf((p - from).dot(d) / len2, 0.0, 1.0)
		cols.append(c0.lerp(c1, t / 0.35) if t < 0.35 else c1.lerp(c2, (t - 0.35) / 0.65))
	ci.draw_polygon(pts, cols)

## radial gradient as a fan from `center`
static func radial_fan(ci: CanvasItem, center: Vector2, pts: PackedVector2Array, c_in: Color, c_out: Color) -> void:
	var n := pts.size()
	for k in n:
		ci.draw_polygon(PackedVector2Array([center, pts[k], pts[(k + 1) % n]]), PackedColorArray([c_in, c_out, c_out]))

static func radial_disc(ci: CanvasItem, c: Vector2, r: float, c_in: Color, c_mid: Color, c_out: Color, mid := 0.5, n := 28) -> void:
	radial_fan(ci, c, ellipse_pts(c, r * mid, r * mid, 0, n), c_in, c_mid)
	var inner := ellipse_pts(c, r * mid, r * mid, 0, n)
	var outer := ellipse_pts(c, r, r, 0, n)
	for k in n:
		var j := (k + 1) % n
		ci.draw_polygon(PackedVector2Array([inner[k], outer[k], outer[j], inner[j]]), PackedColorArray([c_mid, c_out, c_out, c_mid]))

static func closed(pts: PackedVector2Array) -> PackedVector2Array:
	var o := pts.duplicate()
	o.append(pts[0])
	return o

# ---------------------------------------------------------------- stones

static func shape_pts(shape: String, R: float) -> PackedVector2Array:
	var o := PackedVector2Array()
	match shape:
		"round":
			for k in 16: o.append(Vector2(cos(k / 16.0 * TAU - PI / 2), sin(k / 16.0 * TAU - PI / 2)) * R)
		"cushion":
			var s := R * 0.86; var c := R * 0.34
			o = PackedVector2Array([Vector2(-s + c, -s), Vector2(s - c, -s), Vector2(s, -s + c), Vector2(s, s - c), Vector2(s - c, s), Vector2(-s + c, s), Vector2(-s, s - c), Vector2(-s, -s + c)])
		"octagon":
			var w := R * 0.78; var h := R * 0.95; var c := R * 0.3
			o = PackedVector2Array([Vector2(-w + c, -h), Vector2(w - c, -h), Vector2(w, -h + c), Vector2(w, h - c), Vector2(w - c, h), Vector2(-w + c, h), Vector2(-w, h - c), Vector2(-w, -h + c)])
		"hex":
			for k in 6: o.append(Vector2(cos(k / 6.0 * TAU - PI / 2), sin(k / 6.0 * TAU - PI / 2)) * R * 0.95)
		"kite":
			o = PackedVector2Array([Vector2(0, -R), Vector2(R * 0.82, -R * 0.12), Vector2(0, R), Vector2(-R * 0.82, -R * 0.12)])
		_:
			o = PackedVector2Array([Vector2(0, -R * 0.95), Vector2(R * 0.95, R * 0.72), Vector2(-R * 0.95, R * 0.72)])
	return o

static func gem(ci: CanvasItem, t: int, S: float) -> void:
	var g: Dictionary = Data.GEMS[t]
	var R := S * 0.43
	var shape: String = g.shape
	var rd := 0.0 if shape == "round" else S * 0.1 if shape == "trillion" else S * 0.06
	var off := Vector2(0, S * 0.04 if shape == "trillion" else 0.0)
	var pts := rounded(shape_pts(shape, R), rd)
	for i in pts.size(): pts[i] += off
	var cl := Color.html(g.l); var cc := Color.html(g.c); var cd := Color.html(g.d)
	# drop shadow
	var sh := pts.duplicate()
	for i in sh.size(): sh[i] += Vector2(0, S * 0.045)
	ci.draw_colored_polygon(sh, Color(0, 0, 0, 0.35))
	grad_poly(ci, pts, Vector2(-R, -R) + off, Vector2(R, R) + off, cl, cc, cd)
	ci.draw_polyline(closed(pts), cd, S * 0.035, true)
	# table and facets
	var raw := shape_pts(shape, R)
	var inner := PackedVector2Array()
	for p in raw: inner.append(p * 0.52 + Vector2(0, -R * 0.04) + off)
	var step := 2 if shape == "round" else 1
	for k in range(0, raw.size(), step):
		ci.draw_line(raw[k] * 0.92 + off, inner[k], Color(1, 1, 1, 0.28), S * 0.018, true)
	var tin := rounded(inner, rd * 0.5)
	grad_poly(ci, tin, Vector2(0, -R * 0.6) + off, Vector2(0, R * 0.5) + off, Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.38), Color(1, 1, 1, 0.08))
	ci.draw_polyline(closed(tin), Color(1, 1, 1, 0.45), S * 0.018, true)
	# glint
	ci.draw_colored_polygon(ellipse_pts(Vector2(-R * 0.38, -R * 0.42) + off, R * 0.2, R * 0.1, -0.6, 14), Color(1, 1, 1, 0.85))

# ---------------------------------------------------------------- specials

static func special(ci: CanvasItem, sp: String, S: float) -> void:
	match sp:
		"rh", "rv": _dynamite(ci, S, PI / 2 if sp == "rv" else 0.0)
		"bomb": _bundle(ci, S)
		"drill": _drill(ci, S)
		"orb": _orb(ci, S)

static func _dynamite(ci: CanvasItem, S: float, rot: float) -> void:
	_xf(ci, Vector2.ZERO, rot, Vector2.ONE)
	var L := S * 0.74; var H := S * 0.26
	ci.draw_colored_polygon(rrect(Vector2(-L / 2, -H / 2 + S * 0.05), Vector2(L, H), H * 0.45), Color(0, 0, 0, 0.35))
	grad_poly(ci, rrect(Vector2(-L / 2, -H / 2), Vector2(L, H), H * 0.45), Vector2(0, -H / 2), Vector2(0, H / 2), Color("#ff8a7a"), Color("#e0302a"), Color("#7a0e0a"))
	ci.draw_rect(Rect2(-L * 0.14, -H / 2, L * 0.28, H), Color("#f4ead2"))
	ci.draw_line(Vector2(-L * 0.06, -H * 0.25), Vector2(L * 0.06, -H * 0.25), Color("#7a0e0a"), S * 0.03)
	ci.draw_line(Vector2(0, -H * 0.25), Vector2(0, H * 0.28), Color("#7a0e0a"), S * 0.03)
	var fuse := PackedVector2Array()
	for k in 9:
		var t := k / 8.0
		var a := Vector2(L / 2 - 2, 0); var c := Vector2(L / 2 + S * 0.08, -S * 0.1); var b := Vector2(L / 2 + S * 0.02, -S * 0.18)
		fuse.append(a.lerp(c, t).lerp(c.lerp(b, t), t))
	ci.draw_polyline(fuse, Color("#3a2a1a"), S * 0.025, true)
	for s in [-1, 1]:
		ci.draw_colored_polygon(PackedVector2Array([Vector2(s * (L / 2 + S * 0.05), 0), Vector2(s * (L / 2 - S * 0.02), -S * 0.06), Vector2(s * (L / 2 - S * 0.02), S * 0.06)]), Color(1, 0.92, 0.63, 0.9))
	ci.draw_set_transform_matrix(base)

static func _bundle(ci: CanvasItem, S: float) -> void:
	var H := S * 0.64; var W := S * 0.25
	ci.draw_colored_polygon(ellipse_pts(Vector2(0, S * 0.3), S * 0.3, S * 0.07), Color(0, 0, 0, 0.35))
	for e in [[-W * 0.95, -0.18], [0.0, 0.0], [W * 0.95, 0.18]]:
		_xf(ci, Vector2(e[0], 0), e[1], Vector2.ONE)
		grad_poly(ci, rrect(Vector2(-W / 2, -H / 2), Vector2(W, H), W * 0.4), Vector2(-W / 2, 0), Vector2(W / 2, 0), Color("#ff8a7a"), Color("#d8281f"), Color("#6a0a08"))
	ci.draw_set_transform_matrix(base)
	ci.draw_rect(Rect2(-S * 0.32, -S * 0.04, S * 0.64, S * 0.09), Color("#c8a46a"))
	ci.draw_rect(Rect2(-S * 0.32, S * 0.02, S * 0.64, S * 0.025), Color("#8a6a3a"))
	var fuse := PackedVector2Array()
	for k in 9:
		var t := k / 8.0
		var a := Vector2(0, -H / 2); var c := Vector2(S * 0.12, -S * 0.38); var b := Vector2(S * 0.06, -S * 0.44)
		fuse.append(a.lerp(c, t).lerp(c.lerp(b, t), t))
	ci.draw_polyline(fuse, Color("#3a2a1a"), S * 0.025, true)

static func _drill(ci: CanvasItem, S: float) -> void:
	_xf(ci, Vector2.ZERO, -0.6, Vector2(1.22, 1.22))
	ci.draw_colored_polygon(ellipse_pts(Vector2(S * 0.02, S * 0.08), S * 0.14, S * 0.36), Color(0, 0, 0, 0.35))
	grad_poly(ci, rrect(Vector2(-S * 0.15, S * 0.02), Vector2(S * 0.3, S * 0.3), S * 0.06), Vector2(-S * 0.14, 0), Vector2(S * 0.14, 0), Color("#ffe680"), Color("#f2b51e"), Color("#94600a"))
	grad_poly(ci, PackedVector2Array([Vector2(-S * 0.12, S * 0.04), Vector2(S * 0.12, S * 0.04), Vector2(0, -S * 0.4)]), Vector2(-S * 0.12, 0), Vector2(S * 0.12, 0), Color("#e8eef4"), Color("#9aa6b4"), Color("#4a5260"))
	for k in 4:
		var y := -S * 0.02 - k * S * 0.09
		var w := S * 0.11 * (1.0 - k * 0.22)
		ci.draw_line(Vector2(-w, y + S * 0.03), Vector2(w, y - S * 0.02), Color(0.12, 0.14, 0.18, 0.7), S * 0.02, true)
	ci.draw_set_transform_matrix(base)

static func _orb(ci: CanvasItem, S: float) -> void:
	radial_disc(ci, Vector2.ZERO, S * 0.5, Color(0.82, 0.59, 1, 0.7), Color(0.82, 0.59, 1, 0.25), Color(0.82, 0.59, 1, 0))
	radial_disc(ci, Vector2(-S * 0.04, -S * 0.05), S * 0.38, Color("#8a7a6a"), Color("#6a5c4e"), Color("#3a3028"))
	radial_disc(ci, Vector2.ZERO, S * 0.28, Color.WHITE, Color("#e2c6ff"), Color("#5a2aa8"), 0.3)
	for k in 10:
		var a := k / 10.0 * TAU
		var r1 := S * 0.27; var r2 := S * 0.1
		ci.draw_colored_polygon(PackedVector2Array([Vector2(cos(a), sin(a)) * r1, Vector2(cos(a + 0.18), sin(a + 0.18)) * r2, Vector2(cos(a - 0.18), sin(a - 0.18)) * r2]), Color(1, 1, 1, 0.35 + (k % 3) * 0.2))

static func nugget(ci: CanvasItem, S: float) -> void:
	ci.draw_colored_polygon(ellipse_pts(Vector2(0, S * 0.3), S * 0.3, S * 0.07), Color(0, 0, 0, 0.35))
	var pts := PackedVector2Array()
	for k in 11:
		var a := k / 11.0 * TAU
		var r := S * (0.3 + sin(k * 2.7) * 0.06 + (k % 3) * 0.02)
		pts.append(Vector2(cos(a) * r * 1.1, sin(a) * r * 0.9))
	pts = rounded(pts, S * 0.06)
	radial_fan(ci, Vector2(-S * 0.1, -S * 0.12), pts, Color("#fff6c0"), Color("#b07a10"))
	ci.draw_polyline(closed(pts), Color("#6a4204"), S * 0.025, true)
	ci.draw_colored_polygon(ellipse_pts(Vector2(-S * 0.1, -S * 0.12), S * 0.07, S * 0.035, -0.5, 12), Color(1, 1, 1, 0.8))

# ---------------------------------------------------------------- blockers (drawn with the cell's top-left at 0,0)

static func rock(ci: CanvasItem, hp: int, S: float, seed_v := 7) -> void:
	var pad := S * 0.06; var w := S - pad * 2
	var body := rrect(Vector2(pad, pad), Vector2(w, w), S * 0.14)
	if hp >= 2:
		grad_poly(ci, body, Vector2(0, pad), Vector2(0, pad + w), Color("#a9b0ba"), Color("#868d97"), Color("#5a616c"))
	else:
		grad_poly(ci, body, Vector2(0, pad), Vector2(0, pad + w), Color("#d6a46a"), Color("#b8844c"), Color("#8a5a2c"))
	ci.draw_polyline(closed(body), Color("#3e444e") if hp >= 2 else Color("#5e3a18"), S * 0.035, true)
	var rng := Rng32.new(hp * 99 + seed_v)
	if hp >= 2:
		for k in 22:
			var c := Color(0.12, 0.13, 0.16, 0.5) if rng.next() < 0.5 else Color(1, 1, 1, 0.35)
			ci.draw_circle(Vector2(pad + rng.next() * w, pad + rng.next() * w), S * (0.012 + rng.next() * 0.02), c)
	else:
		for k in range(1, 4):
			var y := pad + w * k / 4.0 + sin(k) * 3.0
			var line := PackedVector2Array()
			for s in 9:
				var t := s / 8.0
				line.append(Vector2(pad + S * 0.05 + (w - S * 0.1) * t, y + sin(t * PI * 2 + k) * 2.5))
			ci.draw_polyline(line, Color(0.37, 0.23, 0.09, 0.55), S * 0.02, true)
	ci.draw_colored_polygon(rrect(Vector2(pad + S * 0.06, pad + S * 0.05), Vector2(w - S * 0.12, S * 0.1), S * 0.05), Color(1, 1, 1, 0.25))

static func mud(ci: CanvasItem, S: float) -> void:
	var pad := S * 0.03
	grad_poly(ci, rrect(Vector2(pad, pad), Vector2(S - pad * 2, S - pad * 2), S * 0.16), Vector2(0, 0), Vector2(0, S), Color("#5a3c22"), Color("#4c321c"), Color("#3a2614"))
	var rng := Rng32.new(11)
	for k in 7:
		ci.draw_colored_polygon(ellipse_pts(Vector2(rng.next() * S, rng.next() * S), S * (0.06 + rng.next() * 0.08), S * (0.03 + rng.next() * 0.04), rng.next() * 3.0, 12), Color(0.47, 0.34, 0.2, 0.6))

static func gas(ci: CanvasItem, S: float, wobble := 1.0) -> void:
	var o := Vector2(S / 2, S / 2)
	for b in [[-0.18, 0.06, 0.22], [0.16, 0.07, 0.22], [0.0, -0.12, 0.24], [-0.05, 0.17, 0.2], [0.2, -0.12, 0.15], [-0.22, -0.12, 0.14]]:
		var c: Vector2 = o + Vector2(b[0], b[1]) * S
		var r: float = b[2] * S * wobble
		radial_disc(ci, c, r, Color("#efffb0"), Color("#a2dc3c"), Color("#4a7a1a"), 0.55, 18)
	ci.draw_circle(o + Vector2(-S * 0.1, -S * 0.16), S * 0.045, Color(1, 1, 1, 0.65))
	ci.draw_circle(o + Vector2(S * 0.14, S * 0.02), S * 0.03, Color(1, 1, 1, 0.65))

static func lock(ci: CanvasItem, S: float) -> void:
	var p := S * 0.1; var w := S - p * 2
	ci.draw_rect(Rect2(p, p, w, w), Color("#3a2410"), false, S * 0.14)
	ci.draw_rect(Rect2(p, p, w, w), Color("#b07a3e"), false, S * 0.09)
	ci.draw_line(Vector2(p + S * 0.04, p + S * 0.04), Vector2(S - p - S * 0.04, S - p - S * 0.04), Color("#8a5a2c"), S * 0.08)
	for q in [Vector2(p, p), Vector2(S - p, p), Vector2(p, S - p), Vector2(S - p, S - p)]:
		ci.draw_circle(q, S * 0.045, Color("#d8dce4"))

## the find in the goal bar: a crystal glinting out of a lump of rock, glow in its rarity colour
static func find_icon(ci: CanvasItem, S: float, glow: Color) -> void:
	radial_disc(ci, Vector2(S / 2, S / 2), S * 0.5, Color(glow, 0.55), Color(glow, 0.25), Color(glow, 0.0))
	ci.draw_colored_polygon(ellipse_pts(Vector2(S / 2, S * 0.66), S * 0.36, S * 0.2), Color("#6a5e52"))
	var crystal := PackedVector2Array([Vector2(S * 0.5, S * 0.14), Vector2(S * 0.64, S * 0.34), Vector2(S * 0.6, S * 0.66), Vector2(S * 0.4, S * 0.66), Vector2(S * 0.36, S * 0.34)])
	ci.draw_colored_polygon(crystal, Color("#e8f0ff"))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(S * 0.5, S * 0.14), Vector2(S * 0.64, S * 0.34), Vector2(S * 0.6, S * 0.66), Vector2(S * 0.5, S * 0.66)]), Color(glow, 0.55))
	ci.draw_colored_polygon(ellipse_pts(Vector2(S / 2, S * 0.72), S * 0.38, S * 0.14), Color("#4e443a"))

static func geode_icon(ci: CanvasItem, S: float) -> void:
	ci.draw_texture_rect(NODULE, Rect2(S * 0.06, S * 0.06, S * 0.88, S * 0.88), false)

## any goal's icon, top-left at 0,0
static func goal_icon(ci: CanvasItem, k: String, colour: int, S: float, glow := Color("#c8b0ff")) -> void:
	match k:
		"find": find_icon(ci, S, glow)
		"c": BoardSprites.draw(ci, BoardSprites.gem(colour), Vector2(S / 2, S / 2), S * 0.9)
		"rock": BoardSprites.draw(ci, BoardSprites.tex("rock1"), Vector2(S / 2, S / 2), S * 0.9)
		"mud": BoardSprites.draw(ci, BoardSprites.tex("mud"), Vector2(S / 2, S / 2), S * 0.9)
		"gas": gas(ci, S)
		"lock":
			BoardSprites.draw(ci, BoardSprites.gem(2), Vector2(S / 2, S / 2), S * 0.9)
			BoardSprites.draw(ci, BoardSprites.tex("lock"), Vector2(S / 2, S / 2), S * 0.9)
		"geo": geode_icon(ci, S)
		_: BoardSprites.draw(ci, BoardSprites.tex("nug"), Vector2(S / 2, S / 2), S * 0.9)
