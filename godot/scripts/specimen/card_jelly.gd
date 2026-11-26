class_name CardJelly
extends Control
## (26.11) The jellyfish legend (SpecJelly) out of its window, and the card under water — the two things a legendary card
## does (out past the stone's frame; the interface played with):
##  - now and then one of the stone's jellyfish swims out of the window over the card, its bell pulsing, wanders over
##    the info panel and the brass a while and swims back into the stone (hidden there while it is out: the same one).
##    A 3D layer of its own over the card (a copy of the stone's jelly), added to the card as light. As the butterflies
##    do (CardFlies): the stone's jelly first leaves its orbit and swims in behind the stone's middle (_leave), and only
##    there, the stone hiding all of it, changes over — its copy, drawn in a layer of its own cut by the stone's
##    silhouette (_vpb, _mvp), comes out from under the stone. Going home the copy swims in under the stone, and there the
##    stone's jelly takes over again, behind the stone, and swims back out to its place on its orbit (_home).
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
## the halo's strength (26.11: dense in the stone, faint on the card — on the card the layer's tone curve, on black,
## crushes faint light that in the stone sits on its lit haze): light in the stone, and as much again on the card
static var HALO_STONE := 0.5
static var HALO_CARD := 1.0
const DEEP := 0.45            # behind the stone a jelly is this much of its size: swum off into the depth, where the stone
                              # hides all of it — halo and tentacles too
