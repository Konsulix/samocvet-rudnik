class_name CardBolt
extends Control
## A legendary effect that does not stay inside its stone's frame: the lightning in a find (SpecBolt: frozen lightning,
## living lightning, thunder horns) now and then leaps out of the stone into the card's brass rim, runs down it as a
## crawling spark, jumps to a button of the card and from it to the price — whose figures flicker a moment and settle.
## Nothing is changed by it: the price is the same when it settles, the button does what it did.
## Drawn here as the stone's own lightning is (SpecBolt), flat: ribbons with its filament texture and its shader's
## look (shaders/card_bolt.gdshader) — plain jagged lines read as drawn in a paint program beside it (22.11);
## over the whole card; the card's own nodes are only tinted and, the price, scrambled for half a second.

const RIM_IN := 3.5          # the rim's middle from the card's edge
const FIRST := 3.2           # the first leap after the stone is built, then every EVERY
const EVERY := Vector2(8.0, 14.0)
const T_STRIKE := 0.2        # the bolt from the stone to the rim
const CRAWL_V := 430.0       # the charge along the rim, points a second
const CORNER := 14.0         # the card's rounded corners
const UP_LEN := 300.0        # how far the charge runs the other way round the rim before it dies
const T_LEAP := 0.16         # rim to button, button to price
const T_FLICK := 0.6         # the price's figures

static var test_at := -1.0   # a test key (-- card_bolt=S): the first leap S s after the stone is built, then every 3 s

var card: Control
var view: SpecView
var box: Control             # the card's content: its buttons are looked for in it
var price: Label
var bolt: SpecBolt
var rng := RandomNumberGenerator.new()
var _wait := FIRST
var _t := -1.0               # the leap now playing: seconds into it (< 0: none)
var _a := Vector2.ZERO       # where it leaves the stone
var _h := Vector2.ZERO       # where it hits the rim
var _rim := PackedVector2Array()   # down the rim from there
var _rim_len := 0.0
## the brass taking the charge (22.11: one stretch of lightning sliding down the rim read as "a crawling blue sausage",
## and the frame caught no light of it): the rim itself lights up blue from where it was struck, the light running both
## ways round the frame and dying slowly behind its front; over the lit brass short arcs leap from point to point of the
## rim, as the crackle over the stone's own surface does. _down/_up: the rim from the hit, a point every few points
var _down := PackedVector2Array()
var _up := PackedVector2Array()
## the other side of the frame takes as much (22.11: all of it went to the side the bolt struck, the other got one
## bolt): a second strike SIDE2 s after the first, its own lit brass, its own arcs, its own leap to the button nearest it
const SIDE2 := 0.09
var _a2 := Vector2.ZERO
var _h2 := Vector2.ZERO
var _rim2 := PackedVector2Array()
var _down2 := PackedVector2Array()
var _up2 := PackedVector2Array()
var _shine: Control          # the light on the brass: plain added light under the arcs
## more of it (22.11, "more lightning, and something fun"): bolts and hot points with clocks of their own, beside the
## main leap — second strikes from the stone to the other side of the frame and to its top, restrikes down the first
## channel, the charge hopping from the button it reached to the card's other buttons and from the price to the first
## gene badge, the rivets in the frame's corners flashing, the stone's name flickering. And the card stays charged a
## little after: a finger put on it then gets a spark from the nearest rim (a static shock: a crackle, a buzz)
var _arcs := []              # {a, b, t0, dur, w, salt, forks, fired}
var _glints := []            # {p, t0, dur, r}
var _clock := 0.0
var _live_until := 0.0       # the card is charged till then
var _was_busy := false
var _btn: Control
var _price_text := ""
var _price_col := Color.WHITE
var _sparks := []            # {p, v, t, life}
var _jag := 0.0
var _seed := 0

## the stone has lightning in it: the card gets its leaps
static func attach(card_: Control, view_: SpecView, box_: Control, price_: Label, p: Node3D) -> void:
	var found := p.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n is SpecBolt)
	if found.is_empty(): return
	var cb := CardBolt.new()
	cb.card = card_
	cb.view = view_
	cb.box = box_
	cb.price = price_
	cb.bolt = found[0]
	card_.add_child(cb)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# the same discharge as inside the stone (SpecBolt), flat: shaders/card_bolt.gdshader, in the stone's own colour
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/card_bolt.gdshader")
	m.set_shader_parameter("strands", SpecBolt.STRANDS)
	m.set_shader_parameter("glow_col", Vector3(bolt.col.r, bolt.col.g, bolt.col.b))
	material = m
	_shine = Control.new()
	_shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shine.material = FxLayer.add_material()
	_shine.show_behind_parent = true
	_shine.draw.connect(_draw_shine)
	add_child(_shine)
	z_index = 5
	rng.randomize()
	if test_at >= 0.0: _wait = test_at

