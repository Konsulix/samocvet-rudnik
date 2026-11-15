class_name ProfileCard
## The player's profile, opened by a tap on the portrait in the top bar (15.11; laid out as Royal Match's: looking and
## choosing apart). "Profile": the title, an inset panel with the portrait and the best find side by side in the same
## dark niches ("Edit" on the portrait; "+" on the find picks another stone, a tap on it opens its card), and the
## Records panel - four icons, their words, the numbers on dark plates. "Edit Profile": a small preview, the tabs
## Portrait / Frame / Title, a grid of equal tiles (the worn one ticked, the locked dark with a lock: a tap says how).

const W := 350.0
const SQ := 132.0
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
	var r := Kit.rule(220)
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

## a section's name between two brass rules: ——— Records ———
static func _section(t: String) -> Control:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 8)
	var a := Kit.rule(70)
	var b := Kit.rule(70)
	a.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(a)
	h.add_child(Kit.label(t, 15, UI.display, Kit.AMBER))
	h.add_child(b)
	return h

static func _build() -> void:
	var v := Ov.card(W)
	v.add_theme_constant_override("separation", 10)
	_head(v, "Profile")
	var who := _panel(10.0)
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 12)
	top.add_child(_portrait_sq())
	top.add_child(_find_sq())
	who.add_child(top)
	v.add_child(who)
	var rec := _panel(10.0)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 8)
	rv.add_child(_section("Records"))
	rv.add_child(_records())
	rec.add_child(rv)
	v.add_child(rec)

## a dark niche square (the portrait's and the find's: the same)
static func _niche() -> PanelContainer:
	var w := PanelContainer.new()
	w.custom_minimum_size = Vector2(SQ, SQ)
	w.add_theme_stylebox_override("panel", Kit.box("btn_dark", 4.0))
	return w

## the portrait in its niche, "Edit" on its corner (a tap anywhere on it opens Edit Profile)
static func _portrait_sq() -> Control:
	var w := _niche()
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(SQ - 8, SQ - 8)
	w.add_child(holder)
	holder.add_child(Chrome.portrait(SQ - 8, String(Profile.frame().id), String(Profile.face().id)))
	var tap := _flat_button(Vector2(SQ - 8, SQ - 8))
	tap.pressed.connect(func():
		Sfx.play("click")
		_edit())
	holder.add_child(tap)
	var e := Kit.button("Edit", "btn_green", 13, 2.0)
	e.custom_minimum_size = Vector2(54, 28)
	e.size = Vector2(54, 28)
	e.position = Vector2(-4, SQ - 8 - 26)
	e.pressed.connect(func(): _edit())
	holder.add_child(e)
	if not _new.is_empty(): holder.add_child(Chrome._new_dot(SQ - 8))
	return w

## the best find: the stone in its niche, its name and price on a brass plate along the bottom
static func _find_sq() -> Control:
	var w := _niche()
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(SQ - 8, SQ - 8)
	holder.clip_contents = true
	w.add_child(holder)
	var s := Profile.showcase()
	if s.is_empty():
		var l := Kit.label("Your best find\nwill stand here", 12, UI.body_bold, Kit.DIM)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.size = holder.custom_minimum_size
		holder.add_child(l)
		return w
	# a soft glow of its rarity behind the stone
	var glow := TextureRect.new()
	glow.texture = FxLayer.puff()
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.size = Vector2(SQ - 24, SQ - 44)
	glow.position = Vector2(8, 6)
	glow.modulate = Color(Data.rarity_color(int(s.tier)), 0.5)
	glow.material = FxLayer.add_material()
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(glow)
	var img := TextureRect.new()
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.position = Vector2(4, 4)
	img.size = Vector2(SQ - 16, SQ - 40)
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(img)
	var have := Atlas.cached(s)
	if have: img.texture = have
	else: Atlas.cutout(s, func(t: Texture2D): if is_instance_valid(img): img.texture = t, img)
	# the plate: one line, the name and the price (two lines did not fit the niche)
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", Kit.box("btn_gold", 2.0))
	plate.position = Vector2(2, SQ - 8 - 30)
	plate.size = Vector2(SQ - 12, 28)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pr := HBoxContainer.new()
	pr.alignment = BoxContainer.ALIGNMENT_CENTER
	pr.add_theme_constant_override("separation", 3)
	var name := Stones.name_of(s)
	var nm := Kit.label(name, 12 if name.length() <= 9 else (10 if name.length() <= 13 else 9), UI.display, Color("#2a1d0e"))
	pr.add_child(nm)
	pr.add_child(Kit.res_icon("coin", 14))
	pr.add_child(Kit.label(UI.fmt(roundi(float(s.value) * Save.coin_mul())), 12, UI.display, Color("#2a1d0e")))
	plate.add_child(pr)
	holder.add_child(plate)
	# a tap on the stone opens its card; the "+" in the corner picks another stone for the niche
	var tap := _flat_button(Vector2(SQ - 8, SQ - 8))
	tap.pressed.connect(func():
		Sfx.play("click")
		_open_stone(s))
	holder.add_child(tap)
	var pin := Kit.icon_button("plus", 26)
	pin.position = Vector2(SQ - 8 - 28, 0)
	pin.pressed.connect(func(): _pick_stone())
	holder.add_child(pin)
	return w

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

