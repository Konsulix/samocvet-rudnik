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
const SHAFT_CYCLE := 18.0  # s: the cart down the incline to the deepest open level, a wait, back up, a wait

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
		t0 += (ceilf(v / 24.0) * 24.0 - v) / CREW_FPS
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

func _draw_live() -> void:
	var c := live
	_lights(c)
	_surface_live(c)
	_shaft_cart(c)
	for b in _bands:
		_band_live(c, b)
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
		if String(_shown_bands.get(k, b.state)) == "closed":
			continue
		for l in J.lamps.get(str(int(b.d)), []):
			_light(c, Vector2(float(l[0]), float(b.y) + float(l[1])), 150, Color(1.0, 0.7, 0.32, 0.28 * _flick(k * 3)))

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
		if int(_shown_places.get(String(spec.place), 0)) < 3 or not _crew_ok(String(spec.name)):
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
		var fr := "%s/%02d.png" % [nm, int((t + ph) * float(spec.get("fps", 8))) % n]
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

## the incline railway: a cart rides up the rails and back, its rope paying out from the winch at the top
func _incline_cart(c: CanvasItem) -> void:
	var inc: Dictionary = J.incline
	var a := Vector2(float(inc.a[0]), float(inc.a[1]))
	var b := Vector2(float(inc.b[0]), float(inc.b[1]))
	var u := fmod(t, 16.0)
	var q := 0.0
	if u < 6.0: q = 0.5 - 0.5 * cos(PI * u / 6.0)
	elif u < 8.0: q = 1.0
	elif u < 14.0: q = 0.5 + 0.5 * cos(PI * (u - 8.0) / 6.0)
	var p := a.lerp(b, q)
	var ang := (b - a).angle()
	var cs := _size("cart_full.png") * float(inc.get("s", 0.6))
	c.draw_line(p, b, Color(0.55, 0.45, 0.3), 2.0)
	c.draw_set_transform(p, ang + PI if b.x < a.x else ang, Vector2.ONE)
	c.draw_texture_rect(tex("cart_full.png" if u < 7.0 else "cart_empty.png"), Rect2(Vector2(-cs.x / 2, -cs.y), cs), false)
	c.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

## the hoist's cart in the inclined shaft: down the flights to the deepest open level and back (the steam hoist pulls it)
func _shaft_cart(c: CanvasItem) -> void:
	if int(_shown_places.get("hoist", 0)) < 3:
		return
	var pts: Array = []
	var tp: Array = J.shaft.path_top
	for p in tp: pts.append(Vector2(float(p[0]), float(p[1])))
	for b in _bands:
		if int(b.k) > open:
			break
		var fl: Array = J.shaft.path[str(int(b.d))]
		for p in fl: pts.append(Vector2(float(p[0]), float(b.y) + float(p[1])))
	if pts.size() < 2:
		return
	var total := 0.0
	for i in pts.size() - 1: total += (pts[i + 1] - pts[i]).length()
	var u := fmod(t, SHAFT_CYCLE)
	var q := 0.0
	var half := SHAFT_CYCLE / 2 - 2
	if u < half: q = 0.5 - 0.5 * cos(PI * u / half)
	elif u < half + 2: q = 1.0
	elif u < 2 * half + 2: q = 0.5 + 0.5 * cos(PI * (u - half - 2) / half)
	var d := q * total
	var i := 0
	while i < pts.size() - 2 and d > (pts[i + 1] - pts[i]).length():
		d -= (pts[i + 1] - pts[i]).length()
		i += 1
	var seg: Vector2 = pts[i + 1] - pts[i]
	var p: Vector2 = pts[i] + seg.normalized() * minf(d, seg.length())
	var ang := seg.angle()
	if seg.x < 0: ang += PI
	var cs := _size("cart_full.png") * float(J.shaft.get("cart_s", 0.5))
	c.draw_set_transform(p, ang, Vector2(-1 if seg.x < 0 else 1, 1))
	c.draw_texture_rect(tex("cart_full.png" if u > half else "cart_empty.png"), Rect2(Vector2(-cs.x / 2, -cs.y), cs), false)
	c.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	_light(c, p + Vector2(0, -cs.y * 0.6), 60, Color(1.0, 0.7, 0.35, 0.25))

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
	if cr.has("spark") and _crew_frame(cr, k) in [10, 11]:
		var sp: Array = cr.spark
		_light(c, Vector2(x + float(sp[0]) * (-1.0 if flip else 1.0), floor_y + float(sp[1])), 40, Color(1.0, 0.7, 0.3, 0.6 * al))

# ---------------------------------------------------------------- the Mistress about the place

