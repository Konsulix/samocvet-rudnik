class_name CardKintsugi
extends Control
## Kintsugi (SpecLegend: gold mending in the stone's glass) breaks its card's info panel and mends it with gold: a
## moment after the card opens the panel cracks, falls away in shards and the shards fly back and fit, each seam
## filling with molten gold as both its sides are home; the shards where the buttons were come back turned over —
## the card's back up (the buttons are on the back: a swipe turns the card over). Again now and then while it lies
## face up. The panel's picture for the shards is a snapshot of it (the screen read back once per break).

const SHARDS_ROW := 3          # the shards the button row breaks into
const AGAIN := 30.0            # seconds between breaks, face up
const CRACK := 0.45            # the cracks run
const FALL := 1.0              # the shards fall
const BACK_AT := 1.75          # they start back
const RET := 0.6               # each one's flight home
const STAG := 0.07             # one after the other
const MOLTEN := 0.7
const EMBLEM := Vector2(0.5, 0.27)   # the emblem on the card's back (assets/ui/card_back.png), of its size            # a seam glows white-hot this long, then cools to gold

static var test_every := 0.0   # a test key (-- kin_every=S): a break every S s
static var test_mend := false   # a test key (-- kin_mend): the back up, Mend is pressed and the first broken stone chosen
static var test_flip := 0.0    # a test key (-- kin_flip=S): the card turns over S s after it is built, and back S s later

var card: Control
var view: SpecView
var info: Control
var v: VBoxContainer
var find: Node3D
var row: Control               # the buttons (the caller's last child of the panel's box)

var _root: Control             # (this node sits in the card's padding: its children are placed by hand)
var _hole: Control
var _pieces: Control
var _seams: Control
var _cells := []               # {poly: PackedVector2Array (panel space), c: centroid, down: bool, ...}
var _edges := []               # {pts: PackedVector2Array, a: int, b: int}
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
var _mend: Button
var _gauge: Control
var _side := 0                 # 0: face up, 1: the back up
var _flip_t := -1.0
var _flip_dir := 1.0
var _snap: ImageTexture        # the card's face, for its half of the turn
var _press := Vector2.ZERO
var _pressed := false

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

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 5
	rng.seed = hash(str(find.get_instance_id()))
	if test_every > 0.0: _wait = minf(_wait, test_every)
	_back = load("res://assets/ui/card_back.png") as Texture2D
	_hole = Control.new()
	_hole.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hole.draw.connect(_draw_hole)
	add_child(_hole)
	_pieces = Control.new()
	_pieces.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/card_kin_shard.gdshader")
	m.set_shader_parameter("back", _back)
	_pieces.material = m
	_pieces.draw.connect(_draw_pieces)
	add_child(_pieces)
	_seams = Control.new()
	_seams.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_seams.draw.connect(_draw_seams)
	add_child(_seams)
	# the buttons: the box's last child holding any
	for i in range(v.get_child_count() - 1, -1, -1):
		var c := v.get_child(i) as Control
		if c and (c is Button or not c.find_children("*", "Button", true, false).is_empty()):
			row = c
			break
	_build_back()

func _process(dt: float) -> void:
	if not is_instance_valid(info) or not is_instance_valid(card):
		queue_free()
		return
	_clock += dt
	_turn(dt)
	if test_flip > 0.0 and _flip_t < 0.0 and _t < 0.0 and _clock > test_flip * (_side + 1): flip()
	for n: Control in [_hole, _pieces, _seams]:
		n.global_position = info.global_position
		n.size = info.size
	if _t < 0.0:
		_wait -= dt
		if _wait <= 0.0 and _side == 0 and _flip_t < 0.0 and info.is_visible_in_tree():
			_break()
	else:
		_t += dt
		var home := BACK_AT + RET + STAG * _cells.size()
		if _t > home + MOLTEN + 0.2:
			_t = -1.0
			_wait = test_every if test_every > 0.0 else AGAIN
			info.modulate.a = 1.0
	_pieces.queue_redraw()
	_seams.queue_redraw()
	_hole.queue_redraw()

# ---------------------------------------------------------------- the break

