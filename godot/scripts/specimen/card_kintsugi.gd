class_name CardKintsugi
extends Control
## Kintsugi (SpecLegend: gold mending in the stone's glass) breaks its card's info panel — its slate; the brass round
## it, the ribbon and the card's frame, stays whole — and mends it with gold: a moment after the card opens the slate
## cracks, falls away in shards (through the hole the screen behind shows), and the shards fly back and fit; when all
## are home, gold runs along the seams, under the panel's words — the stone's own gold. The shards where the buttons
## were (and every other one over them: a chequer) come back turned over — the card's back up: the buttons are on the
## back, and the card turns under a drag of the finger, its glow with it. Again now and then while it lies face up.
## The panel's picture for the shards is a snapshot of it (the screen read back once a break).

const SHARDS_ROW := 4          # the shards the button row breaks into
const AGAIN := 30.0            # seconds between breaks, face up
const CRACK := 0.45            # the cracks run
const BACK_AT := 1.75          # the shards start back
const RET := 0.6               # each one's flight home
const STAG := 0.07             # one after the other
const MOLTEN := 1.1            # a seam glows white-hot this long, then cools to gold
const EMBLEM := Vector2(0.5, 0.27)   # the emblem on the card's back (assets/ui/card_back.png), of its size
## what breaks: the card's lower block - the info panel and the card's frame round it, from the panel's top down (the
## screen behind shows through) - but the brass ribbon over the panel stays, live (24.11); no gold on the brass
const TOP_R := 0.0             # the block's top corners: square (it starts on the card's straight sides)
const CORNER := 14.0           # the card's rounded corners below
const SEAM_W := 3.3            # a seam, points across (24.11: thinner, as the stone's own seams)
const HP := 40.0               # room round the card for its rarity glow, turned with it

static var test_every := 0.0   # a test key (-- kin_every=S): a break every S s
static var test_mend := false  # a test key (-- kin_mend): the back up, Mend is pressed and the first broken stone chosen
static var test_back := ""     # a test key (-- kin_back=malachite|lapis|agate): this back
static var test_flip := 0.0    # a test key (-- kin_flip=S): the card turns over S s after it is built, and back S s later

var card: Control
var view: SpecView
var info: Control
var v: VBoxContainer
var find: Node3D
var row: Control               # the buttons (the caller's last child of the panel's box)

var _hole: Control             # (unused: through the broken block the screen behind shows)
var _still: TextureRect        # behind the card while its block is broken: the card as it was, but for the block
var _box: StyleBox             # the card's own frame, put back when the block is home
var _vbox: StyleBox            # the stone's window's mask, put back
var _pieces: Control           # the shards (mended: the turned ones, outside the panel)
var _cracks: Control           # the cracks running, the flying shards' edges
var _gold: Control             # the seams (mended: on the frame, outside the panel)
var _in: Control               # in the panel, over its slate, under its words: the mended seams and turned shards there
var _in_pieces: Control
var _in_gold: Control
var _block := Rect2()          # what breaks, in the card's own space
var _cut := Rect2()            # the panel, in the block's space
var _cells := []               # {poly (block space), loc (about c), c, down}
var _edges := []               # {pts, a, b, w: PackedFloat32Array (the bead's width along it)}
var _knots := []               # where seams meet: [point, radius]
var _front: ImageTexture
var _back: Texture2D
var _t := -1.0                 # time into a break; <0: none
var _wait := 1.6               # to the next break
var _done_once := false        # the first break turned the row's shards over
var _clock := 0.0
var rng := RandomNumberGenerator.new()
## the card's back: drawn in a SubViewport of its own (the back's art, the buttons — the row taken from the panel —
## and the stone's mending), shown through shaders/card_tilt.gdshader turned in depth as the card turns over; while
## the back is up the card itself is hidden and touches on the picture go on into the SubViewport
const FLIP := 0.55             # the turn over, s
var s: Dictionary              # the stone (its mending charge is kept on it)
var _holder: Control
var _bvp: SubViewport
var _bshow: TextureRect
var _art: TextureRect
var _logo: TextureRect         # the game's plate (the trailer's GEMCORE), in the back's upper part, a shadow under it
var _logo_sh: TextureRect
var _mend: Button
var _gauge: Control
var _vial: TextureRect
var _plate: TextureRect
var _plate_l: Label
var _tapes: Array[TextureRect] = []
var _side := 0                 # 0: face up, 1: the back up
## the turn over is the finger's (24.11: "I want to turn it myself, not have a swipe do it"): the card follows a drag
## across it, and let go it falls to the nearer side (a flick carries it over)
var _ang := 0.0                # the turn now, from the side that is up (+-PI: the other side up)
var _av := 0.0
var _ang_to := 0.0
var _turning := false          # shown turned: dragged, or settling
var _drag := false
var _grab := 0.0               # the turn when the finger took it
var _vel := 0.0
var _crossed := false
var _halo: Array[CanvasItem] = []   # the card's rarity glow (the holder's own children)
var _hvp: SubViewport          # the glow drawn again, turned with the card
var _hshow: TextureRect
var _bframe: Panel             # the back's brass: the card's own frame
var _aclip: Control            # the back's picture is cut to the inside of the frame
## the mended block seen from behind (24.11: "the card one whole"): where a shard lies turned on the face, its slate
## is up on the back; the gold of every seam runs through to the back too - both mirrored, as the back is
var _bslate: Control
var _bgold: Control
var _snap: ImageTexture        # the card's face, for its half of the turn
var _press := Vector2.ZERO
var _pressed := false
var _flips := 0                 # (the test key's turns: there and back, once)

## p: the built find; only a kintsugi one (`fx`: the find's living effect, SpecGenome)
static func attach(card_: Control, view_: SpecView, info_: Control, v_: VBoxContainer, p: Node3D, fx: String, s_: Dictionary) -> void:
	if fx != "kintsugi" or card_.has_meta("kintsugi"): return
	card_.set_meta("kintsugi", true)
	# (the panel's swipe is the turn over now, not the next stone of the pile: Museum._swipe_between)
	v_.set_meta("flip_swipe", true)
	var ck := CardKintsugi.new()
	ck.s = s_
	ck.card = card_
	ck.view = view_
	ck.info = info_
	ck.v = v_
	ck.find = p
	card_.add_child(ck)

## the stone's own gold (its worked-gold textures, spec_mat) for the seams' shader
static func _gold_maps(m: ShaderMaterial) -> void:
	m.set_shader_parameter("gold_tex", load("res://assets/textures/gold/gold_diff.png"))
	m.set_shader_parameter("gold_nrm", load("res://assets/textures/gold/gold_nrm.png"))
	m.set_shader_parameter("gold_rough", load("res://assets/textures/gold/gold_rough.png"))

