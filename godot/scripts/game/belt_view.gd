class_name BeltView
extends Node2D
## The conveyor on the board (BoardModel.belts, docs/obstacles.md §5): a belt running along a path of cells - the
## bottom row side to side, a side column, an L or a U round the edges - a malachite basket riding in each slot, open or
## under a tarp. Drawn over the stones (none stand in its cells), with its own bits and light.
## The art is a GPT kit (art/belt_look/kit_b2.png, cut_kit.py -> assets/board/conveyor/; the trough's cells - straight
## runs, the four turns, the caps of a vertical run - art/belt_look/turns_b.png, gen_turns.sh, cut_turns.py): each cell
## of the path lays its own piece, the end posts close the two ends; the rubber and its cleats are drawn here and run
## with the baskets. The path goes round a turn on a curve (`_pt`), the baskets and the cleats both ride it, one slot a move. Motion: the baskets ride a slot along after a move (a pull, a ride,
## a settle, a rock), the one off the far end goes under the end post and comes in at the other; a knock tears the
## tarp off or cracks a basket and bursts it into shards; the last one gone, cracks run through it and it falls apart.
## Tried out first in tests/belt_lab.gd.

const DIR := "res://assets/board/conveyor/"
const SHIFT_S := 0.55
const CAP_CUT := 72.0      # px of the end cap's drum left off: only its post stands, inside the end cell
const ITEM_K := 0.8        # a basket's width in cells
const RUBBER := Color(0.16, 0.135, 0.125)
const CLEAT := Color(0.29, 0.25, 0.23)

var board: BoardView
var vis := []              # per conveyor: {cells, hp (as seen), punch, crack, gone_at, cracks, done}
var move_t := -1.0
var stop_t := -9.0
var parts := []            # flying bits: textures, shards (poly + uv), dust
var glows := []
var _light: Node2D
var rng := RandomNumberGenerator.new()
static var _tex := {}

static func tex(nm: String) -> Texture2D:
	if not _tex.has(nm):
		_tex[nm] = load(DIR + nm + ".png") if ResourceLoader.exists(DIR + nm + ".png") else null
	return _tex[nm]

func _ready() -> void:
	_light = Node2D.new()
	_light.material = FxLayer.add_material()
	_light.draw.connect(_draw_light)
	add_child(_light)

func setup(b: BoardView) -> void:
	board = b
	vis = []
	parts = []
	glows = []
	move_t = -1.0
	for mb: Dictionary in b.model.belts:
		var n: int = (mb.cells as Array).size()
		var zeros := []
		zeros.resize(n)
		zeros.fill(-9.0)
		vis.append({cells = (mb.cells as Array).duplicate(), hp = (mb.hp as Array).duplicate(), punch = zeros.duplicate(),
			crack = zeros.duplicate(), gone_at = -1.0, cracks = [], done = bool(mb.done)})
	queue_redraw()

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

# ---------------------------------------------------------------- what the level tells it

## the baskets ride a slot along (BoardModel.belt_turn has already moved them)
func turn() -> void:
	var live := false
	for v: Dictionary in vis:
		if not v.done: live = true
	if not live: return
	move_t = _now()
	await get_tree().create_timer(SHIFT_S).timeout
	for v: Dictionary in vis:
		if v.done: continue
		for k in ["hp", "punch", "crack"]:
			var a: Array = v[k]
			a.push_front(a.pop_back())
	move_t = -1.0
	stop_t = _now()

