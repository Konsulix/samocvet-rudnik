class_name CardLevitate
extends Control
## Levitation (SpecLegend.levitate: shards of glass circling the stone) takes the whole card with it:
##  1. the card itself floats — it rises and sinks, leans a little, and its soft shadow under it widens and pales as
##     it rises;
##  2. shards of the stone's glass (the same shapes, the same glass) circle the whole card on a tilted ring — behind it
##     on the far half (a layer under the card), in front of it on the near half (a layer over it);
##  3. inside the card nothing quite stays put: the genes' badges, the figures and the buttons drift a point or two,
##     each in its own time;
##  4. a tap on the stone: a ring of force spreads from it, the card jumps, the words and buttons jump after it as the
##     wave reaches them, the shards' ring flares wide and settles back.
## The shards are drawn in 3D: two SubViewports sharing one world, each camera seeing its own half of the ring
## (render layers), laid behind and in front of the card in its holder (Ov.card's plain Control).

const PX := 2.0               # the shard layers' pixels a point
const MARGIN := 110.0         # how far past the card the ring reaches
const SHARDS := 7
var _off := Vector2.ZERO      # the card's float now: its picture's shift (points)
const LIFT := 7.0             # the card's float: points up at its highest
const FRONT := 1
const BACK := 2

static var test_tap := 0.0    # a test key (-- lev_tap=S): a tap on the stone every S s

var card: Control
var view: SpecView
var info: Control
var find: Node3D
var _holder: Control
var _shadow: Panel
var _back: TextureRect
var _front: TextureRect
var _ring: Control
var _vb: SubViewport
var _vf: SubViewport
var _world: Node3D
var _shards := []             # {node, a, speed, spin, s}
var _t := 0.0
var _pulse := 99.0            # seconds since the last tap
var _tap_at := 0.0
var _drift := {}              # node id -> its last offset
var _halo: Array[Node] = []
## the card turned in depth, in true perspective: it is drawn in a 2D SubViewport of its own (at the screen's density:
## size_2d_override), whose picture is laid on the screen through shaders/card_tilt.gdshader, a plane turned a few
## degrees; touches on the picture go on into the SubViewport (where the card lies flat). (A CanvasGroup turned the
## masked stone window and panel white; a squeeze and skew looked crooked - 23.11)
const PAD := 34.0             # room round the card in its picture: its rarity glow, and the turn
const GROW := Vector2(0.06, 0.1)   # room round the picture on the screen, for its near side turned (card_tilt `grow`)
var _cvp: SubViewport
var _show: TextureRect
## the phone's tilt (24.11: "no gyroscope - the turn should follow the phone, not play by itself"): the card keeps level
## in the air as the phone turns under it — it turns against the phone's turn from how it is held (a slow average),
## springy, a little behind; on a computer (no sensor) it drifts by itself
var _g0 := Vector3.ZERO
var _tl := Vector2.ZERO
var _tv := Vector2.ZERO
var rng := RandomNumberGenerator.new()

