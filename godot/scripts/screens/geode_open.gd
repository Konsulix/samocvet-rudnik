class_name GeodeOpen
extends CanvasLayer
## Opening geodes like a pack in Hearthstone (playtest 31.10, task 15): the screen goes dark, the geode lies big in
## the middle and sways; every tap cracks it deeper and light of the stone's rarity bursts out of the cracks (common
## warm white, rare blue, epic violet, very rare magenta, legendary gold - with the screen shaking), the last tap holds
## a breath, the geode splits into two halves of white druse lit in that colour and the stone rises out into its card
## (Reveal.show_stone). Several at once lie side by side: tap one, or "Open all". The rarity shows before the stone.
##   await GeodeOpen.run(stones)
##   await GeodeOpen.run([stone], {title = "...", short = true})   - one tap opens it (the find dug out on the board)
## Pictures: art/geode_open/gen.sh (GPT, in the board's painting) -> cut.py -> assets/ui/geode/ (whole, half_l,
## half_r + geode.json: where each half's hollow is). The cracks are drawn here: jagged lines run from the blow,
## tapering to hairlines, forking; each a dark gap with a white-hot thread of light inside, the light spilling over the
## knobbly rind round it (shaders/geode_rind.gdshader), flickering, sparks seeping out.

signal done

const DIR := "res://assets/ui/geode/"
## the light out of the cracks, by tier (Data.RC's hues, the common one warm white as in the task)
const LIGHT := [Color("#ffe9c4"), Color("#4f8fff"), Color("#a55cff"), Color("#ee3fe6"), Color("#ffbf2e")]
const HITS := 3
const W0 := 0.042        # a crack's half width at the blow, fully open (the rind's radius is 1)
const REACH := [0.0, 0.42, 0.74, 1.0]    # how far the split line has run after each tap
const OPEN := [0.0, 0.5, 0.75, 1.0]      # how wide the gaps are
const GROW := 0.17       # seconds a crack takes to run
const BIG := 280.0       # the geode alone in the middle, points (its picture's longer side)
const SMALL := 108.0     # side by side
const HALF_K := 0.72     # the halves, against the whole: smaller, so the two side by side stay on the screen
const HOLD := 0.3        # the breath after the last tap
const SPLIT := 0.3       # the halves part and the stone's light flies up - the card unfolds out of it while it still rises
const RISE := 0.42       # how long the light would take to reach its top: the card takes it on the way, never at a stop
## a tap in the "Open all" run, seconds apart; snapshots set `auto` to play it through by itself
const AUTO_GAP := 0.42
static var auto := false

var stones: Array
var title := ""
var short := false        # one tap cracks it right through (the find on the board; the hoard's chosen geode)
var _geo: Array[Geode] = []
var _root: Control
var _dim: ColorRect
var _flash: ColorRect
var _title: Label
var _hint: Label
var _all: Button
var _focus: Geode           # the one being opened
var _busy := false
var _t := 0.0
var _shake := 0.0
var _sparks: Array[Dictionary] = []     # {p, v, life, max, col}: sparks out of the cracks, in screen points
var _rng := RandomNumberGenerator.new()
var _auto_run := false

static var _tex := {}
static var _meta := {}
static func tex(name: String) -> Texture2D:
	if not _tex.has(name): _tex[name] = load(DIR + name + ".png")
	return _tex[name]
static func meta() -> Dictionary:
	if _meta.is_empty():
		var f := FileAccess.open(DIR + "geode.json", FileAccess.READ)
		if f: _meta = JSON.parse_string(f.get_as_text())
	return _meta

static func run(list: Array, opts := {}) -> void:
	if list.is_empty(): return
	var g := GeodeOpen.new()
	g.stones = list
	g.title = String(opts.get("title", ""))
	g.short = bool(opts.get("short", false))
	(Engine.get_main_loop() as SceneTree).root.add_child(g)
	await g.done

