class_name Level
extends Control
## One level: the gallery backdrop, the board, its effects and the HUD.
## Runs the turn loop (blast → pops → gravity → cascades) by asking BoardModel for the rules
## and BoardView / FxLayer for the show.

signal finished(result: Dictionary)   # {won, n, stone, bonus, coins}

var model := BoardModel.new()
var bg: GalleryBg
var bg_layer: CanvasLayer
var holder: Control
var shaker: Node2D
var board: BoardView
var fx: FxLayer
var hud: CanvasLayer
var goal_boxes := []      # {root, label, shown}
var moves_label: Label
var moves_token: PanelContainer
var title_label: Label
var hint_label: Label
var booster_bar: HBoxContainer
var overlay: Control
var busy := true
var booster := ""
var idle := 0.0
var _hinted := false
var _flights := 0
var find_studio: SpecStudio     # the sealed specimen, turning slowly inside its block
var find_spec: Node3D

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_layer = CanvasLayer.new()
	bg_layer.layer = -1
	add_child(bg_layer)
	var mod := CanvasModulate.new()
	mod.color = Color(0.78, 0.74, 0.72)
	bg_layer.add_child(mod)
	bg = GalleryBg.new()
	bg_layer.add_child(bg)
	holder = Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(holder)
	shaker = Node2D.new()
	holder.add_child(shaker)
	board = BoardView.new()
	shaker.add_child(board)
	fx = FxLayer.new()
	fx.board = board
	shaker.add_child(fx)
	board.swiped.connect(_on_swipe)
	board.tapped.connect(_on_tap)
	hud = CanvasLayer.new()
	hud.layer = 2
	add_child(hud)
	_build_hud()

# ---------------------------------------------------------------- start

func start(n: int, pre: Array = [], dl: int = 0) -> void:
	var eq: Dictionary = Save.d.eq
	model = BoardModel.new()
	model.rng.randomize()
	model.setup(n, pre, dl, eq, Save.area())
	Save.persist()
	var vp := get_viewport_rect().size
	bg.setup(Save.area(), dl, vp)
	_layout()
	board.rebuild(model)
	_mount_find()
	_render_hud()
	busy = true
	booster = ""
	hint_label.text = ""
	await board.drop_in()
	busy = false
	idle = 0.0

func _mount_find() -> void:
	if find_studio:
		find_studio.vp.queue_free()
		find_studio = null
	board.find_tex = null
	if model.find.is_empty():
		return
	find_studio = SpecStudio.make(200, Viewport.MSAA_2X)
	add_child(find_studio.vp)
	find_spec = find_studio.show(Spec.of_stone(model.find.stone))
	find_spec.rotation = Vector3(0.12, 0.6, 0)
	board.find_tex = find_studio.vp.get_texture()

func _layout() -> void:
	var vp := get_viewport_rect().size
	var top := 150.0
	var bottom := 118.0
	board.layout(Vector2(vp.x - 12, vp.y - top - bottom))
	holder.position = Vector2((vp.x - board.size.x) / 2, top + (vp.y - top - bottom - board.size.y) / 2)
	holder.size = board.size

# ---------------------------------------------------------------- HUD

