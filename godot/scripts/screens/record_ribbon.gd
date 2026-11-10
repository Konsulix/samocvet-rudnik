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
const SILK := Color(0.39, 0.06, 0.077)        # (the silk texture is ~SILK_K grey: these are /0.82)
const SILK_DARK := Color(0.16, 0.022, 0.032)
const SILK_SHEEN := Color(0.52, 0.105, 0.125)
const EDGE_W := 1.6      # the brass edging, across
const FRINGE := 0.45     # its soft edge (a screen pixel or so on the phone)

var card: Control
var info: Control
## the second ribbon (last_of): the last kept stone with a gene an achievement shows - in the left corner, moss green,
## as long as the record's, a brass butterfly instead of the wreath (the awards' Finds, where those genes are collected)
var left := false
var len_ := L
var c_silk := SILK
var c_dark := SILK_DARK
var c_sheen := SILK_SHEEN
## a tap on the ribbon opens a little sheet under it (tell): a heading, one line each, and the first time only the rule
## behind it (rule_id: Save.told) - after that the rule is known and only the list is shown
var head := ""
var lines := PackedStringArray()
var rule_id := ""
var rule := ""
var _tip: Control
var _shut_at := -1000
var _t := -DELAY
static var _weave: ImageTexture
static var _laurel: ImageTexture
static var _fly: ImageTexture

## goes into the info panel itself (after its content): the panel's rounded clip cuts its top into the corner
static func make(card_: Control, info_: Control, last_of := false) -> RecordRibbon:
	var r := RecordRibbon.new()
	if last_of:
		r.left = true
		r._t -= 0.25      # after the record's, if both hang
		r.c_silk = Color(0.12, 0.25, 0.14)
		r.c_dark = Color(0.035, 0.085, 0.045)
		r.c_sheen = Color(0.2, 0.37, 0.21)
	r.card = card_
	r.info = info_
	r.mouse_filter = Control.MOUSE_FILTER_STOP     # only over the ribbon itself (_has_point)
	r.gui_input.connect(func(e: InputEvent):
		if r.head != "" and Atlas._tapped(e):
			r.accept_event()
			r.tell())
	r.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	info_.item_rect_changed.connect(r.queue_redraw)
	card_.item_rect_changed.connect(r.queue_redraw)
	return r

## where the ribbon hangs, in this control's space (generous, for a finger)
func _hang() -> Rect2:
	var ig: Rect2 = get_global_transform().affine_inverse() * info.get_global_transform() * Rect2(Vector2.ZERO, info.size)
	var x := ig.position.x + IN_X if left else ig.end.x - IN_X
	return Rect2(x - W, ig.position.y - UP, W * 2.0, len_ + UP + 8.0)

func _has_point(p: Vector2) -> bool:
	return head != "" and is_instance_valid(info) and _hang().has_point(p)

