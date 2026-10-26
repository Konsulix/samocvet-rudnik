class_name BossLizards
extends Node2D
## The Mistress' lizards. A few run round her frame along the middle of its bars, stop now and then, turn back; none
## comes closer than GAP to the one ahead of it (it waits, then often turns). Her raid: for every green stone she
## takes, a lizard leaps off the nearest bar, runs to it, takes it in its mouth (the stone shrinks and rides at its
## head) and runs back off the board and away along the bar. The run cycle is art/boss/lizard.py's 8 frames
## (head up); the rules (which stones) are BoardModel's, LevelBoss drives the raid. Coordinates: the board's own.

const N := 3
const GAP := 44.0            # pt along the frame, at a 42-pt cell
const SPEED := 230.0         # pt/s on the board
const BIG := 1.35            # a lizard on the board, over the stones, is drawn bigger than on the frame
const CARRY := 0.52          # the stone in its mouth, of a cell
const STEP := 0.14           # s between two raiders setting off
const GRAB := 0.16

var frames: Array[Texture2D] = []
var fps := 12.0
var path := PackedVector2Array()   # the bars' middle line, a closed loop of corners
var total := 0.0
var k := 1.0                 # pt -> board px (the board's cell size over 42)
var ts := 42.0
var origin := Vector2.ZERO
var rows := BoardModel.R
var cols := BoardModel.C
var walkers := []            # {s, v, stop}
var raiders := []            # {a, b, t, id, node}
var _t := 0.0
var _rng := RandomNumberGenerator.new()

static func load_for(id: String) -> BossLizards:
	var dir := "res://assets/boss/%s/" % id
	if not FileAccess.file_exists(dir + "lizard.json"): return null
	var L := BossLizards.new()
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir + "lizard.json"))
	for i in int(meta.frames):
		L.frames.append(load(dir + "lizard_%d.png" % i))
	L.fps = float(meta.get("fps", 12))
	L.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	L.material = BoardSprites.plain_material()
	return L

## the board's shape and grid (as BossFrame.fit); mid: how far out the bars' middle line runs, in cells
func fit(shape: Callable, grid_origin: Vector2, cell: float, mid: float) -> void:
	origin = grid_origin
	ts = cell
	k = cell / 42.0
	var full := func(r: int, c: int) -> bool: return r >= 0 and c >= 0 and r < rows and c < cols and bool(shape.call(r, c))
	# the outline's edges, each walked with its cell on the right (clockwise on screen), then only the turning points
	var nxt := {}
	for r in rows:
		for c in cols:
			if not full.call(r, c): continue
			if not full.call(r - 1, c): nxt[Vector2i(c, r)] = Vector2i(c + 1, r)
			if not full.call(r, c + 1): nxt[Vector2i(c + 1, r)] = Vector2i(c + 1, r + 1)
			if not full.call(r + 1, c): nxt[Vector2i(c + 1, r + 1)] = Vector2i(c, r + 1)
			if not full.call(r, c - 1): nxt[Vector2i(c, r + 1)] = Vector2i(c, r)
	if nxt.is_empty(): return
	var start: Vector2i = nxt.keys().min()
	var loop: Array[Vector2i] = [start]
	var p: Vector2i = nxt[start]
	while p != start and loop.size() < 400:
		loop.append(p)
		p = nxt[p]
	var turns: Array[Vector2i] = []
	var n := loop.size()
	for i in n:
		if loop[i] - loop[i - 1] != loop[(i + 1) % n] - loop[i]: turns.append(loop[i])
	path = PackedVector2Array()
	n = turns.size()
	for i in n:
		var d1 := Vector2(turns[i] - turns[i - 1]).normalized()
		var d2 := Vector2(turns[(i + 1) % n] - turns[i]).normalized()
		var out := Vector2(d1.y, -d1.x) + Vector2(d2.y, -d2.x)   # outwards: left of a clockwise walk (y down)
		path.append(origin + Vector2(turns[i]) * ts + out * mid * ts)
	total = 0.0
	for i in path.size(): total += path[i].distance_to(path[(i + 1) % path.size()])
	if walkers.is_empty():
		for i in N:
			walkers.append({s = total * (i + _rng.randf_range(-0.15, 0.15)) / N,
				v = (1.0 if _rng.randf() < 0.5 else -1.0) * _rng.randf_range(55.0, 80.0), stop = 0.0})
	queue_redraw()

## a point on the loop and the way along it there
func _at(s: float) -> Array:
	s = fposmod(s, total)
	for i in path.size():
		var a := path[i]
		var b := path[(i + 1) % path.size()]
		var ln := a.distance_to(b)
		if s <= ln: return [a + (b - a) * (s / ln), (b - a) / ln]
		s -= ln
	return [path[0], (path[1] - path[0]).normalized()]

func _ahead(w: Dictionary) -> float:
	var best := total
	for o in walkers:
		if not is_same(o, w): best = minf(best, fposmod((float(o.s) - float(w.s)) * signf(float(w.v)), total))
	return best

