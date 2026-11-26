class_name CardFluor
extends Control
## (26.11) The fluorescent stone's secret (the legend «fluorescence»): its card turns over (taken by an edge or the name's
## strip, as kintsugi's), and its back is a collector's catalogue card — nothing more, in the light. But in the moments
## the stone's room goes dark and it glows (Spec.uv), a plan of a mine working shows on the back in the stone's own
## glow: a drift bending this way and that from a lantern to a cross, its sets of timber marking each stretch. It looks
## like the map of a place. It is a way: the first swipes of a level played at the depth the stone was found at, in any
## mine (Stones.code_of, Level._code_step) — played right, a rare geode joins the level's goals and opens when the level
## is won. Once: solved, the plan stays, its cross a tick. Nothing in the game says any of this.

const FLIP := 0.55
const HP := 40.0               # room round the card for its rarity glow, turned with it
const GROW := Vector2(0.08, 0.3)
const EDGE := 44.0             # the face turns taken by its sides, this far in
const TOP := 90.0              # or by its name's strip

static var test_flip := 0.0    # a test key (-- fluor_flip=S): the card turns over S s after it is built
static var test_show := false  # a test key (-- fluor_show): the plan shown all the while (not only in the dark)

var card: Control
var view: SpecView
var info: Control
var s: Dictionary
var glow := Color(0.4, 1.0, 0.5)
var _holder: Control
var _bvp: SubViewport
var _bshow: TextureRect
var _hvp: SubViewport
var _hshow: TextureRect
var _halo: Array[CanvasItem] = []
var _bframe: Panel
var _aclip: Panel
var _art: TextureRect
var _dark: ColorRect
var _logo: TextureRect
var _logo_sh: TextureRect
var _plan: Control
var _snap: ImageTexture
var _side := 0
var _ang := 0.0
var _av := 0.0
var _ang_to := 0.0
var _turning := false
var _drag := false
var _grab := 0.0
var _vel := 0.0
var _crossed := false
var _press := Vector2.ZERO
var _pressed := false
var _clock := 0.0
var _flipped := false

## p: the built find; only a fluorescent one (marked by the builder)
static func attach(card_: Control, view_: SpecView, info_: Control, p: Node3D, s_: Dictionary) -> void:
	if not p.has_meta("fluor") or card_.has_meta("fluor_back"): return
	card_.set_meta("fluor_back", true)
	var cf := CardFluor.new()
	cf.card = card_
	cf.view = view_
	cf.info = info_
	cf.s = s_
	if p.has_meta("fluor_col"):
		var c: Color = p.get_meta("fluor_col")
		var mx := maxf(c.r, maxf(c.g, c.b))
		cf.glow = Color(c.r / mx, c.g / mx, c.b / mx)
	card_.add_child(cf)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for ar in OS.get_cmdline_user_args():
		if ar.begins_with("fluor_flip="): test_flip = float(ar.get_slice("=", 1))
		if ar == "fluor_show": test_show = true
	_build_back()

