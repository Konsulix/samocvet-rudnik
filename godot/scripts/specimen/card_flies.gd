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
const EVERY := [3.5, 7.0]     # how often one leaves, while the cloud is up
const OUT_MAX := 3

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
		out.append([Vector2(r.get_center().x, r.position.y + 3.5), r.size.x * 0.32, 0])
	var ig: Rect2 = to_card * info.get_global_transform() * Rect2(Vector2.ZERO, info.size)
	out.append([Vector2(card.size.x * 0.5, ig.position.y - 1.5), (ig.size.x - Reveal.INFO_R * 2.0) * 0.42, 1])
	out.append([Vector2(card.size.x * 0.6, 2.0), card.size.x * 0.3, 2])
	if test_spot >= 0: out = out.filter(func(q: Array) -> bool: return int(q[2]) == test_spot)
	return out

## one of the cloud's flying butterflies leaves the stone for a spot on the card
func _leave() -> void:
	var spots := _spots()
	spots.shuffle()
	var at := Vector2.INF
	for s: Array in spots:
		var q: Vector2 = s[0] + Vector2(rng.randf_range(-1.0, 1.0) * float(s[1]), 0.0)
		var ok := true
		for o: Dictionary in _out:
			if (o.spot as Vector2).distance_to(q) < SPAN * 1.5: ok = false
		if ok:
			at = q
			break
	if at == Vector2.INF: return
	var flies := find.find_children("*", "", true, false).filter(func(n: Node) -> bool:
		return n is SpecButterfly.Fly and (n as Node3D).visible and (n as SpecButterfly.Fly).looked and (n as SpecButterfly.Fly).state == SpecButterfly.Fly.FLY)
	if flies.is_empty() and test_every > 0.0:
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
	# one leaves now and then while the cloud is up (Flock's phase 1), never too many out at once
	if view.is_visible_in_tree() and card.scale.is_equal_approx(Vector2.ONE):
		_next -= dt
		var up := int(flock.get("phase")) == 1 or test_every > 0.0
		if _next <= 0.0 and up and _out.size() < OUT_MAX:
			_leave()
			_next = test_every if test_every > 0.0 else rng.randf_range(EVERY[0], EVERY[1])
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
				_fade(fb, 1.0)
				o.stage = 1
				o.t = 0.0
			1:
				# out of its twin: the stone's one melts away as this one comes up in its place, its size, growing to its
				# own on the way
				var f := clampf(float(o.t) / 0.4, 0.0, 1.0)
				_fade(fb, 1.0 - f)
				if is_instance_valid(o.src):
					_fade(o.src, f)
					if f >= 1.0: (o.src as Node3D).visible = false
				_size(fb, float(o.k0))
				if fb.state == SpecButterfly.Fly.SIT:
					fb.timer = rng.randf_range(4.0, 9.0)
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
				# home: straight for its stone twin, flapping all the way, never down again
				var home := _w(_proj((o.src as Node3D).global_position) if is_instance_valid(o.src) else o.from)
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
				if dist < fb.size * 1.5 or float(o.t) > 7.0:
					o.stage = 4
					o.t = 0.0
					if is_instance_valid(o.src):
						(o.src as Node3D).visible = true
						_fade(o.src, 1.0)
			4:
				var f := clampf(float(o.t) / 0.4, 0.0, 1.0)
				_fade(fb, f)
				if is_instance_valid(o.src): _fade(o.src, 1.0 - f)
				if f >= 1.0:
					fb.queue_free()
					_out.remove_at(k)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if _out.size() else SubViewport.UPDATE_DISABLED
	_rect.visible = _out.size() > 0
