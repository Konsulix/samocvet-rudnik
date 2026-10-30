class_name CopperView
extends MineView
## Copper Mountain (mine 2): the Demidovs' copper works over the mine, drawn the same way as Old Adit (MineView) but laid
## out its own way (docs/mine-design.md §9): a factory on terraces over the ground, the mine entered by an INCLINED shaft
## that zigzags down the solid rock at the left of the galleries; the life of the place is the furnace fire and the big
## water wheel. Home makes it for area 1 when its pictures exist (available_here) and talks to it as to MineView.
## Pictures and coordinates: assets/mine/copper_mountain/ + mine.json (art/zone/export_mine2.py), source px of the
## 1536-wide stack: the sky, the surface, the depth bands.

const CDIR := "res://assets/mine/copper_mountain/"
## the surface's places in drawing order (their pictures meet at soft edges)
const CPLACES := ["wheel", "smelter", "incline", "draught", "hoist", "lapidary"]
## the depths whose job is built in the gallery itself: its stages are the band's pictures
const BAND_JOBS := {4: "arches", 8: "block", 9: "hall"}
const STAGES := ["clear", "step1", "step2", "done"]

var _mill_water: Sprite2D       # the mill's water (its own layer with the flowing shader), under the wheel
var _mill_on := -100.0    # when the water was let in (the wheel just finished)
var _fx: Node2D            # smoke and sparks over the factory (particles in the picture's own coordinates)
var _smokes := {}          # place -> its emitters
var _hold := {}            # depth -> when its crew's reaction began: the crew's loop waits while it plays

func _init() -> void:
	dir = CDIR

func available_here() -> bool:
	return FileAccess.file_exists(CDIR + "mine.json")

func _ready() -> void:
	super()
	_mill_water = Sprite2D.new()
	_mill_water.centered = false
	var wm := ShaderMaterial.new()
	wm.shader = load("res://shaders/mine_water.gdshader")
	_mill_water.material = wm
	add_child(_mill_water)
	move_child(_mill_water, live.get_index())
	_fx = Node2D.new()
	add_child(_fx)
	move_child(_fx, front.get_index())

# ---------------------------------------------------------------- state

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
	var y0 := float(J.sky) + float(J.surf)
	for k in Data.depths(a).size():
		var d := k + 1
		var st := "closed"
		if k <= open:
			st = "clear"
			if BAND_JOBS.has(d):
				st = STAGES[clampi(int(steps.get(BAND_JOBS[d], 0)), 0, 3)]
		var lived: bool = k <= open and k < wins.size() and int(wins[k]) >= 2 and J.crews.has(str(d))
		_bands.append({y = y0 + k * float(J.band), state = st, d = d, lived = lived, k = k})
	H = y0 + _bands.size() * float(J.band)
	if _set_area != a:
		_events = {}
		_next_event = 5.0
		_set_area = a
	surf.texture = tex("surface.png")
	surf.scale = Vector2.ONE / K
	# only the pines sway (their own mask): the colour test of mine_sway moved the whole gloomy factory
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/mine_sway_mask.gdshader")
	sm.set_shader_parameter("mask", tex("pine_mask.png"))
	var sr: Array = J.sway.rect
	sm.set_shader_parameter("mask_rect", Vector4(float(sr[0]), float(sr[1]), float(sr[2]), float(sr[3])))
	sm.set_shader_parameter("amp", 4.0)
	# the shader's coordinates are the layer's own: the surface sprite is in texture px (1/K), the still layer in mine px
	sm.set_shader_parameter("to_mine", 1.0 / K)
	surf.material = sm
	var stm := sm.duplicate() as ShaderMaterial
	stm.set_shader_parameter("to_mine", 1.0)
	still.material = stm
	_changes()
	if not last_result.is_empty() and int(last_result.area) == a:
		var k := clampi(int(last_result.k), 0, _bands.size() - 1)
		# the reaction starts when the crew's loop comes round to its first drawing (the working pose the reaction begins
		# and ends in), and the loop waits meanwhile and goes on from that drawing - no jump in or out
		var t0 := t + 0.7
		var v := _crew_v(k, t0)
		var ln := _loop(J.crews.get(str(int(_bands[k].d)), {}))
		t0 += (ceilf(v / ln) * ln - v) / CREW_FPS
		_hold[k] = t0
		_react = {k = k, won = bool(last_result.won), t0 = t0, iron = int(last_result.iron), ore = int(last_result.ore)}
		if focus_y < 0: focus_y = band_y(k) + float(J.band) * 0.5
		last_result = {}
	_setup_water()
	_setup_smoke()
	_make_motes()
	_find_niches()
	still.queue_redraw()
	front.queue_redraw()

## what changed since the screen was last shown: new stages come in (ink, then colour), a newly opened level shows
## through the dust, the water comes into the mill, the people of a level fade in after its second win
func _changes() -> void:
	var places := {}
	for p in CPLACES: places[p] = int(steps.get(p, 0))
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
	for p in CPLACES:
		var was := int(last.places.get(p, 0))
		var now := int(places[p])
		if now <= was:
			continue
		if focus_y < 0: focus_y = job_pos(p).y
		_shown_places[p] = was
		var at: Array = J.places[p]
		_reveal("place/%s_%d.png" % [p, now], Vector2(float(at[0]), float(at[1])), wait, func(): _shown_places[p] = now,
			"place/%s_%d.png" % [p, was] if was > 0 else "surface.png")
		if p == "wheel" and now >= 3:
			_mill_on = t + wait + 2.0
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
				_bursts.append([Vector2(560 + 260 * j, y + 330), t + wait + 0.2 + 0.12 * j])
		_reveal("band/d%d_%s.png" % [d, now], Vector2(0, y), delay, func(): _shown_bands[k] = now, "band/d%d_%s.png" % [d, was])
		if d == 9 and now == "done":
			_tremor_at = t + delay + 2.2      # the Mistress's door is open: the whole mountain shudders
	for k in lived:
		if lived[k] and not bool(last.lived.get(k, false)):
			_appear[k] = t + wait
			if focus_y < 0: focus_y = band_y(int(k)) + float(J.band) * 0.5

func job_pos(id: String) -> Vector2:
	if J.place_box.has(id):
		var bx: Array = J.place_box[id]
		return Vector2((float(bx[0]) + float(bx[2])) / 2, (float(bx[1]) + float(bx[3])) / 2)
	for d in BAND_JOBS:
		if BAND_JOBS[d] == id:
			return Vector2(1000, band_y(int(d) - 1) + 300)
	return Vector2(768, float(J.sky) + 900)

# ---------------------------------------------------------------- the still pictures

func _draw_still() -> void:
	var c := still
	for p in CPLACES:
		var s := int(_shown_places.get(p, 0))
		if s > 0:
			var at: Array = J.places[p]
			_put(c, "place/%s_%d.png" % [p, s], Vector2(float(at[0]), float(at[1])))
	for b in _bands:
		var st := String(_shown_bands.get(int(b.k), b.state))
		_put(c, "band/d%d_%s.png" % [int(b.d), st], Vector2(0, float(b.y)))
	_draw_niches(c)
	for b in _bands:
		c.draw_texture_rect(_shade, Rect2(0, float(b.y), float(J.W), 44), false)
		c.draw_rect(Rect2(0, float(b.y) - 3, float(J.W), 6), Color(0.05, 0.05, 0.045))
	_draw_bedrock(c)
	# the inclined shaft: from the portal down through the soil, then one flight per open level, zigzagging
	var sh: Dictionary = J.shaft
	var tp: Array = sh.top
	_put(c, "shaft/top.png", Vector2(float(tp[0]), float(tp[1])))
	for b in _bands:
		if int(b.k) > open:
			break
		_put(c, "shaft/flight_%d.png" % int(b.d), Vector2(0, float(b.y)))

