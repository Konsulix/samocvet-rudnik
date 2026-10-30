class_name Level
extends Control
## One level: the gallery backdrop, the board, its effects and the HUD.
## Runs the turn loop (blast → pops → gravity → cascades) by asking BoardModel for the rules
## and BoardView / FxLayer for the show.

signal finished(result: Dictionary)   # {won, n, stone, bonus, coins}

var model := BoardModel.new()
var bg: TextureRect
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
var looks_icon: Control
var busy := true
var booster := ""
var idle := 0.0
var _hinted := false
var _flights := 0
var ore_chips := {}     # kind -> {root, count, vein}: what this level has mined so far, and the depth's vein
var ore_shown := {iron = 0, ore = 0}
var rich := false        # a rich vein this time: twice the ore stones
var prologue := false    # the very first board: the newcomer digs out of a cave-in towards a lantern (PROLOGUE)
var _light: TextureRect  # the prologue's lantern light from above, nearer as the rubble goes
var _rubble := 1         # how much rubble the prologue started with
var _lamp: KitLantern    # his lantern, hanging into the shaft over the rubble
var coach: Coach                # the tutorial's show on the board, over everything
var goals_line: Control         # the goals plate and the moves token: what the goals tip points at
var _coach_move: Array = []     # the one swap the tutorial lets through, while it shows it
var _coach_cell := Vector2i(-1, -1)   # the one special it lets the player set off
var _coach_tip := ""
var find_studio: SpecStudio     # the sealed specimen, turning slowly inside its block
var find_spec: Node3D

## backgrounds of the board: three of each mine, in the style of its surface picture (art/level_bg/gen_mine.sh, GPT)
const BG_N := 3
static var last_bg := -1

static func bg_path(area: int, i: int) -> String:
	return "res://assets/ui/level_bg/%d_%d.png" % [clampi(area, 0, 3), i + 1]

## a different background of this mine from the last level; `-- bg=N` (0..2) picks one for a shot
static func _pick_bg() -> String:
	var area := Save.area()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("bg="): return bg_path(area, clampi(int(a.get_slice("=", 1)), 0, BG_N - 1))
	if last_bg < 0:
		last_bg = randi() % BG_N
	else:
		last_bg = (last_bg + 1 + randi() % (BG_N - 1)) % BG_N
	return bg_path(area, last_bg)

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_layer = CanvasLayer.new()
	bg_layer.layer = -1
	add_child(bg_layer)
	# behind the board: one of the mine's backgrounds at random (a boss fight puts its own in LevelBoss.mount)
	bg = TextureRect.new()
	bg.texture = load(_pick_bg())
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
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
	var coach_layer := CanvasLayer.new()
	coach_layer.layer = 3
	add_child(coach_layer)
	coach = Coach.new()
	coach_layer.add_child(coach)

# ---------------------------------------------------------------- start

## level: a generated def (LevelGen), or empty for the hand-made level n
func start(n: int, pre: Array = [], dl: int = 0, level: Dictionary = {}) -> void:
	var eq: Dictionary = Save.d.eq
	model = BoardModel.new()
	model.rng.randomize()
	prologue = bool(level.get("prologue", false))
	model.setup(n, pre, dl, eq, Save.area(), not prologue, level)
	rich = bool(level.get("rich", false))
	Save.persist()
	var vp := get_viewport_rect().size
	bg.size = vp
	_layout()
	board.rebuild(model)
	_mount_find()
	_render_hud()
	if model.boss_on(): LevelBoss.mount(self)
	busy = true
	booster = ""
	hint_label.text = ""
	await board.drop_in()
	if model.boss_on(): LevelBoss.start(self)
	if prologue:
		_light_up()
		# someone up there, unseen: only a voice and his lantern
		await StoryScene.play(self, "prologue_voice", _lamp.get_global_transform_with_canvas().origin).finished
	busy = false
	idle = 0.0
	_coach_next()

## one studio for the sealed find, kept for the whole session and moved from level to level: a fresh
## viewport, world and render targets every level were part of the hitch on entering one. Same
## anti-aliasing as the start-up shader warm-up, so its shaders are already compiled for it.
static var _find_pool: SpecStudio

## the game is closing: free the pooled studio's viewport while the renderer is still up. Left to itself it sits outside
## the tree after the last level and is freed with the script, after the rendering server is gone - a crash on quit.
static func release_pool() -> void:
	if _find_pool and is_instance_valid(_find_pool.vp):
		_find_pool.vp.free()
	_find_pool = null

func _exit_tree() -> void:
	# hand the pooled studio back alive: it outlives this level
	if find_studio and find_studio.vp.get_parent() == self:
		find_studio.clear()
		remove_child(find_studio.vp)

func _mount_find() -> void:
	if find_studio:
		find_studio.clear()
		find_spec = null
	board.find_tex = null
	if model.find.is_empty():
		return
	if not _find_pool:
		_find_pool = SpecStudio.make(200, Viewport.MSAA_4X).lite()
	find_studio = _find_pool
	find_studio.clear()
	# the sealed find turns slowly: 30 renders a second are plenty (see _process)
	find_studio.vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if find_studio.vp.get_parent():
		find_studio.vp.get_parent().remove_child(find_studio.vp)
	add_child(find_studio.vp)
	board.find_tex = find_studio.vp.get_texture()
	var st := find_studio
	var p: Node3D = await st.show_async(Spec.of_stone(model.find.stone))
	if st != find_studio or p == null:
		return
	find_spec = p
	find_spec.rotation = Vector3(0.12, 0.6, 0)