func _build_hud() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]: margin.add_theme_constant_override("margin_" + side, 12)
	margin.add_theme_constant_override("margin_top", 8)
	hud.add_child(margin)
	margin.add_child(root)
	# top line: close and the level title
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var close := UI.button("✕", "glass", 16)
	close.custom_minimum_size = Vector2(38, 38)
	close.pressed.connect(_on_quit)
	top.add_child(close)
	title_label = UI.title("Уровень", 15)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title_label)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(38, 38)
	top.add_child(spacer)
	root.add_child(top)
	# goals and the moves token
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var goals_panel := PanelContainer.new()
	goals_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	goals_panel.add_theme_stylebox_override("panel", UI.glass(18))
	var goals_row := HBoxContainer.new()
	goals_row.name = "Goals"
	goals_row.add_theme_constant_override("separation", 10)
	goals_row.alignment = BoxContainer.ALIGNMENT_CENTER
	goals_panel.add_child(goals_row)
	line.add_child(goals_panel)
	moves_token = PanelContainer.new()
	moves_token.custom_minimum_size = Vector2(74, 74)
	var token := StyleBoxFlat.new()
	token.bg_color = Color("#e0aa30")
	token.set_corner_radius_all(37)
	token.border_color = Color("#4a3006")
	token.set_border_width_all(3)
	token.shadow_color = Color(1, 0.8, 0.35, 0.35)
	token.shadow_size = 12
	moves_token.add_theme_stylebox_override("panel", token)
	var mv := VBoxContainer.new()
	mv.alignment = BoxContainer.ALIGNMENT_CENTER
	mv.add_theme_constant_override("separation", -4)
	var small := UI.label("ХОДЫ", 9, UI.body_bold, Color("#5a3604"))
	small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mv.add_child(small)
	moves_label = UI.label("0", 28, UI.display, Color("#3a2200"))
	moves_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mv.add_child(moves_label)
	moves_token.add_child(mv)
	line.add_child(moves_token)
	root.add_child(line)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fill)
	hint_label = UI.label("", 13, UI.body, UI.MUTED)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(hint_label)
	# booster bar at the bottom, like the game's tab bar
	var bar := PanelContainer.new()
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color("#151d2c")
	bs.border_color = Color(1, 1, 1, 0.1)
	bs.border_width_top = 1
	bs.content_margin_top = 10
	bs.content_margin_bottom = 14
	bar.add_theme_stylebox_override("panel", bs)
	booster_bar = HBoxContainer.new()
	booster_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	booster_bar.add_theme_constant_override("separation", 18)
	bar.add_child(booster_bar)
	var bar_wrap := MarginContainer.new()
	bar_wrap.add_theme_constant_override("margin_left", -12)
	bar_wrap.add_theme_constant_override("margin_right", -12)
	bar_wrap.add_child(bar)
	root.add_child(bar_wrap)
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	hud.add_child(overlay)

func _render_hud() -> void:
	title_label.text = "Уровень %d · %d м%s" % [model.n, int(Data.DEPTHS[model.depth].m), " · сложный" if model.hard else ""]
	var row: HBoxContainer = hud.find_child("Goals", true, false)
	for ch in row.get_children(): ch.queue_free()
	goal_boxes.clear()
	for i in model.goals.size():
		var g: Dictionary = model.goals[i]
		var box := HBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		var glow := Data.rarity_color(model.find.stone.tier) if g.k == "find" else Color("#c8b0ff")
		var k: String = g.k
		var colour: int = g.t
		box.add_child(UI.icon(34, func(ci):
			GemArt.begin(ci, Transform2D.IDENTITY)
			GemArt.goal_icon(ci, k, colour, 34, glow)))
		var l := UI.label("", 16, UI.display)
		box.add_child(l)
		row.add_child(box)
		goal_boxes.append({root = box, label = l, shown = g.left})
		_render_goal(i)
	_render_moves()
	_render_boosters()

func _render_goal(i: int) -> void:
	var gb: Dictionary = goal_boxes[i]
	var g: Dictionary = model.goals[i]
	if g.k == "find":
		gb.label.text = ("✓ %d%%" if model.find.done else "%d%%") % model.find.integ
		gb.label.add_theme_color_override("font_color", UI.GOOD if model.find.done else UI.INK)
	else:
		gb.label.text = str(gb.shown) if gb.shown > 0 else "✓"
		gb.label.add_theme_color_override("font_color", UI.GOOD if gb.shown <= 0 else UI.INK)

func _render_moves() -> void:
	moves_label.text = str(model.moves)
	var low := model.moves <= 5 and not model.over
	moves_label.add_theme_color_override("font_color", Color("#a80e1c") if low else Color("#3a2200"))