## over the live layer: what stands in front of the turning things (the engine and railing before the flywheel)
func _draw_shaft(c: CanvasItem) -> void:
	if c == still or J.is_empty():
		return
	if int(_shown_places.get("hoist", 0)) >= 3:
		var fw: Dictionary = J.flywheel
		var fp: Array = fw.front
		_put(c, "flywheel_front.png", Vector2(float(fp[0]), float(fp[1])))

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
		c.draw_texture_rect(_glow, Rect2(Vector2(at.x - sz.x * 0.6, at.y - 10), Vector2(sz.x * 1.2, 22)), false, Color(0.1, 0.06, 0.02, 0.6))
		for dv in [Vector2(-3, 0), Vector2(3, 0), Vector2(0, -3), Vector2(0, 3), Vector2(-2, -2), Vector2(2, 2), Vector2(-2, 2), Vector2(2, -2)]:
			c.draw_texture_rect(tx, Rect2(pos + dv, sz), false, Color(0.06, 0.08, 0.06, 1.0))
		c.draw_texture_rect(tx, Rect2(pos, sz), false, Color(1.0, 0.92, 0.8))

# ---------------------------------------------------------------- water and smoke (nodes of their own)

func _setup_water() -> void:
	var wd: Dictionary = J.water
	_mill_water.texture = tex("water_back.png")
	_mill_water.scale = Vector2.ONE / K
	var at: Array = wd.back
	_mill_water.position = Vector2(float(at[0]), float(at[1]))
	var m := _mill_water.material as ShaderMaterial
	var fl: Array = wd.falls
	for i in 3:
		var r: Array = fl[i] if i < fl.size() else [0, 0, 0, 0]
		m.set_shader_parameter("falls%d" % i, Vector4(float(r[0]), float(r[1]), float(r[2]), float(r[3])))
	_mill_water.visible = int(_shown_places.get("wheel", 0)) >= 3 or _mill_on > t

func _setup_smoke() -> void:
	for ch in _fx.get_children(): ch.queue_free()
	_smokes = {}
	var sm: Dictionary = J.smoke
	for place in sm:
		var list: Array = []
		for s in sm[place]:
			var spec: Array = s           # x, y, size, warm (the smelter's smoke is lit orange from below)
			var p := CPUParticles2D.new()
			p.texture = tex("puff.png")
			p.amount = 34
			p.lifetime = 8.0
			p.preprocess = 8.0
			p.local_coords = true
			p.position = Vector2(float(spec[0]), float(spec[1]))
			p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
			p.emission_sphere_radius = 10.0 * float(spec[2])
			p.direction = Vector2(0.35, -1)
			p.spread = 12
			p.gravity = Vector2(14, -6)
			p.initial_velocity_min = 26 * float(spec[2])
			p.initial_velocity_max = 42 * float(spec[2])
			p.angular_velocity_min = -12
			p.angular_velocity_max = 12
			p.scale_amount_min = 0.7 * float(spec[2])
			p.scale_amount_max = 1.1 * float(spec[2])
			var sc := Curve.new()
			sc.add_point(Vector2(0, 0.5))
			sc.add_point(Vector2(1, 3.2))
			p.scale_amount_curve = sc
			var g := Gradient.new()
			var warm := float(spec[3])
			g.set_color(0, Color(1.0, 0.55 + 0.3 * (1 - warm), 0.3 + 0.5 * (1 - warm), 0.0))
			g.add_point(0.1, Color(1.0, 0.62 + 0.25 * (1 - warm), 0.4 + 0.4 * (1 - warm), 0.55))
			g.add_point(0.45, Color(0.42, 0.40, 0.41, 0.38))
			g.set_color(g.get_point_count() - 1, Color(0.25, 0.25, 0.28, 0.0))
			p.color_ramp = g
			_fx.add_child(p)
			list.append(p)
			if warm > 0.5:
				var sp := CPUParticles2D.new()       # sparks flying up out of the smelter's stacks
				sp.amount = 10
				sp.lifetime = 1.6
				sp.preprocess = 2.0
				sp.local_coords = true
				sp.texture = _glow
				sp.position = p.position
				sp.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
				sp.emission_sphere_radius = 12.0
				sp.direction = Vector2(0.2, -1)
				sp.spread = 25
				sp.gravity = Vector2(0, 30)
				sp.initial_velocity_min = 80
				sp.initial_velocity_max = 160
				sp.scale_amount_min = 0.03
				sp.scale_amount_max = 0.06
				var sg := Gradient.new()
				sg.set_color(0, Color(1.4, 1.0, 0.5, 1.0))
				sg.set_color(1, Color(1.0, 0.4, 0.1, 0.0))
				sp.color_ramp = sg
				_fx.add_child(sp)
				list.append(sp)
		_smokes[place] = list
	_update_smoke()

func _update_smoke() -> void:
	for place in _smokes:
		var on := int(_shown_places.get(place, 0)) >= (2 if place == "draught" else 3)
		for p in _smokes[place]:
			(p as CPUParticles2D).emitting = on

# ---------------------------------------------------------------- the live layer

func _process(delta: float) -> void:
	super(delta)
	if not visible or J.is_empty():
		return
	front.queue_redraw()
	var won := int(_shown_places.get("wheel", 0)) >= 3
	_mill_water.visible = won or t > _mill_on
	var m := _mill_water.material as ShaderMaterial
	m.set_shader_parameter("on", clampf((t - _mill_on) / 2.5, 0.0, 1.0) if t - _mill_on < 3.0 else (1.0 if won or _mill_on > 0 else 0.0))
	if Engine.get_process_frames() % 20 == 0:
		_update_smoke()

## the crowned lizard runs along the wall to a crack drawn in it, in darts, freezing between them, and slips into its
## black inside (the inside is its own layer over her, and what stands in front of the wall there too); the crack's
## lips glint green after. Drawn before the crews: people in the gallery stand in front of the wall she is on
func _lizard_live(c: CanvasItem) -> void:
	if not _events.has("lizard"):
		return
	var s := t - float(_events["lizard"])
	var cr: Dictionary = _events.get("lizard_at", {})
	if cr.is_empty() or s > 5.5 or s < 0.0:
		return
	var y := band_y(int(cr.d) - 1)
	var to := Vector2(float(cr.to[0]), y + float(cr.to[1]))
	var from := Vector2(float(cr.from[0]), y + float(cr.from[1]))
	var dv := Vector2(float(cr.dir[0]), float(cr.dir[1]))
	var p := from
	var moving := false
	var ang := (to - from).angle() + PI / 2
	for j in 3:
		var a0 := j * 0.9
		if s >= a0 + 0.45: p = from.lerp(to, (j + 1) / 3.0)
		elif s >= a0:
			p = from.lerp(to, (j + (s - a0) / 0.45) / 3.0)
			moving = true
	if s >= 2.7:
		var q := clampf((s - 2.7) / 0.6, 0.0, 1.0)
		p = to + dv * float(cr.get("into", 70)) * q
		moving = q < 1.0
		ang = dv.angle() + PI / 2
	if s < 3.4:
		var fr := "lizard/%02d.png" % ((int(t * 16) % 8) if moving else 0)
		var ls := _size(fr) * 0.85
		c.draw_set_transform(p, ang, Vector2.ONE)
		for o in [Vector2(-1.5, 0), Vector2(1.5, 0), Vector2(0, -1.5), Vector2(0, 1.5)]:
			c.draw_texture_rect(tex(fr), Rect2(-ls / 2 + o, ls), false, Color(0.02, 0.03, 0.02, 0.8))
		c.draw_texture_rect(tex(fr), Rect2(-ls / 2, ls), false)
		c.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		var mk: Array = cr.mask
		_put(c, "crack_%d.png" % int(cr.d), Vector2(float(mk[0]), y + float(mk[1])))
		if cr.has("front"):
			var fp: Array = cr.front
			_put(c, "crack_front_%d.png" % int(cr.d), Vector2(float(fp[0]), y + float(fp[1])))
	if s > 3.0:
		_light(c, to + dv * 30.0, 45, Color(0.3, 1.0, 0.45, 0.45 * clampf(1.0 - (s - 3.0) / 2.5, 0.0, 1.0)))

