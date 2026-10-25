class_name Home
extends Control
## The home screen: the mine in cross-section fills the phone, with the mine's name on the sky,
## the task and Play buttons over the dark rock and the tab bar at the bottom.
## Tapping a horizon picks the depth to dig at; a locked one leads to the depot.

signal play(n: int, pre: Array, dl: int)
signal go(screen: String)

var scene: MineScene
var scene_holder: Node2D
var ui_root: VBoxContainer

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color("#0b0f17")
	bg.size = get_viewport_rect().size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	scene_holder = Node2D.new()
	add_child(scene_holder)
	scene = MineScene.new()
	scene_holder.add_child(scene)
	_dust()
	render()

func ai() -> int:
	return Save.area()

func dl_sel() -> int:
	return mini(int(Save.d.depth_sel[ai()]), int(Save.d.depth[ai()]))

func render() -> void:
	var vp := get_viewport_rect().size
	position = Vector2.ZERO
	size = vp
	var hv := roundf(clampf(360.0 * vp.y / maxf(1.0, vp.x), 600.0, 1000.0))
	var s := minf(vp.x / 360.0, vp.y / hv)
	scene_holder.scale = Vector2(s, s)
	scene_holder.position = Vector2((vp.x - 360.0 * s) / 2, (vp.y - hv * s) / 2)
	scene.setup(ai(), Save.d.built[ai()], int(Save.d.depth[ai()]), dl_sel(), hv)
	if ui_root:
		ui_root.queue_free()
	ui_root = VBoxContainer.new()
	ui_root.size = vp
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_theme_constant_override("separation", 0)
	add_child(ui_root)
	var pad := MarginContainer.new()
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]: pad.add_theme_constant_override("margin_" + side, 12)
	pad.add_theme_constant_override("margin_top", 10 + int(UI.safe_top()))
	pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ui_root.add_child(pad)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 4)
	pad.add_child(col)
	col.add_child(Chrome.top_bar())
	var A: Dictionary = Data.AREAS[ai()]
	var title := UI.title(A.n, 22)
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.35))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(title)
	var sub := UI.label(A.sub, 13, UI.body, Color("#d8e0ee"))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	sub.add_theme_constant_override("shadow_outline_size", 6)
	col.add_child(sub)
	var chip := UI.label("⛏ digging at %d m · open to %d m" % [Data.depth_m(ai(), dl_sel()), Data.depth_m(ai(), int(Save.d.depth[ai()]))], 12, UI.body_bold, Color("#ffd27a"))
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color(0.1, 0.07, 0.02, 0.75)
	cs.border_color = Color("#e3a51e", 0.5)
	cs.set_border_width_all(1)
	cs.set_corner_radius_all(12)
	cs.content_margin_left = 10
	cs.content_margin_right = 10
	cs.content_margin_top = 2
	cs.content_margin_bottom = 3
	chip.add_theme_stylebox_override("normal", cs)
	chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(chip)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(fill)
	# one row at the bottom, as in a mobile match-three: the big Play, the mine's progress beside it
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var play := _play_button()
	play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play.size_flags_stretch_ratio = 1.25
	row.add_child(play)
	var task := _tasks_button()
	task.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(task)
	col.add_child(row)
	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(0, 10)
	gap2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(gap2)
	ui_root.add_child(Chrome.nav_bar("home", func(id: String): go.emit(id)))

func _tasks_button() -> Button:
	var A: Dictionary = Data.AREAS[ai()]
	var built: Array = Save.d.built[ai()]
	var next: Array = []
	var ni := -1
	for i in A.tasks.size():
		if not A.tasks[i][0] in built:
			next = A.tasks[i]
			ni = i
			break
	# a depth's task waits until the shaft reaches it
	var deeper: bool = ni > int(Save.d.depth[ai()])
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 64)
	for s in ["normal", "hover", "pressed", "focus"]:
		var st := UI.glass(18, 0.82)
		st.border_color = Color("#e3a51e", 0.45)
		b.add_theme_stylebox_override(s, st)
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 12
	h.offset_right = -10
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 3)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(UI.label("Mine · %d/%d" % [built.size(), A.tasks.size()], 11, UI.body_bold, UI.MUTED))
	var tl := UI.label(("Dig down to %d m" % Data.depth_m(ai(), ni) if deeper else String(next[1])) if next.size() else "Fitted out!", 13, UI.body_bold)
	tl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tl.clip_text = true
	v.add_child(tl)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 7)
	bar.max_value = A.tasks.size()
	bar.value = built.size()
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.1)
	bg.set_corner_radius_all(4)
	var fg := StyleBoxFlat.new()
	fg.bg_color = UI.GOLD
	fg.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(bar)
	h.add_child(v)
	if next.size() and not deeper:
		h.add_child(ore_tag("ore", int(next[2]), 14))
	else:
		h.add_child(UI.label("⛏" if next.size() else "✓", 14, UI.display, UI.GOLD))
	b.add_child(h)
	b.pressed.connect(func(): go.emit("depot") if deeper else _open_tasks())
	return b