func _break() -> void:
	_t = 0.0
	# the shards' map: drawn once, kept (the same seams every time)
	if _cells.is_empty(): _shatter_map()
	# the panel as it is now (the seams and the turned shards hidden for it: they are on the snapshot's shards again)
	var keep := _seams.visible
	_seams.visible = false
	_pieces.visible = false
	await RenderingServer.frame_post_draw
	if not is_instance_valid(info): return
	var vp := get_viewport()
	var xf := vp.get_final_transform() * info.get_global_transform_with_canvas()
	var r := Rect2i(xf * Rect2(Vector2.ZERO, info.size))
	var img := vp.get_texture().get_image()
	r = r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	_front = ImageTexture.create_from_image(img.get_region(r))
	var m := _pieces.material as ShaderMaterial
	m.set_shader_parameter("front", _front)
	m.set_shader_parameter("psize", info.size)
	var cr := card.get_global_rect()
	var ir := info.get_global_rect()
	var gc := Vector2.ZERO
	var gn := 0
	for c: Dictionary in _cells:
		if c.down:
			gc += c.c
			gn += 1
	if gn > 0:
		var q := (ir.position + gc / gn - cr.position) / cr.size
		m.set_shader_parameter("back_shift", EMBLEM - Vector2(1.0 - q.x, q.y))
	m.set_shader_parameter("pin", Vector4((ir.position.x - cr.position.x) / cr.size.x, (ir.position.y - cr.position.y) / cr.size.y,
		ir.size.x / cr.size.x, ir.size.y / cr.size.y))
	_seams.visible = keep or true
	_pieces.visible = true
	# the live panel goes: its shards are drawn in its place
	info.modulate.a = 0.0
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
		c.vx = rng.randf_range(-70.0, 70.0) + (c.c.x - info.size.x * 0.5) * 0.25
		c.vy = rng.randf_range(-90.0, -20.0)
		c.spin = rng.randf_range(-2.6, 2.6)
		c.drop = rng.randf_range(0.0, 0.12)
		c.home = BACK_AT + STAG * order.find(i)
		c.from = Vector2(rng.randf_range(-60.0, 60.0), info.size.y + rng.randf_range(140.0, 260.0))
		c.rot0 = rng.randf_range(-1.4, 1.4)
		c.turn = (c.down as bool) and not _done_once
	_done_once = true
	Sfx.play("crack")
	Sfx.buzz(60)
	# the shards fall away (their plates' clatter), and the gold runs as they come home (the forge's molten pour)
	get_tree().create_timer(CRACK).timeout.connect(func() -> void: Sfx.play("crust"))
	get_tree().create_timer(BACK_AT + RET).timeout.connect(func() -> void: if is_instance_valid(self): Sfx.play("br_pour"))

## the panel cut into shards: a Voronoi map, a few big shards over the button row, smaller ones above; its seams
## made crooked (each seam bent by its own midpoints — the same for the two shards it parts)
func _shatter_map() -> void:
	var w := info.size.x
	var h := info.size.y
	var rr := Rect2(0, h - 56, w, 48)
	if is_instance_valid(row):
		rr = Rect2(row.get_global_rect().position - info.global_position, row.size)
	var seeds: Array[Vector2] = []
	var down: Array[bool] = []
	for k in SHARDS_ROW:
		seeds.append(Vector2(w * (k + 0.5) / SHARDS_ROW + rng.randf_range(-12.0, 12.0), rr.get_center().y + rng.randf_range(-6.0, 6.0)))
		down.append(true)
	var top := rr.position.y - rr.size.y * 0.7
	var cols := 4
	var rows := maxi(2, roundi(top / 62.0))
	for j in rows:
		for k in cols:
			var p := Vector2((k + 0.5 + rng.randf_range(-0.35, 0.35)) * w / cols, (j + 0.5 + rng.randf_range(-0.35, 0.35)) * top / rows)
			seeds.append(p)
			down.append(false)
	var box := PackedVector2Array([Vector2.ZERO, Vector2(w, 0), Vector2(w, h), Vector2(0, h)])
	var polys := []
	for i in seeds.size():
		var poly := box
		for j in seeds.size():
			if i == j: continue
			var mid := (seeds[i] + seeds[j]) * 0.5
			var nrm := (seeds[j] - seeds[i]).normalized()
			poly = _clip(poly, mid, nrm)
			if poly.size() < 3: break
		polys.append(poly)
	# the seams: every edge two shards share, bent once and shared
	var bent := {}
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
		if (e.cells as Array).size() == 2: _edges.append({pts = e.pts, a = e.cells[0], b = e.cells[1]})

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

