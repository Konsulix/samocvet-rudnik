class_name MaidenCard
extends RefCounted
## The Fire Maiden's card (before the chase and after it, docs/fire-maiden.md), from separate pieces: a sheet of dark
## burnt parchment with glowing torn edges (GPT, stretched in its middle as the kit's frames are: KitBox), her portrait
## in an old-brass frame with flame finials (GPT, the opening empty), and the game's own: the fonts, the brass bar of
## the genes' tags as the dividers, the kit's buttons. Embers rise over the portrait.
## Pieces: art/maiden/gen_parts.sh sheet|frame → cut_parts.py → assets/maiden/card_sheet.png, card_frame.png.
## buttons: [[label, "green"|"dark", callable], ...]; extra: shown above the buttons (the coins won)

const W := 350.0
const SHEET_EDGE := Vector4(150, 215, 150, 215)   # the sheet's corners kept as drawn (its px): ornaments, finials
const SHEET_PAD := Vector4(28, 50, 28, 50)        # its content inside the torn edge, points
const OPENING := Rect2(0.0133, 0.0809, 0.9734, 0.8609)   # the frame's opening (shares of card_frame.png)

static func show(lines: Array, accent: String, buttons: Array, extra: Control = null) -> VBoxContainer:
	var v := Ov.card(W)
	var panel := v.get_parent() as PanelContainer
	var sheet: Texture2D = load(MaidenView.DIR + "card_sheet.png")
	var b := KitBox.new()
	b.tex = sheet
	b.margin = SHEET_EDGE
	b.s = sheet.get_width() / W
	b.tile = false
	b.content_margin_left = SHEET_PAD.x
	b.content_margin_top = SHEET_PAD.y
	b.content_margin_right = SHEET_PAD.z
	b.content_margin_bottom = SHEET_PAD.w
	panel.add_theme_stylebox_override("panel", b)
	v.add_theme_constant_override("separation", 10)
	v.add_child(_picture(W - SHEET_PAD.x - SHEET_PAD.z))
	var t := Kit.label("The Fire Maiden", 28, UI.display, Kit.AMBER)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_color_override("font_shadow_color", Color(1.0, 0.45, 0.1, 0.5))
	t.add_theme_constant_override("shadow_offset_x", 0)
	t.add_theme_constant_override("shadow_offset_y", 0)
	t.add_theme_constant_override("shadow_outline_size", 10)
	v.add_child(t)
	v.add_child(divider(220))
	for s in lines:
		var l := Kit.label(String(s), 15, UI.body, Kit.CREAM)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
	if accent != "":
		var a := Kit.label(accent, 15, UI.body_bold, Kit.AMBER)
		a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		a.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(a)
	v.add_child(divider(160))
	if extra: v.add_child(extra)
	for bt in buttons:
		v.add_child(Ov.btn(String(bt[0]), String(bt[1]), bt[2]))
	return v

## the portrait in the brass frame: the picture fills the frame's opening, the frame lies over it, embers rise
static func _picture(w: float) -> Control:
	var fr: Texture2D = load(MaidenView.DIR + "card_frame.png")
	var size := Vector2(w, w * fr.get_height() / float(fr.get_width()))
	var root := Control.new()
	root.custom_minimum_size = size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hole := Rect2(OPENING.position * size, OPENING.size * size).grow(2.0)
	var clip := Control.new()
	clip.clip_contents = true
	clip.position = hole.position
	clip.size = hole.size
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(clip)
	var pic := TextureRect.new()
	pic.texture = load(MaidenView.DIR + "portrait.png")
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.size = hole.size
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(pic)
	var em := Embers.new()
	em.size = hole.size
	clip.add_child(em)
	var frame := TextureRect.new()
	frame.texture = fr
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.size = size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(frame)
	return root

## the brass bar under the genes' tags (Reveal.chip: its notched ends as drawn, the middle stretched), as a divider
static func divider(w: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, 7)
	c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var tex := Kit.tex("underline")
	c.draw.connect(func():
		const H := 7.0
		var ts := tex.get_size()
		var e := ts.y * 4.0 / 8.0
		var ep := H * 4.0 / 8.0
		c.draw_texture_rect_region(tex, Rect2(0, 0, ep, H), Rect2(0, 0, e, ts.y))
		c.draw_texture_rect_region(tex, Rect2(ep, 0, c.size.x - ep * 2, H), Rect2(e, 0, ts.x - e * 2, ts.y))
		c.draw_texture_rect_region(tex, Rect2(c.size.x - ep, 0, ep, H), Rect2(ts.x - e, 0, e, ts.y)))
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
			_p.append([Vector2(size.x * randf_range(0.3, 0.7), size.y * randf_range(0.7, 0.88)),
				Vector2(randf_range(-12, 12), randf_range(-45, -20)), randf_range(1.2, 2.6)])
		for e in _p:
			e[0] += e[1] * dt
			e[1].x += sin(Time.get_ticks_msec() / 400.0 + e[0].y * 0.05) * 8.0 * dt
			e[2] -= dt
		_p = _p.filter(func(e: Array) -> bool: return float(e[2]) > 0.0 and e[0].y > 0.0)
		queue_redraw()
	func _draw() -> void:
		for e in _p:
			var k := clampf(float(e[2]) / 1.5, 0.0, 1.0)
			var r := 2.0 + 4.0 * k
			draw_texture_rect(_glow, Rect2(e[0] - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(1.0, 0.42 + 0.25 * k, 0.12, k))
