class_name Kit
extends RefCounted
## The drawn UI kit (art/ui_kit: GPT sheets cut by kit_cut.py → assets/ui/kit): dark slate in iron and aged brass.
## Frames are KitBox nine-patches, so every plate, button and window keeps its corners on any phone and any size.

const DIR := "res://assets/ui/kit/"
## frame -> [left, top, right, bottom corners (picture px), picture px per point]
const FRAMES := {
	window = [86, 86, 86, 86, 3.6], card = [48, 48, 48, 48, 3.4], tab = [48, 48, 48, 48, 3.4],
	tab_on = [50, 50, 50, 50, 3.4], btn_green = [66, 44, 66, 44, 3.0], btn_slate = [66, 44, 66, 44, 3.0], btn_gold = [56, 44, 56, 44, 3.0],
	btn_dark = [46, 38, 46, 38, 3.0], title = [56, 36, 56, 36, 3.0], capsule = [72, 44, 72, 44, 3.2],
	sq_gold = [36, 36, 36, 36, 3.0], sq_dark = [36, 36, 36, 36, 3.0],
}
## plates whose round ends must keep their shape: scaled to the height, stretched only sideways (KitBox.fit_h)
const FIT_H := ["capsule"]
## plates with a round rivet on each short end: half the rivet's height in picture px, kept as drawn (KitBox.pin)
const PIN := {btn_green = 18.0, btn_slate = 18.0, title = 15.0}
## big panels drawn as a hollow frame over a tiled slate (art/ui_kit/slate_fill.py): frame -> [frame picture, tile]
const FILLS := {window = ["window_frame", "slate"]}
## frames whose middle is seamless (art/ui_kit/seam_mid.py) and repeats along these axes instead of stretching
const TILE := {btn_green = "x", btn_slate = "x", btn_dark = "xy", title = "x", card = "xy", tab = "xy"}
const CREAM := Color("#f3e6c8")       # text on slate
const AMBER := Color("#e6c47e")       # calm brass, like the frames (was #ffc95a)
const DIM := Color("#a89c86")
const ON_GREEN := Color("#f6ffe8")

static var _tex := {}

static func tex(name: String) -> Texture2D:
	if not _tex.has(name):
		_tex[name] = load(DIR + name + ".png")
	return _tex[name]

## a frame as a style box; pad: the inner margin (points) around what sits in it, -1: just inside the frame.
## "<frame>_calm" is the same frame with calmer brass, matching the card frame's rim (art/ui_kit/calm_rim.py)
static func box(name: String, pad := -1.0, tint := Color.WHITE) -> KitBox:
	var pic := name
	name = name.trim_suffix("_calm")
	var f: Array = FRAMES[name]
	var b := KitBox.new()
	b.tex = tex(pic)
	if FILLS.has(name):
		var fl: Array = FILLS[name]
		b.tex = tex(fl[0])
		b.fill = tex(fl[1])
	b.margin = Vector4(float(f[0]), float(f[1]), float(f[2]), float(f[3]))
	b.s = float(f[4])
	b.modulate = tint
	b.tile = false     # tiled slate showed its seams as bands; stretched it reads as one stone
	b.fit_h = name in FIT_H
	b.pin = float(PIN.get(name, 0.0))
	var tl: String = TILE.get(name, "")
	b.tile_x = "x" in tl
	b.tile_y = "y" in tl
	var m := Vector4(b.margin.x, b.margin.y, b.margin.z, b.margin.w) / b.s
	if pad >= 0.0: m = Vector4(pad, pad, pad, pad)
	b.content_margin_left = m.x
	b.content_margin_top = m.y
	b.content_margin_right = m.z
	b.content_margin_bottom = m.w
	return b

## an icon from the kit (icons/<name>), fitted into a square of `size` points
static func icon(name: String, size: float) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex("icons/" + name)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(size, size)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return t

## the icon of a resource: coins, lives, iron, or the mine's own ore (gold at Old Adit, copper at Copper Mountain)
static func res_icon(kind: String, size: float) -> TextureRect:
	match kind:
		"coin": return icon("coin", size)
		"heart": return icon("heart", size)
		"iron": return icon("iron", size)
	return icon("copper" if Save.area() == 1 else "gold", size)