## the nearest point of the bars' middle line straight out from a cell
func _exit(r: int, c: int) -> Vector2:
	var p := origin + Vector2(c + 0.5, r + 0.5) * ts
	var m := ts * 0.31
	var x0 := origin.x - m
	var x1 := origin.x + cols * ts + m
	var y0 := origin.y - m
	var y1 := origin.y + rows * ts + m
	var opts := [[p.x - x0, Vector2(x0, p.y)], [x1 - p.x, Vector2(x1, p.y)], [p.y - y0, Vector2(p.x, y0)], [y1 - p.y, Vector2(p.x, y1)]]
	opts.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	return opts[0][1]

## her raid: the stones at `cells` (ids `ids`, their nodes on `board`) are carried off; returns when all are gone
## and their nodes freed (the model's cells are the level's to empty)
func raid(cells: Array, ids: Array, board: BoardView) -> void:
	for i in cells.size():
		var p: Vector2i = cells[i]
		var node: Node2D = board.nodes.get(ids[i])
		raiders.append({a = _exit(p.x, p.y), b = board.cell_center(p.x, p.y), t = -STEP * i, id = ids[i], node = node,
			away = 1.0 if _rng.randf() < 0.5 else -1.0, f0 = _rng.randi() % 8})
	Sfx.play("swap")
	while not raiders.is_empty():
		await get_tree().process_frame
	for id in ids: board.remove_node(id)

func _process(dt: float) -> void:
	_t += dt
	if total <= 0.0: return
	for w in walkers:
		if float(w.stop) > 0.0:
			w.stop = float(w.stop) - dt
			if float(w.stop) <= 0.0 and _ahead(w) < GAP * k * 1.5 and _rng.randf() < 0.6: w.v = -float(w.v)
		elif _ahead(w) < GAP * k + absf(float(w.v)) * k * dt:
			w.stop = _rng.randf_range(0.5, 1.2)
		else:
			w.s = float(w.s) + float(w.v) * k * dt
			if _rng.randf() < 0.03 * dt * 12.0: w.stop = _rng.randf_range(0.4, 1.2)
			if _rng.randf() < 0.01 * dt * 12.0: w.v = -float(w.v)
	var done := []
	for r in raiders:
		r.t = float(r.t) + dt
		var run := (r.b as Vector2).distance_to(r.a) / (SPEED * k)
		var t: float = r.t
		var node: Node2D = r.node
		if node and is_instance_valid(node) and t >= run:
			# taken: the stone shrinks to the mouth, then rides at the head over the frame
			var s := clampf((t - run) / GRAB, 0.0, 1.0)
			node.z_index = 5
			node.scale = Vector2.ONE * lerpf(1.0, CARRY, s)
			var pos := _raider_pos(r, run)
			var d: Vector2 = pos[1]
			node.position = (pos[0] as Vector2) + d * frames[0].get_height() * BIG * k * 0.42
			if t > run * 2.0 + GRAB + 0.3: node.modulate.a = maxf(0.0, 1.0 - (t - run * 2.0 - GRAB - 0.3) / 0.3)
		if t > run * 2.0 + GRAB + 0.6: done.append(r)
	raiders = raiders.filter(func(r: Dictionary) -> bool: return not done.any(func(d: Dictionary) -> bool: return is_same(d, r)))
	queue_redraw()

## where a raider is and which way it faces: in, grabbing, out, away along the bar
func _raider_pos(r: Dictionary, run: float) -> Array:
	var a: Vector2 = r.a
	var b: Vector2 = r.b
	var t: float = r.t
	if t < run: return [a.lerp(b, t / run), (b - a).normalized()]
	if t < run + GRAB: return [b, (b - a).normalized()]
	t -= run + GRAB
	if t < run: return [b.lerp(a, t / run), (a - b).normalized()]
	var side := (a - b).normalized()
	var along := Vector2(-side.y, side.x) * float(r.away)
	return [a + along * SPEED * k * 0.8 * (t - run), along]

func _lizard(pos: Vector2, dir: Vector2, f: int, scale: float, alpha := 1.0) -> void:
	var tex: Texture2D = frames[f % frames.size()]
	var sz := Vector2(tex.get_size()) * k * scale
	draw_set_transform(pos.round(), atan2(dir.x, -dir.y), Vector2.ONE)
	draw_texture_rect(tex, Rect2(-sz / 2, sz), false, Color(1, 1, 1, alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw() -> void:
	if frames.is_empty() or total <= 0.0: return
	var f := int(_t * fps)
	for i in walkers.size():
		var w: Dictionary = walkers[i]
		var at := _at(float(w.s))
		var d: Vector2 = at[1] * signf(float(w.v))
		_lizard(at[0], d, 0 if float(w.stop) > 0.0 else f + i * 3, 1.0)
	for r in raiders:
		if float(r.t) < 0.0: continue
		var run := (r.b as Vector2).distance_to(r.a) / (SPEED * k)
		var pos := _raider_pos(r, run)
		var t: float = r.t
		var leap := 1.0 + 0.25 * sin(PI * minf(1.0, t / run * 3.0)) if t < run / 3.0 else 1.0
		var alpha := 1.0 if t < run * 2.0 + GRAB else maxf(0.0, 1.0 - (t - run * 2.0 - GRAB) / 0.6)
		_lizard(pos[0], pos[1], 0 if (t >= run and t < run + GRAB) else f + int(r.f0), BIG * leap, alpha)
