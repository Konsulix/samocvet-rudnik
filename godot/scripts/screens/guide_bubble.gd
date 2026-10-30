class_name GuideBubble
extends Control
## The mine's guide talking (docs/onboarding.md, "проводник в сцене"): a slate card over his head with a tail down to
## him, following him as the mine scrolls; a touch anywhere closes it. The boss's pixel cloud is the enemy's voice; this
## one, in the drawn kit, is the friends'.

signal closed

var view: MineView
var _card: PanelContainer
var _born := 0.0

## `view`'s guide says `text`
func _init(v: MineView, text: String) -> void:
	view = v
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_card = PanelContainer.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := Kit.box("card", 0.0)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 11
	sb.content_margin_bottom = 12
	_card.add_theme_stylebox_override("panel", sb)
	var l := Kit.label(text, 16, UI.body_bold)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(250, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.visible_ratio = 0.0
	_card.add_child(l)
	add_child(_card)
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
	var bx := clampf(h.x, r.position.x + 24.0, r.end.x - 24.0)
	var by := r.position.y + 3.0 if below else r.end.y - 3.0
	var tip := h + Vector2(0, 8 if below else -8)
	var pts := PackedVector2Array([Vector2(bx - 10, by), Vector2(bx + 10, by), tip])
	draw_colored_polygon(pts, Color("#2a2f36"))
	draw_polyline(PackedVector2Array([Vector2(bx - 10, by), tip, Vector2(bx + 10, by)]), Color(Kit.AMBER, 0.85), 2.0, true)

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
