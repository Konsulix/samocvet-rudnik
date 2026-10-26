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
const PICK_FPS := 8.0     # the pick's swing: 6 drawings, the strike on the third

static var _tex := {}
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
var _cue := {}            # the last frame each sound cue was checked at, so it fires once per crossing
var t := 0.0
var _rng := RandomNumberGenerator.new()
var _bands: Array = []    # per depth: {y, state, lived}
var _bat_k := 0
var _events := {}         # name -> start time of the running rare event, or -1
var _next_event := 0.0
var _bursts: Array = []   # dust bursts where something was just built: [centre, start time]

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
	amb = MineAmb.new(self)
	add_child(amb)
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
	sel = mini(int(Save.d.depth_sel[a]), open)
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
	_events = {}
	_next_event = 4.0
	surf.texture = tex("surface.png")
	surf.scale = Vector2.ONE / K
	var sm := surf.material as ShaderMaterial
	sm.set_shader_parameter("top", (float(J.sky) + 150.0) / (float(J.sky) + float(J.surf)))
	sm.set_shader_parameter("bottom", (float(J.sky) + 340.0) / (float(J.sky) + float(J.surf)))
	sm.set_shader_parameter("amp", 3.0 / 1536.0)
	_changes()
	still.queue_redraw()

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
	if last.is_empty():
		return
	var wait := 0.5      # the screen glides to the place first
	for p in PLACES:
		var was := int(last.places.get(p, 0))
		if int(places[p]) > was:
			_shown_places[p] = was
			var at: Array = J.places[p]
			var now := int(places[p])
			_reveal("place/%s_%d.png" % [p, now], Vector2(float(at[0]), float(at[1])), wait, func(): _shown_places[p] = now)
			if p == "power" and now >= 3:
				_power_on = t + wait + 1.6
	for k in bands:
		var was := String(last.bands.get(k, bands[k]))
		var now := String(bands[k])
		if was == now:
			continue
		var y := band_y(int(k))
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
			_reveal("band/d%d_%s.png" % [d, now], Vector2(0, y), wait + 1.1, func(): _shown_bands[k] = now)
		else:
			_shown_bands[k] = was
			_reveal("band/d%d_%s.png" % [d, now], Vector2(0, y), wait, func(): _shown_bands[k] = now)
	for k in lived:
		if lived[k] and not bool(last.lived.get(k, false)):
			_appear[k] = t + wait

## a stage coming in over the old one: ink lines first, then the colour; at the end the still layer takes it over
func _reveal(path: String, pos: Vector2, delay: float, done: Callable) -> void:
	var sp := Sprite2D.new()
	sp.centered = false
	sp.texture = tex(path)
	sp.scale = Vector2.ONE / K
	sp.position = pos
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/mine_reveal.gdshader")
	m.set_shader_parameter("p", 0.0)
	sp.material = m
	reveals.add_child(sp)
	var tw := sp.create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func(): amb.shot("rockfall", -6.0, 0.9))
	tw.tween_method(func(v: float): m.set_shader_parameter("p", v), 0.0, 1.0, 1.6).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func():
		done.call()
		still.queue_redraw()
		sp.queue_free())

