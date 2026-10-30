class_name FireView
extends MineView
## Fire Horizon (mine 4, the Cyclops Brontes'): the sulphur mines of inner Sicily under Etna, drawn like Old Adit (MineView)
## but laid out its own way (docs/mine-design.md §9, docs/mine4-etna.md): the only DAY of the mines - a hot day under the
## ash of Etna - terraces of kilns, a chapel and a winding engine over a gorge; there is no shaft: the mine is entered by
## the rock-cut stair behind the giants' gate, seen in section going down from the gate to a stairwell that runs down the
## left of every depth, and the carusi (boys with sacks) climb it. The life of the place is the BREATH OF THE FORGE: every
## ~8 s a blow of a hammer comes up from below - the cracks of every gallery flare orange (the deeper the brighter), the
## lamps dip, dust falls from the roofs, Etna glows on the horizon. Home makes it for area 3 when its pictures exist
## (available_here) and talks to it as to MineView.
## Pictures and coordinates: assets/mine/fire_horizon/ + mine.json (art/zone/export_mine4.py), source px of the
## 1536-wide stack: the sky, the surface, the section under the gate, the depth bands.

const FDIR := "res://assets/mine/fire_horizon/"
## the surface's places in drawing order (their pictures meet at soft edges)
const FPLACES := ["draught", "kiln", "winder", "chapel", "mules", "stair"]
## the depths whose job is built in the gallery itself: its stages are the band's pictures
const FBAND_JOBS := {7: "wall", 8: "bridge", 9: "gate"}
const FSTAGES := ["clear", "step1", "step2", "done"]

var _sfx: Node2D           # smoke and steam (particles in the picture's own coordinates)
var _smokes: Array = []    # [particles, the place it belongs to, the step from which it smokes]
var _hold := {}            # depth -> when its crew's reaction began
var _blow_at := -100.0     # the last blow of the hammer below
var _blow_n := 0
var _blow_k := 1.0         # how hard it was
var _next_blow := 2.5
var _panel_i := 0          # the picture the storyteller's panel shows, and when it turned to it
var _panel_at := -100.0
var _flying: Array = []    # sparks in the air: [pos, vel, born, life, size]
var _stream: Sprite2D      # the acid stream down the gorge and the section (its own layer, the flowing shader)
var _lava: Array = []      # Etna's bombs, far off over its crater: [pos, vel, born, life, size]
var _frost_at := -100.0    # the herald's cold draught at 300 m

func _init() -> void:
	dir = FDIR

## a hot day: the cave breathes under it, the cicadas are the mine's own (FireSounds)
func amb_beds() -> Array:
	return ["cave"]

func available_here() -> bool:
	return FileAccess.file_exists(FDIR + "mine.json")

func _ready() -> void:
	super()
	_sfx = Node2D.new()
	add_child(_sfx)
	move_child(_sfx, live.get_index())
	_stream = Sprite2D.new()
	_stream.centered = false
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/fire_stream.gdshader")
	_stream.material = sm
	add_child(_stream)
	move_child(_stream, _sfx.get_index())

# ---------------------------------------------------------------- state

func _cut_top() -> float:
	return float(J.sky) + float(J.surf)

func setup(a: int) -> void:
	J = JSON.parse_string(FileAccess.get_file_as_string(dir + "mine.json"))
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
	var y0 := _cut_top() + float(J.cut)
	for k in Data.depths(a).size():
		var d := k + 1
		var st := "closed"
		if k <= open:
			st = "clear"
			if FBAND_JOBS.has(d):
				st = FSTAGES[clampi(int(steps.get(FBAND_JOBS[d], 0)), 0, 3)]
		var lived: bool = k <= open and k < wins.size() and int(wins[k]) >= 2 and J.crews.has(str(d))
		_bands.append({y = y0 + k * float(J.band), state = st, d = d, lived = lived, k = k})
	H = y0 + _bands.size() * float(J.band)
	if _set_area != a:
		_events = {}
		_next_event = 6.0
		_set_area = a
	surf.texture = tex("surface.png")
	surf.scale = Vector2.ONE / K
	if J.has("stream"):
		var sa: Array = J.stream.at
		_stream.texture = tex("stream.png")
		_stream.scale = Vector2.ONE / K
		_stream.position = Vector2(float(sa[0]), float(sa[1]))
		(_stream.material as ShaderMaterial).set_shader_parameter("speed", float(J.stream.speed) * K)
		# while the stair is not built the section is drawn dark: so is its stream
		_stream.modulate = Color.WHITE if int(steps.get("stair", 0)) >= 3 else Color(0.62, 0.6, 0.58)
	surf.material = null
	still.material = null
	_changes()
	if not last_result.is_empty() and int(last_result.area) == a:
		var k := clampi(int(last_result.k), 0, _bands.size() - 1)
		var t0 := t + 0.7
		var v := _crew_v(k, t0)
		var ln := _loop(J.crews.get(str(int(_bands[k].d)), {}))
		if ln > 0.0:
			t0 += (ceilf(v / ln) * ln - v) / CREW_FPS
		_hold[k] = t0
		_react = {k = k, won = bool(last_result.won), t0 = t0, iron = int(last_result.iron), ore = int(last_result.ore)}
		if focus_y < 0: focus_y = band_y(k) + float(J.band) * 0.5
		last_result = {}
	_setup_smoke()
	_make_motes()
	_find_niches()
	still.queue_redraw()
	front.queue_redraw()

## what changed since the screen was last shown: new stages come in (ink, then colour), a newly opened level shows
## through the dust, the people of a level fade in after its second win
func _changes() -> void:
	var places := {}
	for p in FPLACES: places[p] = int(steps.get(p, 0))
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
	var wait := 0.5
	for p in FPLACES:
		var was := int(last.places.get(p, 0))
		var now := int(places[p])
		if now <= was:
			continue
		if focus_y < 0: focus_y = job_pos(p).y
		_shown_places[p] = was
		var at: Array = J.places[p]
		_reveal("place/%s_%d.png" % [p, now], Vector2(float(at[0]), float(at[1])), wait, func(): _shown_places[p] = now,
			"place/%s_%d.png" % [p, was] if was > 0 else "surface.png")
	for k in bands:
		var was := String(last.bands.get(k, bands[k]))
		var now := String(bands[k])
		if was == now:
			continue
		var y := band_y(int(k))
		if focus_y < 0: focus_y = y + float(J.band) * 0.5
		var d := int(k) + 1
		_shown_bands[k] = was
		var delay := wait
		if was == "closed":
			# the way down is cut: dust bursts along the new level, then the gallery shows through it
			delay = wait + 0.9
			get_tree().create_timer(wait).timeout.connect(func(): amb.shot("rockfall", 0.0, 0.7))
			for j in 4:
				_bursts.append([Vector2(560 + 240 * j, y + 330), t + wait + 0.2 + 0.12 * j])
		_reveal("band/d%d_%s.png" % [d, now], Vector2(0, y), delay, func(): _shown_bands[k] = now, "band/d%d_%s.png" % [d, was])
		if d == 9 and now == "done":
			_tremor_at = t + delay + 2.2      # the forge gate is open: the whole hill shudders
	for k in lived:
		if lived[k] and not bool(last.lived.get(k, false)):
			_appear[k] = t + wait
			if focus_y < 0: focus_y = band_y(int(k)) + float(J.band) * 0.5

func job_pos(id: String) -> Vector2:
	if J.place_box.has(id):
		var bx: Array = J.place_box[id]
		return Vector2((float(bx[0]) + float(bx[2])) / 2, (float(bx[1]) + float(bx[3])) / 2)
	for d in FBAND_JOBS:
		if FBAND_JOBS[d] == id:
			return Vector2(900, band_y(int(d) - 1) + 300)
	return Vector2(768, float(J.sky) + 900)

# ---------------------------------------------------------------- the still pictures

func _draw_still() -> void:
	var c := still
	for p in FPLACES:
		var s := int(_shown_places.get(p, 0))
		if s > 0:
			var at: Array = J.places[p]
			_put(c, "place/%s_%d.png" % [p, s], Vector2(float(at[0]), float(at[1])))
	# the section's stair: lit once the stair is mended, abandoned before
	_put(c, "cut.png" if int(_shown_places.get("stair", 0)) >= 3 else "cut_dark.png", Vector2(0, _cut_top()))
	for b in _bands:
		var st := String(_shown_bands.get(int(b.k), b.state))
		_put(c, "band/d%d_%s.png" % [int(b.d), st], Vector2(0, float(b.y)))
	_draw_niches(c)
	for b in _bands:
		c.draw_texture_rect(_shade, Rect2(0, float(b.y), float(J.W), 44), false)
		c.draw_rect(Rect2(0, float(b.y) - 3, float(J.W), 6), Color(0.07, 0.045, 0.03))
	_draw_bedrock(c)
	_stairwell(c)

## the stairwell: one drawn piece (two flights and two landings) repeated down the left of the depths, its right landing
## on each gallery's floor, from under the section down to the deepest open level (the closed ones below are rock)
func _stairwell(c: CanvasItem) -> void:
	var sw: Dictionary = J.stair
	var seg := _size("stair.png")
	var x := float(sw.x)
	var y := float(sw.top)
	var start := float(sw.start)
	var bottom := _stair_bottom()
	var tx := tex("stair.png")
	var dark := Color(1, 1, 1) if int(_shown_places.get("stair", 0)) >= 3 else Color(0.62, 0.58, 0.55)
	const FADE := 36.0           # it comes out of the section's landing softly
	while y < bottom:
		var y0 := maxf(y, start)
		var y1 := minf(y + seg.y, bottom)
		while y0 < y1:
			var sl := minf(y1 - y0, 6.0 if y0 < start + FADE else y1 - y0)
			var al := clampf((y0 + sl * 0.5 - start) / FADE, 0.0, 1.0)
			c.draw_texture_rect_region(tx, Rect2(x, y0, seg.x, sl), Rect2(0, (y0 - y) * K, seg.x * K, sl * K), Color(dark, al))
			y0 += sl
		y += seg.y
	# its foot: rubble where the cutting stopped
	c.draw_texture_rect(_shade, Rect2(x, bottom - 30, seg.x, 30), false, Color(1, 1, 1, 0.8))

