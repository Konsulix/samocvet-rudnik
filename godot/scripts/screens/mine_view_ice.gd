class_name IceView
extends MineView
## Proval (mine 5, the end of the first arc: the brother's): an abandoned Soviet coal settlement on Svalbard like
## Pyramiden in the polar night, drawn like Old Adit (MineView) but laid out its own way (docs/mine-design.md §9,
## docs/mine5-proval.md): there is no shaft - behind the settlement the ground fell in as a FUNNEL, and the funnel goes on
## down the middle of the screen through every depth as an open ABYSS; the galleries are cut into its walls, left and right
## in turn, each opening onto it at a timber landing. A gantry over the funnel lowers a kibble on its cable down the abyss
## to the landings. The life of the place is the BLIZZARD: every 9-13 s a gust sweeps snow over the settlement and down
## into the abyss, the kibble swings on its long cable, the lamps gutter; over it all the aurora drifts. Signs of the
## brother and of the four spirits whose shards he carries are frozen into the funnel's walls. Home makes it for area 4
## when its pictures exist (available_here) and talks to it as to MineView.
## Pictures and coordinates: assets/mine/proval/ + mine.json (art/zone/export_mine5.py), source px of the 1536-wide
## stack: the sky, the surface, the section under it, the depth bands.

const IDIR := "res://assets/mine/proval/"
## the surface's places in drawing order (their pictures meet at soft edges)
const IPLACES := ["searchlight", "barracks", "chute", "power", "palace", "gantry"]
## the depths whose job is built in the gallery itself: its stages are the band's pictures
const IBAND_JOBS := {7: "thaw", 8: "icestair", 9: "gate"}
const ISTAGES := ["clear", "step1", "step2", "done"]

var _ic_fx: Node2D          # snow and smoke (particles in the picture's own coordinates)
var _ic_smokes: Array = []  # [particles, the place it belongs to, the step from which it smokes]
var _ic_aurora: Sprite2D    # the aurora over the sky (aurora.gdshader, by the sky's mask)
var _ic_hold := {}          # depth -> when its crew's reaction began
var _gust_at := -100.0      # the last gust of the blizzard, and the next
var _next_gust := 3.0
var _gust_k := 1.0
var _kib_from := 0.0        # the kibble's trip: when it set off, to which depth
var _kib_to := 0
var _kib_y := 0.0           # where it hangs now (source px), and its swing
var _kib_sw := 0.0
var _kib_swv := 0.0
var _kib_up := false        # on its way up (heaped with coal)
var _flare_at := -100.0     # the watchman's flare
var _howl_prev := -1

const KIB_V := 260.0        # source px a second along the cable
const KIB_WAIT := 2.6       # at a landing, and at the top

func _init() -> void:
	dir = IDIR

## the polar night: the cave breathes under the wind (IceSounds' own loop)
func amb_beds() -> Array:
	return ["cave"]

func available_here() -> bool:
	return FileAccess.file_exists(IDIR + "mine.json")

func _ready() -> void:
	super()
	_ic_aurora = Sprite2D.new()
	_ic_aurora.centered = false
	var am := ShaderMaterial.new()
	am.shader = load("res://shaders/aurora.gdshader")
	_ic_aurora.material = am
	add_child(_ic_aurora)
	move_child(_ic_aurora, surf.get_index() + 1)
	_ic_fx = Node2D.new()
	add_child(_ic_fx)
	move_child(_ic_fx, live.get_index())

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
			if IBAND_JOBS.has(d):
				st = ISTAGES[clampi(int(steps.get(IBAND_JOBS[d], 0)), 0, 3)]
		var lived: bool = k <= open and k < wins.size() and int(wins[k]) >= 2 and J.crews.has(str(d))
		_bands.append({y = y0 + k * float(J.band), state = st, d = d, lived = lived, k = k})
	H = y0 + _bands.size() * float(J.band)
	if _set_area != a:
		_events = {}
		_next_event = 7.0
		_set_area = a
		_kib_from = t
		_kib_to = sel
	surf.texture = tex("surface.png")
	surf.scale = Vector2.ONE / K
	surf.material = null
	still.material = null
	if J.has("aurora"):
		var ar: Array = J.aurora
		_ic_aurora.texture = tex("aurora_mask.png")
		_ic_aurora.scale = Vector2(float(ar[2]), float(ar[3])) / _ic_aurora.texture.get_size()
		_ic_aurora.position = Vector2(float(ar[0]), float(ar[1]))
		(_ic_aurora.material as ShaderMaterial).set_shader_parameter("mask", _ic_aurora.texture)
	_changes()
	if not last_result.is_empty() and int(last_result.area) == a:
		var k := clampi(int(last_result.k), 0, _bands.size() - 1)
		var t0 := t + 0.7
		var v := _ic_crew_v(k, t0)
		var ln := _loop(J.crews.get(str(int(_bands[k].d)), {}))
		if ln > 0.0:
			t0 += (ceilf(v / ln) * ln - v) / CREW_FPS
		_ic_hold[k] = t0
		_react = {k = k, won = bool(last_result.won), t0 = t0, iron = int(last_result.iron), ore = int(last_result.ore)}
		if focus_y < 0: focus_y = band_y(k) + float(J.band) * 0.5
		last_result = {}
	_ic_setup_fx()
	_make_motes()
	_find_niches()
	still.queue_redraw()
	front.queue_redraw()

## what changed since the screen was last shown: new stages come in (ink, then colour), a newly opened level shows
## through a burst of snow and coal dust, the people of a level fade in after its second win
func _changes() -> void:
	var places := {}
	for p in IPLACES: places[p] = int(steps.get(p, 0))
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
	for p in IPLACES:
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
			delay = wait + 0.9
			get_tree().create_timer(wait).timeout.connect(func(): amb.shot("rockfall", 0.0, 0.7))
			var gx: Array = J.galleries.get(str(d), [200, 600])
			for j in 4:
				_bursts.append([Vector2(lerpf(float(gx[0]), float(gx[1]), (j + 0.5) / 4.0), y + 330), t + wait + 0.2 + 0.12 * j])
		_reveal("band/d%d_%s.png" % [d, now], Vector2(0, y), delay, func(): _shown_bands[k] = now, "band/d%d_%s.png" % [d, was])
		if d == 9 and now == "done":
			_tremor_at = t + delay + 2.2      # the gate stands open: the whole funnel shudders
	for k in lived:
		if lived[k] and not bool(last.lived.get(k, false)):
			_appear[k] = t + wait
			if focus_y < 0: focus_y = band_y(int(k)) + float(J.band) * 0.5

func job_pos(id: String) -> Vector2:
	if J.place_box.has(id):
		var bx: Array = J.place_box[id]
		return Vector2((float(bx[0]) + float(bx[2])) / 2, (float(bx[1]) + float(bx[3])) / 2)
	for d in IBAND_JOBS:
		if IBAND_JOBS[d] == id:
			return Vector2(800, band_y(int(d) - 1) + 300)
	return Vector2(768, float(J.sky) + 900)

# ---------------------------------------------------------------- the still pictures