## a seam from a to b, crooked as a crack: midpoints pushed aside, twice over (by the place, so both shards agree)
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
			var off := (fmod(hsh, 1.0) - 0.5) * d.length() * 0.28
			nxt.append((p + q) * 0.5 + n * off)
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
		var off := Vector2(float(c.vx) * tf, float(c.vy) * tf + 1500.0 * tf * tf)
		return [off, float(c.spin) * tf, w, clampf(1.0 - (tf - 0.55) / 0.35, 0.0, 1.0)]
	var k := clampf((_t - float(c.home)) / RET, 0.0, 1.0)
	var e := _back_out(k)
	var off2: Vector2 = (c.from as Vector2).lerp(Vector2.ZERO, e)
	var turn := lerpf(float(c.rot0), 0.0, e)
	if bool(c.get("turn", false)):
		w = cos(PI * smoothstep(0.15, 0.85, k))
	return [off2, turn, w, clampf(k / 0.18, 0.0, 1.0)]

static func _back_out(k: float) -> float:
	const S := 1.4
	var x := k - 1.0
	return 1.0 + (S + 1.0) * x * x * x + S * x * x

func _landed(i: int) -> float:
	var c: Dictionary = _cells[i]
	if _t < 0.0: return -99.0
	return float(c.home) + RET

func _draw_hole() -> void:
	if _t < CRACK: return
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.035, 0.035, 0.045)
	sb.set_corner_radius_all(15)
	sb.corner_radius_top_left = 22
	sb.corner_radius_top_right = 22
	sb.shadow_color = Color(0, 0, 0, 0.0)
	_hole.draw_style_box(sb, Rect2(Vector2.ZERO, _hole.size))
	# its inner shade: the panel's socket
	for i in 6:
		var a := 0.22 * (1.0 - i / 6.0)
		_hole.draw_rect(Rect2(0, i, _hole.size.x, 1), Color(0, 0, 0, a))

func _draw_pieces() -> void:
	if _cells.is_empty(): return
	var live := _t >= 0.0
	for i in _cells.size():
		var c: Dictionary = _cells[i]
		if not live and not c.down: continue
		var st := _state(i)
		var fw: float = st[2]
		if absf(fw) < 0.02: continue
		var face_up := fw > 0.0
		var light := 0.78 + 0.22 * absf(fw) - 0.08 * absf(sin(float(st[1])))
		var col := Color(1.0 if face_up else 0.0, 0.0, light, float(st[3]))
		var cols := PackedColorArray()
		var uvs := PackedVector2Array()
		for p: Vector2 in c.poly:
			cols.append(col)
			uvs.append(p / info.size)
		_pieces.draw_set_transform(c.c + st[0], float(st[1]), Vector2(fw, 1.0))
		# (its outline is its home's shape: the face's own place in the panel, mirrored when turned)
		_pieces.draw_polygon(c.loc, cols, uvs)
	_pieces.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_seams() -> void:
	if _cells.is_empty(): return
	# the cracks running before the fall: dark, growing
	if _t >= 0.0 and _t < CRACK + 0.05:
		var k := clampf(_t / (CRACK * 0.8), 0.0, 1.0)
		for e: Dictionary in _edges:
			var pts: PackedVector2Array = e.pts
			var n := maxi(2, roundi(pts.size() * k))
			_seams.draw_polyline(pts.slice(0, n), Color(0.02, 0.02, 0.02, 0.85), 1.4, true)
		return
	# a falling or flying shard's own edge: a thin dark rim
	if _t >= 0.0:
		for i in _cells.size():
			var st := _state(i)
			var c: Dictionary = _cells[i]
			if float(st[3]) <= 0.01 or absf(float(st[2])) < 0.02: continue
			if (st[0] as Vector2).length() < 0.5 and absf(float(st[1])) < 0.01: continue
			_seams.draw_set_transform(c.c + st[0], float(st[1]), Vector2(float(st[2]), 1.0))
			var loop: PackedVector2Array = (c.loc as PackedVector2Array).duplicate()
			loop.append(loop[0])
			_seams.draw_polyline(loop, Color(0, 0, 0, 0.55 * float(st[3])), 1.2, true)
		_seams.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# the gold: a seam is filled once both its shards are home — white-hot, cooling to gold; a glint runs along it
	for e: Dictionary in _edges:
		var lit := -1.0
		if _t < 0.0: lit = 99.0
		else:
			var at := maxf(_landed(int(e.a)), _landed(int(e.b)))
			if _t < at: continue
			lit = _t - at
		var pts: PackedVector2Array = e.pts
		var hot := clampf(1.0 - lit / MOLTEN, 0.0, 1.0)
		var fill := clampf(lit / 0.25, 0.0, 1.0)
		var n := maxi(2, roundi(pts.size() * fill))
		var part := pts.slice(0, n)
		_seams.draw_polyline(part, Color(0.12, 0.07, 0.02, 0.6), 3.2, true)
		var cols := PackedColorArray()
		for p in part:
			var g := fposmod((p.x * 0.6 + p.y * 0.35) - _clock * 70.0, 260.0)
			var glint := exp(-pow((g - 20.0) / 14.0, 2.0)) * 0.6
			var gold := Color(0.86, 0.63, 0.25).lerp(Color(1.0, 0.92, 0.68), glint)
			cols.append(gold.lerp(Color(1.0, 0.97, 0.85), hot))
		_seams.draw_polyline_colors(part, cols, 1.9, true)
		if hot > 0.0:
			_seams.draw_polyline(part, Color(1.0, 0.75, 0.3, 0.35 * hot), 6.0, true)

