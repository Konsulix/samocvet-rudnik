class_name GulpView
extends Node2D
## The plesiosaur's hunt on the board (BoardModel.gulp, CLAUDE.md 22.11): one beast lying round the board. His head, in
## three-quarter view, hangs over the board's top left and looks down at it; his neck leaves the head and runs along
## the top to the right, down the right side and back along the bottom into his body, which lies under the board's
## bottom left with a flipper out. The swallowed find is a lump of light in the neck.
## Pixel art in the bosses' style (art/boss/src/plesio/gen2.sh, art/boss/export_plesio.py -> assets/boss/plesio/):
## the head (shut and gaping), the body, one straight piece of neck repeated end to end and bent round the board (Bend).
## Drawn here: the neck with the lump riding in it, the cells beside the lump lit (where to strike), "+N" as it is
## knocked, the 2x2 his head has marked with the moves left to it, the head's lunge and bite, the find spat out (won)
## or gone down (lost). Bar: the scale on the level's plate, belly to mouth.

var board: BoardView
var model: BoardModel
var glow := Color("#9be8ff")     # the find's own colour (its rarity)
var _anch: Array = []            # [index on the track (fractions at the corners), point, outward normal]
var _n := 0
var _at := 0.0                   # where the lump is drawn (eased towards the model's)
var _t := 0.0
var _gape := 0.0                 # 0 the head as it hangs, 1 jaws wide (its other picture)
var _head_off := Vector2.ZERO    # the head away from its place (a lunge)
var _head_k := 1.0
var _flash := 0.0
var _mark: Array = []
var _mark_left := 0
var _spit := -1.0                # 0..1: the find flying out of his mouth
var _sink := 0.0                 # 0..1: he goes under (lost, or off after the find is out)
var _hurt := 0.0
var _pops: Array = []            # ["+2", where, age, big]

const DIR := "res://assets/boss/plesio/"
var _neck: Texture2D
var _head: Texture2D
var _head_open: Texture2D
var _body: Texture2D
var _info := {}

func setup(b: BoardView, m: BoardModel) -> void:
	board = b
	model = m
	z_index = 20
	position = Vector2.ZERO
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists(DIR + "neck.png"):
		_neck = load(DIR + "neck.png")
		_info = JSON.parse_string(FileAccess.get_file_as_string(DIR + "plesio.json"))
	if ResourceLoader.exists(DIR + "head.png"): _head = load(DIR + "head.png")
	if ResourceLoader.exists(DIR + "head_open.png"): _head_open = load(DIR + "head_open.png")
	if ResourceLoader.exists(DIR + "body.png"): _body = load(DIR + "body.png")
	_build()
	_at = float(m.gulp.at)

## the neck's thickness on the screen (its drawing is NECK_PT thick)
func _w() -> float:
	return board.TS * 0.7

## the parts' scale: the head and the body are drawn with necks as thick as the neck's piece
func _k() -> float:
	return _w() / float(_info.get("neck_pt", 26))

func _build() -> void:
	_anch = []
	var tr: Array = model.gulp.track
	_n = tr.size()
	var d := board.TS * 0.5 + _w() * 0.3
	var R: int = model.R
	var C: int = model.C
	var n1 := C - C / 2                    # along the top, then down the right side, then back along the bottom
	for i in _n:
		var p: Vector2i = tr[i]
		var out := Vector2.UP if i < n1 else Vector2.RIGHT if i < n1 + R - 1 else Vector2.DOWN
		if not _anch.is_empty():
			var last: Array = _anch[_anch.size() - 1]
			var lo: Vector2 = last[2]
			if lo != out:
				# a corner of the board: the neck goes round it
				var cp: Vector2 = board.cell_center(float(tr[i - 1].x), float(tr[i - 1].y)) + (lo + out) * d * 0.86
				_anch.append([i - 0.5, cp, (lo + out).normalized()])
		_anch.append([float(i), board.cell_center(float(p.x), float(p.y)) + out * d, out])
	# past the mouth: on into the head; past the last place: on into the body
	var a0: Array = _anch[0]
	_anch.push_front([-1.0, (a0[1] as Vector2) + Vector2(-board.TS, 0), Vector2.UP])
	var an: Array = _anch[_anch.size() - 1]
	# (the neck dips away from the board's edge as it goes: his body lies clear of the bottom row)
	_anch.append([float(_n), (an[1] as Vector2) + Vector2(-board.TS * 1.1, board.TS * 0.5), Vector2.DOWN])