## a knock on slot i of conveyor bi: hp is what is left of its basket
func hit(bi: int, i: int, hp: int) -> void:
	var v: Dictionary = vis[bi]
	var p := _at(v, float(i))
	v.punch[i] = _now()
	if hp >= 1:
		# the tarp torn off: its rags and the rope fly, the open basket under it
		v.hp[i] = hp
		_glow(p, 0.7, Color(1.0, 0.85, 0.5), 0.25)
		for k in 3: _bit("tarp_%d" % k, p + Vector2(0, -board.TS * 0.12), 0.34 - k * 0.06, 1.1)
		_bit("rope", p, 0.18, 1.0)
		_dust(p, 3)
		Sfx.play("knock")
		return
	# a crack runs through it, a blink later it bursts
	v.crack[i] = _now()
	await get_tree().create_timer(0.08).timeout
	v.hp[i] = 0
	var t := tex("basket_cracked")
	var q := _at(v, float(i))
	_shatter(t, Vector2(t.get_size()) * _item_scale(), q, 6, Vector2(150, 280), Vector2(0, -230), 0.85)
	for k in 4: _bit("wick_%d" % k, q, 0.2, 1.3)
	for k in 3: _bit("chunk_%d" % rng.randi_range(2, 4), q, 0.18, 1.2)
	_dust(q, 8)
	_glow(q, 0.9, Color(1.0, 0.85, 0.55), 0.3)
	_glow(q, 0.6, Color(0.35, 0.9, 0.55), 0.5)
	Sfx.play("nodule")

## the last basket gone: cracks run across the belt, a moment later it falls apart
func gone(bi: int) -> void:
	var v: Dictionary = vis[bi]
	v.gone_at = _now()
	v.cracks = []
	var TS := board.TS
	var n: int = (v.cells as Array).size()
	for i in n:
		if i % 2 == 1 and n > 6: continue
		var d := _dir(v, i)
		var side := Vector2(-d.y, d.x)
		var a := _center(v, i) + side * TS * 0.5 + d * rng.randf_range(-0.2, 0.2) * TS
		var pts := PackedVector2Array([a])
		var k := 0.0
		while k < TS:
			k = minf(TS, k + rng.randf_range(0.1, 0.18) * TS)
			pts.append(a - side * k + d * rng.randf_range(-0.12, 0.12) * TS)
		v.cracks.append(pts)
	await get_tree().create_timer(0.5).timeout
	v.done = true
	var st := tex("slot")
	for i in n:
		var p := _center(v, i)
		_shatter(st, Vector2(TS, TS), p, 3, Vector2(60, 160), Vector2(0, -170), 0.95, _dir(v, i).angle())
		if i % 2 == 0: _dust(p, 2)
	_glow(_center(v, n / 2), 3.0, Color(1.0, 0.85, 0.55), 0.4)
	Sfx.play("rockfall")

# ---------------------------------------------------------------- per frame

func _process(dt: float) -> void:
	for b: Dictionary in parts:
		b.life += dt
		b.v.y += float(b.get("g", 1500.0)) * board.TS / 50.0 * dt
		b.p += b.v * dt
		b.rot += b.w * dt
	parts = parts.filter(func(b): return b.life < b.max)
	for g: Dictionary in glows: g.life += dt
	glows = glows.filter(func(g): return g.life < g.max)
	queue_redraw()
	_light.queue_redraw()

# ---------------------------------------------------------------- the path

func _center(v: Dictionary, i: int) -> Vector2:
	var q: Vector2i = v.cells[clampi(i, 0, (v.cells as Array).size() - 1)]
	return board.cell_center(q.x, q.y)

## the way the baskets ride through cell i (into the next one; the last cell keeps the way it came in)
func _dir(v: Dictionary, i: int) -> Vector2:
	var n: int = (v.cells as Array).size()
	if n < 2: return Vector2.RIGHT
	if i >= n - 1: return (_center(v, n - 1) - _center(v, n - 2)).normalized()
	return (_center(v, i + 1) - _center(v, maxi(i, 0))).normalized()

## a point s slots along the path; past either end it carries on straight (under the end posts)
func _at(v: Dictionary, s: float) -> Vector2:
	var n: int = (v.cells as Array).size()
	var TS := board.TS
	if s <= 0.0: return _center(v, 0) + _dir(v, 0) * s * TS
	if s >= n - 1: return _center(v, n - 1) + _dir(v, n - 1) * (s - (n - 1)) * TS
	var k := int(floor(s + 0.5))
	return _pt(v, k, s - k)

## the edge cell k shares with the one before (way < 0) or after (way > 0); an end cell's open end: straight on
func _edge(v: Dictionary, k: int, way: int) -> Vector2:
	var n: int = (v.cells as Array).size()
	var j := k + way
	if j < 0 or j >= n: return _center(v, k) + _dir(v, k) * float(way) * board.TS * 0.5
	return (_center(v, k) + _center(v, j)) * 0.5

