class_name CardFlies
extends Control
## The cloud of butterflies (SpecSkullFx's flutter: Flock) does not keep to its stone: when the cloud takes off, now and
## then one or two of its butterflies leave the stone's frame and fly out over the card — to settle on the top of a
## button, of the info panel's frame (the ribbon) or of the card itself — sit a while opening their wings to the sun,
## and fly back into the cloud. The very same butterfly: hidden in the stone while it is out, a butterfly of its kind
## in a 3D layer of its own over the card (a transparent SubViewport). It flies and lands as the trailer's did
## (tests/butterfly_flight): SpecButterfly's own Fly, its own approach, landing, sitting and take-off, onto a spot
## facing up, the camera looking a little down on it — a butterfly on a ledge seen dead level was a thin line.

const PX := 2.5               # the layer's pixels a point
const PITCH := 0.35           # the camera's look down (as the trailer's)
const SPAN := 40.0            # its wingspan on the card, in points
const EVERY := [0.7, 1.8]     # how often one leaves, while the cloud is up
const OUT_MIN := 3            # (24.11: a cloud - 3..6 out, two or three on one button)
const OUT_MAX := 6
## how likely each kind of spot: a button, the ribbon, the card's top (24.11: the top was one of five spots, never seen)
const SPOT_W := [1.0, 1.0, 1.6]

static var test_every := 0.0  # a test key (-- flies_every=S): one leaves every S s, cloud up or not
static var test_spot := -1    # a test key (-- flies_spot=0|1|2): only there - a button, the ribbon, the card's top
## the layer reaches this far past the card on every side: one sitting on the card's very top stands out over it (23.11:
## the layer the card's size cut it off at its edge) — and further above it: taking off from the card's top it climbs
## (23.11: cut off at 60 points up)
const MARGIN := 50.0
const MARGIN_TOP := 190.0

var card: Control
var view: SpecView
var info: Control
var flock: Node
var find: Node3D
var _vp: SubViewport
var _hold: Node3D
var _rect: TextureRect
## (24.11: "from under the skull, and back there") one still behind the skull is drawn in a layer of its own (_vpb,
## the same world seen by a camera of the hidden ones' visual layer), cut by the skull's silhouette: the find drawn
## again unshaded on a clear background by the stone's own camera (_mvp) - only while one is behind it
var _vpb: SubViewport
var _rectb: TextureRect
var _mvp: SubViewport
var _mcam: Camera3D
var _out := []                # {fb, src, spot (card point), from, stage, t}
var _next := 2.0
var rng := RandomNumberGenerator.new()

