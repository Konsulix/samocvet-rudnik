class_name Museum
extends Control
## The inventory (for now the old museum): glass cases with the specimens you kept, jewellery and the workshop
## that makes it from cut stones. Every species ever found is in the atlas (Atlas), not here.
## Any piece opens in 3D; kept stones can be cut (a gamble on their value) or sold.

signal go(screen: String)

const SORTS := [["value", "Valuable"], ["rare", "Rare"], ["new", "New"]]

var tab := "spc"
var sort := "value"
var mine := -1          # the stones of one mine only (-1: all)
var content: VBoxContainer
var scroll: ScrollContainer

static var _round_mat: ShaderMaterial
static var start_tab := "spc"

func _ready() -> void:
	size = get_viewport_rect().size
	tab = start_tab
	var bg: Control = Atlas.SlateBg.new() if tab == "spc" else MuseumBg.new()
	bg.size = size
	bg.name = "Bg"
	add_child(bg)
	render()

static func cut_ok(s: Dictionary) -> bool:
	var c: String = s.get("cut", "")
	return c != "" and c != "broken"

func render() -> void:
	var keep_scroll := scroll.scroll_vertical if scroll else 0
	for ch in get_children():
		if ch.name == "Bg": continue
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
		_: _cases()
	var tail := Control.new()
	tail.custom_minimum_size = Vector2(0, 16)
	content.add_child(tail)
	if tab == "spc":
		var dup := _dupes()
		if dup.size():
			root.add_child(_sell_bar(dup))
	root.add_child(Chrome.nav_bar("museum", func(id: String): go.emit(id)))
	if keep_scroll:
		await get_tree().process_frame
		scroll.scroll_vertical = keep_scroll

func _head() -> void:
	var worth := 0
	for st in Save.d.coll: worth += int(st.value)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	var back := Kit.button("", "sq_dark", 16, 2.0)
	back.custom_minimum_size = Vector2(32, 32)
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var chev := Control.new()
	chev.set_anchors_preset(Control.PRESET_FULL_RECT)
	chev.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chev.draw.connect(func():
		var c := chev.size / 2.0 + Vector2(-1, 0)
		chev.draw_polyline(PackedVector2Array([c + Vector2(4, -8), c + Vector2(-4, 0), c + Vector2(4, 8)]), Kit.CREAM, 3.0, true))
	back.add_child(chev)
	back.pressed.connect(func():
		Sfx.play("tab")
		go.emit("museum"))
	head.add_child(back)
	var t := VBoxContainer.new()
	t.add_theme_constant_override("separation", -4)
	t.add_child(Kit.label("Stones" if tab == "spc" else "Workshop", 20, UI.display, Kit.CREAM))
	if tab == "spc":
		t.add_child(Kit.label("%d · %s" % [Save.d.coll.size(), UI.fmt(worth)], 12, UI.body_bold, Kit.AMBER))
	else:
		t.add_child(Kit.label("Jewellery · %d" % Save.d.jewels.size(), 12, UI.body_bold, Kit.AMBER))
	head.add_child(t)
	if tab == "spc":
		# two pickers instead of rows of buttons: they hold any number of mines
		var sort_n := ""
		for o in SORTS:
			if o[0] == sort: sort_n = o[1]
		var sp := _picker(sort_n, SORTS, sort, func(id: String): sort = id)
		var picks := HBoxContainer.new()
		picks.alignment = BoxContainer.ALIGNMENT_CENTER
		picks.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		picks.add_theme_constant_override("separation", 14)
		head.add_child(picks)
		var mines := [[-1, "All mines"]]
		for a in Data.AREAS.size():
			if Atlas.is_open(a): mines.append([a, String(Data.AREAS[a].n)])
		var mine_n := "All mines"
		for o in mines:
			if int(o[0]) == mine: mine_n = o[1]
		picks.add_child(sp)
		picks.add_child(_picker(mine_n, mines, mine, func(id): mine = int(id)))
	content.add_child(head)

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
	if mine >= 0:
		list = list.filter(func(st: Dictionary) -> bool: return int(st.get("area", 0)) == mine)
	match sort:
		"rare": list.sort_custom(func(a, b): return int(a.tier) > int(b.tier) or (int(a.tier) == int(b.tier) and int(a.value) > int(b.value)))
		"new": list.sort_custom(func(a, b): return int(a.id) > int(b.id))
		_: list.sort_custom(func(a, b): return int(a.value) > int(b.value))
	if list.is_empty():
		content.add_child(note("No stones here yet. Stones drop on levels: reach the specimen in the rock."))
		return
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	var w := (size.x - 24 - 20) / 3.0
	# one tile per species: its stones in the sort's order, the tile shows the first; a pile swipes through the rest
	var groups := {}
	var order := []
	for st in list:
		if not groups.has(st.sid):
			groups[st.sid] = []
			order.append(st.sid)
		groups[st.sid].append(st)
	for sid in order:
		grid.add_child(_tile(groups[sid], w))
	content.add_child(grid)

