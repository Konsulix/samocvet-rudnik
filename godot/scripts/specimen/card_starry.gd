class_name CardStarry
extends Control
## (26.11) The starry sky (the legend «starry») and its card — the two things a legendary card does (out past the
## stone's frame; the interface played with):
##  - the info panel's slate is a night sky under its words (card_starry.gdshader): stars twinkling, the Milky Way;
##  - the stone's traits are a constellation: a star by every badge, thin lines joining them one to the next, drawn in
##    one after another when the card opens — each stone its own figure, by what it has;
##  - a shooting star, now and then: it runs along the card's brass rim, a long tail behind it, and is gone;
##  - a touch on the panel's sky lights a star there; the next touch joins it to the last — a constellation of the
##    player's own, which fades after a while.

const EVERY := [5.0, 11.0]    # a shooting star so often
const KEEP := 9.0             # the player's own stars stay this long, then fade
const MAX_OWN := 8

static var test_every := 0.0  # a test key (-- star_every=S): a shooting star every S s
static var test_tap := 0.0    # a test key (-- star_tap=S): at S s three touches on the panel

var card: Control
var view: SpecView
var info: Control
var seed_v := 0.0
var _sky: ColorRect
var _fig: Control             # in the panel, over the sky, under the words: the constellations
var _rim: Control             # over the card: the shooting star
var _k := 0.0
var _t := 0.0
var _next := 3.0
var _shoot := -1.0            # the shooting star's time, s; < 0: none
var _shoot_from := 0.0        # where on the rim it starts (0..1 round it), and which way
var _shoot_dir := 1.0
var _own := []                # [point (the panel's), age]
var _tapped := false
var rng := RandomNumberGenerator.new()

static func attach(card_: Control, view_: SpecView, info_: Control, fx: String, s: Dictionary) -> void:
	if fx != "starry" or card_.has_meta("starry_card"): return
	card_.set_meta("starry_card", true)
	var cs := CardStarry.new()
	cs.card = card_
	cs.view = view_
	cs.info = info_
	cs.seed_v = float(int(s.get("id", 1)) % 977) * 0.37
	card_.add_child(cs)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 5
	rng.randomize()
	for ar in OS.get_cmdline_user_args():
		if ar.begins_with("star_every="): test_every = float(ar.get_slice("=", 1))
		if ar.begins_with("star_tap="): test_tap = float(ar.get_slice("=", 1))
	if test_every > 0.0: _next = test_every
	# inside the info panel, over its slate (its first child) and under its words: the sky, the figures over it
	var hold := Control.new()
	hold.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(hold)
	info.move_child(hold, mini(1, info.get_child_count() - 1))
	_sky = ColorRect.new()
	_sky.color = Color.WHITE
	_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/card_starry.gdshader")
	m.set_shader_parameter("seed", seed_v)
	_sky.material = m
	hold.add_child(_sky)
	_fig = Control.new()
	_fig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fig.material = FxLayer.add_material()
	_fig.draw.connect(_draw_fig)
	hold.add_child(_fig)
	_rim = Control.new()
	_rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rim.material = FxLayer.add_material()
	_rim.draw.connect(_draw_rim)
	add_child(_rim)
	tree_exiting.connect(func() -> void: if is_instance_valid(hold): hold.queue_free())

## a star: a soft point with four fine rays
func _star(n: Control, at: Vector2, r: float, a: float, col := Color(0.9, 0.94, 1.0)) -> void:
	if a <= 0.01: return
	n.draw_circle(at, r * 2.6, Color(col, 0.1 * a))
	n.draw_circle(at, r * 1.3, Color(col, 0.3 * a))
	n.draw_circle(at, r * 0.6, Color(1, 1, 1, 0.95 * a))
	for d: Vector2 in [Vector2(1, 0), Vector2(0, 1)]:
		n.draw_line(at - d * r * 3.4, at + d * r * 3.4, Color(col, 0.5 * a), 1.0, true)

