class_name GalleryBg
extends Node2D
## The face of the gallery behind the board, by mine and depth: strata, crystal pockets, timber sets,
## rails, and two lanterns swinging on chains that really light the wall (PointLight2D under a dark CanvasModulate).

var area := 0
var depth := 0
var view := Vector2(390, 844)
var lamps: Array[Node2D] = []
var _t := 0.0
var _seed := 5
var _dust: CPUParticles2D
var _live: Node2D   # the parts that move: lanterns, twinkling pockets, glowing lava
var _pockets := []
var _lava := []

static func glow_texture(size_px := 256) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.add_point(0.35, Color(1, 1, 1, 0.45))
	g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = size_px
	t.height = size_px
	return t

func setup(a: int, dl: int, size: Vector2) -> void:
	area = a
	depth = dl
	view = size
	_seed = a * 131 + dl * 17 + 5
	for l in lamps: l.queue_free()
	lamps.clear()
	var fire := a == 2
	var tex := glow_texture()
	for k in 2:
		var pivot := Node2D.new()
		pivot.position = Vector2(view.x * (0.28 if k == 0 else 0.72), view.y * 0.08)
		add_child(pivot)
		var lamp := PointLight2D.new()
		lamp.texture = tex
		lamp.texture_scale = 5.0
		lamp.energy = 0.9
		lamp.color = Color("#ffb070") if fire else Color("#ffd28a")
		lamp.position = Vector2(0, view.y * 0.13)
		pivot.add_child(lamp)
		pivot.set_meta("phase", k * 1.7)
		lamps.append(pivot)
	if _live: _live.queue_free()
	_live = Node2D.new()
	_live.draw.connect(_draw_live)
	add_child(_live)
	if _dust: _dust.queue_free()
	_dust = CPUParticles2D.new()
	_dust.position = Vector2(view.x / 2, view.y * 0.45)
	_dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_dust.emission_rect_extents = Vector2(view.x / 2, view.y * 0.4)
	_dust.amount = 40
	_dust.lifetime = 9.0
	_dust.gravity = Vector2(0, 6)
	_dust.initial_velocity_min = 2
	_dust.initial_velocity_max = 10
	_dust.spread = 180
	_dust.scale_amount_min = 1.0
	_dust.scale_amount_max = 2.4
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 0.9, 0.7, 0))
	ramp.add_point(0.5, Color(1.4, 1.2, 0.9, 0.5))
	ramp.set_color(ramp.get_point_count() - 1, Color(1, 0.9, 0.7, 0))
	_dust.color_ramp = ramp
	_dust.preprocess = 9.0
	add_child(_dust)
	queue_redraw()

func _process(dt: float) -> void:
	_t += dt
	for p in lamps:
		var ph: float = p.get_meta("phase")
		p.rotation = sin(_t * 1.9 + ph) * 0.09
		var lamp: PointLight2D = p.get_child(0)
		lamp.energy = 0.9 + sin(_t * 7.3 + ph * 3.0) * 0.05 + sin(_t * 13.1 + ph) * 0.035
	if _live: _live.queue_redraw()

func _mix(a: Color, b: Color, t: float) -> Color:
	return a.lerp(b, t)