## a small chip with the current choice and ▾; tapped, a short list of the choices
func _picker(label: String, opts: Array, cur: Variant, pick: Callable) -> Button:
	var b := Button.new()
	b.text = label + " ▾"
	b.add_theme_font_override("font", UI.body_bold)
	b.add_theme_font_size_override("font_size", 12)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, Kit.AMBER)
	var st := StyleBoxEmpty.new()
	st.content_margin_left = 8
	st.content_margin_right = 8
	st.content_margin_bottom = 7
	for k in ["normal", "hover", "pressed", "focus"]: b.add_theme_stylebox_override(k, st)
	b.custom_minimum_size = Vector2(0, 30)
	b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var tex := Kit.tex("underline")
	b.draw.connect(func():
		const H := 6.0           # as Reveal.chip: the texture 8 pt tall, its ends 4 of its 64 pt
		var ts := tex.get_size()
		var e := ts.y * 4.0 / 8.0
		var ep := H * 4.0 / 8.0
		var y := b.size.y - H + 0.5
		var w := b.size.x
		b.draw_texture_rect_region(tex, Rect2(0, y, ep, H), Rect2(0, 0, e, ts.y))
		b.draw_texture_rect_region(tex, Rect2(ep, y, w - ep * 2, H), Rect2(e, 0, ts.x - e * 2, ts.y))
		b.draw_texture_rect_region(tex, Rect2(w - ep, y, ep, H), Rect2(ts.x - e, 0, e, ts.y)))
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func():
		var v := Ov.card(280)
		for o in opts:
			var id = o[0]
			var on: bool = id == cur
			var ob := Kit.button(("✓  " if on else "") + String(o[1]), "tab_on" if on else "tab", 15, 0.0)
			ob.custom_minimum_size = Vector2(0, 42)
			ob.pressed.connect(func():
				Ov.close()
				if on: return
				Sfx.play("tab")
				pick.call(id)
				scroll.scroll_vertical = 0
				render())
			v.add_child(ob))
	return b