## one geode on the screen: where it is, how far it is cracked, its light; drawn in four layers (glow behind, the
## rind in its own shader, the dark gaps / the halves, light in front)
class Geode:
	var s: Dictionary
	var col: Color
	var tier := 0
	var at := Vector2.ZERO        # centre, points
	var size := SMALL
	var hits := 0
	var hit_t := -10.0           # when the last tap landed (GeodeOpen._t)
	var hold_t := -1.0           # the breath began
	var split_t := -1.0          # the halves began to part
	var orb_gone := false        # the stone's light has gone into its card
	var fade := 1.0              # dimmed while another is opened
	var seed_v := 0
	var origin := Vector2.ZERO   # where it is struck, unit coords
	## the cracks: {pts, wid, arc (length along it from its root), born (the tap that opens it), delay, t0 (when it
	## began to run, -1 not yet), arm (one of the two halves of the split line)}
	var cracks: Array[Dictionary] = []
	var reach_from := 0.0        # how far the split line has run, eased between taps
	var reach_to := 0.0
	var open_from := 0.0         # how wide the gaps are
	var open_to := 0.0
	var grow_t := -10.0
	## worked out each frame (GeodeOpen._shape): each crack as far as it has run, in screen points with half widths,
	## and points along them for the rind's shader
	var vis: Array = []
	var uvs := PackedVector3Array()
	var back: Control
	var rind: Control
	var body: Control
	var front: Control

	func _init(stone: Dictionary) -> void:
		s = stone
		tier = 4 if s.get("legend", false) else clampi(int(s.get("tier", 0)), 0, 4)
		col = LIGHT[tier]
		seed_v = int(s.get("id", 7)) * 977 + 13
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_v
		origin = Vector2(rng.randf_range(-0.14, 0.14), rng.randf_range(-0.22, 0.06))
		# the split line: two arms from the blow, up and down to the rind's edge, jagged at every scale
		var arms: Array[Dictionary] = []
		for dy: float in [-1.0, 1.0]:
			var end := Vector2(rng.randf_range(-0.3, 0.3), dy).normalized() * 0.94
			var pts := _jag(origin, end, 0.34, 5, rng)
			var arc := _arc(pts)
			var wid := PackedFloat32Array()
			for i in pts.size():
				wid.append(W0 * pow(1.0 - arc[i] / arc[arc.size() - 1], 0.6) * rng.randf_range(0.75, 1.2))
			var arm := {pts = pts, wid = wid, arc = arc, born = 1, delay = 0.0, t0 = -1.0, arm = true}
			arms.append(arm)
			cracks.append(arm)
		# a star of short cracks round the blow
		for k in 4:
			_branch(origin, rng.randf() * TAU, rng.randf_range(0.07, 0.14), W0 * 0.55, 1, 0.0, rng)
		# branches off the arms: random roots (more near the blow), off at an angle, some forking; the farther out,
		# the later the tap that opens them
		for k in rng.randi_range(7, 10):
			var arm: Dictionary = arms[rng.randi() % 2]
			var apts: PackedVector2Array = arm.pts
			var awid: PackedFloat32Array = arm.wid
			var f := pow(rng.randf(), 1.3) * 0.82 + 0.06
			var i := clampi(int(f * (apts.size() - 1)), 1, apts.size() - 2)
			var a := (apts[i + 1] - apts[i - 1]).angle() + (1.0 if rng.randf() < 0.5 else -1.0) * rng.randf_range(0.5, 1.2)
			var born := clampi(1 + int(f * 3.0) + (1 if rng.randf() < 0.25 else 0), 1, 3)
			var br := _branch(apts[i], a, rng.randf_range(0.2, 0.48) * (1.0 - f * 0.4), awid[i] * 0.75, born, f * 0.12, rng)
			if rng.randf() < 0.38:
				var bp: PackedVector2Array = br.pts
				var bw: PackedFloat32Array = br.wid
				var j := bp.size() / 2
				var a2 := (bp[j + 1] - bp[j - 1]).angle() + (1.0 if rng.randf() < 0.5 else -1.0) * rng.randf_range(0.5, 1.0)
				_branch(bp[j], a2, rng.randf_range(0.07, 0.18), bw[j] * 0.75, born, f * 0.12 + 0.07, rng)

	func _branch(from: Vector2, a: float, length: float, w: float, born: int, delay: float, rng: RandomNumberGenerator) -> Dictionary:
		var end := from + Vector2(cos(a), sin(a)) * length
		if end.length() > 0.93: end = end.normalized() * 0.93
		var pts := _jag(from, end, 0.32, 4, rng)
		var arc := _arc(pts)
		var wid := PackedFloat32Array()
		for i in pts.size():
			wid.append(w * pow(1.0 - arc[i] / maxf(0.0001, arc[arc.size() - 1]), 0.8) * rng.randf_range(0.8, 1.15))
		var br := {pts = pts, wid = wid, arc = arc, born = born, delay = delay, t0 = -1.0, arm = false}
		cracks.append(br)
		return br

	## a line broken again and again: each piece's middle pushed aside by up to `rough` of its length
	static func _jag(a: Vector2, b: Vector2, rough: float, depth: int, rng: RandomNumberGenerator) -> PackedVector2Array:
		var pts := PackedVector2Array([a, b])
		for k in depth:
			var nx := PackedVector2Array([pts[0]])
			for i in pts.size() - 1:
				var p := pts[i]
				var q := pts[i + 1]
				var m := (p + q) * 0.5 + (q - p).orthogonal() * rng.randf_range(-rough, rough) * pow(0.72, k)
				if m.length() > 0.95: m = m.normalized() * 0.95
				nx.append(m)
				nx.append(q)
			pts = nx
		return pts

	static func _arc(pts: PackedVector2Array) -> PackedFloat32Array:
		var arc := PackedFloat32Array([0.0])
		for i in range(1, pts.size()): arc.append(arc[i - 1] + pts[i].distance_to(pts[i - 1]))
		return arc

