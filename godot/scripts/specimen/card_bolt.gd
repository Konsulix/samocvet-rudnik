class_name CardBolt
extends Control
## A legendary effect that does not stay inside its stone's frame: the lightning in a find (SpecBolt: frozen lightning,
## living lightning, thunder horns) now and then leaps out of the stone into the card's brass rim, runs down it as a
## crawling spark, jumps to a button of the card and from it to the price — whose figures flicker a moment and settle.
## Nothing is changed by it: the price is the same when it settles, the button does what it did.
## Drawn here as light (FxLayer.add_material: one of our own shaders, as every CanvasItem's must be on the iPhone),
## over the whole card; the card's own nodes are only tinted and, the price, scrambled for half a second.

const BLUE := Color(0.45, 0.72, 1.0)
const RIM_IN := 4.0          # the rim's middle from the card's edge
const FIRST := 3.2           # the first leap after the stone is built, then every EVERY
const EVERY := Vector2(8.0, 14.0)
const T_STRIKE := 0.2        # the bolt from the stone to the rim
const CRAWL_V := 560.0       # the spark down the rim, points a second
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
	material = FxLayer.add_material()
	z_index = 5
	rng.randomize()
	if test_at >= 0.0: _wait = test_at

func _process(dt: float) -> void:
	if not is_instance_valid(view) or not is_instance_valid(bolt):
		queue_free()
		return
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
		if _sparks.size(): queue_redraw()
		return
	_t += dt
	_jag += dt
	if _jag > 0.045:
		_jag = 0.0
		_seed = rng.randi()
	_price_tick()
	if _t > _end():
		_settle()
		_t = -1.0
		_wait = 3.0 if test_at >= 0.0 else rng.randf_range(EVERY.x, EVERY.y)
	queue_redraw()

## a point of the card, by a point on the screen, in this node's own space
func _in(p: Vector2) -> Vector2:
	return get_global_transform().affine_inverse() * p

func _mid(c: Control) -> Vector2:
	return _in(c.get_global_rect().get_center())

func _crawl_t() -> float:
	return _rim_len / CRAWL_V

func _end() -> float:
	return T_STRIKE * 0.6 + _crawl_t() + T_LEAP * 2.0 + T_FLICK

func _start() -> void:
	# from a point of the lightning's own stone (as the callouts find theirs: the studio's camera, the view's size)
	var cam := view.studio.cam
	var k := view.size / Vector2(maxi(1, view.studio.vp.size.x), maxi(1, view.studio.vp.size.y))
	var w := bolt.global_transform * bolt.bounds.get_center()
	if bolt.surface.size():
		w = bolt.global_transform * bolt.surface[rng.randi() % bolt.surface.size()]
	_a = _in(view.get_global_transform() * (cam.unproject_position(w) * k))
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
	_rim = PackedVector2Array([_h, Vector2(x, maxf(_h.y + 10.0, to_y))])
	_rim_len = _rim[1].y - _rim[0].y
	_price_text = price.text
	_price_col = price.get_theme_color("font_color")
	_t = 0.0
	if test_at >= 0.0: print("CARDBOLT leap from ", _a, " to rim ", _h, " button ", _btn)
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
		if s == 4:
			_burst(_mid(price), 7, 100.0)
			Sfx.buzz(12)
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

## a jagged line from a to b: midpoints pushed aside, the same every frame until the next jolt (_seed)
func _zig(a: Vector2, b: Vector2, amp: float, salt: int) -> PackedVector2Array:
	var r := RandomNumberGenerator.new()
	r.seed = _seed + salt * 7919
	var n := maxi(3, int(a.distance_to(b) / 9.0))
	var side := (b - a).orthogonal().normalized()
	var out := PackedVector2Array()
	for i in n + 1:
		var u := i / float(n)
		var p := a.lerp(b, u)
		if i > 0 and i < n: p += side * r.randf_range(-amp, amp) * sin(u * PI) + (b - a).normalized() * r.randf_range(-2.0, 2.0)
		out.append(p)
	return out

