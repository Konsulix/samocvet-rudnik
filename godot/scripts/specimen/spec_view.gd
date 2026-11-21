class_name SpecView
extends Control
## A live 3D specimen on screen: it drifts and turns by itself, answers the finger,
## and when let go keeps spinning, slowing back to a drift. Machines keep their parts moving.
## Two fingers pinch to look closer (the mouse wheel on a desktop); a double tap jumps in and back out.
## The studio renders at real screen pixels (not the 390-wide layout units the UI is laid out in),
## so on a 3x phone the stone is not blown up from a small picture and does not shimmer as it turns.

signal built(p: Node3D)   # the specimen is on screen (its meta "grown": what really grew on it)
signal tapped             # a short touch that neither turned nor zoomed the stone

const MAX_PX := 800   # longest side of the render, to keep the phone cool
const FPS := 60.0      # a slow-turning stone needs no more; on a 120 Hz iPhone this halves the work

var studio: SpecStudio
var live: Node3D
var _img: TextureRect
var spin_v := 0.45
var tilt := 0.0
var still := false     # a fixed three-quarter pose, as in thumbnails
var _drag := false
var _t := 0.0
var _req := 0
var zoomable := true
const ZOOM_MAX := 3.0
var _zoom := 1.0       # shown
var _zoom_to := 1.0    # wanted
var _fov0 := 28.0
var _touch := {}       # finger index -> position, for the pinch
var _pinch0 := 0.0
var _pinch_zoom := 1.0
# where a zoom comes down to (the camera's rise above the stone's middle at full zoom): a crystal on its rock is looked
# at in its lower third — the rock, what grows on it, where the butterflies sit — not the bare middle of the crystal
var _aim := NAN
var _v0 := 0.0
var _since := 0.0
var hold := false      # callouts are open: the stone stops drifting round (a finger still turns it)
var _press := Vector2.ZERO
var _press_ms := -1
var _tap_ms := 0

## the stone grey and dim, as the atlas shows a species the player no longer keeps
func hold_grey() -> void:
	_img.material = Atlas.faded()

func _init(px := 512, transparent := false) -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	studio = SpecStudio.make(px, Viewport.MSAA_4X, transparent)
	studio.vp.render_target_update_mode = SubViewport.UPDATE_DISABLED   # rendered from _process, at FPS
	add_child(studio.vp)
	_img = TextureRect.new()
	_img.texture = studio.vp.get_texture()
	_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_img.stretch_mode = TextureRect.STRETCH_SCALE
	_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_img.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_img)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_ENTER_TREE:
		_fit()

## size the render to the view's footprint in physical pixels
func _fit() -> void:
	if not is_inside_tree() or size.x < 1.0 or size.y < 1.0:
		return
	var px := size * get_viewport().get_final_transform().get_scale()
	px *= minf(1.0, MAX_PX / maxf(px.x, px.y))
	var want := Vector2i(maxi(1, roundi(px.x)), maxi(1, roundi(px.y)))
	# a tall frame keeps the stone's width in view instead of cropping its sides
	studio.cam.keep_aspect = Camera3D.KEEP_WIDTH if want.y > want.x else Camera3D.KEEP_HEIGHT
	if studio.vp.size != want:
		studio.vp.size = want
		print_verbose("SpecView render ", want, " for ", size)

func show_spec(o: Dictionary) -> void:
	_req += 1
	var my := _req
	_stand_in(Atlas.cached(o))
	var p: Node3D = await studio.show_async(o, true)
	if my != _req or not is_instance_valid(self):
		return
	_stand_in(null)
	live = p
	_aim = NAN   # (the next zoom aims anew at this stone)
	# (a swimmer of the old seas may strike the card's glass: SpecReef.Swim)
	for n in p.find_children("*", "Node3D", true, false):
		if n.has_signal("glass_hit"): n.connect("glass_hit", _glass)
		if n.has_signal("sea_call"): n.connect("sea_call", _sea_call)
	built.emit(p)
	# (20.11) alexandrite: a tap turns the light to a lamp (_lamp): said once
	if p.get_meta("alex", false):
		_lamp_on = false
		studio.set_lamp(0.0)
		if not Coach.off and not Save.told("t_alex"):
			Save.tell("t_alex")
			Ov.toast("Tap the alexandrite: lamplight turns it red")
	# (19.11) an opal egg can be wetted by a tap (_wet): said once, the first time one is open
	if not Coach.off and not Save.told("t_wet") and not _eggs().is_empty():
		Save.tell("t_wet")
		Ov.toast("Tap the opal: water wakes its fire")
	spin_v = 0.45
	tilt = 0.0
	if still:
		live.rotation = Vector3(0.12, 0.6, 0)

