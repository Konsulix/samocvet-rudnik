class_name ProfileCard
## The player's profile, opened by a tap on the portrait in the top bar (15.11; laid out as Royal Match's: looking and
## choosing apart). "Profile": the title, an inset panel with the portrait and the best find side by side in the same
## dark niches ("Edit" on the portrait; the ribbon with a cup marks it the costliest, a tap on it opens its card), and the
## Records panel - four icons, their words, the numbers on dark plates. "Edit Profile": a small preview, the tabs
## Portrait / Frame / Title, a grid of equal tiles (the worn one ticked, the locked dark with a lock: a tap says how).

const W := 350.0
const SQ := 140.0
static var tab := "faces"
## the fresh things shown as new on this opening (looked at once the card is open: next time they are not new)
static var _new: Array = []

## the profile; `-- ui=profile [ptab=faces|frames|titles]` (a tab given: straight to Edit Profile)
static func open() -> void:
	var edit := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("ptab="):
			tab = a.substr(5)
			edit = true
	_new = Profile.fresh()
	if edit: _edit()
	else: _build()
	if not _new.is_empty(): Profile.mark_seen(_new)

## the window's title with its brass rule, the close cross on the window's corner (out of the layout)
static func _head(v: VBoxContainer, title: String) -> void:
	v.add_child(UI.title(title, 22))
	# under it the genes' brass underline, as the Records' bars
	var r := _bar(200.0)
	r.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(r)
	var x := Reveal.thin_close()
	x.pressed.connect(func(): Ov.close())
	var holder := Ov.holder()
	holder.add_child(x)
	var place := func(): x.position = Vector2(holder.size.x - 48, 14)
	holder.resized.connect(place)
	place.call()

## an inset panel of the window (the kit's card)
static func _panel(pad := 10.0) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Kit.box("card", pad))
	return p

## a section's name between two brass bars, the bars drawn as the genes' underline on a find's card (Reveal.chip)
static func _section(t: String) -> Control:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 10)
	h.add_child(_bar(74.0))
	h.add_child(Kit.label(t, 16, UI.display, Kit.AMBER))
	h.add_child(_bar(74.0))
	return h

## the genes' brass underline (assets/ui/kit/underline.png: its ends not stretched), w points long
static func _bar(w: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, 6)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var tex := Kit.tex("underline")
	c.draw.connect(func():
		const H := 6.0
		var ts := tex.get_size()
		var e := ts.y * 4.0 / 8.0
		var ep := H * 4.0 / 8.0
		var ww := c.size.x
		c.draw_texture_rect_region(tex, Rect2(0, 0, ep, H), Rect2(0, 0, e, ts.y))
		c.draw_texture_rect_region(tex, Rect2(ep, 0, ww - ep * 2, H), Rect2(e, 0, ts.x - e * 2, ts.y))
		c.draw_texture_rect_region(tex, Rect2(ww - ep, 0, ep, H), Rect2(ts.x - e, 0, e, ts.y)))
	return c