func _layout() -> void:
	if model.boss_on():
		LevelBoss.layout(self)
		return
	var vp := get_viewport_rect().size
	var top := 162.0 + UI.safe_top()
	var bottom := 118.0 + UI.safe_bottom()
	board.layout(Vector2(vp.x - 12, vp.y - top - bottom), model.R, model.C)
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
	margin.add_theme_constant_override("margin_top", 8 + int(UI.safe_top()))
	hud.add_child(margin)
	margin.add_child(root)
	# top line: close and the level title
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var close := Kit.icon_button("close", 44)
	close.pressed.connect(_on_quit)
	top.add_child(close)
	top.add_theme_constant_override("separation", 10)
	var title_pill := PanelContainer.new()
	title_pill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# the drawn kit's title plate: dark iron with a brass rim and a rivet at each end
	var tp := Kit.box("title", 0.0)
	tp.content_margin_left = 22
	tp.content_margin_right = 22
	tp.content_margin_top = 8
	tp.content_margin_bottom = 9
	title_pill.add_theme_stylebox_override("panel", tp)
	title_label = Kit.label("Level", 15, UI.display, Kit.CREAM)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.clip_text = true
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.custom_minimum_size = Vector2(60, 0)
	title_pill.add_child(title_label)
	top.add_child(title_pill)
	# the looks: which gems, how ore shows, which timber (to try them out on the board)
	var looks := Kit.button("", "sq_dark", 18, 0.0)
	looks.custom_minimum_size = Vector2(44, 44)
	looks_icon = UI.icon(44, func(ci):
		BoardSprites.draw(ci, BoardSprites.gem(1), Vector2(16, 19), 23 * BoardSprites.gem_scale())
		BoardSprites.draw(ci, BoardSprites.gem(4), Vector2(28, 27), 22 * BoardSprites.gem_scale()))
	looks_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	looks_icon.material = BoardSprites.plain_material()
	looks_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	looks.add_child(looks_icon)
	looks.pressed.connect(_show_looks)
	top.add_child(looks)
	root.add_child(top)
	# goals and the moves token
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var goals_panel := PanelContainer.new()
	goals_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	goals_panel.custom_minimum_size = Vector2(60, 78)
	var gp := Kit.box("card", 0.0)
	gp.content_margin_left = 12
	gp.content_margin_right = 12
	gp.content_margin_top = 9
	gp.content_margin_bottom = 9
	goals_panel.add_theme_stylebox_override("panel", gp)
	var plate := VBoxContainer.new()
	plate.add_theme_constant_override("separation", 4)
	goals_panel.add_child(plate)
	# the goals share the plate in even cells, each centred in its own
	var goals_row := HBoxContainer.new()
	goals_row.name = "Goals"
	goals_row.add_theme_constant_override("separation", 0)
	plate.add_child(goals_row)
	var rule := ColorRect.new()
	rule.color = Color(1, 1, 1, 0.1)
	rule.custom_minimum_size = Vector2(0, 1)
	var rule_wrap := MarginContainer.new()
	for side in ["left", "right"]: rule_wrap.add_theme_constant_override("margin_" + side, 10)
	rule_wrap.add_child(rule)
	rule_wrap.name = "OreRule"
	plate.add_child(rule_wrap)
	# under them, the ore mined so far, each with what is left in the depth's vein in small grey
	var ores := HBoxContainer.new()
	ores.name = "Ores"
	ores.add_theme_constant_override("separation", 0)
	for kind in ["iron", "ore"]:
		var cell := CenterContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 5)
		var k: String = kind
		var ic := Kit.res_icon(k, 20)
		h.add_child(ic)
		var count := UI.label("0", 15, UI.display)
		count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(count)
		var vein := UI.label("", 11, UI.body_bold, UI.MUTED)
		vein.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(vein)
		cell.add_child(h)
		ores.add_child(cell)
		ore_chips[kind] = {root = h, icon = ic, count = count, vein = vein}
	plate.add_child(ores)
	line.add_child(goals_panel)
	goals_line = line
	moves_token = PanelContainer.new()
	moves_token.custom_minimum_size = Vector2(80, 80)
	moves_token.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	# the drawn kit's token: a slate disc in a riveted brass ring, the count in its exact middle
	var ring := Kit.tex("ring")
	moves_token.draw.connect(func():
		var d := minf(moves_token.size.x, moves_token.size.y)
		var c := moves_token.size / 2
		moves_token.draw_circle(c + Vector2(2, 4), d / 2, Color(0, 0, 0, 0.3), true, -1.0, true)
		moves_token.draw_texture_rect(ring, Rect2(c - Vector2(d, d) / 2, Vector2(d, d)), false))
	var mv := VBoxContainer.new()
	mv.alignment = BoxContainer.ALIGNMENT_CENTER
	mv.add_theme_constant_override("separation", -8)
	var small := Kit.label("MOVES", 9, UI.body_bold, Kit.DIM)
	small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mv.add_child(small)
	moves_label = Kit.label("0", 28, UI.display, Kit.AMBER)
	moves_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mv.add_child(moves_label)
	moves_token.add_child(mv)
	moves_token.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(moves_token)
	root.add_child(line)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fill)
	hint_label = UI.label("", 13, UI.body_bold, UI.STONE_INK)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(hint_label)
	# booster bar at the bottom, like the game's tab bar
	var bar := PanelContainer.new()
	var bs := StyleBoxEmpty.new()
	bs.content_margin_top = 6
	bs.content_margin_bottom = maxf(18.0, UI.safe_bottom() + 4.0)
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
	title_label.text = "Level %d · %d m%s" % [model.n, Data.depth_m(Save.area(), model.depth), " · rich vein" if rich else " · hard" if model.hard else ""]
	if prologue: title_label.text = "Cave-in"
	if model.boss_on():
		title_label.text = "%s · %d m" % [model.boss.B.n, int(model.boss.B.m)]
	# no ore is mined at the boss
	for nm in ["Ores", "OreRule"]:
		(hud.find_child(nm, true, false) as Control).visible = not model.boss_on()
	var row: HBoxContainer = hud.find_child("Goals", true, false)
	for ch in row.get_children(): ch.queue_free()
	goal_boxes.clear()
	if not model.find.is_empty(): BoardSprites.find_shape = "%dx%d" % [int(model.find.get("w", 2)), int(model.find.get("h", 2))]
	for i in model.goals.size():
		var g: Dictionary = model.goals[i]
		# a cell of the plate: the icon over its count
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", -2)
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var glow := Data.rarity_color(model.find.stone.tier) if g.k == "find" else Color("#c8b0ff")
		var k: String = g.k
		var colour: int = rock_mix() if k == "rock" else g.t
		var isz := 32 if model.goals.size() <= 3 else 28
		var gic := gas_icon(isz) if k == "gas" and BoardSprites.gem_style != "" else UI.icon(isz, func(ci):
			GemArt.begin(ci, Transform2D.IDENTITY)
			GemArt.goal_icon(ci, k, colour, isz, glow)
			GemArt.end(ci))
		# textures in the interface go through the stones' own shader: on iPhone the stock one draws nothing after the
		# shader bake, and takes the plates and text drawn next to it down with it
		if gic.material == null: gic.material = BoardSprites.plain_material()
		gic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(gic)
		var l := UI.label("", 15, UI.display)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(l)
		row.add_child(box)
		goal_boxes.append({root = box, icon = gic, label = l, shown = g.left})
		_render_goal(i)
	_render_moves()
	_render_boosters()
	ore_shown = {iron = 0, ore = 0}
	_render_ore()

