class_name CardJelly
extends Control
## (26.11) The jellyfish legend (SpecJelly) out of its window, and the card under water — the two things a legendary card
## does (out past the stone's frame; the interface played with):
##  - now and then one of the stone's jellyfish swims out of the window over the card, its bell pulsing, wanders over
##    the info panel and the brass a while and swims back into the stone (hidden there while it is out: the same one).
##    A 3D layer of its own over the card (SpecJelly's own meshes), added to the card as light.
##  - the info panel is sunk in deep water: over its slate, under its words, a blue-green dusk with the sun's caustics
##    running over it (card_water.gdshader), kelp swaying up from its foot (the sea floor's scans, SpecReef, in a layer
##    of their own), the light of a jellyfish over it pooling on the slate; its buttons, figures and badges bob as if
##    afloat.
##  - a tap on a jellyfish: it flinches, flashes and darts off; a tap on the panel sends rings through its water.

const PX := 2.0               # the layer's pixels a point
const MARGIN := 40.0          # the jellyfish layer reaches this far past the card
const EVERY := [3.5, 7.0]     # how often one swims out
const MAX_OUT := 2
const SPEED := 42.0           # its drift, points a second
const STAY := [7.0, 11.0]     # how long it stays out

static var test_every := 0.0  # a test key (-- jelly_every=S): one swims out every S s
static var test_tap := 0.0    # a test key (-- jelly_tap=S): at S s a tap on the first one out, and one on the panel

var card: Control
var view: SpecView
var info: Control
var find: Node3D
var _src: Array[Node3D] = []  # the stone's jellyfish
var _vp: SubViewport
var _cam: Camera3D
var _rect: TextureRect
var _kvp: SubViewport
var _krect: TextureRect
var _water: ColorRect
var _out := []                # {node, src, pos, vel, goal, t, life, size, col, back, mats, dart}
var _next := 2.0
var _t := 0.0
var _drift := {}
var _rips := []               # [x, y, age]
var rng := RandomNumberGenerator.new()

## p: the built find; only one with jellyfish round it (SpecJelly.swarm)
static func attach(card_: Control, view_: SpecView, info_: Control, p: Node3D) -> void:
	var src: Array[Node3D] = []
	for n in p.find_children("*", "MeshInstance3D", true, false):
		var m := (n as MeshInstance3D).material_override as ShaderMaterial
		if m and m.shader and m.shader == SpecJelly._shader and int(m.get_shader_parameter("part")) == 0:
			var j := n.get_parent() as Node3D
			if j and not j in src: src.append(j)
	if src.is_empty(): return
	var cj := CardJelly.new()
	cj.card = card_
	cj.view = view_
	cj.info = info_
	cj.find = p
	cj._src = src
	card_.add_child(cj)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 6
	rng.randomize()
	for ar in OS.get_cmdline_user_args():
		if ar.begins_with("jelly_every="): test_every = float(ar.get_slice("=", 1))
		if ar.begins_with("jelly_tap="): test_tap = float(ar.get_slice("=", 1))
	if test_every > 0.0: _next = 1.0
	# the jellyfish's layer: black, its light added to the card (FxLayer's additive)
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_vp)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color.BLACK
	env.environment = e
	_vp.add_child(env)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.position = Vector3(0, 0, 400)
	_cam.near = 1.0
	_cam.far = 1000.0
	_vp.add_child(_cam)
	_cam.current = true
	_rect = TextureRect.new()
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.texture = _vp.get_texture()
	_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_rect.material = FxLayer.add_material()
	_rect.visible = false
	add_child(_rect)
	_build_panel()
	tree_exiting.connect(func() -> void:
		for o: Dictionary in _out:
			if is_instance_valid(o.src): (o.src as Node3D).visible = true
		if is_instance_valid(_water): _water.queue_free()
		if is_instance_valid(_krect): _krect.queue_free())

