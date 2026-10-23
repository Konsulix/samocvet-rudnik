extends CanvasLayer
## Cards over the whole game (rewards, choices, the stone reveal) and short toasts.
## card() opens a dimmed, centred glass card and returns its content box to fill.

signal closed

var root: Control
var _card: PanelContainer
var _dim: ColorRect
var _center: CenterContainer

func _ready() -> void:
	layer = 20
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

func is_open() -> bool:
	return _card != null

## glow: a coloured rim and halo round the card (the find's rarity); transparent = the plain gold hairline
func card(width := 340.0, glow := Color.TRANSPARENT) -> VBoxContainer:
	close(false)
	var dim := ColorRect.new()
	_dim = dim
	dim.color = Color(0.01, 0.02, 0.04, 0.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	create_tween().tween_property(dim, "color:a", 0.62, 0.2)
	var center := CenterContainer.new()
	_center = center
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	_card = PanelContainer.new()
	var st := UI.glass(26, 0.94)
	st.set_content_margin_all(18)
	st.border_color = Color(1, 0.85, 0.5, 0.22)
	if glow.a > 0.0:
		st.set_border_width_all(2)
		st.border_color = Color(glow, 0.85)
		st.shadow_color = Color(glow, 0.45)
		st.shadow_size = 22
	_card.add_theme_stylebox_override("panel", st)
	_card.custom_minimum_size = Vector2(width, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	_card.add_child(v)
	center.add_child(_card)
	_card.scale = Vector2(0.86, 0.86)
	_card.modulate.a = 0.0
	_card.resized.connect(func(): _card.pivot_offset = _card.size / 2)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_card, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_card, "modulate:a", 1.0, 0.16)
	return v

## a card with a title, text and buttons [[label, kind, callable, enabled], ...]
func panel(title_text: String, body_text: String, buttons: Array) -> VBoxContainer:
	var v := card()
	v.add_child(UI.title(title_text, 22))
	if body_text != "":
		v.add_child(text(body_text))
	for b in buttons:
		v.add_child(btn(b[0], b[1], b[2], b[3] if b.size() > 3 else true))
	return v

func text(s: String, size := 15, col := UI.MUTED) -> Label:
	var l := UI.label(s, size, UI.body, col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func btn(label: String, kind: String, fn: Callable, enabled := true) -> Button:
	var b := UI.button(label, kind, 17)
	b.custom_minimum_size = Vector2(0, 54)
	b.disabled = not enabled
	b.pressed.connect(fn)
	return b

func close(emit := true) -> void:
	for n in [_dim, _center]:
		if n:
			root.remove_child(n)
			n.queue_free()
	_dim = null
	_center = null
	var was := _card != null
	_card = null
	if emit and was:
		closed.emit()

func toast(s: String) -> void:
	var l := UI.label(s, 14, UI.body_bold)
	var p := PanelContainer.new()
	var st := UI.glass(14, 0.92)
	st.border_color = UI.GOLD
	p.add_theme_stylebox_override("panel", st)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(300, 0)
	p.add_child(l)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(p)
	var vp := root.get_viewport_rect().size
	p.position = Vector2((vp.x - 324) / 2, 96)
	p.modulate.a = 0
	var tw := create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.2)
	tw.tween_interval(2.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.3)
	tw.tween_callback(p.queue_free)
