class_name CardFrost
extends Node
## The frost bloom (SpecPolar.frost) does not keep to its stone: now and then frost ferns creep over the card's ground
## from its brass rim inward — as the frost blooms on the stone (its cycle: SpecPolar's meta "frost"), holding while it
## holds and thawing in patches as it thaws. Only so far (CAP): a fringe round the rim and over the info panel's edges,
## the stone's oval clear. Only decoration (22.11: the first take froze the buttons and was wiped with a finger — no),
## and only the card's ground frosts: the frost is laid in two pieces under what is on the card — over the stone's
## frame under its name, over the info panel's slate under its words and buttons (shaders/card_frost.gdshader, one
## pattern across both). The frost itself is assets/fx/frost_ferns.png (art/frost_card/gen.sh, GPT).

## the frost grows in from an edge: a strip rooted on its bottom edge (art/frost_card/gen_strip.sh, GPT), laid along
## every side of a zone roots-outward (22.11: a photo of frost revealed near the rim pointed its fronds anywhere)
const TEX := preload("res://assets/fx/frost_strip.png")
const DEPTH := 190.0         # how deep the strip runs in from the stone's frame; the info panel, small, half of it
const CAP := 1.0             # how far it reaches at its fullest (the shader's growth)

static var test_period := 0.0   # a test key (-- frost_period=S): the cycle S s long, starting now

var card: Control
var phase := 0.0
var period := 16.0
var _pieces: Array[ColorRect] = []
var _was_t := 2.0
var _rng := RandomNumberGenerator.new()

## p: the built find; view: its stone's frame; info: the panel under it (its first child is its slate)
static func attach(card_: Control, view: Control, info: Control, p: Node3D) -> void:
	if not p.has_meta("frost"): return
	var cf := CardFrost.new()
	var m: Array = p.get_meta("frost")
	cf.phase = float(m[0])
	cf.period = float(m[1])
	cf.card = card_
	card_.add_child(cf)
	# over the stone's picture, under the name, the shade, the ✕ and the callouts
	cf._piece(view, (view as SpecView)._img.get_index() + 1 if view is SpecView else 1)
	# over the panel's slate (its first child), under its words and buttons — a zone of its own: from its own four sides
	cf._piece(info, 1).set_meta("zone", 1.0)

func _piece(host: Control, at: int) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color.WHITE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	sm.shader = preload("res://shaders/card_frost.gdshader")
	sm.set_shader_parameter("strip", TEX)
	r.material = sm
	if host is Container:
		# (a container lays its children out inside its margins: the frost goes in a holder it lays out, and itself
		# covers the whole panel — to its very edge, as the slate is drawn — 22.11: it began in a box inside the panel)
		var hold := Control.new()
		hold.mouse_filter = Control.MOUSE_FILTER_IGNORE
		host.add_child(hold)
		host.move_child(hold, mini(at, host.get_child_count() - 1))
		hold.add_child(r)
		r.set_meta("whole", host)
	else:
		host.add_child(r)
		host.move_child(r, mini(at, host.get_child_count() - 1))
		r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pieces.append(r)
	return r

func _ready() -> void:
	if test_period > 0.0:
		period = test_period
		phase = -Time.get_ticks_msec() / 1000.0 / period

func _reroll() -> void:
	for r in _pieces:
		if not is_instance_valid(r): continue
		var sm := r.material as ShaderMaterial
		# one side gets going first, the rest after it, one of them late or hardly at all
		var d := Vector4(_rng.randf() * 0.45, _rng.randf() * 0.45, _rng.randf() * 0.45, _rng.randf() * 0.45)
		d[_rng.randi() % 4] = 0.0
		d[_rng.randi() % 4] = _rng.randf_range(0.5, 0.75)
		sm.set_shader_parameter("sd", d)
		sm.set_shader_parameter("ss", Vector4(_rng.randf_range(0.75, 1.15), _rng.randf_range(0.75, 1.15), _rng.randf_range(0.75, 1.15), _rng.randf_range(0.75, 1.15)))
		sm.set_shader_parameter("sa", Vector4(_rng.randf(), _rng.randf(), _rng.randf(), _rng.randf()))

func _process(_dt: float) -> void:
	if not is_instance_valid(card): return
	# the stone's own cycle: grow, hold, thaw (as shaders/frost_bloom.gdshader keeps it)
	var t := fposmod(Time.get_ticks_msec() / 1000.0 / period + phase, 1.0)
	# a new cycle: each side of each zone its own start, pace and spot along the rim, this time
	if t < _was_t: _reroll()
	_was_t = t
	var grow := CAP * smoothstep(0.0, 0.5, t)
	var thaw := smoothstep(0.76, 0.98, t)
	var inv := card.get_global_transform().affine_inverse()
	for r in _pieces:
		if not is_instance_valid(r): continue
		if r.has_meta("whole"):
			var whole: Control = r.get_meta("whole")
			r.global_position = whole.global_position
			r.size = whole.size
		var sm := r.material as ShaderMaterial
		sm.set_shader_parameter("card", card.size)
		sm.set_shader_parameter("origin", inv * r.global_position)
		sm.set_shader_parameter("rsize", r.size)
		sm.set_shader_parameter("grow", grow)
		sm.set_shader_parameter("thaw", thaw)
		var z := float(r.get_meta("zone", 0.0))
		sm.set_shader_parameter("zone", z)
		sm.set_shader_parameter("depth", DEPTH * (0.4 if z > 0.5 else 1.0))
