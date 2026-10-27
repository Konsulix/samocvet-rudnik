class_name Chrome
extends RefCounted
## Pieces every screen shares: the lives / coins / ore pills and the bottom tab bar.

## the bar on top of every screen, the same everywhere (the drawn kit): the miner's portrait with the player's
## level and the lives under it, then coins, iron and the mine's own ore in brass-rimmed capsules, the gear on the right
static func top_bar() -> HBoxContainer:
	Save.tick_lives()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(_portrait())
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(capsule("coin", UI.fmt(Save.d.coins)))
	row.add_child(capsule("iron", UI.fmt(Save.d.fe)))
	row.add_child(capsule("ore", UI.fmt(Save.d.ore)))
	# where the mine's name plate hangs from (Home._hanging): the coins' and the ore's capsules
	h.set_meta("hooks", [row.get_child(0), row.get_child(2)])
	var gear := Kit.icon_button("gear", 36)
	gear.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	# hold it for a second: the diagnostics card (Diag)
	var held := [0]
	gear.button_down.connect(func(): held[0] = Time.get_ticks_msec())
	gear.button_up.connect(func():
		if Time.get_ticks_msec() - held[0] >= 900:
			held[0] = -1
			Diag.show_card())
	gear.pressed.connect(func():
		if held[0] == -1: return
		settings())
	row.add_child(gear)
	right.add_child(row)
	h.add_child(right)
	return h

## the miner in his round iron frame, the player's level on a brass badge, the lives on a small plate under him
## the portrait frames' windows: [offset, size] as shares of the frame (from the bosses' avatar .json)
const PORTRAIT_INNER := {poloz = [0.25, 0.5], mistress = [0.2778, 0.4444]}

static func _portrait() -> Control:
	const F := 72.0
	var w := Control.new()
	w.custom_minimum_size = Vector2(F, F)
	w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# a square frame from the mine's boss board (the serpent at Old Adit, malachite and copper at Copper Mountain),
	# its window a dark slate with the miner in it (for now the helmet and pick; a portrait is to be drawn)
	var id := "mistress" if Save.area() == 1 else "poloz"
	var inner: Array = PORTRAIT_INNER[id]
	var o := F * float(inner[0])
	var n := F * float(inner[1])
	var back := ColorRect.new()
	back.color = Color("#17130f")
	back.position = Vector2(o - 1, o - 1)
	back.size = Vector2(n + 2, n + 2)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	w.add_child(back)
	var face := Kit.icon("equipment", n * 0.86)
	face.size = Vector2(n, n) * 0.86
	face.position = Vector2(o, o) + Vector2(n, n) * 0.07
	w.add_child(face)
	var frame := TextureRect.new()
	frame.texture = Kit.tex("portrait/" + id)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.size = Vector2(F, F)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# the Mistress's 1-pt pixel frame is stored ×3 so it scales down evenly (unscaled, its cells came out uneven)
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	w.add_child(frame)
	var mins := Save.minutes_to_life()
	# the lives: a heart on the frame's lower right corner with their number on it; while one is coming back,
	# the minutes left in small print under the portrait
	var heart := Kit.icon("heart", 32)
	heart.size = Vector2(32, 32)
	heart.position = Vector2(F - 20, F - 22)
	w.add_child(heart)
	var hn := Kit.label(str(Save.d.lives), 15, UI.display)
	hn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hn.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hn.size = Vector2(32, 28)
	hn.position = heart.position
	w.add_child(hn)
	if mins:
		var tl := Kit.label("+1 in %dm" % mins, 11, UI.body_bold, Kit.DIM)
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tl.size = Vector2(F + 20, 14)
		tl.position = Vector2(-10, F + 4)
		w.add_child(tl)
	return w

## a capsule's number sits between these insets (points): clear of the icon on the left, of the rivet on the right
const CAP_L := 24.0
const CAP_R := 12.0

## where along a capsule `w` points wide the middle of its slate is (the name plate's chains hang from there)
static func capsule_mid(w: float) -> float:
	return (CAP_L + w - CAP_R) / 2