func _draw_still() -> void:
	var c := still
	for p in IPLACES:
		var s := int(_shown_places.get(p, 0))
		if s > 0:
			var at: Array = J.places[p]
			var nm := "place/%s_%d.png" % [p, s]
			_put(c, nm, Vector2(float(at[0]), float(at[1])))
	_put(c, "cut.png", Vector2(0, _cut_top() - float(J.get("cut_over", 0))))
	for b in _bands:
		var st := String(_shown_bands.get(int(b.k), b.state))
		var bp := "band/d%d_%s.png" % [int(b.d), st]
		if ResourceLoader.exists(dir + bp):
			_put(c, bp, Vector2(0, float(b.y)))
	_draw_niches(c)
	# the seams between the bands: a dark line and the shade of the band above - but not across the abyss, which goes on
	var ab: Array = J.abyss
	for b in _bands:
		for seg in [[0.0, float(ab[0])], [float(ab[1]), float(J.W)]]:
			c.draw_texture_rect(_shade, Rect2(float(seg[0]), float(b.y), float(seg[1]) - float(seg[0]), 44), false)
			c.draw_rect(Rect2(float(seg[0]), float(b.y) - 3, float(seg[1]) - float(seg[0]), 6), Color(0.04, 0.05, 0.08))
	# the abyss as one: a soft dark column down its middle over every band, so the bands' own abysses read as one hole
	var top := _cut_top() + float(J.cut) * 0.4
	var cx := (float(ab[0]) + float(ab[1])) * 0.5
	var w := (float(ab[1]) - float(ab[0])) * 0.5
	c.draw_texture_rect(_glow, Rect2(cx - w, top, w * 2.0, H - top), false, Color(0.0, 0.01, 0.03, 0.35))
	# where two bands meet in the abyss their drawn air does not quite match: a drift of dark mist over each seam
	for b in _bands:
		c.draw_texture_rect(_glow, Rect2(float(ab[0]) - 20.0, float(b.y) - 50.0, w * 2.0 + 40.0, 100.0), false, Color(0.01, 0.02, 0.05, 0.45))
	_draw_bedrock(c)

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

func _ic_niche_at(k: int) -> Vector2:
	var nc: Array = J.niches[str(k + 1)]
	return Vector2(float(nc[0]), band_y(k) + float(nc[1]))

func niche_at(p: Vector2) -> Dictionary:
	for k in _niche_want:
		var key := Spec.key_of(Spec.of_stone(_niche_want[k]))
		if not _niche_tex.has(key):
			continue
		var at := _ic_niche_at(k)
		var sz := _niche_size(_niche_tex[key])
		if Rect2(at.x - sz.x / 2 - 30, at.y - sz.y - 30, sz.x + 60, sz.y + 50).has_point(p):
			return _niche_want[k]
	return {}

## the stones on their pedestals: a soft shadow, an ink outline, the stone cooled a little by the polar night
func _draw_niches(c: CanvasItem) -> void:
	for k in _niche_want:
		var key := Spec.key_of(Spec.of_stone(_niche_want[k]))
		if not _niche_tex.has(key) or String(_shown_bands.get(k, "")) == "closed":
			continue
		var tx: Texture2D = _niche_tex[key]
		var at := _ic_niche_at(k)
		var sz := _niche_size(tx)
		var pos := Vector2(at.x - sz.x / 2, at.y - sz.y + 8)
		c.draw_texture_rect(_glow, Rect2(Vector2(at.x - sz.x * 0.6, at.y - 10), Vector2(sz.x * 1.2, 22)), false, Color(0.02, 0.03, 0.06, 0.6))
		for dv in [Vector2(-3, 0), Vector2(3, 0), Vector2(0, -3), Vector2(0, 3), Vector2(-2, -2), Vector2(2, 2), Vector2(-2, 2), Vector2(2, -2)]:
			c.draw_texture_rect(tx, Rect2(pos + dv, sz), false, Color(0.03, 0.035, 0.06, 1.0))
		c.draw_texture_rect(tx, Rect2(pos, sz), false, Color(0.92, 0.94, 1.0))

# ---------------------------------------------------------------- snow and smoke (particles in the picture's coordinates)

func _ic_setup_fx() -> void:
	for ch in _ic_fx.get_children(): ch.queue_free()
	_ic_smokes = []
	for s in J.smoke:
		var spec: Dictionary = s     # at [x, y], size, kind: stove | chimney, place, from (the step it smokes from)
		var k := float(spec.size)
		var p := CPUParticles2D.new()
		p.texture = tex("puff.png")
		p.local_coords = true
		p.position = Vector2(float(spec.at[0]), float(spec.at[1]))
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		var sc := Curve.new()
		var g := Gradient.new()
		var big := String(spec.kind) == "chimney"
		p.amount = 20 if big else 12
		p.lifetime = 11.0 if big else 6.0
		p.preprocess = p.lifetime
		p.emission_sphere_radius = 8.0 * k
		p.direction = Vector2(0.25, -1)
		p.spread = 12
		p.gravity = Vector2(16, -2)        # the wind takes it off to the right
		p.initial_velocity_min = 18 * k
		p.initial_velocity_max = 30 * k
		p.scale_amount_min = 0.5 * k
		p.scale_amount_max = 0.8 * k
		sc.add_point(Vector2(0, 0.5))
		sc.add_point(Vector2(1, 4.0 if big else 3.0))
		g.set_color(0, Color(0.9, 0.8, 0.7, 0.0))
		g.add_point(0.08, Color(0.62, 0.64, 0.7, 0.7) if big else Color(0.75, 0.76, 0.8, 0.55))
		g.add_point(0.5, Color(0.4, 0.43, 0.5, 0.45))
		g.set_color(g.get_point_count() - 1, Color(0.3, 0.33, 0.4, 0.0))
		p.angular_velocity_min = -10
		p.angular_velocity_max = 10
		p.scale_amount_curve = sc
		p.color_ramp = g
		_ic_fx.add_child(p)
		_ic_smokes.append([p, String(spec.get("place", "")), int(spec.get("from", 0))])
	# snow: drifting down over the settlement, and falling on down the abyss through every depth
	var sk := float(J.sky)
	for zone in [Rect2(0, 0, float(J.W), sk + float(J.surf)), Rect2(float(J.abyss[0]), sk + float(J.surf), float(J.abyss[1]) - float(J.abyss[0]), H - sk - float(J.surf))]:
		var r: Rect2 = zone
		var p := CPUParticles2D.new()
		p.texture = _glow
		p.local_coords = true
		p.amount = 120 if r.size.x > 1000 else 70
		p.lifetime = 14.0 if r.size.x > 1000 else 22.0
		p.preprocess = p.lifetime
		p.position = r.position + Vector2(r.size.x * 0.5, 0)
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		p.emission_rect_extents = Vector2(r.size.x * 0.6, 10)
		p.direction = Vector2(0.3, 1)
		p.spread = 20
		p.gravity = Vector2(6, 18)
		p.initial_velocity_min = 40
		p.initial_velocity_max = 90
		p.scale_amount_min = 0.03
		p.scale_amount_max = 0.07
		p.color = Color(0.92, 0.95, 1.0, 0.75)
		_ic_fx.add_child(p)
	_ic_update_fx()

