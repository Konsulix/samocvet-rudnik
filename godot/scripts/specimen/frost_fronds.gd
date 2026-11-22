class_name FrostFronds
extends Control
## Frost ferns grown by code on a zone of a card (CardFrost; 22.11: "draw the patterns in code — more control").
## From points along the zone's rim a frond grows inward: a stem that wanders a little, side branches off it at a slant
## toward its tip, little barbs off them; a dense rime on the rim itself. Every piece of it has the moment it appears
## (its frond's start + how far along the frost it is from the root), so the frost grows out along its fronds, tips
## last, and thaws back the same way. Each side of the zone has its own start, pace and spot it spreads from along the
## rim (asymmetry), drawn again for every cycle. Drawn as lines in a few widths (one call per width), the pieces sorted
## by their moment: what is grown is a slice of the arrays.

## every knob in one place
const P := {
	seed_gap = 34.0,       # rim points between fronds
	reach = [0.35, 0.95],  # a frond's length, of the zone's depth (in waves along the rim)
	tilt = 0.4,            # how far off straight in a frond may lean, radians
	curl = 0.012,          # a frond's steady bend, radians a point (each its own, either way)
	step = 3.5,            # a stem's step, points
	vane_every = 3.2,      # points between the feather's side branches (alternating sides)
	vane_angle = [0.6, 0.85],    # off the stem, radians, leaning toward its tip
	vane_len = [0.32, 26.0],     # of what is left of the stem, at most this many points: a feather, shorter to the tip
	barb_every = 2.4,      # on the side branches: tiny barbs
	barb_len = [1.5, 3.2],
	sub_every = [18.0, 30.0],    # now and then a side branch is a frond itself (smaller, with its own feather)
	sub_len = 0.5,
	speed = 150.0,         # points along the frost a second of growth (at pace 1)
	spread = 0.9,          # seconds for a side's growth to spread from its spot to its far end
	late = [0.0, 0.9],     # a side's start, s
	pace = [0.75, 1.2],
	widths = [1.2, 0.75, 0.5],   # stem, side branch, barb
	glow = 3.0,            # the soft halo, times the width
	col = Color(0.93, 0.97, 1.0),
	halo = Color(0.55, 0.72, 0.95),
}

var depth := 190.0
var sides := 15              # which sides grow: 1 bottom, 2 top, 4 left, 8 right
var avoid := Rect2()         # an oval (its box) kept clear: the stone (zero: none)
var rng := RandomNumberGenerator.new()
var g := 0.0                 # how far it has grown, seconds of growth (CardFrost sets it; down again as it thaws)
var _lv: Array = []          # per width: {pts: PackedVector2Array (pairs), t0: PackedFloat32Array, t1}
var _end := 0.0              # the moment the last piece is grown
var _built_for := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## fronds anew (a new cycle): new spots, starts and paces for the sides
func regrow() -> void:
	_built_for = Vector2.ZERO

func full() -> float:
	return _end

func _process(_dt: float) -> void:
	if size.x > 4.0 and _built_for != size:
		_build()
	queue_redraw()

func _rr(a: Array) -> float:
	return rng.randf_range(float(a[0]), float(a[1]))

func _build() -> void:
	_built_for = size
	var segs := [[], [], []]    # [p0, p1, t0, t1] per width
	# the rim as four sides: from, to, inward normal
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
		var len_ := a.distance_to(b)
		var late := 0.0 if k == first else _rr(P.late)
		var pace := _rr(P.pace)
		var spot := rng.randf()
		var ph := rng.randf() * 100.0
		var s := rng.randf() * float(P.seed_gap)
		while s < len_:
			var u := s / len_
			var root := a.lerp(b, u)
			# (corners: the fronds there lean away from the corner)
			var dir := n
			var edge := minf(s, len_ - s)
			if edge < depth * 0.5: dir = (n + (b - a).normalized() * (1.0 if s < len_ * 0.5 else -1.0) * (1.0 - edge / (depth * 0.5)) * 0.6).normalized()
			dir = dir.rotated(rng.randf_range(-float(P.tilt), float(P.tilt)))
			# along the rim the reach goes in waves
			var wave := 0.5 + 0.5 * sin(s / 37.0 + ph) * sin(s / 91.0 + ph * 1.7)
			var reach := depth * lerpf(float(P.reach[0]), float(P.reach[1]), wave * (0.6 + 0.4 * rng.randf()))
			var t_root := late + absf(u - spot) * float(P.spread) / pace
			_frond(segs, root, dir, reach, t_root, float(P.speed) * pace)
			# rime on the rim
			for r in 3:
				var q := root + (b - a).normalized() * rng.randf_range(-6.0, 6.0) + n * rng.randf_range(0.0, 4.0)
				segs[2].append([q, q + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(1.5, 3.5), t_root, t_root + 0.05])
			s += float(P.seed_gap) * rng.randf_range(0.7, 1.3)
	_lv = []
	_end = 0.0
	for li in 3:
		var arr: Array = segs[li]
		arr.sort_custom(func(x: Array, y: Array) -> bool: return float(x[2]) < float(y[2]))
		var pts := PackedVector2Array()
		var t0 := PackedFloat32Array()
		var t1 := PackedFloat32Array()
		pts.resize(arr.size() * 2)
		t0.resize(arr.size())
		t1.resize(arr.size())
		for i in arr.size():
			var sg: Array = arr[i]
			pts[i * 2] = sg[0]
			pts[i * 2 + 1] = sg[1]
			t0[i] = sg[2]
			t1[i] = sg[3]
			_end = maxf(_end, float(sg[3]))
		_lv.append({pts = pts, t0 = t0, t1 = t1})