## the traits' constellation (a star at each badge's left end, joined in the order they stand), and the player's own
func _draw_fig() -> void:
	var to_me := _fig.get_global_transform().affine_inverse()
	var pts: Array[Vector2] = []
	for n in info.find_children("*", "Label", true, false):
		var l := n as Label
		if not l.has_meta("chip") or not l.is_visible_in_tree(): continue
		pts.append(to_me * (l.get_global_transform() * Vector2(1.0, l.size.y - 3.0)))
	var col := Color(0.75, 0.85, 1.0)
	# drawn in one after another as the card opens: a line, then its star
	var prog := maxf(0.0, _t - 1.2) / 0.45
	for i in pts.size():
		var a := clampf(prog - i, 0.0, 1.0) * _k
		if i > 0:
			var from := pts[i - 1]
			_fig.draw_line(from, from.lerp(pts[i], clampf(prog - (i - 1) - 0.4, 0.0, 1.0) / 0.6 if prog - (i - 1) > 0.4 else 0.0),
				Color(col, 0.32 * _k), 1.0, true)
		_star(_fig, pts[i], 1.9, a * (0.75 + 0.25 * sin(_t * 1.7 + i * 2.1)), col)
	# the player's own: gold, joined in the order they were lit, fading together at the end
	var gold := Color(1.0, 0.85, 0.5)
	for i in _own.size():
		var q: Array = _own[i]
		var a := clampf(float(q[1]) / 0.25, 0.0, 1.0) * clampf((KEEP - float(q[1])) / 2.0, 0.0, 1.0) * _k
		if i > 0:
			var q0: Array = _own[i - 1]
			var a0 := clampf((KEEP - float(q0[1])) / 2.0, 0.0, 1.0)
			_fig.draw_line(q0[0], (q0[0] as Vector2).lerp(q[0], clampf(float(q[1]) / 0.3, 0.0, 1.0)), Color(gold, 0.4 * minf(a, a0)), 1.0, true)
		_star(_fig, q[0], 2.3, a, gold)

## a point of the card's rim, s 0..1 round it (clockwise from the top left corner's end), on the brass's middle line
func _rim_pt(s: float) -> Vector2:
	var w := card.size.x
	var h := card.size.y
	var r := 12.0
	var inset := Reveal.CARD_PAD * 0.5
	var a := Vector2(inset, inset)
	var b := Vector2(w - inset, h - inset)
	var straight_w := (b.x - a.x) - r * 2.0
	var straight_h := (b.y - a.y) - r * 2.0
	var arc := PI * 0.5 * r
	var total := (straight_w + straight_h + arc * 2.0) * 2.0
	var d := fposmod(s, 1.0) * total
	var segs := [straight_w, arc, straight_h, arc, straight_w, arc, straight_h, arc]
	var i := 0
	while i < 7 and d > float(segs[i]):
		d -= float(segs[i])
		i += 1
	match i:
		0: return Vector2(a.x + r + d, a.y)
		1: return Vector2(b.x - r, a.y + r) + Vector2.from_angle(-PI * 0.5 + d / r) * r
		2: return Vector2(b.x, a.y + r + d)
		3: return Vector2(b.x - r, b.y - r) + Vector2.from_angle(d / r) * r
		4: return Vector2(b.x - r - d, b.y)
		5: return Vector2(a.x + r, b.y - r) + Vector2.from_angle(PI * 0.5 + d / r) * r
		6: return Vector2(a.x, b.y - r - d)
	return Vector2(a.x + r, a.y + r) + Vector2.from_angle(PI + d / r) * r

## the shooting star on the rim: a bright head, a long tail thinning behind it; it flares and dies at its end
func _draw_rim() -> void:
	if _shoot < 0.0: return
	const LIFE := 1.25
	var u := _shoot / LIFE
	var head := _shoot_from + _shoot_dir * (1.0 - pow(1.0 - u, 2.0)) * 0.42
	var fade := smoothstep(0.0, 0.08, u) * (1.0 - smoothstep(0.75, 1.0, u))
	var to_me := _rim.get_global_transform().affine_inverse() * card.get_global_transform()
	var n := 26
	var tail := 0.1 * smoothstep(0.0, 0.3, u)
	var prev := to_me * _rim_pt(head)
	for i in range(1, n + 1):
		var f := i / float(n)
		var pt := to_me * _rim_pt(head - _shoot_dir * tail * f)
		var a := (1.0 - f) * (1.0 - f) * fade
		_rim.draw_line(prev, pt, Color(0.7, 0.82, 1.0, 0.25 * a), 7.0 * (1.0 - f) + 1.0, true)
		_rim.draw_line(prev, pt, Color(1.0, 1.0, 1.0, 0.9 * a), 2.2 * (1.0 - f) + 0.6, true)
		prev = pt
	var hp := to_me * _rim_pt(head)
	_star(_rim, hp, 2.6 + 2.0 * smoothstep(0.7, 0.9, u) * (1.0 - smoothstep(0.9, 1.0, u)), fade)

