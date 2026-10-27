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
var view: MineView          # the drawn mine (Old Adit), scrolled with a finger; null where the old scene is used
var scroll := -1.0          # how far the drawn mine is scrolled down, screen units (-1: not placed yet)
static var start_scroll := -1.0   # a test key puts the first view here (-- scroll=N)
var _vel := 0.0             # the drawn mine's fling after the finger lets go, screen units a second
var _track: Array = []      # the last few [time, y] of the finger, for the fling speed
var _glide: Tween
var _press := Vector2.ZERO
var _press_scroll := 0.0
var _dragging := false
var _down := false
var _top_shade: TextureRect

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
	if MineView.available():
		view = MineView.new()
		add_child(view)
		# the name and the plaques stay readable over the mine as it scrolls under them
		_top_shade = TextureRect.new()
		var gt := GradientTexture2D.new()
		var gr := Gradient.new()
		gr.set_color(0, Color(0.03, 0.04, 0.07, 0.92))
		gr.set_color(1, Color(0.03, 0.04, 0.07, 0.0))
		gr.add_point(0.55, Color(0.03, 0.04, 0.07, 0.7))
		gt.gradient = gr
		gt.fill_from = Vector2(0, 0)
		gt.fill_to = Vector2(0, 1)
		_top_shade.texture = gt
		_top_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_top_shade.size = Vector2(get_viewport_rect().size.x, 190 + UI.safe_top())
		_top_shade.stretch_mode = TextureRect.STRETCH_SCALE
		add_child(_top_shade)
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
	var drawn := uses_view()
	scene_holder.visible = not drawn
	if view:
		view.visible = drawn
		_top_shade.visible = drawn
		if _dust_p: _dust_p.visible = not drawn
	if drawn:
		view.scale = Vector2.ONE * (vp.x / 1536.0)
		view.setup(ai())
		if scroll < 0:
			# the depth being dug a little below the middle of the screen
			scroll = view.band_y(dl_sel()) * view.scale.y - vp.y * 0.45
			if start_scroll >= 0: scroll = start_scroll
		_scroll_to(scroll)
		if view.focus_y >= 0.0:
			_glide_to(view.focus_y * view.scale.y - vp.y * 0.45)
	else:
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
	if not uses_view():   # the drawn mine marks the depth being dug on itself (⛏ on its plaque)
		col.add_child(chip)
	var vl := UI.label(Level.vein_text_for(ai(), dl_sel()), 12, UI.body_bold, Color("#d8e0ee"))
	vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	vl.add_theme_constant_override("shadow_outline_size", 6)
	col.add_child(vl)
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

## what stands between the shaft and its next depth: the job of the deepest open depth (paid in the mine's own ore),
## then the drill (iron + coins). At the last depth only its job is left, then the next mine.
## Returns {k (deepest open), job [id, text, cost] or [], job_done, last, tool, fe, coins}
func next_step() -> Dictionary:
	var a := ai()
	var A: Dictionary = Data.AREAS[a]
	var k: int = Save.d.depth[a]
	var last: bool = k >= Data.depths(a).size() - 1
	var job: Array = A.tasks[k] if k < A.tasks.size() else []
	var out := {k = k, job = job, job_done = job.is_empty() or job[0] in Save.d.built[a], last = last, tool = "", fe = 0, coins = 0}
	if not last:
		var D: Dictionary = Data.depth(a, k + 1)
		out.tool = String(D.tool)
		out.fe = int(D.drill[0])
		out.coins = int(D.drill[1])
	return out

func _tasks_button() -> Button:
	var a := ai()
	var st := next_step()
	var all_done: bool = st.last and st.job_done
	var boss := _boss_waits()
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 64)
	for s in ["normal", "hover", "pressed", "focus"]:
		var sb := UI.glass(18, 0.82)
		sb.border_color = Color("#e3a51e", 0.45)
		b.add_theme_stylebox_override(s, sb)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 12
	v.offset_right = -10
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 3)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var head := ("Below %d m" % Data.depth_m(a, int(st.k)) if boss else "Mine fitted out") if all_done else "Last depth" if st.last else "Next: %d m" % Data.depth_m(a, int(st.k) + 1)
	v.add_child(UI.label(head, 11, UI.body_bold, UI.MUTED))
	# the ticks in one line: job · iron · coins
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if all_done:
		h.add_child(UI.label(("%s ›" % Data.AREAS[a].boss.n) if boss else "Next mine ›" if a < Data.AREAS.size() - 1 else "✓", 14, UI.body_bold, Color("#ff8a70") if boss else UI.GOLD))
	else:
		h.add_child(_tick("ore", "✓" if st.job_done else "%d/%d" % [mini(Save.d.ore, int(st.job[2])), int(st.job[2])], st.job_done))
		if not st.last:
			h.add_child(_tick("iron", "%d/%d" % [mini(Save.d.fe, int(st.fe)), int(st.fe)], Save.d.fe >= int(st.fe)))
			h.add_child(_tick("coin", "✓" if Save.d.coins >= int(st.coins) else UI.fmt(int(st.coins)), Save.d.coins >= int(st.coins)))
	v.add_child(h)
	b.add_child(v)
	b.pressed.connect(_open_next)
	return b

