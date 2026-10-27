class_name Museum
extends Control
## The mineralogical museum: glass cases with the specimens you kept, jewellery and the workshop
## that makes it from cut stones, and the atlas of every species with collection sets to complete.
## Any piece opens in 3D; kept stones can be cut (a gamble on their value) or sold.

signal go(screen: String)

const SORTS := [["value", "Valuable"], ["rare", "Rare"], ["new", "New"]]

var tab := "spc"
var sort := "value"
var content: VBoxContainer
var scroll: ScrollContainer

static var _round_mat: ShaderMaterial
static var start_tab := "spc"

func _ready() -> void:
	size = get_viewport_rect().size
	tab = start_tab
	var bg := MuseumBg.new()
	bg.size = size
	add_child(bg)
	render()

static func cut_ok(s: Dictionary) -> bool:
	var c: String = s.get("cut", "")
	return c != "" and c != "broken"

func render() -> void:
	var keep_scroll := scroll.scroll_vertical if scroll else 0
	for ch in get_children():
		if ch is MuseumBg: continue
		ch.queue_free()
	var root := VBoxContainer.new()
	root.size = size
	root.add_theme_constant_override("separation", 0)
	add_child(root)
	var pad := MarginContainer.new()
	for side in ["left", "right"]: pad.add_theme_constant_override("margin_" + side, 12)
	pad.add_theme_constant_override("margin_top", 10 + int(UI.safe_top()))
	pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(pad)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	pad.add_child(col)
	col.add_child(Chrome.top_bar())
	scroll = UI.scroller()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)
	_head()
	match tab:
		"jw": _jewels()
		"atlas": _atlas()
		_: _cases()
	var tail := Control.new()
	tail.custom_minimum_size = Vector2(0, 16)
	content.add_child(tail)
	root.add_child(Chrome.nav_bar("museum", func(id: String): go.emit(id)))
	if keep_scroll:
		await get_tree().process_frame
		scroll.scroll_vertical = keep_scroll

func _head() -> void:
	for s in Save.d.coll:
		if not s.sid in Save.d.seen: Save.d.seen.append(s.sid)
	var worth := 0
	for s in Save.d.coll: worth += int(s.value)
	for j in Save.d.jewels: worth += int(j.value)
	var minable := Data.minable()
	var seen := 0
	for id in Save.d.seen:
		if id in minable: seen += 1
	content.add_child(UI.title("Collection", 22))
	content.add_child(Ov.text("Mineralogical museum", 13, Color("#d8c8a8")))
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 6)
	for st in [["%d/%d" % [seen, minable.size()], "species"], [UI.fmt(worth), "worth"], ["%d/%d" % [Save.d.sets.size(), Data.SETS.size()], "sets"]]:
		var p := PanelContainer.new()
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var ps := StyleBoxFlat.new()
		ps.bg_color = Color(0.055, 0.04, 0.025, 0.6)
		ps.border_color = Color(0.89, 0.65, 0.12, 0.3)
		ps.set_border_width_all(1)
		ps.set_corner_radius_all(12)
		ps.set_content_margin_all(6)
		p.add_theme_stylebox_override("panel", ps)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		var b := UI.label(st[0], 15, UI.display, Color("#ffd77a"))
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(b)
		var sm := UI.label(String(st[1]).to_upper(), 10, UI.body_bold, Color("#c8b090"))
		sm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(sm)
		p.add_child(v)
		stats.add_child(p)
	content.add_child(stats)
	content.add_child(Depot.tabs([["spc", "Showcase · %d" % Save.d.coll.size()], ["jw", "Jewellery · %d" % Save.d.jewels.size()], ["atlas", "Atlas"]], tab, func(id: String):
		tab = id
		scroll.scroll_vertical = 0
		render()))

static func h3(t: String) -> Label:
	var l := UI.label(t.to_upper(), 11, UI.body_bold, Color("#c8b090"))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