## the panel's water and its kelp: under the words, over the slate (as the frost's and the lava's layers lie)
func _build_panel() -> void:
	_kvp = SubViewport.new()
	_kvp.own_world_3d = true
	_kvp.transparent_bg = true
	_kvp.msaa_3d = Viewport.MSAA_2X
	_kvp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_kvp)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.35, 0.6, 0.65)
	e.ambient_light_energy = 0.8
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.environment = e
	_kvp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-1.1, 0.3, 0)
	sun.light_color = Color(0.7, 0.95, 1.0)
	sun.light_energy = 1.1
	_kvp.add_child(sun)
	var kc := Camera3D.new()
	kc.projection = Camera3D.PROJECTION_ORTHOGONAL
	kc.position = Vector3(0, 0, 50)
	kc.near = 0.1
	kc.far = 200.0
	kc.name = "cam"
	_kvp.add_child(kc)
	kc.current = true
	# kelp from the foot of the panel: a frond or two at each side, of the sea floor's weeds
	var picks := ["weed_kelp", "weed_claret", "weed_wiggle"]
	for k in 4:
		var id: String = picks[rng.randi() % picks.size()]
		var mi := MeshInstance3D.new()
		mi.mesh = SpecReef.mesh(id)
		var m := SpecReef.mat(id).duplicate() as ShaderMaterial
		m.set_shader_parameter("sway", 0.12)
		mi.material_override = m
		mi.set_meta("side", -1.0 if k < 2 else 1.0)
		mi.set_meta("k", k % 2)
		_kvp.add_child(mi)
	_krect = TextureRect.new()
	_krect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_krect.texture = _kvp.get_texture()
	_krect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_krect.stretch_mode = TextureRect.STRETCH_SCALE
	_krect.modulate = Color(0.75, 1.0, 0.95, 1.0)
	info.add_child(_krect)
	info.move_child(_krect, mini(1, info.get_child_count() - 1))
	_water = ColorRect.new()
	_water.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var wm := ShaderMaterial.new()
	wm.shader = preload("res://shaders/card_water.gdshader")
	_water.material = wm
	info.add_child(_water)
	info.move_child(_water, mini(2, info.get_child_count() - 1))
	_layout_panel()

func _layout_panel() -> void:
	var sz := info.size
	if sz.x <= 0.0: return
	for n: Control in [_krect, _water]:
		n.position = Vector2.ZERO
		n.size = sz
	_kvp.size = Vector2i(sz * PX)
	var kc := _kvp.get_node("cam") as Camera3D
	kc.size = sz.y
	# the kelp stands on the panel's foot, near its sides, a little in (in points: x right, y up from the middle)
	var i := 0
	for mi in _kvp.get_children():
		if not mi is MeshInstance3D: continue
		var m := mi as MeshInstance3D
		var bb := m.mesh.get_aabb()
		var side := float(m.get_meta("side"))
		var kk := int(m.get_meta("k"))
		var h := sz.y * (0.95 if kk == 0 else 0.7)
		var s := h / maxf(bb.size.y, 0.001)
		var x := side * (sz.x * 0.5 - (14.0 if kk == 0 else 42.0))
		m.transform = Transform3D(Basis(Vector3.UP, 0.4 + i * 1.3).scaled(Vector3.ONE * s), Vector3(x, -sz.y * 0.5 - bb.position.y * s - 4.0, -10.0 - i))
		i += 1
	var wm := _water.material as ShaderMaterial
	wm.set_shader_parameter("rsize", sz)

## the card's point (its own space) of a place in the stone's world
func _on_card(world: Vector3) -> Vector2:
	var studio: SpecStudio = view.studio
	var vs := Vector2(studio.vp.size)
	var k := vs.x / maxf(view.size.x, 1.0)
	var px := studio.cam.unproject_position(world) / k
	return view.get_global_rect().position + px - card.get_global_rect().position

## the layer's world point of a card point
func _w(p: Vector2) -> Vector3:
	return Vector3(p.x - card.size.x * 0.5, -(p.y - card.size.y * 0.5), 0.0)

