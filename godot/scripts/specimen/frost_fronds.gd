class_name FrostFronds
extends Control
## Frost ferns grown by code on a zone of a card (CardFrost; 22.11: "draw the patterns in code — more control", then
## "as it was with the shader and GPT's frost, but in code"). From points along the zone's rim fronds grow inward: a
## curving stem feathered with side branches (long near the root, short to the tip), each of them a little feather of
## barbs, now and then a side branch that is a frond itself; a dense rime of tiny tufts on the rim.
## Every piece knows the moment it appears (its side's start + how far along the frost it is from the root / pace),
## so the frost grows out along its fronds, tips last, and thaws back the same way; each side of the zone starts at its
## own moment, pace and spot along the rim (asymmetry), anew every cycle.
## Drawn once a cycle into a texture (a SubViewport): R — the frost, G — the moment it appears (0..1 of the growth);
## shown each frame by shaders/frost_fronds.gdshader, which lets it in by the moment and lays a soft glow from the
## texture's blurred levels — the density costs nothing per frame.

## every knob in one place
const P := {
	seed_gap = 30.0,       # rim points between fronds
	reach = [0.3, 1.0],    # a frond's length, of the zone's depth (in waves along the rim)
	tilt = 0.3,            # how far off straight in a frond may lean, radians
	curl = 0.016,          # a frond's steady bend, radians a point (each its own, either way)
	step = 3.0,            # a stem's step, points
	vane_every = 2.2,      # points between the feather's side branches (alternating sides)
	vane_angle = [0.68, 0.78],   # off the stem, radians, leaning toward its tip
	vane_len = [0.36, 24.0],     # of what is left of the stem, at most this many points: short to the tip
	vane_curl = 0.02,      # a side branch bends toward the stem's tip
	barb_every = 1.5,      # on the side branches: tiny barbs, both ways in turn
	barb_len = [1.6, 2.6],
	sub_every = [14.0, 26.0],    # now and then a side branch is a frond itself
	sub_len = 0.55,
	rime_gap = 4.5,        # tufts of rime on the rim
	rime_len = [3.0, 8.0], 
	speed = 140.0,         # points along the frost a second of growth (at pace 1)
	spread = 1.0,          # seconds for a side's growth to spread from its spot to its far end
	late = [0.0, 1.0],     # a side's start, s
	pace = [0.75, 1.2],
	widths = [3.6, 2.4, 1.6],    # stem, side branch, barb — texture pixels (the texture is RES points)
	bright = [1.0, 0.8, 0.6],
}
const RES := 3.0             # texture pixels a point

var depth := 190.0
var sides := 15              # which sides grow: 1 bottom, 2 top, 4 left, 8 right
var avoid := Rect2()         # an oval (its box) kept clear: the stone (zero: none)
var rng := RandomNumberGenerator.new()
var g := 0.0                 # how far it has grown, seconds of growth (CardFrost sets it; back down as it thaws)
var _end := 1.0              # the moment the last piece is grown
var _built_for := Vector2.ZERO
var _vp: SubViewport
var _pen: Node2D
var _segs := [[], [], []]    # per width: flat [p0, p1, t, ...] for the pen

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vp = SubViewport.new()
	_vp.transparent_bg = false
	_vp.disable_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	add_child(_vp)
	_pen = Node2D.new()
	var pm := ShaderMaterial.new()
	# (the pen overwrites: the frost's brightness and its moment go in as they are, not blended)
	pm.shader = preload("res://shaders/frost_pen.gdshader")
	_pen.material = pm
	_pen.draw.connect(_draw_pen)
	_vp.add_child(_pen)
	var sm := ShaderMaterial.new()
	sm.shader = preload("res://shaders/frost_fronds.gdshader")
	sm.set_shader_parameter("tex", _vp.get_texture())
	material = sm

## fronds anew (a new cycle): new spots, starts and paces for the sides
func regrow() -> void:
	_built_for = Vector2.ZERO

func full() -> float:
	return _end

func _process(_dt: float) -> void:
	if size.x > 4.0 and _built_for != size: _build()
	(material as ShaderMaterial).set_shader_parameter("g", g / maxf(_end, 0.001))
	queue_redraw()

func _draw() -> void:
	draw_texture_rect(_vp.get_texture(), Rect2(Vector2.ZERO, size), false)

func _rr(a: Array) -> float:
	return rng.randf_range(float(a[0]), float(a[1]))

