class_name MineScene
extends Node2D
## The mine in cross-section, the home screen's backdrop: night sky, ridges with pines, the adit
## and whatever the player has built at it, then the depth horizons with their galleries and the shaft.
## Drawn in a 360-unit-wide space (like the prototype's SVG) and scaled to the screen.
## Static art is drawn once; a child node redraws the moving parts every frame
## (stars, crows, lantern glow, twinkling stones, the cart, the winding wheel, eyes in the dark).

signal band_tapped(k: int)

const W := 360.0
const G0 := 200.0
const B0 := 212.0

var ai := 0
var built: Array = []
var d_open := 0
var d_sel := 0
var Hv := 780.0
var OFF := 0.0
var BH := 50.0
var H := 780.0
var cu := false
var fire := false
var pal := {}
var sp_cols: Array = []
var live: Node2D
var t := 0.0

var _stars := []
var _crows := []
var _pines := []
var _band_gems := []
var _eyes := []
var _embers := []
var _rubble := []
var _specks := []

static func hx(s: String) -> Color:
	return Color(s)

func setup(area: int, built_list: Array, dopen: int, dsel: int, hv: float) -> void:
	ai = area
	built = built_list
	d_open = dopen
	d_sel = dsel
	Hv = hv
	cu = ai == 1
	fire = ai == 2
	OFF = roundf(clampf(Hv * 0.4 - 196.0, 0.0, 120.0))
	BH = roundf(clampf((Hv - 222.0 - B0 - OFF) / 5.0, 40.0, 62.0))
	H = Hv - OFF
	if fire:
		pal = {sky = ["#3a120c", "#160806"], far = "#3a1d18", mid = "#2a1512", near = ["#3a2420", "#1c100e"], soil = "#2a1814", rock = ["#3a2420", "#24120e"], tree = "#000000"}
	elif cu:
		pal = {sky = ["#0f2a33", "#0b1820"], far = "#2a4a52", mid = "#1c3a34", near = ["#2f5a46", "#173126"], soil = "#24402f", rock = ["#2c3a34", "#141c1a"], tree = "#0f241c"}
	else:
		pal = {sky = ["#1d2a46", "#0e1626"], far = "#3a4660", mid = "#2a2a34", near = ["#5a4a3e", "#2c241e"], soil = "#3a2e24", rock = ["#4a3c32", "#1c1612"], tree = "#151c22"}
	var pool: Dictionary = Data.AREAS[ai].pool
	var ids := pool.keys()
	ids.sort_custom(func(a, b): return float(pool[a]) > float(pool[b]))
	sp_cols = []
	for id in ids.slice(0, 6):
		sp_cols.append(Data.sp_color(id))
	var rng := Rng32.new(ai * 977 + 31)
	_pines = []
	if not fire:
		for k in 34:
			var x := rng.next() * W
			var y := ridge(x, 128, 14, 7, 2.2) + 4 + rng.next() * 10
			_pines.append([x, y, 9 + rng.next() * 9])
	_stars = []
	for k in 40:
		_stars.append([rng.next() * W, -OFF + rng.next() * (90 + OFF), 1.3 if rng.next() < 0.2 else 0.7, k % 3 == 0, 2 + rng.next() * 3, rng.next() * 3])
	_crows = []
	for k in 2:
		_crows.append([64 + rng.next() * 40, 38 + rng.next() * 20, k * 17.0])
	_embers = []
	if fire:
		for k in 14:
			_embers.append([rng.next() * W, 0.6 + rng.next(), rng.next() * 60, 5 + rng.next() * 6, rng.next() * 6])
	_band_gems = []
	_specks = []
	_eyes = []
	for k in Data.DEPTHS.size():
		var y := B0 + k * BH
		var sp := []
		for q in 22:
			sp.append([rng.next() * W, y + 4 + rng.next() * (BH - 8), 0.6 + rng.next() * 1.6])
		_specks.append(sp)
		var gems := []
		for q in 7:
			gems.append([20 + rng.next() * 320, y + 6 + rng.next() * (BH - 12), sp_cols[int(rng.next() * sp_cols.size())], 2.4 + rng.next() * 2.4, deg_to_rad(rng.next() * 60 - 30), 2.4 + rng.next() * 3, rng.next() * 4])
		_band_gems.append(gems)
		if k == Data.DEPTHS.size() - 1:
			var gy := y + BH / 2
			for q in 2:
				_eyes.append([70 + q * 170 + rng.next() * 40, gy + (rng.next() - 0.5) * 20, 7 + rng.next() * 6, q * 3.1])
	var r2 := Rng32.new(ai * 41 + 7)
	_rubble = []
	for st in [[128, 196, 7], [192, 196, 6.5], [139, 191, 12], [180, 192, 11], [159, 190, 14], [149, 177, 10], [171, 176, 10], [160, 164, 8.5], [166, 197, 5]]:
		_rubble.append(_stone_pts(st[0], st[1], st[2], r2))
	if not live:
		live = Node2D.new()
		add_child(live)
		live.draw.connect(_draw_live)
	queue_redraw()

