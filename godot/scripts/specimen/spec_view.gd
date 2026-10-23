class_name SpecView
extends Control
## A live 3D specimen on screen: it drifts and turns by itself, answers the finger,
## and when let go keeps spinning, slowing back to a drift. Machines keep their parts moving.
## The studio renders at real screen pixels (not the 390-wide layout units the UI is laid out in),
## so on a 3x phone the stone is not blown up from a small picture and does not shimmer as it turns.

const MAX_PX := 1024   # longest side of the render, to keep the phone cool

var studio: SpecStudio
var live: Node3D
var _img: TextureRect
var spin_v := 0.45
var tilt := 0.0
var still := false     # a fixed three-quarter pose, as in thumbnails
var _drag := false
var _t := 0.0
var _req := 0

func _init(px := 512, transparent := false) -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	studio = SpecStudio.make(px, Viewport.MSAA_4X, transparent)
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
	spin_v = 0.45
	tilt = 0.0
	if still:
		live.rotation = Vector3(0.12, 0.6, 0)

func _process(dt: float) -> void:
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
		spin_v += (0.45 - spin_v) * minf(1.0, dt * 1.2)
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

func _gui_input(e: InputEvent) -> void:
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