## one requirement: its badge and how far along it is, green once met
func _tick(kind: String, text: String, ok: bool) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 3)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := UI.icon(20, func(ci: Control): Chrome.coin_icon(ci, kind, Vector2(10, 10), 9))
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	h.add_child(UI.label(text, 13, UI.body_bold, UI.GOOD if ok else UI.INK))
	return h

func _play_button() -> Button:
	var n: int = Save.d.level
	var def := LevelGen.current(dl_sel())
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
	var sub := UI.moves_text(BoardModel.start_moves(def, dl_sel(), Save.d.eq)) + (" · rich vein!" if def.get("rich", false) else "") + (" · streak %d" % Save.d.streak if Save.d.streak >= 2 else "")
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

## the drawn mine is used where its pictures exist (Old Adit, for now)
func uses_view() -> bool:
	return view != null and ai() == 0

## a smooth ride of the drawn mine to a scroll position (the finger stops it)
func _glide_to(v: float) -> void:
	if _glide: _glide.kill()
	_vel = 0.0
	_glide = create_tween()
	_glide.tween_method(_scroll_to, scroll, v, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _process(dt: float) -> void:
	if view == null or not uses_view() or _down or absf(_vel) < 1.0:
		return
	var was := scroll
	_scroll_to(scroll - _vel * dt)
	_vel *= exp(-3.2 * dt)
	if absf(_vel) < 25.0 or scroll == was:
		_vel = 0.0

func _scroll_to(v: float) -> void:
	var vp := get_viewport_rect().size
	# the last depth can come up above the Play row and the tab bar
	scroll = clampf(v, 0.0, maxf(0.0, view.content_height() + 150.0 - vp.y))
	view.position = Vector2(0, -scroll)

func _gui_input(e: InputEvent) -> void:
	if uses_view():
		_view_input(e)
		return
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
		_open_next()

## test key (-- ui=demo_build): the next step of the mine, paid for - a job's step, or the drill down
func _demo_build() -> void:
	Save.d.ore += 100
	Save.d.fe += 100
	Save.d.coins += 5000
	var st := next_step()
	if not st.job_done:
		_build(String(st.job[0]), int(st.k))
	else:
		_dig()

## test key (-- ui=demo_niche): a tap on the first stone standing in a niche
func _demo_niche() -> void:
	for k in 6:
		var p := Vector2(float(MineView.NICHES.get(k + 1, [0, 0])[0]), view.band_y(k) + float(MineView.NICHES.get(k + 1, [0, 0])[1]) - 40)
		if not view.niche_at(p).is_empty():
			var e := InputEventMouseButton.new()
			e.button_index = MOUSE_BUTTON_LEFT
			e.position = view.get_global_transform() * p
			e.pressed = true
			_view_input(e)
			e = e.duplicate()
			e.pressed = false
			_view_input(e)
			return

## after a build: the drawn mine glides to the place that changed, dust bursts over it
func _show_job(tid: String) -> void:
	if not uses_view(): return
	var at := view.job_pos(tid)
	var vp := get_viewport_rect().size
	view.burst(at)          # the screen itself glides there from render() (MineView.focus_y)

## the drawn mine: a finger drags it up and down; a short touch picks a depth
func _view_input(e: InputEvent) -> void:
	var pressed := false
	var released := false
	var moved := false
	var pos := Vector2.ZERO
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		pressed = e.pressed
		released = not e.pressed
		pos = e.position
	elif e is InputEventScreenTouch:
		pressed = e.pressed
		released = not e.pressed
		pos = e.position
	elif (e is InputEventMouseMotion and _down) or e is InputEventScreenDrag:
		moved = true
		pos = e.position
	elif e is InputEventMouseButton and e.pressed and e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_scroll_to(scroll + (-60.0 if e.button_index == MOUSE_BUTTON_WHEEL_UP else 60.0))
		accept_event()
		return
	var now := Time.get_ticks_msec() / 1000.0
	if pressed:
		_down = true
		_dragging = false
		_press = pos
		_press_scroll = scroll
		_vel = 0.0
		if _glide: _glide.kill()
		_track = [[now, pos.y]]
	elif moved and _down:
		_track.append([now, pos.y])
		while _track.size() > 2 and now - float(_track[0][0]) > 0.12: _track.pop_front()
		if _dragging or absf(pos.y - _press.y) > 10:
			_dragging = true
			_scroll_to(_press_scroll - (pos.y - _press.y))
	elif released and _down:
		_down = false
		# the fling: the finger's speed over its last ~0.1 s carries on and slows down
		if _dragging and _track.size() >= 2:
			var a: Array = _track[0]
			var dtt := now - float(a[0])
			if dtt > 0.01 and now - float(_track[-1][0]) < 0.08:
				_vel = clampf((pos.y - float(a[1])) / dtt, -4000.0, 4000.0)
		if not _dragging:
			var lp := view.get_global_transform().affine_inverse() * pos
			var stone := view.niche_at(lp)
			if not stone.is_empty():
				# the find on its pedestal: its card, as in the museum
				Sfx.play("open")
				var v := Ov.card(350, Data.rarity_color(int(stone.tier)))
				Reveal.stone_card(v, stone, 400, func(): Ov.close())
				v.add_child(Ov.text("Found at %d m" % Data.depth_m(ai(), int(stone.get("dl", 0))), 13))
				accept_event()
				return
			var k := view.band_at(lp)
			if k >= 0:
				_pick_depth(k)
	accept_event()

func _pick_depth(k: int) -> void:
	if k <= int(Save.d.depth[ai()]):
		if int(Save.d.depth_sel[ai()]) != k:
			Save.d.depth_sel[ai()] = k
			Save.persist()
			Sfx.play("swap")
			render()
			Ov.toast("Digging at %d m" % Data.depth_m(ai(), k))
	else:
		_open_next()

var _dust_p: CPUParticles2D

func _dust() -> void:
	# motes drifting in the lamplight over the galleries (the drawn mine has its own, in its galleries)
	var p := CPUParticles2D.new()
	_dust_p = p
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
	var def := LevelGen.current(dl)
	var free := Data.streak_free(Save.d.streak)
	for f in free:
		if not f in sel: sel.append(f)
	var v := Ov.card(350)
	v.add_child(UI.title("Level %d" % n, 24))
	if def.get("rich", false):
		# the rich vein: said before the start, and plain to see on the board
		var rc := UI.label("Rich vein! Twice the ore stones this time", 14, UI.body_bold, Color("#ffd27a"))
		rc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var rs := StyleBoxFlat.new()
		rs.bg_color = Color(0.25, 0.16, 0.02, 0.85)
		rs.border_color = Color("#e3a51e")
		rs.set_border_width_all(1)
		rs.set_corner_radius_all(12)
		rs.content_margin_top = 6
		rs.content_margin_bottom = 6
		rc.add_theme_stylebox_override("normal", rs)
		v.add_child(rc)
	if def.get("intro", false):
		v.add_child(Ov.text("New at this depth: %s" % Data.DMODS[mini(dl, Data.DMODS.size() - 1)], 13, UI.GOLD))
	v.add_child(Ov.text("%s · a specimen waits in the rock" % UI.moves_text(BoardModel.start_moves(def, dl, Save.d.eq)), 14))
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
			# the specials as the board draws them (special_kit.py: dynamite stick, the charge, the resonator)
			if BoardSprites.gem_style != "":
				BoardSprites.draw(ci, BoardSprites.tex(sp0), Vector2(19, 19), 38)
				return
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
	ic.material = BoardSprites.plain_material()   # the stock shader draws no textures on iPhone (see Level)
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
	if c.get("bore_h", 0): return "rock drill"
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
		var cost: int = MineView.step_cost(a, String(t[0]), int(t[2]))
		var here := "%d m" % Data.depth_m(a, i)
		var stp := _step_label(a, String(t[0]))
		var sub := UI.label("Done" if done else "%s%s · %d %s · in the chest: %s" % [here, stp, cost, on, chest_text(ch)], 12, UI.body, UI.MUTED)
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # unwrapped, the longest line widened the card past the screen
		tv.add_child(sub)
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

## the checklist for the next depth: this depth's job, the drill's iron and coins, each ticked off; Dig down
## once all three are met. At the last depth: its job, then the next mine.
func _open_next() -> void:
	var a := ai()
	var st := next_step()
	var on := String(Data.ore(a).n).to_lower()
	var v := Ov.card(350)
	var here := Data.depth_m(a, int(st.k))
	v.add_child(UI.title("Last depth · %d m" % here if st.last else "Down to %d m" % Data.depth_m(a, int(st.k) + 1), 22))
	v.add_child(Ov.text(Level.vein_text_for(a, int(st.k)), 13))
	# 1: the job of this depth
	if not st.job.is_empty():
		var cost: int = MineView.step_cost(a, String(st.job[0]), int(st.job[2]))
		var can: bool = not st.job_done and Save.d.ore >= cost
		var bt := UI.button("✓" if st.job_done else "Build", "gold" if can else "glass", 14)
		var stp := _step_label(a, String(st.job[0]))
		bt.disabled = not can
		var i: int = st.k
		var tid: String = st.job[0]
		bt.pressed.connect(func(): _build(tid, i))
		v.add_child(_need_row("ore", String(st.job[1]) + stp, "Done" if st.job_done else "%d %s · you have %d" % [cost, on, Save.d.ore], st.job_done, bt))
	if not st.last:
		var fe: int = st.fe
		var cn: int = st.coins
		v.add_child(_need_row("iron", "%s: iron" % st.tool, "%d iron · you have %d" % [fe, Save.d.fe], Save.d.fe >= fe, null))
		v.add_child(_need_row("coin", "%s: coins" % st.tool, "%s · you have %s" % [UI.coins(cn), UI.fmt(Save.d.coins)], Save.d.coins >= cn, null))
		var ok: bool = st.job_done and Save.d.fe >= fe and Save.d.coins >= cn
		var dig := Ov.btn("Dig down · %s" % st.tool, "green" if ok else "glass", func(): _dig(), ok)
		v.add_child(dig)
		if not ok:
			v.add_child(Ov.text("Iron and %s come from the levels you win: every ore stone you break." % on, 12))
	elif st.job_done and _boss_waits():
		var B: Dictionary = Data.AREAS[a].boss
		v.add_child(Ov.text("Below, at %d m, %s guards the mine. Beat it to go on to the next one." % [int(B.m), B.n], 13, Color("#ffb0a0")))
		v.add_child(Ov.btn("Fight · %s" % B.n, "red", func(): _fight_boss()))
	elif st.job_done and a < Data.AREAS.size() - 1:
		v.add_child(_next_mine_btn(a))
	v.add_child(Ov.btn("All jobs", "glass", func():
		Ov.close()
		_open_tasks()))
	v.add_child(Ov.btn("Close", "glass", func(): Ov.close()))

## the mine has a boss and it is not beaten yet
func _boss_waits() -> bool:
	var a := ai()
	return Data.AREAS[a].has("boss") and not bool(Save.d.boss_won[a])

## into the fight: a life like any level; the fight sits one below the mine's last depth
func _fight_boss() -> void:
	Save.tick_lives()
	if Save.d.lives <= 0:
		Ov.close()
		_on_play()
		return
	Ov.close()
	play.emit(Save.d.level, [], Data.depths(ai()).size())

## one line of the checklist: badge, what, how far along, a tick (or a button doing it)
func _need_row(kind: String, what: String, sub: String, ok: bool, action: Button) -> PanelContainer:
	var row := PanelContainer.new()
	var st := UI.glass(14, 0.5)
	if ok: st.bg_color = Color(0.1, 0.25, 0.14, 0.6)
	row.add_theme_stylebox_override("panel", st)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var ic := UI.icon(30, func(ci: Control): Chrome.coin_icon(ci, kind, Vector2(15, 15), 14))
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_theme_constant_override("separation", 0)
	var nl := UI.label(what, 14, UI.body_bold)
	nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tv.add_child(nl)
	var sl := UI.label(sub, 12, UI.body, UI.MUTED)
	sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tv.add_child(sl)
	h.add_child(tv)
	if action:
		action.custom_minimum_size = Vector2(70, 40)
		h.add_child(action)
	else:
		var tick := UI.label("✓" if ok else "✗", 18, UI.display, UI.GOOD if ok else Color("#e0904a"))
		tick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(tick)
	row.add_child(h)
	return row

## through to the next depth: the drill takes its iron and coins, the new depth is where the next levels are dug
func _dig() -> void:
	var a := ai()
	var st := next_step()
	if st.last or not st.job_done or Save.d.fe < int(st.fe) or Save.d.coins < int(st.coins): return
	Save.d.fe -= int(st.fe)
	Save.d.coins -= int(st.coins)
	var k: int = int(st.k) + 1
	Save.d.depth[a] = k
	Save.d.depth_sel[a] = k
	Save.persist()
	Sfx.play("build")
	Sfx.buzz(50)
	Ov.close()
	render()
	if uses_view():
		var vp := get_viewport_rect().size
		pass   # render() glides to the new depth (MineView.focus_y)
	_build_pop()
	Ov.toast("%s broke through: %d m" % [st.tool, Data.depth_m(a, k)])

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

## " · step 2/3" for a job paid in steps, "" otherwise
func _step_label(a: int, tid: String) -> String:
	var n := MineView.job_steps(a)
	if n <= 1 or tid in Save.d.built[a]: return ""
	return " · step %d/%d" % [MineView.job_step(a, tid) + 1, n]

## one step of a job (all of it where jobs are not split): the ore is paid, the picture moves on a step; the last step
## finishes the job (the mine's chest, the way down)
func _build(tid: String, i: int) -> void:
	var a := ai()
	var A: Dictionary = Data.AREAS[a]
	var t: Array = A.tasks[i]
	var price := MineView.step_cost(a, tid, int(t[2]))
	if tid in Save.d.built[a] or Save.d.ore < price or i > int(Save.d.depth[a]): return
	Save.d.ore -= price
	var done := MineView.job_step(a, tid) + 1
	if not Save.d.has("jstep"): Save.d.jstep = {}
	if done < MineView.job_steps(a):
		Save.d.jstep["%d:%s" % [a, tid]] = done
		Save.persist()
		Sfx.play("build")
		Sfx.buzz(30)
		Ov.close()
		render()
		_show_job(tid)
		_build_pop()
		Ov.toast("%s · step %d of %d" % [String(t[1]), done, MineView.job_steps(a)])
		return
	Save.d.jstep.erase("%d:%s" % [a, tid])
	Save.d.built[a].append(tid)
	var ch: Dictionary = Data.CHEST[i] if i < Data.CHEST.size() else {coins = 100}
	if ch.get("coins", 0): Save.d.coins += int(ch.coins)
	if ch.get("pick", 0): Save.d.boost.pick += int(ch.pick)
	if ch.get("bore_h", 0): Save.d.boost.bore_h += int(ch.bore_h)
	if ch.has("pre"): Save.d.pre[ch.pre] += 1
	Save.persist()
	Sfx.play("build")
	Sfx.buzz(40)
	Ov.close()
	render()
	_show_job(tid)
	_build_pop()
	get_tree().create_timer(0.5).timeout.connect(func(): Ov.toast("Mine chest: " + chest_text(ch)))
	if i < Data.depths(a).size() - 1:
		get_tree().create_timer(3.2 if uses_view() else 0.9).timeout.connect(_open_next)   # the drawn mine plays the change first
	var all := true
	for x in A.tasks:
		if not x[0] in Save.d.built[a]: all = false
	if all:
		await get_tree().create_timer(6.0 if uses_view() else 0.9).timeout   # the drawn mine plays the change (and the chamber its tremor) first
		Save.d.coins += 500
		Save.d.boost.pick += 1
		Save.d.boost.bore_h += 1
		Save.persist()
		render()
		var btns := []
		if _boss_waits():
			btns.append(["Fight · %s" % A.boss.n, "red", func(): _fight_boss()])
		elif a < Data.AREAS.size() - 1:
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
		Ov.panel(A.n + " is fitted out!", "Reward: 500 coins, a pickaxe and a rock drill." + ("" if a < Data.AREAS.size() - 1 else " New mines are coming in the next version."), btns)

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
	if uses_view():
		p.position = get_viewport_rect().size * Vector2(0.5, 0.45)
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