func _input(ev: InputEvent) -> void:
	var press: bool = (ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT) \
		or (ev is InputEventScreenTouch and (ev as InputEventScreenTouch).pressed)
	if not press or not is_instance_valid(info) or not info.is_visible_in_tree(): return
	var gp: Vector2 = (ev as InputEventMouseButton).position if ev is InputEventMouseButton else (ev as InputEventScreenTouch).position
	touch(info.get_global_transform_with_canvas().affine_inverse() * gp)

## a touch at a point of the panel: a star there (not on a button), joined to the last
func touch(p: Vector2) -> void:
	if not Rect2(Vector2.ZERO, info.size).grow(-8.0).has_point(p): return
	for n in info.find_children("*", "Button", true, false):
		var b := n as Button
		if b.is_visible_in_tree() and (info.get_global_transform().affine_inverse() * b.get_global_transform() * Rect2(Vector2.ZERO, b.size)).grow(4.0).has_point(p): return
	# (the first of a new figure: the old one, fading, is let go)
	if _own.size() and float(_own[-1][1]) > KEEP - 2.0: _own.clear()
	for q: Array in _own: q[1] = minf(float(q[1]), 1.0)
	_own.append([_fig.get_global_transform().affine_inverse() * (info.get_global_transform() * p), 0.0])
	if _own.size() > MAX_OWN: _own.pop_front()
	Sfx.play("reveal", 1)
	Sfx.buzz(8)

func _process(dt: float) -> void:
	if not is_instance_valid(view) or not is_instance_valid(info) or not is_instance_valid(card):
		queue_free()
		return
	var shown := view.is_visible_in_tree()
	_t += dt
	_k = minf(1.0, _k + dt / 1.2) if shown else 0.0
	if test_tap > 0.0 and _t >= test_tap and not _tapped:
		_tapped = true
		for q: Vector2 in [Vector2(0.14, 0.42), Vector2(0.42, 0.14), Vector2(0.62, 0.44), Vector2(0.9, 0.2)]: touch(q * info.size)
	for q: Array in _own: q[1] = float(q[1]) + dt
	_own = _own.filter(func(q: Array) -> bool: return float(q[1]) < KEEP)
	# a shooting star, now and then
	if _shoot >= 0.0:
		_shoot += dt
		if _shoot > 1.25: _shoot = -1.0
	elif shown and card.scale.is_equal_approx(Vector2.ONE):
		_next -= dt
		if _next <= 0.0:
			_next = test_every if test_every > 0.0 else rng.randf_range(EVERY[0], EVERY[1])
			_shoot = 0.0
			_shoot_from = rng.randf()
			_shoot_dir = 1.0 if rng.randf() < 0.5 else -1.0
			Sfx.play("reveal", 0)
	# all in the card's own space, over the whole card (these are laid out inside the card's padding, the panel's)
	var ig: Rect2 = card.get_global_transform().affine_inverse() * info.get_global_transform() * Rect2(Vector2.ZERO, info.size)
	for r: Control in [_sky, _fig]:
		r.position = ((r.get_parent() as Control).get_global_transform().affine_inverse() * card.get_global_transform()).origin
		r.size = card.size
	_rim.position = Vector2.ZERO
	_rim.size = size
	var m := _sky.material as ShaderMaterial
	m.set_shader_parameter("card", card.size)
	m.set_shader_parameter("frame_in", Reveal.CARD_PAD)
	m.set_shader_parameter("rim_bot", ig.position.y)
	m.set_shader_parameter("t", _t)
	m.set_shader_parameter("k", _k)
	_fig.queue_redraw()
	_rim.queue_redraw()
