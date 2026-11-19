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
	# a portrait or frame put on in the profile (or something new looked at) shows in the bar at once, not only on
	# the next screen: the portrait is rebuilt when what it shows changed (the save says "changed" on every write)
	var key := [_portrait_key()]
	var redo := func():
		if not is_instance_valid(h) or _portrait_key() == key[0]: return
		key[0] = _portrait_key()
		var old := h.get_child(0)
		var nw := _portrait()
		h.add_child(nw)
		h.move_child(nw, 0)
		old.queue_free()
	Save.changed.connect(redo)
	h.tree_exiting.connect(func():
		if Save.changed.is_connected(redo): Save.changed.disconnect(redo))
	return h

static func _portrait_key() -> String:
	return "%s|%s|%s|%d" % [Profile.frame().id, Profile.face().id, Profile.fresh().is_empty(), Save.d.lives]

## the player's portrait in the top bar: the frame and the face worn (Profile), the lives on its corner; a tap opens
## the miner's card (ProfileCard). Something earned and not yet looked at: the portrait glows
static func _portrait() -> Control:
	const F := 72.0
	var fid := String(Profile.frame().id)
	var w := portrait(F, fid, String(Profile.face().id), true)
	var tap := Button.new()
	tap.flat = true
	tap.focus_mode = Control.FOCUS_NONE
	tap.size = Vector2(F, F)
	tap.mouse_filter = Control.MOUSE_FILTER_STOP
	tap.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	tap.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	tap.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	tap.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	tap.pressed.connect(func():
		Sfx.play("click")
		ProfileCard.open())
	w.add_child(tap)
	if not Profile.fresh().is_empty(): w.add_child(_new_dot(F))
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
	# the frame's boss alive on it: a lizard of the Mistress', the Kraken's arm (over the heart too)
	if fid != "poloz": w.add_child(PortraitLife.make(fid, F))
	if mins:
		var tl := Kit.label("+1 in %dm" % mins, 11, UI.body_bold, Kit.DIM)
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tl.size = Vector2(F + 20, 14)
		tl.position = Vector2(-10, F + 4)
		w.add_child(tl)
	return w

## a framed portrait `f` points square: the face (assets/ui/kit/face/<face>.png; none yet - the helmet icon) in the
## frame's window on dark slate, the frame over it (Profile.FRAMES). `tail`: the Poloz' tail comes out from under it
## `fit`: the frame scaled up to fill the square (the bosses' pictures have a wide empty margin), for the profile
## `life`: the boss's touch alive on its frame too (the Poloz' tail under it, the Mistress' lizard, the Kraken's arm
## over it), scaled with the frame
static func portrait(f: float, frame_id: String, face_id: String, tail := false, fit := false, life := false) -> Control:
	var w := Control.new()
	w.custom_minimum_size = Vector2(f, f)
	w.size = Vector2(f, f)
	w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fr: Dictionary = Profile.FRAMES[0]
	for e: Dictionary in Profile.FRAMES:
		if String(e.id) == frame_id: fr = e
	var k := 0.96 / float(fr.get("span", 0.96)) if fit else 1.0
	var o := f * (0.5 - (0.5 - float(fr.win[0])) * k)
	var n := f * float(fr.win[1]) * k
	if (tail or life) and frame_id == "poloz": w.add_child(_life(frame_id, f, k))
	var back := ColorRect.new()
	back.color = Color("#17130f")
	back.position = Vector2(o - 1, o - 1)
	back.size = Vector2(n + 2, n + 2)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	w.add_child(back)
	var path := "res://assets/ui/kit/face/%s.png" % face_id
	if ResourceLoader.exists(path):
		var face := TextureRect.new()
		face.texture = load(path)
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_SCALE
		# (a 1-pt pixel picture stored ×3, as the frames: scales down evenly)
		face.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		face.position = Vector2(o, o) - Vector2(1, 1)
		face.size = Vector2(n, n) + Vector2(2, 2)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		w.add_child(face)
	else:
		var icon := Kit.icon("equipment", n * 0.86)
		icon.size = Vector2(n, n) * 0.86
		icon.position = Vector2(o, o) + Vector2(n, n) * 0.07
		w.add_child(icon)
	var frame := TextureRect.new()
	frame.texture = Kit.tex("portrait/" + frame_id)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.size = Vector2(f, f) * k
	frame.position = Vector2(f, f) * (1.0 - k) / 2.0
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# the pixel frames are stored ×3 so they scale down evenly (unscaled, their cells came out uneven)
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	w.add_child(frame)
	if life and frame_id != "poloz": w.add_child(_life(frame_id, f, k))
	return w