func has(id: String) -> bool:
	return id in built

func ridge(x: float, base: float, a1: float, a2: float, ph: float) -> float:
	return base + sin(x * 0.021 + ph) * a1 + sin(x * 0.057 + ph * 2) * a2

func _process(dt: float) -> void:
	t += dt
	if live: live.queue_redraw()

## which horizon a point (in this node's space) falls on, or -1
func band_at(p: Vector2) -> int:
	var y := p.y - OFF
	if y < B0: return -1
	var k := int(floor((y - B0) / BH))
	return k if k < Data.DEPTHS.size() else -1

# ---------------------------------------------------------------- helpers

static func qbez(p0: Vector2, c: Vector2, p1: Vector2, n := 10) -> PackedVector2Array:
	var o := PackedVector2Array()
	for i in n + 1:
		var s := i / float(n)
		o.append(p0.lerp(c, s).lerp(c.lerp(p1, s), s))
	return o

func _vgrad(pts: PackedVector2Array, y0: float, y1: float, c0: Color, c1: Color) -> void:
	var cols := PackedColorArray()
	for p in pts:
		cols.append(c0.lerp(c1, clampf((p.y - y0) / maxf(0.001, y1 - y0), 0.0, 1.0)))
	draw_polygon(pts, cols)

func _rect_grad(r: Rect2, c0: Color, c1: Color) -> void:
	_vgrad(PackedVector2Array([r.position, r.position + Vector2(r.size.x, 0), r.end, r.position + Vector2(0, r.size.y)]), r.position.y, r.end.y, c0, c1)

func _stone_pts(cx: float, cy: float, r: float, rng: Rng32) -> Array:
	var pts := PackedVector2Array()
	for k in 7:
		var a := k / 7.0 * 6.283 + rng.next() * 0.5
		var rr := r * (0.78 + rng.next() * 0.32)
		pts.append(Vector2(cx + cos(a) * rr, cy + sin(a) * rr * 0.8))
	return [pts, cx, cy, r]

func _stone(ci: CanvasItem, s: Array, fill: Color, dark: Color, light: Color) -> void:
	var pts: PackedVector2Array = s[0]
	var cx: float = s[1]
	var cy: float = s[2]
	var r: float = s[3]
	ci.draw_colored_polygon(pts, fill)
	ci.draw_polyline(GemArt.closed(pts), dark, 1.1, true)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(cx - r * 0.55, cy - r * 0.1), Vector2(cx - r * 0.15, cy - r * 0.6), Vector2(cx + r * 0.45, cy - r * 0.42), Vector2(cx + r * 0.08, cy - r * 0.02)]), Color(light, 0.5))
	ci.draw_line(Vector2(cx + r * 0.08, cy - r * 0.02), Vector2(cx + r * 0.5, cy + r * 0.38), Color(dark, 0.55), 0.8, true)

## a dashed stroke along a polyline: stone blocks of an arch, tunnel outlines
func _dashed(ci: CanvasItem, pts: PackedVector2Array, dash: float, gap: float, col: Color, w: float, offset := 0.0) -> void:
	var pos := -fposmod(offset, dash + gap)
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var L := a.distance_to(b)
		var s := 0.0
		while s < L:
			var cyc := fposmod(pos + s, dash + gap)
			var on := cyc < dash
			var step := minf((dash - cyc) if on else (dash + gap - cyc), L - s)
			if on:
				ci.draw_line(a.lerp(b, s / L), a.lerp(b, (s + step) / L), col, w)
			s += maxf(step, 0.01)
		pos += L

static func lantern(ci: CanvasItem, p: Vector2, s: float, glow: float) -> void:
	if glow > 0.0:
		GemArt.radial_disc(ci, p + Vector2(0, 9 * s), 24 * s, Color(1, 0.82, 0.48, 0.55 * glow), Color(1, 0.82, 0.48, 0.18 * glow), Color(1, 0.82, 0.48, 0))
	var q := func(v: Vector2) -> Vector2: return p + v * s
	ci.draw_polyline(qbez(q.call(Vector2(-2.6, 2)), q.call(Vector2(0, -3.2)), q.call(Vector2(2.6, 2)), 6), Color("#1e1a16"), 1.2 * s, true)
	ci.draw_colored_polygon(PackedVector2Array([q.call(Vector2(-4.5, 2)), q.call(Vector2(4.5, 2)), q.call(Vector2(5.6, 5)), q.call(Vector2(-5.6, 5))]), Color("#2e2822"))
	# the pane glows past white so the glow pass blooms it
	ci.draw_colored_polygon(GemArt.rrect(q.call(Vector2(-4.6, 5)), Vector2(9.2, 11) * s, 1.6 * s), Color(1.5, 1.25, 0.8))
	ci.draw_colored_polygon(GemArt.ellipse_pts(q.call(Vector2(0, 11)), 1.9 * s, 3.1 * s, 0, 12), Color(2.2, 2.0, 1.6))
	for x in [-4.6, 0.0, 4.6]:
		ci.draw_line(q.call(Vector2(x, 5)), q.call(Vector2(x, 16)), Color("#2e2822"), 0.8 * s)
	ci.draw_colored_polygon(GemArt.rrect(q.call(Vector2(-5.6, 15.6)), Vector2(11.2, 2.6) * s, 1.0 * s), Color("#2e2822"))