func _layer(parent: Node, shader: Shader, draw: Callable) -> Control:
	var n := Control.new()
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if shader:
		var m := ShaderMaterial.new()
		m.shader = shader
		n.material = m
	n.draw.connect(draw.bind(n))
	parent.add_child(n)
	return n

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 5
	rng.seed = hash(str(find.get_instance_id()))
	if test_every > 0.0: _wait = minf(_wait, test_every)
	# the back: a polished stone, edge to edge - malachite, lapis or agate, the stone's own (24.11: the user's pictures)
	var which: String = ["malachite", "lapis", "agate"][absi(int(s.get("seed", hash(str(s.get("id", "")))))) % 3]
	if test_back != "": which = test_back
	_back = load("res://assets/ui/card_back/back_%s.png" % which) as Texture2D
	var shard := preload("res://shaders/card_kin_shard.gdshader")
	var gold := preload("res://shaders/card_kin_gold.gdshader")
	var gtex := load("res://assets/textures/gold/gold_diff.png")
	_hole = _layer(self, null, _draw_hole)
	_pieces = _layer(self, shard, _draw_pieces)
	_cracks = _layer(self, null, _draw_cracks)
	_gold = _layer(self, gold, _draw_gold)
	# in the panel: over its slate (its first child), under its words
	_in = Control.new()
	_in.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(_in)
	info.move_child(_in, mini(1, info.get_child_count() - 1))
	_in_pieces = _layer(_in, shard, _draw_pieces)
	_in_gold = _layer(_in, gold, _draw_gold)
	for n: Control in [_pieces, _in_pieces]:
		(n.material as ShaderMaterial).set_shader_parameter("back", _back)
		(n.material as ShaderMaterial).set_shader_parameter("rb", CORNER)
	for n: Control in [_gold, _in_gold]: _gold_maps(n.material as ShaderMaterial)
	tree_exiting.connect(func() -> void: if is_instance_valid(_in): _in.queue_free())
	# the buttons: the box's last child holding any
	for i in range(v.get_child_count() - 1, -1, -1):
		var c := v.get_child(i) as Control
		if c and (c is Button or not c.find_children("*", "Button", true, false).is_empty()):
			row = c
			break
	_build_back()
	_still = TextureRect.new()
	_still.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_still.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_still.stretch_mode = TextureRect.STRETCH_SCALE
	var sm := ShaderMaterial.new()
	sm.shader = preload("res://shaders/card_kin_frame.gdshader")
	_still.material = sm
	_still.visible = false
	_holder.add_child(_still)
	_holder.move_child(_still, card.get_index())
	tree_exiting.connect(func() -> void: if is_instance_valid(_still): _still.queue_free())
	for n: Control in [_pieces, _in_pieces]: (n.material as ShaderMaterial).set_shader_parameter("rt", TOP_R)
	_gold.visible = false

func _process(dt: float) -> void:
	if not is_instance_valid(info) or not is_instance_valid(card):
		queue_free()
		return
	_clock += dt
	_turn(dt)
	if test_flip > 0.0 and _flips < 2 and not _turning and _t < 0.0 and _clock > test_flip * (_flips + 1):
		_flips += 1
		flip()
	# the block: from the panel's top (under its brass ribbon) to the card's foot, the card's width
	var top := info.global_position.y - card.global_position.y
	_block = Rect2(0.0, top, card.size.x, card.size.y - top)
	_cut = Rect2(info.global_position - card.global_position - _block.position, info.size)
	var at := card.global_position + _block.position
	for n: Control in [_hole, _pieces, _cracks, _gold, _in_pieces, _in_gold]:
		n.global_position = at
		n.size = _block.size
	# mended: the overlay keeps off the panel (the panel's own layer draws there, under its words)
	var cut := Vector4(_cut.position.x, _cut.position.y, _cut.size.x, _cut.size.y) if not _flying() else Vector4.ZERO
	(_pieces.material as ShaderMaterial).set_shader_parameter("cut", cut)
	(_gold.material as ShaderMaterial).set_shader_parameter("cut", Vector4(_cut.position.x, _cut.position.y, _cut.size.x, _cut.size.y))
	if _t < 0.0:
		_wait -= dt
		if _wait <= 0.0 and _t > -1.5 and _side == 0 and not _turning and not _drag and info.is_visible_in_tree():
			_break()
	else:
		_t += dt
		var home := _home_all()
		if _t > home + 0.6 + MOLTEN + 0.4:
			_t = -1.0
			_wait = test_every if test_every > 0.0 else AGAIN
			_whole(true)
		elif _t > home and info.modulate.a < 1.0:
			# (all home: the card whole again under the cooling gold)
			_whole(true)
	for n: Control in [_hole, _pieces, _cracks, _gold, _in_pieces, _in_gold]: n.queue_redraw()

# ---------------------------------------------------------------- the break

func _break() -> void:
	_t = -2.0   # (held while the snapshot is taken)
	if _cells.is_empty(): _shatter_map()
	# the block as it is now — without the mended seams and turned shards: its shards carry its look, the gold is
	# drawn again over them
	# (and without the ribbon: it stays, live, over the hole - not in the shards, not in the still behind)
	var rim := card.get_node_or_null("InfoRim") as CanvasItem
	if rim: rim.visible = false
	for n: Control in [_pieces, _gold, _in]: n.visible = false
	await RenderingServer.frame_post_draw
	if not is_instance_valid(info): return
	var vp := get_viewport()
	var xf := vp.get_final_transform() * card.get_global_transform_with_canvas()
	var img := vp.get_texture().get_image()
	var r := Rect2i(xf * _block).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	_front = ImageTexture.create_from_image(img.get_region(r))
	var rc := Rect2i(xf * Rect2(Vector2.ZERO, card.size)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	_still.texture = ImageTexture.create_from_image(img.get_region(rc))
	var stm := _still.material as ShaderMaterial
	stm.set_shader_parameter("psize", card.size)
	stm.set_shader_parameter("block", Vector4(_block.position.x, _block.position.y, _block.size.x, _block.size.y))
	stm.set_shader_parameter("rt", TOP_R)
	# (square below: rounded, the card frame's own rounded corners were left over the hole - 24.11)
	stm.set_shader_parameter("rb", 0.0)
	stm.set_shader_parameter("side_w", Reveal.CARD_PAD + 1.0)
	stm.set_shader_parameter("side_down", Reveal.INFO_R + 46.0)
	for n: Control in [_pieces, _in_pieces]:
		var m := n.material as ShaderMaterial
		m.set_shader_parameter("front", _front)
		m.set_shader_parameter("psize", _block.size)
		m.set_shader_parameter("pin", Vector4(_block.position.x / card.size.x, _block.position.y / card.size.y, _block.size.x / card.size.x, _block.size.y / card.size.y))
		var gc := Vector2.ZERO
		var gn := 0
		for c: Dictionary in _cells:
			if c.down:
				gc += c.c
				gn += 1
		m.set_shader_parameter("card_sz", card.size)
		m.set_shader_parameter("inset", Reveal.CARD_PAD)
		var ar := art_rect(card.size)
		m.set_shader_parameter("art", Vector4(ar.position.x, ar.position.y, ar.size.x, ar.size.y))
	for n: Control in [_pieces, _gold, _in]: n.visible = true
	if rim: rim.visible = true
	_t = 0.0
	# the block goes — the panel, its brass, the card's frame round it: its shards are drawn in its place, and through
	# where it was the screen behind shows
	_whole(false)
	# the buttons are turned over with their shards: onto the back (a gap of their height keeps the panel's size)
	if is_instance_valid(row) and row.get_parent() == v:
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, row.size.y)
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(gap)
		v.move_child(gap, row.get_index())
		row.reparent(_bvp, false)
		_layout_back()
	# each shard's fall and flight home, new every time
	var order := range(_cells.size())
	order.shuffle()
	for i in _cells.size():
		var c: Dictionary = _cells[i]
		c.vx = rng.randf_range(-70.0, 70.0) + (c.c.x - _block.size.x * 0.5) * 0.25
		c.vy = rng.randf_range(-90.0, -20.0)
		c.spin = rng.randf_range(-2.6, 2.6)
		c.drop = rng.randf_range(0.0, 0.12)
		c.home = BACK_AT + STAG * order.find(i)
		c.from = Vector2(rng.randf_range(-60.0, 60.0), _block.size.y + rng.randf_range(140.0, 260.0))
		c.rot0 = rng.randf_range(-1.4, 1.4)
		c.turn = (c.down as bool) and not _done_once
	_done_once = true
	Sfx.play("crack")
	Sfx.buzz(60)
	# the shards fall away (their plates' clatter), and the gold runs as they come home (the forge's molten pour)
	get_tree().create_timer(CRACK).timeout.connect(func() -> void: Sfx.play("crust"))
	get_tree().create_timer(BACK_AT + RET).timeout.connect(func() -> void: if is_instance_valid(self): Sfx.play("br_pour"))

