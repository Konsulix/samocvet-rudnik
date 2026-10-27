class_name MineView
extends Node2D
## The Old Adit home screen: the mine in a drawn cross-section (ink and colour, art/zone): the night surface with the
## places its jobs restore, then one band per depth down to the gold chamber, the shaft through them.
## What is drawn follows the save: a job's place shows its step (1..3 restored), a closed depth its rubble (200 m
## under water until the pump), an open one cleared, and after two wins there people work in it.
## Everything lives in the 1536-px space of the source pictures (mine.json); the textures are saved scaled by K.
## Layers: the surface (its pines sway, a shader), the still pictures drawn once, the stages coming in (a reveal
## shader: ink first, then colour) and a live layer redrawn every frame (people, the cart, the cage, smoke, crows,
## sparks, lamp light and the rare signs of the Great Poloz).
## A change of the save (a job's step, a depth opened, the pump, people after two wins) is played, not just swapped:
## what the screen showed last time is kept in _last, the difference comes in as a little scene.

signal band_tapped(k: int)

const DIR := "res://assets/mine/old_adit/"
const PLACES := ["camp", "power", "yard", "headframe"]
const PICK_FPS := 8.0     # the old 6-drawing pick swing, the strike on the third
const CREW_FPS := 14.0    # the 24-drawing crews: a pick swing ~1.7 s, its strike on drawing 10

static var _tex := {}
static var last_result := {}   # the level just played (main sets it): the depth's crew reacts, the ore flies in
static var force_event := ""   # test key (-- mine_event=hole|coil|eyes|bat): play it at once
static var _last := {}    # area -> what the screen showed last: {places, bands, lived}

var J: Dictionary
var K := 1.0
var area := 0
var open := 0
var sel := 0              # the depth being dug
var steps := {}           # job id -> steps done (3 = finished)
var wins: Array = []
var H := 0.0              # content height, source px
var live: Node2D
var front: Node2D         # the shaft column again, over the live layer
var surf: Sprite2D
var still: Node2D
var reveals: Node2D
var _shown_places := {}   # what the still layer draws (may lag behind the save while a change plays)
var _shown_bands := {}
var _appear := {}         # depth -> when its people came (they fade in)
var _power_on := -100.0   # when the electric line came on (its bulbs light one after another)
var _water := {}          # depth -> when its water started to go down
var _drill_in := {}       # depth -> when the drill came through into it
var _glow: Texture2D
var _shade: Texture2D
var _stars: Array = []
var amb: MineAmb
var _motes: Node2D        # dust motes in the open galleries, moving with the rock (not stuck to the screen)
## the best find kept from each depth stands on its pedestal: niche centre x and pedestal top (band rows)
const NICHES := {1: [383, 310], 2: [1050, 305], 3: [462, 318], 4: [350, 312], 5: [860, 316]}
static var _niche_tex := {}  # stone key -> its picture (rendered once, transparent)
static var _niche_studio: SpecStudio
static var _niche_busy := false
var _niche_want := {}     # depth k -> stone (the save's entry)
var _cue := {}            # the last frame each sound cue was checked at, so it fires once per crossing
var t := 0.0
var _rng := RandomNumberGenerator.new()
var _bands: Array = []    # per depth: {y, state, lived}
var _bat_k := 0
var _events := {}         # name -> start time of the running rare event, or -1
var _next_event := 0.0
var _tremor_at := -100.0  # when the mine last began to shake
var _next_tremor := 20.0
var _wheel_dust: Array = []   # [where, when]: little puffs where a cart wheel knocks a rail joint
var _react := {}          # the reaction playing: {k, won, t0, iron, ore}
var _bursts: Array = []   # dust bursts where something was just built: [centre, start time]
var focus_y := -1.0       # where the last setup found a change to show (source px), -1: nothing new
var _set_area := -1
var top: Node2D           # over the shaft: the cage riding it, its rope, the wheel
var marks: Node2D         # the depth plates, over everything (the lamps and bulbs come later and must not cover them)
var _sel_from := -1       # the depth the pick left (its plate closes up) and when
var _sel_at := -100.0

## how many steps of a job are done (a finished job is in Save.d.built instead)
static func job_step(a: int, id: String) -> int:
	return int((Save.d.get("jstep", {}) as Dictionary).get("%d:%s" % [a, id], 0))

## a mine's jobs are paid in this many steps
static func job_steps(a: int) -> int:
	return int(Data.AREAS[a].get("steps", 1))

## what the next step of a job costs: the job's price split evenly, the rounding on the last step
static func step_cost(a: int, id: String, cost: int) -> int:
	var n := job_steps(a)
	var s := job_step(a, id)
	return ceili(cost * (s + 1) / float(n)) - ceili(cost * s / float(n))

static func available() -> bool:
	return FileAccess.file_exists(DIR + "mine.json")

static func tex(path: String) -> Texture2D:
	if not _tex.has(path):
		_tex[path] = load(DIR + path)
	return _tex[path]

func _ready() -> void:
	surf = Sprite2D.new()
	surf.centered = false
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/mine_sway.gdshader")
	surf.material = sm
	add_child(surf)
	still = Node2D.new()
	still.draw.connect(_draw_still)
	add_child(still)
	reveals = Node2D.new()
	add_child(reveals)
	live = Node2D.new()
	live.draw.connect(_draw_live)
	add_child(live)
	front = Node2D.new()
	front.draw.connect(func(): _draw_shaft(front))
	add_child(front)
	top = Node2D.new()
	top.draw.connect(func(): _draw_cage(top))
	add_child(top)
	marks = Node2D.new()
	marks.draw.connect(_draw_marks)
	add_child(marks)
	amb = MineAmb.new(self)
	add_child(amb)
	_motes = Node2D.new()
	still.add_child(_motes)
	var g := GradientTexture2D.new()
	var gr := Gradient.new()
	gr.set_color(0, Color(1, 1, 1, 1))
	gr.set_color(1, Color(1, 1, 1, 0))
	gr.add_point(0.35, Color(1, 1, 1, 0.45))
	g.gradient = gr
	g.fill = GradientTexture2D.FILL_RADIAL
	g.fill_from = Vector2(0.5, 0.5)
	g.fill_to = Vector2(1.0, 0.5)
	g.width = 128
	g.height = 128
	_glow = g
	var sg := GradientTexture2D.new()
	var sgr := Gradient.new()
	sgr.set_color(0, Color(0.05, 0.035, 0.025, 0.85))
	sgr.set_color(1, Color(0.05, 0.035, 0.025, 0.0))
	sg.gradient = sgr
	sg.fill_from = Vector2(0, 0)
	sg.fill_to = Vector2(0, 1)
	sg.width = 8
	sg.height = 64
	_shade = sg
	for i in 46:
		_stars.append([_rng.randf_range(0, 1536), _rng.randf_range(0, 620), _rng.randf_range(0, TAU), _rng.randf_range(0.6, 1.4)])

func setup(a: int) -> void:
	J = JSON.parse_string(FileAccess.get_file_as_string(DIR + "mine.json"))
	K = float(J.K)
	area = a
	open = int(Save.d.depth[a])
	var was_sel := sel
	sel = mini(int(Save.d.depth_sel[a]), open)
	if _set_area == a and was_sel != sel:
		_sel_from = was_sel
		_sel_at = t
	wins = Save.d.dwins
	steps = {}
	for task in Data.AREAS[a].tasks:
		var id := String(task[0])
		steps[id] = 3 if id in Save.d.built[a] else job_step(a, id)
	_bands.clear()
	var y0 := float(J.sky) + float(J.surf)
	for k in Data.depths(a).size():
		var d := k + 1
		var st := "closed"
		if k <= open:
			st = "clear"
			if d == 6:
				st = ["clear", "breach", "vein", "open"][int(steps.get("chamber", 0))]
		elif d == 4 and int(steps.get("pump", 0)) < 3:
			st = "flooded"
		var lived: bool = k <= open and d <= 5 and k < wins.size() and int(wins[k]) >= 2
		_bands.append({y = y0 + k * float(J.band), state = st, d = d, lived = lived, k = k})
	H = y0 + _bands.size() * float(J.band)
	if _set_area != a:
		_events = {}
		_next_event = 4.0
		_set_area = a
	surf.texture = tex("surface.png")
	surf.scale = Vector2.ONE / K
	var sm := surf.material as ShaderMaterial
	sm.set_shader_parameter("top", float(J.sky) - 100.0)
	sm.set_shader_parameter("bottom", float(J.sky) + 900.0)
	sm.set_shader_parameter("amp", 6.0)
	still.material = sm          # the places drawn over the surface sway with it (the bands are below the tree band)
	_changes()
	if not last_result.is_empty() and int(last_result.area) == a:
		var k := clampi(int(last_result.k), 0, _bands.size() - 1)
		_react = {k = k, won = bool(last_result.won), t0 = t + 0.7, iron = int(last_result.iron), ore = int(last_result.ore)}
		if focus_y < 0: focus_y = band_y(k) + float(J.band) * 0.5
		last_result = {}
	_make_motes()
	_find_niches()
	still.queue_redraw()
	front.queue_redraw()

