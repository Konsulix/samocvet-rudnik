class_name CardLava
extends Control
## The lava stone's lava (SpecLegend.lava) does not keep to its frame: now and then a drop swells under the stone where
## its own drips fall, lets go, falls and splashes on the brass ribbon between the stone and the info panel — spreads
## along it, hangs over its lower edge as a drip with a bead at its tip, cools from white-yellow through orange and red
## to a dark crust with its cracks still lit, and crumbles away after a while. The brass round each drop glows red
## while it is hot, and the card's whole frame warms with the lava on it. All drawn by one shader in two passes
## (shaders/card_lava.gdshaderinc): the lava itself, and the light it gives, added - each in two pieces: over the card
## down to the ribbon, and below it inside the info panel, over its slate and under its words (the drips hang under
## the lettering). A drip that reaches a word scorches it - it flares hot and darkens, then slowly comes back - and
## steam rises off it; the slate round a drip is left sooty.

const SLOTS := 8
const FIRST := 1.4            # the first drop, this long after the stone is built
const EVERY := [2.2, 4.6]     # then one every so often

static var test_every := 0.0  # a test key (-- lava_every=S): a drop every S s

var card: Control
var view: SpecView
var info: Control
var drips: CPUParticles3D
var _lava: ColorRect
var _glow: ColorRect
var _pieces: Array[ColorRect] = []
var _now := 0.0
var _next := FIRST
var _slot := 0
var _a: Array[Vector4] = []
var _b: Array[Vector4] = []
var _c: Array[Vector4] = []
var _burnt: Array[Dictionary] = []   # by slot: the words its drip has scorched already
var _land: Array[float] = []
var rng := RandomNumberGenerator.new()

## p: the built find; only a lava stone (its drips marked by SpecLegend.lava)
static func attach(card_: Control, view_: SpecView, info_: Control, p: Node3D) -> void:
	var found := p.find_children("*", "CPUParticles3D", true, false).filter(func(n: Node) -> bool: return n.has_meta("lava_drips"))
	if found.is_empty(): return
	var cl := CardLava.new()
	cl.card = card_
	cl.view = view_
	cl.info = info_
	cl.drips = found[0]
	card_.add_child(cl)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 5
	rng.randomize()
	for i in SLOTS:
		_a.append(Vector4(0, 0, -9.0, 0))
		_b.append(Vector4.ZERO)
		_c.append(Vector4(0, 1, 0, 0))
		_burnt.append({})
		_land.append(-1.0)
	_lava = _pass(preload("res://shaders/card_lava.gdshader"), 0, 0, self)
	_glow = _pass(preload("res://shaders/card_lava_glow.gdshader"), 1, 0, self)
	# inside the info panel, over its slate (its first child) and under its words: a holder it lays out, the pieces
	# themselves placed over the whole card each frame (as CardFrost's)
	var hold := Control.new()
	hold.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(hold)
	info.move_child(hold, mini(1, info.get_child_count() - 1))
	_pass(preload("res://shaders/card_lava.gdshader"), 0, 1, hold)
	_pass(preload("res://shaders/card_lava_glow.gdshader"), 1, 1, hold)
	tree_exiting.connect(func() -> void: if is_instance_valid(hold): hold.queue_free())

func _pass(sh: Shader, g: int, part: int, host: Control) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color.WHITE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("glow", g)
	m.set_shader_parameter("part", part)
	r.material = m
	host.add_child(r)
	_pieces.append(r)
	return r

## a point of the stone's scene on the card (as CardBolt finds its own)
func _proj(w: Vector3) -> Vector2:
	var cam := view.studio.cam
	var k := view.size / Vector2(maxi(1, view.studio.vp.size.x), maxi(1, view.studio.vp.size.y))
	return card.get_global_transform().affine_inverse() * (view.get_global_transform() * (cam.unproject_position(w) * k))

## the ribbon in the card's own space: [top, bottom, left, right] of its straight stretch (Reveal._info_rim draws it)
func _rim() -> Array:
	var ig: Rect2 = card.get_global_transform().affine_inverse() * info.get_global_transform() * Rect2(Vector2.ZERO, info.size)
	const WIDE := 20.0 / 3.6
	return [ig.position.y - WIDE, ig.position.y, ig.position.x + Reveal.INFO_R + 6.0, ig.end.x - Reveal.INFO_R - 6.0]

func _drop(rim: Array) -> void:
	# from under the stone, where its own drips fall (SpecLegend.lava's points), straight down onto the ribbon
	var src := Vector2(card.size.x * 0.5, float(rim[0]) - 150.0)
	var pts := drips.emission_points
	for tries in 6:
		var q := _proj(drips.global_transform * (pts[rng.randi() % pts.size()] if pts.size() else Vector3.ZERO))
		if q.x > float(rim[2]) + 10.0 and q.x < float(rim[3]) - 10.0 and q.y < float(rim[0]) - 40.0:
			src = q
			break
	# each its own: small and quick, or big and slow; a thin drip or a fat one; leaning; a lopsided puddle
	var sz := rng.randf_range(4.0, 9.5) if rng.randf() < 0.75 else rng.randf_range(9.5, 12.0)
	var i := _slot
	_slot = (_slot + 1) % SLOTS
	_a[i] = Vector4(src.x, src.y, _now, sz)
	# its own seed, how long its drip hangs, where along the puddle the drip is, how wide the puddle spreads
	var long := rng.randf()
	var L := rng.randf_range(44.0, 62.0) if long < 0.15 else rng.randf_range(26.0, 44.0) if long < 0.5 else rng.randf_range(8.0, 24.0)
	_b[i] = Vector4(rng.randf(), L, rng.randf_range(-0.7, 0.7), rng.randf_range(9.0, 28.0))
	_c[i] = Vector4(rng.randf_range(-0.45, 0.45), rng.randf_range(0.55, 1.6) * (1.25 if long < 0.15 else 1.0), rng.randf_range(-1.0, 1.0), 0)
	_burnt[i] = {}
	_land[i] = _now + 0.45 + sqrt(2.0 * maxf(float(rim[0]) - src.y - sz, 1.0) / 1100.0)

