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

## the open card's holder (the card sits at its origin): Kit.lantern(Ov.holder()) hangs a lantern on its corner
func holder() -> Control:
	return _card.get_parent() as Control if _card else null

## glow: a coloured halo round the card (the find's rarity)
func card(width := 340.0, glow := Color.TRANSPARENT) -> VBoxContainer:
	close(false)
	Sfx.play("open")
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
	# the drawn kit's window: slate in a brass-and-iron frame (Kit); a rarity glow shows as a halo behind it
	_card.add_theme_stylebox_override("panel", Kit.box("window", 20.0))
	_card.custom_minimum_size = Vector2(width, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	_card.add_child(v)
	# a plain holder, so the card can wear a lantern on its corner (a container would lay it out)
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.resized.connect(func(): holder.custom_minimum_size = _card.size)
	if glow.a > 0.0:
		holder.add_child(_halo(glow, _card))
	holder.add_child(_card)
	center.add_child(holder)
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

func text(s: String, size := 15, col := Color("#cbbfa6")) -> Label:
	var l := UI.label(s, size, UI.body, col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

## a card's button in the drawn kit: green -> the green plate, gold -> brass, anything else -> dark slate
func btn(label: String, kind: String, fn: Callable, enabled := true) -> Button:
	var frame: String = {green = "btn_green", gold = "btn_gold"}.get(kind, "btn_dark")
	var b := Kit.button(label, frame, 20 if frame == "btn_green" else 18, 6.0)
	b.custom_minimum_size = Vector2(0, 60 if frame == "btn_green" else 50)
	b.disabled = not enabled
	b.pressed.connect(fn)
	return b

## the open card stays between these margins (points from the screen's top and bottom), centred in what is left
func keep_clear(top: float, bottom: float) -> void:
	if _center:
		_center.offset_top = top
		_center.offset_bottom = -bottom

## the light round a card in the rarity's colour (being chosen: `-- glow=<look>` for snapshots):
##   muted (chosen) — the colour greyed towards brass, narrow and still; flicker — the first one, a thin halo flickering unevenly;
##   lamp — warm lamplight, no rarity colour; ember — the colour deep and dark, breathing slowly;
##   rim — a dark shadow and a thin line of the colour hugging the frame
static var glow_look := ""

func _halo(glow: Color, card: Control) -> Control:
	if glow_look == "":
		glow_look = "muted"
		for a in OS.get_cmdline_user_args():
			if a.begins_with("glow="): glow_look = a.get_slice("=", 1)
	var brass := Color("#c9a35a")
	var layers: Array = []      # [colour, size, radius]
	match glow_look:
		"muted": layers = [[Color(glow.lerp(brass, 0.55), 0.45), 7, 20]]
		"lamp": layers = [[Color(1.0, 0.78, 0.45, 0.3), 18, 22]]
		"ember": layers = [[Color(glow.darkened(0.35), 0.55), 12, 22], [Color(glow.lerp(brass, 0.3), 0.25), 3, 18]]
		"rim": layers = [[Color(0, 0, 0, 0.7), 18, 22], [Color(glow.lerp(brass, 0.25), 0.7), 2, 18]]
		_: layers = [[Color(glow, 0.8), 5, 20]]
	var box := Control.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for L: Array in layers:
		var halo := Panel.new()
		var hs := StyleBoxFlat.new()
		hs.bg_color = Color(0, 0, 0, 0)
		hs.set_corner_radius_all(int(L[2]))
		hs.shadow_color = L[0]
		hs.shadow_size = int(L[1])
		halo.add_theme_stylebox_override("panel", hs)
		halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.resized.connect(func(): halo.size = card.size)
		box.add_child(halo)
	match glow_look:
		"flicker":
			var fl := box.create_tween().set_loops()
			for k: float in [0.55, 1.0, 0.75, 0.95, 0.5, 0.85, 1.0, 0.65]:
				fl.tween_property(box, "modulate:a", k, 0.22 + 0.5 * absf(k - 0.75)).set_trans(Tween.TRANS_SINE)
		"ember":
			var br := box.create_tween().set_loops()
			br.tween_property(box, "modulate:a", 0.7, 2.4).set_trans(Tween.TRANS_SINE)
			br.tween_property(box, "modulate:a", 1.0, 2.4).set_trans(Tween.TRANS_SINE)
	return box

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
	p.position = Vector2((vp.x - 324) / 2, 96 + UI.safe_top())
	p.modulate.a = 0
	var tw := create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.2)
	tw.tween_interval(2.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.3)
	tw.tween_callback(p.queue_free)
