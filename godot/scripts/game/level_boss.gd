class_name LevelBoss
extends RefCounted
## The boss fight on the level screen. The rules are BoardModel's (boss_*); this shows them: the boss over the board
## (BossView: moods, line boil, hits, the defeat), its body as the board's frame (BossFrame), the dark fight interface
## (BossHud: name, moves, health on the frame, the bubble with its plan or its words), the cells it is about to hit
## outlined on the board (BoardView.marks), the next board dropping in when a third of its health is gone.

## what the boss's actions are called on screen
const ACTS := {coils = "Coils: timber on stones", rockfall = "Rockfall", breath = "Poison breath", hoard = "Hoard: heals on gold",
	lizards = "Lizards: steal the greens", crust = "Malachite crust", flower = "Stone flower: blooms and heals",
	tentacle = "Tentacle: grips stones", ink = "Ink: hides stones", tide = "Tide: floods the bottom",
	hammer = "Hammer: scales stones", bellows = "Bellows: heats billets", pour = "Molten sulphur",
	sigh = "Sigh: gas comes out", drift = "Drift: gas creeps to the bird", cough = "Cough: a burst of gas", knock = "Knock: rocks fall"}
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
static func sea(lv: Level) -> BossSea: return lv.get_node_or_null("BossSea") as BossSea

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
	# a boss whose pictures aren't made yet borrows the first one's (its baked whole frames don't fit other boards)
	var look := id if FileAccess.file_exists("res://assets/boss/%s/boss.json" % id) else "poloz"
	lv.bg.texture = load("res://assets/boss/%s/bg.png" % look)
	lv.bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var v := BossView.load_for(look)
	v.name = "BossView"
	lv.add_child(v)
	lv.move_child(v, lv.holder.get_index())
	# his frame isn't made yet either: the first boss' kit, built round his boards
	var flook := look if FileAccess.file_exists("res://assets/boss/%s/kit/kit.json" % look) else "poloz"
	var f := BossFrame.load_for(flook)
	f.kit_only = flook != id
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
	# the Kraken's sea over his bottom, and his arms
	if ResourceLoader.exists(v.dir + "arm_strip.png"):
		var s := BossSea.load_for(lv, v)
		s.name = "BossSea"
		lv.add_child(s)
		lv.move_child(s, v.get_index() + 1)
		s.set_board(int(lv.model.boss.stage))
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
	# Shubin: the balance scale over the board, the canary on it; his look follows the needle
	if lv.model.scale_on():
		BossShubin.mount(lv)
		lv.set_meta("shubin_mood", lv.model.shubin_mood())
		v.set_phase(lv.model.shubin_mood())
		v.set_rest("idle")

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
	v.position = Vector2(float(v.meta.get("x", BOSS_X)), roundf(top_line + _sink(v, int(lv.model.boss.stage)) - v.size.y))
	var s := sea(lv)
	if s:
		# no flat-cut bottom to hide: it goes on under his water
		v.set_exposed(PackedFloat32Array([0.0]), SINK_BAND)
		s.fit()
	elif v.below:
		# its body goes on below the picture: nothing to sink into the dark
		v.set_exposed(PackedFloat32Array([0.0]), SINK_BAND)
	else:
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
	# a head under his water (the Kraken, sunk on the early boards): the bubble points at the surface over it
	if s: h.bubble_target.y = minf(h.bubble_target.y, s.surface - 10.0)
	h.queue_redraw()