## the frame's life, made for the frame at f and scaled about the middle as the frame is (k)
static func _life(id: String, f: float, k: float) -> Node2D:
	var p := PortraitLife.make(id, f)
	p.scale = Vector2(k, k)
	p.position = Vector2(f, f) * (1.0 - k) / 2.0
	return p

## a small brass dot with a soft pulse on the portrait's upper right corner: something new on the miner's card
static func _new_dot(f: float) -> Control:
	var d := TextureRect.new()
	d.texture = FxLayer.puff()
	d.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	d.size = Vector2(26, 26)
	d.position = Vector2(f - 20, -6)
	d.modulate = Color(1.0, 0.82, 0.45)
	d.material = FxLayer.add_material()
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := d.create_tween().set_loops()
	tw.tween_property(d, "modulate:a", 0.35, 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_property(d, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_SINE)
	return d

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

static func _sound_name() -> String:
	if Save.d.mute: return "Sound: off"
	return "Sound: effects only" if Save.d.get("no_music", false) else "Sound: music + effects"

## the gear: sound mode (hold the gear for the diagnostics)
static func settings() -> void:
	var v := Ov.card(300)
	v.add_child(UI.title("Settings", 22))
	# three modes in turn: music and sounds -> sounds only -> off
	var snd := Ov.btn(_sound_name(), "glass", func(): pass)
	snd.pressed.connect(func():
		if Save.d.mute:
			Save.d.mute = false
			Save.d.no_music = false
		elif Save.d.get("no_music", false):
			Save.d.mute = true
		else:
			Save.d.no_music = true
		Save.persist()
		Sfx.apply_mute()
		snd.text = _sound_name())
	v.add_child(snd)
	v.add_child(Ov.btn("Story so far", "glass", func(): story_card()))
	var tips := Ov.btn("Show tips again", "glass", func(): pass)
	tips.pressed.connect(func():
		# the board's and the guide's tips start over; the story stays told
		Save.d.tut = Save.d.tut.filter(func(t: String) -> bool: return t == "prologue" or t.begins_with("s_"))
		Save.persist()
		tips.text = "Tips will show again")
	v.add_child(tips)
	# for testing: the diagnostics log (errors, slow frames, FPS; Copy) and the tester's panel (any depth, the boss…)
	v.add_child(Ov.btn("Logs", "glass", func(): Diag.show_card()))
	v.add_child(Ov.btn("Admin", "glass", func(): Admin.open()))
	v.add_child(Ov.btn("Close", "glass", func(): Ov.close()))

## the story so far: every scene already seen, to see again
static func story_card() -> void:
	var v := Ov.card(300)
	v.add_child(UI.title("Story so far", 22))
	var any := false
	for e: Array in StoryScene.JOURNAL:
		if not Save.told(String(e[2])): continue
		any = true
		var id := String(e[0])
		v.add_child(Ov.btn(String(e[1]), "glass", func():
			StoryScene.play(Ov.holder(), id)
			Ov.close()))
	if not any: v.add_child(Kit.label("Nothing yet.", 15, UI.body, Kit.DIM))
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

## the badges of the resources, drawn from the kit's icons (Kit.res_icon): a heart, the hexagonal coin, iron, the
## mine's own ore. Was a yellow circle with "$" (playtest 31.10)
static func coin_icon(ci: CanvasItem, kind: String, c: Vector2, r: float) -> void:
	ci.draw_texture_rect(Kit.tex("icons/" + Kit.res_name(kind)), Rect2(c - Vector2(r, r) * 1.1, Vector2(r, r) * 2.2), false)

## the bottom tab bar: mines, mine, atlas, inventory (the old museum for now), three even segments edge to edge; the open one is lit,
## with a gold top edge, a bigger icon and its label, the others show just their icon
## the bottom bar (the drawn kit): the map of mines, the mine itself, the collection, the equipment — four slate
## tiles in iron frames on a dark ledge; the open one lit warm, with its icon a little bigger
static func nav_bar(active: String, on_go: Callable) -> PanelContainer:
	var bar := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color("#0d0c0b", 0.94)
	# (no brass line over the bar any more: left from the old interface, the tabs' own frames divide it)
	st.content_margin_left = 6
	st.content_margin_right = 6
	st.content_margin_top = 6
	st.content_margin_bottom = 4 + UI.safe_bottom()
	bar.add_theme_stylebox_override("panel", st)
	# the screen fades into the bar: a soft darkening rises 30 pt over its top edge (no hard edge, no line)
	bar.draw.connect(func():
		const H := 30.0
		var w := bar.size.x
		var c := st.bg_color
		var cols := PackedColorArray([Color(c, 0.0), Color(c, 0.0), Color(c, c.a), Color(c, c.a)])
		# eased: two bands, the upper one fainter, so the fade has no visible start
		bar.draw_polygon(PackedVector2Array([Vector2(0, -H), Vector2(w, -H), Vector2(w, -H * 0.45), Vector2(0, -H * 0.45)]),
			PackedColorArray([Color(c, 0.0), Color(c, 0.0), Color(c, c.a * 0.3), Color(c, c.a * 0.3)]))
		bar.draw_polygon(PackedVector2Array([Vector2(0, -H * 0.45), Vector2(w, -H * 0.45), Vector2(w, 0), Vector2(0, 0)]),
			PackedColorArray([Color(c, c.a * 0.3), Color(c, c.a * 0.3), Color(c, c.a), Color(c, c.a)])))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 5)
	var tabs := [["map", "Mines", "map"], ["home", "Mine", "mine"], ["atlas", "Atlas", "collection"], ["museum", "Inventory", "equipment"]]
	for tab: Array in tabs:
		var id: String = tab[0]
		var on := id == active
		var b := Button.new()
		b.name = "tab_" + id     # (found by the tutorial: Home._show_atlas_tab)
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
## the Mines tab: every mine, the ones reached open to go back to (on_pick(mine) — Main switches and shows it); each
## row says how far it is dug: its jobs built, its boss
static func mines_card(on_pick: Callable = Callable()) -> void:
	var v := Ov.card(330)
	v.add_child(UI.title("Mines", 22))
	var cur := Save.area()
	var far := Save.reached()
	for a in Data.AREAS.size():
		var A: Dictionary = Data.AREAS[a]
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", Kit.box("tab_on" if a == cur else "card", 12.0))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(Kit.icon("mine" if a <= far else "lock", 34))
		var t := VBoxContainer.new()
		t.add_theme_constant_override("separation", 0)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		t.add_child(Kit.label(String(A.n), 16, UI.display, Kit.AMBER if a == cur else Kit.CREAM if a <= far else Kit.DIM))
		var jobs: Array = A.get("tasks", [])
		var built := 0
		for j: Array in jobs:
			if (Save.d.built[a] as Array).has(j[0]): built += 1
		var st := "not yet reached"
		if a <= far:
			st = "%d of %d jobs built" % [built, jobs.size()] if jobs.size() else ""
			if not (A.get("boss", {}) as Dictionary).is_empty() and bool(Save.d.boss_won[a]): st += " · %s beaten" % String(A.boss.n)
			if a == cur: st = "working here · " + st
		t.add_child(Kit.label(st, 12, UI.body, Kit.DIM))
		h.add_child(t)
		if a <= far and a != cur:
			var go := Kit.label("›", 26, UI.display, Kit.AMBER)
			go.mouse_filter = Control.MOUSE_FILTER_IGNORE
			h.add_child(go)
			row.mouse_filter = Control.MOUSE_FILTER_STOP
			var k := a
			row.gui_input.connect(func(ev: InputEvent): if Atlas._tapped(ev):
				Sfx.play("click")
				Ov.close()
				if on_pick.is_valid(): on_pick.call(k))
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