## where the stair ends: the landing of the deepest open level
func _stair_bottom() -> float:
	return band_y(open) + floor_of(open + 1) + 26.0

func _draw_shaft(_c: CanvasItem) -> void:
	pass

func _draw_cage(_c: CanvasItem) -> void:
	pass

# ---------------------------------------------------------------- niches

func _find_niches() -> void:
	_niche_want = {}
	for s in Save.d.coll:
		if int(s.get("area", -1)) != area or not s.has("dl"):
			continue
		var k := int(s.dl)
		if k > open or not J.niches.has(str(k + 1)):
			continue
		if not _niche_want.has(k) or int(s.value) > int(_niche_want[k].value):
			_niche_want[k] = s
	for k in _niche_want:
		var key := Spec.key_of(Spec.of_stone(_niche_want[k]))
		if not _niche_tex.has(key):
			_render_niche(Spec.of_stone(_niche_want[k]), key)

## a depth's pedestal top in band rows ([x, y]), [0, 0] where the depth has none (Home's niche test)
func niche_spot(k: int) -> Array:
	return J.niches.get(str(k + 1), [0, 0])

func _niche_at_k(k: int) -> Vector2:
	var nc: Array = J.niches[str(k + 1)]
	return Vector2(float(nc[0]), band_y(k) + float(nc[1]))

func niche_at(p: Vector2) -> Dictionary:
	for k in _niche_want:
		var key := Spec.key_of(Spec.of_stone(_niche_want[k]))
		if not _niche_tex.has(key):
			continue
		var at := _niche_at_k(k)
		var sz := _niche_size(_niche_tex[key])
		if Rect2(at.x - sz.x / 2 - 30, at.y - sz.y - 30, sz.x + 60, sz.y + 50).has_point(p):
			return _niche_want[k]
	return {}

func _draw_niches(c: CanvasItem) -> void:
	for k in _niche_want:
		var key := Spec.key_of(Spec.of_stone(_niche_want[k]))
		if not _niche_tex.has(key) or String(_shown_bands.get(k, "")) == "closed":
			continue
		var tx: Texture2D = _niche_tex[key]
		var at := _niche_at_k(k)
		var sz := _niche_size(tx)
		var pos := Vector2(at.x - sz.x / 2, at.y - sz.y + 8)
		c.draw_texture_rect(_glow, Rect2(Vector2(at.x - sz.x * 0.6, at.y - 10), Vector2(sz.x * 1.2, 22)), false, Color(0.08, 0.04, 0.02, 0.6))
		for dv in [Vector2(-3, 0), Vector2(3, 0), Vector2(0, -3), Vector2(0, 3), Vector2(-2, -2), Vector2(2, 2), Vector2(-2, 2), Vector2(2, -2)]:
			c.draw_texture_rect(tx, Rect2(pos + dv, sz), false, Color(0.07, 0.04, 0.03, 1.0))
		c.draw_texture_rect(tx, Rect2(pos, sz), false, Color(1.0, 0.92, 0.8))

# ---------------------------------------------------------------- smoke (particles in the picture's coordinates)

func _setup_smoke() -> void:
	for ch in _sfx.get_children(): ch.queue_free()
	_smokes = []
	for s in J.smoke:
		var spec: Dictionary = s     # at [x, y], size, kind: kiln | etna | steam, place, from (the step it smokes from)
		var k := float(spec.size)
		var kind := String(spec.kind)
		var p := CPUParticles2D.new()
		p.texture = tex("puff.png")
		p.local_coords = true
		p.position = Vector2(float(spec.at[0]), float(spec.at[1]))
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		var sc := Curve.new()
		var g := Gradient.new()
		match kind:
			"etna":
				# the volcano's plume: big slow billows leaning away with the high wind
				p.amount = 22
				p.lifetime = 16.0
				p.preprocess = 16.0
				p.emission_sphere_radius = 14.0 * k
				p.direction = Vector2(0.35, -1)
				p.spread = 10
				p.gravity = Vector2(7, -2)
				p.initial_velocity_min = 14 * k
				p.initial_velocity_max = 22 * k
				p.scale_amount_min = 0.9 * k
				p.scale_amount_max = 1.3 * k
				sc.add_point(Vector2(0, 0.5))
				sc.add_point(Vector2(1, 4.5))
				g.set_color(0, Color(0.9, 0.45, 0.2, 0.0))
				g.add_point(0.08, Color(0.42, 0.32, 0.27, 0.75))
				g.add_point(0.5, Color(0.33, 0.29, 0.27, 0.55))
				g.set_color(g.get_point_count() - 1, Color(0.3, 0.27, 0.25, 0.0))
			"steam":
				# the winding engine's exhaust: quick white puffs
				p.amount = 16
				p.lifetime = 3.2
				p.preprocess = 3.2
				p.emission_sphere_radius = 4.0 * k
				p.direction = Vector2(0.2, -1)
				p.spread = 14
				p.gravity = Vector2(14, -6)
				p.initial_velocity_min = 40 * k
				p.initial_velocity_max = 60 * k
				p.scale_amount_min = 0.35 * k
				p.scale_amount_max = 0.5 * k
				sc.add_point(Vector2(0, 0.4))
				sc.add_point(Vector2(1, 3.0))
				g.set_color(0, Color(1, 1, 1, 0.0))
				g.add_point(0.1, Color(0.92, 0.9, 0.86, 0.55))
				g.set_color(g.get_point_count() - 1, Color(0.8, 0.78, 0.75, 0.0))
			_:
				# a kiln's acrid smoke: yellow-grey, low and lazy, drifting off down the gorge
				p.amount = 18
				p.lifetime = 7.0
				p.preprocess = 7.0
				p.emission_sphere_radius = 10.0 * k
				p.direction = Vector2(0.4, -1)
				p.spread = 18
				p.gravity = Vector2(10, -3)
				p.initial_velocity_min = 16 * k
				p.initial_velocity_max = 26 * k
				p.scale_amount_min = 0.5 * k
				p.scale_amount_max = 0.8 * k
				sc.add_point(Vector2(0, 0.5))
				sc.add_point(Vector2(1, 3.4))
				g.set_color(0, Color(0.95, 0.85, 0.4, 0.0))
				g.add_point(0.1, Color(0.85, 0.79, 0.52, 0.65))
				g.add_point(0.5, Color(0.62, 0.6, 0.52, 0.45))
				g.set_color(g.get_point_count() - 1, Color(0.5, 0.48, 0.45, 0.0))
		p.angular_velocity_min = -10
		p.angular_velocity_max = 10
		p.scale_amount_curve = sc
		p.color_ramp = g
		_sfx.add_child(p)
		_smokes.append([p, String(spec.get("place", "")), int(spec.get("from", 0))])
	_update_smoke()

func _update_smoke() -> void:
	for s in _smokes:
		var pl := String(s[1])
		(s[0] as CPUParticles2D).emitting = pl == "" or int(_shown_places.get(pl, 0)) >= int(s[2])

# ---------------------------------------------------------------- the breath of the forge

## how strongly the last blow still shows `s` seconds after it: a quick flare, a slow fading
func _beat(s: float) -> float:
	if s < 0.0:
		return 0.0
	if s < 0.05:
		return s / 0.05
	return exp(-(s - 0.05) * 2.0)

func _blow() -> void:
	_blow_at = t
	_blow_n += 1
	# every few blows a heavy one: Etna breathes out sparks, the deep levels shake a little
	_blow_k = 1.35 if _blow_n % 4 == 0 else _rng.randf_range(0.75, 1.0)
	FireSounds.hammer(self, _blow_k)
	if _blow_k > 1.2:
		_etna_sparks(1.0)

func _process(delta: float) -> void:
	super(delta)
	if not visible or J.is_empty():
		return
	if Engine.get_process_frames() % 20 == 0:
		_update_smoke()
	if t > _next_blow:
		_next_blow = t + _rng.randf_range(7.0, 9.5)
		_blow()
	# the storyteller's panel turns every 14 s; when it comes back to the giant at his forge, the hammer answers
	if t - _panel_at > 14.0:
		_panel_at = t
		_panel_i = (_panel_i + 1) % maxi(1, int(J.panel.n))
		if _panel_i == 0 and t - _blow_at > 3.0:
			_next_blow = t + 0.8
	_fly(delta)
	_lava_fly(delta)
	# now and then Etna throws a few bombs by itself
	if _rng.randf() < delta / 5.0:
		_etna_sparks(0.35)

## sparks in the air: they fly, fall and go out (drawn in _draw_live)
func _fly(dt: float) -> void:
	for f in _flying.duplicate():
		var age := t - float(f[2])
		if age > float(f[3]):
			_flying.erase(f)
			continue
		var v: Vector2 = f[1]
		v.y += 420.0 * dt
		v *= 1.0 - 0.6 * dt
		f[1] = v
		f[0] = (f[0] as Vector2) + v * dt

func _spray(at: Vector2, dir_: Vector2, n: int, speed: float, life: float, size := 3.0) -> void:
	for i in n:
		var a := dir_.angle() + _rng.randf_range(-0.55, 0.55)
		var v := Vector2.from_angle(a) * speed * _rng.randf_range(0.5, 1.2)
		_flying.append([at, v, t + _rng.randf_range(0.0, 0.25), life * _rng.randf_range(0.6, 1.1), size * _rng.randf_range(0.6, 1.3)])

