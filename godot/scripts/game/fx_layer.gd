class_name FxLayer
extends Node2D
## Explosions, sparks, flying dynamite, lightning and goal icons, drawn above the board.
## Positions are in the board's local space; this layer sits exactly on top of the board.
## Colours above 1.0 bloom through the HDR glow pass.

var board: BoardView
var shake := 0.0
var _rings := []     # {pos, rad, t0, dur, col}
var _zaps := []      # {a, b, t0, pts}
var _flash := []     # {pos, r, t0, col}
var _was_busy := false

func cell(r: float, c: float) -> Vector2:
	return board.cell_center(r, c)

func _process(dt: float) -> void:
	# camera-style shake applied to the board and this layer together; at rest nothing is moved or redrawn
	if shake > 0.05:
		shake = maxf(0.0, shake * pow(0.02, dt))
		board.get_parent().position = Vector2(randf() - 0.5, randf() - 0.5) * shake
	elif shake > 0.0:
		shake = 0.0
		board.get_parent().position = Vector2.ZERO
	if _rings.size() or _flash.size() or _zaps.size() or _was_busy:
		queue_redraw()
	_was_busy = _rings.size() > 0 or _flash.size() > 0 or _zaps.size() > 0

func _draw() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for i in range(_rings.size() - 1, -1, -1):
		var g: Dictionary = _rings[i]
		var k: float = (now - g.t0) / g.dur
		if k >= 1.0:
			_rings.remove_at(i)
			continue
		var r: float = (0.4 + g.rad * 1.15) * board.TS * (1.0 - pow(1.0 - k, 3.0))
		draw_arc(g.pos, r, 0, TAU, 48, Color(g.col, (1.0 - k) * 0.9), board.TS * 0.18 * (1.0 - k) + 2.0, true)
		draw_circle(g.pos, r * 0.9, Color(g.col, (1.0 - k) * 0.12))
	for i in range(_flash.size() - 1, -1, -1):
		var f: Dictionary = _flash[i]
		var k: float = (now - f.t0) / 0.22
		if k >= 1.0:
			_flash.remove_at(i)
			continue
		GemArt.radial_disc(self, f.pos, f.r * (0.6 + k * 0.6), Color(f.col, 1.0 - k), Color(f.col, (1.0 - k) * 0.4), Color(f.col, 0))
	for i in range(_zaps.size() - 1, -1, -1):
		var z: Dictionary = _zaps[i]
		var k: float = (now - z.t0) / 0.28
		if k >= 1.0:
			_zaps.remove_at(i)
			continue
		var pts := PackedVector2Array()
		var segs := 9
		for s in segs + 1:
			var p: Vector2 = z.a.lerp(z.b, s / float(segs))
			if s > 0 and s < segs:
				p += Vector2(randf() - 0.5, randf() - 0.5) * board.TS * 0.35
			pts.append(p)
		draw_polyline(pts, (Color(0.6, 2.2, 3.0, 1.0 - k) if BoardSprites.gem_style != "" else Color(2.2, 1.6, 3.0, 1.0 - k)), 3.0, true)
		draw_polyline(pts, Color(1, 1, 1, 1.0 - k), 1.2, true)

# ---------------------------------------------------------------- particles

## a one-shot burst of chips or sparks
func burst(pos: Vector2, col: Color, amount: int, speed := 160.0, gravity := 520.0, size_px := 4.0, sparkle := false) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = amount
	p.lifetime = 0.7 if sparkle else 0.55
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.35
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, gravity)
	p.scale_amount_min = size_px * 0.5
	p.scale_amount_max = size_px
	p.angular_velocity_min = -360
	p.angular_velocity_max = 360
	var ramp := Gradient.new()
	if sparkle:
		ramp.set_color(0, Color(col.r * 2.4, col.g * 2.4, col.b * 2.4, 1))
		ramp.set_color(1, Color(col, 0))
	else:
		ramp.set_color(0, col)
		ramp.set_color(1, Color(col, 0))
	p.color_ramp = ramp
	add_child(p)
	p.emitting = true
	get_tree().create_timer(p.lifetime + 0.2).timeout.connect(p.queue_free)

## a blocker breaking: its own pieces (blocker_kit.py's shards) burst out, spin and fall away, then the dust
func shards(r: float, c: float, kind: String, col: Color) -> void:
	var at := cell(r, c)
	var ts := board.TS
	for k in 3:
		var s := Sprite2D.new()
		s.texture = BoardSprites.blocker("shards/%s_%d" % [kind, k])
		s.scale = Vector2.ONE * ts * BoardSprites.SPAN / float(s.texture.get_width())
		s.position = at
		s.material = BoardSprites.plain_material()
		add_child(s)
		var dir := Vector2.from_angle(-PI / 2 + (k - 1) * 1.1 + randf_range(-0.3, 0.3))
		var tw := create_tween().set_parallel()
		var dur := randf_range(0.45, 0.6)
		tw.tween_property(s, "position:x", at.x + dir.x * ts * 0.9, dur)
		tw.tween_property(s, "position:y", at.y + dir.y * ts * 0.45 + ts * 0.9, dur).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(s, "rotation", randf_range(-2.5, 2.5), dur)
		tw.tween_property(s, "scale", s.scale * 0.6, dur)
		tw.tween_property(s, "modulate:a", 0.0, dur * 0.5).set_delay(dur * 0.5)
		tw.chain().tween_callback(s.queue_free)
	debris(r, c, col, 6)