## a button in a kit frame: btn_green (the main action), btn_gold, btn_dark, sq_gold, sq_dark, card, tab...
## Pressed it sinks a little darker; disabled it greys out.
static func button(text: String, frame := "btn_dark", font_size := 18, pad := -1.0) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", UI.display)
	b.add_theme_font_size_override("font_size", font_size)
	var kind := frame.trim_suffix("_calm")
	var fc := ON_GREEN if kind == "btn_green" else Color("#2b1a04") if kind in ["btn_gold", "sq_gold"] else CREAM
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(st, fc)
	b.add_theme_color_override("font_disabled_color", Color(fc, 0.4))
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55) if kind != "btn_gold" else Color(1, 0.9, 0.6, 0.3))
	b.add_theme_constant_override("outline_size", 5 if kind != "btn_gold" else 0)
	b.add_theme_stylebox_override("normal", box(frame, pad))
	b.add_theme_stylebox_override("hover", box(frame, pad))
	b.add_theme_stylebox_override("pressed", box(frame, pad, Color(0.78, 0.74, 0.68)))
	b.add_theme_stylebox_override("disabled", box(frame, pad, Color(0.5, 0.5, 0.5, 0.75)))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(func():
		Sfx.buzz(8)
		Sfx.play("click"))
	return b

## a square button with a kit icon in it (close, plus, minus, gear...)
static func icon_button(name: String, size := 44.0, frame := "sq_dark") -> Button:
	var b := button("", frame, 16, 0.0)
	b.custom_minimum_size = Vector2(size, size)
	var ic := icon(name, size * 0.56)
	ic.size = Vector2(size * 0.56, size * 0.56)
	ic.position = Vector2(size * 0.22, size * 0.22)
	b.add_child(ic)
	b.draw.connect(func(): ic.modulate = Color(1, 1, 1, 0.35) if b.disabled else Color.WHITE)
	return b