func _play_button() -> Button:
	var n: int = Save.d.level
	var def := Data.level_def(n)
	var b := UI.button("", "green", 20)
	b.custom_minimum_size = Vector2(0, 64)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", -2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := UI.label("Level %d" % n, 22, UI.display, Color("#06260f"))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var sub := UI.moves_text(int(def.moves)) + (" · hard" if def.get("hard", false) else "") + (" · streak %d" % Save.d.streak if Save.d.streak >= 2 else "")
	var s := UI.label(sub, 12, UI.body_bold, Color(0.02, 0.15, 0.06, 0.8))
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(s)
	b.add_child(v)
	# a glint sweeping across, like the prototype's shine
	# clipped by a rounded mask the shape of the button's face (clip_contents would square off its
	# corners and cut its glow into a hard-edged slab)
	var mask := Panel.new()
	var ms := StyleBoxFlat.new()
	ms.bg_color = Color.WHITE
	ms.set_corner_radius_all(18)
	ms.anti_aliasing = true
	mask.add_theme_stylebox_override("panel", ms)
	mask.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mask.set_anchors_preset(Control.PRESET_FULL_RECT)
	mask.offset_bottom = -6
	b.add_child(mask)
	var shine := ColorRect.new()
	shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shine.color = Color(1, 1, 1, 0.0)
	shine.set_anchors_preset(Control.PRESET_FULL_RECT)
	mask.add_child(shine)
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nvoid fragment(){ float x = fract(TIME / 3.2) * 2.4 - 0.7; float d = abs(UV.x - x - (UV.y - 0.5) * 0.25); COLOR = vec4(1.0, 1.0, 1.0, 0.45 * (1.0 - smoothstep(0.0, 0.12, d))); }"
	mat.shader = sh
	shine.material = mat
	b.pressed.connect(_on_play)
	return b

# ---------------------------------------------------------------- input on the picture

func _gui_input(e: InputEvent) -> void:
	var tap: bool = (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed)
	if not tap:
		return
	var p: Vector2 = scene_holder.get_global_transform().affine_inverse() * (e.position as Vector2)
	var k := scene.band_at(p)
	if k < 0:
		return
	accept_event()
	if k <= int(Save.d.depth[ai()]):
		if int(Save.d.depth_sel[ai()]) != k:
			Save.d.depth_sel[ai()] = k
			Save.persist()
			Sfx.play("swap")
			render()
			Ov.toast("Digging at %d m" % Data.depth_m(ai(), k))
	else:
		go.emit("depot")

func _dust() -> void:
	# motes drifting in the lamplight over the galleries
	var p := CPUParticles2D.new()
	p.amount = 40
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	var vp := get_viewport_rect().size
	p.position = Vector2(vp.x / 2, vp.y * 0.55)
	p.emission_rect_extents = Vector2(vp.x / 2, vp.y * 0.14)
	p.gravity = Vector2(0, -3)
	p.direction = Vector2(1, 0)
	p.spread = 180
	p.initial_velocity_min = 2
	p.initial_velocity_max = 8
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.2
	var g := Gradient.new()
	g.set_color(0, Color(1, 0.85, 0.55, 0))
	g.add_point(0.5, Color(1.3, 1.1, 0.7, 0.55))
	g.set_color(g.get_point_count() - 1, Color(1, 0.85, 0.55, 0))
	p.color_ramp = g
	add_child(p)

# ---------------------------------------------------------------- level panel

func _on_play() -> void:
	Save.tick_lives()
	if Save.d.lives <= 0:
		Ov.panel("No lives", "Next life in %d min." % Save.minutes_to_life(), [
			["Refill · 300 coins", "gold", func():
				if Save.d.coins < 300: return
				Save.d.coins -= 300
				Save.d.lives = Save.MAX_LIVES
				Save.d.life_at = 0
				Save.persist()
				Ov.close()
				render(), Save.d.coins >= 300],
			["Wait", "glass", func(): Ov.close()]])
		return
	_level_panel(dl_sel(), Data.streak_free(Save.d.streak))