func _draw_live() -> void:
	var c := live
	_lights(c)
	_surface_live(c)
	_flags(c)
	_shaft_cart(c)
	_lizard_live(c)
	for b in _bands:
		if _band_seen(b): _band_live(c, b)
	_events_live(c)
	_ore_flight(c)
	_finale(c)
	for bu in _bursts.duplicate():
		if t < float(bu[1]):
			continue
		var i := int((t - float(bu[1])) * 12)
		if i >= 8:
			_bursts.erase(bu)
			continue
		var p := "burst/%02d.png" % i   # this mine's dust frames are 00..07
		var sz := _size(p) * 1.6
		var at: Vector2 = bu[0]
		c.draw_texture_rect(tex(p), Rect2(at - sz / 2, sz), false)

func _lights(c: CanvasItem) -> void:
	for st in _stars:
		if float(st[1]) > float(J.sky) + 200:
			continue
		var v := 0.5 + 0.5 * sin(t * float(st[3]) + float(st[2]))
		if v > 0.55:
			c.draw_rect(Rect2(float(st[0]), float(st[1]), 3, 3), Color(0.8, 0.85, 1.0, v * 0.7))
	_sky(c)
	var sl: Dictionary = J.surface_lamps
	var i := 0
	for place in sl:
		if place != "portal" and int(_shown_places.get(place, 0)) < 3:
			continue
		for l in sl[place]:
			i += 1
			var col := Color(1.0, 0.72, 0.35, 0.33 * _flick(i))
			if l.size() > 3: col = Color(String(l[3]))
			col.a *= _flick(i)
			_light(c, Vector2(float(l[0]), float(l[1])), 70 * float(l[2]), col)
	for b in _bands:
		var k := int(b.k)
		if String(_shown_bands.get(k, b.state)) == "closed" or not _band_seen(b):
			continue
		for l in J.lamps.get(str(int(b.d)), []):
			_light(c, Vector2(float(l[0]), float(b.y) + float(l[1])), 150, Color(1.0, 0.7, 0.32, 0.28 * _flick(k * 3)))

const MOON_CYCLE := 38.0    # s: now and then a ragged cloud drifts over the moon
const TOWER_CYCLE := 27.0   # s: a candle climbs the leaning tower, the bell strikes, the birds fly up

## the sky over the works: the moon's halo breathes and dims when a cloud crosses it; in the leaning tower of Nevyansk
## (the Demidovs' tower, its secrets in the Ural tales) a candle climbs from window to window to the belfry, the bell
## strikes - rings of light, a far toll - and the birds start up from the belfry and circle the spire
func _sky(c: CanvasItem) -> void:
	if not J.has("moon"):
		return
	var mo: Array = J.moon
	var mc := Vector2(float(mo[0]), float(mo[1]))
	var mr := float(mo[2])
	# the cloud: dark puffs in a ragged line, from left to right across the disc
	var u := fmod(t + 9.0, MOON_CYCLE)
	var cover := 0.0
	var cx := lerpf(mc.x - mr * 9.0, mc.x + mr * 9.0, u / 14.0) if u < 14.0 else 1e9
	if u < 14.0:
		cover = 0.7 * clampf(1.0 - absf(cx - mc.x) / (mr * 4.0), 0.0, 1.0)
	_light(c, mc, mr * 5.0, Color(0.75, 0.82, 1.0, (0.16 + 0.04 * sin(t * 0.7)) * (1.0 - 0.75 * cover)))
	_light(c, mc, mr * 2.2, Color(0.85, 0.9, 1.0, 0.18 * (1.0 - 0.8 * cover)))
	if u < 14.0:
		# a thin ragged wisp in the colour of the painted clouds (not a dark blot): many small soft puffs, thicker in the
		# middle, fading in and out at the ends of its way
		var ps := _size("puff.png")
		var edge := clampf(minf(u, 14.0 - u) / 2.5, 0.0, 1.0)
		for i in 15:
			var q := (i - 7) / 7.0
			var off := Vector2(q * mr * 4.2, sin(i * 2.3) * mr * 0.35 + q * q * mr * 0.4)
			var sc := (1.0 - 0.55 * q * q) * (0.9 + 0.3 * sin(i * 1.7)) * mr * 1.5 / ps.x
			var at := Vector2(cx, mc.y) + off
			c.draw_texture_rect(tex("puff.png"), Rect2(at - ps * sc / 2, ps * sc), false, Color(0.17, 0.21, 0.28, 0.42 * edge))
		# its rim catches the moonlight
		_light(c, Vector2(cx, mc.y - mr * 0.6), mr * 2.4, Color(0.7, 0.78, 0.95, 0.14 * cover))
	if not J.has("tower"):
		return
	var tw: Dictionary = J.tower
	var v := fmod(t + 4.0, TOWER_CYCLE)
	var wins: Array = tw.windows
	# the candle: 2 s at each window, going out behind one and showing at the next
	var step := int(v / 2.2)
	if step < wins.size():
		var w: Array = wins[step]
		var f := clampf(1.0 - absf(fmod(v, 2.2) - 1.1) / 1.1, 0.0, 1.0)
		var wp := Vector2(float(w[0]), float(w[1]))
		_light(c, wp, 26, Color(1.0, 0.72, 0.35, 0.75 * f * _flick(40)))
		c.draw_rect(Rect2(wp - Vector2(2, 3), Vector2(4, 6)), Color(1.0, 0.8, 0.45, 0.9 * f))
	var b: Array = tw.belfry
	var bp := Vector2(float(b[0]), float(b[1]))
	var bs := v - wins.size() * 2.2          # seconds since the candle reached the belfry
	if bs >= 0.0 and bs < 6.0:
		# the bell: three strikes, a ring of pale light from the belfry at each
		for k in 3:
			var r := bs - k * 1.6
			if r >= 0.0 and r < 1.6:
				var q := r / 1.6
				c.draw_arc(bp, 10.0 + q * 70.0, 0, TAU, 40, Color(1.0, 0.85, 0.55, 0.35 * (1.0 - q)), 2.0)
			if _passed("bell%d" % k, bs, 100.0, k * 1.6):
				CopperSounds.bell(amb, _far(bp.y))
		_light(c, bp, 34, Color(1.0, 0.75, 0.4, 0.5 * clampf(1.0 - bs / 6.0, 0.0, 1.0)))
	# the birds start at the first strike: up from the belfry, twice round the spire, then away over the ridge
	if bs >= 0.0 and bs < 12.0:
		var sp: Array = tw.spire
		var spc := Vector2(float(sp[0]), float(sp[1]))
		for k in 5:
			var ph := k * 0.9 + bs * 1.1
			var away := clampf((bs - 7.0) / 5.0, 0.0, 1.0)
			var rise := clampf(bs / 1.2, 0.0, 1.0)
			var p := bp.lerp(spc + Vector2(cos(ph) * (60 + k * 8), sin(ph) * 22 - 18 - k * 4), rise)
			p += Vector2(away * (420 + k * 40), -away * (160 + k * 15))
			var flap := sin(t * 14.0 + k * 1.3)
			var col := Color(0.04, 0.05, 0.07, 0.9 * (1.0 - away * 0.6))
			c.draw_polyline(PackedVector2Array([p + Vector2(-7, -4 * flap), p, p + Vector2(7, -4 * flap)]), col, 2.0)

