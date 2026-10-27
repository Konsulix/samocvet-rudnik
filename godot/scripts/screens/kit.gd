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
const CREAM := Color("#f3e6c8")       # text on slate
const AMBER := Color("#ffc95a")
const DIM := Color("#a89c86")
const ON_GREEN := Color("#f6ffe8")

static var _tex := {}

static func tex(name: String) -> Texture2D:
	if not _tex.has(name):
		_tex[name] = load(DIR + name + ".png")
	return _tex[name]

## a frame as a style box; pad: the inner margin (points) around what sits in it, -1: just inside the frame
static func box(name: String, pad := -1.0, tint := Color.WHITE) -> KitBox:
	var f: Array = FRAMES[name]
	var b := KitBox.new()
	b.tex = tex(name)
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
	var fc := ON_GREEN if frame == "btn_green" else Color("#2b1a04") if frame in ["btn_gold", "sq_gold"] else CREAM
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(st, fc)
	b.add_theme_color_override("font_disabled_color", Color(fc, 0.4))
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55) if frame != "btn_gold" else Color(1, 0.9, 0.6, 0.3))
	b.add_theme_constant_override("outline_size", 5 if frame != "btn_gold" else 0)
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
