class_name GulpView
extends Node2D
## The plesiosaur's hunt on the board (BoardModel.gulp, CLAUDE.md 22.11): his neck lies round the board — the head over
## the top's middle, the neck along the top to the right, down the right side, back along the bottom and up the left
## into his body — and the swallowed find is a lump of light in it. Drawn in code for now (a playable draft: the
## rules came first): since 22.11 his pixel art - the bosses' style, GPT's drawings on the 1-pt grid
## (art/boss/src/plesio/gen.sh, art/boss/export_plesio.py -> assets/boss/plesio/): one straight piece of neck, repeated
## end to end and bent round the board (Bend), the skull and the lower jaw as two sprites (the jaw hinged here).
## Drawn: the neck with the lump riding in it, the cells beside the lump lit (where to
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

const DIR := "res://assets/boss/plesio/"
var _neck: Texture2D
var _skull: Texture2D
var _jaw_t: Texture2D
var _info := {}

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
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists(DIR + "neck.png"):
		_neck = load(DIR + "neck.png")
		_skull = load(DIR + "skull.png")
		_jaw_t = load(DIR + "jaw.png")
		_info = JSON.parse_string(FileAccess.get_file_as_string(DIR + "plesio.json"))
	_build()
	_at = float(m.gulp.at)

func _w() -> float:
	return board.TS * 0.62

func _build() -> void:
	_anch = []
	var tr: Array = model.gulp.track
	_n = tr.size()
	var d := board.TS * 0.5 + _w() * 0.36
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
	# (his body is out of the picture: the neck runs on up the left side and away past the screen's edge)
	_anch.append([float(_n), (an[1] as Vector2) + Vector2(0, -board.TS), Vector2.LEFT])
	_anch.append([float(_n) + 1.0, (an[1] as Vector2) + Vector2(-board.TS * 0.7, -board.TS * 1.9), Vector2(-0.7, -0.7).normalized()])
	_anch.append([float(_n) + 2.5, (an[1] as Vector2) + Vector2(-board.TS * 3.2, -board.TS * 2.3), Vector2.UP])

## a place on the neck: [point, outward normal]
func _on_neck(f: float) -> Array:
	f = clampf(f, -1.0, float(_n) + 2.5)
	for i in _anch.size() - 1:
		var a: Array = _anch[i]
		var b: Array = _anch[i + 1]
		if f <= float(b[0]):
			var k := inverse_lerp(float(a[0]), float(b[0]), f)
			return [(a[1] as Vector2).lerp(b[1], k), (a[2] as Vector2).lerp(b[2], k).normalized()]
	var z: Array = _anch[_anch.size() - 1]
	return [z[1], z[2]]

func head_home() -> Vector2:
	return (_on_neck(-1.0)[0] as Vector2) + Vector2(-board.TS * 0.1, -board.TS * 0.42)

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