func _ready() -> void:
	layer = 19      # under the overlay's cards (Ov, layer 20): the stone's card opens over the dark
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.gui_input.connect(_input_at)
	add_child(_root)
	_dim = ColorRect.new()
	_dim.color = Color(0.008, 0.01, 0.018, 0.0)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_dim)
	create_tween().tween_property(_dim, "color:a", 0.9, 0.35)
	_dust()
	var vp := _root.get_viewport_rect().size
	if title == "": title = "A geode from the board" if stones.size() == 1 else "%d geodes from the board" % stones.size()
	_title = Kit.label(title, 22, UI.display, Kit.AMBER)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.position = Vector2(0, UI.safe_top() + 70)
	_title.size = Vector2(vp.x, 30)
	_root.add_child(_title)
	_hint = Kit.label("", 15, UI.body, Kit.CREAM)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.size = Vector2(vp.x, 24)
	_hint.position = Vector2(0, vp.y * 0.76)
	_root.add_child(_hint)
	var wt := tex("whole")
	for st: Dictionary in stones:
		var g := Geode.new(st)
		_geo.append(g)
		g.back = _layer(g, "back", true)
		g.rind = _layer(g, "rind", false)
		var rm := ShaderMaterial.new()
		rm.shader = preload("res://shaders/geode_rind.gdshader")
		rm.set_shader_parameter("aspect", float(wt.get_width()) / wt.get_height())
		g.rind.material = rm
		g.body = _layer(g, "body", false)
		g.front = _layer(g, "front", true)
	_all = Kit.button("Open all", "btn_gold", 17, 4.0)
	_all.custom_minimum_size = Vector2(200, 50)
	_all.position = Vector2((vp.x - 200) / 2, vp.y * 0.82)
	_all.pressed.connect(_open_all)
	_root.add_child(_all)
	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(1, 1, 1, 0)
	_flash.material = FxLayer.add_material()
	_root.add_child(_flash)
	_lay_out(true)
	if _geo.size() == 1 or auto:
		await get_tree().create_timer(0.45).timeout
		if auto: _open_all()
		else: _choose(_geo[0])

## a full-screen drawing layer for one geode
func _layer(g: Geode, part: String, light: bool) -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if light: c.material = FxLayer.add_material()
	c.draw.connect(func(): call("_draw_" + part, c, g))
	_root.add_child(c)
	return c

## the geodes waiting: one row, two rows past four
func _lay_out(now := false) -> void:
	var vp := _root.get_viewport_rect().size
	var wait: Array[Geode] = []
	for g in _geo:
		if g != _focus: wait.append(g)
	var per := 3 if wait.size() > 4 else wait.size()
	for i in wait.size():
		var g := wait[i]
		var row := i / maxi(1, per)
		var in_row := mini(per, wait.size() - row * per)
		var col := i % maxi(1, per)
		var to := Vector2(vp.x / 2 + (col - (in_row - 1) / 2.0) * (SMALL + 16), vp.y * 0.42 + (row - (wait.size() - 1) / per / 2.0) * (SMALL + 10))
		if now:
			g.at = to + Vector2(0, 40)
			g.size = SMALL
			g.fade = 0.0
			_move(g, to, SMALL, 1.0, 0.5 + i * 0.06)
		else:
			_move(g, to, SMALL, 1.0, 0.35)
	_hint.text = "" if wait.size() <= 1 else "Tap a geode"
	_all.visible = wait.size() > 1

func _move(g: Geode, to: Vector2, sz: float, fade: float, dur: float) -> void:
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: Vector2): g.at = v, g.at, to, dur)
	tw.tween_method(func(v: float): g.size = v, g.size, sz, dur)
	tw.tween_method(func(v: float): g.fade = v, g.fade, fade, dur * 0.8)

func _input_at(e: InputEvent) -> void:
	var tap: bool = (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed)
	if not tap or auto: return
	var p: Vector2 = e.position
	if _focus:
		if _focus.hits < HITS and _focus.split_t < 0.0: _hit(_focus)
		return
	if _busy: return
	for g in _geo:
		if p.distance_to(g.at) < g.size * 0.5: _choose(g)

