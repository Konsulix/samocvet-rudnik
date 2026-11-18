class_name HuntRibbon
extends Control
## The hunt for the find the plesiosaur swallowed, as a ribbon on the find's card: seven nodes on a straight dotted
## brass line — three levels, a geode (a reward, and the save point), two more levels, the plesiosaur itself. It is
## wider than the card: it slides under a finger, and brings the node to play to the middle by itself.
## Each level's medallion shows what the level is about (the cove's own works); what is won is gold with a check, the
## one to play is polished and breathes a warm light, the rest are dark. Won back, the card is the find's again: the
## ribbon has no "beaten" end.
## Only the look so far: the hunt's levels are not made (Reveal.hunt), the state comes from the save's `hunt`
## ({won, geode, lost}) or, for pictures, from the key `-- hunt=N[g][x]` (N fights won, g the geode opened, x just lost).

const DIR := "res://assets/ui/hunt/"
const SIGNS := ["tentacle", "ink", "whirl", "glass", "wheel"]
## the nodes in order: a level's number, "geode", "boss"
const NODES := [0, 1, 2, "geode", 3, 4, "boss"]
const FIGHTS := 6
const STEP := 76.0       # from one node's middle to the next, points
const PX := 3.0          # texture pixels to a point (art/ui_redesign/swallowed/cut_parts.py)
const H := 104.0

static var test := {}    # (`-- hunt=…`)
static var _tex := {}
## a test key (`-- hunt_step`): the card's hunt button walks the hunt through its states instead of starting a fight —
## not started, 1, 2, at the geode, the geode opened, 4, 5 (the boss next), lost after the geode, and round again
static var step := false
const WALK := [[0, false, false], [1, false, false], [2, false, false], [3, false, false], [3, true, false], [4, true, false], [5, true, false], [3, true, true]]
static var _walk_i := 0

static func advance() -> void:
	_walk_i = (_walk_i + 1) % WALK.size()
	var w: Array = WALK[_walk_i]
	test = {won = int(w[0]), geode = bool(w[1]), lost = bool(w[2])}

var st := {}
var _x := 0.0            # how far the ribbon is slid
var _to := 0.0
var _drag := false
var _t := 0.0

static func state() -> Dictionary:
	var d: Dictionary = test if not test.is_empty() else Save.d.get("hunt", {})
	return {won = clampi(int(d.get("won", 0)), 0, FIGHTS - 1), geode = bool(d.get("geode", false)), lost = bool(d.get("lost", false))}

## the geode is reached and not opened yet: it is what comes next
static func at_geode(s: Dictionary) -> bool:
	return int(s.won) >= 3 and not bool(s.geode)

## what the card's button says in this state, and whether it is the geode's (gold) one
static func button_text(s: Dictionary) -> String:
	if at_geode(s): return "Open the geode"
	if bool(s.lost): return "Hunt again"
	if int(s.won) >= FIGHTS - 1: return "Face the plesiosaur"
	return "Hunt it down" if int(s.won) == 0 else "Hunt on"

## the line under the ribbon
static func line_text(s: Dictionary) -> String:
	if at_geode(s): return "A geode — and a save point."
	if bool(s.lost): return "It slipped away. Back to the save point." if int(s.won) >= 3 else "It slipped away. The hunt starts over."
	if int(s.won) == 0: return "Six fights in a row — or it gets away."
	return "%d of %d" % [int(s.won), FIGHTS]

static func tex(n: String) -> Texture2D:
	if not _tex.has(n):
		_tex[n] = load(DIR + n + ".png")
	return _tex[n]

func _init() -> void:
	st = state()
	custom_minimum_size = Vector2(0, H)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP

func _ready() -> void:
	_to = _home()
	_x = _to
	resized.connect(func():
		_to = _home()
		_x = _to)

## which node is the one to play (its index in NODES)
func _next_i() -> int:
	if at_geode(st): return 3
	var w := int(st.won)
	return w if w < 3 else w + 1

## a node's state: 2 won, 1 next, 0 not yet
func _mode(i: int) -> int:
	var nx := _next_i()
	return 2 if i < nx else 1 if i == nx else 0

func _span() -> float:
	return STEP * (NODES.size() - 1) + 96.0

## slid so that the node to play is in the middle (and never past the ribbon's ends)
func _home() -> float:
	return _clamp(48.0 + STEP * _next_i() - size.x * 0.5)