## Etna is far off: its bombs are small, rise only a little over the crater and fall back on its own cone, glowing out
func _etna_sparks(k: float) -> void:
	var et: Array = J.etna
	var mouth := Vector2(float(et[0]), float(et[1]))
	for i in int(34 * k):
		var a := -PI / 2 + _rng.randf_range(-0.75, 0.75)
		var v := Vector2.from_angle(a) * _rng.randf_range(38.0, 92.0) * minf(k, 1.2)
		_lava.append([mouth + Vector2(_rng.randf_range(-7, 7), _rng.randf_range(-2, 2)), v, t + _rng.randf_range(0.0, 0.6),
			_rng.randf_range(1.6, 2.6), _rng.randf_range(0.9, 2.0)])

func _lava_fly(dt: float) -> void:
	for f in _lava.duplicate():
		var age := t - float(f[2])
		if age > float(f[3]):
			_lava.erase(f)
			continue
		if age < 0.0:
			continue
		var v: Vector2 = f[1]
		v.y += 85.0 * dt
		f[1] = v
		f[0] = (f[0] as Vector2) + v * dt

func _lava_live(c: CanvasItem) -> void:
	for f in _lava:
		var age := t - float(f[2])
		if age < 0.0:
			continue
		var q := age / float(f[3])
		var p: Vector2 = f[0]
		var v: Vector2 = f[1]
		var sz := float(f[4])
		var a := 1.0 - q * q
		c.draw_line(p, p - v * 0.08, Color(1.0, 0.4, 0.1, 0.45 * a), sz)
		c.draw_circle(p, sz * 0.75, Color(1.0, 0.82 - 0.45 * q, 0.4 - 0.3 * q, a))
		_light(c, p, sz * 4.0, Color(1.0, 0.45, 0.15, 0.3 * a))

# ---------------------------------------------------------------- the live layer

func _draw_live() -> void:
	var c := live
	_lights(c)
	_surface_live(c)
	_fire_flags(c)
	for b in _bands:
		if _band_seen(b): _band_live(c, b)
	_carusi(c)
	_events_live(c)
	_sparks_live(c)
	_lava_live(c)
	_ore_flight(c)
	_finale(c)
	for bu in _bursts.duplicate():
		if t < float(bu[1]):
			continue
		var i := int((t - float(bu[1])) * 12)
		if i >= 8:
			_bursts.erase(bu)
			continue
		var p := "burst/%02d.png" % i
		var sz := _size(p) * 1.6
		var at: Vector2 = bu[0]
		c.draw_texture_rect(tex(p), Rect2(at - sz / 2, sz), false)

## the sun through Etna's ash: a slow corona and long faint rays turning, ash drifting across it that veils it (the
## rays and the glow dim while a veil passes), and the disc's rim shimmering in the heat
func _sun(c: CanvasItem, at: Vector2, r: float) -> void:
	var veil := 0.0
	var ash: Array[Vector2] = []
	for i in 3:
		var u := fmod(t / (38.0 + i * 11.0) + i * 0.37, 1.0)
		var p := at + Vector2(-r * 9.0 + u * r * 18.0, (i - 1) * r * 0.9 + r * 0.4 * sin(t * 0.21 + i))
		ash.append(p)
		veil = maxf(veil, clampf(1.0 - p.distance_to(at) / (r * 2.6), 0.0, 1.0))
	var k := 1.0 - 0.55 * veil
	var br := 0.85 + 0.15 * sin(t * 0.5) * sin(t * 0.23 + 1.0)
	for i in 12:
		var a := t * 0.03 + TAU * i / 12.0 + 0.2 * sin(i * 3.7)
		var ln := r * (4.0 + 2.5 * absf(sin(i * 2.3 + t * 0.15)))
		var d := Vector2.from_angle(a)
		var n := d.orthogonal() * r * 0.22
		var col := Color(1.0, 0.7, 0.38, 0.13 * k * br)
		c.draw_polygon(PackedVector2Array([at + d * r * 0.9 - n, at + d * ln, at + d * r * 0.9 + n]),
			PackedColorArray([col, Color(col, 0.0), col]))
	_light(c, at, r * 7.0, Color(1.0, 0.62, 0.32, 0.13 * k * br))
	_light(c, at, r * 2.6, Color(1.0, 0.75, 0.42, 0.42 * k * br))
	_light(c, at, r * 1.25, Color(1.0, 0.86, 0.6, 0.5 * k))
	for j in 3:
		var rr := r * (1.02 + 0.03 * j) + 1.2 * sin(t * 3.1 + j * 2.0)
		c.draw_arc(at, rr, 0, TAU, 40, Color(1.0, 0.8, 0.5, 0.18 - 0.05 * j), 2.0)
	for p in ash:
		c.draw_texture_rect(tex("puff.png"), Rect2(p - Vector2(r * 2.2, r * 0.9), Vector2(r * 4.4, r * 1.8)), false, Color(0.16, 0.12, 0.1, 0.55))

func _lights(c: CanvasItem) -> void:
	var bt := _beat(t - _blow_at) * _blow_k
	# the hidden sun through the ash, and Etna's mouth glowing - brighter for a moment with each blow below
	if J.has("sun"):
		var sn: Array = J.sun
		_sun(c, Vector2(float(sn[0]), float(sn[1])), float(sn[2]))
	var et: Array = J.etna
	var ep := Vector2(float(et[0]), float(et[1]))
	_light(c, ep, 90.0 + 60.0 * bt, Color(1.0, 0.35, 0.1, 0.3 + 0.45 * bt))
	_light(c, ep + Vector2(0, -40), 200.0, Color(1.0, 0.45, 0.2, 0.06 + 0.12 * bt))
	var sl: Dictionary = J.surface_lamps
	var i := 0
	for place in sl:
		if int(_shown_places.get(place, 0)) < 3:
			continue
		for l in sl[place]:
			i += 1
			var col := Color(1.0, 0.72, 0.35, 0.33)
			if (l as Array).size() > 3: col = Color(String(l[3]))
			col.a *= _flick(i)
			_light(c, Vector2(float(l[0]), float(l[1])), 70 * float(l[2]), col)
	# the lamps of the galleries dip at each blow (the flames shy), and come back
	var dip := 1.0 - 0.5 * clampf(_beat(t - _blow_at - 0.05), 0.0, 1.0)
	for b in _bands:
		var k := int(b.k)
		if String(_shown_bands.get(k, b.state)) == "closed" or not _band_seen(b):
			continue
		var ls: Array = J.lamps.get(str(int(b.d)), [])
		for j in ls.size():
			var l: Array = ls[j]
			var out := 1.0
			if J.has("herald") and int(b.d) == int(J.herald.d) and _events.has("herald"):
				out = _herald_lamp(j)
			_light(c, Vector2(float(l[0]), float(b.y) + float(l[1])), 150, Color(1.0, 0.68, 0.3, 0.26 * _flick(k * 3 + j) * dip * out))

## the surface alive: the kilns smoke with blue flames, the fire basket of the air chimney, the winding wheel turning,
## the chapel's candles and bell, the storyteller and his panel, the kiln man, the donkey, a goat, a kestrel
func _surface_live(c: CanvasItem) -> void:
	var sky := float(J.sky)
	var kl: Dictionary = J.kilns
	if int(_shown_places.get("kiln", 0)) >= 2:
		for d_ in kl.doors:
			var d: Array = d_
			_light(c, Vector2(float(d[0]), float(d[1])), 60, Color(1.0, 0.5, 0.15, 0.4 * _flick(int(d[0]))))
	if int(_shown_places.get("kiln", 0)) >= 3:
		var j := 0
		for f_ in kl.flames:
			var f: Array = f_
			j += 1
			_blue_flame(c, Vector2(float(f[0]), float(f[1])), 1.0, j)
	var dr: Dictionary = J.draught
	if int(_shown_places.get("draught", 0)) >= 3:
		var bp := Vector2(float(dr.basket[0]), float(dr.basket[1]))
		_light(c, bp, 110, Color(1.0, 0.5, 0.15, 0.45 * _flick(77)))
		_light(c, bp + Vector2(0, -50), 60, Color(1.0, 0.8, 0.35, 0.35 * _flick(78)))
		# the draught pulls sparks up out of the basket
		for e in 7:
			var u := fmod(t * 0.55 + e / 7.0, 1.0)
			var p := bp + Vector2(sin(e * 2.1 + t * 1.3) * 18.0 + u * 10.0, -40.0 - u * 220.0)
			_light(c, p, 7.0, Color(1.0, 0.75, 0.3, 0.9 * (1.0 - u)))
	_winder(c)
	if int(_shown_places.get("chapel", 0)) >= 3:
		_chapel(c)
	if int(_shown_places.get("stair", 0)) >= 3:
		var lp: Array = J.gate_lamp
		_light(c, Vector2(float(lp[0]), float(lp[1])), 80, Color(1.0, 0.72, 0.35, 0.45 * _flick(91)))
	_panel(c)
	for a in J.life:
		var spec: Dictionary = a
		var nm := String(spec.name)
		if not _crew_ok(nm):
			continue
		if spec.has("place") and int(_shown_places.get(String(spec.place), 0)) < int(spec.get("from", 3)):
			continue
		var n := int(J.crew_n[nm])
		var ph := float(spec.get("ph", 0))
		var x := float(spec.x)
		var flip := bool(spec.get("flip", false))
		var u := (t + ph) * float(spec.get("fps", 8))
		var fr := "%s/%02d.png" % [nm, _drawing_at(spec, u) if spec.has("play") else int(u) % n]
		var fs := _size(fr) * float(spec.get("s", 1.0))
		var pos := Vector2(x - fs.x / 2, sky + float(spec.y) - fs.y)
		if flip:
			c.draw_set_transform(pos + Vector2(fs.x, 0), 0, Vector2(-1, 1))
			c.draw_texture_rect(tex(fr), Rect2(Vector2.ZERO, fs), false)
			c.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		else:
			c.draw_texture_rect(tex(fr), Rect2(pos, fs), false)
		if spec.has("rail"):
			# behind a railing: its rails and posts, cut out of the picture as it is now, drawn over it again
			var rp: Array = J[String(spec.rail)]
			_put(c, "%s_%d.png" % [String(spec.rail), mini(int(_shown_places.get("mules", 0)), 3)], Vector2(float(rp[0]), float(rp[1])))
		if nm == "donkey" and _passed("bray", u, float(n), 7.0) and randf() < 0.35:
			FireSounds.donkey(self, _far(sky + float(spec.y)))
	_kestrel(c)

