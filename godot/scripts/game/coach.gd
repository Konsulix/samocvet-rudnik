class_name Coach
extends Control
## The tutorial's show on the board (docs/onboarding.md, "показ на поле"): the screen dims but for a few holes, a gloved
## hand shows the move, one line on a slate card. The dark is cut into plain rects (_cut) that also catch touches, so only
## the holes reach what is under them; with tap_any one touch anywhere closes it instead.

signal dismissed

const DIM := Color(0.02, 0.02, 0.03, 0.66)
const HAND := "res://assets/ui/kit/icons/hand.png"
const HAND_H := 80.0
const CYCLE := 1.9
## test runs (shots, autoplay, sims) go without the tutorial (main.gd)
static var off := false

var holes: Array[Rect2] = []
var tap_any := false
var _blocks: Array[Control] = []
var _card: PanelContainer
var _hand_from := Vector2.ZERO
var _hand_to := Vector2.ZERO
var _hand_on := false
var _t := 0.0
var _fade: Tween

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

## dim all but `rects` (screen coordinates), with a line of text by them
func open(rects: Array, text: String, any := false) -> void:
	holes.clear()
	for r in rects: holes.append(r.grow(4.0))
	tap_any = any
	_hand_on = false
	_cut()
	_place_card(text)
	visible = true
	if _fade: _fade.kill()
	modulate.a = 0.0
	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", 1.0, 0.3)
	queue_redraw()

## the hand presses at `from` and slides to `to` (the same point: it taps)
func hand(from: Vector2, to: Vector2) -> void:
	_hand_from = from
	_hand_to = to
	_hand_on = true
	_t = 0.0

func close() -> void:
	if not visible: return
	for b in _blocks: b.queue_free()
	_blocks.clear()
	if _fade: _fade.kill()
	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", 0.0, 0.2)
	_fade.tween_callback(func():
		visible = false
		_hand_on = false
		if _card: _card.queue_free()
		_card = null)

## the dark as bands across the screen: in each band, the spans between the holes that cross it
func _dark() -> Array[Rect2]:
	var vp := get_viewport_rect().size
	var ys: Array[float] = [0.0, vp.y]
	for h in holes:
		ys.append(clampf(h.position.y, 0.0, vp.y))
		ys.append(clampf(h.end.y, 0.0, vp.y))
	ys.sort()
	var out: Array[Rect2] = []
	for i in ys.size() - 1:
		var y0: float = ys[i]
		var y1: float = ys[i + 1]
		if y1 - y0 < 0.5: continue
		var spans: Array[Vector2] = []
		for h in holes:
			if h.position.y <= y0 and h.end.y >= y1: spans.append(Vector2(h.position.x, h.end.x))
		spans.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
		var x := 0.0
		for s in spans:
			if s.x > x: out.append(Rect2(x, y0, s.x - x, y1 - y0))
			x = maxf(x, s.y)
		if x < vp.x: out.append(Rect2(x, y0, vp.x - x, y1 - y0))
	return out

func _cut() -> void:
	for b in _blocks: b.queue_free()
	_blocks.clear()
	var parts: Array[Rect2] = _dark()
	if tap_any: parts = [Rect2(Vector2.ZERO, get_viewport_rect().size)]
	for r in parts:
		var b := Control.new()
		b.position = r.position
		b.size = r.size
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		b.gui_input.connect(_block_input)
		add_child(b)
		_blocks.append(b)

func _block_input(e: InputEvent) -> void:
	var pressed: bool = (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed)
	if not pressed: return
	if tap_any and modulate.a > 0.6:
		close()
		dismissed.emit()
	elif _hand_on:
		_t = 0.0   # a touch off the holes: show the move again

func _place_card(text: String) -> void:
	if _card: _card.queue_free()
	_card = null
	if text == "": return
	var vp := get_viewport_rect().size
	var top := vp.y
	var bottom := 0.0
	for h in holes:
		top = minf(top, h.position.y)
		bottom = maxf(bottom, h.end.y)
	_card = PanelContainer.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := Kit.box("card", 0.0)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 12
	sb.content_margin_bottom = 13
	_card.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 4)
	var w := minf(vp.x - 40.0, 330.0)
	var l := Kit.label(text, 17, UI.body_bold)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# the wrap needs its width up front, or it measures one word per line
	l.custom_minimum_size = Vector2(w - 36.0, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	if tap_any:
		var more := Kit.label("Tap to continue", 12, UI.body_bold, Kit.DIM)
		more.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(more)
	_card.add_child(v)
	_card.custom_minimum_size = Vector2(w, 0)
	add_child(_card)
	# beside the holes, on the side with more room; placed again once the wrapped text has its height
	var above := top - UI.safe_top() > vp.y - bottom - UI.safe_bottom()
	var place := func():
		if not is_instance_valid(_card): return
		var h := _card.size.y
		var y := top - h - 18.0 if above else bottom + 18.0
		_card.position = Vector2((vp.x - w) / 2, clampf(y, UI.safe_top() + 8.0, vp.y - h - UI.safe_bottom() - 8.0))
	_card.resized.connect(place)
	place.call()

func _process(dt: float) -> void:
	if not visible: return
	_t += dt
	queue_redraw()

func _draw() -> void:
	if holes.is_empty() and not tap_any: return
	for r in _dark(): draw_rect(r, DIM)
	var now := Time.get_ticks_msec() / 1000.0
	var glow := 0.55 + 0.35 * sin(now * 3.2)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	sb.border_color = Color(Kit.AMBER, glow)
	for h in holes: draw_style_box(sb, h)
	if _hand_on: _draw_hand()

## one stroke of the hand: comes in, presses, slides (or taps twice), lifts, fades, rests
func _draw_hand() -> void:
	var k := fmod(_t, CYCLE)
	var tap := _hand_from.distance_to(_hand_to) < 1.0
	var p := _hand_from
	var press := 0.0
	var a := 1.0
	if k < 0.25:
		a = k / 0.25
	elif k < 0.4:
		press = (k - 0.25) / 0.15
	elif k < 1.05:
		press = 1.0
		var u := (k - 0.4) / 0.65
		if tap: press = 1.0 - absf(sin(u * PI * 2.0)) * 0.9
		else: p = _hand_from.lerp(_hand_to, ease(u, -2.0))
	elif k < 1.25:
		p = _hand_to
		press = 1.0 - (k - 1.05) / 0.2
	elif k < 1.55:
		p = _hand_to
		a = 1.0 - (k - 1.25) / 0.3
	else:
		return
	var s := 1.0 - 0.12 * press
	if press > 0.5:
		draw_circle(p, 14.0 + 8.0 * press, Color(Kit.AMBER, 0.22 * a))
	var tex := Kit.tex_at(HAND) if ResourceLoader.exists(HAND) else null
	draw_set_transform(p + Vector2(4, 6) * (1.0 - press), -0.32, Vector2(s, s))
	if tex:
		var h := HAND_H
		var w := h * tex.get_width() / tex.get_height()
		# the fingertip is the picture's top middle
		draw_texture_rect(tex, Rect2(-w * 0.5, -2.0, w, h), false, Color(1, 1, 1, a))
	else:
		draw_circle(Vector2.ZERO, 11.0, Color(Kit.CREAM, 0.9 * a))
		draw_arc(Vector2.ZERO, 11.0, 0, TAU, 24, Color(0, 0, 0, 0.6 * a), 2.0, true)
	draw_set_transform(Vector2.ZERO)