func _ic_update_fx() -> void:
	for s in _ic_smokes:
		var pl := String(s[1])
		(s[0] as CPUParticles2D).emitting = pl == "" or int(_shown_places.get(pl, 0)) >= int(s[2])

# ---------------------------------------------------------------- the blizzard, the kibble, the aurora

## how strong the gust is `s` seconds after it came: a fast rise, a long tail
func _gust(s: float) -> float:
	if s < 0.0 or s > 5.0:
		return 0.0
	return sin(PI * clampf(s / 0.8, 0.0, 1.0) * 0.5) * exp(-maxf(0.0, s - 0.8) * 0.9)

## the polar night by the phone's clock: towards midday a blue glow over the southern horizon and a weaker aurora,
## at night the aurora full
func _night() -> float:
	var h := float(Time.get_datetime_dict_from_system().hour) + float(Time.get_datetime_dict_from_system().minute) / 60.0
	return clampf(absf(h - 12.0) / 6.0, 0.25, 1.0)

func _process(delta: float) -> void:
	super(delta)
	if not visible or J.is_empty():
		return
	if Engine.get_process_frames() % 20 == 0:
		_ic_update_fx()
	if t > _next_gust:
		_next_gust = t + _rng.randf_range(9.0, 13.0)
		_gust_at = t
		_gust_k = _rng.randf_range(0.7, 1.15)
		IceSounds.gust(self, _gust_k)
	var gs := _gust(t - _gust_at) * _gust_k
	if _ic_aurora.material:
		var m := _ic_aurora.material as ShaderMaterial
		m.set_shader_parameter("t", t)
		m.set_shader_parameter("k", _night() * (1.0 + 0.35 * gs))
	# the kibble's swing: a long pendulum pushed by the gust
	var ln := maxf(200.0, _kib_y - _cable_top().y)
	var w2 := 9.8 * 60.0 / ln
	_kib_swv += (-w2 * _kib_sw + gs * 26.0) * delta
	_kib_swv *= 1.0 - 0.25 * delta
	_kib_sw += _kib_swv * delta
	_kib_sw = clampf(_kib_sw, -60.0, 60.0)
	_kibble_move()

## where the cable leaves the gantry's sheave (source px)
func _cable_top() -> Vector2:
	var g: Dictionary = J.gantry
	return Vector2(float(g.cable[0]), float(g.cable[1]))

## the kibble goes down to the depth being dug, waits at its landing, comes up, waits at the top; now and then it serves
## another open landing on the way
func _kibble_move() -> void:
	var top := _cable_top().y + 270.0     # at rest just under the deck (the cable runs down through it)
	var to_y := band_y(_kib_to) + floor_of(_kib_to + 1) - 30.0
	var down := (to_y - top) / KIB_V
	var s := t - _kib_from
	var cyc := down * 2.0 + KIB_WAIT * 2.0
	if s > cyc:
		_kib_from = t
		_kib_to = sel if _rng.randf() < 0.6 else _rng.randi_range(0, open)
		s = 0.0
		to_y = band_y(_kib_to) + floor_of(_kib_to + 1) - 30.0
		down = (to_y - top) / KIB_V
	var y := top
	_kib_up = s >= down + KIB_WAIT
	if s < down: y = lerpf(top, to_y, smoothstep(0.0, 1.0, s / down))
	elif s < down + KIB_WAIT: y = to_y
	elif s < down * 2.0 + KIB_WAIT: y = lerpf(to_y, top, smoothstep(0.0, 1.0, (s - down - KIB_WAIT) / down))
	_kib_y = y

## the gantry: its sheave wheel turning while the cable runs, the cable down the abyss, the kibble on it - a riveted iron
## tub with a bail, heaped with coal when it comes up, a lamp on its rim; swinging with the wind
func _gantry(c: CanvasItem) -> void:
	if int(_shown_places.get("gantry", 0)) < 3:
		return
	var g: Dictionary = J.gantry
	var wh: Array = g.wheel
	var at := Vector2(float(wh[0]), float(wh[1]))
	var r := float(wh[2])
	_ic_wheel(c, at, r, -_kib_y / r)
	# what of the frame stands in front of the sheave in the picture (its crossbeam), cut out of s_nowheel
	for f_ in g.get("front", []):
		var fe: Array = f_
		var fa: Array = fe[1]
		_put(c, String(fe[0]), Vector2(float(fa[0]), float(fa[1])))
	var ct := _cable_top()
	var kb := Vector2(ct.x + _kib_sw * clampf((_kib_y - ct.y) / 2400.0, 0.1, 1.0), _kib_y)
	var ink := Color(0.03, 0.035, 0.05)
	c.draw_line(ct, kb + Vector2(0, -44), ink, 5.0)
	c.draw_line(ct, kb + Vector2(0, -44), Color(0.45, 0.48, 0.55, 0.8), 2.0)
	# the tub
	var up := _kib_up
	var ang := clampf(_kib_swv * 0.004, -0.15, 0.15)
	c.draw_set_transform(kb, ang, Vector2.ONE)
	var body := PackedVector2Array([Vector2(-34, -14), Vector2(34, -14), Vector2(28, 30), Vector2(-28, 30)])
	c.draw_colored_polygon(PackedVector2Array([Vector2(-38, -18), Vector2(38, -18), Vector2(31, 34), Vector2(-31, 34)]), ink)
	c.draw_colored_polygon(body, Color(0.2, 0.19, 0.2))
	c.draw_colored_polygon(PackedVector2Array([Vector2(-34, -14), Vector2(-6, -14), Vector2(-4, 30), Vector2(-28, 30)]), Color(0.28, 0.27, 0.3))
	for yy in [-4.0, 16.0]:
		c.draw_line(Vector2(-33 + (yy + 14) * 0.15, yy), Vector2(33 - (yy + 14) * 0.15, yy), Color(0.08, 0.08, 0.1), 3.0)
	c.draw_line(Vector2(-34, -15), Vector2(34, -15), Color(0.55, 0.58, 0.66, 0.8), 2.0)
	if up:
		for j in 6:
			c.draw_circle(Vector2(-22 + j * 9, -16 - 4 * sin(j * 2.1)), 7.0, Color(0.05, 0.05, 0.06))
			c.draw_circle(Vector2(-24 + j * 9, -19 - 4 * sin(j * 2.1)), 2.0, Color(0.5, 0.5, 0.6, 0.7))
	c.draw_arc(Vector2(0, -14), 30.0, PI, TAU, 16, ink, 5.0)
	c.draw_arc(Vector2(0, -14), 30.0, PI, TAU, 16, Color(0.4, 0.42, 0.48), 2.0)
	c.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	_light(c, kb + Vector2(26, -20), 60, Color(1.0, 0.72, 0.35, 0.4 * _flick(301)))
	c.draw_circle(kb + Vector2(26, -20), 4.0, Color(1.0, 0.9, 0.6))