## a small blue flame of burning sulphur: a few tongues licking up, flickering
func _blue_flame(c: CanvasItem, at: Vector2, k: float, seed_: int) -> void:
	_light(c, at + Vector2(0, -6), 34 * k, Color(0.35, 0.55, 1.0, 0.35 + 0.1 * sin(t * 9.0 + seed_)))
	for j in 3:
		var h := (16.0 + 10.0 * sin(t * (7.0 + j * 2.3) + seed_ * 1.7 + j)) * k
		var x := (j - 1) * 7.0 * k + 2.0 * sin(t * 5.0 + j + seed_)
		var tip := at + Vector2(x + 3.0 * sin(t * 11.0 + j), -h)
		var pts := PackedVector2Array([at + Vector2(x - 5.0 * k, 0), tip, at + Vector2(x + 5.0 * k, 0)])
		c.draw_colored_polygon(pts, Color(0.45, 0.65, 1.0, 0.55))
		c.draw_line(at + Vector2(x, -2), tip.lerp(at + Vector2(x, 0), 0.4), Color(0.85, 0.95, 1.0, 0.6), 2.0)

## the winding engine: the wheel on the headframe turning (drawn here, the picture's wheel was taken out), the rope
## running, the flywheel turning, the engine door's fire, puffs of steam with each turn (FireSounds.chuff)
func _winder(c: CanvasItem) -> void:
	var w: Dictionary = J.winder
	var st := int(_shown_places.get("winder", 0))
	if st < 3:
		return
	var dp: Array = w.door
	_light(c, Vector2(float(dp[0]), float(dp[1])), 80, Color(1.0, 0.55, 0.2, 0.4 * _flick(66)))
	var a := t * 1.4
	var wh: Array = w.wheel
	_wheel(c, Vector2(float(wh[0]), float(wh[1])), float(wh[2]), a, 8, Color(0.12, 0.11, 0.1), float(wh[3]), float(wh[4]))
	var fw: Array = w.flywheel
	_wheel(c, Vector2(float(fw[0]), float(fw[1])), float(fw[2]), a * float(wh[2]) / float(fw[2]) * 0.6, 8, Color(0.16, 0.16, 0.17), float(fw[3]), float(fw[4]))
	# what stands in front of the wheels in the picture: the headframe's top platform, the steam pipe
	for f_ in w.get("front", []):
		var fe: Array = f_
		var fa: Array = fe[1]
		_put(c, String(fe[0]), Vector2(float(fa[0]), float(fa[1])))
	if _passed("chuff", a, PI):
		FireSounds.chuff(self, _far(float(fw[1])))

## a spoked wheel of old wrought iron, in ink like the picture: a dark rim with the rope's groove, the light of the hazy
## sun on its upper left and shade below right (these stay put while it turns), rust patches, tapered spokes, a bolted hub
## seen at an angle, as the picture draws them: the wheel's plane squeezed sideways to `sx`, its spokes turning in it,
## and the tyre's thickness showing on the left (`depth` px: the far face of the rim, the tread between them)
func _wheel(c: CanvasItem, at: Vector2, r: float, a: float, spokes: int, col: Color, sx := 1.0, depth := 0.0) -> void:
	var ink := Color(0.035, 0.027, 0.02)
	var iron := Color(0.1, 0.095, 0.09).lerp(col, 0.25)
	var w := r * 0.19
	if depth > 0.0:
		var back := at + Vector2(-depth, 0)
		c.draw_set_transform(back, 0, Vector2(sx, 1))
		c.draw_arc(Vector2.ZERO, r, 0, TAU, 48, ink, w + 4.0)
		c.draw_arc(Vector2.ZERO, r, 0, TAU, 48, iron.darkened(0.35), w)
		c.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		# the tread on the left half: quads between the front and the far face of the rim's outer edge
		for j in 24:
			var a0 := PI * 0.5 + PI * j / 24.0
			var a1 := a0 + PI / 24.0
			var o0 := at + Vector2(cos(a0) * sx, sin(a0)) * (r + w * 0.5)
			var o1 := at + Vector2(cos(a1) * sx, sin(a1)) * (r + w * 0.5)
			var f := clampf(-sin((a0 + a1) * 0.5) * 0.6 + 0.4, 0.0, 1.0)
			var tone := iron.darkened(0.3).lerp(Color(0.3, 0.28, 0.26), f * 0.5)
			c.draw_colored_polygon(PackedVector2Array([o0, o1, o1 + Vector2(-depth, 0), o0 + Vector2(-depth, 0)]), tone)
		c.draw_arc(at + Vector2(-depth * 0.5, 0), r + w * 0.5, PI * 0.5, PI * 1.5, 24, Color(0, 0, 0, 0), 1.0)
	c.draw_set_transform(at, 0, Vector2(sx, 1))
	_wheel_face(c, r, a, spokes, col)
	c.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

func _wheel_face(c: CanvasItem, r: float, a: float, spokes: int, col: Color) -> void:
	var at := Vector2.ZERO
	var ink := Color(0.035, 0.027, 0.02)
	var iron := Color(0.1, 0.095, 0.09).lerp(col, 0.25)
	var lit := Color(0.6, 0.55, 0.5, 0.4)
	var rust := Color(0.32, 0.18, 0.1, 0.4)
	var w := r * 0.19
	# spokes first, under the rim: tapered, inked, a lit edge
	for i in spokes:
		var d := Vector2.from_angle(a + TAU * i / spokes)
		var n := d.orthogonal()
		var p0 := at + d * r * 0.16
		var p1 := at + d * (r - w * 0.4)
		var w0 := maxf(2.5, r * 0.075)
		var w1 := maxf(1.6, r * 0.04)
		c.draw_colored_polygon(PackedVector2Array([p0 - n * (w0 + 1.8), p1 - n * (w1 + 1.8), p1 + n * (w1 + 1.8), p0 + n * (w0 + 1.8)]), ink)
		var sf := absf(n.dot(Vector2(-0.6, -0.8)))
		c.draw_colored_polygon(PackedVector2Array([p0 - n * w0, p1 - n * w1, p1 + n * w1, p0 + n * w0]), iron.lerp(Color(0.3, 0.28, 0.26), 0.35 * sf))
		var side := -1.0 if n.dot(Vector2(-0.6, -0.8)) < 0.0 else 1.0
		c.draw_line(p0 + n * w0 * 0.55 * side, p1 + n * w1 * 0.55 * side, Color(lit, 0.75), maxf(1.2, w1 * 0.7))
		if i % 3 == 1:
			c.draw_line(p0.lerp(p1, 0.35), p0.lerp(p1, 0.7), Color(rust, 0.45), w1 * 1.4)
	# the rim: ink, iron, rust in patches (turning with it), the groove, the light from above left, the shade below right
	c.draw_arc(at, r, 0, TAU, 48, ink, w + 4.0)
	# the rim modelled round: each piece of it as bright as it faces the light (upper left), the outer tyre and the
	# inner felloe in two tones
	var ld := Vector2(-0.6, -0.8)
	for j in 40:
		var a0 := TAU * j / 40.0
		var f := Vector2.from_angle(a0 + TAU / 80.0).dot(ld)
		var tone := iron.lerp(Color(0.36, 0.33, 0.3), clampf(f, 0.0, 1.0) * 0.6).darkened(clampf(-f, 0.0, 1.0) * 0.45)
		c.draw_arc(at, r + w * 0.22, a0, a0 + TAU / 40.0 + 0.01, 3, tone, w * 0.56)
		c.draw_arc(at, r - w * 0.28, a0, a0 + TAU / 40.0 + 0.01, 3, tone.darkened(0.3), w * 0.44)
	for j in 7:
		var a0 := a + j * 0.9 + 0.37 * sin(j * 5.3)
		c.draw_arc(at, r + w * (0.18 * sin(j * 2.7)), a0, a0 + 0.22 + 0.18 * absf(sin(j * 1.9)), 6, rust, w * (0.35 + 0.25 * absf(cos(j * 3.1))))
	c.draw_arc(at, r - w * 0.05, 0, TAU, 48, Color(0.05, 0.04, 0.035, 0.85), maxf(1.2, w * 0.18))
	c.draw_arc(at, r + w * 0.32, -PI * 0.95, -PI * 0.42, 14, lit, maxf(1.5, w * 0.22))
	c.draw_arc(at, r - w * 0.32, -PI * 0.9, -PI * 0.55, 10, Color(lit, 0.3), maxf(1.0, w * 0.12))
	c.draw_arc(at, r, PI * 0.05, PI * 0.55, 14, Color(0.0, 0.0, 0.0, 0.35), w * 0.9)
	# the hub: a thick boss (a dark ring, a rounded middle lit from above left), the axle's end cap, bolts turning round it
	c.draw_circle(at, r * 0.24 + 2.0, ink)
	c.draw_circle(at, r * 0.24, iron)
	c.draw_circle(at, r * 0.17 + 1.5, ink)
	c.draw_circle(at, r * 0.17, iron.lerp(Color(0.3, 0.28, 0.26), 0.45))
	c.draw_arc(at, r * 0.12, -PI * 0.95, -PI * 0.45, 10, lit, maxf(1.5, r * 0.03))
	c.draw_arc(at, r * 0.21, -PI * 0.9, -PI * 0.5, 10, Color(lit, 0.25), 1.5)
	for i in 6:
		var bp := at + Vector2.from_angle(a + TAU * i / 6.0 + 0.3) * r * 0.205
		c.draw_circle(bp, maxf(1.0, r * 0.022), Color(0.42, 0.38, 0.34, 0.85))
	c.draw_circle(at, r * 0.07, iron.darkened(0.3))
	c.draw_circle(at + Vector2(-r * 0.02, -r * 0.02), r * 0.03, Color(0.45, 0.42, 0.38, 0.7))