## one goes to the middle, the rest step back
func _choose(g: Geode) -> void:
	_focus = g
	_busy = true
	_all.visible = false
	var vp := _root.get_viewport_rect().size
	_move(g, Vector2(vp.x / 2, vp.y * 0.44), BIG, 1.0, 0.45)
	for o in _geo:
		if o != g: _move(o, o.at + Vector2(0, vp.y * 0.36), SMALL * 0.6, 0.0, 0.4)
	_hint.text = "Tap to crack it"
	if stones.size() > 1: _title.text = "A geode from the board"

func _hit(g: Geode) -> void:
	g.hits = HITS if short else g.hits + 1
	g.hit_t = _t
	# the cracks run: the split line on, the gaps wider, this tap's branches start
	g.reach_from = _reach(g)
	g.open_from = _open(g)
	g.reach_to = REACH[g.hits]
	g.open_to = OPEN[g.hits]
	g.grow_t = _t
	for cr in g.cracks:
		if int(cr.born) <= g.hits and float(cr.t0) < 0.0: cr.t0 = _t
	Sfx.play("crack", g.hits)
	Sfx.buzz(20 + g.hits * 12 + g.tier * 6)
	_shake = maxf(_shake, 3.0 + g.hits * 1.5 + (g.tier * 1.5 if g.hits >= 2 else 0.0))
	_chips(g, 10 + g.hits * 8)
	# a burst of sparks out of the blow
	var R := g.size * 0.5 * float(meta().get("r", 0.8))
	for i in 5 + g.tier * 3 + g.hits * 2:
		var a := _rng.randf_range(-PI, 0.0)
		_sparks.append({p = g.at + g.origin * R, v = Vector2(cos(a), sin(a)) * _rng.randf_range(90, 260), life = 0.0, max = _rng.randf_range(0.4, 0.9), col = _col(g)})
	if g.hits == 1: _hint.text = ""
	if g.hits >= HITS:
		g.hold_t = _t
		get_tree().create_timer(HOLD).timeout.connect(func(): _split(g))

func _split(g: Geode) -> void:
	g.split_t = _t
	Sfx.play("rock")
	Sfx.buzz(60 + g.tier * 40)
	_shake = 6.0 + g.tier * 3.0
	_flash.color = Color(g.col, 0.0)
	var tw := create_tween()
	tw.tween_property(_flash, "color", Color(g.col.lightened(0.3), 0.55 + g.tier * 0.08), 0.06)
	tw.tween_property(_flash, "color", Color(g.col, 0.0), 0.6)
	_chips(g, 34 + g.tier * 10)
	# glints of the druse burst out: white and the stone's colour
	for i in 22 + g.tier * 8:
		var a := _rng.randf() * TAU
		_sparks.append({p = g.at + Vector2(cos(a), sin(a)) * g.size * 0.08, v = Vector2(cos(a), sin(a)) * _rng.randf_range(160, 460) + Vector2(0, -120),
			life = 0.0, max = _rng.randf_range(0.5, 1.1), col = g.col if i % 3 else Color(1, 1, 1)})
	await get_tree().create_timer(SPLIT).timeout
	# the card unfolds out of the light, which goes into it with a last flash
	Ov.born_at = _orb(g)
	var rv := Reveal.new()
	rv.show_stone(g.s)
	# the card shows two frames on (Ov._grow_from lays it out first): the light goes into it then, not before
	get_tree().create_timer(0.04).timeout.connect(func():
		g.orb_gone = true
		var fl := create_tween()
		fl.tween_property(_flash, "color", Color(g.col.lightened(0.4), 0.35 + g.tier * 0.06), 0.05)
		fl.tween_property(_flash, "color", Color(g.col, 0.0), 0.45))
	await rv.finished
	# that one is done: the halves go, the rest come back
	_geo.erase(g)
	for c: Control in [g.back, g.rind, g.body, g.front]: c.queue_free()
	_focus = null
	_busy = false
	if _geo.is_empty():
		var out := create_tween().set_parallel()
		out.tween_property(_dim, "color:a", 0.0, 0.25)
		out.tween_property(_title, "modulate:a", 0.0, 0.2)
		await out.finished
		done.emit()
		queue_free()
		return
	_lay_out()
	if _auto_run: _next_auto()

func _open_all() -> void:
	_auto_run = true
	_next_auto()

func _next_auto() -> void:
	if _geo.is_empty(): return
	var g := _geo[0]
	_choose(g)
	_hint.text = ""
	await get_tree().create_timer(0.55).timeout
	for i in 1 if short else HITS:
		_hit(g)
		await get_tree().create_timer(AUTO_GAP).timeout