## the ore chips: mined so far, and the vein as it will stand if the level is won
func _render_ore() -> void:
	for i in 2:
		var kind: String = ["iron", "ore"][i]
		var ch: Dictionary = ore_chips[kind]
		var left := vein_after(model.depth, i, int(ore_shown[kind]))
		var stock := vein_stock(model.depth, i)
		var poor := left <= BoardModel.vein_floor(stock)
		ch.count.text = str(ore_shown[kind])
		ch.vein.text = str(left) if not poor else "out"
		ch.vein.add_theme_color_override("font_color", Color("#e0904a") if poor else UI.MUTED)

## "Veins: iron 48/51 · gold 51/51" for a depth of the current mine
static func vein_text_for(a: int, dl: int) -> String:
	var parts := []
	for i in 2:
		var stock := vein_stock(dl, i)
		var left := vein_after(dl, i, 0)
		var nm: String = "iron" if i == 0 else String(Data.ore(a).n).to_lower()
		parts.append("%s %s" % [nm, "worked out" if left <= BoardModel.vein_floor(stock) else "%d/%d" % [left, stock]])
	return "Veins at %d m: " % Data.depth_m(a, dl) + " · ".join(parts)

## the depth's stock of one ore: 0 iron, 1 the mine's own
static func vein_stock(dl: int, i: int) -> int:
	var D: Dictionary = Data.depth(Save.area(), dl)
	return int(D.fe) if i == 0 else int(D.au)

## what is left in a vein once `taken` more is mined from it; its last tenth never goes
static func vein_after(dl: int, i: int, taken: int) -> int:
	var stock := vein_stock(dl, i)
	var left: int = int(Save.d.vein[dl][i]) if dl < Save.d.vein.size() else stock
	var fl := BoardModel.vein_floor(stock)
	return left if left <= fl else maxi(fl, left - taken)

func _render_goal(i: int) -> void:
	var gb: Dictionary = goal_boxes[i]
	var g: Dictionary = model.goals[i]
	if g.k == "boss":
		gb.label.text = "%d" % int(g.left)
		gb.label.add_theme_color_override("font_color", Color("#b0242c"))
	elif g.k == "find":
		gb.label.text = ("✓ %d%%" if model.find.done else "%d%%") % model.find.integ
		gb.label.add_theme_color_override("font_color", UI.GOOD if model.find.done else UI.INK)
	else:
		gb.label.text = str(gb.shown) if gb.shown > 0 else "✓"
		gb.label.add_theme_color_override("font_color", UI.GOOD if gb.shown <= 0 else UI.INK)

func _render_moves() -> void:
	moves_label.text = str(model.moves)
	var low := model.moves <= 5 and not model.over
	moves_label.add_theme_color_override("font_color", Color("#ff5a4a") if low else Kit.AMBER)
	if model.boss_on(): LevelBoss.moves(self)

func _render_boosters() -> void:
	for ch in booster_bar.get_children(): ch.queue_free()
	# a booster opening for the first time: say so once
	var fresh := []
	for bo in Data.BOOSTS:
		if Data.boost_open(bo) and not String(bo.id) in Save.d.btold:
			Save.d.btold.append(bo.id)
			fresh.append("%s: %s" % [bo.n, String(bo.d).to_lower()])
	if not fresh.is_empty():
		Save.persist()
		_toast("New booster! " + "; ".join(fresh))
	for bo in Data.BOOSTS:
		var id: String = bo.id
		var b := Button.new()
		b.custom_minimum_size = Vector2(64, 64)
		# the drawn kit's tiles (the chosen one lit warm), in the boss fight too
		for s in ["normal", "hover", "pressed"]: b.add_theme_stylebox_override(s, Kit.box("tab_on" if booster == id else "card", 0.0))
		var open := Data.boost_open(bo)
		var ic := UI.icon(44, func(ci):
			if id != "pick" or BoardSprites.gem_style != "":
				BoardSprites.draw(ci, BoardSprites.tex(id), Vector2(22, 22), 44)
				return
			GemArt.begin(ci, Transform2D(-0.7, Vector2(22, 22)))
			ci.draw_rect(Rect2(-2, -2, 4, 21), Color("#8a5a2c"))
			ci.draw_polyline(PackedVector2Array([Vector2(-16, -1), Vector2(-8, -9), Vector2(0, -11), Vector2(8, -9), Vector2(16, -1)]), Color("#9aa6b4"), 5, true)
			GemArt.end(ci))
		ic.material = BoardSprites.plain_material()
		ic.position = Vector2(10, 10)
		b.add_child(ic)
		if not open:
			# not yet: the tool in shadow, the depth it opens at under it
			ic.modulate = Color(0.25, 0.24, 0.23, 0.45)
			var at := UI.label("%d m" % Data.depth_m(0, int(bo.at)), 13, UI.body_bold, Color("#ece6dc"))
			at.add_theme_constant_override("outline_size", 6)
			at.add_theme_color_override("font_outline_color", Color("#2a2622"))
			at.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			at.custom_minimum_size = Vector2(64, 0)
			at.position = Vector2(0, 22)
			b.add_child(at)
			b.pressed.connect(func(): _toast("%s opens at %d m" % [bo.n, Data.depth_m(0, int(bo.at))]))
			booster_bar.add_child(b)
			continue
		var n: int = Save.d.boost[id]
		var badge := UI.label(str(n) if n else "+", 12, UI.body_bold)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var bstyle := StyleBoxFlat.new()
		bstyle.bg_color = Color("#e23a55") if n else Color("#e3a51e")
		bstyle.set_corner_radius_all(11)
		bstyle.border_color = Color("#ece6dc")
		bstyle.set_border_width_all(2)
		badge.add_theme_stylebox_override("normal", bstyle)
		badge.custom_minimum_size = Vector2(24, 22)
		badge.position = Vector2(46, 46)
		b.add_child(badge)
		b.pressed.connect(func(): _on_booster(bo))
		booster_bar.add_child(b)

## where a goal's counter sits, in the effects layer's coordinates
func _goal_target(gi: int) -> Vector2:
	var ic: Control = goal_boxes[gi].icon
	return fx.get_global_transform().affine_inverse() * ic.get_global_rect().get_center()

