class_name CardOpal
extends Control
## (26.11) The opal fire (the legend «opal») and its card — the two things a legendary card does (out past the stone's
## frame; the interface played with): the info panel's slate turns to precious opal, a dark body with the stone's own
## mosaic of colour in it, under the panel's words, and the same fire, faint, runs in the card's brass
## (card_opal.gdshader). It plays as a real opal does: every patch throws its colour one way and lights only when the
## card leans that way — tilt the phone a little (Input.get_gravity) and other patches flash, a band of light rolling
## across. Without a sensor (a PC) it leans slowly by itself.

static var test_tilt := Vector2.INF   # a test key (-- opal_tilt=x,y): this lean, held

var card: Control
var view: SpecView
var info: Control
var seed_v := 0.0
var hue := 0.55
var _brass: ColorRect
var _slate: ColorRect
var _k := 0.0
var _t := 0.0
var _g0 := Vector3.ZERO
var _tilt := Vector2.ZERO

static func attach(card_: Control, view_: SpecView, info_: Control, fx: String, s: Dictionary) -> void:
	if fx != "opal" or card_.has_meta("opal_card"): return
	card_.set_meta("opal_card", true)
	var co := CardOpal.new()
	co.card = card_
	co.view = view_
	co.info = info_
	var id := int(s.get("id", 1))
	co.seed_v = float(id % 977) * 0.37
	# (its fire's colours its own: blue-green most often, at times the whole harlequin with red, or green-gold)
	co.hue = [0.55, 0.6, 0.45, 0.25, 0.7][id % 5]
	card_.add_child(co)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 5
	for ar in OS.get_cmdline_user_args():
		if ar.begins_with("opal_tilt="):
			var v := ar.get_slice("=", 1).split(",")
			test_tilt = Vector2(float(v[0]), float(v[1]))
	_brass = _piece(0, self)
	# inside the info panel, over its slate (its first child) and under its words
	var hold := Control.new()
	hold.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(hold)
	info.move_child(hold, mini(1, info.get_child_count() - 1))
	_slate = _piece(1, hold)
	tree_exiting.connect(func() -> void: if is_instance_valid(hold): hold.queue_free())

func _piece(part: int, host: Control) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color.WHITE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/card_opal.gdshader")
	m.set_shader_parameter("part", part)
	m.set_shader_parameter("seed", seed_v)
	m.set_shader_parameter("fh", hue)
	m.set_shader_parameter("spread", 0.34)
	r.material = m
	host.add_child(r)
	return r

func _process(dt: float) -> void:
	if not is_instance_valid(view) or not is_instance_valid(info) or not is_instance_valid(card):
		queue_free()
		return
	_t += dt
	_k = minf(1.0, _k + dt / 1.2) if view.is_visible_in_tree() else 0.0
	# the lean: the phone's, about the way it is held (a slow average) — a little goes a long way; with no sensor, a
	# slow lean of its own
	var aim := Vector2(0.28 * sin(_t * 0.5) + 0.1 * sin(_t * 1.3 + 1.0), 0.22 * sin(_t * 0.37 + 2.0))
	var g := Input.get_gravity()
	if g.length() > 0.5:
		var n := g.normalized()
		_g0 = n if _g0 == Vector3.ZERO else _g0.lerp(n, minf(1.0, dt * 0.25)).normalized()
		var d := n - _g0
		aim = (Vector2(-d.x, d.z) * 2.2).clamp(Vector2(-0.9, -0.9), Vector2(0.9, 0.9)) + aim * 0.15
	if test_tilt != Vector2.INF: aim = test_tilt
	_tilt = _tilt.lerp(aim, minf(1.0, dt * 6.0))
	var ig: Rect2 = card.get_global_transform().affine_inverse() * info.get_global_transform() * Rect2(Vector2.ZERO, info.size)
	const WIDE := 20.0 / 3.6
	for r: ColorRect in [_brass, _slate]:
		# in the card's own space, over the whole card (these are laid out inside the card's padding, the panel's)
		r.position = ((r.get_parent() as Control).get_global_transform().affine_inverse() * card.get_global_transform()).origin
		r.size = card.size
		var m := r.material as ShaderMaterial
		m.set_shader_parameter("card", card.size)
		m.set_shader_parameter("frame_in", Reveal.CARD_PAD)
		m.set_shader_parameter("rim_top", ig.position.y - WIDE)
		m.set_shader_parameter("rim_bot", ig.position.y)
		m.set_shader_parameter("rim_l", ig.position.x + Reveal.INFO_R + 6.0)
		m.set_shader_parameter("rim_r", ig.end.x - Reveal.INFO_R - 6.0)
		m.set_shader_parameter("tilt", _tilt)
		m.set_shader_parameter("k", _k)
