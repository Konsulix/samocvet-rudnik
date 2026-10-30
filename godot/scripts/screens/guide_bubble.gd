class_name GuideBubble
extends Control
## The mine's guide talking (docs/onboarding.md, "проводник в сцене"): a slate card over his head with a tail down to
## him, following him as the mine scrolls; a touch anywhere closes it. The boss's pixel cloud is the enemy's voice; this
## one, in the drawn kit, is the friends'.

signal closed

## how it looks: "parchment" - an old parchment note drawn by GPT in the mine's own style (speech in the world, not
## a window; art/ui_kit/gen_bubble.sh, sheet A design 1); "paper" - a cream note drawn in code; "slate" - a thin
## see-through slate with his name; "card" - the kit's framed card. `-- bubble=<style>` picks one for a shot
static var style := "parchment"
const INK := Color("#2b2218")
const FELL := "res://assets/fonts/IMFellEnglish.ttf"
const PAPER := Color("#efe3c6")
const R := 10.0          # corner radius
const TAIL := 9.0        # half the tail's root

var view: MineView
var _card: PanelContainer
var _born := 0.0

## `view`'s guide says `text`
func _init(v: MineView, text: String) -> void:
	view = v
	for a in OS.get_cmdline_user_args():
		if a.begins_with("bubble="): style = a.substr(7)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_card = PanelContainer.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb: StyleBox = StyleBoxEmpty.new()
	if style == "card": sb = Kit.box("card", 0.0)
	if style == "parchment": sb = Kit.box("bubble", 0.0)
	# the parchment's torn rim takes a little more room
	var mx := {card = 16, parchment = 19}.get(style, 14) as int
	var my := {card = 11, parchment = 13}.get(style, 9) as int
	sb.content_margin_left = mx
	sb.content_margin_right = mx
	sb.content_margin_top = my
	sb.content_margin_bottom = my + 1
	_card.add_theme_stylebox_override("panel", sb)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 1)
	_card.add_child(col)
	if style == "slate":
		col.add_child(Kit.label("Old Miner", 11, UI.body_bold, Color(Kit.AMBER, 0.9)))
	var l: Label
	if style == "card":
		l = Kit.label(text, 16, UI.body_bold)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size = Vector2(250, 0)
	else:
		l = Kit.label(text, 15, UI.body_bold if style == "slate" else UI.body, INK if style in ["paper", "parchment"] else Kit.CREAM)
		# the parchment speaks in old print (IM Fell English, OFL), as if from an old book
		if style == "parchment":
			l.add_theme_font_override("font", load(FELL) as Font)
			l.add_theme_font_size_override("font_size", 17)
		l.custom_minimum_size = Vector2(220, 0)
		l.add_theme_constant_override("line_spacing", -2)
		# ink on a light note: no dark outline (kit labels have one to read over pictures; here it blotted the letters)
		if style in ["paper", "parchment"]: l.add_theme_constant_override("outline_size", 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.visible_ratio = 0.0
	col.add_child(l)
	add_child(_card)
	# what this node draws (the tail) goes over the note: the drawn tail covers the note's edge where they meet
	_card.show_behind_parent = style == "parchment"
	# the words come out as he says them
	var tw := create_tween()
	tw.tween_property(l, "visible_ratio", 1.0, clampf(text.length() / 45.0, 0.6, 2.4))

func _ready() -> void:
	_born = Time.get_ticks_msec() / 1000.0
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.25)

## his head on the screen
func _head() -> Vector2:
	return view.get_global_transform_with_canvas() * view.guide_head()

func _process(_dt: float) -> void:
	var vp := get_viewport_rect().size
	var h := _head()
	var cs := _card.size
	var x := clampf(h.x - cs.x / 2, 12.0, vp.x - cs.x - 12.0)
	var y := h.y - cs.y - 22.0
	# no room over him (at the very top): beside his feet instead
	if y < UI.safe_top() + 150.0: y = h.y + 70.0
	_card.position = Vector2(x, y)
	queue_redraw()

