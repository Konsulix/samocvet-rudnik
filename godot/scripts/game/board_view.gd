class_name BoardView
extends Control
## The tray: a stone frame round slate tiles (BoardKit), blockers and the stones themselves.
## Knows nothing about rules — it mirrors BoardModel and plays the animations Level asks for.

signal swiped(r1: int, c1: int, r2: int, c2: int)
signal tapped(r: int, c: int)

var R := 9                    # the board's size, the model's (set by layout)
var C := 8

var model: BoardModel
var TS := 46.0
var PAD := 6.0
var nodes := {}               # gem id -> GemNode
var under: Node2D            # mud and rocks: redrawn only when the board changes
var gas_layer: Node2D        # the gas, one shader over all its cells (shaders/gas.gdshader)
var live: Node2D             # gas, geodes, the find: they breathe, pulse and shake, so redrawn every frame while present
var gems: Node2D
var over: Node2D             # timber locks sit on top of their stones
var marks: Array = []        # cells the boss is about to hit (LevelBoss)
var board3d: Board3D         # the stones themselves, faceted 3D gems seen from straight above
var find_tex: Texture2D       # the sealed specimen, rendered in 3D when available
var find_hit_at := -10.0
var find_done_at := -10.0
var _zone_tex := {}
const ZONE_SCALE := 0.95
var geo_hit_at := {}
var nod_grow := {}            # cell key -> {from, t0}: a nodule growing its next layer
var flower_layer: Node2D      # the Mistress' stone flower: pixel art (art/boss/stone_flower.py), drawn sharp
var flower_at := -10.0        # when it last grew or bloomed: a flash
const NOD_GROW_S := 0.6
## the Kraken's board (Whalebone Cove): the maelstrom's water and his eye lie under the stones, his tentacles, ink and
## the tide over them; all drawn in code. A tentacle is one straight drawing bent along its cells (Bend)
var sea_under: Node2D
var sea_over: Node2D
var tent_at := {}             # tentacle id -> when it reached out (it slides onto the board tip first)
var eye_at := -10.0           # when the eye was last hit: it flinches shut
const TENT_IN := 0.55
var _eye_tex := {}            # his drawn eye, open and shut: loaded with the board (a texture first drawn the frame it
                              # loads shows white)
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
	gas_layer = _layer(_draw_gas)
	var gm := ShaderMaterial.new()
	gm.shader = preload("res://shaders/gas.gdshader")
	gas_layer.material = gm
	live = _layer(_draw_live)
	flower_layer = _layer(_draw_flower)
	flower_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sea_under = _layer(_draw_sea_under)
	gems = Node2D.new()
	gems.light_mask = 0
	add_child(gems)
	over = _layer(_draw_over)
	# Timber needs the same explicit shader as gems on iPhone with baked shaders.
	over.material = BoardSprites.plain_material()
	sea_over = _layer(_draw_sea_over)
	sea_over.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _layer(fn: Callable) -> Node2D:
	var n := Node2D.new()
	n.light_mask = 0
	n.draw.connect(fn.bind(n))
	add_child(n)
	return n

## fit a rows x cols board into `avail` (pixels) and centre it there
func layout(avail: Vector2, rows: int, cols: int) -> void:
	R = rows
	C = cols
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
	_eye_tex = {}
	var dir := "res://assets/boss/%s/" % String(m.boss.B.get("id", "")) if m.boss_on() else ""
	if dir != "" and not m.eye.is_empty() and ResourceLoader.exists(dir + "eye_open.png"):
		_eye_tex = {open = load(dir + "eye_open.png"), shut = load(dir + "eye_shut.png")}
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
	flower_layer.queue_redraw()
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