## p: the built find; only a levitating one (SpecLegend.levitate marks it)
static func attach(card_: Control, view_: SpecView, info_: Control, p: Node3D) -> void:
	if not p.has_meta("levitate"): return
	var cl := CardLevitate.new()
	cl.card = card_
	cl.view = view_
	cl.info = info_
	cl.find = p
	card_.add_child(cl)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	rng.randomize()
	_holder = card.get_parent() as Control
	for n in _holder.get_children():
		# (only the card's glow: in the inventory its pile's other cards are beside it in the holder — 25.11, copies)
		if n != card and n.has_meta("halo"): _halo.append(n)
	# the card, its glow with it, into its own SubViewport; its picture where the card was
	_cvp = SubViewport.new()
	_cvp.transparent_bg = true
	_cvp.size_2d_override_stretch = true
	_cvp.msaa_2d = Viewport.MSAA_4X
	_show = TextureRect.new()
	_show.texture = _cvp.get_texture()
	_show.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_show.stretch_mode = TextureRect.STRETCH_SCALE
	_show.mouse_filter = Control.MOUSE_FILTER_STOP
	var shm := ShaderMaterial.new()
	shm.shader = preload("res://shaders/card_tilt.gdshader")
	_show.material = shm
	_show.gui_input.connect(_pass_input)
	# (under the picture, not under this node: this node is the card's, and the card goes into it)
	_show.add_child(_cvp)
	_size_vp()
	var at := card.get_index()
	_holder.add_child(_show)
	_holder.move_child(_show, at)
	for n in _halo:
		if is_instance_valid(n) and n.get_parent() == _holder: n.reparent(_cvp, false)
	card.reparent(_cvp, false)
	card.position = Vector2.ONE * PAD
	for n in _halo:
		if is_instance_valid(n) and n is Control: (n as Control).position = Vector2.ONE * PAD
	# the shadow under the card
	_shadow = Panel.new()
	_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.draw_center = false
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.set_corner_radius_all(16)
	_shadow.add_theme_stylebox_override("panel", sb)
	_holder.add_child(_shadow)
	_holder.move_child(_shadow, 0)
	# the shards' world, seen by two cameras: the far half of the ring and the near half
	_vb = _viewport()
	_vb.own_world_3d = true
	_vf = _viewport()
	_vf.world_3d = _vb.find_world_3d()
	_world = Node3D.new()
	_vb.add_child(_world)
	_camera(_vb, BACK)
	_camera(_vf, FRONT)
	# lit as the stone's studio lights its own shards (23.11: a plain light made them flat plastic): its sky for the
	# glass to reflect (softboxes, SpecStudio's shared sky), its warm key, cold and warm rims and a fill from below
	for L: Array in [[Color("#fff0dc"), 1.45, Vector3(2.5, 3.5, 3)], [Color("#8fb8ff"), 1.4, Vector3(-3.5, 1.5, -2.5)],
			[Color("#ffc890"), 0.9, Vector3(3.5, 0.4, -3)], [Color(1, 1, 1), 0.25, Vector3(0, -2, 4)]]:
		var l := DirectionalLight3D.new()
		l.light_color = L[0]
		l.light_energy = L[1]
		_world.add_child(l)
		l.look_at_from_position(L[2] as Vector3, Vector3.ZERO)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.sky = SpecStudio._shared_sky()
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.45
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_exposure = 1.05
	e.tonemap_white = 6.0
	e.glow_enabled = true
	e.glow_intensity = 0.55
	e.glow_hdr_threshold = 1.0
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.environment = e
	_world.add_child(env)
	_back = _layer(_vb)
	_holder.add_child(_back)
	_holder.move_child(_back, _show.get_index())
	_front = _layer(_vf)
	_holder.add_child(_front)
	# the shards: the stone's own shapes and glass
	var src := find.find_children("*", "MeshInstance3D", true, false).filter(func(n: Node) -> bool: return n.has_meta("lev_shard"))
	for k in SHARDS:
		if src.is_empty(): break
		var from: MeshInstance3D = src[k % src.size()]
		var mi := MeshInstance3D.new()
		mi.mesh = from.mesh
		mi.material_override = from.material_override
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var wide := maxf(0.001, mi.mesh.get_aabb().size.length())
		_world.add_child(mi)
		_shards.append({node = mi, a = float(k) / SHARDS * TAU + rng.randf_range(-0.3, 0.3), speed = rng.randf_range(0.22, 0.32),
			spin = Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized() * rng.randf_range(1.3, 2.8),
			s = rng.randf_range(32.0, 44.0) / wide, rr = rng.randf_range(0.92, 1.08), b = Basis(Vector3(rng.randf(), rng.randf(), rng.randf()).normalized(), rng.randf() * TAU)})
	# the ring of force on a tap, over everything
	_ring = Control.new()
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.draw.connect(_draw_ring)
	_holder.add_child(_ring)
	view.tapped.connect(_tap)
	tree_exiting.connect(func() -> void:
		for n in [_shadow, _back, _front, _ring]:
			if is_instance_valid(n): n.queue_free()
		# (the card back out of its group, where it was: the window closes with it)
		if is_instance_valid(_show): _show.queue_free())

## the card's own picture: at the screen's density and a quarter over (24.11: soft on the phone — turned, the picture
## is read between its pixels); on a low-density screen twice it. Its stone renders at the picture's density: it sizes
## itself to it (on entering the viewport it was sized 1:1, before the viewport had its size - the stone was soft)
func _size_vp() -> void:
	var full := card.size + Vector2.ONE * PAD * 2.0
	# (the screen's: this node is the card's, inside the picture's own viewport - read there, its density fed on itself)
	var dens := maxf(1.0, _holder.get_viewport().get_final_transform().get_scale().x)
	dens *= 2.0 if dens < 1.8 else 1.25
	var px := Vector2i((full * dens).round())
	var changed := _cvp.size != px or _cvp.size_2d_override != Vector2i(full.round())
	if _cvp.size != px: _cvp.size = px
	if _cvp.size_2d_override != Vector2i(full.round()): _cvp.size_2d_override = Vector2i(full.round())
	if changed and is_instance_valid(view): view._fit.call_deferred()

func _viewport() -> SubViewport:
	var v := SubViewport.new()
	v.transparent_bg = true
	v.msaa_3d = Viewport.MSAA_4X
	add_child(v)
	return v