## a spoked iron sheave in ink like the picture, turning (the picture's own wheel was taken out: s_nowheel)
func _ic_wheel(c: CanvasItem, at: Vector2, r: float, a: float) -> void:
	var ink := Color(0.03, 0.03, 0.04)
	var iron := Color(0.13, 0.13, 0.15)
	var lit := Color(0.55, 0.6, 0.72, 0.5)
	var w := r * 0.16
	for i in 8:
		var d := Vector2.from_angle(a + TAU * i / 8.0)
		var n := d.orthogonal()
		var p0 := at + d * r * 0.16
		var p1 := at + d * (r - w * 0.4)
		c.draw_colored_polygon(PackedVector2Array([p0 - n * 5.0, p1 - n * 3.6, p1 + n * 3.6, p0 + n * 5.0]), ink)
		c.draw_colored_polygon(PackedVector2Array([p0 - n * 3.0, p1 - n * 1.8, p1 + n * 1.8, p0 + n * 3.0]), iron)
	c.draw_arc(at, r, 0, TAU, 48, ink, w + 4.0)
	c.draw_arc(at, r, 0, TAU, 48, iron, w)
	c.draw_arc(at, r + w * 0.3, -PI * 0.95, -PI * 0.4, 14, lit, maxf(1.5, w * 0.25))
	# frost on the rim's top: it turns with it
	for j in 5:
		var a0 := a + j * 1.26
		c.draw_arc(at, r + w * 0.35, a0, a0 + 0.3, 5, Color(0.85, 0.92, 1.0, 0.55), 2.0)
	c.draw_circle(at, r * 0.2 + 2.0, ink)
	c.draw_circle(at, r * 0.2, iron.lightened(0.15))
	c.draw_circle(at + Vector2(-r * 0.05, -r * 0.05), r * 0.06, Color(0.6, 0.62, 0.7, 0.7))

## the searchlight: its cone sweeping slowly over the settlement and down into the funnel, brighter where it falls
func _searchlight(c: CanvasItem) -> void:
	if int(_shown_places.get("searchlight", 0)) < 3:
		return
	var sl: Dictionary = J.searchlight
	var at := Vector2(float(sl.lamp[0]), float(sl.lamp[1]))
	var ang := deg_to_rad(40.0 + 32.0 * sin(t * 0.21))          # mostly down and to the right, over the funnel
	if _events.has("bear") and J.has("bear"):
		var bp := Vector2(float(J.bear.x), float(J.sky) + float(J.bear.y) - 40.0)
		ang = lerp_angle(ang, (bp - at).angle(), clampf((t - float(_events.bear)) / 1.2, 0.0, 1.0))
	var ln := 1500.0
	var d := Vector2.from_angle(ang)
	var n := d.orthogonal()
	var far := at + d * ln
	var col := Color(0.85, 0.92, 1.0, 0.16)
	c.draw_polygon(PackedVector2Array([at - n * 8.0, at + n * 8.0, far + n * 190.0, far - n * 190.0]),
		PackedColorArray([col, col, Color(col, 0.0), Color(col, 0.0)]))
	c.draw_polygon(PackedVector2Array([at - n * 4.0, at + n * 4.0, far + n * 70.0, far - n * 70.0]),
		PackedColorArray([Color(1, 1, 1, 0.16), Color(1, 1, 1, 0.16), Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.0)]))
	_light(c, at, 46, Color(0.9, 0.95, 1.0, 0.85))
	# the snow lit in the beam
	for j in 16:
		var u := fmod(t * 0.08 + j / 16.0, 1.0)
		var p := at + d * (120.0 + u * 900.0) + n * (sin(j * 7.3 + t * 0.9) * 60.0 * u)
		c.draw_circle(p, 2.4, Color(1, 1, 1, 0.7 * sin(PI * u)))

func _lights(c: CanvasItem) -> void:
	var gs := _gust(t - _gust_at) * _gust_k
	var sl: Dictionary = J.surface_lamps
	var i := 0
	for place in sl:
		if place != "" and int(_shown_places.get(place, 0)) < 3:
			continue
		for l in sl[place]:
			i += 1
			var col := Color(1.0, 0.72, 0.35, 0.33)
			if (l as Array).size() > 3: col = Color(String(l[3]))
			col.a *= _flick(i) * (1.0 - 0.3 * gs)
			_light(c, Vector2(float(l[0]), float(l[1])), 70 * float(l[2]), col)
	# the galleries' lamps gutter in the gust that comes down the abyss
	for b in _bands:
		var k := int(b.k)
		if String(_shown_bands.get(k, b.state)) == "closed" or not _band_seen(b):
			continue
		var ls: Array = J.lamps.get(str(int(b.d)), [])
		var dip := 1.0 - 0.45 * _gust(t - _gust_at - 0.4 - k * 0.12) * _gust_k
		for j in ls.size():
			var l: Array = ls[j]
			_light(c, Vector2(float(l[0]), float(b.y) + float(l[1])), 150, Color(1.0, 0.7, 0.32, 0.26 * _flick(k * 3 + j) * dip))
	# the cold light from far below, up the abyss: stronger the deeper (under the deepest open level it waits)
	var ab: Array = J.abyss
	var cx := (float(ab[0]) + float(ab[1])) * 0.5
	for b in _bands:
		if not _band_seen(b):
			continue
		var deep := 0.3 + 0.7 * float(b.k) / 8.0
		_light(c, Vector2(cx, float(b.y) + 300), 260, Color(0.45, 0.75, 1.0, 0.07 * deep))

## the surface alive: chimney smoke, lit windows, the searchlight, the gantry and its kibble, the coal chute's car, the
## guide (the Scholar) at the rim, the watchman, the old man with the bayan, the dogs, a reindeer, a fox
func _surface_live(c: CanvasItem) -> void:
	var sky := float(J.sky)
	_searchlight(c)
	_chute(c)
	if int(_shown_places.get("power", 0)) >= 3 and J.has("power"):
		var pw: Dictionary = J.power
		for w_ in pw.windows:
			var w: Array = w_
			_light(c, Vector2(float(w[0]), float(w[1])), 46, Color(1.0, 0.7, 0.35, 0.3 * _flick(int(w[0]))))
	if int(_shown_places.get("palace", 0)) >= 3 and J.has("palace"):
		var pl: Dictionary = J.palace
		for w_ in pl.windows:
			var w: Array = w_
			# the piano plays inside: the windows breathe a little with it
			_light(c, Vector2(float(w[0]), float(w[1])), 40, Color(1.0, 0.78, 0.45, 0.28 + 0.06 * sin(t * 2.0 + float(w[0]))))
	for a in J.life:
		var spec: Dictionary = a
		var nm := String(spec.name)
		if not _crew_ok(nm):
			continue
		if spec.has("place") and int(_shown_places.get(String(spec.place), 0)) < int(spec.get("from", 3)):
			continue
		if spec.has("until") and int(_shown_places.get(String(spec.until), 0)) >= 3:
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
		if nm == "guide24":
			# her jar: the glowing crystal lights her and the snow round her
			_light(c, pos + Vector2(fs.x * (0.3 if flip else 0.7), fs.y * 0.35), 60, Color(0.7, 0.95, 1.0, 0.35 + 0.08 * sin(t * 1.7)))
		if nm == "husky":
			# it howls as its head goes up (drawing 5 of its loop)
			var di := _drawing_at(spec, u) if spec.has("play") else int(u) % n
			if di == 5 and _howl_prev != 5:
				IceSounds.howl(self, _far(sky + float(spec.y)))
			_howl_prev = di
	_gantry(c)