static func note(t: String) -> Label:
	var l := UI.label(t, 12, UI.body, Color("#c8b090"))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

## a photo slot filled when the offscreen studio gets to it
static func photo(o: Dictionary, px: float, round := false) -> TextureRect:
	var img := TextureRect.new()
	img.custom_minimum_size = Vector2(px, px)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if round:
		if not _round_mat:
			_round_mat = ShaderMaterial.new()
			var sh := Shader.new()
			sh.code = "shader_type canvas_item;\nvoid fragment(){ vec4 c = texture(TEXTURE, UV); float d = length(UV - 0.5); c.a *= 1.0 - smoothstep(0.47, 0.5, d); COLOR = c * COLOR; }"
			_round_mat.shader = sh
		img.material = _round_mat
	Spec.thumb(o, func(t: Texture2D): if is_instance_valid(img): img.texture = t)
	return img

# ---------------------------------------------------------------- cases

func _cases() -> void:
	var list: Array = Save.d.coll.duplicate()
	match sort:
		"rare": list.sort_custom(func(a, b): return int(a.tier) > int(b.tier) or (int(a.tier) == int(b.tier) and int(a.value) > int(b.value)))
		"new": list.sort_custom(func(a, b): return int(a.id) > int(b.id))
		_: list.sort_custom(func(a, b): return int(a.value) > int(b.value))
	if list.is_empty():
		content.add_child(note("The showcases are empty for now. Stones drop on levels: reach the specimen in the rock."))
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	for s in SORTS:
		var on: bool = s[0] == sort
		var b := UI.button(s[1], "gold" if on else "glass", 12)
		b.custom_minimum_size = Vector2(0, 32)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var id: String = s[0]
		b.pressed.connect(func():
			sort = id
			render())
		row.add_child(b)
	content.add_child(row)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	var w := (size.x - 24 - 16) / 3.0
	for s in list:
		grid.add_child(_case(s, w))
	content.add_child(grid)

func _case(s: Dictionary, w: float) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(w, w + 44)
	var rc := Data.rarity_color(int(s.tier))
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.03, 0.04, 0.05, 0.85)
	st.border_color = Color(rc, 0.55) if s.get("legend", false) else Color("#6a5028")
	st.set_border_width_all(2)
	st.set_corner_radius_all(14)
	st.shadow_color = Color(0, 0, 0, 0.5)
	st.shadow_size = 6
	for k in ["normal", "hover", "pressed", "focus"]: b.add_theme_stylebox_override(k, st)
	b.clip_contents = true
	var img := photo(Spec.of_stone(s), w - 12)
	img.position = Vector2(6, 6)
	img.size = Vector2(w - 12, w - 12)
	b.add_child(img)
	var dot := UI.icon(10, func(ci: Control):
		ci.draw_circle(Vector2(5, 5), 7, Color(rc, 0.3))
		ci.draw_circle(Vector2(5, 5), 4.5, Color(rc.r * 1.4, rc.g * 1.4, rc.b * 1.4)))
	dot.position = Vector2(11, 11)
	b.add_child(dot)
	if cut_ok(s):
		var cm := UI.label("✦", 14, UI.body_bold, Color(1.4, 1.2, 0.7))
		cm.position = Vector2(w - 22, 4)
		b.add_child(cm)
	var plate := PanelContainer.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color("#c8a050")
	ps.border_color = Color("#f8e0a0")
	ps.border_width_top = 1
	ps.content_margin_top = 3
	ps.content_margin_bottom = 4
	plate.add_theme_stylebox_override("panel", ps)
	plate.position = Vector2(0, w - 2)
	plate.size = Vector2(w, 46)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -2)
	var n := UI.label(Data.SP[s.sid].n, 12, UI.body_bold, Color("#2a1a04"))
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.clip_text = true
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(n)
	var sm := UI.label("%s · %s" % [Stones.fmt_weight(int(s.g)), UI.fmt(int(s.value))], 10, UI.body_bold, Color("#4a3008"))
	sm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sm)
	plate.add_child(v)
	b.add_child(plate)
	b.pressed.connect(func(): _open_stone(s))
	return b

