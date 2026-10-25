class_name Chrome
extends RefCounted
## Pieces every screen shares: the lives / coins / ore pills and the bottom tab bar.

## the bar on top of every screen, the same everywhere: lives, coins, iron and the mine's own ore sharing the width
## in even plates, a round sound button on the right
static func top_bar() -> HBoxContainer:
	Save.tick_lives()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mins := Save.minutes_to_life()
	h.add_child(plate("heart", str(Save.d.lives) if not mins else "%d · %dm" % [Save.d.lives, mins]))
	h.add_child(plate("coin", UI.fmt(Save.d.coins)))
	h.add_child(plate("iron", str(Save.d.fe)))
	h.add_child(plate("ore", str(Save.d.ore)))
	var snd := UI.button("♪" if not Save.d.mute else "×", "glass", 17)
	snd.custom_minimum_size = Vector2(38, 38)
	for k in ["normal", "hover", "pressed", "disabled"]:
		var st := UI.glass(19, 0.78)
		st.set_content_margin_all(0)
		snd.add_theme_stylebox_override(k, st)
	# hold it for a second: the diagnostics card (Diag)
	var held := [0]
	snd.button_down.connect(func(): held[0] = Time.get_ticks_msec())
	snd.button_up.connect(func():
		if Time.get_ticks_msec() - held[0] >= 900:
			held[0] = -1
			Diag.show_card())
	snd.pressed.connect(func():
		if held[0] == -1: return
		Save.d.mute = not Save.d.mute
		Save.persist()
		Sfx.apply_mute()
		snd.text = "♪" if not Save.d.mute else "×")
	h.add_child(snd)
	return h

## one resource plate: a dark rounded bar with its round badge sitting over the left end
static func plate(kind: String, text: String) -> Control:
	var w := Control.new()
	w.custom_minimum_size = Vector2(0, 38)
	w.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := Panel.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.04, 0.06, 0.1, 0.78)
	st.border_color = Color(1, 1, 1, 0.14)
	st.set_border_width_all(1)
	st.set_corner_radius_all(14)
	bg.add_theme_stylebox_override("panel", st)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.offset_left = 12
	bg.offset_top = 4
	bg.offset_bottom = -4
	w.add_child(bg)
	var l := UI.label(text, 15, UI.body_bold)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.offset_left = 30
	l.offset_right = -4
	l.clip_text = true
	w.add_child(l)
	var ic := UI.icon(32, func(ci: Control): coin_icon(ci, kind, Vector2(16, 16), 15))
	ic.position = Vector2(0, 3)
	w.add_child(ic)
	return w

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

## the round badges: a heart, a coin, iron (a steel cube), the mine's own ore (a nugget in the mine's colour)
static func coin_icon(ci: CanvasItem, kind: String, c: Vector2, r: float) -> void:
	var col: Color = {heart = Color("#e2334f"), coin = Color("#f2b630"), iron = Color("#5f6d80")}.get(kind, Color.GRAY)
	if kind == "ore": col = Color.html(Data.ore(Save.area()).c)
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
		"iron":
			# a cube seen from a corner: lit top, two darker sides
			var e := r * 0.52
			var top := c + Vector2(0, -e)
			var mid := c + Vector2(0, e * 0.1)
			var lt := c + Vector2(-e * 0.92, -e * 0.45)
			var rt := c + Vector2(e * 0.92, -e * 0.45)
			ci.draw_colored_polygon(PackedVector2Array([top, rt, mid, lt]), Color(0.93, 0.96, 1.0))
			ci.draw_colored_polygon(PackedVector2Array([lt, mid, mid + Vector2(0, e * 1.0), lt + Vector2(0, e * 1.0)]), Color(0.66, 0.72, 0.8))
			ci.draw_colored_polygon(PackedVector2Array([mid, rt, rt + Vector2(0, e * 1.0), mid + Vector2(0, e * 1.0)]), Color(0.45, 0.5, 0.58))
		_:
			# a lumpy nugget with a highlight
			var pts2 := PackedVector2Array()
			for i in 9:
				var a := i / 9.0 * TAU
				pts2.append(c + Vector2(cos(a) * 1.15, sin(a) * 0.9) * r * (0.5 + 0.1 * sin(i * 2.7)))
			var oc := Color.html(Data.ore(Save.area()).c)
			ci.draw_colored_polygon(pts2, oc.lightened(0.65))
			ci.draw_circle(c + Vector2(-r * 0.18, -r * 0.16), r * 0.15, Color(1, 1, 1, 0.9))

## the bottom tab bar: mine, depot, museum, three even segments edge to edge; the open one is lit,
## with a gold top edge, a bigger icon and its label, the others show just their icon
static func nav_bar(active: String, on_go: Callable) -> PanelContainer:
	var bar := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color("#151d2c")
	st.border_color = Color(1, 1, 1, 0.1)
	st.border_width_top = 1
	st.content_margin_left = 0
	st.content_margin_right = 0
	st.content_margin_top = 0
	st.content_margin_bottom = UI.safe_bottom()
	st.shadow_color = Color(0, 0, 0, 0.45)
	st.shadow_size = 18
	bar.add_theme_stylebox_override("panel", st)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 0)
	var tabs := [["home", "Mine"], ["depot", "Machines"], ["museum", "Collection"]]
	for ti in tabs.size():
		var tab: Array = tabs[ti]
		var id: String = tab[0]
		var on := id == active
		if ti > 0:
			var sep := ColorRect.new()
			sep.color = Color(1, 1, 1, 0.07)
			sep.custom_minimum_size = Vector2(1, 0)
			sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
			h.add_child(sep)
		var b := Button.new()
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 58)
		var bs := StyleBoxFlat.new()
		bs.bg_color = Color("#24324b") if on else Color(0, 0, 0, 0)
		if on:
			bs.border_color = Color("#f2b630")
			bs.border_width_top = 3
		for s in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(s, bs)
		var col := Color("#ffd77a") if on else Color("#7d8ba3")
		var v := VBoxContainer.new()
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_theme_constant_override("separation", 2)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var isz := 30.0 if on else 26.0
		var ic := UI.icon(isz, func(ci: Control):
			ci.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE * isz / 26.0)
			tab_icon(ci, id, col))
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(ic)
		if on:
			var l := UI.label(tab[1], 12, UI.body_bold, col)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			v.add_child(l)
		b.add_child(v)
		b.pressed.connect(func():
			Sfx.buzz(8)
			if not on:
				Sfx.play("tab")
				on_go.call(id))
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