func _process(dt: float) -> void:
	_t += dt
	_shake = maxf(0.0, _shake - dt * 22.0)
	if _focus and _focus.hold_t >= 0.0 and _focus.split_t < 0.0:
		_shake = maxf(_shake, 1.0 + (_t - _focus.hold_t) / HOLD * (2.0 + _focus.tier))
	_root.position = Vector2(sin(_t * 61.0), cos(_t * 47.0)) * _shake if _shake > 0.05 else Vector2.ZERO
	for g in _geo:
		_shape(g)
		for c: Control in [g.back, g.rind, g.body, g.front]: c.queue_redraw()
	# sparks seep out of the cracks while they glow, and fly
	if _focus and _focus.hits > 0 and _focus.split_t < 0.0 and _focus.vis.size():
		var g := _focus
		if _rng.randf() < (3.0 + g.tier * 2.5) * _glow(g) * dt:
			var v: Array = g.vis[_rng.randi() % g.vis.size()]
			var P: PackedVector2Array = v[0]
			_sparks.append({p = P[_rng.randi() % P.size()], v = Vector2(_rng.randf_range(-35, 35), _rng.randf_range(-110, -40)), life = 0.0, max = _rng.randf_range(0.6, 1.3), col = _col(g)})
	for sp in _sparks:
		sp.life = float(sp.life) + dt
		sp.v = (sp.v as Vector2) + Vector2(0, 170) * dt
		sp.p = (sp.p as Vector2) + (sp.v as Vector2) * dt
	_sparks = _sparks.filter(func(sp: Dictionary) -> bool: return float(sp.life) < float(sp.max))

## the light's colour now: warm white at the first tap, turning to the rarity's own by the last (the rarity is told
## a little at a time, as a pack's glow in Hearthstone)
func _col(g: Geode) -> Color:
	if g.hold_t >= 0.0: return g.col
	return Color(1, 0.9, 0.74).lerp(g.col, [0.0, 0.3, 0.7, 1.0][clampi(g.hits, 0, 3)] as float)

## how bright the light from the cracks is now: grows with every tap, swells in the breath, flares on each tap
func _glow(g: Geode) -> float:
	var k := [0.0, 0.45, 0.7, 0.9][clampi(g.hits, 0, 3)] as float
	k += maxf(0.0, 0.6 - (_t - g.hit_t) * 1.8)
	if g.hold_t >= 0.0: k += clampf((_t - g.hold_t) / HOLD, 0.0, 1.0) * 0.8
	return k

## how the light flickers: uneven, never quite still
func _flicker(g: Geode) -> float:
	var t := _t + g.seed_v * 0.01
	return 0.82 + 0.1 * sin(t * 7.3) + 0.06 * sin(t * 13.7 + 1.3) + 0.05 * sin(t * 2.1)

## the split line's run and the gaps' width now (eased between taps); the breath opens them a little more
func _reach(g: Geode) -> float:
	return lerpf(g.reach_from, g.reach_to, _ease((_t - g.grow_t) / GROW))

func _open(g: Geode) -> float:
	var o := lerpf(g.open_from, g.open_to, _ease((_t - g.grow_t) / (GROW * 1.4)))
	if g.hold_t >= 0.0: o *= 1.0 + clampf((_t - g.hold_t) / HOLD, 0.0, 1.0) * 0.35
	return o

static func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return 1.0 - pow(1.0 - x, 3.0)

## the picture's scale: its longer side is the geode's size
func _scale(g: Geode, t: Texture2D) -> float:
	var w := tex("whole")
	return g.size / maxf(w.get_width(), w.get_height()) * (1.0 if t == w else HALF_K)

func _sway(g: Geode) -> float:
	var hold := clampf((_t - g.hold_t) / HOLD, 0.0, 1.0) if g.hold_t >= 0.0 else 0.0
	return sin(_t * 1.3 + g.seed_v) * 0.035 + sin(_t * 40.0) * 0.02 * hold

func _bob(g: Geode) -> Vector2:
	return Vector2(0, sin(_t * 1.7 + g.seed_v * 0.3) * 4.0 * g.size / BIG)

