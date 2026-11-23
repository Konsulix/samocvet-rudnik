class_name CardAurora
extends Control
## The northern lights (SpecPolar.borealis) make the whole card a shiny one, as a holographic trading card: the stone's
## window is the night sky with the aurora (SpecStudio.set_aurora, in the stone's studio), the info panel's slate gives
## way to the night with the aurora's glow on it from above (shaders/card_aurora_panel.gdshader, over the slate and
## under the words), and over the brass — the card's rim and the ribbon — a sheen of aurora colours sweeps as the phone
## is tilted (shaders/card_aurora_foil.gdshader, added light; on a computer, with no gravity sensor, it drifts).

var card: Control
var info: Control
var _panel: ColorRect
var _foil: ColorRect
var _hold: Control
var _t := 0.0
var _tilt := Vector2.ZERO

## p: the built find; only one with the northern lights (its meta "aurora")
static func attach(card_: Control, info_: Control, p: Node3D) -> void:
	if not p.has_meta("aurora"): return
	var ca := CardAurora.new()
	ca.card = card_
	ca.info = info_
	card_.add_child(ca)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 4
	# the panel's night: over its slate (its first child), under its words — as CardFrost's
	_hold = Control.new()
	_hold.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(_hold)
	info.move_child(_hold, mini(1, info.get_child_count() - 1))
	_panel = ColorRect.new()
	_panel.color = Color.WHITE
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pm := ShaderMaterial.new()
	pm.shader = preload("res://shaders/card_aurora_panel.gdshader")
	_panel.material = pm
	_hold.add_child(_panel)
	_foil = ColorRect.new()
	_foil.color = Color.WHITE
	_foil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fm := ShaderMaterial.new()
	fm.shader = preload("res://shaders/card_aurora_foil.gdshader")
	_foil.material = fm
	add_child(_foil)
	tree_exiting.connect(func() -> void: if is_instance_valid(_hold): _hold.queue_free())

func _process(dt: float) -> void:
	if not is_instance_valid(info) or not is_instance_valid(card):
		queue_free()
		return
	_t += dt
	# the panel, to its very edge (its container lays the holder out inside its margins)
	_panel.global_position = info.global_position
	_panel.size = info.size
	(_panel.material as ShaderMaterial).set_shader_parameter("rsize", info.size)
	# the foil over the whole card, frame and all (this layer sits inside the card's padding)
	_foil.position = -position
	_foil.size = card.size
	# the tilt: the phone's gravity sensor (it is still on a computer: there it drifts by itself)
	var g := Input.get_gravity()
	var want := Vector2(sin(_t * 0.37) * 0.8, sin(_t * 0.23 + 1.0) * 0.6)
	if g.length() > 0.5:
		var n := g.normalized()
		want = Vector2(n.x, n.z) * 1.4
	_tilt = _tilt.lerp(want, minf(1.0, dt * 4.0))
	var ig: Rect2 = card.get_global_transform().affine_inverse() * info.get_global_transform() * Rect2(Vector2.ZERO, info.size)
	var m := _foil.material as ShaderMaterial
	m.set_shader_parameter("card", card.size)
	m.set_shader_parameter("frame_in", Reveal.CARD_PAD)
	m.set_shader_parameter("rim_top", ig.position.y - 20.0 / 3.6)
	m.set_shader_parameter("rim_bot", ig.position.y)
	m.set_shader_parameter("rim_l", ig.position.x + Reveal.INFO_R)
	m.set_shader_parameter("rim_r", ig.end.x - Reveal.INFO_R)
	m.set_shader_parameter("tilt", _tilt)