func _stroke(pts: PackedVector2Array, a: float, w: float) -> void:
	if pts.size() < 2 or a <= 0.01: return
	draw_polyline(pts, Color(BLUE, 0.16 * a), w * 5.0, true)
	draw_polyline(pts, Color(BLUE, 0.5 * a), w * 2.0, true)
	draw_polyline(pts, Color(1, 1, 1, 0.95 * a), w * 0.7, true)

func _glow(p: Vector2, r: float, a: float) -> void:
	draw_texture_rect(FxLayer.puff(), Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(BLUE.lerp(Color.WHITE, 0.4), a))

func _draw() -> void:
	for sp: Dictionary in _sparks:
		var su := 1.0 - float(sp.t) / float(sp.life)
		draw_line(sp.p, (sp.p as Vector2) - (sp.v as Vector2) * 0.02, Color(0.8, 0.92, 1.0, su), 1.4, true)
	if _t < 0.0: return
	var st := _stage()
	var s := int(st[0])
	var k := float(st[1])
	if _t < T_STRIKE:
		# the bolt out of the stone: bright, a flicker, gone; a fork or two off it
		var u := _t / T_STRIKE
		var a := 1.0 if u < 0.3 else 0.3 if u < 0.45 else 0.9 * (1.0 - smoothstep(0.55, 1.0, u))
		var main := _zig(_a, _h, 16.0, 1)
		_stroke(main, a, 2.2)
		var m := main[main.size() / 2]
		_stroke(_zig(m, m + (_h - _a).rotated(0.7).limit_length(46.0), 7.0, 2), a * 0.6, 1.2)
		_glow(_h, 26.0, a * 0.8)
		_glow(_a, 20.0, a * 0.5)
	if s == 1:
		# the spark crawling down the rim: a bright head, a short crackling tail hugging the brass, twigs off it
		var head := _rim[0].lerp(_rim[1], k)
		var tail := _rim[0].lerp(_rim[1], maxf(0.0, k - 70.0 / maxf(1.0, _rim_len)))
		_stroke(_zig(tail, head, 3.0, 3), 0.9, 1.5)
		_glow(head, 16.0, 0.9)
		var r := RandomNumberGenerator.new()
		r.seed = _seed
		var inward := -signf(_rim[0].x - size.x * 0.5)
		for i in 2:
			var q := tail.lerp(head, r.randf())
			_stroke(_zig(q, q + Vector2(inward * r.randf_range(8.0, 22.0), r.randf_range(-10.0, 10.0)), 3.0, 4 + i), 0.6, 1.0)
		# the brass it has passed still glows a moment
		draw_line(_rim[0], tail, Color(BLUE, 0.22), 3.0, true)
	if s == 2 and is_instance_valid(_btn):
		var a2 := 1.0 - smoothstep(0.5, 1.0, k)
		var br := Rect2(_in(_btn.global_position), _btn.size)
		var to := Vector2(clampf(_rim[1].x, br.position.x + 6.0, br.end.x - 6.0), br.get_center().y)
		_stroke(_zig(_rim[1], to, 6.0, 6), a2, 1.8)
		_glow(to, 18.0, a2 * 0.8)
	if s == 3:
		var a3 := 1.0 - smoothstep(0.5, 1.0, k)
		var from := _mid(_btn) if is_instance_valid(_btn) else _rim[1]
		if is_instance_valid(_btn): from.y = _in(_btn.global_position).y + 4.0
		_stroke(_zig(from, _mid(price), 9.0, 7), a3, 1.6)
		_glow(_mid(price), 20.0, a3 * 0.8)
	if s == 4 and is_instance_valid(price):
		# the price crackles: little arcs over its figures, fewer as it dies down
		var pr := Rect2(_in(price.global_position), price.size)
		var mid := pr.get_center()
		var hw := maxf(14.0, price.get_minimum_size().x * 0.5)
		var r2 := RandomNumberGenerator.new()
		r2.seed = _seed
		for i in 3:
			if r2.randf() < k: continue
			var p0 := mid + Vector2(r2.randf_range(-hw, hw), r2.randf_range(-9.0, 9.0))
			var p1 := mid + Vector2(r2.randf_range(-hw, hw), r2.randf_range(-9.0, 9.0))
			_stroke(_zig(p0, p1, 4.0, 8 + i), 0.7 * (1.0 - k), 1.0)
		_glow(mid, hw + 10.0, 0.25 * (1.0 - k))