## each crack as far as it has run, in screen points with half widths (pointed at its running front), and points
## along them in the picture's UV for the rind's shader
func _shape(g: Geode) -> void:
	g.vis.clear()
	g.uvs.clear()
	if g.hits == 0 or g.split_t >= 0.0: return
	var R := g.size * 0.5 * float(meta().get("r", 0.8))
	var xf := Transform2D(_sway(g), g.at + _bob(g))
	var open := _open(g)
	var reach := _reach(g)
	var wt := tex("whole")
	var wsz := Vector2(wt.get_width(), wt.get_height())
	var half := 0.5 * float(meta().get("r", 0.8)) * maxf(wsz.x, wsz.y)    # unit -> picture px
	for cr in g.cracks:
		if float(cr.t0) < 0.0: continue
		var f := reach if cr.arm else _ease((_t - float(cr.t0) - float(cr.delay)) / (GROW * 1.3))
		if f <= 0.0: continue
		var pts: PackedVector2Array = cr.pts
		var wid: PackedFloat32Array = cr.wid
		var arc: PackedFloat32Array = cr.arc
		var cutl := arc[arc.size() - 1] * f
		var P := PackedVector2Array()
		var W := PackedFloat32Array()
		var since := 1.0
		for i in pts.size():
			var q := pts[i]
			var ai := arc[i]
			if ai > cutl:
				q = pts[i - 1].lerp(q, (cutl - arc[i - 1]) / maxf(0.0001, ai - arc[i - 1]))
				ai = cutl
			var wf := wid[i] * open * clampf((cutl - ai) / 0.06, 0.0, 1.0)
			P.append(xf * (q * R))
			W.append(wf * R)
			if i > 0: since += q.distance_to(pts[i - 1])
			if since >= 0.035 and g.uvs.size() < 64:
				since = 0.0
				g.uvs.append(Vector3((q.x * half + wsz.x / 2) / wsz.x, (q.y * half + wsz.y / 2) / wsz.y, clampf(wf / W0, 0.15, 1.0)))
			if ai >= cutl: break
		if P.size() > 1: g.vis.append([P, W])

## a crack as a tapered ribbon: from its middle (colour cc) out to both edges (ce), half width k times its own
## (+ `add` points, gone at the tips); triangles added to one list
func _ribbon(P: PackedVector2Array, W: PackedFloat32Array, k: float, add: float, cc: Color, ce: Color, out_p: PackedVector2Array, out_c: PackedColorArray) -> void:
	var n := P.size()
	for i in n - 1:
		var na := (P[mini(i + 1, n - 1)] - P[maxi(i - 1, 0)]).orthogonal().normalized()
		var nb := (P[mini(i + 2, n - 1)] - P[i]).orthogonal().normalized()
		var ha := W[i] * k + add * clampf(W[i], 0.0, 1.0)
		var hb := W[i + 1] * k + add * clampf(W[i + 1], 0.0, 1.0)
		var a := P[i]
		var b := P[i + 1]
		for sd: float in [-1.0, 1.0]:
			out_p.append_array(PackedVector2Array([a, a + na * ha * sd, b + nb * hb * sd, a, b + nb * hb * sd, b]))
			out_c.append_array(PackedColorArray([cc, ce, ce, cc, ce, cc]))

func _flush(c: Control, P: PackedVector2Array, C: PackedColorArray) -> void:
	if P.is_empty(): return
	var idx := PackedInt32Array()
	idx.resize(P.size())
	for i in P.size(): idx[i] = i
	RenderingServer.canvas_item_add_triangle_array(c.get_canvas_item(), idx, P, C)

func _draw_back(c: Control, g: Geode) -> void:
	if g.fade <= 0.01: return
	var R := g.size * 0.5
	var k := _glow(g)
	var ctr := g.at + _bob(g)
	# a soft halo behind; before the first tap a dull warm one (the rarity is not told yet)
	var halo := _col(g) if g.hits > 0 else Color(1, 0.85, 0.6)
	c.draw_texture_rect(FxLayer.puff(), Rect2(ctr - Vector2(R, R) * 1.9, Vector2(R, R) * 3.8), false, Color(halo, (0.10 + k * 0.3) * g.fade))
	if g.split_t >= 0.0 or g.hold_t >= 0.0:
		# rays: thin beams turning slowly, more of them the rarer it is
		var a0 := (_t - g.hold_t) if g.split_t < 0.0 else (_t - g.split_t + HOLD)
		var n := 8 + g.tier * 3
		var L := R * (2.2 + minf(a0, 1.5) * 1.4)
		for i in n:
			var a := i * TAU / n + _t * 0.15 + (0.12 if i % 2 else 0.0)
			var w := 0.05 + 0.03 * sin(i * 3.1)
			var dir := Vector2(cos(a), sin(a))
			var side := Vector2(-dir.y, dir.x)
			var al := clampf(a0 / 0.4, 0.0, 1.0) * (0.16 + 0.1 * sin(_t * 3.0 + i)) * g.fade
			if g.split_t >= 0.0: al *= clampf(1.6 - (_t - g.split_t), 0.0, 1.0) + 0.25
			c.draw_colored_polygon(PackedVector2Array([ctr, ctr + dir * L + side * L * w, ctr + dir * L - side * L * w]),
				Color(g.col.lightened(0.2), al))