## the coal chute: once rebuilt, a little lamp-lit car rides down its gallery from the adit to the bunker now and then
func _chute(c: CanvasItem) -> void:
	if int(_shown_places.get("chute", 0)) < 3 or not J.has("chute"):
		return
	var line: Array = J.chute.line
	var u := fmod(t / 22.0, 1.0)
	if u > 0.6:
		return
	var q := u / 0.6
	var n := line.size()
	var f := q * (n - 1)
	var i0 := mini(int(f), n - 2)
	var a: Array = line[i0]
	var b: Array = line[i0 + 1]
	var p := Vector2(float(a[0]), float(a[1])).lerp(Vector2(float(b[0]), float(b[1])), f - i0)
	_light(c, p, 34, Color(1.0, 0.75, 0.4, 0.55 * sin(PI * q)))

func _draw_live() -> void:
	var c := live
	_lights(c)
	_surface_live(c)
	_ic_flags(c)
	for b in _bands:
		if _band_seen(b): _band_live(c, b)
	_events_live(c)
	_blizzard(c)
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
		if not ResourceLoader.exists(dir + p):
			_bursts.erase(bu)
			continue
		var sz := _size(p) * 1.6
		var at: Vector2 = bu[0]
		c.draw_texture_rect(tex(p), Rect2(at - sz / 2, sz), false)

## a gust: streaks of driven snow racing across the screen where it is looked at, and spilling down the abyss
func _blizzard(c: CanvasItem) -> void:
	var gs := _gust(t - _gust_at) * _gust_k
	if gs < 0.03:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_gust_at * 10.0)
	var y0 := _seen.x
	var y1 := minf(_seen.y, float(J.sky) + float(J.surf) + float(J.cut))
	for j in 46:
		var y := rng.randf_range(y0, maxf(y0 + 1.0, y1))
		var sp := rng.randf_range(900.0, 1500.0)
		var x := fmod(rng.randf_range(0, 1800) + (t - _gust_at) * sp, 1900.0) - 180.0
		var l := rng.randf_range(40.0, 120.0) * gs
		c.draw_line(Vector2(x, y), Vector2(x - l, y - l * 0.12), Color(0.9, 0.94, 1.0, 0.45 * gs), rng.randf_range(1.5, 3.5))
	# down the abyss: a curtain of snow sliding down and sideways
	var ab: Array = J.abyss
	for j in 30:
		var x := rng.randf_range(float(ab[0]) + 20.0, float(ab[1]) - 20.0)
		var y := fmod(rng.randf_range(0.0, 2000.0) + (t - _gust_at) * 700.0, 2200.0) + _cut_top() - 200.0
		if y < _seen.x or y > _seen.y: continue
		c.draw_line(Vector2(x, y), Vector2(x + 30.0 * gs, y - 70.0), Color(0.88, 0.93, 1.0, 0.35 * gs), 2.5)

## a level's life: the crew, the stove of 250 m, the steam of 350 m, the signs of the four in the funnel's far wall
func _band_live(c: CanvasItem, b: Dictionary) -> void:
	var k := int(b.k)
	var y := float(b.y)
	var st := String(_shown_bands.get(k, b.state))
	if st == "closed":
		return
	var d := int(b.d)
	var floor_y := y + floor_of(d)
	if J.has("stove") and d == int(J.stove.d):
		var sp: Array = J.stove.at
		_light(c, Vector2(float(sp[0]), y + float(sp[1])), 90, Color(1.0, 0.5, 0.18, 0.45 * _flick(77)))
	if J.has("steam") and d == int(J.steam.d) and st in ["step2", "done"]:
		var sp: Array = J.steam.at
		var ps := _size("puff.png")
		for j in 8:
			var u := fmod(t * 0.35 + j / 8.0, 1.0)
			var p := Vector2(float(sp[0]) + float(J.steam.dir) * u * 160.0 + sin(j * 2.3 + t) * 12.0, y + float(sp[1]) - u * 90.0)
			var sc := 0.3 + 1.1 * u
			c.draw_texture_rect(tex("puff.png"), Rect2(p - ps * sc / 2, ps * sc), false, Color(0.95, 0.97, 1.0, 0.3 * sin(PI * u)))
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
	if cr.has("nozzle") and rx == "":
		# the steam jet off the hose's nozzle onto the ice
		var nz: Array = cr.nozzle
		var at := Vector2(x + float(nz[0]) * (-1.0 if flip else 1.0), floor_y + float(nz[1]))
		var ps := _size("puff.png")
		for j in 10:
			var u := fmod(t * 1.3 + j / 10.0, 1.0)
			var q := at + Vector2((-1.0 if flip else 1.0) * u * 150.0, -u * 30.0 + sin(j * 3.0) * 10.0 * u)
			var sc := 0.2 + 0.9 * u
			c.draw_texture_rect(tex("puff.png"), Rect2(q - ps * sc / 2, ps * sc), false, Color(1, 1, 1, 0.45 * (1.0 - u)))

# ---------------------------------------------------------------- the brother and the four, about the place

func _tick_events() -> void:
	if force_event != "" and t > 0.5:
		_start_event(force_event)
		force_event = ""
	if t < _next_event:
		return
	_next_event = t + _rng.randf_range(10.0, 16.0)
	var pool := ["brother", "lantern"]
	if open >= 4: pool.append("heart")
	for sg in J.get("signs", []):
		if int(sg.d) - 1 <= open:
			pool.append("signs")
			break
	if J.has("dwarf") and String(_shown_bands.get(int(J.dwarf.d) - 1, "closed")) in ["step2", "done"]:
		pool.append("dwarf")     # the herald of the second arc: nobody here knows what he is
	if int(_shown_places.get("searchlight", 0)) < 3 or _rng.randf() < 0.4:
		pool.append("bear")
	_start_event(pool[_rng.randi() % pool.size()])

func _start_event(ev: String) -> void:
	_events[ev] = t
	match ev:
		"heart":
			for j in 4:
				get_tree().create_timer(0.3 + j * 1.15).timeout.connect(func(): IceSounds.heart(self, _far(band_y(open) + 400)))
		"signs":
			var cand: Array = []
			for sg in J.get("signs", []):
				if int(sg.d) - 1 <= open and String(_shown_bands.get(int(sg.d) - 1, "closed")) != "closed":
					cand.append(sg)
			if cand.is_empty():
				_events.erase(ev)
				return
			_events.erase("signs_at")
		"dwarf":
			IceSounds.crack(self, _far(band_y(int(J.dwarf.d) - 1) + 300))
		"bear":
			if int(_shown_places.get("searchlight", 0)) >= 3:
				_flare_at = t + 1.6
				get_tree().create_timer(1.6).timeout.connect(func(): IceSounds.flare(self, _far(float(J.sky) + 600)))
		"brother":
			IceSounds.gust(self, 0.6)

