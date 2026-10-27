class_name BossHud
extends Control
## The fight's own interface over the level's: dark slate with the mine's gold, as on the mock-up (art/boss/layout.py).
## The top bar (close · the boss' name and title · moves), its health on the frame's top bar with the phase marks,
## and the bubble by its head: what it does next and in how many moves, or what it says.

const INK := Color8(240, 228, 205)
const SUB := Color8(190, 160, 110)
const SLATE := Color8(30, 26, 23)
const METAL := Color8(201, 160, 74)
const METAL_D := Color8(110, 84, 36)
const BAR := 48.0

var lv: Level
var name_label: Label
var sub_label: Label
var moves_label: Label
var hp := [1, 1]             # left, max
var hp_rect := Rect2()
var bubble: Control
var bubble_target := Vector2.ZERO
var intent := {}             # {act, left}
var speech := ""
var _speech_until := 0.0
var _t := 0.0
var _icons := {}             # the actions' signs, loaded up front: a texture first drawn the frame it loads shows white

## a slate plate trimmed with the mine's metal
static func plate(radius := 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = SLATE
	s.border_color = METAL
	s.set_border_width_all(2)
	s.set_corner_radius_all(radius)
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size = 6
	s.shadow_offset = Vector2(0, 3)
	s.set_content_margin_all(4)
	return s

func _init(level: Level) -> void:
	lv = level
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	var vp := lv.get_viewport_rect().size
	var y0 := UI.safe_top() + 2.0
	# the controls are the drawn kit's, as everywhere else (the frame, the bubble and the health bar stay the boss' own)
	var close := Kit.icon_button("close", BAR)
	close.position = Vector2(10, y0)
	close.size = Vector2(BAR, BAR)
	close.pressed.connect(lv._on_quit)
	add_child(close)
	# the boss' name over its title and depth, on the kit's title plate
	var title := PanelContainer.new()
	title.add_theme_stylebox_override("panel", Kit.box("title", 0.0))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.position = Vector2(66, y0)
	title.size = Vector2(vp.x - 66 - 84, BAR)
	var tv := VBoxContainer.new()
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	tv.add_theme_constant_override("separation", -4)
	name_label = Kit.label("", 18, UI.display, Kit.CREAM)
	sub_label = Kit.label("", 11, UI.body_bold, Kit.AMBER)
	for l: Label in [name_label, sub_label]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.clip_text = true
		tv.add_child(l)
	title.add_child(tv)
	add_child(title)
	# moves: the kit's brass-ringed token, as on the level's bar
	var mv := Control.new()
	mv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mv.position = Vector2(vp.x - 74, y0 - 4)
	mv.size = Vector2(64, 64)
	var ring := Kit.tex("ring")
	mv.draw.connect(func():
		mv.draw_circle(mv.size / 2 + Vector2(2, 3), 32, Color(0, 0, 0, 0.3), true, -1.0, true)
		mv.draw_texture_rect(ring, Rect2(Vector2.ZERO, mv.size), false))
	var mvv := VBoxContainer.new()
	mvv.set_anchors_preset(Control.PRESET_FULL_RECT)
	mvv.alignment = BoxContainer.ALIGNMENT_CENTER
	mvv.add_theme_constant_override("separation", -7)
	mvv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ml := Kit.label("MOVES", 8, UI.body_bold, Kit.DIM)
	moves_label = Kit.label("0", 23, UI.display, Kit.AMBER)
	for l: Label in [ml, moves_label]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mvv.add_child(l)
	mv.add_child(mvv)
	add_child(mv)
	# the bubble draws itself (intent or words)
	bubble = Control.new()
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.material = BoardSprites.plain_material()
	bubble.draw.connect(_draw_bubble)
	add_child(bubble)
	_icons = {coils = BoardSprites.tex("lock"), rockfall = BoardSprites.blocker(BoardSprites.granite()),
		breath = load("res://assets/board/pieces/gas.png"), crust = BoardSprites.malachite("crust_0"),
		flower = BoardSprites.flower("flower_s3")}
	if ResourceLoader.exists("res://assets/boss/mistress/lizard_0.png"):
		_icons.lizards = load("res://assets/boss/mistress/lizard_0.png")

func bar_bottom() -> float:
	return UI.safe_top() + 2.0 + BAR

func set_title(n: String, sub: String) -> void:
	name_label.text = n
	sub_label.text = sub

func set_moves(n: int) -> void:
	moves_label.text = str(n)
	moves_label.add_theme_color_override("font_color", Color("#ff5a4a") if n <= 5 else Kit.AMBER)

func set_hp(left: int, mx: int) -> void:
	hp = [left, mx]
	queue_redraw()

func set_intent(act: String, left: int) -> void:
	intent = {act = act, left = left}
	bubble.queue_redraw()

func clear_intent() -> void:
	intent = {}
	bubble.queue_redraw()

## its words in the bubble for a while; the plan comes back after
func say(text: String, sec := 2.8) -> void:
	speech = text
	_speech_until = _t + sec
	bubble.queue_redraw()

func _process(dt: float) -> void:
	_t += dt
	if speech != "" and _t >= _speech_until:
		speech = ""
		bubble.queue_redraw()

# ---------------------------------------------------------------- health on the frame

func _draw() -> void:
	if hp_rect.size.x <= 0: return
	var r := hp_rect
	draw_style_box(plate(9), r)
	var inner := r.grow(-5)
	draw_rect(inner, Color8(40, 12, 10))
	var f := clampf(float(hp[0]) / maxf(1.0, float(hp[1])), 0.0, 1.0)
	if f > 0.0:
		var fill := Rect2(inner.position, Vector2(inner.size.x * f, inner.size.y))
		draw_rect(fill, Color8(150, 26, 24))
		draw_rect(Rect2(fill.position, Vector2(fill.size.x, 3)), Color8(214, 58, 46))
	for p: float in [1.0 / 3.0, 2.0 / 3.0]:
		var x := inner.position.x + inner.size.x * p
		draw_colored_polygon(PackedVector2Array([Vector2(x - 4, r.position.y - 1), Vector2(x + 4, r.position.y - 1), Vector2(x, r.position.y + 6)]), METAL)
		draw_line(Vector2(x, inner.position.y), Vector2(x, inner.end.y), Color8(60, 10, 10), 1.0)
	var txt := "%d / %d" % hp
	var fs := 10
	var w := UI.display.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(UI.display, Vector2(r.get_center().x - w / 2, r.get_center().y + 4), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color8(255, 238, 225))

# ---------------------------------------------------------------- the bubble

## the bubble: one shape for everything, its corner and tail fixed by the head, growing only downwards.
## Its words on top (each sentence on a line of its own, long ones wrapped), its plan in a row underneath.
const BUBBLE_W := 168.0
const BUBBLE_PAD := 10.0
const LINE_H := 16.0
const SAY_FS := 12
const PLAN_H := 46.0
const ACT_NAMES := {coils = ["Coils", "locks stones"], rockfall = ["Rockfall", "drops rock"],
	breath = ["Breath", "spreads gas"], hoard = ["Hoard", "heals on gold"], lizards = ["Lizards", "steal greens"],
	crust = ["Crust", "locks stones"], flower = ["Flower", "blooms: heals"]}

func bubble_rect() -> Rect2:
	var vp := lv.get_viewport_rect().size
	var lines := _lines(speech)
	var h := 0.0
	if not lines.is_empty(): h += BUBBLE_PAD + lines.size() * LINE_H + 4.0
	if not intent.is_empty(): h += PLAN_H
	return Rect2(vp.x - 10.0 - BUBBLE_W, bar_bottom() + 14.0, BUBBLE_W, maxf(h, PLAN_H))

func _lines(text: String) -> PackedStringArray:
	var out := PackedStringArray()
	if text == "": return out
	# a sentence per line: break after . ! ? … followed by a space
	var sentences := PackedStringArray()
	var cur := ""
	for i in text.length():
		cur += text[i]
		if text[i] in [".", "!", "?", "…"] and i + 1 < text.length() and text[i + 1] == " ":
			sentences.append(cur.strip_edges())
			cur = ""
	if cur.strip_edges() != "": sentences.append(cur.strip_edges())
	for snt in sentences:
		out.append_array(_balanced(snt, BUBBLE_W - BUBBLE_PAD * 2.0, SAY_FS))
	return out

func _draw_bubble() -> void:
	if speech == "" and intent.is_empty(): return
	var r := bubble_rect()
	bubble.draw_style_box(plate(14), r)
	# the tail: out of the left side at a fixed height, pointing at its head; over the plate's rim, gold-edged
	var base := Vector2(r.position.x + 1, r.position.y + 24)
	var dir := (bubble_target - base).normalized()
	if dir.x > -0.3: dir = Vector2(-1, 0.4).normalized()
	var tip := base + dir * 15.0
	var t0 := base + Vector2(0, -8)
	var t1 := base + Vector2(0, 8)
	bubble.draw_colored_polygon(PackedVector2Array([t0, tip, t1]), SLATE)
	bubble.draw_polyline(PackedVector2Array([t0, tip, t1]), METAL, 2.0, true)
	var y := r.position.y
	var lines := _lines(speech)
	if not lines.is_empty():
		for i in lines.size():
			bubble.draw_string(UI.body_bold, Vector2(r.position.x + BUBBLE_PAD, y + BUBBLE_PAD + 12 + i * LINE_H), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, SAY_FS, INK)
		y += BUBBLE_PAD + lines.size() * LINE_H + 4.0
		if not intent.is_empty():
			bubble.draw_line(Vector2(r.position.x + 10, y), Vector2(r.end.x - 10, y), Color(METAL, 0.35), 1.0)
	if intent.is_empty(): return
	# the plan: its sign, what it is, the moves left
	var cy := y + PLAN_H * 0.5
	var ic := Vector2(r.position.x + BUBBLE_PAD + 15, cy)
	_draw_act(String(intent.act), ic)
	var nm: Array = ACT_NAMES.get(intent.act, [String(intent.act), ""])
	var tx := ic.x + 24
	bubble.draw_string(UI.display, Vector2(tx, cy - 1), String(nm[0]), HORIZONTAL_ALIGNMENT_LEFT, r.end.x - 50 - tx, 13, INK)
	bubble.draw_string(UI.body_bold, Vector2(tx, cy + 13), String(nm[1]), HORIZONTAL_ALIGNMENT_LEFT, r.end.x - 50 - tx, 9, SUB)
	var cc := Vector2(r.end.x - 25, cy)
	bubble.draw_circle(cc, 17, METAL, true, -1.0, true)
	bubble.draw_circle(cc, 15, Color8(16, 14, 12), true, -1.0, true)
	var n := str(int(intent.left))
	var nw := UI.display.get_string_size(n, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
	bubble.draw_string(UI.display, Vector2(cc.x - nw / 2, cc.y + 7), n, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("#ff7a5a") if int(intent.left) <= 1 else INK)

## the action's sign: the board's own pieces where it has them
func _draw_act(act: String, c: Vector2) -> void:
	var t: Texture2D = _icons.get(act)
	if t:
		bubble.draw_texture_rect(t, Rect2(c - Vector2(15, 15), Vector2(30, 30)), false)
		return
	# the hoard: three gold ingots
	for o in [Vector2(-9, 6), Vector2(9, 6), Vector2(0, -4)]:
		var p: Vector2 = c + o
		bubble.draw_colored_polygon(PackedVector2Array([p + Vector2(-8, 5), p + Vector2(8, 5), p + Vector2(5, -5), p + Vector2(-5, -5)]), Color8(232, 182, 64))
		bubble.draw_polyline(PackedVector2Array([p + Vector2(-8, 5), p + Vector2(8, 5), p + Vector2(5, -5), p + Vector2(-5, -5), p + Vector2(-8, 5)]), Color8(90, 60, 15), 1.0)
		bubble.draw_line(p + Vector2(-3, -3), p + Vector2(3, -3), Color8(255, 236, 160), 1.0)

## a sentence on as few lines as fit, their lengths evened out (no lone word left on the last line)
func _balanced(text: String, w: float, fs: int) -> PackedStringArray:
	var greedy := _wrap(text, w, fs)
	if greedy.size() != 2: return greedy
	var words := text.split(" ")
	var best := greedy
	var best_w := INF
	for i in range(1, words.size()):
		var a := " ".join(words.slice(0, i))
		var b := " ".join(words.slice(i))
		var wa := UI.body_bold.get_string_size(a, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var wb := UI.body_bold.get_string_size(b, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		if wa <= w and wb <= w and maxf(wa, wb) < best_w:
			best_w = maxf(wa, wb)
			best = PackedStringArray([a, b])
	return best

func _wrap(text: String, w: float, fs: int) -> PackedStringArray:
	var out := PackedStringArray()
	var cur := ""
	for word in text.split(" "):
		var t := word if cur == "" else cur + " " + word
		if UI.body_bold.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > w and cur != "":
			out.append(cur)
			cur = word
		else:
			cur = t
	if cur != "": out.append(cur)
	return out