## the gas goal: a single pocket of the board's own gas (shaders/gas.gdshader), drifting as on the board
static func gas_icon(S: float) -> Control:
	var r := ColorRect.new()
	r.custom_minimum_size = Vector2(S, S)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.color = Color(0, 0, 0, 1)   # no gas neighbours
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/gas.gdshader")
	m.set_shader_parameter("overhang", 0.95)
	m.set_shader_parameter("cell_px", S / 0.95)
	r.material = m
	return r

## which rock the rock goal shows: 0 sandstone, 1 granite, 2 both
func rock_mix() -> int:
	var sand := false
	var granite := false
	for r in model.R:
		for c in model.C:
			if model.ROCK_MAX[r][c] >= 2: granite = true
			elif model.ROCK_MAX[r][c] == 1: sand = true
	return 2 if sand and granite else 1 if granite else 0

# ---------------------------------------------------------------- input

var _find_since := 0.0

func _process(dt: float) -> void:
	if find_spec:
		find_spec.rotation.y += dt * 0.5
	if _light: _light_tick()
	if find_studio:
		# 30 renders a second by the clock, whatever the screen's refresh rate
		_find_since += dt
		if _find_since >= 1.0 / 30.0 - 0.002 or not find_spec:
			_find_since = 0.0
			find_studio.vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	if busy or model.over or coach.visible: return
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
	if not _coach_allows(r1, c1, r2, c2):
		Sfx.play("bad")
		return
	var a_id := a.id
	var b_id := b.id
	var res = model.swap(r1, c1, r2, c2)
	if res == null:
		Sfx.play("bad")
		return
	if not res.get("undone", false): _coach_done()
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
	if not _coach_move.is_empty() or (_coach_cell.x >= 0 and Vector2i(r, c) != _coach_cell): return
	var g: BoardModel.Gem = model.gem_at(r, c)
	if g and g.sp != "" and not model.LOCK[r][c]:
		_coach_done()
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
		if cascade == 3: _cheer("Great!")
		elif cascade == 5: _cheer("Brilliant!")
		elif cascade == 7: _cheer("Nugget!")
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
		_cheer("Shuffling")
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
				fx.gem_chips(e.r, e.c, Color.html(Data.GEMS[e.color].c))
		"rock":
			board.redraw_under()
			if BoardSprites.gem_style != "" and e.left == 0:
				fx.shards(e.r, e.c, BoardSprites.granite() if e.get("granite", false) else "sand", Color("#c89a62"))
			else:
				fx.debris(e.r, e.c, Color("#c89a62") if e.left == 0 else Color("#8a919c"), 10)
			Sfx.play("rock")
			Sfx.buzz(10)
		"gas":
			board.redraw_under()
			fx.debris(e.r, e.c, Color("#a2dc3c"), 12)
			Sfx.play("rock")
		"mud":
			board.redraw_under()
			if BoardSprites.gem_style != "": fx.shards(e.r, e.c, "mud", Color("#7a4a2a"))
			else: fx.debris(e.r, e.c, Color("#7a5a3a"), 8)
		"lock":
			board.over.queue_redraw()
			fx.debris(e.r, e.c, Color("#b07a3e"), 10)
			Sfx.play("rock")
		"crust":
			board.over.queue_redraw()
			fx.plates(e.r, e.c, BoardSprites.malachite_look(e.r, e.c))
			Sfx.play("crust")
		"flower_tear":
			board.flower_layer.queue_redraw()
			fx.petals(e.r, e.c, ["", "buds", "middle", "outer"][int(e.st) + 1])
			Sfx.play("crust")
			if not has_meta("tear_told"):
				set_meta("tear_told", true)
				LevelBoss.line(self, "tear")
		"nodule":
			board.redraw_under()
			fx.shards(e.r, e.c, "malachite", Color("#2f8a62"))
			fx.sparkle(e.r, e.c, Color("#5fe0a0"), 6 + int(e.stage) * 6)
			if int(e.stage) >= 3: fx.pop_text(e.r, e.c, "+%d" % int(e.stage), Color("#7af0b4"))
			Sfx.play("nodule", int(e.stage))
			Sfx.buzz(10 + int(e.stage) * 8)
		"geo_hit":
			board.geo_hit_at[e.gi] = Time.get_ticks_msec() / 1000.0
			Sfx.play("crack", 4 - e.hp)
			var geo: Dictionary = model.geos[e.gi]
			fx.debris(geo.r + 0.5, geo.c + 0.5, Color("#9a8a78"), 12)
		"geo_open":
			board.redraw_under()
			fx.sparkle(e.r + 0.5, e.c + 0.5, Color("#d8b8ff"), 30)
			Sfx.play("reveal", 1)
			_toast("Geode cracked: a stone awaits you at the end of the level")
		"find_hit":
			board.find_hit_at = Time.get_ticks_msec() / 1000.0
			var F: Dictionary = model.find
			var fr: float = F.r + (F.h - 2) * 0.5
			var fc: float = F.c + (F.w - 2) * 0.5
			if e.rough:
				Sfx.play("crack", 3)
				Sfx.buzz(35)
				fx.debris(fr + 0.5, fc + 0.5, Color("#ffb090"), 16)
				fx.pop_text(fr + 0.5, fc + 0.5, "chip −%d%%" % e.chip)
			else:
				Sfx.play("rock")
				fx.debris(fr + 0.5, fc + 0.5, Color("#9a8a78"), 9)
			var gi := model.goal_index("find")
			if gi >= 0: _render_goal(gi)
		"find_done":
			board.find_done_at = Time.get_ticks_msec() / 1000.0
			board.redraw_under()
			var col := Data.rarity_color(model.find.stone.tier)
			fx.sparkle(e.r + 0.5, e.c + 0.5, Color(col.r * 1.5, col.g * 1.5, col.b * 1.5), 44)
			fx.flash(e.r + 0.5, e.c + 0.5, Color(col.r * 2, col.g * 2, col.b * 2), 2.0)
			Sfx.play("reveal", model.find.stone.tier)
			Sfx.buzz(60)
			_toast("Specimen extracted · soundness %d%%" % model.find.integ)
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
		"ore":
			_flights += 1
			var kind: String = e.kind
			var box: Control = ore_chips[kind].root
			var to: Vector2 = fx.get_global_transform().affine_inverse() * (ore_chips[kind].icon as Control).get_global_rect().get_center()
			fx.fly_badge(e.r, e.c, to, kind, func():
				_flights -= 1
				ore_shown[kind] += 1
				_render_ore()
				box.pivot_offset = box.size / 2
				var tw := create_tween()
				tw.tween_property(box, "scale", Vector2(1.08, 1.08), 0.07)
				tw.tween_property(box, "scale", Vector2.ONE, 0.12)
				Sfx.play("coin"))
		"tentacle_cut":
			board.sea_over.queue_redraw()
			for p: Vector2i in e.cells: fx.debris(p.x, p.y, Color("#8a6a7a"), 7)
			LevelBoss.sound(self, "cut", "crust")
		"ink":
			board.sea_over.queue_redraw()
		"eye_hit":
			board.eye_at = Time.get_ticks_msec() / 1000.0
			fx.flash(e.r, e.c, Color(0.8, 1.8, 2.4), 2.0)
			LevelBoss.sound(self, "eye", "boom")
			if not has_meta("eye_told"):
				set_meta("eye_told", true)
				LevelBoss.line(self, "eye")
		"boss_hit":
			LevelBoss.on_hit(self, e)
			if int(e.dmg) >= 25: fx.pop_text(e.r, e.c, "−%d" % int(e.dmg), Color("#ffd27a"))
		"bore":
			fx.bore(e.sp, e.r, e.c, BoardModel.BORE_IN / 1000.0, BoardModel.BORE_STEP / 1000.0)
			Sfx.play("rocket")
			Sfx.play("rockfall")
			Sfx.buzz(30)
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
			if BoardSprites.gem_style != "":
				# the radar pings: a cyan wave rolls out over the board before the zaps find their stones
				fx.flash(e.r, e.c, Color(0.6, 2.0, 2.6), 1.4)
				fx.ring(e.r, e.c, 3.0, Color(0.5, 1.8, 2.4))
			else:
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
	if model.boss_on():
		var stage_was: int = int(model.boss.stage)
		await LevelBoss.after_turn(self)
		if int(model.boss.stage) != stage_was:
			busy = false
			return
	var p := model.gas_spread()
	if p.x >= 0:
		board.sync(true)   # the gassed stone goes (and any other the model no longer has)
		board.redraw_under()
		fx.sparkle(p.x, p.y, Color("#c8f070"), 14)
		Sfx.play("gas")
		var gi := model.goal_index("gas")
		if gi >= 0:
			goal_boxes[gi].shown += 1
			_render_goal(gi)
		if not has_meta("gas_told"):
			set_meta("gas_told", true)
			_toast("Gas is spreading — hit it every move")
		await _wait(0.26)
	await _grow_nodules()
	if model.moves <= 0:
		model.over = true
		await _wait(0.3)
		_out_of_moves()
		return
	board.sync()
	busy = false
	idle = 0.0
	_hinted = false
	_coach_next()