func _camera(v: SubViewport, layer: int) -> void:
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.position = Vector3(0, 0, 400)
	cam.near = 1.0
	cam.far = 1000.0
	cam.cull_mask = layer
	v.add_child(cam)
	cam.current = true

func _layer(v: SubViewport) -> TextureRect:
	var r := TextureRect.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.texture = v.get_texture()
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	return r

func _tap() -> void:
	_pulse = 0.0
	Sfx.play("reveal_2")
	Sfx.buzz(30)

## the jump a tap gives, `d` seconds after the wave reaches a thing: up quick, settling slow
static func _jump(d: float) -> float:
	if d <= 0.0: return 0.0
	return (d / 0.22) * exp(1.0 - d / 0.22)

## a point of the card's own SubViewport in the holder's space (the card's picture lies flat there, give or take its turn)
func _out(p: Vector2) -> Vector2:
	return _show.position + _off + (card.size + Vector2.ONE * PAD * 2.0) * GROW + p

## the stone's middle, in the holder's space
func _stone() -> Vector2:
	return _out(view.get_global_rect().get_center())

## a touch on the card's picture goes on into its SubViewport, at the same point of the card
func _pass_input(ev: InputEvent) -> void:
	if not is_instance_valid(_cvp) or not _cvp.is_inside_tree(): return
	var e := ev.duplicate()
	var sh := (card.size + Vector2.ONE * PAD * 2.0) * GROW + _off
	if e is InputEventMouse: (e as InputEventMouse).position = (ev as InputEventMouse).position - sh
	if e is InputEventScreenTouch: (e as InputEventScreenTouch).position = (ev as InputEventScreenTouch).position - sh
	if e is InputEventScreenDrag: (e as InputEventScreenDrag).position = (ev as InputEventScreenDrag).position - sh
	_cvp.push_input(e, true)
	_show.accept_event()

func _draw_ring() -> void:
	if _pulse > 1.2: return
	var c := _stone() - _ring.position
	var u := _pulse / 1.2
	var r := 20.0 + u * 360.0
	var a := (1.0 - u) * (1.0 - u)
	for k in 3:
		_ring.draw_arc(c, r - k * 7.0, 0.0, TAU, 96, Color(0.75, 0.9, 1.0, a * (0.5 - k * 0.15)), 3.0 - k, true)

