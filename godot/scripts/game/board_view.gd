class_name BoardView
extends Control
## The tray: a stone frame round slate tiles (BoardKit), blockers and the stones themselves.
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
var find_tex: Texture2D       # the sealed specimen, rendered in 3D when available
var find_hit_at := -10.0
var geo_hit_at := {}
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
	# room round the cells for the frame, its corner caps and their shadow
	var rim := BoardKit.FW * 0.5 + BoardKit.CAP * 0.5 + 0.04
	TS = floorf(minf(minf((avail.x - 4) / (C + rim * 2.0), (avail.y - 4) / (R + rim * 2.0)), 62.0))
	PAD = ceilf(TS * rim)
	custom_minimum_size = Vector2(C * TS + PAD * 2, R * TS + PAD * 2)
	size = custom_minimum_size

func cell_center(r: float, c: float) -> Vector2:
	return Vector2(PAD + (c + 0.5) * TS, PAD + (r + 0.5) * TS)

func cell_at(p: Vector2) -> Vector2i:
	return Vector2i(int(floor((p.y - PAD) / TS)), int(floor((p.x - PAD) / TS)))

# ---------------------------------------------------------------- building

func rebuild(m: BoardModel) -> void:
	model = m
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

## the tray: the mine's stone kit (BoardKit) laid out to the board's shape
func _draw() -> void:
	if model == null: return
	BoardKit.for_area(Save.area()).draw(self, Vector2(PAD, PAD), TS, R, C, model.playable)

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
			if BoardSprites.gem_style != "":
				if model.MUD[r][c]: BoardSprites.draw(ci, BoardSprites.blocker("mud"), cc, TS)
				if model.ROCK[r][c]: BoardSprites.draw(ci, BoardSprites.blocker(_rock_look(r, c)), cc, TS)
				continue
			if model.MUD[r][c]: BoardSprites.draw(ci, BoardSprites.tex("mud"), cc, TS)
			if model.ROCK[r][c]: BoardSprites.draw(ci, BoardSprites.tex(ROCKS[mini(2, model.ROCK[r][c])]), cc, TS)
	ci.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

const ROCKS := ["rock0", "rock1", "rock2"]

## granite (two hits), granite split by the first hit, or sandstone (one hit)
func _rock_look(r: int, c: int) -> String:
	if model.ROCK_MAX[r][c] >= 2:
		return "granite" if model.ROCK[r][c] >= 2 else "granite_cracked"
	return "sand"

func _draw_live(ci: Node2D) -> void:
	if model == null: return
	var now := Time.get_ticks_msec() / 1000.0
	for r in R:
		for c in C:
			if not model.playable(r, c): continue
			var p := Vector2(PAD + c * TS, PAD + r * TS)
			if model.GAS[r][c] and BoardSprites.gem_style != "":
				# the cloud churns: two layers of it turning against each other, breathing in and out
				var gt := BoardSprites.blocker("gas")
				var ctr := p + Vector2(TS, TS) * 0.5
				for k in 2:
					var sgn := 1.0 if k == 0 else -1.0
					var w2 := 1.0 + sin(now * (1.7 + k * 0.6) + r * 1.3 + c) * 0.05
					ci.draw_set_transform(ctr, sgn * now * (0.35 + k * 0.2) + r + c * 2.0, Vector2(w2, w2))
					BoardSprites.draw(ci, gt, Vector2.ZERO, TS, Color(1, 1, 1, 0.85 if k == 0 else 0.55))
			elif model.GAS[r][c]:
				var w := 1.0 + sin(now * 2.5 + r + c) * 0.04
				ci.draw_set_transform(p + Vector2(TS, TS) * 0.5 * (1.0 - w), 0, Vector2(w, w))
				BoardSprites.draw(ci, BoardSprites.tex("gas"), Vector2(TS, TS) * 0.5, TS)
	ci.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	for gi in model.geos.size():
		var geo: Dictionary = model.geos[gi]
		if geo.hp > 0: _draw_geode(ci, geo, gi, now)
	if not model.find.is_empty() and not model.find.done:
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
	var shake := 0.0
	var since: float = now - geo_hit_at.get(gi, -10.0)
	if since < 0.22: shake = sin(since * 55.0) * 3.0
	var ctr := Vector2(PAD + (geo.c + 1) * TS + shake, PAD + (geo.r + 1) * TS)
	GemArt.radial_disc(ci, ctr, TS * 1.1, Color(0.78, 0.59, 1, 0.15 + (4 - geo.hp) * 0.08), Color(0.78, 0.59, 1, 0.08), Color(0.78, 0.59, 1, 0))
	BoardSprites.draw(ci, BoardSprites.tex("geode"), ctr, TS * 2.0)
	if geo.hp < 4:
		for line in crack_paths(geo.r * 31 + geo.c, (4 - geo.hp) * 2):
			var pts := PackedVector2Array()
			for q in line: pts.append(ctr - Vector2(TS, TS) * 0.84 + q * TS * 1.68 / 100.0)
			ci.draw_polyline(pts, Color(1, 0.9, 0.66, 0.9), 2.2, true)