## the profile: the title and its rule; the framed portrait and the best find's card side by side, the same size;
## under them "Edit" and the find's plate (its name and price); a rule; the records
static func _build() -> void:
	var v := Ov.card(W)
	v.add_theme_constant_override("separation", 12)
	_head(v, "Profile")
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 22)
	g.add_theme_constant_override("v_separation", 8)
	var s := Profile.showcase()
	g.add_child(_portrait_sq())
	# the card a little smaller than the portrait's square: the drawn frame's ragged edge stops short of it, and at the
	# same square the card looked a size bigger
	var fc := Control.new()
	fc.custom_minimum_size = Vector2(SQ, SQ)
	var card := _find_sq(s)
	var c := card.custom_minimum_size.x
	card.position = Vector2(SQ - c, SQ - c) / 2
	fc.add_child(card)
	# the card's frame once more over what is in it - its rim only, the four corners and the four edges (a kit box
	# fills its middle): the ribbon's top goes under the rim
	var rim := Control.new()
	rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rim.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var tex := Kit.tex("card")
	var f: Array = Kit.FRAMES["card"]
	rim.draw.connect(func():
		var m := float(f[0])               # the corner, picture px
		var k := float(f[4])               # picture px per point
		var ts := tex.get_size()
		var e := m / k * 0.5               # drawn: only the outer half of the corner's band (its brass), in points
		var sz := rim.size
		var src_e := m * 0.5
		# corners: whole (their rivets), the slate in them is the card's own
		var cw := m / k
		rim.draw_texture_rect_region(tex, Rect2(0, 0, cw, cw), Rect2(0, 0, m, m))
		rim.draw_texture_rect_region(tex, Rect2(sz.x - cw, 0, cw, cw), Rect2(ts.x - m, 0, m, m))
		rim.draw_texture_rect_region(tex, Rect2(0, sz.y - cw, cw, cw), Rect2(0, ts.y - m, m, m))
		rim.draw_texture_rect_region(tex, Rect2(sz.x - cw, sz.y - cw, cw, cw), Rect2(ts.x - m, ts.y - m, m, m))
		# edges (stretched along)
		rim.draw_texture_rect_region(tex, Rect2(cw, 0, sz.x - 2 * cw, e), Rect2(m, 0, ts.x - 2 * m, src_e))
		rim.draw_texture_rect_region(tex, Rect2(cw, sz.y - e, sz.x - 2 * cw, e), Rect2(m, ts.y - src_e, ts.x - 2 * m, src_e))
		rim.draw_texture_rect_region(tex, Rect2(0, cw, e, sz.y - 2 * cw), Rect2(0, m, src_e, ts.y - 2 * m))
		rim.draw_texture_rect_region(tex, Rect2(sz.x - e, cw, e, sz.y - 2 * cw), Rect2(ts.x - src_e, m, src_e, ts.y - 2 * m)))
	fc.add_child(rim)
	var fit := func():
		rim.position = card.position
		rim.size = card.size
		rim.queue_redraw()
	card.resized.connect(fit)
	fit.call()
	g.add_child(fc)
	var e := Kit.button("Edit", "btn_green", 16, 3.0)
	e.custom_minimum_size = Vector2(SQ, 36)
	e.pressed.connect(func(): _edit())
	g.add_child(e)
	g.add_child(_find_plate(s))
	var cc := CenterContainer.new()
	cc.add_child(g)
	v.add_child(cc)
	v.add_child(_section("Records"))
	v.add_child(_records())

## the portrait in its own drawn frame (a tap opens Edit Profile)
static func _portrait_sq() -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(SQ, SQ)
	holder.add_child(Chrome.portrait(SQ, String(Profile.frame().id), String(Profile.face().id)))
	var tap := _flat_button(Vector2(SQ, SQ))
	tap.pressed.connect(func():
		Sfx.play("click")
		_edit())
	holder.add_child(tap)
	if not _new.is_empty(): holder.add_child(Chrome._new_dot(SQ))
	return holder

