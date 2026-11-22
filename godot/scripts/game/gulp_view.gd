class_name GulpView
extends Node2D
## The plesiosaur's hunt on the board (BoardModel.gulp, CLAUDE.md 22.11): his neck is the board's frame, and the fight
## climbs it over three boards, the neck zigzagging up - the belly (his body under the board's bottom left, the neck
## along the bottom and up the right side), the neck (in at the bottom right, up the left side), the throat (in at
## the bottom left, round the right side and along the top to his head, big, in three-quarter view over the board's
## top left). The swallowed find is a lump of light in the neck.
## Pixel art in the bosses' style, drawn pixel for pixel on their 1-pt grid (art/boss/src/plesio/gen*.sh,
## art/boss/export_plesio.py -> assets/boss/plesio/): one straight piece of neck repeated end to end and bent round
## the board (Bend), the head in five moods (plain, blinking, hurt, glaring before a bite, jaws wide), the body, the
## ring of teeth that marks a bite.
## Drawn here: the neck with the lump riding in it, the cells beside the lump lit (where to strike), "+N" as it is
## knocked, the bite - its ring on the 2x2 (still, then throbbing with one move to go), the jaws' snap - the find
## spat out (won) or gone down (lost), the climb from board to board. Bar: the scale on the level's plate.

var board: BoardView
var model: BoardModel
var glow := Color("#9be8ff")     # the find's own colour (its rarity)
var _anch: Array = []            # [index on the track (the bends and the ends between and past the cells), point, outward normal]
var _track: Array = []           # this board's cells as drawn (the model is a step ahead while a climb plays)
var _stage := 0
var _n := 0
var _f0 := -1.0                  # the neck's line from here ...
var _f1 := 1.0                   # ... to here, in places of the track
var _flip := false               # the drawing's back on the line's other side (the board whose neck runs the other way round)
var _at := 0.0                   # where the lump is drawn (eased towards the model's)
var _t := 0.0
var _gape := 0.0                 # the jaws wide (his other picture)
var _head_off := Vector2.ZERO
var _flash := 0.0
var _mark: Array = []
var _mark_left := 0
var _snap := -1.0                # the bite's ring shutting: 0..1, then _burst
var _snap_c := Vector2.ZERO
var _burst := -1.0               # the ring after the snap: fading (a plain bite) or flying apart (a special went off in it)
var _burst_big := false
var _spit := -1.0                # 0..1: the find flying out of his mouth; -2: its light out (lost)
var _sink := 0.0                 # 0..1: he goes under (lost, or off after the find is out)
var _hurt := 0.0
var _blink := 0.0
var _blink_in := 2.0
var _pops: Array = []            # ["+2", where, age, big]
var _bits: Array = []            # [pos, vel, life, colour, size]: what flies from a bite
var _home := Vector2.ZERO
var _homed := false

const DIR := "res://assets/boss/plesio/"
var _neck: Texture2D
var _heads := {}
var _body: Texture2D
var _maw: Texture2D
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
	for nm in ["head", "head_blink", "head_hurt", "head_glare", "head_open"]:
		if ResourceLoader.exists(DIR + nm + ".png"): _heads[nm] = load(DIR + nm + ".png")
	if ResourceLoader.exists(DIR + "body.png"): _body = load(DIR + "body.png")
	if ResourceLoader.exists(DIR + "maw.png"): _maw = load(DIR + "maw.png")
	_build()
	_at = float(m.gulp.at)

## the neck's thickness on the screen: its drawing's own, pixel for pixel
func _w() -> float:
	return float(_info.get("neck_pt", 26))