func _render_boosters() -> void:
	for ch in booster_bar.get_children(): ch.queue_free()
	for bo in Data.BOOSTS:
		var id: String = bo.id
		var b := Button.new()
		b.custom_minimum_size = Vector2(64, 64)
		var st := UI.button_style("glass")
		st.bg_color = Color("#2c3c5a") if booster != id else Color("#4a5a7a")
		st.border_color = UI.GOLD if booster == id else Color("#0a0f18")
		st.set_border_width_all(2 if booster == id else 0)
		st.border_width_bottom = 4
		for s in ["normal", "hover", "pressed"]: b.add_theme_stylebox_override(s, st)
		var ic := UI.icon(44, func(ci):
			if id == "dyn":
				GemArt.begin(ci, Transform2D(0.0, Vector2(22, 22)))
				GemArt.special(ci, "rh", 44)
			else:
				GemArt.begin(ci, Transform2D(-0.7, Vector2(22, 22)))
				ci.draw_rect(Rect2(-2, -2, 4, 21), Color("#8a5a2c"))
				ci.draw_polyline(PackedVector2Array([Vector2(-16, -1), Vector2(-8, -9), Vector2(0, -11), Vector2(8, -9), Vector2(16, -1)]), Color("#9aa6b4"), 5, true)
			GemArt.end(ci))
		ic.position = Vector2(10, 10)
		b.add_child(ic)
		var n: int = Save.d.boost[id]
		var badge := UI.label(str(n) if n else "+", 12, UI.body_bold)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var bstyle := StyleBoxFlat.new()
		bstyle.bg_color = Color("#e23a55") if n else Color("#e3a51e")
		bstyle.set_corner_radius_all(11)
		bstyle.border_color = Color("#151d2c")
		bstyle.set_border_width_all(2)
		badge.add_theme_stylebox_override("normal", bstyle)
		badge.custom_minimum_size = Vector2(24, 22)
		badge.position = Vector2(46, 46)
		b.add_child(badge)
		b.pressed.connect(func(): _on_booster(bo))
		booster_bar.add_child(b)

## where a goal's counter sits, in the effects layer's coordinates
func _goal_target(gi: int) -> Vector2:
	var box: Control = goal_boxes[gi].root
	var gpos := box.get_global_rect().position + Vector2(17, box.size.y / 2)
	return fx.get_global_transform().affine_inverse() * gpos

# ---------------------------------------------------------------- input

func _process(dt: float) -> void:
	if find_spec:
		find_spec.rotation.y += dt * 0.5
	if busy or model.over: return
	idle += dt
	if idle > 5.0 and not _hinted:
		_hinted = true
		var mv := model.find_move()
		if not mv.is_empty(): board.hint(mv)

func _on_swipe(r1: int, c1: int, r2: int, c2: int) -> void:
	if busy or model.over: return
	_touched()
	if booster != "":
		return
	var a: BoardModel.Gem = model.gem_at(r1, c1)
	var b: BoardModel.Gem = model.gem_at(r2, c2)
	if a == null or b == null: return
	var a_id := a.id
	var b_id := b.id
	var res = model.swap(r1, c1, r2, c2)
	if res == null:
		Sfx.play("bad")
		return
	busy = true
	Sfx.play("swap")
	if res.get("undone", false):
		await board.animate_swap(a_id, b_id, true)
		Sfx.play("bad")
		busy = false
		return
	await board.animate_swap(a_id, b_id)
	model.use_move()
	_render_moves()
	await _resolve(res.events, res.swap_cells)
	await _after_turn()

func _on_tap(r: int, c: int) -> void:
	if busy or model.over: return
	_touched()
	if booster != "":
		await _use_booster(r, c)
		return
	var g: BoardModel.Gem = model.gem_at(r, c)
	if g and g.sp != "" and not model.LOCK[r][c]:
		busy = true
		model.use_move()
		_render_moves()
		await _resolve([{t = 0.0, r = r, c = c, kind = "fx"}], [])
		await _after_turn()

func _touched() -> void:
	idle = 0.0
	_hinted = false

# ---------------------------------------------------------------- the turn

func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