## for screenshots: ui=open_first
func _open_first() -> void:
	if Save.d.coll.size(): _open_stone(Save.d.coll[0])

## for screenshots: ui=open_uncut
func _open_uncut() -> void:
	for s in Save.d.coll:
		if s.get("cut", "") == "":
			_open_stone(s)
			return

func _open_stone(s: Dictionary) -> void:
	var v := Ov.card(350, Data.rarity_color(int(s.tier)))
	Reveal.stone_card(v, s, 400, func(): Ov.close())
	var cut_done: bool = s.get("cut", "") != ""
	if cut_done:
		v.add_child(Ov.text("Cut: " + String(Data.CUTN[s.cut]), 13))
	var price := roundi(float(s.value) * Save.coin_mul())
	var sell := func():
		Save.d.coll.erase(s)
		Save.d.coins += price
		Save.persist()
		Sfx.play("coin")
		Ov.close()
		render()
	var sell_b := Kit.button("Sell · " + UI.coins(price), "btn_gold", 16, 4.0)
	if cut_done:
		sell_b.custom_minimum_size = Vector2(0, 48)
		sell_b.pressed.connect(sell)
		v.add_child(sell_b)
	else:
		v.add_child(Reveal.action_row(Kit.button("Cut", "btn_dark", 17, 4.0), func(): _cut_panel(s), sell_b, sell))

# ---------------------------------------------------------------- cutting

func _cut_panel(s: Dictionary) -> void:
	var chance := func(c: Dictionary) -> float: return minf(0.98, float(c.p) + int(s.gi) * 0.025)
	var v := Ov.card(350)
	v.add_child(UI.title("Cutting", 22))
	v.add_child(Ov.text("%s · now %s" % [Data.SP[s.sid].n, UI.coins(int(s.value))]))
	for c in Data.CUTS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 66)
		b.disabled = Save.d.coins < int(c.cost)
		var st := UI.glass(14, 0.7)
		st.bg_color = Color("#2a1f44")
		st.border_color = Color("#8a6ad0")
		for k in ["normal", "hover", "pressed", "focus", "disabled"]: b.add_theme_stylebox_override(k, st)
		var bv := VBoxContainer.new()
		bv.position = Vector2(12, 8)
		bv.size = Vector2(290, 52)
		bv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bv.add_theme_constant_override("separation", 0)
		var top := HBoxContainer.new()
		var nl := UI.label(c.n, 15, UI.display, Color("#e8d8ff"))
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(nl)
		top.add_child(UI.label("%d%%" % roundi(chance.call(c) * 100), 15, UI.display, UI.GOOD))
		bv.add_child(top)
		var sm := UI.label("success: %s · failure: %s · labour %d coins" % [UI.fmt(roundi(float(s.value) * float(c.m))), UI.fmt(roundi(float(s.value) * float(c.fail))), int(c.cost)], 11, UI.body, UI.MUTED)
		bv.add_child(sm)
		b.add_child(bv)
		if b.disabled: b.modulate.a = 0.5
		b.pressed.connect(func(): _do_cut(s, c, chance.call(c)))
		v.add_child(b)
	v.add_child(Ov.btn("Don't risk it", "glass", func(): Ov.close()))

