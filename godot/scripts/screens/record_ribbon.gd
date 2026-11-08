class_name RecordRibbon
extends Control
## The species' record stone (its atlas page, Reveal.is_record): a burgundy silk bookmark hangs from the info panel's
## top right corner, out from under its brass rim, a swallowtail end and a small brass diamond. Drawn in code: a strip
## of quads down its length (three across: the middle is a soft fold), a woven texture made once, the light following
## how each piece leans. When the card opens it drops in and flutters like a flag in a gust, then hangs still.

const W := 19.0          # across
const L := 52.0          # down, to the tips of the swallowtail
const NOTCH := 8.0       # the swallowtail's cut
const N := 18            # pieces down its length
const IN_X := 23.0       # its middle this far in from the panel's right edge (just where the rim starts to round)
const UP := 5.0          # it starts this far above the panel's top: under the rim
const DELAY := 0.18      # the card's own opening first
const RUN := 2.2         # then the flutter, settling

const SILK := Color(0.47, 0.07, 0.11)
const SILK_DARK := Color(0.24, 0.03, 0.06)
const SILK_LIGHT := Color(0.72, 0.2, 0.22)

var card: Control
var info: Control
var _t := -DELAY
static var _weave: ImageTexture

static func make(card_: Control, info_: Control) -> RecordRibbon:
	var r := RecordRibbon.new()
	r.card = card_
	r.info = info_
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	info_.item_rect_changed.connect(r.queue_redraw)
	card_.item_rect_changed.connect(r.queue_redraw)
	return r

func _process(dt: float) -> void:
	_t += dt
	queue_redraw()
	if _t > RUN: set_process(false)

## the silk's weave, once: a fine twill, threads along the ribbon, a little unevenness (grey: the colour is the vertices')
static func weave() -> ImageTexture:
	if _weave == null:
		var S := 32
		var img := Image.create(S, S, true, Image.FORMAT_RGBA8)
		var rng := RandomNumberGenerator.new()
		rng.seed = 731
		var row := []
		for y in S: row.append(rng.randf())
		for y in S:
			for x in S:
				var v := 0.9
				if (x + y) % 4 < 2: v -= 0.07          # the twill's diagonal
				if x % 2 == 0: v += 0.04               # warp threads, along the ribbon
				v += (float(row[y]) - 0.5) * 0.06      # a slub here and there across
				v += (rng.randf() - 0.5) * 0.05
				img.set_pixel(x, y, Color(v, v, v))
		img.generate_mipmaps()
		_weave = ImageTexture.create_from_image(img)
	return _weave

## where the ribbon's middle line is at a share `s` (0 top .. 1 tip) of its length, and its lean there (dx/dy)
func _line(s: float) -> Vector2:
	var t := maxf(_t, 0.0)
	var k := 1.0
	if _t < RUN:
		# it drops out from under the rim, a little overshoot
		var d := clampf(t / 0.3, 0.0, 1.0)
		var len_k := 0.25 + 0.75 * (1.0 + 2.2 * pow(d - 1.0, 3) + 1.2 * pow(d - 1.0, 2))
		k = len_k
		# the gust: the whole ribbon swings from its top, a wave runs down it; both die away
		var sw := 0.3 * exp(-t / 0.55) * sin(8.5 * t)
		var wave := 6.5 * exp(-t / 0.5) * pow(s, 1.4) * sin(15.0 * t - 3.4 * s)
		var y := s * L * k
		return Vector2(y * sin(sw) + wave, y * cos(sw))
	return Vector2(0.0, s * L)

func _draw() -> void:
	if not is_instance_valid(info) or _t < 0.0: return     # the card opens first, then the ribbon drops
	var to_me := get_global_transform().affine_inverse()
	var ig: Rect2 = to_me * info.get_global_transform() * Rect2(Vector2.ZERO, info.size)
	var top := Vector2(ig.end.x - IN_X, ig.position.y - UP)
	# the middle line, its leans, the edges
	var mid := PackedVector2Array()
	var lean := PackedFloat32Array()
	for i in N + 1:
		mid.append(top + _line(float(i) / N))
	for i in N + 1:
		var a := mid[maxi(0, i - 1)]
		var b := mid[mini(N, i + 1)]
		var d := b - a
		lean.append(d.x / maxf(absf(d.y), 0.01))
	var cols := [PackedVector2Array(), PackedVector2Array(), PackedVector2Array()]
	for i in N + 1:
		var s := float(i) / N
		var a := mid[maxi(0, i - 1)]
		var b := mid[mini(N, i + 1)]
		var across := (b - a).normalized().orthogonal() * -1.0      # to the right
		var w := W * (1.0 - 0.22 * minf(absf(lean[i]), 1.0))      # leaning, it turns a little: narrower
		if i == 0:
			across = Vector2.RIGHT     # its top is held under the rim: it never tips up out of it
			w = W
		var p := mid[i]
		# the swallowtail: the middle comes up, the corners stay
		var cut := NOTCH * clampf((s - (1.0 - NOTCH / L)) / (NOTCH / L), 0.0, 1.0)
		cols[0].append(p - across * w / 2.0)
		cols[1].append(p - (b - a).normalized() * cut)
		cols[2].append(p + across * w / 2.0)
	# its shadow on the panel
	var sh := Vector2(2.0, 3.0)
	for i in N:
		for c in 2:
			var q: PackedVector2Array = cols[c]
			var r: PackedVector2Array = cols[c + 1]
			draw_colored_polygon(PackedVector2Array([q[i] + sh, q[i + 1] + sh, r[i + 1] + sh, r[i] + sh]), Color(0, 0, 0, 0.3))
	# the silk
	var tex := weave()
	for i in N:
		for c in 2:
			var q: PackedVector2Array = cols[c]
			var r: PackedVector2Array = cols[c + 1]
			var pts := PackedVector2Array([q[i], q[i + 1], r[i + 1], r[i]])
			var cl := PackedColorArray([_shade(c, lean[i], i), _shade(c, lean[i + 1], i + 1), _shade(c + 1, lean[i + 1], i + 1), _shade(c + 1, lean[i], i)])
			var uv := PackedVector2Array()
			for k in 4:
				var col := c if k < 2 else c + 1
				var row := i if k == 0 or k == 3 else i + 1
				uv.append(Vector2(col * 0.5 * W / 12.0, row * (L / N) / 12.0))
			draw_primitive(pts, cl, uv, tex)
	# stitching down both sides, just inside the edge
	for side: int in [0, 2]:
		var e: PackedVector2Array = cols[side]
		for i in range(0, N - 2, 2):
			var a := e[i].lerp(cols[1][i], 0.2)
			var b := e[i + 1].lerp(cols[1][i + 1], 0.2)
			draw_line(a, b, Color(0.95, 0.62, 0.5, 0.22), 0.8, true)
	# a small brass laurel wreath near the end, turning with the silk
	var at := int(round(N * (1.0 - (NOTCH + 11.5) / L)))
	_wreath(Transform2D(-atan(lean[at]), mid[at]))