## is cell k a turn (its way in and way out at right angles)
func _turn(v: Dictionary, k: int) -> bool:
	var n: int = (v.cells as Array).size()
	if k <= 0 or k >= n - 1: return false
	var a := _center(v, k - 1) - _center(v, k)
	var b := _center(v, k + 1) - _center(v, k)
	return absf(a.dot(b)) < 0.5 * board.TS * board.TS

## the point u (-0.5 .. 0.5) through cell k: straight across, or round a turn on a curve from edge to edge
## (a basket at rest in a turn sits a little into its inner corner)
func _pt(v: Dictionary, k: int, u: float) -> Vector2:
	var a := _edge(v, k, -1)
	var b := _edge(v, k, 1)
	var t := u + 0.5
	if not _turn(v, k): return a.lerp(b, t)
	return a * (1.0 - t) * (1.0 - t) + _center(v, k) * 2.0 * t * (1.0 - t) + b * t * t

## the way along the path at u through cell k
func _tan(v: Dictionary, k: int, u: float) -> Vector2:
	var a := _edge(v, k, -1)
	var b := _edge(v, k, 1)
	if not _turn(v, k): return (b - a).normalized()
	var t := u + 0.5
	return ((_center(v, k) - a) * 2.0 * (1.0 - t) + (b - _center(v, k)) * 2.0 * t).normalized()

func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	var c2 := 1.2 * 1.525
	if x < 0.5: return pow(2.0 * x, 2.0) * ((c2 + 1.0) * 2.0 * x - c2) * 0.5
	return (pow(2.0 * x - 2.0, 2.0) * ((c2 + 1.0) * (2.0 * x - 2.0) + c2) + 2.0) * 0.5

func _ride() -> float:
	return _ease((_now() - move_t) / SHIFT_S) if move_t >= 0.0 else 0.0

## the baskets lean back as the belt pulls them off and forward as it stops, then rock to rest
func _tilt() -> float:
	if move_t >= 0.0:
		var k := (_now() - move_t) / SHIFT_S
		return clampf(-(_ease(k + 0.04) - 2.0 * _ease(k) + _ease(k - 0.04)) * 9.0, -0.3, 0.3)
	var since := _now() - stop_t
	return -0.16 * exp(-since * 6.0) * sin(since * 22.0) if since < 1.0 else 0.0

func _item_scale() -> float:
	return board.TS * ITEM_K / float(tex("basket").get_width())

func _cap_w() -> float:
	var ct := tex("cap_l")
	return board.TS * (ct.get_width() - CAP_CUT) / ct.get_height()

# ---------------------------------------------------------------- effects

func _glow(p: Vector2, r: float, col: Color, life: float) -> void:
	glows.append({p = p, r = r * board.TS, col = col, life = 0.0, max = life})

func _bit(nm: String, p: Vector2, size: float, force: float) -> void:
	var t := tex(nm)
	if t == null: return
	var k := board.TS / 50.0
	var a := rng.randf_range(-PI * 0.85, -PI * 0.15)
	parts.append({tex = t, p = p + Vector2(rng.randf_range(-6, 6), rng.randf_range(-6, 4)) * k,
		v = Vector2.from_angle(a) * rng.randf_range(160.0, 330.0) * force * k, rot = rng.randf() * TAU,
		w = rng.randf_range(-9.0, 9.0), life = 0.0, max = rng.randf_range(0.55, 0.85),
		s = size * board.TS / maxf(t.get_width(), t.get_height())})

func _dust(p: Vector2, n: int) -> void:
	var k := board.TS / 50.0
	for i in n:
		parts.append({dust = true, p = p + Vector2(rng.randf_range(-12, 12), rng.randf_range(0, 10)) * k,
			v = Vector2(rng.randf_range(-60, 60), rng.randf_range(-70, -20)) * k, g = -40.0, rot = 0.0, w = 0.0,
			life = 0.0, max = rng.randf_range(0.5, 0.8), r = rng.randf_range(8.0, 14.0) * k})