## what changed since the screen was last shown in this mine, played as scenes; the first time just shows it all
func _changes() -> void:
	var places := {}
	for p in PLACES: places[p] = int(steps.get(p, 0))
	var bands := {}
	var lived := {}
	for b in _bands:
		bands[int(b.k)] = String(b.state)
		lived[int(b.k)] = bool(b.lived)
	for c in reveals.get_children(): c.queue_free()
	_shown_places = places.duplicate()
	_shown_bands = bands.duplicate()
	var last: Dictionary = _last.get(area, {})
	_last[area] = {places = places, bands = bands, lived = lived}
	focus_y = -1.0
	if last.is_empty():
		return
	var wait := 0.5      # the screen glides to the place first
	for p in PLACES:
		var was := int(last.places.get(p, 0))
		if int(places[p]) > was:
			if focus_y < 0: focus_y = job_pos(p).y
			_shown_places[p] = was
			var at: Array = J.places[p]
			var now := int(places[p])
			_reveal("place/%s_%d.png" % [p, now], Vector2(float(at[0]), float(at[1])), wait, func(): _shown_places[p] = now,
				"place/%s_%d.png" % [p, was] if was > 0 else "surface.png")
			if p == "power" and now >= 3:
				_power_on = t + wait + 1.6
	for k in bands:
		var was := String(last.bands.get(k, bands[k]))
		var now := String(bands[k])
		if was == now:
			continue
		var y := band_y(int(k))
		if focus_y < 0: focus_y = y + float(J.band) * 0.5
		var d := int(k) + 1
		if was == "flooded":
			# the pump: the water goes down, the picture under it was the closed gallery all along
			_water[k] = t + wait
			get_tree().create_timer(wait).timeout.connect(func(): amb.shot("pan", -2.0, 0.55))
		elif was == "closed":
			# the drill comes down through the rock, then the gallery shows through the dust
			_shown_bands[k] = was
			_drill_in[k] = t + wait
			get_tree().create_timer(wait).timeout.connect(func(): amb.shot("rockfall", 0.0, 0.7))
			for j in 3:
				_bursts.append([Vector2(420 + 330 * j, y + 330), t + wait + 0.8 + 0.12 * j])
			_reveal("band/d%d_%s.png" % [d, now], Vector2(0, y), wait + 1.1, func(): _shown_bands[k] = now, "band/d%d_%s.png" % [d, was])
		else:
			_shown_bands[k] = was
			_reveal("band/d%d_%s.png" % [d, now], Vector2(0, y), wait, func(): _shown_bands[k] = now, "band/d%d_%s.png" % [d, was])
			if d == 6 and now == "open":
				_tremor_at = t + wait + 2.2      # the door to the Great Poloz is open: the whole mine shudders
	for k in lived:
		if lived[k] and not bool(last.lived.get(k, false)):
			_appear[k] = t + wait
			if focus_y < 0: focus_y = band_y(int(k)) + float(J.band) * 0.5

## a stage coming in over the old one: ink lines first, then the colour; at the end the still layer takes it over
func _reveal(path: String, pos: Vector2, delay: float, done: Callable, prev_path := "") -> void:
	var sp := Sprite2D.new()
	sp.centered = false
	sp.texture = tex(path)
	sp.scale = Vector2.ONE / K
	sp.position = pos
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/mine_reveal.gdshader")
	m.set_shader_parameter("p", 0.0)
	if prev_path != "":
		var pt := tex(prev_path)
		m.set_shader_parameter("prev", pt)
		m.set_shader_parameter("has_prev", 1.0)
		if prev_path == "surface.png":
			# a place's first step over the ruined surface: where the place's picture sits in the surface picture
			var ps := pt.get_size() / K
			var sz := tex(path).get_size() / K
			m.set_shader_parameter("prev_rect", Vector4(pos.x / ps.x, pos.y / ps.y, sz.x / ps.x, sz.y / ps.y))
	sp.material = m
	reveals.add_child(sp)
	var tw := sp.create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func(): amb.shot("rockfall", -6.0, 0.9))
	tw.tween_method(func(v: float): m.set_shader_parameter("p", v), 0.0, 1.0, 2.6).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func():
		done.call()
		still.queue_redraw()
		sp.queue_free())

## where a job's work shows (source px): its place on the surface, or the chamber's band
func job_pos(id: String) -> Vector2:
	if J.has("place_box") and J.place_box.has(id):
		var bx: Array = J.place_box[id]
		return Vector2((float(bx[0]) + float(bx[2])) / 2, (float(bx[1]) + float(bx[3])) / 2)
	if id == "chamber": return Vector2(900, band_y(5) + 300)
	if id == "pump": return Vector2(700, band_y(3) + 300)
	return Vector2(768, float(J.sky) + 520)

## a cloud of dust and stones over a spot: the change of picture under it is not seen as a jump
func burst(at: Vector2) -> void:
	_bursts.append([at, t])

## the height of everything, in screen units at this node's scale
func content_height() -> float:
	return H * scale.y

## the depth under a point in this node's space (source px), or -1 above the first band
func band_at(p: Vector2) -> int:
	for b in _bands:
		if p.y >= float(b.y) and p.y < float(b.y) + float(J.band):
			return int(b.k)
	return -1

## the top of a depth's band, source px
func band_y(k: int) -> float:
	return float(_bands[clampi(k, 0, _bands.size() - 1)].y)

func _put(ci: CanvasItem, path: String, pos: Vector2, flip := false, alpha := 1.0) -> void:
	var tx := tex(path)
	var sz := tx.get_size() / K
	if not flip:
		ci.draw_texture_rect(tx, Rect2(pos, sz), false, Color(1, 1, 1, alpha))
		return
	# mirrored by a transform (a rect of negative width is not mirrored, only shifted)
	ci.draw_set_transform(pos + Vector2(sz.x, 0), 0, Vector2(-1, 1))
	ci.draw_texture_rect(tx, Rect2(Vector2.ZERO, sz), false, Color(1, 1, 1, alpha))
	ci.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

func _put_rot(ci: CanvasItem, path: String, centre: Vector2, ang: float, size_px := Vector2.ZERO) -> void:
	var tx := tex(path)
	var sz := size_px if size_px != Vector2.ZERO else tx.get_size() / K
	ci.draw_set_transform(centre, ang, Vector2.ONE)
	ci.draw_texture_rect(tx, Rect2(-sz / 2, sz), false)
	ci.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

func _size(path: String) -> Vector2:
	return tex(path).get_size() / K

# ---------------------------------------------------------------- the still pictures

func _draw_still() -> void:
	var c := still
	for p in PLACES:
		var s := int(_shown_places.get(p, 0))
		if s > 0:
			var at: Array = J.places[p]
			_put(c, "place/%s_%d.png" % [p, s], Vector2(float(at[0]), float(at[1])))
	for b in _bands:
		var st := String(_shown_bands.get(int(b.k), b.state))
		_put(c, "band/d%d_%s.png" % [int(b.d), st], Vector2(0, float(b.y)))
	_draw_niches(c)
	# the seams between the bands: a dark line and the shadow of the band above falling on the next
	for b in _bands:
		c.draw_texture_rect(_shade, Rect2(0, float(b.y), float(J.W), 44), false)
		c.draw_rect(Rect2(0, float(b.y) - 3, float(J.W), 6), Color(0.08, 0.055, 0.04))
	_draw_shaft(c)

