class_name RecordRibbon
extends Control
## The species' record stone (its atlas page, Reveal.is_record): a wine-red silk bookmark tucked into the info panel's
## top right corner - its top runs under the brass rim and is cut by the panel's rounded corner (the ribbon lives inside
## the panel, which clips its children to its shape), a thin brass edging, a swallowtail end, a small brass laurel wreath.
## Drawn in code: a strip of quads down its length (a satin sheen across it), a faint weave made once, the light
## following how each piece leans. When the card opens it drops in and flutters like a flag in a gust, then hangs still.

const W := 20.0          # across
const L := 47.0          # down from the panel's top to the tips of the swallowtail
const NOTCH := 8.5       # the swallowtail's cut
const N := 18            # pieces down its length
const IN_X := 12.5       # its middle this far in from the panel's right edge: snug against the rim
const UP := 6.0          # it starts this far above the panel's top (cut away by the panel's shape)
const DELAY := 0.18      # the card's own opening first
const RUN := 2.2         # then the flutter, settling
const WREATH_PT := 16.0  # the wreath, across

# the silk, sRGB (the reference: a deep wine, darker up under the rim, a soft sheen a third of the way across)
const SILK := Color(0.35, 0.055, 0.07)
const SILK_DARK := Color(0.13, 0.018, 0.026)
const SILK_SHEEN := Color(0.47, 0.095, 0.11)
const EDGE := Color(0.86, 0.66, 0.33)
const EDGE_DARK := Color(0.30, 0.17, 0.06)

var card: Control
var info: Control
var _t := -DELAY
static var _weave: ImageTexture
static var _laurel: ImageTexture

## goes into the info panel itself (after its content): the panel's rounded clip cuts its top into the corner
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

## the silk's weave, once: a faint satin - threads along the ribbon, a little unevenness (grey: the colour is the vertices')
static func weave() -> ImageTexture:
	if _weave == null:
		var S := 32
		var img := Image.create(S, S, true, Image.FORMAT_RGBA8)
		var rng := RandomNumberGenerator.new()
		rng.seed = 731
		var col := []
		for x in S: col.append(rng.randf())
		for y in S:
			for x in S:
				var v := 0.95
				if x % 2 == 0: v += 0.025                 # warp threads, along the ribbon
				if (x + y) % 6 < 2: v -= 0.035  # a faint diagonal twill
				if (x + 3 * y) % 8 == 0: v -= 0.02        # the satin's sparse binding points
				v += (float(col[x]) - 0.5) * 0.04         # a thread a touch thicker here and there
				v += (rng.randf() - 0.5) * 0.025
				img.set_pixel(x, y, Color(v, v, v))
		img.generate_mipmaps()
		_weave = ImageTexture.create_from_image(img)
	return _weave

## where the ribbon's middle line is at a share `s` (0 top .. 1 tip) of its length
func _line(s: float) -> Vector2:
	var t := maxf(_t, 0.0)
	if _t < RUN:
		# it drops out from under the rim, a little overshoot
		var d := clampf(t / 0.3, 0.0, 1.0)
		var k := 0.3 + 0.7 * (1.0 + 2.2 * pow(d - 1.0, 3) + 1.2 * pow(d - 1.0, 2))
		# the gust: the whole ribbon swings from its top, a wave runs down it; both die away
		var sw := 0.26 * exp(-t / 0.55) * sin(8.5 * t)
		var wave := 5.0 * exp(-t / 0.5) * pow(s, 1.4) * sin(15.0 * t - 3.4 * s)
		var y := s * L * k
		return Vector2(y * sin(sw) + wave, y * cos(sw))
	return Vector2(0.0, s * L)