## p: the built find; only one with the cloud of butterflies (SpecSkullFx's Flock)
static func attach(card_: Control, view_: SpecView, info_: Control, p: Node3D) -> void:
	var found := p.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n is SpecSkullFx.Flock)
	if found.is_empty(): return
	var cf := CardFlies.new()
	cf.card = card_
	cf.view = view_
	cf.info = info_
	cf.flock = found[0]
	cf.find = p
	card_.add_child(cf)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 6
	rng.randomize()
	_vp = SubViewport.new()
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_vp)
	# the butterflies' own "find": nothing in it (Fly looks round its find for a box and things to keep out of)
	_hold = Node3D.new()
	_hold.set_meta("grown", {})
	_vp.add_child(_hold)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.position = Vector3(0, sin(PITCH), cos(PITCH)) * 400.0
	cam.near = 1.0
	cam.far = 1000.0
	_vp.add_child(cam)
	cam.look_at(Vector3.ZERO)
	cam.current = true
	# the trailer's light: a warm key from above, a cool rim behind, a soft ambient
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_color = Color(0.45, 0.45, 0.5)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.environment = e
	_vp.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(-0.9, 0.5, 0)
	key.light_color = Color(1.0, 0.93, 0.82)
	key.light_energy = 1.3
	_vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation = Vector3(-0.3, PI + 0.4, 0)
	rim.light_color = Color(0.6, 0.75, 1.0)
	rim.light_energy = 0.8
	_vp.add_child(rim)
	_rect = TextureRect.new()
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.texture = _vp.get_texture()
	_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_rect.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(_rect)
	cam.cull_mask = 1
	_vpb = SubViewport.new()
	_vpb.transparent_bg = true
	_vpb.msaa_3d = Viewport.MSAA_4X
	_vpb.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_vpb)
	_vpb.world_3d = _vp.find_world_3d()
	var camb := Camera3D.new()
	camb.projection = Camera3D.PROJECTION_ORTHOGONAL
	camb.near = 1.0
	camb.far = 1000.0
	camb.cull_mask = 2
	_vpb.add_child(camb)
	camb.current = true
	_rectb = TextureRect.new()
	_rectb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rectb.texture = _vpb.get_texture()
	_rectb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_rectb.stretch_mode = TextureRect.STRETCH_SCALE
	var bm := ShaderMaterial.new()
	bm.shader = preload("res://shaders/fly_behind.gdshader")
	_rectb.material = bm
	_rectb.visible = false
	add_child(_rectb)
	_mvp = SubViewport.new()
	_mvp.transparent_bg = true
	_mvp.debug_draw = Viewport.DEBUG_DRAW_UNSHADED
	_mvp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_mvp)
	_mvp.world_3d = view.studio.vp.find_world_3d()
	_mcam = Camera3D.new()
	# (its own clear background: with the studio's sky the mask was solid)
	var me := Environment.new()
	me.background_mode = Environment.BG_CLEAR_COLOR
	_mcam.environment = me
	_mcam.cull_mask = 0xFFFFF & ~SpecStudio.BACKDROP   # (not the studio's haze behind the find)
	_mvp.add_child(_mcam)
	_mcam.current = true
	bm.set_shader_parameter("mask", _mvp.get_texture())
	# the butterflies out on the card go home with it closed
	tree_exiting.connect(func() -> void:
		for o: Dictionary in _out:
			if is_instance_valid(o.src):
				(o.src as Node3D).visible = true
				_fade(o.src, 0.0))

## a card point (x right, y down) into the layer's world: a vertical plane through 0, its height stretched by the
## camera's tilt (an orthographic look down shortens it so much) — the card's middle at 0
func _w(p: Vector2) -> Vector3:
	return Vector3(p.x - card.size.x * 0.5, (card.size.y * 0.5 - p.y) / cos(PITCH), 0.0)

## a point of the stone's scene on the card (as CardBolt finds its own)
func _proj(w: Vector3) -> Vector2:
	var cam := view.studio.cam
	var k := view.size / Vector2(maxi(1, view.studio.vp.size.x), maxi(1, view.studio.vp.size.y))
	return card.get_global_transform().affine_inverse() * (view.get_global_transform() * (cam.unproject_position(w) * k))

## where one may sit, in the card's space: [the point it is set down at, how far either side]: the buttons' tops, the
## top of the info panel's frame (the ribbon), the card's very top — a few points below each edge: seen from a little
## above, its body sits over its feet, and set on the edge itself it hung clear of it
func _spots() -> Array:
	var to_card := card.get_global_transform().affine_inverse()
	var out := []
	for n in info.find_children("*", "Button", true, false):
		var b := n as Button
		if not b.is_visible_in_tree(): continue
		var r: Rect2 = to_card * b.get_global_transform() * Rect2(Vector2.ZERO, b.size)
		out.append([Vector2(r.get_center().x, r.position.y + 3.5), r.size.x * 0.4, 0])
	var ig: Rect2 = to_card * info.get_global_transform() * Rect2(Vector2.ZERO, info.size)
	out.append([Vector2(card.size.x * 0.5, ig.position.y - 1.5), (ig.size.x - Reveal.INFO_R * 2.0) * 0.42, 1])
	out.append([Vector2(card.size.x * 0.6, 2.0), card.size.x * 0.3, 2])
	if test_spot >= 0: out = out.filter(func(q: Array) -> bool: return int(q[2]) == test_spot)
	return out