## a swimmer's voice (its song as it passes, the rush of water before it, its roar): only while this card shows
func _sea_call(what: String) -> void:
	if not is_visible_in_tree():
		return
	if what == "dark":
		_dark()
		return
	Sfx.play("sea_" + what)

## a plesiosaur's jaws shut over the eye: the view goes dark a moment, and clears
func _dark() -> void:
	var r := ColorRect.new()
	r.color = Color(0.05, 0.01, 0.015, 0.0)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(r)
	move_child(r, _img.get_index() + 1)
	var tw := r.create_tween()
	tw.tween_property(r, "color:a", 1.0, 0.1)
	tw.tween_interval(0.16)
	tw.tween_property(r, "color:a", 0.0, 0.45)
	tw.tween_callback(r.queue_free)

## the glass struck from inside, at this point of the studio's world: cracks from there (a soft one: mist), the view
## shakes, the phone thumps
var _shake := 0.0
func _glass(at: Vector3, soft: bool) -> void:
	if not is_visible_in_tree() or studio.vp.size.x < 2:
		return
	var px := studio.cam.unproject_position(at)
	GlassCrack.strike(self, px / Vector2(studio.vp.size) * size, soft, _img.texture)
	Sfx.play("glass_tap" if soft else "glass_ram")
	if not soft:
		_shake = 1.0
		Sfx.buzz(70)

## while the live stone is built (a skull takes seconds, and waits for the build already running), its picture made
## earlier for a tile or the atlas stands in; it fades out as the live one comes (null: fade the one up now)
var _hint: TextureRect
func _stand_in(t: Texture2D) -> void:
	if t == null:
		if _hint:
			var h := _hint
			_hint = null
			var tw := h.create_tween()
			tw.tween_property(h, "modulate:a", 0.0, 0.25)
			tw.tween_callback(h.queue_free)
		return
	if _hint == null:
		_hint = TextureRect.new()
		_hint.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_hint.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hint.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		# about where the studio frames the stone: the middle of the view, a margin round it
		_hint.anchor_left = 0.2
		_hint.anchor_right = 0.8
		_hint.anchor_top = 0.22
		_hint.anchor_bottom = 0.72
		add_child(_hint)
	_hint.texture = t
	_hint.modulate.a = 1.0