func _process(dt: float) -> void:
	if not is_instance_valid(view) or not is_instance_valid(bolt):
		queue_free()
		return
	_clock += dt
	for i in range(_arcs.size() - 1, -1, -1):
		var ar: Dictionary = _arcs[i]
		if not ar.fired and _clock >= float(ar.t0):
			ar.fired = true
			_burst(ar.b, 5, 120.0)
		if _clock > float(ar.t0) + float(ar.dur): _arcs.remove_at(i)
	for i in range(_glints.size() - 1, -1, -1):
		if _clock > float(_glints[i].t0) + float(_glints[i].dur): _glints.remove_at(i)
	for i in range(_sparks.size() - 1, -1, -1):
		var s: Dictionary = _sparks[i]
		s.t += dt
		s.v += Vector2(0, 380.0) * dt
		s.p += s.v * dt
		if s.t >= s.life: _sparks.remove_at(i)
	if _t < 0.0:
		_wait -= dt
		if _wait <= 0.0 and view.is_visible_in_tree() and card.scale.is_equal_approx(Vector2.ONE):
			_start()
		var busy := _sparks.size() + _arcs.size() + _glints.size() > 0
		if busy or _was_busy: _redraw()
		_was_busy = busy
		return
	_t += dt
	_jag += dt
	if _jag > 0.045:
		_jag = 0.0
		_seed = rng.randi()
	_price_tick()
	# the front of the charge sheds sparks as it runs
	if int(_stage()[0]) == 1 and rng.randf() < 0.5:
		_burst(_rim[0].lerp(_rim[1], float(_stage()[1])), 1, 110.0)
	var f2 := _front2()
	if f2 > 0.0 and f2 < _rim2[1].y - _rim2[0].y and rng.randf() < 0.5:
		_burst(_rim2[0] + Vector2(0, f2), 1, 110.0)
	if _t > _end():
		_settle()
		_t = -1.0
		_live_until = _clock + 1.6
		_wait = 3.0 if test_at >= 0.0 else rng.randf_range(EVERY.x, EVERY.y)
	_redraw()

func _redraw() -> void:
	queue_redraw()
	_shine.queue_redraw()

## a point of the card, by a point on the screen, in this node's own space
func _in(p: Vector2) -> Vector2:
	return get_global_transform().affine_inverse() * p

func _mid(c: Control) -> Vector2:
	return _in(c.get_global_rect().get_center())

func _crawl_t() -> float:
	return _rim_len / CRAWL_V

func _end() -> float:
	return T_STRIKE * 0.6 + _crawl_t() + T_LEAP * 2.0 + T_FLICK

## a point of the lightning's own stone on the card (as the callouts find theirs: the studio's camera, the view's size)
func _stone_pt() -> Vector2:
	var cam := view.studio.cam
	var k := view.size / Vector2(maxi(1, view.studio.vp.size.x), maxi(1, view.studio.vp.size.y))
	var w := bolt.global_transform * bolt.bounds.get_center()
	if bolt.surface.size():
		w = bolt.global_transform * bolt.surface[rng.randi() % bolt.surface.size()]
	return _in(view.get_global_transform() * (cam.unproject_position(w) * k))

## a bolt of its own, `delay` s from now
func _arc(a: Vector2, b: Vector2, delay: float, dur := 0.18, w := 6.0, forks := 0.3) -> void:
	_arcs.append({a = a, b = b, t0 = _clock + delay, dur = dur, w = w, salt = 20 + rng.randi() % 900, forks = forks, fired = false})

func _glint(p: Vector2, delay: float, r := 16.0, dur := 0.4) -> void:
	_glints.append({p = p, t0 = _clock + delay, dur = dur, r = r})