## where a job's work shows (source px): its place on the surface, or the chamber's band
func job_pos(id: String) -> Vector2:
	if J.places.has(id):
		var at: Array = J.places[id]
		var w := _size("place/%s_1.png" % id).x
		return Vector2(float(at[0]) + w / 2, float(J.sky) + 520)
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
	var r := Rect2(pos, sz)
	if flip:
		r = Rect2(pos + Vector2(sz.x, 0), Vector2(-sz.x, sz.y))
	ci.draw_texture_rect(tx, r, false, Color(1, 1, 1, alpha))

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
	# the seams between the bands: a dark line and the shadow of the band above falling on the next
	for b in _bands:
		c.draw_texture_rect(_shade, Rect2(0, float(b.y), float(J.W), 44), false)
		c.draw_rect(Rect2(0, float(b.y) - 3, float(J.W), 6), Color(0.08, 0.055, 0.04))
	# each depth's mark at its top left: the one being dug in gold, closed ones dim
	var font: Font = UI.body_bold
	for b in _bands:
		var k := int(b.k)
		var txt := "%d m" % Data.depth_m(area, k)
		var fs := 54
		var col := Color("#ffd27a") if k == sel else (Color("#f0e6d2") if k <= open else Color(0.75, 0.72, 0.68, 0.7))
		if k == sel: txt = "⛏ " + txt
		var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var r := Rect2(24, float(b.y) + 18, w + 40, 74)
		c.draw_style_box(_chip(k == sel), r)
		c.draw_string(font, Vector2(r.position.x + 20, r.position.y + 54), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	# the shaft down to the floor of the deepest open depth
	var sh: Array = J.shaft
	var seg := _size("shaft.png")
	var y := float(J.sky) + float(J.surf) - 30
	var bottom := band_y(open) + float(J.band) - 40
	while y < bottom:
		var h := minf(seg.y, bottom - y)
		c.draw_texture_rect_region(tex("shaft.png"), Rect2(float(sh[0]), y, seg.x, h), Rect2(0, 0, seg.x * K, h * K))
		y += seg.y

func _chip(on: bool) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.1, 0.07, 0.02, 0.78)
	st.border_color = Color("#e3a51e", 0.85 if on else 0.3)
	st.set_border_width_all(3 if on else 2)
	st.set_corner_radius_all(37)
	return st

# ---------------------------------------------------------------- the live layer

func _process(delta: float) -> void:
	if not visible:
		return
	t += delta
	_tick_events()
	_sounds(delta)
	live.queue_redraw()

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
	if int(steps.get("headframe", 0)) >= 3 and _passed("cage", t, 6.0):
		amb.shot("winch_%d" % (randi() % 2), _far(float(J.cage.top)))
	for b in _bands:
		if not b.lived or _appear.has(int(b.k)):
			continue
		var k := int(b.k)
		var y := float(b.y) + float(J.floor)
		var deep := -k * 1.5
		var mine := k == sel
		# the pick strikes on frame 2 of its swing (the pick down at the heap); every gallery on its own beat
		if _passed("pick%d" % k, t * PICK_FPS + k * 2.3, 6.0, 2.0) and (mine or randf() < 0.18):
			amb.shot("pick", _far(y) + deep + (0.0 if mine else -4.0), 0.9 - k * 0.03)
		# the cart: rolling sounds while it moves (each take is 4 s), out to the shaft and back
		var P: Dictionary = J.push
		var go := (float(J.portal) + 330.0) / float(P.step)
		var cyc := 2.0 * go + 16.0
		var ft := fmod(t * 24.0 + k * 37.0, cyc)
		var moving := ft < go - 30.0 or (ft > go + 16.0 and ft < cyc - 20.0)
		# (the other galleries' carts only when on screen, and not every take: five rolling at once was a din)
		if _passed("cart%d" % k, t * 24.0 + k * 37.0, 96.0) and moving and (mine or (_far(y) > -5.0 and randf() < 0.5)):
			amb.shot("cart_%d" % (randi() % 2), _far(y) + deep + (0.0 if mine else -6.0), 1.0 - k * 0.03)


