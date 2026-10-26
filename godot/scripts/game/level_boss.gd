class_name LevelBoss
extends RefCounted
## The boss fight on the level screen. The rules are BoardModel's (boss_*); this shows them: the boss over the board
## (BossView: moods, line boil, hits, the defeat), its body as the board's frame (BossFrame), the dark fight interface
## (BossHud: name, moves, health on the frame, the bubble with its plan or its words), the cells it is about to hit
## outlined on the board (BoardView.marks), the next board dropping in when a third of its health is gone.

## what the boss's actions are called on screen
const ACTS := {coils = "Coils: timber on stones", rockfall = "Rockfall", breath = "Poison breath", hoard = "Hoard: heals on gold",
	lizards = "Lizards: steal the greens", crust = "Malachite crust", flower = "Stone flower: blooms and heals"}
## the stage over the board, pt; how far the boss' bottom tucks behind the frame; its sprite's left edge
const STAGE := 190.0
const SINK := 26.0
const BOSS_X := -8.0
## a hit this strong, or this much in one move, makes it flinch
const BIG_HIT := 25
const BIG_TURN := 80
## where no bar hides the boss' flat-cut bottom it sinks into the dark over this much, pt; the ramp beside a bar
const SINK_BAND := 22.0
const SINK_RAMP := 10

static var _turn_dmg := 0

static func view(lv: Level) -> BossView: return lv.get_node_or_null("BossView") as BossView
static func frame(lv: Level) -> BossFrame: return lv.shaker.get_node_or_null("BossFrame") as BossFrame
static func hud(lv: Level) -> BossHud: return lv.hud.get_node_or_null("BossHud") as BossHud
static func lizards(lv: Level) -> BossLizards: return lv.shaker.get_node_or_null("BossLizards") as BossLizards

## a boss' own sound for a moment of the fight (its data's "sfx": hurt, phase, an action's name), or `fallback`
static func sound(lv: Level, key: String, fallback := "") -> void:
	var s := String(lv.model.boss.B.get("sfx", {}).get(key, fallback))
	if s != "": Sfx.play(s)

static func line(lv: Level, key: String, i := -1) -> void:
	var L: Dictionary = lv.model.boss.B.lines
	var t = L.get(key, "")
	if t is Array: t = t[clampi(i, 0, t.size() - 1)]
	if String(t) == "": return
	var h := hud(lv)
	if h: h.say(String(t))
	else: lv._toast("%s: “%s”" % [lv.model.boss.B.n, t])

# ---------------------------------------------------------------- building the fight's screen

## the board under the boss' stage, at a cell size the pixel frame was baked for
static func layout(lv: Level) -> void:
	var vp := lv.get_viewport_rect().size
	var top := UI.safe_top() + 2.0 + BossHud.BAR + STAGE
	var bottom := 80.0 + UI.safe_bottom()
	lv.board.layout(Vector2(vp.x - 12, vp.y - top - bottom), lv.model.R, lv.model.C)
	lv.holder.position = Vector2(roundf((vp.x - lv.board.size.x) / 2), roundf(top))
	lv.holder.size = lv.board.size

## the boss, its frame, its interface; the level's own header and goal plate make way
static func mount(lv: Level) -> void:
	# `-- boss_stage=N`: start on board N (0..2), for checking the boards' shapes and the frame round them
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("boss_stage=") and int(lv.model.boss.stage) == 0:
			for i in int(arg.get_slice("=", 1)): lv.model.next_stage()
			lv._layout()
			lv.board.rebuild(lv.model)
	var B: Dictionary = lv.model.boss.B
	var id: String = B.get("id", "poloz")
	if view(lv): return
	if Sfx.MUSIC.has("boss_" + id): Sfx.music("boss_" + id)
	lv.bg.texture = load("res://assets/boss/%s/bg.png" % id)
	lv.bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var v := BossView.load_for(id)
	v.name = "BossView"
	lv.add_child(v)
	lv.move_child(v, lv.holder.get_index())
	var f := BossFrame.load_for(id)
	f.name = "BossFrame"
	lv.shaker.add_child(f)
	lv.shaker.move_child(f, lv.board.get_index() + 1)
	# the Mistress' lizards run over her frame
	var lz := BossLizards.load_for(id)
	if lz:
		lz.name = "BossLizards"
		lz.z_index = 6
		lv.shaker.add_child(lz)
		lv.shaker.move_child(lz, f.get_index() + 1)
	var h := BossHud.new(lv)
	h.name = "BossHud"
	lv.hud.add_child(h)
	# the level's title row and goal plate are the fight's top bar and health now
	(lv.title_label.get_parent().get_parent() as Control).visible = false
	(lv.moves_token.get_parent() as Control).visible = false
	lv.hint_label.text = ""
	place(lv)
	title(lv)
	moves(lv)
	refresh_hp(lv)
	v.set_phase(int(lv.model.boss.stage))
	v.set_rest("rage" if int(lv.model.boss.stage) >= 2 else "idle")