static func cart(ci: CanvasItem, p: Vector2, s: float, cols: Array) -> void:
	var q := func(v: Vector2) -> Vector2: return p + v * s
	var gem := func(gx: float, gy: float, r: float, c: Color) -> void:
		var pts := PackedVector2Array([q.call(Vector2(gx, gy - r)), q.call(Vector2(gx + r * 0.9, gy - r * 0.2)), q.call(Vector2(gx + r * 0.55, gy + r * 0.8)), q.call(Vector2(gx - r * 0.55, gy + r * 0.8)), q.call(Vector2(gx - r * 0.9, gy - r * 0.2))])
		ci.draw_colored_polygon(pts, c)
		ci.draw_polyline(GemArt.closed(pts), Color("#1a1a1a"), 0.6 * s, true)
		ci.draw_colored_polygon(PackedVector2Array([pts[0], pts[1], q.call(Vector2(gx, gy))]), Color(1, 1, 1, 0.45))
	var n := cols.size()
	gem.call(-10, -19, 5.5, cols[0])
	gem.call(0, -21, 6.5, cols[1 % n])
	gem.call(10, -19, 5.5, cols[2 % n])
	gem.call(-5, -16, 4.5, cols[3 % n])
	gem.call(6, -15.5, 4.5, cols[4 % n])
	var body := PackedVector2Array([q.call(Vector2(-22, -16)), q.call(Vector2(22, -16)), q.call(Vector2(18, 2)), q.call(Vector2(-18, 2))])
	var cc := PackedColorArray()
	for v in body: cc.append(Color("#7a828c").lerp(Color("#3a3f46"), clampf((v.y - body[0].y) / (18 * s), 0, 1)))
	ci.draw_polygon(body, cc)
	ci.draw_polyline(GemArt.closed(body), Color("#1c1f24"), 1.2 * s, true)
	ci.draw_colored_polygon(GemArt.rrect(q.call(Vector2(-23.5, -18)), Vector2(47, 3.4) * s, 1.2 * s), Color("#8a929c"))
	for x in [-7.0, 7.0]:
		ci.draw_line(q.call(Vector2(x, -14.6)), q.call(Vector2(x * 6 / 7, 1.6)), Color("#2a2e34"), 1.0 * s)
	for rx in [-17.0, -9.5, -2.0, 5.5, 13.0]:
		ci.draw_circle(q.call(Vector2(rx + 2, -11.5)), 0.9 * s, Color("#c8d0d8"))
	ci.draw_rect(Rect2(q.call(Vector2(-17, 1)), Vector2(34, 2.4) * s), Color("#22262c"))
	for wx in [-11.0, 11.0]:
		var c: Vector2 = q.call(Vector2(wx, 5.5))
		ci.draw_circle(c, 5.4 * s, Color("#22262c"))
		ci.draw_arc(c, 5.4 * s, 0, TAU, 20, Color("#0e1012"), 1.0 * s, true)
		ci.draw_arc(c, 3.6 * s, 0, TAU, 18, Color("#5a626c"), 0.9 * s, true)
		ci.draw_circle(c, 1.2 * s, Color("#9aa4ae"))

func _post(x: float, y0: float, y1: float) -> void:
	draw_rect(Rect2(x - 1.8, y0, 3.6, y1 - y0), Color("#7a4e26"))
	draw_rect(Rect2(x - 6, y0 - 3, 12, 3.6), Color("#8e5c2c"))
	draw_line(Vector2(x - 1.8, y0 + 5), Vector2(x - 6, y0 + 0.6), Color("#6a4220"), 1.6)
	draw_line(Vector2(x + 1.8, y0 + 5), Vector2(x + 6, y0 + 0.6), Color("#6a4220"), 1.6)

# ---------------------------------------------------------------- the picture