## a node's cold blink, `delay` s from now (its own colour back after it)
func _blink(c: CanvasItem, delay: float, dur := 0.35) -> void:
	var tw := c.create_tween()
	tw.tween_interval(maxf(0.001, delay))
	tw.tween_callback(func() -> void: c.modulate = Color(0.75, 0.95, 1.5, c.modulate.a))
	tw.tween_property(c, "modulate", Color(1, 1, 1, c.modulate.a), dur)

func _start() -> void:
	_a = _stone_pt()
	var r := Rect2(_in(card.global_position), card.size)
	# to the nearer side of the rim, a little above the point it left
	var right := _a.x > r.get_center().x
	var x := r.end.x - RIM_IN if right else r.position.x + RIM_IN
	_h = Vector2(x, clampf(_a.y - rng.randf_range(10.0, 50.0), r.position.y + 40.0, r.end.y - 120.0))
	# down the rim to the buttons' height (or the price's, on a card with none)
	_btn = null
	var best := INF
	for b: Button in box.find_children("*", "Button", true, false):
		if not b.is_visible_in_tree() or b.disabled: continue
		var d := absf(_mid(b).x - x)
		if d < best:
			best = d
			_btn = b
	var to_y := _mid(_btn).y if _btn else _mid(price).y
	var top := r.position.y + RIM_IN
	_rim = PackedVector2Array([_h, Vector2(x, maxf(_h.y + 10.0, to_y))])
	_rim_len = _rim[1].y - _rim[0].y
	_down = _resample(_rim)
	_up = _way_up(_h, right, r)
	_price_text = price.text
	_price_col = price.get_theme_color("font_color")
	_t = 0.0
	if test_at >= 0.0: print("CARDBOLT leap from ", _a, " to rim ", _h, " button ", _btn)
	# more of it: a second strike to the other side of the frame, often a third to its top, restrikes down the first
	# channel; the rivets in the corners flash; the stone's name flickers
	var x2 := r.position.x + RIM_IN if right else r.end.x - RIM_IN
	_a2 = _stone_pt()
	_h2 = Vector2(x2, clampf(_a2.y + rng.randf_range(-40.0, 40.0), r.position.y + 40.0, r.end.y - 120.0))
	_rim2 = PackedVector2Array([_h2, Vector2(x2, maxf(_h2.y + 10.0, to_y))])
	_down2 = _resample(_rim2)
	_up2 = _way_up(_h2, not right, r)
	_arc(_a2, _h2, SIDE2, 0.2, 9.0)
	_arc(_a2, _h2 + Vector2(0, rng.randf_range(-14.0, 14.0)), SIDE2 + 0.27, 0.12, 5.0)
	_glint(_h2, SIDE2, 34.0)
	# its charge leaps to the button nearest it when it gets down there
	var btn2: Button = null
	var best2 := INF
	for b: Button in box.find_children("*", "Button", true, false):
		if not b.is_visible_in_tree() or b.disabled: continue
		if absf(_mid(b).x - x2) < best2:
			best2 = absf(_mid(b).x - x2)
			btn2 = b
	if btn2:
		var at2 := SIDE2 + T_STRIKE * 0.6 + (_rim2[1].y - _rim2[0].y) / CRAWL_V
		var br2 := Rect2(_in(btn2.global_position), btn2.size)
		_arc(_rim2[1], Vector2(clampf(x2, br2.position.x + 10.0, br2.end.x - 10.0) + (30.0 if not right else -30.0), br2.get_center().y), at2, 0.2, 6.5, 0.4)
		_blink(btn2, at2 + 0.04)
	if rng.randf() < 0.6:
		var a3 := _stone_pt()
		var h3 := Vector2(clampf(a3.x + rng.randf_range(-70.0, 70.0), r.position.x + 30.0, r.end.x - 30.0), top)
		_arc(a3, h3, 0.18, 0.2, 7.0)
		_glint(h3, 0.18, 28.0)
	_arc(_a, _h + Vector2(0, rng.randf_range(-14.0, 14.0)), 0.27, 0.12, 5.0)
	_arc(_a, _h + Vector2(0, rng.randf_range(-14.0, 14.0)), 0.44, 0.1, 4.0)
	for c in 4:
		var cp := Vector2(r.position.x + 9.0 if c % 2 == 0 else r.end.x - 9.0, r.position.y + 9.0 if c < 2 else r.end.y - 9.0)
		_glint(cp, 0.02 + c * 0.03, 15.0, 0.45)
	if is_instance_valid(Reveal._name_l) and card.is_ancestor_of(Reveal._name_l):
		_blink(Reveal._name_l, 0.0, 0.12)
		_blink(Reveal._name_l, 0.2, 0.3)
	# the stone's own bolt strikes with it, so the flash inside and the leap are one
	bolt._strike()
	Sfx.play("card_arc")
	Sfx.buzz(18)
	_burst(_h, 9, 150.0)