## a picture broken into n shards (Voronoi cells of its rect), each flying off from the middle
func _shatter(t: Texture2D, sz: Vector2, p: Vector2, n: int, speed: Vector2, up: Vector2, life: float, rot := 0.0) -> void:
	var k := board.TS / 50.0
	var rect := Rect2(-sz * 0.5, sz)
	var seeds := []
	for i in n: seeds.append(rect.position + Vector2(rng.randf_range(0.1, 0.9), rng.randf_range(0.1, 0.9)) * rect.size)
	for i in seeds.size():
		var poly := PackedVector2Array([rect.position, rect.position + Vector2(rect.size.x, 0), rect.end, rect.position + Vector2(0, rect.size.y)])
		for j in seeds.size():
			if i == j: continue
			poly = _clip(poly, seeds[i], seeds[j])
			if poly.size() < 3: break
		if poly.size() < 3: continue
		var ctr := Vector2.ZERO
		for q in poly: ctr += q
		ctr /= poly.size()
		var local := PackedVector2Array()
		var uv := PackedVector2Array()
		for q in poly:
			local.append(q - ctr)
			uv.append((q - rect.position) / rect.size)
		var dir := ctr.normalized() if ctr.length() > 0.5 else Vector2.UP
		parts.append({poly = local, uv = uv, tex = t, p = p + ctr.rotated(rot), v = (dir.rotated(rot) * rng.randf_range(speed.x, speed.y) + up) * k,
			rot = rot, w = rng.randf_range(-6.0, 6.0), life = 0.0, max = life * rng.randf_range(0.85, 1.1)})

## the half of a polygon nearer to a than to b
static func _clip(poly: PackedVector2Array, a: Vector2, b: Vector2) -> PackedVector2Array:
	var n := b - a
	var m := (a + b) * 0.5
	var out := PackedVector2Array()
	for i in poly.size():
		var p := poly[i]
		var q := poly[(i + 1) % poly.size()]
		var dp := (p - m).dot(n)
		var dq := (q - m).dot(n)
		if dp <= 0.0: out.append(p)
		if (dp <= 0.0) != (dq <= 0.0):
			out.append(p + (q - p) * (dp / (dp - dq)))
	return out

# ---------------------------------------------------------------- drawing

