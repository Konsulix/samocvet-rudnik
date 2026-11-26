class_name CardHeart
extends Control
## (26.11) The star heart (SpecLegend.heart) and its card: the stone is the card's heart — the two things a legendary
## card does (out past the stone's frame; the interface played with), kept simple:
##  - vessels of light in the card's brass (its frame, the ribbon over the info panel) and over the panel's slate, under
##    its words, the heart's own colour — always there, dimly lit; the beat gives them life: on every beat a wave of
##    light runs out along them from the stone, and the light in them is driven on outward, as blood
##    (card_heart.gdshader);
##  - the beat goes through the card: the stone's own lub-dub (Spec.beat), the card itself starting ever so slightly,
##    its badges, figures and buttons each in turn as the wave reaches it; a dull double thud, quietly;
##  - the heart is calm — a slow beat, a long rest. Shake the stone (the phone; or flick it hard round) and it races
##    (Spec.heart_rush) and settles again over some ten seconds. The phone beats along all the while: faintly at rest,
##    harder while it races.

const SPEED := 520.0          # the wave over the card, points a second
const HN := 48                # the beat's past, kept for the wave: this many samples
const HS := 0.025             # s apart
const FLICK := 4.0            # the stone flicked round this fast (SpecView.spin_v): as good as shaken

static var test_rush := 0.0   # a test key (-- heart_rush=S): the heart is startled every S s

var card: Control
var view: SpecView
var info: Control
var light: OmniLight3D
var _rect: ColorRect
var _slate: ColorRect
var _age := 0.0
var _k := 0.0
var _hist := PackedFloat32Array()
var _acc := 0.0
var _flow := 0.0
var _last_t := 0.0
var _beats := 0
var _rush_at := 0.0
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
	_hist.resize(HN)
	for ar in OS.get_cmdline_user_args():
		if ar.begins_with("heart_rush="): test_rush = float(ar.get_slice("=", 1))
	_rect = _piece(0, self)
	# inside the info panel, over its slate (its first child) and under its words: a holder the panel lays out, the
	# piece itself placed over the whole card each frame (as CardLava's)
	var hold := Control.new()
	hold.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(hold)
	info.move_child(hold, mini(1, info.get_child_count() - 1))
	_slate = _piece(1, hold)
	tree_exiting.connect(func() -> void:
		if is_instance_valid(hold): hold.queue_free()
		if _mine and is_instance_valid(card): card.scale = Vector2.ONE)

func _piece(part: int, host: Control) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color.WHITE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/card_heart.gdshader")
	m.set_shader_parameter("part", part)
	r.material = m
	host.add_child(r)
	return r

## the beat `delay` s ago (the wave reaching a thing that far from the heart)
func _beat_ago(delay: float) -> float:
	var x := maxf(0.0, delay - _acc) / HS
	var i := int(x)
	if i >= HN - 1: return 0.0
	return lerpf(_hist[i], _hist[i + 1], x - i)

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
	# shaken (SpecView.shake_find sets it), or flicked hard round: the heart races
	if shown and absf(view.spin_v) > FLICK: Spec.heart_rush = 1.0
	if test_rush > 0.0:
		_rush_at += dt
		if _rush_at >= test_rush:
			_rush_at = 0.0
			Spec.heart_rush = 1.0
	# the beat's past, for the wave; and how far the beats have driven the light on
	_acc += dt
	while _acc >= HS:
		_acc -= HS
		for i in range(HN - 1, 0, -1): _hist[i] = _hist[i - 1]
		_hist[0] = Spec.beat
	_flow += Spec.beat * dt * 1.5
	var src := _proj(light.global_position)
	var ig: Rect2 = card.get_global_transform().affine_inverse() * info.get_global_transform() * Rect2(Vector2.ZERO, info.size)
	const WIDE := 20.0 / 3.6
	var lc := light.light_color
	for r: ColorRect in [_rect, _slate]:
		# over the whole card, frame and all (these are laid out inside the card's padding, the panel's)
		# (in the card's own space, not the screen's: the card's scale starts with the beat, and a place taken on the
		# screen a frame before it slid the vessels off the brass for a frame)
		r.position = ((r.get_parent() as Control).get_global_transform().affine_inverse() * card.get_global_transform()).origin
		r.size = card.size
		var m := r.material as ShaderMaterial
		m.set_shader_parameter("card", card.size)
		m.set_shader_parameter("frame_in", Reveal.CARD_PAD)
		m.set_shader_parameter("rim_top", ig.position.y - WIDE)
		m.set_shader_parameter("rim_bot", ig.position.y)
		m.set_shader_parameter("rim_l", ig.position.x + Reveal.INFO_R + 6.0)
		m.set_shader_parameter("rim_r", ig.end.x - Reveal.INFO_R - 6.0)
		m.set_shader_parameter("src", src)
		m.set_shader_parameter("t", _age)
		m.set_shader_parameter("speed", SPEED)
		m.set_shader_parameter("col", Vector3(lc.r, lc.g, lc.b))
		m.set_shader_parameter("k", _k)
		m.set_shader_parameter("hist", _hist)
		m.set_shader_parameter("hoff", _acc)
		m.set_shader_parameter("flow", _flow)
	# the card itself starts with the beat, ever so slightly — unless another hand is on it (it opens and shuts with
	# a scale tween)
	if card.scale.is_equal_approx(_set_scale) or card.scale.is_equal_approx(Vector2.ONE):
		# (only on the beat itself: on its faint rise the card crept by a pixel and back, before every beat)
		_set_scale = Vector2.ONE * (1.0 + 0.008 * maxf(0.0, Spec.beat - 0.2) * _k)
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
		var b := _beat_ago(at.distance_to(src) / SPEED) * _k
		c.pivot_offset = c.size / 2.0
		c.scale = Vector2.ONE * (1.0 + (0.035 if c is Button else 0.06) * b)
	# the thud, and the phone's own beat: on the lub and, softer, on the dub
	var ht := Spec.heart_t
	if shown and _k > 0.5:
		# (26.11, asked: always, only faint) the phone beats along all the while — faintly at rest, harder while it races
		var hard := Spec.heart_rush > 0.12
		var dub := 0.07 + Spec.heart_gap
		if _last_t < 0.05 and ht >= 0.05:
			_beats += 1
			Sfx.play("heart_lub")
			Sfx.buzz(16 if hard else 7)
		elif _last_t < dub - 0.02 and ht >= dub - 0.02:
			Sfx.play("heart_dub")
			Sfx.buzz(8 if hard else 4)
	_last_t = ht