func _draw_find(ci: Node2D, now: float) -> void:
	var F: Dictionary = model.find
	var shake := 0.0
	if now - find_hit_at < 0.22: shake = sin((now - find_hit_at) * 55.0) * 3.0
	var p := Vector2(PAD + F.c * TS + shake, PAD + F.r * TS)
	var k: float = float(F.hp) / F.hp_max
	var col := Data.rarity_color(F.stone.tier)
	var box := GemArt.rrect(p + Vector2(2, 2), Vector2(TS * 2 - 4, TS * 2 - 4), TS * 0.3)
	# a dark slate niche with a gold rim, like the goals panel
	ci.draw_colored_polygon(box, Color("#202326"))
	ci.draw_polyline(GemArt.closed(box), Color("#c9a35a"), 2.0, true)
	var pulse := 0.25 + 0.15 * sin(now * 2.0)
	GemArt.radial_disc(ci, p + Vector2(TS, TS), TS * 1.05, Color(col, pulse * (1.2 - k)), Color(col, pulse * 0.4), Color(col, 0))
	var a := 0.55 + (1.0 - k) * 0.45
	if find_tex:
		ci.draw_texture_rect(find_tex, Rect2(p + Vector2(TS, TS) * 0.05, Vector2(TS, TS) * 1.9), false, Color(1, 1, 1, a))
	else:
		ci.draw_set_transform(p + Vector2(TS * 0.2, TS * 0.15), 0, Vector2(1.6, 1.6) * TS / 46.0)
		GemArt.find_icon(ci, 46.0, col)
		ci.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	# rock matrix that thins with every layer peeled
	ci.draw_set_transform(p, 0, Vector2(2, 2))
	var rock_a := 0.15 + k * 0.55
	var body := GemArt.rrect(Vector2(1, 1), Vector2(TS - 2, TS - 2), TS * 0.15)
	GemArt.grad_poly(ci, body, Vector2(0, 0), Vector2(0, TS), Color(0.66, 0.69, 0.73, rock_a), Color(0.52, 0.55, 0.59, rock_a), Color(0.35, 0.38, 0.42, rock_a))
	ci.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	if F.integ < 100:
		for line in crack_paths(F.r * 13 + F.c, int(ceil((100 - F.integ) / 12.0))):
			var pts := PackedVector2Array()
			for q in line: pts.append(p + q * TS * 2.0 / 100.0)
			ci.draw_polyline(pts, Color(1, 0.69, 0.56), 1.8, true)
	ci.draw_polyline(GemArt.closed(box), Color(col, 0.5 + 0.3 * sin(now * 2.5)), 2.0, true)
	# layers left as dots
	var dots_w := TS * 0.9
	ci.draw_rect(Rect2(p + Vector2(TS - dots_w / 2, TS * 1.62), Vector2(dots_w, TS * 0.26)), Color(0, 0, 0, 0.6))
	for i in F.hp:
		var x: float = p.x + TS - dots_w / 2 + dots_w * (i + 0.5) / F.hp_max
		ci.draw_circle(Vector2(x, p.y + TS * 1.75), TS * 0.045, Color.WHITE)

func _process(_dt: float) -> void:
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
