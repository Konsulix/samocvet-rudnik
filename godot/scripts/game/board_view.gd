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
var ink_layer: Node2D         # the Kraken's ink, one shader over all its cells (shaders/ink.gdshader), like the gas
var tent_at := {}             # tentacle id -> when it reached out (it slides onto the board tip first)
var _arm_tex: Texture2D
var eye_at := -10.0           # when the eye was last hit: it flinches shut
const TENT_IN := 0.55
## the maelstrom: a square hole broken through the board (art/boss/export_kraken.py), its water flowing in a whirlpool
## (shaders/whirl.gdshader) on the boss' 1-pt grid (a PixelLayer); it flows faster for a moment when the ring goes round
## (whirl_kick)
var _whirl: PixelLayer
var _whirl_tex: Texture2D
var _whirl_a := 0.0
var _whirl_kick := -10.0
var _eye_tex := {}            # his drawn eye, open and shut: loaded with the board (a texture first drawn the frame it
                              # loads shows white)
## his eye alive (shaders/kraken_eye.gdshader on its own layer, over the stones): the pupil darts about in jerks -
## now a burst of quick darts, now a roll round the eyeball, now a stare at where the player touched the board -
## grows a little when hit (its shape stays), the lids blink, squint and flinch shut, the whole eye shudders now and then
var eye_layer: Node2D
var _eye_meta := {}
var _look := Vector2.ZERO        # the pupil's offset now, px of the eye picture
var _look_to := Vector2.ZERO
var _look_next := 0.0
var _burst := 0                  # quick darts left in a burst
var _roll_until := -1.0
var _roll_a := 0.0
var _stare_until := -1.0
var _blink_at := 2.0             # the next blink starts then
var _squint_until := -1.0
var _twitch_at := -10.0
var _lid := 0.0
var _slit := Vector2(5.5, 3.5)
var _down := {}
## the gallery's works (BoardMech draws them): belts under the stones, carts, kegs and buckets among them, the dark over
## them and its lanterns over the dark; what moves them
var belt_layer: Node2D
var mech_layer: Node2D
var dark_layer: Node2D
var lamp_layer: Node2D
var belt_phase := 0.0          # cells the belts have run
var cart_bump := {}            # cart index -> when a stone went in
var cart_go_at := {}           # cart index -> when it set off, full
var keg_hit := {}              # cell key -> when a fuse burnt
var bucket_hit := {}           # cell key -> when it tipped
var lit_at := {}               # cell key -> when the dark there was lit
var dark_any := false
var _dark_mask: ImageTexture

func _init() -> void:
	clip_contents = true
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	light_mask = 0   # the gallery's lamps light the wall, not the tray
	# the sprites are rendered big and shown small: sample their mipmaps so they stay clean
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mouse_filter = Control.MOUSE_FILTER_STOP

