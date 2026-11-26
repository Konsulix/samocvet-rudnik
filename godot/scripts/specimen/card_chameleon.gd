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
var _bug: MeshInstance3D  # (unused: the bee of the first hunt)
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
	_skin.set_shader_parameter("head_rot", _head)
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
	# (26.11) the prey: a fly (no scan of one: built here), its wings a buzzing blur
	_prey = _build_fly()
	_prey.visible = false
	_hold.add_child(_prey)
	var tm := StandardMaterial3D.new()
	tm.albedo_color = Color(0.85, 0.42, 0.48)
	tm.roughness = 0.25
	_tongue = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.009
	cm.bottom_radius = 0.013
	cm.height = 1.0
	cm.radial_segments = 8
	cm.rings = 1
	_tongue.mesh = cm
	_tongue.material_override = tm
	_tongue.visible = false
	_hold.add_child(_tongue)
	_tip = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.022
	sm.height = 0.044
	sm.radial_segments = 10
	sm.rings = 6
	_tip.mesh = sm
	_tip.material_override = tm
	_tip.visible = false
	_hold.add_child(_tip)

## the fly's length (model units; the chameleon's head is ~0.15)
const FLY_LEN := 0.1
var _wings: Array[Node3D] = []
var _wing_ph := 0.0
var _path: Array[Vector3] = []
var _seg := 0
var _seg_t := 0.0
var _nose := Vector3.LEFT
const DART := 0.38
const HOVER := [0.2, 0.55]
var _hover_for := 0.3

static var _wing_tex: ImageTexture

## (26.11) a bluebottle: dark head with big red eyes, a grey bristly thorax, a metallic blue-green belly, six legs, two
## clear veined wings. Its own axes: +x its nose, +y its back
func _build_fly() -> Node3D:
	var f := Node3D.new()
	var body := Node3D.new()
	body.scale = Vector3.ONE * FLY_LEN
	f.add_child(body)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.05, 0.05, 0.06)
	dark.roughness = 0.6
	var thor := StandardMaterial3D.new()
	thor.albedo_color = Color(0.16, 0.16, 0.15)
	thor.roughness = 0.85
	var belly := StandardMaterial3D.new()
	belly.albedo_color = Color(0.04, 0.2, 0.3)
	belly.metallic = 0.75
	belly.roughness = 0.22
	var eye := StandardMaterial3D.new()
	eye.albedo_color = Color(0.5, 0.07, 0.03)
	eye.roughness = 0.28
	var ball := SphereMesh.new()
	ball.radius = 0.5
	ball.height = 1.0
	ball.radial_segments = 14
	ball.rings = 8
	var parts := [
		[Vector3(0.38, 0.32, 0.34), Vector3(0.05, 0.0, 0.0), thor],
		[Vector3(0.46, 0.3, 0.36), Vector3(-0.36, -0.04, 0.0), belly],
		[Vector3(0.2, 0.28, 0.34), Vector3(0.36, -0.01, 0.0), dark],
		[Vector3(0.16, 0.24, 0.15), Vector3(0.4, 0.02, 0.11), eye],
		[Vector3(0.16, 0.24, 0.15), Vector3(0.4, 0.02, -0.11), eye],
	]
	for pt in parts:
		var mi := MeshInstance3D.new()
		mi.mesh = ball
		mi.material_override = pt[2]
		mi.scale = pt[0]
		mi.position = pt[1]
		body.add_child(mi)
	# legs: two joints each, out and down from under the thorax
	var stick := CylinderMesh.new()
	stick.top_radius = 0.016
	stick.bottom_radius = 0.012
	stick.height = 1.0
	stick.radial_segments = 5
	stick.rings = 1
	for zs in [-1.0, 1.0]:
		for k in 3:
			var x0 := 0.16 - 0.14 * k
			var a := Vector3(x0, -0.12, 0.08 * zs)
			var b := Vector3(x0 + 0.1 - 0.14 * k, -0.22, 0.3 * zs)
			var c := Vector3(x0 + 0.16 - 0.24 * k, -0.46, 0.38 * zs)
			for seg in [[a, b], [b, c]]:
				var p0: Vector3 = seg[0]
				var p1: Vector3 = seg[1]
				var d := p1 - p0
				var y := d.normalized()
				var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
				var mi := MeshInstance3D.new()
				mi.mesh = stick
				mi.material_override = dark
				mi.transform = Transform3D(Basis(x, y * d.length(), x.cross(y)), p0 + d * 0.5)
				body.add_child(mi)
	# the wings: on the thorax, swept back; each with a ghost half a beat behind (the blur of a beat too quick to see)
	if not _wing_tex: _wing_tex = _make_wing_tex()
	for zs in [-1.0, 1.0]:
		for ghost in [false, true]:
			var piv := Node3D.new()
			piv.position = Vector3(0.1, 0.15, 0.06 * zs)
			piv.set_meta("side", zs)
			piv.set_meta("ghost", ghost)
			body.add_child(piv)
			var wm := StandardMaterial3D.new()
			wm.albedo_texture = _wing_tex
			wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			wm.cull_mode = BaseMaterial3D.CULL_DISABLED
			wm.roughness = 0.15
			wm.metallic = 0.3
			wm.albedo_color = Color(1, 1, 1, 0.45 if ghost else 1.0)
			var pm := PlaneMesh.new()
			pm.size = Vector2(0.78, 0.3)
			var mi := MeshInstance3D.new()
			mi.mesh = pm
			mi.material_override = wm
			var sweep := 0.5
			var d := Vector3(-cos(sweep), 0.0, sin(sweep) * zs)
			# (the plane's x — its texture's length — laid along d, root at the pivot)
			mi.transform = Transform3D(Basis(Vector3.UP, atan2(-d.z, d.x)), d * 0.39)
			piv.add_child(mi)
			_wings.append(piv)
	return f

