class_name MaidenCard
extends RefCounted
## The Fire Maiden's card (before the chase and after it, docs/fire-maiden.md), in the kit's window: her portrait by
## the campfire fills the card up to the brass rim (rounded at the top like the frame) and sinks into the slate below,
## embers rise over it; under it her name large and warm, a brass rule with a little flame in the middle, the text
## centred, the kit's buttons. buttons: [[label, "green"|"dark", callable], ...]

const GOLD := Color("#f2c46a")
const FELL := "res://assets/fonts/IMFellEnglish.ttf"

static func show(lines: Array, accent: String, buttons: Array, extra: Control = null, pic_h := 290.0) -> VBoxContainer:
	var v := Ov.card(340, Color(1.0, 0.55, 0.18))
	# the window's frame closer round its content: the portrait goes right up to the rim
	(v.get_parent() as PanelContainer).add_theme_stylebox_override("panel", Kit.box("window", Reveal.CARD_PAD))
	v.add_theme_constant_override("separation", 0)
	v.add_child(_portrait(pic_h))
	var body := MarginContainer.new()
	for side in ["left", "right"]: body.add_theme_constant_override("margin_" + side, 18)
	body.add_theme_constant_override("margin_bottom", 14)
	v.add_child(body)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	body.add_child(col)
	# the name over the portrait's dark lower edge
	var t := Label.new()
	t.text = "The Fire Maiden"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# an old book's face, warm gold with a soft glow of the fire behind it (not the kit's black: too loud here)
	t.add_theme_font_override("font", load(FELL) as Font)
	t.add_theme_font_size_override("font_size", 34)
	t.add_theme_color_override("font_color", GOLD)
	t.add_theme_color_override("font_shadow_color", Color(1.0, 0.5, 0.12, 0.5))
	t.add_theme_constant_override("shadow_offset_x", 0)
	t.add_theme_constant_override("shadow_offset_y", 0)
	t.add_theme_constant_override("shadow_outline_size", 12)
	col.add_child(t)
	t.custom_minimum_size = Vector2(0, 34)
	col.add_child(_rule())
	for i in lines.size():
		var l := UI.label(String(lines[i]), 15, UI.body, Kit.CREAM)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(l)
	if accent != "":
		var a := UI.label(accent, 16, load(FELL) as Font, GOLD)
		a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		a.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(a)
	if extra: col.add_child(extra)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 2)
	col.add_child(gap)
	for b in buttons:
		col.add_child(Ov.btn(String(b[0]), String(b[1]), b[2]))
	# the name sits on the portrait's dark foot
	body.add_theme_constant_override("margin_top", -40)
	return v

## the portrait in a mask rounded at the top like the frame, fading into the slate at the bottom, embers rising
static func _portrait(h: float) -> Control:
	var mask := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color.WHITE
	st.corner_radius_top_left = 15
	st.corner_radius_top_right = 15
	st.anti_aliasing = true
	mask.add_theme_stylebox_override("panel", st)
	mask.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	mask.custom_minimum_size = Vector2(0, h)
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := Control.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mask.add_child(box)
	var pic := TextureRect.new()
	pic.texture = load(MaidenView.DIR + "portrait.png")
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.set_anchors_preset(Control.PRESET_FULL_RECT)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# the lower part sinks into the card's own slate (its alpha fades, the slate shows through: no seam)
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/fade_down.gdshader")
	pic.material = m
	box.add_child(pic)
	box.add_child(Embers.new())
	box.resized.connect(func():
		for ch in box.get_children(): (ch as Control).size = box.size)
	mask.resized.connect(func(): box.size = mask.size)
	return mask

## the brass rule of the kit with a little flame in its middle
static func _rule() -> Control:
	var c := CenterContainer.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var r := Kit.rule(250)
	c.add_child(r)
	var f := Flame.new()
	f.custom_minimum_size = Vector2(18, 22)
	c.add_child(f)
	return c

## embers rising over the portrait, from the fire at its foot
class Embers extends Control:
	var _p: Array = []
	var _glow: Texture2D = GemArt.glow_tex()
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _process(dt: float) -> void:
		if size.x <= 0: return
		if randf() < 0.3:
			_p.append([Vector2(size.x * randf_range(0.3, 0.7), size.y * randf_range(0.62, 0.75)),
				Vector2(randf_range(-12, 12), randf_range(-45, -20)), randf_range(1.2, 2.6)])
		for e in _p:
			e[0] += e[1] * dt
			e[1].x += sin(Time.get_ticks_msec() / 400.0 + e[0].y * 0.05) * 8.0 * dt
			e[2] -= dt
		_p = _p.filter(func(e: Array) -> bool: return float(e[2]) > 0.0)
		queue_redraw()
	func _draw() -> void:
		for e in _p:
			var k := clampf(float(e[2]) / 1.5, 0.0, 1.0)
			var r := 2.0 + 4.0 * k
			draw_texture_rect(_glow, Rect2(e[0] - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(1.0, 0.42 + 0.25 * k, 0.12, k))

## a little flame (the rule's ornament), flickering
class Flame extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _process(_dt: float) -> void:
		queue_redraw()
	func _draw() -> void:
		var tm := Time.get_ticks_msec() / 1000.0
		var c := Vector2(size.x / 2.0, size.y * 0.92)
		var h := size.y * (0.9 + 0.08 * sin(tm * 9.0))
		var sway := sin(tm * 5.0) * 0.12
		for layer in 2:
			var k := 1.0 if layer == 0 else 0.55
			var pts := PackedVector2Array()
			for i in 17:
				var u := float(i) / 16.0 * TAU
				var x := sin(u) * 0.32
				var y := -0.3 + cos(u) * 0.3
				if y < -0.3:
					var q := (-0.3 - y) / 0.3
					x *= 1.0 - q * 0.9
					y = -0.3 - q * 0.7
				pts.append(c + Vector2(x * h * k + sway * h * (-y) * k, y * h * k))
			draw_colored_polygon(pts, Color(1.0, 0.55, 0.12) if layer == 0 else Color(1.0, 0.9, 0.5))
