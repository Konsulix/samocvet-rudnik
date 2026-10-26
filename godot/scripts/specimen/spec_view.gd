class_name SpecView
extends Control
## A live 3D specimen on screen: it drifts and turns by itself, answers the finger,
## and when let go keeps spinning, slowing back to a drift. Machines keep their parts moving.
## Two fingers pinch to look closer (the mouse wheel on a desktop); a double tap jumps in and back out.
## The studio renders at real screen pixels (not the 390-wide layout units the UI is laid out in),
## so on a 3x phone the stone is not blown up from a small picture and does not shimmer as it turns.

signal built(p: Node3D)   # the specimen is on screen (its meta "grown": what really grew on it)
signal tapped             # a short touch that neither turned nor zoomed the stone

const MAX_PX := 800   # longest side of the render, to keep the phone cool
const FPS := 60.0      # a slow-turning stone needs no more; on a 120 Hz iPhone this halves the work

var studio: SpecStudio
var live: Node3D
var _img: TextureRect
var spin_v := 0.45
var tilt := 0.0
var still := false     # a fixed three-quarter pose, as in thumbnails
var _drag := false
var _t := 0.0
var _req := 0
var zoomable := true
const ZOOM_MAX := 3.0
var _zoom := 1.0       # shown
var _zoom_to := 1.0    # wanted
var _fov0 := 28.0
var _touch := {}       # finger index -> position, for the pinch
var _pinch0 := 0.0
var _pinch_zoom := 1.0
var _since := 0.0
var hold := false      # callouts are open: the stone stops drifting round (a finger still turns it)
var _press := Vector2.ZERO
var _press_ms := -1
var _tap_ms := 0

func _init(px := 512, transparent := false) -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	studio = SpecStudio.make(px, Viewport.MSAA_4X, transparent)
	studio.vp.render_target_update_mode = SubViewport.UPDATE_DISABLED   # rendered from _process, at FPS
	add_child(studio.vp)
	_img = TextureRect.new()
	_img.texture = studio.vp.get_texture()
	_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_img.stretch_mode = TextureRect.STRETCH_SCALE
	_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_img.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_img)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_ENTER_TREE:
		_fit()

## size the render to the view's footprint in physical pixels
func _fit() -> void:
	if not is_inside_tree() or size.x < 1.0 or size.y < 1.0:
		return
	var px := size * get_viewport().get_final_transform().get_scale()
	px *= minf(1.0, MAX_PX / maxf(px.x, px.y))
	var want := Vector2i(maxi(1, roundi(px.x)), maxi(1, roundi(px.y)))
	# a tall frame keeps the stone's width in view instead of cropping its sides
	studio.cam.keep_aspect = Camera3D.KEEP_WIDTH if want.y > want.x else Camera3D.KEEP_HEIGHT
	if studio.vp.size != want:
		studio.vp.size = want
		print_verbose("SpecView render ", want, " for ", size)

func show_spec(o: Dictionary) -> void:
	_req += 1
	var my := _req
	var p: Node3D = await studio.show_async(o)
	if my != _req or not is_instance_valid(self):
		return
	live = p
	built.emit(p)
	spin_v = 0.45
	tilt = 0.0
	if still:
		live.rotation = Vector3(0.12, 0.6, 0)