func _draw() -> void:
	draw_set_transform(Vector2(0, OFF))
	var sky0 := hx(pal.sky[0])
	var sky1 := hx(pal.sky[1])
	_rect_grad(Rect2(0, -OFF, W, G0 + 10 + OFF), sky0, sky1)
	if fire:
		var ridge_pts := _ridge_poly(150, 6, 4, 0.4)
		draw_colored_polygon(ridge_pts, hx(pal.far))
		draw_colored_polygon(PackedVector2Array([Vector2(118, 156), Vector2(168, 52), Vector2(192, 52), Vector2(246, 156)]), hx("#2a1410"))
		draw_colored_polygon(GemArt.ellipse_pts(Vector2(180, 52), 14, 4), Color(1.6, 0.7, 0.2))
		draw_polyline(PackedVector2Array([Vector2(176, 56), Vector2(170, 80), Vector2(182, 112), Vector2(188, 134), Vector2(178, 156)]), Color(1.5, 0.5, 0.12, 0.9), 3.5, true)
		draw_polyline(PackedVector2Array([Vector2(188, 58), Vector2(198, 84), Vector2(194, 108)]), Color(1.6, 0.85, 0.3, 0.8), 2.0, true)
	else:
		GemArt.radial_disc(self, Vector2(292, 48), 38, Color(1, 0.96, 0.85, 0.35), Color(1, 0.96, 0.85, 0.12), Color(1, 0.96, 0.85, 0))
		draw_circle(Vector2(292, 48), 13, Color(1.15, 1.1, 1.0))
		draw_circle(Vector2(287, 44), 3, Color("#d8cfb8", 0.6))
		draw_circle(Vector2(296, 52), 2, Color("#d8cfb8", 0.5))
		draw_colored_polygon(_ridge_poly(108, 22, 10, 0.9), hx(pal.far))
		var x := 0.0
		while x <= W:
			var y := ridge(x, 108, 22, 10, 0.9)
			if y < 96:
				draw_colored_polygon(PackedVector2Array([Vector2(x - 7, y + 7), Vector2(x, y), Vector2(x + 7, y + 7)]), Color("#dfe6f0", 0.55))
			x += 12
	draw_colored_polygon(_ridge_poly(128, 14, 7, 2.2), hx(pal.mid))
	for p in _pines:
		var px: float = p[0]
		var py: float = p[1]
		var h: float = p[2]
		var w := h * 0.36
		draw_colored_polygon(PackedVector2Array([Vector2(px, py - h), Vector2(px + w, py - h * 0.35), Vector2(px + w * 0.55, py - h * 0.38), Vector2(px + w * 1.25, py),
			Vector2(px - w * 1.25, py), Vector2(px - w * 0.55, py - h * 0.38), Vector2(px - w, py - h * 0.35)]), hx(pal.tree))
	_rect_grad(Rect2(0, 120, W, G0 - 116), Color(sky1, 0), Color(sky0, 0.7))
	# the near hill the adit is cut into
	var hill := PackedVector2Array([Vector2(28, G0 + 2)])
	hill.append_array(qbez(Vector2(28, G0 + 2), Vector2(60, 160), Vector2(104, 124)))
	hill.append(Vector2(140, 96))
	hill.append_array(qbez(Vector2(140, 96), Vector2(172, 78), Vector2(208, 100)))
	hill.append(Vector2(246, 128))
	hill.append_array(qbez(Vector2(246, 128), Vector2(272, 150), Vector2(286, G0 + 2)))
	_vgrad(hill, 80, G0, hx(pal.near[0]), hx(pal.near[1]))
	var crest := PackedVector2Array([Vector2(104, 124), Vector2(140, 96)])
	crest.append_array(qbez(Vector2(140, 96), Vector2(172, 78), Vector2(208, 100)))
	draw_polyline(crest, Color(1, 1, 1, 0.08), 2.0, true)
	draw_rect(Rect2(0, G0, W, B0 - G0 + 2), hx(pal.soil))
	var grass := PackedVector2Array([Vector2(0, G0)])
	for q in 19: grass.append(Vector2(q * 20, G0 - 1 - (q % 3)))
	grass.append(Vector2(W, G0))
	draw_polyline(grass, hx("#4a2a1a" if fire else "#3f7a4a" if cu else "#5a6a3a"), 3.0, true)
	# the adit: a dark mouth under an arch of stone blocks
	var mouth := PackedVector2Array([Vector2(130, G0), Vector2(130, 146)])
	mouth.append_array(qbez(Vector2(130, 146), Vector2(160, 112), Vector2(190, 146)))
	mouth.append(Vector2(190, G0))
	_vgrad(mouth, 120, G0, Color("#1a1410"), Color("#000000"))
	var arch := PackedVector2Array([Vector2(128, G0), Vector2(128, 145)])
	arch.append_array(qbez(Vector2(128, 145), Vector2(160, 108), Vector2(192, 145), 14))
	arch.append(Vector2(192, G0))
	draw_polyline(arch, hx("#2a1a14" if fire else "#3e3832"), 11.0)
	_dashed(self, arch, 9, 1.8, hx("#5a3a2a" if fire else "#7a7064"), 8.5)
	if not has("rubble"):
		var f := hx("#4a2a1e" if fire else "#5e6a5e" if cu else "#857766")
		var dk := hx("#1a0c08" if fire else "#2a241e")
		var lt := hx("#ff8a4a" if fire else "#d8ccb8")
		for st in _rubble: _stone(self, st, f, dk, lt)
	if has("timber"): _timber()
	if has("rails"): _rails()
	if has("lamps"):
		draw_polyline(PackedVector2Array([Vector2(121, 137), Vector2(108, 137), Vector2(108, 141)]), hx("#2e2822"), 2.0)
		draw_polyline(PackedVector2Array([Vector2(199, 137), Vector2(212, 137), Vector2(212, 141)]), hx("#2e2822"), 2.0)
	if has("cart"): cart(self, Vector2(240, G0 - 7), 0.95, sp_cols)
	if has("headframe"): _headframe()
	if cu:
		var r3 := Rng32.new(77)
		for st in [[58, 196, 6], [76, 197, 4.5], [330, 196, 5.5]]:
			_stone(self, _stone_pts(st[0], st[1], st[2], r3), hx("#4a6a5a"), hx("#1a2a22"), hx("#7adfb0"))
	# deep rock below the horizons
	var deep_y := B0 + BH * 5 - 2
	draw_rect(Rect2(0, deep_y, W, H - deep_y + 2), hx(pal.rock[1]).lerp(Color.BLACK, 0.45))
	_bands()
	_shaft()
	draw_set_transform(Vector2.ZERO)
	_rect_grad(Rect2(0, 0, W, 120), Color("#05080e", 0.55), Color("#05080e", 0))
	_rect_grad(Rect2(0, Hv - 250, W, 250), Color("#0b0f17", 0), Color("#0b0f17", 0.95))