# ---------------------------------------------------------------- the back

const MEND_EVERY := 100        # wins between a stone's mendings (each kintsugi stone its own)

## wins to go before this stone can mend again (0: it can)
static func mend_wait(st: Dictionary) -> int:
	if not st.has("kin_won"): return 0
	return maxi(0, MEND_EVERY - (int(Save.d.get("won_n", 0)) - int(st.kin_won)))

func _build_back() -> void:
	_holder = card.get_parent() as Control
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
	_art = TextureRect.new()
	_art.texture = _back
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_SCALE
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bvp.add_child(_art)
	# the stone's mending: a gold button, and under it how far its next charge has come (wins)
	_mend = Kit.button("Mend", "btn_dark", 17, 4.0)
	_mend.add_theme_color_override("font_color", Color(0.95, 0.76, 0.38))
	_mend.pressed.connect(_mend_pick)
	_bvp.add_child(_mend)
	_gauge = Control.new()
	_gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gauge.draw.connect(_draw_gauge)
	_bvp.add_child(_gauge)
	tree_exiting.connect(func() -> void: if is_instance_valid(_bshow): _bshow.queue_free())

## the back's layout at the card's size: the art over all of it; at the foot the buttons, the mending above them
func _layout_back() -> void:
	var sz := card.size
	_art.position = Vector2.ZERO
	_art.size = sz
	var w := sz.x - 44.0
	var y := sz.y - 26.0
	if is_instance_valid(row) and row.get_parent() == _bvp:
		row.position = Vector2(22, y - 48.0)
		row.size = Vector2(w, 48)
		y -= 48.0 + 26.0
	var wait := mend_wait(s)
	# (only a kept stone mends — the inventory's card knows how to open another: a new find's back has its two buttons)
	var can := v.has_meta("open_stone")
	_mend.visible = can
	_gauge.visible = can
	_gauge.position = Vector2(22, y - 22.0)
	_gauge.size = Vector2(w, 22)
	_mend.position = Vector2(22, y - 22.0 - 8.0 - 52.0)
	_mend.size = Vector2(w, 52)
	_mend.disabled = wait > 0
	_mend.text = "Mend" if wait == 0 else "Mend · in %d wins" % wait
	_gauge.queue_redraw()

func _draw_gauge() -> void:
	var wait := mend_wait(s)
	var k := 1.0 - float(wait) / MEND_EVERY
	var r := Rect2(Vector2(0, 4), Vector2(_gauge.size.x, 10))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.04, 0.05, 0.85)
	sb.border_color = Color(0.55, 0.42, 0.22)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(5)
	_gauge.draw_style_box(sb, r)
	if k > 0.0:
		var f := StyleBoxFlat.new()
		f.bg_color = Color(0.9, 0.68, 0.28) if wait == 0 else Color(0.72, 0.52, 0.2)
		f.set_corner_radius_all(4)
		_gauge.draw_style_box(f, Rect2(r.position + Vector2(1, 1), Vector2((r.size.x - 2) * k, r.size.y - 2)))
	# ticks at every quarter
	for q in [0.25, 0.5, 0.75]:
		var x: float = r.size.x * q
		_gauge.draw_line(Vector2(x, r.position.y + 2), Vector2(x, r.end.y - 2), Color(0, 0, 0, 0.35), 1.0)