func _clamp(x: float) -> float:
	return clampf(x, 0.0, maxf(0.0, _span() - size.x))

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		_drag = e.pressed
		accept_event()
	elif e is InputEventMouseMotion and _drag:
		_to = _clamp(_to - e.relative.x)
		_x = _to
		accept_event()

func _process(dt: float) -> void:
	_t += dt
	if not _drag: _x = lerpf(_x, _to, minf(1.0, dt * 8.0))
	queue_redraw()

## a node's middle on the control
func _at(i: int) -> Vector2:
	return Vector2(48.0 + STEP * i - _x, H * 0.5 + 2.0)

## how much of a thing at x shows: it fades out at the ribbon's cut ends (not where the ribbon itself ends)
func _edge(x: float) -> float:
	var a := 1.0
	if _x > 1.0: a = minf(a, smoothstep(4.0, 40.0, x))
	if _x < _span() - size.x - 1.0: a = minf(a, smoothstep(4.0, 40.0, size.x - x))
	return a

func _pic(t: Texture2D, mid: Vector2, k := 1.0, a := 1.0) -> void:
	var sz := t.get_size() / PX * k
	draw_texture_rect(t, Rect2(mid - sz * 0.5, sz), false, Color(1, 1, 1, a))

func _draw() -> void:
	var nx := _next_i()
	# the line, node to node: gold up to the node to play, dark beyond; drawn in short runs so its ends can fade
	var dark := tex("line_dark")
	var gold := tex("line_gold")
	for i in NODES.size() - 1:
		var a := _at(i)
		var b := _at(i + 1)
		var t := gold if i < nx else dark
		var lh := t.get_height() / PX
		var runs := 6
		for k in runs:
			var x0 := lerpf(a.x, b.x, float(k) / runs)
			var x1 := lerpf(a.x, b.x, float(k + 1) / runs)
			var u0 := fposmod(STEP * i + (x0 - a.x), t.get_width() / PX) * PX
			draw_texture_rect_region(t, Rect2(x0, a.y - lh * 0.5, x1 - x0, lh), Rect2(u0, 0, (x1 - x0) * PX, t.get_height()), Color(1, 1, 1, _edge((x0 + x1) * 0.5)))
	for i in NODES.size():
		var p := _at(i)
		if p.x < -60.0 or p.x > size.x + 60.0:
			continue
		var a := _edge(p.x)
		var md := _mode(i)
		var n: Variant = NODES[i]
		# the node to play breathes a warm light (the boss a red one)
		if md == 1 and not bool(st.lost):
			var br := 0.5 + 0.5 * sin(_t * 2.6)
			var rr := (50.0 if n is String and n == "boss" else 38.0) * (1.0 + 0.08 * br)
			var gc := Color(1.0, 0.35, 0.2) if n is String and n == "boss" else Color(0.75, 0.5, 1.0) if n is String else Color(1.0, 0.78, 0.4)
			draw_texture_rect(GlassCrack.blob(), Rect2(p - Vector2(rr, rr), Vector2(rr, rr) * 2.0), false, Color(gc, (0.3 + 0.3 * br) * a))
		if n is String and n == "geode":
			var g := "geode_open" if bool(st.geode) else "geode_cracked" if at_geode(st) else "geode_shut"
			_pic(tex(g), p + Vector2(0, 2), 1.0, a)
			_pic(tex("flag_gold" if int(st.won) >= 3 else "flag_dark"), p + Vector2(18, -30), 0.85, a)
		elif n is String:
			# (the boss's picture has its skull tag under the ring: the ring's own middle sits on the line)
			var bt := tex("boss_next" if md == 1 else "boss_dark")
			var sz := bt.get_size() / PX
			draw_texture_rect(bt, Rect2(p - Vector2(sz.x * 0.5, sz.x * 0.5), sz), false, Color(1, 1, 1, a))
		else:
			var lt := tex("lv_%s_%s" % [SIGNS[int(n)], ["dark", "next", "won"][md]])
			var lsz := lt.get_size() / PX
			# (a won one has its check tab under the ring: by the ring's middle too)
			draw_texture_rect(lt, Rect2(p - Vector2(lsz.x * 0.5, lsz.x * 0.5), lsz), false, Color(1, 1, 1, a))
			# just lost here: a crack of shame is not drawn — the node only dims and shivers
			if bool(st.lost) and md == 1:
				draw_arc(p, lsz.x * 0.5 + 3.0, 0.0, TAU, 40, Color(0.85, 0.3, 0.2, 0.55 * a * (0.6 + 0.4 * sin(_t * 5.0))), 2.0, true)
