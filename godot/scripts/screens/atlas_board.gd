class_name AtlasBoard
extends Control
## The atlas as one board you drag and pinch (mock-ups art/ui_redesign/achievements/f_web.png, g_thread.png): every mine an
## "island" - its boss's sign in the middle, its species around it on thin brass threads (the found ones as their best
## stone in a soft dark socket with a glow of their colour, the rest as dark silhouettes), under the sign the mine's name,
## "6/8" and its seals. A beaten boss's sign replays the fight. The islands lie round "Earth" in the middle (the chain
## of mines on a ring, joined in their order; the reserve mines and the one to come further out), the whole map on the
## screen at first: tap an island to fly into it.
## Everything is drawn here in one _draw (pictures: Atlas.cutout), in board coordinates under one transform.

const RING := 150.0      # species round the sign
const CARD := Vector2(72, 82)   # a species' card (like the inventory's, smaller)
const SOCK := 41.0       # half a card's height: room round it
const SIGN := 46.0       # the boss's sign
const SIGN_Y := -28.0    # the sign sits a little high: its text goes under it
const PATCH := 196.0     # the lighter slate under an island
const RX := 430.0        # the ring of the chain's mines (taller than wide: a phone)
const RY := 600.0
const OUT := 1.72        # the reserve mines and the one to come: this much further out, between the chain's
const ZMIN := 0.2
const CHAIN := 5         # the mines on the road; the reserve ones (6-8) join once open
const ZMAX := 1.8
const NAMES_AT := 0.62   # below this zoom the species' names are hidden (they turn to mush)
const FAR := 0.5         # below this zoom an island is drawn simply: a big sign, a ring of dots, its name large
const DOT := 15.0        # a species as a dot on the far view
const INK := Color(0.95, 0.92, 0.86)   # the callouts' ink (SpecCallouts.INK)

var atlas: Atlas
var zoom := 1.0
var off := Vector2.ZERO          # where the board's (0, 0) is on the screen
var _isl: Array[Dictionary] = [] # {a, c (centre), open, won, ids, pos (socket centres)}
var _tex := {}                   # species id -> picture
var _lit: Array[Array] = []      # the won rubies drawn this frame: [centre, half size, own offset] - for the glints
var _gl: Control
var _boxes := {}                 # a card's StyleBoxFlat by its look
var _touch := {}                 # finger -> position
var _pinch := 0.0
var _press := Vector2.ZERO
var _moved := false
var _down := false
var _sel := ""                   # the species tapped last (named even when zoomed out)
var _glide: Tween
var _vel := Vector2.ZERO         # the fling after a drag
var _last_t := 0.0
var _t := 0.0                    # time, for the fling and tap ripples
var _ripples: Array[Array] = []  # [board point, start time]

func _init(at: Atlas) -> void:
	atlas = at
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP

func _ready() -> void:
	# the chain of mines (1-5), then the reserve ones only once open, then one still to come
	var show: Array[int] = []
	for a in Data.AREAS.size():
		show.append(a)   # every mine, the reserve ones (6-8) too: further out
	var n := show.size()
	for j in n:
		var a := show[j]
		var c := _spot(j)
		var A: Dictionary = Data.AREAS[a]
		var ids: Array = A.pool.keys()
		ids.sort_custom(func(x, y): return int(Data.SP[x].r) < int(Data.SP[y].r) or (int(Data.SP[x].r) == int(Data.SP[y].r) and float(A.pool[x]) > float(A.pool[y])))
		var pos: Array[Vector2] = []
		for i in ids.size():
			# evenly round the ring, half a step turned so a pair sits under the text, not one on it
			var an := -PI / 2.0 + TAU * (i + 0.5) / ids.size()
			pos.append(c + Vector2(cos(an), sin(an)) * RING)
		var open := Atlas.is_open(a)
		var won: bool = a < Save.d.boss_won.size() and bool(Save.d.boss_won[a]) and A.has("boss")
		_isl.append({a = a, c = c, open = open, won = won, ids = ids, pos = pos})
	# one more, still to come
	_isl.append({a = -1, c = _spot(n), open = false, won = false, ids = [], pos = []})
	# the pictures: the player's mine first
	var order: Array[Dictionary] = [_find(Save.area())]
	for isl in _isl:
		if isl != order[0] and isl.a >= 0 and isl.open: order.append(isl)
	for isl in _isl:
		if isl.a >= 0 and not isl.open: order.append(isl)
	for isl in order:
		for id in isl.ids:
			var e: Dictionary = Save.d.atlas.get(id, {})
			var sid := String(id)
			Atlas.cutout(Spec.of_stone(e.best) if e.has("best") else Atlas._sample(sid), func(t: Texture2D):
				if is_instance_valid(self):
					_tex[sid] = t
					queue_redraw())
	resized.connect(func(): if off == Vector2.ZERO: overview(false))
	_gl = Glints.new(self)
	add_child(_gl)
	_buttons()