func _build_back() -> void:
	_holder = card.get_parent() as Control
	for h in _holder.get_children():
		if h != card and h is CanvasItem and h.has_meta("halo"): _halo.append(h as CanvasItem)
	# the card's rarity glow again, in a picture of its own: it turns with the card
	_hvp = SubViewport.new()
	_hvp.transparent_bg = true
	_hvp.size_2d_override_stretch = true
	_hvp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	for h in _halo:
		var d := h.duplicate() as CanvasItem
		d.visible = true
		d.modulate.a = 1.0
		_hvp.add_child(d)
	_hshow = TextureRect.new()
	_hshow.texture = _hvp.get_texture()
	_hshow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hshow.stretch_mode = TextureRect.STRETCH_SCALE
	_hshow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hshow.visible = false
	var hm := ShaderMaterial.new()
	hm.shader = preload("res://shaders/card_tilt.gdshader")
	_hshow.material = hm
	_hshow.add_child(_hvp)
	_holder.add_child(_hshow)
	_holder.move_child(_hshow, 0)
	_bvp = SubViewport.new()
	_bvp.transparent_bg = true
	_bvp.size_2d_override_stretch = true
	_bvp.msaa_2d = Viewport.MSAA_4X
	_bvp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_bshow = TextureRect.new()
	_bshow.texture = _bvp.get_texture()
	_bshow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bshow.stretch_mode = TextureRect.STRETCH_SCALE
	_bshow.mouse_filter = Control.MOUSE_FILTER_STOP
	_bshow.visible = false
	var shm := ShaderMaterial.new()
	shm.shader = preload("res://shaders/card_tilt.gdshader")
	shm.set_shader_parameter("pad", Vector2.ZERO)
	_bshow.material = shm
	_bshow.add_child(_bvp)
	_holder.add_child(_bshow)
	# the back in the same brass as the face: the card's own frame, the catalogue card inside it in a rounded mask
	_bframe = Panel.new()
	_bframe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bframe.add_theme_stylebox_override("panel", card.get_theme_stylebox("panel"))
	_bvp.add_child(_bframe)
	_aclip = Panel.new()
	var ast := StyleBoxFlat.new()
	ast.bg_color = Color.WHITE
	ast.set_corner_radius_all(15)
	ast.anti_aliasing = true
	_aclip.add_theme_stylebox_override("panel", ast)
	_aclip.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	_aclip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bvp.add_child(_aclip)
	_art = TextureRect.new()
	_art.texture = load("res://assets/ui/card_back.png")
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_SCALE
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aclip.add_child(_art)
	# the game's brass plate (the trailer's GEMCORE, as on kintsugi's back) at the paper's foot, a shadow under it
	_logo_sh = TextureRect.new()
	_logo = TextureRect.new()
	for t: TextureRect in [_logo_sh, _logo]:
		t.texture = load("res://assets/ui/card_back/logo.png")
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_SCALE
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_aclip.add_child(t)
	_logo_sh.modulate = Color(0, 0, 0, 0.5)
	# the room going dark over the paper, and the plan glowing through it
	_dark = ColorRect.new()
	_dark.color = Color(0.01, 0.0, 0.05, 0.0)
	_dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aclip.add_child(_dark)
	_plan = Control.new()
	_plan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plan.material = FxLayer.add_material()
	_plan.draw.connect(_draw_plan)
	_aclip.add_child(_plan)
	tree_exiting.connect(func() -> void:
		if is_instance_valid(_bshow): _bshow.queue_free()
		if is_instance_valid(_hshow): _hshow.queue_free())

## the plan of the working: the code's steps as a drift from a lantern to a cross, drawn by a hand that was not steady
func _draw_plan() -> void:
	var code := Stones.code_of(s)
	if code.is_empty(): return
	var k := 1.0 if test_show else Spec.uv
	if k <= 0.01: return
	var done := bool(s.get("code_done", false))
	var pts: Array[Vector2] = [Vector2.ZERO]
	for d: Vector2i in code: pts.append(pts[-1] + Vector2(d.y, d.x))   # (a step: rows down, columns right)
	var lo := pts[0]
	var hi := pts[0]
	for q in pts:
		lo = lo.min(q)
		hi = hi.max(q)
	# in the paper's empty lower half
	var area := Rect2(_plan.size.x * 0.16, _plan.size.y * 0.51, _plan.size.x * 0.68, _plan.size.y * 0.31)
	var ext := (hi - lo).max(Vector2.ONE)
	var u := minf(minf(area.size.x / (ext.x + 0.6), area.size.y / (ext.y + 0.6)), 52.0)
	var org := area.get_center() - (lo + hi) * 0.5 * u
	var rng := RandomNumberGenerator.new()
	rng.seed = int(s.get("id", 1)) * 7919 + 13
	var col := Color(glow.r, glow.g, glow.b, 1.0)
	var line := PackedVector2Array()
	for i in pts.size() - 1:
		var a := org + pts[i] * u
		var b := org + pts[i + 1] * u
		var n := (b - a).orthogonal().normalized()
		for j in 6:
			var f := j / 6.0
			line.append(a.lerp(b, f) + n * rng.randf_range(-1.3, 1.3) * (0.0 if j == 0 else 1.0))
		# a set of timber where each stretch ends: a short stroke across the drift
		var e := b + n * rng.randf_range(-0.8, 0.8)
		if i < pts.size() - 2:
			_plan.draw_line(e - n * 6.0, e + n * 6.0, Color(col, 0.75 * k), 2.0, true)
	line.append(org + pts[-1] * u)
	for w: Array in [[11.0, 0.1], [6.0, 0.22], [2.4, 0.95]]:
		_plan.draw_polyline(line, Color(col, float(w[1]) * k), float(w[0]), true)
	# the lantern it starts from: a small ring, rays round it
	var st := org
	_plan.draw_arc(st, 6.0, 0.0, TAU, 20, Color(col, 0.95 * k), 2.0, true)
	for i in 8:
		var a := i * TAU / 8.0 + 0.2
		_plan.draw_line(st + Vector2.from_angle(a) * 9.5, st + Vector2.from_angle(a) * (13.0 + 2.0 * (i % 2)), Color(col, 0.7 * k), 1.6, true)
	# the cross it ends at (solved: a tick)
	var en := org + pts[-1] * u
	if done:
		_plan.draw_polyline(PackedVector2Array([en + Vector2(-8, 0), en + Vector2(-2, 7), en + Vector2(9, -8)]), Color(col, 0.95 * k), 2.6, true)
	else:
		_plan.draw_line(en + Vector2(-7, -7), en + Vector2(7, 7), Color(col, 0.95 * k), 2.6, true)
		_plan.draw_line(en + Vector2(-7, 7), en + Vector2(7, -7), Color(col, 0.95 * k), 2.6, true)