func _resolve(first: Array, swap_cells: Array) -> void:
	var cascade := 0
	var sw := swap_cells
	while true:
		var groups := model.find_groups()
		var ev := first
		first = []
		if groups.is_empty() and ev.is_empty():
			break
		cascade += 1
		var created := model.groups_to_blast(groups, sw, ev)
		var merges := {}
		for r in model.R:
			for c in model.C:
				var g: BoardModel.Gem = model.G[r][c]
				if g and g.merge.x >= 0: merges[g.id] = g.merge
		model.fx = []
		var max_t := model.run_blast(ev)
		_play_fx(model.fx.duplicate(), merges)
		Sfx.play("pop", cascade)
		if not created.is_empty():
			get_tree().create_timer(0.12).timeout.connect(func(): Sfx.play("special"))
		await _wait(max_t / 1000.0 + 0.26)
		for id in model.remove_dead():
			if board.nodes.has(id): board.remove_node(id)
		for g in model.place_specials(created):
			for s in created:
				if model.G[s.r][s.c] == g:
					board.grow_special(g, s.r, s.c)
					fx.ring(s.r, s.c, 0.3, Color(1.6, 1.3, 2.0))
		if cascade == 3: _cheer("Отлично!")
		elif cascade == 5: _cheer("Блестяще!")
		elif cascade == 7: _cheer("Самородок!")
		board.refresh()
		await board.animate_collapse(model.collapse())
		while true:
			var got := model.collect_nuggets()
			if got.is_empty(): break
			for n in got:
				board.remove_node(n.id)
				fx.sparkle(n.r, n.c, Color("#ffd24a"), 18)
				Sfx.play("coin")
				_play_fx(n.goal_fx, {})
			await _wait(0.12)
			await board.animate_collapse(model.collapse())
		sw = []
	if not model.over and not model.has_moves():
		_cheer("Перемешиваю")
		model.shuffle()
		await board.animate_shuffle()

## turn the model's effect list into the show, each at its moment
func _play_fx(list: Array, merges: Dictionary) -> void:
	for e in list:
		var cb := _fx_one.bind(e, merges)
		if e.t <= 0.0: cb.call()
		else: get_tree().create_timer(e.t / 1000.0).timeout.connect(cb)