func _do_cut(s: Dictionary, c: Dictionary, chance: float) -> void:
	if Save.d.coins < int(c.cost): return
	Save.d.coins -= int(c.cost)
	Save.persist()
	var win := randf() < chance
	var v := Ov.card(350)
	var view := SpecView.new(384)
	view.custom_minimum_size = Vector2(314, 290)
	v.add_child(view)
	view.show_spec(Spec.of_stone(s))
	view.spin_v = 6.0
	v.add_child(UI.title(String(c.n) + "…", 22))
	for k in 10:
		await get_tree().create_timer(0.16).timeout
		Sfx.play("rock")
		Sfx.buzz(10)
		view.spin_v = 6.0
		_spark_at(view.get_global_rect().get_center() + Vector2(0, 40))
	s.cut = c.id if win else "broken"
	s.value = roundi(float(s.value) * (float(c.m) if win else float(c.fail)))
	Save.persist()
	if win:
		Sfx.play("reveal", mini(4, int(s.tier) + 1))
		Sfx.buzz(120)
	else:
		Sfx.play("lose")
	var r := Ov.card(350)
	var rv := SpecView.new(384)
	rv.custom_minimum_size = Vector2(314, 290)
	r.add_child(rv)
	rv.show_spec(Spec.of_stone(s))
	r.add_child(UI.title("The cut worked!" if win else "The stone cracked", 22))
	r.add_child(Ov.text("Now it is worth %s." % UI.coins(int(s.value))))
	r.add_child(Ov.btn("Great", "green", func():
		Ov.close()
		render()))

func _spark_at(p: Vector2) -> void:
	var sp := CPUParticles2D.new()
	sp.position = p
	sp.one_shot = true
	sp.explosiveness = 0.9
	sp.amount = 10
	sp.lifetime = 0.5
	sp.spread = 70
	sp.direction = Vector2(0, -1)
	sp.initial_velocity_min = 80
	sp.initial_velocity_max = 200
	sp.gravity = Vector2(0, 500)
	sp.scale_amount_min = 1.5
	sp.scale_amount_max = 3
	sp.color = Color(2.0, 1.8, 1.2)
	Ov.root.add_child(sp)
	sp.emitting = true
	get_tree().create_timer(0.8).timeout.connect(sp.queue_free)

# ---------------------------------------------------------------- jewellery

## the cheapest cut stones that fit a recipe, or [] when there are none
static func pick_for(j: Dictionary) -> Array:
	var pool := []
	for s in Save.d.coll:
		if cut_ok(s): pool.append(s)
	pool.sort_custom(func(a, b): return int(a.value) < int(b.value))
	var need = j.need
	if need is String and need == "pair":
		var by := {}
		for st in pool:
			if not by.has(st.sid): by[st.sid] = []
			by[st.sid].append(st)
			if by[st.sid].size() >= 2: return by[st.sid].slice(0, 2)
		return []
	if need is String and need == "trio":
		var out := []
		var seen := {}
		for st in pool:
			if not seen.has(st.sid):
				seen[st.sid] = true
				out.append(st)
				if out.size() == 3: return out
		return []
	var reqs: Array = (need as Array).duplicate()
	var rank := func(c: Dictionary) -> int: return 2 if c.has("sid") else 1 if c.has("r") else 0
	reqs.sort_custom(func(a, b): return rank.call(a) > rank.call(b))
	var used := []
	var out2 := []
	for c in reqs:
		var found: Dictionary = {}
		for x in pool:
			if x in used: continue
			if c.has("sid") and x.sid != c.sid: continue
			if c.has("r") and int(Data.SP[x.sid].r) < int(c.r): continue
			found = x
			break
		if found.is_empty(): return []
		used.append(found)
		out2.append(found)
	return out2

func _jewels() -> void:
	var cut := 0
	for s in Save.d.coll:
		if cut_ok(s): cut += 1
	if Save.d.jewels.is_empty():
		content.add_child(note("No jewellery yet. Make your first piece in the workshop."))
	else:
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		var w := (size.x - 24 - 8) / 2.0
		for j in Save.d.jewels:
			grid.add_child(_jewel_case(j, w))
		content.add_child(grid)
	content.add_child(h3("Workshop · cut stones: %d" % cut))
	content.add_child(note("The jeweller takes the cheapest stones that fit; valuable ones stay in the showcase."))
	for j in Data.JEWELS:
		content.add_child(_workshop_row(j))