## put the boss, the frame and the health bar where the board is now
static func place(lv: Level) -> void:
	var b := lv.board
	var grid := Vector2(b.PAD, b.PAD)
	var f := frame(lv)
	f.rows = lv.model.R
	f.cols = lv.model.C
	f.use_stage(int(lv.model.boss.stage))
	f.fit(lv.model.playable, grid, b.TS)
	var lz := lizards(lv)
	if lz:
		lz.rows = lv.model.R
		lz.cols = lv.model.C
		lz.fit(lv.model.playable, grid, b.TS, float(f.meta.offset))
	var top_line := lv.holder.position.y + f.top_line()
	var v := view(lv)
	v.position = Vector2(float(v.meta.get("x", BOSS_X)), roundf(top_line + float(v.meta.get("sink", SINK)) - v.size.y))
	_expose(lv, v, f)
	var h := hud(lv)
	var gx := lv.holder.position.x + b.PAD
	# inset by a cell and a bit: the quartz on the frame's top corners stays in sight
	# on the top run of the frame: the board's first row, from its first cell to its last, its corners left in sight
	var m := lv.model
	var r0 := 0
	while r0 < m.R - 1 and range(m.C).all(func(c: int) -> bool: return not m.playable(r0, c)): r0 += 1
	var cs := range(m.C).filter(func(c: int) -> bool: return m.playable(r0, c))
	var inset := b.TS * (1.25 if cs.size() >= 6 else 0.45)
	var x0: float = gx + float(cs[0]) * b.TS + inset
	var x1: float = gx + float(cs[-1] + 1) * b.TS - inset
	h.hp_rect = Rect2(roundf(x0), roundf(top_line + r0 * b.TS - 10), roundf(x1 - x0), 20)
	h.bubble_target = v.head_global()
	h.queue_redraw()

## which columns of the boss' picture have no bar of the frame under their bottom: beyond the board's sides and
## over a cut-away corner of its top. The frame's bar reaches a little past its cells; the edge is ramped softly
static func _expose(lv: Level, v: BossView, f: BossFrame) -> void:
	var b := lv.board
	var m := lv.model
	var w := int(v.size.x)
	var bottom := v.position.y + v.size.y
	var reach := b.TS * (float(f.meta.offset) + 0.3)         # the bar's outer edge, out from the cells
	var raw := PackedFloat32Array()
	raw.resize(w)
	for x in w:
		var gx := v.position.x + x - lv.holder.position.x - b.PAD   # in the grid, px
		var top := INF
		for c in m.C:
			if gx < c * b.TS - reach or gx > (c + 1) * b.TS + reach: continue
			for r in m.R:
				if m.playable(r, c):
					top = minf(top, lv.holder.position.y + b.PAD + r * b.TS - reach)
					break
		raw[x] = 1.0 if top > bottom - 2.0 else 0.0
	var out := PackedFloat32Array()
	out.resize(w)
	for x in w:
		var s := 0.0
		for d in range(-SINK_RAMP, SINK_RAMP + 1): s += raw[clampi(x + d, 0, w - 1)]
		out[x] = s / float(SINK_RAMP * 2 + 1)
	v.set_exposed(out, SINK_BAND)