func _build() -> void:
	_built_for = size
	_segs = [[], [], []]
	_end = 0.0
	var S := size
	var defs := [[Vector2(0, S.y), Vector2(S.x, S.y), Vector2(0, -1), 1], [Vector2(S.x, 0), Vector2(0, 0), Vector2(0, 1), 2],
		[Vector2(0, 0), Vector2(0, S.y), Vector2(1, 0), 4], [Vector2(S.x, S.y), Vector2(S.x, 0), Vector2(-1, 0), 8]]
	var first := rng.randi() % 4
	for k in 4:
		var d: Array = defs[k]
		if not (sides & int(d[3])): continue
		var a: Vector2 = d[0]
		var b: Vector2 = d[1]
		var n: Vector2 = d[2]
		var along := (b - a).normalized()
		var len_ := a.distance_to(b)
		var late := 0.0 if k == first else _rr(P.late)
		var pace := _rr(P.pace)
		var spot := rng.randf()
		var ph := rng.randf() * 100.0
		var v := float(P.speed) * pace
		# the fronds
		var s := rng.randf() * float(P.seed_gap)
		while s < len_:
			var u := s / len_
			var root := a.lerp(b, u)
			var dir := n
			var edge := minf(s, len_ - s)
			# (by the corners the fronds lean away from the corner)
			if edge < depth * 0.5: dir = (n + along * (1.0 if s < len_ * 0.5 else -1.0) * (1.0 - edge / (depth * 0.5)) * 0.7).normalized()
			dir = dir.rotated(rng.randf_range(-float(P.tilt), float(P.tilt)))
			var wave := 0.5 + 0.5 * sin(s / 41.0 + ph) * sin(s / 97.0 + ph * 1.7)
			var reach := depth * lerpf(float(P.reach[0]), float(P.reach[1]), wave * (0.55 + 0.45 * rng.randf()))
			_frond(root, dir, reach, late + absf(u - spot) * float(P.spread) / pace, v, 0)
			s += float(P.seed_gap) * rng.randf_range(0.6, 1.4)
		# the rime: little tufts all along the rim, first of all
		s = 0.0
		while s < len_:
			var u2 := s / len_
			var r0 := a.lerp(b, u2) + n * rng.randf_range(0.0, 3.0)
			var t0 := late + absf(u2 - spot) * float(P.spread) / pace
			_vane(r0, n.rotated(rng.randf_range(-0.6, 0.6)), _rr(P.rime_len), t0, v, 0.0)
			s += float(P.rime_gap) * rng.randf_range(0.6, 1.4)
	# the texture: drawn once now
	_vp.size = Vector2i(maxi(1, int(size.x * RES)), maxi(1, int(size.y * RES)))
	_pen.queue_redraw()
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE

func _clear(p: Vector2) -> bool:
	if p.x < 0.0 or p.y < 0.0 or p.x > size.x or p.y > size.y: return false
	if avoid.size.x > 0.0:
		var q := (p - avoid.get_center()) / (avoid.size * 0.5)
		if q.length_squared() < 1.0: return false
	return true

func _seg(lv: int, p0: Vector2, p1: Vector2, t: float) -> void:
	var a: Array = _segs[lv]
	a.append(p0)
	a.append(p1)
	a.append(t)
	_end = maxf(_end, t)

## a frond: a curving stem feathered with side branches; lv 0 off the rim, 1 off a frond
func _frond(root: Vector2, dir: Vector2, reach: float, t: float, v: float, lv: int) -> void:
	var p := root
	var d := dir
	var run := 0.0
	var curl := float(P.curl) * rng.randf_range(0.2, 1.0) * (1.0 if rng.randf() < 0.5 else -1.0)
	var stp := float(P.step)
	var next_v := float(P.vane_every)
	var next_s := _rr(P.sub_every)
	var side := 1.0 if rng.randf() < 0.5 else -1.0
	while run < reach:
		var q := p + d * stp
		if not _clear(q): break
		_seg(0 if lv == 0 else 1, p, q, t + run / v)
		p = q
		run += stp
		d = d.rotated(curl * stp + rng.randf_range(-0.012, 0.012)).normalized()
		var left := reach - run
		if lv == 0 and run >= next_s and left > reach * 0.25:
			next_s = run + _rr(P.sub_every)
			_frond(p, d.rotated(side * _rr(P.vane_angle)), left * float(P.sub_len), t + run / v, v, 1)
			side = -side
			continue
		while run >= next_v:
			next_v += float(P.vane_every) * (1.0 if lv == 0 else 1.25)
			var vl := minf(left * float(P.vane_len[0]) + 2.5, float(P.vane_len[1]) * (1.0 if lv == 0 else 0.6))
			_vane(p, d.rotated(side * _rr(P.vane_angle)), vl * rng.randf_range(0.9, 1.1), t + run / v, v, side * float(P.vane_curl))
			side = -side

## a side branch: a small feather of barbs, bending toward the stem's tip
func _vane(root: Vector2, dir: Vector2, reach: float, t: float, v: float, bend: float) -> void:
	var p := root
	var d := dir
	var run := 0.0
	var stp := minf(2.2, reach)
	var side := 1.0
	var next_b := float(P.barb_every)
	while run < reach - 0.3:
		var q := p + d * stp
		if not _clear(q): return
		_seg(1, p, q, t + run / v)
		p = q
		run += stp
		d = d.rotated(-bend * stp).normalized()
		while run >= next_b and reach > 4.0:
			next_b += float(P.barb_every)
			var bl := _rr(P.barb_len) * (1.0 - run / reach * 0.75)
			var e := p + d.rotated(side * rng.randf_range(0.65, 0.8)) * bl
			if _clear(e): _seg(2, p, e, t + (run + bl) / v)
			side = -side

## into the texture: R the frost's brightness, G its moment (0..1); barbs first, stems last (they hold the earliest
## moments where they cross)
func _draw_pen() -> void:
	var inv := 1.0 / maxf(_end, 0.001)
	# (the ground: nothing, and never)
	_pen.draw_rect(Rect2(Vector2.ZERO, Vector2(_vp.size)), Color(0, 1, 0, 1))
	for li in [2, 1, 0]:
		var a: Array = _segs[li]
		var n := a.size() / 3
		if n == 0: continue
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		pts.resize(n * 2)
		cols.resize(n)
		var br: float = P.bright[li]
		for i in n:
			pts[i * 2] = (a[i * 3] as Vector2) * RES
			pts[i * 2 + 1] = (a[i * 3 + 1] as Vector2) * RES
			cols[i] = Color(br * rng.randf_range(0.9, 1.0), float(a[i * 3 + 2]) * inv, 0, 1)
		_pen.draw_multiline_colors(pts, cols, float(P.widths[li]))
