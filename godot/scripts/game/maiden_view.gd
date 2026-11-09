class_name MaidenView
extends Node2D
## The Fire Maiden on the board (docs/fire-maiden.md): a little girl of flame standing on a stone, dancing; she leaps
## in an arc to one of the cells marked ahead (small flames on them), flinches when caught, laughs and runs off at the
## end. Frames: assets/maiden/<anim>_<i>.png (GPT sheet, art/maiden/cut.py); without them a flame drawn here.
## A child of the BoardView: positions are the board's cell centres.

const DIR := "res://assets/maiden/"
const ANIMS := {dance = 6, jump = 6, caught = 3, laugh = 3, run = 6}
const FPS := {dance = 8.0, jump = 12.0, caught = 10.0, laugh = 8.0, run = 12.0}
const H := 1.45            # her height, in cells
const FOOT := 0.32         # her feet below the cell's centre, in cells

var board: BoardView
var cell := Vector2i.ZERO
var marks: Array = []
var anim := "dance"
var t := 0.0               # time in the current animation
var loop := true
var fade := 1.0
var _frames := {}
var _sparks: Array = []    # [position, velocity, life]
var _hop_from := Vector2.ZERO
var _hop_to := Vector2.ZERO
var _hop_k := -1.0         # 0..1 while in the air

func setup(b: BoardView, at: Vector2i) -> void:
	board = b
	cell = at
	z_index = 20
	position = Vector2.ZERO
	for a in ANIMS:
		var fr: Array = []
		for i in int(ANIMS[a]):
			var p := DIR + "%s_%d.png" % [a, i]
			if ResourceLoader.exists(p): fr.append(load(p))
		_frames[a] = fr

func _feet() -> Vector2:
	if _hop_k >= 0.0:
		var p := _hop_from.lerp(_hop_to, _hop_k)
		return p + Vector2(0, -sin(_hop_k * PI) * board.TS * (1.2 + 0.08 * _hop_from.distance_to(_hop_to) / board.TS))
	return board.cell_center(cell.x, cell.y) + Vector2(0, board.TS * FOOT)

func play(a: String, looping := false) -> void:
	anim = a
	t = 0.0
	loop = looping

func _process(dt: float) -> void:
	t += dt
	var n := int(ANIMS[anim])
	if not loop and t * float(FPS[anim]) >= n: t = (n - 0.01) / float(FPS[anim])
	# sparks fly off her all the time, more in the air
	if randf() < (0.9 if _hop_k >= 0.0 else 0.35):
		var at := _feet() + Vector2(randf_range(-0.25, 0.25), -randf_range(0.2, 1.1)) * board.TS
		_sparks.append([at, Vector2(randf_range(-20, 20), randf_range(-70, -30)), randf_range(0.5, 1.0)])
	for s in _sparks:
		s[0] += s[1] * dt
		s[1].y += 20.0 * dt
		s[2] -= dt
	_sparks = _sparks.filter(func(s: Array) -> bool: return float(s[2]) > 0.0)
	queue_redraw()