func _level_panel(dl: int, sel: Array) -> void:
	var n: int = Save.d.level
	var def := Data.level_def(n)
	var free := Data.streak_free(Save.d.streak)
	for f in free:
		if not f in sel: sel.append(f)
	var v := Ov.card(350)
	v.add_child(UI.title("Level %d" % n, 24))
	v.add_child(Ov.text("%s%s · a specimen waits in the rock" % [UI.moves_text(int(def.moves) - dl / 2 + int(Save.d.eq.food)), " · hard" if def.get("hard", false) else ""], 14))
	# what the level asks for, read from its map
	var goals := HBoxContainer.new()
	goals.alignment = BoxContainer.ALIGNMENT_CENTER
	goals.add_theme_constant_override("separation", 12)
	goals.add_child(_goal_chip("find", 0, "specimen"))
	var map: String = def.get("map", "")
	var cnt := func(ch: String) -> int: return map.count(ch)
	for g in def.goals:
		var k: String = g[0]
		match k:
			"c": goals.add_child(_goal_chip("c", int(g[1]), str(int(g[2]))))
			"rock": goals.add_child(_goal_chip("rock", 0, str(cnt.call("r") + cnt.call("R") * 2)))
			"mud": goals.add_child(_goal_chip("mud", 0, str(cnt.call("m"))))
			"nug": goals.add_child(_goal_chip("nug", 0, str(cnt.call("n"))))
			"gas": goals.add_child(_goal_chip("gas", 0, str(cnt.call("g"))))
			"lock": goals.add_child(_goal_chip("lock", 0, str(cnt.call("l"))))
			_: goals.add_child(_goal_chip("geo", 0, str(cnt.call("G"))))
	v.add_child(goals)
	# depth: deeper is harder and pays more
	var open: int = Save.d.depth[ai()]
	var drow := HBoxContainer.new()
	drow.add_theme_constant_override("separation", 8)
	var minus := UI.button("−", "glass", 22)
	minus.custom_minimum_size = Vector2(46, 46)
	minus.disabled = dl <= 0
	minus.pressed.connect(func():
		Save.d.depth_sel[ai()] = dl - 1
		Save.persist()
		_level_panel(dl - 1, sel))
	drow.add_child(minus)
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 0)
	var dt := UI.label("Depth %d m" % Data.depth_m(ai(), dl), 16, UI.display, UI.GOLD)
	dt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(dt)
	var mods := ", ".join(Data.DSHORT.slice(1, dl + 1)) + " · coins ×%s, stones worth more" % str(Data.depth_pay(dl)) if dl else "ordinary board and ordinary rewards"
	var ds := Ov.text(mods, 12)
	mid.add_child(ds)
	drow.add_child(mid)
	var plus := UI.button("+", "glass", 22)
	plus.custom_minimum_size = Vector2(46, 46)
	plus.disabled = dl >= open
	plus.pressed.connect(func():
		Save.d.depth_sel[ai()] = dl + 1
		Save.persist()
		_level_panel(dl + 1, sel))
	drow.add_child(plus)
	v.add_child(drow)
	if open < Data.depths(ai()).size() - 1:
		v.add_child(Ov.text("Below %d m only machines get through: %s." % [Data.depth_m(ai(), open), String(Data.depth(ai(), open + 1).tool).to_lower()], 12))
	if Save.d.streak >= 2:
		v.add_child(Ov.text("Win streak: %d. %s" % [Save.d.streak, Data.streak_text(Save.d.streak)], 13, UI.GOLD))
	# pre-boosters to start with
	var pre := HBoxContainer.new()
	pre.add_theme_constant_override("separation", 8)
	for p in Data.PRE:
		var id: String = p.id
		var fr := id in free
		var have: int = Save.d.pre[id]
		var on := id in sel
		var b := Button.new()
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 92)
		var st := UI.glass(14, 0.6)
		st.bg_color = Color("#2c3c5a") if on else Color(0.06, 0.09, 0.14, 0.7)
		st.border_color = UI.GOLD if on else Color(1, 1, 1, 0.12)
		st.set_border_width_all(2 if on else 1)
		for s in ["normal", "hover", "pressed", "focus"]: b.add_theme_stylebox_override(s, st)
		var bv := VBoxContainer.new()
		bv.set_anchors_preset(Control.PRESET_FULL_RECT)
		bv.alignment = BoxContainer.ALIGNMENT_CENTER
		bv.add_theme_constant_override("separation", 0)
		bv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sp0: String = p.sp[0]
		var ic := UI.icon(38, func(ci: Control):
			GemArt.begin(ci, Transform2D(0.0, Vector2(19, 19)))
			GemArt.special(ci, sp0, 38)
			GemArt.end(ci))
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		bv.add_child(ic)
		var nl := UI.label(p.n, 13, UI.body_bold)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bv.add_child(nl)
		var sl := UI.label("free" if fr else ("have %d" % have) if have else "%d coins" % int(p.price), 11, UI.body, UI.GOOD if fr else UI.MUTED)
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bv.add_child(sl)
		b.add_child(bv)
		b.pressed.connect(func():
			if fr: return
			if on: sel.erase(id)
			elif have > 0: sel.append(id)
			elif Save.d.coins >= int(p.price):
				Save.d.coins -= int(p.price)
				Save.d.pre[id] += 1
				Save.persist()
				Sfx.play("coin")
				sel.append(id)
			else:
				Ov.toast("Not enough coins")
				return
			_level_panel(dl, sel))
		pre.add_child(b)
	v.add_child(pre)
	v.add_child(Ov.btn("Play", "green", func():
		var sps := []
		for p in Data.PRE:
			if p.id in sel:
				if not p.id in free: Save.d.pre[p.id] -= 1
				sps.append_array(p.sp)
		Save.persist()
		Ov.close()
		play.emit(n, sps, dl)))
	v.add_child(Ov.btn("Back", "glass", func(): Ov.close()))