## a place on the neck: [point, outward normal]
func _on_neck(f: float) -> Array:
	f = clampf(f, -1.0, float(_n))
	for i in _anch.size() - 1:
		var a: Array = _anch[i]
		var b: Array = _anch[i + 1]
		if f <= float(b[0]):
			var k := inverse_lerp(float(a[0]), float(b[0]), f)
			return [(a[1] as Vector2).lerp(b[1], k), (a[2] as Vector2).lerp(b[2], k).normalized()]
	var z: Array = _anch[_anch.size() - 1]
	return [z[1], z[2]]

## where the neck meets the head (the head's neck end sits here), and the body
func head_joint() -> Vector2:
	return _on_neck(-1.0)[0]

func body_joint() -> Vector2:
	return _on_neck(float(_n))[0]

func _process(dt: float) -> void:
	_t += dt
	_flash = maxf(0.0, _flash - dt * 2.5)
	_hurt = maxf(0.0, _hurt - dt * 1.6)
	for p: Array in _pops: p[2] = float(p[2]) + dt
	_pops = _pops.filter(func(p: Array) -> bool: return float(p[2]) < 1.1)
	queue_redraw()

# ---------------------------------------------------------------- what happens

## the lump rides to its new place
func move_lump(to: int, dur := 0.32) -> void:
	if is_equal_approx(_at, float(to)): return
	var tw := create_tween()
	tw.tween_property(self, "_at", float(to), dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished

## knocked back towards the mouth by n places: a flash at the lump, "+n" over it, he flinches
func knock(hard: bool, n: int) -> void:
	_flash = 1.0
	_hurt = 1.0 if hard else 0.5
	_pops.append(["+%d" % n, (_on_neck(_at)[0] as Vector2), 0.0, hard])

func set_mark(cells: Array, left: int) -> void:
	_mark = cells
	_mark_left = left

## his head comes down on the marked stones and takes them: `taken` is called as the jaws shut
func bite(cells: Array, choke: bool, taken: Callable) -> void:
	_mark = []
	if cells.is_empty():
		taken.call()
		return
	var c := Vector2.ZERO
	for p: Vector2i in cells: c += board.cell_center(float(p.x), float(p.y))
	c /= float(cells.size())
	var to := c - _mouth()
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "_gape", 1.0, 0.16)
	tw.tween_property(self, "_head_off", to, 0.36).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "_head_k", 1.12, 0.36)
	await tw.finished
	_gape = 0.0
	taken.call()
	if choke:
		# it went off in his mouth: he rears back, shaking
		_flash = 1.0
		_hurt = 1.8
		_pops.append(["+%d" % int(model.gulp.cfg.choke_up), c, 0.0, true])
		var ct := create_tween()
		for i in 5:
			ct.tween_property(self, "_head_off", to + Vector2(randf_range(-10, 10), randf_range(-14, 4)), 0.06)
			ct.parallel().tween_property(self, "_gape", 1.0 if i % 2 == 0 else 0.0, 0.06)
		await ct.finished
	else:
		await get_tree().create_timer(0.14).timeout
	var bk := create_tween()
	bk.set_parallel(true)
	bk.tween_property(self, "_head_off", Vector2.ZERO, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bk.tween_property(self, "_head_k", 1.0, 0.45)
	bk.tween_property(self, "_gape", 0.0, 0.3)
	await bk.finished

## won: the lump runs up into his mouth, he gags and the find flies out onto the board; then he goes under
func spit() -> void:
	var tw := create_tween()
	tw.tween_property(self, "_at", -1.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(self, "_gape", 1.0, 0.3)
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
	var tw := create_tween()
	tw.tween_property(self, "_at", float(_n), 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	_spit = -2.0      # (the light is out)
	var away := create_tween()
	away.tween_property(self, "_sink", 1.0, 1.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await away.finished

# ---------------------------------------------------------------- drawing

## the head's picture laid with its neck end on the joint: its place on the screen
func _head_rect() -> Rect2:
	if _head == null: return Rect2(head_joint(), Vector2.ZERO)
	var k := _k() * float(_info.get("head_k", 1.0)) * _head_k
	var sz := _head.get_size() * k
	var ex := Vector2(float(_info.get("head_exit_x", _head.get_width())), float(_info.get("head_exit_y", _head.get_height() * 0.8))) * k
	var bob := Vector2(0, sin(_t * 1.3) * board.TS * 0.05)
	return Rect2(head_joint() + Vector2(board.TS * 0.25, 0) - ex + _head_off + bob, sz)

## his mouth on the screen as he hangs (what comes down on the bitten stones, where the find flies out of)
func _mouth() -> Vector2:
	var r := _head_rect()
	return r.position - _head_off + r.size * Vector2(float(_info.get("mouth_x", 0.3)), float(_info.get("mouth_y", 0.75)))

## the neck's line from f0 to f1 on the track (the head reaching out drags its first places after it)
func _line(f0: float, f1: float, drop: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	var f := f0
	while true:
		var p: Vector2 = (_on_neck(f)[0] as Vector2) + drop
		if f < 2.0: p += _head_off * pow(1.0 - clampf((f + 1.0) / 3.0, 0.0, 1.0), 1.5)
		out.append(p)
		if f >= f1: break
		f = minf(f1, f + 0.2)
	return out

## how thick the neck is at a place: it breathes a little, and swells where the lump lies
func _thick(f: float) -> float:
	var w := _w() * (1.0 + 0.04 * sin(_t * 1.7 - f * 0.9))
	var near := absf(f - _at)
	if near < 1.1 and _spit < 0.0 and _spit > -1.5: w *= 1.0 + 0.32 * (1.0 - near / 1.1)
	return w

func _draw() -> void:
	if board == null or _anch.is_empty(): return
	var TS: float = board.TS
	var W := _w()
	var fade := 1.0 - _sink
	var drop := Vector2(0, _sink * TS * 0.8)
	var lit := _spit < 0.0 and _spit > -1.5 and _sink <= 0.0
	# the cells beside the lump: where a match knocks it back
	if lit:
		var pulse := 0.5 + 0.5 * sin(_t * 4.0)
		for p: Vector2i in model.gulp_zone():
			var c := board.cell_center(float(p.x), float(p.y))
			var rr := Rect2(c - Vector2(TS, TS) * 0.46, Vector2(TS, TS) * 0.92)
			draw_rect(rr, Color(glow, 0.10 + 0.08 * pulse), true)
			draw_rect(rr, Color(glow, 0.55 + 0.35 * pulse), false, maxf(2.0, TS * 0.06))
	# the marked bite: his teeth closing round it, the moves left to it
	if not _mark.is_empty():
		var hot := 0.5 + 0.5 * sin(_t * (9.0 if _mark_left <= 1 else 5.0))
		var mc := Vector2.ZERO
		for p: Vector2i in _mark: mc += board.cell_center(float(p.x), float(p.y))
		mc /= float(_mark.size())
		draw_rect(Rect2(mc - Vector2(TS, TS) * 0.98, Vector2(TS, TS) * 1.96), Color(0.5, 0.02, 0.04, 0.22 + 0.16 * hot), true)
		var px := maxf(2.0, roundf(TS / 12.0))     # (the teeth on the bosses' own grid: squares, not smooth lines)
		for side in 4:
			var dir: Vector2 = [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT][side]
			var along := dir.orthogonal()
			for k in 5:
				var base := mc + dir * TS * 1.02 + along * (k - 2.0) * TS * 0.4
				var ln := 4 + (1 if k % 2 == 0 else 0) - int(hot * 1.5)
				for j in ln:
					var wd := maxf(1.0, 3.0 - j * 0.6)
					var q := base - dir * px * j
					draw_rect(Rect2(q - Vector2(px, px) * wd * 0.5, Vector2(px, px) * wd).abs(), Color("#1a0a0c") if j == 0 else Color("#e9dfc4").darkened(0.08 * j))
		var f := UI.display
		var txt := str(_mark_left)
		var fs := int(TS * 0.8)
		var sz := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		draw_string_outline(f, mc + Vector2(-sz.x / 2, sz.y * 0.3), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, Color(0.12, 0.02, 0.02, 0.95))
		draw_string(f, mc + Vector2(-sz.x / 2, sz.y * 0.3), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("#f2e3c0"))
	var tint := Color(1, 1, 1, fade).lerp(Color(1.0, 0.72, 0.66, fade), 0.5 * minf(1.0, _hurt))
	# his body under the board's corner, the neck running into it
	if _body:
		var k := _k() * float(_info.get("body_k", 1.0))
		var ex := Vector2(float(_info.get("body_exit_x", _body.get_width())), float(_info.get("body_exit_y", _body.get_height() * 0.2))) * k
		var sway := Vector2(sin(_t * 0.8) * 2.0, sin(_t * 1.1) * 1.5)
		var at := body_joint() + Vector2(TS * 0.25, 0) - ex + drop + sway
		draw_texture_rect(_body, Rect2(at + Vector2(4, 6), _body.get_size() * k), false, Color(0, 0, 0, 0.35 * fade))
		draw_texture_rect(_body, Rect2(at, _body.get_size() * k), false, tint)
	if _neck:
		# the neck: the one drawing laid end to end along its line (every second piece mirrored: no seam), its back
		# outwards, its pale underside to the board; its shadow on the board under it
		var th := float(_neck.get_height())
		var piece := float(_neck.get_width()) / th * W * 1.24 / TS      # a piece's length, in places of the track
		for pass_n in 2:
			var f0 := -1.0
			var k := 0
			while f0 < float(_n):
				var f1 := minf(f0 + piece, float(_n))
				var a := f0
				var b := f1
				var pts := _line(f0, f1, drop + (Vector2(-4, 7) if pass_n == 0 else Vector2.ZERO))
				var u1 := (f1 - f0) / piece
				Bend.draw(self, pts, func(q: float) -> float: return _thick(lerpf(a, b, q)) * 0.5 * 1.24,
					_neck, 1.0 if k % 2 == 1 else 0.0, (1.0 - u1) if k % 2 == 1 else u1, false,
					Color(0, 0, 0, 0.45 * fade) if pass_n == 0 else tint)
				f0 = f1
				k += 1
	# the find in his neck: its light through the hide
	if _spit < 0.0 and _spit > -1.5:
		var lp: Vector2 = (_on_neck(_at)[0] as Vector2) + drop
		if _at < 2.0: lp += _head_off * pow(1.0 - clampf((_at + 1.0) / 3.0, 0.0, 1.0), 1.5)
		var br := 0.75 + 0.25 * sin(_t * 5.0)
		var r := W * 0.5
		GemArt.radial_disc(self, lp, r * 5.2, Color(glow, 0.5 * br * fade), Color(glow, 0.2 * fade), Color(glow, 0))
		GemArt.radial_disc(self, lp, r * 1.7, Color(glow.lerp(Color.WHITE, 0.7), 0.95 * fade), Color(glow, 0.7 * br * fade), Color(glow, 0))
		draw_circle(lp, r * 0.42, Color(1, 1, 1, 0.9 * fade))
		if _flash > 0.0:
			GemArt.radial_disc(self, lp, r * (4.0 + 6.0 * (1.0 - _flash)), Color(1, 1, 1, 0.8 * _flash), Color(glow, 0.4 * _flash), Color(glow, 0))
	# the head over it all
	if _head:
		var hr := _head_rect()
		hr.position += drop
		var tx: Texture2D = _head
		if _gape > 0.5 and _head_open:
			# (the gaping head is a bigger picture: laid so that its skull stays where the shut one's is)
			tx = _head_open
			var hk := hr.size.x / float(_head.get_width())
			hr = Rect2(hr.position + Vector2(float(_info.get("open_dx", 0.0)), float(_info.get("open_dy", 0.0))) * hk, _head_open.get_size() * hk)
		draw_texture_rect(tx, Rect2(hr.position + Vector2(-5, 8), hr.size), false, Color(0, 0, 0, 0.4 * fade))
		draw_texture_rect(tx, hr, false, tint)
	# "+2": what a knock was worth
	for p: Array in _pops:
		var age: float = p[2]
		var big: bool = p[3]
		var fs := int(TS * (0.85 if big else 0.62))
		var at: Vector2 = (p[1] as Vector2) + Vector2(0, -TS * (0.5 + age * 1.1))
		var al := clampf((1.1 - age) / 0.35, 0.0, 1.0)
		var f := UI.display
		var sz := f.get_string_size(String(p[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		at.x = clampf(at.x - sz.x / 2, 4.0, board.size.x - sz.x - 4.0)
		draw_string_outline(f, at, String(p[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, Color(0.02, 0.06, 0.08, al))
		draw_string(f, at, String(p[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(glow.lerp(Color.WHITE, 0.5), al))
	# the find flying out of his mouth onto the board
	if _spit >= 0.0:
		var from := _mouth()
		var to := board.cell_center(float(model.R) / 2.0 - 0.5, float(model.C) / 2.0 - 0.5)
		var p := from.lerp(to, _spit) + Vector2(0, -sin(_spit * PI) * TS * 1.6)
		var r := TS * (0.3 + 0.5 * _spit)
		GemArt.radial_disc(self, p, r * 4.0, Color(glow, 0.6), Color(glow, 0.2), Color(glow, 0))
		draw_circle(p, r, Color(glow.lerp(Color.WHITE, 0.4), 1.0))
		draw_circle(p + Vector2(-r * 0.25, -r * 0.3), r * 0.35, Color(1, 1, 1, 0.9))

## The scale on the level's plate: his belly at the left, his mouth at the right, the find's light between - where it
## stands, which way is out, how near the belly is
class Bar:
	extends Control
	var model: BoardModel
	var glow := Color("#9be8ff")
	var _shown := -1.0

	func _process(dt: float) -> void:
		if model == null or model.gulp.is_empty(): return
		var at := float(model.gulp.at)
		_shown = at if _shown < 0.0 else lerpf(_shown, at, minf(1.0, dt * 8.0))
		queue_redraw()

	func _draw() -> void:
		if model == null or model.gulp.is_empty(): return
		var n: int = (model.gulp.track as Array).size()
		var f := UI.body_bold
		var x0 := 46.0
		var x1 := size.x - 50.0
		var y := size.y * 0.42
		draw_string(f, Vector2(4, y + 5), "BELLY", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#c9584a"))
		draw_string(f, Vector2(x1 + 8, y + 5), "MOUTH", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(glow, 0.95))
		draw_line(Vector2(x0, y), Vector2(x1, y), Color(0, 0, 0, 0.55), 8.0)
		draw_line(Vector2(x0, y), Vector2(lerpf(x0, x1, 0.3), y), Color("#7a2a22"), 4.0)
		draw_line(Vector2(lerpf(x0, x1, 0.3), y), Vector2(x1, y), Color("#3d5560"), 4.0)
		for i in n:
			var x := lerpf(x1, x0, float(i) / float(n - 1))
			draw_rect(Rect2(x - 1, y - 4, 2, 8), Color(1, 1, 1, 0.22))
		var px := lerpf(x1, x0, clampf(_shown / float(n - 1), 0.0, 1.0))
		var pulse := 0.75 + 0.25 * sin(Time.get_ticks_msec() / 1000.0 * 5.0)
		GemArt.radial_disc(self, Vector2(px, y), 15.0, Color(glow, 0.6 * pulse), Color(glow, 0.2), Color(glow, 0))
		draw_circle(Vector2(px, y), 5.0, Color(glow.lerp(Color.WHITE, 0.6), 1.0))
		# what to do, in a line
		var hint := "Match in the lit cells: push the light to his mouth"
		var sz := f.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
		draw_string(f, Vector2((size.x - sz.x) / 2, size.y - 3), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.55))