static func title(lv: Level) -> void:
	var B: Dictionary = lv.model.boss.B
	hud(lv).set_title(String(B.n), "%s · %d m" % [String(B.get("sub", "")), int(B.m)])

static func moves(lv: Level) -> void:
	var h := hud(lv)
	if h: h.set_moves(lv.model.moves)

# ---------------------------------------------------------------- the fight

## the start: its words, its first plan
static func start(lv: Level) -> void:
	line(lv, "start")
	show_intent(lv)

## the next action and how many moves until it; its cells outlined on the last move before it
static func show_intent(lv: Level) -> void:
	var b: Dictionary = lv.model.boss
	var it: Dictionary = b.intent
	var left: int = int(b.timer)
	# the lizards' marks are taken the move before they come: the greens there are then
	if it.act == "lizards" and left <= 1: it.cells = lv.model.lizard_marks()
	var h := hud(lv)
	if h: h.set_intent(String(it.act), left)
	else: lv.hint_label.text = "%s · %s in %d %s" % [b.B.n, ACTS.get(it.act, it.act), left, "move" if left == 1 else "moves"]
	lv.board.marks = it.cells if left <= 1 else []
	lv.board.over.queue_redraw()

## a hit landed (the model's "boss_hit" effect): the health bar, a flash, a flinch when it hurt
static func on_hit(lv: Level, e: Dictionary) -> void:
	refresh_hp(lv)
	var v := view(lv)
	if not v: return
	var was := _turn_dmg
	_turn_dmg += int(e.get("dmg", 0))
	var big := int(e.get("dmg", 0)) >= BIG_HIT or (was < BIG_TURN and _turn_dmg >= BIG_TURN)
	v.hit(big)
	if big: sound(lv, "hurt")
	if was < BIG_TURN * 2 and _turn_dmg >= BIG_TURN * 2: line(lv, "combo")

## after the player's move: a cleared board makes way for the next; then the boss takes its turn
static func after_turn(lv: Level) -> void:
	_turn_dmg = 0
	var m: BoardModel = lv.model
	if m.boss_stage_clear():
		await next_board(lv)
		return
	var acting := int(m.boss.timer) <= 1
	if acting and view(lv):
		view(lv).cast()
		await lv._wait(0.35)
	var res := m.boss_turn()
	if not res.is_empty() and res.act == "lizards":
		await _lizard_raid(lv, res)
	elif not res.is_empty() and res.act == "flower":
		await _flower(lv, res)
	elif not res.is_empty():
		for id in res.removed: lv.board.remove_node(id)
		lv.board.redraw_under()
		lv.board.over.queue_redraw()
		for p: Vector2i in res.cells:
			if res.act == "crust": lv.fx.sparkle(p.x, p.y, Color("#3fd08a"), 10)
			else: lv.fx.debris(p.x, p.y, Color("#b07a3e"), 8)
		var tw := lv.create_tween()
		for k in 4:
			tw.tween_property(lv.shaker, "position", Vector2(randf_range(-5, 5), randf_range(-4, 4)), 0.04)
		tw.tween_property(lv.shaker, "position", Vector2.ZERO, 0.05)
		sound(lv, String(res.act), "rock")
		if res.act == "hoard":
			var h := hud(lv)
			var msg := "My hoard feeds me: +%d" % int(res.heal) if res.heal else "Nothing left to feed on..."
			if h: h.say(msg, 2.0)
			else: lv._toast(msg)
			refresh_hp(lv)
		await lv._wait(0.35)
		if not m.has_moves():
			m.shuffle()
			await lv.board.animate_shuffle()
	show_intent(lv)

## her lizards carry off the greens; the holes fill with any colour but green, and what that matches goes as usual
static func _lizard_raid(lv: Level, res: Dictionary) -> void:
	var m: BoardModel = lv.model
	lv.board.marks = []
	lv.board.over.queue_redraw()
	var lz := lizards(lv)
	sound(lv, "lizards")
	if lz: await lz.raid(res.cells, res.removed, lv.board)
	else:
		for id in res.removed: lv.board.remove_node(id)
	for p: Vector2i in res.cells: m.G[p.x][p.y] = null
	lv.board.refresh()
	await lv.board.animate_collapse(m.collapse())
	m.skip_colour = -1
	await lv._resolve([], [])

