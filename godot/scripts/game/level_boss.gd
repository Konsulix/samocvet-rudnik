class_name LevelBoss
extends RefCounted
## The boss fight on the level screen. The rules are BoardModel's (boss_*); this shows them: the boss over the board
## (BossView: moods, line boil, hits, the defeat), its body as the board's frame (BossFrame), the dark fight interface
## (BossHud: name, moves, health on the frame, the bubble with its plan or its words), the cells it is about to hit
## outlined on the board (BoardView.marks), the next board dropping in when a third of its health is gone.

## what the boss's actions are called on screen
const ACTS := {coils = "Coils: timber on stones", rockfall = "Rockfall", breath = "Poison breath", hoard = "Hoard: heals on gold"}
## the stage over the board, pt; how far the boss' bottom tucks behind the frame; its sprite's left edge
const STAGE := 190.0
const SINK := 26.0
const BOSS_X := -8.0
## a hit this strong, or this much in one move, makes it flinch
const BIG_HIT := 25
const BIG_TURN := 80

static var _turn_dmg := 0

static func view(lv: Level) -> BossView: return lv.get_node_or_null("BossView") as BossView
static func frame(lv: Level) -> BossFrame: return lv.shaker.get_node_or_null("BossFrame") as BossFrame
static func hud(lv: Level) -> BossHud: return lv.hud.get_node_or_null("BossHud") as BossHud

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
	var bottom := 96.0 + UI.safe_bottom()
	lv.board.layout(Vector2(vp.x - 12, vp.y - top - bottom))
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
	v.set_rest("rage" if int(lv.model.boss.stage) >= 2 else "idle")

## put the boss, the frame and the health bar where the board is now
static func place(lv: Level) -> void:
	var b := lv.board
	var grid := Vector2(b.PAD, b.PAD)
	var f := frame(lv)
	f.use_stage(int(lv.model.boss.stage))
	f.fit(lv.model.playable, grid, b.TS)
	var top_line := lv.holder.position.y + f.top_line()
	var v := view(lv)
	v.position = Vector2(BOSS_X, roundf(top_line + SINK - v.size.y))
	var h := hud(lv)
	var gx := lv.holder.position.x + b.PAD
	# inset by a cell and a bit: the quartz on the frame's top corners stays in sight
	# on the top run of the frame: the board's first row, from its first cell to its last, its corners left in sight
	var m := lv.model
	var r0 := 0
	while r0 < BoardModel.R - 1 and range(BoardModel.C).all(func(c: int) -> bool: return not m.playable(r0, c)): r0 += 1
	var cs := range(BoardModel.C).filter(func(c: int) -> bool: return m.playable(r0, c))
	var inset := b.TS * (1.25 if cs.size() >= 6 else 0.45)
	var x0: float = gx + float(cs[0]) * b.TS + inset
	var x1: float = gx + float(cs[-1] + 1) * b.TS - inset
	h.hp_rect = Rect2(roundf(x0), roundf(top_line + r0 * b.TS - 10), roundf(x1 - x0), 20)
	h.bubble_target = v.head_global()
	h.queue_redraw()

static func title(lv: Level) -> void:
	var B: Dictionary = lv.model.boss.B
	hud(lv).set_title(String(B.n), "%s · %d m · board %d/3" % [String(B.get("sub", "")), int(B.m), int(lv.model.boss.stage) + 1])

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
	if not res.is_empty():
		for id in res.removed: lv.board.remove_node(id)
		lv.board.redraw_under()
		lv.board.over.queue_redraw()
		for p: Vector2i in res.cells:
			lv.fx.debris(p.x, p.y, Color("#b07a3e"), 8)
		var tw := lv.create_tween()
		for k in 4:
			tw.tween_property(lv.shaker, "position", Vector2(randf_range(-5, 5), randf_range(-4, 4)), 0.04)
		tw.tween_property(lv.shaker, "position", Vector2.ZERO, 0.05)
		Sfx.play("rock")
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

## a third of its health gone: it screams, its words, then the next board falls in with the moves carried over
static func next_board(lv: Level) -> void:
	var m: BoardModel = lv.model
	var v := view(lv)
	if v: v.lose_phase()
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