func _tick_events() -> void:
	if t < _next_event:
		return
	_next_event = t + _rng.randf_range(9.0, 16.0)
	var pool := []
	if open >= 0: pool.append("hole")
	if _bands.size() > 3 and String(_bands[3].state) == "flooded": pool.append("coil")
	if open < _bands.size() - 1: pool.append("eyes")
	pool.append("bat")
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
	for b in _bands:
		_band_live(c, b)
	_snake_live(c)
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
		_put(c, "crow/%d.png" % (int(t * 12) % 6), Vector2(1600 - u * 360, 120 + 25 * sin(t * 1.9)))
	elif u > 12.0 and u < 17.0:
		var v := u - 12.0
		for i in 3:
			var off: Array = [[0, 0, 0], [-70, 34, 3], [-120, -22, 7]][i]
			var x := -100 + v * 360 + float(off[0])
			_put(c, "crow/%d.png" % ((int(t * 12) + int(off[2])) % 6), Vector2(x, 80 + float(off[1]) + 12 * sin(t * 2.2 + i)), true)
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
	# the restored headframe: the cage goes down the shaft and comes back, the wheel turns with the rope
	if int(steps.get("headframe", 0)) >= 3:
		var cg: Dictionary = J.cage
		var depth := float(cg.travel) * (0.5 - 0.5 * cos(TAU * t / 12.0))
		var rx := float(cg.rope_x)
		var top := float(cg.top) + depth
		var gr := float(cg.ground)
		var cs := _size("cage.png")
		c.draw_line(Vector2(rx, float(cg.rope_y)), Vector2(rx, minf(top + 6, gr)), Color(0.59, 0.47, 0.31), 3)
		var vis := minf(cs.y, gr - top)
		if vis > 0:
			c.draw_texture_rect_region(tex("cage.png"), Rect2(rx - cs.x / 2, top, cs.x, vis), Rect2(0, 0, cs.x * K, vis * K))
		var hub: Array = cg.hub
		var ws := _size("wheel.png")
		_put_rot(c, "wheel.png", Vector2(float(hub[0]), float(hub[1])), depth / float(cg.r), ws)
		var bm: Array = cg.beams
		_put(c, "beams.png", Vector2(float(bm[0]), float(bm[1])))

func _band_live(c: CanvasItem, b: Dictionary) -> void:
	var y := float(b.y)
	var floor_y := y + float(J.floor)
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
			var dp := "drill/%d.png" % clampi(k - 1, 0, 4)
			var ds := _size(dp)
			var sh: Array = J.shaft
			var cx := (float(sh[0]) + float(sh[1])) / 2
			var yy := y - ds.y * 0.35 + minf(s / 1.1, 1.0) * (float(J.floor) - ds.y * 0.4)
			_put(c, dp, Vector2(cx - ds.x / 2 + _rng.randf_range(-3, 3), yy + _rng.randf_range(-2, 2)))
	# the drill working at the face under the deepest open depth
	if k == open + 1 and k <= 5:
		var dp := "drill/%d.png" % mini(open, 4)
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
	# the miner at the back breaking a heap of ore, sparks off the heap on each strike
	var back := floor_y - 34
	var hs := _size("heap.png")
	_put(c, "heap.png", Vector2(812, back - hs.y + 8), false, al)
	var pf := int(t * PICK_FPS + k * 2.3) % 6
	var pp := "pick/%d.png" % pf
	var psz := _size(pp)
	_put(c, pp, Vector2(760 - psz.x / 2, back - psz.y), false, al)
	var sf := int(fposmod(t * PICK_FPS + k * 2.3 - 2.0, 6.0) * 2.0)
	if sf < 4:
		_put(c, "gspark/%d.png" % sf, Vector2(830, back - hs.y - 30), false, al)
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

## a sprite cut off at the shaft: what is past the portal is inside the shaft
func _clip_put(c: CanvasItem, path: String, pos: Vector2, flip: bool, portal: float, al := 1.0) -> void:
	var tx := tex(path)
	var sz := tx.get_size() / K
	var w := clampf(portal - pos.x, 0, sz.x)
	if w <= 0:
		return
	if not flip:
		c.draw_texture_rect_region(tx, Rect2(pos, Vector2(w, sz.y)), Rect2(0, 0, w * K, sz.y * K), Color(1, 1, 1, al))
	else:
		# mirrored: the part nearest the portal is the texture's left side
		c.draw_texture_rect_region(tx, Rect2(pos + Vector2(w, 0), Vector2(-w, sz.y)), Rect2((sz.x - w) * K, 0, w * K, sz.y * K), Color(1, 1, 1, al))