const PICK_W := 60.0      # the slot the pick takes on the plate of the depth being dug

## each depth's plate at its top left, over the lamps: a dark tablet with a brass rim and rivets; the depth being dug
## in gold with the pick, which opens its slot smoothly when the choice moves (the old plate closes up the same way)
func _draw_marks() -> void:
	var c := marks
	var font: Font = UI.body_bold
	var u := clampf((t - _sel_at) / 0.3, 0.0, 1.0)
	u = u * u * (3.0 - 2.0 * u)
	for b in _bands:
		var k := int(b.k)
		var shut := k > open
		var g := 0.0          # how far the pick is in
		if k == sel: g = u
		elif k == _sel_from: g = 1.0 - u
		var num := str(Data.depth_m(area, k))
		var fs := 50
		var fm := 32
		var wn := font.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var wm := font.get_string_size(" m", HORIZONTAL_ALIGNMENT_LEFT, -1, fm).x
		var r := Rect2(26, float(b.y) + 22, wn + wm + 64 + PICK_W * g, 70)
		var gold := Color("#ffd27a")
		var brass := Color("#c8913a")
		if g > 0.0:
			_light(c, r.get_center(), r.size.x * 0.8, Color(1.0, 0.75, 0.3, 0.22 * g))
		# the shadow it casts on the rock, the tablet, its rim and the thin line inside
		c.draw_style_box(_plate(Color(0, 0, 0, 0.35), Color(0, 0, 0, 0), 0), Rect2(r.position + Vector2(4, 6), r.size))
		var rim := brass.lerp(gold, g)
		rim.a = 0.45 if shut else 0.9
		c.draw_style_box(_plate(Color(0.085, 0.06, 0.035, 0.9), rim, 3), r)
		var inner := r.grow(-8)
		c.draw_style_box(_plate(Color(0, 0, 0, 0), Color(rim, 0.28), 1, 5), inner)
		# rivets at both ends
		for x: float in [r.position.x + 15, r.end.x - 15]:
			var at := Vector2(x, r.get_center().y)
			c.draw_circle(at, 6.0, Color(0.05, 0.035, 0.02))
			c.draw_circle(at, 4.5, Color(rim, 1.0 if not shut else 0.5))
			c.draw_circle(at + Vector2(-1.3, -1.3), 1.6, Color(1, 0.95, 0.8, 0.7 if not shut else 0.3))
		var x0 := r.position.x + 32
		if g > 0.0:
			_draw_pick(c, Vector2(x0 + PICK_W * 0.5 - 7, r.get_center().y + 2), g)
		x0 += PICK_W * g
		var col := Color("#f0e6d2").lerp(gold, g)
		if shut: col = Color(0.72, 0.68, 0.62, 0.6)
		var base := r.position.y + 51
		c.draw_string(font, Vector2(x0, base), num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		c.draw_string(font, Vector2(x0 + wn, base), " m", HORIZONTAL_ALIGNMENT_LEFT, -1, fm, Color(col, col.a * 0.7))

## a small pickaxe drawn in lines (the font has no pick sign): the handle, the curved head; a: how far it has come in
func _draw_pick(c: CanvasItem, at: Vector2, a: float) -> void:
	var s := (0.6 + 0.4 * a) * 1.15
	c.draw_set_transform(at, 0.6, Vector2(s, s))
	var dark := Color(0.04, 0.025, 0.01, a)
	var tip := Vector2(0, -14)
	c.draw_line(Vector2(0, 22), tip, dark, 9)
	c.draw_line(Vector2(0, 22), tip, Color(0.66, 0.45, 0.24, a), 5)
	var head := PackedVector2Array()
	for i in 13:
		var q := lerpf(-1.0, 1.0, i / 12.0)
		head.append(tip + Vector2(q * 25, -9 * (1 - q * q) + 5))
	c.draw_polyline(head, dark, 10)
	c.draw_polyline(head, Color("#ffd27a", a), 6)
	c.draw_circle(tip + Vector2(0, -3), 4.5, Color(0.55, 0.5, 0.45, a))
	c.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

const CAGE_CYCLE := 16.0   # s: down 6, wait 2 at the bottom, up 6, wait 2 at the top

## how far down the cage is (source px from its top stop): eased down, a wait at the bottom, up, a wait at the top
func cage_depth() -> float:
	var cg: Dictionary = J.cage
	var bottom := band_y(open) + floor_of(open + 1) - _size("cage.png").y
	var run := maxf(0.0, bottom - float(cg.top))
	var u := fmod(t, CAGE_CYCLE)
	var q := 0.0
	if u < 6.0: q = 0.5 - 0.5 * cos(PI * u / 6.0)
	elif u < 8.0: q = 1.0
	elif u < 14.0: q = 0.5 + 0.5 * cos(PI * (u - 8.0) / 6.0)
	return run * q

## the restored headframe: the cage rides the shaft down to the deepest open depth and back, the wheel turns with
## the rope; drawn over the shaft column (the cage is in front of its ladder)
func _draw_cage(c: CanvasItem) -> void:
	if J.is_empty() or int(steps.get("headframe", 0)) < 3:
		return
	var cg: Dictionary = J.cage
	var depth := cage_depth()
	var rx := float(cg.rope_x)
	var y := float(cg.top) + depth
	var cs := _size("cage.png")
	c.draw_line(Vector2(rx, float(cg.rope_y)), Vector2(rx, y + 6), Color(0.59, 0.47, 0.31), 3)
	_put(c, "cage.png", Vector2(rx - cs.x / 2, y))
	var hub: Array = cg.hub
	_put_rot(c, "wheel.png", Vector2(float(hub[0]), float(hub[1])), depth / float(cg.r), _size("wheel.png"))
	var bm: Array = cg.beams
	_put(c, "beams.png", Vector2(float(bm[0]), float(bm[1])))

## motes drifting in the lamplight of each open gallery: children of the picture, so a swipe carries them with the rock
func _make_motes() -> void:
	for ch in _motes.get_children(): ch.queue_free()
	for b in _bands:
		if String(b.state) in ["closed", "flooded"]:
			continue
		var p := CPUParticles2D.new()
		p.amount = 14
		p.lifetime = 9.0
		p.preprocess = 9.0
		p.local_coords = true          # the motes live in the picture: a swipe carries them with the rock
		p.texture = _glow
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		p.position = Vector2(640, float(b.y) + 270)
		p.emission_rect_extents = Vector2(620, 140)
		p.gravity = Vector2(0, -6)
		p.direction = Vector2(1, 0)
		p.spread = 180
		p.initial_velocity_min = 8
		p.initial_velocity_max = 30
		p.scale_amount_min = 0.03       # the 128-px soft dot -> 4..8 source px (1..2 pt on the phone)
		p.scale_amount_max = 0.06
		var g := Gradient.new()
		g.set_color(0, Color(1, 0.85, 0.55, 0))
		g.add_point(0.5, Color(1.3, 1.1, 0.7, 0.55))
		g.set_color(g.get_point_count() - 1, Color(1, 0.85, 0.55, 0))
		p.color_ramp = g
		_motes.add_child(p)

## the best stone kept from each open depth (the save's collection remembers where it was found): its picture is
## rendered once in a small transparent studio and stands on the depth's pedestal
## the game is closing: drop the static pictures and the niche studio while the renderer is still up
static func release() -> void:
	_tex.clear()
	_niche_tex.clear()
	if _niche_studio:
		_niche_studio.vp.queue_free()
		_niche_studio = null

func _find_niches() -> void:
	_niche_want = {}
	for s in Save.d.coll:
		if int(s.get("area", -1)) != area or not s.has("dl"):
			continue
		var k := int(s.dl)
		if k > open or not NICHES.has(k + 1):
			continue
		if not _niche_want.has(k) or int(s.value) > int(_niche_want[k].value):
			_niche_want[k] = s
	for k in _niche_want:
		var key := Spec.key_of(Spec.of_stone(_niche_want[k]))
		if not _niche_tex.has(key):
			_render_niche(Spec.of_stone(_niche_want[k]), key)

func _render_niche(o: Dictionary, key: String) -> void:
	while _niche_busy:
		await get_tree().process_frame
	if _niche_tex.has(key):
		return
	_niche_busy = true
	if _niche_studio == null:
		_niche_studio = SpecStudio.make(256, Viewport.MSAA_4X, true)
		_niche_studio.vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		Spec.add_child(_niche_studio.vp)
	var st := _niche_studio
	var p: Node3D = await st.show_async(o)
	if p != null:
		p.rotation = Vector3(0.12, 0.6, 0)
		for i in 2:
			st.vp.render_target_update_mode = SubViewport.UPDATE_ONCE
			await RenderingServer.frame_post_draw
		var img := st.vp.get_texture().get_image()
		var used := img.get_used_rect()
		if used.size.x > 2:
			_niche_tex[key] = ImageTexture.create_from_image(img.get_region(used))
		st.clear()
	_niche_busy = false
	if is_inside_tree():
		still.queue_redraw()

## a stone's size on its pedestal (source px)
func _niche_size(tx: Texture2D) -> Vector2:
	var sz := tx.get_size() * (105.0 / maxf(1.0, tx.get_size().y))
	if sz.x > 120:
		sz *= 120.0 / sz.x
	return sz

## the stone standing on a pedestal under a point (this node's space), or {}
func niche_at(p: Vector2) -> Dictionary:
	for k in _niche_want:
		var key := Spec.key_of(Spec.of_stone(_niche_want[k]))
		if not _niche_tex.has(key):
			continue
		var nc: Array = NICHES[k + 1]
		var sz := _niche_size(_niche_tex[key])
		var top := band_y(k) + float(nc[1])
		var r := Rect2(float(nc[0]) - sz.x / 2 - 30, top - sz.y - 30, sz.x + 60, sz.y + 50)
		if r.has_point(p):
			return _niche_want[k]
	return {}

## the stones on their pedestals: a soft shadow, an ink outline (the picture eight times in dark, a pixel round),
## the stone warmed by the lantern light
func _draw_niches(c: CanvasItem) -> void:
	for k in _niche_want:
		var key := Spec.key_of(Spec.of_stone(_niche_want[k]))
		if not _niche_tex.has(key):
			continue
		var tx: Texture2D = _niche_tex[key]
		var nc: Array = NICHES[k + 1]
		var sz := _niche_size(tx)
		var top := band_y(k) + float(nc[1])
		var pos := Vector2(float(nc[0]) - sz.x / 2, top - sz.y + 8)
		c.draw_texture_rect(_glow, Rect2(Vector2(float(nc[0]) - sz.x * 0.6, top - 10), Vector2(sz.x * 1.2, 22)), false, Color(0.1, 0.06, 0.02, 0.6))
		for d in [Vector2(-3, 0), Vector2(3, 0), Vector2(0, -3), Vector2(0, 3), Vector2(-2, -2), Vector2(2, 2), Vector2(-2, 2), Vector2(2, -2)]:
			c.draw_texture_rect(tx, Rect2(pos + d, sz), false, Color(0.14, 0.08, 0.04, 1.0))
		c.draw_texture_rect(tx, Rect2(pos, sz), false, Color(1.0, 0.9, 0.76))

## the shaft down to the floor of the deepest open depth
func _draw_shaft(c: CanvasItem) -> void:
	var sh: Array = J.shaft
	var seg := _size("shaft.png")
	var y := float(J.sky) + float(J.surf) - 30
	var bottom := band_y(open) + float(J.band) - 40
	while y < bottom:
		var h := minf(seg.y, bottom - y)
		c.draw_texture_rect_region(tex("shaft.png"), Rect2(float(sh[0]), y, seg.x, h), Rect2(0, 0, seg.x * K, h * K))
		y += seg.y

func _plate(bg: Color, rim: Color, wd: int, rad := 10) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = bg
	st.border_color = rim
	st.set_border_width_all(wd)
	st.set_corner_radius_all(rad)
	st.anti_aliasing = true
	return st

# ---------------------------------------------------------------- the live layer

func _process(delta: float) -> void:
	if not visible:
		return
	t += delta
	_tick_events()
	_tremor()
	_sounds(delta)
	live.queue_redraw()
	top.queue_redraw()
	marks.queue_redraw()

## the shaking: a big one when the door opens, small ones now and then while the boss waits behind it
func _tremor() -> void:
	if String(_shown_bands.get(5, "")) == "open" and not bool(Save.d.boss_won[area]) and t > _next_tremor:
		_next_tremor = t + _rng.randf_range(18.0, 30.0)
		if t - _tremor_at > 5.0:
			_tremor_at = t
	var s := t - _tremor_at
	var big := s < 2.5 and _tremor_at > 0.0
	var amp := 0.0
	if s >= 0.0 and s < 1.6:
		amp = (7.0 if big else 3.0) * (1.0 - s / 1.6)
		if _passed("tremor", s, 100.0, 0.0):
			amp = amp
	position.x = sin(t * 47.0) * amp * scale.x
	if s >= 0.0 and s < 0.05 and not _cue.has("tremor%d" % int(_tremor_at)):
		_cue["tremor%d" % int(_tremor_at)] = true
		amb.shot("rockfall", -4.0, 0.6)
		amb.shot("hiss", -8.0, 0.5)
		for b in _bands:
			if String(b.state) != "closed" and String(b.state) != "flooded":
				_bursts.append([Vector2(_rng.randf_range(200, 1100), float(b.y) + 90), t + _rng.randf_range(0.0, 0.4)])

func _finale(c: CanvasItem) -> void:
	if String(_shown_bands.get(5, "")) != "open":
		return
	var y := band_y(5)
	# the vein: points of gold light running up along it
	for i in 9:
		var u := fmod(t * 0.18 + i / 9.0, 1.0)
		var p := Vector2(560, y + 380).lerp(Vector2(900, y + 90), u) + Vector2(sin(i * 2.3) * 60, cos(i * 1.7) * 30)
		_light(c, p, 26, Color(1.0, 0.82, 0.3, 0.55 * sin(PI * u)))
	# the door's crack breathes green, stronger while the mine shakes
	var sh := clampf(1.0 - (t - _tremor_at) / 2.0, 0.0, 1.0)
	var g := 0.45 + 0.25 * sin(t * 1.6) + 0.5 * sh
	_light(c, Vector2(1117, y + 300), 120, Color(0.35, 1.0, 0.45, 0.30 * g))
	c.draw_line(Vector2(1117, y + 180), Vector2(1117, y + 425), Color(0.5, 1.0, 0.55, 0.5 * g), 5)
	# the carved serpent's eyes glint now and then
	var e := maxf(0.0, sin(t * 0.7)) ** 8 + sh
	if e > 0.05:
		_light(c, Vector2(1078, y + 122), 22, Color(1.0, 0.85, 0.3, 0.8 * minf(e, 1.0)))

## how much quieter a sound is for being far from the middle of the screen (dB, 0 at the middle)
func _far(y_src: float) -> float:
	var vp := get_viewport_rect().size
	var sy := position.y + y_src * scale.y
	return -clampf(absf(sy - vp.y * 0.5) / vp.y * 14.0, 0.0, 28.0)

## true once each time `v` (a running count) passes a multiple of `every` plus `at`
func _passed(key: String, v: float, every: float, at := 0.0) -> bool:
	var n := floorf((v - at) / every)
	var was: float = _cue.get(key, n)
	_cue[key] = n
	return n > was

## the sounds at the moments the picture shows them
func _sounds(_dt: float) -> void:
	# the cage sets off down (cycle start) and up (half way)
	if int(steps.get("headframe", 0)) >= 3 and (_passed("cage_dn", t, CAGE_CYCLE) or _passed("cage_up", t, CAGE_CYCLE, 8.0)):
		amb.shot("winch_%d" % (randi() % 2), _far(float(J.cage.top) + cage_depth()))
	for b in _bands:
		if not b.lived or _appear.has(int(b.k)):
			continue
		var k := int(b.k)
		var y := float(b.y) + floor_of(int(b.d))
		var deep := -k * 1.5
		var mine := k == sel
		# the pick strikes on frame 2 of its swing (the pick down at the heap); every gallery on its own beat
		var cr: Dictionary = J.crews.get(str(int(b.d)), {}) if J.has("crews") else {}
		var wk: Array = cr.get("work", ["pick"])
		var who := String(wk[0]) if wk.size() else ""
		var hit := false
		if who == "pick24" and _crew_ok(who): hit = _passed("pick%d" % k, t * CREW_FPS + k * 7.0, 24.0, 10.0)
		elif who == "pick" or not _crew_ok(who): hit = _passed("pick%d" % k, t * PICK_FPS + k * 2.3, 6.0, 2.0)
		elif who == "shovel24": hit = _passed("pick%d" % k, t * CREW_FPS + k * 7.0, 24.0, 20.0)
		elif who == "jack24" or who == "lad24": hit = _passed("pick%d" % k, t * CREW_FPS + k * 7.0, 24.0, 11.0)
		elif who == "load24" or who == "old24": hit = _passed("pick%d" % k, t * CREW_FPS + k * 7.0, 24.0, 19.0)
		if hit and (mine or randf() < 0.18):
			amb.shot("pick", _far(y) + deep + (0.0 if mine else -4.0), 0.9 - k * 0.03)
		# the cart: rolling sounds while it moves (each take is 4 s), out to the shaft and back
		var P: Dictionary = J.push
		var go := (float(J.portal) + 330.0) / float(P.step)
		var cyc := 2.0 * go + 16.0
		var ft := fmod(t * 24.0 + k * 37.0, cyc)
		var moving := ft < go - 30.0 or (ft > go + 16.0 and ft < cyc - 20.0)
		# (the other galleries' carts only when on screen, and not every take: five rolling at once was a din)
		if _passed("cart%d" % k, t * 24.0 + k * 37.0, 96.0) and moving and bool(cr.get("push", true)) and (mine or (_far(y) > -5.0 and randf() < 0.5)):
			amb.shot("cart_%d" % (randi() % 2), _far(y) + deep + (0.0 if mine else -6.0), 1.0 - k * 0.03)


func _tick_events() -> void:
	if force_event != "" and t > 0.5:
		_bat_k = open
		_events[force_event] = t
		force_event = ""
	if t < _next_event:
		return
	_next_event = t + _rng.randf_range(9.0, 16.0)
	var pool := []
	if open >= 0: pool.append("hole")
	if _bands.size() > 3 and String(_bands[3].state) == "flooded": pool.append("coil")
	pool.append("eyes")
	pool.append("bat")
	if area == 0 and J.has("lizard2") and String(_shown_bands.get(int(J.lizard2.get("k", 0)), "")) == "clear":
		pool.append("lizard")         # the herald of the next mine's Mistress: nobody here knows who she is
	_bat_k = _rng.randi_range(0, open)
	if not pool.is_empty():
		var ev: String = pool[_rng.randi() % pool.size()]
		_events[ev] = t
		match ev:
			"hole": get_tree().create_timer(1.6).timeout.connect(func(): amb.shot("hiss", _far(band_y(0) + 400) - 14.0, 1.4))
			"coil": amb.shot("hiss", _far(band_y(3) + 300) - 10.0, 0.6)

func _draw_live() -> void:
	var c := live
	_lights(c)
	_surface_live(c)
	_snake_live(c)
	for b in _bands:
		_band_live(c, b)
	_ore_flight(c)
	for wd in _wheel_dust.duplicate():
		var i := int((t - float(wd[1])) * 14.0)
		if i >= 8:
			_wheel_dust.erase(wd)
			continue
		var dp := "dust/%d.png" % i
		var ds := _size(dp) * 1.4
		var at: Vector2 = wd[0]
		c.draw_texture_rect(tex(dp), Rect2(at - Vector2(ds.x / 2, ds.y - 6), ds), false, Color(1, 1, 1, 0.75))
	_finale(c)
	for bu in _bursts.duplicate():
		var i := int((t - float(bu[1])) * 12)
		if t < float(bu[1]):
			continue
		if i >= 8:
			_bursts.erase(bu)
			continue
		var p := "burst/%d.png" % i
		var sz := _size(p) * 1.6
		var at: Vector2 = bu[0]
		c.draw_texture_rect(tex(p), Rect2(at - sz / 2, sz), false)

## a soft round light: warm for oil and fire, cold white for the electric bulbs
func _light(c: CanvasItem, at: Vector2, r: float, col: Color) -> void:
	c.draw_texture_rect(_glow, Rect2(at - Vector2(r, r), Vector2(r, r) * 2), false, col)

func _flick(i: int) -> float:
	return 0.78 + 0.14 * sin(t * 2.3 + i * 1.7) + 0.08 * sin(t * 7.1 + i * 3.1)

func _lights(c: CanvasItem) -> void:
	# stars over the ridge
	for st in _stars:
		var v := 0.5 + 0.5 * sin(t * float(st[3]) + float(st[2]))
		if v > 0.35:
			c.draw_rect(Rect2(float(st[0]), float(st[1]), 3, 3), Color(0.85, 0.88, 1.0, v))
	# the surface's lamps, each lit once its place is restored (the adit's lantern always)
	var sl: Dictionary = J.surface_lamps
	var i := 0
	for place in sl:
		if place != "adit" and int(_shown_places.get(place, 0)) < 3:
			continue
		for l in sl[place]:
			i += 1
			_light(c, Vector2(float(l[0]), float(l[1])), 70 * float(l[2]), Color(1.0, 0.72, 0.35, 0.33 * _flick(i)))
	# the galleries: the oil lantern of each open one; the electric line once the power is on, bulb after bulb
	var power := int(_shown_places.get("power", 0)) >= 3
	var cb: Dictionary = J.cable
	var cs := _size("cable.png")
	for b in _bands:
		var k := int(b.k)
		if String(_shown_bands.get(k, b.state)) in ["closed", "flooded"]:
			continue
		var y := float(b.y)
		for l in J.lamps[str(int(b.d))]:
			_light(c, Vector2(float(l[0]), y + float(l[1])), 150, Color(1.0, 0.7, 0.32, 0.30 * _flick(k * 3)))
		if not power:
			continue
		for xi in (cb.xs as Array).size():
			var x0 := float(cb.xs[xi])
			_put(c, "cable.png", Vector2(x0, y + float(cb.y)))
			for bi in (cb.bulbs as Array).size():
				var on := clampf((t - _power_on - k * 0.35 - (xi * 3 + bi) * 0.06) / 0.25, 0.0, 1.0)
				if on <= 0.0: continue
				var bp: Array = cb.bulbs[bi]
				var at := Vector2(x0 + float(bp[0]), y + float(cb.y) + float(bp[1]))
				_light(c, at, 95, Color(0.8, 0.9, 1.0, 0.32 * on * (0.95 + 0.05 * sin(t * 40 + bi))))

func _surface_live(c: CanvasItem) -> void:
	var sky := float(J.sky)
	# the white crow, and later a flock of three the other way, each with its own wing beat
	var u := fmod(t, 24.0)
	if u < 5.0:
		_put(c, "crow/%d.png" % (int(t * 12) % 6), Vector2(1600 - u * 360, sky + 150 + 25 * sin(t * 1.9)))
	elif u > 12.0 and u < 17.0:
		var v := u - 12.0
		for i in 3:
			var off: Array = [[0, 0, 0], [-70, 34, 3], [-120, -22, 7]][i]
			var x := -100 + v * 360 + float(off[0])
			_put(c, "crow/%d.png" % ((int(t * 12) + int(off[2])) % 6), Vector2(x, sky + 110 + float(off[1]) + 12 * sin(t * 2.2 + i)), true)
	# the camp: chimney smoke once it has a roof and a fire, the old guide on his bench when it is done
	var camp := int(steps.get("camp", 0))
	if camp >= 2:
		var ch: Array = J.chimney
		var ps := _size("puff.png")
		for p in 14:
			var age := fmod(t / 6.0 * 14.0 - p, 14.0) / 14.0 * 2.2
			if age > 1.0: continue
			var s := 0.35 + 0.9 * age
			var a := 0.85 * pow(1.0 - age, 1.3)
			var pos := Vector2(float(ch[0]) + 60 * age + 10 * sin(age * 5 + p), float(ch[1]) - 190 * age)
			c.draw_texture_rect(tex("puff.png"), Rect2(pos - ps * s / 2, ps * s), false, Color(1, 1, 1, a))
	if camp >= 3:
		var g: Array = J.guide
		var gp := "guide/%02d.png" % (int(t * 8) % 24)
		var gs := _size(gp)
		_put(c, gp, Vector2(float(g[0]) - gs.x / 2, float(g[1]) - gs.y))
	# hens and a rooster pecking about the ore yard, a dog asleep by the hut, once those places are done
	if J.has("yard_life"):
		for a in J.yard_life:
			var spec: Dictionary = a
			if int(steps.get(String(spec.place), 0)) < 3 or not _crew_ok(String(spec.name)):
				continue
			var nm := String(spec.name)
			var n := int(J.crew_n[nm])
			var fps := float(spec.get("fps", 8))
			var ph := float(spec.get("ph", 0))
			var x := float(spec.x)
			var flip := false
			if spec.has("roam"):
				# wanders: a few steps one way, pecks, a few steps back
				var per := float(spec.roam[1])
				var ru := fmod(t + ph, per) / per
				x += float(spec.roam[0]) * (0.5 - 0.5 * cos(TAU * ru))
				flip = (ru > 0.5) == (float(spec.roam[0]) > 0.0)
			var fr := "%s/%02d.png" % [nm, int((t + ph) * fps) % n]
			var fs := _size(fr)
			_put(c, fr, Vector2(x - fs.x / 2, float(J.sky) + float(spec.y) - fs.y), flip)
	# the generator hums once the power is on: it trembles and sparks jump at the brushes
	if int(steps.get("power", 0)) >= 3:
		var m: Array = J.machine
		var f := int(t * 24)
		_put(c, "machine.png", Vector2(float(m[0]) + [0, 1, 0, -1][f % 4], float(m[1])))
		if f % 5 < 2 and (f / 5) % 3 != 2:
			var sp := "spark_%d.png" % ((f / 5) % int(J.sparks.n))
			var ss := _size(sp)
			var at: Array = J.sparks.at
			_put(c, sp, Vector2(float(at[0]), float(at[1])) - ss / 2)

## the rails' top of a depth (band rows): each gallery was drawn with its own floor line
func floor_of(d: int) -> float:
	if J.has("floors") and J.floors.has(str(d)): return float(J.floors[str(d)])
	return float(J.floor)

## a 24-drawing crew sheet, or "" where it was not exported
func _crew_ok(name: String) -> bool:
	return J.has("crew_n") and int(J.crew_n.get(name, 0)) > 0

func _band_live(c: CanvasItem, b: Dictionary) -> void:
	var y := float(b.y)
	var floor_y := y + floor_of(int(b.d))
	var k := int(b.k)
	if _water.has(k):
		# the flooded picture is uncovered from the top: its water line sinks to the floor and is gone
		var q := clampf((t - float(_water[k])) / 3.0, 0.0, 1.0)
		var tx := tex("band/d%d_flooded.png" % int(b.d))
		var sz := tx.get_size()
		var cut := q * float(J.band)
		if q < 1.0:
			c.draw_texture_rect_region(tx, Rect2(0, y + cut, sz.x / K, float(J.band) - cut), Rect2(0, cut * K, sz.x, sz.y - cut * K))
		else:
			_water.erase(k)
	if _drill_in.has(k):
		var s := t - float(_drill_in[k])
		if s > 1.6:
			_drill_in.erase(k)
		elif s > 0:
			var dp := _drill_frame(k - 1)
			var ds := _size(dp)
			var sh: Array = J.shaft
			var cx := (float(sh[0]) + float(sh[1])) / 2
			var yy := y - ds.y * 0.35 + minf(s / 1.1, 1.0) * (floor_of(int(b.d)) - ds.y * 0.4)
			_put(c, dp, Vector2(cx - ds.x / 2 + _rng.randf_range(-3, 3), yy + _rng.randf_range(-2, 2)))
	# the drill working at the face under the deepest open depth
	if k == open + 1 and k <= 5:
		var dp := _drill_frame(open)
		var ds := _size(dp)
		var sh: Array = J.shaft
		var cx := (float(sh[0]) + float(sh[1])) / 2
		_put(c, dp, Vector2(cx - ds.x / 2 + _rng.randf_range(-1.5, 1.5), y - ds.y * 0.35 + _rng.randf_range(-1.0, 1.0)))
	if String(b.state) != "closed" and int(b.d) == 3:
		_put(c, "snake/skin_%02d.png" % (int(t * 8) % 24), Vector2(float(J.skin[0]) - _size("snake/skin_00.png").x / 2, y + float(J.skin[1])))
	if not b.lived:
		return
	var al := 1.0
	if _appear.has(k):
		al = clampf((t - float(_appear[k])) / 1.2, 0.0, 1.0)
		if al >= 1.0: _appear.erase(k)
		if al <= 0.0: return
	var back := floor_y - 34
	var cr: Dictionary = J.crews.get(str(int(b.d)), {}) if J.has("crews") else {}
	_crew_live(c, cr, y, floor_y, back, k, al)
	if not bool(cr.get("push", true)):
		return
	# the pusher: out from the face (left) with a full cart into the shaft, back with an empty one
	var P: Dictionary = J.push
	var n := int(P.n)
	var fps := 24.0
	var step := float(P.step)
	var go := (float(J.portal) + 330.0) / step
	var cyc := 2.0 * go + 16.0
	var ft := fmod(t * fps + k * 37.0, cyc)
	var fi := int(ft) % n
	var hands: Array = P.hands[fi]
	var ps := _size("push/%02d.png" % fi)
	var hx := float(hands[0])
	var portal := float(J.portal)
	var full: Dictionary = J.cart_full
	var empty: Dictionary = J.cart_empty
	if ft < go:
		var x := -330.0 + ft * step
		_cart(c, "cart_full", full, Vector2(x + hx - 34, floor_y + 4), ft * step, false, portal, al)
		_clip_put(c, "push/%02d.png" % fi, Vector2(x, floor_y - ps.y), false, portal, al)
	elif ft >= go + 16:
		var r := (ft - go - 16) * step
		var x := portal + 60 - r
		var es := Vector2(float(empty.w), float(empty.h))
		_cart(c, "cart_empty", empty, Vector2(x + ps.x - hx - es.x + 34, floor_y + 4), r, true, portal, al)
		_clip_put(c, "push/%02d.png" % fi, Vector2(x, floor_y - ps.y), true, portal, al)

## the drill of the deepest open depth: the jackhammer, the rig and the borer work (their sheets), the others shake
func _drill_frame(i: int) -> String:
	match clampi(i, 0, 4):
		0: return "jackhammer/%d.png" % (int(t * 12) % 4)
		2: return "rig/%d.png" % (int(t * 10) % 6)
		3: return "borer/%d.png" % (int(t * 12) % 6)
	return "drill/%d.png" % clampi(i, 0, 4)

## who works at the back of a depth (mine.json "crews"): a pick man at a heap, a shovel man, a man resting on a crate;
## the pump on its plinth at 150 m once the pump is built, water dripping, the jackhammer at the face of 250 m
func _crew_live(c: CanvasItem, cr: Dictionary, y: float, floor_y: float, back: float, k: int, al: float) -> void:
	if cr.has("drip"):
		var dx := float(cr.drip[0])
		var di := int(t * 8 + k * 3) % 16
		if di < 8:
			# the drop falls from the roof and splashes on this gallery's own floor (the sprite's bottom is the puddle)
			var dsz := _size("drip/%d.png" % di)
			var fy := floor_y + 2.0
			var h := fy - (y + 40.0)
			c.draw_texture_rect(tex("drip/%d.png" % di), Rect2(Vector2(dx, fy - h), Vector2(dsz.x, h)), false, Color(1, 1, 1, al * 0.9))
	if cr.has("pump") and int(steps.get("pump", 0)) >= 1:
		var pi := int(t * 10) % 8
		var pp := "pump/%d.png" % pi
		var ps_ := _size(pp)
		_put(c, pp, Vector2(float(cr.pump[0]) - ps_.x / 2, y + float(cr.pump[1]) - ps_.y + 6))
	if cr.has("pair") and _crew_ok("doublejack24"):
		var pf := int(t * 11.0 + k * 5.0) % 24
		var pp := "doublejack24/%02d.png" % pf
		var ps2 := _size(pp)
		_put(c, pp, Vector2(float(cr.pair[0]) - ps2.x / 2, back + 4 - ps2.y), bool(cr.get("pair_flip", false)), al)
		if pf >= 11 and pf <= 13:
			var sx := float(cr.pair[0]) + float(cr.pair[1]) * (-1.0 if bool(cr.get("pair_flip", false)) else 1.0)
			_put(c, "gspark/%d.png" % mini(pf - 11, 3), Vector2(sx, back - 120), false, al)
		if _passed("pair%d" % k, t * 11.0 + k * 5.0, 24.0, 12.0) and k == sel:
			amb.shot("pick", _far(back) - 2.0, 1.05)
	if cr.has("jack"):
		var jp := "jackhammer/%d.png" % (int(t * 12) % 4)
		var js := _size(jp)
		_put(c, jp, Vector2(float(cr.jack[0]) - js.x / 2, back + 10 - js.y), false, al)
	if cr.has("cart") and (cr.get("work", ["x"]) as Array).is_empty():
		_cart(c, "cart_full", J.cart_full, Vector2(float(cr.cart[0]), floor_y + 4), 0.0, false, 1e9, al)
	if cr.has("heap"):
		var hs0 := _size("heap.png")
		_put(c, "heap.png", Vector2(float(cr.heap[0]) - hs0.x / 2, floor_y + 12 - hs0.y), false, al)
	var w: Array = cr.get("work", ["pick", 760, "heap"])
	if w.is_empty():
		return
	var who := String(w[0])
	var x := float(w[1])
	var heap := String(w[2])
	if not _crew_ok(who):
		who = "pick"
	var hs := _size("heap.png")
	if bool(cr.get("front", false)):
		back = floor_y + 6            # he stands by the rails, not at the back wall
	if heap == "heap":
		_put(c, "heap.png", Vector2(x + 52, back - hs.y + 8), false, al)
	elif heap == "heap_l":
		_put(c, "heap.png", Vector2(x - 40 - hs.x, back - hs.y + 8), false, al)
	if who == "pick":
		var pf := int(t * PICK_FPS + k * 2.3) % 6
		var pp := "pick/%d.png" % pf
		var psz := _size(pp)
		_put(c, pp, Vector2(x - psz.x / 2, back - psz.y), false, al)
		var sf := int(fposmod(t * PICK_FPS + k * 2.3 - 2.0, 6.0) * 2.0)
		if sf < 4:
			_put(c, "gspark/%d.png" % sf, Vector2(x + 70, back - hs.y - 30), false, al)
		return
	var flip := bool(cr.get("flip", false))
	var f := _crew_frame(cr, k)
	var p := "%s/%02d.png" % [who, f]
	var rx := _reaction_frame(who, k)
	if rx != "":
		p = rx
	var sz := _size(p)
	if cr.has("cart"):
		# the cart he loads, standing on the rails on the side he throws to; its load grows a little with each throw
		var cd: Dictionary = J.cart_full
		var cx := float(cr.cart[0])
		_cart(c, "cart_full", cd, Vector2(cx, floor_y + 4), 0.0, flip, 1e9, al)
	_put(c, p, Vector2(x - sz.x / 2, back - sz.y), flip, al)
	if (who == "jack24" or who == "lad24") and f >= 11 and f <= 13:
		# the hammer on the chisel: sparks at its point, against the rock (the sheet's right edge; mirrored when flipped)
		var fx := x + (sz.x * 0.42) * (-1.0 if flip else 1.0)
		_put(c, "gspark/%d.png" % mini(f - 11, 3), Vector2(fx - 30, back - sz.y * 0.55), flip, al)
	if who == "pick24":
		var sf := int(fposmod(t * CREW_FPS + k * 7.0 - 10.0, 24.0) / 1.5)
		if sf < 4:
			_put(c, "gspark/%d.png" % sf, Vector2(x + (-5 if flip else 5), back - hs.y - 5), false, al)

## which of a crew's 24 drawings now: a steady loop, or - with "pause" - the action once, then he just sits, breathing
## (drawings 17..24 back and forth) for that many seconds before the next time
func _crew_frame(cr: Dictionary, k: int) -> int:
	var v := t * CREW_FPS + k * 7.0
	if not cr.has("pause"):
		return int(v) % 24
	var act := 24.0
	var rest := float(cr.pause) * CREW_FPS
	var u := fmod(v, act + rest)
	if u < act:
		return int(u)
	var q := int((u - act) / 3.0) % 14
	return 17 + (q if q < 7 else 13 - q)

## the crew's reaction to the level just played, while it plays: its 12 drawings at 8 a second, or ""
func _reaction_frame(who: String, k: int) -> String:
	if _react.is_empty() or int(_react.k) != k:
		return ""
	var s := t - float(_react.t0)
	var name := "%s_%s" % [who.trim_suffix("24"), "cheer" if bool(_react.won) else "scratch"]
	if s < 0.0 or s > 1.5 or not _crew_ok(name):
		return ""
	return "react/%s/%02d.png" % [name, mini(int(s * 8.0), 11)]

## after a win the ore of the level flies down from the top into the depth it came from: gold and iron nuggets in
## arcs, each with a little flash where it lands (a tick of coins in the sound)
func _ore_flight(c: CanvasItem) -> void:
	if _react.is_empty():
		return
	var s := t - float(_react.t0)
	if s > 4.0:
		_react = {}
		return
	if not bool(_react.won):
		return
	var k := int(_react.k)
	var cr: Dictionary = J.crews.get(str(k + 1), {}) if J.has("crews") else {}
	var w: Array = cr.get("work", ["pick", 760, ""])
	var to := Vector2(float(w[1]) if w.size() > 1 else 700.0, band_y(k) + floor_of(k + 1) - 70)
	var vp := get_viewport_rect().size
	var from := Vector2(768, -position.y / scale.y + 40)   # the top of the screen, where the header's ore counters are
	var n_gold := mini(int(_react.ore), 10)
	var n_iron := mini(int(_react.iron), 10)
	for i in n_gold + n_iron:
		var u := (s - 0.4 - i * 0.09) / 0.8
		if u < 0.0 or u > 1.25:
			continue
		var gold := i % 2 == 0 and i / 2 < n_gold or i >= 2 * n_iron
		var tgt := to + Vector2((i % 5 - 2) * 18, (i % 3) * 6)
		if u <= 1.0:
			var e := u * u * (3.0 - 2.0 * u)
			var p := from.lerp(tgt, e) + Vector2(sin(i * 1.7) * 160 * sin(PI * u), -220 * sin(PI * u))
			var col := Color(1.0, 0.78, 0.25) if gold else Color(0.72, 0.76, 0.82)
			c.draw_circle(p, 13, Color(0.12, 0.07, 0.03))
			c.draw_circle(p, 10, col)
			c.draw_circle(p + Vector2(-3, -3), 3.5, Color(1, 1, 1, 0.7))
		else:
			var f := (u - 1.0) / 0.25
			_light(c, tgt, 40 + 30 * f, Color(1.0, 0.85, 0.4, 0.6 * (1.0 - f)))
		if _passed("ore%d" % i, u, 1.0, 1.0):
			amb.shot("coin", -10.0, 1.2 + (i % 4) * 0.05)

## a sprite cut off at the shaft: what is past the portal is inside the shaft
func _clip_put(c: CanvasItem, path: String, pos: Vector2, flip: bool, portal: float, al := 1.0) -> void:
	var tx := tex(path)
	var sz := tx.get_size() / K
	if not flip:
		var w := clampf(portal - pos.x, 0, sz.x)
		if w > 0:
			c.draw_texture_rect_region(tx, Rect2(pos, Vector2(w, sz.y)), Rect2(0, 0, w * K, sz.y * K), Color(1, 1, 1, al))
		return
	# mirrored (a transform, not a negative rect: that came out unflipped and shifted): in the mirrored frame u runs
	# from the sprite's right edge leftwards; only u past the portal's line is outside the shaft
	var u0 := clampf(pos.x + sz.x - portal, 0, sz.x)
	if u0 >= sz.x:
		return
	c.draw_set_transform(Vector2(pos.x + sz.x, pos.y), 0, Vector2(-1, 1))
	c.draw_texture_rect_region(tx, Rect2(u0, 0, sz.x - u0, sz.y), Rect2(u0 * K, 0, (sz.x - u0) * K, sz.y * K), Color(1, 1, 1, al))
	c.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

## a cart standing on the rails at `bottom_left` (its sole), rolled `rolled` px: the wheels turn, it dips over the
## rail joints. Drawn in the cart's own frame (mirrored for the way back), so the wheels stay in their arches; what is
## past the portal is inside the shaft and not drawn
func _cart(c: CanvasItem, path: String, cd: Dictionary, bottom_left: Vector2, rolled: float, flip: bool, portal: float, al := 1.0) -> void:
	var w := float(cd.w)
	var h := float(cd.h)
	var r := float(cd.r)
	var joint := 150.0
	var base := absf(float(cd.wheels[1][0]) - float(cd.wheels[0][0]))
	var dips := []
	for off in [base, 0.0]:
		var uu: float = fmod(rolled + float(off), joint) / 14.0
		dips.append(maxf(0.0, 1.0 - absf(uu - 1.0)) if uu < 2.0 else 0.0)
	var sx := -1.0 if flip else 1.0
	var tilt := deg_to_rad(1.2 * (float(dips[0]) - float(dips[1])) + 0.35 * sin(rolled / 37.0)) * sx
	for wi in 2:
		var jn := floorf((rolled + (base if wi == 0 else 0.0)) / joint)
		var key := "%s%d_%d" % [path, wi, int(bottom_left.y)]
		if int(_cue.get(key, jn)) != int(jn):
			var wx := float(cd.wheels[1 - wi][0])
			if flip: wx = w - wx
			_wheel_dust.append([Vector2(bottom_left.x + wx, bottom_left.y), t])
		_cue[key] = jn
	var sink := 3.0 * maxf(float(dips[0]), float(dips[1]))
	var piv := Vector2(bottom_left.x + w / 2, bottom_left.y + sink)
	# the part of the cart (its own x, -w/2..w/2) still out of the shaft
	var u0 := -w / 2
	var u1 := w / 2
	if flip: u0 = maxf(u0, piv.x - portal)
	else: u1 = minf(u1, portal - piv.x)
	if u1 <= u0:
		return
	var T := Transform2D(tilt, Vector2(sx, 1), 0.0, piv)
	var ws := _size("cart_wheel.png")
	for wh in cd.wheels:
		var ctr := Vector2(float(wh[0]) - w / 2, float(wh[1]) - h)
		if ctr.x + r > u1 or ctr.x - r < u0:
			continue
		c.draw_set_transform_matrix(T * Transform2D(rolled / r, ctr))
		c.draw_texture_rect(tex("cart_wheel.png"), Rect2(-ws / 2, ws), false, Color(1, 1, 1, al))
	c.draw_set_transform_matrix(T)
	var tx := tex(path + ".png")
	c.draw_texture_rect_region(tx, Rect2(u0, -h, u1 - u0, h), Rect2((u0 + w / 2) * K, 0, (u1 - u0) * K, h * K), Color(1, 1, 1, al))
	c.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

## two reptile eyes opening in the dark: a slow open, a look left and right, a blink, closing (s: seconds in)
func _eyes(c: CanvasItem, at: Vector2, s: float, k := 1.0) -> void:
	var o := clampf(s / 0.8, 0.0, 1.0) * clampf((5.0 - s) / 0.8, 0.0, 1.0)
	if s > 2.9 and s < 3.1: o *= 0.1
	if o <= 0.02:
		return
	var look := 0.0
	if s > 1.0 and s < 2.0: look = -1.0
	elif s > 2.0 and s < 2.8: look = 1.0
	_light(c, at, 70 * k, Color(1.0, 0.75, 0.25, 0.35 * o))
	for side in [-1.0, 1.0]:
		var e := at + Vector2(side * 26 * k, 0)
		var h := 11.0 * o * k
		var pts := PackedVector2Array()
		for j in 20:
			var a := TAU * j / 20.0
			pts.append(e + Vector2(cos(a) * 16 * k, sin(a) * h))
		c.draw_colored_polygon(pts, Color(1.0, 0.78, 0.25))
		var pu := e + Vector2(look * 5 * k, 0)
		c.draw_rect(Rect2(pu.x - 1.6 * k, e.y - h * 0.9, 3.2 * k, h * 1.8), Color(0.08, 0.04, 0.0))

func _snake_live(c: CanvasItem) -> void:
	for ev in _events.keys():
		var s := t - float(_events[ev])
		var done := false
		match ev:
			"hole":
				# frames are the snake alone, placed by the burrow drawn in the 50 m wall (mine.json "hole")
				var seq := [1, 1, 2, 2, 3, 3, 4, 4, 4, 5, 5, 5, 4, 4, 6, 6, 7, 8, 9, 10, 10, 10, 10, 10, 10, 10, 10, 9, 8, 7, 6, 3, 2, 1, 1]
				var i := int(s * 6)
				if i >= seq.size() or String(_shown_bands.get(0, "")) == "closed": done = true
				else:
					var hp: Dictionary = J.hole
					var fi := int(seq[i])
					var off: Array = hp.frames[fi]
					_put(c, "snake/hole_%02d.png" % fi, Vector2(float(hp.x) + float(off[0]), band_y(0) + float(hp.y) + float(off[1])))
			"coil":
				var i := int(s * 8)
				if i >= 16 + 4: done = true
				elif i < 16:
					var p := "snake/coil_%02d.png" % i
					var sz := _size(p)
					_put(c, p, Vector2(640 - sz.x / 2, band_y(3) + 512 - 190 + 14 - sz.y))
			"eyes":
				# in the dark of the adit on the surface, under its lantern
				if s > 5.0: done = true
				else:
					_eyes(c, Vector2(968, float(J.sky) + 1606), s, 0.38)
			"lizard":
				# she lives in the crack of the malachite vein on the 200 m back wall: comes out (24 drawings), sits on the vein
				# almost unseen, blinking now and then (12 drawings), and goes back in (the coming out reversed)
				var L2: Dictionary = J.lizard2
				var out_s := 24.0 / 12.0
				var sit := 25.0
				var fr := ""
				if s < out_s: fr = "lizard2/out_%02d.png" % int(s * 12.0)
				elif s < out_s + sit:
					var q := s - out_s
					var blink := fmod(q, 6.0)
					fr = "lizard2/idle_%02d.png" % (int(blink * 8.0) if blink < 1.5 else 0)
				elif s < out_s * 2.0 + sit: fr = "lizard2/out_%02d.png" % (23 - int((s - out_s - sit) * 12.0))
				else: done = true
				if fr != "":
					_put(c, fr, Vector2(float(L2.x), band_y(int(L2.get("k", 0))) + float(L2.y)))
			"bat":
				var u := s / 3.2
				if u >= 1.0: done = true
				else:
					var y := band_y(_bat_k)
					var bx := -80 + u * (float(J.portal) + 120)
					var by := y + 80 + 60 * pow(sin(u * PI * 2), 2)
					if bx < float(J.portal):
						_put(c, "bat/%d.png" % (int(t * 14) % 6), Vector2(bx, by))
		if done:
			_events.erase(ev)