func _layout_back() -> void:
	var sz := card.size
	_bframe.position = Vector2.ZERO
	_bframe.size = sz
	var pad := Reveal.CARD_PAD
	_aclip.position = Vector2(pad, pad)
	_aclip.size = sz - Vector2(pad, pad) * 2.0
	# the paper covers the inside whole, keeping its own proportions
	var ts := _art.texture.get_size()
	var sc := maxf(_aclip.size.x / ts.x, _aclip.size.y / ts.y) * 1.04
	_art.size = ts * sc
	_art.position = (_aclip.size - _art.size) * 0.5
	var lw := _aclip.size.x * 0.46
	var lh := lw * float(_logo.texture.get_height()) / float(_logo.texture.get_width())
	_logo.size = Vector2(lw, lh)
	_logo.position = Vector2((_aclip.size.x - lw) * 0.5, _aclip.size.y - lh - 16.0)
	_logo_sh.size = _logo.size
	_logo_sh.position = _logo.position + Vector2(2, 4)
	for n: Control in [_dark, _plan]:
		n.position = Vector2.ZERO
		n.size = _aclip.size

func _process(dt: float) -> void:
	if not is_instance_valid(info) or not is_instance_valid(card):
		queue_free()
		return
	_clock += dt
	_turn(dt)
	if _side == 1 or _turning:
		var k := 1.0 if test_show else Spec.uv
		_dark.color.a = 0.86 * k
		_plan.queue_redraw()
	if test_flip > 0.0 and not _flipped and not _turning and _clock > test_flip:
		_flipped = true
		flip()

## a drag across the card's edge or its name's strip (face up), or anywhere across the back, turns it under the finger
func _input(e: InputEvent) -> void:
	var press: bool = (e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT) or e is InputEventScreenTouch
	if press:
		var pos: Vector2 = (e as InputEventMouseButton).position if e is InputEventMouseButton else (e as InputEventScreenTouch).position
		var cpos := (card.get_global_transform_with_canvas() * card.get_global_transform().affine_inverse()).affine_inverse() * pos
		var cr := card.get_global_rect()
		var on := cr.has_point(cpos) and card.is_visible_in_tree()
		if on and _side == 0:
			on = cpos.x < cr.position.x + EDGE or cpos.x > cr.end.x - EDGE or cpos.y < cr.position.y + TOP
		if e.is_pressed():
			_pressed = on
			_press = pos
			_drag = false
			_vel = 0.0
		elif _pressed:
			_pressed = false
			if _drag: _let_go()
		return
	if not _pressed or not (e is InputEventMouseMotion or e is InputEventScreenDrag): return
	var mp: Vector2 = (e as InputEventMouseMotion).position if e is InputEventMouseMotion else (e as InputEventScreenDrag).position
	var mv: Vector2 = (e as InputEventMouseMotion).velocity if e is InputEventMouseMotion else (e as InputEventScreenDrag).velocity
	var d := mp - _press
	if not _drag:
		if absf(d.x) < 14.0 or absf(d.x) < absf(d.y) * 1.3: return
		_drag = true
		_grab = _ang
		_press = mp
		_begin()
		d = Vector2.ZERO
	_ang_to = clampf(_grab + d.x / (card.size.x * 0.85) * PI, -PI * 1.05, PI * 1.05)
	_vel = mv.x
	get_viewport().set_input_as_handled()

func _let_go() -> void:
	_drag = false
	var a := _ang_to + clampf(_vel / (card.size.x * 0.85) * PI * 0.18, -1.2, 1.2)
	_ang_to = signf(a) * PI if absf(a) > PI * 0.5 else 0.0

## the card turns over (the test key's): as a drag all the way
func flip(dir := -1.0) -> void:
	if _turning: return
	await _begin()
	_ang_to = signf(dir) * PI

## the turn begins: the face snapshotted (it turns as a picture), the back drawn, the card and its glow hidden behind
## their turning pictures
func _begin() -> void:
	if _turning: return
	_turning = true
	_crossed = false
	_av = 0.0
	_layout_back()
	_size_back()
	_bvp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_hvp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if _side == 0:
		await RenderingServer.frame_post_draw
		if not is_instance_valid(card): return
		var vp := get_viewport()
		var xf := vp.get_final_transform() * card.get_global_transform_with_canvas()
		var r := Rect2i(xf * Rect2(Vector2.ZERO, card.size))
		var img := vp.get_texture().get_image()
		r = r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		_snap = ImageTexture.create_from_image(img.get_region(r))
	_bshow.visible = true
	_hshow.visible = true
	_bshow.texture = _snap if _side == 0 else _bvp.get_texture()
	card.modulate.a = 0.0
	for h in _halo:
		if is_instance_valid(h): h.visible = false
	Sfx.buzz(15)