## this board's stretch of neck as a line: the cells' places, an arc at each corner, and the ends running on - into
## his head or his body, or off the screen to the board above / below
func _build() -> void:
	_anch = []
	_stage = int(model.gulp.stage)
	_track = (model.gulp.track as Array).duplicate()
	var sides: Array = model.gulp.sides
	_n = _track.size()
	_flip = _stage == 1
	var TS: float = board.TS
	var d := TS * 0.5 + _w() * 0.36          # the neck lies on the board's own rim, a little over the cells' edge
	var rad := TS * 0.62
	for i in _n:
		var p: Vector2i = _track[i]
		var out := Vector2(sides[i])
		if not _anch.is_empty():
			var lo: Vector2 = (_anch[_anch.size() - 1] as Array)[2]
			if lo != out:
				var cc: Vector2 = board.cell_center(float(_track[i - 1].x), float(_track[i - 1].y)) + (lo + out) * (d - rad)
				for j in range(1, 6):
					var a := PI * 0.5 * j / 6.0
					var nrm := (lo * cos(a) + out * sin(a)).normalized()
					_anch.append([i - 1.0 + j / 6.0, cc + nrm * rad, nrm])
		_anch.append([float(i), board.cell_center(float(p.x), float(p.y)) + out * d, out])
	var a0: Vector2 = (_anch[0] as Array)[1]
	var an: Vector2 = (_anch[_anch.size() - 1] as Array)[1]
	var front: Array = []       # the line on past the top end, going away from it
	var back: Array = []        # ... past the bottom end
	match _stage:
		0:
			front = _curve(a0, a0 + Vector2(0, -TS * 2.0), a0 + Vector2(TS * 2.4, -TS * 2.3))
			back = [an + Vector2(-TS * 1.1, TS * 0.5)]
		1:
			front = _curve(a0, a0 + Vector2(0, -TS * 2.0), a0 + Vector2(-TS * 2.4, -TS * 2.3))
			back = [an + Vector2(TS * 2.6, 0)]
		_:
			front = [a0 + Vector2(-TS * 2.0, 0)]
			back = [an + Vector2(-TS * 2.6, 0)]
	var prev := a0
	var f := 0.0
	for q: Vector2 in front:
		f -= prev.distance_to(q) / TS
		_anch.push_front([f, q, _out_of(q - prev, true)])
		prev = q
	_f0 = f
	prev = an
	f = float(_n - 1)
	for q: Vector2 in back:
		f += prev.distance_to(q) / TS
		_anch.append([f, q, _out_of(q - prev, false)])
		prev = q
	_f1 = f

func _curve(a: Vector2, c: Vector2, b: Vector2) -> Array:
	var out: Array = []
	for i in range(1, 8):
		var k := i / 7.0
		out.append(a.lerp(c, k).lerp(c.lerp(b, k), k))
	return out

## the outward side of a stretch going `dir` (towards the front: against the line's own run)
func _out_of(dir: Vector2, to_front: bool) -> Vector2:
	var run := (-dir if to_front else dir).normalized()
	return run.orthogonal() * (-1.0 if _flip else 1.0)

## a place on the neck: [point, outward normal]
func _on_neck(f: float) -> Array:
	f = clampf(f, _f0, _f1)
	for i in _anch.size() - 1:
		var a: Array = _anch[i]
		var b: Array = _anch[i + 1]
		if f <= float(b[0]):
			var k := inverse_lerp(float(a[0]), float(b[0]), f)
			return [(a[1] as Vector2).lerp(b[1], k), (a[2] as Vector2).lerp(b[2], k).normalized()]
	var z: Array = _anch[_anch.size() - 1]
	return [z[1], z[2]]

## where the neck comes out from behind the head: the head's neck end sits here
func head_joint() -> Vector2:
	return _on_neck(0.25)[0]

func _process(dt: float) -> void:
	_t += dt
	_flash = maxf(0.0, _flash - dt * 2.5)
	_hurt = maxf(0.0, _hurt - dt * 1.4)
	_blink = maxf(0.0, _blink - dt)
	_blink_in -= dt
	if _blink_in <= 0.0:
		_blink = 0.13
		_blink_in = 0.3 if randf() < 0.2 else randf_range(2.2, 5.0)      # (now and then twice in a row)
	for p: Array in _pops: p[2] = float(p[2]) + dt
	_pops = _pops.filter(func(p: Array) -> bool: return float(p[2]) < 1.1)
	for b: Array in _bits:
		b[1] = (b[1] as Vector2) + Vector2(0, 620.0) * dt
		b[0] = (b[0] as Vector2) + (b[1] as Vector2) * dt
		b[2] = float(b[2]) - dt
	_bits = _bits.filter(func(b: Array) -> bool: return float(b[2]) > 0.0)
	queue_redraw()

# ---------------------------------------------------------------- what happens

