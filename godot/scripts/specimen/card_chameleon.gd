class_name CardChameleon
extends Node
## The chameleon legend's own guest (25.11, first try: placing only, no colour yet): a chameleon on a twig sticking
## out of the stone window's lower right corner — where the card's frame meets its info panel — climbing up and in,
## beside the stone. On a skull its skeleton, on its own twig. Scans: assets/specimen/chameleon (CREDITS.md,
## prototype/tools/chameleon/cham_prep.py). It lives in the stone's own studio (its lamps and its sky), outside the
## turning find: every frame it is put back in the window's corner, the same size on the screen.

const DIR := "res://assets/specimen/chameleon/"
## (25.11, the user's sketch) the twig laid across the window's lower right corner: one end on the info panel's top,
## CHORD.x of the window's width in from the right, the other on the right frame, CHORD.y up from the panel; its ends
## run on a little behind them (LEN_K of the chord)
const CHORD := Vector2(0.29, 0.41)
const LEN_K := 1.18
## the skeleton's twig: out of the corner, up and in, this long (of the window's width)
const SKEL_LEN := 0.78
## how far in front of the camera (the stone stands at ~6.6)
const DEPTH := 4.6

## the colours it turns, [body, its bands] (the stone, the panel and the brass take the body's)
const PALS := [
	[Color(0.07, 0.42, 0.1), Color(0.85, 0.72, 0.08)],     # leaf green, yellow bands
	[Color(0.03, 0.4, 0.42), Color(0.8, 0.95, 0.85)],      # turquoise, pale bands
	[Color(0.62, 0.08, 0.03), Color(0.98, 0.6, 0.08)],     # red, orange bands
	[Color(0.05, 0.14, 0.62), Color(0.25, 0.82, 0.92)],    # blue, cyan bands
	[Color(0.38, 0.05, 0.5), Color(0.95, 0.45, 0.7)],      # violet, pink bands
	[Color(0.62, 0.34, 0.02), Color(0.2, 0.09, 0.03)],     # amber, dark bands
]
## how long a colour holds; how a change runs: the chameleon first, head to tail, then the stone, the panel, the brass
const HOLD := [6.0, 10.0]
const T_BODY := 1.3
const T_STONE := [0.5, 1.6]
const T_SPREAD := [0.8, 2.6]

var view: SpecView
var card: Control
var info: Control
var skel := false
var _hold: Node3D
var _len := 1.0          # the twig's length, model units
var _base := Vector3.ZERO  # its lower end, model space
var _rot := Basis.IDENTITY
var _skin: ShaderMaterial
var _pal := 0             # the colour now
var _from := 0            # the colour before the change
var _t := 0.0             # time into the current colour (a change runs at its start)
var _hold_for := 3.0
var _stone: Array[ShaderMaterial] = []
var _pan_hold: Control
var _pan: ColorRect
var _frame: ColorRect
var _sway := 0.0

static func attach(card_: Control, view_: SpecView, info_: Control, fx: String, skull: bool) -> void:
	if fx != "chameleon": return
	var cc := CardChameleon.new()
	cc.card = card_
	cc.view = view_
	cc.info = info_
	cc.skel = skull
	view_.add_child(cc)

static func _mat(tex: String, tint := Color.WHITE) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SpecFungi.SHADER
	m.set_shader_parameter("tex_d", load(DIR + tex))
	m.set_shader_parameter("tex_n", load(DIR + "cham_n.png"))
	m.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
	m.set_shader_parameter("gain", 1.0)
	m.set_shader_parameter("sat", 1.0)
	m.set_shader_parameter("rough", 0.6)
	m.set_shader_parameter("back_k", 0.15)
	return m