## the whole geode in its rind shader, lit from the cracks
func _draw_rind(c: Control, g: Geode) -> void:
	if g.fade <= 0.01 or g.split_t >= 0.0: return
	var m := c.material as ShaderMaterial
	m.set_shader_parameter("count", g.uvs.size())
	if g.uvs.size():
		var arr := g.uvs.duplicate()
		arr.resize(64)
		m.set_shader_parameter("pts", arr)
	m.set_shader_parameter("light", _col(g))
	m.set_shader_parameter("power", _glow(g) * _flicker(g) * g.fade)
	var w := tex("whole")
	var sc := _scale(g, w)
	c.draw_set_transform(g.at + _bob(g), _sway(g), Vector2(sc, sc))
	c.draw_texture(w, -w.get_size() / 2, Color(1, 1, 1, g.fade))
	c.draw_set_transform_matrix(Transform2D.IDENTITY)

func _draw_body(c: Control, g: Geode) -> void:
	if g.fade <= 0.01: return
	var ctr := g.at + _bob(g)
	if g.split_t < 0.0:
		# the gaps: a soft shadow round each, then the dark crack itself
		var P := PackedVector2Array()
		var C := PackedColorArray()
		var dk := Color(0.03, 0.02, 0.015)
		for v: Array in g.vis:
			_ribbon(v[0], v[1], 2.2, 1.6, Color(dk, 0.45 * g.fade), Color(dk, 0.0), P, C)
		for v: Array in g.vis:
			_ribbon(v[0], v[1], 1.0, 0.9, Color(dk, 0.95 * g.fade), Color(dk, 0.25 * g.fade), P, C)
		_flush(c, P, C)
	else:
		# the halves part: each moves out and turns, and drops a little
		var e := _ease((_t - g.split_t) / 0.5)
		for side: int in [-1, 1]:
			var h := tex("half_l" if side < 0 else "half_r")
			var sc := _scale(g, h)
			var off := Vector2(side * (h.get_width() * sc * 0.5 + g.size * 0.07 * e), g.size * 0.06 * e)
			c.draw_set_transform(ctr + off, side * 0.22 * e, Vector2(sc, sc))
			c.draw_texture(h, -h.get_size() / 2, Color(1, 1, 1, g.fade))
		c.draw_set_transform_matrix(Transform2D.IDENTITY)