# ---------------------------------------------------------------- the tutorial (docs/onboarding.md)

const TIP := {
	swap = "Swap two stones to make a row of three",
	goals = "These are the level's goals. Clear them before the moves run out",
	sp_rocket = "Four in a row make a stick of dynamite. Tap it!",
	sp_bomb = "An L or a T makes a dynamite bundle. Tap it!",
	sp_drill = "A square of four makes a drill. Tap it!",
	sp_orb = "Five in a row make a resonator. Tap it!",
	sand = "Sand crumbles when you match right beside it",
	mud = "Mud lies under a stone: break that stone to wash it off",
	granite = "Granite takes two hits beside it",
	gas = "Gas creeps every move. Match beside it to clear it",
	lock = "Timber pins a stone. Match that stone to knock it loose",
}
const TIP_SP := {rh = "sp_rocket", rv = "sp_rocket", bomb = "sp_bomb", drill = "sp_drill", orb = "sp_orb"}

## the next tip this board has for the player, if any: whenever the player may move. One at a time, each once
## (Save.told): the first swap (only that one goes through), the goals, a special the first time one stands on
## the board (only it can be set off), an obstacle the first time the board has it
func _coach_next() -> void:
	if Coach.off or model.boss_on() or model.over or busy or coach.visible: return
	if not Save.told("swap"):
		var mv := model.find_move()
		if mv.size() < 4 or (mv[0] == mv[2] and mv[1] == mv[3]): return
		_coach_move = mv
		_coach_tip = "swap"
		coach.open([_cells_rect(_match_cells(mv))], TIP.swap)
		coach.hand(_cell_screen(mv[0], mv[1]), _cell_screen(mv[2], mv[3]))
		return
	if not Save.told("goals"):
		_coach_tap("goals", [goals_line.get_global_rect()])
		return
	for r in model.R:
		for c in model.C:
			var g: BoardModel.Gem = model.G[r][c]
			if g and TIP_SP.has(g.sp) and not Save.told(TIP_SP[g.sp]) and not model.LOCK[r][c]:
				_coach_cell = Vector2i(r, c)
				_coach_tip = TIP_SP[g.sp]
				coach.open([_cells_rect([_coach_cell])], TIP[_coach_tip])
				var p := _cell_screen(r, c)
				coach.hand(p, p)
				return
	for id in ["sand", "mud", "granite", "gas", "lock"]:
		if Save.told(id): continue
		var cells := _obstacle_cells(id)
		if cells.is_empty(): continue
		# a few that lie together: the first and its nearest
		var first: Vector2i = cells[0]
		cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return (a - first).length_squared() < (b - first).length_squared())
		var rects := []
		for p in cells.slice(0, 3): rects.append(_cells_rect([p]))
		_coach_tap(id, rects)
		return

## a tip read and closed with a touch anywhere; the next one follows
func _coach_tap(id: String, rects: Array) -> void:
	busy = true
	coach.open(rects, TIP[id], true)
	await coach.dismissed
	Save.tell(id)
	busy = false
	_coach_next()

func _coach_allows(r1: int, c1: int, r2: int, c2: int) -> bool:
	if not _coach_move.is_empty():
		var m := _coach_move
		return (r1 == m[0] and c1 == m[1] and r2 == m[2] and c2 == m[3]) or (r1 == m[2] and c1 == m[3] and r2 == m[0] and c2 == m[1])
	if _coach_cell.x >= 0:
		return Vector2i(r1, c1) == _coach_cell or Vector2i(r2, c2) == _coach_cell
	return true

## the shown move was made: the tip is learnt
func _coach_done() -> void:
	if _coach_tip == "": return
	Save.tell(_coach_tip)
	_coach_tip = ""
	_coach_move = []
	_coach_cell = Vector2i(-1, -1)
	coach.close()