func _ridge_poly(base: float, a1: float, a2: float, ph: float) -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2(0, G0 + 4)])
	var x := 0.0
	while x <= W:
		pts.append(Vector2(x, ridge(x, base, a1, a2, ph)))
		x += 12
	pts.append(Vector2(W, G0 + 4))
	return pts

func _timber() -> void:
	var wood := hx("#8a5a2c")
	var edge := hx("#3a2410")
	for r in [Rect2(121, 134, 12, 68), Rect2(187, 134, 12, 68), Rect2(113, 124, 94, 12)]:
		draw_colored_polygon(GemArt.rrect(r.position, r.size, 1.5), wood)
		draw_polyline(GemArt.closed(GemArt.rrect(r.position, r.size, 1.5)), edge, 1.2, true)
	for ln in [[Vector2(124, 140), Vector2(124, 198)], [Vector2(129, 138), Vector2(129, 199)], [Vector2(191, 140), Vector2(191, 198)], [Vector2(196, 139), Vector2(196, 199)], [Vector2(118, 128), Vector2(202, 129)], [Vector2(120, 132), Vector2(200, 131)]]:
		draw_line(ln[0], ln[1], Color("#5a3818", 0.8), 0.8)
	draw_line(Vector2(133, 148), Vector2(145, 136), hx("#7a4e26"), 4.0)
	draw_line(Vector2(187, 148), Vector2(175, 136), hx("#7a4e26"), 4.0)
	for r in [Rect2(119.5, 150, 15, 4), Rect2(185.5, 150, 15, 4), Rect2(121, 126, 9, 8), Rect2(190, 126, 9, 8)]:
		draw_rect(r, hx("#3a3e44"))
	for p in [Vector2(123, 152), Vector2(131, 152), Vector2(189, 152), Vector2(197, 152), Vector2(125.5, 130), Vector2(194.5, 130)]:
		draw_circle(p, 0.9, hx("#9aa4ae"))
	for x in [113.0, 207.0]:
		draw_circle(Vector2(x, 130), 5.5, hx("#6a4220"))
		draw_arc(Vector2(x, 130), 5.5, 0, TAU, 16, edge, 1.0, true)
		draw_arc(Vector2(x, 130), 2.5, 0, TAU, 12, edge, 0.6, true)

func _rails() -> void:
	for q in 19:
		draw_rect(Rect2(142 + q * 8, G0 - 4.5, 4.5, 8), hx("#4a3018"))
	draw_line(Vector2(140, G0 - 3), Vector2(292, G0 - 3), hx("#3a3e44"), 2.4)
	draw_line(Vector2(140, G0 - 3.6), Vector2(292, G0 - 3.6), hx("#b8c2cc"), 0.9)
	draw_line(Vector2(138, G0 + 2), Vector2(292, G0 + 2), hx("#3a3e44"), 2.4)
	draw_line(Vector2(138, G0 + 1.4), Vector2(292, G0 + 1.4), hx("#b8c2cc"), 0.9)
	draw_rect(Rect2(286, G0 - 8, 5, 12), hx("#c8341e"))

