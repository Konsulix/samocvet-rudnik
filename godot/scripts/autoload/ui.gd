extends Node
## Shared look: fonts, the app theme, glass panels and the chunky game buttons.

var display: FontVariation   # Unbounded — titles, numbers
var body: FontVariation      # Nunito — everything else
var body_bold: FontVariation
var theme: Theme

const GOLD := Color("#f5c04a")
const INK := Color("#eef2f8")
const MUTED := Color("#9fb0c8")
const GOOD := Color("#4cd480")

func _ready() -> void:
	display = _font("res://assets/fonts/Unbounded.ttf", 800)
	body = _font("res://assets/fonts/Nunito.ttf", 700)
	body_bold = _font("res://assets/fonts/Nunito.ttf", 850)
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

func button(text: String, kind := "glass", font_size := 20) -> Button:
	var b := Button.new()
	b.text = text
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
	b.pressed.connect(func(): Sfx.buzz(8))
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
	b.pressed.connect(func(): Sfx.buzz(8))
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
		out = " " + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out

func plural(n: int, one: String, few: String, many: String) -> String:
	var a := absi(n) % 100
	var b := a % 10
	if a > 10 and a < 20: return many
	if b > 1 and b < 5: return few
	if b == 1: return one
	return many

func coins(n: int) -> String:
	return "%s %s" % [fmt(n), plural(n, "монета", "монеты", "монет")]

func moves_text(n: int) -> String:
	return "%d %s" % [n, plural(n, "ход", "хода", "ходов")]