## a sign of the four to show: an open level's, the one on the screen if there is one
func _ic_sign() -> Dictionary:
	var cand: Array = []
	for sg in J.get("signs", []):
		if int(sg.d) - 1 <= open and String(_shown_bands.get(int(sg.d) - 1, "closed")) != "closed":
			cand.append(sg)
	if cand.is_empty():
		return {}
	var pick: Dictionary = cand[_rng.randi() % cand.size()]
	var mid := lerpf(_seen.x, _seen.y, 0.4)
	var best := 1e9
	for c_ in cand:
		var y := band_y(int(c_.d) - 1) + 300.0
		if y > _seen.x and y < _seen.y and absf(y - mid) < best:
			best = absf(y - mid)
			pick = c_
	return pick

const HEART_COLS := [Color(1.0, 0.8, 0.3), Color(0.3, 0.95, 0.55), Color(0.35, 0.7, 1.0), Color(1.0, 0.45, 0.15)]

func _events_live(c: CanvasItem) -> void:
	for ev in _events.keys():
		if ev == "signs_at":
			continue
		var s := t - float(_events[ev])
		var done := false
		match ev:
			"brother":
				# a man on the far rim of the funnel, against the aurora: he comes out of the blowing snow, stands with his
				# lantern, and the next swirl of snow takes him
				if s > 7.0 or not J.has("brother"): done = true
				else:
					var bp: Array = J.brother
					var al := clampf(s / 1.2, 0.0, 1.0) * clampf((7.0 - s) / 1.0, 0.0, 1.0)
					var fr := "brother/%02d.png" % (int(t * 4.0) % maxi(1, int(J.crew_n.get("brother", 1))))
					if _crew_ok("brother"):
						var sz := _size(fr)
						_put(c, fr, Vector2(float(bp[0]) - sz.x / 2, float(J.sky) + float(bp[1]) - sz.y), false, al)
						_light(c, Vector2(float(bp[0]) + sz.x * 0.25, float(J.sky) + float(bp[1]) - sz.y * 0.35), 40, Color(1.0, 0.72, 0.35, 0.5 * al))
			"lantern":
				# his lantern far down the abyss, below the deepest open level, going on down
				if s > 9.0: done = true
				else:
					var ab: Array = J.abyss
					var y := band_y(open) + float(J.band) * 1.15 + s * 22.0
					var p := Vector2((float(ab[0]) + float(ab[1])) * 0.5 + 40.0 * sin(s * 0.7), y)
					var al := clampf(s / 1.5, 0.0, 1.0) * clampf((9.0 - s) / 2.0, 0.0, 1.0)
					_light(c, p, 70, Color(1.0, 0.7, 0.3, 0.35 * al))
					c.draw_circle(p, 3.5, Color(1.0, 0.9, 0.6, al))
			"heart":
				# the heart he carries, far below: four beats up the abyss, gold, green, blue, fire
				if s > 5.4: done = true
				else:
					var ab: Array = J.abyss
					var cx := (float(ab[0]) + float(ab[1])) * 0.5
					var j := mini(int((s - 0.3) / 1.15), 3)
					var q := fposmod(s - 0.3, 1.15) / 1.15
					if s >= 0.3:
						var col: Color = HEART_COLS[j]
						var yb := band_y(open) + float(J.band) * 1.2
						for b in _bands:
							if int(b.k) > open: continue
							var f := exp(-q * 3.0) * (0.4 + 0.6 * float(b.k) / maxf(1.0, float(open)))
							_light(c, Vector2(cx, float(b.y) + 300), 460, Color(col, 0.5 * f))
							_light(c, Vector2(cx, float(b.y) + 300), 170, Color(col, 0.55 * f))
						# a beat of light running up the abyss from below, the colour of the shard
						var top_y := band_y(0) - 200.0
						var run := clampf(q / 0.55, 0.0, 1.0)
						var head := lerpf(yb, top_y, run)
						var fade := 1.0 - smoothstep(0.55, 1.0, q)
						for k2 in 12:
							var py := lerpf(head, yb, k2 / 11.0)
							_light(c, Vector2(cx + 10.0 * sin(py * 0.01 + s), py), 110.0 - k2 * 4.0, Color(col.lightened(0.2), 0.35 * fade * (1.0 - k2 / 14.0)))
						_light(c, Vector2(cx, yb), 340, Color(col, 0.8 * exp(-q * 2.0)))
					if J.has("crack"):
						var cr: Dictionary = J.crack
						var y0 := band_y(int(cr.d) - 1)
						var pts := PackedVector2Array()
						for p_ in cr.line:
							pts.append(Vector2(float(p_[0]), y0 + float(p_[1])))
						var col2: Color = HEART_COLS[maxi(j, 0)]
						var f2 := exp(-q * 2.5) if s >= 0.3 else 0.0
						c.draw_polyline(pts, Color(col2, 0.8 * f2), 7.0)
						c.draw_polyline(pts, Color(1, 1, 1, 0.7 * f2), 2.5)
						for p in pts: _light(c, p, 50, Color(col2, 0.35 * f2))
			"signs":
				if not _events.has("signs_at"):
					_events["signs_at"] = _ic_sign()
				var sg: Dictionary = _events.get("signs_at", {})
				if sg.is_empty() or s > 3.5: done = true
				else: _sign(c, sg, s)
			"dwarf":
				# the frozen dwarf wakes for a moment: his eyes open as two cold blue sparks, the empty heart on his medallion
				# glows the four colours in turn, frost cracks run out over the lens - then it all goes still again
				if s > 5.5 or not J.has("dwarf"): done = true
				else:
					var dw: Dictionary = J.dwarf
					var y := band_y(int(dw.d) - 1)
					var al := clampf((s - 0.4) / 0.5, 0.0, 1.0) * clampf((5.5 - s) / 1.0, 0.0, 1.0)
					var blink := 1.0 if fmod(s, 2.2) < 2.05 else 0.15
					for e_ in dw.eyes:
						var e: Array = e_
						var ep := Vector2(float(e[0]), y + float(e[1]))
						_light(c, ep, 46, Color(0.5, 0.85, 1.0, 0.55 * al))
						c.draw_set_transform(ep, 0, Vector2(1.0, 0.45 * blink))
						c.draw_circle(Vector2.ZERO, 4.5, Color(0.85, 0.97, 1.0, al))
						c.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
					if dw.has("medal"):
						var md: Array = dw.medal
						var mp := Vector2(float(md[0]), y + float(md[1]))
						var col: Color = HEART_COLS[int(s / 0.9) % 4]
						_light(c, mp, 60, Color(col, 0.6 * al))
						c.draw_circle(mp, 6.0, Color(col.lightened(0.4), 0.9 * al))
					var rng := RandomNumberGenerator.new()
					rng.seed = 77
					var cen := Vector2(float(dw.eyes[0][0]) + 6.0, y + float(dw.eyes[0][1]))
					var grow := clampf((s - 0.6) / 1.4, 0.0, 1.0)
					for j in 7:
						var a := rng.randf_range(0, TAU)
						var p := cen
						var pts := PackedVector2Array([p])
						for k in 4:
							a += rng.randf_range(-0.6, 0.6)
							p += Vector2.from_angle(a) * rng.randf_range(14.0, 24.0) * grow
							pts.append(p)
						c.draw_polyline(pts, Color(0.92, 0.98, 1.0, 0.75 * al), 2.0)
					if _passed("dwarf_crk", s, 100.0, 0.6):
						IceSounds.crack(self, _far(y + 300))
			"bear":
				# a polar bear at the settlement's edge, sniffing; with the searchlight built the beam finds it, the
				# watchman's red flare goes up and the bear goes off into the dark
				if s > 9.0 or not J.has("bear"): done = true
				else:
					var be: Dictionary = J.bear
					var lit := int(_shown_places.get("searchlight", 0)) >= 3
					var go := clampf((s - 3.0) / 3.0, 0.0, 1.0) if lit else clampf((s - 6.5) / 2.5, 0.0, 1.0)
					var al := clampf(s / 1.0, 0.0, 1.0) * (1.0 - go)
					var n := maxi(1, int(J.crew_n.get("bear", 1)))
					var fr := "bear/%02d.png" % (int(t * 6.0) % n)
					if _crew_ok("bear"):
						var sz := _size(fr)
						var at := Vector2(float(be.x) - go * 220.0, float(J.sky) + float(be.y))
						_put(c, fr, Vector2(at.x - sz.x / 2, at.y - sz.y), go > 0.0, al)
					if lit:
						var fs := t - _flare_at
						if fs > 0.0 and fs < 5.0:
							var fp := Vector2(float(be.x) + 120.0, float(J.sky) + float(be.y) - 120.0 - 380.0 * minf(fs / 1.4, 1.0) + maxf(0.0, fs - 1.4) * 40.0)
							_light(c, fp, 140, Color(1.0, 0.25, 0.15, 0.45 * clampf(1.0 - fs / 5.0, 0.0, 1.0)))
							c.draw_circle(fp, 6.0, Color(1.0, 0.75, 0.6, clampf(1.0 - fs / 5.0, 0.0, 1.0)))
		if done:
			_events.erase(ev)

