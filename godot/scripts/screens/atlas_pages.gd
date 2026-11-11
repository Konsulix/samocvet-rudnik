class_name AtlasPages
extends Control
## The atlas as pages, one mine a page, swiped left and right (the pannable board of islands, AtlasBoard, did not work
## on a phone: one island in the middle of empty slate, small blurry stones, a useless far view).
## On top a strip with every mine's boss medallion (locked ones with a lock): how many there are, tap to jump.
## A page is a spread of a collector's album: the mine's 8 species as collectible cards 3 x 3 round the boss's
## medallion (three ruby sockets - a ruby per beaten difficulty, AtlasBoard.rubies - n/m and Replay in the middle).
## Found - a small copy of the specimen card; not found - the card's back with where it turns up (AlbumCard). Cards
## found since last time turn over when their page shows; a whole mine found lights the spread (its seal).
## Taps are hit-tested here (the cards ignore the mouse), so a swipe that starts on a card still turns the page.

const STRIP_H := 50.0
const CARD_K := 1.36       # a card's height to its width
const SIGN := 78.0         # the medallion's size on a page
const GAP := 8.0
const PAD := 12.0

var atlas: Atlas
var page := 0
var _track: Control        # all the pages side by side; its x is the swipe
var _pages: Array[Control] = []
var _strip: HBoxContainer
var _taps: Array[Array] = []   # [Control, Callable]
var _down := false
var _moved := false
var _press := Vector2.ZERO
var _x0 := 0.0
var _vx := 0.0
var _last := 0.0
var _t := 0.0
var _slide: Tween
var _built := false
var _to_flip := {}         # page -> cards found since last time, face down until the page shows

func _init(at: Atlas) -> void:
	atlas = at
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP

func _ready() -> void:
	page = clampi(Save.area(), 0, Data.AREAS.size() - 1)
	resized.connect(_build)

func _process(dt: float) -> void:
	_t += dt

func _build() -> void:
	if _built or size.x < 10: return
	_built = true
	_strip = HBoxContainer.new()
	_strip.alignment = BoxContainer.ALIGNMENT_CENTER
	_strip.add_theme_constant_override("separation", 4)
	_strip.position = Vector2(0, 4)
	_strip.size = Vector2(size.x, STRIP_H - 6)
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_strip)
	for a in Data.AREAS.size():
		_strip.add_child(_dot(a))
	_track = Control.new()
	_track.position = Vector2(0, STRIP_H)
	_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_track)
	var ph := size.y - STRIP_H
	# the page in view first, so its stones are the first rendered
	var order: Array[int] = [page]
	for a in Data.AREAS.size():
		if a != page: order.append(a)
	_pages.resize(Data.AREAS.size())
	for a in order:
		var p := _page(a, Vector2(size.x, ph))
		p.position = Vector2(size.x * a, 0)
		_track.add_child(p)
		_pages[a] = p
	_track.position.x = -size.x * page
	_flip_page(page)

# ---------------------------------------------------------------- the strip of medallions

func _dot(a: int) -> Control:
	var d := Control.new()
	d.custom_minimum_size = Vector2(40, STRIP_H - 6)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var open := Atlas.is_open(a)
	var em := AtlasBoard._emblem(Atlas._sign(a, open))
	d.draw.connect(func():
		var c := Vector2(d.size.x / 2.0, 19)
		var on := a == page
		var r := 17.0 if on else 14.0
		d.draw_texture_rect(em, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(1, 1, 1, 1.0 if on else (0.75 if open else 0.4)))
		if on:
			d.draw_line(Vector2(c.x - 10, d.size.y - 2), Vector2(c.x + 10, d.size.y - 2), Kit.AMBER, 2.0, true))
	_taps.append([d, func(): go_to(a)])
	return d