## the pickaxe booster: it swings in over the cell from up right, strikes, and drops away
func pickaxe(r: int, c: int) -> void:
	var at := cell(r, c)
	var ts := board.TS
	var pivot := Node2D.new()       # turns about the handle's foot, as a swing does
	pivot.position = at + Vector2(ts * 0.75, ts * 0.55)
	add_child(pivot)
	var s := Sprite2D.new()
	s.texture = BoardSprites.tex("pick")
	s.scale = Vector2.ONE * ts * BoardSprites.SPAN * 1.5 / float(s.texture.get_width())
	s.position = Vector2(-ts * 0.45, -ts * 0.7)
	s.material = BoardSprites.plain_material()
	pivot.add_child(s)
	pivot.rotation = 1.1
	pivot.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(pivot, "modulate:a", 1.0, 0.06)
	tw.tween_property(pivot, "rotation", -0.25, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		shake = maxf(shake, 6.0)
		flash(r, c, Color(2.0, 1.7, 1.2), 0.9)
		burst(at, Color("#b8a890"), 12, 220.0, 650.0, 4.5))
	tw.tween_property(pivot, "rotation", 0.15, 0.1)
	tw.tween_property(pivot, "modulate:a", 0.0, 0.18)
	tw.tween_callback(pivot.queue_free)

func debris(r: float, c: float, col: Color, amount := 10) -> void:
	burst(cell(r, c), col, amount, 170.0, 620.0, 4.5)

func sparkle(r: float, c: float, col: Color, amount := 24) -> void:
	burst(cell(r, c), col, amount, 230.0, 60.0, 3.0, true)

func flash(r: float, c: float, col: Color, size_cells := 1.6) -> void:
	_flash.append({pos = cell(r, c), r = board.TS * size_cells, t0 = Time.get_ticks_msec() / 1000.0, col = col})

# ---------------------------------------------------------------- big effects

func ring(r: float, c: float, rad: float, col := Color(2.0, 1.4, 0.6)) -> void:
	_rings.append({pos = cell(r, c), rad = rad, t0 = Time.get_ticks_msec() / 1000.0, dur = 0.45 + rad * 0.05, col = col})

func boom(r: int, c: int, rad: int) -> void:
	ring(r, c, rad)
	flash(r, c, Color(2.4, 1.6, 0.7), 1.2 + rad * 0.5)
	burst(cell(r, c), Color(1.0, 0.75, 0.35), 26 + rad * 6, 300.0 + rad * 40, 300.0, 5.0, true)
	burst(cell(r, c), Color("#6a5848"), 16, 220.0, 700.0, 5.0)
	shake = maxf(shake, 10.0 + rad * 2.0)

## dynamite shoots both ways along a row or column, with a fizzing trail
func rocket(sp: String, r: int, c: int) -> void:
	shake = maxf(shake, 4.0)
	var dirs := [Vector2i(0, 1), Vector2i(0, -1)] if sp == "rh" else [Vector2i(1, 0), Vector2i(-1, 0)]
	for d in dirs:
		var n := Node2D.new()
		n.position = cell(r, c)
		if BoardSprites.gem_style != "":
			# the stick itself flies, spinning end over end along its line
			var spr := Sprite2D.new()
			spr.texture = BoardSprites.tex(sp)
			spr.scale = Vector2.ONE * board.TS * BoardSprites.SPAN * 0.85 / float(spr.texture.get_width())
			spr.material = BoardSprites.plain_material()
			n.add_child(spr)
			var spin := create_tween()
			spin.tween_property(spr, "rotation", TAU * 1.5 * (1 if d.y + d.x > 0 else -1), 0.3)
		else:
			n.rotation = 0.0 if d.x == 0 else PI / 2
			n.draw.connect(func():
				n.draw_colored_polygon(GemArt.rrect(Vector2(-board.TS * 0.3, -board.TS * 0.1), Vector2(board.TS * 0.6, board.TS * 0.2), board.TS * 0.08), Color("#e0302a"))
				n.draw_circle(Vector2(board.TS * 0.32 * (1 if d.y + d.x > 0 else -1), 0), board.TS * 0.09, Color(3.0, 2.2, 0.8)))
		add_child(n)
		var trail := CPUParticles2D.new()
		trail.amount = 40
		trail.lifetime = 0.35
		trail.gravity = Vector2.ZERO
		trail.spread = 25
		trail.direction = Vector2(-d.y, -d.x)
		trail.initial_velocity_min = 30
		trail.initial_velocity_max = 80
		trail.scale_amount_min = 2
		trail.scale_amount_max = 4
		var ramp := Gradient.new()
		ramp.set_color(0, Color(3.0, 2.0, 0.6))
		ramp.set_color(1, Color(1, 0.3, 0.1, 0))
		trail.color_ramp = ramp
		n.add_child(trail)
		var far := 9.0
		var target := cell(r + d.x * far, c + d.y * far)
		var tw := create_tween()
		tw.tween_property(n, "position", target, far * 0.032 * 1.0).set_trans(Tween.TRANS_LINEAR)
		tw.finished.connect(n.queue_free)