## the lump rides to its new place on this board (past an end: on out of it)
func move_lump(to: float, dur := 0.32) -> void:
	if is_equal_approx(_at, to): return
	var tw := create_tween()
	tw.tween_property(self, "_at", to, dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished

## knocked back towards the mouth by n places: a flash at the lump, "+n" over it, he winces
func knock(hard: bool, n: int) -> void:
	_flash = 1.0
	_hurt = 0.9 if hard else 0.45
	_pops.append(["+%d" % n, (_on_neck(_at)[0] as Vector2), 0.0, hard])

func set_mark(cells: Array, left: int) -> void:
	_mark = cells
	_mark_left = left

## the climb to the board above (up) or the slip to the one below: this stretch of neck slides out of the picture,
## the next one comes in from the other side, the lump at its new place
func restage(up: bool) -> void:
	if not _homed:
		_home = position
		_homed = true
	var far := board.TS * 4.0 * (1.0 if up else -1.0)
	var out := create_tween().set_parallel(true)
	out.tween_property(self, "position:y", _home.y + far, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	out.tween_property(self, "modulate:a", 0.0, 0.3)
	await out.finished
	_mark = []
	_build()
	_at = float(model.gulp.at)
	position.y = _home.y - far
	var inn := create_tween().set_parallel(true)
	inn.tween_property(self, "position:y", _home.y, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	inn.tween_property(self, "modulate:a", 1.0, 0.25)
	await inn.finished
	_flash = 1.0

## his bite, where he hangs: the jaws gape, the ring of teeth on the marked stones tightens and snaps shut - `taken`
## is called on the snap - and the stones burst out of it; a special among them goes off in his mouth
func bite(cells: Array, choke: bool, taken: Callable) -> void:
	_mark = []
	if cells.is_empty():
		taken.call()
		return
	var c := Vector2.ZERO
	for p: Vector2i in cells: c += board.cell_center(float(p.x), float(p.y))
	c /= float(cells.size())
	_snap_c = c
	_snap = 0.0
	_burst = -1.0
	# he rears a little and gapes ...
	_gape = 1.0
	var up := create_tween()
	up.tween_property(self, "_head_off", Vector2(4, -9), 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await up.finished
	await get_tree().create_timer(0.08).timeout
	# ... and snaps: the head jerks down, the ring shuts
	var sn := create_tween().set_parallel(true)
	sn.tween_property(self, "_snap", 1.0, 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	sn.tween_property(self, "_head_off", Vector2(-5, 10), 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await sn.finished
	_gape = 0.0
	taken.call()
	_flash = 1.0
	var TS: float = board.TS
	for i in (34 if choke else 20):
		var a := randf() * TAU
		var sp := randf_range(120.0, 420.0) * (1.5 if choke else 1.0)
		var col: Color = [Color("#e9dfc4"), glow.lerp(Color.WHITE, 0.4), Color("#7fb3c2"), Color("#b3261e")][i % 4]
		if choke and i % 3 == 0: col = Color("#ffb347")
		_bits.append([c + Vector2(cos(a), sin(a)) * TS * 0.5, Vector2(cos(a), sin(a)) * sp + Vector2(0, -160), randf_range(0.35, 0.75), col, randf_range(2.0, 5.0)])
	_snap = -1.0
	_burst = 0.0
	_burst_big = choke
	if choke:
		# it went off in his mouth: the ring flies apart, he recoils shaking, eyes shut
		_hurt = 2.2
		_pops.append(["+%d" % int(model.gulp.cfg.choke_up), c, 0.0, true])
		var ct := create_tween()
		ct.tween_property(self, "_burst", 1.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		var sh := create_tween()
		for i in 7:
			sh.tween_property(self, "_head_off", Vector2(randf_range(-9, 9), randf_range(-12, 3)), 0.055)
		await sh.finished
		if ct.is_running(): await ct.finished
	else:
		var ft := create_tween()
		ft.tween_property(self, "_burst", 1.0, 0.22)
		await ft.finished
	_burst = -1.0
	var bk := create_tween()
	bk.tween_property(self, "_head_off", Vector2.ZERO, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await bk.finished

## won: the lump runs up into his mouth, he gags and the find flies out onto the board; then he goes under
func spit() -> void:
	var tw := create_tween()
	tw.tween_property(self, "_at", _f0 + 0.6, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	_gape = 1.0
	_flash = 1.0
	_spit = 0.0
	var st := create_tween()
	st.tween_property(self, "_spit", 1.0, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await st.finished
	_gape = 0.0
	_hurt = 3.0
	var away := create_tween()
	away.tween_property(self, "_sink", 1.0, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await away.finished

## lost: the lump goes down into his body and its light with it; he sinks away
func swallow() -> void:
	var tw := create_tween()
	tw.tween_property(self, "_at", _f1, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	_spit = -2.0      # (the light is out)
	var away := create_tween()
	away.tween_property(self, "_sink", 1.0, 1.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await away.finished

# ---------------------------------------------------------------- drawing

## which of his faces: jaws wide in a bite, wincing when knocked, glaring with a bite one move off, a blink, plain
func _mood() -> String:
	if _gape > 0.5 and _heads.has("head_open"): return "head_open"
	if _hurt > 0.3 and _heads.has("head_hurt"): return "head_hurt"
	if not _mark.is_empty() and _mark_left <= 1 and _heads.has("head_glare"): return "head_glare"
	if _blink > 0.0 and _heads.has("head_blink"): return "head_blink"
	return "head"

## the head's picture laid with its neck end on the joint: its top left on the screen (pixel for pixel)
func _head_at() -> Vector2:
	var ex := Vector2(float(_info.get("head_exit_x", 178)), float(_info.get("head_exit_y", 86)))
	var bob := Vector2(0, roundf(sin(_t * 1.3) * 2.0))
	# (hurt: he shudders)
	var shake := Vector2(roundf(sin(_t * 47.0) * 2.0), 0) * clampf(_hurt, 0.0, 1.0)
	return (head_joint() - ex + _head_off + bob + shake).round()

## his mouth on the screen (where the find flies out of)
func _mouth() -> Vector2:
	var sz := Vector2(178, 120)
	if _heads.has("head"): sz = (_heads["head"] as Texture2D).get_size()
	return _head_at() + sz * Vector2(float(_info.get("mouth_x", 0.2)), float(_info.get("mouth_y", 0.78)))

func _line(f0: float, f1: float, drop: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	var f := f0
	while true:
		out.append((_on_neck(f)[0] as Vector2) + drop)
		if f >= f1: break
		f = minf(f1, f + 0.2)
	return out

## how thick the neck is at a place: out of the head as thick as the head's own neck, thinning to the frame's along
## the first places; swollen where the lump lies
func _thick(f: float) -> float:
	var w := _w()
	if _stage >= 2: w *= lerpf(float(_info.get("head_k", 1.5)), 1.0, smoothstep(0.2, 3.6, f))
	var near := absf(f - _at)
	if near < 1.1 and _spit < 0.0 and _spit > -1.5: w *= 1.0 + 0.3 * (1.0 - near / 1.1)
	return w

## the neck's drawing laid end to end along its line from `from` on (every second piece mirrored: no seam)
func _draw_neck(from: float, drop: Vector2, col: Color) -> void:
	var th := float(_neck.get_height())
	var W := _w()
	var piece := float(_neck.get_width()) / board.TS      # a piece's length, in places of the track
	var f0 := _f0
	var k := 0
	while f0 < _f1:
		var f1 := minf(f0 + piece, _f1)
		var a := maxf(f0, from)
		if a < f1:
			var b := f1
			var ua := (a - f0) / piece
			var ub := (f1 - f0) / piece
			if k % 2 == 1:
				ua = 1.0 - ua
				ub = 1.0 - ub
			Bend.draw(self, _line(a, b, drop), func(q: float) -> float: return _thick(lerpf(a, b, q)) * 0.5 * th / W, _neck, ua, ub, _flip, col)
		f0 = f1
		k += 1

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
		var mid := int(roundf(_at))
		for i in range(mid - 1, mid + 2):
			if i < 0 or i >= _n: continue
			var p: Vector2i = _track[i]
			var c := board.cell_center(float(p.x), float(p.y))
			var rr := Rect2(c - Vector2(TS, TS) * 0.46, Vector2(TS, TS) * 0.92)
			draw_rect(rr, Color(glow, 0.10 + 0.08 * pulse), true)
			draw_rect(rr, Color(glow, 0.55 + 0.35 * pulse), false, maxf(2.0, TS * 0.06))
	# the snap: the ring shuts on the stones, then fades - or flies apart, if a special went off in it
	if _maw and (_snap >= 0.0 or _burst >= 0.0):
		var k := 0.58
		var al := 1.0
		if _snap >= 0.0: k = lerpf(1.08, 0.58, _snap)
		elif _burst_big:
			k = lerpf(0.58, 1.9, _burst)
			al = 1.0 - _burst
		else:
			al = 1.0 - _burst
		var ms := _maw.get_size() * (TS / 37.0) * k
		draw_rect(Rect2(_snap_c - Vector2(TS, TS), Vector2(TS, TS) * 2.0), Color(0.45, 0.02, 0.04, 0.4 * al), true)
		draw_texture_rect(_maw, Rect2(_snap_c - ms * 0.5, ms), false, Color(1, 1, 1, al))
		if _burst >= 0.0:
			var fc := Color("#ffb347") if _burst_big else Color.WHITE
			GemArt.radial_disc(self, _snap_c, TS * (1.2 + 2.6 * _burst) * (1.6 if _burst_big else 1.0), Color(fc, 0.85 * (1.0 - _burst)), Color(fc, 0.3 * (1.0 - _burst)), Color(fc, 0))
	var tint := Color(1, 1, 1, fade).lerp(Color(1.0, 0.74, 0.68, fade), 0.45 * minf(1.0, _hurt))
	# his body under the first board's corner, the neck running into it
	if _body and _stage == 0:
		var ex := Vector2(float(_info.get("body_exit_x", _body.get_width())), float(_info.get("body_exit_y", 24)))
		var at := ((_on_neck(_f1)[0] as Vector2) + Vector2(10, 0) - ex + drop + Vector2(0, roundf(sin(_t * 1.1) * 1.5))).round()
		draw_texture(_body, at + Vector2(-4, 7), Color(0, 0, 0, 0.4 * fade))
		draw_texture(_body, at, tint)
	if _neck:
		# (on the last board the neck begins where the head's own neck ends: nothing of it under the head)
		var nf := 0.0 if _stage >= 2 else _f0
		_draw_neck(nf, drop + Vector2(-4, 7), Color(0, 0, 0, 0.45 * fade))
		_draw_neck(nf, drop, tint)
	# his head on the last board, and the neck again over its neck's cut end: the joint lies under the hide
	if _stage >= 2 and _heads.has("head"):
		var tx: Texture2D = _heads[_mood()]
		var at := _head_at() + drop
		draw_texture(tx, at + Vector2(-5, 8), Color(0, 0, 0, 0.4 * fade))
		draw_texture(tx, at, tint)
		if _neck: _draw_neck(0.02, drop, tint)
	# the marked bite: the ring of his teeth round the square - still with two moves to go, throbbing with one
	if not _mark.is_empty() and _maw:
		var soon := _mark_left <= 1
		var hot := (0.5 + 0.5 * sin(_t * 11.0)) if soon else 0.0
		var mc := Vector2.ZERO
		for p: Vector2i in _mark: mc += board.cell_center(float(p.x), float(p.y))
		mc /= float(_mark.size())
		draw_rect(Rect2(mc - Vector2(TS, TS), Vector2(TS, TS) * 2.0), Color(0.45, 0.02, 0.04, 0.16 + 0.22 * hot), true)
		var ms := _maw.get_size() * (TS / 37.0) * (1.0 + 0.05 * hot)
		var mcol := Color(1.0, 1.0 - 0.14 * hot, 1.0 - 0.14 * hot) if soon else Color(1, 1, 1, 0.9)
		draw_texture_rect(_maw, Rect2(mc - ms * 0.5, ms), false, mcol)
	# the find in his neck: its light through the hide
	if _spit < 0.0 and _spit > -1.5:
		var lp: Vector2 = (_on_neck(_at)[0] as Vector2) + drop
		var br := 0.75 + 0.25 * sin(_t * 5.0)
		var r := W * 0.5
		GemArt.radial_disc(self, lp, r * 5.2, Color(glow, 0.5 * br * fade), Color(glow, 0.2 * fade), Color(glow, 0))
		GemArt.radial_disc(self, lp, r * 1.7, Color(glow.lerp(Color.WHITE, 0.7), 0.95 * fade), Color(glow, 0.7 * br * fade), Color(glow, 0))
		draw_circle(lp, r * 0.42, Color(1, 1, 1, 0.9 * fade))
		if _flash > 0.0:
			GemArt.radial_disc(self, lp, r * (4.0 + 6.0 * (1.0 - _flash)), Color(1, 1, 1, 0.8 * _flash), Color(glow, 0.4 * _flash), Color(glow, 0))
	# what flies from a bite: teeth-white, blood, water, the find's light - squares, on the same grid
	for b: Array in _bits:
		var sz: float = roundf(float(b[4]))
		var al := clampf(float(b[2]) / 0.25, 0.0, 1.0)
		draw_rect(Rect2(((b[0] as Vector2) - Vector2(sz, sz) * 0.5).round(), Vector2(sz, sz)), Color(b[3] as Color, al))
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

## The map on the level's plate, in the hunt ribbon's make (brass beads): his neck in three rows, zigzagging up as the
## boards do - the belly's row at the bottom from the left, the neck's back from the right, the throat's at the top
## out to his teeth. A bead a place; the find's light on its own; the beads it has still to climb are bright
class Bar:
	extends Control
	var model: BoardModel
	var glow := Color("#9be8ff")
	var maw: Texture2D
	var _shown := -1.0

	func _ready() -> void:
		if ResourceLoader.exists(GulpView.DIR + "maw.png"): maw = load(GulpView.DIR + "maw.png")

	func _process(dt: float) -> void:
		if model == null or model.gulp.is_empty(): return
		var at := float(model.gulp_overall()[0])
		_shown = at if _shown < 0.0 else lerpf(_shown, at, minf(1.0, dt * 8.0))
		queue_redraw()

	func _bead(p: Vector2, gold: bool) -> void:
		draw_circle(p + Vector2(0.3, 0.5), 2.5, Color(0, 0, 0, 0.55))
		draw_circle(p, 2.0, Color("#d9a441") if gold else Color("#6b5633"))
		draw_circle(p + Vector2(-0.6, -0.6), 0.9, Color("#ffe9a8") if gold else Color("#a08a5c"))

	func _draw() -> void:
		if model == null or model.gulp.is_empty(): return
		var stages := int(model.gulp.cfg.stages)
		var x0 := 26.0
		var x1 := size.x - 34.0
		var rows: Array = []          # the places from the mouth on: [point, ...]
		for st in range(stages - 1, -1, -1):
			var n: int = (model.gulp_track(st)[0] as Array).size()
			var y := lerpf(size.y - 9.0, 9.0, float(st) / float(maxi(stages - 1, 1)))
			var to_right := st % 2 == 0          # (this row runs left to right, going up his neck)
			for i in n:
				var k := 1.0 - (i + 0.5) / float(n)      # (0 at the row's lower end .. 1 at its upper)
				rows.append(Vector2(lerpf(x0, x1, k if to_right else 1.0 - k), y))
		# the turns between the rows, and the two ends: his teeth, his belly
		var acc := 0
		for st in range(stages - 1, 0, -1):
			acc += (model.gulp_track(st)[0] as Array).size()
			var a: Vector2 = rows[acc - 1]
			var b: Vector2 = rows[acc]
			var out := 9.0 if a.x > size.x * 0.5 else -9.0
			for j in range(1, 4):
				var q := j / 4.0
				_bead(Vector2(a.x + out * sin(q * PI), lerpf(a.y, b.y, q)), _shown > acc - 0.5)
		var at := clampf(_shown, 0.0, float(rows.size() - 1))
		for i in rows.size():
			if absf(float(i) - at) < 0.6: continue
			_bead(rows[i], float(i) < at)
		var top: Vector2 = rows[0]
		if maw: draw_texture_rect(maw, Rect2(top + Vector2(5, -11), Vector2(22, 22)), false)
		var end: Vector2 = rows[rows.size() - 1]
		draw_circle(end + Vector2(-9, 0), 5.0, Color(0, 0, 0, 0.6))
		draw_circle(end + Vector2(-9, 0), 4.0, Color("#8e1f1a"))
		draw_circle(end + Vector2(-10.2, -1.2), 1.5, Color("#e2675a"))
		var i0 := int(floorf(at))
		var lp: Vector2 = (rows[i0] as Vector2).lerp(rows[mini(i0 + 1, rows.size() - 1)], at - float(i0))
		var pulse := 0.75 + 0.25 * sin(Time.get_ticks_msec() / 1000.0 * 5.0)
		GemArt.radial_disc(self, lp, 13.0, Color(glow, 0.6 * pulse), Color(glow, 0.2), Color(glow, 0))
		draw_circle(lp, 4.0, Color(glow.lerp(Color.WHITE, 0.6), 1.0))
