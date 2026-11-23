class_name CardFlies
extends Control
## The cloud of butterflies (SpecSkullFx's flutter: Flock) does not keep to its stone: when the cloud takes off, now and
## then one or two of its butterflies leave the stone's frame and fly out over the card — to settle on a gene's brass
## bar, on the card's top rim, on the ribbon over the info panel or on a button — sit a while slowly working their
## wings, and fly back into the cloud. The very same butterfly: hidden in the stone while it is out, its own model
## (SpecButterfly.MODELS) in a 3D layer of its own over the card (a transparent SubViewport, an orthographic camera
## onto the card's plane), so it looks as it does round the stone.

const PX := 2.5               # the layer's pixels a point
const SPEED := 95.0           # points a second
const EVERY := [3.5, 7.0]     # how often one leaves, while the cloud is up
const OUT_MAX := 3

static var test_every := 0.0  # a test key (-- flies_every=S): one leaves every S s, cloud up or not

var card: Control
var view: SpecView
var info: Control
var flock: Node
var find: Node3D
var _vp: SubViewport
var _world: Node3D
var _rect: TextureRect
var _out := []                # {node, src, kind, ap, clip, span, state, a, b, c1, c2, t, dur, sit, spot, head}
var _next := 2.0
var _taken := []              # the spots sat on now
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
	_world = Node3D.new()
	_vp.add_child(_world)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.position = Vector3(0, 0, 300)
	cam.near = 1.0
	cam.far = 800.0
	_vp.add_child(cam)
	cam.current = true
	# a light like the stone's studio: a key from the top left, a soft fill
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(-0.7, -0.5, 0)
	key.light_energy = 1.4
	_vp.add_child(key)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.72, 0.7)
	e.ambient_light_energy = 0.7
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	_vp.add_child(env)
	_rect = TextureRect.new()
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.texture = _vp.get_texture()
	_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_rect.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(_rect)
	# the butterflies out on the card go home with it closed
	tree_exiting.connect(func() -> void:
		for o: Dictionary in _out:
			if is_instance_valid(o.src): (o.src as Node3D).visible = true)

## the card's plane in the layer's world: a point (x right, y down) to (x right, y up), the card's middle at 0
func _w(p: Vector2) -> Vector3:
	return Vector3(p.x - card.size.x * 0.5, card.size.y * 0.5 - p.y, 0.0)

## a point of the stone's scene on the card (as CardBolt finds its own)
func _proj(w: Vector3) -> Vector2:
	var cam := view.studio.cam
	var k := view.size / Vector2(maxi(1, view.studio.vp.size.x), maxi(1, view.studio.vp.size.y))
	return card.get_global_transform().affine_inverse() * (view.get_global_transform() * (cam.unproject_position(w) * k))

## where one may sit, in the card's space: [point its feet go, how far either side it may sit]: the genes' brass bars,
## the card's top rim, the ribbon over the info panel, the buttons' tops
func _spots() -> Array:
	var to_card := card.get_global_transform().affine_inverse()
	var out := []
	for n in info.find_children("*", "Label", true, false):
		var l := n as Label
		if not l.has_meta("chip") or not l.is_visible_in_tree(): continue
		var r: Rect2 = to_card * l.get_global_transform() * Rect2(Vector2.ZERO, l.size)
		out.append([Vector2(r.get_center().x, r.end.y - 5.0), r.size.x * 0.3])
	for n in info.find_children("*", "Button", true, false):
		var b := n as Button
		if not b.is_visible_in_tree(): continue
		var r: Rect2 = to_card * b.get_global_transform() * Rect2(Vector2.ZERO, b.size)
		out.append([Vector2(r.get_center().x, r.position.y + 3.0), r.size.x * 0.3])
	var ig: Rect2 = to_card * info.get_global_transform() * Rect2(Vector2.ZERO, info.size)
	out.append([Vector2(card.size.x * 0.5, ig.position.y - 20.0 / 3.6), card.size.x * 0.3])
	out.append([Vector2(card.size.x * 0.62, 2.5), card.size.x * 0.25])
	return out

func _model(kind: String, span: float) -> Array:
	var md: Dictionary = SpecButterfly.MODELS[kind]
	var file := String(md.file)
	var model := (load(file if file.begins_with("res://") else SpecButterfly.DIR + file) as PackedScene).instantiate() as Node3D
	var body := Node3D.new()
	var turn := Node3D.new()
	turn.rotation = Vector3(0, float(md.yaw), 0)
	turn.scale = Vector3.ONE * span / float(md.span)
	body.add_child(turn)
	turn.add_child(model)
	if md.has("centre"): model.position = -(md.centre as Vector3)
	if md.has("drop"): model.position.y -= float(md.drop) * float(md.span)
	for nm: String in md.get("hide", []):
		var hn := model.find_child(nm, true, false) as Node3D
		if hn: hn.visible = false
	if md.get("scales", false): SpecButterfly._scales(model, kind)
	_world.add_child(body)
	var ap := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var clip := String((md.clips as Dictionary).get("fly", ""))
	if ap and ap.has_animation(clip):
		var an := ap.get_animation(clip)
		an.loop_mode = Animation.LOOP_LINEAR
		ap.play(clip)
		ap.seek(rng.randf() * an.length, true)
	return [body, ap]