const HOME_T := 3.2           # s: from behind the stone back to its place on its orbit
const STONE_JELLY := 1 << 18  # the stone's jellies' visual layer (the silhouette mask leaves them out)

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
var _env: WorldEnvironment
var _vpb: SubViewport         # the copies still under the stone: the same world, their own layer (2)
var _rectb: TextureRect
var _mvp: SubViewport         # the stone drawn again, unshaded on clear: its silhouette, cutting _vpb
var _mcam: Camera3D
var _was := {}                # each stone jelly's point on the card last frame, and the frame's length
var _was_dt := 1.0 / 60.0
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
	for ar in OS.get_cmdline_user_args():   # a test key: -- jhalo=<stone>,<card>
		if ar.begins_with("jhalo="):
			HALO_STONE = float(ar.get_slice("=", 1).get_slice(",", 0))
			HALO_CARD = float(ar.get_slice("=", 1).get_slice(",", 1))
	for j in src:
		for g in j.find_children("*", "VisualInstance3D", true, false): (g as VisualInstance3D).layers = STONE_JELLY
		for mi in j.find_children("*", "MeshInstance3D", true, false):
			var m := (mi as MeshInstance3D).material_override as ShaderMaterial
			if m and int(m.get_shader_parameter("part")) == 4: m.set_shader_parameter("halo_k", HALO_STONE)
		j.set_meta("slot", j.transform)
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
	if test_every > 0.0: _next = test_every
	# the jellyfish's layer: black, its light added to the card (FxLayer's additive)
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	_env = env
	_vp.add_child(env)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.position = Vector3(0, 0, 400)
	_cam.near = 1.0
	_cam.far = 1000.0
	_vp.add_child(_cam)
	_cam.current = true
	_cam.cull_mask = 1
	_vpb = SubViewport.new()
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
	bm.shader = preload("res://shaders/jelly_behind.gdshader")
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
	var me := Environment.new()
	me.background_mode = Environment.BG_CLEAR_COLOR
	_mcam.environment = me
	_mcam.cull_mask = 0xFFFFF & ~SpecStudio.BACKDROP & ~STONE_JELLY
	_mvp.add_child(_mcam)
	_mcam.current = true
	bm.set_shader_parameter("mask", _mvp.get_texture())
	_rect = TextureRect.new()
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.texture = _vp.get_texture()
	_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_rect.stretch_mode = TextureRect.STRETCH_SCALE
	var am := ShaderMaterial.new()
	am.shader = preload("res://shaders/add_rgb.gdshader")
	_rect.material = am
	_rect.visible = false
	add_child(_rect)
	_build_panel()
	tree_exiting.connect(func() -> void:
		for o: Dictionary in _out:
			if is_instance_valid(o.src):
				(o.src as Node3D).visible = true
				(o.src as Node3D).remove_meta("on_card")
		for d: Dictionary in [_leave, _home]:
			for j: Node3D in d.values():
				if is_instance_valid(j): _to_slot(j)
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
			_set_stroke(o, 1.8)
			Sfx.play("glass_tap")
			Sfx.buzz(15)
	var ir := Rect2(info.get_global_rect().position - card.get_global_rect().position, info.size)
	if ir.has_point(cpos):
		_rips.append([cpos.x - ir.position.x, cpos.y - ir.position.y, 0.0])
		if _rips.size() > 4: _rips.pop_front()

## one of the stone's jellies comes out — only one the stone hides now (behind it): it changes over unseen
func _send_one(j: Node3D) -> void:
	var studio: SpecStudio = view.studio
	# its size where its bell is (the stone's camera has perspective: nearer is bigger)
	var bc := j.global_transform * Vector3(0.0, 0.3, 0.0)
	var span := maxf((_on_card(bc + studio.cam.global_basis.x * j.global_basis.get_scale().x) - _on_card(bc)).length(), 6.0)
	# a copy of the stone's own: the same bell and tentacles, the same stroke at the same moment, turned as it was
	var node := j.duplicate() as Node3D
	node.top_level = false
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
		if int(sm.get_shader_parameter("part")) == 4: sm.set_shader_parameter("halo_k", HALO_CARD)
		if int(sm.get_shader_parameter("part")) == 0:
			var v: Vector3 = sm.get_shader_parameter("col")
			col = Color(v.x, v.y, v.z)
			stroke = Vector2(float(sm.get_shader_parameter("speed")), float(sm.get_shader_parameter("phase")))
	var b0 := _cam_basis(j)
	var at := _anchor(j, span)
	# it carries on as it swam round its orbit there
	var head := Vector2(b0.y.x, -b0.y.y)
	head = head.normalized() if head.length() > 0.2 else (_goal() - at).normalized()
	var v0 := Vector2.ZERO
	if _was.has(j.get_instance_id()):
		v0 = (_on_card(j.global_position) - (_was[j.get_instance_id()] as Vector2)) / _was_dt
	if v0.length() > 3.0: head = v0.normalized()
	j.set_meta("on_card", true)
	j.visible = false
	_sync_env()
	_under(node, true)
	# (behind the stone it is DEEP of its size: `full` is its size on its orbit)
	var full := span / DEEP
	var size := clampf(full * 1.1, 26.0, 70.0)
	_out.append({node = node, src = j, pos = at, head = head, kick = Vector2.ZERO, flee = Vector2.ZERO, goal = _goal(),
		gt = 0.0, t = 0.0, life = rng.randf_range(STAY[0], STAY[1]), size = size, size0 = span, full = full, col = col,
		back = false, mats = mats, dart = 0.0, stroke = stroke, sp0 = stroke.x, bank = 0.0, spd = minf(v0.length(), 160.0),
		q = Quaternion(b0), pitch = rng.randf_range(0.0, TAU), under = true, home = false, shrink = 1.0, dive = 0.0,
		dive_t = 0.0, back_t = 0.0, fade = 1.0, core = Vector2.ZERO, core_t = -9.0})

## one of the stone's jellies, in the back half of its orbit, leaves it for behind the stone's middle (_leave)
func _start_leave() -> bool:
	var mid := _depth(find.global_transform * _find_mid())
	var free_src := _src.filter(func(j: Node3D) -> bool:
		return is_instance_valid(j) and j.visible and not j.has_meta("on_card") \
			and _depth(j.global_transform * Vector3(0.0, 0.3, 0.0)) > mid)
	if free_src.is_empty(): return false
	var j: Node3D = free_src[rng.randi() % free_src.size()]
	j.set_meta("on_card", true)
	j.set_meta("trip_t", 0.0)
	var gt := j.global_transform
	# (it leaves its orbit at the speed it had there: stopping dead to turn off was a jerk)
	var v0 := Vector3.ZERO
	if _was3.has(j.get_instance_id()): v0 = (gt.origin - (_was3[j.get_instance_id()] as Vector3)) / _was_dt
	j.set_meta("p0", gt.origin)
	j.set_meta("v0", v0)
	j.set_meta("trip_T", clampf(gt.origin.distance_to(_behind_pt()) / (_s0(j) * 1.4), 1.8, 3.5))
	j.top_level = true
	j.global_transform = gt
	_leave[j.get_instance_id()] = j
	return true

## a stone jelly's own size (its place on its orbit keeps it)
static func _s0(j: Node3D) -> float:
	return (j.get_meta("slot") as Transform3D).basis.get_scale().x

## behind the stone's middle, as far back as half the stone's size: there the stone hides a jelly whole
func _behind_pt() -> Vector3:
	var c: Camera3D = (view.studio as SpecStudio).cam
	var fwd := -c.global_basis.z.normalized()
	var mid := find.global_transform * _find_mid()
	return mid + fwd * _find_r() * 0.55

## bell first along a way
static func _facing(d: Vector3) -> Quaternion:
	var y := d.normalized()
	var x := y.cross(Vector3.UP)
	if x.length() < 0.01: x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	return Quaternion(Basis(x, y, x.cross(y)).orthonormalized())

## a stone jelly off its orbit set at a point, turning (no faster than `rate`) to face `want`, at k of its size
func _set_trip(j: Node3D, at: Vector3, want: Quaternion, rate: float, k: float, dt: float) -> void:
	var cur := Quaternion(j.global_basis.orthonormalized())
	var gap := cur.angle_to(want)
	if gap > 0.0001: cur = cur.slerp(want, minf(1.0, rate * dt / gap))
	j.global_transform = Transform3D(Basis(cur).scaled(Vector3.ONE * _s0(j) * k), at)

## the stone's silhouette (the mask: the find unshaded by the stone's camera), read back from the GPU ten times a second
## while a jelly is changing over — what truly hides one (26.11: the find's box said «hidden» beside the crystal, over the
## gaps between it and its moss: jellies changed over and vanished in plain sight)
var _mask_img: Image
var _mask_at := -1.0
func _mask_refresh() -> void:
	if _t - _mask_at > 0.1 or not _mask_img:
		_mask_at = _t
		_mask_img = _mvp.get_texture().get_image()

## the mask at a card point: 0 clear .. 1 stone (the layer under the stone is gone from 0.14 up: jelly_behind.gdshader)
func _mask_a(cp: Vector2) -> float:
	if not _mask_img or _mask_img.get_width() < 2: return 0.0
	var off := view.get_global_rect().position - card.get_global_rect().position
	var ms := Vector2(_mask_img.get_size())
	var v := (cp - off) / view.size * ms
	if v.x < 0.0 or v.y < 0.0 or v.x >= ms.x or v.y >= ms.y: return 0.0
	return _mask_img.get_pixelv(Vector2i(v)).a

## a jelly's points (its own space): its bell; and its halo's edge and its tentacles' reach
const BELL_PTS := [Vector3(0, 0.3, 0), Vector3(0.6, 0.1, 0), Vector3(-0.6, 0.1, 0), Vector3(0, 0.1, 0.6), Vector3(0, 0.1, -0.6),
	Vector3(0, 0.62, 0)]
const WIDE_PTS := [Vector3(1.25, 0.2, 0), Vector3(-1.25, 0.2, 0), Vector3(0, 0.2, 1.25), Vector3(0, 0.2, -1.25),
	Vector3(0, 1.45, 0), Vector3(0, -1.05, 0), Vector3(0, -1.8, 0)]

## does the stone's silhouette cover all of this stone jelly — bell, halo, tentacles?
func _mask_hides(j: Node3D) -> bool:
	if _depth(j.global_transform * Vector3(0.0, 0.3, 0.0)) < _depth(find.global_transform * _find_mid()): return false
	for pts: Array in [BELL_PTS, WIDE_PTS]:
		for lp: Vector3 in pts:
			if _mask_a(_on_card(j.global_transform * lp)) < 0.14: return false
	return true

## how much of the stone lies over a copy's points: [the least, the most]
func _copy_cover(o: Dictionary, pts: Array) -> Vector2:
	var tr := (o.node as Node3D).transform
	var lo := 1.0
	var hi := 0.0
	for lp: Vector3 in pts:
		var w := tr * lp
		var a := _mask_a(Vector2(w.x + card.size.x * 0.5, card.size.y * 0.5 - w.y))
		lo = minf(lo, a)
		hi = maxf(hi, a)
	return Vector2(lo, hi)

## where on the card the stone is thickest round its middle: where a copy going home dives under it. The middle itself if
## the stone is there; else the nearest place with stone all round
func _core_pt() -> Vector2:
	var t := _on_card(find.global_transform * _find_mid())
	var best := t
	var best_d := INF
	var off := view.get_global_rect().position - card.get_global_rect().position
	for gy in 14:
		for gx in 12:
			var c := off + Vector2((gx + 0.5) / 12.0, (gy + 0.5) / 14.0) * view.size
			if _mask_a(c) < 0.5: continue
			var ok := true
			for d: Vector2 in [Vector2(22, 0), Vector2(-22, 0), Vector2(0, 22), Vector2(0, -22)]:
				if _mask_a(c + d) < 0.5: ok = false
			var dd := c.distance_to(t)
			if ok and dd < best_d:
				best_d = dd
				best = c
	return best

## a copy's glow ×k (its shaders add its colour: dimming it is fading it; the colour it had kept in a meta)
static func _dim(mats: Array, k: float) -> void:
	for m: ShaderMaterial in mats:
		if not m.has_meta("col0"): m.set_meta("col0", m.get_shader_parameter("col"))
		var c: Vector3 = m.get_meta("col0")
		m.set_shader_parameter("col", c * k)

## a stone jelly back on its orbit, at its place
static func _to_slot(j: Node3D) -> void:
	j.top_level = false
	j.transform = j.get_meta("slot")
	j.visible = true
	j.remove_meta("on_card")
	for k in ["trip_t", "p0", "v0", "trip_T", "going"]: j.remove_meta(k)

## a copy under the stone (its own layer, cut by the stone's silhouette) or out over the card
static func _under(n: Node, on: bool) -> void:
	for g in n.find_children("*", "VisualInstance3D", true, false):
		(g as VisualInstance3D).layers = 2 if on else 1

## the stone on the card: its meshes' boxes (not the jellies) seen through the stone's camera
func _stone_rect() -> Rect2:
	var r := Rect2()
	var first := true
	for n in find.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if not mi.is_visible_in_tree() or not mi.mesh or (mi.layers & (STONE_JELLY | SpecStudio.BACKDROP)) != 0: continue
		var bx := mi.mesh.get_aabb()
		for i in 8:
			var pt := _on_card(mi.global_transform * bx.get_endpoint(i))
			if first:
				r = Rect2(pt, Vector2.ZERO)
				first = false
			else:
				r = r.expand(pt)
	return r

## how far from the stone's camera (along its look)
func _depth(world: Vector3) -> float:
	var c: Camera3D = (view.studio as SpecStudio).cam
	return -(c.global_transform.affine_inverse() * world).z

var _mid := Vector3.ZERO
var _mid_set := false
## the stone's middle (the find's own space)
func _find_mid() -> Vector3:
	if not _mid_set:
		var bx := AABB()
		var first := true
		for n in find.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			if not mi.mesh or (mi.layers & (STONE_JELLY | SpecStudio.BACKDROP)) != 0: continue
			var b := (find.global_transform.affine_inverse() * mi.global_transform) * mi.mesh.get_aabb()
			bx = b if first else bx.merge(b)
			first = false
		_mid = bx.get_center()
		_r = (find.global_basis * bx.size).length() * 0.5
		_mid_set = true
	return _mid

var _r := 1.0
## half the stone's size (the world's)
func _find_r() -> float:
	_find_mid()
	return _r

## the bell's stroke rate changed (darting off a touch and calming down) without a jump in the stroke: the shader beats
## at fract(TIME·speed + phase), so the phase takes up the difference (26.11: the bell twitched to another moment)
func _set_stroke(o: Dictionary, sp: float) -> void:
	var st: Vector2 = o.stroke
	if absf(sp - st.x) < 0.0001: return
	var now := Time.get_ticks_msec() * 0.001
	st = Vector2(sp, st.y + now * (st.x - sp))
	o.stroke = st
	for m: ShaderMaterial in o.mats:
		m.set_shader_parameter("speed", st.x)
		m.set_shader_parameter("phase", st.y)

## (26.11: coming out it lost half its glow in a frame) the layer's tone and bloom are the stone studio's as they are now
## (the jellyfish legend darkens the studio and opens its bloom after the card is built), on black — added to the card
func _sync_env() -> void:
	if not _env: return
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color.BLACK
	# the studio's tone curve (ACES whitens a bright bell as the stone's does), not its room or its glow (on black that
	# blew the bell out white)
	var se: Environment = (view.studio as SpecStudio).env if is_instance_valid(view) and view.studio else null
	e.tonemap_mode = se.tonemap_mode if se else Environment.TONE_MAPPER_ACES
	e.tonemap_white = se.tonemap_white if se else 6.0
	e.tonemap_exposure = se.tonemap_exposure if se else 1.05
	_env.environment = e

## where the copy's origin goes on the card for its bell's middle to sit on the stone jelly's (sz: the copy's size, points)
func _anchor(j: Node3D, sz: float) -> Vector2:
	var ctr := _on_card(j.global_transform * Vector3(0.0, 0.3, 0.0))
	var vb := _cam_basis(j) * Vector3(0.0, 0.3 * sz, 0.0)
	return ctr - Vector2(vb.x, -vb.y)

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
		if _out.size() + _leave.size() < MAX_OUT and not _start_leave():
			_next = 0.15   # none in the back of its orbit just now: soon again
		else:
			_next = test_every if test_every > 0.0 else rng.randf_range(EVERY[0], EVERY[1])
	# where the stone's jellies are on the card now: the next to come out leaves at the speed it swam there
	for j in _src:
		if is_instance_valid(j) and not j.has_meta("on_card"):
			_was[j.get_instance_id()] = _on_card(j.global_position)
			_was3[j.get_instance_id()] = j.global_position
	_was_dt = maxf(dt, 0.001)
	var jls := PackedVector4Array([Vector4.ZERO, Vector4.ZERO])
	var ir := Rect2(info.get_global_rect().position - card.get_global_rect().position, info.size)
	var gone := []
	_sr = _stone_rect() if not (_out.is_empty() and _leave.is_empty()) else Rect2()
	var changing := not (_leave.is_empty() and _home.is_empty())
	for o: Dictionary in _out:
		if o.back or bool(o.under): changing = true
	if changing: _mask_refresh()
	var cam3: Camera3D = (view.studio as SpecStudio).cam
	var away := _facing(-cam3.global_basis.z)
	var bp := _behind_pt() if not (_leave.is_empty() and _home.is_empty()) else Vector3.ZERO
	# the stone's jellies leaving: off their orbits (at the speed they had) in behind the stone's middle, swimming off into
	# the depth (smaller), bell turned away at the end — and there, the stone's silhouette over all of them (halo and
	# tentacles too), they change over to the card's
	for id in _leave.keys():
		var j: Node3D = _leave[id]
		if not is_instance_valid(j):
			_leave.erase(id)
			continue
		var tt := float(j.get_meta("trip_t")) + dt
		j.set_meta("trip_t", tt)
		var tl := float(j.get_meta("trip_T"))
		var u := clampf(tt / tl, 0.0, 1.0)
		var p0: Vector3 = j.get_meta("p0")
		var v0: Vector3 = j.get_meta("v0")
		var at := p0 * (2.0 * u * u * u - 3.0 * u * u + 1.0) + v0 * tl * (u * u * u - 2.0 * u * u + u) + bp * (-2.0 * u * u * u + 3.0 * u * u)
		var d := at - j.global_position
		var want := _facing(d) if d.length() > _s0(j) * 0.002 else Quaternion(j.global_basis.orthonormalized())
		want = want.slerp(away, smoothstep(0.55, 1.0, u))
		_set_trip(j, at, want, 2.6, lerpf(1.0, DEEP, smoothstep(0.2, 1.0, u)), dt)
		var turned := Quaternion(j.global_basis.orthonormalized()).angle_to(away) < 0.35
		if (u >= 1.0 and turned and _mask_hides(j)) or tt > tl + 5.0:
			_leave.erase(id)
			_send_one(j)
	# the stone's jellies home: each waits hidden behind the stone till its place on its orbit is in the back half, then
	# swims out to it — from the point behind the stone to the place as it goes round, there exactly at the end (26.11:
	# chasing its place at a speed of its own it never caught it, and after 8 s jumped to it)
	for id in _home.keys():
		var j: Node3D = _home[id]
		if not is_instance_valid(j):
			_home.erase(id)
			continue
		var slot: Transform3D = (j.get_parent() as Node3D).global_transform * (j.get_meta("slot") as Transform3D)
		if not j.has_meta("going"):
			_set_trip(j, bp, away, 2.6, DEEP, dt)
			if _depth(slot.origin) > _depth(find.global_transform * _find_mid()) + _find_r() * 0.1:
				j.set_meta("going", true)
				j.set_meta("trip_t", 0.0)
			continue
		var tt := float(j.get_meta("trip_t")) + dt
		j.set_meta("trip_t", tt)
		var u := clampf(tt / HOME_T, 0.0, 1.0)
		var at := bp.lerp(slot.origin, smoothstep(0.0, 1.0, u))
		var d := at - j.global_position
		var want := _facing(d) if d.length() > _s0(j) * 0.002 else Quaternion(j.global_basis.orthonormalized())
		var sk := lerpf(DEEP, 1.0, smoothstep(0.0, 1.0, u))
		_set_trip(j, at, want, 2.6, sk, dt)
		# (turning into its place's own turn over the last third: there exactly at the end)
		var w := smoothstep(0.65, 1.0, u)
		if w > 0.0:
			var q := Quaternion(j.global_basis.orthonormalized()).slerp(Quaternion(slot.basis.orthonormalized()), w)
			j.global_transform = Transform3D(Basis(q).scaled(Vector3.ONE * _s0(j) * sk), at)
		if u >= 1.0:
			_home.erase(id)
			_to_slot(j)
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
			_set_stroke(o, lerpf(float(o.sp0), 1.8, float(o.dart)))
		if not o.back and float(o.t) > float(o.life): o.back = true
		var src: Node3D = o.src
		o.gt = float(o.gt) + dt
		var sr := _sr
		if o.back:
			o.back_t = float(o.back_t) + dt
			if not bool(o.home):
				# home: under the stone from now on — but not while it is over it (it would vanish there): first clear of it
				if _copy_cover(o, BELL_PTS + WIDE_PTS).y < 0.02:
					o.home = true
					o.under = true
					_under(o.node, true)
				else:
					var offw := pos - _on_card(find.global_transform * _find_mid())
					goal = pos + (offw.normalized() if offw.length() > 1.0 else Vector2.DOWN) * 80.0
			if bool(o.home):
				# in under the stone where it is thickest; its bell under it, it dives (turns away, swims off into the depth,
				# smaller) — and gone only with the stone's silhouette over all of it (26.11: it was taken off inside the
				# find's box, in plain sight by the moss)
				if _t - float(o.core_t) > 1.0:
					o.core_t = _t
					o.core = _core_pt()
				goal = o.core
				if _copy_cover(o, BELL_PTS).x >= 0.14: o.dive = minf(1.0, float(o.dive) + dt / 0.8)
				if float(o.dive) >= 1.0:
					o.dive_t = float(o.dive_t) + dt
					if _copy_cover(o, BELL_PTS + WIDE_PTS).x >= 0.14: gone.append(i)
			# (never hidden — a find too small or too thin for it: it fades out where it is, no pop)
			if float(o.dive_t) > 2.5 or float(o.back_t) > 14.0:
				o.fade = maxf(0.0, float(o.fade) - dt / 0.6)
				_dim(o.mats, float(o.fade))
				if float(o.fade) <= 0.0 and not i in gone: gone.append(i)
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
		if o.back: rate = maxf(rate, 1.4) * (1.0 + 2.0 * clampf(1.0 - dist / 90.0, 0.0, 1.0))
		var flee: Vector2 = o.flee
		if float(o.dart) > 0.3 and flee != Vector2.ZERO:
			want = flee
			rate = 5.0
		# (26.11: it ran into the card's edge and stopped dead) near an edge it turns inward, the closer the harder
		var edge := Vector2.ZERO
		var mg := 46.0
		edge.x = maxf(0.0, mg - pos.x) - maxf(0.0, pos.x - (card.size.x - mg))
		edge.y = maxf(0.0, mg - pos.y) - maxf(0.0, pos.y - (card.size.y - mg))
		if edge != Vector2.ZERO and head.dot(edge) < 0.3 and not o.back and not bool(o.under):
			var e := clampf(edge.length() / mg, 0.0, 1.0)
			want = (want + edge.normalized() * e * 3.0).normalized()
			rate = maxf(rate, 0.8 + 2.2 * e)
		# under the stone on its way out it makes for the nearest way out from under it (a while hidden there is long)
		if bool(o.under) and not bool(o.home) and sr.size.x > 4.0:
			var outw := (pos - sr.get_center())
			outw = outw.normalized() if outw.length() > 1.0 else head
			want = (want * 0.3 + outw * 0.7).normalized()
			rate = maxf(rate, 3.0)
		var ang := head.angle_to(want)
		var turn := clampf(ang, -rate * dt, rate * dt)
		head = head.rotated(turn)
		# it leans into the turn
		o.bank = lerpf(float(o.bank), clampf(ang, -1.0, 1.0) * 0.5, minf(1.0, dt * 2.0))
		var spd := SPEED * (1.4 if o.back else 1.0) * (0.7 + 0.5 * pull)
		if bool(o.home): spd *= 0.8 * (1.0 - 0.75 * float(o.dive)) * clampf(dist / 30.0, 0.15, 1.0)
		elif bool(o.under): spd *= 2.2
		# (26.11: going home it sped up ×1.6 in one frame) the speed eases to what it wants
		o.spd = lerpf(float(o.spd), spd, minf(1.0, dt * 1.2))
		pos += head * float(o.spd) * dt + kick * dt
		kick *= exp(-2.6 * dt)
		# out it comes small (from the depth behind the stone), swelling to its size on the card; going back it shrinks to
		# its size on its orbit as it nears the stone, and smaller yet as it dives under it
		var sz := lerpf(float(o.size0), size, smoothstep(0.0, 1.4, float(o.t)))
		if o.back:
			var dh := pos.distance_to(_on_card(find.global_transform * _find_mid()))
			o.shrink = minf(float(o.shrink), clampf((dh - 40.0) / 90.0, 0.0, 1.0))
			sz = lerpf(float(o.full), sz, float(o.shrink)) * lerpf(1.0, DEEP, smoothstep(0.0, 1.0, float(o.dive)))
		# out from under the stone — clear of its silhouette, bell, halo and tentacles: into the layer over the card
		if bool(o.under) and not bool(o.home) and float(o.t) > 0.3 \
				and (_copy_cover(o, BELL_PTS + WIDE_PTS).y < 0.02 or not sr.grow(size * 3.0).has_point(pos)):
			o.under = false
			_under(o.node, false)
		# (it keeps to the card: darting off it went past its edge, cut by the layer's)
		# going home it may cross the edge (the stone's jelly is behind the window's frame then): the layer reaches past it
		var lim := -MARGIN * 0.6 if (o.back or bool(o.under)) else 8.0
		pos = pos.clamp(Vector2(lim, lim), card.size - Vector2(lim, lim))
		o.pos = pos
		o.head = head
		o.kick = kick
		# bell first along its way, tipped toward us and away by turns, leaning into its turns
		o.pitch = float(o.pitch) + dt * 0.35
		var dv := smoothstep(0.0, 1.0, float(o.dive))
		var yv := Vector3(head.x * (1.0 - dv * 0.9), -head.y * (1.0 - dv * 0.9), lerpf(0.3 + 0.22 * sin(float(o.pitch)), -1.0, dv)).normalized()
		var xv := yv.cross(Vector3.BACK).normalized()
		var zv := xv.cross(yv)
		var bs := Basis(xv, yv, zv) * Basis(Vector3.UP, float(o.bank) * 1.4)
		# out of the stone it starts turned as it was there, and settles into its way; going home it turns back as the
		# stone's jelly is now, to become it
		var qt := Quaternion(bs)
		# (26.11: settling from its pose in the stone it spun up to 0.45 rad a frame) the body turns toward where it
		# should face no faster than a jellyfish can, easing in at the end
		var q: Quaternion = o.q
		var gap := q.angle_to(qt)
		if gap > 0.0001:
			var w := minf(gap * 2.5, 1.3 + (4.0 if float(o.dart) > 0.3 else 0.0)) * dt
			q = q.slerp(qt, minf(1.0, w / gap))
		o.q = q
		(o.node as Node3D).transform = Transform3D(Basis(q).scaled(Vector3.ONE * sz), _w(pos))
		if i < 2 and ir.has_point(pos + Vector2(0, size)):
			jls[i] = Vector4(pos.x - ir.position.x, pos.y - ir.position.y, size * 1.6, 1.0)
		if i < 2: wm.set_shader_parameter("jc%d" % i, Vector3(o.col.r, o.col.g, o.col.b))
	for i in range(gone.size() - 1, -1, -1):
		var o: Dictionary = _out[gone[i]]
		if is_instance_valid(o.src):
			var j := o.src as Node3D
			j.top_level = true
			j.global_transform = Transform3D(Basis(away).scaled(Vector3.ONE * _s0(j) * DEEP), _behind_pt())
			j.visible = true
			j.remove_meta("going")
			j.set_meta("trip_t", 0.0)
			_home[j.get_instance_id()] = j
		(o.node as Node3D).queue_free()
		_out.remove_at(gone[i])
	wm.set_shader_parameter("jl", jls)
	var any := not _out.is_empty()
	var any_b := false
	for o: Dictionary in _out:
		if bool(o.under): any_b = true
	_rect.visible = any
	_rectb.visible = any_b
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if any else SubViewport.UPDATE_DISABLED
	_vpb.render_target_update_mode = SubViewport.UPDATE_ALWAYS if any_b else SubViewport.UPDATE_DISABLED
	# the mask: every frame while a copy is drawn under the stone (it cuts it); ten times a second while it is only read
	var need_m := any_b or changing
	if any_b:
		_mvp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	elif need_m and _t - _mask_drawn > 0.1:
		_mask_drawn = _t
		_mvp.render_target_update_mode = SubViewport.UPDATE_ONCE
	elif not need_m:
		_mvp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if need_m:
		var sc: Camera3D = (view.studio as SpecStudio).cam
		_mcam.global_transform = sc.global_transform
		_mcam.projection = sc.projection
		_mcam.fov = sc.fov
		_mcam.size = sc.size
		_mcam.keep_aspect = sc.keep_aspect
		_mcam.near = sc.near
		_mcam.far = sc.far
		_mcam.h_offset = sc.h_offset
		_mcam.v_offset = sc.v_offset
		var svp: SubViewport = (view.studio as SpecStudio).vp
		var ms := Vector2i(maxi(2, svp.size.x / 2), maxi(2, svp.size.y / 2))
		if _mvp.size != ms: _mvp.size = ms
	if any:
		var full := card.size + Vector2.ONE * MARGIN * 2.0
		_rect.position = -Vector2.ONE * MARGIN
		_rect.size = full
		_vp.size = Vector2i(full * PX)
		_cam.size = full.y
	if any_b:
		_rectb.position = _rect.position
		_rectb.size = _rect.size
		if _vpb.size != _vp.size: _vpb.size = _vp.size
		var camb := _vpb.get_camera_3d()
		camb.size = _cam.size
		camb.global_transform = _cam.global_transform
		var bm := _rectb.material as ShaderMaterial
		var vr := Rect2(view.global_position - _rectb.global_position, view.size)
		bm.set_shader_parameter("view_rect", Vector4(vr.position.x, vr.position.y, vr.size.x, vr.size.y))
		bm.set_shader_parameter("lsize", _rectb.size)

var _sr := Rect2()
var _mask_drawn := -1.0
var _was3 := {}               # each stone jelly's place in the stone's world last frame
var _leave := {}              # stone jellies swimming in behind the stone to come out onto the card
var _home := {}               # and swimming back out from behind it to their places on their orbits
var _last_sz := Vector2.ZERO
func _layout_panel_if() -> void:
	if info.size != _last_sz:
		_last_sz = info.size
		_layout_panel()