func _ready() -> void:
	under = _layer(_draw_under)
	belt_layer = _layer(func(ci: Node2D): if model: BoardMech.draw_belts(self, ci))
	gas_layer = _layer(_draw_gas)
	var gm := ShaderMaterial.new()
	gm.shader = preload("res://shaders/gas.gdshader")
	gas_layer.material = gm
	live = _layer(_draw_live)
	flower_layer = _layer(_draw_flower)
	flower_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sea_under = _layer(_draw_sea_under)
	mech_layer = _layer(func(ci: Node2D): if model: BoardMech.draw_mech(self, ci, Time.get_ticks_msec() / 1000.0))
	gems = Node2D.new()
	gems.light_mask = 0
	add_child(gems)
	over = _layer(_draw_over)
	# Timber needs the same explicit shader as gems on iPhone with baked shaders.
	over.material = BoardSprites.plain_material()
	dark_layer = _layer(func(ci: Node2D): if model: BoardMech.draw_dark(self, ci))
	var dm := ShaderMaterial.new()
	dm.shader = preload("res://shaders/dark.gdshader")
	dark_layer.material = dm
	lamp_layer = _layer(func(ci: Node2D):
		if model:
			BoardMech.draw_belt_rails(self, ci)
			BoardMech.draw_lamps(self, ci, Time.get_ticks_msec() / 1000.0))
	ink_layer = _layer(_draw_ink)
	var im := ShaderMaterial.new()
	im.shader = preload("res://shaders/ink.gdshader")
	ink_layer.material = im
	sea_over = _layer(_draw_sea_over)
	sea_over.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	eye_layer = _layer(func(ci: Node2D): _draw_eye(ci, Time.get_ticks_msec() / 1000.0))
	eye_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var eym := ShaderMaterial.new()
	eym.shader = preload("res://shaders/kraken_eye.gdshader")
	eye_layer.material = eym

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
	_whirl_tex = null
	if _whirl:
		_whirl.queue_free()
		_whirl = null
	var dir := "res://assets/boss/%s/" % String(m.boss.B.get("id", "")) if m.boss_on() else ""
	if dir != "" and not m.ring.is_empty() and ResourceLoader.exists(dir + "whirl_hi.png"):
		_whirl_tex = load(dir + "whirl_hi.png")
		_whirl = PixelLayer.make(size, _draw_whirl)
		var wm := ShaderMaterial.new()
		wm.shader = preload("res://shaders/whirl.gdshader")
		_whirl.canvas.material = wm
		add_child(_whirl)
		move_child(_whirl, gems.get_index())
	if dir != "" and not m.eye.is_empty() and ResourceLoader.exists(dir + "eye_open.png"):
		_eye_tex = {open = load(dir + "eye_open.png"), shut = load(dir + "eye_shut.png")}
		if ResourceLoader.exists(dir + "eye_blank.png"):
			_eye_tex.blank = load(dir + "eye_blank.png")
			_eye_meta = JSON.parse_string(FileAccess.get_file_as_string(dir + "eye.json"))
			var em := eye_layer.material as ShaderMaterial
			em.set_shader_parameter("ball", load(dir + "eye_ball.png"))
			em.set_shader_parameter("size", Vector2(_eye_meta.size[0], _eye_meta.size[1]))
			em.set_shader_parameter("ball_c", Vector2(_eye_meta.ball[0], _eye_meta.ball[1]))
			em.set_shader_parameter("ball_h", Vector2(_eye_meta.ball[2], _eye_meta.ball[3]))
			em.set_shader_parameter("tilt", deg_to_rad(float(_eye_meta.get("tilt", 17.0))))
	cart_bump = {}
	cart_go_at = {}
	keg_hit = {}
	bucket_hit = {}
	lit_at = {}
	belt_phase = 0.0
	BoardMech.dark_mask(self, 0.0)
	_has_mech = not m.carts.is_empty()
	for r in m.R:
		for c in m.C:
			if m.playable(r, c) and (m.KEG[r][c] or m.BUCKET[r][c] or m.LAMP[r][c]): _has_mech = true
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
	belt_layer.queue_redraw()
	mech_layer.queue_redraw()
	dark_layer.queue_redraw()
	lamp_layer.queue_redraw()
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
				var dur := 0.12 + sqrt(d) * 0.11
				tw.tween_property(n, "position", target, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				# a stone that fell a cell or more lands with a little squash
				if d >= 0.9: get_tree().create_timer(dur).timeout.connect(_land.bind(n, minf(1.0, d / 4.0)))
				any = true
	if any:
		await tw.finished
	else:
		tw.kill()

func _land(n: GemNode, k: float) -> void:
	if not is_instance_valid(n) or n.is_queued_for_deletion(): return
	var tw := n.create_tween()
	tw.tween_property(n, "scale", Vector2(1.0 + 0.1 * k, 1.0 - 0.13 * k), 0.06).set_trans(Tween.TRANS_SINE)
	tw.tween_property(n, "scale", Vector2(1.0 - 0.03 * k, 1.0 + 0.04 * k), 0.08).set_trans(Tween.TRANS_SINE)
	tw.tween_property(n, "scale", Vector2.ONE, 0.08).set_trans(Tween.TRANS_SINE)

func animate_swap(a_id: int, b_id: int, back := false) -> void:
	var na: GemNode = nodes.get(a_id)
	var nb: GemNode = nodes.get(b_id)
	if na == null or nb == null: return
	var pa := na.position
	var pb := nb.position
	# the stone moved lifts a little over the other as they pass
	na.z_index = 1
	var tw := create_tween().set_parallel(true)
	tw.tween_property(na, "position", pb, 0.15).set_trans(Tween.TRANS_SINE)
	tw.tween_property(nb, "position", pa, 0.15).set_trans(Tween.TRANS_SINE)
	tw.tween_method(func(k: float): na.scale = Vector2.ONE * (1.0 + 0.16 * sin(k * PI)), 0.0, 1.0, 0.15)
	tw.tween_method(func(k: float): nb.scale = Vector2.ONE * (1.0 - 0.08 * sin(k * PI)), 0.0, 1.0, 0.15)
	await tw.finished
	if back:
		# no match: they knock against each other and go back, shaking it off
		var tw2 := create_tween().set_parallel(true)
		tw2.tween_property(na, "position", pa, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw2.tween_property(nb, "position", pb, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await tw2.finished
		var tw3 := create_tween()
		var side := (pb - pa).normalized().orthogonal() * TS * 0.05
		for k in 3:
			tw3.tween_property(na, "position", pa + side * (1 if k % 2 == 0 else -1), 0.035)
		tw3.tween_property(na, "position", pa, 0.035)
		await tw3.finished
	na.z_index = 0

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
		# it flares bright as it swells, then shrinks away
		tw.set_parallel(true)
		tw.tween_property(n, "scale", Vector2(1.24, 1.24), 0.07).set_trans(Tween.TRANS_SINE)
		tw.tween_property(n, "modulate", Color(1.9, 1.9, 1.9, 1.0), 0.07)
		tw.chain().tween_property(n, "scale", Vector2(0.0, 0.0), 0.13).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
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
	return BoardSprites.sand()

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
			elif model.playable(r, c) and model.LOCK[r][c] >= 4:
				if BoardSprites.gem_style != "":
					# the ice block rendered in Blender (prototype/tools/blender/ice_kit.py): see-through, the stone under it shows
					BoardSprites.draw(ci, BoardSprites.blocker("ice" if model.LOCK[r][c] == 4 else "ice_cracked"), cell_center(r, c), TS)
				else:
					ice(ci, cell_center(r, c), TS, model.LOCK[r][c] == 4, r * 31 + c)
	ci.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	for p: Vector2i in marks:
		var at := cell_center(p.x, p.y) - Vector2(TS, TS) * 0.46
		ci.draw_rect(Rect2(at, Vector2(TS, TS) * 0.92), Color(1.0, 0.25, 0.15, 0.22))
		ci.draw_rect(Rect2(at, Vector2(TS, TS) * 0.92), Color(1.0, 0.35, 0.2, 0.95), false, maxf(2.0, TS * 0.06))

## Proval's ice over a frozen stone (BoardModel LOCK 4 thick, 5 cracked), drawn here: a block of clear blue-white ice
## with chamfered edges, the light from the upper left on its top facet and rim, frost in its corners; once hit, cracks
## run through it from a white star
static func ice(ci: CanvasItem, ctr: Vector2, ts: float, thick: bool, seed_v: int) -> void:
	var h := ts * 0.48
	var ch := ts * 0.13
	var poly := PackedVector2Array([ctr + Vector2(-h + ch, -h), ctr + Vector2(h - ch, -h), ctr + Vector2(h, -h + ch),
		ctr + Vector2(h, h - ch), ctr + Vector2(h - ch, h), ctr + Vector2(-h + ch, h), ctr + Vector2(-h, h - ch), ctr + Vector2(-h, -h + ch)])
	ci.draw_colored_polygon(poly, Color(0.62, 0.82, 1.0, 0.46 if thick else 0.3))
	# the lit top-left facet and the shaded lower right
	ci.draw_colored_polygon(PackedVector2Array([poly[0], poly[1], ctr + Vector2(h * 0.35, -h * 0.55), ctr + Vector2(-h * 0.55, h * 0.35), poly[6], poly[7]]),
		Color(0.92, 0.97, 1.0, 0.26 if thick else 0.16))
	ci.draw_colored_polygon(PackedVector2Array([poly[3], poly[4], poly[5], ctr + Vector2(-h * 0.2, h * 0.62), ctr + Vector2(h * 0.62, -h * 0.2), poly[2]]),
		Color(0.18, 0.36, 0.62, 0.22))
	poly.append(poly[0])
	ci.draw_polyline(poly, Color(0.06, 0.12, 0.22, 0.75), maxf(2.0, ts * 0.06), true)
	ci.draw_polyline(poly, Color(0.85, 0.95, 1.0, 0.9 if thick else 0.6), maxf(1.0, ts * 0.025), true)
	# a glint
	ci.draw_line(ctr + Vector2(-h * 0.62, -h * 0.25), ctr + Vector2(-h * 0.25, -h * 0.62), Color(1, 1, 1, 0.85), maxf(1.5, ts * 0.05))
	ci.draw_line(ctr + Vector2(-h * 0.5, 0.0), ctr + Vector2(0.0, -h * 0.5), Color(1, 1, 1, 0.45), maxf(1.0, ts * 0.025))
	# frost in the corners
	for k in 4:
		var d := Vector2(-1 if k % 2 == 0 else 1, -1 if k < 2 else 1)
		var cn := ctr + d * h * 0.78
		for j in 3:
			var a := d.angle() + PI + (j - 1) * 0.55
			ci.draw_line(cn, cn + Vector2.from_angle(a) * ts * 0.1, Color(0.95, 0.98, 1.0, 0.7), maxf(1.0, ts * 0.02))
	if not thick:
		var k := ts / 100.0
		for line: PackedVector2Array in crack_paths(seed_v, 4):
			var pts := PackedVector2Array()
			for p in line: pts.append(ctr + (p - Vector2(50, 50)) * k * 0.95)
			ci.draw_polyline(pts, Color(0.1, 0.2, 0.35, 0.6), maxf(1.6, ts * 0.04))
			ci.draw_polyline(pts, Color(1.0, 1.0, 1.0, 0.9), maxf(1.0, ts * 0.018))

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

## a white texel, stretched by the layers whose shader draws everything
func white() -> Texture2D:
	if _white == null:
		var im := Image.create(4, 4, false, Image.FORMAT_RGBA8)
		im.fill(Color.WHITE)
		_white = ImageTexture.create_from_image(im)
	return _white

## a cell of the dark being lit: its dark fades out (BoardMech.LIGHT_S)
func light_cell(r: int, c: int) -> void:
	lit_at[r * C + c] = Time.get_ticks_msec() / 1000.0

## the belts run one cell along, in time with their stones (Level._belts)
func run_belts(dur: float) -> void:
	var from := belt_phase
	var tw := create_tween()
	tw.tween_method(func(k: float) -> void:
		belt_phase = from + k
		belt_layer.queue_redraw()
		lamp_layer.queue_redraw(), 0.0, 1.0, dur).set_trans(Tween.TRANS_SINE)
	await tw.finished

var _has_mech := false         # carts, kegs, buckets or lanterns on this board: their layers are live
var _dark_live := false
func _process(dt: float) -> void:
	if model and _has_mech:
		mech_layer.queue_redraw()
		lamp_layer.queue_redraw()
	if model and (dark_any or _dark_live):
		_dark_live = BoardMech.dark_mask(self, Time.get_ticks_msec() / 1000.0)
		dark_layer.queue_redraw()
	# gas breathes, specimens pulse, shaken blocks settle
	if model and (not model.find.is_empty() and (not model.find.done or Time.get_ticks_msec() / 1000.0 - find_done_at < 0.7) or _has_gas() or not geo_hit_at.is_empty() or not nod_grow.is_empty()):
		live.queue_redraw()
	if model and not model.flower.is_empty():
		flower_layer.queue_redraw()
	if model and model.boss_on():
		sea_under.queue_redraw()
		sea_over.queue_redraw()
		ink_layer.queue_redraw()
		if not model.eye.is_empty():
			_eye_live(dt)
			eye_layer.queue_redraw()
	if _whirl:
		var kick := clampf(1.0 - (Time.get_ticks_msec() / 1000.0 - _whirl_kick) / 0.8, 0.0, 1.0)
		_whirl_a += dt * (1.0 + 3.0 * kick)
		(_whirl.canvas.material as ShaderMaterial).set_shader_parameter("flow", _whirl_a)
		_whirl.redraw()
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
			eye_watch(cell.x, cell.y)
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
	# the deep's light spills out of the maelstrom onto the cells round it, under their stones (breathing as in its shader)
	if w.x >= 0.0 and _whirl_tex != null:
		var breath := 0.75 + 0.25 * sin(_whirl_a * 1.3) + 0.08 * sin(_whirl_a * 3.7)
		GemArt.radial_disc(ci, w, TS * 2.6, Color(0.5, 0.88, 1.0, 0.5 * breath), Color(0.45, 0.85, 1.0, 0.3 * breath), Color(0.45, 0.85, 1.0, 0), 0.62)
	if w.x >= 0.0 and _whirl_tex == null:
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

## the middle of the maelstrom's water
func whirl_mid() -> Vector2:
	return _sea_mid(1)

## the ring went round: the water spins faster a moment
func whirl_kick() -> void:
	_whirl_kick = Time.get_ticks_msec() / 1000.0

func _draw_whirl(ci: Node2D) -> void:
	var w := _sea_mid(1)
	if w.x < 0.0 or _whirl_tex == null: return
	var sz := Vector2(_whirl_tex.get_size()) / 3.0 * TS / 37.0
	ci.draw_texture_rect(_whirl_tex, Rect2((w - sz * 0.5).round(), sz.round()), false)

## his eye (2x2, art/boss/export_kraken.py, on the boss' 1-pt grid): drawn over the stones - it bulges up out of the
## board, its torn edge over the cells round it, its shadow on them; open (watching the board) or shut after a hit
## how much of his eye is up (LevelBoss._eye_swim: it sinks to 0, moves, comes up to 1)
var eye_show := 1.0
func _draw_eye(ci: Node2D, now: float) -> void:
	var e := _sea_mid(2)
	if e.x < 0.0 or model == null or model.eye.is_empty() or _eye_tex.is_empty() or eye_show <= 0.01: return
	var live: bool = _eye_tex.has("blank")
	var shut := int(model.eye.shut) > 0
	var tx: Texture2D = _eye_tex.blank if live else (_eye_tex.shut if shut else _eye_tex.open)
	var glow := 0.55 + 0.25 * sin(now * 2.2)
	if _lid < 0.8:
		GemArt.radial_disc(ci, e, TS * 1.3, Color(0.5, 0.9, 1.0, 0.25 * glow * (1.0 - _lid)), Color(0.4, 0.85, 1.0, 0.08), Color(0.4, 0.85, 1.0, 0))
	var k := TS / 37.0 * (1.0 + 0.018 * sin(now * 1.7)) * (0.35 + 0.65 * eye_show)
	var sz := (Vector2(tx.get_size()) * k).round()
	# a shudder now and then, a hard one when hit
	var since := now - eye_at
	var shake := Vector2.ZERO
	var tw := now - _twitch_at
	if tw < 0.25: shake = Vector2(sin(tw * 90.0), cos(tw * 70.0)) * 1.5 * k
	if since < 0.35: shake += Vector2(sin(since * 80.0), cos(since * 65.0)) * 3.0 * k * (1.0 - since / 0.35)
	var at := (e - sz * 0.5 + shake).round()
	if live:
		var em := ci.material as ShaderMaterial
		em.set_shader_parameter("look", _look.round())
		em.set_shader_parameter("slit", _slit)
		em.set_shader_parameter("lid", _lid)
		em.set_shader_parameter("glow", 0.95 + 0.12 * sin(now * 3.1))
	# its own shape as a shadow cast down-right
	var fade := Color(1, 1, 1, eye_show)
	ci.draw_texture_rect(tx, Rect2(at + (Vector2(6, 8) * k).round(), sz), false, Color(0, 0, 0, 0.28 * eye_show))
	ci.draw_texture_rect(tx, Rect2(at + (Vector2(3, 4) * k).round(), sz), false, Color(0, 0, 0, 0.45 * eye_show))
	ci.draw_texture_rect(tx, Rect2(at, sz), false, fade)
	if since < 0.4:
		ci.draw_circle(e, TS * (1.0 + since), Color(1.0, 0.95, 0.8, 0.5 * (1.0 - since / 0.4)), false, 3.0)

## the player touched the board at (r, c): he stares there a moment
func eye_watch(r: int, c: int) -> void:
	if _eye_meta.is_empty(): return
	var d := (cell_center(r, c) - _sea_mid(2)).rotated(-deg_to_rad(float(_eye_meta.get("tilt", 17.0))))
	var half := Vector2(_eye_meta.ball[2], _eye_meta.ball[3])
	_look_to = _clamp_look(d.normalized() * half * minf(1.0, d.length() / (TS * 2.0)))
	_stare_until = Time.get_ticks_msec() / 1000.0 + randf_range(0.6, 1.1)
	_roll_until = -1.0
	_burst = 0

## where the pupil may go: its slit stays inside the eyeball
func _clamp_look(v: Vector2) -> Vector2:
	var hx := float(_eye_meta.ball[2]) - _slit.x - 3.0
	var hy := float(_eye_meta.ball[3]) - _slit.x - 3.0
	var q := Vector2(v.x / maxf(hx, 1.0), v.y / maxf(hy, 1.0))
	if q.length() > 1.0: q = q.normalized()
	return Vector2(q.x * hx, q.y * hy)

## the eye's restless life, a frame at a time
func _eye_live(dt: float) -> void:
	if _eye_meta.is_empty(): return
	var now := Time.get_ticks_msec() / 1000.0
	var hit := now - eye_at
	var half := Vector2(_eye_meta.ball[2], _eye_meta.ball[3])
	# where the pupil goes next: jerky darts, bursts of quick ones, a roll round the eyeball; a stare holds it
	if now >= _roll_until and now >= _stare_until and now >= _look_next:
		var pick := randf()
		if _burst > 0:
			_burst -= 1
			_look_next = now + randf_range(0.07, 0.16)
		elif pick < 0.12:
			_roll_until = now + randf_range(0.7, 1.3)
			_roll_a = randf() * TAU
			_look_next = _roll_until
		elif pick < 0.38:
			_burst = randi_range(2, 4)
			_look_next = now + 0.1
		else:
			_look_next = now + randf_range(0.25, 1.3)
		_look_to = _clamp_look(Vector2(randf_range(-1, 1), randf_range(-0.8, 0.8)) * half)
	if now < _roll_until:
		_roll_a += dt * 9.0
		_look_to = _clamp_look(Vector2(cos(_roll_a), sin(_roll_a)) * half)
	# a dart is fast, then it holds still
	_look = _look.lerp(_look_to, 1.0 - exp(-dt * 28.0))
	# the pupil keeps its round shape; hit, it widens a little and settles back
	var want := Vector2(5.5 * (1.0 + 0.35 * clampf(1.0 - hit / 1.2, 0.0, 1.0)), 3.5)
	_slit = _slit.lerp(want, 1.0 - exp(-dt * 14.0))
	# the lids: shut while he is hurt, a blink every few seconds (now and then a double one), a suspicious squint
	if now >= _blink_at + 0.18:
		_blink_at = now + (0.25 if randf() < 0.2 else randf_range(1.6, 4.5))
	if now >= _squint_until + 3.0 and randf() < dt * 0.2:
		_squint_until = now + randf_range(0.6, 1.4)
	if now >= _twitch_at + 1.0 and randf() < dt * 0.35:
		_twitch_at = now
	var to := 0.0
	if int(model.eye.shut) > 0: to = 1.0
	elif now < _squint_until: to = 0.5
	var b := now - _blink_at
	if b >= 0.0 and b < 0.18: to = maxf(to, 1.0 - absf(b - 0.08) / 0.1)
	_lid = lerpf(_lid, to, 1.0 - exp(-dt * (40.0 if to > _lid else 14.0)))

## the ink as one cloud over the grid (shaders/ink.gdshader): the board's ink goes in as a small mask, a texel a cell
## with a cell of margin (1 just spilled, 0.55 on its last move), and the shader smooths and frays it into one blot
var _ink_mask: ImageTexture
func _draw_ink(ci: Node2D) -> void:
	if model == null or not model.boss_on(): return
	var any := false
	var img := Image.create(C + 2, R + 2, false, Image.FORMAT_L8)
	for r in R:
		for c in C:
			if model.playable(r, c) and model.INK[r][c] > 0:
				any = true
				var v := 1.0 if int(model.INK[r][c]) > 1 else 0.55
				img.set_pixel(c + 1, r + 1, Color(v, v, v))
	if not any: return
	if _ink_mask == null or _ink_mask.get_width() != C + 2 or _ink_mask.get_height() != R + 2:
		_ink_mask = ImageTexture.create_from_image(img)
	else:
		_ink_mask.update(img)
	var sm := ci.material as ShaderMaterial
	sm.set_shader_parameter("mask", _ink_mask)
	sm.set_shader_parameter("cells", Vector2(C + 2, R + 2))
	if _white == null:
		var wi := Image.create(4, 4, false, Image.FORMAT_RGBA8)
		wi.fill(Color.WHITE)
		_white = ImageTexture.create_from_image(wi)
	ci.draw_texture_rect(_white, Rect2(Vector2(PAD - TS, PAD - TS), Vector2(C + 2, R + 2) * TS), false)

## the tide over the bottom rows, the tentacles gripping their stones
func _draw_sea_over(ci: Node2D) -> void:
	if model == null: return
	var now := Time.get_ticks_msec() / 1000.0
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
	# his arm's own drawing, laid on the grid at this size (art/boss/export_kraken.py: arm_s); the part on the board is
	# its tip end, its cut root end under the frame's bar
	if _arm_tex == null: _arm_tex = load("res://assets/boss/kraken/arm_s.png")
	var hw := float(_arm_tex.get_height()) * 0.65 * TS / 37.0
	Bend.draw(ci, pts, func(_q: float) -> float: return hw, _arm_tex, 1.0 - maxf(k, 0.02), 1.0)