## the best find's card: the stone on the slate of a kit card, its rarity's soft glow behind it, and the ribbon of
## the costliest stone hanging from the card's top edge (a cup on it; a tap on it says what it is); a tap on the stone
## opens its card
static func _find_sq(s: Dictionary) -> Control:
	const C := SQ * 0.92
	var w := PanelContainer.new()
	w.custom_minimum_size = Vector2(C, C)
	w.add_theme_stylebox_override("panel", Kit.box("card", 5.0))
	var inner := Control.new()
	inner.custom_minimum_size = Vector2(C - 10, C - 10)
	inner.clip_contents = true
	w.add_child(inner)
	if s.is_empty():
		var l := Kit.label("Your best find\nwill stand here", 12, UI.body_bold, Kit.DIM)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.size = Vector2(C - 10, C - 10)
		inner.add_child(l)
		return w
	var glow := TextureRect.new()
	glow.texture = FxLayer.puff()
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.size = Vector2(C - 10, C - 10)
	glow.modulate = Color(Data.rarity_color(int(s.tier)), 0.45)
	glow.material = FxLayer.add_material()
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(glow)
	var img := TextureRect.new()
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.position = Vector2(C - 10, C - 10) * 0.08
	img.size = Vector2(C - 10, C - 10) * 0.84
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(img)
	var have := Atlas.cached(s)
	if have: img.texture = have
	else: Atlas.cutout(s, func(t: Texture2D): if is_instance_valid(img): img.texture = t, img)
	var tap := _flat_button(Vector2(C - 10, C - 10))
	tap.pressed.connect(func():
		Sfx.play("click")
		_open_stone(s))
	inner.add_child(tap)
	# the costliest stone's ribbon in the top right corner, its top cut by the card's edge (as the record's on a find)
	var rr := RecordRibbon.make(w, inner)
	rr.cup = true
	rr.len_ = 40.0
	rr.in_x = 26.0
	rr.head = "Your costliest stone"
	rr.lines = PackedStringArray(["The most valuable find you keep"])
	inner.add_child(rr)
	return w

## the find's plate: its name and price on a dark plate that fits them (names and prices of any length), centred
## under the card; a very long one in a smaller letter, never wider than the window's half
static func _find_plate(s: Dictionary) -> Control:
	var plate := PanelContainer.new()
	plate.custom_minimum_size = Vector2(0, 36)
	plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	plate.add_theme_stylebox_override("panel", Kit.box("btn_dark", 12.0))
	var line := HBoxContainer.new()
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	line.add_theme_constant_override("separation", 5)
	if s.is_empty():
		line.add_child(Kit.label("-", 15, UI.display, Kit.DIM))
		plate.add_child(line)
		return plate
	var name := Stones.name_of(s)
	var price := UI.fmt(roundi(float(s.value) * Save.coin_mul()))
	var fs := 15
	var font: Font = UI.display
	while fs > 11 and font.get_string_size(name + " " + price, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 20 + 5 * 2 + 24 > W / 2 - 4: fs -= 1
	line.add_child(Kit.label(name, fs, font, Kit.CREAM))
	var coin := Kit.res_icon("coin", fs + 1)
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(coin)
	line.add_child(Kit.label(price, fs, font, Kit.AMBER))
	plate.add_child(line)
	return plate

static func _flat_button(sz: Vector2) -> Button:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.size = sz
	for st in ["normal", "hover", "pressed", "focus"]: b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	return b

static func _open_stone(s: Dictionary) -> void:
	var v := Ov.card(350, Data.rarity_color(int(s.tier)))
	Reveal.stone_card(v, s, 400, func(): _build())

## the four records: an icon, its word, the number on a dark plate
static func _records() -> Control:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 6)
	for r: Array in Profile.records().slice(0, 4):
		var c := VBoxContainer.new()
		c.add_theme_constant_override("separation", 2)
		c.custom_minimum_size = Vector2(70, 0)
		var ic: TextureRect
		if String(r[0]).begins_with("res://"):
			ic = TextureRect.new()
			ic.texture = load(String(r[0]))
			ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ic.custom_minimum_size = Vector2(30, 30)
		else: ic = Kit.icon(String(r[0]), 30)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		c.add_child(ic)
		var l := Kit.label(String(r[1]), 12, UI.body_bold, Kit.DIM)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c.add_child(l)
		var plate := PanelContainer.new()
		plate.add_theme_stylebox_override("panel", Kit.box("btn_dark", 2.0))
		var n := Kit.label(String(r[2]), 15, UI.display, Kit.CREAM)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		plate.add_child(n)
		c.add_child(plate)
		h.add_child(c)
	return h