func _draw() -> void:
	# the tail from the card down to his head
	var h := _head()
	var r := Rect2(_card.position, _card.size)
	var below := r.position.y > h.y
	var bx := clampf(h.x, r.position.x + R + TAIL + 4.0, r.end.x - R - TAIL - 4.0)
	var tip := h + Vector2(0, 8 if below else -10)
	if style == "parchment":
		# the drawn tail laid over the note's bottom edge (its own top ink line cut off), so the outlines join; flipped
		# when he stands below
		var t := Kit.tex("bubble_tail")
		var ts := Vector2(t.get_width(), t.get_height()) / 3.0
		var x0 := clampf(h.x, r.position.x + 22.0, r.end.x - 22.0) - ts.x / 2
		if below:
			draw_set_transform(Vector2(x0, r.position.y + 2.3), 0.0, Vector2(1, -1))
		else:
			draw_set_transform(Vector2(x0, r.end.y - 2.3))
		draw_texture_rect(t, Rect2(Vector2.ZERO, ts), false)
		draw_set_transform_matrix(Transform2D.IDENTITY)
		return
	if style == "card":
		var by := r.position.y + 3.0 if below else r.end.y - 3.0
		var pts := PackedVector2Array([Vector2(bx - 10, by), Vector2(bx + 10, by), tip])
		draw_colored_polygon(pts, Color("#2a2f36"))
		draw_polyline(PackedVector2Array([Vector2(bx - 10, by), tip, Vector2(bx + 10, by)]), Color(Kit.AMBER, 0.85), 2.0, true)
		return
	var shape := _outline(r, bx, tip, below)
	if style == "paper":
		var shadow := shape.duplicate()
		for i in shadow.size(): shadow[i] += Vector2(2, 3)
		draw_colored_polygon(shadow, Color(0, 0, 0, 0.35))
		draw_colored_polygon(shape, PAPER)
		var loop := shape.duplicate()
		loop.append(shape[0])
		draw_polyline(loop, INK, 2.0, true)
	else:
		draw_colored_polygon(shape, Color("#161a20", 0.86))
		var loop := shape.duplicate()
		loop.append(shape[0])
		draw_polyline(loop, Color(Kit.AMBER, 0.75), 1.0, true)

## the note and its tail as one shape (so the outline runs round both): a rounded box, and on the side towards him
## a wedge whose sides bow, its point at his mouth
func _outline(r: Rect2, bx: float, tip: Vector2, below: bool) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var corners := [r.position + Vector2(R, R), Vector2(r.end.x - R, r.position.y + R), r.end - Vector2(R, R), Vector2(r.position.x + R, r.end.y - R)]
	# clockwise from the top-left corner; the tail goes in on the bottom edge (or the top one when he is above)
	for k in 4:
		var c: Vector2 = corners[k]
		var a0 := PI + k * PI / 2
		for j in 7:
			var a := a0 + j / 6.0 * PI / 2
			pts.append(c + Vector2(cos(a), sin(a)) * R)
		if k == 0 and below: _wedge(pts, Vector2(bx - TAIL, r.position.y), tip, Vector2(bx + TAIL, r.position.y))
		if k == 2 and not below: _wedge(pts, Vector2(bx + TAIL, r.end.y), tip, Vector2(bx - TAIL, r.end.y))
	return pts

func _wedge(pts: PackedVector2Array, a: Vector2, tip: Vector2, b: Vector2) -> void:
	# the bow: each side curves through a point pulled towards the tail's middle line
	var mid := (a + b) / 2
	for side in [[a, tip], [tip, b]]:
		var p0: Vector2 = side[0]
		var p1: Vector2 = side[1]
		var ctl := (p0 + p1) / 2 + ((mid + tip) / 2 - (p0 + p1) / 2) * 0.5
		for j in range(0 if p0 == a else 1, 7):
			var t := j / 6.0
			pts.append(p0.lerp(ctl, t).lerp(ctl.lerp(p1, t), t))

func _gui_input(e: InputEvent) -> void:
	var pressed: bool = (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed)
	# a moment first, so a touch that was already on its way does not close it unread
	if not pressed or Time.get_ticks_msec() / 1000.0 - _born < 0.5: return
	accept_event()
	set_process(false)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func():
		closed.emit()
		queue_free())