## once a turn has settled: the stones on screen are exactly the model's, each in its own cell. A stone dropped from
## the model without its node, or a node left behind by an effect, otherwise stays drawn: two stones in one cell.
## `expected`: nodes the caller knows are gone from the model (gas took the stone) - not worth a warning
func sync(expected := false) -> void:
	var alive := {}
	for r in R:
		for c in C:
			var g: BoardModel.Gem = model.G[r][c]
			if g == null: continue
			alive[g.id] = true
			var n: GemNode = nodes.get(g.id)
			if n == null:
				push_warning("board sync: no node for stone %d at %d,%d" % [g.id, r, c])
				_spawn_node(g, r, c)
			else: n.position = cell_center(r, c)
	for id in nodes.keys():
		if not alive.has(id):
			if not expected: push_warning("board sync: stray node %d (colour %d) at %s" % [id, (nodes[id] as GemNode).t, cell_at((nodes[id] as GemNode).position)])
			remove_node(id)
	# nodes no longer on the books (a pop whose fade never ended): every pop has long finished by the turn's end
	var kept := {}
	for n in nodes.values(): kept[n] = true
	for ch in gems.get_children():
		if ch is GemNode and not kept.has(ch) and not ch.is_queued_for_deletion():
			push_warning("board sync: orphan node %d (colour %d) at %s" % [(ch as GemNode).id, (ch as GemNode).t, cell_at((ch as GemNode).position)])
			ch.queue_free()