func _burst(p: Vector2, n: int, sp: float) -> void:
	for i in n:
		var a := rng.randf() * TAU
		_sparks.append({p = p, v = Vector2(cos(a), sin(a) - 0.4) * sp * rng.randf_range(0.35, 1.0), t = 0.0, life = rng.randf_range(0.25, 0.55)})

## where the leap is on its way: 0 the strike, 1 the crawl, 2 rim to button, 3 button to price, 4 the price flickers
func _stage() -> Array:
	var t := _t
	if t < T_STRIKE * 0.6: return [0, t / T_STRIKE]
	t -= T_STRIKE * 0.6
	if t < _crawl_t(): return [1, t / maxf(0.001, _crawl_t())]
	t -= _crawl_t()
	if t < T_LEAP: return [2, t / T_LEAP]
	t -= T_LEAP
	if t < T_LEAP: return [3, t / T_LEAP]
	return [4, (t - T_LEAP) / T_FLICK]

var _stage_was := -1
func _price_tick() -> void:
	var st := _stage()
	var s := int(st[0])
	if s != _stage_was:
		_stage_was = s
		if s == 2:
			_burst(_rim[1], 6, 120.0)
		if s == 3 and is_instance_valid(_btn):
			# the button takes the charge: a blink of cold light
			var tw := _btn.create_tween()
			_btn.modulate = Color(0.75, 0.95, 1.5)
			tw.tween_property(_btn, "modulate", Color.WHITE, 0.35)
			_burst(_mid(_btn), 5, 90.0)
			Sfx.buzz(12)
			# and on to the card's other buttons
			var hop := 0.07
			for b2: Button in box.find_children("*", "Button", true, false):
				if b2 == _btn or not b2.is_visible_in_tree(): continue
				_arc(_mid(_btn), _mid(b2), hop, 0.2, 5.5, 0.4)
				_blink(b2, hop + 0.03)
				hop += 0.06
		if s == 4:
			_burst(_mid(price), 7, 100.0)
			Sfx.buzz(12)
			# from the price on to the first gene badge (the lightning's own: the dearest comes first)
			for fl in box.find_children("*", "HFlowContainer", true, false):
				for ch in fl.get_children():
					if ch is Label and (ch as Label).is_visible_in_tree():
						_arc(_mid(price), _mid(ch), 0.1, 0.2, 5.0, 0.4)
						_blink(ch as Label, 0.13)
						break
				break
	if s == 4 and is_instance_valid(price):
		# the figures jump (the commas, dots and letters stay), cold and bright, slower as it dies down
		var k := float(st[1])
		if _jag == 0.0 and rng.randf() > k * k:
			var out := ""
			for ch in _price_text:
				out += String.num_int64(rng.randi() % 10) if ch.is_valid_int() else ch
			price.text = out
			price.add_theme_color_override("font_color", _price_col.lerp(Color(0.8, 0.95, 1.0), rng.randf_range(0.5, 1.0)))
		elif _jag == 0.0:
			price.text = _price_text
			price.add_theme_color_override("font_color", _price_col)

func _settle() -> void:
	_stage_was = -1
	if is_instance_valid(price):
		# (the weight may have been settled meanwhile: only our own scramble is put back)
		price.text = _price_text
		price.add_theme_color_override("font_color", _price_col)

func _exit_tree() -> void:
	if _t >= 0.0: _settle()

