extends Node
## Shared look: fonts, the app theme, glass panels and the chunky game buttons.

var display: FontVariation   # Nunito Sans black — titles, numbers
var body: FontVariation      # Nunito Sans — everything else
var body_bold: FontVariation
var theme: Theme

const GOLD := Color("#f5c04a")
const INK := Color("#eef2f8")
const MUTED := Color("#9fb0c8")
const GOOD := Color("#4cd480")

func _ready() -> void:
	display = _font("res://assets/fonts/NunitoSans.ttf", 900)
	body = _font("res://assets/fonts/NunitoSans.ttf", 600)
	body_bold = _font("res://assets/fonts/NunitoSans.ttf", 800)
	theme = Theme.new()
	theme.default_font = body
	theme.default_font_size = 16
	theme.set_color("font_color", "Label", INK)
	theme.set_color("font_color", "Button", INK)
	theme.set_stylebox("normal", "Button", glass(14))
	theme.set_stylebox("hover", "Button", glass(14, 0.75))
	theme.set_stylebox("pressed", "Button", glass(14, 0.85))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_stylebox("disabled", "Button", glass(14, 0.4))
	theme.set_stylebox("panel", "PanelContainer", glass(16))
	get_tree().root.theme = theme

## the screen's unsafe edges in layout units: the Dynamic Island / notch on top, the home indicator below.
## Only phones report them; screenshots on a desktop can fake one with the notch=TOP,BOTTOM key.
var fake_insets := Vector2(-1, -1)

func safe_top() -> float:
	return _insets().x

func safe_bottom() -> float:
	return _insets().y

func _insets() -> Vector2:
	if fake_insets.x >= 0.0:
		return fake_insets
	if not OS.has_feature("mobile"):
		return Vector2.ZERO
	var win := DisplayServer.window_get_size()
	if win.y <= 0:
		return Vector2.ZERO
	var sa := DisplayServer.get_display_safe_area()
	var k := get_tree().root.get_visible_rect().size.y / float(win.y)
	return Vector2(maxf(0.0, sa.position.y) * k, maxf(0.0, win.y - sa.end.y) * k)

## a scroll area for touch: dragged with the finger, no desktop-style scroll bars
func scroller(horizontal := false) -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER if horizontal else ScrollContainer.SCROLL_MODE_DISABLED
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED if horizontal else ScrollContainer.SCROLL_MODE_SHOW_NEVER
	return sc

func _font(path: String, weight: int) -> FontVariation:
	var f := FontVariation.new()
	f.base_font = load(path)
	f.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return f

func glass(radius := 16, alpha := 0.66) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.055, 0.08, 0.125, alpha)
	s.border_color = Color(1, 1, 1, 0.14)
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 8
	s.shadow_offset = Vector2(0, 4)
	s.set_content_margin_all(10)
	return s