## the cells a swap lines up, the two swapped among them
func _match_cells(mv: Array) -> Array:
	var a := Vector2i(mv[0], mv[1])
	var b := Vector2i(mv[2], mv[3])
	var col := func(p: Vector2i) -> int:
		var q := b if p == a else (a if p == b else p)
		if q.x < 0 or q.y < 0 or q.x >= model.R or q.y >= model.C: return -1
		var g: BoardModel.Gem = model.G[q.x][q.y]
		return g.t if g and g.sp == "" else -1
	var out := [a, b]
	for p in [a, b]:
		var t: int = col.call(p)
		if t < 0: continue
		for d in [Vector2i(0, 1), Vector2i(1, 0)]:
			var run := [p]
			for s in [1, -1]:
				var q: Vector2i = p + d * s
				while col.call(q) == t:
					run.append(q)
					q += d * s
			if run.size() >= 3:
				for q in run:
					if not out.has(q): out.append(q)
	return out

func _obstacle_cells(id: String) -> Array:
	var out := []
	for r in model.R:
		for c in model.C:
			var on := false
			match id:
				"sand": on = model.ROCK[r][c] > 0 and model.ROCK_MAX[r][c] < 2
				"granite": on = model.ROCK[r][c] > 0 and model.ROCK_MAX[r][c] >= 2
				"mud": on = model.MUD[r][c] > 0
				"gas": on = model.GAS[r][c] > 0
				"lock": on = model.LOCK[r][c] == 1
			if on: out.append(Vector2i(r, c))
	return out

## a cell's middle on the screen (the coach's layer has no transform of its own)
func _cell_screen(r: int, c: int) -> Vector2:
	return board.get_global_transform_with_canvas() * board.cell_center(r, c)

## the screen rect round some cells
func _cells_rect(cells: Array) -> Rect2:
	var xf := board.get_global_transform_with_canvas()
	var out := Rect2()
	for i in cells.size():
		var p: Vector2i = cells[i]
		var lo := xf * (board.cell_center(p.x, p.y) - Vector2.ONE * board.TS * 0.5)
		var hi := xf * (board.cell_center(p.x, p.y) + Vector2.ONE * board.TS * 0.5)
		var r := Rect2(lo, hi - lo)
		out = r if i == 0 else out.merge(r)
	return out

## Copper Mountain: the malachite nodules grow; a full one overgrows and crusts the stones round it
func _grow_nodules() -> void:
	var grown := model.nodule_grow()
	if grown.is_empty(): return
	board.grow_nodules(grown)
	var crusted := false
	for e: Dictionary in grown:
		for p: Vector2i in e.crust:
			crusted = true
			fx.sparkle(p.x, p.y, Color("#3fd08a"), 10)
		if e.crust.size(): fx.debris(e.r, e.c, Color("#2f8a62"), 8)
	board.over.queue_redraw()
	Sfx.play("pop", 2)
	if crusted and not has_meta("crust_told"):
		set_meta("crust_told", true)
		_toast("Overgrown! Malachite crusted the stones round it")
	elif not has_meta("nodule_told"):
		set_meta("nodule_told", true)
		_toast("Malachite grows: the bigger it is, the more copper it gives — cut it off from beside")
	await _wait(NOD_WAIT)
	if not model.has_moves():
		_cheer("Shuffling")
		model.shuffle()
		await board.animate_shuffle()

const NOD_WAIT := 0.45

func _on_booster(bo: Dictionary) -> void:
	if busy or model.over: return
	var id: String = bo.id
	if Save.d.boost[id] <= 0:
		_buy_booster(bo)
		return
	if id == "pan":
		await _use_pan()
		return
	booster = "" if booster == id else id
	hint_label.text = ("%s: %s — tap a cell" % [bo.n, String(bo.d).to_lower()]) if booster != "" else ""
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
	if id == "pick":
		fx.pickaxe(r, c)
		await _wait(FxLayer.PICK_HIT)
	await _resolve(model.booster_events(id, r, c), [])
	await _booster_done()

## the gold pan: every loose stone is shaken up and settles somewhere else; specials, nuggets, anything locked,
## nodules and the rest of the board stay where they are. It costs no move.
func _use_pan() -> void:
	booster = ""
	hint_label.text = ""
	Save.d.boost.pan = maxi(0, Save.d.boost.pan - 1)
	Save.persist()
	_render_boosters()
	busy = true
	Sfx.play("pan")
	await fx.pan()
	model.shuffle()
	await board.animate_shuffle(true)
	await _resolve([], [])     # only if the shake-up could not help leaving a line ready
	await _booster_done()

func _booster_done() -> void:
	await _flights_done()
	if model.goals_done():
		model.over = true
		await _finale()
		_win()
		return
	if model.boss_stage_clear():
		await LevelBoss.next_board(self)
	elif not model.has_moves():
		_cheer("Shuffling")
		model.shuffle()
		await board.animate_shuffle()
	busy = false

func _buy_booster(bo: Dictionary) -> void:
	var price: int = bo.price
	_panel("%s" % bo.n, "%s. Buy 3?" % bo.d, [
		["Buy · %s" % UI.coins(price), "gold", func():
			if Save.d.coins < price: return
			Save.d.coins -= price
			Save.d.boost[bo.id] += 3
			Save.persist()
			Sfx.play("coin")
			_close_panel()
			_render_boosters(), Save.d.coins >= price],
		["Not now", "glass", _close_panel, true]])

# ---------------------------------------------------------------- level end

func _finale() -> void:
	if model.boss_on(): await LevelBoss.defeat(self)
	if model.moves <= 0: return
	_cheer("Blast shift!")
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
	# the ore counts only now, and comes out of the depth's veins (none is mined at the boss)
	if model.boss_on():
		model.mined = {iron = 0, ore = 0}
		Save.d.boss_won[Save.area()] = true
		LevelBoss.line(self, "win")
		# the reward, the boss's hoard (Hoard), is opened after the fight (Main._on_level_finished)
	Save.d.fe += int(model.mined.iron)
	Save.d.ore += int(model.mined.ore)
	if model.depth < Save.d.vein.size():
		for i in 2:
			Save.d.vein[model.depth][i] = vein_after(model.depth, i, int(model.mined[["iron", "ore"][i]]))
	Save.d.level = maxi(Save.d.level, model.n + 1)
	Save.d.streak += 1
	Save.persist()
	var stone := {}
	if not model.find.is_empty() and model.find.done:
		stone = model.extracted_stone(Save.has_jewel("diadem"))
	_victory_fx()
	await _wait(0.6)
	finished.emit({won = true, n = model.n, depth = model.depth, coins = coins, stone = stone, bonus = model.bonus, mined = model.mined.duplicate(), boss = model.boss_on(), prologue = prologue})