## the card whole (its block home) or broken: broken, its frame is drawn by the still behind it (the card's own frame
## box empty), the stone's window kept above the block (its mask's foot raised), the panel and its brass hidden
func _whole(on: bool) -> void:
	var win := view.get_parent() as Control
	# the card's rarity glow is a shadow filling the card's whole shape: through the broken block it showed as a
	# coloured sheet — it fades out while the block is off
	for ci in _halo:
		if not is_instance_valid(ci): continue
		ci.create_tween().tween_property(ci, "modulate:a", 1.0 if on else 0.0, 0.5 if on else 0.12)
	if on:
		info.modulate.a = 1.0
		if _box: card.add_theme_stylebox_override("panel", _box)
		if _vbox and is_instance_valid(win): win.add_theme_stylebox_override("panel", _vbox)
		_box = null
		_vbox = null
		_still.visible = false
		return
	info.modulate.a = 0.0
	_box = card.get_theme_stylebox("panel")
	# (empty, but with the frame's own margins: without them the card laid its stone and panel out over its frame)
	var eb := StyleBoxEmpty.new()
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]: eb.set_content_margin(side, _box.get_content_margin(side))
	card.add_theme_stylebox_override("panel", eb)
	if is_instance_valid(win):
		_vbox = win.get_theme_stylebox("panel")
		var sb := (_vbox as StyleBoxFlat).duplicate() as StyleBoxFlat if _vbox is StyleBoxFlat else StyleBoxFlat.new()
		sb.expand_margin_bottom = -(win.global_position.y + win.size.y - (card.global_position.y + _block.position.y))
		win.add_theme_stylebox_override("panel", sb)
	_still.visible = true
	_still.global_position = card.global_position
	_still.size = card.size

## the block cut into shards: a Voronoi map, a few big shards over the button row, smaller ones above; its seams
## made crooked (each seam bent by its own midpoints — the same for the two shards it parts), each its own width
## along it, swelling where seams meet; and a drop of gold at every meeting
func _shatter_map() -> void:
	var w := _block.size.x
	var h := _block.size.y
	var rr := Rect2(0, h - 70, w, 48)
	if is_instance_valid(row):
		rr = Rect2(row.global_position - card.global_position - _block.position, row.size)
	var seeds: Array[Vector2] = []
	var down: Array[bool] = []
	for k in SHARDS_ROW:
		seeds.append(Vector2(w * (k + 0.5) / SHARDS_ROW + rng.randf_range(-12.0, 12.0), rr.get_center().y + rng.randf_range(-6.0, 6.0)))
		down.append(true)
	var top := rr.position.y - rr.size.y * 0.7
	# (24.11: more of them, the chequer plainer)
	var cols := 5
	var rows := maxi(3, roundi(top / 44.0))
	for j in rows:
		for k in cols:
			seeds.append(Vector2((k + 0.5 + rng.randf_range(-0.35, 0.35)) * w / cols, (j + 0.5 + rng.randf_range(-0.35, 0.35)) * top / rows))
			# (the row over the buttons turned over every other one: a chequer with them - 24.11)
			down.append((j == rows - 1 and k % 2 == 0) or (j == rows - 2 and k % 2 == 1))
	var box := PackedVector2Array([Vector2.ZERO, Vector2(w, 0), Vector2(w, h), Vector2(0, h)])
	var polys := []
	for i in seeds.size():
		var poly := box
		for j in seeds.size():
			if i == j: continue
			poly = _clip(poly, (seeds[i] + seeds[j]) * 0.5, (seeds[j] - seeds[i]).normalized())
			if poly.size() < 3: break
		polys.append(poly)
	var bent := {}
	var ends := {}
	for i in polys.size():
		var poly: PackedVector2Array = polys[i]
		var out := PackedVector2Array()
		for k in poly.size():
			var a := poly[k]
			var b := poly[(k + 1) % poly.size()]
			out.append(a)
			if _on_box(a, w, h) and _on_box(b, w, h) and (is_equal_approx(a.x, b.x) or is_equal_approx(a.y, b.y)): continue
			var key := _key(a, b)
			if not bent.has(key):
				var line := _crook(a, b) if _key_lo(a, b) else _crook(b, a)
				bent[key] = {pts = line, cells = []}
			var e: Dictionary = bent[key]
			(e.cells as Array).append(i)
			var mids: PackedVector2Array = e.pts.slice(1, e.pts.size() - 1)
			if not _key_lo(a, b): mids.reverse()
			out.append_array(mids)
		var c := Vector2.ZERO
		for p in out: c += p
		c /= maxf(1.0, out.size())
		var loc := PackedVector2Array()
		for p in out: loc.append(p - c)
		_cells.append({poly = out, loc = loc, c = c, down = down[i]})
	for e: Dictionary in bent.values():
		if (e.cells as Array).size() != 2: continue
		var pts: PackedVector2Array = e.pts
		# the bead's width along it: uneven, swelling at its ends (where it meets others)
		var wd := PackedFloat32Array()
		var len_at := 0.0
		var total := 0.0
		for k in pts.size() - 1: total += pts[k].distance_to(pts[k + 1])
		var ph := rng.randf() * 10.0
		for k in pts.size():
			if k > 0: len_at += pts[k - 1].distance_to(pts[k])
			var end_d := minf(len_at, total - len_at)
			wd.append(SEAM_W * (0.75 + 0.35 * sin(len_at * 0.11 + ph) + 0.2 * sin(len_at * 0.37 + ph * 2.0)) + 0.5 * exp(-end_d / 4.0))
		_edges.append({pts = pts, a = e.cells[0], b = e.cells[1], w = wd, delay = clampf((pts[0].y + pts[pts.size() - 1].y) * 0.5 / maxf(1.0, h), 0.0, 1.0) * 0.45 + rng.randf() * 0.15})
		for p: Vector2 in [pts[0], pts[pts.size() - 1]]:
			var kk := "%d,%d" % [roundi(p.x), roundi(p.y)]
			ends[kk] = [p, int((ends.get(kk, [p, 0]) as Array)[1]) + 1]
	for e: Array in ends.values():
		# (where seams meet, just the joint filled: no drop - 24.11: "the little circles" read as the mines' ore)
		if int(e[1]) >= 2: _knots.append([e[0], SEAM_W * 0.55])