## her flower grew a ring back, or bloomed: healed her and crusted the stones round it
static func _flower(lv: Level, res: Dictionary) -> void:
	var m: BoardModel = lv.model
	lv.board.flower_at = Time.get_ticks_msec() / 1000.0
	lv.board.marks = []
	if res.get("bloom", false):
		var F: Dictionary = m.flower
		lv.fx.flash(float(F.r) + 0.5, float(F.c) + 0.5, Color(0.8, 2.2, 1.2), 2.2)
		lv.fx.ring(float(F.r) + 0.5, float(F.c) + 0.5, 2.0, Color(0.5, 2.0, 1.0))
		for p: Vector2i in res.cells: lv.fx.sparkle(p.x, p.y, Color("#3fd08a"), 10)
		sound(lv, "bloom")
		get_tree_timer(lv, 0.25, func(): sound(lv, "crust"))
		line(lv, "bloom")
		refresh_hp(lv)
		var h := hud(lv)
		if h and int(res.heal): h.say("+%d" % int(res.heal), 1.6)
	else:
		sound(lv, "grow")
	lv.board.refresh()
	await lv._wait(0.5)
	if not m.has_moves():
		m.shuffle()
		await lv.board.animate_shuffle()

static func get_tree_timer(lv: Level, sec: float, fn: Callable) -> void:
	lv.get_tree().create_timer(sec).timeout.connect(fn)

## a third of its health gone: it screams, its words, then the next board falls in with the moves carried over
static func next_board(lv: Level) -> void:
	var m: BoardModel = lv.model
	var v := view(lv)
	if v: v.lose_phase()
	sound(lv, "phase")
	line(lv, "stage", int(m.boss.stage))
	await lv._wait(1.0)
	m.next_stage()
	lv.board.marks = []
	lv.board.rebuild(m)
	lv._render_hud()
	if v:
		place(lv)
		title(lv)
		moves(lv)
		refresh_hp(lv)
		v.set_phase(int(m.boss.stage))
		v.set_rest("rage" if int(m.boss.stage) >= 2 else "idle")
	await lv.board.drop_in()
	lv._toast(String(m.boss.B.stages[m.boss.stage].name))
	show_intent(lv)

## its health is gone: no more plans; it screams, falls and lies in the dust before the win
static func defeat(lv: Level) -> void:
	var v := view(lv)
	if not v: return
	lv.board.marks = []
	lv.board.over.queue_redraw()
	var h := hud(lv)
	h.clear_intent()
	h.set_hp(0, int(lv.model.boss.hp_max))
	frame(lv).swaying = false
	await v.defeat()

## the show for screenshots and checks on a phone: hits, a flinch, its turn, a lost board, the defeat
static func demo(lv: Level) -> void:
	var v := view(lv)
	var h := hud(lv)
	await lv._wait(1.0)
	v.hit(false)
	await lv._wait(0.6)
	h.set_hp(900, int(lv.model.boss.hp_max))
	v.hit(true)
	await lv._wait(1.2)
	v.cast()
	h.set_intent("rockfall", 1)
	await lv._wait(1.4)
	v.lose_phase()
	line(lv, "stage", 1)
	await lv._wait(1.6)
	v.set_rest("rage")
	h.set_hp(300, int(lv.model.boss.hp_max))
	await lv._wait(1.6)
	lv.model.over = true
	await defeat(lv)
	line(lv, "win")

static func refresh_hp(lv: Level) -> void:
	var h := hud(lv)
	if h: h.set_hp(lv.model.boss_hp(), int(lv.model.boss.hp_max))
	var gi := lv.model.goal_index("boss")
	if gi >= 0 and gi < lv.goal_boxes.size():
		lv.goal_boxes[gi].shown = lv.model.boss_hp()
		lv._render_goal(gi)
