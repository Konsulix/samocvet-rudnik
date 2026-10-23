class_name Chrome
extends RefCounted
## Pieces every screen shares: the lives / coins / stars pills and the bottom tab bar.

## lives (with the time to the next one), coins and stars, as little glass pills
static func pills() -> HBoxContainer:
	Save.tick_lives()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mins := Save.minutes_to_life()
	h.add_child(pill("heart", str(Save.d.lives) + (" · %d min" % mins if mins else "")))
	h.add_child(pill("coin", UI.fmt(Save.d.coins)))
	h.add_child(pill("star", str(Save.d.stars)))
	return h

static func pill(kind: String, text: String) -> PanelContainer:
	var p := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.04, 0.06, 0.1, 0.72)
	st.border_color = Color(1, 1, 1, 0.12)
	st.set_border_width_all(1)
	st.set_corner_radius_all(16)
	st.content_margin_left = 4
	st.content_margin_right = 10
	st.content_margin_top = 3
	st.content_margin_bottom = 3
	p.add_theme_stylebox_override("panel", st)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.add_child(UI.icon(22, func(ci: Control): coin_icon(ci, kind, Vector2(11, 11), 11)))
	h.add_child(UI.label(text, 14, UI.body_bold))
	p.add_child(h)
	return p

## the round badges: a heart, a coin, a star
static func coin_icon(ci: CanvasItem, kind: String, c: Vector2, r: float) -> void:
	var col: Color = {heart = Color("#e2334f"), coin = Color("#f2b630"), star = Color("#7a5cff")}.get(kind, Color.GRAY)
	ci.draw_circle(c, r, col.darkened(0.35))
	ci.draw_circle(c - Vector2(0, 1), r - 1.5, col)
	var w := Color(1, 1, 1, 0.95)
	match kind:
		"heart":
			var pts := PackedVector2Array()
			for i in 24:
				var a := i / 24.0 * TAU
				var x := 16 * pow(sin(a), 3)
				var y := -(13 * cos(a) - 5 * cos(2 * a) - 2 * cos(3 * a) - cos(4 * a))
				pts.append(c + Vector2(x, y) * r / 30.0)
			ci.draw_colored_polygon(pts, w)
		"coin":
			ci.draw_arc(c, r * 0.58, 0, TAU, 18, Color(1, 0.95, 0.75, 0.9), 1.6, true)
			ci.draw_string(UI.display, c + Vector2(-r * 0.3, r * 0.36), "$", HORIZONTAL_ALIGNMENT_LEFT, -1, int(r * 1.0), Color("#6a4204"))
		_:
			var pts2 := PackedVector2Array()
			for i in 10:
				var a := -PI / 2 + i * PI / 5
				pts2.append(c + Vector2(cos(a), sin(a)) * (r * 0.68 if i % 2 == 0 else r * 0.3))
			ci.draw_colored_polygon(pts2, w)

## the bottom tab bar: mine, depot, museum
static func nav_bar(active: String, on_go: Callable) -> PanelContainer:
	var bar := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color("#151d2c")
	st.border_color = Color(1, 1, 1, 0.1)
	st.border_width_top = 1
	st.content_margin_left = 10
	st.content_margin_right = 10
	st.content_margin_top = 6
	st.content_margin_bottom = 12
	st.shadow_color = Color(0, 0, 0, 0.45)
	st.shadow_size = 18
	bar.add_theme_stylebox_override("panel", st)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	for tab in [["home", "Mine"], ["depot", "Machines"], ["museum", "Collection"]]:
		var id: String = tab[0]
		var on := id == active
		var b := Button.new()
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 58)
		var bs := StyleBoxFlat.new()
		bs.set_corner_radius_all(14)
		bs.bg_color = Color("#26344e") if on else Color(0, 0, 0, 0)
		if on:
			bs.border_color = Color("#e3a51e")
			bs.border_width_bottom = 3
		for s in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(s, bs)
		var col := Color("#ffd77a") if on else Color("#9fb0c8")
		var v := VBoxContainer.new()
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_theme_constant_override("separation", 1)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ic := UI.icon(26, func(ci: Control): tab_icon(ci, id, col))
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(ic)
		var l := UI.label(tab[1], 12, UI.body_bold, col)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
		b.add_child(v)
		b.pressed.connect(func():
			Sfx.buzz(8)
			if not on: on_go.call(id))
		h.add_child(b)
	bar.add_child(h)
	return bar

static func tab_icon(ci: CanvasItem, id: String, col: Color) -> void:
	var w := 2.0
	match id:
		"home":
			ci.draw_line(Vector2(3, 22), Vector2(23, 22), col, w, true)
			var arch := PackedVector2Array([Vector2(5, 22), Vector2(5, 12)])
			for i in 13:
				var a := PI + i / 12.0 * PI
				arch.append(Vector2(13, 12) + Vector2(cos(a), sin(a)) * 8)
			arch.append(Vector2(21, 22))
			ci.draw_polyline(arch, col, w, true)
			ci.draw_polyline(PackedVector2Array([Vector2(10, 22), Vector2(10, 16), Vector2(16, 16), Vector2(16, 22)]), col, w, true)
		"depot":
			ci.draw_polyline(PackedVector2Array([Vector2(15, 5), Vector2(21, 11), Vector2(18, 12), Vector2(14, 8), Vector2(15, 5)]), col, w, true)
			ci.draw_polyline(PackedVector2Array([Vector2(14, 8), Vector2(5, 17), Vector2(9, 21), Vector2(18, 12)]), col, w, true)
			ci.draw_line(Vector2(7, 19), Vector2(4, 22), col, w, true)
		_:
			var pts := PackedVector2Array([Vector2(7, 4), Vector2(19, 4), Vector2(23, 10), Vector2(13, 23), Vector2(3, 10)])
			ci.draw_polyline(GemArt.closed(pts), col, w, true)
			ci.draw_polyline(PackedVector2Array([Vector2(3, 10), Vector2(23, 10)]), col, w, true)
			ci.draw_polyline(PackedVector2Array([Vector2(10, 4), Vector2(9, 10), Vector2(13, 23), Vector2(17, 10), Vector2(16, 4)]), col, 1.4, true)