func drill(r: int, c: int, tr: int, tc: int) -> void:
	var n := Node2D.new()
	n.position = cell(r, c)
	if BoardSprites.gem_style != "":
		# the auger flies point first towards its target, shuddering as it bores, throwing chips behind it
		var spr := Sprite2D.new()
		spr.texture = BoardSprites.tex("drill")
		spr.scale = Vector2.ONE * board.TS * BoardSprites.SPAN * 0.9 / float(spr.texture.get_width())
		spr.material = BoardSprites.plain_material()
		n.add_child(spr)
		n.rotation = (cell(tr, tc) - cell(r, c)).angle() - PI / 2     # the sprite points down: turn it to the target
		add_child(n)
		var shake := create_tween().set_loops(8)
		shake.tween_property(spr, "position:x", board.TS * 0.04, 0.025)
		shake.tween_property(spr, "position:x", -board.TS * 0.04, 0.025)
		var tw2 := create_tween()
		tw2.tween_property(n, "position", cell(tr, tc), 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw2.tween_callback(func():
			shake.kill()
			burst(cell(tr, tc), Color("#8a8f99"), 10, 200.0, 600.0, 4.0)
			n.queue_free())
		return
	n.draw.connect(func():
		GemArt.begin(n, Transform2D(0.0, Vector2(0.8, 0.8), 0.0, Vector2.ZERO))
		GemArt.special(n, "drill", board.TS)
		GemArt.end(n))
	add_child(n)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(n, "position", cell(tr, tc), 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(n, "rotation", TAU * 2, 0.42)
	tw.chain().tween_callback(n.queue_free)

func zap(r: int, c: int, tr: int, tc: int) -> void:
	_zaps.append({a = cell(r, c), b = cell(tr, tc), t0 = Time.get_ticks_msec() / 1000.0})
	sparkle(tr, tc, Color(0.45, 0.95, 1.0) if BoardSprites.gem_style != "" else Color(0.85, 0.65, 1.0), 6)

func pop_text(r: float, c: float, txt: String, col := Color("#ffb090")) -> void:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 5)
	l.position = cell(r, c) - Vector2(40, 12)
	l.size = Vector2(80, 24)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(l)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 46, 0.9).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.2)
	tw.chain().tween_callback(l.queue_free)

## an icon of what was collected flies into the goal panel (target in this layer's space)
## a round ore badge flying from a cell to the HUD
func fly_badge(r: float, c: float, target: Vector2, kind: String, on_land: Callable) -> void:
	var n := Node2D.new()
	var rad: float = board.TS * 0.26
	n.draw.connect(func(): Chrome.coin_icon(n, kind, Vector2.ZERO, rad))
	n.position = cell(r, c)
	add_child(n)
	var p0 := n.position
	var mid := p0.lerp(target, 0.5) + Vector2(randf_range(-40, 40), -60)
	var tw := create_tween()
	tw.tween_method(func(t: float):
		n.position = p0.lerp(mid, t).lerp(mid.lerp(target, t), t)
		n.scale = Vector2.ONE * lerpf(1.2, 0.8, t), 0.0, 1.0, 0.5 + randf() * 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.finished.connect(func():
		n.queue_free()
		on_land.call())

func fly_icon(r: float, c: float, target: Vector2, k: String, colour: int, glow: Color, on_land: Callable) -> void:
	var n := Node2D.new()
	var S := board.TS * 0.8
	n.position = cell(r, c)
	n.draw.connect(func():
		GemArt.begin(n, Transform2D.IDENTITY)
		GemArt.goal_icon(n, k, colour, S, glow))
	n.material = BoardSprites.plain_material()   # the stock shader draws no textures on iPhone (see Level)
	n.position -= Vector2(S, S) * 0.5
	add_child(n)
	var mid := n.position.lerp(target, 0.5) + Vector2(randf_range(-60, 60), -80)
	var tw := create_tween()
	var dur := 0.52 + randf() * 0.12
	tw.tween_method(func(t: float):
		n.position =(n.get_meta("p0") as Vector2).lerp(mid, t).lerp(mid.lerp(target - Vector2(S, S) * 0.5, t), t)
		n.scale = Vector2.ONE * lerpf(1.0, 0.6, t), 0.0, 1.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	n.set_meta("p0", n.position)
	tw.finished.connect(func():
		n.queue_free()
		on_land.call())
