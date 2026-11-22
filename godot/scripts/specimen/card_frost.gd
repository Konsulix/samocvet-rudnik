class_name CardFrost
extends ColorRect
## The frost bloom (SpecPolar.frost) does not keep to its stone: frost ferns creep over the card's glass from its brass
## rim inward — a wave of it with each bloom on the stone (its cycle: SpecPolar's meta "frost"), none while the stone's
## own frost holds and thaws, so the card frosts over in two or three blooms. Under it the price blurs and the buttons
## freeze: they take no press. A finger wipes it off — a wet film with droplets that freezes over again in a few
## seconds — and a button wiped clear works again. Drawn by shaders/card_frost.gdshader over the card's content;
## the frost (art/frost_card/gen.sh, GPT) is assets/fx/frost_ferns.png.

const TEX := preload("res://assets/fx/frost_ferns.png")
const RATE := 0.25           # how far it grows with each bloom of the stone (the buttons are under it at ~0.35)
const CAP := 0.6             # a frame of frost over the rim, the panel and the buttons; the stone stays clear
const TILE := 300.0          # the ferns' tile, points
const REFREEZE := 6.0        # s for a wiped spot to frost over again
const BRUSH := 26.0          # the finger, points
const WW := 64               # the wipe map, across

static var test_fast := 0.0  # a test key (-- frost_fast=N): it grows N a second whatever the stone does
static var test_wipe := false   # a test key (-- frost_wipe): once grown, a finger wipes across the buttons

var card: Control
var box: Control
var phase := 0.0
var period := 16.0
var grow := 0.0
var _cpu: Image              # the ferns' texture, read here for where the frost is (the buttons)
var _img: Image
var _tex: ImageTexture
var _wipe := PackedFloat32Array()
var _wh := 120
var _wet := false
var _down := false
var _last := Vector2.ZERO
var _frozen := {}            # button -> its own mouse_filter
var _tick := 0.0
var _squeak := 0.0
var _test_t := -1.0

static func attach(card_: Control, box_: Control, p: Node3D) -> void:
	if not p.has_meta("frost"): return
	var cf := CardFrost.new()
	var m: Array = p.get_meta("frost")
	cf.phase = float(m[0])
	cf.period = float(m[1])
	cf.card = card_
	cf.box = box_
	card_.add_child(cf)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color.WHITE
	var sm := ShaderMaterial.new()
	sm.shader = preload("res://shaders/card_frost.gdshader")
	sm.set_shader_parameter("ferns", TEX)
	sm.set_shader_parameter("tile", TILE)
	material = sm
	_cpu = TEX.get_image()
	if _cpu.is_compressed(): _cpu.decompress()
	resized.connect(_fit)
	_fit()

func _fit() -> void:
	if size.x < 4.0: return
	_wh = maxi(8, roundi(WW * size.y / size.x))
	_wipe.resize(WW * _wh)
	_wipe.fill(0.0)
	_img = Image.create(WW, _wh, false, Image.FORMAT_L8)
	_tex = ImageTexture.create_from_image(_img)
	var sm := material as ShaderMaterial
	sm.set_shader_parameter("wipe", _tex)
	sm.set_shader_parameter("card", size)

func _process(dt: float) -> void:
	if not is_instance_valid(card) or not is_visible_in_tree(): return
	# it grows with the stone's blooms (the first half of its cycle), never thaws on the card
	var now := Time.get_ticks_msec() / 1000.0
	if fposmod(now / period + phase, 1.0) < 0.5: grow += dt * RATE / (period * 0.5)
	grow += dt * test_fast
	grow = minf(grow, CAP)
	(material as ShaderMaterial).set_shader_parameter("grow", grow)
	# wiped spots freeze over again
	if _wet:
		_wet = false
		var k := dt / REFREEZE
		for i in _wipe.size():
			if _wipe[i] > 0.0:
				_wipe[i] = maxf(0.0, _wipe[i] - k)
				_wet = true
		_upload()
	_squeak = maxf(0.0, _squeak - dt)
	_tick += dt
	if _tick > 0.15:
		_tick = 0.0
		_buttons()
	if test_wipe: _test(dt)

func _upload() -> void:
	var data := PackedByteArray()
	data.resize(_wipe.size())
	for i in _wipe.size(): data[i] = int(clampf(_wipe[i], 0.0, 1.0) * 255.0)
	_img.set_data(WW, _wh, false, Image.FORMAT_L8, data)
	_tex.update(_img)