func _fx_one(e: Dictionary, merges: Dictionary) -> void:
	match String(e.type):
		"clear":
			board.pop_gem(e.id, merges.get(e.id, Vector2i(-1, -1)))
			if e.color >= 0 and not merges.has(e.id):
				fx.debris(e.r, e.c, Color.html(Data.GEMS[e.color].c), 6)
		"rock":
			board.under.queue_redraw()
			fx.debris(e.r, e.c, Color("#c89a62") if e.left == 0 else Color("#8a919c"), 10)
			Sfx.play("rock")
			Sfx.buzz(10)
		"gas":
			board.under.queue_redraw()
			fx.debris(e.r, e.c, Color("#a2dc3c"), 12)
			Sfx.play("rock")
		"mud":
			board.under.queue_redraw()
			fx.debris(e.r, e.c, Color("#7a5a3a"), 8)
		"lock":
			board.over.queue_redraw()
			fx.debris(e.r, e.c, Color("#b07a3e"), 10)
			Sfx.play("rock")
		"geo_hit":
			board.geo_hit_at[e.gi] = Time.get_ticks_msec() / 1000.0
			Sfx.play("crack", 4 - e.hp)
			var geo: Dictionary = model.geos[e.gi]
			fx.debris(geo.r + 0.5, geo.c + 0.5, Color("#9a8a78"), 12)
		"geo_open":
			board.under.queue_redraw()
			fx.sparkle(e.r + 0.5, e.c + 0.5, Color("#d8b8ff"), 30)
			Sfx.play("reveal", 1)
			_toast("Жеода расколота: камень ждёт вас в конце уровня")
		"find_hit":
			board.find_hit_at = Time.get_ticks_msec() / 1000.0
			var F: Dictionary = model.find
			if e.rough:
				Sfx.play("crack", 3)
				Sfx.buzz(35)
				fx.debris(F.r + 0.5, F.c + 0.5, Color("#ffb090"), 16)
				fx.pop_text(F.r + 0.5, F.c + 0.5, "скол −%d%%" % e.chip)
			else:
				Sfx.play("rock")
				fx.debris(F.r + 0.5, F.c + 0.5, Color("#9a8a78"), 9)
			var gi := model.goal_index("find")
			if gi >= 0: _render_goal(gi)
		"find_done":
			board.under.queue_redraw()
			var col := Data.rarity_color(model.find.stone.tier)
			fx.sparkle(e.r + 0.5, e.c + 0.5, Color(col.r * 1.5, col.g * 1.5, col.b * 1.5), 44)
			fx.flash(e.r + 0.5, e.c + 0.5, Color(col.r * 2, col.g * 2, col.b * 2), 2.0)
			Sfx.play("reveal", model.find.stone.tier)
			Sfx.buzz(60)
			_toast("Образец извлечён · целостность %d%%" % model.find.integ)
		"goal":
			_flights += 1
			var gi: int = e.gi
			var glow := Data.rarity_color(model.find.stone.tier) if e.k == "find" else Color("#c8b0ff")
			fx.fly_icon(e.r, e.c, _goal_target(gi), e.k, e.color, glow, func():
				_flights -= 1
				var gb: Dictionary = goal_boxes[gi]
				gb.shown = maxi(model.goals[gi].left, gb.shown - 1)
				_render_goal(gi)
				var box: Control = gb.root
				box.pivot_offset = box.size / 2
				var tw := create_tween()
				tw.tween_property(box, "scale", Vector2(1.25, 1.25), 0.08)
				tw.tween_property(box, "scale", Vector2.ONE, 0.12)
				Sfx.play("pop", 2))
		"rocket":
			fx.rocket(e.sp, e.r, e.c)
			Sfx.play("rocket")
			Sfx.buzz(20)
		"boom":
			fx.boom(e.r, e.c, e.rad)
			Sfx.play("boom")
			Sfx.buzz(45)
		"drill":
			fx.drill(e.r, e.c, e.tr, e.tc)
		"zap":
			fx.zap(e.r, e.c, e.tr, e.tc)
		"orb":
			Sfx.play("zap")
			fx.flash(e.r, e.c, Color(1.8, 1.2, 2.6), 1.4)
		"convert":
			board.convert_gem(e.id, e.sp)
		"combo":
			fx.flash(e.r, e.c, Color(2.4, 2.0, 1.2), 2.0)
			fx.shake = maxf(fx.shake, 8.0)

func _flights_done() -> void:
	var guard := 0
	while _flights > 0 and guard < 60:
		guard += 1
		await _wait(0.06)

func _after_turn() -> void:
	await _flights_done()
	if model.goals_done():
		model.over = true
		await _finale()
		_win()
		return
	var p := model.gas_spread()
	if p.x >= 0:
		board.remove_node(_gem_id_at_removed(p))
		board.under.queue_redraw()
		fx.sparkle(p.x, p.y, Color("#c8f070"), 14)
		Sfx.play("gas")
		var gi := model.goal_index("gas")
		if gi >= 0:
			goal_boxes[gi].shown += 1
			_render_goal(gi)
		if not has_meta("gas_told"):
			set_meta("gas_told", true)
			_toast("Газ расползается — задевайте его каждый ход")
		await _wait(0.26)
	if model.moves <= 0:
		model.over = true
		await _wait(0.3)
		_out_of_moves()
		return
	busy = false
	idle = 0.0
	_hinted = false

## gas swallowed a stone: find which node no longer has a cell
func _gem_id_at_removed(_p: Vector2i) -> int:
	var alive := {}
	for r in model.R:
		for c in model.C:
			var g: BoardModel.Gem = model.G[r][c]
			if g: alive[g.id] = true
	for id in board.nodes:
		if not alive.has(id): return id
	return -1

