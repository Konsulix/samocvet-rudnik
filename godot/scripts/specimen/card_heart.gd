class_name CardHeart
extends Control
## (26.11) The star heart (SpecLegend.heart) and its card: the stone is the card's heart — the two things a legendary
## card does (out past the stone's frame; the interface played with), kept simple:
##  - thin vessels of light in the card's brass, its frame and the ribbon over the info panel, the heart's own colour;
##    on every beat a wave of light runs out along them from the stone and dies away (card_heart.gdshader);
##  - the beat goes through the card: the stone's own lub-dub (Spec.beat, the same clock), the card itself starting ever
##    so slightly, its badges, figures and buttons each in turn as the wave reaches it; a dull double thud, quietly,
##    and the phone's own double tap for the first beats after the card opens.

const PERIOD := 0.86          # Spec's beat
const SPEED := 900.0          # the wave over the card, points a second
const BUZZ_FOR := 9.0         # the phone beats along this long after the card opens (then only the eye and the ear)

var card: Control
var view: SpecView
var info: Control
var light: OmniLight3D
var _rect: ColorRect
var _age := 0.0
var _k := 0.0
var _last_h := 0.0
var _set_scale := Vector2.ONE   # the card's scale as this set it last (another's hand on it: hands off)
var _mine := false

## p: the built find; only one with the star heart (its light marked by SpecLegend.heart)
static func attach(card_: Control, view_: SpecView, info_: Control, p: Node3D) -> void:
	if not p.has_meta("heart_light"): return
	var l := p.get_meta("heart_light") as OmniLight3D
	if not is_instance_valid(l): return
	var ch := CardHeart.new()
	ch.card = card_
	ch.view = view_
	ch.info = info_
	ch.light = l
	card_.add_child(ch)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 5
	_rect = ColorRect.new()
	_rect.color = Color.WHITE
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/card_heart.gdshader")
	_rect.material = m
	add_child(_rect)
	tree_exiting.connect(func() -> void:
		if _mine and is_instance_valid(card): card.scale = Vector2.ONE)

static func beat(tt: float) -> float:
	var h := fposmod(tt / PERIOD, 1.0)
	return exp(-pow((h - 0.12) * 11.0, 2.0)) + 0.55 * exp(-pow((h - 0.36) * 11.0, 2.0))

## a point of the stone's scene on the card
func _proj(w: Vector3) -> Vector2:
	var cam := view.studio.cam
	var kk := view.size / Vector2(maxi(1, view.studio.vp.size.x), maxi(1, view.studio.vp.size.y))
	return card.get_global_transform().affine_inverse() * (view.get_global_transform() * (cam.unproject_position(w) * kk))

func _process(dt: float) -> void:
	if not is_instance_valid(view) or not is_instance_valid(info) or not is_instance_valid(light):
		queue_free()
		return
	var shown := view.is_visible_in_tree()
	_age += dt
	_k = minf(1.0, _k + dt / 1.5) if shown else 0.0
	# the beat's clock: Spec's own (the stone's heart and its light beat by it)
	var t := fmod(Time.get_ticks_msec() / 1000.0, PERIOD * 1000.0)
	var src := _proj(light.global_position)
	# the brass: over the whole card, frame and all (this layer is laid out inside the card's padding)
	_rect.global_position = card.global_position
	_rect.size = card.size
	var ig: Rect2 = card.get_global_transform().affine_inverse() * info.get_global_transform() * Rect2(Vector2.ZERO, info.size)
	const WIDE := 20.0 / 3.6
	var m := _rect.material as ShaderMaterial
	var lc := light.light_color
	m.set_shader_parameter("card", card.size)
	m.set_shader_parameter("frame_in", Reveal.CARD_PAD)
	m.set_shader_parameter("rim_top", ig.position.y - WIDE)
	m.set_shader_parameter("rim_bot", ig.position.y)
	m.set_shader_parameter("rim_l", ig.position.x + Reveal.INFO_R + 6.0)
	m.set_shader_parameter("rim_r", ig.end.x - Reveal.INFO_R - 6.0)
	m.set_shader_parameter("src", src)
	m.set_shader_parameter("t", t)
	m.set_shader_parameter("speed", SPEED)
	m.set_shader_parameter("col", Vector3(lc.r, lc.g, lc.b))
	m.set_shader_parameter("k", _k)
	# the card itself starts with the beat, ever so slightly — unless another hand is on it (it opens and shuts with
	# a scale tween)
	if card.scale.is_equal_approx(_set_scale) or card.scale.is_equal_approx(Vector2.ONE):
		_set_scale = Vector2.ONE * (1.0 + 0.006 * beat(t) * _k)
		card.scale = _set_scale
		_mine = true
	else:
		_mine = false
	# its badges, figures and buttons, each as the wave reaches it
	for n in info.find_children("*", "", true, false):
		if not (n is Label or n is Button) or not (n as Control).is_visible_in_tree(): continue
		var c := n as Control
		if c.get_parent() is Button: continue
		var at: Vector2 = card.get_global_transform().affine_inverse() * (c.get_global_transform() * (c.size * 0.5))
		var b := beat(t - at.distance_to(src) / SPEED) * _k
		c.pivot_offset = c.size / 2.0
		c.scale = Vector2.ONE * (1.0 + (0.035 if c is Button else 0.06) * b)
	# the thud, and the phone's own beat: on the lub and, softer, on the dub
	var h := fposmod(t / PERIOD, 1.0)
	if shown and _k > 0.5:
		if _last_h < 0.1 and h >= 0.1:
			Sfx.play("heart_lub")
			if _age < BUZZ_FOR: Sfx.buzz(16)
		elif _last_h < 0.34 and h >= 0.34:
			Sfx.play("heart_dub")
			if _age < BUZZ_FOR: Sfx.buzz(8)
	_last_h = h