func _process(dt: float) -> void:
	_since += dt
	if _since >= 1.0 / FPS - 0.002 and is_visible_in_tree():
		_since = 0.0
		studio.vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	if absf(_zoom - _zoom_to) > 0.001:
		_zoom = lerpf(_zoom, _zoom_to, minf(1.0, dt * 12.0))
		studio.cam.fov = _fov0 / _zoom
	# a fluorescent find: the studio goes dark in step with its glow; a star heart dims it a little
	studio.set_uv(Spec.uv if live and live.has_meta("fluor") else 0.4 if live and live.has_meta("heart_light") else 0.0)
	if live and live.has_meta("heart_light"):
		var hl: OmniLight3D = live.get_meta("heart_light")
		if is_instance_valid(hl): hl.light_energy = 1.2 + 2.2 * Spec.beat
	if not live or still:
		return
	dt = minf(dt, 0.05)
	_t += dt
	if not _drag:
		spin_v += ((0.0 if hold else 0.45) - spin_v) * minf(1.0, dt * (2.5 if hold else 1.2))
		live.rotation.y += spin_v * dt
		tilt *= maxf(0.0, 1.0 - dt * 0.8)
	live.rotation.x += (tilt + sin(_t * 0.7) * 0.06 - live.rotation.x) * minf(1.0, dt * 6.0)
	live.position.y = sin(_t * 1.1) * 0.06
	for a in live.get_meta("anim", []):
		var n: Node3D = a[0]
		match a[1]:
			"x": n.rotate_object_local(Vector3.RIGHT, a[2] * dt)
			"y": n.rotate_object_local(Vector3.UP, a[2] * dt)
			_: n.rotate_object_local(Vector3.BACK, a[2] * dt)

func _set_zoom(z: float) -> void:
	_zoom_to = clampf(z, 1.0, ZOOM_MAX)

func _gui_input(e: InputEvent) -> void:
	if zoomable and _zoom_gesture(e):
		_press_ms = -1
		accept_event()
		return
	_tap(e)
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		_drag = e.pressed
		accept_event()
	elif e is InputEventScreenTouch:
		_drag = e.pressed
		accept_event()
	elif (e is InputEventMouseMotion and _drag) or e is InputEventScreenDrag:
		var r: Vector2 = e.relative * (390.0 / maxf(1.0, size.x))
		if live:
			live.rotation.y += r.x * 0.012
			spin_v = clampf(r.x * 0.7, -9.0, 9.0)
			tilt = clampf(tilt + r.y * 0.008, -0.7, 0.7)
		accept_event()

## a press let go soon, near where it went down (touch and the mouse it emulates count once)
func _tap(e: InputEvent) -> void:
	var down: bool = (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT) or e is InputEventScreenTouch
	if down and e.pressed:
		_press = e.position
		_press_ms = Time.get_ticks_msec()
	elif down and _press_ms >= 0:
		var now := Time.get_ticks_msec()
		if now - _press_ms < 350 and e.position.distance_to(_press) < 12.0 and now - _tap_ms > 150:
			_tap_ms = now
			tapped.emit()
		_press_ms = -1

## pinch, wheel and double tap; true when the event was a zoom (it then does not turn the stone)
func _zoom_gesture(e: InputEvent) -> bool:
	if e is InputEventScreenTouch:
		if e.pressed: _touch[e.index] = e.position
		else: _touch.erase(e.index)
		if _touch.size() == 2:
			var pts: Array = _touch.values()
			_pinch0 = maxf(1.0, (pts[0] as Vector2).distance_to(pts[1]))
			_pinch_zoom = _zoom_to
			_drag = false
			return true
		if e.pressed and e.double_tap:
			_set_zoom(1.0 if _zoom_to > 1.3 else 2.2)
			return true
		return _touch.size() > 1
	if e is InputEventScreenDrag and _touch.size() >= 2:
		_touch[e.index] = e.position
		var pts: Array = _touch.values()
		_set_zoom(_pinch_zoom * (pts[0] as Vector2).distance_to(pts[1]) / _pinch0)
		return true
	if e is InputEventMagnifyGesture:
		_set_zoom(_zoom_to * e.factor)
		return true
	if e is InputEventMouseButton and e.pressed:
		match e.button_index:
			MOUSE_BUTTON_WHEEL_UP: _set_zoom(_zoom_to * 1.12)
			MOUSE_BUTTON_WHEEL_DOWN: _set_zoom(_zoom_to / 1.12)
			MOUSE_BUTTON_LEFT:
				if not e.double_click: return false
				_set_zoom(1.0 if _zoom_to > 1.3 else 2.2)
			_: return false
		return true
	# while two fingers are down the emulated mouse must not turn the stone either
	return _touch.size() > 1 and e is InputEventMouseMotion