func _draw() -> void:
	if board == null: return
	var TS := board.TS
	var now := _now()
	var ride := _ride()
	for v: Dictionary in vis:
		if v.done: continue
		var cells: Array = v.cells
		var n := cells.size()
		var shake := 0.0
		if float(v.gone_at) >= 0.0: shake = 0.5 - (now - float(v.gone_at))
		if move_t >= 0.0 or now - stop_t < 0.1: shake = maxf(shake, 0.04)
		var jit := Vector2(sin(now * 95.0), cos(now * 83.0)) * shake * TS * 0.2 if shake > 0.0 else Vector2.ZERO
		# the rubber, its cleats running with the baskets
		for i in n:
			_draw_rubber(v, i, jit, ride)
		# the trough: each cell its piece - a straight run or a turn, open where the belt goes on
		for i in n:
			var pt := tex(_piece(v, i))
			if pt: draw_texture_rect(pt, Rect2(_center(v, i) + jit - Vector2(TS, TS) * 0.5, Vector2(TS, TS)), false)
		# the baskets: s slots along the path; the one off the far end comes back in at the near one
		var cap := _cap_w()
		# (lower ones over the upper: down a vertical run a basket's top lies over the one above it)
		var order := []
		for i in n:
			if int(v.hp[i]) <= 0: continue
			var s := float(i) + ride
			order.append([s, i])
			if s > n - 1: order.append([s - n, i])
		order.sort_custom(func(x: Array, y: Array) -> bool: return _at(v, float(x[0])).y < _at(v, float(y[0])).y)
		for o: Array in order: _draw_basket(v, int(o[1]), float(o[0]), jit, cap)
		# the end posts (a vertical run's: its own caps, the flat side and a bit of the drum, inside the end cell)
		for e in 2:
			var i := 0 if e == 0 else n - 1
			var d := _dir(v, i) * (-1.0 if e == 0 else 1.0)    # out of the belt
			if absf(d.y) > 0.5:
				var vt := tex("cap_t" if d.y < 0.0 else "cap_b")
				var keep := float(vt.get_width()) * cap / TS     # px of it kept, as much as the side caps keep
				var vsrc := Rect2(0, vt.get_height() - keep, vt.get_width(), keep) if d.y < 0.0 else Rect2(0, 0, vt.get_width(), keep)
				var y0 := _center(v, i).y + (-TS * 0.5 if d.y < 0.0 else TS * 0.5 - cap)
				draw_texture_rect_region(vt, Rect2(Vector2(_center(v, i).x - TS * 0.5, y0) + jit, Vector2(TS, cap)), vsrc)
				continue
			var ct := tex("cap_r")
			var src := Rect2(0, 0, ct.get_width() - CAP_CUT, ct.get_height())
			draw_set_transform(_center(v, i) + d * (TS * 0.5 - cap * 0.5) + jit, d.angle(), Vector2.ONE)
			draw_texture_rect_region(ct, Rect2(Vector2(-cap * 0.5, -TS * 0.5), Vector2(cap, TS)), src)
		draw_set_transform(Vector2.ZERO)
		# cracks before it falls apart
		if float(v.gone_at) >= 0.0:
			var k := clampf((now - float(v.gone_at)) / 0.4, 0.0, 1.0)
			for pts: PackedVector2Array in v.cracks:
				var seg := pts.slice(0, maxi(2, int(ceil(pts.size() * k))))
				for j in seg.size(): seg[j] += jit
				draw_polyline(seg, Color(0.06, 0.03, 0.02, 0.95), maxf(1.5, TS * 0.05))
				for j in seg.size(): seg[j] += Vector2(1, 0)
				draw_polyline(seg, Color(1.0, 0.85, 0.5, 0.5), 1.0)
	# the bits flying off
	for b: Dictionary in parts:
		var a := clampf((float(b.max) - float(b.life)) / 0.25, 0.0, 1.0)
		if b.has("dust"):
			var k: float = float(b.life) / float(b.max)
			var r: float = float(b.r) * (1.0 + k)
			draw_texture_rect(FxLayer.puff(), Rect2(b.p - Vector2.ONE * r, Vector2.ONE * r * 2.0), false, Color(0.55, 0.45, 0.35, 0.45 * (1.0 - k)))
			continue
		draw_set_transform(b.p, b.rot, Vector2.ONE)
		if b.has("poly"):
			draw_polygon(b.poly, PackedColorArray([Color(1, 1, 1, a)]), b.uv, b.tex)
		else:
			var t: Texture2D = b.tex
			var sz := Vector2(t.get_size()) * float(b.s)
			draw_texture_rect(t, Rect2(-sz * 0.5, sz), false, Color(1, 1, 1, a))
		draw_set_transform(Vector2.ZERO)

## the trough's piece for cell i: which sides the belt goes on through (an end cell: straight on, under its post)
func _piece(v: Dictionary, i: int) -> String:
	if not _turn(v, i):
		return "run_v" if absf(_dir(v, i).y) > 0.5 else "run_h"
	var c := _center(v, i)
	var w := (_center(v, i - 1) - c) + (_center(v, i + 1) - c)   # the two open ways together
	return "turn_" + ("r" if w.x > 0.0 else "l") + ("d" if w.y > 0.0 else "u")

## a cell of rubber belt with three cleats across it, carried along by the ride exactly as the baskets are (the same
## path, the same slot a move): round a turn they fan out on its curve
func _draw_rubber(v: Dictionary, i: int, jit: Vector2, ride: float) -> void:
	var TS := board.TS
	var c := _center(v, i) + jit
	draw_rect(Rect2(c - Vector2(TS, TS) * 0.5, Vector2(TS, TS)), RUBBER)
	var w := maxf(2.0, TS * 0.07)
	for k in 3:
		var u := fposmod((k + 0.5) / 3.0 + ride, 1.0) - 0.5
		var m := _pt(v, i, u) + jit
		var d := _tan(v, i, u)
		var across := Vector2(-d.y, d.x)
		var a := m - across * TS * 0.36
		var b := m + across * TS * 0.36
		draw_line(a + Vector2(0, w * 0.5), b + Vector2(0, w * 0.5), Color(0.05, 0.04, 0.04, 0.7), w)
		draw_line(a, b, CLEAT, w)
		draw_line(a - Vector2(0, w * 0.35), b - Vector2(0, w * 0.35), Color(0.45, 0.4, 0.37, 0.6), maxf(1.0, w * 0.25))

