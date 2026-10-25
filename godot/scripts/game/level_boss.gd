class_name LevelBoss
extends RefCounted
## The boss fight on the level screen, for now in plain words: its health in the goals plate, what it will do
## next (and where) in the hint line, its lines as toasts, the cells it is about to hit outlined on the board,
## the next board dropping in when a third of its health is gone. The rules are BoardModel's (boss_*);
## the fight's own look (the boss, its frame, the speech bubble) comes later and hooks onto these same calls.

## what the boss's actions are called on screen
const ACTS := {coils = "Coils: timber on stones", rockfall = "Rockfall", breath = "Poison breath", hoard = "Hoard: heals on gold"}

static func line(lv: Level, key: String, i := -1) -> void:
	var L: Dictionary = lv.model.boss.B.lines
	var t = L.get(key, "")
	if t is Array: t = t[clampi(i, 0, t.size() - 1)]
	if String(t) != "":
		lv._toast("%s: “%s”" % [lv.model.boss.B.n, t])

## the start: its words, its first plan
static func start(lv: Level) -> void:
	line(lv, "start")
	show_intent(lv)

## the hint line: the next action and how many moves until it; its cells outlined on the last move before it
static func show_intent(lv: Level) -> void:
	var b: Dictionary = lv.model.boss
	var it: Dictionary = b.intent
	var left: int = int(b.timer)
	lv.hint_label.text = "%s · %s in %d %s" % [b.B.n, ACTS.get(it.act, it.act), left, "move" if left == 1 else "moves"]
	lv.board.marks = it.cells if left <= 1 else []
	lv.board.over.queue_redraw()

## after the player's move: a cleared board makes way for the next; then the boss takes its turn
static func after_turn(lv: Level) -> void:
	var m: BoardModel = lv.model
	if m.boss_stage_clear():
		await next_board(lv)
		return
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
			lv._toast("The hoard feeds it: +%d" % int(res.heal) if res.heal else "Nothing left to feed on")
			refresh_hp(lv)
		await lv._wait(0.35)
		if not m.has_moves():
			m.shuffle()
			await lv.board.animate_shuffle()
	show_intent(lv)

## a third of its health gone: its words, then the next board falls in with the moves carried over
static func next_board(lv: Level) -> void:
	var m: BoardModel = lv.model
	line(lv, "stage", int(m.boss.stage))
	await lv._wait(0.6)
	m.next_stage()
	lv.board.marks = []
	lv.board.rebuild(m)
	lv._render_hud()
	await lv.board.drop_in()
	lv._toast(String(m.boss.B.stages[m.boss.stage].name))
	show_intent(lv)

static func refresh_hp(lv: Level) -> void:
	var gi := lv.model.goal_index("boss")
	if gi >= 0:
		lv.goal_boxes[gi].shown = lv.model.boss_hp()
		lv._render_goal(gi)
