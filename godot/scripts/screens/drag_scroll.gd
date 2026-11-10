class_name DragScroll
extends ScrollContainer
## A scroll list that moves under the finger from anywhere on it, not only from the gaps between its rows: the
## cards, rows and plates in it are buttons that take the touch for themselves, so the stock ScrollContainer got it
## only on the bare background. The press is watched before the interface sees it (_input); once the finger has
## travelled DEAD points along the list's axis it is a drag: the list follows, the button under the finger is let
## go without firing, and the list coasts on when released. A touch that does not travel is an ordinary tap.

const DEAD := 10.0        # points the finger travels before it is a drag, not a tap
const FRICTION := 5.0     # how fast the coast dies away (per second)

var _down := false
var _drag := false
var _from := Vector2.ZERO
var _start := 0.0
var _last := Vector2.ZERO
var _vel := 0.0
var _releasing := false

func _horiz() -> bool:
	return vertical_scroll_mode == SCROLL_MODE_DISABLED

func _axis(v: Vector2) -> float:
	return v.x if _horiz() else v.y

func _scroll_now() -> float:
	return float(scroll_horizontal if _horiz() else scroll_vertical)

func _set_scroll(v: float) -> void:
	if _horiz(): scroll_horizontal = int(round(v))
	else: scroll_vertical = int(round(v))

func _input(e: InputEvent) -> void:
	if _releasing or not is_visible_in_tree(): return
	# the touch comes as emulated mouse events too: those are the ones followed (one stream, no double scrolling)
	if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := e as InputEventMouseButton
		if mb.pressed:
			_down = get_global_rect().has_point(mb.position) and _on_top(mb.position)
			_drag = false
			_from = mb.position
			_last = mb.position
			_start = _scroll_now()
			_vel = 0.0
		elif _down:
			_down = false
			if _drag:
				_drag = false
				get_viewport().set_input_as_handled()
	elif e is InputEventMouseMotion and _down:
		var p := (e as InputEventMouseMotion).position
		var d := p - _from
		if not _drag:
			if absf(_axis(d)) < DEAD:
				# a sideways swipe belongs to a list across this one (or to nothing): let it go
				if absf(_axis(Vector2(d.y, d.x))) >= DEAD: _down = false
				return
			_drag = true
			_cancel_press()
		var step := _axis(p - _last)
		_last = p
		var dt := maxf(get_process_delta_time(), 1.0 / 120.0)
		_vel = lerpf(_vel, -step / dt, 0.5)
		_set_scroll(_start - _axis(d))
		get_viewport().set_input_as_handled()
	elif _drag and (e is InputEventScreenDrag or e is InputEventScreenTouch):
		# the same touch as raw screen events: the stock scrolling must not move the list a second time
		get_viewport().set_input_as_handled()

## the button under the finger is let go away from it, so it does not fire
func _cancel_press() -> void:
	var off := InputEventMouseButton.new()
	off.button_index = MOUSE_BUTTON_LEFT
	off.pressed = false
	off.position = Vector2(-10000, -10000)
	off.global_position = off.position
	_releasing = true
	get_viewport().push_input(off)
	_releasing = false

## the press is ours only if no window is open over the list (a list inside the window itself is fine)
func _on_top(_p: Vector2) -> bool:
	return not Ov.is_open() or Ov.root.is_ancestor_of(self)

func _process(dt: float) -> void:
	if _down or absf(_vel) < 5.0:
		_vel = 0.0
		return
	var was := _scroll_now()
	_set_scroll(was + _vel * dt)
	if _scroll_now() == was: _vel = 0.0   # came to an end of the list
	_vel *= exp(-FRICTION * dt)