func _draw() -> void:
	var W := view.x
	var H := view.y
	var t := depth / 4.0
	var fire := area == 2
	var cu := area == 1
	var wall: Array = [Color("#4a2a22"), Color("#24100c")] if fire else [Color("#2e4038"), Color("#121a18")] if cu else [Color("#4e4034"), Color("#1a1410")]
	var top := _mix(wall[0], Color.BLACK, 0.25 + t * 0.3)
	var mid := _mix(wall[0], Color("#5a1a08") if fire else Color.BLACK, t * 0.35)
	var bot := _mix(wall[1], Color.BLACK, t * 0.3)
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(W, 0), Vector2(W, H * 0.35), Vector2(0, H * 0.35)]), PackedColorArray([top, top, mid, mid]))
	draw_polygon(PackedVector2Array([Vector2(0, H * 0.35), Vector2(W, H * 0.35), Vector2(W, H), Vector2(0, H)]), PackedColorArray([mid, mid, bot, bot]))
	var rng := Rng32.new(_seed)
	_lava.clear()
	_pockets.clear()
	# strata
	for k in 7:
		var y := 90 + k * 105 + rng.next() * 30
		var amp := 8 + rng.next() * 14
		var ph := rng.next() * 6.0
		var pts := PackedVector2Array()
		for x in range(-10, int(W) + 30, 20):
			pts.append(Vector2(x, y + sin(x * 0.015 + ph) * amp + x * 0.06))
		for x in range(int(W) + 20, -30, -20):
			pts.append(Vector2(x, y + 40 + sin(x * 0.015 + ph) * amp + x * 0.06))
		draw_colored_polygon(pts, Color(0, 0, 0, 0.05) if k % 2 else Color(1, 1, 1, 0.04))
	for k in 240:
		draw_circle(Vector2(rng.next() * W, rng.next() * H), 0.6 + rng.next() * 2.2, Color(0, 0, 0, 0.12) if rng.next() < 0.5 else Color(1, 1, 1, 0.08))
	# lava cracks in the fiery mine
	if fire:
		for k in 5:
			var p := Vector2(rng.next() * W, 200 + rng.next() * 500)
			var line := PackedVector2Array([p])
			for q in 6:
				p += Vector2((rng.next() - 0.5) * 50, 15 + rng.next() * 25)
				line.append(p)
			_lava.append(line)
	# crystal pockets with the mine's own minerals
	var pool: Dictionary = Data.AREAS[area].pool
	var ids := pool.keys()
	ids.sort_custom(func(a, b): return pool[a] > pool[b])
	ids = ids.slice(0, 6)
	for k in 4 + depth * 2:
		var low := k % 4 > 1
		var side := k % 2
		var pos := Vector2(40 + rng.next() * (W - 80), 650 + rng.next() * 70) if low else Vector2(W - 50 - rng.next() * 110 if side else 50 + rng.next() * 110, 150 + rng.next() * 60)
		var col := Data.sp_color(ids[int(rng.next() * ids.size()) % ids.size()])
		var n := 3 + int(rng.next() * 4)
		draw_colored_polygon(GemArt.ellipse_pts(pos, 14 + n * 3, 9 + n * 2), Color(0, 0, 0, 0.45))
		for s in n:
			var a := deg_to_rad((200.0 if side else -20.0) + rng.next() * 140.0)
			var l := 10 + rng.next() * (12 + depth * 4)
			var w := 3 + rng.next() * 3
			var d := Vector2(cos(a), sin(a))
			var nn := Vector2(-d.y, d.x)
			var shard := PackedVector2Array([pos + nn * w, pos + d * l + nn * w * 0.6, pos + d * (l + w * 1.4), pos + d * l - nn * w * 0.6, pos - nn * w])
			draw_colored_polygon(shard, col)
			draw_colored_polygon(PackedVector2Array([pos + nn * w, pos + d * l + nn * w * 0.6, pos + d * (l + w * 1.4)]), Color(1, 1, 1, 0.35))
		_pockets.append([pos, 18 + n * 3, col, k])
	# rails at the bottom
	var floor_y := H - 120
	draw_colored_polygon(PackedVector2Array([Vector2(0, floor_y), Vector2(W / 2, floor_y - 20), Vector2(W, floor_y), Vector2(W, H), Vector2(0, H)]), Color(0, 0, 0, 0.35))
	for k in 6:
		var y := H - 110 + k * 20
		var w := 70 + k * 26
		draw_rect(Rect2(W / 2 - w / 2, y, w, 6 + k), Color("#4a2e14"))
	draw_line(Vector2(W / 2 - 30, H - 112), Vector2(W / 2 - 110, H), Color("#9aa6b4", 0.7), 3)
	draw_line(Vector2(W / 2 + 30, H - 112), Vector2(W / 2 + 110, H), Color("#9aa6b4", 0.7), 3)
	# timber posts and the cap beam
	for x in [-4.0, W - 22]:
		draw_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + 26, 0), Vector2(x + 26, H), Vector2(x, H)]), PackedColorArray([Color("#4a2c12"), Color("#3a2210"), Color("#3a2210"), Color("#4a2c12")]))
		draw_rect(Rect2(x + 8, 0, 8, H), Color("#8a5a2c", 0.6))
		for k in 22:
			draw_line(Vector2(x + 4 + (k % 4) * 5, k * 40), Vector2(x + 6 + (k % 4) * 5, k * 40 + 34), Color("#2a1808", 0.35), 1)
	var beam_y := view.y * 0.08 - 11
	draw_polygon(PackedVector2Array([Vector2(-4, beam_y), Vector2(W + 4, beam_y), Vector2(W + 4, beam_y + 22), Vector2(-4, beam_y + 22)]), PackedColorArray([Color("#9a6a34"), Color("#9a6a34"), Color("#4a2c12"), Color("#4a2c12")]))

func _draw_live() -> void:
	for k in _lava.size():
		_live.draw_polyline(_lava[k], Color(2.0, 0.7, 0.2, 0.55 + 0.3 * sin(_t * 2 + k)), 2.5, true)
	for p in _pockets:
		var tw := 0.5 + 0.5 * sin(_t * (0.8 + p[3] * 0.17) + p[3])
		var col: Color = p[2]
		_live.draw_circle(p[0], p[1], Color(col.r * 1.6, col.g * 1.6, col.b * 1.6, 0.14 * tw))
	# the lanterns themselves, swinging with their lights
	for p in lamps:
		var o := p.position
		var hang := Vector2(0, view.y * 0.13).rotated(p.rotation)
		var bulb := o + hang
		_live.draw_line(o, bulb - hang.normalized() * 14, Color("#2a2420"), 2)
		_live.draw_colored_polygon(PackedVector2Array([bulb + Vector2(-8, -14), bulb + Vector2(8, -14), bulb + Vector2(10, 10), bulb + Vector2(-10, 10)]), Color("#3a3028"))
		_live.draw_rect(Rect2(bulb + Vector2(-6, -10), Vector2(12, 16)), Color(2.2, 1.8, 1.1))
		_live.draw_colored_polygon(PackedVector2Array([bulb + Vector2(-10, 10), bulb + Vector2(10, 10), bulb + Vector2(6, 16), bulb + Vector2(-6, 16)]), Color("#2a221c"))