## one of the cloud's flying butterflies leaves the stone for a spot on the card
func _leave() -> void:
	var spots := _spots()
	spots.shuffle()
	# a kind of spot first, by its weight, then its spots first
	var wsum := 0.0
	for w: float in SPOT_W: wsum += w
	var pick := rng.randf() * wsum
	var kind := 0
	while kind < 2 and pick > float(SPOT_W[kind]):
		pick -= float(SPOT_W[kind])
		kind += 1
	spots.sort_custom(func(a: Array, b: Array) -> bool: return int(int(a[2]) == kind) > int(int(b[2]) == kind))
	# (most often to where one or two already sit: two or three together on a button - 24.11, "a cloud")
	if rng.randf() < 0.7:
		var company := spots.filter(func(q: Array) -> bool:
			var n := 0
			for o: Dictionary in _out:
				if (o.spot as Vector2).distance_to(q[0]) <= float(q[1]) + SPAN: n += 1
			return n >= 1 and n <= 2)
		if company.size(): spots = company + spots
	var at := Vector2.INF
	for s: Array in spots:
		var q: Vector2 = s[0] + Vector2(rng.randf_range(-1.0, 1.0) * float(s[1]), 0.0)
		var ok := true
		for o: Dictionary in _out:
			if (o.spot as Vector2).distance_to(q) < SPAN * 0.7: ok = false
		if ok:
			at = q
			break
	if at == Vector2.INF: return
	var flies := find.find_children("*", "", true, false).filter(func(n: Node) -> bool:
		return n is SpecButterfly.Fly and (n as Node3D).visible and (n as SpecButterfly.Fly).looked and (n as SpecButterfly.Fly).state == SpecButterfly.Fly.FLY)
	# (the cloud down on the skull: one of those resting takes off from it - 24.11, they left only while the cloud was up)
	if flies.is_empty():
		flies = find.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n is SpecButterfly.Fly and (n as Node3D).visible)
	if flies.is_empty(): return
	# one round the back of the skull, if any: it comes out from behind it (23.11: the swap in mid-air was abrupt)
	var cam := view.studio.cam
	var deep := func(w: Vector3) -> float: return -(cam.global_transform.affine_inverse() * w).z
	var mid: float = deep.call(find.global_position)
	var behind := flies.filter(func(n: Node) -> bool: return float(deep.call((n as Node3D).global_position)) > mid)
	if behind.size(): flies = behind
	var src: SpecButterfly.Fly = flies[rng.randi() % flies.size()]
	if not SpecButterfly.KINDS.has(src.kind): return
	var land := _w(at)
	var fb := SpecButterfly.put(_hold, Rng32.new(rng.randi() % 99999), src.kind, land, Vector3.UP,
			SPAN / float(SpecButterfly.KINDS[src.kind].span) / maxf(SpecButterfly.fly_big, 0.01), false, [[land, Vector3.UP]]) as SpecButterfly.Fly
	fb.visible = false
	_out.append({fb = fb, src = src, spot = at, from = _proj(src.global_position), stage = 0, t = 0.0, fade = 0.0})

## how wide the stone's butterfly is on the card now, in points: its model's own wingspan (MODELS' span, times the
## model holder's scale in the stone's world) seen through the stone's camera at where it is (23.11: measured by the
## Fly's size, the card's came out half the size of the stone's)
func _twin_span(src: Node3D) -> float:
	var f := src as SpecButterfly.Fly
	var turn := f.get_child(0) as Node3D
	var wide := turn.global_transform.basis.get_scale().x * float(SpecButterfly.MODELS[f.kind].span)
	var side := view.studio.cam.global_transform.basis.x
	return maxf(4.0, _proj(src.global_position + side * wide).distance_to(_proj(src.global_position)))