## a sign of one of the four in the funnel's wall waking: the Serpent's golden scales glint one after another, the
## Mistress's malachite crust breathes green, the Kraken's sucker marks shine wet, the Smith's handprint glows like a
## coal and steams
func _sign(c: CanvasItem, sg: Dictionary, s: float) -> void:
	var y := band_y(int(sg.d) - 1)
	var pts: Array = sg.pts
	var f := sin(PI * clampf(s / 3.5, 0.0, 1.0))
	match String(sg.kind):
		"scales":
			for i in pts.size():
				var p: Array = pts[i]
				var q := clampf((s - i * 0.18) / 0.6, 0.0, 1.0)
				var g := sin(PI * q)
				var at := Vector2(float(p[0]), y + float(p[1]))
				_light(c, at, 40, Color(1.0, 0.82, 0.3, 0.55 * g))
				c.draw_line(at + Vector2(-9, 0) * g, at + Vector2(9, 0) * g, Color(1, 0.95, 0.7, g), 2.0)
				c.draw_line(at + Vector2(0, -9) * g, at + Vector2(0, 9) * g, Color(1, 0.95, 0.7, g), 2.0)
		"malachite":
			for p_ in pts:
				var p: Array = p_
				_light(c, Vector2(float(p[0]), y + float(p[1])), 110, Color(0.25, 0.95, 0.5, 0.3 * f * (0.7 + 0.3 * sin(s * 4.0 + float(p[0])))))
		"suckers":
			for i in pts.size():
				var p: Array = pts[i]
				var g := clampf(f * 1.4 - absf(sin(s * 2.0 - i * 0.6)) * 0.4, 0.0, 1.0)
				_light(c, Vector2(float(p[0]), y + float(p[1])), 34, Color(0.45, 0.8, 1.0, 0.5 * g))
				c.draw_arc(Vector2(float(p[0]), y + float(p[1])), 12.0, -PI * 0.9, -PI * 0.3, 8, Color(0.85, 0.95, 1.0, 0.8 * g), 2.0)
		"hand":
			var p: Array = pts[0]
			var at := Vector2(float(p[0]), y + float(p[1]))
			_light(c, at, 120, Color(1.0, 0.45, 0.12, 0.5 * f))
			_light(c, at, 46, Color(1.0, 0.85, 0.5, 0.6 * f))
			var ps := _size("puff.png")
			for j in 6:
				var u := fmod(s * 0.5 + j / 6.0, 1.0)
				var q := at + Vector2(sin(j * 2.1) * 30.0, -u * 160.0)
				var sc := 0.3 + u
				c.draw_texture_rect(tex("puff.png"), Rect2(q - ps * sc / 2, ps * sc), false, Color(1, 1, 1, 0.25 * f * (1.0 - u)))
	if _passed("sign_snd", s, 100.0, 0.05):
		IceSounds.sign(self, String(sg.kind), _far(y + 300))

## flags on the finished places once the brother is beaten (the same wind-bent pennant as the other mines)
func _ic_flags(c: CanvasItem) -> void:
	if not ResourceLoader.exists(dir + "flag_strip.png") or not J.has("flags"): return
	if area >= Save.d.boss_won.size() or not bool(Save.d.boss_won[area]): return
	var tx := tex("flag_strip.png")
	var i := 0
	for fl: Dictionary in J.flags:
		i += 1
		if int(_shown_places.get(String(fl.place), 0)) < 3: continue
		var pole: Array = fl.pole
		var foot := Vector2(float(pole[0]), float(pole[1]))
		var top := Vector2(foot.x, float(pole[2]))
		c.draw_line(foot, top, Color(0.05, 0.05, 0.07), 4.0)
		c.draw_circle(top, 3.2, Color(0.5, 0.52, 0.6))
		var ln: float = fl.len
		var hw := ln * float(tx.get_height()) / float(tx.get_width()) * 0.5
		var ph := t + i * 3.7
		var wind := clampf(0.7 + 0.25 * sin(ph * 0.27) + 0.3 * _gust(t - _gust_at), 0.2, 1.0)
		var fold := func(q: float) -> float: return q * 7.0 - ph * (5.0 + 5.0 * wind)
		var pts := Bend.chain(top + Vector2(0, hw + 2.0), ln * (0.9 + 0.1 * wind), 24, func(q: float) -> float:
			return (0.14 + 0.3 * (1.0 - wind)) * q * sin(fold.call(q)) + (1.0 - wind) * 0.8 * q)
		Bend.draw(c, pts, func(q: float) -> float: return hw * (1.0 - 0.1 * q * absf(cos(fold.call(q)))), tx, 0.0, 1.0, false,
			func(q: float) -> Color: var v := 0.8 + 0.2 * q * sin(fold.call(q) + 1.2); return Color(v, v, v))