func _process(dt: float) -> void:
	if not is_instance_valid(view) or not is_instance_valid(drips) or not is_instance_valid(info):
		queue_free()
		return
	_now += dt
	var rim := _rim()
	# only while the card is open and settled (it opens with a scale tween)
	if view.is_visible_in_tree() and card.scale.is_equal_approx(Vector2.ONE):
		_next -= dt
		if _next <= 0.0:
			_drop(rim)
			_next = test_every if test_every > 0.0 else rng.randf_range(EVERY[0], EVERY[1])
	# a hiss as each one lands
	for i in SLOTS:
		if _land[i] > 0.0 and _now >= _land[i]:
			_land[i] = -1.0
			Sfx.play("sh_flame")
	_scorch(rim)
	for r in _pieces:
		# over the whole card, frame and all (this layer is laid out inside the card's padding: the brass rim is
		# outside it - 23.11: the veins ran inside the rim; the panel's pieces likewise, wherever they sit)
		r.global_position = card.global_position
		r.size = card.size
		var m := r.material as ShaderMaterial
		m.set_shader_parameter("card", card.size)
		m.set_shader_parameter("frame_in", Reveal.CARD_PAD)
		m.set_shader_parameter("now", _now)
		m.set_shader_parameter("rim_top", float(rim[0]))
		m.set_shader_parameter("rim_bot", float(rim[1]))
		m.set_shader_parameter("rim_l", float(rim[2]))
		m.set_shader_parameter("rim_r", float(rim[3]))
		m.set_shader_parameter("heat", 0.22)
		m.set_shader_parameter("da", _a)
		m.set_shader_parameter("db", _b)
		m.set_shader_parameter("dc", _c)

## where a drop's main drip has got to (its tip, in the card's space), as the shader draws it; null before it hangs
func _tip(i: int, rim: Array) -> Variant:
	var A := _a[i]
	if A.z < -1.0: return null
	var a := _now - A.z
	var land := 0.45 + sqrt(2.0 * maxf(float(rim[0]) - A.y - A.w, 1.0) / 1100.0)
	var s := a - land
	if s < 0.2 or s > 15.0: return null
	var B := _b[i]
	var w := B.w * (1.0 - exp(-s * 9.0)) + A.w * 0.6
	var L := B.y * (1.0 - exp(-maxf(s - 0.15, 0.0) * 0.9))
	var xd := A.x + B.z * w * 0.5
	return Vector2(xd + _c[i].x * L, float(rim[1]) + L + A.w * 0.55 * _c[i].y * 0.6)

## a drip reaching a word: the word flares hot and darkens (scorched), slowly comes back; steam rises off it
func _scorch(rim: Array) -> void:
	var to_card := card.get_global_transform().affine_inverse()
	var words: Array = info.find_children("*", "Label", true, false)
	for i in SLOTS:
		var tip = _tip(i, rim)
		if tip == null: continue
		for l: Label in words:
			if not l.is_visible_in_tree() or l.text.strip_edges() == "" or _burnt[i].has(l.get_instance_id()): continue
			var r: Rect2 = to_card * l.get_global_transform() * Rect2(Vector2.ZERO, l.size)
			# (the glyphs, not the label's whole box: its middle band, where the letters are)
			r = Rect2(r.position + Vector2(0, r.size.y * 0.2), Vector2(r.size.x, r.size.y * 0.6))
			if not r.has_point(tip): continue
			_burnt[i][l.get_instance_id()] = true
			var was := l.self_modulate
			var tw := l.create_tween()
			tw.tween_property(l, "self_modulate", Color(1.6, 0.75, 0.35), 0.18)
			tw.tween_property(l, "self_modulate", Color(0.62, 0.48, 0.4), 1.2)
			tw.tween_interval(5.0)
			tw.tween_property(l, "self_modulate", was, 6.0)
			_steam(tip)
			Sfx.play("sh_flame")

## a puff of steam off a scorched word, rising and spreading as it fades
func _steam(at: Vector2) -> void:
	var ps := CPUParticles2D.new()
	ps.texture = FxLayer.puff()
	ps.one_shot = true
	ps.amount = 22
	ps.lifetime = 2.0
	ps.explosiveness = 0.55
	ps.direction = Vector2.UP
	ps.spread = 28.0
	ps.initial_velocity_min = 14.0
	ps.initial_velocity_max = 30.0
	ps.gravity = Vector2(0, -22.0)
	ps.damping_min = 6.0
	ps.damping_max = 10.0
	ps.scale_amount_min = 0.3
	ps.scale_amount_max = 0.55
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.4))
	sc.add_point(Vector2(1, 1.6))
	ps.scale_amount_curve = sc
	var gr := Gradient.new()
	gr.set_color(0, Color(0.95, 0.93, 0.9, 0.75))
	gr.set_color(1, Color(0.85, 0.85, 0.85, 0.0))
	ps.color_ramp = gr
	ps.position = at - position
	add_child(ps)
	ps.emitting = true
	get_tree().create_timer(2.5).timeout.connect(ps.queue_free)