func _draw_front(c: Control, g: Geode) -> void:
	if g.fade <= 0.01: return
	var ctr := g.at + _bob(g)
	if g.split_t < 0.0:
		if g.hits > 0:
			# the light inside: a glow over each gap in its colour, then the light in the gap, then a white-hot thread
			# down the middle - narrower than the gap, so its dark edges stay
			var k := minf(_glow(g) * _flicker(g), 1.4) * g.fade
			var lc := _col(g)
			var hot := lc.lerp(Color(1, 1, 1), 0.7)
			var P := PackedVector2Array()
			var C := PackedColorArray()
			for v: Array in g.vis:
				_ribbon(v[0], v[1], 3.4, 3.0, Color(lc, 0.3 * k), Color(lc, 0.0), P, C)
			for v: Array in g.vis:
				_ribbon(v[0], v[1], 0.85, 0.6, Color(lc.lightened(0.15), 0.9 * k), Color(lc, 0.0), P, C)
			for v: Array in g.vis:
				_ribbon(v[0], v[1], 0.32, 0.25, Color(hot, k), Color(hot, 0.0), P, C)
			_flush(c, P, C)
			# the blow's point burns brightest
			var R := g.size * 0.5 * float(meta().get("r", 0.8))
			var o := Transform2D(_sway(g), ctr) * (g.origin * R)
			var ob := g.size * (0.05 + 0.04 * k)
			c.draw_texture_rect(FxLayer.puff(), Rect2(o - Vector2(ob, ob) * 2.0, Vector2(ob, ob) * 4.0), false, Color(lc, 0.35 * k))
			c.draw_texture_rect(FxLayer.puff(), Rect2(o - Vector2(ob, ob) * 0.6, Vector2(ob, ob) * 1.2), false, Color(hot, 0.6 * k))
	else:
		# the druse in each half lit in the stone's colour, a pillar of light where the stone rises
		var e := _ease((_t - g.split_t) / 0.5)
		var M := meta()
		for side: int in [-1, 1]:
			var nm := "half_l" if side < 0 else "half_r"
			var h := tex(nm)
			var sc := _scale(g, h)
			var off := Vector2(side * (h.get_width() * sc * 0.5 + g.size * 0.07 * e), g.size * 0.06 * e)
			var hol: Array = M.get(nm, {}).get("hollow", [0.5, 0.5, 0.3])
			var hp := Vector2((float(hol[0]) - 0.5) * h.get_width(), (float(hol[1]) - 0.5) * h.get_height()) * sc
			hp = hp.rotated(side * 0.22 * e)
			var hr := float(hol[2]) * h.get_width() * sc
			var pulse := 0.8 + 0.2 * sin(_t * 4.0 + side)
			c.draw_texture_rect(FxLayer.puff(), Rect2(ctr + off + hp - Vector2(hr, hr) * 1.5, Vector2(hr, hr) * 3.0), false, Color(g.col, 0.42 * pulse * g.fade))
			c.draw_texture_rect(FxLayer.puff(), Rect2(ctr + off + hp - Vector2(hr, hr) * 0.7, Vector2(hr, hr) * 1.4), false, Color(1, 1, 1, 0.12 * pulse * g.fade))
		# the shock of the split: two rings of the stone's colour running out
		var st := _t - g.split_t
		for k in 2:
			var rt := clampf((st - k * 0.08) / 0.5, 0.0, 1.0)
			if rt > 0.0 and rt < 1.0:
				var rad := g.size * (0.15 + 1.5 * _ease(rt))
				c.draw_arc(ctr, rad, 0.0, TAU, 64, Color(g.col.lightened(0.3), (1.0 - rt) * 0.7 * g.fade), g.size * 0.05 * (1.0 - rt) + 1.5, true)
		# the stone's light flies up out of the gap, brightening, till the card unfolds out of it
		if not g.orb_gone:
			var u := _ease(st / SPLIT)
			var orb := _orb(g)
			var rr := g.size * (0.08 + 0.1 * u)
			c.draw_texture_rect(FxLayer.puff(), Rect2(orb - Vector2(rr, rr) * 2.2, Vector2(rr, rr) * 4.4), false, Color(g.col, 0.8 * g.fade))
			c.draw_texture_rect(FxLayer.puff(), Rect2(orb - Vector2(rr, rr) * 0.7, Vector2(rr, rr) * 1.4), false, Color(1, 1, 1, 0.95 * g.fade))
			var bw := g.size * 0.1
			c.draw_texture_rect(FxLayer.puff(), Rect2(orb.x - bw, orb.y - g.size * 0.1, bw * 2, ctr.y - orb.y + g.size * 0.25), false, Color(g.col, 0.4 * g.fade))
	# sparks: a hot dot in a soft halo, fading
	if g == _focus:
		for sp in _sparks:
			var a := 1.0 - float(sp.life) / float(sp.max)
			var q: Vector2 = sp.p
			var sc: Color = sp.col
			c.draw_texture_rect(FxLayer.puff(), Rect2(q - Vector2(7, 7), Vector2(14, 14)), false, Color(sc, 0.5 * a))
			c.draw_texture_rect(FxLayer.puff(), Rect2(q - Vector2(2, 2), Vector2(4, 4)), false, Color(1, 1, 1, 0.9 * a))

## where the stone's light is: rising out of the split, slowing only a little - the card takes it still moving
func _orb(g: Geode) -> Vector2:
	var u := clampf((_t - g.split_t) / RISE, 0.0, 1.0)
	return g.at + _bob(g) + Vector2(0, -g.size * 0.42 * (1.0 - pow(1.0 - u, 1.6)))

## chips of rind flying from the geode
func _chips(g: Geode, n: int) -> void:
	var p := CPUParticles2D.new()
	p.position = g.at
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = n
	p.lifetime = 0.9
	p.direction = Vector2(0, -1)
	p.spread = 180
	p.initial_velocity_min = 140
	p.initial_velocity_max = 380
	p.gravity = Vector2(0, 980)
	p.scale_amount_min = 3
	p.scale_amount_max = 8
	p.angular_velocity_min = -400
	p.angular_velocity_max = 400
	var gr := Gradient.new()
	gr.set_color(0, Color("#9a8670"))
	gr.add_point(0.5, Color("#5e4e3e"))
	gr.set_color(gr.get_point_count() - 1, g.col.lightened(0.4) if g.hits >= 2 else Color("#b09a80"))
	p.color_initial_ramp = gr
	_root.add_child(p)
	p.emitting = true
	get_tree().create_timer(1.3).timeout.connect(p.queue_free)

## slow motes of dust in the dark
func _dust() -> void:
	var vp := _root.get_viewport_rect().size
	var p := CPUParticles2D.new()
	p.position = Vector2(vp.x / 2, vp.y * 0.5)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = vp / 2
	p.amount = 40
	p.lifetime = 6.0
	p.preprocess = 6.0
	p.direction = Vector2(0, -1)
	p.spread = 40
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 4
	p.initial_velocity_max = 14
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.5
	p.color = Color(1, 0.9, 0.75, 0.25)
	_root.add_child(p)