## the stones go to their shuffled places; `swirl` (the gold pan): each one is tossed up and carried round the
## board's middle on its way, a little turned, landing with a small bounce, not all at once
func animate_shuffle(swirl := false) -> void:
	var tw := create_tween().set_parallel(true)
	var mid := cell_center((R - 1) / 2.0, (C - 1) / 2.0)
	var dur := 0.0
	for r in R:
		for c in C:
			var g: BoardModel.Gem = model.G[r][c]
			if not g or not nodes.has(g.id): continue
			var n: Node2D = nodes[g.id]
			var to := cell_center(r, c)
			if not swirl:
				tw.tween_property(n, "position", to, 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
				dur = 0.42
				continue
			var from := n.position
			var turn := randf_range(0.3, 0.5)
			var delay := randf() * 0.12 + from.distance_to(mid) / (TS * 40.0)
			var spin := randf_range(-0.4, 0.4)
			var path := func(t: float):
				var e := t * t * (3.0 - 2.0 * t)
				var p := from.lerp(to, e)
				# carried round the middle: most turn mid-way, none at the ends
				p = mid + (p - mid).rotated(sin(PI * e) * turn)
				n.position = p + Vector2(0, -sin(PI * e) * TS * 0.25)
				n.rotation = sin(PI * e) * spin
				n.scale = Vector2.ONE * (1.0 + sin(PI * e) * 0.18)
			tw.tween_method(path, 0.0, 1.0, 0.62).set_delay(delay)
			dur = maxf(dur, delay + 0.62)
	if dur == 0.0:
		tw.kill()
		return
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
## the player picked other looks: repaint every stone and the layers, keeping the board as it is
func restyle() -> void:
	for n: GemNode in nodes.values(): n.restyle()
	queue_redraw()
	redraw_under()
	over.queue_redraw()

func redraw_under() -> void:
	under.queue_redraw()
	gas_layer.queue_redraw()
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

static var _white: Texture2D

## every gas cell as a quad a little larger than the cell, its colour telling the shader which neighbours are gas
## too, so neighbouring pockets join into tunnels (only with the new gem sets; the old ones keep their sprite)
func _draw_gas(ci: Node2D) -> void:
	if model == null or BoardSprites.gem_style == "": return
	if _white == null:
		var im := Image.create(4, 4, false, Image.FORMAT_RGBA8)
		im.fill(Color.WHITE)
		_white = ImageTexture.create_from_image(im)
	var over := 1.3
	(ci.material as ShaderMaterial).set_shader_parameter("cell_px", TS)
	(ci.material as ShaderMaterial).set_shader_parameter("overhang", over)
	var gas := func(r: int, c: int) -> bool: return model.playable(r, c) and model.GAS[r][c] > 0
	for r in R:
		for c in C:
			if not gas.call(r, c): continue
			var m := (1 if gas.call(r, c - 1) else 0) + (2 if gas.call(r, c + 1) else 0) + (4 if gas.call(r - 1, c) else 0) + (8 if gas.call(r + 1, c) else 0)
			var ctr := cell_center(r, c)
			var half := TS * 0.5 * over
			ci.draw_texture_rect(_white, Rect2(ctr - Vector2(half, half), Vector2(half, half) * 2.0), false, Color(m / 15.0, 0, 0, 1))

## granite (two hits), granite split by the first hit, or sandstone (one hit)
func _rock_look(r: int, c: int) -> String:
	if model.ROCK_MAX[r][c] >= 2:
		return BoardSprites.granite() + ("" if model.ROCK[r][c] >= 2 else "_cracked")
	return "sand"

func _draw_live(ci: Node2D) -> void:
	if model == null: return
	var now := Time.get_ticks_msec() / 1000.0
	for r in R:
		for c in C:
			if not model.playable(r, c): continue
			var p := Vector2(PAD + c * TS, PAD + r * TS)
			if model.GAS[r][c] and BoardSprites.gem_style == "":
				var w := 1.0 + sin(now * 2.5 + r + c) * 0.04
				ci.draw_set_transform(p + Vector2(TS, TS) * 0.5 * (1.0 - w), 0, Vector2(w, w))
				BoardSprites.draw(ci, BoardSprites.tex("gas"), Vector2(TS, TS) * 0.5, TS)
	ci.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	for r in R:
		for c in C:
			if model.playable(r, c) and model.NOD[r][c]: _draw_nodule(ci, r, c, now)
	if BoardSprites.zone_style != "classic":
		for gi in model.geos.size():
			var geo: Dictionary = model.geos[gi]
			_draw_zone(ci, "geode", geo, now - geo_hit_at.get(gi, -10.0), now)
		if not model.find.is_empty():
			var since_done := now - find_done_at
			if not model.find.done or since_done < 0.6:
				_draw_zone(ci, "find", model.find, now - find_hit_at, now)
		return
	for gi in model.geos.size():
		var geo: Dictionary = model.geos[gi]
		if not geo.get("done", false): _draw_geode(ci, geo, gi, now)
	if not model.find.is_empty() and not model.find.done:
		_draw_find(ci, now)

## a big block in the rendered look (zone_kit.py): its stage by the hits taken; an opened geode stays as an empty
## shell, a find just taken out shows its emptied nest a moment, fading
func _draw_zone(ci: Node2D, kind: String, b: Dictionary, since_hit: float, now: float) -> void:
	var w: int = b.get("w", 2)
	var h: int = b.get("h", 2)
	var stage := "open" if b.get("done", false) else str(clampi(int(floor(float(b.hp_max - b.hp) / float(b.hp_max) * 8.0)), 0, 7))
	var path := "res://assets/board/zones/%s/%s_%dx%d_%s.png" % [BoardSprites.zone_style, kind, w, h, stage]
	if not _zone_tex.has(path): _zone_tex[path] = load(path)
	var shake := sin(since_hit * 55.0) * TS * 0.06 if since_hit < 0.22 else 0.0
	var a := 1.0
	if kind == "find" and b.get("done", false): a = clampf(1.0 - (now - find_done_at) / 0.6, 0.0, 1.0)
	# a little smaller than its cells, so the board's grid shows round it, as round the gems
	var size := Vector2(w + 0.24, h + 0.24) * TS * ZONE_SCALE
	var ctr := Vector2(PAD + (b.c + w * 0.5) * TS + shake, PAD + (b.r + h * 0.5) * TS)
	ci.draw_texture_rect(_zone_tex[path], Rect2(ctr - size * 0.5, size), false, Color(1, 1, 1, a))

## a malachite nodule, its stage as drawn; while it grows a layer, the new bubbles blow up behind the old ones and the
## crevices between them fill in (a full one overgrowing goes back to its core at once)
func _draw_nodule(ci: Node2D, r: int, c: int, now: float) -> void:
	var v := BoardSprites.malachite_look(r, c)
	var st: int = model.NOD[r][c]
	var ctr := cell_center(r, c)
	var g: Dictionary = nod_grow.get(r * C + c, {})
	var t := clampf((now - float(g.t0)) / NOD_GROW_S, 0.0, 1.0) if not g.is_empty() else 1.0
	var from: int = int(g.get("from", st))
	if t >= 1.0 or from >= st:
		BoardSprites.draw(ci, BoardSprites.malachite("nodule_%d_s%d" % [v, st]), ctr, TS)
		return
	var info := BoardSprites.malachite_info("nodule")
	var cen: Array = info.centre[str(v)]
	var shift: Array = info.shift[str(v)]
	var upto := [0, int(info.stages[0]), int(info.stages[1]), cen.size()]
	var w := TS * BoardSprites.SPAN
	var px := float(BoardSprites.malachite("nodule_%d_s1" % v).get_width())
	ci.draw_texture_rect(BoardSprites.malachite("nodule_%d_fill_s%d" % [v, st]), Rect2(ctr - Vector2(w, w) * 0.5, Vector2(w, w)), false, Color(1, 1, 1, t))
	for j in range(upto[st] - 1, upto[from] - 1, -1):
		var k := clampf(t * 1.6 - (j - upto[from]) * 0.15, 0.0, 1.0)
		var s := (k * 1.18 / 0.75 if k < 0.75 else 1.18 - 0.18 * (k - 0.75) / 0.25) if k > 0.0 else 0.0
		if s <= 0.0: continue
		var piv := ctr + Vector2(float(cen[j][0]), float(cen[j][1])) * TS + Vector2(float(shift[0]), float(shift[1])) / px * w
		var r0 := Rect2(ctr - Vector2(w, w) * 0.5, Vector2(w, w))
		ci.draw_texture_rect(BoardSprites.malachite("nodule_%d_%d" % [v, j]), Rect2(piv + (r0.position - piv) * s, r0.size * s), false)
	if from > 0: BoardSprites.draw(ci, BoardSprites.malachite("nodule_%d_s%d" % [v, from]), ctr, TS)

## the stone flower on its 2x2: its rings as they are; full and about to bloom it glows, pulsing; it flashes as it
## grows or blooms. Its sprite is drawn at the pixel frame's scale (1 pt = cell / 42)
func _draw_flower(ci: Node2D) -> void:
	if model == null or model.flower.is_empty(): return
	var F: Dictionary = model.flower
	var ctr := Vector2(PAD + (float(F.c) + 1.0) * TS, PAD + (float(F.r) + 1.0) * TS)
	var now := Time.get_ticks_msec() / 1000.0
	var hot := 1.0 - clampf((now - flower_at) / 0.5, 0.0, 1.0)
	if int(F.st) >= 3:
		var pulse := 0.5 + 0.5 * sin(now * 4.0)
		GemArt.radial_disc(ci, ctr, TS * 1.25, Color(0.4, 1.0, 0.6, 0.22 + 0.18 * pulse), Color(0.3, 0.9, 0.5, 0.1), Color(0.3, 0.9, 0.5, 0))
	if hot > 0.0:
		GemArt.radial_disc(ci, ctr, TS * 1.4, Color(0.6, 1.0, 0.7, 0.5 * hot), Color(0.4, 1.0, 0.6, 0.2 * hot), Color(0.4, 1.0, 0.6, 0))
	var tex: Texture2D = BoardSprites.flower("flower_s%d" % clampi(int(F.st), 1, 3))
	var sz := Vector2(tex.get_size()) * TS / 42.0
	ci.draw_texture_rect(tex, Rect2((ctr - sz * 0.5).round(), sz.round()), false)

## the nodules that just grew: [{r, c, from, stage}] from BoardModel.nodule_grow
func grow_nodules(list: Array) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for e: Dictionary in list:
		nod_grow[int(e.r) * C + int(e.c)] = {from = int(e.from), t0 = now}
	live.queue_redraw()

func _draw_over(ci: Node2D) -> void:
	if model == null: return
	for r in R:
		for c in C:
			if model.playable(r, c) and model.LOCK[r][c] == 2:
				BoardSprites.draw(ci, BoardSprites.malachite("crust_%d" % BoardSprites.malachite_look(r, c)), cell_center(r, c), TS)
			elif model.playable(r, c) and model.LOCK[r][c] == 1:
				BoardSprites.draw(ci, BoardSprites.tex("lock"), cell_center(r, c), TS)
	ci.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	for p: Vector2i in marks:
		var at := cell_center(p.x, p.y) - Vector2(TS, TS) * 0.46
		ci.draw_rect(Rect2(at, Vector2(TS, TS) * 0.92), Color(1.0, 0.25, 0.15, 0.22))
		ci.draw_rect(Rect2(at, Vector2(TS, TS) * 0.92), Color(1.0, 0.35, 0.2, 0.95), false, maxf(2.0, TS * 0.06))

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
	if model and (not model.find.is_empty() and (not model.find.done or Time.get_ticks_msec() / 1000.0 - find_done_at < 0.7) or _has_gas() or not geo_hit_at.is_empty() or not nod_grow.is_empty()):
		live.queue_redraw()
	if model and not model.flower.is_empty():
		flower_layer.queue_redraw()
	if model and model.boss_on():
		sea_under.queue_redraw()
		sea_over.queue_redraw()
	# a grown nodule stays drawn as its new stage
	var now := Time.get_ticks_msec() / 1000.0
	for key in nod_grow.keys():
		if now - float(nod_grow[key].t0) > NOD_GROW_S + 0.1: nod_grow.erase(key)

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

# ---------------------------------------------------------------- the Kraken's board

## the middle of the block of SEA cells of kind k (the maelstrom's 3x3, his eye's 2x2), or (-1, -1)
func _sea_mid(k: int) -> Vector2:
	var sum := Vector2.ZERO
	var n := 0
	for r in R:
		for c in C:
			if model.SEA[r][c] == k:
				sum += cell_center(r, c)
				n += 1
	return sum / n if n else Vector2(-1, -1)

## the maelstrom's water turning in the middle of its ring
func _draw_sea_under(ci: Node2D) -> void:
	if model == null: return
	var now := Time.get_ticks_msec() / 1000.0
	var w := _sea_mid(1)
	if w.x >= 0.0:
		var rad := TS * 1.45
		ci.draw_circle(w, rad, Color("#0b2233"))
		ci.draw_circle(w, rad * 0.62, Color("#071722"))
		ci.draw_circle(w, rad * 0.22, Color("#02080d"))
		for arm in 5:
			var pts := PackedVector2Array()
			for i in 24:
				var q := i / 23.0
				var a := now * 1.6 + arm * TAU / 5.0 + q * 4.2
				pts.append(w + Vector2(cos(a), sin(a)) * rad * (0.95 - q * 0.75))
			ci.draw_polyline(pts, Color(0.62, 0.82, 0.88, 0.5), maxf(1.5, TS * 0.05), true)

## his eye (2x2, art/boss/export_kraken.py, on the boss' 1-pt grid): drawn over the stones - it bulges up out of the
## board, its torn edge over the cells round it, its shadow on them; open (watching the board) or shut after a hit
func _draw_eye(ci: Node2D, now: float) -> void:
	var e := _sea_mid(2)
	if e.x < 0.0 or model.eye.is_empty() or _eye_tex.is_empty(): return
	# shut after a hit; open, it blinks now and then (two rhythms, so not like a clock) and breathes a little
	var shut := int(model.eye.shut) > 0 or fposmod(now + 1.3, 4.7) < 0.15 or fposmod(now + 3.1, 6.3) < 0.12
	var tx: Texture2D = _eye_tex.shut if shut else _eye_tex.open
	if not shut:
		var glow := 0.55 + 0.25 * sin(now * 2.2)
		GemArt.radial_disc(ci, e, TS * 1.3, Color(0.5, 0.9, 1.0, 0.25 * glow), Color(0.4, 0.85, 1.0, 0.08), Color(0.4, 0.85, 1.0, 0))
	var k := TS / 37.0 * (1.0 + 0.018 * sin(now * 1.7))
	var sz := (Vector2(tx.get_size()) * k).round()
	var at := (e - sz * 0.5).round()
	# its own shape as a shadow cast down-right
	ci.draw_texture_rect(tx, Rect2(at + (Vector2(6, 8) * k).round(), sz), false, Color(0, 0, 0, 0.28))
	ci.draw_texture_rect(tx, Rect2(at + (Vector2(3, 4) * k).round(), sz), false, Color(0, 0, 0, 0.45))
	ci.draw_texture_rect(tx, Rect2(at, sz), false)
	var since := now - eye_at
	if since < 0.4:
		ci.draw_circle(e, TS * (1.0 + since), Color(1.0, 0.95, 0.8, 0.5 * (1.0 - since / 0.4)), false, 3.0)

## the tide over the bottom rows, the ink clouds, the tentacles gripping their stones
func _draw_sea_over(ci: Node2D) -> void:
	if model == null: return
	var now := Time.get_ticks_msec() / 1000.0
	_draw_eye(ci, now)
	for r in R:
		for c in C:
			if not model.playable(r, c): continue
			var p := Vector2(PAD + c * TS, PAD + r * TS)
			if model.TIDE[r][c]:
				ci.draw_rect(Rect2(p, Vector2(TS, TS)), Color(0.08, 0.3, 0.42, 0.62))
				if r == 0 or not model.TIDE[r - 1][c]:
					var wave := PackedVector2Array()
					for i in 9:
						var x := i / 8.0
						wave.append(p + Vector2(x * TS, sin(now * 3.0 + (c + x) * 2.4) * TS * 0.05))
					ci.draw_polyline(wave, Color(0.7, 0.9, 0.95, 0.85), maxf(1.5, TS * 0.05), true)
	for r in R:
		for c in C:
			if not model.playable(r, c) or not model.INK[r][c]: continue
			var ctr := cell_center(r, c)
			var a := 0.92 if int(model.INK[r][c]) > 1 else 0.7
			for k in 4:
				var o := Vector2(sin(now * 0.9 + k * 1.7 + r), cos(now * 0.7 + k * 2.3 + c)) * TS * 0.14
				ci.draw_circle(ctr + o, TS * (0.54 - k * 0.04), Color(0.03, 0.03, 0.07, a * 0.7))
	for tn: Dictionary in model.tentacles: _draw_tentacle(ci, tn, now)

## where a tentacle comes over the rim: a cell's length out from its first cell, away from the board
func tentacle_root(tn: Dictionary) -> Vector2:
	var b: Vector2i = tn.cells[0] if not tn.cells.is_empty() else Vector2i.ZERO
	var into := Vector2i(1, 0)
	for d: Vector2i in BoardModel.DIRS4:
		if not model.playable(b.x - d.x, b.y - d.y):
			into = d
			break
	return cell_center(b.x, b.y) - Vector2(into.y, into.x) * TS * 1.1

## one tentacle: from beyond the rim through its cells' middles to its tip, swaying a little; it slides in tip first
func _draw_tentacle(ci: Node2D, tn: Dictionary, now: float) -> void:
	var cells: Array = tn.cells
	if cells.is_empty(): return
	var ctrl := PackedVector2Array([tentacle_root(tn)])
	for i in cells.size():
		var p: Vector2i = cells[i]
		var sway := sin(now * 2.1 + i * 1.3 + int(tn.id)) * TS * 0.07 * (i + 1) / cells.size()
		ctrl.append(cell_center(p.x, p.y) + Vector2(sway, -sway * 0.6))
	var line := Bend.smooth(ctrl, 8)
	var L := Bend.length(line)
	var k := clampf((now - float(tent_at.get(int(tn.id), -10.0))) / TENT_IN, 0.0, 1.0)
	k = 1.0 - pow(1.0 - k, 3.0)
	# it slides in tip first: the part out on the board is the end of the whole arm
	var pts := Bend.sample(line, 0.0, L * maxf(k, 0.02), 40)
	tentacle_body(ci, pts, lerpf(TS * 0.1, TS * 0.36, k), TS * 0.1)

## a tentacle's body along pts (root first): a dark hide tapering from w0 to w1 (half widths), a pale belly with a row
## of suckers along it, a wet glint on its back. Drawn in code until its own picture is made
static func tentacle_body(ci: CanvasItem, pts: PackedVector2Array, w0: float, w1: float) -> void:
	var n := pts.size()
	if n < 2: return
	var wd := func(i: int) -> float: return lerpf(w0, w1, float(i) / float(n - 1))
	var side := func(i: int) -> Vector2:
		var d := (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized()
		return Vector2(-d.y, d.x)
	for i in n: ci.draw_circle(pts[i], float(wd.call(i)) + 1.5, Color("#1a0f16"))
	for i in n: ci.draw_circle(pts[i], float(wd.call(i)), Color("#5b3446"))
	var belly := PackedVector2Array()
	var back := PackedVector2Array()
	for i in n:
		var s: Vector2 = side.call(i)
		belly.append(pts[i] + s * float(wd.call(i)) * 0.45)
		back.append(pts[i] - s * float(wd.call(i)) * 0.45)
	ci.draw_polyline(belly, Color("#a7787f"), maxf(1.5, w0 * 0.55), true)
	ci.draw_polyline(back, Color(0.85, 0.75, 0.85, 0.35), maxf(1.0, w0 * 0.12), true)
	var i := 2
	while i < n - 1:
		var s: Vector2 = side.call(i)
		var w: float = wd.call(i)
		ci.draw_circle(pts[i] + s * w * 0.5, w * 0.32, Color("#e2c9c0"))
		ci.draw_circle(pts[i] + s * w * 0.5, w * 0.14, Color("#4a2632"))
		i += 3