## midpoint displacement, as SpecBolt._bolt grows its channels: split the line, push the middle aside, recurse; fork
## now and then. segs entries: [p0, p1, half-width, brightness, branch id, core]
func _grow(r: RandomNumberGenerator, p0: Vector2, p1: Vector2, disp: float, depth: int, segs: Array, bright: float, w: float, br: float, forks := 0.35) -> void:
	if depth == 2:
		segs.append([p0, p1, w * 2.6, bright * 0.7, br, 0.0])
	if depth == 0:
		segs.append([p0, p1, w, bright, br, 1.0])
		return
	var d := p1 - p0
	var perp := d.orthogonal().normalized()
	var m := (p0 + p1) * 0.5 + perp * r.randf_range(-disp, disp)
	_grow(r, p0, m, disp * 0.5, depth - 1, segs, bright, w, br, forks)
	_grow(r, m, p1, disp * 0.5, depth - 1, segs, bright, w, br, forks)
	if depth >= 2 and r.randf() < forks and bright > 0.2:
		var bd := (d.normalized() + perp * r.randf_range(0.6, 1.4) * (1.0 if r.randf() < 0.5 else -1.0)).normalized()
		_grow(r, m, m + bd * d.length() * r.randf_range(0.35, 0.7), disp * 0.5, depth - 1, segs, bright * 0.55, w * 0.6, r.randf(), forks)

## the channels as one mesh of ribbons: a quad to a segment, its UV across and along, as the shader reads them
func _ribbons(segs: Array, a: float) -> void:
	if segs.is_empty() or a <= 0.01: return
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	# (halos first: the cores lie over them)
	for pass_core: float in [0.0, 1.0]:
		var along := 0.0
		for sg: Array in segs:
			if float(sg[5]) != pass_core: continue
			var p0: Vector2 = sg[0]
			var p1: Vector2 = sg[1]
			var w: float = sg[2]
			var d := p1 - p0
			var l := d.length()
			if l < 0.01: continue
			var side := d.orthogonal() / l * w
			var e := d / l * w * 0.25      # (a little over each end: no gaps at the joints)
			var c := Color(float(sg[5]), float(sg[4]), 0.0, float(sg[3]) * a)
			var i0 := pts.size()
			pts.append_array(PackedVector2Array([p0 - e - side, p0 - e + side, p1 + e + side, p1 + e - side]))
			uvs.append_array(PackedVector2Array([Vector2(-1, along), Vector2(1, along), Vector2(1, along + l / 46.0), Vector2(-1, along + l / 46.0)]))
			cols.append_array(PackedColorArray([c, c, c, c]))
			idx.append_array(PackedInt32Array([i0, i0 + 1, i0 + 2, i0, i0 + 2, i0 + 3]))
			along += l / 46.0
	if idx.size():
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), idx, pts, cols, uvs)