## the neck's line from f0 to f1 on the track (the head reaching out drags its first places after it)
func _line(f0: float, f1: float, drop: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	var f := f0
	while true:
		var p: Vector2 = (_on_neck(f)[0] as Vector2) + drop
		if f < 1.5: p += _head_off * (1.0 - clampf((f + 1.0) / 2.5, 0.0, 1.0))
		out.append(p)
		if f >= f1: break
		f = minf(f1, f + 0.2)
	return out

## how thick the neck is at a place: thicker towards the body, swollen where the lump lies
func _thick(f: float) -> float:
	var w := _w() * (0.86 + 0.5 * clampf(f / float(_n), 0.0, 1.3))
	var near := absf(f - _at)
	if near < 1.1 and _spit < 0.0: w *= 1.0 + 0.38 * (1.0 - near / 1.1)
	return w

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
			draw_rect(rr, Color(glow, 0.08 + 0.07 * pulse), true)
			draw_rect(rr, Color(glow, 0.5 + 0.35 * pulse), false, maxf(2.0, TS * 0.055))
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
	var tint := Color(1, 1, 1, fade).lerp(Color(1.0, 0.55, 0.5, fade), 0.5 * minf(1.0, _hurt))
	if _neck:
		# the neck: the one drawing laid end to end along its line (every second piece mirrored: no seam), its back
		# outwards, its pale underside to the board; a shadow under it
		var th := float(_neck.get_height())
		var piece := float(_neck.get_width()) / th * W * 1.05 / TS      # a piece's length, in places of the track
		for pass_n in 2:
			var f0 := -1.0
			var k := 0
			while f0 < float(_n) + 2.5:
				var f1 := minf(f0 + piece, float(_n) + 2.5)
				var a := f0
				var b := f1
				var pts := _line(f0, f1, drop + (Vector2(3, 5) if pass_n == 0 else Vector2.ZERO))
				var u1 := (f1 - f0) / piece
				Bend.draw(self, pts, func(q: float) -> float: return _thick(lerpf(a, b, q)) * 0.5 * 1.24,
					_neck, 1.0 if k % 2 == 1 else 0.0, (1.0 - u1) if k % 2 == 1 else u1, false,
					Color(0, 0, 0, 0.4 * fade) if pass_n == 0 else tint)
				f0 = f1
				k += 1
	else:
		var pl := _line(-1.0, float(_n) + 2.5, drop)
		draw_polyline(pl, Color(INK, fade), W + 5.0, true)
		draw_polyline(pl, Color(SKIN, fade), W, true)
	# the find in his neck: its light through the hide
	if _spit < 0.0 and _at <= float(_n) + 0.5:
		var lp: Vector2 = (_on_neck(_at)[0] as Vector2) + drop
		if _at < 1.5: lp += _head_off * (1.0 - clampf((_at + 1.0) / 2.5, 0.0, 1.0))
		var br := 0.75 + 0.25 * sin(_t * 5.0)
		var r := W * 0.5
		GemArt.radial_disc(self, lp, r * 5.2, Color(glow, 0.5 * br * fade), Color(glow, 0.2 * fade), Color(glow, 0))
		GemArt.radial_disc(self, lp, r * 1.7, Color(glow.lerp(Color.WHITE, 0.7), 0.95 * fade), Color(glow, 0.7 * br * fade), Color(glow, 0))
		draw_circle(lp, r * 0.42, Color(1, 1, 1, 0.9 * fade))
		if _flash > 0.0:
			GemArt.radial_disc(self, lp, r * (4.0 + 5.0 * (1.0 - _flash)), Color(1, 1, 1, 0.8 * _flash), Color(glow, 0.4 * _flash), Color(glow, 0))
	# the harpoon standing in his neck, its rope back to the board
	if _pin_k > 0.0:
		var hn := _on_neck(_at)
		var hp: Vector2 = (hn[0] as Vector2) + drop
		var nrm: Vector2 = hn[1]
		var tail := hp - nrm * TS * 1.0 * _pin_k
		draw_line(tail, hp + nrm * W * 0.2, Color("#120d09"), 6.0)
		draw_line(tail, hp + nrm * W * 0.2, Color("#8c7a5a"), 3.0)
		draw_line(tail, tail + nrm * TS * 0.25, Color("#c9c2b0"), 3.0)
		var rope := PackedVector2Array()
		for i in 9:
			var k := i / 8.0
			rope.append(tail.lerp(tail - nrm * TS * 0.55 + nrm.orthogonal() * TS * 0.55, k) + Vector2(0, sin(k * PI) * TS * 0.2))
		draw_polyline(rope, Color("#120d09"), 4.0)
		draw_polyline(rope, Color("#a08a5c"), 2.0)
	# the head
	_draw_head(head_home() + _head_off + drop, tint)
	# the find flying out of his mouth onto the board
	if _spit >= 0.0:
		var from := head_home() + Vector2(-TS * 1.6, TS * 0.2)
		var to := board.cell_center(float(model.R) / 2.0 - 0.5, float(model.C) / 2.0 - 0.5)
		var p := from.lerp(to, _spit) + Vector2(0, -sin(_spit * PI) * TS * 1.6)
		var r := TS * (0.3 + 0.5 * _spit)
		GemArt.radial_disc(self, p, r * 4.0, Color(glow, 0.6), Color(glow, 0.2), Color(glow, 0))
		draw_circle(p, r, Color(glow.lerp(Color.WHITE, 0.4), 1.0))
		draw_circle(p + Vector2(-r * 0.25, -r * 0.3), r * 0.35, Color(1, 1, 1, 0.9))

## his head: the skull, its neck end on the neck's first place, the snout to the left; the lower jaw hinged at its back
func _draw_head(at: Vector2, tint: Color) -> void:
	if _skull == null: return
	var sk := _skull.get_size()
	var jw := _jaw_t.get_size()
	var k := _w() * 1.24 / float(_info.get("neck_pt", 26)) * 1.25      # the head a little big for his neck: it is the face of the fight
	var bob := sin(_t * 1.3) * board.TS * 0.04
	var rot := _head_turn * -0.9 + sin(_t * 0.9) * 0.03
	# (the skull's neck end, right middle, on `at`)
	var pivot := Vector2(sk.x * 0.92, sk.y * 0.55)
	var hinge := Vector2(float(_info.get("jaw_dx", 0.0)) + jw.x * 0.93, sk.y * 0.72)
	draw_set_transform(at + Vector2(0, bob), rot, Vector2(k, k))
	draw_set_transform_matrix(Transform2D(rot, Vector2(k, k), 0.0, at + Vector2(0, bob)) * Transform2D(-_jaw * 0.5, Vector2.ONE, 0.0, hinge - pivot))
	draw_texture(_jaw_t, Vector2(-jw.x * 0.93, -jw.y * 0.35), tint)
	draw_set_transform(at + Vector2(0, bob), rot + _jaw * 0.12, Vector2(k, k))
	draw_texture(_skull, -pivot, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
