class_name BoardView
extends Control
## The tray: a beveled stone frame, slate pockets, blockers and the stones themselves.
## Knows nothing about rules — it mirrors BoardModel and plays the animations Level asks for.

signal swiped(r1: int, c1: int, r2: int, c2: int)
signal tapped(r: int, c: int)

const R := BoardModel.R
const C := BoardModel.C

var model: BoardModel
var TS := 46.0
var PAD := 6.0
var nodes := {}               # gem id -> GemNode
var under: Node2D            # mud and rocks: redrawn only when the board changes
var live: Node2D             # gas, geodes, the find: they breathe, pulse and shake, so redrawn every frame while present
var gems: Node2D
var over: Node2D             # timber locks sit on top of their stones
var board3d: Board3D         # the stones themselves, faceted 3D gems seen from straight above
var find_hit_at := -10.0
var geo_hit_at := {}
const DEPOSIT_TRANSITION := 0.28
var deposit_transitions := {}
var rock_transitions := {}
var _down := {}

func _init() -> void:
	clip_contents = true
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	light_mask = 0   # the gallery's lamps light the wall, not the tray
	# the sprites are rendered big and shown small: sample their mipmaps so they stay clean
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mouse_filter = Control.MOUSE_FILTER_STOP

func _ready() -> void:
	under = _layer(_draw_under)
	live = _layer(_draw_live)
	gems = Node2D.new()
	gems.light_mask = 0
	add_child(gems)
	over = _layer(_draw_over)
	# Timber needs the same explicit shader as gems on iPhone with baked shaders.
	over.material = BoardSprites.plain_material()

func _layer(fn: Callable) -> Node2D:
	var n := Node2D.new()
	n.light_mask = 0
	n.draw.connect(fn.bind(n))
	add_child(n)
	return n

## fit the board into `avail` (pixels) and centre it there
func layout(avail: Vector2) -> void:
	# Include the rim when fitting the board, so it stays inside the viewport.
	TS = maxf(1.0, floorf(minf(minf(avail.x / (C + 0.7), avail.y / (R + 0.7)), 62.0)))
	PAD = roundf(TS * 0.35)
	custom_minimum_size = Vector2(C * TS + PAD * 2, R * TS + PAD * 2)
	size = custom_minimum_size

func cell_center(r: float, c: float) -> Vector2:
	return Vector2(PAD + (c + 0.5) * TS, PAD + (r + 0.5) * TS)

func cell_at(p: Vector2) -> Vector2i:
	return Vector2i(int(floor((p.y - PAD) / TS)), int(floor((p.x - PAD) / TS)))

# ---------------------------------------------------------------- building

func rebuild(m: BoardModel) -> void:
	model = m
	rock_transitions.clear()
	for n in gems.get_children(): n.queue_free()
	nodes.clear()
	for r in R:
		for c in C:
			var g: BoardModel.Gem = m.G[r][c]
			if g: _spawn_node(g, r, c)
	refresh()

func _spawn_node(g: BoardModel.Gem, r: int, c: int) -> GemNode:
	var n := GemNode.new()
	n.setup(g, TS)
	n.position = cell_center(r, c)
	gems.add_child(n)
	nodes[g.id] = n
	return n

func refresh() -> void:
	queue_redraw()
	redraw_under()
	over.queue_redraw()

## stones fall into the board from above at the start
func drop_in() -> void:
	var tw := create_tween().set_parallel(true)
	for r in R:
		for c in C:
			var g: BoardModel.Gem = model.G[r][c]
			if g == null: continue
			var n: GemNode = nodes[g.id]
			var target := n.position
			n.position.y -= (R + 1 + randf() * 2) * TS
			tw.tween_property(n, "position", target, 0.45 + r * 0.02).set_delay(c * 0.025 + randf() * 0.04).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	await tw.finished