func _draw() -> void:
	var TS: float = board.TS
	var tm := Time.get_ticks_msec() / 1000.0
	# the next leaps: a small flame flickering on each marked cell
	for p: Vector2i in marks:
		var c := board.cell_center(p.x, p.y)
		var fl := 0.8 + 0.2 * sin(tm * 9.0 + p.x * 1.7 + p.y)
		draw_circle(c, TS * 0.42, Color(1.0, 0.45, 0.1, 0.16 * fade))
		draw_arc(c, TS * 0.4, 0, TAU, 28, Color(1.0, 0.7, 0.3, 0.75 * fade), maxf(1.5, TS * 0.045), true)
		_flame(c + Vector2(0, TS * 0.18), TS * 0.32 * fl, 0.85 * fade)
	var ft := _feet()
	# her light on the stones under her
	for i in 3:
		draw_circle(ft + Vector2(0, -TS * 0.3), TS * (0.95 - i * 0.25), Color(1.0, 0.55, 0.15, (0.06 + i * 0.05) * fade))
	for s in _sparks:
		var k := float(s[2])
		draw_circle(s[0], maxf(1.0, TS * 0.035 * k), Color(1.0, 0.8 * k + 0.2, 0.3 * k, k * fade))
	var fr: Array = _frames.get(anim, [])
	if fr.size():
		var i := clampi(int(t * float(FPS[anim])) % fr.size() if loop else int(t * float(FPS[anim])), 0, fr.size() - 1)
		var tx: Texture2D = fr[i]
		var h := TS * H
		var w := h * tx.get_width() / float(tx.get_height())
		draw_texture_rect(tx, Rect2(ft - Vector2(w / 2.0, h), Vector2(w, h)), false, Color(1, 1, 1, fade))
	else:
		# no drawing yet: a dancing tongue of flame
		var sway := sin(tm * 7.0) * 0.12
		_flame(ft + Vector2(0, -TS * 0.05), TS * H * 0.62, fade, sway)
		draw_circle(ft + Vector2(sway * TS * 0.5, -TS * 0.55), TS * 0.17, Color(1.0, 0.95, 0.7, fade))

## a tongue of fire: rounded base, a point leaning with `sway`
func _flame(base: Vector2, h: float, a: float, sway := 0.0) -> void:
	var pts := PackedVector2Array()
	for i in 17:
		var u := float(i) / 16.0 * TAU
		var x := sin(u) * 0.36
		var y := -0.5 + cos(u) * 0.5
		# the top half drawn up to a point
		if y < -0.5:
			var k := (-0.5 - y) / 0.5
			x *= 1.0 - k * 0.85
			y = -0.5 - k * 0.5 - k * k * 0.3
		pts.append(base + Vector2(x * h + sway * h * (-y), y * h))
	draw_colored_polygon(pts, Color(1.0, 0.42, 0.08, 0.85 * a))
	var inner := PackedVector2Array()
	for p in pts: inner.append(base + (p - base) * 0.6 + Vector2(0, -h * 0.02))
	draw_colored_polygon(inner, Color(1.0, 0.85, 0.35, 0.9 * a))

## the leap to a cell, in an arc
func hop(to: Vector2i, dur := 0.5) -> void:
	_hop_from = _feet()
	cell = to
	_hop_to = board.cell_center(to.x, to.y) + Vector2(0, board.TS * FOOT)
	play("jump")
	_hop_k = 0.0
	var tw := create_tween()
	tw.tween_method(func(k: float): _hop_k = k, 0.0, 1.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	_hop_k = -1.0
	for i in 14:
		_sparks.append([_feet() + Vector2(randf_range(-0.3, 0.3), -0.1) * board.TS, Vector2(randf_range(-90, 90), randf_range(-120, -40)), randf_range(0.4, 0.9)])
	await get_tree().create_timer(0.12).timeout
	play("dance", true)

## caught: she flinches, sparks fly
func caught() -> void:
	play("caught")
	for i in 30:
		_sparks.append([_feet() + Vector2(0, -0.6) * board.TS, Vector2(randf_range(-160, 160), randf_range(-180, 40)), randf_range(0.5, 1.1)])
	await get_tree().create_timer(0.45).timeout
	play("laugh")
	await get_tree().create_timer(0.35).timeout

## her laugh: a trill of little bells running down (a fairy's laugh, as games have it), n notes
func giggle(n := 6) -> void:
	for i in n:
		Sfx.play("mdn_giggle", i)
		await get_tree().create_timer(0.065 + randf() * 0.02).timeout

## the end: she laughs, and dashes off the board fading into smoke
func run_away() -> void:
	play("laugh")
	await get_tree().create_timer(0.7).timeout
	play("run")
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "fade", 0.0, 0.8)
	tw.tween_property(self, "position:x", board.TS * 3.0, 0.8)
	await tw.finished