func _out_of_moves() -> void:
	Sfx.play("lose")
	var left := 0
	for g in model.goals:
		if g.left > 0: left += 1
	var msg := "Goals left: %d.%s Five more moves?" % [left, " The specimen will stay in the rock." if not model.find.is_empty() and not model.find.done else ""]
	_panel("Out of moves", msg, [
		["+5 moves · 300 coins", "gold", func():
			if Save.d.coins < 300: return
			Save.d.coins -= 300
			Save.persist()
			model.moves += 5
			model.over = false
			_render_moves()
			_close_panel()
			Sfx.play("coin")
			busy = false, Save.d.coins >= 300],
		["Give up (−1 life)", "glass", func():
			Save.tick_lives()
			Save.d.streak = 0
			Save.d.lives = maxi(0, Save.d.lives - 1)
			if not Save.d.life_at: Save.d.life_at = Save.now_ms()
			Save.persist()
			_close_panel()
			finished.emit({won = false, n = model.n, depth = model.depth, boss = model.boss_on()}), true]])

func _on_quit() -> void:
	if model.over or busy:
		if not model.over: return
	_panel("Leave the level?", "It counts as a loss and costs a life.", [
		["Leave", "red", func():
			Save.tick_lives()
			Save.d.streak = 0
			Save.d.lives = maxi(0, Save.d.lives - 1)
			if not Save.d.life_at: Save.d.life_at = Save.now_ms()
			Save.persist()
			_close_panel()
			finished.emit({won = false, n = model.n, depth = model.depth, boss = model.boss_on()}), true],
		["Keep playing", "glass", _close_panel, true]])

# ---------------------------------------------------------------- small UI helpers

# ---------------------------------------------------------------- the looks panel

## `-- level=1 gen depth=6 ui=boss_demo`: the boss' whole show without playing (hits, its turn, a lost board, the end)
func _boss_demo() -> void:
	if model.boss_on(): await LevelBoss.demo(self)

## `-- area=2 level=1 gen depth=9 ui=boss_next`: the next board of the fight comes in now (the Kraken rising, his gulls)
func _boss_next() -> void:
	if not model.boss_on(): return
	busy = true
	await LevelBoss.next_board(self)
	busy = false

## `-- area=1 level=1 gen depth=6 ui=boss_raid`: the Mistress' lizards come for the greens right away
func _boss_raid() -> void:
	if not model.boss_on() or not model.boss.B.act.has("lizards"): return
	model.boss.intent = {act = "lizards", cells = model.lizard_marks()}
	model.boss.timer = 1
	LevelBoss.show_intent(self)
	await _wait(0.8)
	busy = true
	await LevelBoss.after_turn(self)
	busy = false

func _show_looks() -> void:
	if busy or model.over or overlay.visible: return
	var v := _panel("Look", "Try the board's looks. Kept for every level.", [["Close", "glass", _close_panel, true]])
	var close_btn := v.get_child(v.get_child_count() - 1)
	var add := func(n: Control) -> void:
		v.add_child(n)
		v.move_child(close_btn, -1)
	add.call(_looks_head("Gems"))
	for style: String in BoardSprites.GEM_STYLES:
		var b := _looks_option(BoardSprites.GEM_STYLES[style], BoardSprites.gem_style == style, 54)
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for colour in 6:
			var ic := UI.icon(30, func(ci):
				BoardSprites.draw(ci, BoardSprites.gem_in_style(colour, style), Vector2(15, 15), 30 * 0.95 * BoardSprites.gem_scale(style)))
			ic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			ic.material = BoardSprites.plain_material()
			row.add_child(ic)
		b.get_child(0).add_child(row)
		b.pressed.connect(_set_look.bind("gem_style", style))
		add.call(b)
	add.call(_looks_head("Ore"))
	var ores := HBoxContainer.new()
	ores.add_theme_constant_override("separation", 6)
	for look: String in BoardSprites.ORE_LOOKS:
		var b := _looks_option(BoardSprites.ORE_LOOKS[look], BoardSprites.ore_look == look, 44)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_set_look.bind("ore_look", look))
		ores.add_child(b)
	add.call(ores)
	add.call(_looks_head("Blocks"))
	var zones := HBoxContainer.new()
	zones.add_theme_constant_override("separation", 6)
	for style: String in BoardSprites.ZONE_STYLES:
		var b := _looks_option(BoardSprites.ZONE_STYLES[style], BoardSprites.zone_style == style, 70)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if style != "classic":
			var zt := BoardSprites.zone_icon("geode_2x2", style)
			var zi := UI.icon(40, func(ci): ci.draw_texture_rect(zt, Rect2(0, 0, 40, 40), false))
			zi.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			zi.material = BoardSprites.plain_material()
			var zc := CenterContainer.new()
			zc.mouse_filter = Control.MOUSE_FILTER_IGNORE
			zc.add_child(zi)
			b.get_child(0).add_child(zc)
		b.pressed.connect(_set_look.bind("zone_style", style))
		zones.add_child(b)
	add.call(zones)
	add.call(_looks_head("Timber"))
	var locks := HBoxContainer.new()
	locks.add_theme_constant_override("separation", 6)
	for style: String in BoardSprites.LOCK_STYLES:
		var b := _looks_option(BoardSprites.LOCK_STYLES[style], BoardSprites.lock_style == style, 70)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var path: String = {rendered = "res://assets/board/special_kit/lock.png", drawn = "res://assets/board/blockers_natural/lock.png"}.get(style, "res://assets/board/pieces/lock.png")
		var lock_tex: Texture2D = load(path)
		var ic := UI.icon(40, func(ci): BoardSprites.draw(ci, lock_tex, Vector2(20, 20), 36))
		ic.material = BoardSprites.plain_material()
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		var c := CenterContainer.new()
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.add_child(ic)
		b.get_child(0).add_child(c)
		b.pressed.connect(_set_look.bind("lock_style", style))
		locks.add_child(b)
	add.call(locks)

func _looks_head(text: String) -> Label:
	var l := UI.label(text, 14, UI.body_bold, UI.MUTED)
	return l

## an option card: its label on top, room below (its first child's column) for previews; gold-edged when chosen
func _looks_option(text: String, chosen: bool, height: float) -> Button:
	var b := UI.button("", "glass", 15)
	b.custom_minimum_size = Vector2(0, height)
	if chosen:
		var border := UI.glass(14, 0.9)
		border.border_color = UI.GOLD
		border.set_border_width_all(2)
		b.add_theme_stylebox_override("normal", border)
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 2)
	var l := UI.label(text + ("  ✓" if chosen else ""), 14, UI.display)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(l)
	b.add_child(col)
	return b