## the chapel of Saint Barbara: candles in its door; every 37 s its little bell strikes twice
const CHAPEL_CYCLE := 37.0
func _chapel(c: CanvasItem) -> void:
	var ch: Dictionary = J.chapel
	var dp: Array = ch.door
	_light(c, Vector2(float(dp[0]), float(dp[1])), 70, Color(1.0, 0.7, 0.35, 0.35 * _flick(50)))
	var bp := Vector2(float(ch.bell[0]), float(ch.bell[1]))
	var v := fmod(t + 9.0, CHAPEL_CYCLE)
	for k in 2:
		var r := v - k * 1.4
		if r >= 0.0 and r < 1.6:
			var q := r / 1.6
			c.draw_arc(bp, 10.0 + q * 70.0, 0, TAU, 40, Color(1.0, 0.88, 0.6, 0.3 * (1.0 - q)), 2.0)
		if _passed("bell%d" % k, v, CHAPEL_CYCLE, k * 1.4):
			FireSounds.bell(self, _far(bp.y))

## the storyteller's painted panel: it turns to the next picture of the story every 14 s (a quick cross-fade)
func _panel(c: CanvasItem) -> void:
	var pn: Dictionary = J.panel
	if int(pn.n) < 2:
		return
	var at := Vector2(float(pn.at[0]), float(pn.at[1]))
	var q := clampf((t - _panel_at) / 0.7, 0.0, 1.0)
	var prev := (_panel_i + int(pn.n) - 1) % int(pn.n)
	if q < 1.0:
		_put(c, "panel_%d.png" % prev, at)
		_put(c, "panel_%d.png" % _panel_i, at, false, q)
	elif _panel_i != 0:
		_put(c, "panel_%d.png" % _panel_i, at)
	if _panel_i == 0 and q < 1.0:
		# back to the giant at his forge: his fire flares on the panel with the blow
		var fp: Array = pn.fire
		_light(c, Vector2(float(fp[0]), float(fp[1])), 70, Color(1.0, 0.55, 0.2, 0.5 * (1.0 - q)))

## the end of the section's acid stream: a wet glistening seep down the rock to the gallery's roof beam (a glint runs down
## it), a drop swelling under the beam, falling, a splash and rings on a little puddle on the floor
const DRIP_GROW := 1.3
const DRIP_G := 1500.0
func _drip(c: CanvasItem, y: float) -> void:
	var dp: Dictionary = J.drip
	var x := float(dp.x)
	var sp: Array = dp.seep
	var beam := y + float(dp.beam)
	var fl := y + float(dp.floor)
	var wet := Color(0.6, 0.74, 0.68)
	var ink := Color(0.06, 0.08, 0.06, 0.8)
	var pts := PackedVector2Array()
	for i in 9:
		var q := i / 8.0
		pts.append(Vector2(x + 4.0 * sin(q * 7.0 + 1.0) - 3.0 * q, y + lerpf(float(sp[0]), float(sp[1]), q)))
	c.draw_polyline(pts, ink, 8.0)
	c.draw_polyline(pts, Color(wet, 0.8), 5.0)
	var fall := sqrt(2.0 * (fl - beam) / DRIP_G)
	var period := DRIP_GROW + fall + 0.9
	var u := fmod(t, period)
	# the glint running down the seep just before each drop
	var gq := clampf(u / (DRIP_GROW * 0.8), 0.0, 1.0)
	var gi := mini(int(gq * 8.0), 7)
	var gp := pts[gi].lerp(pts[gi + 1], gq * 8.0 - gi)
	_light(c, gp, 22.0, Color(0.85, 0.95, 0.9, 0.45 * (1.0 - gq)))
	c.draw_circle(gp, 3.0, Color(0.95, 1.0, 0.97, 0.9 * (1.0 - gq)))
	var bx := x - 3.0
	var puddle := Vector2(bx, fl)
	c.draw_set_transform(puddle, 0, Vector2(1.0, 0.3))
	c.draw_circle(Vector2.ZERO, 34.0, Color(0.06, 0.1, 0.08, 0.45))
	c.draw_circle(Vector2.ZERO, 30.0, Color(0.36, 0.47, 0.43, 0.55))
	c.draw_arc(Vector2.ZERO, 26.0, -PI * 0.9, -PI * 0.3, 10, Color(0.85, 1.0, 0.92, 0.6), 3.0)
	c.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	if u < DRIP_GROW:
		# swelling under the beam, a teardrop hanging
		var r := 2.0 + 6.0 * u / DRIP_GROW
		var hang := Vector2(bx, beam + r * 0.9)
		var tri := PackedVector2Array([Vector2(bx - r * 0.6, hang.y - r * 0.3), Vector2(bx, beam - 2.0), Vector2(bx + r * 0.6, hang.y - r * 0.3)])
		c.draw_circle(hang, r + 2.0, ink)
		c.draw_colored_polygon(tri, wet)
		c.draw_circle(hang, r, wet)
		c.draw_circle(hang + Vector2(-r * 0.35, -r * 0.35), r * 0.32, Color(1, 1, 1, 0.9))
		return
	var f := u - DRIP_GROW
	if f < fall:
		var p := Vector2(bx, beam + 7.0 + 0.5 * DRIP_G * f * f)
		var v := DRIP_G * f
		c.draw_line(p - Vector2(0, minf(v * 0.03, 26.0)), p, Color(wet, 0.5), 4.0)
		c.draw_circle(p, 7.5, ink)
		c.draw_circle(p, 6.0, wet)
		c.draw_circle(p + Vector2(-2.0, -2.0), 2.0, Color(1, 1, 1, 0.9))
		return
	# the splash: little drops jump out, rings run out over the puddle
	var s := (f - fall) / 0.9
	for j in 3:
		var dir := float(j - 1) * 1.3
		var e := s * 0.9
		var sp_ := puddle + Vector2(dir * 38.0 * e, -110.0 * e + 300.0 * e * e)
		if e < 0.45:
			c.draw_circle(sp_, 3.2, Color(wet, 0.95 * (1.0 - e * 2.2)))
	c.draw_set_transform(puddle, 0, Vector2(1.0, 0.3))
	for j in 2:
		var q := s - j * 0.3
		if q > 0.0 and q < 1.0:
			c.draw_arc(Vector2.ZERO, 6.0 + 34.0 * q, 0, TAU, 28, Color(0.9, 1.0, 0.95, 0.75 * (1.0 - q)), 3.0)
	c.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

## a kestrel hanging in the hot wind over the gorge, wings beating, drifting slowly
func _kestrel(c: CanvasItem) -> void:
	if not _crew_ok("kestrel"):
		return
	var ks: Array = J.kestrel
	var u := t / 47.0
	var p := Vector2(float(ks[0]) + 140.0 * sin(u * TAU), float(ks[1]) + 30.0 * sin(u * TAU * 2.3) + 6.0 * sin(t * 1.7))
	var fr := "kestrel/%02d.png" % (int(t * 14.0) % int(J.crew_n.kestrel))
	# it turns round slowly at each end of its drift: narrows side-on, banks, and opens the other way
	var sx := -clampf(cos(u * TAU) * 3.0, -1.0, 1.0)
	if absf(sx) < 0.12:
		sx = 0.12 * (1.0 if sx >= 0.0 else -1.0)
	var sz := _size(fr)
	c.draw_set_transform(p, 0.25 * sin(u * TAU) * (1.0 - absf(sx)), Vector2(sx, 1.0))
	c.draw_texture_rect(tex(fr), Rect2(-sz / 2, sz), false)
	c.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