## after the model's gravity step: move every stone to its cell, spawning new ones above the tray
func animate_collapse(spawned: Array) -> void:
	var spawned_ids := {}
	for g in spawned:
		spawned_ids[g.id] = g
	var tw := create_tween().set_parallel(true)
	var any := false
	for r in R:
		for c in C:
			var g: BoardModel.Gem = model.G[r][c]
			if g == null: continue
			var n: GemNode = nodes.get(g.id)
			if n == null:
				n = _spawn_node(g, r, c)
				n.position = cell_center(g.spawn_y, c)
			var target := cell_center(r, c)
			if n.position.distance_to(target) > 0.5:
				var d := n.position.distance_to(target) / TS
				tw.tween_property(n, "position", target, 0.12 + sqrt(d) * 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				any = true
	if any:
		await tw.finished
	else:
		tw.kill()

func animate_swap(a_id: int, b_id: int, back := false) -> void:
	var na: GemNode = nodes.get(a_id)
	var nb: GemNode = nodes.get(b_id)
	if na == null or nb == null: return
	var pa := na.position
	var pb := nb.position
	var tw := create_tween().set_parallel(true)
	tw.tween_property(na, "position", pb, 0.15).set_trans(Tween.TRANS_SINE)
	tw.tween_property(nb, "position", pa, 0.15).set_trans(Tween.TRANS_SINE)
	await tw.finished
	if back:
		var tw2 := create_tween().set_parallel(true)
		tw2.tween_property(na, "position", pa, 0.16).set_trans(Tween.TRANS_SINE)
		tw2.tween_property(nb, "position", pb, 0.16).set_trans(Tween.TRANS_SINE)
		await tw2.finished

## a stone dies: slides into the new special it helps make, or pops
func pop_gem(id: int, merge_to: Vector2i) -> void:
	var n: GemNode = nodes.get(id)
	if n == null: return
	nodes.erase(id)
	var tw := create_tween()
	if merge_to.x >= 0:
		tw.set_parallel(true)
		tw.tween_property(n, "position", cell_center(merge_to.x, merge_to.y), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(n, "scale", Vector2(0.6, 0.6), 0.16)
		tw.tween_property(n, "modulate:a", 0.0, 0.16)
	else:
		tw.tween_property(n, "scale", Vector2(1.22, 1.22), 0.07).set_trans(Tween.TRANS_SINE)
		tw.tween_property(n, "scale", Vector2(0.0, 0.0), 0.13).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.finished.connect(n.queue_free)

func grow_special(g: BoardModel.Gem, r: int, c: int) -> void:
	var n := _spawn_node(g, r, c)
	n.scale = Vector2(0.2, 0.2)
	create_tween().tween_property(n, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func convert_gem(id: int, sp: String) -> void:
	var n: GemNode = nodes.get(id)
	if n == null: return
	n.become(sp)
	n.scale = Vector2(0.4, 0.4)
	create_tween().tween_property(n, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func remove_node(id: int) -> void:
	var n: GemNode = nodes.get(id)
	if n:
		nodes.erase(id)
		n.queue_free()

func animate_shuffle() -> void:
	var tw := create_tween().set_parallel(true)
	for r in R:
		for c in C:
			var g: BoardModel.Gem = model.G[r][c]
			if g and nodes.has(g.id):
				tw.tween_property(nodes[g.id], "position", cell_center(r, c), 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tw.finished

func hint(mv: Array) -> void:
	for k in [0, 2]:
		var g: BoardModel.Gem = model.G[mv[k]][mv[k + 1]]
		if g and nodes.has(g.id):
			var n: GemNode = nodes[g.id]
			var tw := create_tween().set_loops(2)
			tw.tween_property(n, "scale", Vector2(1.14, 1.14), 0.25).set_trans(Tween.TRANS_SINE)
			tw.tween_property(n, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_SINE)

# ---------------------------------------------------------------- drawing

const FIELD_FRAME := preload("res://assets/board/stone_field/frame.png")
const FIELD_TILE := preload("res://assets/board/stone_field/tile.png")
const FIELD_CONTOUR := preload("res://scripts/game/board_contour.gd")

## Only playable cells have a bed. The background remains visible in cutouts.
func _draw() -> void:
	if model == null: return
	var mask := []
	for r in R:
		var row := []
		for c in C:
			var playable := model.playable(r, c)
			row.append(playable)
		mask.append(row)
	for contour in FIELD_CONTOUR.trace(mask):
		_draw_frame(contour)
	# At diagonal contacts, the neighboring island's rim must not cover a cell.
	for r in R:
		for c in C:
			if mask[r][c]:
				var p := Vector2(PAD + c * TS, PAD + r * TS)
				draw_rect(Rect2(p, Vector2.ONE * TS), Color("#141716"))
				_pocket(p)

func _draw_frame(contour: PackedVector2Array) -> void:
	var width := PAD * 0.82
	var bevel := width * 0.32
	var points := PackedVector2Array()
	var incoming := PackedVector2Array()
	var outgoing := PackedVector2Array()
	var convex := []
	var count := contour.size()
	for p in contour: points.append(Vector2.ONE * PAD + p * TS)
	for i in count:
		var before := (points[i] - points[(i + count - 1) % count]).normalized()
		var after := (points[(i + 1) % count] - points[i]).normalized()
		var n0 := Vector2(before.y, -before.x)
		var n1 := Vector2(after.y, -after.x)
		var outer := points[i] + (n0 + n1) * width
		var is_convex := before.cross(after) > 0.0
		convex.append(is_convex)
		incoming.append(outer - before * bevel if is_convex else outer)
		outgoing.append(outer + after * bevel if is_convex else outer)
	# A narrow shadow follows the contour too; it never fills an absent cell.
	var outline := PackedVector2Array()
	for i in count:
		outline.append(incoming[i] + Vector2(0.7, 1.8))
		outline.append(outgoing[i] + Vector2(0.7, 1.8))
	outline.append(outline[0])
	draw_polyline(outline, Color(0, 0, 0, 0.46), 3.5, true)
	for i in count:
		var j := (i + 1) % count
		var quad := PackedVector2Array([points[i], points[j], incoming[j], outgoing[i]])
		_frame_stone(quad, PackedVector2Array([Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]))
		if convex[i]:
			_frame_stone(PackedVector2Array([points[i], incoming[i], outgoing[i]]), PackedVector2Array([Vector2(0.5, 1), Vector2(0.35, 0), Vector2(0.65, 0)]))
	# Fine bevel lines distinguish the stone face from the pocket and the ground.
	for i in count:
		var j := (i + 1) % count
		var direction := (points[j] - points[i]).normalized()
		var normal := Vector2(direction.y, -direction.x)
		var light := 0.17 + maxf(0.0, normal.dot(Vector2(-0.6, -0.8))) * 0.32
		draw_line(outgoing[i], incoming[j], Color(0.78, 0.74, 0.65, light), 1.2, true)
		draw_line(points[i], points[j], Color(0, 0, 0, 0.75), 2.0, true)
		if convex[i]:
			draw_line(incoming[i], outgoing[i], Color(0.78, 0.74, 0.65, 0.32), 1.2, true)

func _frame_stone(points: PackedVector2Array, local_uv: PackedVector2Array) -> void:
	# Reuse the supplied frame's stone face, including its natural cracks.
	var uv := PackedVector2Array()
	var texture_size := FIELD_FRAME.get_size()
	for p in local_uv:
		uv.append(Vector2(96.0 + p.x * 600.0, 12.0 + p.y * 28.0) / texture_size)
	draw_polygon(points, PackedColorArray([Color.WHITE]), uv, FIELD_FRAME)

func _pocket(p: Vector2) -> void:
	# A narrow dark seam and a restrained bevel keep the cell boundaries readable.
	var inset := maxf(0.75, TS * 0.018)
	var target := Rect2(p + Vector2.ONE * inset, Vector2.ONE * (TS - inset * 2.0))
	draw_texture_rect(FIELD_TILE, target, false)

## the layers under the stones changed (a rock cracked, mud cleared, a geode or the find was hit)
func redraw_under() -> void:
	under.queue_redraw()
	live.queue_redraw()

func _draw_under(ci: Node2D) -> void:
	if model == null: return
	for r in R:
		for c in C:
			if not model.playable(r, c): continue
			var p := Vector2(PAD + c * TS, PAD + r * TS)
			ci.draw_set_transform(p, 0, Vector2.ONE)
			var cc := Vector2(TS, TS) * 0.5
			if model.MUD[r][c]: BoardSprites.draw(ci, BoardSprites.tex("mud"), cc, TS)
			if model.ROCK[r][c] and not rock_transitions.has(r * C + c):
				BoardSprites.draw(ci, BoardSprites.tex(BoardSprites.rock_name(model.ROCK[r][c], model.ROCK_MAX[r][c] >= 2)), cc, TS)
	ci.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

func animate_rock(r: int, c: int, before: String, after: String) -> void:
	rock_transitions[r * C + c] = {r = r, c = c, before = before, after = after, elapsed = 0.0}
	redraw_under()

func _draw_live(ci: Node2D) -> void:
	if model == null: return
	var now := Time.get_ticks_msec() / 1000.0
	for r in R:
		for c in C:
			if not model.playable(r, c): continue
			var p := Vector2(PAD + c * TS, PAD + r * TS)
			if model.GAS[r][c]:
				var w := 1.0 + sin(now * 2.5 + r + c) * 0.04
				ci.draw_set_transform(p + Vector2(TS, TS) * 0.5 * (1.0 - w), 0, Vector2(w, w))
				BoardSprites.draw(ci, BoardSprites.tex("gas"), Vector2(TS, TS) * 0.5, TS)
	ci.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	for transition: Dictionary in rock_transitions.values():
		var p := clampf(float(transition.elapsed) / 0.24, 0.0, 1.0)
		var center := cell_center(transition.r, transition.c) + Vector2(sin(p * TAU * 2.0) * (1.0 - p) * 2.0, 0)
		var scale_px := TS * (1.0 + 0.05 * sin(p * PI))
		BoardSprites.draw(ci, BoardSprites.tex(transition.after), center, scale_px)
		BoardSprites.draw(ci, BoardSprites.tex(transition.before), center, scale_px, Color(1, 1, 1, 1.0 - smoothstep(0.0, 1.0, p)))
	for gi in model.geos.size():
		var geo: Dictionary = model.geos[gi]
		_draw_geode(ci, geo, gi, now)
	if not model.find.is_empty() and (not model.find.done or model.find.get("ruined", false) or deposit_transitions.has("mineral:0")):
		_draw_find(ci, now)

func _draw_over(ci: Node2D) -> void:
	if model == null: return
	for r in R:
		for c in C:
			if model.playable(r, c) and model.LOCK[r][c]:
				BoardSprites.draw(ci, BoardSprites.tex("lock"), cell_center(r, c), TS)
	ci.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

static func crack_paths(seed_v: int, count: int) -> Array:
	var rand := Rng32.new(seed_v)
	var out := []
	for k in count:
		var p := Vector2(50 + (rand.next() - 0.5) * 10, 50 + (rand.next() - 0.5) * 10)
		var a0 := rand.next() * TAU
		var line := PackedVector2Array([p])
		for s in 5:
			var a := a0 + (rand.next() - 0.5) * 1.1
			p += Vector2(cos(a), sin(a)) * (5 + rand.next() * 6)
			line.append(p)
		out.append(line)
	return out

func _draw_geode(ci: Node2D, geo: Dictionary, gi: int, now: float) -> void:
	var since: float = now - geo_hit_at.get(gi, -10.0)
	var shake := sin(since * 55.0) * 3.0 if since < 0.22 else 0.0
	var ctr := Vector2(PAD + (geo.c + 1) * TS + shake, PAD + (geo.r + 1) * TS)
	var stage := clampi(4 - int(geo.hp), 0, 4)
	_draw_deposit(ci, "geode", stage, ctr, "geode:%d" % gi)

func _draw_find(ci: Node2D, now: float) -> void:
	var F: Dictionary = model.find
	var since: float = now - find_hit_at
	var shake := sin(since * 55.0) * 3.0 if since < 0.22 else 0.0
	var ctr := Vector2(PAD + (F.c + 1) * TS + shake, PAD + (F.r + 1) * TS)
	var stage := 4 if F.get("ruined", false) else clampi(4 - int(F.hp), 0, 3)
	if F.done and not F.get("ruined", false): stage = -1
	_draw_deposit(ci, "mineral", stage, ctr, "mineral:0")

func animate_deposit(kind: String, id: int, before: int, after: int) -> void:
	deposit_transitions["%s:%d" % [kind, id]] = {before = before, after = after, elapsed = 0.0}
	live.queue_redraw()

func _draw_deposit(ci: Node2D, kind: String, stage: int, ctr: Vector2, key: String) -> void:
	if not deposit_transitions.has(key):
		_deposit_image(ci, kind, stage, ctr, 1.0, 1.0)
		return
	var transition: Dictionary = deposit_transitions[key]
	var p := clampf(float(transition.elapsed) / DEPOSIT_TRANSITION, 0.0, 1.0)
	var blend := smoothstep(0.0, 1.0, p)
	var pulse := 1.0 + sin(p * PI) * 0.018
	_deposit_image(ci, kind, int(transition.before), ctr, 1.0 - blend, pulse)
	_deposit_image(ci, kind, int(transition.after), ctr, blend, pulse)

func _deposit_image(ci: Node2D, kind: String, stage: int, ctr: Vector2, alpha: float, pulse: float) -> void:
	if stage < 0 or alpha <= 0.0: return
	var tex := BoardSprites.tex("deposit_%s_%d" % [kind, stage])
	# Align the masonry with the cells; transparent padding and rubble are outside it.
	var core := BoardSprites.DEPOSIT_CORE
	var body_size := Vector2.ONE * (TS * 2.0 - 2.0) * pulse
	var image_scale := body_size / core.size
	var image_rect := Rect2(ctr - body_size * 0.5 - core.position * image_scale, tex.get_size() * image_scale)
	ci.draw_texture_rect(tex, image_rect, false, Color(1, 1, 1, alpha))

func _process(dt: float) -> void:
	if not rock_transitions.is_empty():
		for key in rock_transitions.keys():
			rock_transitions[key].elapsed += dt
			if float(rock_transitions[key].elapsed) >= 0.24:
				rock_transitions.erase(key)
		redraw_under()
	if not deposit_transitions.is_empty():
		for key in deposit_transitions.keys():
			deposit_transitions[key].elapsed += dt
			if float(deposit_transitions[key].elapsed) >= DEPOSIT_TRANSITION:
				deposit_transitions.erase(key)
		live.queue_redraw()
	# gas breathes, specimens pulse, shaken blocks settle
	if model and (not model.find.is_empty() and not model.find.done or _has_gas() or not geo_hit_at.is_empty()):
		live.queue_redraw()

func _has_gas() -> bool:
	for r in R:
		for c in C:
			if model.GAS[r][c]: return true
	return false

# ---------------------------------------------------------------- input

func _gui_input(e: InputEvent) -> void:
	var press: bool = e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT
	if press and e.pressed:
		var cell := cell_at(e.position)
		if model and model.playable(cell.x, cell.y):
			_down = {cell = cell, pos = e.position, moved = false}
	elif press and not e.pressed:
		if not _down.is_empty() and not _down.moved:
			tapped.emit(_down.cell.x, _down.cell.y)
		_down = {}
	elif e is InputEventMouseMotion and not _down.is_empty() and not _down.moved:
		var d: Vector2 = e.position - _down.pos
		if d.length() >= TS * 0.35:
			_down.moved = true
			var step := Vector2i(0, signi(int(d.x))) if absf(d.x) > absf(d.y) else Vector2i(signi(int(d.y)), 0)
			swiped.emit(_down.cell.x, _down.cell.y, _down.cell.x + step.x, _down.cell.y + step.y)