## one resource (or the lives): a long brass-rimmed capsule, its icon sitting over the left end, the number
static func capsule(kind: String, text: String) -> Control:
	var w := Control.new()
	w.custom_minimum_size = Vector2(0, 36)
	w.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := Panel.new()
	bg.add_theme_stylebox_override("panel", Kit.box("capsule", 0.0))
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.offset_left = 12
	bg.offset_top = 3
	bg.offset_bottom = -3
	w.add_child(bg)
	var l := Kit.label(text, 13)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	# centred on the capsule's slate (its rims are as wide at both ends), clear of the icon over the left one
	l.offset_left = CAP_L
	l.offset_right = -CAP_R
	l.clip_text = true
	w.add_child(l)
	var ic := Kit.res_icon(kind, 30)
	ic.size = Vector2(30, 30)
	ic.position = Vector2(0, 3)
	w.add_child(ic)
	return w

## the gear: sound on or off (hold the gear for the diagnostics)
static func settings() -> void:
	var v := Ov.card(300)
	v.add_child(UI.title("Settings", 22))
	var snd := Ov.btn("Sound: on" if not Save.d.mute else "Sound: off", "glass", func(): pass)
	snd.pressed.connect(func():
		Save.d.mute = not Save.d.mute
		Save.persist()
		Sfx.apply_mute()
		snd.text = "Sound: on" if not Save.d.mute else "Sound: off")
	v.add_child(snd)
	# for testing: the diagnostics log (errors, slow frames, FPS; Copy) and the tester's panel (any depth, the boss…)
	v.add_child(Ov.btn("Logs", "glass", func(): Diag.show_card()))
	v.add_child(Ov.btn("Admin", "glass", func(): Admin.open()))
	v.add_child(Ov.btn("Close", "glass", func(): Ov.close()))

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
## the bottom bar (the drawn kit): the map of mines, the mine itself, the collection, the equipment — four slate
## tiles in iron frames on a dark ledge; the open one lit warm, with its icon a little bigger
static func nav_bar(active: String, on_go: Callable) -> PanelContainer:
	var bar := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color("#0d0c0b", 0.94)
	st.border_color = Color("#6b5530")
	st.border_width_top = 2
	st.content_margin_left = 6
	st.content_margin_right = 6
	st.content_margin_top = 6
	st.content_margin_bottom = 4 + UI.safe_bottom()
	st.shadow_color = Color(0, 0, 0, 0.5)
	st.shadow_size = 14
	bar.add_theme_stylebox_override("panel", st)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 5)
	var tabs := [["map", "Mines", "map"], ["home", "Mine", "mine"], ["museum", "Collection", "collection"], ["depot", "Equipment", "equipment"]]
	for tab: Array in tabs:
		var id: String = tab[0]
		var on := id == active
		var b := Button.new()
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 66)
		for s in ["normal", "hover", "focus"]:
			b.add_theme_stylebox_override(s, Kit.box("tab_on" if on else "tab", 0.0))
		b.add_theme_stylebox_override("pressed", Kit.box("tab_on" if on else "tab", 0.0, Color(0.8, 0.76, 0.7)))
		var v := VBoxContainer.new()
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_theme_constant_override("separation", 0)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ic := Kit.icon(String(tab[2]), 36.0 if on else 32.0)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		if not on: ic.modulate = Color(0.8, 0.78, 0.74)
		v.add_child(ic)
		var l := Kit.label(tab[1], 11, UI.body_bold, Kit.AMBER if on else Kit.DIM)
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

## the map of mines (for now a card): the mines in order, the one being worked marked, the next ones shut
static func mines_card() -> void:
	var v := Ov.card(330)
	v.add_child(UI.title("Mines", 22))
	var cur := Save.area()
	for a in Data.AREAS.size():
		var A: Dictionary = Data.AREAS[a]
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", Kit.box("tab_on" if a == cur else "card", 12.0))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		h.add_child(Kit.icon("mine" if a <= cur else "lock", 34))
		var t := VBoxContainer.new()
		t.add_theme_constant_override("separation", 0)
		t.add_child(Kit.label(String(A.n), 16, UI.display, Kit.AMBER if a == cur else Kit.CREAM if a < cur else Kit.DIM))
		t.add_child(Kit.label("worked now" if a == cur else "worked out" if a < cur else "not yet reached", 12, UI.body, Kit.DIM))
		h.add_child(t)
		row.add_child(h)
		v.add_child(row)
	v.add_child(Ov.btn("Close", "glass", func(): Ov.close()))

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