## a level's life: the cracks glow and flare with each blow, the crew works, the forge of 300 m, the hot wall of
## 250 m steaming, the river of molten sulphur at 400 m running and burning blue
func _band_live(c: CanvasItem, b: Dictionary) -> void:
	var k := int(b.k)
	var y := float(b.y)
	var st := String(_shown_bands.get(k, b.state))
	if st == "closed":
		return
	var d := int(b.d)
	var floor_y := y + floor_of(d)
	var deep := 0.35 + 0.65 * k / 8.0
	var bt := _beat(t - _blow_at - k * 0.04) * _blow_k
	if J.has("drip") and d == int(J.drip.d):
		_drip(c, y)
	# the whole gallery breathes with the blow: a warm wash over it, stronger deeper down
	if bt > 0.02:
		_light(c, Vector2(980, y + 280), 620, Color(1.0, 0.45, 0.12, 0.13 * bt * deep))
	for cr_ in J.cracks.get(str(d), []):
		_crack(c, cr_ as Array, y, deep, bt)
	# dust shaken from the roof by the blow
	var s := t - _blow_at - k * 0.04
	if s > 0.0 and s < 1.6 and J.has("roofs"):
		var rf: Array = J.roofs.get(str(d), [500, 1400, 260])
		var rng := RandomNumberGenerator.new()
		rng.seed = _blow_n * 31 + k
		for j in int(16 * deep * _blow_k + 4):
			var x := rng.randf_range(float(rf[0]), float(rf[1]))
			var dl := rng.randf_range(0.0, 0.4)
			var q := s - dl
			if q < 0.0: continue
			var p := Vector2(x + rng.randf_range(-6, 6), y + float(rf[2]) + 420.0 * q * q)
			if p.y > floor_y: continue
			var al := 0.85 * clampf(1.0 - q / 1.2, 0.0, 1.0)
			# a grain falling and a thin trail of dust behind it
			c.draw_line(p, p - Vector2(0, 26.0 * minf(q * 4.0, 1.0)), Color(0.8, 0.7, 0.5, al * 0.45), 3.0)
			c.draw_circle(p, rng.randf_range(2.6, 4.6), Color(0.82, 0.72, 0.5, al))
	if J.has("forge") and str(d) == str(int(J.forge.d)) and st != "closed":
		var fp: Array = J.forge.at
		_light(c, Vector2(float(fp[0]), y + float(fp[1])), 70, Color(1.0, 0.45, 0.12, 0.45 * _flick(120) + 0.3 * bt))
	if J.has("steam") and str(d) == str(int(J.steam.d)):
		var sp: Array = J.steam.at
		var ps := _size("puff.png")
		for j in 6:
			var u := fmod(t * 0.22 + j / 6.0, 1.0)
			var p := Vector2(float(sp[0]) + sin(j * 2.3 + t * 0.4) * 22.0 + u * 30.0, y + float(sp[1]) - u * 180.0)
			var sc := 0.4 + 1.2 * u
			c.draw_texture_rect(tex("puff.png"), Rect2(p - ps * sc / 2, ps * sc), false, Color(0.95, 0.92, 0.88, 0.22 * sin(PI * u)))
	if J.has("river") and str(d) == str(int(J.river.d)):
		_river(c, y, bt)
	if not b.lived:
		return
	var al := 1.0
	if _appear.has(k):
		al = clampf((t - float(_appear[k])) / 1.2, 0.0, 1.0)
		if al >= 1.0: _appear.erase(k)
		if al <= 0.0: return
	var cr: Dictionary = J.crews[str(d)]
	var w: Array = cr.work
	var who := String(w[0])
	if not _crew_ok(who):
		return
	var x := float(w[1])
	var flip := bool(cr.get("flip", false))
	var fi := _crew_frame(cr, k)
	var p := "%s/%02d.png" % [who, fi]
	var rx := _reaction_frame(who, k)
	if rx != "":
		p = rx
	var sz := _size(p)
	_put(c, p, Vector2(x - sz.x / 2, floor_y - sz.y + 4 + float(cr.get("dy", 0.0))), flip, al)
	if cr.has("lamp"):
		var lp: Array = cr.lamp
		_light(c, Vector2(x + float(lp[0]) * (-1.0 if flip else 1.0), floor_y + float(lp[1])), 60, Color(1.0, 0.75, 0.4, 0.45 * al * _flick(k)))
	# the smith's sparks off the anvil on his blows
	if cr.has("sparks") and rx == "" and _passed("anvil%d" % k, _crew_v(k, t), _loop(cr), _hit_at(cr)):
		var sk: Array = cr.sparks
		var at := Vector2(x + float(sk[0]) * (-1.0 if flip else 1.0), floor_y + float(sk[1]))
		_spray(at, Vector2(-1.0 if flip else 1.0, -0.6), 14, 240.0, 0.7, 2.6)

## a glowing crack in a gallery's wall: a faint ember line, flaring up the length of it with the blow from below
func _crack(c: CanvasItem, cr: Array, y: float, deep: float, bt: float) -> void:
	var pts := PackedVector2Array()
	for p_ in cr:
		var p: Array = p_
		pts.append(Vector2(float(p[0]), y + float(p[1])))
	if pts.size() < 2:
		return
	var base := 0.14 + 0.06 * sin(t * 1.3 + pts[0].x * 0.01)
	var f := clampf(base + bt * (0.55 + 0.75 * deep), 0.0, 1.6)
	for i in pts.size():
		var p := pts[i]
		_light(c, p, 34.0 + 70.0 * f, Color(1.0, 0.42, 0.1, 0.3 * f))
		if i > 0:
			_light(c, p.lerp(pts[i - 1], 0.5), 30.0 + 50.0 * f, Color(1.0, 0.5, 0.15, 0.25 * f))
	c.draw_polyline(pts, Color(1.0, 0.42, 0.1, minf(0.75 * f, 0.9)), 7.0)
	c.draw_polyline(pts, Color(1.0, 0.88, 0.5, 0.9 * clampf(f - 0.3, 0.0, 1.0)), 3.0)

## the river of molten sulphur: bright streaks running along its channel, blue flames dancing on it
func _river(c: CanvasItem, y: float, bt: float) -> void:
	var rv: Dictionary = J.river
	var line: Array = rv.line
	var n := line.size()
	for j in 26:
		var u := fmod(t * 0.07 + j / 26.0, 1.0)
		var fi := u * (n - 1)
		var i0 := mini(int(fi), n - 2)
		var a: Array = line[i0]
		var b2: Array = line[i0 + 1]
		var p := Vector2(float(a[0]), float(a[1])).lerp(Vector2(float(b2[0]), float(b2[1])), fi - i0) + Vector2(0, y + sin(j * 2.7) * 14.0)
		var l := 26.0 + 14.0 * sin(j * 1.9)
		c.draw_line(p, p + Vector2(l, 1.5), Color(1.0, 0.75, 0.3, 0.45 * sin(PI * u)), 3.0)
	for f_ in rv.flames:
		var f: Array = f_
		_blue_flame(c, Vector2(float(f[0]), y + float(f[1])), 0.8 + 0.3 * bt, int(f[0]))
	var gl: Array = rv.glow
	_light(c, Vector2(float(gl[0]), y + float(gl[1])), float(gl[2]), Color(1.0, 0.45, 0.1, 0.18 + 0.25 * bt))

# ---------------------------------------------------------------- the carusi on the stair

const CLIMB_V := 34.0            # source px a second along the stair: a slow heavy climb
const CARUSI := 7

## the path of the stair, from the deepest open landing up the flights and through the section to the gate
var _path := PackedVector2Array()
var _path_open := -1
var _path_len := 0.0
func _stair_path() -> PackedVector2Array:
	if _path_open == open and not _path.is_empty():
		return _path
	_path_open = open
	var sw: Dictionary = J.stair
	var pts := PackedVector2Array()
	var dr: Array = sw.door
	pts.append(Vector2(float(dr[0]), band_y(open) + float(dr[1])))
	for k in range(open, -1, -1):
		var y := band_y(k)
		for p_ in sw.path:
			var p: Array = p_
			var q := Vector2(float(p[0]), y + float(p[1]))
			if pts.is_empty() or pts[pts.size() - 1].distance_to(q) > 1.0:
				pts.append(q)
	for p_ in sw.entry:
		var p: Array = p_
		pts.append(Vector2(float(p[0]), float(p[1])))
	_path = pts
	_path_len = 0.0
	for i in range(1, pts.size()):
		_path_len += pts[i].distance_to(pts[i - 1])
	return _path

## the boys climb with their sacks from the deepest landing to the gate, one behind another; once the steam winder
## hoists the ore they are gone from the stair (two of them sit on the anvil boulder with a slate and a doll)
func _carusi(c: CanvasItem) -> void:
	if int(_shown_places.get("winder", 0)) >= 3 or not _crew_ok("climb_a") or not J.has("stair"):
		return
	var pts := _stair_path()
	if pts.size() < 2 or _path_len < 10.0:
		return
	var stride := float(J.stair.stride)
	for i in CARUSI:
		var s := fmod(t * CLIMB_V + i * _path_len / CARUSI + 200.0, _path_len)
		var at := _along(pts, s)
		var ahead := _along(pts, minf(s + 12.0, _path_len))
		if at.y + 200.0 < _seen.x or at.y - 300.0 > _seen.y:
			continue
		var al := clampf(s / 60.0, 0.0, 1.0) * clampf((_path_len - s) / 80.0, 0.0, 1.0)
		var nm := "climb_a" if i % 2 == 0 else "climb_b"
		var fr := "%s/%02d.png" % [nm, int(s / stride * 12.0) % int(J.crew_n[nm])]
		var sz := _size(fr)
		_put(c, fr, Vector2(at.x - sz.x / 2, at.y - sz.y + 6), ahead.x < at.x, al)

func _along(pts: PackedVector2Array, s: float) -> Vector2:
	var left := s
	for i in range(1, pts.size()):
		var l := pts[i].distance_to(pts[i - 1])
		if left <= l:
			return pts[i - 1].lerp(pts[i], left / maxf(l, 0.001))
		left -= l
	return pts[pts.size() - 1]

# ---------------------------------------------------------------- the Cyclops about the place

func _tick_events() -> void:
	if force_event != "" and t > 0.5:
		_start_event(force_event)
		force_event = ""
	if t < _next_event:
		return
	_next_event = t + _rng.randf_range(10.0, 16.0)
	var pool := ["etna"]
	for sp in J.get("spark_cracks", []):
		if int(sp.d) - 1 <= open and String(_shown_bands.get(int(sp.d) - 1, "closed")) != "closed":
			pool.append("sparks")
			break
	if J.has("vent") and int(J.vent.d) - 1 <= open:
		pool.append("vent")
	if J.has("gaps") and 6 <= open:
		pool.append("shadow")
	if J.has("herald") and int(J.herald.d) - 1 <= open:
		pool.append("herald")     # the herald of the next mine, the frozen one: nobody here knows what it means
	_start_event(pool[_rng.randi() % pool.size()])