func _size_back() -> void:
	var sz := card.size
	var dens := maxf(1.0, get_viewport().get_final_transform().get_scale().x)
	if dens < 1.8: dens *= 2.0
	var px := Vector2i((sz * dens).round())
	if _bvp.size != px: _bvp.size = px
	if _bvp.size_2d_override != Vector2i(sz.round()): _bvp.size_2d_override = Vector2i(sz.round())
	var hs := sz + Vector2.ONE * HP * 2.0
	var hpx := Vector2i((hs * minf(dens, 2.0)).round())
	if _hvp.size != hpx: _hvp.size = hpx
	if _hvp.size_2d_override != Vector2i(hs.round()): _hvp.size_2d_override = Vector2i(hs.round())
	var ds := _hvp.get_children()
	for i in mini(ds.size(), _halo.size()):
		if ds[i] is Control and is_instance_valid(_halo[i]) and _halo[i] is Control:
			(ds[i] as Control).position = (_halo[i] as Control).position - card.position + Vector2.ONE * HP
			(ds[i] as Control).size = (_halo[i] as Control).size
			# (26.11: a strip of glow hung under the turned card) the glow's panels follow the card's size by its
			# `resized` — their copies do not: the card had grown shorter since they were copied
			for ch in ds[i].get_children():
				if ch is Control: (ch as Control).size = card.size

func _turn(dt: float) -> void:
	if not is_instance_valid(_bshow): return
	_bshow.global_position = card.global_position - card.size * GROW
	_bshow.size = card.size * (Vector2.ONE + GROW * 2.0)
	(_bshow.material as ShaderMaterial).set_shader_parameter("grow", GROW)
	var hsz0 := card.size + Vector2.ONE * HP * 2.0
	_hshow.global_position = card.global_position - Vector2.ONE * HP - hsz0 * GROW
	_hshow.size = hsz0 * (Vector2.ONE + GROW * 2.0)
	(_hshow.material as ShaderMaterial).set_shader_parameter("grow", GROW)
	if not _turning: return
	if _drag:
		_ang = lerpf(_ang, _ang_to, minf(1.0, dt * 22.0))
		_av = 0.0
	else:
		var left := dt
		while left > 0.0:
			var h := minf(left, 1.0 / 240.0)
			_av += ((_ang_to - _ang) * 110.0 - _av * 17.0) * h
			_ang += _av * h
			left -= h
		if absf(_ang_to - _ang) < 0.004 and absf(_av) < 0.06:
			_end_turn()
			return
	var other := absf(_ang) > PI * 0.5
	if other != _crossed:
		_crossed = other
		Sfx.play("open")
	var a := _ang - signf(_ang) * PI if other else _ang
	var up_t: Texture2D = _snap if _side == 0 else _bvp.get_texture()
	var down_t: Texture2D = _bvp.get_texture() if _side == 0 else _snap
	_bshow.texture = down_t if other else up_t
	(_bshow.material as ShaderMaterial).set_shader_parameter("tilt", Vector2(-a, 0.0))
	var hm := _hshow.material as ShaderMaterial
	hm.set_shader_parameter("tilt", Vector2(-a, 0.0))
	hm.set_shader_parameter("persp", 0.7 * (card.size.x + HP * 2.0) / maxf(1.0, card.size.x))
	var hsz := card.size + Vector2.ONE * HP * 2.0
	hm.set_shader_parameter("hole", Vector2(HP / hsz.x, HP / hsz.y))
	hm.set_shader_parameter("hole_r", 20.0 / hsz.x)

func _end_turn() -> void:
	_turning = false
	if absf(_ang_to) > 1.0: _side = 1 - _side
	_ang = 0.0
	_ang_to = 0.0
	_av = 0.0
	(_bshow.material as ShaderMaterial).set_shader_parameter("tilt", Vector2.ZERO)
	(_hshow.material as ShaderMaterial).set_shader_parameter("tilt", Vector2.ZERO)
	if _side == 0:
		_bshow.visible = false
		_hshow.visible = false
		card.modulate.a = 1.0
		for h in _halo:
			if is_instance_valid(h): h.visible = true
		_bvp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_hvp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	else:
		_bshow.texture = _bvp.get_texture()
		Sfx.buzz(20)
