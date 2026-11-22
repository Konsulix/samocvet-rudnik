class_name GulpView
extends Node2D
## The plesiosaur's hunt on the board (BoardModel.gulp, CLAUDE.md 22.11): his neck lies round the board — the head over
## the top's middle, the neck along the top to the right, down the right side, back along the bottom and up the left
## into his body — and the swallowed find is a lump of light in it. Drawn in code for now (a playable draft: the
## rules first, his pixel art after): the neck with the lump riding in it, the cells beside the lump lit (where to
## strike), a harpoon standing in the neck while the lump is pinned, the 2x2 his head has marked with the moves left
## to it, the head's lunge and bite, the find spat out (won) or gone down (lost).

var board: BoardView
var model: BoardModel
var glow := Color("#9be8ff")     # the find's own colour (its rarity)
var _anch: Array = []            # [index on the track (fractions at the corners), point, outward normal]
var _n := 0
var _at := 0.0                   # where the lump is drawn (eased towards the model's)
var _t := 0.0
var _jaw := 0.15
var _head_off := Vector2.ZERO    # the head away from its place (a lunge)
var _head_turn := 0.0
var _pin_k := 0.0                # the harpoon in the neck: 0 none .. 1 in
var _pin_at := 0.0
var _flash := 0.0
var _mark: Array = []
var _mark_left := 0
var _spit := -1.0                # 0..1: the find flying out of his mouth
var _sink := 0.0                 # 0..1: he goes under (lost)
var _hurt := 0.0

const SKIN := Color("#2b5b68")
const SKIN_HI := Color("#4f8f9a")
const SKIN_LO := Color("#17343d")
const BELLY := Color("#a9c8bc")
const INK := Color("#081419")

func setup(b: BoardView, m: BoardModel) -> void:
	board = b
	model = m
	z_index = 20
	position = Vector2.ZERO
	_build()
	_at = float(m.gulp.at)

func _w() -> float:
	return board.TS * 0.46

func _build() -> void:
	_anch = []
	var tr: Array = model.gulp.track
	_n = tr.size()
	var d := board.TS * 0.5 + _w() * 0.5 + 1.0
	var R: int = model.R
	var C: int = model.C
	for i in _n:
		var p: Vector2i = tr[i]
		var n1 := C - C / 2            # along the top, then down the right side, back along the bottom, up the left
		var out := Vector2.UP if i < n1 else Vector2.RIGHT if i < n1 + R - 1 else Vector2.DOWN if i < n1 + R - 1 + C - 1 else Vector2.LEFT
		if not _anch.is_empty():
			var last: Array = _anch[_anch.size() - 1]
			var lo: Vector2 = last[2]
			if lo != out:
				# a corner of the board: the neck goes round it
				var cp: Vector2 = board.cell_center(float(tr[i - 1].x), float(tr[i - 1].y)) + (lo + out) * d
				_anch.append([i - 0.5, cp, (lo + out).normalized()])
		_anch.append([float(i), board.cell_center(float(p.x), float(p.y)) + out * d, out])
	# the head's end, past the mouth; the body's, past the belly
	var a0: Array = _anch[0]
	_anch.push_front([-1.0, (a0[1] as Vector2) + Vector2(-board.TS * 0.95, 0), Vector2.UP])
	var an: Array = _anch[_anch.size() - 1]
	_anch.append([float(_n), (an[1] as Vector2) + Vector2(0, -board.TS), Vector2.LEFT])
	_anch.append([float(_n) + 1.0, (an[1] as Vector2) + Vector2(-board.TS * 0.5, -board.TS * 1.9), Vector2.LEFT])

## a place on the neck: [point, outward normal]
func _on_neck(f: float) -> Array:
	f = clampf(f, -1.0, float(_n) + 1.0)
	for i in _anch.size() - 1:
		var a: Array = _anch[i]
		var b: Array = _anch[i + 1]
		if f <= float(b[0]):
			var k := inverse_lerp(float(a[0]), float(b[0]), f)
			return [(a[1] as Vector2).lerp(b[1], k), (a[2] as Vector2).lerp(b[2], k).normalized()]
	var z: Array = _anch[_anch.size() - 1]
	return [z[1], z[2]]