func _input(ev: InputEvent) -> void:
	var press: bool = (ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT) \
		or (ev is InputEventScreenTouch and (ev as InputEventScreenTouch).pressed)
	if not press or not is_instance_valid(card) or not card.is_visible_in_tree(): return
	var gp: Vector2 = (ev as InputEventMouseButton).position if ev is InputEventMouseButton else (ev as InputEventScreenTouch).position
	var cpos := (card.get_global_transform_with_canvas().affine_inverse() * gp)
	tap_at(cpos)

## a touch at a card point: a jellyfish there darts off; on the panel, rings through the water
func tap_at(cpos: Vector2) -> void:
	for o: Dictionary in _out:
		var pos: Vector2 = o.pos
		if pos.distance_to(cpos) < float(o.size) * 0.8 and not o.back:
			var away := (pos - cpos).normalized() if pos.distance_to(cpos) > 1.0 else Vector2.UP
			o.kick = away * 240.0
			o.flee = away
			o.dart = 1.0
			for m: ShaderMaterial in o.mats: m.set_shader_parameter("speed", 1.8)
			Sfx.play("glass_tap")
			Sfx.buzz(15)
	var ir := Rect2(info.get_global_rect().position - card.get_global_rect().position, info.size)
	if ir.has_point(cpos):
		_rips.append([cpos.x - ir.position.x, cpos.y - ir.position.y, 0.0])
		if _rips.size() > 4: _rips.pop_front()

func _send_one() -> void:
	var free_src := _src.filter(func(j: Node3D) -> bool: return is_instance_valid(j) and j.visible)
	if free_src.is_empty(): return
	var j: Node3D = free_src[rng.randi() % free_src.size()]
	var at := _on_card(j.global_position)
	var studio: SpecStudio = view.studio
	var span := (_on_card(j.global_position + studio.cam.global_basis.x * j.global_basis.get_scale().x) - at).length()
	# (26.11: it jumped as it came out — another jelly, upright, its stroke elsewhere) the card's jelly is a copy of the
	# stone's own: the same bell and tentacles, the same stroke at the same moment, turned as it was in the stone
	var node := j.duplicate() as Node3D
	_vp.add_child(node)
	var col := Color(0.4, 0.9, 1.4)
	var mats: Array[ShaderMaterial] = []
	var stroke := Vector2(0.6, 0.0)
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var sm := (mi as MeshInstance3D).material_override as ShaderMaterial
		if not sm: continue
		sm = sm.duplicate() as ShaderMaterial
		(mi as MeshInstance3D).material_override = sm
		mats.append(sm)
		if int(sm.get_shader_parameter("part")) == 0:
			var v: Vector3 = sm.get_shader_parameter("col")
			col = Color(v.x, v.y, v.z)
			stroke = Vector2(float(sm.get_shader_parameter("speed")), float(sm.get_shader_parameter("phase")))
	var b0 := _cam_basis(j)
	# it carries on the way its bell was pointing
	var head := Vector2(b0.y.x, -b0.y.y)
	head = head.normalized() if head.length() > 0.2 else (_goal() - at).normalized()
	j.visible = false
	var size := clampf(span * 1.1, 26.0, 70.0)
	_out.append({node = node, src = j, pos = at, head = head, kick = Vector2.ZERO, flee = Vector2.ZERO, b0 = b0, goal = _goal(),
		gt = 0.0, t = 0.0, life = rng.randf_range(STAY[0], STAY[1]), size = size, size0 = maxf(span, 6.0), col = col,
		back = false, mats = mats, dart = 0.0, stroke = stroke, bank = 0.0, pitch = rng.randf_range(0.0, TAU)})

## a stone jelly's turn as the card layer sees it (the studio camera's axes = the layer's: x right, y up, z to us)
func _cam_basis(j: Node3D) -> Basis:
	var studio: SpecStudio = view.studio
	return (studio.cam.global_basis.orthonormalized().inverse() * j.global_basis).orthonormalized()