## the sheet under the ribbon (again: it folds away)
func tell() -> void:
	if is_instance_valid(_tip) or Time.get_ticks_msec() - _shut_at < 350:
		_shut()
		return
	Sfx.play("click")
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Kit.box("btn_dark", 10.0))
	p.top_level = true                 # (over the card, not clipped by the panel, not laid out by it)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 1)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := Kit.label(head, 13, UI.body_bold, Kit.AMBER)
	vb.add_child(h)
	for t in lines:
		var l := Kit.label("•  " + t, 15, UI.body, Kit.CREAM)
		vb.add_child(l)
	if rule_id != "" and not Save.told(rule_id):
		var r := Kit.label(rule, 12, UI.body, Kit.DIM)
		r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		r.custom_minimum_size = Vector2(170, 0)
		vb.add_child(r)
		Save.tell(rule_id)
	for c in vb.get_children():
		(c as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(vb)
	card.add_child(p)
	p.reset_size()
	# hung from the ribbon's tip, on its side of the card, kept inside the card
	var hang := _hang()
	var g := get_global_transform()
	var tip := g * Vector2(hang.get_center().x, hang.position.y + UP + len_ + 2.0)
	var cr := card.get_global_rect()
	var x := tip.x - W * 0.7 if left else tip.x + W * 0.7 - p.size.x
	x = clampf(x, cr.position.x + 8.0, cr.end.x - 8.0 - p.size.x)
	p.global_position = Vector2(x, tip.y)
	p.pivot_offset = Vector2(0.0 if left else p.size.x, 0.0)
	p.scale = Vector2(0.85, 0.85)
	p.modulate.a = 0.0
	var tw := p.create_tween().set_parallel()
	tw.tween_property(p, "modulate:a", 1.0, 0.15)
	tw.tween_property(p, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tip = p
	get_tree().create_timer(6.0).timeout.connect(func(): if _tip == p: _shut())

func _shut() -> void:
	if not is_instance_valid(_tip): return
	var p := _tip
	_tip = null
	_shut_at = Time.get_ticks_msec()
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 0.0, 0.15)
	tw.tween_callback(p.queue_free)

## any touch folds the sheet away (and goes on to whatever it was for)
func _input(e: InputEvent) -> void:
	if is_instance_valid(_tip) and e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
		_shut()

func _process(dt: float) -> void:
	_t += dt
	queue_redraw()
	if _t > RUN: set_process(false)

## the silk, once, over the whole ribbon (u across 0..1, v down 0..1): soft creases - wandering lines, each a dark
## fold with a lit edge above it, as in the reference - over a mottled ground and fine threads along it. Grey around
## SILK_K: the colour is the vertices', the texture only lights and shades it
const SILK_K := 0.82
static func silk() -> ImageTexture:
	if _weave == null:
		const TW := 80
		const TH := 188
		var folds := FastNoiseLite.new()
		folds.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		folds.seed = 41
		folds.frequency = 0.022
		folds.fractal_octaves = 1
		folds.domain_warp_enabled = true
		folds.domain_warp_amplitude = 7.0
		folds.domain_warp_frequency = 0.012
		var mottle := FastNoiseLite.new()
		mottle.seed = 7
		mottle.frequency = 0.045
		mottle.fractal_octaves = 3
		var rng := RandomNumberGenerator.new()
		rng.seed = 731
		var thread := []
		for x in TW: thread.append(rng.randf() - 0.5)
		var crease := func(x: float, y: float) -> float:
			var w := Vector2(x, y * 0.8)        # the folds run a little more along the ribbon than across
			var n := folds.get_noise_2d(w.x, w.y)
			return 1.0 - smoothstep(0.02, 0.16, absf(n))
		var img := Image.create(TW, TH, true, Image.FORMAT_RGBA8)
		for y in TH:
			for x in TW:
				var v := SILK_K
				v += mottle.get_noise_2d(x, y) * 0.07
				v -= float(crease.call(x, y)) * 0.24                     # the fold
				v += float(crease.call(x + 2.0, y + 2.0)) * 0.14         # its lit edge, up and to the left
				v += float(thread[x]) * 0.035 + (rng.randf() - 0.5) * 0.03
				img.set_pixel(x, y, Color(v, v, v))
		img.generate_mipmaps()
		_weave = ImageTexture.create_from_image(img)
	return _weave

## the brass edging, once: a strip (u along, repeating; v across 0..1): a dark line each side, a rounded gilt bead
## between, lit a little above its middle; along it the metal is uneven - brighter and duller stretches, small dark
## a few bright specks (the reference's edging is worked brass, not a flat line)
static var _brass: ImageTexture
static func brass() -> ImageTexture:
	if _brass == null:
		const TW := 192
		const TH := 16
		var along := FastNoiseLite.new()
		along.seed = 19
		along.frequency = 0.05
		along.fractal_octaves = 2
		var rng := RandomNumberGenerator.new()
		rng.seed = 88
		# the card frame's own calm brass (sampled from rule.png, the rim's strip): the edging is the same metal as the rim
		var hi := Color(0.86, 0.8, 0.69)
		var md := Color(0.63, 0.56, 0.45)
		var lo := Color(0.34, 0.29, 0.22)
		var dk := Color(0.06, 0.03, 0.015)
		var img := Image.create(TW, TH, true, Image.FORMAT_RGBA8)
		for x in TW:
			var a := along.get_noise_2d(x, 0.0) * 0.5
			for y in TH:
				var v := (y + 0.5) / TH
				var c: Color
				if v < 0.2 or v > 0.93:   # v 0 is the outer side (the strip runs round with its inside on the +normal)
					c = dk
				else:
					var t := (v - 0.2) / 0.73
					var lit := sin(PI * clampf(t * 1.1, 0.0, 1.0))     # rounded, its crest a little above the middle
					c = lo.lerp(md, lit).lerp(hi, pow(lit, 6.0) * 0.8)
					c = c.lerp(lo if a < 0.0 else hi, absf(a) * 0.4)
					if rng.randf() < 0.012: c = c.lerp(Color.WHITE, 0.5)   # a speck
				img.set_pixel(x, y, c)
		img.generate_mipmaps()
		_brass = ImageTexture.create_from_image(img)
	return _brass

## a textured strip along `pts` (open), `wd` across: mitred at the corners, u by length (`per` points a repeat)
func _strip(pts: PackedVector2Array, wd: float, tex: Texture2D, per: float) -> void:
	var n := pts.size()
	var nrm := PackedVector2Array()
	for i in n:
		var a := (pts[i] - pts[maxi(0, i - 1)]).normalized() if i > 0 else Vector2.ZERO
		var b := (pts[mini(n - 1, i + 1)] - pts[i]).normalized() if i < n - 1 else Vector2.ZERO
		var t := (a + b).normalized() if (a + b).length() > 0.001 else b if b != Vector2.ZERO else a
		var o := t.orthogonal()
		var mit := 1.0 / maxf(o.dot(a.orthogonal() if a != Vector2.ZERO else o), 0.45)
		nrm.append(o * mit)
	var u := 0.0
	var white := Color.WHITE
	for i in n - 1:
		var seg := pts[i].distance_to(pts[i + 1])
		var u1 := u + seg / per
		var p0 := pts[i]
		var p1 := pts[i + 1]
		var h := wd / 2.0
		draw_primitive(PackedVector2Array([p0 - nrm[i] * h, p1 - nrm[i + 1] * h, p1 + nrm[i + 1] * h, p0 + nrm[i] * h]),
			PackedColorArray([white, white, white, white]),
			PackedVector2Array([Vector2(u, 0.0), Vector2(u1, 0.0), Vector2(u1, 1.0), Vector2(u, 1.0)]), tex)
		# a soft fringe on each side, fading out: quads are not antialiased, and a diagonal edge stair-stepped
		# into little notches along the swallowtail
		var clear := Color(1, 1, 1, 0)
		for sd: float in [-1.0, 1.0]:
			var v := 0.0 if sd < 0.0 else 1.0
			draw_primitive(PackedVector2Array([p0 + nrm[i] * h * sd, p1 + nrm[i + 1] * h * sd, p1 + nrm[i + 1] * (h + FRINGE) * sd, p0 + nrm[i] * (h + FRINGE) * sd]),
				PackedColorArray([white, white, clear, clear]),
				PackedVector2Array([Vector2(u, v), Vector2(u1, v), Vector2(u1, v), Vector2(u, v)]), tex)
		u = u1

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
		var y := s * len_ * k
		return Vector2(y * sin(sw) + wave, y * cos(sw))
	return Vector2(0.0, s * len_)

func _draw() -> void:
	if not is_instance_valid(info) or _t < 0.0: return     # the card opens first, then the ribbon drops
	var to_me := get_global_transform().affine_inverse()
	var ig: Rect2 = to_me * info.get_global_transform() * Rect2(Vector2.ZERO, info.size)
	var top := Vector2(ig.position.x + IN_X if left else ig.end.x - IN_X, ig.position.y - UP)
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
		var cut := NOTCH * clampf((s - (1.0 - NOTCH / len_)) / (NOTCH / len_), 0.0, 1.0)
		for c in ACROSS.size():
			var a: float = ACROSS[c]
			var up := cut * (1.0 - absf(a) * 2.0)               # the V: deepest in the middle, none at the corners
			var col_pts: PackedVector2Array = cols[c]     # packed arrays are values: append, then put back
			col_pts.append(mid[i] + across * w * a - dn * up)
			cols[c] = col_pts
	var outline := PackedVector2Array()
	for i in N + 1: outline.append(cols[0][i])
	outline.append(cols[2][N])     # the swallowtail: its two straight cuts, no points between (they kinked the edging)
	for i in range(N, -1, -1): outline.append(cols[ACROSS.size() - 1][i])
	# a soft shadow on the slate, down and to the left (not on a frame where the outline folds over itself: the
	# renderer can't fill that and logs an error per polygon — it happened on the frame the card opened)
	var flat := Geometry2D.triangulate_polygon(outline).size() > 0
	for k in (3 if flat else 0):
		var off := Vector2(-0.8 - k * 0.9, 1.6 + k * 1.3)
		var sh := PackedVector2Array()
		for p in outline: sh.append(p + off)
		draw_colored_polygon(sh, Color(0, 0, 0, 0.16))
	# the silk
	var tex := silk()
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
				uv.append(Vector2(float(ACROSS[cc]) + 0.5, float(row) / N))
			draw_primitive(pts, cl, uv, tex)
	# the worked brass edging down both sides and round the swallowtail, on the silk's edge
	_strip(outline, EDGE_W, brass(), 40.0)    # ~as many texels along as across: no muddy mipmap
	# the laurel near the end, turning with the silk
	var at := int(round(N * (1.0 - (NOTCH + 10.5) / len_)))
	var tilt := -atan(lean[at])
	if left:
		draw_set_transform(mid[at], tilt, Vector2.ONE * (18.0 / 96.0))
		draw_texture_rect(butterfly(), Rect2(-Vector2(48, 48), Vector2(96, 96)), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	draw_set_transform(mid[at] + Vector2(0, 0), tilt, Vector2.ONE * (WREATH_PT / 96.0))
	var lt := laurel()
	draw_texture_rect(lt, Rect2(-Vector2(48, 50), Vector2(96, 96)), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## the silk's colour at a vertex: column c (0 left edge .. 4 right edge), a satin sheen a third of the way across,
## darker to the edges and up under the rim, lighter where it leans to the light (top left)
func _shade(c: int, lean_: float, i: int) -> Color:
	var col := c_silk
	match c:
		0: col = c_silk.lerp(c_dark, 0.2)
		1: col = c_silk.lerp(c_sheen, 0.28)
		2: col = c_silk.lerp(c_sheen, 0.12)
		4: col = c_silk.lerp(c_dark, 0.3)
	var l := clampf(-lean_ * 0.8, -0.5, 0.5)
	col = col.lerp(c_sheen, l) if l > 0.0 else col.lerp(c_dark, -l)
	var s := float(i) / N
	col = col.lerp(c_dark, clampf(0.55 - s * 2.2, 0.0, 0.55))     # the shade of the rim over its top
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

## the butterfly, painted once into a 96 px texture like the wreath: four wings (the fore ones larger, swept up, an
## eyespot in each; the hind ones with a tail), a slim body, two antennae with knobs; worked brass, each wing's
## face lit by how it turns to the light (top left), a thin dark rim round everything
static func butterfly() -> ImageTexture:
	if _fly != null: return _fly
	const S := 96
	var C := Vector2(48, 52)
	var light := Vector2(-0.6, -0.8).normalized()
	var hi := Color(1.0, 0.9, 0.62)
	var md := Color(0.86, 0.66, 0.32)
	var lo := Color(0.52, 0.34, 0.12)
	var rim := Color(0.13, 0.06, 0.02)
	# wings: [centre, angle, half length, half width, eyespot share along, eyespot radius, tail]
	var wings := []
	for sd: float in [-1.0, 1.0]:
		wings.append([C + Vector2(sd * 17.0, -10.0), (PI if sd < 0.0 else 0.0) - sd * 0.62, 21.0, 13.5, 0.38, 4.2, false])
		wings.append([C + Vector2(sd * 13.5, 12.0), (PI if sd < 0.0 else 0.0) + sd * 0.78, 15.5, 10.0, 0.3, 2.8, true])
	var img := Image.create(S, S, true, Image.FORMAT_RGBA8)
	for y in S:
		for x in S:
			var p := Vector2(x + 0.5, y + 0.5)
			var out := Color(0, 0, 0, 0)
			# the antennae: two thin curves up and out, a knob at each tip
			for sd: float in [-1.0, 1.0]:
				var a0 := C + Vector2(sd * 2.0, -12.0)
				var tipp := C + Vector2(sd * 15.0, -38.0)
				var ctrl := C + Vector2(sd * 3.5, -34.0)
				var best := 1e9
				for k in 13:
					var t := k / 12.0
					var q := a0.lerp(ctrl, t).lerp(ctrl.lerp(tipp, t), t)
					best = minf(best, p.distance_to(q))
				out = _over(out, rim, clampf(2.8 - best, 0.0, 1.0))
				out = _over(out, md.lerp(hi, 0.3), clampf(1.6 - best, 0.0, 1.0))
				var dk := p.distance_to(tipp)
				out = _over(out, rim, clampf(4.6 - dk, 0.0, 1.0))
				out = _over(out, md.lerp(hi, clampf((tipp.y + 1.5 - p.y) / 3.0, 0.0, 1.0)), clampf(3.4 - dk, 0.0, 1.0))
			for wg in wings:
				var o: Vector2 = wg[0]
				var ang: float = wg[1]
				var hl: float = wg[2]
				var hw: float = wg[3]
				var d := (p - o).rotated(-ang)
				# an egg, fuller towards its outer end
				var u := d.x / hl
				if absf(u) > 1.3: continue
				var half := hw * sqrt(maxf(0.0, 1.0 - u * u)) * (1.0 + 0.22 * u)
				var edge := absf(d.y) - half
				if bool(wg[6]):
					# the hind wing's tail: a small round lobe past its outer end
					var tl := (d - Vector2(hl * 1.02, 0.0)).length() - 3.6
					edge = minf(edge, tl)
				var cov_rim := clampf(1.4 - edge, 0.0, 1.0)
				if cov_rim <= 0.0: continue
				out = _over(out, rim, cov_rim)
				var cov := clampf(0.4 - edge, 0.0, 1.0)
				if cov <= 0.0: continue
				# the wing's face: a gentle dome, lit from the top left
				var n := Vector2(u, d.y / maxf(half, 0.01)).rotated(ang) * 0.8
				var face := n.dot(light)
				var c := md.lerp(hi, clampf(face, 0.0, 1.0)) if face > 0.0 else md.lerp(lo, clampf(-face, 0.0, 1.0))
				# veins fanning from the root, and a darker hem
				var root := (p - (C + Vector2(0, -2))).angle()
				if absf(sin(root * 7.0)) < 0.09 and absf(u) < 0.85: c = c.lerp(lo, 0.45)
				if edge > -2.0: c = c.lerp(lo, 0.35)
				# the eyespot: a dark ring round a bright pupil
				var es := p.distance_to(o + Vector2(hl * float(wg[4]), 0).rotated(ang))
				var er: float = wg[5]
				if es < er + 1.0: c = rim.lerp(c, clampf(es - er, 0.0, 1.0))
				if es < er * 0.55: c = hi
				out = _over(out, c, cov)
			# the body, over the wings: a slim segmented spindle
			var db := p - C
			var bu := db.y / 19.0
			if absf(bu) < 1.1:
				var bh := 2.9 * sqrt(maxf(0.0, 1.0 - bu * bu)) + (0.6 if bu < -0.55 else 0.0)
				var be := absf(db.x) - bh
				var ends := (1.0 - absf(bu)) * 19.0
				out = _over(out, rim, clampf(1.4 - be, 0.0, 1.0) * clampf(ends + 1.4, 0.0, 1.0))
				var bc := md.lerp(hi, clampf(-db.x / maxf(bh, 0.01), 0.0, 1.0) * 0.8)
				if bu > -0.4 and fmod(db.y + 40.0, 4.0) < 0.9: bc = bc.lerp(lo, 0.5)
				out = _over(out, bc, clampf(0.4 - be, 0.0, 1.0) * clampf(ends + 0.4, 0.0, 1.0))
			img.set_pixel(x, y, out)
	img.generate_mipmaps()
	_fly = ImageTexture.create_from_image(img)
	return _fly


## `c` laid over `dst` with coverage `a` (straight alpha)
static func _over(dst: Color, c: Color, a: float) -> Color:
	if a <= 0.0: return dst
	var oa := a + dst.a * (1.0 - a)
	if oa <= 0.0: return Color(0, 0, 0, 0)
	var rgb := (Vector3(c.r, c.g, c.b) * a + Vector3(dst.r, dst.g, dst.b) * dst.a * (1.0 - a)) / oa
	return Color(rgb.x, rgb.y, rgb.z, oa)