## which columns of the boss' picture have no bar of the frame under their bottom: beyond the board's sides and
## over a cut-away corner of its top. The frame's bar reaches a little past its cells; the edge is ramped softly
## how far the boss' bottom sits below the frame's top bar on board i: the Kraken rises out of his water board by
## board ("sinks" in its boss.json), the others sit at one depth ("sink")
static func _sink(v: BossView, i: int) -> float:
	var ss: Array = v.meta.get("sinks", [])
	return float(ss[clampi(i, 0, ss.size() - 1)]) if not ss.is_empty() else float(v.meta.get("sink", SINK))

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
	lv.board.bolt_marks = lv.model.bolt_cells()
	lv.board.hammer_over = Vector2(-1, -1)
	if it.act == "hammer" and left <= 1 and not (it.cells as Array).is_empty():
		var mid := Vector2.ZERO
		for p: Vector2i in it.cells: mid += Vector2(p)
		lv.board.hammer_over = mid / (it.cells as Array).size()
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
	if m.scale_on():
		await _shubin(lv)
		return
	if m.boss_stage_clear():
		await next_board(lv)
		return
	# the sea's own move (the Kraken's boards): the maelstrom turns, ink thins, the tide ebbs
	await _sea(lv)
	if m.boss_stage_clear():
		await next_board(lv)
		return
	# the forge's own (Brontes'): billets cool, sulphur runs, the thunderbolt charges or strikes
	await _forge(lv)
	if m.boss_stage_clear():
		await next_board(lv)
		return
	var acting := int(m.boss.timer) <= 1
	if acting and view(lv):
		view(lv).cast()
		await lv._wait(0.35)
	var res := m.boss_turn()
	if not res.is_empty() and not res.drag.is_empty():
		await _drag(lv, res)
	if not res.is_empty() and not res.get("taken", []).is_empty():
		await _take(lv, res)
	if not res.is_empty() and res.act in ["hammer", "bellows", "pour"]:
		await _forge_act(lv, res)
		if m.boss_stage_clear():
			await next_board(lv)
			return
	elif not res.is_empty() and res.act in ["tentacle", "ink", "tide"]:
		await _sea_act(lv, res)
	elif not res.is_empty() and res.act == "lizards":
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
	# Awards: Keep Your Greens / The Kindly Mistress count the greens taken
	lv.set_meta("aw_stolen", int(lv.get_meta("aw_stolen", 0)) + (res.removed as Array).size())
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

## the maelstrom carries the stones of its ring round a cell - along an arc round its water, turning a little - and
## sucks in a blue stone or a special beside it: down the spiral, shrinking; what falls in and lines up goes as usual
static func _sea(lv: Level) -> void:
	var m: BoardModel = lv.model
	var res := m.sea_turn()
	lv.board.sea_over.queue_redraw()
	await _eye_swim(lv)
	if res.turned.is_empty(): return
	var b := lv.board
	var mid := b.whirl_mid()
	var tw := lv.create_tween().set_parallel(true)
	var any := false
	for t: Array in res.turned:
		var n: GemNode = b.nodes.get(int(t[0]))
		if n == null: continue
		var to: Vector2i = t[2]
		var p0 := n.position - mid
		var p1 := b.cell_center(to.x, to.y) - mid
		var a0 := p0.angle()
		var a1 := a0 + wrapf(p1.angle() - a0, -PI, PI)
		tw.tween_method(func(k: float) -> void:
			n.position = mid + Vector2.from_angle(lerp_angle(a0, a1, k)) * lerpf(p0.length(), p1.length(), k)
			n.rotation = sin(k * PI) * 0.25, 0.0, 1.0, 0.42).set_trans(Tween.TRANS_SINE)
		any = true
	if not any:
		tw.kill()
		return
	sound(lv, "maelstrom")
	b.whirl_kick()
	await tw.finished
	if not res.sucked.is_empty():
		var sw := lv.create_tween().set_parallel(true)
		for s: Dictionary in res.sucked:
			var n: GemNode = b.nodes.get(int(s.id))
			if n == null: continue
			b.nodes.erase(int(s.id))
			var p0 := n.position - mid
			var a0 := p0.angle()
			sw.tween_method(func(k: float) -> void:
				var e := k * k
				n.position = mid + Vector2.from_angle(a0 + e * TAU * 1.25) * p0.length() * (1.0 - e)
				n.rotation = e * TAU * 1.5
				n.scale = Vector2.ONE * (1.0 - 0.85 * e)
				n.modulate.a = 1.0 - clampf((k - 0.7) / 0.3, 0.0, 1.0), 0.0, 1.0, 0.75)
			lv.get_tree().create_timer(0.8).timeout.connect(n.queue_free)
		sound(lv, "suck", "kr_maelstrom")
		b.whirl_kick()
		await sw.finished
		if not Save.told("maelstrom_suck"):
			Save.tell("maelstrom_suck")
			lv._toast("The maelstrom swallows blue stones and specials beside it")
		await b.animate_collapse(m.collapse())
	await lv._resolve([], [])