func _jewel_case(j: Dictionary, w: float) -> Button:
	var R0: Dictionary = {}
	for x in Data.JEWELS:
		if x.id == j.rid: R0 = x
	var b := Button.new()
	b.custom_minimum_size = Vector2(w, w + 44)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.03, 0.04, 0.05, 0.85)
	st.border_color = Color("#a07a30")
	st.set_border_width_all(2)
	st.set_corner_radius_all(14)
	for k in ["normal", "hover", "pressed", "focus"]: b.add_theme_stylebox_override(k, st)
	b.clip_contents = true
	var img := photo(Spec.of_jewel(j), w - 12)
	img.position = Vector2(6, 6)
	img.size = Vector2(w - 12, w - 12)
	b.add_child(img)
	var plate := PanelContainer.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color("#c8a050")
	ps.content_margin_top = 3
	ps.content_margin_bottom = 4
	plate.add_theme_stylebox_override("panel", ps)
	plate.position = Vector2(0, w - 2)
	plate.size = Vector2(w, 46)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -2)
	var n := UI.label(R0.get("n", ""), 13, UI.body_bold, Color("#2a1a04"))
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(n)
	var sm := UI.label(UI.coins(int(j.value)) + (" · " + String(R0.perk) if R0.has("perk") else ""), 10, UI.body_bold, Color("#1f5a20") if R0.has("perk") else Color("#4a3008"))
	sm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sm.clip_text = true
	sm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(sm)
	plate.add_child(v)
	b.add_child(plate)
	b.pressed.connect(func(): _show_jewel(j))
	return b

func _workshop_row(j: Dictionary) -> PanelContainer:
	var st := pick_for(j)
	var val := 0
	var cols := []
	for x in st:
		val += int(x.value)
		cols.append(Data.SP[x.sid].c)
	val = roundi(val * float(j.m))
	if cols.is_empty(): cols = ["#6a7080"]
	var p := PanelContainer.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0, 0, 0, 0.35)
	ps.border_color = Color("#4a3a22")
	ps.set_border_width_all(1)
	ps.set_corner_radius_all(14)
	ps.set_content_margin_all(8)
	p.add_theme_stylebox_override("panel", ps)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var img := photo({seed = 7, jewel = {rid = j.id, cols = cols}}, 72)
	h.add_child(img)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 1)
	v.add_child(UI.label(j.n, 14, UI.display, Color("#ffe8c0")))
	var d := note(j.d)
	v.add_child(d)
	if j.has("perk"):
		var pk := UI.label(j.perk, 12, UI.body_bold, Color("#7ad87a"))
		v.add_child(pk)
	if st.size():
		var names := []
		for x in st: names.append(Data.SP[x.sid].n)
		v.add_child(note("From: %s → %s" % [", ".join(names), UI.coins(val)]))
	var b := UI.button("Make" if st.size() else "No stones", "gold" if st.size() else "glass", 13)
	b.custom_minimum_size = Vector2(0, 36)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.disabled = st.is_empty()
	b.pressed.connect(func(): _craft(j))
	v.add_child(b)
	h.add_child(v)
	p.add_child(h)
	return p

func _craft(j: Dictionary) -> void:
	var st := pick_for(j)
	if st.is_empty(): return
	var value := 0
	var cols := []
	var names := []
	for x in st:
		Save.d.coll.erase(x)
		value += int(x.value)
		cols.append(Data.SP[x.sid].c)
		names.append(Data.SP[x.sid].n)
	var jw := {id = Save.next_uid(), rid = j.id, cols = cols, names = names, value = roundi(value * float(j.m))}
	Save.d.jewels.append(jw)
	Save.persist()
	Sfx.play("build")
	Sfx.buzz(60)
	render()
	_show_jewel(jw, true)