## a label in the kit's colours: cream on slate, with a dark outline so it reads over the pictures
static func label(text: String, size := 16, font: Font = null, col := CREAM) -> Label:
	var l := UI.label(text, size, font if font else UI.body_bold, col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("outline_size", 4)
	return l

## the old miner's lantern hanging on a chain inside the top-left corner of a frame (the level window), swinging and
## flickering (KitLantern); `on` is a plain Control (not a container) holding the frame at its origin
static func lantern(on: Control, height := 60.0) -> void:
	var l := KitLantern.new(height)
	l.position = Vector2(40, 6)     # the hook, on the frame's top rim just past the corner plate
	on.add_child(l)

## a thin brass rule under a title: a strip of the window frame's own brass rim (art/ui_kit/rule.py), fading out to
## its ends, with a small rivet near each end
static func rule(width := 220.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(width, 8)
	c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var t := tex("rule")
	c.draw.connect(func():
		var w := c.size.x
		c.draw_texture_rect(t, Rect2(0, 1.5, w, 5.0), false)
		var brass := Color("#d9a94e")
		var dark := Color(0.05, 0.03, 0.01, 0.85)
		for x: float in [w * 0.16, w * 0.84]:
			c.draw_circle(Vector2(x, 4), 2.6, dark)
			c.draw_circle(Vector2(x, 4), 1.8, brass.darkened(0.2))
			c.draw_circle(Vector2(x - 0.6, 3.4), 0.7, brass.lightened(0.5)))
	return c

## a brass chain from a to b (the name plate's chains): links in turn face-on and edge-on
static func chain(ci: CanvasItem, a: Vector2, b: Vector2, link := 5.0) -> void:
	var brass := Color("#c99a4a")
	var dark := Color("#2a1a08")
	var d := b - a
	var n := maxi(1, int(d.length() / link))
	var ang := d.angle() - PI / 2
	for i in n:
		var c := a + d * (i + 0.5) / n
		var r := Vector2(1.7, link * 0.62) if i % 2 == 0 else Vector2(0.7, link * 0.62)
		for pass_i in 2:
			var rr := r + Vector2(0.8, 0.8) if pass_i == 0 else r
			var pts := PackedVector2Array()
			for k in 13:
				var t := TAU * k / 12.0
				pts.append(c + Vector2(cos(t) * rr.x, sin(t) * rr.y).rotated(ang))
			ci.draw_polyline(pts, dark if pass_i == 0 else brass, 1.6 if pass_i == 0 else 1.0, true)

## a screen's name (the mine's, the museum's…) on a slate plate in its brass frame, in the titles' font (Nunito Sans Black) set in spaced capitals
static func title_plate(n: String) -> Control:
	var p := PanelContainer.new()
	var st := box("title", 0.0)
	st.content_margin_left = 20
	st.content_margin_right = 20
	st.content_margin_top = 4
	st.content_margin_bottom = 5
	p.add_theme_stylebox_override("panel", st)
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font := FontVariation.new()
	font.base_font = UI.display.base_font       # (a variation of a variation loses its weight: copy it over)
	font.variation_opentype = UI.display.variation_opentype
	font.spacing_glyph = 1
	var l := label(n.to_upper(), 19, font, AMBER)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("shadow_offset_y", 2)
	p.add_child(l)
	return p

## a plate hung under the top bar on two brass chains from the middles of its coins' and ore capsules (the bar's
## "hooks"), as wide as the chains are apart; it sways a touch about the chains' tops
static func hanging(p: Control, bar: Control) -> Control:
	var hooks: Array = bar.get_meta("hooks", [])
	var slot := Control.new()
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var sw := Control.new()     # the swinging part: the chains and the plate (a plain Control, so nothing resets it)
	sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(sw)
	sw.add_child(p)
	const INSET := 24.0         # from the plate's ends to its chains
	var ends := func() -> Array:
		# the hooks in the swinging part's own space: [left x, right x, top y]
		var a: Control = hooks[0]
		var b: Control = hooks[1]
		var ga := a.get_global_rect()
		var gb := b.get_global_rect()
		var o := slot.get_global_rect().position
		# under the middle of the capsule's slate, where its number is centred (Chrome.capsule)
		return [ga.position.x + Chrome.capsule_mid(ga.size.x) - o.x, gb.position.x + Chrome.capsule_mid(gb.size.x) - o.x, ga.end.y - 5.0 - o.y]
	var fit := func():
		var m := p.get_combined_minimum_size()
		if hooks.size() == 2:
			var apart: float = (hooks[1] as Control).get_global_rect().get_center().x - (hooks[0] as Control).get_global_rect().get_center().x
			m.x = maxf(m.x, apart + INSET * 2)
		p.custom_minimum_size.x = m.x
		slot.custom_minimum_size = m
		sw.size = m
		p.size = m
	bar.resized.connect(func(): fit.call_deferred())
	# the plate's middle under the middle between the chains (the slot itself is centred on the screen)
	var place := func():
		if hooks.size() == 2 and slot.is_inside_tree():
			var e: Array = ends.call()
			sw.position.x = (float(e[0]) + float(e[1])) / 2 - sw.size.x / 2
		sw.queue_redraw()
	slot.item_rect_changed.connect(func(): place.call_deferred())
	fit.call()
	sw.draw.connect(func():
		var xs: Array = [INSET, sw.size.x - INSET]
		var top := -30.0
		if hooks.size() == 2 and slot.is_inside_tree():
			var e: Array = ends.call()
			xs = [float(e[0]) - sw.position.x, float(e[1]) - sw.position.x]
			top = e[2]
		sw.pivot_offset = Vector2((float(xs[0]) + float(xs[1])) / 2, top)
		for x: float in xs:
			chain(sw, Vector2(x, top), Vector2(x, 5)))
	var tw := sw.create_tween().set_loops()
	tw.tween_property(sw, "rotation", 0.012, 2.2).set_trans(Tween.TRANS_SINE)
	tw.tween_property(sw, "rotation", -0.012, 2.2).set_trans(Tween.TRANS_SINE)
	return slot

## tabs in the kit: a row of slate tiles in iron, the chosen one lit warm in brass (Collection, Depot)
static func tabs(list: Array, active: String, on_pick: Callable) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	for t in list:
		var id: String = t[0]
		var on := id == active
		var b := button(t[1], "tab_on" if on else "tab", 14, 0.0)
		b.add_theme_font_override("font", UI.body_bold)
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(c, AMBER if on else DIM)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 40)
		b.pressed.connect(func(): if not on: on_pick.call(id))
		h.add_child(b)
	return h