func _headframe() -> void:
	var st := hx("#b86a34" if cu else "#b8502a" if fire else "#a8947a")
	var dk := hx("#2a2018")
	for pair in [[Vector2(286, G0), Vector2(301, 98)], [Vector2(322, G0), Vector2(307, 98)]]:
		draw_line(pair[0], pair[1], dk, 5.0)
		draw_line(pair[0], pair[1], st, 3.4)
	for ab in [[198.0, 168.0], [168.0, 140.0], [140.0, 116.0]]:
		var a: float = ab[0]
		var b: float = ab[1]
		var xa := 286 + (a - G0) / (98 - G0) * 15
		var xb := 286 + (b - G0) / (98 - G0) * 15
		draw_line(Vector2(xa, a), Vector2(608 - xb, b), Color(st, 0.95), 1.4)
		draw_line(Vector2(608 - xa, a), Vector2(xb, b), Color(st, 0.95), 1.4)
		draw_line(Vector2(xb, b), Vector2(608 - xb, b), Color(st, 0.95), 1.4)
	draw_rect(Rect2(297, 96, 14, 5), dk)
	draw_line(Vector2(314, 92), Vector2(336, 176), hx("#1a1a1a"), 0.9)
	var house := PackedVector2Array([Vector2(326, G0), Vector2(326, 178), Vector2(340, 168), Vector2(354, 178), Vector2(354, G0)])
	draw_colored_polygon(house, hx("#3a2420" if fire else "#4a3a2c"))
	draw_polyline(GemArt.closed(house), hx("#1e1610"), 1.0)
	draw_polyline(PackedVector2Array([Vector2(324, 179), Vector2(340, 166), Vector2(356, 179)]), hx("#2a1e14"), 2.6, true)
	draw_rect(Rect2(333, 184, 7, 6), Color(1.4, 1.1, 0.6, 0.9))
	draw_line(Vector2(336.5, 184), Vector2(336.5, 190), hx("#2a1e14"), 0.7)
	draw_line(Vector2(333, 187), Vector2(340, 187), hx("#2a1e14"), 0.7)

func _band_rock(k: int) -> Color:
	var tt := k / float(Data.DEPTHS.size() - 1)
	return hx(pal.rock[0]).lerp(hx("#3a0c06" if fire else pal.rock[1]), tt * 0.75)

func _bands() -> void:
	var font: Font = UI.body_bold
	for k in Data.DEPTHS.size():
		var D: Dictionary = Data.DEPTHS[k]
		var y := B0 + k * BH
		var open := k <= d_open
		var nxt := k == d_open + 1
		var tt := k / float(Data.DEPTHS.size() - 1)
		var top := PackedVector2Array()
		if k:
			for q in 13: top.append(Vector2(q * 30, y + sin(q * 1.7 + k * 2.3) * 3))
		else:
			top.append(Vector2(0, y))
		top.append(Vector2(W, y))
		top.append(Vector2(W, y + BH + 4))
		top.append(Vector2(0, y + BH + 4))
		draw_colored_polygon(top, _band_rock(k))
		for s in _specks[k]:
			draw_circle(Vector2(s[0], s[1]), s[2], Color(0, 0, 0, 0.25))
		if not open:
			draw_rect(Rect2(0, y, W, BH), Color(0, 0, 0, 0.25 + tt * 0.3))
		var gy := y + BH / 2
		var gx0 := 46.0
		var gx1 := 296.0
		if open:
			_vgrad(GemArt.rrect(Vector2(gx0, gy - 15), Vector2(gx1 - gx0, 30), 12), gy - 15, gy + 15, hx("#1a120c"), hx("#3a2a1a"))
			for q in 6: _post(gx0 + 14 + q * 44, gy - 12, gy + 14)
			draw_line(Vector2(gx0 + 6, gy + 13), Vector2(gx1, gy + 13), hx("#8a96a4"), 1.2)
		else:
			_dashed(self, GemArt.closed(GemArt.rrect(Vector2(gx0, gy - 15), Vector2(gx1 - gx0, 30), 12)), 4, 5, Color(1, 1, 1, 0.12), 1.0)
			var lbl: String = ("%s · %s" % [D.tool, UI.fmt(Data.depth_cost(ai, k))]) if nxt else String(D.tool)
			var fs := 10
			var tw := font.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 30
			var cx := (gx0 + gx1) / 2
			var pill := GemArt.rrect(Vector2(cx - tw / 2, gy - 11), Vector2(tw, 22), 11)
			draw_colored_polygon(pill, hx("#3a2a0e" if nxt else "#0c1018"))
			draw_polyline(GemArt.closed(pill), hx("#e3a51e" if nxt else "#2a3442"), 1.0, true)
			_lock_icon(Vector2(cx - tw / 2 + 13, gy), hx("#ffd27a" if nxt else "#8d97a6"))
			draw_string(font, Vector2(cx - tw / 2 + 22, gy + 3.5), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, hx("#ffd27a" if nxt else "#8d97a6"))
		draw_string(font, Vector2(10, y + 15), "%d m" % int(D.m), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, hx("#ffd27a" if open else "#6a7484"))

func _lock_icon(c: Vector2, col: Color) -> void:
	draw_rect(Rect2(c + Vector2(-3.5, -1), Vector2(7, 5.5)), col)
	draw_arc(c + Vector2(0, -1.5), 2.4, PI, TAU, 10, col, 1.3, true)