## (19.11) shaken: the phone given a jolt while the card is open — dust sifts off the stone, butterflies and fireflies
## start up and scatter, the crumbs at a broken find's foot rattle, an enhydro's bubble sloshes, the stone itself
## trembles, the phone buzzes. (A jolt: the push past gravity over SHAKE_G m/s², at most once a second)
const SHAKE_G := 13.0
var _shake_cd := 0.0
## points on the rock's sides (meta base, or a rock material), relative to `at`, in the scene's space
func _rock_top(at: Vector3) -> PackedVector3Array:
	var out := PackedVector3Array()
	for n in live.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var cm := mi.material_override
		if not mi.visible or mi.mesh == null or not (mi.has_meta("base") or (cm and cm.has_meta("rock"))): continue
		var xf := mi.global_transform
		for si in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(si)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var ns: PackedVector3Array = arr[Mesh.ARRAY_NORMAL] if arr[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
			var step := maxi(1, vs.size() / 400)
			for i in range(0, vs.size(), step):
				# (its sides, upper half: the dust sifts off the rock's edges and falls clear of it — off its top it fell
				# through the stone and sat on it as white crumbs)
				var ny := (xf.basis * ns[i]).normalized().y if ns.size() == vs.size() else 0.0
				if ny < -0.25 or ny > 0.55: continue
				out.append(xf * vs[i] + (xf.basis * ns[i]).normalized() * 0.01 - at if ns.size() == vs.size() else xf * vs[i] - at)
	return out

func shake_find(k := 1.0) -> void:
	if not is_instance_valid(live) or not is_visible_in_tree(): return
	_shake = maxf(_shake, 0.6 * k)
	Sfx.buzz(45)
	var bb := AABB()
	var first := true
	for n in live.find_children("*", "", true, false):
		if n is SpecButterfly.Fly:
			var f: SpecButterfly.Fly = n
			if f.state == SpecButterfly.Fly.SIT: f.timer = 0.0
			elif f.state == SpecButterfly.Fly.LAND: f.state = SpecButterfly.Fly.FLY
			f.vel += Vector3(randf() - 0.5, randf() * 0.6, randf() - 0.5) * f.size * 6.0 * k
		if n.has_method("jolt"):
			n.call("jolt", k)
		if n is MeshInstance3D and n.has_meta("crumb"):
			var m := n as MeshInstance3D
			var p0 := m.position
			var r0 := m.rotation
			var hop := m.get_aabb().size.length() * (0.3 + randf() * 0.5) * k
			var tw := m.create_tween()
			tw.tween_property(m, "position", p0 + Vector3(0, hop, 0), 0.08).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(m, "rotation", r0 + Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * 0.6, 0.16)
			tw.tween_property(m, "position", p0, 0.12).set_ease(Tween.EASE_IN)
		if n is MeshInstance3D and n.has_meta("geo") and (n as MeshInstance3D).visible:
			var ab: AABB = (n as MeshInstance3D).global_transform * (n as MeshInstance3D).get_aabb()
			bb = ab if first else bb.merge(ab)
			first = false
	if first: return
	# dust shaken off the rock (21.11: 140 equal soft dots read as white beads, not dust): a haze of a few big
	# ragged puffs that billow out, swell and thin away, and a sift of fine dark grains falling under it.
	# Both earth-coloured, from the rock's sides; a find with no rock keeps a box over its upper part
	var at := Vector3(bb.get_center().x, bb.end.y - bb.size.y * 0.35, bb.get_center().z)
	var pts := _rock_top(at)
	var dia := bb.size.length()
	var haze := _dust_emitter(pts, bb, at, int(24 * k), 2.6, 0.9, dia * 0.14, _dust_tex(true), Color(0.66, 0.59, 0.5, 0.3))
	haze.initial_velocity_max = bb.size.y * 0.1
	haze.gravity = Vector3(0, -bb.size.y * 0.03, 0)
	haze.damping_min = bb.size.y * 0.08
	haze.damping_max = bb.size.y * 0.14
	haze.angle_min = -180.0
	haze.angle_max = 180.0
	haze.angular_velocity_min = -25.0
	haze.angular_velocity_max = 25.0
	var swell := Curve.new()
	swell.add_point(Vector2(0, 0.35))
	swell.add_point(Vector2(0.4, 0.85))
	swell.add_point(Vector2(1, 1.3))
	haze.scale_amount_curve = swell
	var grains := _dust_emitter(pts, bb, at, int(45 * k), 2.0, 0.7, dia * 0.004, _dust_tex(false), Color(0.5, 0.44, 0.36, 0.6))
	grains.initial_velocity_max = bb.size.y * 0.25
	grains.gravity = Vector3(0, -bb.size.y * 0.55, 0)
	grains.damping_min = 0.0
	grains.damping_max = bb.size.y * 0.1
	for e: CPUParticles3D in [haze, grains]:
		e.emitting = true
		get_tree().create_timer(3.0).timeout.connect(e.queue_free)

## one emitter of the shake's dust: billboarded soft quads of `size`, coloured `col` fading in fast and out slow
func _dust_emitter(pts: PackedVector3Array, bb: AABB, at: Vector3, n: int, life: float, burst: float, size: float, tex: Texture2D, col: Color) -> CPUParticles3D:
	var e := CPUParticles3D.new()
	e.one_shot = true
	e.explosiveness = burst
	e.amount = maxi(n, 2)
	e.lifetime = life
	e.randomness = 0.4
	e.direction = Vector3(0, -1, 0)
	e.spread = 80.0
	e.initial_velocity_min = 0.0
	e.scale_amount_min = 0.45
	e.scale_amount_max = 1.0
	var qm := QuadMesh.new()
	qm.size = Vector2.ONE * size
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	dm.vertex_color_use_as_albedo = true
	dm.albedo_texture = tex
	qm.material = dm
	e.mesh = qm
	var ramp := Gradient.new()
	ramp.set_color(0, Color(col, 0.0))
	ramp.add_point(0.08, col)
	ramp.add_point(0.55, Color(col, col.a * 0.6))
	ramp.set_color(ramp.get_point_count() - 1, Color(col, 0.0))
	e.color_ramp = ramp
	live.get_parent().add_child(e)
	e.global_position = at
	if pts.size():
		e.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINTS
		e.emission_points = pts
	else:
		e.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		e.emission_box_extents = Vector3(bb.size.x * 0.35, bb.size.y * 0.3, bb.size.z * 0.35)
	return e

## the dust's sprites, made once: a ragged cloud (noise under a soft round mask) or a small soft grain
static var _dust_tx := {}
static func _dust_tex(cloud: bool) -> Texture2D:
	if _dust_tx.has(cloud): return _dust_tx[cloud]
	var sz := 64 if cloud else 16
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var nz := FastNoiseLite.new()
	nz.seed = 7
	nz.frequency = 0.045
	nz.fractal_octaves = 3
	for y in sz:
		for x in sz:
			var d := Vector2(x + 0.5 - sz * 0.5, y + 0.5 - sz * 0.5).length() / (sz * 0.5)
			var a := clampf(1.0 - d, 0.0, 1.0)
			if cloud:
				a = smoothstep(0.0, 0.7, a) * clampf(0.35 + nz.get_noise_2d(x, y) * 1.1, 0.0, 1.0)
			else:
				a = smoothstep(0.0, 0.6, a)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	var t := ImageTexture.create_from_image(img)
	_dust_tx[cloud] = t
	return t

func _process(dt: float) -> void:
	_since += dt
	# (alexandrite's lamp: the flame breathes, its glow at the card's edge with it)
	if _lamp_glow and studio._lamp > 0.001:
		var f := studio.lamp_flicker(_since)
		_lamp_glow.modulate.a = studio._lamp * f
	elif _lamp_glow:
		_lamp_glow.modulate.a = 0.0
	_shake_cd = maxf(0.0, _shake_cd - dt)
	if _shake_cd <= 0.0 and is_instance_valid(live):
		var jerk := (Input.get_accelerometer() - Input.get_gravity()).length()
		if jerk > SHAKE_G:
			_shake_cd = 1.0
			shake_find(clampf(jerk / SHAKE_G - 0.4, 0.6, 1.6))
	if _since >= 1.0 / FPS - 0.002 and is_visible_in_tree():
		_since = 0.0
		studio.vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	# (the camera's own rise is kept while the stone is not zoomed: the card sets it as it lays itself out)
	if _zoom <= 1.001 and _zoom_to <= 1.001: _v0 = studio.cam.v_offset
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - dt * 2.4)
		studio.cam.h_offset = sin(_shake * 46.0) * 0.07 * _shake * _shake
	if is_nan(_aim) and live: _aim = _aim_of(live)
	if absf(_zoom - _zoom_to) > 0.001:
		_zoom = lerpf(_zoom, _zoom_to, minf(1.0, dt * 12.0))
		studio.cam.fov = _fov0 / _zoom
	if not is_nan(_aim) and _zoom > 1.001: studio.cam.v_offset = _v0 + _aim * (1.0 - 1.0 / _zoom)
	# a fluorescent find: the studio goes dark in step with its glow; a star heart dims it a little
	studio.set_uv(Spec.uv if live and live.has_meta("fluor") else 0.75 if live and live.has_meta("dark") else 0.4 if live and (live.has_meta("heart_light") or live.has_meta("dim")) else 0.0)
	if live and live.has_meta("heart_light"):
		var hl: OmniLight3D = live.get_meta("heart_light")
		if is_instance_valid(hl): hl.light_energy = 1.2 + 2.2 * Spec.beat
	if not live or still:
		return
	dt = minf(dt, 0.05)
	_t += dt
	if not _drag and live.has_meta("face") and absf(spin_v) < 1.0:
		# a find with a front (an open oyster, a slab): it sways to and fro about its front instead of turning its back
		spin_v = 0.0
		var to := 0.6 + sin(_t * 0.32) * float(live.get_meta("sway", 0.75))
		live.rotation.y = lerp_angle(live.rotation.y, to, minf(1.0, dt * (0.6 if not hold else 0.0)))
	elif not _drag:
		spin_v += ((0.0 if hold else 0.45) - spin_v) * minf(1.0, dt * (2.5 if hold else 1.2))
		live.rotation.y += spin_v * dt
		tilt *= maxf(0.0, 1.0 - dt * 0.8)
	live.rotation.x += (tilt + sin(_t * 0.7) * 0.06 - live.rotation.x) * minf(1.0, dt * 6.0)
	live.position.y = sin(_t * 1.1) * 0.06
	for a in live.get_meta("anim", []):
		var n: Node3D = a[0]
		match a[1]:
			"x": n.rotate_object_local(Vector3.RIGHT, a[2] * dt)
			"y": n.rotate_object_local(Vector3.UP, a[2] * dt)
			_: n.rotate_object_local(Vector3.BACK, a[2] * dt)