func _rng_of(salt: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = _seed + salt * 7919
	return r

func _draw() -> void:
	var segs := []
	# sparks: short bright streaks, slivers of the same ribbon
	for sp: Dictionary in _sparks:
		var su := 1.0 - float(sp.t) / float(sp.life)
		segs.append([sp.p, (sp.p as Vector2) - (sp.v as Vector2) * 0.03, 1.6, su * 0.8, 0.3, 1.0])
	_ribbons(segs, 1.0)
	for ar: Dictionary in _arcs:
		var age := _clock - float(ar.t0)
		if age < 0.0: continue
		var au := age / float(ar.dur)
		var aa := 1.0 if au < 0.3 else 0.3 if au < 0.45 else 0.95 * (1.0 - smoothstep(0.55, 1.0, au))
		var pa: Vector2 = ar.a
		var pb: Vector2 = ar.b
		var dist := pa.distance_to(pb)
		var rr := _rng_of(int(ar.salt))
		segs = []
		_grow(rr, pa, pb, dist * 0.2, 5 if dist > 120.0 else 4 if dist > 50.0 else 3, segs, 1.0, float(ar.w), rr.randf(), float(ar.forks))
		_ribbons(segs, aa)
	if _t < 0.0: return
	var st := _stage()
	var s := int(st[0])
	var k := float(st[1])
	if _t < T_STRIKE:
		# the bolt out of the stone: bright, a flicker, an afterglow — forking as it goes
		var u := _t / T_STRIKE
		var a := 1.0 if u < 0.3 else 0.3 if u < 0.45 else 0.95 * (1.0 - smoothstep(0.55, 1.0, u))
		segs = []
		_grow(_rng_of(1), _a, _h, _a.distance_to(_h) * 0.2, 5, segs, 1.0, 9.0, 0.11)
		_ribbons(segs, a)
	if s == 1:
		_rim_arcs(_rim, _up, k * _rim_len, 3)
	var f2 := _front2()
	if f2 > 0.0 and f2 < _rim2[1].y - _rim2[0].y:
		_rim_arcs(_rim2, _up2, f2, 5)
	if s == 2 and is_instance_valid(_btn):
		var a2 := 1.0 - smoothstep(0.55, 1.0, k)
		var br := Rect2(_in(_btn.global_position), _btn.size)
		var to2 := Vector2(clampf(_rim[1].x, br.position.x + 10.0, br.end.x - 10.0), br.get_center().y)
		if to2.distance_to(_rim[1]) < 24.0: to2.x += -signf(_rim[1].x - size.x * 0.5) * 30.0
		segs = []
		_grow(_rng_of(6), _rim[1], to2, 7.0, 4, segs, 1.0, 6.5, 0.53)
		# the charge spreading over the button's face
		var r6 := _rng_of(9)
		for i in 3:
			var e := Vector2(r6.randf_range(br.position.x + 8.0, br.end.x - 8.0), r6.randf_range(br.position.y + 6.0, br.end.y - 6.0))
			_grow(r6, to2, e, to2.distance_to(e) * 0.2, 3, segs, 0.55, 4.0, r6.randf(), 0.3)
		_ribbons(segs, a2)
	if s == 3:
		var a3 := 1.0 - smoothstep(0.55, 1.0, k)
		var from := _mid(_btn) if is_instance_valid(_btn) else _rim[1]
		if is_instance_valid(_btn): from.y = _in(_btn.global_position).y + 4.0
		segs = []
		_grow(_rng_of(7), from, _mid(price), from.distance_to(_mid(price)) * 0.18, 5, segs, 1.0, 7.0, 0.71)
		_ribbons(segs, a3)
	if s == 4 and is_instance_valid(price):
		# the price crackles: little arcs over its figures, fewer as it dies down
		var pr := Rect2(_in(price.global_position), price.size)
		var mid := pr.get_center()
		var hw := maxf(14.0, price.get_minimum_size().x * 0.5 + 4.0)
		var r2 := _rng_of(8)
		segs = []
		for i in 4:
			if r2.randf() < k: continue
			var p0 := mid + Vector2(r2.randf_range(-hw, hw), r2.randf_range(-10.0, 10.0))
			var p1 := mid + Vector2(r2.randf_range(-hw, hw), r2.randf_range(-10.0, 10.0))
			_grow(r2, p0, p1, p0.distance_to(p1) * 0.3, 3, segs, 0.8, 4.0, r2.randf(), 0.3)
		_ribbons(segs, 1.0 - k * 0.6)

## a line with a point every 6 points along it (and no further than `limit`)
func _resample(line: PackedVector2Array, limit := INF) -> PackedVector2Array:
	var out := PackedVector2Array([line[0]])
	var run := 0.0
	for i in range(1, line.size()):
		var a := line[i - 1]
		var b := line[i]
		var l := a.distance_to(b)
		var n := maxi(1, int(ceil(l / 6.0)))
		for kk in range(1, n + 1):
			run += l / n
			if run > limit: return out
			out.append(a.lerp(b, kk / float(n)))
	return out

## how far the charge has run along the rim, and how much of its light is left
func _charge() -> Vector2:
	if _t < 0.0: return Vector2.ZERO
	var since := _t - T_STRIKE * 0.3
	if since < 0.0: return Vector2.ZERO
	var after := _t - (T_STRIKE * 0.6 + _crawl_t())
	return Vector2(since * CRAWL_V, 1.0 - smoothstep(0.0, T_LEAP * 2.0 + T_FLICK, after))

## the light on the brass: brightest at the front of the charge, a long dying tail behind it, both ways from the hit
func _draw_shine() -> void:
	# hot points on the brass: where a bolt struck, the rivets in the corners
	var pt0 := FxLayer.puff()
	for g: Dictionary in _glints:
		var ga := _clock - float(g.t0)
		if ga < 0.0: continue
		var gu := 1.0 - ga / float(g.dur)
		var gr: float = g.r
		var gp: Vector2 = g.p
		_shine.draw_texture_rect(pt0, Rect2(gp - Vector2(gr, gr), Vector2(gr, gr) * 2.0), false, Color(0.45, 0.72, 1.0, 0.8 * gu * gu))
		_shine.draw_texture_rect(pt0, Rect2(gp - Vector2(gr, gr) * 0.35, Vector2(gr, gr) * 0.7), false, Color(1, 1, 1, gu))
	var ch := _charge()
	if ch.y <= 0.01: return
	var jit := 0.82 + 0.18 * _rng_of(11).randf()
	for way in 4:
		var line: PackedVector2Array = [_down, _up, _down2, _up2][way]
		var run := ch.x if way < 2 else ch.x - SIDE2 * CRAWL_V
		if run <= 0.0 or line.size() < 2: continue
		var fade_len := INF if way % 2 == 0 else UP_LEN
		# (one line with a colour to each point: drawn piece by piece the pieces overlapped into a row of beads)
		var pts := PackedVector2Array()
		var bs := PackedFloat32Array()
		for i in line.size():
			var sd := i * 6.0
			if sd > run: break
			var b := (0.3 + 0.7 * exp(-(run - sd) / 60.0)) * ch.y * jit
			if way % 2 == 1: b *= 1.0 - smoothstep(0.35, 1.0, sd / fade_len)
			pts.append(line[i])
			bs.append(b)
		if pts.size() < 2: continue
		for lay: Array in [[15.0, Color(0.2, 0.45, 1.0), 0.2], [7.0, Color(0.35, 0.62, 1.0), 0.4], [1.6, Color(0.8, 0.92, 1.0), 0.7]]:
			var cols := PackedColorArray()
			for b in bs: cols.append(Color(lay[1] as Color, float(lay[2]) * b))
			_shine.draw_polyline_colors(pts, cols, float(lay[0]), true)
	# the whole frame catches the flash of the strike: its brass outlined in cold light for a blink
	var blink := (1.0 - smoothstep(0.0, 0.3, _t)) * ch.y
	if blink > 0.02:
		var cr := Rect2(_in(card.global_position) + Vector2(RIM_IN, RIM_IN), card.size - Vector2(RIM_IN, RIM_IN) * 2.0)
		var ring := PackedVector2Array()
		for c in 4:
			var cc: Vector2 = [cr.position + Vector2(CORNER, CORNER), Vector2(cr.end.x - CORNER, cr.position.y + CORNER), cr.end - Vector2(CORNER, CORNER), Vector2(cr.position.x + CORNER, cr.end.y - CORNER)][c]
			for q in 5:
				var an := PI + c * PI * 0.5 + q / 4.0 * PI * 0.5
				ring.append(cc + Vector2(cos(an), sin(an)) * CORNER)
		ring.append(ring[0])
		_shine.draw_polyline(ring, Color(0.25, 0.5, 1.0, 0.22 * blink), 12.0, true)
		_shine.draw_polyline(ring, Color(0.6, 0.8, 1.0, 0.4 * blink), 2.5, true)
	# where it was struck: the brass white-hot a moment, a cold light over the card from that side
	var hot := (1.0 - smoothstep(0.0, 0.45, _t)) * ch.y
	if hot > 0.02:
		var pt := FxLayer.puff()
		_shine.draw_texture_rect(pt, Rect2(_h - Vector2(34, 34), Vector2(68, 68)), false, Color(0.55, 0.78, 1.0, 0.75 * hot))
		_shine.draw_texture_rect(pt, Rect2(_h - Vector2(150, 150), Vector2(300, 300)), false, Color(0.3, 0.5, 1.0, 0.16 * hot))
	var hot2 := (1.0 - smoothstep(0.0, 0.45, _t - SIDE2)) * ch.y if _t >= SIDE2 else 0.0
	if hot2 > 0.02:
		var pt2 := FxLayer.puff()
		_shine.draw_texture_rect(pt2, Rect2(_h2 - Vector2(34, 34), Vector2(68, 68)), false, Color(0.55, 0.78, 1.0, 0.75 * hot2))
		_shine.draw_texture_rect(pt2, Rect2(_h2 - Vector2(150, 150), Vector2(300, 300)), false, Color(0.3, 0.5, 1.0, 0.16 * hot2))

## the card is charged while the lightning is out on it and a little after: a finger put on it gets a spark from the
## nearer side of the rim (the touch itself goes on to whatever it was for)
func _input(e: InputEvent) -> void:
	if not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT): return
	if _t < 0.0 and _clock > _live_until: return
	if not is_instance_valid(card) or not is_visible_in_tree(): return
	var r := Rect2(_in(card.global_position), card.size)
	var p := _in((e as InputEventMouseButton).global_position)
	if not r.has_point(p): return
	var x := r.position.x + RIM_IN if p.x < r.get_center().x else r.end.x - RIM_IN
	var from := Vector2(x, clampf(p.y + rng.randf_range(-50.0, 50.0), r.position.y + 20.0, r.end.y - 20.0))
	_arc(from, p, 0.0, 0.2, 7.0, 0.45)
	_arc(from + Vector2(0, rng.randf_range(-30.0, 30.0)), p, 0.07, 0.14, 4.5, 0.3)
	_glint(p, 0.0, 26.0, 0.35)
	_glint(from, 0.0, 20.0, 0.3)
	Sfx.play("card_arc")
	Sfx.buzz(28)