## his eye swims (the last board, every few moves): it sinks, comes up over four stones elsewhere - they go under -
## and the stones above its old place fall into it
static func _eye_swim(lv: Level) -> void:
	lv.eye_hits = 0
	var m: BoardModel = lv.model
	var b := lv.board
	var to := m.eye_spot()
	if to.x < 0: return
	sound(lv, "rise", "kr_rise")
	var tw := lv.create_tween()
	tw.tween_property(b, "eye_show", 0.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tw.finished
	var gone := m.eye_move(to)
	b.sea_under.queue_redraw()
	b.sea_over.queue_redraw()
	var sw := lv.create_tween().set_parallel(true)
	for id: int in gone:
		var n: GemNode = b.nodes.get(id)
		if n == null: continue
		b.nodes.erase(id)
		sw.tween_property(n, "scale", Vector2.ONE * 0.4, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		sw.tween_property(n, "modulate", Color(0.3, 0.6, 0.7, 0.0), 0.4)
		lv.get_tree().create_timer(0.45).timeout.connect(n.queue_free)
	sw.tween_property(b, "eye_show", 1.0, 0.55).set_delay(0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# the stones above its old place fall in while it comes up (waiting, the place stood a hole)
	await lv.get_tree().create_timer(0.25).timeout
	await b.animate_collapse(m.collapse())
	if sw.is_running(): await sw.finished
	await lv._resolve([], [])

## the tentacles left on the board drag the stones at their tips over the rim into the deep: he heals
static func _drag(lv: Level, res: Dictionary) -> void:
	var m: BoardModel = lv.model
	lv.board.marks = []
	sound(lv, "drag")
	lv.set_meta("aw_dragged", true)    # Awards: Hold Fast
	var tw := lv.create_tween().set_parallel(true)
	var any := false
	for d: Dictionary in res.drag:
		var n: GemNode = lv.board.nodes.get(int(d.id))
		if n == null: continue
		lv.board.nodes.erase(int(d.id))
		var root := lv.board.cell_center(int(d.r), int(d.c))
		for tn: Dictionary in m.tentacles:
			if int(tn.id) == int(d.tid): root = lv.board.tentacle_root(tn)
		tw.tween_property(n, "position", root, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.tween_property(n, "scale", Vector2(0.35, 0.35), 0.55)
		tw.tween_property(n, "modulate:a", 0.0, 0.35).set_delay(0.2)
		lv.get_tree().create_timer(0.6).timeout.connect(n.queue_free)
		lv.fx.debris(int(d.r), int(d.c), Color("#6a8a9a"), 8)
		any = true
	if any: await tw.finished
	else: tw.kill()
	refresh_hp(lv)
	var h := hud(lv)
	if h and int(res.heal): h.say("+%d" % int(res.heal), 1.6)
	if not lv.has_meta("drag_told"):
		lv.set_meta("drag_told", true)
		line(lv, "drag")
	lv.board.refresh()
	await lv.board.animate_collapse(m.collapse())
	await lv._resolve([], [])

## a tentacle reaches onto the board, ink spreads, the tide comes in
static func _sea_act(lv: Level, res: Dictionary) -> void:
	var m: BoardModel = lv.model
	lv.board.marks = []
	var now := Time.get_ticks_msec() / 1000.0
	match String(res.act):
		"tentacle":
			if res.has("tid"): lv.board.tent_at[int(res.tid)] = now
			var tw := lv.create_tween()
			for k in 4:
				tw.tween_property(lv.shaker, "position", Vector2(randf_range(-4, 4), randf_range(-3, 3)), 0.04)
			tw.tween_property(lv.shaker, "position", Vector2.ZERO, 0.05)
		"ink":
			for p: Vector2i in res.cells: lv.fx.debris(p.x, p.y, Color("#10141c"), 4)
		"tide":
			for p: Vector2i in res.cells: lv.fx.sparkle(p.x, p.y, Color("#9fd8ea"), 4)
	sound(lv, String(res.act), "rock")
	lv.board.refresh()
	await lv._wait(0.6)
	if not m.has_moves():
		m.shuffle()
		await lv.board.animate_shuffle()

## once per fight: a short word on a piece of his the first time it matters
static func tip(lv: Level, key: String, text: String) -> void:
	if lv.has_meta(key): return
	lv.set_meta(key, true)
	lv._toast(text)

## the forge's own move after the player's (Brontes' boards): billets cool a step, molten sulphur nobody touched runs
## onto a stone, the thunderbolt charges - full, it strikes its two columns
static func _forge(lv: Level) -> void:
	var m: BoardModel = lv.model
	if m.BIL.is_empty() or not m.boss.B.act.has("bellows"): return
	var res := m.forge_turn()
	var b := lv.board
	b.redraw_under()
	b.bolt_marks = m.bolt_cells()
	b.over.queue_redraw()
	if not res.ran.is_empty():
		b.sync(true)
		for p: Vector2i in res.ran:
			lv.fx.sparkle(p.x, p.y, Color(1.8, 1.0, 0.3), 10)
		sound(lv, "run", "gas")
		tip(lv, "run_told", "Molten sulphur runs on every move you leave it - break stones beside it")
		await lv._wait(0.3)
	if not res.bolt.is_empty():
		await _thunder(lv, res.bolt)
	elif not b.bolt_marks.is_empty():
		tip(lv, "bolt_told", "The thunderbolt is charged! Strike beside the anvil, or it hits the violet columns")

## the thunderbolt strikes: he hurls it down two columns, their stones fuse with scale, he heals
static func _thunder(lv: Level, res: Dictionary) -> void:
	var m: BoardModel = lv.model
	var v := view(lv)
	# the scale it leaves shows when it lands, not while he winds up
	for p: Vector2i in res.cells: m.LOCK[p.x][p.y] = 0
	lv.board.over.queue_redraw()
	if v: v.cast()
	line(lv, "bolt")
	await lv._wait(0.35)
	for p: Vector2i in res.cells: m.LOCK[p.x][p.y] = 6
	lv.board.bolt_flash_at = Time.get_ticks_msec() / 1000.0
	for c: int in res.cols:
		var r0 := 0
		var r1 := m.R - 1
		while r0 < m.R and not m.playable(r0, c): r0 += 1
		while r1 > 0 and not m.playable(r1, c): r1 -= 1
		lv.fx.thunder(c, r0, r1)
	sound(lv, "bolt", "boom")
	Sfx.buzz(80)
	lv.board.bolt_marks = []
	lv.board.over.queue_redraw()
	refresh_hp(lv)
	var h := hud(lv)
	if h and int(res.heal): h.say("+%d" % int(res.heal), 1.6)
	await lv._wait(0.7)
	if not m.has_moves():
		m.shuffle()
		await lv.board.animate_shuffle()

## he takes back the billets left to go cold: each flies up to him glowing, he heals; the stones above fall in
static func _take(lv: Level, res: Dictionary) -> void:
	var m: BoardModel = lv.model
	var v := view(lv)
	var to := lv.board.get_global_transform().affine_inverse() * (v.head_global() if v else Vector2(200, 0))
	var b := lv.board
	for p: Vector2i in res.taken:
		var n := Node2D.new()
		var from := b.cell_center(p.x, p.y)
		n.position = from
		var tx: Texture2D = b._forge_tex.get(1)
		n.draw.connect(func():
			if tx:
				var sz := Vector2(tx.get_size()) * b.TS / 37.0
				n.draw_texture_rect(tx, Rect2(-sz * 0.5, sz), false)
			else:
				n.draw_rect(Rect2(-12, -6, 24, 12), Color(0.4, 0.4, 0.45)))
		lv.fx.add_child(n)
		var tw := lv.create_tween().set_parallel(true)
		tw.tween_property(n, "position", to, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.tween_property(n, "scale", Vector2(0.5, 0.5), 0.6)
		tw.tween_property(n, "modulate:a", 0.0, 0.25).set_delay(0.4)
		tw.chain().tween_callback(n.queue_free)
		lv.fx.debris(p.x, p.y, Color("#4a4a52"), 6)
	b.redraw_under()
	sound(lv, "take", "rock")
	await lv._wait(0.6)
	refresh_hp(lv)
	var h := hud(lv)
	if h and int(res.heal): h.say("+%d" % int(res.heal), 1.6)
	if not lv.has_meta("take_told"):
		lv.set_meta("take_told", true)
		line(lv, "take")
	await lv.board.animate_collapse(m.collapse())
	await lv._resolve([], [])

## his hammer comes down (stones scale over, billets glow white again, the player's specials there go off), the bellows
## blow (billets glow white, new ones come in), molten sulphur pours from the top
static func _forge_act(lv: Level, res: Dictionary) -> void:
	var m: BoardModel = lv.model
	var b := lv.board
	b.marks = []
	var now := Time.get_ticks_msec() / 1000.0
	b.hammer_over = Vector2(-1, -1)
	match String(res.act):
		"hammer":
			if not res.cells.is_empty():
				var mid := Vector2.ZERO
				for p: Vector2i in res.cells: mid += Vector2(p)
				mid /= res.cells.size()
				lv.fx.flash(mid.x, mid.y, Color(2.2, 1.4, 0.6), 2.6)
				lv.fx.ring(mid.x, mid.y, 1.6, Color(2.0, 1.2, 0.5))
				lv.fx.shake = maxf(lv.fx.shake, 16.0)
				for p: Vector2i in res.cells:
					lv.fx.burst(b.cell_center(p.x, p.y), Color(2.2, 1.3, 0.4), 4, 260.0, 500.0, 3.0, true)
					lv.fx.debris(p.x, p.y, Color("#2a2522"), 4)
			for p: Vector2i in res.get("hot", []): b.bil_at[p.x * m.C + p.y] = now
			sound(lv, "hammer", "boom")
			Sfx.buzz(90)
			b.refresh()
			tip(lv, "scale_told", "Scale: a match beside it knocks it off. Leave a special under his hammer - it goes off for you")
			await lv._wait(0.45)
			if not res.blast.is_empty():
				line(lv, "hammer")
				await lv._resolve(res.blast.map(func(q: Vector2i) -> Dictionary: return {t = 0.0, r = q.x, c = q.y, kind = "fx"}), [])
		"bellows":
			for id in res.removed: b.remove_node(id)
			for r in m.R:
				for c in m.C:
					if m.BIL[r][c]: b.bil_at[r * m.C + c] = now
			for p: Vector2i in res.cells:
				lv.fx.flash(p.x, p.y, Color(2.4, 1.6, 0.6), 1.4)
				lv.fx.sparkle(p.x, p.y, Color(2.0, 1.3, 0.4), 12)
			sound(lv, "bellows", "rocket")
			b.refresh()
			if not lv.has_meta("billet_told"):
				lv.set_meta("billet_told", true)
				line(lv, "billet")
			tip(lv, "billet_tip", "Billets: break them while white-hot - the hotter, the harder he's hurt. Cold, he takes them back")
			await lv._wait(0.5)
		"pour":
			for id in res.removed: b.remove_node(id)
			for p: Vector2i in res.cells: lv.fx.sparkle(p.x, p.y, Color(1.8, 1.0, 0.3), 12)
			sound(lv, "pour", "gas")
			b.refresh()
			tip(lv, "pour_told", "Molten sulphur: a match beside it cools it off")
			await lv._wait(0.5)
	if not m.has_moves():
		m.shuffle()
		await b.animate_shuffle()

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
	lv.board.hammer_over = Vector2(-1, -1)
	lv.board.rebuild(m)
	lv._render_hud()
	if v:
		var was := v.position.y
		place(lv)
		# the Kraken rises from his water to the new board's height, with a burst of spray
		if sea(lv) and absf(v.position.y - was) > 1.0:
			var to := v.position.y
			v.position.y = was
			sea(lv).splash()
			if int(m.boss.stage) == 1: sea(lv).gulls_off(Vector2(v.position.x, was))
			lv.create_tween().tween_property(v, "position:y", to, 1.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			sound(lv, "rise", "rockfall")
		title(lv)
		moves(lv)
		refresh_hp(lv)
		v.set_phase(int(m.boss.stage))
		v.set_rest("rage" if int(m.boss.stage) >= 2 else "idle")
	if sea(lv): sea(lv).set_board(int(m.boss.stage))
	await lv.board.drop_in()
	lv._toast(String(m.boss.B.stages[m.boss.stage].name))
	show_intent(lv)

## its health is gone: no more plans; it screams, falls and lies in the dust before the win
static func defeat(lv: Level) -> void:
	var v := view(lv)
	if not v: return
	lv.board.marks = []
	lv.board.bolt_marks = []
	lv.board.hammer_over = Vector2(-1, -1)
	lv.board.over.queue_redraw()
	var h := hud(lv)
	h.clear_intent()
	if lv.model.scale_on():
		# the song outweighs the gas: the canary sings him its lullaby, he yawns and falls asleep
		BossShubin.lullaby(lv)
		sound(lv, "song")
		line(lv, "win")
	else:
		h.set_hp(0, int(lv.model.boss.hp_max))
	frame(lv).swaying = false
	# its theme dies with it, gone before the win jingle
	Sfx.music_fade(3.5)
	if sea(lv):
		get_tree_timer(lv, 1.1, sea(lv).drown)
		get_tree_timer(lv, 1.2, func(): sound(lv, "drown"))
	await v.defeat()

# ---------------------------------------------------------------- Shubin

## his mood follows the scale's needle: a new look (a dissolve) and a word when it changes
static func _mood(lv: Level) -> void:
	var m: BoardModel = lv.model
	var md := m.shubin_mood()
	var was := int(lv.get_meta("shubin_mood", 0))
	if md == was: return
	lv.set_meta("shubin_mood", md)
	var v := view(lv)
	if v: v.set_phase(md)
	if md > was:
		line(lv, "stir" if md == 1 else "cough")
		sound(lv, "cough")
	else:
		line(lv, "sleep")

## after the player's move: the canary sings (a note into its pan) or is silent; asleep - the level wins; his act
## (gas out of the marked stones, the gas creeping towards the bird, rocks off the roof); then what falls and matches
static func _shubin(lv: Level) -> void:
	var m: BoardModel = lv.model
	var v := view(lv)
	var res := m.song_turn()
	BossShubin.sang(lv, res)
	# he feels the air: much gas cleared - he sinks deeper (eyes shut, a snore); the bird silenced - he frowns, stirs
	var cleared := int(lv.get_meta("shubin_gas", m.gas_count())) - m.gas_count()
	if v and cleared >= 2: v.show_for("blink", 1.4)
	elif v and not bool(res.sang): v.show_for("hurt", 1.0)
	if not bool(res.sang) and lv.get_meta("shubin_sang", true): sound(lv, "cheep")
	lv.set_meta("shubin_sang", bool(res.sang))
	_mood(lv)
	if m.goals_done(): return
	var acting := int(m.boss.timer) <= 1
	if acting and v:
		v.cast()
		await lv._wait(0.35)
	var r := m.boss_turn()
	if not r.is_empty():
		var b := lv.board
		b.marks = []
		for id in r.removed: b.remove_node(id)
		b.redraw_under()
		b.over.queue_redraw()
		match String(r.act):
			"sigh", "cough", "drift":
				for p: Vector2i in r.cells: lv.fx.sparkle(p.x, p.y, Color("#a8d890"), 12)
				BossShubin.gas_out(lv, r.cells)
				sound(lv, "cough" if r.act == "cough" else "sigh")
				if r.act == "cough":
					var tw := lv.create_tween()
					for k in 4:
						tw.tween_property(lv.shaker, "position", Vector2(randf_range(-4, 4), randf_range(-3, 3)), 0.04)
					tw.tween_property(lv.shaker, "position", Vector2.ZERO, 0.05)
					tip(lv, "cough_told", "He coughs gas right by the cage - clear it before the bird falls silent")
				elif r.act == "drift":
					tip(lv, "drift_told", "The gas creeps towards the canary's song - keep the air round the cage clear")
				else:
					tip(lv, "sigh_told", "Every cloud of gas weighs on the scale. Match beside it to clear it")
			"knock":
				for p: Vector2i in r.cells: lv.fx.debris(p.x, p.y, Color("#3a3430"), 10)
				lv.fx.shake = maxf(lv.fx.shake, 10.0)
				sound(lv, "knock")
		b.refresh()
		await lv._wait(0.35)
		await b.animate_collapse(m.collapse())
		await lv._resolve([], [])
		if not m.has_moves():
			m.shuffle()
			await b.animate_shuffle()
	BossShubin.update_bird(lv)
	_mood(lv)
	lv.set_meta("shubin_gas", m.gas_count())
	show_intent(lv)

## the gas outweighed the song: he wakes, the canary falls from its perch onto its back. The fight is lost
static func shubin_lost(lv: Level) -> void:
	var v := view(lv)
	lv.board.marks = []
	lv.board.over.queue_redraw()
	hud(lv).clear_intent()
	BossShubin.fall(lv)
	sound(lv, "cheep")
	await lv._wait(1.2)
	if v:
		v.set_phase(2)
		v.set_rest("rage")
	sound(lv, "wake")
	lv.fx.shake = maxf(lv.fx.shake, 14.0)
	line(lv, "lose")
	await lv._wait(2.4)

## fresh air bought after the canary fell: the gas is blown out of the mine (all but a few far clouds), the bird
## comes round and gets back on its perch, he sinks back into his doze
static func shubin_revive(lv: Level) -> void:
	var m: BoardModel = lv.model
	var gas := []
	for r in m.R:
		for c in m.C:
			if m.GAS[r][c]: gas.append(Vector2i(r, c))
	gas.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return m.cage_dist(a.x, a.y) < m.cage_dist(b.x, b.y))
	for i in maxi(0, gas.size() - 2):
		var p: Vector2i = gas[i]
		m.GAS[p.x][p.y] = 0
		lv.fx.sparkle(p.x, p.y, Color("#dff4ff"), 10)
	m.boss.song.notes = maxi(int(m.boss.song.notes), int(m.boss.B.scale.get("start", 4)))
	m.scale_goal()
	m.over = false
	lv.board.redraw_under()
	await lv.board.animate_collapse(m.collapse())
	await lv._resolve([], [])
	var c := BossShubin.cage_of(lv)
	if c: c.set_state("sing")
	sound(lv, "song")
	var v := view(lv)
	lv.set_meta("shubin_mood", m.shubin_mood())
	if v:
		v.set_rest("idle")
		v.set_phase(m.shubin_mood())
	line(lv, "sleep")
	m.boss_plan()
	show_intent(lv)

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