## store a look and repaint the board in place: no new board, no lost moves
func _set_look(key: String, value: Variant) -> void:
	Save.d[key] = value
	Save.persist()
	Save.looks_to_board()
	board.restyle()
	for gb: Dictionary in goal_boxes: (gb.root as Control).queue_redraw()
	looks_icon.queue_redraw()
	_close_panel()
	_show_looks()

## a centred card with a title, text and buttons [[label, kind, callable, enabled], ...]; returns its column
func _panel(title_text: String, body_text: String, buttons: Array) -> VBoxContainer:
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
		btn.custom_minimum_size = Vector2(0, 50)
		btn.disabled = not b[3]
		btn.pressed.connect(b[2])
		v.add_child(btn)
	card.add_child(v)
	center.add_child(card)
	overlay.visible = true
	card.scale = Vector2(0.85, 0.85)
	card.pivot_offset = Vector2(165, 120)
	create_tween().tween_property(card, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return v

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

## the win: the mine answers — gold sparks fly up off the board and drift down, while dust and grit sift from the
## roof (the old coloured confetti did not belong underground)
func _victory_fx() -> void:
	var vp := get_viewport_rect().size
	var soft := GradientTexture2D.new()
	var sg := Gradient.new()
	sg.set_color(0, Color(1, 1, 1, 1))
	sg.set_color(1, Color(1, 1, 1, 0))
	soft.gradient = sg
	soft.fill = GradientTexture2D.FILL_RADIAL
	soft.fill_from = Vector2(0.5, 0.5)
	soft.fill_to = Vector2(1.0, 0.5)
	soft.width = 32
	soft.height = 32
	# soft dust from the roof
	var dust := _victory_emitter(Vector2(vp.x / 2, -10), Vector2(vp.x / 2, 6), 70, 2.8, 0.5)
	dust.texture = soft
	dust.gravity = Vector2(0, 40)
	dust.initial_velocity_min = 10
	dust.initial_velocity_max = 50
	dust.direction = Vector2(0, 1)
	dust.spread = 25
	dust.scale_amount_min = 0.4
	dust.scale_amount_max = 1.6
	dust.color_ramp = _ramp([Color(0.62, 0.52, 0.4, 0.0), Color(0.62, 0.52, 0.4, 0.6), Color(0.5, 0.42, 0.33, 0.0)])
	# grit falling with it, faster, not spinning like paper
	var grit := _victory_emitter(Vector2(vp.x / 2, -10), Vector2(vp.x / 2, 6), 40, 1.8, 0.6)
	grit.gravity = Vector2(0, 700)
	grit.initial_velocity_min = 20
	grit.initial_velocity_max = 90
	grit.direction = Vector2(0, 1)
	grit.spread = 10
	grit.scale_amount_min = 1.5
	grit.scale_amount_max = 3.5
	grit.color_ramp = _ramp([Color("#8a7660"), Color("#5e4e3e"), Color(0.37, 0.31, 0.24, 0.0)])
	# gold sparks thrown up off the board, then sinking and going out
	var sparks := _victory_emitter(Vector2(vp.x / 2, vp.y * 0.52), Vector2(vp.x * 0.38, vp.y * 0.18), 90, 1.6, 0.8)
	sparks.texture = soft
	sparks.gravity = Vector2(0, 180)
	sparks.initial_velocity_min = 80
	sparks.initial_velocity_max = 260
	sparks.direction = Vector2(0, -1)
	sparks.spread = 40
	sparks.damping_min = 40
	sparks.damping_max = 90
	sparks.scale_amount_min = 0.25
	sparks.scale_amount_max = 0.6
	sparks.color_ramp = _ramp([Color(1.0, 0.93, 0.6, 1.0), Color(1.0, 0.72, 0.25, 0.9), Color(0.85, 0.4, 0.1, 0.0)])

func _victory_emitter(at: Vector2, ext: Vector2, amount: int, life: float, burst: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.position = at
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = ext
	p.amount = amount
	p.one_shot = true
	p.explosiveness = burst
	p.lifetime = life
	hud.add_child(p)
	p.emitting = true
	get_tree().create_timer(life + 0.5).timeout.connect(p.queue_free)
	return p

func _ramp(cols: Array[Color]) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, cols[0])
	g.set_color(1, cols[cols.size() - 1])
	for i in range(1, cols.size() - 1):
		g.add_point(i / float(cols.size() - 1), cols[i])
	return g

# ---------------------------------------------------------------- the prologue (docs/onboarding.md, first entry)

## the very first board: a cave-in at the mouth of a shaft, sand rubble overhead, a lantern beyond it. Easy, a few
## colours, moves to spare; no find, no boss. Won, the camera rises through the mine to the one holding the lantern
const PROLOGUE := {
	prologue = true, gen = true, colors = 4, moves = 40, goals = [["rock"]],
	map = "##rrrr##|#rrrrrr#|#rr..rr#|#......#|........|........|........|........",
}

## the lantern's light over the rubble: a warm glow from above the board
func _light_up() -> void:
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.85, 0.5, 1.0))
	g.add_point(0.4, Color(1.0, 0.72, 0.32, 0.45))
	g.set_color(g.get_point_count() - 1, Color(1.0, 0.6, 0.2, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	gt.width = 256
	gt.height = 256
	_rubble = maxi(1, _rubble_left())
	_light = TextureRect.new()
	_light.texture = gt
	_light.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_light)
	_lamp = KitLantern.new(64.0)
	_lamp.position = Vector2(board.size.x / 2, -78.0)
	holder.add_child(_lamp)
	_light_tick()

## nearer and brighter as the rubble goes; it flickers like a flame
func _light_tick() -> void:
	var done := 1.0 - clampf(float(_rubble_left()) / float(_rubble), 0.0, 1.0)
	var w := board.size.x * (0.7 + 0.6 * done)
	var h := board.size.y * (0.35 + 0.55 * done)
	_light.size = Vector2(w, h)
	_light.position = Vector2((board.size.x - w) / 2, -h * (0.25 - 0.2 * done))
	var flick := 0.92 + 0.08 * sin(Time.get_ticks_msec() / 1000.0 * 9.0) * sin(Time.get_ticks_msec() / 1000.0 * 3.7)
	_light.modulate.a = (0.55 + 0.45 * done) * flick

func _rubble_left() -> int:
	for gl in model.goals:
		if String(gl.k) == "rock": return int(gl.left)
	return 0