## how far down a zoom goes: to the lower third of a crystal on its rock (0 for anything else — a skull, a fossil, a lump)
static func _aim_of(p: Node3D) -> float:
	if p == null or p.get_child_count() == 0: return 0.0
	var g: Dictionary = p.get_child(0).get_meta("genome", {})
	if g.is_empty() or String(g.get("form", "")) in SpecGenome.NO_BASE or String(g.get("form", "")) == "skull" or String(g.get("lustre", "")) == "fossil": return 0.0
	var b := SpecUtil.box_of(p)
	var y := b.position.y + b.size.y * 0.3
	# (a tall lone crystal on a stub of rock: its lower third is still bare crystal — down to where it leaves the rock)
	for m in p.find_children("*", "MeshInstance3D", true, false):
		if m.has_meta("base") and m.has_meta("geo"):
			var rb := SpecUtil.rel_xform(m, p) * (m.get_meta("geo") as Geo).aabb()
			y = minf(y, rb.end.y + b.size.y * 0.06)
			break
	return y - b.get_center().y

func _set_zoom(z: float) -> void:
	_zoom_to = clampf(z, 1.0, ZOOM_MAX)

func _gui_input(e: InputEvent) -> void:
	if zoomable and _zoom_gesture(e):
		_press_ms = -1
		accept_event()
		return
	_tap(e)
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		_drag = e.pressed
		accept_event()
	elif e is InputEventScreenTouch:
		_drag = e.pressed
		accept_event()
	elif (e is InputEventMouseMotion and _drag) or e is InputEventScreenDrag:
		var r: Vector2 = e.relative * (390.0 / maxf(1.0, size.x))
		if live:
			live.rotation.y += r.x * 0.012
			spin_v = clampf(r.x * 0.7, -9.0, 9.0)
			tilt = clampf(tilt + r.y * 0.008, -0.7, 0.7)
		accept_event()