## the factory alive: the wheel turning in the falling water, the hoisting engine's flywheel, the fire in the smelter
## and the stack, the cart on the incline, the green windows of the lapidary, the people and the animals
func _surface_live(c: CanvasItem) -> void:
	var sky := float(J.sky)
	if int(_shown_places.get("wheel", 0)) >= 3:
		_water_wheel(c, -TAU * float(J.wheel.rate) * t)
		var fo: Array = J.water.foam
		_put(c, "water_foam.png", Vector2(float(fo[0]), float(fo[1])), false, 0.85 + 0.15 * sin(t * 9.0))
	if int(_shown_places.get("hoist", 0)) >= 3:
		var fw: Dictionary = J.flywheel
		var fc: Array = fw.c
		_put_rot(c, "flywheel.png", Vector2(float(fc[0]), float(fc[1])), t * TAU * float(fw.rate), Vector2.ONE * 2.0 * float(fw.r))
		# a puff of steam from the engine every turn
		var pu := fmod(t * float(fw.rate), 1.0)
		if pu < 0.5:
			var sp: Array = fw.steam
			var ps := _size("puff.png") * (0.3 + pu * 0.8)
			c.draw_texture_rect(tex("puff.png"), Rect2(Vector2(float(sp[0]) + pu * 40, float(sp[1]) - pu * 90) - ps / 2, ps), false, Color(0.9, 0.9, 0.92, 0.7 * (1.0 - pu * 2.0)))
	var sm: Dictionary = J.smelter
	if int(_shown_places.get("smelter", 0)) >= 2:
		var mo: Array = sm.mouth
		var fl := "flame/%02d.png" % (int(t * 10) % int(J.crew_n.get("flame", 1)))
		if _crew_ok("flame"):
			c.draw_texture_rect(tex(fl), Rect2(float(mo[0]), float(mo[1]), float(mo[2]), float(mo[3])), false, Color(1, 1, 1, 0.9))
		_light(c, Vector2(float(mo[0]) + float(mo[2]) / 2, float(mo[1]) + float(mo[3]) * 0.7), 260, Color(1.0, 0.5, 0.15, 0.35 * _flick(31)))
	if int(_shown_places.get("draught", 0)) >= 2:
		var dr: Array = J.draught.door
		_light(c, Vector2(float(dr[0]), float(dr[1])), 70, Color(1.0, 0.5, 0.15, 0.45 * _flick(32)))
	if int(_shown_places.get("lapidary", 0)) >= 3:
		# the shadow of the crowned lizard runs inside the green room: behind the stone piers and the vases (the front of
		# the window strip is its own layer over it), so it goes from window to window and away, not out of thin air
		if _events.has("window"):
			var s := t - float(_events["window"])
			var run: Array = J.lapidary.run
			var p := Vector2(float(run[0][0]), float(run[0][1])).lerp(Vector2(float(run[1][0]), float(run[1][1])), clampf(s / 3.2, 0.0, 1.0))
			p.y += 6.0 * sin(s * 9.0)
			var fr := "lizard/%02d.png" % (int(t * 16) % 8)
			var ls := _size(fr) * 1.7
			c.draw_set_transform(p, PI / 2, Vector2.ONE)
			c.draw_texture_rect(tex(fr), Rect2(-ls / 2, ls), false, Color(0.02, 0.07, 0.04, 0.95))
			c.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		var lf: Array = J.lapidary.front
		_put(c, "lapidary_front.png", Vector2(float(lf[0]), float(lf[1])))
		var gl := 0.75 + 0.25 * sin(t * 0.8)
		for w in J.lapidary.windows:
			var r: Array = w
			_light(c, Vector2(float(r[0]), float(r[1])), float(r[2]), Color(0.35, 1.0, 0.5, 0.20 * gl))
	if int(_shown_places.get("incline", 0)) >= 3:
		_incline_cart(c)
		# the rails run behind the draught stack: the stack again over the cart
		var sf: Array = J.stack_front
		_put(c, "stack_front.png", Vector2(float(sf[0]), float(sf[1])))
	# people and animals of the finished places
	for a in J.life:
		var spec: Dictionary = a
		# the guide is always there (he talks to a newcomer); the others come with their places
		if (String(spec.name) != "guide24" and int(_shown_places.get(String(spec.place), 0)) < 3) or not _crew_ok(String(spec.name)):
			continue
		var nm := String(spec.name)
		var n := int(J.crew_n[nm])
		var ph := float(spec.get("ph", 0))
		var x := float(spec.x)
		var flip := bool(spec.get("flip", false))
		if spec.has("roam"):
			var per := float(spec.roam[1])
			var ru := fmod(t + ph, per) / per
			x += float(spec.roam[0]) * (0.5 - 0.5 * cos(TAU * ru))
			flip = (ru > 0.5) != flip
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

## the water wheel stands at an angle: its flat drawing turned, then squashed into the ellipse of the picture; the
## drum behind it is the rim drawn again along the depth, darker towards the back
func _water_wheel(c: CanvasItem, ang: float) -> void:
	var w: Dictionary = J.wheel
	var ctr := Vector2(float(w.c[0]), float(w.c[1]))
	var dv := Vector2(float(w.depth[0]), float(w.depth[1]))
	var n := int(w.layers)
	var tx := tex("wheel.png")
	var rim := tex("wheel_rim.png")
	var sz := tx.get_size()
	var sc := Vector2(2.0 * float(w.rx) / sz.x, 2.0 * float(w.ry) / sz.y)
	for i in range(n, -1, -1):
		var k := float(i) / n
		var T := Transform2D(0.0, sc, 0.0, ctr + dv * k) * Transform2D(ang, Vector2.ZERO)
		c.draw_set_transform_matrix(T)
		if i == n:
			c.draw_texture(tx, -sz / 2, Color(0.45, 0.45, 0.45))
		elif i == 0:
			c.draw_texture(tx, -sz / 2)
		else:
			var v := 0.55 + 0.4 * (1.0 - k)
			c.draw_texture(rim, -sz / 2, Color(v, v, v))
	c.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