func _shaft() -> void:
	var bot := B0 + d_open * BH + BH / 2 + 12
	var r := Rect2(295, G0 - 4, 18, bot - G0 + 4)
	draw_polygon(PackedVector2Array([r.position, r.position + Vector2(r.size.x, 0), r.end, r.position + Vector2(0, r.size.y)]),
		PackedColorArray([hx("#050403"), hx("#050403"), hx("#050403"), hx("#050403")]))
	draw_rect(Rect2(298, G0 - 4, 12, bot - G0 + 4), hx("#14100c"))
	draw_rect(Rect2(293, G0 - 4, 3, bot - G0 + 4), hx("#6a4220"))
	draw_rect(Rect2(312, G0 - 4, 3, bot - G0 + 4), hx("#6a4220"))
	for q in int((bot - G0) / 10):
		draw_line(Vector2(293, G0 + q * 10), Vector2(296, G0 + q * 10), hx("#3a2410"), 0.6)
		draw_line(Vector2(312, G0 + 5 + q * 10), Vector2(315, G0 + 5 + q * 10), hx("#3a2410"), 0.6)
	draw_line(Vector2(298, G0 - 2), Vector2(298, bot), hx("#8a5a2c"), 1.4)
	draw_line(Vector2(304, G0 - 2), Vector2(304, bot), hx("#8a5a2c"), 1.4)
	for q in int((bot - G0) / 7):
		draw_line(Vector2(298, G0 + 3 + q * 7), Vector2(304, G0 + 3 + q * 7), hx("#a06a34"), 1.2)
	_dashed(self, GemArt.closed(PackedVector2Array([Vector2(293, bot), Vector2(315, bot), Vector2(315, H), Vector2(293, H)])), 3, 4, Color(1, 1, 1, 0.08), 1.0)

# ---------------------------------------------------------------- moving parts