func _on_booster(bo: Dictionary) -> void:
	if busy or model.over: return
	var id: String = bo.id
	if Save.d.boost[id] <= 0:
		_buy_booster(bo)
		return
	booster = "" if booster == id else id
	hint_label.text = ("%s: %s — нажмите на клетку" % [bo.n, String(bo.d).to_lower()]) if booster != "" else ""
	_render_boosters()

func _use_booster(r: int, c: int) -> void:
	if not model.playable(r, c): return
	var id := booster
	booster = ""
	hint_label.text = ""
	Save.d.boost[id] -= 1
	Save.persist()
	_render_boosters()
	busy = true
	await _resolve(model.booster_events(id, r, c), [])
	await _flights_done()
	if model.goals_done():
		model.over = true
		await _finale()
		_win()
		return
	busy = false

func _buy_booster(bo: Dictionary) -> void:
	var price: int = bo.price
	_panel("%s" % bo.n, "%s. Купить 3 штуки?" % bo.d, [
		["Купить · %s" % UI.coins(price), "gold", func():
			if Save.d.coins < price: return
			Save.d.coins -= price
			Save.d.boost[bo.id] += 3
			Save.persist()
			Sfx.play("coin")
			_close_panel()
			_render_boosters(), Save.d.coins >= price],
		["Не сейчас", "glass", _close_panel, true]])

# ---------------------------------------------------------------- level end

func _finale() -> void:
	if model.moves <= 0: return
	_cheer("Взрывная смена!")
	await _wait(0.5)
	var picks := model.finale_picks()
	for p in picks:
		var g: BoardModel.Gem = model.G[p.x][p.y]
		board.convert_gem(g.id, g.sp)
		_render_moves()
		Sfx.play("coin")
		await _wait(0.09)
	var ev := []
	for i in picks.size():
		ev.append({t = i * 120.0, r = picks[i].x, c = picks[i].y, kind = "fx"})
	await _resolve(ev, [])
	await _flights_done()

func _win() -> void:
	Sfx.play("win")
	Sfx.buzz(80)
	var coins := roundi((20 + model.coins_won) * Data.depth_pay(model.depth) * (1.0 + Save.d.eq.crush * 0.25) * Save.coin_mul())
	Save.d.coins += coins
	Save.d.stars += 1
	Save.d.level = maxi(Save.d.level, model.n + 1)
	Save.d.streak += 1
	Save.persist()
	var stone := {}
	if not model.find.is_empty() and model.find.done:
		stone = model.extracted_stone(Save.has_jewel("diadem"))
	_confetti()
	await _wait(0.6)
	finished.emit({won = true, n = model.n, depth = model.depth, coins = coins, stone = stone, bonus = model.bonus})

func _out_of_moves() -> void:
	Sfx.play("lose")
	var left := 0
	for g in model.goals:
		if g.left > 0: left += 1
	var msg := "Осталось целей: %d.%s Ещё пять ходов?" % [left, " Образец так и останется в породе." if not model.find.is_empty() and not model.find.done else ""]
	_panel("Ходы закончились", msg, [
		["+5 ходов · 300 монет", "gold", func():
			if Save.d.coins < 300: return
			Save.d.coins -= 300
			Save.persist()
			model.moves += 5
			model.over = false
			_render_moves()
			_close_panel()
			Sfx.play("coin")
			busy = false, Save.d.coins >= 300],
		["Сдаться (−1 жизнь)", "glass", func():
			Save.tick_lives()
			Save.d.streak = 0
			Save.d.lives = maxi(0, Save.d.lives - 1)
			if not Save.d.life_at: Save.d.life_at = Save.now_ms()
			Save.persist()
			_close_panel()
			finished.emit({won = false, n = model.n}), true]])