func _ready() -> void:
	var studio: SpecStudio = view.studio
	_hold = Node3D.new()
	studio.vp.add_child(_hold)
	var body := MeshInstance3D.new()
	var twig := MeshInstance3D.new()
	if skel:
		body.mesh = load(DIR + "cham_skel.obj")
		_skin = ShaderMaterial.new()
		_skin.shader = preload("res://shaders/chameleon.gdshader")
		_skin.set_shader_parameter("tex_d", load(DIR + "bone_d.png"))
		_skin.set_shader_parameter("bone", 1.0)
		_skin.set_shader_parameter("seed", randf() * 10.0)
		body.material_override = _skin
		twig.mesh = load(DIR + "cham_skel_branch.obj")
		twig.material_override = _mat("bone_d.png", Color(0.45, 0.3, 0.2))
	else:
		body.mesh = load(DIR + "cham_body.obj")
		twig.mesh = load(DIR + "cham_branch.obj")
		twig.material_override = _mat("cham_d.png")
		_skin = ShaderMaterial.new()
		_skin.shader = preload("res://shaders/chameleon.gdshader")
		_skin.set_shader_parameter("tex_d", load(DIR + "cham_d.png"))
		_skin.set_shader_parameter("seed", randf() * 10.0)
		body.material_override = _skin
	_hold.add_child(twig)
	_hold.add_child(body)
	# the twig's run: its two ends farthest apart; the lower one (the scan's own up is +y) goes into the corner
	var pts := (twig.mesh as Mesh).get_faces()
	var c := Vector3.ZERO
	for p in pts: c += p
	c /= maxf(1.0, pts.size())
	var a := c
	for p in pts: if p.distance_squared_to(c) > a.distance_squared_to(c): a = p
	var b := a
	for p in pts: if p.distance_squared_to(a) > b.distance_squared_to(a): b = p
	# (the end farther from the animal goes into the corner: it climbs up the twig, away from the frame)
	var bc0 := Vector3.ZERO
	var bp0 := (body.mesh as Mesh).get_faces()
	for p in bp0: bc0 += p
	bc0 /= maxf(1.0, bp0.size())
	if (a.distance_squared_to(bc0) > b.distance_squared_to(bc0)) != OS.get_cmdline_user_args().has("cham_flip"):
		var t := a
		a = b
		b = t
	_len = maxf(0.01, a.distance_to(b))
	# the animal's middle (on the twig) is what sits by the corner — a little in from it, up the twig
	var ax0 := (b - a).normalized()
	_base = (a + b) * 0.5
	# (the skeleton as it was first, 25.11 by request: its twig out of the corner up and in, its middle a little up it)
	if skel: _base = a + ax0 * (bc0 - a).dot(ax0)
	var bc := Vector3.ZERO
	var bp := (body.mesh as Mesh).get_faces()
	for p in bp: bc += p
	bc /= maxf(1.0, bp.size())
	# turned: the twig up and in from the corner (up-left on the screen, a little toward the camera), then about it, so
	# the animal (its middle off the twig) is on the side facing the camera
	var cam := studio.cam
	var want := (cam.global_basis.x * CHORD.x + cam.global_basis.y * CHORD.y + cam.global_basis.z * 0.08).normalized()
	if skel: want = (-cam.global_basis.x * 0.72 + cam.global_basis.y * 0.62 + cam.global_basis.z * 0.3).normalized()
	var axis := (b - a).normalized()
	var r0 := Basis(SpecUtil.quat_to(axis, want))
	var off := bc - a
	off -= axis * off.dot(axis)
	var face := (cam.global_basis.z * 0.85 + cam.global_basis.y * 0.3).normalized()
	var best := -INF
	for k in 48:
		var rr := Basis(want, k * TAU / 48.0) * r0
		var s := (rr * off).normalized().dot(face)
		if s > best:
			best = s
			_rot = rr
	if _skin:
		# the body's line, head (up the twig, toward b) to tail; its length along it
		var hx := (a - b).normalized()
		var lo := INF
		var hi := -INF
		for p in bp:
			var t := (p - bc).dot(hx)
			lo = minf(lo, t)
			hi = maxf(hi, t)
		_skin.set_shader_parameter("c0", bc)
		_skin.set_shader_parameter("ax", hx)
		_skin.set_shader_parameter("side", hx.cross(Vector3.UP).normalized())
		_skin.set_shader_parameter("s_lo", lo)
		_skin.set_shader_parameter("s_hi", hi)
	_pal = randi() % PALS.size()
	_from = _pal
	_set_skin(1.0)
	_build_ui()
	tree_exiting.connect(func() -> void:
		if is_instance_valid(_hold): _hold.queue_free()
		if is_instance_valid(_pan_hold): _pan_hold.queue_free()
		if is_instance_valid(_frame): _frame.queue_free())