func _tick_events() -> void:
	if force_event != "" and t > 0.5:
		_events[force_event] = t
		if force_event == "lizard":
			_events["lizard_at"] = J.cracks[0]
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
		pool.append("hotcrack")
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
				# the crowned lizard runs along the wall to her crack in darts and freezes, and is gone into it
				var cr: Dictionary = _events.get("lizard_at", {})
				if cr.is_empty() or s > 6.0:
					done = true
				else:
					var y := band_y(int(cr.d) - 1)
					var to := Vector2(float(cr.x), y + float(cr.y))
					var from := to + Vector2(-float(cr.get("run", 420)), float(cr.get("rise", 60)))
					# darts: run 0.5 s, freeze 0.6 s, three times, then into the crack
					var prog := 0.0
					var moving := false
					for j in 3:
						var a0 := j * 1.1
						if s >= a0 + 0.5: prog = (j + 1) / 3.0
						elif s >= a0:
							prog = (j + (s - a0) / 0.5) / 3.0
							moving = true
					var p := from.lerp(to, prog)
					var ang := (to - from).angle() + PI / 2
					var fade := clampf((4.2 - s) / 0.4, 0.0, 1.0)
					if fade > 0.0:
						var fr := "lizard/%02d.png" % ((int(t * 16) % 8) if moving else 0)
						var ls := _size(fr) * 0.7
						c.draw_set_transform(p, ang, Vector2.ONE)
						c.draw_texture_rect(tex(fr), Rect2(-ls / 2, ls), false, Color(1, 1, 1, fade))
						c.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
						_light(c, p + Vector2(0, -ls.y * 0.3), 18, Color(1.0, 0.85, 0.3, 0.35 * fade))
					if s > 4.2:
						_light(c, to, 50, Color(0.3, 1.0, 0.45, 0.4 * (1.0 - (s - 4.2) / 1.8)))
			"reflection":
				# in the curtain of the waterfall: a woman in green, for a moment
				var rf: Array = J.water.reflection
				var a := sin(PI * clampf(s / 5.0, 0.0, 1.0))
				if s > 5.0: done = true
				else:
					var rs := _size("reflection.png")
					var wob := Vector2(sin(t * 3.0) * 3.0, 0)
					c.draw_texture_rect(tex("reflection.png"), Rect2(Vector2(float(rf[0]), float(rf[1])) - rs / 2 + wob, rs), false, Color(1, 1, 1, 0.7 * a))
			"window":
				# the shadow of a lizard with a crown crosses a green window of the lapidary
				var wn: Array = J.lapidary.windows[_rng.randi() % 1]
				if s > 2.4: done = true
				else:
					var p := Vector2(float(wn[0]) - float(wn[2]) * 0.6 + s / 2.4 * float(wn[2]) * 1.2, float(wn[1]) + 20 * sin(s * 3.0))
					var fr := "lizard/%02d.png" % (int(t * 16) % 8)
					var ls := _size(fr) * 0.8
					c.draw_set_transform(p, PI / 2, Vector2.ONE)
					c.draw_texture_rect(tex(fr), Rect2(-ls / 2, ls), false, Color(0.02, 0.06, 0.03, 0.75))
					c.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
			"hotcrack":
				# the next mine's heart of fire: a crack in the deepest rock glows red and breathes steam, and cools
				var hc: Dictionary = J.hotcrack
				if s > 6.0: done = true
				else:
					var y := band_y(int(hc.d) - 1)
					var a := sin(PI * clampf(s / 6.0, 0.0, 1.0))
					var at := Vector2(float(hc.x), y + float(hc.y))
					var hs := _size("hotcrack.png")
					c.draw_texture_rect(tex("hotcrack.png"), Rect2(at - hs / 2, hs), false, Color(1, 1, 1, a))
					_light(c, at, 120, Color(1.0, 0.35, 0.1, 0.4 * a))
					for j in 4:
						var u := fmod(s * 0.5 + j * 0.25, 1.0)
						var ps := _size("puff.png") * (0.2 + 0.4 * u)
						c.draw_texture_rect(tex("puff.png"), Rect2(at + Vector2(10 * sin(j * 2.0 + s), -hs.y * 0.4 - 120 * u) - ps / 2, ps), false, Color(1, 0.9, 0.85, 0.35 * a * (1.0 - u)))
		if done:
			_events.erase(ev)

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
	return int(_crew_v(k, t)) % 24

func _sounds(_dt: float) -> void:
	for b in _bands:
		if not b.lived or _appear.has(int(b.k)):
			continue
		var k := int(b.k)
		var cr: Dictionary = J.crews[str(int(b.d))]
		if not cr.has("hit"):
			continue
		if _passed("hit%d" % k, _crew_v(k, t), 24.0, float(cr.hit)) and (k == sel or randf() < 0.15):
			CopperSounds.strike(amb, String(cr.work[0]), _far(float(b.y) + floor_of(int(b.d))) - k * 1.2 + (0.0 if k == sel else -4.0), 0.95 - k * 0.02)
	if int(_shown_places.get("hoist", 0)) >= 3 and (_passed("shaft_dn", t, SHAFT_CYCLE) or _passed("shaft_up", t, SHAFT_CYCLE, SHAFT_CYCLE / 2)):
		amb.shot("winch_%d" % (randi() % 2), _far(float(J.sky) + 1500))
	CopperSounds.of(self).tick(self)