func _start_event(ev: String) -> void:
	_events[ev] = t
	match ev:
		"etna":
			_etna_sparks(1.3)
			FireSounds.rumble(self, _far(float(J.etna[1])))
		"sparks":
			var cand: Array = []
			for sp in J.get("spark_cracks", []):
				if int(sp.d) - 1 <= open and String(_shown_bands.get(int(sp.d) - 1, "closed")) != "closed":
					cand.append(sp)
			if cand.is_empty():
				_events.erase(ev)
				return
			_events.erase("sparks_at")     # chosen when first drawn: by then the screen has scrolled to where it shows
		"herald":
			_frost_at = t
			FireSounds.wind(self, _far(band_y(int(J.herald.d) - 1) + 300))
		"shadow":
			FireSounds.rumble(self, _far(band_y(6) + 300) - 4.0)
		"vent":
			FireSounds.steam(self, _far(band_y(int(J.vent.d) - 1) + 300))

## a crack to spray sparks from: an open level's, the one on the screen if there is one (off it they would fly unseen)
func _spark_crack() -> Dictionary:
	var cand: Array = []
	for sp in J.get("spark_cracks", []):
		if int(sp.d) - 1 <= open and String(_shown_bands.get(int(sp.d) - 1, "closed")) != "closed":
			cand.append(sp)
	if cand.is_empty():
		return {}
	var pick: Dictionary = cand[_rng.randi() % cand.size()]
	var mid := lerpf(_seen.x, _seen.y, 0.4)          # the middle of what is seen over the Play row
	var best := 1e9
	for c_ in cand:
		var y := band_y(int(c_.d) - 1) + float(c_.at[1])
		if y > _seen.x and y < _seen.y and absf(y - mid) < best:
			best = absf(y - mid)
			pick = c_
	return pick

const SHADOW_LEN := 6.0
const HERALD_LEN := 7.0
func _events_live(c: CanvasItem) -> void:
	for ev in _events.keys():
		if ev == "sparks_at":
			continue
		var s := t - float(_events[ev])
		var done := false
		match ev:
			"etna":
				if s > 4.0: done = true
			"sparks":
				# sparks spray out of a crack as off a grindstone, in bursts, with a crackle
				if not _events.has("sparks_at"):
					_events["sparks_at"] = _spark_crack()
				var sp: Dictionary = _events.get("sparks_at", {})
				if sp.is_empty() or s > 2.4: done = true
				else:
					var at := Vector2(float(sp.at[0]), band_y(int(sp.d) - 1) + float(sp.at[1]))
					var dr := Vector2(float(sp.dir[0]), float(sp.dir[1]))
					if _passed("spk", s + 0.4, 0.45):
						_spray(at, dr, 34, 380.0, 1.2, 4.5)
						FireSounds.sparks(self, _far(at.y))
					var fl := (1.0 - s / 2.4) * (0.75 + 0.25 * sin(s * 40.0))
					_light(c, at, 110, Color(1.0, 0.6, 0.2, 0.7 * fl))
					_light(c, at, 40, Color(1.0, 0.95, 0.7, 0.9 * fl))
			"vent":
				# a jet of hot steam out of the hot wall
				var vt: Dictionary = J.vent
				if s > 3.0: done = true
				else:
					var at := Vector2(float(vt.at[0]), band_y(int(vt.d) - 1) + float(vt.at[1]))
					var ps := _size("puff.png")
					for j in 12:
						var u := fmod(s * 1.4 + j / 12.0, 1.0)
						if s * 1.4 < j / 12.0: continue
						var p := at + Vector2(float(vt.dir[0]), float(vt.dir[1])) * u * 260.0 + Vector2(sin(j * 3.1) * 14.0 * u, -u * u * 60.0)
						var sc := 0.25 + u * 1.3
						c.draw_texture_rect(tex("puff.png"), Rect2(p - ps * sc / 2, ps * sc), false, Color(1, 0.97, 0.92, 0.5 * (1.0 - u) * clampf((3.0 - s) / 0.8, 0.0, 1.0)))
			"shadow":
				# something huge moves past behind the wall of giant blocks: its glow slides along the gaps from right to
				# left, as if a forge were carried by
				if s > SHADOW_LEN: done = true
				else:
					var cx := lerpf(1600.0, 300.0, s / SHADOW_LEN)
					var y := band_y(6)
					for g_ in J.gaps:
						var g: Array = g_
						var f := exp(-pow((float(g[0]) - cx) / 230.0, 2.0)) * sin(PI * s / SHADOW_LEN)
						if f < 0.02: continue
						var a := Vector2(float(g[0]), y + float(g[1]))
						var b := Vector2(float(g[2]), y + float(g[3]))
						for q in 4:
							_light(c, a.lerp(b, (q + 0.5) / 4.0), 60.0 + 70.0 * f, Color(1.0, 0.45, 0.12, 0.4 * f))
						c.draw_line(a, b, Color(1.0, 0.5, 0.15, 0.9 * f), 8.0)
						c.draw_line(a, b, Color(1.0, 0.9, 0.55, 0.9 * f), 3.0)
			"herald":
				if s > HERALD_LEN: done = true
				else: _herald(c, s)
		if done:
			_events.erase(ev)

## the herald of the next mine (the snow one): at 300 m a cold draught comes out of nowhere - pale streaks of mist
## drift through the gallery, the lamp gutters and goes out, frost grows white over the water trough and its water
## freezes, then the lamp catches again and the frost melts away
func _herald(c: CanvasItem, s: float) -> void:
	var hd: Dictionary = J.herald
	var y := band_y(int(hd.d) - 1)
	var u := s / HERALD_LEN
	var wv := sin(PI * clampf(u * 1.3, 0.0, 1.0))
	for j in 9:
		var q := fmod(s * 0.35 + j / 9.0, 1.0)
		var p := Vector2(1500.0 - q * 1100.0, y + 260.0 + sin(j * 2.1) * 90.0 + sin(s * 2.0 + j) * 10.0)
		c.draw_line(p, p + Vector2(150.0, 4.0 * sin(j)), Color(0.8, 0.9, 1.0, 0.18 * wv * sin(PI * q)), 5.0)
	var tr: Array = hd.trough
	var at := Vector2(float(tr[0]), y + float(tr[1]))
	var w := float(tr[2])
	var fr := clampf(u * 2.2, 0.0, 1.0) * clampf((1.0 - u) * 4.0, 0.0, 1.0)
	if fr > 0.0:
		c.draw_rect(Rect2(at.x - w / 2, at.y - 4, w, 8), Color(0.85, 0.93, 1.0, 0.55 * fr))
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for j in 22:
			var x := at.x + rng.randf_range(-w / 2, w / 2)
			var l := rng.randf_range(8.0, 26.0) * fr
			var a := -PI / 2 + rng.randf_range(-1.0, 1.0)
			var p0 := Vector2(x, at.y - 2)
			var p1 := p0 + Vector2.from_angle(a) * l
			c.draw_line(p0, p1, Color(0.92, 0.97, 1.0, 0.8 * fr), 2.0)
			c.draw_line(p0.lerp(p1, 0.5), p0.lerp(p1, 0.5) + Vector2.from_angle(a + 0.7) * l * 0.35, Color(0.92, 0.97, 1.0, 0.6 * fr), 1.4)
		_light(c, at, 60, Color(0.6, 0.8, 1.0, 0.25 * fr))
	# a breath of cold made visible over the frost
	_light(c, Vector2(900, y + 300), 300, Color(0.55, 0.7, 1.0, 0.08 * wv))

## the lamp of the herald's level: it gutters and goes out with the cold draught, and catches again
func _herald_lamp(j: int) -> float:
	var s := t - _frost_at
	if s < 0.0 or s > HERALD_LEN or j != int(J.herald.get("lamp", 0)):
		return 1.0
	if s < 1.0: return 1.0 - 0.5 * s + 0.3 * sin(s * 40.0) * s
	if s < 4.6: return 0.0
	return clampf((s - 4.6) / 0.8, 0.0, 1.0) * (0.8 + 0.2 * sin(s * 30.0))

func _sparks_live(c: CanvasItem) -> void:
	for f in _flying:
		var age := t - float(f[2])
		if age < 0.0:
			continue
		var q := age / float(f[3])
		var p: Vector2 = f[0]
		var v: Vector2 = f[1]
		var col := Color(1.0, 0.85 - 0.4 * q, 0.45 - 0.3 * q, 1.0 - q)
		c.draw_line(p, p - v * 0.045, Color(1.0, 0.5, 0.15, col.a * 0.7), float(f[4]) + 3.0)
		c.draw_line(p, p - v * 0.03, col, float(f[4]))
		_light(c, p, float(f[4]) * 5.0, Color(1.0, 0.6, 0.2, 0.5 * (1.0 - q)))