static func _clip(poly: PackedVector2Array, at: Vector2, n: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in poly.size():
		var a := poly[k]
		var b := poly[(k + 1) % poly.size()]
		var da := (a - at).dot(n)
		var db := (b - at).dot(n)
		if da <= 0.0: out.append(a)
		if (da < 0.0) != (db < 0.0) and absf(da - db) > 1e-6:
			out.append(a.lerp(b, da / (da - db)))
	return out

static func _on_box(p: Vector2, w: float, h: float) -> bool:
	return p.x < 0.01 or p.y < 0.01 or p.x > w - 0.01 or p.y > h - 0.01

static func _key_lo(a: Vector2, b: Vector2) -> bool:
	return a.x < b.x - 0.01 or (absf(a.x - b.x) <= 0.01 and a.y < b.y)

static func _key(a: Vector2, b: Vector2) -> String:
	var lo := a if _key_lo(a, b) else b
	var hi := b if _key_lo(a, b) else a
	return "%d,%d,%d,%d" % [roundi(lo.x * 10.0), roundi(lo.y * 10.0), roundi(hi.x * 10.0), roundi(hi.y * 10.0)]

## a seam from a to b, crooked as a crack: midpoints pushed aside, three times over (by the place, so both shards agree)
func _crook(a: Vector2, b: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array([a, b])
	for level in 3:
		var nxt := PackedVector2Array([pts[0]])
		for k in pts.size() - 1:
			var p := pts[k]
			var q := pts[k + 1]
			var d := q - p
			var n := Vector2(-d.y, d.x).normalized()
			var hsh := absf(sin(p.x * 12.9898 + q.y * 78.233 + level * 3.1) * 43758.5453)
			nxt.append((p + q) * 0.5 + n * (fmod(hsh, 1.0) - 0.5) * d.length() * 0.28)
			nxt.append(q)
		pts = nxt
	return pts

# ---------------------------------------------------------------- drawing

## where each shard is now: [offset from home, turn, its face's width (−1..1: turned over), fade]
func _state(i: int) -> Array:
	var c: Dictionary = _cells[i]
	var w := 1.0 if not c.down else -1.0
	if _t < 0.0: return [Vector2.ZERO, 0.0, w, 1.0]
	if bool(c.get("turn", false)): w = 1.0
	if _t < CRACK: return [Vector2(rng.randf_range(-0.4, 0.4), 0.0) if _t > CRACK * 0.6 else Vector2.ZERO, 0.0, w, 1.0]
	var tf := _t - CRACK - float(c.drop)
	if _t < float(c.home):
		if tf < 0.0: return [Vector2.ZERO, 0.0, w, 1.0]
		return [Vector2(float(c.vx) * tf, float(c.vy) * tf + 1500.0 * tf * tf), float(c.spin) * tf, w, clampf(1.0 - (tf - 0.55) / 0.35, 0.0, 1.0)]
	var k := clampf((_t - float(c.home)) / RET, 0.0, 1.0)
	var e := _back_out(k)
	if bool(c.get("turn", false)): w = cos(PI * smoothstep(0.15, 0.85, k))
	return [(c.from as Vector2).lerp(Vector2.ZERO, e), lerpf(float(c.rot0), 0.0, e), w, clampf(k / 0.18, 0.0, 1.0)]

static func _back_out(k: float) -> float:
	const S := 1.4
	var x := k - 1.0
	return 1.0 + (S + 1.0) * x * x * x + S * x * x

## shards in the air (or not yet all home): the shards drawn over the card, the panel hidden
func _flying() -> bool:
	return _t >= 0.0 and _t < _home_all()

## every shard home (the panel whole again): the gold starts to run
func _home_all() -> float:
	return BACK_AT + RET + STAG * _cells.size() + 0.05

func _landed(i: int) -> float:
	return float(_cells[i].home) + RET

## the dark where the block was, while it is broken
func _draw_hole(n: Control) -> void:
	return
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.03, 0.04)
	sb.corner_radius_bottom_left = int(CORNER)
	sb.corner_radius_bottom_right = int(CORNER)
	n.draw_style_box(sb, Rect2(Vector2.ZERO, n.size))
	for i in 8:
		n.draw_rect(Rect2(0, i, n.size.x, 1), Color(0, 0, 0, 0.3 * (1.0 - i / 8.0)))

func _draw_pieces(n: Control) -> void:
	if _cells.is_empty() or _t < -1.0: return
	# (once every shard is home the panel is live again: only the turned shards are drawn, in the panel under its words)
	var live := _flying()
	if live and n == _in_pieces: return
	for i in _cells.size():
		var c: Dictionary = _cells[i]
		if not live and not c.down: continue
		var st := _state(i)
		var fw: float = st[2]
		if absf(fw) < 0.02: continue
		var light := 0.78 + 0.22 * absf(fw) - 0.08 * absf(sin(float(st[1])))
		var col := Color(1.0 if fw > 0.0 else 0.0, 0.0, light, float(st[3]))
		var cols := PackedColorArray()
		var uvs := PackedVector2Array()
		for p: Vector2 in c.poly:
			cols.append(col)
			uvs.append(p / _block.size)
		# (its outline never mirrored: a turned shard lies in its own place, only its picture is the back's, mirrored by
		# the shader; mirrored, it fitted nowhere - bits of the frame lay in the slate, the seams off its edges - 24.11)
		n.draw_set_transform(c.c + st[0], float(st[1]), Vector2(absf(fw), 1.0))
		n.draw_polygon(c.loc, cols, uvs)
	n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## the cracks running before the fall, and a flying shard's own thin dark edge
func _draw_cracks(n: Control) -> void:
	if _cells.is_empty() or _t < 0.0: return
	if _t < CRACK + 0.05:
		var k := clampf(_t / (CRACK * 0.8), 0.0, 1.0)
		for e: Dictionary in _edges:
			var pts: PackedVector2Array = e.pts
			n.draw_polyline(pts.slice(0, maxi(2, roundi(pts.size() * k))), Color(0.02, 0.02, 0.02, 0.85), 1.4, true)
		return
	for i in _cells.size():
		var st := _state(i)
		var c: Dictionary = _cells[i]
		if float(st[3]) <= 0.01 or absf(float(st[2])) < 0.02: continue
		if (st[0] as Vector2).length() < 0.5 and absf(float(st[1])) < 0.01: continue
		n.draw_set_transform(c.c + st[0], float(st[1]), Vector2(absf(float(st[2])), 1.0))
		var loop: PackedVector2Array = (c.loc as PackedVector2Array).duplicate()
		loop.append(loop[0])
		n.draw_polyline(loop, Color(0, 0, 0, 0.55 * float(st[3])), 1.2, true)
	n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## the gold: a seam fills once both its shards are home — molten, running along it, cooling; a drop where seams meet.
## Beads as triangle strips for shaders/card_kin_gold.gdshader
func _draw_gold(n: Control) -> void:
	if _cells.is_empty() or _t < -1.0 or n == _gold: return
	var live := _t >= 0.0
	var pts_all := PackedVector2Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var glow_pts := PackedVector2Array()
	var glow_cols := PackedColorArray()
	var glow_uvs := PackedVector2Array()
	var glow_idx := PackedInt32Array()
	var lit_at := {}
	for e: Dictionary in _edges:
		var lit := 99.0
		if live:
			# (the gold runs once every shard is home and the panel is live again: under its words from the start)
			var at := _home_all() + float(e.get("delay", 0.0))
			if _t < at: continue
			lit = _t - at
		var hot := clampf(1.0 - lit / MOLTEN, 0.0, 1.0)
		var fill := clampf(lit / 0.3, 0.0, 1.0)
		var pts: PackedVector2Array = e.pts
		var m := maxi(2, roundi(pts.size() * fill))
		_strip(pts, e.w, m, Color(hot, 0.0, 0.0, 1.0), 1.0, pts_all, cols, uvs, idx)
		if hot > 0.0: _strip(pts, e.w, m, Color(hot, 0.0, 1.0, 1.0), 3.2, glow_pts, glow_cols, glow_uvs, glow_idx)
		for p: Vector2 in [pts[0], pts[pts.size() - 1]]:
			var kk := "%d,%d" % [roundi(p.x), roundi(p.y)]
			lit_at[kk] = maxf(float(lit_at.get(kk, -1.0)), hot) if fill >= 1.0 else float(lit_at.get(kk, -1.0))
	for kn: Array in _knots:
		var p: Vector2 = kn[0]
		var kk := "%d,%d" % [roundi(p.x), roundi(p.y)]
		if not lit_at.has(kk) or float(lit_at[kk]) < 0.0: continue
		_disc(p, float(kn[1]), Color(float(lit_at[kk]), 1.0, 0.0, 1.0), pts_all, cols, uvs, idx)
	var ci := n.get_canvas_item()
	if glow_idx.size(): RenderingServer.canvas_item_add_triangle_array(ci, glow_idx, glow_pts, glow_cols, glow_uvs)
	if idx.size(): RenderingServer.canvas_item_add_triangle_array(ci, idx, pts_all, cols, uvs)

## a bead along pts[0..m): its width wd (×k), UV.y across it −1..1
static func _strip(pts: PackedVector2Array, wd: PackedFloat32Array, m: int, col: Color, k: float, out: PackedVector2Array, cols: PackedColorArray, uvs: PackedVector2Array, idx: PackedInt32Array) -> void:
	var base := out.size()
	for i in m:
		var a := pts[maxi(i - 1, 0)]
		var b := pts[mini(i + 1, pts.size() - 1)]
		var d := (b - a).normalized()
		var nn := Vector2(-d.y, d.x)
		var hw := wd[i] * 0.5 * k
		out.append(pts[i] + nn * hw)
		out.append(pts[i] - nn * hw)
		cols.append(col)
		cols.append(col)
		# (UV.x: which way "across" points on screen, as a turn — the gold's shader bends the bead's normal that way)
		var turn := fposmod(nn.angle() / TAU, 1.0)
		uvs.append(Vector2(turn, -1.0))
		uvs.append(Vector2(turn, 1.0))
		if i > 0:
			var o := base + (i - 1) * 2
			idx.append_array([o, o + 1, o + 2, o + 1, o + 3, o + 2])

## a drop of gold: a disc, UV its own −1..1
static func _disc(c: Vector2, r: float, col: Color, out: PackedVector2Array, cols: PackedColorArray, uvs: PackedVector2Array, idx: PackedInt32Array) -> void:
	var base := out.size()
	out.append(c)
	cols.append(col)
	uvs.append(Vector2.ZERO)
	const N := 14
	for i in N:
		var a := TAU * i / N
		var u := Vector2(cos(a), sin(a))
		out.append(c + u * r)
		cols.append(col)
		uvs.append(u)
		idx.append_array([base, base + 1 + i, base + 1 + (i + 1) % N])

# ---------------------------------------------------------------- the back

const MEND_EVERY := 100        # wins between a stone's mendings (each kintsugi stone its own)

## wins to go before this stone can mend again (0: it can)
static func mend_wait(st: Dictionary) -> int:
	if not st.has("kin_won"): return 0
	return maxi(0, MEND_EVERY - (int(Save.d.get("won_n", 0)) - int(st.kin_won)))

func _build_back() -> void:
	_holder = card.get_parent() as Control
	for h in _holder.get_children():
		if h != card and h is CanvasItem: _halo.append(h as CanvasItem)
	# the glow, again, in a picture of its own: turned with the card as it turns over (24.11: it stood still)
	_hvp = SubViewport.new()
	_hvp.transparent_bg = true
	_hvp.size_2d_override_stretch = true
	_hvp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	for h in _halo:
		var d := h.duplicate() as CanvasItem
		d.visible = true
		d.modulate.a = 1.0
		_hvp.add_child(d)
	_hshow = TextureRect.new()
	_hshow.texture = _hvp.get_texture()
	_hshow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hshow.stretch_mode = TextureRect.STRETCH_SCALE
	_hshow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hshow.visible = false
	var hm := ShaderMaterial.new()
	hm.shader = preload("res://shaders/card_tilt.gdshader")
	_hshow.material = hm
	_hshow.add_child(_hvp)
	_holder.add_child(_hshow)
	_holder.move_child(_hshow, 0)
	tree_exiting.connect(func() -> void: if is_instance_valid(_hshow): _hshow.queue_free())
	_bvp = SubViewport.new()
	_bvp.transparent_bg = true
	_bvp.size_2d_override_stretch = true
	_bvp.msaa_2d = Viewport.MSAA_4X
	_bvp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_bshow = TextureRect.new()
	_bshow.texture = _bvp.get_texture()
	_bshow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bshow.stretch_mode = TextureRect.STRETCH_SCALE
	_bshow.mouse_filter = Control.MOUSE_FILTER_STOP
	_bshow.visible = false
	var shm := ShaderMaterial.new()
	shm.shader = preload("res://shaders/card_tilt.gdshader")
	shm.set_shader_parameter("pad", Vector2.ZERO)
	_bshow.material = shm
	_bshow.gui_input.connect(_pass_input)
	_bshow.add_child(_bvp)
	_holder.add_child(_bshow)
	# the back in the same brass as the face (24.11): the card's own frame, the back's picture inside it
	_bframe = Panel.new()
	_bframe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bframe.add_theme_stylebox_override("panel", card.get_theme_stylebox("panel"))
	_bvp.add_child(_bframe)
	_aclip = Control.new()
	_aclip.clip_contents = true
	_aclip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bvp.add_child(_aclip)
	_art = TextureRect.new()
	_art.texture = _back
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_SCALE
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aclip.add_child(_art)
	_logo_sh = TextureRect.new()
	_logo = TextureRect.new()
	for t: TextureRect in [_logo_sh, _logo]:
		t.texture = load("res://assets/ui/card_back/logo.png")
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_SCALE
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_aclip.add_child(t)
	_logo_sh.modulate = Color(0, 0, 0, 0.55)
	_bslate = Control.new()
	_bslate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bslate.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_bslate.draw.connect(_draw_back_slate)
	_aclip.add_child(_bslate)
	_bgold = Control.new()
	_bgold.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bgm := ShaderMaterial.new()
	bgm.shader = preload("res://shaders/card_kin_gold.gdshader")
	_gold_maps(bgm)
	_bgold.material = bgm
	_bgold.draw.connect(_draw_back_gold)
	_aclip.add_child(_bgold)
	# the mending's charge: a glass vial filling with molten gold (drawn by code under the glass), a brass plate under
	# it telling how far, taped on; the Mend button taped under it
	_gauge = Control.new()
	_gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gm := ShaderMaterial.new()
	gm.shader = preload("res://shaders/card_kin_gold.gdshader")
	_gold_maps(gm)
	_gauge.material = gm
	_gauge.draw.connect(_draw_gauge)
	_bvp.add_child(_gauge)
	_vial = _sprite("vial")
	_plate = _sprite("plate")
	_plate_l = Kit.label("", 14, UI.body_bold, Color(0.16, 0.09, 0.03))
	_plate_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_plate_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_plate_l.add_theme_constant_override("outline_size", 0)
	_plate_l.set_anchors_preset(Control.PRESET_FULL_RECT)
	_plate.add_child(_plate_l)
	_mend = Kit.button("Mend", "btn_dark", 17, 4.0)
	_mend.add_theme_color_override("font_color", Color(0.95, 0.76, 0.38))
	_mend.pressed.connect(_mend_pick)
	_bvp.add_child(_mend)
	tree_exiting.connect(func() -> void: if is_instance_valid(_bshow): _bshow.queue_free())

func _sprite(n: String) -> TextureRect:
	var t := TextureRect.new()
	t.texture = load("res://assets/ui/card_back/%s.png" % n)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bvp.add_child(t)
	return t

## a strip of tape across a corner of rect r (in the back's space; `at` 0 its top-left corner, 1 its bottom-right one —
## clear of the words in the middle), on top
func _tape(r: Rect2, at: float, k: int, lean: float) -> void:
	var t := _sprite("tape_%d" % (k % 4))
	t.size = Vector2(40, 18)
	t.pivot_offset = t.size * 0.5
	t.position = (r.position + Vector2(5, 5) if at < 0.5 else r.end - Vector2(5, 5)) - t.size * 0.5
	t.rotation = lean
	_tapes.append(t)

## a point of the block (its space) on the back, in the back's picture clip: mirrored across the card
func _on_back(p: Vector2) -> Vector2:
	var cp := _block.position + p
	return Vector2(card.size.x - cp.x, cp.y) - Vector2.ONE * Reveal.CARD_PAD

func _draw_back_slate() -> void:
	if _cells.is_empty() or not _done_once: return
	var tex := Kit.tex("slate")
	var k := 3.0   # (the slate's pixels a point, as the kit lays it)
	for c: Dictionary in _cells:
		if not c.down: continue
		var pts := PackedVector2Array()
		var uvs := PackedVector2Array()
		for p: Vector2 in c.poly:
			var q := _on_back(p)
			pts.append(q)
			uvs.append(q * k / Vector2(tex.get_width(), tex.get_height()))
		_bslate.draw_colored_polygon(pts, Color.WHITE, uvs, tex)
		# its broken edge a shade darker, as the face's shards
		var loop := pts.duplicate()
		loop.append(pts[0])
		_bslate.draw_polyline(loop, Color(0, 0, 0, 0.45), 1.2, true)

func _draw_back_gold() -> void:
	if _cells.is_empty() or not _done_once: return
	var out := PackedVector2Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for e: Dictionary in _edges:
		var pts := PackedVector2Array()
		for p: Vector2 in e.pts: pts.append(_on_back(p))
		_strip(pts, e.w, pts.size(), Color(0, 0, 0, 1), 1.0, out, cols, uvs, idx)
	for kn: Array in _knots:
		_disc(_on_back(kn[0]), float(kn[1]), Color(0, 1, 0, 1), out, cols, uvs, idx)
	if idx.size(): RenderingServer.canvas_item_add_triangle_array(_bgold.get_canvas_item(), idx, out, cols, uvs)

## the back's picture in the card's space: its own proportions, covering the inside of the frame and a little more -
## its torn paper edges and see-through corners out of sight (24.11: stretched to the frame, it was drawn out and its
## corners showed empty)
func art_rect(sz: Vector2) -> Rect2:
	var inner := sz - Vector2.ONE * Reveal.CARD_PAD * 2.0
	var ts := Vector2(_back.get_width(), _back.get_height())
	var k := maxf(inner.x / ts.x, inner.y / ts.y) * 1.02
	var d := ts * k
	return Rect2(Vector2.ONE * Reveal.CARD_PAD + (inner - d) * 0.5, d)

## the back's layout at the card's size: the art over all of it; at the foot the buttons, each taped at its ends,
## a little crooked; above them the Mend button, taped, and above that the vial of gold with its plate
func _layout_back() -> void:
	var sz := card.size
	_bframe.position = Vector2.ZERO
	_bframe.size = sz
	var ar := art_rect(sz)
	_aclip.position = Vector2.ONE * Reveal.CARD_PAD
	_aclip.size = sz - Vector2.ONE * Reveal.CARD_PAD * 2.0
	_art.position = ar.position - _aclip.position
	_art.size = ar.size
	for n: Control in [_bslate, _bgold]:
		n.position = Vector2.ZERO
		n.size = _aclip.size
		n.queue_redraw()
	for t in _tapes:
		if is_instance_valid(t): t.queue_free()
	_tapes.clear()
	var w := sz.x - 40.0
	var y := sz.y - 34.0
	var tk := 0
	if is_instance_valid(row) and row.get_parent() == _bvp:
		row.position = Vector2(20, y - 48.0)
		row.size = Vector2(w, 48)
		# (each button crooked its own way, taped at both ends: the row lays them out, its children are rects)
		var bs: Array = row.find_children("*", "Button", true, false) if not row is Button else [row]
		var lean := [-0.05, 0.04, -0.03]
		for i in bs.size():
			var b := bs[i] as Button
			var br := Rect2(row.position + b.position, b.size) if b != row else Rect2(row.position, row.size)
			b.pivot_offset = b.size * 0.5
			b.rotation = lean[i % 3]
			_tape(br, 0.0, tk, -0.75 + lean[i % 3])
			_tape(br, 1.0, tk + 1, -0.7 + lean[i % 3])
			tk += 2
		y -= 48.0 + 30.0
	var can := v.has_meta("open_stone")
	var wait := mend_wait(s)
	_mend.position = Vector2(sz.x * 0.5 - 90.0, y - 50.0)
	_mend.size = Vector2(180, 50)
	_mend.pivot_offset = _mend.size * 0.5
	_mend.rotation = 0.03
	_mend.disabled = wait > 0 or not can
	_mend.text = "Mend" if wait == 0 and can else ("Keep it to mend" if not can else "Mend")
	_tape(Rect2(_mend.position, _mend.size), 0.0, tk, -0.75)
	_tape(Rect2(_mend.position, _mend.size), 1.0, tk + 1, -0.7)
	tk += 2
	y -= 50.0 + 26.0
	# the vial: 0.8 of the card's width, its plate under its middle
	var vw := sz.x * 0.78
	var vh := vw * 167.0 / 1051.0
	_vial.size = Vector2(vw, vh)
	_vial.position = Vector2((sz.x - vw) * 0.5, y - vh - 18.0)
	_vial.pivot_offset = _vial.size * 0.5
	_vial.rotation = -0.02
	_gauge.position = _vial.position
	_gauge.size = _vial.size
	_gauge.pivot_offset = _vial.pivot_offset
	_gauge.rotation = _vial.rotation
	_plate.size = Vector2(110, 110.0 * 167.0 / 326.0)
	_plate.position = Vector2(sz.x * 0.5 - 55.0, _vial.position.y + vh - 4.0)
	_plate_l.text = "Ready" if wait == 0 else "%d / %d" % [MEND_EVERY - wait, MEND_EVERY]
	# the plate: in the middle of what is free above the vial
	var lw := (sz.x - Reveal.CARD_PAD * 2.0) * 0.82
	var lh := lw * float(_logo.texture.get_height()) / float(_logo.texture.get_width())
	var ly := (Reveal.CARD_PAD + _vial.position.y) * 0.5 - lh * 0.5
	_logo.size = Vector2(lw, lh)
	_logo.position = Vector2((sz.x - lw) * 0.5, ly) - _aclip.position
	_logo_sh.size = _logo.size
	_logo_sh.position = _logo.position + Vector2(2, 5)
	# (the vial's tapes across its brass caps, upright)
	for e: Array in [[0.07, 1.45], [0.93, 1.7]]:
		var t := _sprite("tape_%d" % ((tk + int(e[0] > 0.5)) % 4))
		t.size = Vector2(40, 18)
		t.pivot_offset = t.size * 0.5
		t.position = _vial.position + Vector2(_vial.size.x * float(e[0]), _vial.size.y * 0.5) - t.size * 0.5
		t.rotation = float(e[1])
		_tapes.append(t)
	_gauge.queue_redraw()

## the gold in the vial: how full, as the gold of the seams (a bead along the tube, its inside as wide as the bead)
func _draw_gauge() -> void:
	var k := 1.0 - float(mend_wait(s)) / MEND_EVERY
	if k <= 0.0: return
	var sz := _gauge.size
	# the tube's inside, between its brass caps (of the vial's picture)
	var x0 := sz.x * 0.135
	var x1 := sz.x * 0.865
	var cy := sz.y * 0.5
	var pts := PackedVector2Array([Vector2(x0, cy), Vector2(lerpf(x0, x1, k), cy)])
	var wd := PackedFloat32Array([sz.y * 0.36, sz.y * 0.36])
	var out := PackedVector2Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	_strip(pts, wd, 2, Color(0.0, 0.0, 0.0, 1.0), 1.0, out, cols, uvs, idx)
	RenderingServer.canvas_item_add_triangle_array(_gauge.get_canvas_item(), idx, out, cols, uvs)

func _pass_input(ev: InputEvent) -> void:
	if _side != 1 or _turning: return
	_bvp.push_input(ev.duplicate(), true)
	_bshow.accept_event()

## a drag across the panel (face up) or across the back turns the card, under the finger
func _input(e: InputEvent) -> void:
	if _t >= 0.0: return
	var press: bool = (e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT) or e is InputEventScreenTouch
	if press:
		var pos: Vector2 = (e as InputEventMouseButton).position if e is InputEventMouseButton else (e as InputEventScreenTouch).position
		# (the event in the canvas of the card's layer)
		var cpos := (card.get_global_transform_with_canvas() * card.get_global_transform().affine_inverse()).affine_inverse() * pos
		var area := info.get_global_rect() if _side == 0 else card.get_global_rect()
		if e.is_pressed():
			_pressed = area.has_point(cpos)
			_press = pos
			_drag = false
			_vel = 0.0
		elif _pressed:
			_pressed = false
			if _drag: _let_go()
		return
	if not _pressed or not (e is InputEventMouseMotion or e is InputEventScreenDrag): return
	var mp: Vector2 = (e as InputEventMouseMotion).position if e is InputEventMouseMotion else (e as InputEventScreenDrag).position
	var mv: Vector2 = (e as InputEventMouseMotion).velocity if e is InputEventMouseMotion else (e as InputEventScreenDrag).velocity
	var d := mp - _press
	if not _drag:
		if absf(d.x) < 14.0 or absf(d.x) < absf(d.y) * 1.3: return
		_drag = true
		_grab = _ang
		_press = mp
		_begin()
		d = Vector2.ZERO
	# (the event's points are the screen's logical ones, as the card's)
	_ang_to = clampf(_grab + d.x / (card.size.x * 0.85) * PI, -PI * 1.05, PI * 1.05)
	_vel = mv.x
	get_viewport().set_input_as_handled()

## let go: to the nearer side, a flick carrying it on
func _let_go() -> void:
	_drag = false
	var a := _ang_to + clampf(_vel / (card.size.x * 0.85) * PI * 0.18, -1.2, 1.2)
	_ang_to = signf(a) * PI if absf(a) > PI * 0.5 else 0.0

## the card turns over (a test key, and the code's own): as a drag all the way
func flip(dir := -1.0) -> void:
	if _turning or _t >= 0.0: return
	await _begin()
	_ang_to = signf(dir) * PI

## the turn begins: the face snapshotted (it turns as a picture), the back drawn, the card and its glow hidden behind
## their turning pictures
func _begin() -> void:
	if _turning: return
	_turning = true
	_crossed = false
	_av = 0.0
	_layout_back()
	_size_back()
	# (drawn from now on - till the face is up again: then nothing draws them)
	_bvp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_hvp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if _side == 0:
		await RenderingServer.frame_post_draw
		if not is_instance_valid(card): return
		var vp := get_viewport()
		var xf := vp.get_final_transform() * card.get_global_transform_with_canvas()
		var r := Rect2i(xf * Rect2(Vector2.ZERO, card.size))
		var img := vp.get_texture().get_image()
		r = r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		_snap = ImageTexture.create_from_image(img.get_region(r))
	_bshow.visible = true
	_hshow.visible = true
	_bshow.texture = _snap if _side == 0 else _bvp.get_texture()
	card.modulate.a = 0.0
	for h in _halo:
		if is_instance_valid(h): h.visible = false
	Sfx.buzz(15)

func _size_back() -> void:
	var sz := card.size
	var dens := maxf(1.0, get_viewport().get_final_transform().get_scale().x)
	if dens < 1.8: dens *= 2.0
	var px := Vector2i((sz * dens).round())
	if _bvp.size != px: _bvp.size = px
	if _bvp.size_2d_override != Vector2i(sz.round()): _bvp.size_2d_override = Vector2i(sz.round())
	var hs := sz + Vector2.ONE * HP * 2.0
	var hpx := Vector2i((hs * minf(dens, 2.0)).round())
	if _hvp.size != hpx: _hvp.size = hpx
	if _hvp.size_2d_override != Vector2i(hs.round()): _hvp.size_2d_override = Vector2i(hs.round())
	# the glow's copies where the glow is, about the card
	var ds := _hvp.get_children()
	for i in mini(ds.size(), _halo.size()):
		if ds[i] is Control and is_instance_valid(_halo[i]) and _halo[i] is Control:
			(ds[i] as Control).position = (_halo[i] as Control).position - card.position + Vector2.ONE * HP
			(ds[i] as Control).size = (_halo[i] as Control).size

func _turn(dt: float) -> void:
	if not is_instance_valid(_bshow): return
	_bshow.global_position = card.global_position
	_bshow.size = card.size
	_hshow.global_position = card.global_position - Vector2.ONE * HP
	_hshow.size = card.size + Vector2.ONE * HP * 2.0
	if not _turning: return
	if _drag:
		_ang = lerpf(_ang, _ang_to, minf(1.0, dt * 22.0))
		_av = 0.0
	else:
		# settling: a spring, just past and back (in small steps: a long frame made it swing wildly)
		var left := dt
		while left > 0.0:
			var h := minf(left, 1.0 / 240.0)
			_av += ((_ang_to - _ang) * 110.0 - _av * 17.0) * h
			_ang += _av * h
			left -= h
		if absf(_ang_to - _ang) < 0.004 and absf(_av) < 0.06:
			_end_turn()
			return
	var other := absf(_ang) > PI * 0.5
	if other != _crossed:
		_crossed = other
		Sfx.play("open")
	var a := _ang - signf(_ang) * PI if other else _ang
	var up_t: Texture2D = _snap if _side == 0 else _bvp.get_texture()
	var down_t: Texture2D = _bvp.get_texture() if _side == 0 else _snap
	_bshow.texture = down_t if other else up_t
	(_bshow.material as ShaderMaterial).set_shader_parameter("tilt", Vector2(-a, 0.0))
	var hm := _hshow.material as ShaderMaterial
	hm.set_shader_parameter("tilt", Vector2(-a, 0.0))
	hm.set_shader_parameter("persp", 0.7 * (card.size.x + HP * 2.0) / maxf(1.0, card.size.x))
	# (the glow is a shadow under the whole card's shape: the card's own place is cut out of its picture)
	var hsz := card.size + Vector2.ONE * HP * 2.0
	hm.set_shader_parameter("hole", Vector2(HP / hsz.x, HP / hsz.y))
	hm.set_shader_parameter("hole_r", 20.0 / hsz.x)

func _end_turn() -> void:
	_turning = false
	if absf(_ang_to) > 1.0: _side = 1 - _side
	_ang = 0.0
	_ang_to = 0.0
	_av = 0.0
	(_bshow.material as ShaderMaterial).set_shader_parameter("tilt", Vector2.ZERO)
	(_hshow.material as ShaderMaterial).set_shader_parameter("tilt", Vector2.ZERO)
	if _side == 0:
		_bshow.visible = false
		_hshow.visible = false
		card.modulate.a = 1.0
		for h in _halo:
			if is_instance_valid(h): h.visible = true
		_bvp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_hvp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	else:
		_bshow.texture = _bvp.get_texture()
		Sfx.buzz(20)
		if test_mend and _mend.visible and not _mend.disabled:
			get_tree().create_timer(1.0).timeout.connect(func() -> void: if is_instance_valid(_mend): _mend.pressed.emit())

## the stones the mending can take: kept, broken (Chipped or Damaged), not mended yet, not swallowed, not this one
func _broken() -> Array:
	var out := []
	for st: Dictionary in Save.d.coll:
		if st == s or st.get("gulp", false) or st.get("mended", false): continue
		if int(st.get("integ", 100)) >= 70: continue   # (Chipped and Damaged: a Fine stone has nothing to fill)
		out.append(st)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("value", 0)) > int(b.get("value", 0)))
	return out

