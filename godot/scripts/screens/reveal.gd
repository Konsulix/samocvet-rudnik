class_name Reveal
extends RefCounted
## Finding out what you dug up: crack a nodule open with three taps, then turn the specimen in your hand
## and decide whether to sell it or keep it. Both steps are awaited:  await Reveal.new().crack(s, title)

signal finished

## a bonus stone from a geode: tap it open first
func crack(s: Dictionary, title := "Расколите камень") -> void:
	var v := Ov.card()
	v.add_child(UI.title(title, 22))
	var hits := [0]
	var nod := Control.new()
	nod.custom_minimum_size = Vector2(240, 240)
	nod.mouse_filter = Control.MOUSE_FILTER_STOP
	nod.pivot_offset = Vector2(120, 120)
	nod.draw.connect(func():
		GemArt.radial_disc(nod, Vector2(120, 120), 120, Color(0.78, 0.59, 1, 0.28), Color(0.78, 0.59, 1, 0.1), Color(0.78, 0.59, 1, 0))
		nod.draw_texture_rect(GemArt.NODULE, Rect2(20, 20, 200, 200), false)
		for line in BoardView.crack_paths(int(s.id), hits[0] * 2 + 1 if hits[0] else 0):
			var pts := PackedVector2Array()
			for q in line: pts.append(Vector2(30, 30) + q * 1.8)
			nod.draw_polyline(pts, Color(0.08, 0.05, 0.03), 4.0, true)
			nod.draw_polyline(pts, Color(1, 0.86, 0.6), 1.6, true))
	var hint := Ov.text("Нажимайте на камень")
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
	var sp: Dictionary = Data.SP[s.sid]
	var tier: int = s.tier
	Sfx.play("reveal", tier)
	Sfx.buzz(140 if tier >= 3 else 40)
	if not s.sid in Save.d.seen:
		Save.d.seen.append(s.sid)
		Save.persist()
	var v := Ov.card(350)
	var view := SpecView.new(384)
	view.custom_minimum_size = Vector2(314, 290)
	v.add_child(view)
	view.show_spec(Spec.of_stone(s))
	var rc := Data.rarity_color(tier)
	var rar := UI.label("легендарная находка" if s.get("legend", false) else String(Data.RAR[tier]), 13, UI.body_bold, rc)
	rar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rar.uppercase = true
	v.add_child(rar)
	var name_l := UI.title(sp.n, 24)
	v.add_child(name_l)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 2)
	_row(rows, "Вес", Stones.fmt_weight(int(s.g)))
	_row(rows, "Качество", String(Data.GR[int(s.gi)].n))
	if s.has("integ"):
		var ig := int(s.integ)
		_row(rows, "Целостность", "%d%%" % ig, UI.GOOD if ig >= 90 else Color("#f0b040") if ig >= 60 else Color("#ff6a5a"))
	_row(rows, "Оценка", UI.coins(int(s.value)), UI.GOLD)
	v.add_child(rows)
	var traits: Array = s.get("traits", [])
	if traits.size():
		var flow := HFlowContainer.new()
		flow.alignment = FlowContainer.ALIGNMENT_CENTER
		flow.add_theme_constant_override("h_separation", 6)
		flow.add_theme_constant_override("v_separation", 6)
		for id in traits:
			var t: Dictionary = Data.TR[id]
			flow.add_child(chip(t.n, float(t.p) < 0.06))
		v.add_child(flow)
	if others.size():
		var names := []
		for o in others: names.append(Data.SP[o.sid].n)
		v.add_child(Ov.text("Остальные были: " + ", ".join(names), 13))
	var price := roundi(float(s.value) * Save.coin_mul())
	v.add_child(Ov.btn("Продать · " + UI.coins(price), "gold", func():
		Save.d.coins += price
		Save.persist()
		Sfx.play("coin")
		Ov.close()
		finished.emit()))
	v.add_child(Ov.btn("В коллекцию", "green", func():
		Save.d.coll.append({id = s.id, sid = s.sid, kind = s.get("kind", "crystal"), gi = s.gi, traits = traits, legend = s.get("legend", false), g = s.g, value = s.value, tier = tier})
		Save.persist()
		Ov.close()
		Ov.toast("Камень в коллекции")
		finished.emit()))

static func _row(box: VBoxContainer, k: String, val: String, col := UI.INK) -> void:
	var h := HBoxContainer.new()
	var a := UI.label(k, 15, UI.body, UI.MUTED)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(a)
	h.add_child(UI.label(val, 15, UI.body_bold, col))
	box.add_child(h)

static func chip(t: String, rare := false) -> Label:
	var l := UI.label(t, 12, UI.body_bold, Color("#2a1a00") if rare else UI.INK)
	var st := StyleBoxFlat.new()
	st.bg_color = UI.GOLD if rare else Color(1, 1, 1, 0.1)
	st.set_corner_radius_all(10)
	st.content_margin_left = 9
	st.content_margin_right = 9
	st.content_margin_top = 3
	st.content_margin_bottom = 3
	l.add_theme_stylebox_override("normal", st)
	return l