## the card butterfly's own wingspan in points at k 1 (the layer's world is in points, its camera orthographic)
func _own_span(fb: SpecButterfly.Fly) -> float:
	var turn := fb.get_child(0) as Node3D
	var s0: Vector3 = turn.get_meta("s0") if turn.has_meta("s0") else turn.scale
	return s0.x * float(SpecButterfly.MODELS[fb.kind].span)

## where one going home hands over to its twin: past the skull's edge on the side it comes from, a little behind the
## skull's middle and a little up — in the stone's world
func _door(fb: SpecButterfly.Fly) -> Vector3:
	var b := view.studio.cam.global_transform.basis
	var c := find.global_position
	var rad := 0.3
	for n in find.find_children("*", "", true, false):
		if n is SpecButterfly.Fly and (n as SpecButterfly.Fly).box.size.length() > 0.0:
			var bx: AABB = (n as SpecButterfly.Fly).box
			c = find.global_transform * bx.get_center()
			rad = (bx.size * find.global_transform.basis.get_scale()).length() * 0.32
			break
	# (straight behind its middle: the card one flies in under the skull's silhouette, and there, hidden, hands over)
	return c - b.z * rad * 0.9 + b.y * rad * 0.1

## its twin at the door, still and hidden (go: and now on, in behind the skull's middle, which hides it)
func _pin(n: Node3D, at: Vector3, go: bool) -> void:
	var f := n as SpecButterfly.Fly
	var par := f.get_parent() as Node3D
	f.pos = par.to_local(at)
	f.global_position = at
	f.state = SpecButterfly.Fly.FLY
	if not go:
		f.vel = Vector3.ZERO
		return
	var b := view.studio.cam.global_transform.basis
	var off := (at - find.global_position).dot(b.x)
	var behind := par.to_local(at - b.x * off * 1.3 - b.z * 0.2)
	f.vel = (behind - f.pos).normalized() * f.size * 3.0
	f.way = behind
	f.far = false
	f.retarget = 2.5
	f.dwell = 2.5
	f.beats_left = 6

## a card butterfly behind the skull (drawn in the cut layer) or out over the card
static func _behind(fb: Node, on: bool) -> void:
	for g in fb.find_children("*", "VisualInstance3D", true, false):
		(g as VisualInstance3D).layers = 2 if on else 1

## a card butterfly's place on the card (the layer's world back to the card's points)
func _cp(w: Vector3) -> Vector2:
	return Vector2(w.x + card.size.x * 0.5, card.size.y * 0.5 - w.y * cos(PITCH))

## the skull on the card: its find's box seen through the stone's camera
func _skull_rect() -> Rect2:
	var bx := AABB()
	for n in find.find_children("*", "", true, false):
		if n is SpecButterfly.Fly and (n as SpecButterfly.Fly).box.size.length() > 0.0:
			bx = (n as SpecButterfly.Fly).box
			break
	if bx.size.length() == 0.0: return Rect2()
	var r := Rect2(_proj(find.global_transform * bx.position), Vector2.ZERO)
	for i in 8:
		r = r.expand(_proj(find.global_transform * bx.get_endpoint(i)))
	return r

## a butterfly's see-through-ness: 0 solid .. 1 gone (every mesh of it)
static func _fade(n: Node, a: float) -> void:
	for g in n.find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).transparency = a

## the card butterfly's size: k of its own (its model's holder, under the Fly, which sets the Fly's own transform)
func _size(fb: Node3D, k: float) -> void:
	var turn := fb.get_child(0) as Node3D
	if not turn.has_meta("s0"): turn.set_meta("s0", turn.scale)
	turn.scale = (turn.get_meta("s0") as Vector3) * k