## a fly's wing: clear, faintly smoky, dark veins running its length, its edge darker
static func _make_wing_tex() -> ImageTexture:
	var W := 128
	var H := 48
	var im := Image.create(W, H, false, Image.FORMAT_RGBA8)
	for y in H:
		for x in W:
			# x along the wing (0 its root .. 1 its tip), y across it
			var u := float(x) / (W - 1)
			var v := float(y) / (H - 1) * 2.0 - 1.0
			var half := 0.92 * pow(sin(PI * clampf(u * 0.96 + 0.04, 0.0, 1.0)), 0.6) * (0.55 + 0.45 * u)
			if absf(v) > half or u > 0.99:
				im.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var a := 0.22
			var c := Color(0.82, 0.86, 0.9)
			# veins: lines along it, bowing toward the tip, and two across
			for vk in [-0.6, -0.2, 0.15, 0.5]:
				var line: float = float(vk) * half * (1.0 - 0.3 * u)
				if absf(v - line) < 0.07: a = 0.8
			if absf(u - 0.45) < 0.012 or absf(u - 0.7) < 0.012: a = 0.75
			if absf(v) > half - 0.08: a = maxf(a, 0.6)
			if a > 0.5: c = Color(0.18, 0.14, 0.1)
			im.set_pixel(x, y, Color(c.r, c.g, c.b, a))
	im.generate_mipmaps()
	return ImageTexture.create_from_image(im)

## its wings beat (too quick to see — every frame about half a beat, a ghost behind)
func _beat(dt: float) -> void:
	_wing_ph += dt * TAU * 27.0
	for piv in _wings:
		var zs := float(piv.get_meta("side"))
		var ph := _wing_ph + (PI if piv.get_meta("ghost") else 0.0)
		var ang := 0.35 + sin(ph) * 0.85
		piv.basis = Basis(Vector3.RIGHT, -ang * zs)

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


func _tongue_to(from: Vector3, at: Vector3) -> void:
	var d := at - from
	var L := d.length()
	_tongue.visible = L > 0.01
	_tip.visible = L > 0.01
	if L <= 0.01: return
	var y := d / L
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	_tongue.transform = Transform3D(Basis(x, y * L, z), from + d * 0.5)
	_tip.position = at

## the hunt: a fly comes buzzing out from behind the stone, by its head; the head snaps round to it, away from the viewer — its
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
			var k := clampf(_ht / 0.09, 0.0, 1.0)
			_tongue_to(mouth, mouth.lerp(_bug_at, k))
			if _ht > 0.2:
				_hunt = 4
				_ht = 0.0
				Sfx.buzz(20)
		4:
			var k := 1.0 - clampf(_ht / 0.28, 0.0, 1.0)
			var tip := mouth.lerp(_bug_at, k)
			_tongue_to(mouth, tip)
			_prey.position = tip
			_prey.scale = Vector3.ONE * (0.4 + 0.6 * k)
			if k <= 0.0:
				_tongue.visible = false
				_tip.visible = false
				_prey.visible = false
				_prey.scale = Vector3.ONE
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
	if _hunt in [1, 2, 3]:
		# buzzing: a quick small jitter about where it is, its nose along its last dart
		var t := _sway
		var j := Vector3(sin(t * 31.0), sin(t * 23.0 + 1.0), sin(t * 27.0 + 2.0)) * 0.004
		_prey.position = _bug_at + j
		var up := _head_up
		var xv := _nose - up * _nose.dot(up)
		if xv.length() < 0.01: xv = _head_dir
		xv = xv.normalized()
		_prey.basis = Basis(xv, up, xv.cross(up)).orthonormalized()