## Edit Profile: the preview, the tabs, the tiles; Done goes back to the profile
static func _edit() -> void:
	var v := Ov.card(W)
	v.add_theme_constant_override("separation", 12)
	_head(v, "Edit Profile")
	# the preview, no panel round it (as on the profile): the portrait as it is worn, and what is worn in words
	var ph := HBoxContainer.new()
	ph.alignment = BoxContainer.ALIGNMENT_CENTER
	ph.add_theme_constant_override("separation", 14)
	var pc := Control.new()
	pc.custom_minimum_size = Vector2(96, 96)
	pc.add_child(Chrome.portrait(96, String(Profile.frame().id), String(Profile.face().id)))
	ph.add_child(pc)
	var words := VBoxContainer.new()
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", 0)
	words.add_child(Kit.label(String(Profile.face().n), 18, UI.display, Kit.CREAM))
	words.add_child(Kit.label(String(Profile.frame().n), 13, UI.body_bold, Kit.DIM))
	words.add_child(Kit.label(Profile.title(), 14, UI.display, Kit.AMBER))
	ph.add_child(words)
	v.add_child(ph)
	v.add_child(_tabs())
	# the tiles straight on the window (no panel round them); the same height on every tab: the window does not jump
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	body.custom_minimum_size = Vector2(0, 204)
	v.add_child(body)
	_fill(body)
	var done := Ov.btn("Done", "green", func(): _build())
	done.custom_minimum_size.x = 160
	done.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(done)

static func _tabs() -> Control:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 6)
	for t: Array in [["faces", "Portrait"], ["frames", "Frame"], ["titles", "Title"]]:
		var id := String(t[0])
		var b := Kit.button(String(t[1]), "btn_green" if tab == id else "btn_dark", 15, 4.0)
		b.custom_minimum_size = Vector2(100, 38)
		var dot := false
		for k: String in _new:
			if k.begins_with(String({frames = "frame:", faces = "face:", titles = "title:"}[id])): dot = true
		if dot and tab != id: b.text = String(t[1]) + " •"
		b.pressed.connect(func():
			if tab == id: return
			Sfx.play("click")
			tab = id
			_edit())
		h.add_child(b)
	return h

static func _fill(body: VBoxContainer) -> void:
	match tab:
		"frames": _grid(body, Profile.FRAMES, true)
		"faces": _grid(body, Profile.FACES, false)
		_: _titles(body)

## frames or portraits, three to a row, each on the same dark tile: the worn one ticked on a green-lit tile, the
## locked dark with a lock (a tap says how it is earned); no names - the pictures speak for themselves
static func _grid(body: VBoxContainer, list: Array, frames: bool) -> void:
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 10)
	var worn := String((Profile.frame() if frames else Profile.face()).id)
	const T := 92.0
	const S := 78.0
	var inner := T - 6
	for e: Dictionary in list:
		var id := String(e.id)
		var owned := Profile.has_frame(e) if frames else Profile.has_face(e)
		var tile := PanelContainer.new()
		tile.custom_minimum_size = Vector2(T, T)
		tile.add_theme_stylebox_override("panel", Kit.box("btn_dark", 3.0, Color(0.8, 1.25, 0.8) if id == worn else Color.WHITE))
		var cell := Control.new()
		cell.custom_minimum_size = Vector2(inner, inner)
		tile.add_child(cell)
		var por := Chrome.portrait(S, id if frames else String(Profile.frame().id), String(Profile.face().id) if frames else id)
		por.position = Vector2(inner - S, inner - S) / 2
		if not owned: por.modulate = Color(0.5, 0.47, 0.45)
		cell.add_child(por)
		if not owned:
			var lk := Kit.icon("lock", 30)
			lk.size = Vector2(30, 30)
			lk.position = Vector2(inner - 30, inner - 30) / 2
			cell.add_child(lk)
		if id == worn:
			var ck := Kit.icon("check", 28)
			ck.size = Vector2(28, 28)
			ck.position = Vector2(inner - 22, inner - 24)
			cell.add_child(ck)
		if (_new as Array).has(("frame:" if frames else "face:") + id):
			var nw := Kit.label("NEW", 11, UI.display, Kit.AMBER)
			nw.position = Vector2(2, -2)
			cell.add_child(nw)
		var b := _flat_button(Vector2(inner, inner))
		var how := Profile.frame_how(e) if frames else String(e.get("how", ""))
		b.pressed.connect(func():
			Sfx.play("click")
			if not owned:
				Ov.toast("%s · %s" % [String(e.n), how])
			elif id != worn:
				Profile.wear("frame" if frames else "face", id)
				_edit())
		cell.add_child(b)
		g.add_child(tile)
	var cc := CenterContainer.new()
	cc.add_child(g)
	body.add_child(cc)