func _show_jewel(j: Dictionary, fresh := false) -> void:
	var R0: Dictionary = {}
	for x in Data.JEWELS:
		if x.id == j.rid: R0 = x
	var v := Ov.card(350)
	var view := SpecView.new(384)
	view.custom_minimum_size = Vector2(314, 280)
	v.add_child(view)
	view.show_spec(Spec.of_jewel(j))
	var rar := UI.label("new jewellery" if fresh else "jewellery", 13, UI.body_bold, Color("#e4ae39"))
	rar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rar.uppercase = true
	v.add_child(rar)
	v.add_child(UI.title(R0.get("n", ""), 22))
	var rows := VBoxContainer.new()
	Reveal._row(rows, "Stones", ", ".join(j.get("names", [])))
	Reveal._row(rows, "Value", UI.coins(int(j.value)), UI.GOLD)
	v.add_child(rows)
	if R0.has("perk"):
		var c := Reveal.chip(R0.perk, true)
		c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(c)
	var price := roundi(float(j.value) * Save.coin_mul())
	var armed := [false]
	var sell := Ov.btn("Sell · " + UI.coins(price), "gold", func(): pass)
	sell.pressed.connect(func():
		if not armed[0]:
			armed[0] = true
			sell.text = "Sell for sure? " + ("The bonus will be lost" if R0.has("perk") else "You can't get it back")
			return
		Save.d.jewels.erase(j)
		Save.d.coins += price
		Save.persist()
		Sfx.play("coin")
		Ov.close()
		render())
	v.add_child(sell)
	v.add_child(Ov.btn("Close", "glass", func(): Ov.close()))

# ---------------------------------------------------------------- atlas

func _atlas() -> void:
	var ids := Data.minable()
	var best := {}
	var got := {}
	for s in Save.d.coll:
		got[s.sid] = true
		if not best.has(s.sid) or int(s.value) > int(best[s.sid].value): best[s.sid] = s
	ids.sort_custom(func(a, b): return int(Data.SP[a].r) < int(Data.SP[b].r) or (int(Data.SP[a].r) == int(Data.SP[b].r) and float(Data.SP[a].v) < float(Data.SP[b].v)))
	var nseen := 0
	for id in ids:
		if id in Save.d.seen: nseen += 1
	content.add_child(h3("Species · found %d of %d" % [nseen, ids.size()]))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 10)
	var w := (size.x - 24 - 24) / 4.0
	for id in ids:
		var seen: bool = id in Save.d.seen
		var v := VBoxContainer.new()
		v.custom_minimum_size = Vector2(w, 0)
		v.add_theme_constant_override("separation", 3)
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(w, w)
		var spc := Data.sp_color(id)
		holder.draw.connect(func():
			var c := Vector2(w, w) / 2
			holder.draw_circle(c, w / 2, Color("#08060a"))
			GemArt.radial_disc(holder, c - Vector2(0, w * 0.08), w * 0.48, Color("#1a1410"), Color("#120e0b"), Color("#08060a"))
			holder.draw_arc(c, w / 2 - 1, 0, TAU, 40, Color("#6a5028"), 2.0, true)
			if not best.has(id):
				if seen:
					holder.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -w * 0.22), c + Vector2(w * 0.16, 0), c + Vector2(0, w * 0.22), c + Vector2(-w * 0.16, 0)]), spc)
				else:
					holder.draw_string(UI.display, c + Vector2(-w * 0.1, w * 0.12), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, int(w * 0.34), Color("#4a3a28")))
		if best.has(id):
			var img := photo(Spec.of_stone(best[id]), w, true)
			img.size = Vector2(w, w)
			holder.add_child(img)
		v.add_child(holder)
		var nl := UI.label(Data.SP[id].n if seen else "???", 11, UI.body_bold, Color("#e8d8bc") if seen else Color("#7a6a58"))
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(nl)
		if not seen:
			var where := ""
			for A in Data.AREAS:
				if A.pool.has(id):
					where = A.n
					break
			var wl := UI.label(where, 9, UI.body, Color("#8a7a62"))
			wl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			wl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			v.add_child(wl)
		grid.add_child(v)
	content.add_child(grid)
	content.add_child(h3("Sets"))
	for st in Data.SETS:
		content.add_child(_set_row(st, got))