func _draw_live() -> void:
	var ci := live
	ci.draw_set_transform(Vector2(0, OFF))
	for s in _stars:
		var a := 0.6
		if s[3]: a *= 0.6 + 0.4 * cos((t + s[5]) / s[4] * TAU)
		ci.draw_circle(Vector2(s[0], s[1]), s[2], Color(1, 1, 1, a))
	if cu:
		var a1 := 0.1 + 0.18 * (0.5 + 0.5 * sin(t * TAU / 7.0))
		var a2 := 0.06 + 0.14 * (0.5 + 0.5 * cos(t * TAU / 9.0))
		var p1 := PackedVector2Array()
		var p2 := PackedVector2Array()
		for i in 25:
			var x := -10 + i * 16.0
			p1.append(Vector2(x, 62 + sin(x * 0.02 + t * 0.2) * 14))
			p2.append(Vector2(x, 82 + sin(x * 0.016 + 1.3 + t * 0.15) * 10))
		for w in [22.0, 14.0, 7.0]:
			ci.draw_polyline(p1, Color(0.25, 0.9, 0.65, a1 * 7.0 / w * 0.5), w, true)
			ci.draw_polyline(p2, Color(0.37, 0.75, 1.0, a2 * 7.0 / w * 0.5), w * 0.7, true)
	if fire:
		var pulse := 0.45 + 0.25 * (0.5 + 0.5 * sin(t * TAU / 3.0))
		GemArt.radial_disc(ci, Vector2(180, 44), 46, Color(1.4, 0.9, 0.4, pulse * 0.7), Color(1, 0.6, 0.2, pulse * 0.25), Color(1, 0.5, 0.2, 0))
		for k in 3:
			var dur := 6.0 + k * 2
			var ph := fposmod(t - k * 2.0, dur) / dur
			ci.draw_circle(Vector2(178 + k * 6, lerpf(40, -10 - k * 8, ph)), 10 + k * 4 + ph * 8, Color(0.42, 0.35, 0.35, 0.5 * (1.0 - ph)))
		for e in _embers:
			var ph: float = fposmod(t - e[4], e[3]) / e[3]
			ci.draw_circle(Vector2(e[0], lerpf(e[2], 210, ph)), e[1], Color(1.6, 0.8, 0.3, sin(ph * PI)))
		var lava := 0.12 + 0.12 * (0.5 + 0.5 * sin(t * TAU / 5.0))
		ci.draw_rect(Rect2(0, H - 70, W, 70), Color(1, 0.35, 0.1, lava))
	for c in _crows:
		var dur: float = c[1]
		var ph := fposmod(t + c[2], dur) / dur
		var p := Vector2(lerpf(-30, W + 30, ph), lerpf(c[0], c[0] - 20, ph))
		var flap := sin(t * 9.0 + c[2])
		ci.draw_polyline(qbez(p + Vector2(-5, 0), p + Vector2(-2.5, -3 * flap), p, 4), Color("#0a0c10"), 1.4, true)
		ci.draw_polyline(qbez(p, p + Vector2(2.5, -3 * flap), p + Vector2(5, 0), 4), Color("#0a0c10"), 1.4, true)
	if has("lamps"):
		for i in 2:
			lantern(ci, Vector2(108 if i == 0 else 212, 140), 0.95, 0.75 + 0.2 * sin(t * 3.1 + i))
	if has("headframe"):
		_wheel(ci)
	for k in Data.DEPTHS.size():
		var y := B0 + k * BH
		var gy := y + BH / 2
		if k <= d_open:
			for g in _band_gems[k]:
				var ph := 0.5 - 0.5 * cos((t + g[6]) / g[5] * TAU)
				var c: Color = g[2]
				var r: float = g[3]
				var gp := Vector2(g[0], g[1])
				if ph > 0.05:
					GemArt.radial_disc(ci, gp, r * 2.6, Color(c, 0.5 * ph), Color(c, 0.15 * ph), Color(c, 0))
				var pts := PackedVector2Array([Vector2(0, -r * 1.6), Vector2(r, 0), Vector2(0, r * 0.9), Vector2(-r, 0)])
				for i in pts.size(): pts[i] = gp + pts[i].rotated(g[4])
				ci.draw_colored_polygon(pts, Color(c.r * (1 + ph * 0.8), c.g * (1 + ph * 0.8), c.b * (1 + ph * 0.8)))
				ci.draw_polyline(GemArt.closed(pts), Color(1, 1, 1, 0.35), 0.5, true)
			for q in 3:
				lantern(ci, Vector2(46 + 36 + q * 88, gy - 14), 0.5, 0.65 + 0.25 * sin(t * (2.0 + (q + k) * 0.37) * 1.7 + q))
			if k == d_sel:
				var ph := fposmod(t, 10.0) / 10.0
				var dx := 150.0 * (_ease(ph / 0.4) if ph < 0.4 else 1.0 if ph < 0.5 else 1.0 - _ease((ph - 0.5) / 0.4) if ph < 0.9 else 0.0)
				cart(ci, Vector2(46 + 34 + dx, gy + 9), 0.5, sp_cols)
				_dashed(ci, GemArt.closed(GemArt.rrect(Vector2(43, gy - 18), Vector2(256, 36), 14)), 5, 4, Color(1.3, 1.05, 0.55), 1.6, -t * 15.0)
		elif k == Data.DEPTHS.size() - 1:
			for e in _eyes:
				var ph: float = fposmod(t - e[3], e[2]) / e[2]
				var a := 0.0
				if ph > 0.55 and ph < 0.75:
					a = 0.9 * clampf(minf((ph - 0.55) / 0.05, (0.75 - ph) / 0.05), 0.0, 1.0)
				if a > 0.0:
					for dx in [0.0, 9.0]:
						ci.draw_colored_polygon(GemArt.ellipse_pts(Vector2(e[0] + dx, e[1]), 2.2, 1.3 * (0.3 if fposmod(t * 1.3, 2.0) < 0.08 else 1.0), 0, 10), Color(1.5, 1.4, 0.6, a))
	if has("headframe"):
		var bot := B0 + d_open * BH + BH / 2 + 12
		var ph := fposmod(t, 9.0) / 9.0
		var dy := (bot - G0 - 22) * (_ease(ph / 0.42) if ph < 0.42 else 1.0 if ph < 0.5 else 1.0 - _ease((ph - 0.5) / 0.42) if ph < 0.92 else 0.0)
		ci.draw_line(Vector2(309, G0 - 108 + dy), Vector2(309, G0 - 4 + dy), hx("#9aa6b4"), 0.8)
		ci.draw_rect(Rect2(305, G0 - 4 + dy, 8, 15), hx("#c8a060"))
		ci.draw_line(Vector2(305, G0 + dy), Vector2(313, G0 + dy), hx("#4a3418"), 0.6)
		ci.draw_line(Vector2(305, G0 + 5 + dy), Vector2(313, G0 + 5 + dy), hx("#4a3418"), 0.6)

func _wheel(ci: CanvasItem) -> void:
	var st := hx("#b86a34" if cu else "#b8502a" if fire else "#a8947a")
	var dk := hx("#2a2018")
	var c := Vector2(304, 90)
	ci.draw_arc(c, 11.5, 0, TAU, 28, dk, 3.6, true)
	ci.draw_arc(c, 11.5, 0, TAU, 28, st, 2.0, true)
	for q in 6:
		var a := q * 1.047 + t * TAU / 6.0
		ci.draw_line(c, c + Vector2(cos(a), sin(a)) * 10.5, st, 1.2)
	ci.draw_circle(c, 2.4, dk)

static func _ease(p: float) -> float:
	p = clampf(p, 0.0, 1.0)
	return 4 * p * p * p if p < 0.5 else 1 - pow(-2 * p + 2, 3) / 2