## the incline railway: a cart rides the track's rail (a polyline measured on the picture) up to the winch house and
## back; at the bends its tilt turns smoothly. The draught stack is drawn again over it (the track runs behind it)
func _incline_cart(c: CanvasItem) -> void:
	var inc: Dictionary = J.incline
	var pts: Array[Vector2] = []
	for v in inc.path: pts.append(Vector2(float(v[0]), float(v[1])))
	var u := fmod(t, 16.0)
	var q := 0.0
	if u < 6.0: q = 0.5 - 0.5 * cos(PI * u / 6.0)
	elif u < 8.0: q = 1.0
	elif u < 14.0: q = 0.5 + 0.5 * cos(PI * (u - 8.0) / 6.0)
	var lens: Array[float] = []
	var total := 0.0
	for i in pts.size() - 1:
		lens.append((pts[i + 1] - pts[i]).length())
		total += lens[i]
	var d := q * total
	var i := 0
	while i < lens.size() - 1 and d > lens[i]:
		d -= lens[i]
		i += 1
	var p := pts[i].lerp(pts[i + 1], clampf(d / lens[i], 0.0, 1.0))
	var ang := (pts[i + 1] - pts[i]).angle()
	const EASE := 18.0      # px either side of a bend over which the tilt turns
	if i > 0 and d < EASE:
		ang = lerp_angle((pts[i] - pts[i - 1]).angle(), ang, 0.5 + 0.5 * d / EASE)
	elif i < lens.size() - 1 and lens[i] - d < EASE:
		ang = lerp_angle(ang, (pts[i + 2] - pts[i + 1]).angle(), 0.5 - 0.5 * (lens[i] - d) / EASE)
	var cs := _size("cart_full.png") * float(inc.get("s", 0.34))
	c.draw_line(p, pts[pts.size() - 1], Color(0.45, 0.38, 0.28, 0.8), 1.5)     # the rope up to the winch
	c.draw_set_transform(p, ang, Vector2.ONE)
	c.draw_texture_rect(tex("cart_full.png" if u < 7.0 else "cart_empty.png"), Rect2(Vector2(-cs.x / 2, -cs.y + 2), cs), false)
	c.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

## the hoist's bucket conveyor in the inclined shaft: one chain loop per flight (and one through the cut of soil), between a
## pulley at its top and one at its bottom; full buckets ride up the floor side, empty ones come down the other
const CONV_R := 20.0       # px: the pulleys' radius = half the gap between the runs
const CONV_GAP := 44.0     # px between buckets along the chain
const CONV_B := 2.1        # the buckets' size
const CONV_V := 30.0       # px/s
const CONV_PH := 0.37      # a conveyor's buckets this share of a gap behind the one above
func _shaft_cart(c: CanvasItem) -> void:
	if int(_shown_places.get("hoist", 0)) < 3:
		return
	var runs := _conv_runs()
	for i in runs.size():
		_conveyor(c, runs[i][0], runs[i][1], i)

## the conveyors' top and bottom pulleys: the cut of soil, then each open level's flight
func _conv_runs() -> Array:
	var tp: Array = J.shaft.path_top
	var runs: Array = [[tp[tp.size() - 2], tp[tp.size() - 1], 0.0]]
	for b in _bands:
		if int(b.k) > open:
			break
		var fl: Array = J.shaft.path[str(int(b.d))]
		runs.append([fl[0], fl[1], float(b.y)])
	var out: Array = []
	for r in runs:
		var p0: Array = r[0]
		var p1: Array = r[1]
		var oy := float(r[2])
		# the rails run 32 px to the floor side of the flight's axis (left of it going down-right, right of it on the
		# mirrored flights going down-left); the conveyor stands on the axis
		var ax := 32.0 * signf(float(p1[0]) - float(p0[0]))
		out.append([Vector2(float(p0[0]) + ax, oy + float(p0[1]) + CONV_R + 6.0),
			Vector2(float(p1[0]) + ax, oy + float(p1[1]) - CONV_R - 6.0)])
	return out

## the conveyor's sounds, as the buckets pass the pulleys: a clank of chain as one goes round the bottom and scoops,
## the rattle of ore as one tips out over the top; the conveyors near the middle of the screen, the rest too far
func _conv_sounds() -> void:
	var runs := _conv_runs()
	var near: Array = []                                # the two conveyors nearest the middle of the screen
	var by: Array = []
	for i in runs.size():
		by.append([-_far((runs[i][0].y + runs[i][1].y) / 2.0), i])
	by.sort()
	for j in mini(2, by.size()): near.append(by[j][1])
	for i in runs.size():
		var top: Vector2 = runs[i][0]
		var bot: Vector2 = runs[i][1]
		var l := (bot - top).length()
		var per := 2.0 * l + TAU * CONV_R
		var gap := per / maxi(2, roundi(per / CONV_GAP))
		var v := t * CONV_V / gap + i * CONV_PH
		var scoop := fmod(l + 0.6 * PI * CONV_R, gap) / gap
		var pour := fmod(2.0 * l + 1.4 * PI * CONV_R, gap) / gap
		var fb := _far(bot.y)
		var ft := _far(top.y)
		if near.find(i) < 0:
			continue
		if _passed("conv_c%d" % i, v, 1.0, scoop) and fb > -9.0:
			amb.shot("copper/clank_%d" % (randi() % 3), -24.0 + fb, randf_range(0.9, 1.08))
		if _passed("conv_p%d" % i, v, 1.0, pour) and ft > -9.0:
			amb.shot("copper/pour_%d" % (randi() % 3), -21.0 + ft, randf_range(0.92, 1.08))

func _conveyor(c: CanvasItem, top: Vector2, bot: Vector2, idx: int) -> void:
	var ax := (bot - top)
	var l := ax.length()
	var dn := ax / l                                   # down the flight
	var side := Vector2(-dn.y, dn.x)                   # perpendicular
	if side.y < 0: side = -side                        # the floor side (below the axis)
	var per := 2.0 * l + TAU * CONV_R
	var iron := Color(0.11, 0.09, 0.075)
	# the chain: the up run on the floor side, the down run above it, around the two pulleys
	c.draw_line(top + side * CONV_R, bot + side * CONV_R, iron, 6.0)
	c.draw_line(top - side * CONV_R, bot - side * CONV_R, iron, 6.0)
	c.draw_line(top + side * CONV_R, bot + side * CONV_R, Color(0.42, 0.3, 0.2), 2.2)
	c.draw_line(top - side * CONV_R, bot - side * CONV_R, Color(0.42, 0.3, 0.2), 2.2)
	# the pulleys turn with the chain: clockwise on screen where the up run is on the left
	var ang := t * CONV_V / CONV_R * signf(dn.cross(side))
	for at in [top, bot]:
		c.draw_circle(at, CONV_R + 5.0, iron)
		c.draw_circle(at, CONV_R - 1.0, Color(0.36, 0.25, 0.16))
		c.draw_circle(at, CONV_R - 7.0, Color(0.16, 0.12, 0.09))
		for k in 4:
			var sp := Vector2.from_angle(ang + k * PI / 2.0) * (CONV_R - 2.5)
			c.draw_line(at - sp, at + sp, Color(0.4, 0.28, 0.18), 3.0)
		c.draw_circle(at, 5.0, Color(0.62, 0.45, 0.27))
	# the buckets, fixed to the chain with their mouths outward
	var n := maxi(2, roundi(per / CONV_GAP))           # a whole number of buckets round the loop: even gaps
	var gap := per / n
	var sh := fmod(t * CONV_V + idx * CONV_PH * gap, gap)    # each conveyor in its own step: they don't clank as one
	for i in n:
		var s := fmod(i * gap + sh, per)
		var pos: Vector2
		var out: Vector2
		var full := 0.0
		if s < l:                                      # the down run (upper side): empty, top to bottom
			pos = top - side * CONV_R + dn * s
			out = -side
		elif s < l + PI * CONV_R:                      # round the bottom pulley
			var a := (s - l) / CONV_R
			out = -side * cos(a) + dn * sin(a)
			pos = bot + out * CONV_R
			full = smoothstep(PI * 0.45, PI * 0.85, a)     # scooping up at the bottom
		elif s < 2.0 * l + PI * CONV_R:                # the up run (floor side): full, bottom to top
			pos = bot + side * CONV_R - dn * (s - l - PI * CONV_R)
			out = side
			full = 1.0
		else:                                          # round the top pulley, where it tips its ore
			var a := (s - 2.0 * l - PI * CONV_R) / CONV_R
			out = side * cos(a) - dn * sin(a)
			pos = top + out * CONV_R
			full = 1.0 - smoothstep(PI * 0.25, PI * 0.6, a)   # tipping it out over the top
		_bucket(c, pos, out, full)