## how much frost there is at a point of this node (the shader's own sum, without the fine lines)
func cover(q: Vector2) -> float:
	if size.x < 4.0: return 0.0
	var tx := _cpu.get_pixel(posmod(int(q.x / TILE * _cpu.get_width()), _cpu.get_width()), posmod(int(q.y / TILE * _cpu.get_height()), _cpu.get_height()))
	var e := minf(minf(minf(q.x, q.y), minf(size.x - q.x, size.y - q.y)) / 150.0, 1.0)
	var so := (q - size * Vector2(0.5, 0.34)) / (size * Vector2(0.36, 0.22))
	var stone := maxf(0.0, 1.0 - so.dot(so))
	var front := grow * 1.2 - (e * 0.8 + tx.b * 0.35 - tx.g * 0.25 + stone * 0.9)
	var c := smoothstep(0.0, 0.18, front)
	var wx := clampi(int(q.x / size.x * WW), 0, WW - 1)
	var wy := clampi(int(q.y / size.y * _wh), 0, _wh - 1)
	return c * (1.0 - smoothstep(0.12, 0.65, _wipe[wy * WW + wx]))

## a button under the frost takes no press; wiped clear it works again (and the ice cracks off it)
func _buttons() -> void:
	for b: Button in box.find_children("*", "Button", true, false):
		if not b.is_visible_in_tree(): continue
		var r := Rect2(get_global_transform().affine_inverse() * b.global_position, b.size)
		var c := 0.0
		for f: Vector2 in [Vector2(0.25, 0.5), Vector2(0.5, 0.5), Vector2(0.75, 0.5)]:
			c += cover(r.position + r.size * f) / 3.0
		if c > 0.5 and not _frozen.has(b):
			_frozen[b] = b.mouse_filter
			b.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if not Save.told("t_frost"):
				Save.tell("t_frost")
				Ov.toast("Frost on the glass — wipe it off")
		elif c < 0.3 and _frozen.has(b):
			b.mouse_filter = _frozen[b]
			_frozen.erase(b)
			Sfx.play("crust")
			Sfx.buzz(20)

func _exit_tree() -> void:
	for b: Control in _frozen:
		if is_instance_valid(b): b.mouse_filter = _frozen[b]
	_frozen.clear()

func _input(e: InputEvent) -> void:
	if not is_visible_in_tree() or grow <= 0.02: return
	if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var q := get_global_transform().affine_inverse() * (e as InputEventMouseButton).global_position
		_down = e.pressed and Rect2(Vector2.ZERO, size).has_point(q)
		if _down:
			_last = q
			_paint(q, q)
	elif e is InputEventMouseMotion and _down:
		var q := get_global_transform().affine_inverse() * (e as InputEventMouseMotion).global_position
		_paint(_last, q)
		_last = q

## the finger's stroke from a to b, into the wipe map; a squeak now and then while it wipes real frost
func _paint(a: Vector2, b: Vector2) -> void:
	if cover(b) > 0.2 and _squeak <= 0.0:
		_squeak = 0.22
		Sfx.play("glass_tap")
	var steps := maxi(1, int(a.distance_to(b) / 5.0))
	var sx := WW / size.x
	var sy := _wh / size.y
	var rx := BRUSH * sx
	for s in steps + 1:
		var q := a.lerp(b, s / float(steps))
		var cx := q.x * sx
		var cy := q.y * sy
		for y in range(maxi(0, int(cy - rx)), mini(_wh, int(cy + rx) + 1)):
			for x in range(maxi(0, int(cx - rx)), mini(WW, int(cx + rx) + 1)):
				var d := Vector2(x + 0.5 - cx, y + 0.5 - cy).length() / rx
				if d < 1.0:
					var i := y * WW + x
					_wipe[i] = maxf(_wipe[i], 1.0 - d * d * 0.6)
	_wet = true
	_upload()

## (frost_wipe: once it has grown, a finger runs across the buttons and back)
func _test(dt: float) -> void:
	if grow < CAP and _test_t < 0.0: return
	_test_t += dt if _test_t >= 0.0 else 1.0 + dt
	var k := (_test_t - 1.5) / 0.8
	if k < 0.0 or k > 1.0: return
	var y := size.y - 34.0
	var a := Vector2(lerpf(20.0, size.x - 20.0, maxf(0.0, k - 0.04)), y + sin(k * 18.0) * 14.0)
	var b := Vector2(lerpf(20.0, size.x - 20.0, k), y + sin(k * 18.0 + 0.7) * 14.0)
	_paint(a, b)