## the stones to show: the most valuable twenty-four kept, a tap puts one in the niche
static func _pick_stone() -> void:
	var v := Ov.card(W)
	v.add_theme_constant_override("separation", 10)
	_head(v, "Show in the niche")
	var list: Array = Save.d.coll.duplicate()
	list.sort_custom(func(a, b): return int(a.value) > int(b.value))
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 6)
	var shown := int(Profile.showcase().get("id", -1))
	for s: Dictionary in list.slice(0, 24):
		var cell := PanelContainer.new()
		cell.custom_minimum_size = Vector2(70, 70)
		cell.add_theme_stylebox_override("panel", Kit.box("btn_dark", 3.0, Color(0.8, 1.25, 0.8) if int(s.id) == shown else Color.WHITE))
		var img := TextureRect.new()
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.custom_minimum_size = Vector2(60, 60)
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var have := Atlas.cached(s)
		if have: img.texture = have
		else: Atlas.cutout(s, func(t: Texture2D): if is_instance_valid(img): img.texture = t, img)
		cell.add_child(img)
		var b := _flat_button(Vector2(70, 70))
		var sid := int(s.id)
		b.pressed.connect(func():
			Sfx.play("click")
			Profile.wear("stone", str(sid))
			_build())
		cell.add_child(b)
		g.add_child(cell)
	var box := _panel(8.0)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, 310)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var cc := CenterContainer.new()
	cc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cc.add_child(g)
	sc.add_child(cc)
	box.add_child(sc)
	v.add_child(box)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	var best := Ov.btn("The best one", "dark", func():
		Profile.wear("stone", "")
		_build())
	var back := Ov.btn("Done", "green", func(): _build())
	for b: Button in [best, back]:
		b.custom_minimum_size.x = 130
		row.add_child(b)
	v.add_child(row)

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
	v.add_theme_constant_override("separation", 10)
	_head(v, "Edit Profile")
	# the preview: the portrait as it is worn, and what is worn in words
	var pv := _panel(8.0)
	var ph := HBoxContainer.new()
	ph.add_theme_constant_override("separation", 12)
	var pc := Control.new()
	pc.custom_minimum_size = Vector2(84, 84)
	pc.add_child(Chrome.portrait(84, String(Profile.frame().id), String(Profile.face().id)))
	ph.add_child(pc)
	var words := VBoxContainer.new()
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", 0)
	words.add_child(Kit.label(String(Profile.face().n), 17, UI.display, Kit.CREAM))
	words.add_child(Kit.label(String(Profile.frame().n), 13, UI.body_bold, Kit.DIM))
	words.add_child(Kit.label(Profile.title(), 13, UI.display, Kit.AMBER))
	ph.add_child(words)
	pv.add_child(ph)
	v.add_child(pv)
	v.add_child(_tabs())
	var grid := _panel(10.0)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	# (the same height on every tab: the window does not jump when the tab changes)
	body.custom_minimum_size = Vector2(0, 204)
	grid.add_child(body)
	v.add_child(grid)
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
	for t: Array in Profile.titles():
		var nm := String(t[0])
		var owned := bool(t[1])
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", Kit.box("btn_dark", 4.0, Color(0.8, 1.25, 0.8) if nm == worn else Color.WHITE))
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