## where the j-th island lies: the chain on the ring clockwise from the top, the rest further out between them
func _spot(j: int) -> Vector2:
	var an := -PI / 2.0 + TAU * j / CHAIN
	var r := Vector2(RX, RY)
	if j >= CHAIN:
		an = -PI / 2.0 + TAU * (j - CHAIN + 0.5) / CHAIN
		r *= OUT
	return Vector2(cos(an), sin(an)) * r

## centre the player's mine
func home(glide := true) -> void:
	_go(_find(Save.area()).c + Vector2(0, 6), 1.0, glide)

func _find(a: int) -> Dictionary:
	for isl in _isl:
		if isl.a == a: return isl
	return _isl[0]

func _go(at: Vector2, z: float, glide: bool) -> void:
	var to := size / 2.0 - at * z
	if not glide:
		zoom = z
		off = to
		queue_redraw()
		return
	if _glide: _glide.kill()
	var z0 := zoom
	var o0 := off
	_glide = create_tween()
	_glide.tween_method(func(k: float):
		zoom = lerpf(z0, z, k)
		off = o0.lerp(to, k)
		queue_redraw(), 0.0, 1.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _buttons() -> void:
	# "my mine" and "all" at the bottom right
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	col.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	col.grow_vertical = Control.GROW_DIRECTION_BEGIN
	col.offset_right = -12
	col.offset_bottom = -12
	add_child(col)
	col.add_child(_round("mine", func(): home()))
	col.add_child(_round("all", overview))

## the whole map at once
func overview(glide := true) -> void:
	var r := _bounds()
	var z := clampf(minf(size.x / r.size.x, size.y / r.size.y), ZMIN, 1.0)
	_go(r.get_center(), z, glide)

## all the islands with their patches
func _bounds() -> Rect2:
	var r := Rect2(_isl[0].c, Vector2.ZERO)
	for i in _isl: r = r.expand(i.c)
	return r.grow(PATCH * 1.05)

func _round(kind: String, f: Callable) -> Button:
	var b := Kit.button("", "sq_dark", 16, 2.0)
	b.custom_minimum_size = Vector2(40, 40)
	var g := Control.new()
	g.set_anchors_preset(Control.PRESET_FULL_RECT)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.draw.connect(func():
		var c := g.size / 2.0
		if kind == "mine":   # a target
			g.draw_arc(c, 8, 0, TAU, 24, Kit.CREAM, 1.8, true)
			g.draw_circle(c, 2.5, Kit.CREAM)
			for d: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				g.draw_line(c + d * 9, c + d * 13, Kit.CREAM, 1.8, true)
		else:   # three dots on a line: the whole road
			for i in 3:
				g.draw_circle(c + Vector2(-4 + i * 4, -7 + i * 7), 3.0, Kit.CREAM)
			g.draw_line(c + Vector2(-4, -7), c + Vector2(4, 7), Color(Kit.CREAM, 0.6), 1.2, true))
	b.add_child(g)
	b.pressed.connect(f)
	return b

# ---------------------------------------------------------------- input

func _gui_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		if e.pressed: _touch[e.index] = e.position
		else: _touch.erase(e.index)
		_pinch = 0.0
		if _touch.size() >= 2: _moved = true
	elif e is InputEventScreenDrag:
		_touch[e.index] = e.position
		if _touch.size() >= 2:
			var k: Array = _touch.values()
			var p0: Vector2 = k[0]
			var p1: Vector2 = k[1]
			var d := p0.distance_to(p1)
			if _pinch > 0.0:
				_zoom_at((p0 + p1) / 2.0, d / _pinch)
			_pinch = d
	elif e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				_down = true
				_moved = false
				_press = e.position
				_vel = Vector2.ZERO
				_last_t = _t
				if _glide: _glide.kill()
				if e.double_click: home()
			else:
				_down = false
				if not _moved: _tap(e.position)
				elif _t - _last_t > 0.08: _vel = Vector2.ZERO   # held still before letting go: no fling
		elif e.pressed and e.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_glide(e.position, 1.25)
		elif e.pressed and e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_glide(e.position, 1.0 / 1.25)
	elif e is InputEventMouseMotion and _down and _touch.size() < 2:
		if not _moved and e.position.distance_to(_press) > 7.0:
			_moved = true
		if _moved:
			off += e.relative
			# the speed of the finger, smoothed: what the board keeps when let go
			var dt := maxf(_t - _last_t, 1.0 / 120.0)
			_vel = _vel.lerp(e.relative / dt, 0.4)
			_last_t = _t
			_clamp()
			queue_redraw()
	elif e is InputEventMagnifyGesture:
		_zoom_at(e.position, e.factor)
	elif e is InputEventPanGesture:
		off -= e.delta * 12.0
		_clamp()
		queue_redraw()

## a wheel step: the same zoom, but glides there
func _zoom_glide(p: Vector2, k: float) -> void:
	var z1 := clampf(zoom * k, ZMIN, ZMAX)
	var w := (p - off) / zoom
	if _glide: _glide.kill()
	var z0 := zoom
	_glide = create_tween()
	_glide.tween_method(func(q: float):
		zoom = lerpf(z0, z1, q)
		off = p - w * zoom
		_clamp()
		queue_redraw(), 0.0, 1.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _process(dt: float) -> void:
	_t += dt
	# the fling, slowing down
	# redrawn only while something moves (a fling, a ripple): standing still the board costs nothing
	var moving := false
	if not _down and _vel.length() > 8.0:
		off += _vel * dt
		_vel *= exp(-dt * 4.5)
		_clamp()
		moving = true
	elif not _down:
		_vel = Vector2.ZERO
	while _ripples.size() and _t - float(_ripples[0][1]) > 0.5:
		_ripples.pop_front()
		moving = true
	if moving or _ripples.size():
		queue_redraw()

func _ripple(w: Vector2) -> void:
	_ripples.append([w, _t])

func _zoom_at(p: Vector2, k: float) -> void:
	var z := clampf(zoom * k, ZMIN, ZMAX)
	off = p - (p - off) * (z / zoom)
	zoom = z
	_clamp()
	queue_redraw()

## the board does not run away: some island always stays on the screen
func _clamp() -> void:
	var b := _bounds()
	var lo := b.position
	var hi := b.end
	var m := size * 0.5
	off.x = clampf(off.x, m.x - hi.x * zoom, m.x - lo.x * zoom)
	off.y = clampf(off.y, m.y - hi.y * zoom, m.y - lo.y * zoom)

func _tap(p: Vector2) -> void:
	var w := (p - off) / zoom
	# zoomed out: a tap on an island flies into it
	if zoom < FAR:
		for isl in _isl:
			if isl.a >= 0 and w.distance_to(isl.c) < PATCH:
				Sfx.play("tab")
				_ripple(isl.c)
				_go(isl.c + Vector2(0, 6), 1.0, true)
				return
		return
	for isl in _isl:
		if isl.a < 0: continue
		if w.distance_to(isl.c + Vector2(0, SIGN_Y)) < SIGN + 6:
			_ripple(isl.c + Vector2(0, SIGN_Y))
			if isl.open: atlas._boss_card(isl.a)
			else: Ov.toast("%s · locked" % Data.AREAS[isl.a].n)
			return
		for i in isl.ids.size():
			if Rect2(isl.pos[i] - CARD / 2.0, CARD).grow(4).has_point(w):
				var id := String(isl.ids[i])
				_sel = id
				_ripple(isl.pos[i])
				if not isl.open:
					Ov.toast("Lies in %s · locked" % Data.AREAS[isl.a].n)
					return
				if Save.d.atlas.has(id) and Save.d.atlas[id].has("best"):
					Sfx.play("open")
					atlas._open_species(id)
				else:
					Ov.toast("Not found yet · %s" % Data.RAR[int(Data.SP[id].r)])
				return
		if not isl.open: continue
		# the name under the sign: the mine's own page (the old one, for now)
		if Rect2(isl.c + Vector2(-90, 18), Vector2(180, 64)).has_point(w):
			Sfx.play("tab")
			atlas.area = isl.a
			atlas.render()
			return

# ---------------------------------------------------------------- drawing

func _draw() -> void:
	_lit.clear()
	if _gl: _gl.queue_redraw()
	draw_set_transform(off, 0.0, Vector2(zoom, zoom))
	var far := zoom < FAR
	# threads from Earth to every island; the chain's road round the ring, in the order of the mines; the outer road
	# of the reserve mines and the one to come, a faint dotted ellipse broken at the islands
	for isl in _isl:
		_dots(Vector2.ZERO, isl.c, PATCH * 0.8, Color(Kit.AMBER, 0.3 if isl.open else 0.16), 1.8, 18.0)
	var chain := mini(CHAIN, _isl.size())
	for i in chain - 1:
		_dots(_isl[i].c, _isl[i + 1].c, PATCH * 0.8, Color(Kit.AMBER, 0.6 if _isl[i + 1].open else 0.32), 2.6, 14.0)
	_outer_road()
	_hub()
	# only the islands on the screen
	var view := Rect2(-off / zoom, size / zoom).grow(20.0)
	for isl in _isl:
		if not view.intersects(Rect2(isl.c - Vector2(PATCH, PATCH), Vector2(PATCH, PATCH) * 2.0).grow(80.0)): continue
		if far: _island_far(isl)
		else: _island(isl)
	for r in _ripples:
		var k := (_t - float(r[1])) / 0.5
		draw_arc(r[0], lerpf(20.0, 70.0, k) / maxf(zoom, 0.35), 0, TAU, 48, Color(Kit.AMBER, 0.6 * (1.0 - k)), 2.0 / zoom, true)
	draw_set_transform(Vector2.ZERO)

## the reserve mines' road: dots on the outer ellipse, gone where an island lies
func _outer_road() -> void:
	if _isl.size() <= CHAIN: return
	var r := Vector2(RX, RY) * OUT
	var n := int(TAU * (r.x + r.y) * 0.5 / 16.0)
	for i in n:
		var an := TAU * i / n
		var p := Vector2(cos(an), sin(an)) * r
		var near := false
		for isl in _isl:
			if p.distance_to(isl.c) < PATCH * 0.85: near = true
		if not near:
			draw_circle(p, 2.0, Color(Kit.AMBER, 0.2))

## a dotted line from a to b, leaving `gap` free at both ends
func _dots(a: Vector2, b: Vector2, gap: float, col: Color, r: float, step: float) -> void:
	var d := (b - a).normalized()
	var a0 := a + d * (gap if a != Vector2.ZERO else 70.0)
	var a1 := b - d * gap
	var n := int(a0.distance_to(a1) / step)
	for k in n + 1:
		draw_circle(a0.lerp(a1, float(k) / maxf(1, n)), r, col)

## Earth in the middle: what is found of all of it
func _hub() -> void:
	var have := 0
	var all := 0
	for a in Data.AREAS.size():
		have += Atlas.found_in(a)
		all += Data.AREAS[a].pool.size()
	var k := 2.4 if zoom < FAR else 1.0
	_disc(Vector2.ZERO, 110.0 * k, Color(1, 0.94, 0.84, 0.07), Color(1, 0.94, 0.84, 0.0))
	draw_arc(Vector2.ZERO, 54.0 * k, 0, TAU, 64, Color(Kit.AMBER, 0.5), 1.4 * k, true)
	_text("Earth", Vector2(0, -2 * k), int(20 * k), UI.display, Kit.CREAM, true)
	_text("%d/%d species" % [have, all], Vector2(0, 18 * k), int(12 * k), UI.body_bold, Kit.DIM, true)

## an island seen from afar: the sign large in the middle, its species a ring of dots (found ones lit in their colour),
## the name and n/m large under it
func _island_far(isl: Dictionary) -> void:
	var c: Vector2 = isl.c
	var open: bool = isl.open
	_disc(c, PATCH, Color(1, 0.94, 0.84, 0.06 if open else 0.035), Color(1, 0.94, 0.84, 0.0))
	for i in isl.pos.size():
		var id := String(isl.ids[i])
		var p: Vector2 = isl.pos[i]
		var got: bool = open and Save.d.atlas.has(id)
		if got:
			var col := Data.sp_color(id)
			if not Atlas.best_kept(id): col = Color(0.55, 0.54, 0.52)
			_disc(p, DOT * 2.6, Color(col, 0.45), Color(col, 0.0))
			draw_circle(p, DOT, col.lightened(0.15))
		else:
			draw_circle(p, DOT, Color(0.06, 0.05, 0.045, 0.9))
			draw_arc(p, DOT, 0, TAU, 24, Color(1, 0.95, 0.85, 0.22 if open else 0.12), 2.5, true)
	var sg := 82.0
	var sign := Atlas._sign(isl.a, open) if isl.a >= 0 else "lock"
	draw_texture_rect(_emblem(sign), Rect2(c - Vector2(sg, sg), Vector2(sg, sg) * 2.0), false, Color(1, 1, 1, 1.0 if open else 0.75))
	if isl.a >= 0 and Data.AREAS[isl.a].has("boss"):
		_rubies(c, sg, rubies(isl.a) if open else 0, 2.2, open)
	var nm := "???" if isl.a < 0 else String(Data.AREAS[isl.a].n)
	var y := c.y + RING + DOT + 62.0
	_text(nm, Vector2(c.x, y), 54, UI.display, Kit.CREAM if open else Kit.DIM, true)
	if isl.a >= 0:
		var n := Atlas.found_in(isl.a) if open else 0
		_text("%d/%d" % [n, isl.ids.size()], Vector2(c.x, y + 52), 38, UI.body_bold, Kit.CREAM if open else Kit.DIM, true)

func _island(isl: Dictionary) -> void:
	var c: Vector2 = isl.c
	var open: bool = isl.open
	var dim := 1.0 if open else 0.6
	var sg := SIGN
	# a barely lighter patch of slate under it
	_disc(c, PATCH, Color(1, 0.94, 0.84, 0.055 * dim), Color(1, 0.94, 0.84, 0.0))
	var sc := c + Vector2(0, SIGN_Y)
	# threads like the gene callouts on the specimen card (SpecCallouts): a hair-thin light line on a soft shade, out
	# from under the sign (drawn before it), a tiny ring with a point a little off the card's edge; the same width on
	# the screen at any zoom
	var px := 1.0 / zoom
	var ink := Color(INK, 0.55 * dim)
	var shade := Color(0, 0, 0, 0.3 * dim)
	for i in isl.pos.size():
		var p: Vector2 = isl.pos[i]
		var d := (p - sc).normalized()
		var a := sc + d * sg * 0.7
		var b := p - d * (_to_edge(d) + 6.0 * px)
		draw_line(a, b - d * 2.6 * px, shade, 2.0 * px, true)
		draw_line(a, b - d * 2.6 * px, ink, 0.8 * px, true)
		draw_arc(b, 2.4 * px, 0.0, TAU, 24, shade, 2.0 * px, true)
		draw_arc(b, 2.4 * px, 0.0, TAU, 24, ink, 0.8 * px, true)
		draw_circle(b, 0.9 * px, ink)
	var names := zoom >= NAMES_AT
	for i in isl.pos.size():
		_species(String(isl.ids[i]), isl.pos[i], open, names)
	# the boss's sign
	var sign := Atlas._sign(isl.a, open) if isl.a >= 0 else "lock"
	draw_texture_rect(_emblem(sign), Rect2(sc - Vector2(sg, sg), Vector2(sg, sg) * 2.0), false, Color(1, 1, 1, 1.0 if open else 0.7))
	if isl.a >= 0 and Data.AREAS[isl.a].has("boss"):
		_rubies(sc, sg, rubies(isl.a) if open else 0, 1.0, open)
	# under it: Replay, the name, n/m
	var y := sc.y + sg + 6
	if isl.won:
		_pill(Vector2(c.x, y + 10), "Replay")
		y += 24
	var nm := "???" if isl.a < 0 else String(Data.AREAS[isl.a].n)
	_text(nm, Vector2(c.x, y + 19), 19, UI.display, Kit.CREAM if open else Kit.DIM, true)
	if isl.a >= 0:
		var n := Atlas.found_in(isl.a) if open else 0
		var row := y + 38
		_text("%d/%d" % [n, isl.ids.size()], Vector2(c.x, row), 13, UI.body_bold, Kit.CREAM if open else Kit.DIM, true)

## from a card's middle to its edge along d
static func _to_edge(d: Vector2) -> float:
	var h := CARD / 2.0
	return minf(h.x / maxf(absf(d.x), 0.001), h.y / maxf(absf(d.y), 0.001))

## a species as a small card like the inventory's (Museum._tile): dark ground tinted by its colour, a calm brass edge,
## its best stone on a soft glow, the name top-left over a short rule of its rarity; not found: darker, the silhouette,
## "???" and its rarity at the bottom
func _species(id: String, p: Vector2, open: bool, _names: bool) -> void:
	var e: Dictionary = Save.d.atlas.get(id, {})
	var got := open and e.has("best")
	var gone := got and not Atlas.best_kept(id)
	var col := Data.sp_color(id)
	if gone: col = Color(0.5, 0.49, 0.47)
	var r := Rect2(p - CARD / 2.0, CARD)
	# the card's box, made once per species and kept (not a new one every frame)
	var key := "%s:%d%d%d%d" % [id, int(got), int(gone), int(open), int(_sel == id)]
	if not _boxes.has(key):
		var st := StyleBoxFlat.new()
		st.bg_color = Color("#17130f").lerp(col, 0.06) if got else Color("#14110d", 0.95 if open else 0.7)
		st.border_color = Color(Kit.AMBER, 0.9 if _sel == id else 0.38 if got else 0.16 if open else 0.09)
		st.set_border_width_all(1)
		st.set_corner_radius_all(8)
		st.anti_aliasing = true
		_boxes[key] = st
	draw_style_box(_boxes[key], r)
	if got:
		_disc(p + Vector2(0, CARD.y * 0.1), CARD.x * 0.5, Color(col, 0.22), Color(col, 0.0))
	var t: Texture2D = _tex.get(id)
	if t:
		var box := Vector2(CARD.x * 0.84, CARD.y * 0.6)
		var k := minf(box.x / t.get_width(), box.y / t.get_height())
		var s := t.get_size() * k
		var at := Vector2(p.x, r.position.y + CARD.y * 0.27 + box.y / 2.0)
		# found: the stone; not found: its silhouette; in a locked mine the silhouette is fainter still
		var m := Color.WHITE if got and not gone else Color(0.55, 0.55, 0.55) if gone else Color(0.015, 0.012, 0.01, 1.0 if open else 0.6)
		draw_texture_rect(t, Rect2(at - s / 2.0, s), false, m)
	var fnt: Font = UI.body_bold
	var nm := String(Data.SP[id].n) if got else "???"
	var maxw := CARD.x - 12.0
	while nm.length() > 3 and fnt.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x > maxw:
		nm = nm.substr(0, nm.length() - 2) + "…"
	var tp := r.position + Vector2(6, 12)
	draw_string(fnt, tp + Vector2(0, 1), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0, 0, 0, 0.7))
	draw_string(fnt, tp, nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Kit.CREAM if got else Color(Kit.DIM, 0.8 if open else 0.45))
	var tier: int = int(e.best.tier) if got else int(Data.SP[id].r)
	var rc := Data.rarity_color(tier)
	if got:
		draw_rect(Rect2(tp + Vector2(0, 3), Vector2(12, 1.2)), rc.lightened(0.15))
	elif open:
		var rt := String(Data.RAR[tier])
		var rw := fnt.get_string_size(rt, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
		draw_string(fnt, Vector2(p.x - rw / 2.0, r.end.y - 5), rt, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(rc.lerp(Kit.DIM, 0.55), 0.85))

## the emblem as a plain image texture: drawn straight from the imported file it came out a white square here
static var _em := {}
static func _emblem(sign: String) -> Texture2D:
	var own := "res://assets/atlas/board/emblem_%s.png" % sign
	return _pic(own if ResourceLoader.exists(own) else "res://assets/atlas/emblem_%s.png" % sign, 160)

static func _pic(path: String, px: int) -> Texture2D:
	if not _em.has(path):
		var src: Texture2D = load(path)
		var img := src.get_image()
		if img.is_compressed(): img.decompress()
		img.clear_mipmaps()
		img.resize(px, px, Image.INTERPOLATE_LANCZOS)
		_em[path] = ImageTexture.create_from_image(img)
	return _em[path]

## how many of the boss's three rubies are won: one for the first win, then one for each harder fight (2nd and 3rd
## tier: more health or fewer moves - not made yet). Kept in Save.d.boss_rubies when it exists; test key rubies=N
static func rubies(a: int) -> int:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("rubies="): return clampi(int(arg.trim_prefix("rubies=")), 0, 3)
	var r: Array = Save.d.get("boss_rubies", [])
	if a < r.size(): return clampi(int(r[a]), 0, 3)
	return 1 if a < Save.d.boss_won.size() and bool(Save.d.boss_won[a]) else 0

## the three sockets on the boss's sign, at the points of a three-pointed star (top, lower right, lower left) on its
## ring, where the old four rivets were; a won one holds a cut ruby (GPT sprites, assets/atlas/board/); the glints on
## the rubies are drawn by the Glints layer over the board
const RUBY_R := 0.86     # the sockets' circle, share of the sign's radius
const RUBY_S := 0.25      # a socket's half size, share of the sign's radius
func _rubies(sc: Vector2, sg: float, n: int, _k: float, open: bool) -> void:
	for i in 3:
		var an := -PI / 2.0 + TAU * i / 3.0
		var c := sc + Vector2(cos(an), sin(an)) * sg * RUBY_R
		var h := sg * RUBY_S
		if i < n:
			_disc(c, h * 2.6, Color(1.0, 0.15, 0.2, 0.35), Color(1, 0.15, 0.2, 0))
			draw_texture_rect(_pic("res://assets/atlas/board/ruby_%d.png" % RUBY_CUT, 96), Rect2(c - Vector2(h, h), Vector2(h, h) * 2.0), false)
			_lit.append([c, h, float(i) * 0.31 + c.x * 0.0007])
		else:
			draw_texture_rect(_pic("res://assets/atlas/board/socket.png", 96), Rect2(c - Vector2(h, h), Vector2(h, h) * 2.0), false, Color(1, 1, 1, 1.0 if open else 0.6))

const RUBY_CUT := 3      # which of the three cuts GPT drew

func _pill(c: Vector2, t: String, k := 1.0) -> void:
	var w := 70.0 * k
	var r := Rect2(c - Vector2(w / 2.0, 9 * k), Vector2(w, 18 * k))
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.06, 0.05, 0.04, 0.85)
	st.border_color = Color(Kit.AMBER, 0.7)
	st.set_border_width_all(1)
	st.set_corner_radius_all(int(9 * k))
	st.anti_aliasing = true
	draw_style_box(st, r)
	_text(t, c + Vector2(0, 4 * k), int(11 * k), UI.body_bold, Kit.CREAM, false)

func _text(t: String, at: Vector2, fs: int, f: Font, col: Color, shade: bool) -> void:
	var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var p := Vector2(at.x - w / 2.0, at.y)
	if shade:
		draw_string(f, p + Vector2(0, 1.5), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.7))
	draw_string(f, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

## a soft round glow: `a` in the middle fading out at radius r (`b` is always `a` gone clear). One quad with a radial
## gradient picture - it was 80 triangles each, thousands per frame while the board moved
static var _glow: GradientTexture2D
func _disc(c: Vector2, r: float, a: Color, _b: Color) -> void:
	if _glow == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
		_glow = GradientTexture2D.new()
		_glow.gradient = g
		_glow.fill = GradientTexture2D.FILL_RADIAL
		_glow.fill_from = Vector2(0.5, 0.5)
		_glow.fill_to = Vector2(1.0, 0.5)
		_glow.width = 128
		_glow.height = 128
	draw_texture_rect(_glow, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false, a)

## the glints on the won rubies, over the board: each ruby drawn again with ruby_glint.gdshader (added light), its
## sweep moved by the board's position and slowly by time - a moving page makes them flash
class Glints extends Control:
	var b: AtlasBoard
	var mat: ShaderMaterial
	func _init(board: AtlasBoard) -> void:
		b = board
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mat = ShaderMaterial.new()
		mat.shader = load("res://shaders/ruby_glint.gdshader")
		material = mat
	func _process(_dt: float) -> void:
		if b._lit.size(): queue_redraw()
	func _draw() -> void:
		mat.set_shader_parameter("phase", (b.off.x * 0.7 + b.off.y) * 0.0022 + b._t * 0.045)
		draw_set_transform(b.off, 0.0, Vector2(b.zoom, b.zoom))
		var tx := AtlasBoard._pic("res://assets/atlas/board/ruby_%d.png" % AtlasBoard.RUBY_CUT, 96)
		for r in b._lit:
			var c: Vector2 = r[0]
			var h: float = r[1]
			draw_texture_rect(tx, Rect2(c - Vector2(h, h), Vector2(h, h) * 2.0), false, Color(fposmod(float(r[2]), 1.0), 1, 1, 1))