func _bucket(c: CanvasItem, at: Vector2, out: Vector2, full: float) -> void:
	var w := out.orthogonal() * CONV_B
	out = out * CONV_B
	var base := at + out * 2.0
	var poly := PackedVector2Array([base - w * 5.0, base + w * 5.0, base + w * 8.0 + out * 10.0, base - w * 8.0 + out * 10.0])
	var edge := PackedVector2Array([base - w * 6.5, base + w * 6.5, base + w * 9.5 + out * 11.5, base - w * 9.5 + out * 11.5])
	c.draw_colored_polygon(edge, Color(0.09, 0.07, 0.06))
	c.draw_colored_polygon(poly, Color(0.45, 0.29, 0.17))
	c.draw_line(base - w * 8.0 + out * 9.5, base + w * 8.0 + out * 9.5, Color(0.78, 0.55, 0.3), 2.6)
	c.draw_line(at, base, Color(0.11, 0.09, 0.075), 4.0)
	if full > 0.02:
		c.draw_circle(base + out * 10.5 - w * 3.5, 3.2 * CONV_B * full, Color(0.22, 0.52, 0.4))
		c.draw_circle(base + out * 11.0 + w * 2.0, 3.6 * CONV_B * full, Color(0.72, 0.4, 0.18))
		c.draw_circle(base + out * 12.0 - w * 0.5, 2.6 * CONV_B * full, Color(0.3, 0.66, 0.5))

func _band_live(c: CanvasItem, b: Dictionary) -> void:
	var k := int(b.k)
	var y := float(b.y)
	var st := String(_shown_bands.get(k, b.state))
	if st == "closed":
		return
	var d := int(b.d)
	var floor_y := y + floor_of(d)
	# the pump rods of the wet level go up and down once the wheel drives them
	if J.has("pump") and J.pump.has(str(d)) and int(_shown_places.get("wheel", 0)) >= 3:
		var pr: Array = J.pump[str(d)]
		var dy := 6.0 * sin(t * TAU * absf(float(J.wheel.rate)) * 2.0)
		c.draw_line(Vector2(float(pr[0]), y + float(pr[1]) + dy), Vector2(float(pr[0]), y + float(pr[2]) + dy), Color(0.16, 0.13, 0.1), 7)
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
	var p := "%s/%02d.png" % [who, _crew_frame(cr, k)]
	var rx := _reaction_frame(who, k)
	if rx != "":
		p = rx
	var sz := _size(p)
	if cr.has("pet") and _crew_ok(String(cr.pet[0])):
		var pn := String(cr.pet[0])
		var pp := "%s/%02d.png" % [pn, int(t * 7.0) % int(J.crew_n[pn])]
		var psz := _size(pp)
		_put(c, pp, Vector2(float(cr.pet[1]) - psz.x / 2, floor_y - psz.y + 4), bool(cr.get("pet_flip", false)), al)
	_put(c, p, Vector2(x - sz.x / 2, floor_y - sz.y + 4), flip, al)
	if cr.has("spark") and _crew_frame(cr, k) in [int(cr.hit), int(cr.hit) + 1]:
		var sp: Array = cr.spark
		_light(c, Vector2(x + float(sp[0]) * (-1.0 if flip else 1.0), floor_y + float(sp[1])), 40, Color(1.0, 0.7, 0.3, 0.6 * al))

# ---------------------------------------------------------------- the Mistress about the place

func _tick_events() -> void:
	if force_event != "" and t > 0.5:
		# lizard, or lizard2 / lizard5 / lizard7: to the crack of that depth
		if force_event.begins_with("lizard"):
			var want := force_event.trim_prefix("lizard")
			_events["lizard"] = t
			_events["lizard_at"] = J.cracks[0]
			for cr in J.cracks:
				if str(int(cr.d)) == want: _events["lizard_at"] = cr
		else:
			_events[force_event] = t
		force_event = ""
	if t < _next_event:
		return
	_next_event = t + _rng.randf_range(10.0, 16.0)
	var pool := []
	for cr in J.cracks:
		var k := int(cr.d) - 1
		if k <= open and String(_shown_bands.get(k, "closed")) != "closed":
			pool.append("lizard")
			break
	if int(_shown_places.get("wheel", 0)) >= 3:
		pool.append("reflection")
	if int(_shown_places.get("lapidary", 0)) >= 3:
		pool.append("window")
	if J.has("hotcrack") and open >= int(J.hotcrack.d) - 1:
		pool.append("brine")
	if pool.is_empty():
		return
	var ev: String = pool[_rng.randi() % pool.size()]
	_events[ev] = t
	if ev == "lizard":
		var cand: Array = []
		for cr in J.cracks:
			if int(cr.d) - 1 <= open and String(_shown_bands.get(int(cr.d) - 1, "closed")) != "closed":
				cand.append(cr)
		_events["lizard_at"] = cand[_rng.randi() % cand.size()]

func _events_live(c: CanvasItem) -> void:
	for ev in _events.keys():
		if ev == "lizard_at":
			continue
		var s := t - float(_events[ev])
		var done := false
		match ev:
			"lizard":
				# drawn behind the crews (_lizard_live, before the bands' people); here only its end
				if _events.get("lizard_at", {}).is_empty() or s > 5.5:
					done = true
			"reflection":
				# in the curtain of the waterfall: a woman in green, for a moment
				var rf: Array = J.water.reflection
				var a := sin(PI * clampf(s / 5.0, 0.0, 1.0))
				if s > 5.0: done = true
				else:
					var rs := _size("reflection.png")
					# her face is cut by the falls' water already: only a breath of a sway, so she stays inside it
					var wob := Vector2(sin(t * 2.3) * 1.0, 0)
					c.draw_texture_rect(tex("reflection.png"), Rect2(Vector2(float(rf[0]), float(rf[1])) - rs / 2 + wob, rs), false, Color(1, 1, 1, 0.6 * a))
			"window":
				# drawn with the lapidary (_surface_live), under the front of its windows
				if s > 3.4: done = true
			"brine":
				# the next mine is the Kraken's sea: under the great block the rock weeps - salt water wells out of a crack,
				# glows a cold sea-cyan for a moment, runs down in streaks and drips, and the crack dries dark again
				if s > 7.0: done = true
				else:
					_brine(c, band_y(7), s)
			"hotcrack":
				# the next mine's heart of fire: a crack opens in the deepest rock, heat runs along it, embers and steam
				# rise, then it cools to a dark scar and closes
				var hc: Dictionary = J.hotcrack
				if s > 7.0: done = true
				else:
					_hot_crack(c, Vector2(float(hc.x), band_y(int(hc.d) - 1) + float(hc.y)), s)
		if done:
			_events.erase(ev)