## a species' tile like the atlas's: the first stone on its own tinted ground, the name and the rarity's rule in the
## corner, the price low on the right; more of them: two more edges behind and the count
func _tile(g: Array, w: float) -> Control:
	var s0: Dictionary = g[0]
	var box := Control.new()
	box.custom_minimum_size = Vector2(w, w * 1.12)
	var lift := 4.0 if g.size() > 1 else 0.0
	var spc := Data.sp_color(s0.sid)
	if g.size() > 1:
		for k in [2, 1]:
			var edge := Panel.new()
			var es := StyleBoxFlat.new()
			es.bg_color = Color("#17130f")
			es.border_color = Color(Kit.AMBER, 0.14 + 0.08 * (2 - k))
			es.set_border_width_all(1)
			es.set_corner_radius_all(10)
			edge.add_theme_stylebox_override("panel", es)
			edge.position = Vector2(2.0 * k + 2.0, 0)
			edge.size = Vector2(w - 2.0 * k - 2.0, w * 1.12 - 2.0 * k - 2.0)
			edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			box.add_child(edge)
	var rc := Data.rarity_color(int(s0.tier))
	var b := Button.new()
	b.position = Vector2(0, lift)
	b.size = Vector2(w - lift, w * 1.12 - lift)
	var st := StyleBoxFlat.new()
	st.bg_color = Color("#17130f").lerp(spc, 0.06)
	st.border_color = Color(Kit.AMBER, 0.38)
	st.set_border_width_all(1)
	st.set_corner_radius_all(10)
	st.anti_aliasing = true
	for k in ["normal", "hover", "focus"]: b.add_theme_stylebox_override(k, st)
	var sp := st.duplicate() as StyleBoxFlat
	sp.bg_color = Color("#17130f").lerp(spc, 0.16)
	b.add_theme_stylebox_override("pressed", sp)
	b.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	var glow := Control.new()
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.draw.connect(func():
		GemArt.radial_disc(glow, glow.size * Vector2(0.5, 0.6), glow.size.x * 0.55, Color(spc, 0.2), Color(spc, 0.06), Color(spc, 0.0)))
	b.add_child(glow)
	var img := TextureRect.new()
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	img.set_anchors_preset(Control.PRESET_FULL_RECT)
	img.offset_top = w * 0.24
	img.offset_bottom = -w * 0.2
	img.offset_left = w * 0.08
	img.offset_right = -w * 0.08
	b.add_child(img)
	Atlas.cutout(Spec.of_stone(s0), func(tx: Texture2D): if is_instance_valid(img): img.texture = tx)
	var txt := VBoxContainer.new()
	txt.position = Vector2(9, 7)
	txt.add_theme_constant_override("separation", 2)
	txt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var nl := Kit.label(String(Data.SP[s0.sid].n), 11, UI.body_bold, Kit.CREAM)
	nl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	nl.add_theme_constant_override("shadow_offset_y", 1)
	nl.clip_text = true
	nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nl.custom_minimum_size = Vector2(w - 26 - lift, 0)
	txt.add_child(nl)
	var rule := ColorRect.new()
	rule.color = rc.lightened(0.15)
	rule.custom_minimum_size = Vector2(18, 1.5)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	txt.add_child(rule)
	b.add_child(txt)
	if cut_ok(s0):
		var cm := Kit.label("✦", 12, UI.body_bold, Kit.AMBER)
		cm.position = Vector2(w - lift - 20, 6)
		b.add_child(cm)
	var price := Kit.label(UI.fmt(int(s0.value)), 11, UI.body_bold, Kit.AMBER)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	price.add_theme_constant_override("shadow_offset_y", 1)
	price.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	price.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	price.grow_vertical = Control.GROW_DIRECTION_BEGIN
	price.offset_right = -8
	price.offset_bottom = -5
	b.add_child(price)
	if g.size() > 1:
		var cnt := Kit.label("×%d" % g.size(), 11, UI.body_bold, Kit.DIM)
		cnt.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		cnt.add_theme_constant_override("shadow_offset_y", 1)
		cnt.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
		cnt.grow_vertical = Control.GROW_DIRECTION_BEGIN
		cnt.offset_left = 9
		cnt.offset_bottom = -5
		b.add_child(cnt)
	b.pressed.connect(func(): _open_stone(s0, g))
	box.add_child(b)
	return box

# ---------------------------------------------------------------- duplicates

## the stones that can go: every one but the best of its species, never a legendary or a cut one
func _dupes() -> Array:
	var best := {}
	for st in Save.d.coll:
		if not best.has(st.sid) or int(st.value) > int(best[st.sid].value): best[st.sid] = st
	var out := []
	for st in Save.d.coll:
		if st == best[st.sid] or bool(st.get("legend", false)) or String(st.get("cut", "")) != "": continue
		out.append(st)
	return out

func _sell_bar(dup: Array) -> Control:
	var sum := 0
	for st in dup: sum += roundi(float(st.value) * Save.coin_mul())
	var m := MarginContainer.new()
	for side in ["left", "right"]: m.add_theme_constant_override("margin_" + side, 12)
	m.add_theme_constant_override("margin_bottom", 6)
	var b := Kit.button("Sell %d duplicates · %s" % [dup.size(), UI.coins(sum)], "btn_gold", 15, 4.0)
	b.custom_minimum_size = Vector2(0, 46)
	b.pressed.connect(func(): _sell_dupes(dup, sum))
	m.add_child(b)
	return m

func _sell_dupes(dup: Array, sum: int) -> void:
	Ov.panel("Sell duplicates?", "%d stones go, the best of every species stays. Legendary and cut stones are never sold here." % dup.size(), [
		["Sell · " + UI.coins(sum), "gold", func():
			for st in dup: Save.d.coll.erase(st)
			Save.d.coins += sum
			Save.persist()
			Sfx.play("coin")
			Ov.close()
			render()],
		["Keep them", "glass", func(): Ov.close()]])