func go_to(a: int) -> void:
	a = clampi(a, 0, Data.AREAS.size() - 1)
	if a != page: Sfx.play("tab")
	page = a
	if _slide: _slide.kill()
	_slide = create_tween()
	_slide.tween_property(_track, "position:x", -size.x * page, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for ch in _strip.get_children(): ch.queue_redraw()
	_flip_page(page)

# ---------------------------------------------------------------- a page: a spread of the album

func _page(a: int, sz: Vector2) -> Control:
	var p := Control.new()
	p.size = sz
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var A: Dictionary = Data.AREAS[a]
	var open := Atlas.is_open(a)
	# the mine's name and where it is
	var nm := Atlas._shadowed(String(A.n), 22, Kit.CREAM if open else Kit.DIM)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.position = Vector2(0, 2)
	nm.size = Vector2(sz.x, 28)
	p.add_child(nm)
	var sub := Kit.label(String(A.get("sub", "")) if open else "Locked", 11, UI.body, Kit.DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(0, 30)
	sub.size = Vector2(sz.x, 16)
	p.add_child(sub)
	# 3 x 3 cards, the boss's medallion in the middle one
	var ids: Array = A.pool.keys()
	ids.sort_custom(func(x, y): return int(Data.SP[x].r) < int(Data.SP[y].r) or (int(Data.SP[x].r) == int(Data.SP[y].r) and float(A.pool[x]) > float(A.pool[y])))
	var at := Stones.opens_at(a)
	var top := 54.0
	var foot := 30.0
	# the mine's beasts' skulls (Stones.BEAST_AREAS): a fourth row under the species, a counter between them
	var beasts: Array = Stones.BEAST_AREAS.get(a, [])
	var rows := 4 if beasts.size() else 3
	var cw := (sz.x - PAD * 2 - GAP * 2) / 3.0
	var ch := cw * CARD_K
	var room := sz.y - top - foot
	if ch * rows + GAP * (rows - 1) > room:
		ch = (room - GAP * (rows - 1)) / rows
		cw = ch / CARD_K
	var x0 := (sz.x - cw * 3 - GAP * 2) / 2.0
	var slots := [0, 1, 2, 3, 5, 6, 7, 8]
	var n := Atlas.found_in(a) if open else 0
	var done := open and n == ids.size()
	if done:
		p.add_child(_sealed_glow(Rect2(x0 - 6, top - 6, cw * 3 + GAP * 2 + 12, ch * 3 + GAP * 2 + 12)))
	for i in slots.size():
		var cell: int = slots[i]
		var pos := Vector2(x0 + (cw + GAP) * (cell % 3), top + (ch + GAP) * (cell / 3))
		if i >= ids.size():
			continue
		var c := _card(String(ids[i]), Vector2(cw, ch), open, a, int(at.get(ids[i], 0)))
		c.position = pos
		p.add_child(c)
	# the middle: the medallion with its rubies, n/m, Replay
	var mid := Vector2(x0 + cw + GAP, top + ch + GAP)
	var ms := minf(cw, ch) * 0.86
	if A.has("boss") or not open:
		var m := Medallion.new(a, open, self)
		m.size = Vector2(ms, ms)
		m.position = mid + Vector2((cw - ms) / 2.0, 2)
		p.add_child(m)
		_taps.append([m, func(): atlas._boss_card(a)])
	var cnt := Atlas._shadowed("%d/%d" % [n, ids.size()], 15, Kit.AMBER if done else Kit.CREAM)
	cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cnt.position = Vector2(mid.x, mid.y + ms + 2)
	cnt.size = Vector2(cw, 20)
	p.add_child(cnt)
	if open and a < Save.d.boss_won.size() and bool(Save.d.boss_won[a]):
		var rp := _pill("Replay")
		rp.position = Vector2(mid.x + (cw - rp.size.x) / 2.0, mid.y + ch - rp.size.y - 2)
		p.add_child(rp)
		_taps.append([rp, func(): atlas._boss_card(a)])
	if beasts.size():
		var y := top + (ch + GAP) * 3
		var nb := 0
		for k in beasts.size():
			var bid := "beast_" + String(beasts[k])
			if open and Save.d.atlas.has(bid): nb += 1
			var bc := _card(bid, Vector2(cw, ch), open, a, Stones.beast_from(a))
			bc.position = Vector2(x0 + (cw + GAP) * (0 if k == 0 else 2), y)
			p.add_child(bc)
		var bl := Atlas._shadowed("Bones
%d/%d" % [nb, beasts.size()], 14, Kit.AMBER if nb == beasts.size() else Kit.CREAM)
		bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		bl.position = Vector2(x0 + cw + GAP, y)
		bl.size = Vector2(cw, ch)
		p.add_child(bl)
	var ft := Kit.label(("%s sealed: every kind found" if done else "Find every kind of %s to seal it") % String(A.n), 11, UI.body, Kit.AMBER if done else Kit.DIM)
	ft.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ft.position = Vector2(0, top + ch * rows + GAP * (rows - 1) + 8)
	ft.size = Vector2(sz.x, 18)
	p.add_child(ft)
	return p

## a whole mine found: a warm light round the spread
func _sealed_glow(r: Rect2) -> Control:
	var g := Control.new()
	g.position = r.position
	g.size = r.size
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.draw.connect(func():
		for k in 6:
			var st := StyleBoxFlat.new()
			st.bg_color = Color(0, 0, 0, 0)
			st.border_color = Color(Kit.AMBER, 0.14 - k * 0.02)
			st.set_border_width_all(2)
			st.set_corner_radius_all(14 + k * 2)
			st.anti_aliasing = true
			g.draw_style_box(st, Rect2(Vector2(-k * 2, -k * 2), g.size + Vector2(k * 4, k * 4))))
	return g

## a species as a collectible card: found - a small copy of the specimen card (its best stone on a ground of its
## colour, name and rarity rule top-left, a rim of rarity and brass; rare ones glow); not found - the card's back
## (assets/atlas/album/back.png) with the mine's medallion and where it turns up. A card found since the album was
## last opened lies face down and turns over when its page comes into view (AlbumCard.flip, Save.d.atlas_seen).
func _card(id: String, sz: Vector2, open: bool, a: int, dl: int) -> Control:
	var e: Dictionary = Save.d.atlas.get(id, {})
	var got := open and e.has("best")
	var c := AlbumCard.new()
	c.setup(id, sz, open, a, dl, got, got and not Atlas.best_kept(id))
	if got:
		Atlas.cutout(Spec.of_stone(e.best), func(t: Texture2D): if is_instance_valid(c): c.set_stone(t))
		var seen: Array = Save.d.get("atlas_seen", [])
		if not seen.has(id):
			c.face = false
			_to_flip[a] = _to_flip.get(a, []) + [c]
	_taps.append([c, func():
		if got:
			Sfx.play("open")
			atlas._open_species(id)
		elif open:
			Ov.toast("Not found yet · turns up from %d m" % Data.depth_m(a, dl))
		else:
			Ov.toast("%s is locked" % Data.AREAS[a].n)])
	return c

## the cards found since last time on page a turn over, one after another
func _flip_page(a: int) -> void:
	var cs: Array = _to_flip.get(a, [])
	if cs.is_empty(): return
	_to_flip.erase(a)
	var seen: Array = Save.d.get("atlas_seen", [])
	var k := 0
	for c: AlbumCard in cs:
		if not is_instance_valid(c): continue
		get_tree().create_timer(0.35 + k * 0.28).timeout.connect(func(): if is_instance_valid(c): c.flip())
		seen.append(c.id)
		k += 1
	Save.d["atlas_seen"] = seen
	Save.persist()

func _pill(t: String) -> Control:
	var c := Control.new()
	c.size = Vector2(68, 22)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func():
		var st := StyleBoxFlat.new()
		st.bg_color = Color(0.06, 0.05, 0.04, 0.9)
		st.border_color = Color(Kit.AMBER, 0.75)
		st.set_border_width_all(1)
		st.set_corner_radius_all(11)
		st.anti_aliasing = true
		c.draw_style_box(st, Rect2(Vector2.ZERO, c.size))
		var f: Font = UI.body_bold
		var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		c.draw_string(f, Vector2((c.size.x - w) / 2.0, 15), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Kit.CREAM))
	return c

# ---------------------------------------------------------------- input: swipe pages, hit-test taps

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_down = true
			_moved = false
			_press = e.position
			_x0 = _track.position.x
			_vx = 0.0
			_last = _t
			if _slide: _slide.kill()
		elif _down:
			_down = false
			if not _moved:
				_tap(e.global_position)
				return
			var dx := _track.position.x - (-size.x * page)
			var to := page
			if dx < -size.x * 0.18 or _vx < -500.0: to = page + 1
			elif dx > size.x * 0.18 or _vx > 500.0: to = page - 1
			go_to(to)
	elif e is InputEventMouseMotion and _down:
		var dx: float = e.position.x - _press.x
		if not _moved and absf(dx) > 8.0: _moved = true
		if _moved:
			var x := _x0 + dx
			# a little give past the first and last page
			var lo := -size.x * (Data.AREAS.size() - 1)
			if x > 0.0: x *= 0.35
			elif x < lo: x = lo + (x - lo) * 0.35
			_track.position.x = x
			var dt := maxf(_t - _last, 1.0 / 120.0)
			_vx = lerpf(_vx, e.relative.x / dt, 0.4)
			_last = _t

func _tap(gp: Vector2) -> void:
	for t in _taps:
		var c: Control = t[0]
		if is_instance_valid(c) and c.is_visible_in_tree() and c.get_global_rect().has_point(gp):
			(t[1] as Callable).call()
			return

## the boss's medallion with its three ruby sockets (AtlasBoard: sprites, a ruby per beaten difficulty), the rubies
## catching light as the page moves (ruby_glint.gdshader, phase from the page's swipe and time)
class Medallion extends Control:
	var a: int
	var open: bool
	var pages: AtlasPages
	var glints: Array[TextureRect] = []
	func _init(area: int, o: bool, p: AtlasPages) -> void:
		a = area
		open = o
		pages = p
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _ready() -> void:
		var n := AtlasBoard.rubies(a) if open else 0
		var sg := size.x / 2.0
		var h := sg * AtlasBoard.RUBY_S
		var sh: Shader = load("res://shaders/ruby_glint.gdshader")
		for i in 3:
			if i >= n: continue
			var an := -PI / 2.0 + TAU * i / 3.0
			var c := Vector2(sg, sg) + Vector2(cos(an), sin(an)) * sg * AtlasBoard.RUBY_R
			var g := TextureRect.new()
			g.texture = AtlasBoard._pic("res://assets/atlas/board/ruby_%d.png" % AtlasBoard.RUBY_CUT, 96)
			g.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			g.position = c - Vector2(h, h)
			g.size = Vector2(h, h) * 2.0
			g.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var m := ShaderMaterial.new()
			m.shader = sh
			g.material = m
			g.self_modulate = Color(float(i) * 0.31 + a * 0.17, 1, 1, 1)
			add_child(g)
			glints.append(g)
	func _process(_dt: float) -> void:
		var ph := (pages._track.position.x if pages._track else 0.0) * 0.003 + pages._t * 0.045
		for g in glints:
			(g.material as ShaderMaterial).set_shader_parameter("phase", ph)
	func _draw() -> void:
		var sg := size.x / 2.0
		draw_texture_rect(AtlasBoard._emblem(Atlas._sign(a, open)), Rect2(Vector2.ZERO, size), false, Color(1, 1, 1, 1.0 if open else 0.7))
		if not Data.AREAS[a].has("boss"): return
		var n := AtlasBoard.rubies(a) if open else 0
		var h := sg * AtlasBoard.RUBY_S
		for i in 3:
			var an := -PI / 2.0 + TAU * i / 3.0
			var c := Vector2(sg, sg) + Vector2(cos(an), sin(an)) * sg * AtlasBoard.RUBY_R
			var tex := "res://assets/atlas/board/ruby_%d.png" % AtlasBoard.RUBY_CUT if i < n else "res://assets/atlas/board/socket.png"
			draw_texture_rect(AtlasBoard._pic(tex, 96), Rect2(c - Vector2(h, h), Vector2(h, h) * 2.0), false, Color(1, 1, 1, 1.0 if open else 0.6))