func _pass_input(ev: InputEvent) -> void:
	if _side != 1 or _flip_t >= 0.0: return
	_bvp.push_input(ev.duplicate(), true)
	_bshow.accept_event()

## a swipe across the panel (face up) or across the back turns the card over
func _input(e: InputEvent) -> void:
	if _flip_t >= 0.0 or _t >= 0.0: return
	var press: bool = (e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT) or e is InputEventScreenTouch
	if not press: return
	var pos: Vector2 = (e as InputEventMouseButton).position if e is InputEventMouseButton else (e as InputEventScreenTouch).position
	# (the event in the canvas of the card's layer)
	var cpos := (card.get_global_transform_with_canvas() * card.get_global_transform().affine_inverse()).affine_inverse() * pos
	var area := info.get_global_rect() if _side == 0 else card.get_global_rect()
	if e.is_pressed():
		_pressed = area.has_point(cpos)
		_press = pos
	elif _pressed:
		_pressed = false
		var d := pos - _press
		if absf(d.x) > 48.0 and absf(d.x) > absf(d.y) * 1.5:
			flip(signf(d.x))

## the card turns over: its face (a snapshot) turns away in depth, then the back turns in (or back again)
func flip(dir := -1.0) -> void:
	if _flip_t >= 0.0 or _t >= 0.0: return
	_flip_dir = dir
	_layout_back()
	_size_back()
	# (drawn from now on — till the face is up again: then nothing draws it)
	_bvp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if _side == 0:
		await RenderingServer.frame_post_draw
		if not is_instance_valid(card): return
		var vp := get_viewport()
		var xf := vp.get_final_transform() * card.get_global_transform_with_canvas()
		var r := Rect2i(xf * Rect2(Vector2.ZERO, card.size))
		var img := vp.get_texture().get_image()
		r = r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		_snap = ImageTexture.create_from_image(img.get_region(r))
	else:
		await RenderingServer.frame_post_draw
	_flip_t = 0.0
	_bshow.visible = true
	_bshow.texture = _snap if _side == 0 else _bvp.get_texture()
	card.modulate.a = 0.0
	Sfx.play("open")
	Sfx.buzz(20)

func _size_back() -> void:
	var sz := card.size
	var dens := maxf(1.0, get_viewport().get_final_transform().get_scale().x)
	if dens < 1.8: dens *= 2.0
	var px := Vector2i((sz * dens).round())
	if _bvp.size != px: _bvp.size = px
	if _bvp.size_2d_override != Vector2i(sz.round()): _bvp.size_2d_override = Vector2i(sz.round())

func _turn(dt: float) -> void:
	if not is_instance_valid(_bshow): return
	_bshow.global_position = card.global_position
	_bshow.size = card.size
	if _flip_t < 0.0: return
	_flip_t += dt
	var k := clampf(_flip_t / FLIP, 0.0, 1.0)
	var e := k * k * (3.0 - 2.0 * k)
	var m := _bshow.material as ShaderMaterial
	var a: float
	# first half: the side that is up turns away; then the other turns in from the far edge
	if e < 0.5:
		a = e * 2.0 * 1.55
		_bshow.texture = _snap if _side == 0 else _bvp.get_texture()
	else:
		a = -(1.0 - e) * 2.0 * 1.55
		_bshow.texture = _bvp.get_texture() if _side == 0 else _snap
	m.set_shader_parameter("tilt", Vector2(a * -_flip_dir, 0.0))
	if k >= 1.0:
		_flip_t = -1.0
		_side = 1 - _side
		m.set_shader_parameter("tilt", Vector2.ZERO)
		if _side == 0:
			_bshow.visible = false
			card.modulate.a = 1.0
			_bvp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		else:
			_bshow.texture = _bvp.get_texture()
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
	if int(st.get("integ", 100)) < 50: Awards.once("mended_bad")

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