## a cart standing on the rails at `bottom_left` (its sole), rolled `rolled` px: the wheels turn, it dips over the
## rail joints, a puff of dust at a knock
func _cart(c: CanvasItem, path: String, cd: Dictionary, bottom_left: Vector2, rolled: float, flip: bool, portal: float, al := 1.0) -> void:
	var w := float(cd.w)
	var h := float(cd.h)
	var r := float(cd.r)
	var pos := Vector2(bottom_left.x, bottom_left.y - h)
	if pos.x > portal: return
	var joint := 150.0
	var base := absf(float(cd.wheels[1][0]) - float(cd.wheels[0][0]))
	var dips := []
	for off in [base, 0.0]:
		var uu: float = fmod(rolled + float(off), joint) / 14.0
		dips.append(maxf(0.0, 1.0 - absf(uu - 1.0)) if uu < 2.0 else 0.0)
	var tilt := deg_to_rad(1.2 * (float(dips[0]) - float(dips[1])) + 0.35 * sin(rolled / 37.0)) * (-1.0 if flip else 1.0)
	var sink := 3.0 * maxf(float(dips[0]), float(dips[1]))
	var ang := rolled / r * (-1.0 if flip else 1.0)
	var piv := pos + Vector2(w / 2, h + sink)
	c.draw_set_transform(piv, tilt, Vector2.ONE)
	var ws := _size("cart_wheel.png")
	for wh in cd.wheels:
		var wx := float(wh[0])
		if flip: wx = w - wx
		var ctr := Vector2(wx - w / 2, float(wh[1]) - h)
		c.draw_set_transform(piv + ctr.rotated(tilt), tilt + ang, Vector2.ONE)
		c.draw_texture_rect(tex("cart_wheel.png"), Rect2(-ws / 2, ws), false, Color(1, 1, 1, al))
	c.draw_set_transform(piv, tilt, Vector2.ONE)
	var tx := tex(path + ".png")
	var rr := Rect2(Vector2(-w / 2, -h), Vector2(w, h))
	if flip: rr = Rect2(Vector2(w / 2, -h), Vector2(-w, h))
	c.draw_texture_rect(tx, rr, false, Color(1, 1, 1, al))
	c.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

func _snake_live(c: CanvasItem) -> void:
	for ev in _events.keys():
		var s := t - float(_events[ev])
		var done := false
		match ev:
			"hole":
				var seq := [0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 4, 5, 5, 5, 4, 4, 6, 6, 7, 8, 9, 10, 10, 10, 10, 10, 10, 10, 10, 9, 8, 7, 6, 3, 2, 1, 0, 0]
				var i := int(s * 6)
				if i >= seq.size(): done = true
				else:
					var p := "snake/hole_%02d.png" % int(seq[i])
					var sz := _size(p)
					_put(c, p, Vector2(900 - sz.x / 2, band_y(0) + float(J.floor) - 29 - sz.y))
			"coil":
				var i := int(s * 8)
				if i >= 16 + 4: done = true
				elif i < 16:
					var p := "snake/coil_%02d.png" % i
					var sz := _size(p)
					_put(c, p, Vector2(640 - sz.x / 2, band_y(3) + 512 - 190 + 14 - sz.y))
			"eyes":
				var seq := [0, 0, 1, 2, 3, 3, 4, 4, 5, 5, 3, 3, 6, 7, 0]
				var i := int(s * 3)
				if i >= seq.size(): done = true
				else:
					var p := "snake/eyes_%d.png" % int(seq[i])
					var sz := _size(p)
					_put(c, p, Vector2(560 - sz.x / 2, band_y(open) + float(J.band) - 8 - sz.y / 2))
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