## for screenshots: ui=swipe_stack opens the biggest pile and swipes once to its second stone
func _swipe_stack() -> void:
	_open_stack()
	await get_tree().create_timer(0.6).timeout
	var groups := {}
	var all: Array = Save.d.coll.duplicate()
	all.sort_custom(func(a, b): return int(a.value) > int(b.value))
	for s in all:
		if not groups.has(s.sid): groups[s.sid] = []
		groups[s.sid].append(s)
	var best: Array = []
	for k in groups:
		if groups[k].size() > best.size(): best = groups[k]
	_open_stone(best[1], best, 1)

## for screenshots: ui=open_stack opens the gallery of the species with the most stones
func _open_stack() -> void:
	var groups := {}
	var all: Array = Save.d.coll.duplicate()
	all.sort_custom(func(a, b): return int(a.value) > int(b.value))
	for s in all:
		if not groups.has(s.sid): groups[s.sid] = []
		groups[s.sid].append(s)
	var best: Array = []
	for k in groups:
		if groups[k].size() > best.size(): best = groups[k]
	if best.size(): _open_stone(best[0], best)

## for screenshots: ui=open_first
func _open_first() -> void:
	if Save.d.coll.size(): _open_stone(Save.d.coll[0])

## for screenshots: ui=open_uncut
func _open_uncut() -> void:
	for s in Save.d.coll:
		if s.get("cut", "") == "":
			_open_stone(s)
			return

## group: the stones of one species in the showcase's order; a sideways swipe over the info panel brings the next one
## (the stone itself turns under the finger, so the swipe is taken below it), from: -1 / 1 the side it slides in from
func _open_stone(s: Dictionary, group := [], from := 0) -> void:
	var v := Ov.card(350, Data.rarity_color(int(s.tier)))
	Reveal.stone_card(v, s, 400, func(): Ov.close())
	if group.size() > 1:
		_swipe_between(v, s, group, from)
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

func _swipe_between(v: VBoxContainer, s: Dictionary, group: Array, from: int) -> void:
	var i := group.find(s)
	# where it is in the pile: a dot for each stone, this one lit
	var dots := HBoxContainer.new()
	dots.alignment = BoxContainer.ALIGNMENT_CENTER
	dots.add_theme_constant_override("separation", 6)
	for k in group.size():
		var d := Control.new()
		d.custom_minimum_size = Vector2(7, 7)
		var on := k == i
		d.draw.connect(func(): d.draw_circle(Vector2(3.5, 3.5), 3.5 if on else 2.5, Kit.AMBER if on else Color(Kit.DIM, 0.6)))
		dots.add_child(d)
	v.add_child(dots)
	v.move_child(dots, 0)
	var info := v.get_parent() as Control
	var start := [Vector2.ZERO, false]
	info.mouse_filter = Control.MOUSE_FILTER_STOP
	info.gui_input.connect(func(e: InputEvent):
		var press: bool = (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT) or e is InputEventScreenTouch
		if not press: return
		if e.pressed:
			start[0] = e.position
			start[1] = true
		elif start[1]:
			start[1] = false
			var d: Vector2 = e.position - start[0]
			if absf(d.x) > 48.0 and absf(d.x) > absf(d.y) * 1.5:
				var step := -1 if d.x > 0.0 else 1
				var j := clampi(i + step, 0, group.size() - 1)
				if j != i:
					# the new card's own page turn (Ov.card) is the swipe's sound
					_open_stone(group[j], group, step))
	# the new card slides in from the side it was swiped from
	# (the holder itself is placed by its CenterContainer, so the card and its halo inside it are moved, not the holder)
	if from != 0:
		var h := Ov.holder()
		if h:
			h.modulate.a = 0.0
			var tw := h.create_tween().set_parallel()
			tw.tween_property(h, "modulate:a", 1.0, 0.18)
			for c in h.get_children():
				var ci := c as Control
				if ci == null: continue
				tw.tween_property(ci, "position:x", ci.position.x, 0.22).from(ci.position.x + 70.0 * from).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

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
