class_name Reveal
extends RefCounted
## Finding out what you dug up: crack a nodule open with three taps, then turn the specimen in your hand
## and decide whether to sell it or keep it. Both steps are awaited:  await Reveal.new().crack(s, title)

signal finished
signal replied    # the reply button was pressed (see `reply`)

## a joke the guide plays (the prologue's gift, docs/onboarding.md): the card first shows `name_as` instead of the stone's
## name and one button, `reply` - the player's own words; pressed, it emits `replied` and waits for unmask(), which
## types the real name in and brings the usual Sell / Keep
var name_as := ""
var reply := ""
var _btn_row: Control
var _row_make: Callable
static var _name_l: Label   # the last card's name, for unmask()

## a bonus stone from a geode: tap it open first
func crack(s: Dictionary, title := "Crack the stone") -> void:
	var v := Ov.card()
	v.add_child(UI.title(title, 22))
	var hits := [0]
	var nod := Control.new()
	nod.custom_minimum_size = Vector2(240, 240)
	nod.mouse_filter = Control.MOUSE_FILTER_STOP
	nod.pivot_offset = Vector2(120, 120)
	nod.material = BoardSprites.plain_material()   # the stock shader draws no textures on iPhone (see Level)
	nod.draw.connect(func():
		GemArt.radial_disc(nod, Vector2(120, 120), 120, Color(0.78, 0.59, 1, 0.28), Color(0.78, 0.59, 1, 0.1), Color(0.78, 0.59, 1, 0))
		nod.draw_texture_rect(GemArt.NODULE, Rect2(20, 20, 200, 200), false)
		for line in BoardView.crack_paths(int(s.id), hits[0] * 2 + 1 if hits[0] else 0):
			var pts := PackedVector2Array()
			for q in line: pts.append(Vector2(30, 30) + q * 1.8)
			nod.draw_polyline(pts, Color(0.08, 0.05, 0.03), 4.0, true)
			nod.draw_polyline(pts, Color(1, 0.86, 0.6), 1.6, true))
	var hint := Ov.text("Tap the stone")
	var wrap := CenterContainer.new()
	wrap.add_child(nod)
	v.add_child(wrap)
	v.add_child(hint)
	nod.gui_input.connect(func(e: InputEvent):
		var tap: bool = (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed)
		if not tap or hits[0] >= 3: return
		hits[0] += 1
		Sfx.play("crack", hits[0])
		Sfx.buzz(20)
		nod.queue_redraw()
		var tw := nod.create_tween()
		tw.tween_property(nod, "scale", Vector2(0.93, 0.93), 0.05)
		tw.tween_property(nod, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_chips(nod, 10 + hits[0] * 6)
		if hits[0] >= 3:
			nod.get_tree().create_timer(0.3).timeout.connect(func(): show_stone(s)))
	await finished

func _chips(at: Control, n: int) -> void:
	var p := CPUParticles2D.new()
	p.position = Vector2(120, 120)
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = n
	p.lifetime = 0.8
	p.direction = Vector2(0, -1)
	p.spread = 180
	p.initial_velocity_min = 120
	p.initial_velocity_max = 320
	p.gravity = Vector2(0, 900)
	p.scale_amount_min = 4
	p.scale_amount_max = 9
	p.angular_velocity_min = -400
	p.angular_velocity_max = 400
	var g := Gradient.new()
	g.set_color(0, Color("#8a7660"))
	g.add_point(0.5, Color("#5e4e3e"))
	g.set_color(g.get_point_count() - 1, Color("#b09a80"))
	p.color_initial_ramp = g
	at.add_child(p)
	p.emitting = true
	at.get_tree().create_timer(1.2).timeout.connect(p.queue_free)

## the reveal: a live specimen, its label, sell or keep. `others` were the stones not chosen.
func show_stone(s: Dictionary, others := []) -> void:
	var tier: int = s.tier
	Sfx.play("reveal", tier)
	Sfx.buzz(140 if tier >= 3 else 40)
	if not s.sid in Save.d.seen:
		Save.d.seen.append(s.sid)
	# into the atlas whether it is kept or sold
	Save.note_find(s, Save.area(), mini(int(Save.d.depth_sel[Save.area()]), int(Save.d.depth[Save.area()])))
	Save.persist()
	var v := Ov.card(350, Data.rarity_color(tier))
	var traits: Array = s.get("traits", [])
	var shown := s.duplicate()
	if name_as != "": shown.name_as = name_as
	stone_card(v, shown, 400 if others.is_empty() else 360)
	if others.size():
		var names := []
		for o in others: names.append(Data.SP[o.sid].n)
		v.add_child(Ov.text("The others were: " + ", ".join(names), 13))
	var price := roundi(float(s.value) * Save.coin_mul())
	var sell := func():
		Save.d.coins += price
		Save.persist()
		Sfx.play("coin")
		Ov.close()
		finished.emit()
	var keep := func():
		# where it was found: the mine's screen puts the best find of each depth on its pedestal
		Save.d.coll.append({id = s.id, sid = s.sid, kind = s.get("kind", "crystal"), gi = s.gi, traits = traits, legend = s.get("legend", false), g = s.g, value = s.value, tier = tier,
			area = Save.area(), dl = mini(int(Save.d.depth_sel[Save.area()]), int(Save.d.depth[Save.area()]))})
		Save.persist()
		Ov.close()
		Ov.toast("Added to the inventory")
		finished.emit()
	_row_make = func() -> Control: return action_row(Kit.button("Sell · " + UI.coins(price), "btn_gold", 16, 4.0), sell, Kit.button("Keep", "btn_green", 17, 4.0), keep)
	if reply != "":
		var b := Kit.button(reply, "btn_gold", 17, 4.0)
		b.custom_minimum_size = Vector2(0, 48)
		b.pressed.connect(func():
			b.disabled = true
			replied.emit())
		_btn_row = b
	else:
		_btn_row = _row_make.call()
	v.add_child(_btn_row)

## the joke is over: the stone's own name types in over `name_as`, and the usual buttons come
func unmask(s: Dictionary) -> void:
	if is_instance_valid(_name_l):
		_name_l.text = Data.SP[s.sid].n
		_name_l.visible_ratio = 0.0
		_name_l.create_tween().tween_property(_name_l, "visible_ratio", 1.0, 0.6)
	if is_instance_valid(_btn_row):
		var parent := _btn_row.get_parent()
		var at := _btn_row.get_index()
		_btn_row.queue_free()
		_btn_row = _row_make.call()
		parent.add_child(_btn_row)
		parent.move_child(_btn_row, at)

## the stone is the star: the live specimen fills the whole card under the frame (drag it anywhere above the info),
## its name in the top left corner over a soft shade, a thin ✕ in the top right; below, an info panel with rounded
## top corners laps over the stone: weight, grade and soundness, the gene tags, and whatever the caller adds to `v`
## (the card's box now sits inside that panel). Rarity is the colour of the card's glow. Shared with the museum.
## on_close: the ✕ (the museum's card), instead of a Close button
const CARD_PAD := 7.0        # the card's frame to the stone: just inside the brass rim
const INFO_R := 22.0         # the info panel's top corners
const TITLE_H := 64.0        # the name in the corner covers this much of the stone's frame

static func stone_card(v: VBoxContainer, s: Dictionary, view_h: float, on_close := Callable()) -> SpecView:
	# the card's own box becomes the info panel's content: the stone goes above it, edge to edge
	var card := v.get_parent() as PanelContainer
	card.add_theme_stylebox_override("panel", Kit.box("window", CARD_PAD))
	card.remove_child(v)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", int(-INFO_R))
	card.add_child(outer)
	v.add_theme_constant_override("separation", 10)
	var so := Spec.of_stone(s)
	var frame := PanelContainer.new()
	var fst := StyleBoxFlat.new()
	fst.bg_color = Color.WHITE
	fst.corner_radius_top_left = 15
	fst.corner_radius_top_right = 15
	fst.anti_aliasing = true
	frame.add_theme_stylebox_override("panel", fst)
	frame.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	var view := SpecView.new(384)
	view.custom_minimum_size = Vector2(320, view_h + INFO_R)
	frame.add_child(view)
	outer.add_child(frame)
	view.show_spec(so)
	# the stone in the middle of what is left free: below the name, above the panel's lip (the camera rises a little)
	view.resized.connect(func():
		var cam := view.studio.cam
		var span := 2.0 * 6.6 * tan(deg_to_rad(28.0) / 2.0)    # what the studio's camera sees across, at the stone
		var per_pt := span / (view.size.x if view.size.y > view.size.x else view.size.y)
		cam.v_offset = (TITLE_H - INFO_R) / 2.0 * per_pt)
	# over the stone: a shade under the name, the name in the corner with a short rule in the rarity's colour, the ✕
	var shade := TextureRect.new()
	var gt := GradientTexture2D.new()
	var gg := Gradient.new()
	gg.set_color(0, Color(0, 0, 0, 0.55))
	gg.set_color(1, Color(0, 0, 0, 0))
	gt.gradient = gg
	gt.fill_from = Vector2(0.5, 0)
	gt.fill_to = Vector2(0.5, 1)
	gt.width = 4
	gt.height = 64
	shade.texture = gt
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.set_anchors_preset(Control.PRESET_TOP_WIDE)
	shade.offset_bottom = 92
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(shade)
	var head := VBoxContainer.new()
	head.position = Vector2(18, 14)
	head.add_theme_constant_override("separation", 2)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_l := Kit.label(String(s.get("name_as", Data.SP[s.sid].n)), 30, UI.display, Kit.CREAM)
	_name_l = name_l
	name_l.add_theme_constant_override("outline_size", 0)
	name_l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	name_l.add_theme_constant_override("shadow_offset_y", 2)
	head.add_child(name_l)
	var rule := ColorRect.new()
	rule.color = Data.rarity_color(int(s.tier)).lightened(0.15)
	rule.custom_minimum_size = Vector2(28, 1.5)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(rule)
	view.add_child(head)
	if on_close.is_valid():
		var x := thin_close()
		x.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		x.position = Vector2(-48, 14)
		x.pressed.connect(on_close)
		view.add_child(x)
	# the info panel: the card's own slate (the window's tile at its size), rounded on top, lapping over the stone's
	# lower edge; its rounded shape is a mask (clip_children), the slate and a soft shade along its top are drawn in it
	var info := PanelContainer.new()
	var ist := StyleBoxFlat.new()
	ist.bg_color = Color.WHITE
	ist.corner_radius_top_left = int(INFO_R)
	ist.corner_radius_top_right = int(INFO_R)
	ist.corner_radius_bottom_left = 15
	ist.corner_radius_bottom_right = 15
	ist.anti_aliasing = true
	ist.content_margin_left = 14
	ist.content_margin_right = 14
	ist.content_margin_top = 16
	ist.content_margin_bottom = 12
	info.add_theme_stylebox_override("panel", ist)
	info.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	var slate := Control.new()
	slate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slate.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	slate.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var tile := Kit.tex("slate")
	slate.draw.connect(func():
		const S := 3.6               # tile px per point, as the window draws it (Kit.FRAMES.window)
		slate.draw_set_transform(-Vector2(14, 16), 0.0, Vector2.ONE / S)
		slate.draw_texture_rect(tile, Rect2(Vector2.ZERO, info.size * S), true)
		slate.draw_set_transform(-Vector2(14, 16), 0.0, Vector2.ONE)
		# the stone's shade fading down into the panel
		for i in 10:
			slate.draw_rect(Rect2(0, i, info.size.x, 1), Color(0, 0, 0, 0.3 * (1.0 - i / 10.0))))
	info.add_child(slate)
	info.resized.connect(func(): slate.queue_redraw())
	info.add_child(v)
	outer.add_child(info)
	# the panel's brass rim, a layer of its own over the whole card: it rises out of the card's rim on each side,
	# turns round the panel's rounded corner and runs across its top — one ribbon, no joint
	card.add_child(_info_rim(card, info))
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 8)
	_stat(stats, "Weight", Stones.fmt_weight(int(s.g)))
	_stat(stats, "Grade", String(Data.GR[int(s.gi)].n))
	if s.has("integ"):
		var ig := int(s.integ)
		_stat(stats, "Soundness", "%d%%" % ig, UI.GOOD if ig >= 90 else Color("#f0b040") if ig >= 60 else Color("#ff6a5a"))
	else:
		_stat(stats, "Value", UI.fmt(int(s.value)), UI.GOLD)
	v.add_child(stats)
	var gene := SpecGenome.of(so)
	var flow := HFlowContainer.new()
	flow.alignment = FlowContainer.ALIGNMENT_CENTER
	flow.add_theme_constant_override("h_separation", 12)
	flow.add_theme_constant_override("v_separation", 6)
	# every gene the find rolled, keyed as the builder marks them: [name, rare]; hidden until the stone is built
	var genes := {}
	if String(gene.fx) != "":
		genes.fx = [SpecLegend.FX_N.get(gene.fx, gene.fx), true]
	for id in s.get("traits", []):
		var t: Dictionary = Data.TR[id]
		genes[id] = [t.n, float(t.p) < 0.06]
	for a in gene.accents:
		var fn := SpecFossil.gene_name(a, gene.get("fossil", {}))
		genes[a] = [fn if fn != "" else SpecFungi.NAMES[int(gene.shroom)] if a == "mushrooms" else SpecGenome.ACC_N.get(a, a), false]
	var chips := {}
	for id: String in genes:
		var c := chip(genes[id][0], genes[id][1], not (id in s.get("traits", [])) and id != "fx")
		c.modulate.a = 0.0
		chips[id] = c
		flow.add_child(c)
	if flow.get_child_count():
		v.add_child(flow)
	# then only what really grew on it stays (a gene the stone's form had no room for is not named),
	# and a tap on a badge (or on the stone) draws threads from name plates to where each grew
	view.built.connect(func(p: Node3D) -> void:
		var grown: Dictionary = p.get_meta("grown", {})
		var list := []
		for id: String in chips:
			var c: Label = chips[id]
			if not grown.has(id):
				c.queue_free()
				continue
			c.create_tween().tween_property(c, "modulate:a", 1.0, 0.3)
			list.append({id = id, name = genes[id][0], rare = genes[id][1], pts = grown[id]})
		if list.is_empty():
			flow.queue_free()
			return
		var co := SpecCallouts.attach(view)
		co.top_clear = TITLE_H - 10.0
		co.bottom_clear = INFO_R
		co.setup(list)
		var close := func() -> void:
			co.hide_all()
		co.plate_tapped.connect(func(_id: String) -> void: close.call())
		# a tap on the stone opens them all (none picked) or puts them away
		view.tapped.connect(func() -> void:
			if co.open: co.hide_all()
			else: co.show_all())
		for it: Dictionary in list:
			var id: String = it.id
			var c: Label = chips[id]
			c.mouse_filter = Control.MOUSE_FILTER_STOP
			c.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			c.gui_input.connect(func(e: InputEvent) -> void:
				if not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
					return
				c.accept_event()
				var tw := c.create_tween()
				c.pivot_offset = c.size * 0.5
				tw.tween_property(c, "scale", Vector2(0.92, 0.92), 0.05)
				tw.tween_property(c, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				if not co.open:
					co.show_all(id)
				elif co.sel == id:
					co.hide_all()
				else:
					co.select(id))
		if auto_callouts != "":
			co.show_all.call_deferred("" if auto_callouts == "1" else auto_callouts)
	, CONNECT_ONE_SHOT)
	return view

static var auto_callouts := ""   # for screenshots: open the callouts once built ("1": none picked)

## the info panel's rim over the card (stone_card): a ribbon of the frame's own brass (art/ui_kit/rule.png is cut
## from its top edge: dark outline, brass band, inner shade) laid on the card's rim on either side — fading in up it,
## exactly over it — then round the panel's top corners (outside them: its inner edge is the panel's edge) and across
static func _info_rim(card: Control, info: Control) -> Control:
	var rim := Control.new()
	rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rim.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var tex := Kit.tex("rule")
	const OUT := 5.0 / 3.6       # the frame's rim strip (rule.png's rows) starts this far in from the card's edge
	const WIDE := 20.0 / 3.6     # and is this wide
	const UP := 46.0             # how far up the card's rim the ribbon fades in
	rim.draw.connect(func():
		# all in this layer's own space, through the transforms (the card opens with a scale tween: global rects
		# taken mid-way would be off once it settles)
		var to_me := rim.get_global_transform().affine_inverse()
		var cg: Rect2 = to_me * card.get_global_transform() * Rect2(Vector2.ZERO, card.size)
		var ig: Rect2 = to_me * info.get_global_transform() * Rect2(Vector2.ZERO, info.size)
		var card_l := cg.position.x
		var card_r := cg.end.x
		var top := ig.position.y
		var R := INFO_R
		var mid := R + WIDE / 2.0                        # the ribbon's middle line: just outside the panel's corner
		var cl := Vector2(ig.position.x + R, top + R)    # the corners' centres
		var cr := Vector2(ig.end.x - R, top + R)
		var xl := card_l + OUT + WIDE / 2.0              # down the sides: right over the card's own rim
		var xr := card_r - OUT - WIDE / 2.0
		var path := PackedVector2Array()
		path.append(Vector2(xl, top + R + UP))
		path.append(Vector2(xl, top + R))
		for k in 17:
			var a := PI - k * (PI / 2.0) / 16.0
			path.append(cl + Vector2(cos(a) * (cl.x - xl), -sin(a) * mid))
		for k in 17:
			var a := PI / 2.0 - k * (PI / 2.0) / 16.0
			path.append(cr + Vector2(cos(a) * (xr - cr.x), -sin(a) * mid))
		path.append(Vector2(xr, top + R + UP))
		var lens := [0.0]
		for i in range(1, path.size()): lens.append(float(lens[i - 1]) + path[i].distance_to(path[i - 1]))
		var total: float = lens[-1]
		var nrm := func(i: int) -> Vector2:
			var a := path[maxi(0, i - 1)]
			var b := path[mini(path.size() - 1, i + 1)]
			return (b - a).normalized().orthogonal() * -1.0     # inwards, towards the panel
		for i in range(path.size() - 1):
			var p0 := path[i]
			var p1 := path[i + 1]
			var n0: Vector2 = nrm.call(i)
			var n1: Vector2 = nrm.call(i + 1)
			# along the ribbon: the strip's even middle (its ends fade out), once over the whole length
			var u0 := 0.3 + 0.4 * float(lens[i]) / total
			var u1 := 0.3 + 0.4 * float(lens[i + 1]) / total
			var f0 := clampf((top + R + UP - p0.y) / UP, 0.0, 1.0)
			var f1 := clampf((top + R + UP - p1.y) / UP, 0.0, 1.0)
			var c0 := Color(1, 1, 1, f0 * f0)
			var c1 := Color(1, 1, 1, f1 * f1)
			rim.draw_primitive(PackedVector2Array([p0 - n0 * WIDE / 2.0, p1 - n1 * WIDE / 2.0, p1 + n1 * WIDE / 2.0, p0 + n0 * WIDE / 2.0]),
				PackedColorArray([c0, c1, c1, c0]),
				PackedVector2Array([Vector2(u0, 0.0), Vector2(u1, 0.0), Vector2(u1, 1.0), Vector2(u0, 1.0)]), tex))
	info.item_rect_changed.connect(func(): rim.queue_redraw())
	card.item_rect_changed.connect(func(): rim.queue_redraw())
	return rim

## a quiet ✕ over the stone: a thin ring on a faint dark disc, a thin cross
static func thin_close() -> Button:
	var b := Button.new()
	b.size = Vector2(34, 34)
	b.custom_minimum_size = Vector2(34, 34)
	b.focus_mode = Control.FOCUS_NONE
	for st in ["normal", "hover", "pressed", "focus"]: b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.draw.connect(func():
		var c := b.size / 2
		var r := 16.0
		var k := 0.75 if b.button_pressed else 1.0
		b.draw_circle(c, r, Color(0, 0, 0, 0.35), true, -1.0, true)
		b.draw_arc(c, r, 0, TAU, 40, Color(Kit.CREAM, 0.45 * k), 1.0, true)
		var d := 5.5
		for v2: Vector2 in [Vector2(d, d), Vector2(d, -d)]:
			b.draw_line(c - v2, c + v2, Color(Kit.CREAM, 0.9 * k), 1.4, true))
	b.pressed.connect(func():
		Sfx.buzz(8)
		Sfx.play("click"))
	return b

## two quiet buttons side by side: [left] [right]
static func action_row(left: Button, on_left: Callable, right: Button, on_right: Callable) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	for pair in [[left, on_left], [right, on_right]]:
		var b: Button = pair[0]
		b.custom_minimum_size = Vector2(0, 48)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(pair[1])
		h.add_child(b)
	return h

## a golden frame for legendary finds: light running round it, sparks of colour, like a golden card
static func legend_frame() -> ColorRect:
	var fr := ColorRect.new()
	fr.set_anchors_preset(Control.PRESET_FULL_RECT)
	fr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;
void fragment(){
	vec2 d = min(UV, 1.0 - UV);
	float e = min(d.x, d.y);
	float band = 1.0 - smoothstep(0.0, 0.035, e);
	float ang = atan(UV.y - 0.5, UV.x - 0.5) / 6.2832;
	float run = pow(0.5 + 0.5 * sin((ang - TIME * 0.35) * 6.2832 * 2.0), 8.0);
	vec3 gold = vec3(1.0, 0.75, 0.3);
	vec3 hue = 0.5 + 0.5 * cos(6.2832 * (ang * 2.0 + TIME * 0.2 + vec3(0.0, 0.33, 0.67)));
	vec3 c = mix(gold, hue, 0.35) * (0.55 + 1.6 * run);
	float glow = (1.0 - smoothstep(0.0, 0.12, e)) * 0.35 * (0.6 + 0.4 * run);
	COLOR = vec4(c * 1.4, clamp(band + glow, 0.0, 1.0));
}
"
	var m := ShaderMaterial.new()
	m.shader = sh
	fr.material = m
	return fr

static func _row(box: VBoxContainer, k: String, val: String, col := UI.INK) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var a := UI.label(k, 15, UI.body, UI.MUTED)
	a.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(a)
	# a long value (three growths, a legendary effect) wraps onto more lines instead of pushing the card off screen
	var b := UI.label(val, 15, UI.body_bold, col)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(60, 0)
	h.add_child(b)
	box.add_child(h)

## one figure under the specimen: a small muted caption over a bold value
static func _stat(box: HBoxContainer, k: String, val: String, col := UI.INK) -> void:
	var c := VBoxContainer.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.add_theme_constant_override("separation", 0)
	for l in [UI.label(k, 12, UI.body, UI.MUTED), UI.label(val, 17, UI.body_bold, col)]:
		(l as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c.add_child(l)
	box.add_child(c)

## a gene's tag: just the word over a thin brass bar whose ends flare into notched tails, no box (chosen from GPT's
## sheet art/ui_kit/chips/ideas_a.png, no. 2; the bar is a texture, art/ui_kit/chips/underline.py: its ends stay as
## drawn, its middle stretches). rare (a valuable trait): amber, the brass full; growth (what grew on the stone): dim
static func chip(t: String, rare := false, growth := false) -> Label:
	var l := Kit.label(t, 13, UI.body_bold, Kit.AMBER if rare else Kit.DIM if growth else Kit.CREAM)
	l.add_theme_constant_override("outline_size", 3)
	var st := StyleBoxEmpty.new()
	st.content_margin_left = 8
	st.content_margin_right = 8
	st.content_margin_top = 1
	st.content_margin_bottom = 7
	l.add_theme_stylebox_override("normal", st)
	l.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var tex := Kit.tex("underline")
	var tint := Color.WHITE if rare else Color(0.4, 0.37, 0.33, 0.55) if growth else Color(0.85, 0.8, 0.74, 0.85)
	l.draw.connect(func():
		const H := 6.0           # points; the texture is 8 pt tall, its ends 4 of its 64 pt long
		var ts := tex.get_size()
		var e := ts.y * 4.0 / 8.0          # one end, in texture px
		var ep := H * 4.0 / 8.0            # one end, in points
		var y := l.size.y - H + 0.5
		var w := l.size.x
		l.draw_texture_rect_region(tex, Rect2(0, y, ep, H), Rect2(0, 0, e, ts.y), tint)
		l.draw_texture_rect_region(tex, Rect2(ep, y, w - ep * 2, H), Rect2(e, 0, ts.x - e * 2, ts.y), tint)
		l.draw_texture_rect_region(tex, Rect2(w - ep, y, ep, H), Rect2(ts.x - e, 0, e, ts.y), tint))
	return l
