class_name ProfileCard
## The miner's card, opened by a tap on the portrait in the top bar (15.11, GPT mockup art/profile/out/mock_a2.png):
## on top two squares side by side - the portrait in its frame and the best find in a slate niche with its name and
## price on a brass plate (a tap opens its card, the pin picks another stone); then four records; then the tabs
## Frames / Portraits / Titles - what is owned to wear, what is not as a dark shape with a lock and how to earn it.

const W := 350.0
const SQ := 150.0
static var tab := "frames"
## (a snapshot opens on another tab: `-- ui=profile ptab=faces`)
## the fresh things shown as new on this opening (looked at once the card is open: next time they are not new)
static var _new: Array = []

static func open() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("ptab="): tab = a.substr(5)
	_new = Profile.fresh()
	_build()
	if not _new.is_empty(): Profile.mark_seen(_new)

static func _build() -> void:
	var v := Ov.card(W)
	v.add_theme_constant_override("separation", 10)
	# no title: the portrait and the find say what this is; the close cross alone on the top right
	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_END
	var x := Reveal.thin_close()
	x.pressed.connect(func(): Ov.close())
	head.add_child(x)
	head.custom_minimum_size = Vector2(0, 26)
	v.add_child(head)
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 10)
	top.add_child(_portrait_sq())
	top.add_child(_find_sq())
	v.add_child(top)
	v.add_child(_records())
	v.add_child(_tabs(v))
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	# (the same height on every tab: the card does not jump when the tab changes)
	body.custom_minimum_size = Vector2(0, 200)
	v.add_child(body)
	_fill(body)

## the portrait, the size of the find's niche
static func _portrait_sq() -> Control:
	var w := Control.new()
	w.custom_minimum_size = Vector2(SQ, SQ)
	w.add_child(Chrome.portrait(SQ, String(Profile.frame().id), String(Profile.face().id)))
	return w

## the best find: a stone on slate in an iron-rimmed niche, its name and price on a brass plate along the bottom
static func _find_sq() -> Control:
	var w := PanelContainer.new()
	w.custom_minimum_size = Vector2(SQ, SQ)
	w.add_theme_stylebox_override("panel", Kit.box("card", 6.0, Color(0.72, 0.72, 0.78)))
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(SQ - 12, SQ - 12)
	holder.clip_contents = true
	w.add_child(holder)
	var s := Profile.showcase()
	if s.is_empty():
		var l := Kit.label("Your best find\nwill stand here", 13, UI.body_bold, Kit.DIM)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.size = holder.custom_minimum_size
		holder.add_child(l)
		return w
	var img := TextureRect.new()
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.position = Vector2(6, 2)
	img.size = Vector2(SQ - 24, SQ - 44)
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# a soft glow of its rarity behind the stone
	var glow := TextureRect.new()
	glow.texture = FxLayer.puff()
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.size = Vector2(SQ - 30, SQ - 50)
	glow.position = Vector2(9, 4)
	glow.modulate = Color(Data.rarity_color(int(s.tier)), 0.5)
	glow.material = FxLayer.add_material()
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(glow)
	holder.add_child(img)
	var have := Atlas.cached(s)
	if have: img.texture = have
	else: Atlas.cutout(s, func(t: Texture2D): if is_instance_valid(img): img.texture = t, img)
	# the plate
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", Kit.box("btn_gold", 3.0))
	plate.position = Vector2(8, SQ - 12 - 42)
	plate.size = Vector2(SQ - 28, 40)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", -4)
	pv.alignment = BoxContainer.ALIGNMENT_CENTER
	var nm := Kit.label(Stones.name_of(s), 13 if Stones.name_of(s).length() < 15 else 11, UI.display, Color("#2a1d0e"))
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.clip_text = true
	pv.add_child(nm)
	var pr := HBoxContainer.new()
	pr.alignment = BoxContainer.ALIGNMENT_CENTER
	pr.add_theme_constant_override("separation", 3)
	var coin := Kit.res_icon("coin", 16)
	pr.add_child(coin)
	pr.add_child(Kit.label(UI.fmt(roundi(float(s.value) * Save.coin_mul())), 13, UI.display, Color("#2a1d0e")))
	pv.add_child(pr)
	plate.add_child(pv)
	holder.add_child(plate)
	# a tap on the stone opens its card; the pin in the corner picks another stone for the niche
	var tap := _flat_button(Vector2(SQ - 12, SQ - 12))
	tap.pressed.connect(func():
		Sfx.play("click")
		_open_stone(s))
	holder.add_child(tap)
	var pin := Kit.icon_button("plus", 26)
	pin.position = Vector2(SQ - 12 - 30, 2)
	pin.tooltip_text = "Show another stone"
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
	v.add_child(UI.title("Show in the niche", 20))
	v.add_child(Kit.rule(220))
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
		cell.add_theme_stylebox_override("panel", Kit.box("btn_gold" if int(s.id) == shown else "btn_dark", 3.0))
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
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, 330)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var cc := CenterContainer.new()
	cc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cc.add_child(g)
	sc.add_child(cc)
	v.add_child(sc)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	row.add_child(Ov.btn("The best one", "dark", func():
		Profile.wear("stone", "")
		_build()))
	row.add_child(Ov.btn("Back", "green", func(): _build()))
	v.add_child(row)