func _goal_chip(k: String, colour: int, text: String) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	var glow := Color("#c8b0ff")
	var ic := UI.icon(34, func(ci: Control):
		GemArt.begin(ci, Transform2D.IDENTITY)
		GemArt.goal_icon(ci, k, colour, 34, glow)
		GemArt.end(ci))
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	var l := UI.label(text, 12, UI.body_bold)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	return v

# ---------------------------------------------------------------- tasks

static func chest_text(c: Dictionary) -> String:
	if c.get("coins", 0): return "%d coins" % int(c.coins)
	if c.get("pick", 0): return "pickaxe"
	if c.get("dyn", 0): return "dynamite"
	return "a charge before the level"

func _open_tasks() -> void:
	var a := ai()
	var A: Dictionary = Data.AREAS[a]
	var built: Array = Save.d.built[a]
	var open: int = Save.d.depth[a]
	var on := String(Data.ore(a).n).to_lower()
	var v := Ov.card(350)
	v.add_child(UI.title(A.n, 22))
	v.add_child(Ov.text("Each depth has one job, paid in %s from the levels you win. Finish it to dig deeper. You have %d %s." % [on, int(Save.d.ore), on], 14))
	var all_done := true
	for i in A.tasks.size():
		var t: Array = A.tasks[i]
		var done: bool = t[0] in built
		if not done: all_done = false
		var row := PanelContainer.new()
		var st := UI.glass(14, 0.5)
		if done: st.bg_color = Color(0.1, 0.25, 0.14, 0.6)
		row.add_theme_stylebox_override("panel", st)
		var h := HBoxContainer.new()
		var tv := VBoxContainer.new()
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.add_theme_constant_override("separation", 0)
		var nl := UI.label(t[1], 14, UI.body_bold)
		nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tv.add_child(nl)
		var ch: Dictionary = Data.CHEST[i] if i < Data.CHEST.size() else {coins = 100}
		var cost: int = t[2]
		var here := "%d m" % Data.depth_m(a, i)
		tv.add_child(UI.label("Done" if done else "%s · %d %s · in the chest: %s" % [here, cost, on, chest_text(ch)], 12, UI.body, UI.MUTED))
		h.add_child(tv)
		var reach: bool = i <= open
		var can: bool = not done and reach and Save.d.ore >= cost
		var b := UI.button("✓" if done else str(cost) if reach else here, "gold" if can else "glass", 14)
		b.custom_minimum_size = Vector2(70, 40)
		b.disabled = not can
		var tid: String = t[0]
		b.pressed.connect(func(): _build(tid, i))
		h.add_child(b)
		row.add_child(h)
		v.add_child(row)
	if all_done and a < Data.AREAS.size() - 1:
		v.add_child(_next_mine_btn(a))
	v.add_child(Ov.btn("Close", "glass", func(): Ov.close()))