## after a win the level's ore flies down into the depth it came from: lumps of copper and malachite (this mine's ore) and
## of iron, tumbling in arcs with a short trail; where each lands, a puff of dust and a glint of its colour
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
	var cr: Dictionary = J.crews.get(str(k + 1), {}) if J.has("crews") else {}
	var w: Array = cr.get("work", ["pick", 760, ""])
	var to := Vector2(float(w[1]) if w.size() > 1 else 700.0, band_y(k) + floor_of(k + 1) - 40)
	var from := Vector2(1240, -position.y / scale.y + 40)  # the header's ore counters, top right
	var n_ore := mini(int(_react.ore), 10)
	var n_iron := mini(int(_react.iron), 8)
	for i in n_ore + n_iron:
		var u := (s - 0.4 - i * 0.09) / 0.9
		if u < 0.0 or u > 1.4:
			continue
		var kind := 2 if i >= n_ore else i % 2          # 0 copper, 1 malachite, 2 iron
		var tgt := to + Vector2((i % 5 - 2) * 34 + sin(i * 2.3) * 10, (i % 3) * 8)
		if u <= 1.0:
			for tr in 3:                                # the trail: where it was a moment ago
				var ut := u - (tr + 1) * 0.035
				if ut > 0.0:
					c.draw_circle(_ore_at(from, tgt, ut, i), 18.0 - tr * 5.0, Color(_ore_glow(kind), 0.28 - tr * 0.08))
			_lump(c, _ore_at(from, tgt, u, i), 34.0, kind, i, t * (3.0 + (i % 3)) * (1 if i % 2 == 0 else -1))
		else:
			var f := (u - 1.0) / 0.4
			_light(c, tgt, 60 + 70 * f, Color(_ore_glow(kind), 0.6 * (1.0 - f)))
			for d in 5:                                 # dust kicked up where it lands
				var dv := Vector2.from_angle(PI + PI * (d + 0.5) / 5.0) * (16 + 60 * f)
				c.draw_circle(tgt + dv + Vector2(0, -6 * f), 9.0 * (1.0 - f) + 3.0, Color(0.42, 0.36, 0.3, 0.5 * (1.0 - f)))
			_lump(c, tgt + Vector2(0, -8), 34.0 * (1.0 - smoothstep(0.5, 1.0, f)), kind, i, 0.0)
		if _passed("ore%d" % i, u, 1.0, 1.0):
			amb.shot("coin", -10.0, 1.2 + (i % 4) * 0.05)

func _ore_at(from: Vector2, tgt: Vector2, u: float, i: int) -> Vector2:
	var e := u * u * (3.0 - 2.0 * u)
	return from.lerp(tgt, e) + Vector2(sin(i * 1.7) * 160 * sin(PI * u), -220 * sin(PI * u))

func _ore_glow(kind: int) -> Color:
	var g: Array = [Color(1.0, 0.55, 0.22), Color(0.35, 1.0, 0.6), Color(0.75, 0.85, 1.0)]
	return g[kind]

## a lump of ore: a knobbly stone with an ink outline, a lit face and, by kind, copper's shine, malachite's bands or
## iron's dark cube
func _lump(c: CanvasItem, at: Vector2, r: float, kind: int, seed: int, spin: float) -> void:
	if r < 1.0:
		return
	var pts := PackedVector2Array()
	var rim := PackedVector2Array()
	var face := PackedVector2Array()
	for j in 7:
		var a := spin + TAU * j / 7.0
		var rr := r * (0.78 + 0.22 * absf(sin(seed * 3.1 + j * 1.9)))
		pts.append(at + Vector2.from_angle(a) * rr)
		rim.append(at + Vector2.from_angle(a) * (rr + 5.0))
		face.append(at + Vector2(-0.22, -0.26) * r + Vector2.from_angle(a) * rr * 0.55)
	var bases: Array = [Color(0.62, 0.32, 0.14), Color(0.13, 0.47, 0.33), Color(0.33, 0.34, 0.37)]
	var lits: Array = [Color(0.95, 0.6, 0.3), Color(0.33, 0.78, 0.55), Color(0.62, 0.66, 0.72)]
	c.draw_colored_polygon(rim, Color(0.07, 0.05, 0.04))
	c.draw_colored_polygon(pts, bases[kind])
	c.draw_colored_polygon(face, lits[kind])
	if kind == 1:                                       # malachite's dark bands
		for b in 2:
			var bc := at + Vector2.from_angle(spin + seed) * r * 0.9
			c.draw_arc(bc, r * (0.6 + 0.35 * b), spin + seed + PI * 0.75, spin + seed + PI * 1.25, 6, Color(0.05, 0.25, 0.17), 4.0)
	elif kind == 0:                                     # copper's bright speck
		c.draw_circle(at + Vector2(-0.3, -0.35) * r, r * 0.16, Color(1.0, 0.86, 0.6))
	else:
		c.draw_rect(Rect2(at + Vector2(0.05, -0.1) * r, Vector2(r, r) * 0.42), Color(0.16, 0.17, 0.2))
		c.draw_line(at + Vector2(0.05, -0.1) * r, at + Vector2(0.47, -0.1) * r, Color(0.85, 0.9, 1.0), 3.0)

var _crack_pts: Array = []   # the hot crack's lines (main + branches), made once

func _hot_crack(c: CanvasItem, at: Vector2, s: float) -> void:
	if _crack_pts.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.seed = 41
		var main := PackedVector2Array([Vector2(-230, -6)])
		for j in 14:                                    # left to right, jagged, a little lower in the middle
			var x := -230.0 + 460.0 * (j + 1) / 14.0
			main.append(Vector2(x + rng.randf_range(-8, 8), rng.randf_range(-16, 16) + 10.0 * cos(x / 230.0 * PI * 0.5)))
		_crack_pts.append(main)
		for st in [3, 7, 11]:                           # branches down, toward the fire below
			var br := PackedVector2Array([main[st]])
			var dx := rng.randf_range(-1, 1)
			for j in 4:
				br.append(br[j] + Vector2(dx * 18 + rng.randf_range(-10, 10), rng.randf_range(-16, -9) if st == 7 else rng.randf_range(7, 12)))
			_crack_pts.append(br)
	var open_ := clampf(s / 1.2, 0.0, 1.0)              # how far it has opened along its length
	var heat := clampf(s / 1.0, 0.0, 1.0) * (1.0 - smoothstep(4.2, 6.2, s))
	var fade := 1.0 - smoothstep(6.0, 7.0, s)
	for li in _crack_pts.size():
		var line: PackedVector2Array = _crack_pts[li]
		var share := open_ if li == 0 else clampf(open_ * 2.0 - 1.0, 0.0, 1.0)
		var len_ := (line.size() - 1) * share
		var n := int(ceil(len_))
		var wide := 16.0 if li == 0 else 10.0
		for j in n:
			var a := at + line[j]
			var b := at + line[j + 1]
			if j == n - 1 and len_ < float(n):
				b = a.lerp(b, len_ - float(j))
			# heat runs along the crack in waves; the core goes from yellow to red as it cools
			var h := heat * (0.6 + 0.4 * sin(j * 0.9 - s * 5.0 + li))
			c.draw_line(a, b, Color(0.05, 0.03, 0.02, fade), wide)
			c.draw_line(a, b, Color(1.0, 0.25 + 0.5 * h, 0.05 + 0.25 * h * h, h * fade), wide * 0.5)
			if li == 0 and j % 3 == 0:
				_light(c, a, 80, Color(1.0, 0.4, 0.1, 0.4 * h * fade))
	_light(c, at, 260, Color(1.0, 0.35, 0.1, 0.35 * heat))
	var main_: PackedVector2Array = _crack_pts[0]
	for e in 18:                                        # embers drift up off the crack
		var u := fmod(s * 0.6 + e * 0.137, 1.0)
		var src := main_[1 + (e * 5) % (main_.size() - 2)]
		var p := at + src + Vector2(sin(e * 2.1 + s * 2.0) * 10.0 * u, -160.0 * u)
		c.draw_circle(p, 6.0 * (1.0 - u) + 2.0, Color(1.0, 0.6 + 0.3 * (1.0 - u), 0.2, heat * (1.0 - u)))
	for j in 4:                                         # steam
		var u := fmod(s * 0.5 + j * 0.25, 1.0)
		var ps := _size("puff.png") * (0.2 + 0.4 * u)
		c.draw_texture_rect(tex("puff.png"), Rect2(at + Vector2(-100 + 65 * j + 10 * sin(j * 2.0 + s), -20 - 120 * u) - ps / 2, ps), false, Color(1, 0.9, 0.85, 0.3 * heat * (1.0 - u)))