## a tap on the chameleon's corner: it changes colour now
func _input(e: InputEvent) -> void:
	var press: bool = (e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT) 		or (e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed)
	if not press or not is_instance_valid(info) or not is_instance_valid(view): return
	var pos: Vector2 = (e as InputEventMouseButton).position if e is InputEventMouseButton else (e as InputEventScreenTouch).position
	var cpos := (view.get_global_transform_with_canvas() * view.get_global_transform().affine_inverse()).affine_inverse() * pos
	var vr := view.get_global_rect()
	var top := info.get_global_rect().position.y
	var zone := Rect2(Vector2(vr.end.x - vr.size.x * 0.4, top - vr.size.x * 0.5), Vector2(vr.size.x * 0.4, vr.size.x * 0.5))
	if zone.has_point(cpos) and _t > T_SPREAD[1]:
		_t = _hold_for + 0.01
		Sfx.play("open")

func _process(dt: float) -> void:
	if not is_instance_valid(info) or not is_instance_valid(view) or not is_instance_valid(_hold): return
	_colour(dt)
	var studio: SpecStudio = view.studio
	var cam := studio.cam
	var vs := Vector2(studio.vp.size)
	if view.size.x <= 0.0: return
	var k := vs.x / view.size.x
	# the window's lower right corner: the view's right edge, the info panel's top (in the studio's pixels)
	var ir := info.get_global_rect()
	var vr := view.get_global_rect()
	var corner := Vector2(vr.size.x, ir.position.y - vr.position.y) * k
	var w := vr.size.x * k
	if skel:
		var p0 := cam.project_position(corner, DEPTH)
		var p1 := cam.project_position(corner - Vector2(w * SKEL_LEN, 0.0), DEPTH)
		var into := (-cam.global_basis.x * 0.72 + cam.global_basis.y * 0.62).normalized() * p0.distance_to(p1) * 0.3
		var bk := _rot.scaled(Vector3.ONE * p0.distance_to(p1) / _len)
		_hold.global_transform = Transform3D(bk, p0 + into - bk * _base)
		return
	var e1 := cam.project_position(corner + Vector2(-w * CHORD.x, 0.0), DEPTH)
	var e2 := cam.project_position(corner + Vector2(0.0, -w * CHORD.y), DEPTH)
	var sc := e1.distance_to(e2) * LEN_K / _len
	var bs := _rot.scaled(Vector3.ONE * sc)
	# it sways a little up and down its twig, as chameleons do: a leaf in the wind
	_sway += dt
	var along := (e2 - e1).normalized() * e1.distance_to(e2) * 0.018 * (sin(_sway * 1.3) + 0.4 * sin(_sway * 3.1))
	_hold.global_transform = Transform3D(bs, (e1 + e2) * 0.5 - bs * _base + along)

static func _c3(c: Color) -> Vector3:
	return Vector3(c.r, c.g, c.b)

## the chameleon's skin: the change's wave `w` (0 not begun .. 1 done)
func _set_skin(w: float) -> void:
	if not _skin: return
	var A: Array = PALS[_from]
	var B: Array = PALS[_pal]
	_skin.set_shader_parameter("main_a", _c3(A[0]))
	_skin.set_shader_parameter("pat_a", _c3(A[1]))
	_skin.set_shader_parameter("main_b", _c3(B[0]))
	_skin.set_shader_parameter("pat_b", _c3(B[1]))
	_skin.set_shader_parameter("wave", lerpf(-0.1, 1.1, w))

## the panel's and the brass's layers (over the slate, under the words; over the brass)
func _build_ui() -> void:
	var sh := preload("res://shaders/card_cham_tint.gdshader")
	_pan_hold = Control.new()
	_pan_hold.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(_pan_hold)
	info.move_child(_pan_hold, mini(1, info.get_child_count() - 1))
	_pan = ColorRect.new()
	_pan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pm := ShaderMaterial.new()
	pm.shader = sh
	pm.set_shader_parameter("mode", 0)
	pm.set_shader_parameter("k", 0.75)
	pm.set_shader_parameter("pan_r", Reveal.INFO_R)
	_pan.material = pm
	_pan_hold.add_child(_pan)
	_frame = ColorRect.new()
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.z_index = 4
	var fm := ShaderMaterial.new()
	fm.shader = sh
	fm.set_shader_parameter("mode", 1)
	fm.set_shader_parameter("k", 0.6)
	_frame.material = fm
	card.add_child(_frame)