## the big game button: gold, green, purple or plain glass
func button_style(kind: String, pressed := false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	var top: Color = {gold = Color("#ffd77a"), green = Color("#4fcf6c"), purple = Color("#b48cff"), red = Color("#ff7a7a")}.get(kind, Color("#2c3c5a"))
	var edge: Color = {gold = Color("#7a4c08"), green = Color("#0f4a22"), purple = Color("#3e1f78"), red = Color("#6a1a1a")}.get(kind, Color("#0a0f18"))
	s.bg_color = top
	s.set_corner_radius_all(18)
	s.border_color = edge
	s.border_width_bottom = 2 if pressed else 6
	s.set_content_margin_all(12)
	s.content_margin_top = 14 if pressed else 12
	s.shadow_color = Color(top, 0.35) if kind in ["gold", "green"] else Color(0, 0, 0, 0.3)
	s.shadow_size = 10
	return s

## a quiet button for cards: dark glass with a thin coloured rim and coloured text (soft_gold, soft_green, ...);
## ghost_gold, ghost_purple...: quieter still, a neutral hairline and only the text in colour
func soft_style(c: Color, a: float, rim := 0.55) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(c, a)
	s.set_corner_radius_all(16)
	s.set_border_width_all(1)
	s.border_color = Color(c, rim)
	s.set_content_margin_all(10)
	return s

func button(text: String, kind := "glass", font_size := 20) -> Button:
	var b := Button.new()
	b.text = text
	if kind.begins_with("soft_") or kind.begins_with("ghost_"):
		var ghost := kind.begins_with("ghost_")
		var c: Color = {gold = GOLD, green = GOOD, purple = Color("#b48cff")}.get(kind.get_slice("_", 1), INK)
		b.add_theme_font_override("font", body_bold)
		b.add_theme_font_size_override("font_size", font_size)
		for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(st, c.lightened(0.15))
		b.add_theme_color_override("font_disabled_color", Color(c, 0.4))
		var bc := Color.WHITE if ghost else c
		var a0 := 0.03 if ghost else 0.08
		var rim := 0.12 if ghost else 0.55
		b.add_theme_stylebox_override("normal", soft_style(bc, a0, rim))
		b.add_theme_stylebox_override("hover", soft_style(bc, a0 * 1.8, rim))
		b.add_theme_stylebox_override("pressed", soft_style(bc, a0 * 3.0, rim))
		b.add_theme_stylebox_override("disabled", soft_style(bc, a0 * 0.4, rim))
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.pressed.connect(func():
			Sfx.buzz(8)
			Sfx.play("click"))
		return b
	b.add_theme_font_override("font", display if kind != "glass" else body_bold)
	b.add_theme_font_size_override("font_size", font_size)
	var dark := kind in ["gold", "green"]
	var fc := Color("#2a1a00") if kind == "gold" else Color("#06260f") if kind == "green" else INK
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(st, fc)
	b.add_theme_color_override("font_disabled_color", Color(fc, 0.5) if dark else MUTED)
	if kind == "glass":
		b.add_theme_stylebox_override("normal", glass(16, 0.7))
		b.add_theme_stylebox_override("hover", glass(16, 0.8))
		b.add_theme_stylebox_override("pressed", glass(16, 0.9))
		b.add_theme_stylebox_override("disabled", glass(16, 0.35))
	else:
		b.add_theme_stylebox_override("normal", button_style(kind))
		b.add_theme_stylebox_override("hover", button_style(kind))
		b.add_theme_stylebox_override("pressed", button_style(kind, true))
		var dis := button_style(kind)
		dis.bg_color = Color(dis.bg_color, 0.45)
		b.add_theme_stylebox_override("disabled", dis)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(func():
		Sfx.buzz(8)
		Sfx.play("click"))
	return b

# ---------------------------------------------------------------- the stone look (marble and slate)

const STONE_INK := Color("#3b332a")       # text on marble
const STONE_MUTED := Color("#7d7264")

## a pale marble surface: buttons, pills, the moves disc
func marble(radius := 18, raised := true) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color("#ece6dc")
	s.border_color = Color("#cfc4b2")
	s.set_border_width_all(1)
	s.border_width_bottom = 4 if raised else 1
	s.set_corner_radius_all(radius)
	s.shadow_color = Color(0.25, 0.18, 0.1, 0.22)
	s.shadow_size = 10
	s.shadow_offset = Vector2(3, 5)
	s.set_content_margin_all(10)
	return s

## dark slate with a thin gold rim: the goals panel
func slate(radius := 22) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color("#2c2f33")
	s.border_color = Color("#c9a35a")
	s.set_border_width_all(2)
	s.set_corner_radius_all(radius)
	s.shadow_color = Color(0.2, 0.14, 0.08, 0.3)
	s.shadow_size = 12
	s.shadow_offset = Vector2(3, 6)
	s.set_content_margin_all(10)
	return s

func marble_button(text: String, font_size := 18) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", body_bold)
	b.add_theme_font_size_override("font_size", font_size)
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(st, STONE_INK)
	b.add_theme_stylebox_override("normal", marble())
	b.add_theme_stylebox_override("hover", marble())
	var pr := marble(18, false)
	pr.bg_color = Color("#e2dbcf")
	b.add_theme_stylebox_override("pressed", pr)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(func():
		Sfx.buzz(8)
		Sfx.play("click"))
	return b

func label(text: String, size := 16, font: Font = null, col := INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font if font else body)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l

func title(text: String, size := 22) -> Label:
	var l := label(text, size, display)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_y", 3)
	l.add_theme_constant_override("shadow_outline_size", 6)
	return l

## a Control that paints itself with `fn(ci)` — handy for icons drawn with GemArt
func icon(size_px: float, fn: Callable) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(size_px, size_px)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func(): fn.call(c))
	return c

func fmt(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out

func plural(n: int, one: String, many: String) -> String:
	return one if absi(n) == 1 else many

func coins(n: int) -> String:
	return "%s %s" % [fmt(n), plural(n, "coin", "coins")]

func moves_text(n: int) -> String:
	return "%d %s" % [n, plural(n, "move", "moves")]