func _clear(p: Vector2) -> bool:
	if p.x < 0.0 or p.y < 0.0 or p.x > size.x or p.y > size.y: return false
	if avoid.size.x > 0.0:
		var q := (p - avoid.get_center()) / (avoid.size * 0.5)
		if q.length_squared() < 1.0: return false
	return true

## a frond: a curving stem from root along dir, reach long, feathered with side branches on alternate sides (shorter
## toward the tip), now and then a side branch that is a frond itself. lv: 0 a frond off the rim, 1 a frond off a
## frond. t: the moment at its root; v: points a second
func _frond(segs: Array, root: Vector2, dir: Vector2, reach: float, t: float, v: float, lv := 0) -> void:
	var p := root
	var d := dir
	var run := 0.0
	var curl := float(P.curl) * rng.randf_range(0.3, 1.0) * (1.0 if rng.randf() < 0.5 else -1.0)
	var stp := float(P.step)
	var next_v := float(P.vane_every) * 2.0
	var next_s := _rr(P.sub_every)
	var side := 1.0 if rng.randf() < 0.5 else -1.0
	while run < reach:
		var q := p + d * stp
		if not _clear(q): break
		segs[mini(lv, 1)].append([p, q, t + run / v, t + (run + stp) / v])
		p = q
		run += stp
		d = d.rotated(curl * stp + rng.randf_range(-0.02, 0.02)).normalized()
		var left := reach - run
		if lv == 0 and run >= next_s and left > reach * 0.3:
			next_s = run + _rr(P.sub_every)
			_frond(segs, p, d.rotated(side * _rr(P.vane_angle)), left * float(P.sub_len), t + run / v, v, 1)
			side = -side
			continue
		while run >= next_v:
			next_v += float(P.vane_every) * (1.0 if lv == 0 else 1.3)
			# a feather: long side branches near the root, short at the tip
			var vl := minf(left * float(P.vane_len[0]) + 3.0, float(P.vane_len[1]) * (1.0 if lv == 0 else 0.6))
			_vane(segs, p, d.rotated(side * _rr(P.vane_angle)), vl * rng.randf_range(0.8, 1.15), t + run / v, v)
			side = -side

## a side branch of the feather: nearly straight, bending a little toward the stem's tip, with tiny barbs
func _vane(segs: Array, root: Vector2, dir: Vector2, reach: float, t: float, v: float) -> void:
	var p := root
	var d := dir
	var run := 0.0
	var stp := minf(3.0, reach)
	var side := 1.0
	var next_b := float(P.barb_every)
	while run < reach - 0.5:
		var q := p + d * stp
		if not _clear(q): return
		segs[1].append([p, q, t + run / v, t + (run + stp) / v])
		p = q
		run += stp
		if run >= next_b and reach > 6.0:
			next_b += float(P.barb_every)
			var bl := _rr(P.barb_len) * (1.0 - run / reach * 0.7)
			var e := p + d.rotated(side * rng.randf_range(0.6, 0.9)) * bl
			if _clear(e): segs[2].append([p, e, t + run / v, t + (run + bl) / v])
			side = -side

func _draw() -> void:
	for li in _lv.size():
		var L: Dictionary = _lv[li]
		var t0: PackedFloat32Array = L.t0
		var t1: PackedFloat32Array = L.t1
		var pts: PackedVector2Array = L.pts
		# what has fully grown: a slice of the sorted pieces (the few growing at their tips are cut short)
		var n := t0.bsearch(g)
		if n <= 0: continue
		var out := pts.slice(0, n * 2)
		# (only the last few can still be growing: a piece takes a step's time)
		for i in range(maxi(0, t0.bsearch(g - 0.08)), n):
			if t1[i] > g:
				var k := clampf((g - t0[i]) / maxf(0.0001, t1[i] - t0[i]), 0.0, 1.0)
				out[i * 2 + 1] = out[i * 2].lerp(out[i * 2 + 1], k)
		var w: float = P.widths[li]
		draw_multiline(out, Color(P.halo, 0.06), w * float(P.glow), true)
		draw_multiline(out, Color(P.col, 0.8), w, true)