## how far the other side's charge has run down its rim (0: not struck yet)
func _front2() -> float:
	if _t < 0.0 or _rim2.size() < 2: return 0.0
	return maxf(0.0, (_t - SIDE2 - T_STRIKE * 0.6) * CRAWL_V)

## the rim from a hit, the other way: up, round the corner and along the top to the frame's middle
func _way_up(h: Vector2, right: bool, r: Rect2) -> PackedVector2Array:
	var top := r.position.y + RIM_IN
	var in_x := 1.0 if not right else -1.0
	var up := PackedVector2Array([h, Vector2(h.x, top + CORNER)])
	for i in 5:
		var a := (i + 1) / 5.0 * PI * 0.5
		up.append(Vector2(h.x + in_x * CORNER * (1.0 - cos(a)), top + CORNER * (1.0 - sin(a))))
	up.append(Vector2(r.get_center().x, top))
	return _resample(up, UP_LEN)

## over a side's lit brass: short arcs leaping from point to point of the rim near the front of the charge, bowed off
## it into the card (as SpecBolt's crackle over the stone); twigs reaching further in; a little star at the front
func _rim_arcs(rim: PackedVector2Array, up: PackedVector2Array, front: float, salt: int) -> void:
	var r := _rng_of(salt)
	# over the lit brass: short arcs leaping from point to point of the rim near the front of the charge, bowed
	# off it into the card (as SpecBolt's crackle over the stone); a twig or two reaching further in; and at the
	# front itself a little star of them
	var inward := -signf(rim[0].x - size.x * 0.5)
	var segs := []
	for i in 9:
		var s0 := maxf(0.0, front - r.randf_range(0.0, 190.0))
		var s1 := clampf(s0 + r.randf_range(16.0, 58.0) * (1.0 if r.randf() < 0.6 else -1.0), 0.0, front)
		if absf(s1 - s0) < 10.0: continue
		var p0 := Vector2(rim[0].x, rim[0].y + s0)
		var p1 := Vector2(rim[0].x, rim[0].y + s1)
		var mid := (p0 + p1) * 0.5 + Vector2(inward * absf(s1 - s0) * r.randf_range(0.25, 0.6), 0.0)
		var br := r.randf()
		_grow(r, p0, mid, p0.distance_to(mid) * 0.3, 3, segs, 0.85, 2.6, br, 0.25)
		_grow(r, mid, p1, p0.distance_to(mid) * 0.3, 3, segs, 0.85, 2.6, br, 0.25)
	var head := Vector2(rim[0].x, rim[0].y + front)
	for i in 3:
		var to := head + Vector2(inward * r.randf_range(10.0, 46.0), r.randf_range(-18.0, 30.0))
		_grow(r, head, to, head.distance_to(to) * 0.28, 3, segs, 0.9 if i == 0 else 0.6, 2.8, r.randf(), 0.45)
	# the same over the brass the charge ran up along
	for i in 5:
		if up.size() < 6: break
		var n := mini(up.size() - 1, int(front / 6.0))
		if n < 4: break
		var i0 := r.randi() % n
		var i1 := mini(n, i0 + 3 + r.randi() % 7)
		var q0 := up[i0]
		var q1 := up[i1]
		var bow := (q1 - q0).orthogonal().normalized()
		if bow.dot(size * 0.5 - q0) < 0.0: bow = -bow
		var qm := (q0 + q1) * 0.5 + bow * q0.distance_to(q1) * r.randf_range(0.25, 0.5)
		var br2 := r.randf()
		_grow(r, q0, qm, q0.distance_to(qm) * 0.3, 3, segs, 0.6, 2.4, br2, 0.2)
		_grow(r, qm, q1, q0.distance_to(qm) * 0.3, 3, segs, 0.6, 2.4, br2, 0.2)
	_ribbons(segs, 1.0)
