class_name Reveal
extends RefCounted
## Finding out what you dug up: crack a nodule open with three taps, then turn the specimen in your hand
## and decide whether to sell it or keep it. Both steps are awaited:  await Reveal.new().crack(s, title)

signal finished

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
		Save.persist()
	var v := Ov.card(350, Data.rarity_color(tier))
	var traits: Array = s.get("traits", [])
	stone_card(v, s, 400 if others.is_empty() else 360)
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
		Ov.toast("Added to the collection")
		finished.emit()
	v.add_child(action_row(UI.button("Sell · " + UI.coins(price), "soft_gold", 16), sell, UI.button("Keep", "soft_green", 16), keep))

## the stone is the star: name on top, a big live specimen in a rounded frame, then only weight,
## grade and soundness; rarity is the colour of the card's glow, the rest are badges. Shared with the museum.
## on_close: a small ✕ in the header (the museum's card), instead of a Close button
static func stone_card(v: VBoxContainer, s: Dictionary, view_h: float, on_close := Callable()) -> SpecView:
	v.add_theme_constant_override("separation", 10)
	# the name in the same colour as the card's glow: the rarity at a glance
	var name_l := UI.title(Data.SP[s.sid].n, 26)
	name_l.add_theme_color_override("font_color", Data.rarity_color(int(s.tier)).lightened(0.15))
	if on_close.is_valid():
		# the name stays centred: an empty slot on the left balances the ✕ on the right
		var head := HBoxContainer.new()
		var pad := Control.new()
		pad.custom_minimum_size = Vector2(36, 0)
		head.add_child(pad)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(name_l)
		var x := UI.button("✕", "glass", 16)
		x.custom_minimum_size = Vector2(36, 36)
		x.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		x.pressed.connect(on_close)
		head.add_child(x)
		v.add_child(head)
	else:
		v.add_child(name_l)
	var so := Spec.of_stone(s)
	var frame := PanelContainer.new()
	var fst := StyleBoxFlat.new()
	fst.bg_color = Color.WHITE
	fst.set_corner_radius_all(20)
	fst.anti_aliasing = true
	frame.add_theme_stylebox_override("panel", fst)
	frame.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	var view := SpecView.new(384)
	view.custom_minimum_size = Vector2(314, view_h)
	frame.add_child(view)
	v.add_child(frame)
	view.show_spec(so)
	if s.get("legend", false):
		view.add_child(legend_frame())
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
	flow.add_theme_constant_override("h_separation", 6)
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

## rare: a gold badge (a valuable trait); growth: a quiet outlined one (what grew on the stone)
static func chip(t: String, rare := false, growth := false) -> Label:
	var l := UI.label(t, 12, UI.body_bold, Color("#2a1a00") if rare else UI.MUTED if growth else UI.INK)
	var st := StyleBoxFlat.new()
	st.bg_color = UI.GOLD if rare else Color(1, 1, 1, 0.03) if growth else Color(1, 1, 1, 0.1)
	if growth:
		st.set_border_width_all(1)
		st.border_color = Color(1, 1, 1, 0.18)
	st.set_corner_radius_all(10)
	st.content_margin_left = 9
	st.content_margin_right = 9
	st.content_margin_top = 3
	st.content_margin_bottom = 3
	l.add_theme_stylebox_override("normal", st)
	return l