## the four records as tiles: an icon, a word, the number
static func _records() -> Control:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 6)
	for r: Array in Profile.records().slice(0, 4):
		var p := Control.new()
		p.custom_minimum_size = Vector2(76, 58)
		var c := VBoxContainer.new()
		c.add_theme_constant_override("separation", -2)
		c.alignment = BoxContainer.ALIGNMENT_CENTER
		var ic: TextureRect
		if String(r[0]).begins_with("res://"):
			ic = TextureRect.new()
			ic.texture = load(String(r[0]))
			ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ic.custom_minimum_size = Vector2(26, 26)
		else: ic = Kit.icon(String(r[0]), 26)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		c.add_child(ic)
		var l := Kit.label(String(r[1]), 11, UI.body_bold, Kit.DIM)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c.add_child(l)
		var n := Kit.label(String(r[2]), 16, UI.display, Kit.CREAM)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c.add_child(n)
		c.size = Vector2(76, 58)
		p.add_child(c)
		h.add_child(p)
	return h

static func _tabs(v: Control) -> Control:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 6)
	for t: Array in [["frames", "Frames"], ["faces", "Portraits"], ["titles", "Titles"]]:
		var id := String(t[0])
		var b := Kit.button(String(t[1]), "btn_green" if tab == id else "btn_dark", 15, 4.0)
		b.custom_minimum_size = Vector2(100, 38)
		var dot := false
		for k: String in _new:
			if k.begins_with({frames = "frame:", faces = "face:", titles = "title:"}[id]): dot = true
		if dot and tab != id: b.text = String(t[1]) + " •"
		b.pressed.connect(func():
			if tab == id: return
			Sfx.play("click")
			tab = id
			_build())
		h.add_child(b)
	return h

static func _fill(body: VBoxContainer) -> void:
	match tab:
		"frames": _grid(body, Profile.FRAMES, true)
		"faces": _grid(body, Profile.FACES, false)
		_: _titles(body)

## frames or portraits, three to a row: the owned to wear (the worn one ticked), the rest dark with how to earn them
static func _grid(body: VBoxContainer, list: Array, frames: bool) -> void:
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 12)
	g.add_theme_constant_override("v_separation", 10)
	var worn := String((Profile.frame() if frames else Profile.face()).id)
	const S := 92.0
	for e: Dictionary in list:
		var id := String(e.id)
		var owned := Profile.has_frame(e) if frames else Profile.has_face(e)
		var cell := Control.new()
		cell.custom_minimum_size = Vector2(S, S)
		var por := Chrome.portrait(S, id if frames else String(Profile.frame().id), String(Profile.face().id) if frames else id)
		if not owned: por.modulate = Color(0.4, 0.37, 0.36)
		cell.add_child(por)
		if not owned:
			var lk := Kit.icon("lock", 30)
			lk.size = Vector2(30, 30)
			lk.position = Vector2(S - 30, S - 32) / 2 + Vector2(0, 0)
			lk.position = Vector2((S - 30) / 2, (S - 30) / 2)
			cell.add_child(lk)
		if id == worn:
			var ck := Kit.icon("check", 28)
			ck.size = Vector2(28, 28)
			ck.position = Vector2(S - 26, S - 26)
			cell.add_child(ck)
		if (_new as Array).has(("frame:" if frames else "face:") + id):
			var nw := Kit.label("NEW", 12, UI.display, Kit.AMBER)
			nw.position = Vector2(0, -4)
			cell.add_child(nw)
		# a tap: the owned is worn; the locked says how it is earned (no names under the pictures: they speak for
		# themselves, as in Royal Match's profile)
		var b := _flat_button(Vector2(S, S))
		var how := Profile.frame_how(e) if frames else String(e.get("how", ""))
		b.pressed.connect(func():
			Sfx.play("click")
			if not owned:
				Ov.toast("%s · %s" % [String(e.n), how])
			elif id != worn:
				Profile.wear("frame" if frames else "face", id)
				_build())
		cell.add_child(b)
		g.add_child(cell)
	var cc := CenterContainer.new()
	cc.add_child(g)
	body.add_child(cc)

## the titles: brass plates, the worn one bright; the rest with how to earn them
static func _titles(body: VBoxContainer) -> void:
	var worn := Profile.title()
	for t: Array in Profile.titles():
		var nm := String(t[0])
		var owned := bool(t[1])
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", Kit.box("btn_gold" if nm == worn else "btn_dark", 4.0))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		var l := Kit.label(nm, 15, UI.display, Kit.CREAM if owned else Kit.DIM)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		if not owned:
			h.add_child(Kit.label(String(t[2]), 11, UI.body, Kit.DIM))
		row.add_child(h)
		if owned and nm != worn:
			var b := _flat_button(Vector2(W - 40, 36))
			b.pressed.connect(func():
				Sfx.play("click")
				Profile.wear("title", nm)
				_build())
			row.add_child(b)
		body.add_child(row)

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
	v.add_child(Kit.rule(200))
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
		b.custom_minimum_size.x = 118
		row.add_child(b)
	v.add_child(row)
	await Ov.closed