## one stroke of the bell (as its shader beats it): quick contraction, then a long slow relaxation
static func _beat(u: float) -> float:
	return sin(u / 0.2 * 1.5708) if u < 0.2 else pow(1.0 - (u - 0.2) / 0.8, 2.0)

## somewhere over the panel and the card's lower half, inside the card
func _goal() -> Vector2:
	var ir := Rect2(info.get_global_rect().position - card.get_global_rect().position, info.size)
	return Vector2(rng.randf_range(30.0, card.size.x - 30.0), rng.randf_range(ir.position.y - 80.0, ir.end.y - 30.0))

func _process(dt: float) -> void:
	if not is_instance_valid(card) or not is_instance_valid(view) or not is_instance_valid(info): return
	_t += dt
	_layout_panel_if()
	if test_tap > 0.0 and _t >= test_tap:
		test_tap = 0.0
		if not _out.is_empty(): tap_at((_out[0].pos as Vector2) + Vector2(4, 4))
		tap_at(info.get_global_rect().get_center() - card.get_global_rect().position + Vector2(60, 10))
	# the water's rings
	for r: Array in _rips: r[2] = float(r[2]) + dt
	_rips = _rips.filter(func(r: Array) -> bool: return float(r[2]) < 2.5)
	var wm := _water.material as ShaderMaterial
	var rv := PackedVector4Array()
	for n in 4: rv.append(Vector4(_rips[n][0], _rips[n][1], _rips[n][2], 1.0) if n < _rips.size() else Vector4.ZERO)
	wm.set_shader_parameter("rip", rv)
	# the buttons, figures and badges afloat
	var k := 0
	for n in info.find_children("*", "", true, false):
		if not (n is Label or n is Button) or not (n as Control).is_visible_in_tree(): continue
		var c := n as Control
		if c.get_parent() is Button: continue
		k += 1
		var id := c.get_instance_id()
		var ph := float(k) * 1.9
		var amp := 1.6 if c is Button else 0.9
		var o := Vector2(0.5 * sin(_t * 0.5 + ph), amp * sin(_t * 1.1 + ph * 1.3))
		var last: Vector2 = _drift.get(id, Vector2.ZERO)
		c.position += o - last
		_drift[id] = o
		c.pivot_offset = c.size / 2.0
		c.rotation = (0.016 if c is Button else 0.008) * sin(_t * 0.8 + ph)
	# the jellyfish
	_next -= dt
	if _next <= 0.0:
		_next = test_every if test_every > 0.0 else rng.randf_range(EVERY[0], EVERY[1])
		if _out.size() < MAX_OUT: _send_one()
	var jls := PackedVector4Array([Vector4.ZERO, Vector4.ZERO])
	var ir := Rect2(info.get_global_rect().position - card.get_global_rect().position, info.size)
	var gone := []
	for i in _out.size():
		var o: Dictionary = _out[i]
		o.t = float(o.t) + dt
		var pos: Vector2 = o.pos
		var head: Vector2 = o.head
		var kick: Vector2 = o.kick
		var goal: Vector2 = o.goal
		var size: float = float(o.size)
		if float(o.dart) > 0.0:
			o.dart = maxf(0.0, float(o.dart) - dt * 0.8)
			for m: ShaderMaterial in o.mats: m.set_shader_parameter("speed", 0.6 + 1.2 * float(o.dart))
		if not o.back and float(o.t) > float(o.life): o.back = true
		var src: Node3D = o.src
		o.gt = float(o.gt) + dt
		if o.back and is_instance_valid(src):
			goal = _on_card(src.global_position)
		elif pos.distance_to(goal) < 45.0 or float(o.gt) > 5.0:
			goal = _goal()
			o.gt = 0.0
		o.goal = goal
		# (26.11: it turned on the spot, like a pin) a jellyfish swims where its bell points and turns only a little at a
		# time, mostly on the stroke: it goes round in arcs. Darting off a touch it turns away fast
		var st: Vector2 = o.stroke
		var u := fposmod(Time.get_ticks_msec() * 0.001 * st.x + st.y, 1.0)
		var pull := 0.35 + 1.3 * _beat(u)
		var want := (goal - pos).normalized() if pos.distance_to(goal) > 1.0 else head
		var dist := pos.distance_to(goal)
		var rate := 0.9 * pull
		if o.back: rate *= 1.0 + 3.0 * clampf(1.0 - dist / 90.0, 0.0, 1.0)
		var flee: Vector2 = o.flee
		if float(o.dart) > 0.3 and flee != Vector2.ZERO:
			want = flee
			rate = 5.0
		var ang := head.angle_to(want)
		var turn := clampf(ang, -rate * dt, rate * dt)
		head = head.rotated(turn)
		# it leans into the turn
		o.bank = lerpf(float(o.bank), clampf(ang, -1.0, 1.0) * 0.5, minf(1.0, dt * 2.0))
		var spd := SPEED * (1.6 if o.back else 1.0) * (0.7 + 0.5 * pull)
		if o.back: spd *= clampf(dist / 40.0, 0.35, 1.0)
		pos += head * spd * dt + kick * dt
		kick *= exp(-2.6 * dt)
		# in it comes at its size in the stone, swelling to its size on the card; going back, it shrinks again
		var grow := smoothstep(0.0, 1.2, float(o.t))
		var sz := lerpf(float(o.size0), size, grow)
		if o.back:
			sz = lerpf(float(o.size0), size, clampf(dist / 60.0, 0.0, 1.0))
			if dist < 6.0: gone.append(i)
		# (it keeps to the card: darting off it went past its edge, cut by the layer's)
		pos = pos.clamp(Vector2(12.0, 12.0), card.size - Vector2(12.0, 12.0))
		o.pos = pos
		o.head = head
		o.kick = kick
		# bell first along its way, tipped toward us and away by turns, leaning into its turns
		o.pitch = float(o.pitch) + dt * 0.35
		var yv := Vector3(head.x, -head.y, 0.3 + 0.22 * sin(float(o.pitch))).normalized()
		var xv := yv.cross(Vector3.BACK).normalized()
		var zv := xv.cross(yv)
		var bs := Basis(xv, yv, zv) * Basis(Vector3.UP, float(o.bank) * 1.4)
		# out of the stone it starts turned as it was there, and settles into its way; going home it turns back as the
		# stone's jelly is now, to become it
		var q := Quaternion((o.b0 as Basis)).slerp(Quaternion(bs), smoothstep(0.0, 1.4, float(o.t)))
		if o.back and is_instance_valid(src):
			q = Quaternion(_cam_basis(src)).slerp(q, clampf(dist / 70.0, 0.0, 1.0))
		(o.node as Node3D).transform = Transform3D(Basis(q).scaled(Vector3.ONE * sz), _w(pos))
		if i < 2 and ir.has_point(pos + Vector2(0, size)):
			jls[i] = Vector4(pos.x - ir.position.x, pos.y - ir.position.y, size * 1.6, 1.0)
		if i < 2: wm.set_shader_parameter("jc%d" % i, Vector3(o.col.r, o.col.g, o.col.b))
	for i in range(gone.size() - 1, -1, -1):
		var o: Dictionary = _out[gone[i]]
		if is_instance_valid(o.src): (o.src as Node3D).visible = true
		(o.node as Node3D).queue_free()
		_out.remove_at(gone[i])
	wm.set_shader_parameter("jl", jls)
	var any := not _out.is_empty()
	_rect.visible = any
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if any else SubViewport.UPDATE_DISABLED
	if any:
		var full := card.size + Vector2.ONE * MARGIN * 2.0
		_rect.position = -Vector2.ONE * MARGIN
		_rect.size = full
		_vp.size = Vector2i(full * PX)
		_cam.size = full.y

var _last_sz := Vector2.ZERO
func _layout_panel_if() -> void:
	if info.size != _last_sz:
		_last_sz = info.size
		_layout_panel()