## the way on to the next mine: iron and coins; the ore of this one left over is sold
func _next_mine_btn(a: int) -> Button:
	var cost: Array = Data.AREAS[a].next
	var fe: int = cost[0]
	var cn: int = cost[1]
	var ok: bool = Save.d.fe >= fe and Save.d.coins >= cn
	var nm := String(Data.AREAS[a + 1].n)
	var b := Ov.btn("%s · %d iron + %s" % [nm, fe, UI.coins(cn)] if ok else "%s: need %d iron, %s" % [nm, fe, UI.coins(cn)], "green" if ok else "glass", func():
		if Save.d.fe < fe or Save.d.coins < cn: return
		Save.d.fe -= fe
		Save.d.coins -= cn
		var sold := Save.open_mine(a + 1)
		Save.persist()
		Ov.close()
		render()
		Ov.toast("Welcome to %s" % nm + (" · leftover ore sold for %s" % UI.coins(sold) if sold else "")))
	b.disabled = not ok
	return b

func _build(tid: String, i: int) -> void:
	var a := ai()
	var A: Dictionary = Data.AREAS[a]
	var t: Array = A.tasks[i]
	if Save.d.ore < int(t[2]) or i > int(Save.d.depth[a]): return
	Save.d.ore -= int(t[2])
	Save.d.built[a].append(tid)
	var ch: Dictionary = Data.CHEST[i] if i < Data.CHEST.size() else {coins = 100}
	if ch.get("coins", 0): Save.d.coins += int(ch.coins)
	if ch.get("pick", 0): Save.d.boost.pick += int(ch.pick)
	if ch.get("dyn", 0): Save.d.boost.dyn += int(ch.dyn)
	if ch.has("pre"): Save.d.pre[ch.pre] += 1
	Save.persist()
	Sfx.play("build")
	Sfx.buzz(40)
	Ov.close()
	render()
	_build_pop()
	get_tree().create_timer(0.5).timeout.connect(func(): Ov.toast("Mine chest: " + chest_text(ch)))
	var all := true
	for x in A.tasks:
		if not x[0] in Save.d.built[a]: all = false
	if all:
		await get_tree().create_timer(0.9).timeout
		Save.d.coins += 500
		Save.d.boost.pick += 1
		Save.d.boost.dyn += 1
		Save.persist()
		render()
		var btns := []
		if a < Data.AREAS.size() - 1:
			var cost: Array = A.next
			btns.append(["Open: %s · %d iron + %s" % [Data.AREAS[a + 1].n, int(cost[0]), UI.coins(int(cost[1]))], "green", func():
				if Save.d.fe < int(cost[0]) or Save.d.coins < int(cost[1]): return
				Save.d.fe -= int(cost[0])
				Save.d.coins -= int(cost[1])
				Save.open_mine(a + 1)
				Save.persist()
				Ov.close()
				render(), Save.d.fe >= int(cost[0]) and Save.d.coins >= int(cost[1])])
		btns.append(["Later", "glass", func(): Ov.close()])
		Ov.panel(A.n + " is fitted out!", "Reward: 500 coins, a pickaxe and dynamite." + ("" if a < Data.AREAS.size() - 1 else " New mines are coming in the next version."), btns)

## a price in ore: the round badge and the number
static func ore_tag(kind: String, n: int, fs: int) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 3)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var r := fs * 0.62
	var ic := UI.icon(int(r * 2 + 2), func(ci: Control): Chrome.coin_icon(ci, kind, Vector2(r + 1, r + 1), r))
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	h.add_child(UI.label(str(n), fs, UI.display, UI.GOLD))
	return h

## a little thump of the picture and a burst of sparks when something gets built
func _build_pop() -> void:
	var tw := create_tween()
	var base := scene_holder.scale
	tw.tween_property(scene_holder, "scale", base * 0.985, 0.08)
	tw.tween_property(scene_holder, "scale", base, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var p := CPUParticles2D.new()
	p.position = scene_holder.position + Vector2(160, 170 + scene.OFF) * scene_holder.scale.x
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = 60
	p.lifetime = 1.2
	p.spread = 180
	p.initial_velocity_min = 80
	p.initial_velocity_max = 260
	p.gravity = Vector2(0, 300)
	p.scale_amount_min = 2
	p.scale_amount_max = 5
	var g := Gradient.new()
	g.set_color(0, Color(2.0, 1.6, 0.7))
	g.set_color(1, Color(1, 0.7, 0.3, 0))
	p.color_ramp = g
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.6).timeout.connect(p.queue_free)