## Mend: a window of the broken stones to choose from; the one chosen is mended and its card opens on it, the gold
## running into its breaks
func _mend_pick() -> void:
	var opener: Callable = v.get_meta("open_stone")
	var list := _broken()
	if list.is_empty():
		Ov.toast("Nothing to mend: every stone is whole")
		return
	var me := s
	var w := Ov.card(350, Color(0.9, 0.66, 0.25))
	w.add_child(UI.title("Mend with gold", 22))
	w.add_child(Kit.rule())
	w.add_child(Ov.text("Gold fills its breaks: whole again, and worth a pristine stone.", 14))
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, mini(3, ceili(list.size() / 3.0)) * 142.0)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(grid)
	w.add_child(sc)
	for st: Dictionary in list:
		var b := Button.new()
		b.custom_minimum_size = Vector2(96, 134)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for k in ["normal", "hover", "focus", "disabled"]: b.add_theme_stylebox_override(k, Kit.box("btn_dark", 6.0))
		b.add_theme_stylebox_override("pressed", Kit.box("btn_dark", 6.0, Color(0.78, 0.74, 0.68)))
		var bv := VBoxContainer.new()
		bv.set_anchors_preset(Control.PRESET_FULL_RECT)
		bv.offset_top = 6
		bv.offset_bottom = -6
		bv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bv.add_theme_constant_override("separation", 1)
		var ph := Museum.photo(Spec.of_stone(st), 84)
		ph.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		bv.add_child(ph)
		var nl := Kit.label(Stones.name_of(st), 12, UI.body_bold, Kit.CREAM)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nl.custom_minimum_size = Vector2(88, 0)
		bv.add_child(nl)
		var cond: Array = Stones.condition(int(st.get("integ", 100)))
		var cl := Kit.label(String(cond[1]), 11, UI.body_bold, [UI.GOOD, Kit.CREAM, Color("#f0b040"), Color("#ff6a5a")][clampi(Stones.CONDITION.find(cond), 0, 3)])
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bv.add_child(cl)
		b.add_child(bv)
		b.pressed.connect(func() -> void:
			mend(st, me)
			pour_id = int(st.id)
			Ov.close()
			opener.call(st))
		grid.add_child(b)
		if test_mend and grid.get_child_count() == 1:
			test_mend = false
			b.get_tree().create_timer(1.5).timeout.connect(func() -> void: if is_instance_valid(b): b.pressed.emit())
	var bk := Kit.button("Back", "btn_dark", 17, 4.0)
	bk.custom_minimum_size = Vector2(0, 48)
	bk.pressed.connect(func() -> void: opener.call(me))
	w.add_child(bk)