## the sea seeping in at 400 m: from a joint in the strip of back wall between the niche's post and the great block,
## band px; it runs down the wall to the floor
const BRINE := Vector2(778, 150)
const BRINE_FLOOR := 462.0

func _brine(c: CanvasItem, y: float, s: float) -> void:
	var at := Vector2(BRINE.x, y + BRINE.y)
	var wet := clampf(s / 1.5, 0.0, 1.0) * (1.0 - smoothstep(5.5, 7.0, s))
	# the wall darkens where the water runs: a few thin wet streaks, wider towards the floor
	var bot := y + BRINE_FLOOR
	for k in 3:
		var pts := PackedVector2Array()
		for j in 9:
			var q := j / 8.0
			pts.append(Vector2(at.x + (k - 1) * 7.0 * q + sin(q * 5.0 + k) * 3.0, lerpf(at.y, bot, q * minf(1.0, s / 2.0))))
		c.draw_polyline(pts, Color(0.02, 0.05, 0.06, 0.35 * wet), 5.0)
		c.draw_polyline(pts, Color(0.55, 0.85, 0.95, 0.12 * wet), 1.5)
	# a faint cold glint at the joint, breathing
	_light(c, at, 40, Color(0.35, 0.85, 1.0, 0.12 * wet * (0.7 + 0.3 * sin(s * 2.0))))
	# a small puddle spreading on the floor under it, catching a little light
	var pw := 40.0 * clampf((s - 1.0) / 3.0, 0.0, 1.0)
	if pw > 1.0:
		c.draw_set_transform(Vector2(at.x, bot + 2.0), 0.0, Vector2(1.0, 0.22))
		c.draw_circle(Vector2.ZERO, pw, Color(0.05, 0.12, 0.15, 0.55 * wet))
		c.draw_arc(Vector2.ZERO, pw * (0.5 + 0.5 * fmod(s * 0.8, 1.0)), 0, TAU, 20, Color(0.7, 0.92, 1.0, 0.35 * wet), 3.0)
		c.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	# drops gather at the joint and fall to the floor, splashing
	for k in 4:
		var u := fmod(s * 0.8 + k * 0.25, 1.0)
		var dx := (k - 1.5) * 5.0
		if u < 0.65:
			var q := u / 0.65
			c.draw_circle(Vector2(at.x + dx, lerpf(at.y + 6.0, bot, q * q)), 4.5, Color(0.8, 0.96, 1.0, 0.9 * wet))
		else:
			var q := (u - 0.65) / 0.35
			c.draw_arc(Vector2(at.x + dx, bot), 4.0 + 12.0 * q, PI, TAU, 10, Color(0.8, 0.96, 1.0, 0.6 * wet * (1.0 - q)), 1.6)

func _tremor() -> void:
	if String(_shown_bands.get(8, "")) == "done" and not bool(Save.d.boss_won[area]) and t > _next_tremor:
		_next_tremor = t + _rng.randf_range(18.0, 30.0)
		if t - _tremor_at > 5.0:
			_tremor_at = t
	var s := t - _tremor_at
	var amp := 0.0
	if s >= 0.0 and s < 1.6:
		amp = (7.0 if s < 2.5 else 3.0) * (1.0 - s / 1.6)
	position.x = sin(t * 47.0) * amp * scale.x
	if s >= 0.0 and s < 0.05 and not _cue.has("tremor%d" % int(_tremor_at)):
		_cue["tremor%d" % int(_tremor_at)] = true
		amb.shot("rockfall", -4.0, 0.6)

## the hall of the stone flower open: the flower breathes green, the lizard door glows in its cracks
func _finale(c: CanvasItem) -> void:
	if String(_shown_bands.get(8, "")) != "done" or not J.has("hall"):
		return
	var y := band_y(8)
	var hl: Dictionary = J.hall
	var sh := clampf(1.0 - (t - _tremor_at) / 2.0, 0.0, 1.0)
	var g := 0.5 + 0.3 * sin(t * 1.3) + 0.5 * sh
	var fl: Array = hl.flower
	_light(c, Vector2(float(fl[0]), y + float(fl[1])), 160, Color(0.3, 1.0, 0.45, 0.32 * g))
	var dr: Array = hl.door
	_light(c, Vector2(float(dr[0]), y + float(dr[1])), 110, Color(0.35, 1.0, 0.5, 0.28 * (0.6 + 0.4 * sin(t * 1.9)) + 0.3 * sh))
	for i in 7:
		var u := fmod(t * 0.15 + i / 7.0, 1.0)
		var p := Vector2(float(fl[0]) + sin(i * 2.1 + t * 0.4) * 90, y + float(fl[1]) + 40 - u * 260)
		_light(c, p, 14, Color(0.5, 1.0, 0.6, 0.6 * sin(PI * u)))

const REACT_S := 1.5       # a reaction: 12 drawings at 8 a second

## where a depth's crew is in its 24-drawing loop at time `at` (the loop stands still while a reaction plays)
func _crew_v(k: int, at: float) -> float:
	var v := at * CREW_FPS + k * 7.0
	if _hold.has(k):
		v -= clampf(at - float(_hold[k]), 0.0, REACT_S) * CREW_FPS
	return v

func _crew_frame(cr: Dictionary, k: int) -> int:
	return _drawing_at(cr, _crew_v(k, t))

## where in the loop the blow lands (its drawing's first showing)
func _hit_at(cr: Dictionary) -> float:
	var p := _play(cr)
	var seq: Array = p.seq
	var at: Array = p.at
	return float(at[maxi(seq.find(int(cr.hit)), 0)])

func _sounds(_dt: float) -> void:
	for b in _bands:
		if not b.lived or _appear.has(int(b.k)):
			continue
		var k := int(b.k)
		var cr: Dictionary = J.crews[str(int(b.d))]
		if not cr.has("hit"):
			continue
		if _passed("hit%d" % k, _crew_v(k, t), _loop(cr), _hit_at(cr)) and (k == sel or randf() < 0.15):
			CopperSounds.strike(amb, String(cr.work[0]), _far(float(b.y) + floor_of(int(b.d))) - k * 1.2 + (0.0 if k == sel else -4.0), 0.95 - k * 0.02)
	if int(_shown_places.get("hoist", 0)) >= 3:
		_conv_sounds()
	CopperSounds.of(self).tick(self)