## the titles: plates, the worn one lit and ticked; the rest with how to earn them
static func _titles(body: VBoxContainer) -> void:
	var worn := Profile.title()
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, 204)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 4)
	sc.add_child(col)
	# (no bar: a finger drags the list)
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	for t: Array in Profile.titles():
		var nm := String(t[0])
		var owned := bool(t[1])
		var row := PanelContainer.new()
		var rb := Kit.box("btn_dark", 4.0, Color(0.8, 1.25, 0.8) if nm == worn else Color.WHITE)
		rb.content_margin_left = 14
		rb.content_margin_right = 12
		row.add_theme_stylebox_override("panel", rb)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		var l := Kit.label(nm, 15, UI.display, Kit.AMBER if nm == worn else (Kit.CREAM if owned else Kit.DIM))
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		if not owned: h.add_child(Kit.label(String(t[2]), 11, UI.body, Kit.DIM))
		elif nm == worn: h.add_child(Kit.icon("check", 22))
		row.add_child(h)
		if owned and nm != worn:
			var b := _flat_button(Vector2(W - 80, 34))
			b.pressed.connect(func():
				Sfx.play("click")
				Profile.wear("title", nm)
				_edit())
			row.add_child(b)
		col.add_child(row)
	body.add_child(sc)

## a boss beaten: its frame is the player's - shown big, dropping into place, to wear at once or later
static func award_frame(area: int) -> void:
	var f := {}
	for e: Dictionary in Profile.FRAMES:
		if int(e.get("area", -1)) == area: f = e
	if f.is_empty() or not Profile.has_frame(f): return
	var key := "frame:" + String(f.id)
	if (Save.d.get("prof_seen", []) as Array).has(key): return
	var v := Ov.card(300)
	v.add_child(UI.title("A new portrait frame", 20))
	var r := Kit.rule(200)
	r.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(r)
	var hold := Control.new()
	hold.custom_minimum_size = Vector2(0, 190)
	var por := Chrome.portrait(180, String(f.id), String(Profile.face().id), true)
	hold.add_child(por)
	hold.resized.connect(func(): por.position.x = (hold.size.x - 180) / 2)
	v.add_child(hold)
	# it drops in from above and settles with a bump
	por.position.y = -60
	por.modulate.a = 0.0
	var tw := por.create_tween().set_parallel(true)
	tw.tween_property(por, "position:y", 5.0, 0.55).set_delay(0.15).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(por, "modulate:a", 1.0, 0.2).set_delay(0.15)
	var nm := Kit.label(String(f.n), 18, UI.display, Kit.AMBER)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(nm)
	v.add_child(Ov.text("%s is beaten. Its frame is yours to wear." % String(Data.AREAS[area].boss.n), 14))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	var later := Ov.btn("Later", "dark", func(): Ov.close())
	var wear := Ov.btn("Wear it", "green", func():
		Profile.wear("frame", String(f.id))
		Profile.mark_seen([key])
		Ov.close())
	for b: Button in [later, wear]:
		b.custom_minimum_size = Vector2(118, 50)
		row.add_child(b)
	v.add_child(row)
	await Ov.closed