static var pour_id := -1       # the stone just mended: its card runs the gold in (pour)

## a stone mended with gold by kintsugi stone `by`: worth a pristine one (its condition's share of the price taken
## out, Pristine's put in), marked; `by` waits its next hundred wins
static func mend(st: Dictionary, by: Dictionary) -> void:
	var was: float = float(Stones.condition(int(st.get("integ", 100)))[2])
	var best: float = float(Stones.CONDITION[0][2])
	st.value = roundi(float(st.get("value", 0)) / maxf(0.01, was) * best)
	st.mended = true
	by.kin_won = int(Save.d.get("won_n", 0))
	Save.persist()
	Diag.note("kintsugi mended " + Stones.name_of(st))
	Awards.once("mended")

## the mended stone's card, built: the gold runs into its breaks white-hot and cools (spec.gdshaderinc mend_k, mend_hot)
static func pour(view: Node, p: Node3D) -> void:
	var mats: Array = p.get_meta("mend_mats", [])
	var caps: Array = p.get_meta("mend_caps", [])
	var set_k := func(k: float, hot: float) -> void:
		for m: ShaderMaterial in mats:
			m.set_shader_parameter("mend_k", k)
			m.set_shader_parameter("mend_hot", hot)
		for c: StandardMaterial3D in caps:
			c.emission_energy_multiplier = hot * 2.5
			c.albedo_color.a = 1.0
	set_k.call(0.0, 1.0)
	var tw := view.create_tween()
	tw.tween_interval(0.5)
	tw.tween_method(func(k: float) -> void: set_k.call(k, 1.0), 0.0, 1.0, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(func(h: float) -> void: set_k.call(1.0, h), 1.0, 0.0, 1.6)
	view.get_tree().create_timer(0.5).timeout.connect(func() -> void: Sfx.play("br_pour"))
	view.get_tree().create_timer(2.6).timeout.connect(func() -> void: Sfx.play("price_up"))
	Sfx.buzz(80)
