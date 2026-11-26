class_name CardMoon
extends Control
## (26.11) The wolf's moon (a beast skull's legend «wolfmoon», SpecBeastFx.MoonNode) and its card. Two small things,
## nothing explained:
## - a tap on the stone and the skull howls: its eyes light, the moon's halo swells, the phone hums with the howl;
##   under a full moon the pack answers from far off, twice;
## - at the new moon, when the card is at its darkest, a wolf's tracks come up across the info panel's slate, one
##   paw after another, and fade.
## Keys: `moon_at=0..1` the month starts here (0 new, 0.5 full), `moon_tap=S` a tap every S seconds.

const HOWL_T := 3.4          # a howl, seconds
const HOWL_REST := 5.0       # not oftener than this
const FULL := 0.82           # the moon is full enough for the pack to answer
const STEP := 0.34           # a paw after a paw, seconds
const HOLD := 2.6
const FADE := 2.2

var card: Control
var view: SpecView
var info: Control
var moon: SpecBeastFx.MoonNode
var _tracks: Control
var _prints := []            # [pos, angle, born]
var _t := 0.0
var _howl_at := -100.0
var _was_new := false
var _tap_every := 0.0
var _tap_in := 0.0
var _seed := 1

static func attach(card_: Control, view_: SpecView, info_: Control, fx: String, p: Node3D) -> void:
	if fx != "wolfmoon" or card_.has_meta("moon_card"): return
	var mo := _find(p)
	if mo == null: return
	card_.set_meta("moon_card", true)
	# (a tap on this stone is its howl: the callouts open from the badges, Reveal)
	p.set_meta("wolfmoon", true)
	var cm := CardMoon.new()
	cm.card = card_
	cm.view = view_
	cm.info = info_
	cm.moon = mo
	card_.add_child(cm)

static func _find(n: Node) -> SpecBeastFx.MoonNode:
	if n is SpecBeastFx.MoonNode: return n
	for c in n.get_children():
		var f := _find(c)
		if f: return f
	return null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for ar in OS.get_cmdline_user_args():
		if ar.begins_with("moon_at="): moon.t = float(ar.get_slice("=", 1)) * SpecBeastFx.MoonNode.MONTH
		if ar.begins_with("moon_tap="): _tap_every = float(ar.get_slice("=", 1))
	_tap_in = _tap_every
	# the tracks: inside the info panel, over its slate (its first child) and under its words
	_tracks = Control.new()
	_tracks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(_tracks)
	info.move_child(_tracks, mini(1, info.get_child_count() - 1))
	_tracks.draw.connect(_draw_tracks)
	tree_exiting.connect(func() -> void: if is_instance_valid(_tracks): _tracks.queue_free())
	view.tapped.connect(howl)
	_was_new = _is_new()

func _is_new() -> bool:
	var ph := moon.phase()
	return ph < 0.05 or ph > 0.97

func _process(dt: float) -> void:
	if not is_instance_valid(view) or not is_instance_valid(info) or not is_instance_valid(moon):
		queue_free()
		return
	_t += dt
	if _tap_every > 0.0:
		_tap_in -= dt
		if _tap_in <= 0.0:
			_tap_in = _tap_every
			howl()
	# (a container lays its children out in its margins: the tracks' layer covers the whole panel)
	_tracks.position = Vector2.ZERO
	_tracks.size = info.size
	var new_now := _is_new()
	if new_now and not _was_new and view.is_visible_in_tree(): _trail()
	_was_new = new_now
	if not _prints.is_empty():
		_tracks.queue_redraw()
		if _t - float(_prints.back()[2]) > 0.5 + HOLD + FADE:
			_prints.clear()
			_tracks.queue_redraw()

## the skull howls (a tap on the stone); under a full moon the pack answers
func howl() -> void:
	if _t - _howl_at < HOWL_REST or not is_instance_valid(moon): return
	_howl_at = _t
	moon.howl(HOWL_T)
	Sfx.play("wolf_howl")
	# the phone hums as the howl swells and trails off
	for i in 7:
		var ms := [40, 70, 110, 130, 110, 70, 40][i] as int
		get_tree().create_timer(0.15 + i * 0.36).timeout.connect(func() -> void: Sfx.buzz(ms))
	if moon.full() >= FULL:
		for d: float in [2.3, 3.9]:
			get_tree().create_timer(d).timeout.connect(func() -> void: Sfx.play("wolf_far"))

## a wolf walks across the panel: a line of prints, hind foot into the fore foot's place, each side in turn
func _trail() -> void:
	_seed += 1
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed * 7919 + int(info.size.x)
	var sz := info.size
	var left := rng.randf() < 0.5
	var a := Vector2(-12.0 if left else sz.x + 12.0, sz.y * rng.randf_range(0.55, 0.9))
	var b := Vector2(sz.x + 12.0 if left else -12.0, sz.y * rng.randf_range(0.1, 0.45))
	var dir := (b - a).normalized()
	var side := Vector2(-dir.y, dir.x)
	var stride := 46.0
	var n := int(a.distance_to(b) / stride)
	_prints.clear()
	for i in n:
		var p := a + dir * (stride * (i + 0.5)) + side * ((7.0 if i % 2 == 0 else -7.0) + rng.randf_range(-1.5, 1.5))
		_prints.append([p, dir.angle() + PI * 0.5 + rng.randf_range(-0.12, 0.12), _t + i * STEP])

func _draw_tracks() -> void:
	for pr: Array in _prints:
		var age := _t - float(pr[2])
		if age < 0.0: continue
		var k := clampf(age / 0.5, 0.0, 1.0) * clampf(1.0 - (age - 0.5 - HOLD) / FADE, 0.0, 1.0)
		if k <= 0.0: continue
		_paw(pr[0], float(pr[1]), 0.2 * k)

## a wolf's print, its toes towards -y before the turn: the heel pad, four toes, the claws' marks ahead of them
func _paw(at: Vector2, ang: float, alpha: float) -> void:
	var col := Color(0.74, 0.84, 1.0, alpha)
	var dim := Color(0.74, 0.84, 1.0, alpha * 0.55)
	_tracks.draw_set_transform(at, ang, Vector2.ONE)
	# the heel pad: wide behind, drawn in at the front
	var pad := PackedVector2Array()
	for i in 20:
		var t := TAU * i / 20.0
		var r := 5.6 + 1.3 * cos(t * 3.0 + PI)
		pad.append(Vector2(cos(t) * r * 1.05, 4.5 + sin(t) * r * 0.8))
	_tracks.draw_colored_polygon(pad, col)
	# the toes: two in front, two at the sides, and the claws
	for toe: Array in [[-3.4, -6.5, -0.12], [3.4, -6.5, 0.12], [-7.6, -1.2, -0.5], [7.6, -1.2, 0.5]]:
		var c := Vector2(float(toe[0]), float(toe[1]))
		var pts := PackedVector2Array()
		for i in 14:
			var t := TAU * i / 14.0
			pts.append(c + Vector2(cos(t) * 2.5, sin(t) * 3.6).rotated(float(toe[2])))
		_tracks.draw_colored_polygon(pts, col)
		_tracks.draw_circle(c + Vector2(0, -5.6).rotated(float(toe[2])), 0.8, dim)
	_tracks.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