## the laurel: two sprays of leaves round an open circle, meeting at the foot; each leaf a pointed oval along the
## stem, leaning out, lit on its upper edge; a dark rim under all of it so it reads on the silk
func _wreath(xf: Transform2D) -> void:
	const R := 6.0
	const LEAVES := 7
	var dark := Color(0.14, 0.06, 0.02, 0.8)
	var leaf := func(c: Vector2, dir: float, ln: float, wd: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for k in 10:
			var a := TAU * k / 10.0
			var p := Vector2(cos(a) * ln, sin(a) * wd * (1.0 - 0.35 * absf(cos(a))))   # pointed at both ends
			pts.append(xf * (c + p.rotated(dir)))
		return pts
	var parts := []      # [points, shade]
	for side: float in [-1.0, 1.0]:
		for k in LEAVES:
			# from the foot (straight down) up round the side, stopping short of the top
			var a := PI / 2.0 - side * (0.35 + k * (PI * 0.9) / LEAVES)
			var on := Vector2(cos(a), sin(a)) * R
			var tangent := a - side * PI / 2.0       # pointing up the spray
			var out := 0.55 * side                     # leaves lean outwards
			var size := 1.0 - 0.06 * k
			parts.append([leaf.call(on + Vector2(cos(a), sin(a)) * 1.1, tangent - out, 2.3 * size, 0.95 * size), 0.15 + 0.1 * side])
			parts.append([leaf.call(on - Vector2(cos(a), sin(a)) * 0.9, tangent + out * 0.7, 2.0 * size, 0.85 * size), -0.1])
	# the stems: two arcs, and the tie at the foot
	var stem := func(side: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for k in 12:
			var a := PI / 2.0 - side * (0.15 + k * (PI * 0.92) / 11.0)
			pts.append(xf * (Vector2(cos(a), sin(a)) * R))
		return pts
	for side: float in [-1.0, 1.0]: draw_polyline(stem.call(side), dark, 2.0, true)
	for p in parts: draw_colored_polygon(_grow(p[0], 0.55), dark)
	for side: float in [-1.0, 1.0]: draw_polyline(stem.call(side), Kit.AMBER.darkened(0.3), 0.8, true)
	for p in parts:
		var s: float = p[1]
		draw_colored_polygon(p[0], Kit.AMBER.lightened(s) if s > 0.0 else Kit.AMBER.darkened(-s))
	# a glint along the top leaves and the knot at the foot
	draw_circle(xf * Vector2(0, R + 0.4), 1.3, dark, true, -1.0, true)
	draw_circle(xf * Vector2(0, R + 0.4), 0.85, Kit.AMBER.lightened(0.2), true, -1.0, true)

## a polygon puffed out from its middle by `by` (the dark rim under each leaf)
static func _grow(pts: PackedVector2Array, by: float) -> PackedVector2Array:
	var c := Vector2.ZERO
	for p in pts: c += p
	c /= pts.size()
	var out := PackedVector2Array()
	for p in pts: out.append(p + (p - c).normalized() * by)
	return out

## the silk's colour at a corner: the edges darker than the soft fold in the middle, the light from the top left on
## whatever leans towards it, darker at the top where it comes out from under the rim
func _shade(col: int, lean_: float, i: int) -> Color:
	var c := SILK
	if col == 1: c = c.lerp(SILK_LIGHT, 0.22)
	else: c = c.lerp(SILK_DARK, 0.25)
	var l := clampf(-lean_ * 0.9, -0.6, 0.6)
	c = c.lerp(SILK_LIGHT, l) if l > 0.0 else c.lerp(SILK_DARK, -l)
	if i <= 1: c = c.lerp(SILK_DARK, 0.55 - 0.3 * i)
	return c