## the colour of the moment: held, then changed: the chameleon first, head to tail, the stone after it, then a ring of
## the new colour spreading from the corner over the panel and the brass
func _colour(dt: float) -> void:
	_t += dt
	if _t > _hold_for:
		_t = 0.0
		_from = _pal
		_pal = (_pal + 1 + randi() % (PALS.size() - 1)) % PALS.size()
		_hold_for = randf_range(HOLD[0], HOLD[1])
	_set_skin(clampf(_t / T_BODY, 0.0, 1.0))
	var a: Color = (PALS[_from] as Array)[0]
	var b: Color = (PALS[_pal] as Array)[0]
	# the stone: its chameleon colour (spec.gdshaderinc cham_col), from the old to the new
	var ks := smoothstep(T_STONE[0], T_STONE[1], _t)
	if _stone.is_empty() and is_instance_valid(view.live):
		for n in view.live.find_children("*", "GeometryInstance3D", true, false):
			var m := (n as GeometryInstance3D).material_override as ShaderMaterial
			while m:
				var ck = m.get_shader_parameter("cham_k")
				if ck != null and float(ck) > 0.0: _stone.append(m)
				m = m.next_pass as ShaderMaterial
	for m in _stone:
		if is_instance_valid(m): m.set_shader_parameter("cham_col", _c3(a.lerp(b, ks)))
	# the ring: from the chameleon's corner (the panel's top right)
	var ks2 := clampf((_t - T_SPREAD[0]) / (T_SPREAD[1] - T_SPREAD[0]), 0.0, 1.0)
	var ir := info.get_global_rect()
	var cr := card.get_global_rect()
	var corner := Vector2(ir.end.x, ir.position.y)
	var far := cr.size.length() * 1.1
	var rad := ks2 * ks2 * far if ks2 < 1.0 else 9999.0
	_pan.global_position = info.global_position
	_pan.size = info.size
	var pm := _pan.material as ShaderMaterial
	pm.set_shader_parameter("rsize", info.size)
	pm.set_shader_parameter("col_a", _c3(a))
	pm.set_shader_parameter("col_b", _c3(b))
	pm.set_shader_parameter("src", corner - info.global_position)
	pm.set_shader_parameter("rad", rad)
	_frame.global_position = card.global_position
	_frame.size = card.size
	var fm := _frame.material as ShaderMaterial
	fm.set_shader_parameter("rsize", card.size)
	fm.set_shader_parameter("col_a", _c3(a))
	fm.set_shader_parameter("col_b", _c3(b))
	fm.set_shader_parameter("src", corner - card.global_position)
	fm.set_shader_parameter("rad", rad)
	fm.set_shader_parameter("frame_in", Reveal.CARD_PAD)
	# the ribbon over the panel, as Reveal._info_rim lays it (the numbers of CardAurora)
	var ig: Rect2 = Rect2(ir.position - cr.position, ir.size)
	const OUT := 5.0 / 3.6
	const WIDE := 20.0 / 3.6
	const UP := 46.0
	var R := Reveal.INFO_R
	var midw := R + WIDE / 2.0
	var top := ig.position.y
	var xl := OUT + WIDE / 2.0
	var xr := card.size.x - OUT - WIDE / 2.0
	var cl := Vector2(ig.position.x + R, top + R)
	var crr := Vector2(ig.end.x - R, top + R)
	fm.set_shader_parameter("rib_y", top + R - midw)
	fm.set_shader_parameter("rib_cl", cl)
	fm.set_shader_parameter("rib_cr", crr)
	fm.set_shader_parameter("rib_ax", Vector2(cl.x - xl, midw))
	fm.set_shader_parameter("rib_xl", xl)
	fm.set_shader_parameter("rib_xr", xr)
	fm.set_shader_parameter("rib_end", top + R + UP)
	fm.set_shader_parameter("rib_w", WIDE)