func _on_quit() -> void:
	if model.over or busy:
		if not model.over: return
	_panel("Выйти из уровня?", "Уровень засчитается как проигрыш, жизнь сгорит.", [
		["Выйти", "red", func():
			Save.tick_lives()
			Save.d.streak = 0
			Save.d.lives = maxi(0, Save.d.lives - 1)
			if not Save.d.life_at: Save.d.life_at = Save.now_ms()
			Save.persist()
			_close_panel()
			finished.emit({won = false, n = model.n}), true],
		["Играть дальше", "glass", _close_panel, true]])

# ---------------------------------------------------------------- small UI helpers

## a centred card with a title, text and buttons [[label, kind, callable, enabled], ...]
func _panel(title_text: String, body_text: String, buttons: Array) -> void:
	for ch in overlay.get_children(): ch.queue_free()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var card := PanelContainer.new()
	var st := UI.glass(24, 0.92)
	st.set_content_margin_all(18)
	card.add_theme_stylebox_override("panel", st)
	card.custom_minimum_size = Vector2(330, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.add_child(UI.title(title_text, 22))
	var body := UI.label(body_text, 15, UI.body, UI.MUTED)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(body)
	for b in buttons:
		var btn := UI.button(b[0], b[1], 17)
		btn.custom_minimum_size = Vector2(0, 54)
		btn.disabled = not b[3]
		btn.pressed.connect(b[2])
		v.add_child(btn)
	card.add_child(v)
	center.add_child(card)
	overlay.visible = true
	card.scale = Vector2(0.85, 0.85)
	card.pivot_offset = Vector2(165, 120)
	create_tween().tween_property(card, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _close_panel() -> void:
	overlay.visible = false
	for ch in overlay.get_children(): ch.queue_free()

func _toast(text: String) -> void:
	var l := UI.label(text, 14, UI.body_bold)
	var p := PanelContainer.new()
	var st := UI.glass(14, 0.9)
	st.border_color = UI.GOLD
	p.add_theme_stylebox_override("panel", st)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(300, 0)
	p.add_child(l)
	hud.add_child(p)
	p.position = Vector2((get_viewport_rect().size.x - 330) / 2, 120)
	p.modulate.a = 0
	var tw := create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.2)
	tw.tween_interval(2.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.3)
	tw.tween_callback(p.queue_free)

func _cheer(text: String) -> void:
	var l := UI.title(text, 34)
	l.add_theme_color_override("font_color", Color(1.4, 1.2, 0.6))
	l.add_theme_color_override("font_outline_color", Color("#3a2200"))
	l.add_theme_constant_override("outline_size", 10)
	hud.add_child(l)
	var vp := get_viewport_rect().size
	l.size = Vector2(vp.x, 60)
	l.position = Vector2(0, vp.y * 0.42)
	l.pivot_offset = l.size / 2
	l.scale = Vector2(0.3, 0.3)
	var tw := create_tween()
	tw.tween_property(l, "scale", Vector2(1.1, 1.1), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.6)
	tw.tween_property(l, "modulate:a", 0.0, 0.3)
	tw.tween_callback(l.queue_free)

func _confetti() -> void:
	var p := CPUParticles2D.new()
	var vp := get_viewport_rect().size
	p.position = Vector2(vp.x / 2, -20)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(vp.x / 2, 10)
	p.amount = 160
	p.one_shot = true
	p.explosiveness = 0.85
	p.lifetime = 2.6
	p.gravity = Vector2(0, 260)
	p.initial_velocity_min = 40
	p.initial_velocity_max = 160
	p.direction = Vector2(0, 1)
	p.spread = 60
	p.angular_velocity_min = -300
	p.angular_velocity_max = 300
	p.scale_amount_min = 4
	p.scale_amount_max = 8
	var cols := Gradient.new()
	cols.set_color(0, Color("#ee3a55"))
	cols.add_point(0.25, Color("#3484ff"))
	cols.add_point(0.5, Color("#25c071"))
	cols.add_point(0.75, Color("#ffbd2e"))
	cols.set_color(cols.get_point_count() - 1, Color("#a05ef7"))
	p.color_initial_ramp = cols
	hud.add_child(p)
	p.emitting = true
	get_tree().create_timer(3.0).timeout.connect(p.queue_free)