func _process(dt: float) -> void:
	if not is_instance_valid(view) or not is_instance_valid(info) or not is_instance_valid(card):
		queue_free()
		return
	_t += dt
	_pulse += dt
	if test_tap > 0.0:
		_tap_at += dt
		if _tap_at >= test_tap:
			_tap_at = 0.0
			_tap()
	var settled := card.scale.is_equal_approx(Vector2.ONE)
	# 1. the card floats (and jumps on a tap)
	var jump := _jump(_pulse) * 16.0
	var h := (LIFT * (0.55 + 0.45 * sin(_t * 1.15)) + jump) if settled else 0.0
	var off := Vector2(0, -h)
	# turned a few degrees in depth, slowly, as a card hanging in the air; a tap rocks it
	var rock := _jump(_pulse) * 0.06
	var aim := Vector2(0.09 * sin(_t * 0.55) + 0.03 * sin(_t * 1.3 + 1.0), 0.06 * sin(_t * 0.7 + 2.0))
	var g := Input.get_gravity()
	if g.length() > 0.5:
		var n := g.normalized()
		_g0 = n if _g0 == Vector3.ZERO else _g0.lerp(n, minf(1.0, dt * 0.35)).normalized()
		var d := n - _g0
		# (25.11: "a little weaker")
		aim = Vector2(-d.x, d.z) * 0.65 + Vector2(0.015 * sin(_t * 0.55), 0.012 * sin(_t * 0.7 + 2.0))
		aim = aim.clamp(Vector2(-0.18, -0.14), Vector2(0.18, 0.14))
	# a spring: it lags and overshoots a little, as a thing hanging in the air
	_tv += ((aim - _tl) * 38.0 - _tv * 7.0) * dt
	_tl += _tv * dt
	var tilt := (_tl + Vector2(rock, -rock * 0.6)) if settled else Vector2.ZERO
	var full := card.size + Vector2.ONE * PAD * 2.0
	_size_vp()
	# (the inventory's swipe to the next stone slides the holder's children in from the side - the card too, which is in
	# the picture's viewport now: it ended off its place, out of sight - 24.11)
	card.position = Vector2.ONE * PAD
	for n in _halo:
		if is_instance_valid(n) and n is Control and n.get_parent() == _cvp: (n as Control).position = Vector2.ONE * PAD
	# (26.11: the float went in little jerks — a Control's place is snapped to whole pixels) the picture's rect stays
	# put; the float is a shift of the picture inside it, in the shader, and of the shards' cameras
	_off = off
	_show.position = -Vector2.ONE * PAD - full * GROW
	_show.size = full * (Vector2.ONE + GROW * 2.0)
	var tm := _show.material as ShaderMaterial
	tm.set_shader_parameter("shift", off / _show.size)
	tm.set_shader_parameter("grow", GROW)
	tm.set_shader_parameter("tilt", tilt)
	tm.set_shader_parameter("pad", Vector2(PAD / full.x, PAD / full.y))
	# its shadow: under it, further down, wider and paler the higher it is
	_shadow.size = card.size
	_shadow.position = Vector2(0, 10.0 + h * 0.6)
	var sb := _shadow.get_theme_stylebox("panel") as StyleBoxFlat
	sb.shadow_size = int(14.0 + h * 1.6)
	sb.shadow_color = Color(0, 0, 0, clampf(0.6 - h * 0.018, 0.25, 0.6))
	_shadow.visible = settled
	# 2. the shards round the card
	var rect := Rect2(-Vector2.ONE * MARGIN, card.size + Vector2.ONE * MARGIN * 2.0)
	for r in [_back, _front]:
		(r as TextureRect).position = rect.position
		(r as TextureRect).size = rect.size
	var want := Vector2i((rect.size * PX).round())
	for v in [_vb, _vf]:
		if (v as SubViewport).size != want: (v as SubViewport).size = want
		(v as SubViewport).get_camera_3d().size = rect.size.y
		(v as SubViewport).get_camera_3d().position.y = off.y   # (the layer's world is in points, y up: the picture rises)
	_ring.position = Vector2.ZERO
	_ring.size = _holder.size
	var flare := 1.0 + 0.35 * _jump(_pulse - 0.05)
	# a ring just past the card's sides: where a shard goes from behind the card to in front of it (the ring's ends)
	# it is clear of the brass (23.11: switching over the rim it popped up over it); the size of the largest shard
	var rx := (card.size.x * 0.5 + 30.0) * flare
	var ry := card.size.y * 0.1 * flare
	var rz := 200.0
	for sh: Dictionary in _shards:
		sh.a = float(sh.a) + dt * float(sh.speed) * (1.0 + 0.8 * _jump(_pulse))
		var a: float = sh.a
		var rr: float = sh.rr
		# a ring tilted across the card: high on the left at its back, low on the right in front
		var p := Vector3(cos(a) * rx, sin(a) * ry * rr - cos(a) * card.size.y * 0.28 + sin(a * 2.0) * 10.0, sin(a) * rz)
		var mi: MeshInstance3D = sh.node
		var s: float = float(sh.s) * (1.0 + 0.18 * sin(a))   # (nearer, a little bigger)
		# tumbling: a spin about its own axis and a slower roll about another, the faces catching the light in turn
		# (23.11: at under a turn a second it hardly showed); a tap spins it up with the ring
		var sv: Vector3 = sh.spin
		var roll := Vector3(sv.y, sv.z, sv.x).normalized()
		sh.ang = float(sh.get("ang", 0.0)) + dt * sv.length() * (1.0 + 1.5 * _jump(_pulse))
		var b: Basis = (sh.b as Basis) * Basis(sv.normalized(), float(sh.ang)) * Basis(roll, float(sh.ang) * 0.45)
		mi.transform = Transform3D(b.orthonormalized() * Basis.from_scale(Vector3.ONE * s), p)
		mi.layers = FRONT if p.z > 0.0 else BACK
	var active := settled and _shards.size() > 0
	_back.visible = active
	_front.visible = active
	_vb.render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
	_vf.render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
	# 3. inside it: the badges, figures and buttons drift, each in its own time; 4. and jump after the wave
	var stone := _stone()
	var k := 0
	for n in info.find_children("*", "", true, false):
		if not (n is Label or n is Button) or not (n as Control).is_visible_in_tree(): continue
		var c := n as Control
		if c.get_parent() is Button: continue
		k += 1
		var id := c.get_instance_id()
		var ph := float(k) * 1.7
		var dist := _out(c.get_global_rect().get_center()).distance_to(stone)
		var j := _jump(_pulse - dist / 300.0) * 7.0
		var o := Vector2(0.9 * sin(_t * 0.6 + ph), 1.6 * sin(_t * 0.9 + ph * 1.3) - j) if settled else Vector2.ZERO
		var last: Vector2 = _drift.get(id, Vector2.ZERO)
		c.position += o - last
		_drift[id] = o
		c.pivot_offset = c.size / 2.0
		c.rotation = (0.012 * sin(_t * 0.7 + ph)) if settled else 0.0
	_ring.queue_redraw()