func _process(dt: float) -> void:
	if not is_instance_valid(view) or not is_instance_valid(flock) or not is_instance_valid(info):
		queue_free()
		return
	# over the card and MARGIN past it all round, MARGIN_TOP above; the camera looks at the rect's middle (_w is the
	# card's: its middle at 0)
	_rect.position = -position - Vector2(MARGIN, MARGIN_TOP)
	_rect.size = card.size + Vector2(MARGIN * 2.0, MARGIN + MARGIN_TOP)
	var want := Vector2i((_rect.size * PX).round())
	if _vp.size != want: _vp.size = want
	var cam := _vp.get_camera_3d()
	cam.size = _rect.size.y
	var cam_up := cam.global_transform.basis.y
	cam.position = Vector3(0, sin(PITCH), cos(PITCH)) * 400.0 + cam_up * (MARGIN_TOP - MARGIN) * 0.5
	var any_b := false
	for o: Dictionary in _out:
		if bool(o.get("behind", false)): any_b = true
	_rectb.visible = any_b
	_vpb.render_target_update_mode = SubViewport.UPDATE_ALWAYS if any_b else SubViewport.UPDATE_DISABLED
	_mvp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if any_b else SubViewport.UPDATE_DISABLED
	if any_b:
		_rectb.position = _rect.position
		_rectb.size = _rect.size
		if _vpb.size != _vp.size: _vpb.size = _vp.size
		var camb := _vpb.get_camera_3d()
		camb.size = cam.size
		camb.global_transform = cam.global_transform
		var sc := view.studio.cam
		_mcam.global_transform = sc.global_transform
		_mcam.projection = sc.projection
		_mcam.fov = sc.fov
		_mcam.size = sc.size
		_mcam.keep_aspect = sc.keep_aspect
		_mcam.near = sc.near
		_mcam.far = sc.far
		_mcam.h_offset = sc.h_offset
		_mcam.v_offset = sc.v_offset
		var ms := Vector2i(maxi(2, view.studio.vp.size.x / 2), maxi(2, view.studio.vp.size.y / 2))
		if _mvp.size != ms: _mvp.size = ms
		var bm := _rectb.material as ShaderMaterial
		var vr := Rect2(view.global_position - _rectb.global_position, view.size)
		bm.set_shader_parameter("view_rect", Vector4(vr.position.x, vr.position.y, vr.size.x, vr.size.y))
		bm.set_shader_parameter("lsize", _rectb.size)
	var skull := _skull_rect()
	# one leaves now and then while the cloud is up (Flock's phase 1), never too many out at once
	if view.is_visible_in_tree() and card.scale.is_equal_approx(Vector2.ONE):
		_next -= dt
		var up := true
		if _next <= 0.0 and up and _out.size() < OUT_MAX:
			_leave()
			_next = test_every if test_every > 0.0 else (rng.randf_range(0.4, 0.9) if _out.size() < OUT_MIN else rng.randf_range(EVERY[0], EVERY[1]))
	for k in range(_out.size() - 1, -1, -1):
		var o: Dictionary = _out[k]
		var fb: SpecButterfly.Fly = o.fb
		o.t = float(o.t) + dt
		match int(o.stage):
			0:
				# once it has looked round (its first frame): in the air where its stone twin was, landing on the spot
				# (the trailer's way: its own approach and landing)
				if not fb.looked: continue
				var land := _w(o.spot)
				fb.pos = _w(o.from)
				fb.vel = (land - fb.pos).normalized() * fb.size * 3.0
				fb.yaw = atan2(fb.vel.x, fb.vel.z)
				fb.state = SpecButterfly.Fly.LAND
				fb.spot = [land, Vector3.UP]
				fb.land_key = Vector3.INF
				fb._m_play("fly", 0.0, 0.0, 0.0)
				fb.visible = true
				# the stone's own size: it stays so all the way (23.11: grown to a size of its own it looked small)
				o.k0 = clampf(_twin_span(o.src) / _own_span(fb), 0.2, 3.0)
				_size(fb, o.k0)
				# it takes its twin's place at once, behind the skull as its twin was, and comes out from under it
				_fade(fb, 0.0)
				# (behind the skull only if its twin was: one in front of it comes out in front)
				var ct := view.studio.cam.global_transform.affine_inverse()
				var back := is_instance_valid(o.src) and -(ct * (o.src as Node3D).global_position).z > -(ct * find.global_position).z
				_behind(fb, back)
				o.behind = back
				if is_instance_valid(o.src): (o.src as Node3D).visible = false
				o.stage = 1
				o.t = 0.0
			1:
				# out from under the skull: over the card once clear of its silhouette
				if bool(o.behind) and not skull.grow(SPAN * 0.3).has_point(_cp(fb.pos)):
					o.behind = false
					_behind(fb, false)
				_size(fb, float(o.k0))
				if fb.state == SpecButterfly.Fly.SIT:
					fb.timer = rng.randf_range(6.0, 12.0)
					o.stage = 2
				elif float(o.t) > 9.0:
					o.stage = 3   # (never got down: home)
			2:
				# sitting: warming its wings, as it landed (23.11: no turning round on the spot - it looked odd)
				_size(fb, float(o.k0))
				if fb.state == SpecButterfly.Fly.OFF or fb.state == SpecButterfly.Fly.FLY:
					o.stage = 3
					o.t = 0.0
			3:
				# home: in behind the skull (24.11: melting into its twin in mid-air it simply vanished) — its twin waits,
				# hidden, at a door just past the skull's edge and a little behind it; the card one flies there, hands over
				# to it, and the twin flies on behind the skull, which hides it
				if not o.has("door"): o.door = _door(fb)
				if is_instance_valid(o.src): _pin(o.src, o.door, false)
				# first to a point just past the skull's side (there it goes behind: nothing of the skull covers it yet),
				# then in behind its middle - the skull's silhouette closing over it (24.11: gone behind while over the
				# skull's front, it vanished at once)
				var sk_c := skull.get_center()
				if not o.has("edge"):
					var sd := 1.0 if _cp(fb.pos).x >= sk_c.x else -1.0
					o.edge = Vector2(sk_c.x + sd * (skull.size.x * 0.5 + SPAN * 0.35), sk_c.y - skull.size.y * 0.15)
				var home := _w(_proj(o.door)) if bool(o.get("behind", false)) else _w(o.edge)
				if fb.state == SpecButterfly.Fly.FLY:
					fb.beats_left = 9
					fb.want_glide = false
					fb.way = home
					fb.far = true
					fb.retarget = 99.0
					fb.dwell = 99.0
					fb.timer = 99.0
				# shrinking back to its twin's size as it nears it, and melting into it
				var kt := clampf(_twin_span(o.src) / _own_span(fb), 0.2, 3.0) if is_instance_valid(o.src) else float(o.k0)
				var dist := fb.pos.distance_to(home)
				_size(fb, lerpf(kt, float(o.k0), clampf(dist / (SPAN * 3.0), 0.0, 1.0)))
				if not bool(o.get("behind", false)):
					if dist < SPAN * 0.4 or float(o.t) > 5.0:
						o.behind = true
						_behind(fb, true)
				elif dist < fb.size * 1.2 or float(o.t) > 8.0:
					# hidden behind the skull: its twin takes over there, at once, and flies on behind it
					o.stage = 4
					o.t = 0.0
					if is_instance_valid(o.src):
						_pin(o.src, o.door, true)
						(o.src as Node3D).visible = true
						_fade(o.src, 0.0)
					_fade(fb, 1.0)
			4:
				var f := 1.0
				_fade(fb, f)
				if is_instance_valid(o.src): _fade(o.src, 1.0 - f)
				if f >= 1.0:
					fb.queue_free()
					_out.remove_at(k)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if _out.size() else SubViewport.UPDATE_DISABLED
	_rect.visible = _out.size() > 0
