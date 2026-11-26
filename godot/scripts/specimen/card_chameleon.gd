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
## (25.11: softer, the colours of real chameleons, not neon) [body, its line and head]
const PALS := [
	[Color(0.12, 0.36, 0.1), Color(0.72, 0.68, 0.22)],     # leaf green, a yellow line
	[Color(0.08, 0.33, 0.3), Color(0.62, 0.78, 0.62)],     # teal, pale green
	[Color(0.5, 0.14, 0.06), Color(0.85, 0.55, 0.2)],      # rust red, orange
	[Color(0.1, 0.2, 0.42), Color(0.45, 0.7, 0.72)],       # slate blue, pale cyan
	[Color(0.32, 0.12, 0.3), Color(0.8, 0.5, 0.55)],       # plum, dusty rose
	[Color(0.45, 0.3, 0.08), Color(0.82, 0.72, 0.42)],     # ochre, cream
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
var _bbc: BackBufferCopy
var _sway := 0.0
var _body: MeshInstance3D
var _twig_ax := Vector3.UP
# the eyes (the scan's turrets, model space: their rings marked on renders of the head from both sides, 25.11) and their roll
const EYE1 := Vector3(-0.0842, 0.3739, 0.0485)
const EYE2 := Vector3(-0.1235, 0.3746, -0.024)
const EYE_IN := 0.016
const MOUTH := Vector3(-0.16, 0.385, 0.035)
# (25.11) its neck, where its head turns; its front leg, shoulder to hand (marked on a side render with a grid)
const NECK := Vector3(-0.05, 0.3, -0.017)
const SNOUT := Vector3(-0.163, 0.399, 0.035)
const ARM_A := Vector3(-0.063, 0.162, 0.045)
const ARM_B := Vector3(-0.228, 0.236, 0.089)
var _head := Vector2.ZERO
var _head_to := Vector2.ZERO
var _head_next := 2.0
var _leg := 0.0
var _leg_t := 0.0
var _leg_next := 5.0
var _head_dir := Vector3.LEFT
var _head_up := Vector3.UP
var _prey: Node3D
var _eye := [Vector2.ZERO, Vector2.ZERO]
var _eye_to := [Vector2.ZERO, Vector2.ZERO]
var _eye_next := [0.5, 1.2]
# the hunt: a bee comes buzzing by its snout; it fixes both eyes on it, and its tongue shoots out and takes it
var _tongue: MeshInstance3D
var _tip: MeshInstance3D
var _hunt := 0            # 0 none, 1 coming, 2 hovering, 3 the tongue out, 4 back with it
var _ht := 0.0
var _hwait := 5.0
var _bug_at := Vector3.ZERO
var _bug_from := Vector3.ZERO

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
	_body = body
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
	_twig_ax = (b - a).normalized()
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
		# its across: the flanks along z (where its eyes are), its back away from the twig it holds
		var latv := Vector3(0, 0, 1)
		var bk := bc - c
		bk -= hx * bk.dot(hx)
		bk -= latv * bk.dot(latv)
		bk = bk.normalized() if bk.length() > 0.001 else hx.cross(latv).normalized()
		var rs := 0.0
		var rn := 0
		for p in bp:
			var t := (p - bc).dot(hx)
			if t < lo + (hi - lo) * 0.3 or t > lo + (hi - lo) * 0.6: continue
			var q := p - bc - hx * t
			rs += absf(q.dot(bk))
			rn += 1
		_skin.set_shader_parameter("lat", latv)
		_skin.set_shader_parameter("back", bk)
		_skin.set_shader_parameter("girth", maxf(0.01, rs / maxf(1, rn) * 1.6))
		_skin.set_shader_parameter("s_lo", lo)
		_skin.set_shader_parameter("s_hi", hi)
	if _skin and not skel:
		_skin.set_shader_parameter("eye1", EYE1 + Vector3(0, 0, -EYE_IN))
		_skin.set_shader_parameter("eye2", EYE2 + Vector3(0, 0, EYE_IN))
		_skin.set_shader_parameter("eye_r", 0.026)
		_head_dir = (SNOUT - NECK).normalized()
		var hl := (Vector3(0, 0, 1) - _head_dir * _head_dir.z).normalized()
		_head_up = hl.cross(_head_dir).normalized()
		if _head_up.y < 0.0: _head_up = -_head_up
		_skin.set_shader_parameter("neck", NECK)
		_skin.set_shader_parameter("head_dir", _head_dir)
		_skin.set_shader_parameter("head_up", _head_up)
		_skin.set_shader_parameter("arm_a", ARM_A)
		_skin.set_shader_parameter("arm_b", ARM_B)
		_build_hunt()
	_pal = randi() % PALS.size()
	# (tests: cham_pal=N — that colour, held)
	for ar in OS.get_cmdline_user_args():
		if ar.begins_with("cham_pal="):
			_pal = int(ar.get_slice("=", 1)) % PALS.size()
			_hold_for = 1e9
	_from = _pal
	_set_skin(1.0)
	_build_ui()
	tree_exiting.connect(func() -> void:
		if is_instance_valid(_hold): _hold.queue_free()
		if is_instance_valid(_pan_hold): _pan_hold.queue_free()
		if is_instance_valid(_bbc): _bbc.queue_free()
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
	if not skel:
		_eyes(dt)
		_moves(dt)
		_hunting(dt)
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
	_hold.global_transform = Transform3D(bs, (e1 + e2) * 0.5 - bs * _base)
	# (26.11: it no longer rocks along its twig — it stays put; only its head, eyes, leg and tail move)

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
	# (25.11: a dark strip over the panel's top) the screen this layer reads was copied when the panel's layer read it —
	# before the ribbon and the words were drawn: on the ribbon it drew the slate under it. A fresh copy first
	_bbc = BackBufferCopy.new()
	_bbc.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	_bbc.z_index = 4
	card.add_child(_bbc)
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
				# (on a skull its crystals have no chameleon colour of their own: given it, the bone and the rock left be)
				if ck == null and m.shader and m.shader.get_shader_uniform_list().any(func(u: Dictionary) -> bool: return u.name == "cham_k"): ck = 0.0
				if ck != null and skel and float(ck) <= 0.0 and not m.get_meta("rock", false):
					m.set_shader_parameter("cham_k", 0.85)
					ck = 0.85
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

## each eye rolls on its own, now here, now there; when it hunts, both turn to the bee
func _eyes(dt: float) -> void:
	for k in 2:
		_eye_next[k] = float(_eye_next[k]) - dt
		if _hunt in [2, 3, 4]:
			# (each eye's own outward look is +z or -z: turned toward the snout and the bee in front of it)
			_eye_to[k] = Vector2(0.75 if k == 0 else -0.75, -0.25)
		elif float(_eye_next[k]) <= 0.0:
			_eye_next[k] = randf_range(0.6, 2.4)
			_eye_to[k] = Vector2(randf_range(-0.7, 0.7), randf_range(-0.45, 0.45))
		# a quick flick, then still (a chameleon's eye jumps)
		_eye[k] = (_eye[k] as Vector2).lerp(_eye_to[k], minf(1.0, dt * 14.0))
	_skin.set_shader_parameter("rot1", _eye[0])
	_skin.set_shader_parameter("rot2", _eye[1])

## its head turns, in a quick move and a long stillness; now and then a front leg comes off the twig, hangs, and goes
## back; its tail swings
func _moves(dt: float) -> void:
	_head_next -= dt
	if _hunt >= 2:
		# the hunt: its head away from the viewer, toward the fly behind it (its mouth out of sight)
		_head_to = Vector2(AWAY, 0.12)
	elif _head_next <= 0.0:
		_head_next = randf_range(2.0, 5.0)
		_head_to = Vector2(randf_range(-0.3, 0.35), randf_range(-0.14, 0.2))
	_head = _head.lerp(_head_to, minf(1.0, dt * (9.0 if _hunt >= 2 else 4.5)))
	# (tests: cham_head=x,y — the head held so)
	for ar in OS.get_cmdline_user_args():
		if ar.begins_with("cham_head="):
			var hv := ar.get_slice("=", 1).split(",")
			_head = Vector2(float(hv[0]), float(hv[1]))
			_hwait = 1e9
	_jerk = lerpf(_jerk, 0.0, minf(1.0, dt * 7.0))
	_skin.set_shader_parameter("head_rot", _head + Vector2(0.0, -_jerk))
	_leg_next -= dt
	if _leg_next <= 0.0 and _leg_t <= 0.0 and _hunt == 0:
		_leg_t = randf_range(2.2, 3.6)
		_leg_next = randf_range(8.0, 15.0)
	if _leg_t > 0.0: _leg_t -= dt
	var up := 1.0 if _leg_t > 0.5 else 0.0
	_leg = lerpf(_leg, up, minf(1.0, dt * 4.0))
	# (lifted: off the twig, up and out — and a small tremble while it hangs)
	_skin.set_shader_parameter("arm_lift", -(0.32 * _leg + 0.03 * _leg * sin(_sway * 9.0)))
	_skin.set_shader_parameter("tail_curl", sin(_sway * 0.45) * 0.7 + sin(_sway * 1.1 + 1.0) * 0.3)

## how far its head turns from the viewer for the hunt
const AWAY := 0.9

## a point of its head, turned as the head is now (the shader's own turn, for the tongue's root)
func _on_head(p: Vector3) -> Vector3:
	var hl := _head_dir.cross(_head_up).normalized()
	var q := (p - NECK).rotated(_head_up, _head.x)
	q = q.rotated(hl, _head.y)
	return NECK + q

func _build_hunt() -> void:
	# (26.11) the prey: a demoiselle, its wings beating
	_prey = _build_fly()
	_prey.visible = false
	_hold.add_child(_prey)
	# (26.11) the tongue: a wet pink tube, bowed, thicker at its root; its tip a sticky club
	var tm := StandardMaterial3D.new()
	tm.albedo_color = Color(0.86, 0.45, 0.5)
	tm.roughness = 0.14
	tm.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	tm.rim_enabled = true
	tm.rim = 0.3
	_tmesh = ImmediateMesh.new()
	_tongue = MeshInstance3D.new()
	_tongue.mesh = _tmesh
	_tongue.material_override = tm
	_tongue.visible = false
	_hold.add_child(_tongue)
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.78, 0.32, 0.4)
	cm.roughness = 0.08
	_tip = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.026
	sm.height = 0.052
	sm.radial_segments = 12
	sm.rings = 8
	_tip.mesh = sm
	_tip.material_override = cm
	_tip.visible = false
	_hold.add_child(_tip)

## (26.11) the prey: a banded demoiselle — the amber's scan (assets/specimen/insects), its four wings beating in the
## fungi shader (flap*: what lies out from the thorax turns about its hinge, the hind pair a little ahead of the fore)
const PREY := "res://assets/specimen/insects/dragonfly_demoiselle"
const PREY_LEN := 0.24
var _flap_ph := 0.0
var _flap_k := 0.85
var _prey_mat: ShaderMaterial
var _path: Array[Vector3] = []
var _seg := 0
var _seg_t := 0.0
var _nose := Vector3.LEFT
const DART := 0.42
const HOVER := [0.25, 0.6]
var _hover_for := 0.3
var _tumble := Vector3.UP
var _jerk := 0.0
var _tmesh: ImmediateMesh

## its own axes: +x its nose, +y its back (the scan lies head to -x: turned round)
func _build_fly() -> Node3D:
	var f := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = load(PREY + ".obj")
	_prey_mat = ShaderMaterial.new()
	_prey_mat.shader = SpecFungi.SHADER
	_prey_mat.set_shader_parameter("tex_d", load(PREY + "_d.png"))
	_prey_mat.set_shader_parameter("tex_n", load(PREY + "_n.png"))
	_prey_mat.set_shader_parameter("gain", 1.25)
	_prey_mat.set_shader_parameter("back_k", 0.8)
	# its hinges: along its length, at the thorax's top, the wings out beyond its sides; fore and hind split there
	_prey_mat.set_shader_parameter("flap_hinge", Vector3(-0.165, 0.1, 0.035))
	mi.material_override = _prey_mat
	mi.rotation = Vector3(0, PI, 0)
	mi.scale = Vector3.ONE * PREY_LEN
	f.add_child(mi)
	return f

## its wings beat: quick, but seen (a demoiselle's flutter), the hind pair leading
func _beat(dt: float) -> void:
	_flap_ph += dt * TAU * 11.0
	_prey_mat.set_shader_parameter("flap", _flap_k)
	_prey_mat.set_shader_parameter("flap_ph", fmod(_flap_ph, TAU * 100.0))

## the fly's way: from behind the stone (out of sight), out past its edge on the chameleon's side, a dart near it,
## then to `spot` by its head (all in the chameleon's own space)
func _fly_path(spot: Vector3) -> void:
	var cam := view.studio.cam
	var lo := Vector3.INF
	var hi := -Vector3.INF
	if is_instance_valid(view.live):
		for n in view.live.find_children("*", "GeometryInstance3D", true, false):
			var g := n as GeometryInstance3D
			if not g.is_visible_in_tree(): continue
			var bb := g.global_transform * g.get_aabb()
			lo = lo.min(bb.position)
			hi = hi.max(bb.end)
	var ok := lo.x < INF
	var sc := (lo + hi) * 0.5 if ok else _hold.to_global(Vector3.ZERO) - cam.global_basis.x
	var rr := (hi - lo).length() * 0.35 if ok else 0.6
	var bz := cam.global_basis.z
	var head := _hold.to_global(NECK)
	var side := head - sc
	side -= bz * side.dot(bz)
	side = side.normalized() if side.length() > 0.001 else cam.global_basis.x
	var g0 := sc - bz * rr * 0.9 + side * rr * 0.2
	var g1 := sc - bz * rr * 0.3 + side * rr * 0.95 + cam.global_basis.y * rr * 0.15
	_path = [_hold.to_local(g0), _hold.to_local(g1)]
	var mid := _hold.to_local(g1).lerp(spot, 0.5)
	_path.append(mid + _head_up * randf_range(0.04, 0.12) + _head_dir.cross(_head_up) * randf_range(-0.08, 0.08))
	_path.append(spot)
	_seg = 0
	_seg_t = 0.0
	_hover_for = 0.05
	_nose = (_path[1] - _path[0]).normalized()


## the tongue: a tube from `from` to `at`, bowed toward `bend` (a quadratic curve), thick at its root and thinner on to
## its club of a tip — rebuilt each frame
func _tongue_to(from: Vector3, at: Vector3, bend := Vector3.ZERO) -> void:
	var L := (at - from).length()
	_tongue.visible = L > 0.01
	_tip.visible = L > 0.01
	if L <= 0.01: return
	var ctl := (from + at) * 0.5 + bend
	const SEG := 14
	const SIDES := 8
	var pts: Array[Vector3] = []
	var tans: Array[Vector3] = []
	for i in SEG + 1:
		var s := float(i) / SEG
		var a := from.lerp(ctl, s)
		var b := ctl.lerp(at, s)
		pts.append(a.lerp(b, s))
		tans.append((b - a).normalized() if (b - a).length() > 0.0001 else (at - from).normalized())
	_tmesh.clear_surfaces()
	_tmesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var ref := Vector3.UP if absf(tans[0].y) < 0.9 else Vector3.RIGHT
	var rings: Array = []
	for i in SEG + 1:
		var t := tans[i]
		var x := ref.cross(t).normalized()
		var y := t.cross(x)
		var s := float(i) / SEG
		var r := lerpf(0.017, 0.009, s) * (1.0 + 0.12 * sin(s * 9.0 + _sway * 20.0) * s)
		var ring: Array = []
		for k in SIDES:
			var an := TAU * k / SIDES
			var n := x * cos(an) + y * sin(an)
			ring.append([pts[i] + n * r, n])
		rings.append(ring)
	for i in SEG:
		for k in SIDES:
			var k2 := (k + 1) % SIDES
			for q in [[i, k], [i + 1, k], [i + 1, k2], [i, k], [i + 1, k2], [i, k2]]:
				var v: Array = rings[q[0]][q[1]]
				_tmesh.surface_set_normal(v[1])
				_tmesh.surface_add_vertex(v[0])
	_tmesh.surface_end()
	_tip.position = at
	_tip.basis = Basis(SpecUtil.quat_to(Vector3.UP, tans[SEG])).scaled(Vector3(1.0, 0.8, 1.0))

## world's down, in the chameleon's space
func _down() -> Vector3:
	return (_hold.global_basis.inverse() * Vector3.DOWN).normalized()

## the hunt: a demoiselle comes out from behind the stone, by its head; the head snaps round to it, away from the viewer — its
## mouth out of sight — and the tongue shoots out from behind the head and takes it
func _hunting(dt: float) -> void:
	_ht += dt
	# where it flutters: past the head, on its far side (from the neck along the head as it will be turned, and up)
	var hl := _head_dir.cross(_head_up).normalized()
	var aim := _head_dir.rotated(_head_up, AWAY)
	var spot := NECK + aim * 0.36 + _head_up * 0.05
	var mouth := _on_head(MOUTH)
	match _hunt:
		0:
			if _ht > _hwait:
				_hunt = 1
				_ht = 0.0
				_fly_path(spot)
				_bug_at = _path[0]
				_prey.position = _bug_at
				_prey.visible = true
		1:
			# (26.11) out from behind the stone, as the butterflies of a skull's cloud come out from under it: quick darts,
			# a hover between them
			_seg_t += dt
			var p0: Vector3 = _path[_seg]
			var p1: Vector3 = _path[_seg + 1]
			var k := smoothstep(0.0, DART, _seg_t)
			_bug_at = p0.lerp(p1, k)
			if _seg_t < DART and (p1 - p0).length() > 0.001: _nose = (p1 - p0).normalized()
			if _seg_t > DART + _hover_for:
				_seg += 1
				_seg_t = 0.0
				_hover_for = randf_range(HOVER[0], HOVER[1])
				if _seg >= _path.size() - 1:
					_hunt = 2
					_ht = 0.0
		2:
			# it has seen it: the head round, both eyes on it, a held breath
			_bug_at = spot
			if _ht > 1.1:
				_hunt = 3
				_ht = 0.0
				Sfx.play("click")
		3:
			# out in a blink, a little past it, and back onto it — it sticks; the head jolts with the hit
			var reach := 0.0
			if _ht < 0.07:
				reach = 1.0 - pow(1.0 - _ht / 0.07, 3.0)
				reach *= 1.06
			else:
				var u := (_ht - 0.07) / 0.09
				reach = 1.0 + 0.06 * exp(-u * 3.0) * cos(u * 9.0)
				if _prey.get_meta("stuck", false) == false:
					_prey.set_meta("stuck", true)
					_jerk = 0.16
					_flap_k = 1.3
					Sfx.buzz(20)
					Sfx.play("click")
			var d := _bug_at - mouth
			var side := d.cross(_head_up).normalized()
			var bend := side * sin(clampf(_ht / 0.07, 0.0, 1.0) * PI) * 0.03 * d.length()
			_tongue_to(mouth, mouth + d * reach, bend)
			if _prey.get_meta("stuck", false): _prey.position = mouth + d * reach
			if _ht > 0.2:
				_hunt = 4
				_ht = 0.0
				_tumble = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
		4:
			# reeled in: slow to start, then a snap; the tongue sags and wavers, the catch tumbles on its tip
			var u := clampf(_ht / 0.36, 0.0, 1.0)
			var reach := 1.0 - pow(u, 2.3)
			var d := _bug_at - mouth
			var L := d.length() * reach
			var side := d.cross(_head_up).normalized()
			var bend := _down() * 0.09 * L * sin(u * PI + 0.4) + side * 0.05 * L * sin(u * 16.0) * (1.0 - u)
			var tip := mouth + d * reach
			_tongue_to(mouth, tip, bend)
			_prey.position = tip
			_prey.basis = _prey.basis.rotated(_tumble, dt * 9.0 * (0.4 + u)).orthonormalized()
			_prey.scale = Vector3.ONE * (1.0 if reach > 0.25 else lerpf(0.35, 1.0, reach / 0.25))
			if u >= 1.0:
				_tongue.visible = false
				_tip.visible = false
				_prey.visible = false
				_prey.scale = Vector3.ONE
				_prey.set_meta("stuck", false)
				_flap_k = 0.85
				_jerk = 0.08
				_hunt = 5
				_ht = 0.0
		5:
			# it chews, its head still turned; then back
			if _ht > 0.9:
				_hunt = 0
				_ht = 0.0
				_hwait = randf_range(10.0, 18.0)
				_head_next = 0.0
	if _prey.visible: _beat(dt)
	if _hunt in [1, 2] or (_hunt == 3 and not _prey.get_meta("stuck", false)):
		# hanging in the air: a small bob with its wingbeat, its nose along its last dart
		var t := _sway
		var j := Vector3(sin(t * 3.1), sin(_flap_ph) * 0.6 + sin(t * 2.3 + 1.0), sin(t * 2.7 + 2.0)) * 0.006
		_prey.position = _bug_at + j
		var up := _head_up
		var xv := _nose - up * _nose.dot(up)
		if xv.length() < 0.01: xv = _head_dir
		xv = xv.normalized()
		_prey.basis = Basis(xv, up, xv.cross(up)).orthonormalized()