func head_home() -> Vector2:
	return (_on_neck(-1.0)[0] as Vector2) + Vector2(-board.TS * 0.2, -board.TS * 0.5)

func _process(dt: float) -> void:
	_t += dt
	_flash = maxf(0.0, _flash - dt * 2.5)
	_hurt = maxf(0.0, _hurt - dt * 1.6)
	queue_redraw()

# ---------------------------------------------------------------- what happens

## the lump rides to its new place
func move_lump(to: int, dur := 0.32) -> void:
	if is_equal_approx(_at, float(to)): return
	var tw := create_tween()
	tw.tween_property(self, "_at", float(to), dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished

## knocked back towards the mouth: a flash at the lump, he flinches
func knock(harpoon: bool) -> void:
	_flash = 1.0
	_hurt = 1.0 if harpoon else 0.5
	if harpoon:
		_pin_at = _at
		_pin_k = 0.0
		create_tween().tween_property(self, "_pin_k", 1.0, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## the harpoon lets go (the pin has run out)
func unpin() -> void:
	if _pin_k <= 0.0: return
	create_tween().tween_property(self, "_pin_k", 0.0, 0.25)

func set_mark(cells: Array, left: int) -> void:
	_mark = cells
	_mark_left = left

## his head comes down on the marked stones and takes them: `taken` is called as the jaws shut
func bite(cells: Array, choke: bool, taken: Callable) -> void:
	_mark = []
	var c := Vector2.ZERO
	for p: Vector2i in cells: c += board.cell_center(float(p.x), float(p.y))
	if cells.is_empty():
		taken.call()
		return
	c /= float(cells.size())
	var to := c - head_home() + Vector2(board.TS * 0.2, -board.TS * 0.1)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "_head_off", to, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "_jaw", 1.0, 0.26)
	tw.tween_property(self, "_head_turn", 0.9, 0.3)
	await tw.finished
	_jaw = 0.0
	taken.call()
	if choke:
		# it went off in his mouth: he rears back, shaking
		_flash = 1.0
		_hurt = 1.6
		var ct := create_tween()
		for i in 4:
			ct.tween_property(self, "_head_turn", 0.9 + (0.5 if i % 2 == 0 else -0.5), 0.07)
			ct.parallel().tween_property(self, "_jaw", 1.0 if i % 2 == 0 else 0.3, 0.07)
		await ct.finished
	else:
		await get_tree().create_timer(0.12).timeout
	var bk := create_tween()
	bk.set_parallel(true)
	bk.tween_property(self, "_head_off", Vector2.ZERO, 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bk.tween_property(self, "_head_turn", 0.0, 0.42)
	bk.tween_property(self, "_jaw", 0.15, 0.42)
	await bk.finished

## won: the lump runs up into his mouth, he gags and the find flies out onto the board
func spit() -> void:
	unpin()
	var tw := create_tween()
	tw.tween_property(self, "_at", -1.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(self, "_jaw", 1.0, 0.4)
	await tw.finished
	_flash = 1.0
	_hurt = 2.0
	_spit = 0.0
	var st := create_tween()
	st.tween_property(self, "_spit", 1.0, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await st.finished
	var away := create_tween()
	away.tween_property(self, "_sink", 1.0, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await away.finished

## lost: the lump goes down into his body and its light with it; he sinks away
func swallow() -> void:
	unpin()
	var tw := create_tween()
	tw.tween_property(self, "_at", float(_n) + 1.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	_jaw = 0.0
	var away := create_tween()
	away.tween_property(self, "_sink", 1.0, 1.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await away.finished

# ---------------------------------------------------------------- drawing

func _draw() -> void:
	if board == null or _anch.is_empty(): return
	var TS: float = board.TS
	var W := _w()
	var fade := 1.0 - _sink
	var drop := Vector2(0, _sink * TS * 0.6)
	# the cells beside the lump: where a match knocks it back
	if _spit < 0.0 and _sink <= 0.0:
		var pulse := 0.5 + 0.5 * sin(_t * 4.0)
		for p: Vector2i in model.gulp_zone():
			var c := board.cell_center(float(p.x), float(p.y))
			var rr := Rect2(c - Vector2(TS, TS) * 0.46, Vector2(TS, TS) * 0.92)
			draw_rect(rr, Color(glow, 0.10 + 0.08 * pulse), true)
			draw_rect(rr, Color(glow, 0.55 + 0.35 * pulse), false, maxf(2.0, TS * 0.055))
	# the marked bite
	if not _mark.is_empty():
		var hot := 0.5 + 0.5 * sin(_t * (9.0 if _mark_left <= 1 else 5.0))
		var mc := Vector2.ZERO
		for p: Vector2i in _mark:
			var c := board.cell_center(float(p.x), float(p.y))
			mc += c
			draw_rect(Rect2(c - Vector2(TS, TS) * 0.48, Vector2(TS, TS) * 0.96), Color(1.0, 0.25, 0.2, 0.12 + 0.14 * hot), true)
		mc /= float(_mark.size())
		draw_rect(Rect2(mc - Vector2(TS, TS) * 0.98, Vector2(TS, TS) * 1.96), Color(1.0, 0.3, 0.22, 0.6 + 0.4 * hot), false, maxf(2.5, TS * 0.07))
		# teeth round the mark, and the moves left to it
		for i in 8:
			var a := TAU * i / 8.0 + PI / 8.0
			var q := mc + Vector2(cos(a), sin(a)) * TS * 1.05
			var tip := mc + Vector2(cos(a), sin(a)) * TS * (0.78 - 0.08 * hot)
			var side := Vector2(-sin(a), cos(a)) * TS * 0.1
			draw_colored_polygon(PackedVector2Array([q + side, q - side, tip]), Color(1.0, 0.94, 0.86, 0.9))
		var f := ThemeDB.fallback_font
		var txt := str(_mark_left)
		var fs := int(TS * 0.7)
		var sz := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		draw_string_outline(f, mc + Vector2(-sz.x / 2, sz.y * 0.32), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0.1, 0.02, 0.02, 0.9))
		draw_string(f, mc + Vector2(-sz.x / 2, sz.y * 0.32), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.9, 0.8))
	# his body past the belly end of the neck, half out of the picture
	var bd: Vector2 = (_on_neck(float(_n) + 1.0)[0] as Vector2) + drop
	draw_set_transform(bd + Vector2(-TS * 0.9, -TS * 0.3), -0.25, Vector2(1.9, 1.25))
	draw_circle(Vector2.ZERO, TS * 1.02, Color(INK, fade))
	draw_circle(Vector2.ZERO, TS * 0.95, Color(SKIN, fade))
	draw_circle(Vector2(0, TS * 0.25), TS * 0.7, Color(SKIN_LO, 0.5 * fade))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# a flipper, paddling
	var fl := bd + Vector2(-TS * 0.2, TS * 0.55)
	var sw := sin(_t * 1.6) * 0.3
	draw_set_transform(fl, 0.9 + sw, Vector2.ONE)
	draw_colored_polygon(PackedVector2Array([Vector2(-TS * 0.22, 0), Vector2(TS * 0.22, 0), Vector2(TS * 0.12, TS * 1.25), Vector2(-TS * 0.1, TS * 1.3)]), Color(SKIN_LO, fade))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# the neck: shadow, outline, skin, the pale underside towards the board, spots
	var step := 0.25
	var pts: Array = []
	var f0 := -1.0
	while f0 <= float(_n) + 1.0 + 0.001:
		pts.append([f0, _on_neck(f0)])
		f0 += step
	# (the head reaching out drags the first of the neck after it)
	var reach := _head_off.length() > 1.0
	for layer in 4:
		for i in pts.size() - 1:
			var fa: float = pts[i][0]
			var pa: Vector2 = (pts[i][1][0] as Vector2) + drop
			var pb: Vector2 = (pts[i + 1][1][0] as Vector2) + drop
			var na: Vector2 = pts[i][1][1]
			if reach and fa < 1.0:
				var k := 1.0 - clampf((fa + 1.0) / 2.0, 0.0, 1.0)
				pa += _head_off * k
				pb += _head_off * (1.0 - clampf((float(pts[i + 1][0]) + 1.0) / 2.0, 0.0, 1.0))
			var w := W * (0.78 + 0.5 * clampf(fa / float(_n), 0.0, 1.0))
			# the lump swells the neck where it lies
			var near := absf(fa - _at)
			if near < 1.0 and _spit < 0.0: w *= 1.0 + 0.45 * (1.0 - near)
			match layer:
				0:
					draw_line(pa + Vector2(3, 5), pb + Vector2(3, 5), Color(0, 0, 0, 0.3 * fade), w + 6.0, true)
				1:
					draw_line(pa, pb, Color(INK, fade), w + 5.0, true)
					draw_circle(pa, (w + 5.0) / 2.0, Color(INK, fade))
				2:
					draw_line(pa, pb, Color(SKIN.lerp(Color(1.0, 0.5, 0.4), 0.35 * minf(1.0, _hurt)), fade), w, true)
					draw_circle(pa, w / 2.0, Color(SKIN.lerp(Color(1.0, 0.5, 0.4), 0.35 * minf(1.0, _hurt)), fade))
				3:
					draw_line(pa - na * w * 0.3, pb - na * w * 0.3, Color(BELLY, 0.55 * fade), w * 0.2, true)
					if i % 3 == 0: draw_circle(pa + na * w * 0.18, w * 0.13, Color(SKIN_LO, 0.9 * fade))
					if i % 3 == 1: draw_circle(pa + na * w * 0.05, w * 0.08, Color(SKIN_HI, 0.8 * fade))
	# which way the lump is going: faint marks towards the belly
	# the find in his neck: its light through the skin
	if _spit < 0.0 and _at <= float(_n) + 0.5:
		var lp: Vector2 = (_on_neck(_at)[0] as Vector2) + drop
		if reach and _at < 1.0: lp += _head_off * (1.0 - clampf((_at + 1.0) / 2.0, 0.0, 1.0))
		var br := 0.75 + 0.25 * sin(_t * 5.0)
		var r := W * 0.62
		GemArt.radial_disc(self, lp, r * 3.4, Color(glow, 0.5 * br * fade), Color(glow, 0.18 * fade), Color(glow, 0))
		draw_circle(lp, r, Color(glow.lerp(Color.WHITE, 0.35), 0.95 * fade))
		draw_circle(lp + Vector2(-r * 0.25, -r * 0.3), r * 0.35, Color(1, 1, 1, 0.9 * fade))
		if _flash > 0.0:
			GemArt.radial_disc(self, lp, r * (4.0 + 5.0 * (1.0 - _flash)), Color(1, 1, 1, 0.8 * _flash), Color(glow, 0.4 * _flash), Color(glow, 0))
	# the harpoon standing in his neck, its rope to the board
	if _pin_k > 0.0:
		var hn := _on_neck(_at)
		var hp: Vector2 = (hn[0] as Vector2) + drop
		var nrm: Vector2 = hn[1]
		var tail := hp - nrm * TS * 0.95 * _pin_k
		draw_line(tail, hp + nrm * W * 0.3, Color(0.05, 0.04, 0.03, 0.9), 5.0, true)
		draw_line(tail, hp + nrm * W * 0.3, Color("#c9b48a"), 2.6, true)
		draw_colored_polygon(PackedVector2Array([hp + nrm * W * 0.55, hp - nrm.orthogonal() * W * 0.22, hp + nrm.orthogonal() * W * 0.22]), Color("#d8dde2"))
		var rope := PackedVector2Array()
		for i in 9:
			var k := i / 8.0
			rope.append(tail.lerp(tail - nrm * TS * 0.5 + nrm.orthogonal() * TS * 0.5, k) + Vector2(0, sin(k * PI) * TS * 0.18))
		draw_polyline(rope, Color("#8a744e"), 2.0, true)
	# the head
	_draw_head(head_home() + _head_off + drop, fade)
	# the find flying out of his mouth onto the board
	if _spit >= 0.0:
		var from := head_home() + Vector2(-TS * 0.6, TS * 0.2)
		var to := board.cell_center(float(model.R) / 2.0 - 0.5, float(model.C) / 2.0 - 0.5)
		var p := from.lerp(to, _spit) + Vector2(0, -sin(_spit * PI) * TS * 1.6)
		var r := TS * (0.3 + 0.5 * _spit)
		GemArt.radial_disc(self, p, r * 4.0, Color(glow, 0.6), Color(glow, 0.2), Color(glow, 0))
		draw_circle(p, r, Color(glow.lerp(Color.WHITE, 0.4), 1.0))
		draw_circle(p + Vector2(-r * 0.25, -r * 0.3), r * 0.35, Color(1, 1, 1, 0.9))

func _draw_head(at: Vector2, fade: float) -> void:
	var TS: float = board.TS
	var L := TS * 2.3          # the skull's length, snout to the left
	var H := TS * 0.8
	var bob := sin(_t * 1.3) * TS * 0.04
	draw_set_transform(at + Vector2(0, bob), -0.08 + _head_turn + sin(_t * 0.9) * 0.03, Vector2.ONE)
	var gape := _jaw * 0.55
	# the lower jaw, hinged at the back
	draw_set_transform(at + Vector2(0, bob), -0.08 + _head_turn + sin(_t * 0.9) * 0.03 - gape, Vector2.ONE)
	var jaw := PackedVector2Array([Vector2(TS * 0.25, H * 0.05), Vector2(-L * 0.78, H * 0.1), Vector2(-L * 0.74, H * 0.36), Vector2(TS * 0.2, H * 0.5)])
	draw_colored_polygon(jaw, Color(INK, fade))
	draw_colored_polygon(PackedVector2Array([Vector2(TS * 0.2, H * 0.1), Vector2(-L * 0.74, H * 0.14), Vector2(-L * 0.7, H * 0.3), Vector2(TS * 0.16, H * 0.42)]), Color(BELLY.darkened(0.25), fade))
	for i in 6:
		var x := -L * 0.7 + i * L * 0.12
		draw_colored_polygon(PackedVector2Array([Vector2(x, H * 0.12), Vector2(x + L * 0.05, H * 0.12), Vector2(x + L * 0.025, -H * 0.16)]), Color(1.0, 0.96, 0.88, fade))
	# the skull
	draw_set_transform(at + Vector2(0, bob), -0.08 + _head_turn + sin(_t * 0.9) * 0.03 + gape * 0.5, Vector2.ONE)
	var sk := PackedVector2Array([Vector2(TS * 0.42, -H * 0.2), Vector2(TS * 0.1, -H * 0.82), Vector2(-L * 0.35, -H * 0.72), Vector2(-L * 0.86, -H * 0.3), Vector2(-L * 0.9, H * 0.02), Vector2(TS * 0.3, H * 0.12)])
	var ol := PackedVector2Array()
	for q in sk: ol.append(q * 1.07 + Vector2(-L * 0.02, -H * 0.03))
	draw_colored_polygon(ol, Color(INK, fade))
	draw_colored_polygon(sk, Color(SKIN.lerp(Color(1.0, 0.5, 0.4), 0.35 * minf(1.0, _hurt)), fade))
	draw_colored_polygon(PackedVector2Array([Vector2(TS * 0.05, -H * 0.74), Vector2(-L * 0.35, -H * 0.66), Vector2(-L * 0.8, -H * 0.3), Vector2(-L * 0.3, -H * 0.45)]), Color(SKIN_HI, 0.7 * fade))
	for i in 7:
		var x := -L * 0.84 + i * L * 0.12
		draw_colored_polygon(PackedVector2Array([Vector2(x, H * 0.02), Vector2(x + L * 0.05, H * 0.03), Vector2(x + L * 0.025, H * 0.34)]), Color(1.0, 0.96, 0.88, fade))
	# the eye: amber, a slit; shut tight when hurt
	var e := Vector2(-L * 0.18, -H * 0.36)
	if _hurt > 0.6:
		draw_line(e + Vector2(-TS * 0.1, 0), e + Vector2(TS * 0.1, 0), Color(INK, fade), 3.0, true)
	else:
		draw_circle(e, TS * 0.12, Color(INK, fade))
		draw_circle(e, TS * 0.095, Color(1.0, 0.72, 0.2, fade))
		draw_line(e + Vector2(0, -TS * 0.08), e + Vector2(0, TS * 0.08), Color(INK, fade), 2.4, true)
	draw_circle(Vector2(-L * 0.8, -H * 0.2), TS * 0.03, Color(INK, fade))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