## one of the cloud's flying butterflies leaves the stone for a spot on the card
func _leave() -> void:
	var spots := _spots()
	spots.shuffle()
	var spot: Array = []
	for s: Array in spots:
		var ok := true
		for t: Vector2 in _taken:
			if t.distance_to(s[0]) < 40.0: ok = false
		if ok:
			spot = s
			break
	if spot.is_empty(): return
	var flies := find.find_children("*", "", true, false).filter(func(n: Node) -> bool:
		return n is SpecButterfly.Fly and (n as Node3D).visible and (n as SpecButterfly.Fly).looked and (n as SpecButterfly.Fly).state == SpecButterfly.Fly.FLY)
	if flies.is_empty() and test_every > 0.0:
		flies = find.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n is SpecButterfly.Fly and (n as Node3D).visible)
	if flies.is_empty(): return
	var src: SpecButterfly.Fly = flies[rng.randi() % flies.size()]
	if not SpecButterfly.MODELS.has(src.kind): return
	# its size on the card: its own wingspan seen through the stone's camera
	var a := _proj(src.global_position)
	var side := view.studio.cam.global_transform.basis.x
	var span := clampf(_proj(src.global_position + side * src.size * 2.0).distance_to(a) * 2.2, 26.0, 38.0)
	var m := _model(src.kind, span)
	src.visible = false
	var at: Vector2 = spot[0] + Vector2(rng.randf_range(-1.0, 1.0) * float(spot[1]), 0.0)
	_taken.append(at)
	var o := {node = m[0], ap = m[1], src = src, span = span, state = 0, t = 0.0, sit = rng.randf_range(4.0, 9.0), spot = at}
	_hop(o, a, at)
	_out.append(o)

## a flight from a to b: a curve, rising over its middle, swinging out to one side, as a butterfly goes
func _hop(o: Dictionary, a: Vector2, b: Vector2) -> void:
	o.a = a
	o.b = b
	var d := a.distance_to(b)
	var sway := rng.randf_range(0.25, 0.55) * d * (1.0 if rng.randf() < 0.5 else -1.0)
	var n := (b - a).normalized().orthogonal()
	o.c1 = a.lerp(b, 0.3) + n * sway + Vector2(0, -d * 0.25)
	o.c2 = a.lerp(b, 0.75) - n * sway * 0.4 + Vector2(0, -d * 0.35)
	o.t = 0.0
	o.dur = clampf(d / SPEED, 1.2, 4.0)

func _bez(o: Dictionary, u: float) -> Vector2:
	var a: Vector2 = o.a
	var b: Vector2 = o.b
	var c1: Vector2 = o.c1
	var c2: Vector2 = o.c2
	var v := 1.0 - u
	return a * v * v * v + c1 * 3.0 * v * v * u + c2 * 3.0 * v * u * u + b * u * u * u

func _process(dt: float) -> void:
	if not is_instance_valid(view) or not is_instance_valid(flock) or not is_instance_valid(info):
		queue_free()
		return
	_rect.position = Vector2.ZERO - position
	_rect.size = card.size
	var want := Vector2i((card.size * PX).round())
	if _vp.size != want: _vp.size = want
	var cam := _vp.get_camera_3d()
	cam.size = card.size.y
	# one leaves now and then while the cloud is up (Flock's phase 1), never too many out at once
	if view.is_visible_in_tree() and card.scale.is_equal_approx(Vector2.ONE):
		_next -= dt
		var up := int(flock.get("phase")) == 1 or test_every > 0.0
		if _next <= 0.0 and up and _out.size() < OUT_MAX:
			_leave()
			_next = test_every if test_every > 0.0 else rng.randf_range(EVERY[0], EVERY[1])
	for k in range(_out.size() - 1, -1, -1):
		var o: Dictionary = _out[k]
		var body: Node3D = o.node
		var ap: AnimationPlayer = o.ap
		o.t = float(o.t) + dt
		var p: Vector2
		var face := Vector3(1, 0, 0)
		if int(o.state) == 0 or int(o.state) == 2:
			# flying: along its curve, eased in and out, bobbing with its wingbeat
			var u := clampf(float(o.t) / float(o.dur), 0.0, 1.0)
			var e := u * u * (3.0 - 2.0 * u)
			p = _bez(o, e)
			var ahead := _bez(o, minf(1.0, e + 0.02))
			var dir := ahead - p
			p.y += sin(float(o.t) * 11.0) * 2.2 * (1.0 - smoothstep(0.85, 1.0, u))
			if absf(dir.x) > 0.01: face = Vector3(signf(dir.x), 0, 0)
			o.face_x = face.x
			if ap: ap.speed_scale = 1.0
			if u >= 1.0:
				if int(o.state) == 0:
					o.state = 1
					o.t = 0.0
				else:
					# home: the stone's own butterfly takes over again
					if is_instance_valid(o.src): (o.src as Node3D).visible = true
					_taken.erase(o.spot)
					body.queue_free()
					_out.remove_at(k)
					continue
		else:
			# sitting: its wings working slowly, open and shut in the sun
			p = o.spot
			face = Vector3(float(o.get("face_x", 1.0)), 0, 0)
			if ap: ap.speed_scale = 0.16
			if float(o.t) >= float(o.sit):
				# back to its cloud: where its stone twin is now
				o.state = 2
				var home := _proj((o.src as Node3D).global_position) if is_instance_valid(o.src) else Vector2(card.size.x * 0.5, card.size.y * 0.35)
				_hop(o, o.spot, home)
				_taken.erase(o.spot)
		# turned three-quarters to the viewer, the way it goes; nose up a little in flight
		var heading := (face + Vector3(0, 0, 0.7)).normalized()
		var pitch := 0.0 if int(o.state) == 1 else 0.18
		body.transform = Transform3D(Basis.looking_at(-heading, Vector3.UP) * Basis(Vector3.RIGHT, pitch), _w(p))
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if _out.size() else SubViewport.UPDATE_DISABLED
	_rect.visible = _out.size() > 0