func _draw() -> void:
	if not is_instance_valid(info) or _t < 0.0: return     # the card opens first, then the ribbon drops
	var to_me := get_global_transform().affine_inverse()
	var ig: Rect2 = to_me * info.get_global_transform() * Rect2(Vector2.ZERO, info.size)
	var top := Vector2(ig.end.x - IN_X, ig.position.y - UP)
	var mid := PackedVector2Array()
	var lean := PackedFloat32Array()
	for i in N + 1:
		mid.append(top + _line(float(i) / N))
	for i in N + 1:
		var d := mid[mini(N, i + 1)] - mid[maxi(0, i - 1)]
		lean.append(d.x / maxf(absf(d.y), 0.01))
	# five columns across: edge, sheen, middle, middle, edge; the middle one rises into the swallowtail's cut
	const ACROSS := [-0.5, -0.17, 0.0, 0.2, 0.5]
	var cols := []
	for c in ACROSS.size(): cols.append(PackedVector2Array())
	for i in N + 1:
		var s := float(i) / N
		var dn := (mid[mini(N, i + 1)] - mid[maxi(0, i - 1)]).normalized()
		var across := dn.orthogonal()        # to the right (orthogonal() turns (0, 1) into (1, 0))
		var w := W * (1.0 - 0.2 * minf(absf(lean[i]), 1.0))       # leaning, it turns a little: narrower
		if i == 0:
			across = Vector2.RIGHT
			w = W
		var cut := NOTCH * clampf((s - (1.0 - NOTCH / L)) / (NOTCH / L), 0.0, 1.0)
		for c in ACROSS.size():
			var a: float = ACROSS[c]
			var up := cut * (1.0 - absf(a) * 2.0)               # the V: deepest in the middle, none at the corners
			var col_pts: PackedVector2Array = cols[c]     # packed arrays are values: append, then put back
			col_pts.append(mid[i] + across * w * a - dn * up)
			cols[c] = col_pts
	var outline := PackedVector2Array()
	for i in N + 1: outline.append(cols[0][i])
	for c in range(1, ACROSS.size()): outline.append(cols[c][N])
	for i in range(N, -1, -1): outline.append(cols[ACROSS.size() - 1][i])
	# a soft shadow on the slate, down and to the left
	for k in 3:
		var off := Vector2(-0.8 - k * 0.9, 1.6 + k * 1.3)
		var sh := PackedVector2Array()
		for p in outline: sh.append(p + off)
		draw_colored_polygon(sh, Color(0, 0, 0, 0.16))
	# the silk
	var tex := weave()
	for i in N:
		for c in ACROSS.size() - 1:
			var q: PackedVector2Array = cols[c]
			var r: PackedVector2Array = cols[c + 1]
			var pts := PackedVector2Array([q[i], q[i + 1], r[i + 1], r[i]])
			var cl := PackedColorArray([_shade(c, lean[i], i), _shade(c, lean[i + 1], i + 1), _shade(c + 1, lean[i + 1], i + 1), _shade(c + 1, lean[i], i)])
			var uv := PackedVector2Array()
			for k in 4:
				var cc := c if k < 2 else c + 1
				var row := i if k == 0 or k == 3 else i + 1
				uv.append(Vector2((float(ACROSS[cc]) + 0.5) * W / 10.0, row * (L / N) / 10.0))
			draw_primitive(pts, cl, uv, tex)
	# the brass edging down both sides and round the swallowtail: a dark line outside, the brass inside it, a glint
	# on the left side
	var edge := outline
	draw_polyline(edge, EDGE_DARK, 2.3, true)
	draw_polyline(edge, EDGE, 1.15, true)
	var lit := PackedVector2Array()
	for i in range(2, N - 2): lit.append(cols[0][i] + (cols[1][i] - cols[0][i]).normalized() * 0.5)
	draw_polyline(lit, Color(1.0, 0.9, 0.7, 0.35), 0.6, true)
	# the laurel near the end, turning with the silk
	var at := int(round(N * (1.0 - (NOTCH + 10.5) / L)))
	var tilt := -atan(lean[at])
	draw_set_transform(mid[at] + Vector2(0, 0), tilt, Vector2.ONE * (WREATH_PT / 96.0))
	var lt := laurel()
	draw_texture_rect(lt, Rect2(-Vector2(48, 50), Vector2(96, 96)), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## the silk's colour at a vertex: column c (0 left edge .. 4 right edge), a satin sheen a third of the way across,
## darker to the edges and up under the rim, lighter where it leans to the light (top left)
func _shade(c: int, lean_: float, i: int) -> Color:
	var col := SILK
	match c:
		0: col = SILK.lerp(SILK_DARK, 0.2)
		1: col = SILK.lerp(SILK_SHEEN, 0.28)
		2: col = SILK.lerp(SILK_SHEEN, 0.12)
		4: col = SILK.lerp(SILK_DARK, 0.3)
	var l := clampf(-lean_ * 0.8, -0.5, 0.5)
	col = col.lerp(SILK_SHEEN, l) if l > 0.0 else col.lerp(SILK_DARK, -l)
	var s := float(i) / N
	col = col.lerp(SILK_DARK, clampf(0.55 - s * 2.2, 0.0, 0.55))     # the shade of the rim over its top
	return col

## the wreath, painted once into a 96 px texture (smooth edges at any size): two sprays of pointed leaves round an
## open ring, outer and inner leaves alternating and smaller towards the top, a midrib in each, the half of each leaf
## facing the light (top left) brighter, a thin dark rim round everything, the stems tied at the foot
static func laurel() -> ImageTexture:
	if _laurel != null: return _laurel
	const S := 96
	var C := Vector2(48, 50)
	const R := 29.0
	var leaves := []      # [centre, angle, half length, half width]
	for side: float in [-1.0, 1.0]:
		var n := 7
		for k in n:
			var f := float(k) / (n - 1)
			var phi := deg_to_rad(104.0 + f * 132.0)          # from just past the foot round the side to near the top
			var p := C + Vector2(cos(phi), sin(phi)) * R
			var rad := Vector2(cos(phi), sin(phi))
			var tan_a := phi + PI / 2.0                        # up the spray
			var sz := 1.0 - 0.32 * f
			var hl := 10.0 * sz
			var hw := 4.6 * sz
			# outer, then inner a half step further up
			leaves.append([p + rad * 5.0 + Vector2.from_angle(tan_a) * 3.0, tan_a - 0.62, hl, hw])
			if k < n - 1:
				var phi2 := phi + deg_to_rad(132.0 / (n - 1) * 0.5)
				var p2 := C + Vector2(cos(phi2), sin(phi2)) * R
				var rad2 := Vector2(cos(phi2), sin(phi2))
				leaves.append([p2 - rad2 * 4.6 + Vector2.from_angle(phi2 + PI / 2.0) * 3.0, phi2 + PI / 2.0 + 0.62, hl * 0.88, hw * 0.88])
		# the top leaf, along the stem
		var pe := deg_to_rad(104.0 + 132.0 + 9.0)
		leaves.append([C + Vector2(cos(pe), sin(pe)) * R, pe + PI / 2.0, 6.5, 2.6])
		if side < 0.0:
			# mirror the left spray into the right one
			var m := []
			for lf in leaves:
				var c: Vector2 = lf[0]
				m.append([Vector2(2.0 * C.x - c.x, c.y), PI - float(lf[1]), lf[2], lf[3]])
			leaves.append_array(m)
			break
	var light := Vector2(-0.6, -0.8).normalized()
	var hi := Color(1.0, 0.9, 0.62)
	var md := Color(0.86, 0.66, 0.32)
	var lo := Color(0.52, 0.34, 0.12)
	var rim := Color(0.13, 0.06, 0.02)
	var img := Image.create(S, S, true, Image.FORMAT_RGBA8)
	for y in S:
		for x in S:
			var p := Vector2(x + 0.5, y + 0.5)
			var out := Color(0, 0, 0, 0)
			# the stems: arcs of the ring from the foot to the top leaves, and the tie
			var dc := p - C
			var ang := fposmod(atan2(dc.y, dc.x), TAU)
			var on_arc := ang > deg_to_rad(92.0) and ang < deg_to_rad(242.0) or ang < deg_to_rad(88.0) or ang > deg_to_rad(298.0)
			var ds := absf(dc.length() - R)
			if on_arc:
				out = _over(out, rim, clampf(2.4 - ds, 0.0, 1.0))
				out = _over(out, md.lerp(lo, 0.3), clampf(1.3 - ds, 0.0, 1.0))
			for lf in leaves:
				var d: Vector2 = (p - (lf[0] as Vector2)).rotated(-float(lf[1]))
				var hl: float = lf[2]
				var hw: float = lf[3]
				var u := d.x / hl
				if absf(u) > 1.15: continue
				var half := hw * maxf(0.0, 1.0 - u * u) * (1.0 + 0.15 * u)    # pointed both ends, a little fuller up
				var edge := absf(d.y) - half
				var tip := (1.0 - absf(u)) * hl
				var cov_rim := clampf(1.3 - edge, 0.0, 1.0) * clampf(tip + 1.3, 0.0, 1.0)
				if cov_rim <= 0.0: continue
				out = _over(out, rim, cov_rim)
				var cov := clampf(0.5 - edge, 0.0, 1.0) * clampf(tip + 0.5, 0.0, 1.0)
				if cov <= 0.0: continue
				# which half: its outward side, towards the light or away
				var side_dir := Vector2(0.0, signf(d.y)).rotated(float(lf[1]))
				var face := side_dir.dot(light)
				var across := clampf(absf(d.y) / maxf(half, 0.01), 0.0, 1.0)
				var c := md.lerp(hi, clampf(face * 0.9, 0.0, 1.0) * (0.35 + 0.65 * across)) if face > 0.0 else md.lerp(lo, clampf(-face, 0.0, 1.0) * (0.3 + 0.7 * across))
				c = c.lerp(hi, 0.15 * clampf(u, 0.0, 1.0))              # lighter to the tip
				if absf(d.y) < 0.55 and absf(u) < 0.8: c = c.lerp(lo, 0.55)    # the midrib
				out = _over(out, c, cov)
			# the tie at the foot: a small round knot
			var dk := p.distance_to(C + Vector2(0, R + 1.0))
			out = _over(out, rim, clampf(4.2 - dk, 0.0, 1.0))
			out = _over(out, md.lerp(hi, clampf((C.y + R - p.y) / 3.0, 0.0, 1.0) * 0.6), clampf(3.0 - dk, 0.0, 1.0))
			img.set_pixel(x, y, out)
	img.generate_mipmaps()
	_laurel = ImageTexture.create_from_image(img)
	return _laurel

## `c` laid over `dst` with coverage `a` (straight alpha)
static func _over(dst: Color, c: Color, a: float) -> Color:
	if a <= 0.0: return dst
	var oa := a + dst.a * (1.0 - a)
	if oa <= 0.0: return Color(0, 0, 0, 0)
	var rgb := (Vector3(c.r, c.g, c.b) * a + Vector3(dst.r, dst.g, dst.b) * dst.a * (1.0 - a)) / oa
	return Color(rgb.x, rgb.y, rgb.z, oa)