## after a win the level's coal flies down into the depth it came from: black glossy lumps with ember cracks, grey iron
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
	var from := Vector2(800, -position.y / scale.y + 40)
	var n_ore := mini(int(_react.ore), 10)
	var n_iron := mini(int(_react.iron), 8)
	for i in n_ore + n_iron:
		var u := (s - 0.4 - i * 0.09) / 0.9
		if u < 0.0 or u > 1.4:
			continue
		var iron := i >= n_ore
		var tgt := to + Vector2((i % 5 - 2) * 34 + sin(i * 2.3) * 10, (i % 3) * 8)
		var glow := Color(0.75, 0.8, 0.9) if iron else Color(1.0, 0.45, 0.18)
		if u <= 1.0:
			var e := u * u * (3.0 - 2.0 * u)
			var p := from.lerp(tgt, e) + Vector2(sin(i * 1.7) * 160 * sin(PI * u), -220 * sin(PI * u))
			c.draw_circle(p, 22.0, Color(glow, 0.22))
			_coal(c, p, 30.0, iron, i, t * (3.0 + (i % 3)))
		else:
			var f := (u - 1.0) / 0.4
			_light(c, tgt, 60 + 70 * f, Color(glow, 0.6 * (1.0 - f)))
			_coal(c, tgt + Vector2(0, -8), 30.0 * (1.0 - smoothstep(0.5, 1.0, f)), iron, i, 0.0)
		if _passed("ore%d" % i, u, 1.0, 1.0):
			amb.shot("coin", -10.0, 1.2 + (i % 4) * 0.05)

## a lump of coal (black, glassy facets, a smouldering red seam) or of grey iron ore
func _coal(c: CanvasItem, at: Vector2, r: float, iron: bool, seed_: int, spin: float) -> void:
	if r < 1.0:
		return
	var pts := PackedVector2Array()
	var rim := PackedVector2Array()
	for j in 6:
		var a := spin + TAU * j / 6.0
		var rr := r * (0.75 + 0.25 * absf(sin(seed_ * 3.1 + j * 1.9)))
		pts.append(at + Vector2.from_angle(a) * rr)
		rim.append(at + Vector2.from_angle(a) * (rr + 5.0))
	c.draw_colored_polygon(rim, Color(0.02, 0.02, 0.03))
	c.draw_colored_polygon(pts, Color(0.36, 0.35, 0.37) if iron else Color(0.07, 0.07, 0.08))
	if iron:
		c.draw_rect(Rect2(at + Vector2(0.0, -0.1) * r, Vector2(r, r) * 0.42), Color(0.18, 0.18, 0.21))
	else:
		c.draw_colored_polygon(PackedVector2Array([at, pts[0], pts[1]]), Color(0.22, 0.22, 0.26))
		c.draw_line(pts[3].lerp(at, 0.2), pts[5].lerp(at, 0.3), Color(1.0, 0.4, 0.12), 3.0)
		c.draw_circle(at + Vector2(-0.3, -0.4) * r, r * 0.1, Color(0.8, 0.85, 1.0))

func _tremor() -> void:
	if String(_shown_bands.get(8, "")) == "done" and not bool(Save.d.boss_won[area]) and t > _next_tremor:
		_next_tremor = t + _rng.randf_range(18.0, 30.0)
		if t - _tremor_at > 5.0:
			_tremor_at = t
	var s := t - _tremor_at
	var amp := 0.0
	if s >= 0.0 and s < 1.6:
		amp = 6.0 * (1.0 - s / 1.6)
	position.x = sin(t * 47.0) * amp * scale.x
	if s >= 0.0 and s < 0.05 and not _cue.has("tremor%d" % int(_tremor_at)):
		_cue["tremor%d" % int(_tremor_at)] = true
		amb.shot("rockfall", -4.0, 0.55)
		IceSounds.crack(self, -2.0)
		IceSounds.gate(self, -4.0)

## the dwarven gate open: the runes round its heart-shaped hollow beat like a heart in the four colours, cold light
## breathes out between its leaves and over the ice, the brother's footprints on the ice glow up to it, snow drifts down
func _finale(c: CanvasItem) -> void:
	if String(_shown_bands.get(8, "")) != "done" or not J.has("gate"):
		return
	var y := band_y(8)
	var gt: Dictionary = J.gate
	var sh := clampf(1.0 - (t - _tremor_at) / 2.0, 0.0, 1.0)
	var beat := fposmod(t, 2.4)
	var pulse := exp(-beat * 4.0) + 0.7 * exp(-maxf(0.0, beat - 0.3) * 4.0) * float(beat > 0.3)
	var col: Color = HEART_COLS[int(t / 2.4) % 4]
	var dr: Array = gt.door
	var at := Vector2(float(dr[0]), y + float(dr[1]))
	_light(c, at, 320.0, Color(0.55, 0.8, 1.0, 0.22 + 0.15 * sh))
	_light(c, at, 120.0, Color(0.85, 0.95, 1.0, 0.4 + 0.2 * pulse))
	c.draw_line(at + Vector2(0, -150), at + Vector2(0, 190), Color(0.8, 0.95, 1.0, 0.5 + 0.3 * pulse), 9.0)
	c.draw_line(at + Vector2(0, -150), at + Vector2(0, 190), Color(1, 1, 1, 0.7), 3.0)
	var rw: Array = gt.runes        # centre x, y, radius of the ring of runes round the hollow
	var rc := Vector2(float(rw[0]), y + float(rw[1]))
	for i in 12:
		var a := TAU * i / 12.0 - PI / 2
		_light(c, rc + Vector2.from_angle(a) * float(rw[2]), 26.0, Color(col, 0.35 + 0.55 * pulse))
	_light(c, rc, float(rw[2]) * 0.6, Color(col, 0.5 * pulse))
	var fl: Array = gt.floor
	c.draw_set_transform(Vector2(float(fl[0]), y + float(fl[1])), 0.0, Vector2(1.0, 0.2))
	_light(c, Vector2.ZERO, float(fl[2]), Color(0.6, 0.85, 1.0, 0.35 + 0.2 * pulse))
	c.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	for p_ in gt.get("prints", []):
		var p: Array = p_
		_light(c, Vector2(float(p[0]), y + float(p[1])), 22, Color(0.7, 0.9, 1.0, 0.3 + 0.2 * pulse))
	if _passed("gate_beat", t, 2.4, 0.0) and _far(at.y) > -12.0:
		IceSounds.heart(self, _far(at.y) - 4.0)

# ---------------------------------------------------------------- crews and sounds

func _ic_crew_v(k: int, at: float) -> float:
	var v := at * CREW_FPS + k * 7.0
	if _ic_hold.has(k):
		v -= clampf(at - float(_ic_hold[k]), 0.0, REACT_LEN) * CREW_FPS
	return v

func _crew_frame(cr: Dictionary, k: int) -> int:
	return _drawing_at(cr, _ic_crew_v(k, t))

func _ic_hit_at(cr: Dictionary) -> float:
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
		if _passed("hit%d" % k, _ic_crew_v(k, t), _loop(cr), _ic_hit_at(cr)) and (k == sel or randf() < 0.15):
			IceSounds.strike(amb, String(cr.work[0]), _far(float(b.y) + floor_of(int(b.d))) - k * 1.2 + (0.0 if k == sel else -4.0), 0.95 - k * 0.02)
	IceSounds.of(self).tick(self)