## flags on the finished places once Brontes is beaten (the same wind-bent pennant as the other mines; poles in mine.json)
func _fire_flags(c: CanvasItem) -> void:
	if not ResourceLoader.exists(dir + "flag_strip.png") or not J.has("flags"): return
	if area >= Save.d.boss_won.size() or not bool(Save.d.boss_won[area]): return
	var tx := tex("flag_strip.png")
	var i := 0
	for fl: Dictionary in J.flags:
		i += 1
		if int(_shown_places.get(String(fl.place), 0)) < 3: continue
		var pole: Array = fl.pole       # foot x, foot y, top y (stack px)
		var foot := Vector2(float(pole[0]), float(pole[1]))
		var top := Vector2(foot.x, float(pole[2]))
		c.draw_line(foot, top, Color(0.09, 0.07, 0.05), 4.0)
		c.draw_line(foot + Vector2(-0.6, 0), top + Vector2(-0.6, 0), Color(0.42, 0.33, 0.22), 1.6)
		c.draw_circle(top, 3.2, Color(0.55, 0.43, 0.22))
		var ln: float = fl.len
		var fly: float = fl.fly
		var hw := ln * float(tx.get_height()) / float(tx.get_width()) * 0.5
		var ph := t + i * 3.7
		var wind := clampf(0.55 + 0.25 * sin(ph * 0.27) + 0.18 * sin(ph * 0.71 + 1.0), 0.15, 1.0)
		var sag := (1.0 - wind) * 0.9
		var fold := func(q: float) -> float: return q * 7.0 - ph * (4.5 + 4.0 * wind)
		var pts := Bend.chain(top + Vector2(0, hw + 2.0), ln * (0.9 + 0.1 * wind), 24, func(q: float) -> float:
			var a := (0.18 + 0.32 * wind) * q * sin(fold.call(q)) + 0.06 * sin(ph * 1.7) * q + sag * q
			return a if fly > 0.0 else PI - a)
		Bend.draw(c, pts, func(q: float) -> float: return hw * (1.0 - 0.1 * q * absf(cos(fold.call(q)))), tx, 0.0, 1.0, fly < 0.0,
			func(q: float) -> Color: var v := 0.82 + 0.2 * q * sin(fold.call(q) + 1.2); return Color(v, v, v))

## after a win the level's ore flies down into the depth it came from: lumps of yellow sulphur crystal and grey iron ore
func _ore_flight(c: CanvasItem) -> void:
	if _react.is_empty():
		return
	var s := t - float(_react.t0)
	if s > 4.0 and t > float(_react.get("ts", 0.0)) + REACT_LEN:
		if _react.has("ts"):
			_held[int(_react.k)] = float(_held.get(int(_react.k), 0.0)) + REACT_LEN
		_react = {}
		return
	if not bool(_react.won):
		return
	var k := int(_react.k)
	var cr: Dictionary = J.crews.get(str(k + 1), {})
	var w: Array = cr.get("work", ["", 900, ""])
	var to := Vector2(float(w[1]) if w.size() > 1 else 900.0, band_y(k) + floor_of(k + 1) - 40)
	var from := Vector2(1240, -position.y / scale.y + 40)
	var n_ore := mini(int(_react.ore), 10)
	var n_iron := mini(int(_react.iron), 8)
	for i in n_ore + n_iron:
		var u := (s - 0.4 - i * 0.09) / 0.9
		if u < 0.0 or u > 1.4:
			continue
		var iron := i >= n_ore
		var tgt := to + Vector2((i % 5 - 2) * 34 + sin(i * 2.3) * 10, (i % 3) * 8)
		var glow := Color(0.75, 0.8, 0.9) if iron else Color(1.0, 0.9, 0.35)
		if u <= 1.0:
			var e := u * u * (3.0 - 2.0 * u)
			var p := from.lerp(tgt, e) + Vector2(sin(i * 1.7) * 160 * sin(PI * u), -220 * sin(PI * u))
			c.draw_circle(p, 22.0, Color(glow, 0.22))
			_lump(c, p, 30.0, iron, i, t * (3.0 + (i % 3)))
		else:
			var f := (u - 1.0) / 0.4
			_light(c, tgt, 60 + 70 * f, Color(glow, 0.6 * (1.0 - f)))
			_lump(c, tgt + Vector2(0, -8), 30.0 * (1.0 - smoothstep(0.5, 1.0, f)), iron, i, 0.0)
		if _passed("ore%d" % i, u, 1.0, 1.0):
			amb.shot("coin", -10.0, 1.2 + (i % 4) * 0.05)

## a lump of native sulphur (bright yellow, crystal faces, a resinous glint) or of grey iron ore
func _lump(c: CanvasItem, at: Vector2, r: float, iron: bool, seed_: int, spin: float) -> void:
	if r < 1.0:
		return
	var pts := PackedVector2Array()
	var rim := PackedVector2Array()
	for j in 6:
		var a := spin + TAU * j / 6.0
		var rr := r * (0.75 + 0.25 * absf(sin(seed_ * 3.1 + j * 1.9)))
		pts.append(at + Vector2.from_angle(a) * rr)
		rim.append(at + Vector2.from_angle(a) * (rr + 5.0))
	c.draw_colored_polygon(rim, Color(0.05, 0.03, 0.02))
	c.draw_colored_polygon(pts, Color(0.36, 0.35, 0.37) if iron else Color(0.93, 0.78, 0.18))
	if iron:
		c.draw_rect(Rect2(at + Vector2(0.0, -0.1) * r, Vector2(r, r) * 0.42), Color(0.18, 0.18, 0.21))
	else:
		c.draw_colored_polygon(PackedVector2Array([at, pts[0], pts[1]]), Color(1.0, 0.92, 0.45))
		c.draw_colored_polygon(PackedVector2Array([at, pts[3], pts[4]]), Color(0.72, 0.55, 0.1))
		c.draw_circle(at + Vector2(-0.3, -0.4) * r, r * 0.1, Color(1.0, 1.0, 0.85))

func _tremor() -> void:
	if String(_shown_bands.get(8, "")) == "done" and not bool(Save.d.boss_won[area]) and t > _next_tremor:
		_next_tremor = t + _rng.randf_range(18.0, 30.0)
		if t - _tremor_at > 5.0:
			_tremor_at = t
	var s := t - _tremor_at
	var amp := 0.0
	if s >= 0.0 and s < 1.6:
		amp = 6.0 * (1.0 - s / 1.6)
	# a heavy blow shakes the picture a little too
	if _blow_k > 1.2:
		amp = maxf(amp, 2.5 * _beat(t - _blow_at) * (1.0 if (t - _blow_at) < 0.5 else 0.0))
	position.x = sin(t * 47.0) * amp * scale.x
	if s >= 0.0 and s < 0.05 and not _cue.has("tremor%d" % int(_tremor_at)):
		_cue["tremor%d" % int(_tremor_at)] = true
		amb.shot("rockfall", -4.0, 0.55)
		FireSounds.ring(self, -2.0)

## the forge gate open: the forge behind it breathes with the hammer - its light swells on the floor with every blow,
## embers drift out between the bronze leaves, the eye of the relief glints
func _finale(c: CanvasItem) -> void:
	if String(_shown_bands.get(8, "")) != "done" or not J.has("hall"):
		return
	var y := band_y(8)
	var hl: Dictionary = J.hall
	var sh := clampf(1.0 - (t - _tremor_at) / 2.0, 0.0, 1.0)
	var bt := _beat(t - _blow_at) * _blow_k
	var g := 0.55 + 0.2 * sin(t * 1.1) + 0.6 * bt + 0.4 * sh
	var dr: Array = hl.door
	var at := Vector2(float(dr[0]), y + float(dr[1]))
	_light(c, at, 300.0 + 120.0 * bt, Color(1.0, 0.5, 0.15, 0.35 * g))
	_light(c, at, 120.0, Color(1.0, 0.85, 0.5, 0.45 * g))
	# the seam between the leaves blazes
	c.draw_line(at + Vector2(0, -170), at + Vector2(0, 200), Color(1.0, 0.8, 0.4, 0.55 * g), 10.0)
	c.draw_line(at + Vector2(0, -170), at + Vector2(0, 200), Color(1.0, 0.97, 0.8, 0.7 * g), 4.0)
	var fl: Array = hl.floor
	c.draw_set_transform(Vector2(float(fl[0]), y + float(fl[1])), 0.0, Vector2(1.0, 0.22))
	_light(c, Vector2.ZERO, float(fl[2]), Color(1.0, 0.55, 0.2, 0.45 * g))
	c.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	for i in 10:
		var u := fmod(t * 0.16 + i / 10.0, 1.0)
		var p := at + Vector2(sin(i * 2.3 + t * 0.4) * 60.0 + (i % 2 * 2 - 1) * u * 140.0, 60.0 - u * 260.0)
		_light(c, p, 9, Color(1.0, 0.7, 0.3, 0.7 * sin(PI * u)))
	if hl.has("eye"):
		var ey: Array = hl.eye
		var e := maxf(0.0, sin(t * 0.6)) ** 6 + sh + bt * 0.5
		_light(c, Vector2(float(ey[0]), y + float(ey[1])), 40, Color(1.0, 0.75, 0.3, 0.6 * minf(e, 1.0)))

# ---------------------------------------------------------------- crews and sounds

func _crew_v(k: int, at: float) -> float:
	var v := at * CREW_FPS + k * 7.0
	if _hold.has(k):
		v -= clampf(at - float(_hold[k]), 0.0, REACT_LEN) * CREW_FPS
	return v

func _crew_frame(cr: Dictionary, k: int) -> int:
	return _drawing_at(cr, _crew_v(k, t))

func _hit_at(cr: Dictionary) -> float:
	var p := _play(cr)
	var seq: Array = p.seq
	var at: Array = p.at
	return float(at[maxi(seq.find(int(cr.get("hit", 0))), 0)])

func _sounds(_dt: float) -> void:
	for b in _bands:
		if not b.lived or _appear.has(int(b.k)):
			continue
		var k := int(b.k)
		var cr: Dictionary = J.crews[str(int(b.d))]
		if not cr.has("hit"):
			continue
		if _passed("hit%d" % k, _crew_v(k, t), _loop(cr), _hit_at(cr)) and (k == sel or randf() < 0.15):
			FireSounds.strike(amb, String(cr.work[0]), _far(float(b.y) + floor_of(int(b.d))) - k * 1.2 + (0.0 if k == sel else -4.0), 0.95 - k * 0.02)
	FireSounds.of(self).tick(self)