func _set_row(st: Dictionary, got: Dictionary) -> PanelContainer:
	var n := 0
	for x in st.need:
		if got.has(x): n += 1
	var full: bool = n == st.need.size()
	var claimed: bool = st.id in Save.d.sets
	var p := PanelContainer.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0, 0, 0, 0.35)
	ps.border_color = Color("#e3a51e") if full and not claimed else Color("#4a3a22")
	ps.set_border_width_all(1)
	ps.set_corner_radius_all(14)
	ps.set_content_margin_all(10)
	p.add_theme_stylebox_override("panel", ps)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	var top := HBoxContainer.new()
	var nm := UI.label(st.n, 15, UI.display, Color("#ffe8c0"))
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(nm)
	top.add_child(UI.label("%d/%d" % [n, st.need.size()], 12, UI.body_bold, Color("#c8b090")))
	v.add_child(top)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 6)
	bar.max_value = st.need.size()
	bar.value = n
	var bgs := StyleBoxFlat.new()
	bgs.bg_color = Color(1, 1, 1, 0.08)
	bgs.set_corner_radius_all(3)
	var fgs := StyleBoxFlat.new()
	fgs.bg_color = UI.GOLD
	fgs.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", bgs)
	bar.add_theme_stylebox_override("fill", fgs)
	v.add_child(bar)
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 5)
	chips.add_theme_constant_override("v_separation", 5)
	for x in st.need:
		chips.add_child(Reveal.chip(Data.SP[x].n, got.has(x)))
	v.add_child(chips)
	var rw: Dictionary = st.reward
	v.add_child(note("Reward: %d coins%s%s" % [int(rw.coins), (", pickaxe ×%d" % int(rw.pick)) if rw.get("pick", 0) else "", (", rock drill ×%d" % int(rw.bore_h)) if rw.get("bore_h", 0) else ""]))
	if claimed:
		v.add_child(UI.label("✓ Claimed", 13, UI.body_bold, UI.GOOD))
	elif full:
		var b := UI.button("Claim reward", "gold", 15)
		b.custom_minimum_size = Vector2(0, 44)
		b.pressed.connect(func():
			if st.id in Save.d.sets: return
			Save.d.sets.append(st.id)
			Save.d.coins += int(rw.coins)
			Save.d.boost.pick += int(rw.get("pick", 0))
			Save.d.boost.bore_h += int(rw.get("bore_h", 0))
			Save.persist()
			Sfx.play("coin")
			render()
			Ov.toast("%s: reward claimed" % st.n))
		v.add_child(b)
	p.add_child(v)
	return p

## a dark gallery: warm wood fading to black, wall panels, two spotlights from above
class MuseumBg extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, 0), Vector2(r.end.x, size.y * 0.7), Vector2(0, size.y * 0.7)]),
			PackedColorArray([Color("#24170e"), Color("#24170e"), Color("#120c08"), Color("#120c08")]))
		draw_rect(Rect2(0, size.y * 0.7, size.x, size.y * 0.3), Color("#120c08"))
		var x := 46.0
		while x < size.x:
			draw_rect(Rect2(x, 0, 2, size.y), Color(0, 0, 0, 0.18))
			x += 48
		for sx in [0.18, 0.82]:
			GemArt.radial_disc(self, Vector2(size.x * sx, 0), size.x * 0.4, Color(1, 0.82, 0.55, 0.2), Color(1, 0.82, 0.55, 0.06), Color(1, 0.82, 0.55, 0), 0.5, 32)
		GemArt.radial_disc(self, Vector2(size.x / 2, -size.y * 0.04), size.x * 0.9, Color(1, 0.78, 0.47, 0.14), Color(1, 0.78, 0.47, 0.05), Color(1, 0.78, 0.47, 0), 0.5, 40)