## a basket s slots along the path; under the end posts it is cut off (only its part inside the belt is drawn)
func _draw_basket(v: Dictionary, i: int, s: float, jit: Vector2, cap: float) -> void:
	var n: int = (v.cells as Array).size()
	var TS := board.TS
	var t := tex("sealed") if int(v.hp[i]) >= 2 else tex("basket")
	var now := _now()
	if now - float(v.crack[i]) < 0.3: t = tex("basket_cracked")
	var sc := _item_scale()
	var sx := 1.0
	var sy := 1.0
	var since := now - float(v.punch[i])
	if since < 1.0:
		var a := exp(-since * 7.0) * sin(since * 34.0) * 0.22
		sx += a
		sy -= a
	var sz := Vector2(t.get_size()) * sc * Vector2(sx, sy)
	var hop := sin(clampf((now - move_t) / SHIFT_S, 0.0, 1.0) * PI) * TS * 0.06 if move_t >= 0.0 else 0.0
	var p := _at(v, s) + jit + Vector2(0, -hop)
	var r := Rect2(p - Vector2(sz.x * 0.5, sz.y * 0.55), sz)
	var src := Rect2(Vector2.ZERO, Vector2(t.get_size()))
	# cut off by the end posts: the start's inner face, the end's inner face
	var clipped := false
	for e in 2:
		var ci := 0 if e == 0 else n - 1
		var d := _dir(v, ci) * (-1.0 if e == 0 else 1.0)   # out of the belt
		var face := _center(v, ci) + jit + d * (TS * 0.5 - cap * 0.6)
		var res := _cut(r, src, face, d)
		if res.is_empty(): return
		if res[0] != r: clipped = true
		r = res[0]
		src = res[1]
	var d0 := _dir(v, clampi(int(round(s)), 0, n - 1))
	var tilt := _tilt() if absf(d0.y) < 0.5 and not clipped else 0.0
	if tilt == 0.0:
		draw_texture_rect_region(t, r, src)
		return
	var foot := Vector2(r.position.x + r.size.x * 0.5, r.end.y - sz.y * 0.03)
	draw_set_transform(foot, tilt, Vector2.ONE)
	draw_texture_rect_region(t, Rect2(r.position - foot, r.size), src)
	draw_set_transform(Vector2.ZERO)

## an axis-aligned picture cut by a face: what lies beyond it (along d, one of the four ways) goes. [rect, src] or []
static func _cut(r: Rect2, src: Rect2, face: Vector2, d: Vector2) -> Array:
	if absf(d.x) > 0.5:
		var x0 := r.position.x
		var x1 := r.end.x
		if d.x > 0.0: x1 = minf(x1, face.x)
		else: x0 = maxf(x0, face.x)
		if x1 <= x0: return []
		var u0 := (x0 - r.position.x) / r.size.x
		var u1 := (x1 - r.position.x) / r.size.x
		return [Rect2(x0, r.position.y, x1 - x0, r.size.y), Rect2(src.position.x + u0 * src.size.x, src.position.y, (u1 - u0) * src.size.x, src.size.y)]
	var y0 := r.position.y
	var y1 := r.end.y
	if d.y > 0.0: y1 = minf(y1, face.y)
	else: y0 = maxf(y0, face.y)
	if y1 <= y0: return []
	var v0 := (y0 - r.position.y) / r.size.y
	var v1 := (y1 - r.position.y) / r.size.y
	return [Rect2(r.position.x, y0, r.size.x, y1 - y0), Rect2(src.position.x, src.position.y + v0 * src.size.y, src.size.x, (v1 - v0) * src.size.y)]

func _draw_light() -> void:
	for g: Dictionary in glows:
		var k: float = float(g.life) / float(g.max)
		var r: float = float(g.r) * (0.6 + 0.6 * k)
		var col: Color = g.col
		_light.draw_texture_rect(FxLayer.puff(), Rect2(g.p - Vector2.ONE * r, Vector2.ONE * r * 2.0), false, Color(col.r, col.g, col.b, (1.0 - k) * 0.9))