## a press let go soon, near where it went down (touch and the mouse it emulates count once)
func _tap(e: InputEvent) -> void:
	var down: bool = (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT) or e is InputEventScreenTouch
	if down and e.pressed:
		_press = e.position
		_press_ms = Time.get_ticks_msec()
	elif down and _press_ms >= 0:
		var now := Time.get_ticks_msec()
		if now - _press_ms < 350 and e.position.distance_to(_press) < 12.0 and now - _tap_ms > 150:
			_tap_ms = now
			tapped.emit()
			_wet()
			_lamp()
		_press_ms = -1

## (19.11) a tap on an opal egg wets it, as water does hydrophane opal: its milk clears and its fire flares, then over
## a few seconds it dries back (shaders/opal_seam.gdshader, wet)
var _wet_tw: Tween
func _eggs() -> Array:
	var ms: Array = []
	if not is_instance_valid(live): return ms
	for n in live.find_children("*", "MeshInstance3D", true, false):
		var m := (n as MeshInstance3D).material_override as ShaderMaterial
		if not m: continue
		var eo: Variant = m.get_shader_parameter("egg_on")
		if eo != null and float(eo) > 0.0 and not m in ms: ms.append(m)
	return ms

func _wet() -> void:
	var ms := _eggs()
	if ms.is_empty(): return
	var rocks: Array = []
	for n in live.find_children("*", "MeshInstance3D", true, false):
		var rm := (n as MeshInstance3D).material_override as ShaderMaterial
		if rm and rm.has_meta("wet_rock") and not rm in rocks: rocks.append(rm)
	var set_w := func(x: float) -> void:
		for m: ShaderMaterial in ms: m.set_shader_parameter("wet", x)
		# (wet stone: darker)
		for m: ShaderMaterial in rocks: m.set_shader_parameter("albedo", Vector3.ONE * (1.0 - 0.38 * x))
	var w0v: Variant = (ms[0] as ShaderMaterial).get_shader_parameter("wet")
	var w0 := float(w0v) if w0v != null else 0.0
	if _wet_tw: _wet_tw.kill()
	# a shower over the card first: streaks of rain falling from the top, splashing where the stone is
	var rain := Rain.new()
	rain.size = size
	rain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rain.clip_contents = true
	add_child(rain)
	Sfx.play("opal_rain")
	_wet_tw = create_tween()
	_wet_tw.tween_interval(0.35)
	_wet_tw.tween_method(set_w, w0, 1.0, 0.7).set_trans(Tween.TRANS_SINE)
	_wet_tw.tween_interval(1.6)
	_wet_tw.tween_method(set_w, 1.0, 0.0, 6.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

## (20.11) a tap on an alexandrite card swaps daylight for a warm lamp and back: the lights go amber over a second,
## and the stone, a beat behind, turns from green to raspberry (spec.gdshaderinc alex_k) — as the real one does by
## candlelight. It stays so until the next tap
var _lamp_on := false
var _lamp_tw: Tween
var _lamp_glow: TextureRect
func _lamp() -> void:
	if not (is_instance_valid(live) and live.get_meta("alex", false)): return
	var ms: Array = []
	for n in live.find_children("*", "MeshInstance3D", true, false):
		var m := (n as MeshInstance3D).material_override as ShaderMaterial
		if m and m.has_meta("alex") and not m in ms: ms.append(m)
	if ms.is_empty(): return
	_lamp_on = not _lamp_on
	var to := 1.0 if _lamp_on else 0.0
	var light := func(x: float) -> void: studio.set_lamp(x)
	var stone := func(x: float) -> void:
		for m: ShaderMaterial in ms: m.set_shader_parameter("alex_k", x)
	var a0v: Variant = (ms[0] as ShaderMaterial).get_shader_parameter("alex_k")
	if _lamp_tw: _lamp_tw.kill()
	Sfx.play("sh_flame" if _lamp_on else "click")
	if _lamp_on: Awards.once("tsar_stone")
	# the lamp's warm glow in from the card's right edge (additive: the shared add shader, not a CanvasItemMaterial)
	if not _lamp_glow:
		_lamp_glow = TextureRect.new()
		_lamp_glow.texture = FxLayer.puff()
		_lamp_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_lamp_glow.stretch_mode = TextureRect.STRETCH_SCALE
		_lamp_glow.material = FxLayer.add_material()
		_lamp_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_lamp_glow.self_modulate = Color(1.0, 0.55, 0.2, 0.55)
		_lamp_glow.modulate.a = 0.0
		add_child(_lamp_glow)
	var gs := size.x * 1.1
	_lamp_glow.size = Vector2(gs, gs)
	_lamp_glow.position = Vector2(size.x - gs * 0.38, size.y * 0.42 - gs * 0.5)
	_lamp_tw = create_tween().set_parallel()
	_lamp_tw.tween_method(light, studio._lamp, to, 0.9).set_trans(Tween.TRANS_SINE)
	_lamp_tw.tween_method(stone, float(a0v) if a0v != null else 0.0, to, 1.7).set_trans(Tween.TRANS_SINE).set_delay(0.25)

## pinch, wheel and double tap; true when the event was a zoom (it then does not turn the stone)
func _zoom_gesture(e: InputEvent) -> bool:
	if e is InputEventScreenTouch:
		if e.pressed: _touch[e.index] = e.position
		else: _touch.erase(e.index)
		if _touch.size() == 2:
			var pts: Array = _touch.values()
			_pinch0 = maxf(1.0, (pts[0] as Vector2).distance_to(pts[1]))
			_pinch_zoom = _zoom_to
			_drag = false
			return true
		if e.pressed and e.double_tap:
			_set_zoom(1.0 if _zoom_to > 1.3 else 2.2)
			return true
		return _touch.size() > 1
	if e is InputEventScreenDrag and _touch.size() >= 2:
		_touch[e.index] = e.position
		var pts: Array = _touch.values()
		_set_zoom(_pinch_zoom * (pts[0] as Vector2).distance_to(pts[1]) / _pinch0)
		return true
	if e is InputEventMagnifyGesture:
		_set_zoom(_zoom_to * e.factor)
		return true
	if e is InputEventMouseButton and e.pressed:
		match e.button_index:
			MOUSE_BUTTON_WHEEL_UP: _set_zoom(_zoom_to * 1.12)
			MOUSE_BUTTON_WHEEL_DOWN: _set_zoom(_zoom_to / 1.12)
			MOUSE_BUTTON_LEFT:
				if not e.double_click: return false
				_set_zoom(1.0 if _zoom_to > 1.3 else 2.2)
			_: return false
		return true
	# while two fingers are down the emulated mouse must not turn the stone either
	return _touch.size() > 1 and e is InputEventMouseMotion

## (19.11) the rain a tap on an opal egg brings (SpecView._wet): a shower over the card, drawn by its own shader
## (shaders/rain.gdshader: four depths of falling streaks, the near ones out of focus); the light goes a touch greyer
## while it falls; it comes on in a breath and thins away. (Drawn as lines with splashes and a mist it read as nothing
## like rain)
class Rain extends ColorRect:
	const SHADER := preload("res://shaders/rain.gdshader")
	const DUR := 2.0
	var t := 0.0
	var m: ShaderMaterial

	func _ready() -> void:
		color = Color(1, 1, 1, 1)
		m = ShaderMaterial.new()
		m.shader = SHADER
		m.set_shader_parameter("aspect", size.y / maxf(1.0, size.x))
		m.set_shader_parameter("seed", randf() * 10.0)
		material = m
		var veil := ColorRect.new()
		veil.color = Color(0.04, 0.07, 0.11, 0.0)
		veil.size = size
		veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		veil.show_behind_parent = true
		add_child(veil)
		set_meta("veil", veil)

	func _process(dt: float) -> void:
		t += dt
		if t > DUR + 0.7:
			queue_free()
			return
		var on := smoothstep(0.0, 0.25, t) * (1.0 - smoothstep(DUR - 0.4, DUR + 0.6, t))
		m.set_shader_parameter("on", on)
		(get_meta("veil") as ColorRect).color.a = 0.22 * on
