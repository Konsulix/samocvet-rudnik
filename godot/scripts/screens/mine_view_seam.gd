class_name SeamView
extends MineView
## Whispering Seam (mine 8, Shubin's and the canary's - a third mine of its own, outside the first arc's chain;
## docs/mine8-shubin.md §5): a coal mine about 1900 on a white chalk cape over a great river at dusk - chalk pillars, a
## cave church in the cliff, the headframe, the lamp house full of canaries, a coal steamer at the long pier. Drawn like
## Old Adit (MineView) but laid out its own way: no shaft and no stairwell - ONE thick black coal seam dips steeply
## through every depth, from the adit at the upper left to the right at the bottom, the INCLINE cut along it; a level
## branches off it at each floor (right at 50-200 m, left from 250 m).
## The life of the place: the CART on its rope going up and down the incline through all the depths (the bell rings at
## the adit when it comes up, the headframe's wheel turns), the furnace's draught (its wheel turns, the air drifts along
## the levels), the steamer loading at the pier, sailing off and coming back, and the CANARIES singing in every level.
## Firedamp hangs pale under the deep roofs; now and then it thickens, a canary falls silent, the lamps' flames stretch
## blue - and Shubin coughs in the dark. Pictures and coordinates: assets/mine/whispering_seam/ + mine.json
## (art/zone/export_mine8.py), source px of the 1536-wide stack: the sky, the surface, the section, the depth bands.

const SDIR := "res://assets/mine/whispering_seam/"
## the surface's places in drawing order (their pictures meet at soft edges)
const SPLACES := ["church", "headframe", "fan", "staithe", "lamps", "adit"]
## the depths whose job is built in the level itself: its stages are the band's pictures
const SBAND_JOBS := {7: "burn", 8: "fall", 9: "lull"}
const SSTAGES := ["clear", "step1", "step2", "done"]
const INK := Color(0.04, 0.035, 0.035)
const GAS := Color(0.72, 0.8, 0.7)
const FLAME := Color(0.45, 0.7, 1.0)
const CANARY := Color(1.0, 0.86, 0.3)

## the cart's trip on the incline: down to the deepest open level, a wait while it is filled, back up to the adit, a
## wait while it is tipped; its speed in source px a second
const CART_V := 260.0
const CART_WAIT := 3.0
const CART_EASE := 1.5
## the steamer's day: at the pier loading, sailing off up the river, away, coming back
const SHIP_AT := 42.0
const SHIP_GO := 14.0
const SHIP_AWAY := 8.0

var _sx: Node2D               # smoke (particles in the picture's own coordinates)
var _smokes: Array = []       # [particles, the place it belongs to, the step from which it smokes]
var _hold := {}               # depth -> when its crew's reaction began
var _path := PackedVector2Array()   # the incline: from the adit's lip down along the seam to the deepest level's floor
var _path_len := PackedFloat32Array()
var _bell_a := 0.0            # the adit's bell on its beam (radians) and its speed
var _bell_v := 0.0
var _wheel_a := 0.0           # the headframe's wheel (turns with the rope)
var _fan_a := 0.0             # the furnace's wheel
var _gas_k := {}              # depth -> how thick its gas is now (1 as it should be; an event thickens it)
var _quiet := {}              # depth -> since when its canary is silent
var _haze: Array = []         # gas wisps under the roofs: [x share, phase, speed, size]
var _dip := {}                # depth -> when its lamps last cowered (a cough, a knock)

func _init() -> void:
	dir = SDIR

func amb_beds() -> Array:
	return ["cave"]

func available_here() -> bool:
	return FileAccess.file_exists(SDIR + "mine.json")

func _ready() -> void:
	super()
	_sx = Node2D.new()
	add_child(_sx)
	move_child(_sx, live.get_index())
	var r := RandomNumberGenerator.new()
	r.seed = 808
	for i in 14:
		_haze.append([r.randf(), r.randf_range(0, TAU), r.randf_range(6.0, 16.0) * (1 if i % 2 else -1), r.randf_range(0.7, 1.3)])

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
			if SBAND_JOBS.has(d):
				st = SSTAGES[clampi(int(steps.get(SBAND_JOBS[d], 0)), 0, 3)]
		var lived: bool = k <= open and k < wins.size() and int(wins[k]) >= 2 and J.crews.has(str(d))
		_bands.append({y = y0 + k * float(J.band), state = st, d = d, lived = lived, k = k})
	H = y0 + _bands.size() * float(J.band)
	if _set_area != a:
		_events = {}
		_next_event = 7.0
		_set_area = a
	surf.texture = tex("surface.png")
	surf.scale = Vector2.ONE / K
	surf.material = null
	still.material = null
	if J.has("sway") and ResourceLoader.exists(dir + "sway_mask.png"):
		var sm := ShaderMaterial.new()
		sm.shader = load("res://shaders/mine_sway_mask.gdshader")
		var sr: Array = J.sway.rect
		sm.set_shader_parameter("mask", tex("sway_mask.png"))
		sm.set_shader_parameter("mask_rect", Vector4(float(sr[0]), float(sr[1]), float(sr[2]), float(sr[3])))
		sm.set_shader_parameter("amp", 2.0)
		sm.set_shader_parameter("to_mine", 1.0 / K)
		surf.material = sm
		var stm := sm.duplicate() as ShaderMaterial
		stm.set_shader_parameter("to_mine", 1.0)
		still.material = stm
	_changes()
	if not last_result.is_empty() and int(last_result.area) == a:
		var k := clampi(int(last_result.k), 0, _bands.size() - 1)
		var t0 := t + 0.7
		var cr: Dictionary = J.crews.get(str(int(_bands[k].d)), {})
		var v := _crew_v(k, t0)
		var ln := _loop(cr) if not cr.is_empty() else 0.0
		if ln > 0.0:
			t0 += (ceilf(v / ln) * ln - v) / CREW_FPS
		_hold[k] = t0
		_react = {k = k, won = bool(last_result.won), t0 = t0, iron = int(last_result.iron), ore = int(last_result.ore)}
		if focus_y < 0: focus_y = band_y(k) + float(J.band) * 0.5
		last_result = {}
	_make_path()
	_setup_fx()
	_make_motes()
	_find_niches()
	still.queue_redraw()
	front.queue_redraw()

## what changed since the screen was last shown: new stages come in (ink, then colour), a newly opened level shows
## through a burst of coal dust, the people of a depth fade in after its second win
func _changes() -> void:
	var places := {}
	for p in SPLACES: places[p] = int(steps.get(p, 0))
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
	for p in SPLACES:
		var was := int(last.places.get(p, 0))
		var now := int(places[p])
		if now <= was:
			continue
		if focus_y < 0: focus_y = job_pos(p).y
		_shown_places[p] = was
		var at: Array = J.places[p]
		_reveal("place/%s_%d.png" % [p, now], Vector2(float(at[0]), float(at[1])), wait, func(): _shown_places[p] = now,
			"place/%s_%d.png" % [p, was] if was > 0 else "surface.png", p, SPLACES)
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
			var gx: Array = J.galleries.get(str(d), [300, 1200])
			for j in 4:
				_bursts.append([Vector2(lerpf(float(gx[0]), float(gx[1]), (j + 0.5) / 4.0), y + 330), t + wait + 0.2 + 0.12 * j])
		_reveal("band/d%d_%s.png" % [d, now], Vector2(0, y - _over()), delay, func(): _shown_bands[k] = now, "band/d%d_%s.png" % [d, was])
		if d == 9 and now == "done":
			_tremor_at = t + delay + 2.2      # the lullaby sung in the hollow: the seam sighs
	for k in lived:
		if lived[k] and not bool(last.lived.get(k, false)):
			_appear[k] = t + wait
			if focus_y < 0: focus_y = band_y(int(k)) + float(J.band) * 0.5

func job_pos(id: String) -> Vector2:
	if J.place_box.has(id):
		var bx: Array = J.place_box[id]
		return Vector2((float(bx[0]) + float(bx[2])) / 2, (float(bx[1]) + float(bx[3])) / 2)
	for d in SBAND_JOBS:
		if SBAND_JOBS[d] == id:
			return Vector2(768, band_y(int(d) - 1) + 300)
	return Vector2(768, float(J.sky) + 900)

# ---------------------------------------------------------------- the still pictures

func _draw_still() -> void:
	var c := still
	for p in SPLACES:
		var s := int(_shown_places.get(p, 0))
		if s > 0:
			var at: Array = J.places[p]
			_put(c, "place/%s_%d.png" % [p, s], Vector2(float(at[0]), float(at[1])))
	if ResourceLoader.exists(dir + "cut.png"):
		_put(c, "cut.png", Vector2(0, _cut_top() - float(J.get("cut_over", 0))))
	for b in _bands:
		var st := String(_shown_bands.get(int(b.k), b.state))
		var bp := "band/d%d_%s.png" % [int(b.d), st]
		if ResourceLoader.exists(dir + bp):
			_put(c, bp, Vector2(0, float(b.y) - _over()))
	_draw_niches(c)
	_draw_bedrock(c)

func _over() -> float:
	return float(J.get("band_over", 0))

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

func niche_spot(k: int) -> Array:
	return J.niches.get(str(k + 1), [0, 0])

func _niche_pos(k: int) -> Vector2:
	var nc: Array = J.niches[str(k + 1)]
	return Vector2(float(nc[0]), band_y(k) + float(nc[1]))

func niche_at(p: Vector2) -> Dictionary:
	for k in _niche_want:
		var key := Spec.key_of(Spec.of_stone(_niche_want[k]))
		if not _niche_tex.has(key):
			continue
		var at := _niche_pos(k)
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
		var at := _niche_pos(k)
		var sz := _niche_size(tx)
		var pos := Vector2(at.x - sz.x / 2, at.y - sz.y + 8)
		c.draw_texture_rect(_glow, Rect2(Vector2(at.x - sz.x * 0.6, at.y - 10), Vector2(sz.x * 1.2, 22)), false, Color(0.04, 0.03, 0.03, 0.6))
		for dv in [Vector2(-3, 0), Vector2(3, 0), Vector2(0, -3), Vector2(0, 3), Vector2(-2, -2), Vector2(2, 2), Vector2(-2, 2), Vector2(2, -2)]:
			c.draw_texture_rect(tx, Rect2(pos + dv, sz), false, Color(0.05, 0.04, 0.04, 1.0))
		c.draw_texture_rect(tx, Rect2(pos, sz), false, Color(1.0, 0.95, 0.88))

# ---------------------------------------------------------------- smoke (particles in the picture's coordinates)

func _setup_fx() -> void:
	for ch in _sx.get_children(): ch.queue_free()
	_smokes = []
	for s in J.get("smoke", []):
		var spec: Dictionary = s
		var k := float(spec.size)
		var p := CPUParticles2D.new()
		p.texture = tex("puff.png")
		p.local_coords = true
		p.position = Vector2(float(spec.at[0]), float(spec.at[1]))
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		var sc := Curve.new()
		var g := Gradient.new()
		p.amount = 12
		p.lifetime = 8.0
		p.preprocess = p.lifetime
		p.emission_sphere_radius = 6.0 * k
		p.direction = Vector2(0.2, -1)
		p.spread = 10
		p.gravity = Vector2(6, -2)        # the evening air off the river: it rises, then drifts away to the right
		p.initial_velocity_min = 16 * k
		p.initial_velocity_max = 26 * k
		p.scale_amount_min = 0.5 * k
		p.scale_amount_max = 0.8 * k
		sc.add_point(Vector2(0, 0.5))
		sc.add_point(Vector2(1, 3.4))
		var dk := float(spec.get("dark", 0.0))      # the furnace's smoke is coal-black
		g.set_color(0, Color(0.7, 0.7, 0.72, 0.0))
		g.add_point(0.08, Color(Color(0.66, 0.66, 0.7).darkened(dk), 0.5))
		g.add_point(0.5, Color(Color(0.45, 0.45, 0.5).darkened(dk), 0.35))
		g.set_color(g.get_point_count() - 1, Color(0.36, 0.36, 0.4, 0.0))
		p.angular_velocity_min = -10
		p.angular_velocity_max = 10
		p.scale_amount_curve = sc
		p.color_ramp = g
		_sx.add_child(p)
		_smokes.append([p, String(spec.get("place", "")), int(spec.get("from", 0))])
	_update_fx()

func _update_fx() -> void:
	for s in _smokes:
		var pl := String(s[1])
		(s[0] as CPUParticles2D).emitting = pl == "" or int(_shown_places.get(pl, 0)) >= int(s[2])

# ---------------------------------------------------------------- the incline and its cart

## the incline's line: the measured points from the adit's lip down through the section, then the seam's centre down
## every open band (the layout's formula: export_mine8 shifts each band so its seam sits there) to the deepest floor
func _make_path() -> void:
	_path = PackedVector2Array()
	for p_ in J.get("incline", []):
		var p: Array = p_
		_path.append(Vector2(float(p[0]), float(p[1])))
	var sm: Dictionary = J.get("seam", {})
	if sm.is_empty():
		return
	for b in _bands:
		var k := int(b.k)
		if k > open:
			break
		var d := int(b.d)
		var y := float(b.y)
		var floor_y := y + floor_of(d)
		var last := k == open
		for j in 9:
			var q := j / 8.0
			var yy := lerpf(y, floor_y if last else y + float(J.band), q)
			_path.append(Vector2(seam_x(d, yy - y), yy))
	_path_len = PackedFloat32Array()
	var acc := 0.0
	for i in _path.size():
		if i > 0: acc += _path[i].distance_to(_path[i - 1])
		_path_len.append(acc)

## the seam's (and the incline's) centre in band d, `row` source px under the band's top
func seam_x(d: int, row: float) -> float:
	var sm: Dictionary = J.seam
	return float(sm.x0) + float(sm.dx) * (d - 1) + row * float(sm.slope)

func _at_len(s: float) -> Vector2:
	var n := _path.size()
	if n < 2: return Vector2.ZERO
	var i := _path_len.bsearch(s)
	i = clampi(i, 1, n - 1)
	var a := _path_len[i - 1]
	var b := _path_len[i]
	return _path[i - 1].lerp(_path[i], clampf((s - a) / maxf(b - a, 0.01), 0.0, 1.0))

## where the cart is: x its distance down the incline (0 at the adit), y 0 moving / 1 waiting, z 0 going down / 1 up
func _cart_state() -> Vector3:
	var L := _path_len[_path_len.size() - 1] if _path_len.size() > 1 else 0.0
	if L <= 0.0 or int(_shown_places.get("adit", 0)) < 3:
		return Vector3(0, 1, 0)
	var go := L / CART_V + CART_EASE
	var cyc := go * 2.0 + CART_WAIT * 2.0
	var s := fmod(t + 3.5, cyc)
	if s < go:
		return Vector3(_trip(s, go, L), 0, 0)
	if s < go + CART_WAIT:
		return Vector3(L, 1, 0)
	if s < go * 2.0 + CART_WAIT:
		return Vector3(L - _trip(s - go - CART_WAIT, go, L), 0, 1)
	return Vector3(0, 1, 1)

## the distance gone `s` seconds into a trip of `go` s and `L` px: steady speed, gathered and slowed over CART_EASE s
func _trip(s: float, go: float, L: float) -> float:
	var e := CART_EASE
	var v := L / (go - e)
	if s < e: return 0.5 * v / e * s * s
	if s > go - e:
		var r := go - s
		return L - 0.5 * v / e * r * r
	return 0.5 * v * e + v * (s - e)

## the rope from the adit down to the cart, and the cart itself: a little iron tub on its wheels, heaped with coal on
## the way up, a lamp hung on its front
func _incline_cart(c: CanvasItem) -> void:
	if _path.size() < 2 or int(_shown_places.get("adit", 0)) < 3:
		return
	var st := _cart_state()
	var at := _at_len(st.x)
	if at.y < _seen.x - 300.0 and _path[0].y < _seen.x - 300.0:
		return
	# the rope: the path from the top down to the cart
	var rope := PackedVector2Array()
	for i in _path.size():
		if _path_len[i] >= st.x: break
		rope.append(_path[i])
	rope.append(at)
	if rope.size() >= 2:
		c.draw_polyline(rope, INK, 6.0)
		c.draw_polyline(rope, Color(0.72, 0.62, 0.46), 3.0)
	var dir_ := (_at_len(st.x + 4.0) - _at_len(st.x - 4.0)).normalized()
	var ang := atan2(dir_.y, dir_.x) - PI / 2.0
	# GPT's tub (full on the way up and while it waits at the bottom, empty going down)
	var full := st.z > 0.5 or (st.y > 0.5 and st.x > 1.0)
	var tp := "tub_full.png" if full else "tub_empty.png"
	if ResourceLoader.exists(dir + tp):
		var ts := _size(tp)
		var rock := sin(t * 9.0) * 0.02 * (1.0 - st.y)            # a little jolt over the sleepers while it runs
		c.draw_set_transform(at, ang * 0.15 + rock, Vector2.ONE)
		c.draw_texture_rect(tex(tp), Rect2(Vector2(-ts.x / 2, -ts.y * 0.85), ts), false)
		c.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		_light(c, at + Vector2(-ts.x * 0.3, -ts.y * 0.4), 130, Color(1.0, 0.7, 0.35, 0.42 * _flick(3)))
		return
	c.draw_set_transform(at, ang * 0.25, Vector2.ONE * 2.1)
	var body := Color(0.42, 0.38, 0.34)
	c.draw_colored_polygon(PackedVector2Array([Vector2(-30, -26), Vector2(30, -26), Vector2(25, 10), Vector2(-25, 10)]), INK)
	c.draw_colored_polygon(PackedVector2Array([Vector2(-27, -23), Vector2(27, -23), Vector2(22, 7), Vector2(-22, 7)]), body)
	c.draw_line(Vector2(-26, -14), Vector2(26, -14), Color(0.35, 0.32, 0.3), 2.0)
	c.draw_line(Vector2(-24, -2), Vector2(24, -2), Color(0.35, 0.32, 0.3), 2.0)
	for wx in [-15.0, 15.0]:
		c.draw_circle(Vector2(wx, 12), 8.0, INK)
		c.draw_circle(Vector2(wx, 12), 5.0, Color(0.3, 0.28, 0.27))
	if st.z > 0.5 or (st.y > 0.5 and st.z < 0.5 and st.x > 1.0):
		c.draw_colored_polygon(PackedVector2Array([Vector2(-26, -23), Vector2(-14, -36), Vector2(0, -40), Vector2(16, -35), Vector2(26, -23)]), Color(0.06, 0.06, 0.07))
		c.draw_line(Vector2(-8, -34), Vector2(4, -37), Color(0.5, 0.52, 0.6, 0.8), 2.0)
	c.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	_light(c, at + Vector2(0, -20), 150, Color(1.0, 0.7, 0.35, 0.45 * _flick(3)))
	c.draw_circle(at + Vector2(0, -6), 5.0, Color(1.0, 0.85, 0.5))

# ---------------------------------------------------------------- the surface's machines

## the adit's bell swings on its beam when the cart comes up (and rings); the headframe's wheel turns while the rope
## runs, the furnace's wheel always, slowly
func _machines(c: CanvasItem) -> void:
	if J.has("headwheel") and int(_shown_places.get("headframe", 0)) >= 3 and ResourceLoader.exists(dir + "wheel_head.png"):
		var hw: Dictionary = J.headwheel
		var cp: Array = hw.c
		_put_rot(c, "wheel_head.png", Vector2(float(cp[0]), float(cp[1])), _wheel_a, Vector2.ONE * float(hw.r) * 2.0)
	if J.has("fanwheel") and int(_shown_places.get("fan", 0)) >= 3 and ResourceLoader.exists(dir + "wheel_fan.png"):
		var fw: Dictionary = J.fanwheel
		var cp: Array = fw.c
		var sz := Vector2.ONE * float(fw.r) * 2.0
		# the wheel stands in the arch at an angle: its circle squeezed sideways
		c.draw_set_transform(Vector2(float(cp[0]), float(cp[1])), 0.0, Vector2(float(fw.get("sx", 1.0)), 1.0))
		c.draw_set_transform_matrix(Transform2D(Vector2(float(fw.get("sx", 1.0)), 0), Vector2(0, 1), Vector2(float(cp[0]), float(cp[1]))) * Transform2D(_fan_a, Vector2.ZERO))
		c.draw_texture_rect(tex("wheel_fan.png"), Rect2(-sz / 2, sz), false)
		c.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	if J.has("bell") and int(_shown_places.get("adit", 0)) >= 2 and ResourceLoader.exists(dir + "bell.png"):
		var bl: Dictionary = J.bell
		var an: Array = bl.anchor
		var off: Array = bl.off
		c.draw_set_transform(Vector2(float(an[0]), float(an[1])), _bell_a, Vector2.ONE)
		c.draw_texture_rect(tex("bell.png"), Rect2(Vector2(float(off[0]), float(off[1])), _size("bell.png")), false)
		c.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

## the pier's coal tub: pushed out along the pier's rails to the chute's head, tipped (coal pours down the chute into
## the steamer's hold), and back - only while the steamer is in
func _pier_cart(c: CanvasItem) -> void:
	if not J.has("pier") or int(_shown_places.get("staithe", 0)) < 3 or not ResourceLoader.exists(dir + "pcart.png"):
		return
	var pr: Dictionary = J.pier
	var a_: Array = pr.a
	var b_: Array = pr.b
	var a := Vector2(float(a_[0]), float(a_[1]))
	var b := Vector2(float(b_[0]), float(b_[1]))
	if a.y > _seen.y + 200.0 or a.y < _seen.x - 400.0:
		return
	var cyc := 14.0
	var s := fmod(t, cyc)
	var u := 0.0
	var tip := 0.0
	var ship_in := _ship_off() < 0.01
	if ship_in:
		if s < 5.0: u = smoothstep(0.0, 1.0, s / 5.0)
		elif s < 8.0:
			u = 1.0
			tip = sin(clampf((s - 5.0) / 3.0, 0.0, 1.0) * PI)
		elif s < 13.0: u = 1.0 - smoothstep(0.0, 1.0, (s - 8.0) / 5.0)
	var p := a.lerp(b, u)
	var sz := _size("pcart.png")
	c.draw_set_transform(p, -0.5 * tip, Vector2.ONE)
	c.draw_texture_rect(tex("pcart.png"), Rect2(Vector2(-sz.x / 2, -sz.y), sz), false)
	c.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	# the coal pouring down the chute while it is tipped
	if tip > 0.2 and pr.has("chute"):
		var ch: Array = pr.chute     # head x, y, foot x, y
		var h := Vector2(float(ch[0]), float(ch[1]))
		var f := Vector2(float(ch[2]), float(ch[3]))
		for i in 14:
			var q := fmod(t * 1.6 + i / 14.0, 1.0)
			var pp := h.lerp(f, q) + Vector2(sin(i * 2.1) * 3.0, -4.0 + q * q * 6.0)
			c.draw_circle(pp, 3.5, Color(0.06, 0.06, 0.07, tip))
		if _passed("pour", s, cyc, 5.4):
			amb.shot("copper/pour_%d" % (randi() % 3), _far(h.y) - 10.0, 0.9)

## how far the steamer is off the pier: 0 moored, 1 gone up the river
func _ship_off() -> float:
	if int(_shown_places.get("staithe", 0)) < 3:
		return 1.0
	var cyc := SHIP_AT + SHIP_GO * 2.0 + SHIP_AWAY
	var s := fmod(t + 20.0, cyc)
	if s < SHIP_AT: return 0.0
	if s < SHIP_AT + SHIP_GO: return smoothstep(0.0, 1.0, (s - SHIP_AT) / SHIP_GO)
	if s < SHIP_AT + SHIP_GO + SHIP_AWAY: return 1.0
	return 1.0 - smoothstep(0.0, 1.0, (s - SHIP_AT - SHIP_GO - SHIP_AWAY) / SHIP_GO)

## the steamer: rides the water by the pier, smokes; then sails off up the river towards the sunset getting smaller,
## and comes back (empty, higher in the water)
func _ship(c: CanvasItem) -> void:
	if not J.has("ship") or not ResourceLoader.exists(dir + "ship.png"):
		return
	var sh: Dictionary = J.ship
	var at_: Array = sh.at
	var home := Vector2(float(at_[0]), float(at_[1]))
	if home.y > _seen.y + 300.0 or home.y < _seen.x - 600.0:
		return
	var off := _ship_off()
	if off > 0.995:
		return
	var away_: Array = sh.get("away", [home.x + 300.0, home.y - 380.0])
	var away := Vector2(float(away_[0]), float(away_[1]))
	var e := off * off
	var p := home.lerp(away, e)
	# along the river's own course (round the cape's tip), not straight over it
	var rt: Array = sh.get("route", [])
	if rt.size() >= 2:
		var pts := [home]
		for q_ in rt: pts.append(Vector2(float((q_ as Array)[0]), float((q_ as Array)[1])))
		var u := e * (pts.size() - 1)
		var i := mini(int(u), pts.size() - 2)
		p = (pts[i] as Vector2).lerp(pts[i + 1] as Vector2, u - i)
	var sc := lerpf(1.0, 0.25, e)
	var sz := _size("ship.png") * sc
	var bob := sin(t * 0.9) * 2.0 * sc
	var roll := sin(t * 0.7 + 0.6) * 0.012
	var al := clampf((1.0 - off) / 0.15, 0.0, 1.0)
	var keel := p + Vector2(0, bob)           # the ship's waterline middle
	# coming back down the river it sails the other way: the picture mirrored about its middle
	var cyc := SHIP_AT + SHIP_GO * 2.0 + SHIP_AWAY
	var back := fmod(t + 20.0, cyc) > SHIP_AT + SHIP_GO + SHIP_AWAY and off > 0.02
	# near the pier it swings round to lie bow upstream again (its picture narrows through broadside and widens back)
	var sx := 1.0
	if back:
		sx = -1.0 if off > 0.15 else lerpf(1.0, -1.0, off / 0.15)
		if absf(sx) < 0.25: sx = 0.25 * signf(sx + 0.0001)
	c.draw_set_transform(keel, roll, Vector2(sx, 1.0))
	var bo: Array = sh.get("box_off", [-sz.x / 2, -sz.y])
	c.draw_texture_rect(tex("ship.png"), Rect2(Vector2(float(bo[0]), float(bo[1])) * sc, sz), false, Color(1, 1, 1, al))
	c.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	# its reflection: a few broken dark-gold strokes under the lit cabin
	for j in 7:
		var q := j / 6.0
		var y := keel.y + 8.0 + q * 70.0 * sc
		var w := sz.x * (0.25 + 0.2 * absf(sin(j * 1.9 + t * 1.1)))
		c.draw_line(Vector2(keel.x + sz.x * 0.12 - w / 2, y), Vector2(keel.x + sz.x * 0.12 + w / 2, y), Color(1.0, 0.7, 0.35, 0.16 * (1.0 - q) * al), 2.5)
	# the funnel's smoke: soft puffs streaming back
	if sh.has("funnel"):
		var fn: Array = sh.funnel        # from the waterline middle, unscaled
		var top := keel + Vector2(float(fn[0]), float(fn[1])) * sc
		var ps := _size("puff.png")
		for i in 9:
			var q := fmod(t * 0.12 + i / 9.0, 1.0)
			var pp := top + Vector2(-q * 160.0 * sc - (off * 40.0), -q * 120.0 * sc) + Vector2(sin(t + i) * 6.0, 0)
			var s2 := Vector2.ONE * lerpf(0.35, 1.3, q) * sc
			c.draw_texture_rect(tex("puff.png"), Rect2(pp - ps * s2 / 2, ps * s2), false, Color(0.3, 0.3, 0.33, 0.45 * (1.0 - q) * al))
	# the moored ship's lamps
	if off < 0.02 and sh.has("lamps"):
		for l_ in sh.lamps:
			var l: Array = l_
			_light(c, keel + Vector2(float(l[0]), float(l[1])), 50, Color(1.0, 0.68, 0.32, 0.3 * _flick(int(l[0]))))

## the river: the sunset's red line shivering on the water, little glints drifting with the current
func _river(c: CanvasItem) -> void:
	if not J.has("river"):
		return
	var rv: Dictionary = J.river
	var nt := _night()
	if rv.has("sun"):
		var rf: Array = rv.sun          # x0, x1, y0, y1
		if float(rf[2]) < _seen.y + 100.0:
			for j in 18:
				var q := j / 17.0
				var y := lerpf(float(rf[2]), float(rf[3]), q)
				var w := (float(rf[1]) - float(rf[0])) * (0.3 + 0.4 * absf(sin(j * 2.3 + t * 0.9)))
				var cx := (float(rf[0]) + float(rf[1])) * 0.5 + sin(j * 1.7 + t * 0.4) * 8.0
				c.draw_line(Vector2(cx - w * 0.5, y), Vector2(cx + w * 0.5, y), Color(1.0, 0.32, 0.22, (0.14 + 0.16 * absf(sin(t * 1.2 + j))) * (1.0 - 0.6 * nt)), 2.0)
	if rv.has("pts"):
		var pts: Array = rv.pts
		for i in pts.size():
			var pp: Array = pts[i]
			var p := Vector2(float(pp[0]) + sin(t * 0.3 + i) * 10.0, float(pp[1]))
			if p.y < _seen.x - 50.0 or p.y > _seen.y + 50.0: continue
			var on := maxf(0.0, sin(t * (0.6 + 0.25 * (i % 4)) + i * 2.3))
			on = on * on * on
			if on < 0.05: continue
			var w := 8.0 + 14.0 * fmod(i * 0.61, 1.0)
			c.draw_line(p - Vector2(w, 0), p + Vector2(w, 0), Color(0.78, 0.82, 0.92, 0.3 * on), 2.0)
		return
	if rv.has("glints"):
		var gl: Array = rv.glints       # x0, y0, x1, y1
		var x0 := float(gl[0])
		var y0 := float(gl[1])
		var x1 := float(gl[2])
		var y1 := float(gl[3])
		if y0 > _seen.y or y1 < _seen.x:
			return
		for i in 26:
			var u := fmod(i * 0.381 + t * 0.012, 1.0)
			var v := fmod(i * 0.617, 1.0)
			var p := Vector2(lerpf(x0, x1, u), lerpf(y0, y1, v))
			var on := maxf(0.0, sin(t * (0.7 + 0.2 * (i % 3)) + i * 2.3))
			on = on * on * on
			if on < 0.05: continue
			var w := lerpf(10.0, 26.0, v)
			c.draw_line(p - Vector2(w, 0), p + Vector2(w, 0), Color(0.75, 0.8, 0.9, 0.28 * on), 2.0)

## jackdaws: a little flock wheels round the chalk pillars, now and then
func _jackdaws(c: CanvasItem) -> void:
	if not J.has("pillars") or not _crew_ok("jackdaw"):
		return
	var pl: Array = J.pillars
	var ctr := Vector2(float(pl[0]), float(pl[1]))
	if ctr.y > _seen.y + 300.0 or ctr.y < _seen.x - 500.0:
		return
	var n := int(J.crew_n.jackdaw)
	var s := fmod(t + 6.0, 26.0)
	if s > 14.0:
		return
	for i in 5:
		var q := s - i * 0.25
		if q < 0.0: continue
		var a := q * 0.9 + i * TAU / 5.0
		var r := Vector2(260.0 + 30.0 * sin(i * 1.3), 70.0 + 10.0 * sin(i * 2.1))
		var come := clampf(q / 2.0, 0.0, 1.0)
		var go := clampf((q - 11.0) / 2.5, 0.0, 1.0)
		r *= lerpf(2.2, 1.0, come) * (1.0 + 2.0 * go)
		var p := ctr + Vector2(cos(a) * r.x, sin(a) * r.y - 150.0 * go)
		var near := 0.5 + 0.5 * sin(a)
		var fr := "jackdaw/%02d.png" % (int(t * 12.0 + i * 3) % n)
		var fs := _size(fr) * lerpf(0.8, 1.15, near)
		var al := clampf(q / 0.5, 0.0, 1.0) * clampf((14.0 - s) / 1.0, 0.0, 1.0)
		_put_scaled(c, fr, p - fs / 2, fs, sin(a) < 0.0, al, Color(lerpf(0.6, 1.0, near), lerpf(0.6, 1.0, near), lerpf(0.6, 1.0, near)))

func _put_scaled(c: CanvasItem, path: String, pos: Vector2, sz: Vector2, flip: bool, al := 1.0, tint := Color.WHITE) -> void:
	var col := Color(tint, al)
	if not flip:
		c.draw_texture_rect(tex(path), Rect2(pos, sz), false, col)
		return
	c.draw_set_transform(pos + Vector2(sz.x, 0), 0, Vector2(-1, 1))
	c.draw_texture_rect(tex(path), Rect2(Vector2.ZERO, sz), false, col)
	c.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

# ---------------------------------------------------------------- the clock and the motion

func _night() -> float:
	var dt := Time.get_datetime_dict_from_system()
	var h := float(dt.hour) + float(dt.minute) / 60.0
	if h >= 21.0 or h < 5.0: return 1.0
	if h >= 19.0: return (h - 19.0) / 2.0
	if h < 7.0: return 1.0 - (h - 5.0) / 2.0
	return 0.0

func _process(delta: float) -> void:
	super(delta)
	if not visible or J.is_empty():
		return
	if Engine.get_process_frames() % 20 == 0:
		_update_fx()
	var st := _cart_state()
	var moving := st.y < 0.5
	# the headframe's wheel turns with the rope; the bell is struck when the cart comes up to the adit
	if moving:
		_wheel_a += delta * (1.4 if st.z < 0.5 else -1.4)
	_fan_a += delta * 0.5
	if _passed("cart_top", 1.0 if (st.y > 0.5 and st.z > 0.5) else 0.0, 1.0, 0.5):
		_bell_v += 2.6
		amb.shot_clear("seam/bell", _far(_bell_y()) - 4.0, 1.0)
		get_tree().create_timer(0.7).timeout.connect(func(): amb.shot_clear("seam/bell", _far(_bell_y()) - 8.0, 1.0))
	_bell_v += (-_bell_a * 9.0 - _bell_v * 0.9) * delta
	_bell_a += _bell_v * delta
	# the gas in each deep level: back towards its usual thickness
	for k in _gas_k.keys():
		_gas_k[k] = move_toward(float(_gas_k[k]), 1.0, delta * 0.12)
		if absf(float(_gas_k[k]) - 1.0) < 0.01: _gas_k.erase(k)
	for k in _quiet.keys():
		if t - float(_quiet[k]) > 8.0: _quiet.erase(k)

func _bell_y() -> float:
	return float((J.bell.anchor as Array)[1]) if J.has("bell") else float(J.sky) + 1500.0

# ---------------------------------------------------------------- lights

func _lights(c: CanvasItem) -> void:
	var nt := _night()
	var sl: Dictionary = J.get("surface_lamps", {})
	var i := 0
	for place in sl:
		if place != "" and int(_shown_places.get(place, 0)) < 3:
			continue
		for l in sl[place]:
			i += 1
			var col := Color(1.0, 0.64, 0.3, (0.3 + 0.2 * nt) * _flick(i))
			_light(c, Vector2(float(l[0]), float(l[1])), 80 * float(l[2]), col)
	for g_ in J.get("glows", []):
		var g: Dictionary = g_
		var pl := String(g.place)
		if pl != "" and int(_shown_places.get(pl, 0)) < 3:
			continue
		var at: Array = g.at
		var gp := Vector2(float(at[0]), float(at[1]))
		if gp.y > _seen.y + 100.0 or gp.y < _seen.x - 500.0:
			continue
		var fl := 0.25 + 0.35 * nt + 0.12 * sin(t * 2.1 + gp.x * 0.01) + 0.06 * sin(t * 7.3 + gp.y * 0.02)
		c.draw_texture_rect(tex(String(g.path)), Rect2(gp, _size(String(g.path))), false, Color(1.25, 1.05, 0.8, fl))
	if nt > 0.02:
		c.draw_rect(Rect2(0, 0, float(J.W), float(J.sky) + float(J.get("horizon", 700))), Color(0.02, 0.02, 0.05, 0.45 * nt))
		for s in _stars:
			var tw := 0.5 + 0.5 * sin(t * float(s[3]) + float(s[2]))
			c.draw_circle(Vector2(float(s[0]), float(s[1]) * 0.6), 1.6, Color(1, 0.95, 0.9, 0.7 * nt * tw))
	for b in _bands:
		var k := int(b.k)
		if String(_shown_bands.get(k, b.state)) == "closed" or not _band_seen(b):
			continue
		var ls: Array = J.lamps.get(str(int(b.d)), [])
		var gas := float(_gas_k.get(k, 1.0))
		for j in ls.size():
			var l: Array = ls[j]
			var p := Vector2(float(l[0]), float(b.y) + float(l[1]))
			# in thick gas a safety lamp's flame stretches tall and bluish
			var blue := clampf((gas - 1.0) / 1.5, 0.0, 1.0)
			var col := Color(1.0, 0.66, 0.3).lerp(FLAME, blue)
			var dip := 0.0
			if _dip.has(k):
				var q := t - float(_dip[k])
				dip = clampf(q / 0.15, 0.0, 1.0) * clampf((1.6 - q) / 0.8, 0.0, 1.0) * (0.75 + 0.25 * sin(q * 40.0))
			_light(c, p, 140 + 40.0 * blue, Color(col, (0.26 + 0.12 * blue) * _flick(k * 3 + j) * (1.0 - 0.8 * dip)))
			if blue > 0.05:
				c.draw_line(p + Vector2(0, 6), p + Vector2(sin(t * 9.0) * 1.5, -10.0 - 22.0 * blue), Color(0.6, 0.8, 1.0, 0.7 * blue), 3.0)

# ---------------------------------------------------------------- the depths

func _draw_live() -> void:
	var c := live
	_lights(c)
	_river(c)
	_ship(c)
	_jackdaws(c)
	_machines(c)
	_pier_cart(c)
	_surface_live(c)
	_incline_cart(c)
	for b in _bands:
		if _band_seen(b):
			_gas(c, b)
			_band_live(c, b)
			_small_life(c, b)
			_gas_welling(c, b)
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
		var p := "burst/%02d.png" % i
		if not ResourceLoader.exists(dir + p):
			_bursts.erase(bu)
			continue
		var sz := _size(p) * (float(bu[2]) if bu.size() > 2 else 1.6)
		var at: Vector2 = bu[0]
		c.draw_texture_rect(tex(p), Rect2(at - sz / 2, sz), false)

func _surface_live(c: CanvasItem) -> void:
	var sky := float(J.sky)
	for a in J.get("life", []):
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
		_put_scaled(c, fr, pos, fs, flip)
		if nm == "guide24" or nm == "lampman24":
			_light(c, pos + Vector2(fs.x * 0.5, fs.y * 0.45), 46, Color(1.0, 0.66, 0.3, 0.16 + 0.04 * sin(t * 2.0)))

## firedamp under a deep level's roof: slow pale wisps drifting along it, thicker the deeper, thicker still while an
## event has it welling up
func _gas(c: CanvasItem, b: Dictionary) -> void:
	var k := int(b.k)
	var d := int(b.d)
	var st := String(_shown_bands.get(k, b.state))
	if st == "closed" or not J.has("roofs") or not J.roofs.has(str(d)):
		return
	var rf: Array = J.roofs[str(d)]       # x0, x1, y (band px) and the usual thickness 0..1
	var base := float(rf[3]) if rf.size() > 3 else 0.0
	if d == 7 and st == "done": base *= 0.25
	if d == 9 and st == "done": base *= 0.6
	var th := base * float(_gas_k.get(k, 1.0))
	if th < 0.02:
		return
	var x0 := float(rf[0])
	var x1 := float(rf[1])
	var y := float(b.y) + float(rf[2])
	var ps := _size("puff.png")
	for h in _haze:
		var w := 260.0 * float(h[3])
		var x := fposmod(float(h[0]) * (x1 - x0) + t * float(h[2]), (x1 - x0) + w) + x0 - w * 0.5
		var q := Vector2(x, y + 20.0 + sin(t * 0.3 + float(h[1])) * 12.0 + 30.0 * minf(th, 2.0) * float(h[3]))
		var sc := Vector2(w, 60.0 + 50.0 * minf(th, 2.0)) / ps
		c.draw_texture_rect(tex("puff.png"), Rect2(q - ps * sc / 2, ps * sc), false, Color(GAS, clampf(0.2 * th, 0.0, 0.6)))

## firedamp welling up in a level (the "gas" event): a thick grey-green fog rolls down from under the roof over the people
## to about the height of their chests, swirling, and thins away again
func _gas_welling(c: CanvasItem, b: Dictionary) -> void:
	var k := int(b.k)
	var g := float(_gas_k.get(k, 1.0)) - 1.0
	if g <= 0.02:
		return
	var d := int(b.d)
	var gx: Array = J.galleries.get(str(d), [300, 1200])
	var x0 := float(gx[0])
	var x1 := float(gx[1])
	var y := float(b.y)
	var floor_y := y + floor_of(d)
	var top := y + 110.0
	var depth := clampf(g / 1.6, 0.0, 1.0)           # how far down it has come
	for i in 22:
		var u := fmod(i * 0.137 + t * 0.008 * (1 + i % 3), 1.0)
		var x := lerpf(x0 + 40.0, x1 - 40.0, u)
		var yy := lerpf(top, lerpf(top + 40.0, floor_y - 120.0, depth), fmod(i * 0.379, 1.0)) + sin(t * 0.6 + i) * 10.0
		var sz := Vector2(220.0 + 80.0 * sin(i * 1.7), 110.0 + 40.0 * cos(i * 2.3)) * (0.8 + 0.4 * depth)
		c.draw_set_transform(Vector2(x, yy), sin(t * 0.4 + i * 0.9) * 0.3, Vector2.ONE)
		c.draw_texture_rect(tex("puff.png"), Rect2(-sz / 2, sz), false, Color(0.62, 0.74, 0.6, 0.16 * minf(g, 1.2)))
		c.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

## a depth's life: its crew (and their reaction to the level), its second dweller, its canary
func _band_live(c: CanvasItem, b: Dictionary) -> void:
	var k := int(b.k)
	var y := float(b.y)
	var st := String(_shown_bands.get(k, b.state))
	if st == "closed":
		return
	var d := int(b.d)
	var floor_y := y + floor_of(d)
	_canary(c, b)
	if not b.lived:
		return
	var al := 1.0
	if _appear.has(k):
		al = clampf((t - float(_appear[k])) / 1.2, 0.0, 1.0)
		if al >= 1.0: _appear.erase(k)
		if al <= 0.0: return
	if J.has("crews2") and J.crews2.has(str(d)):
		var w2: Dictionary = J.crews2[str(d)]
		var nm2 := String(w2.name)
		if _crew_ok(nm2):
			var n2 := int(J.crew_n[nm2])
			var u2 := (t + k * 1.3) * float(w2.get("fps", 8))
			var f2 := "%s/%02d.png" % [nm2, _drawing_at(w2, u2) if w2.has("play") else int(u2) % n2]
			var s2 := _size(f2)
			var fl2 := y + float(w2.get("floor", floor_of(d)))
			_put(c, f2, Vector2(float(w2.x) - s2.x / 2, fl2 - s2.y + 4), bool(w2.get("flip", false)), al)
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
	var sgn := -1.0 if flip else 1.0
	if cr.has("lamp"):
		var lp: Array = cr.lamp
		var fl := 0.5 + 0.2 * sin(t * 11.0) + 0.15 * sin(t * 17.0)
		_light(c, Vector2(x + float(lp[0]) * sgn, floor_y + float(lp[1])), 80, Color(1.0, 0.6, 0.25, fl * al))

## the canary of a level: its little cage hangs from a prop, the bird hops and sings; silent and fluffed up while the
## gas thickens there
func _canary(c: CanvasItem, b: Dictionary) -> void:
	var d := int(b.d)
	if not J.has("cages") or not J.cages.has(str(d)):
		return
	if d == 9 and String(_shown_bands.get(int(b.k), "")) != "done":
		return
	var k := int(b.k)
	var hk: Array = J.cages[str(d)]
	var top := Vector2(float(hk[0]), float(b.y) + float(hk[1]))
	var quiet := _quiet.has(k)
	var nm := "canaryq" if quiet else "canary"
	if not _crew_ok(nm):
		return
	var n := int(J.crew_n[nm])
	var i := mini(int((t - float(_quiet[k])) * 5.0), n - 1) if quiet else int((t * 7.0 + k * 5.0)) % n
	var fr := "%s/%02d.png" % [nm, i]
	var fs := _size(fr)
	var sw := sin(t * 1.1 + k) * 0.05
	c.draw_line(top + Vector2(0, -26), top, INK, 2.0)
	c.draw_set_transform(top, sw, Vector2.ONE)
	c.draw_texture_rect(tex(fr), Rect2(Vector2(-fs.x / 2, 0), fs), false)
	c.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	_light(c, top + Vector2(0, fs.y * 0.55), fs.x * 0.9, Color(CANARY, 0.12))

## per depth, the life between the events: coal dust drifting with the draught, drops off the roof, glints
func _small_life(c: CanvasItem, b: Dictionary) -> void:
	var k := int(b.k)
	var d := int(b.d)
	var y := float(b.y)
	var st := String(_shown_bands.get(k, b.state))
	if st == "closed":
		return
	# the draught: motes of dust drifting along the level towards the incline
	var gx: Array = J.galleries.get(str(d), [300, 1200])
	var x0 := float(gx[0])
	var x1 := float(gx[1])
	var to_left := d <= 4      # the levels lie right of the incline at 50-200 m: their air goes left to it
	for j in 7:
		var u := fmod(t * 0.05 + j * 0.143 + k * 0.07, 1.0)
		var x := lerpf(x1, x0, u) if to_left else lerpf(x0, x1, u)
		var p := Vector2(x, y + 200.0 + fmod(j * 61.0 + k * 23.0, 220.0) + sin(t + j) * 8.0)
		c.draw_circle(p, 1.8, Color(0.85, 0.8, 0.7, 0.25 * sin(PI * u)))
	var L: Dictionary = J.get("light", {}).get(str(d), {})
	if L.has("drips"):
		var dp: Array = L.drips
		for j in dp.size():
			var e: Array = dp[j]
			var cyc := 2.8 + j * 0.7
			var s3 := fmod(t + j * 1.1, cyc)
			var x := float(e[0])
			var ya := y + float(e[1])
			var yb := y + float(e[2])
			if s3 < 0.6:
				c.draw_circle(Vector2(x, ya + 4.0 * s3), 2.0 + 2.0 * s3, Color(0.75, 0.85, 0.95, 0.7))
			elif s3 < 1.15:
				var u2 := (s3 - 0.6) / 0.55
				c.draw_line(Vector2(x, lerpf(ya, yb, u2 * u2) - 8.0), Vector2(x, lerpf(ya, yb, u2 * u2)), Color(0.8, 0.9, 1.0, 0.8), 2.0)
	if L.has("pts"):
		var col := Color(String(L.get("col", "#ffd88a")))
		var pts: Array = L.pts
		for j in pts.size():
			var pp: Array = pts[j]
			var p := Vector2(float(pp[0]), y + float(pp[1]))
			var on := pow(maxf(0.0, sin(t * (0.9 + 0.3 * sin(j)) + j * 2.1)), 8.0)
			if on < 0.05: continue
			_light(c, p, 22, Color(col, 0.6 * on))
			c.draw_line(p - Vector2(7, 0) * on, p + Vector2(7, 0) * on, Color(1, 1, 1, 0.8 * on), 1.5)
			c.draw_line(p - Vector2(0, 7) * on, p + Vector2(0, 7) * on, Color(1, 1, 1, 0.8 * on), 1.5)
	# 300 m: the red lamp before Saint Barbara flickers
	if L.has("icon"):
		var ic: Array = L.icon
		_light(c, Vector2(float(ic[0]), y + float(ic[1])), 60, Color(1.0, 0.3, 0.2, 0.3 * _flick(k + 9)))

# ---------------------------------------------------------------- events (signs of Shubin)

## the deepest open level from `from` down (gas, coughs and knocks are heard where people work)
func _deep_band(from: int) -> int:
	if _want_k >= from and _want_k <= open:
		var w := _want_k
		_want_k = -1
		return w
	var ks: Array = []
	for b in _bands:
		var k := int(b.k)
		if k >= from and k <= open and String(_shown_bands.get(k, "closed")) != "closed":
			ks.append(k)
	return int(ks[_rng.randi() % ks.size()]) if not ks.is_empty() else -1

func event_y(ev: String) -> float:
	match ev:
		"whistle":
			return float((J.ship.at as Array)[1]) if J.has("ship") else float(J.sky) + 900.0
		"jackdaws":
			return float((J.pillars as Array)[1]) if J.has("pillars") else float(J.sky) + 600.0
		"cough", "knock", "gas":
			_want_k = mini(maxi(open, 1), 6)
			return band_y(_want_k) + 300.0
		"flame":
			return band_y(6) + 300.0
		"eyes":
			return band_y(7) + 300.0
		"shubin":
			_want_k = mini(open, 7)
			return band_y(_want_k) + 300.0
		"rats":
			_want_k = mini(open, 5)
			return band_y(_want_k) + 300.0
	return -1.0

var _pending_ev := ""
var _pending_at := 0.0
var _ev_band := {}            # event -> the depth it happens at
var _want_k := -1             # the depth an event the screen glided to (event_y) is to happen at
func _tick_events() -> void:
	if force_event != "":
		event_y(force_event)          # it sets the depth the event is to happen at
		_pending_ev = force_event
		_pending_at = t + 0.9
		force_event = ""
	if _pending_ev != "" and t > _pending_at:
		_start_event(_pending_ev)
		_pending_ev = ""
	if t < _next_event:
		return
	_next_event = t + _rng.randf_range(10.0, 16.0)
	var pool := ["cough", "knock", "jackdaws"]
	if open >= 1: pool += ["gas", "rats"]
	if open >= 3: pool += ["shubin", "gas"]
	if open >= 6 and String(_shown_bands.get(6, "closed")) != "closed": pool.append("flame")
	if open >= 7 and String(_shown_bands.get(7, "closed")) != "closed": pool.append("eyes")
	if _ship_off() < 0.01: pool.append("whistle")
	_start_event(pool[_rng.randi() % pool.size()])

func _start_event(ev: String) -> void:
	_events[ev] = t
	match ev:
		"cough":
			var k := _deep_band(0)
			_ev_band[ev] = k
			if k >= 0: _dip[k] = t + 0.2
			SeamSounds.cough(self, _far(band_y(maxi(k, 0)) + 300.0) if k >= 0 else -14.0)
		"knock":
			var k := _deep_band(0)
			_ev_band[ev] = k
			SeamSounds.knock(self, _far(band_y(maxi(k, 0)) + 300.0) if k >= 0 else -14.0)
			if k >= 0:
				var gx: Array = J.galleries.get(str(k + 1), [300, 1200])
				for j in 3:
					_bursts.append([Vector2(lerpf(float(gx[0]), float(gx[1]), 0.25 + 0.25 * j), band_y(k) + 140.0), t + 0.05 + j * 0.57, 0.45])
					get_tree().create_timer(0.05 + j * 0.57).timeout.connect(func(): _dip[k] = t)
		"gas":
			# firedamp wells up in a level: the canary falls silent, the lamps stretch blue; Shubin coughs
			var k := _deep_band(1)
			if k < 0:
				_events.erase(ev)
				return
			_ev_band[ev] = k
			# the rats know first: they bolt along the floor; then the gas wells up and the canary falls silent
			_events["rats"] = t
			_ev_band["rats"] = k
			SeamSounds.scurry(self, _far(band_y(k) + 300.0))
			get_tree().create_timer(1.4).timeout.connect(func():
				_gas_k[k] = 2.6
				_quiet[k] = t + 1.2
				SeamSounds.hiss(self, _far(band_y(k) + 200.0)))
			get_tree().create_timer(3.0).timeout.connect(func(): SeamSounds.cough(self, _far(band_y(k) + 300.0) - 4.0))
		"flame":
			SeamSounds.flame(self, _far(band_y(6) + 200.0))
		"whistle":
			SeamSounds.whistle(self, _far(float((J.ship.at as Array)[1])) if J.has("ship") else -14.0)
		"rats":
			_ev_band[ev] = _deep_band(0)
			SeamSounds.scurry(self, _far(band_y(maxi(int(_ev_band[ev]), 0)) + 300.0))
		"jackdaws":
			SeamSounds.jackdaws(self, _far(float((J.pillars as Array)[1])) if J.has("pillars") else -12.0)
		"shubin":
			_ev_band[ev] = _deep_band(2)
		"eyes":
			SeamSounds.cough(self, _far(band_y(7) + 300.0) - 6.0)

func _events_live(c: CanvasItem) -> void:
	for ev in _events.keys():
		var s := t - float(_events[ev])
		var done := false
		var k := int(_ev_band.get(ev, -1))
		match ev:
			"cough":
				# a lamp in that level shudders at the cough, a little dust falls
				done = s > 2.5
				if k >= 0 and s < 1.6:
					var gx: Array = J.galleries.get(str(k + 1), [300, 1200])
					var x := lerpf(float(gx[0]), float(gx[1]), 0.5)
					for j in 5:
						var yy := band_y(k) + 130.0 + 300.0 * s * s + j * 9.0
						c.draw_circle(Vector2(x + j * 13.0 - 30.0, yy), 2.2, Color(0.2, 0.18, 0.17, 0.8 * (1.0 - s / 1.6)))
			"knock":
				# three knocks: each shakes dust off the roof somewhere along the level
				done = s > 2.6
				if k >= 0:
					var gx: Array = J.galleries.get(str(k + 1), [300, 1200])
					for j in 3:
						var q := s - (0.05 + j * 0.57)
						if q < 0.0 or q > 0.9: continue
						var x := lerpf(float(gx[0]), float(gx[1]), 0.25 + 0.25 * j)
						for i in 4:
							c.draw_circle(Vector2(x + i * 9.0 - 14.0, band_y(k) + 120.0 + 260.0 * q * q + i * 5.0), 2.4, Color(0.22, 0.2, 0.18, 0.85 * (1.0 - q)))
			"gas":
				done = s > 10.0
			"rats":
				# rats bolt along the level's floor towards the incline: they always run before the gas
				done = s > 3.0
				if k >= 0 and _crew_ok("rat"):
					var d := k + 1
					var gx: Array = J.galleries.get(str(d), [300, 1200])
					var right := d > 4
					var n := int(J.crew_n.rat)
					for i in 3:
						var u := clampf((s - i * 0.25) / 2.4, 0.0, 1.0)
						if u <= 0.0 or u >= 1.0: continue
						var x := lerpf(float(gx[1]), float(gx[0]), u) if not right else lerpf(float(gx[0]), float(gx[1]), u)
						var fr := "rat/%02d.png" % (int(s * 16.0 + i * 3) % n)
						var fs := _size(fr)
						_put_scaled(c, fr, Vector2(x - fs.x / 2, band_y(k) + floor_of(d) - fs.y + 4.0 - i * 3.0), fs, not right)
			"flame":
				# the burner's flame runs under the roof of 350 m: a blue sheet rolling along, the haze burning off
				done = s > 3.2
				if J.has("roofs") and J.roofs.has("7"):
					var rf: Array = J.roofs["7"]
					var y := band_y(6) + float(rf[2]) + 30.0
					var x0 := float(rf[0])
					var x1 := float(rf[1])
					var u := clampf(s / 2.4, 0.0, 1.0)
					var front_x := lerpf(x1, x0, u)
					for i in 18:
						var q := i / 17.0
						var x := lerpf(front_x, x1, q)
						var fl := (1.0 - q) * clampf((3.2 - s) / 0.8, 0.0, 1.0)
						var h := 24.0 + 22.0 * sin(t * 13.0 + i * 1.9)
						_light(c, Vector2(x, y), 70, Color(FLAME, 0.35 * fl))
						c.draw_line(Vector2(x, y + 12), Vector2(x + sin(t * 9.0 + i) * 6.0, y - h * fl), Color(0.55, 0.8, 1.0, 0.8 * fl), 7.0)
					if s < 0.1: _gas_k[6] = 0.2
			"eyes":
				# two coal-red eyes open in the old fall at 400 m, look along the level, close
				done = s > 5.6
				if J.has("fall_eyes") and open >= 7:
					var ey: Array = J.fall_eyes
					_eyes(c, Vector2(float(ey[0]), band_y(7) + float(ey[1])), s, 1.4)
			"shubin":
				# the shadow of a stooped old miner in a shaggy coat walks along a far level with a pole torch; its
				# light is cold and wavering. Nobody casts it
				done = s > 10.0
				if k >= 0 and _crew_ok("shubin"):
					var d := k + 1
					var gx: Array = J.galleries.get(str(d), [300, 1200])
					var u := clampf(s / 10.0, 0.0, 1.0)
					var x := lerpf(float(gx[0]) + 60.0, float(gx[1]) - 60.0, u)
					var n := int(J.crew_n.shubin)
					var fr := "shubin/%02d.png" % (int(s * 4.0) % n)
					var fs := _size(fr) * 1.2
					var al := clampf(s / 1.5, 0.0, 1.0) * clampf((10.0 - s) / 1.5, 0.0, 1.0)
					var fy := band_y(k) + floor_of(d)
					var tip := Vector2(x + fs.x * 0.44, fy - fs.y * 0.93)
					# his torch's cold blue light on the wall behind him, the shadow over it
					_light(c, tip + Vector2(-fs.x * 0.3, fs.y * 0.3), 260, Color(FLAME, 0.22 * al))
					c.draw_texture_rect(tex(fr), Rect2(Vector2(x - fs.x / 2, fy - fs.y + 4.0), fs), false, Color(0.0, 0.0, 0.03, 0.85 * al))
					var fl := 0.7 + 0.3 * sin(t * 13.0) + 0.15 * sin(t * 29.0)
					_light(c, tip, 90, Color(FLAME, 0.5 * al * fl))
					for j in 3:
						c.draw_line(tip + Vector2(0, 6), tip + Vector2(sin(t * 11.0 + j * 2.0) * 6.0, -16.0 - 14.0 * fl - j * 6.0), Color(0.55 + 0.15 * j, 0.8, 1.0, 0.7 * al), 7.0 - j * 2.0)
					# the canary there falls silent while he passes; he coughs half way
					if s > 2.0 and s < 2.1 and not _quiet.has(k): _quiet[k] = t
					if _passed("shubin_cough", s, 100.0, 5.0): SeamSounds.cough(self, _far(fy) - 4.0)
			"whistle", "jackdaws":
				done = s > 3.0
		if done:
			_events.erase(ev)
			_ev_band.erase(ev)

func _tremor() -> void:
	if String(_shown_bands.get(8, "")) == "done" and not bool(Save.d.boss_won[area]) and t > _next_tremor:
		_next_tremor = t + _rng.randf_range(20.0, 32.0)
		if t - _tremor_at > 5.0:
			_tremor_at = t
	var s := t - _tremor_at
	var amp := 0.0
	if s >= 0.0 and s < 1.6:
		amp = 5.0 * (1.0 - s / 1.6)
	position.x = sin(t * 47.0) * amp * scale.x
	if s >= 0.0 and s < 0.05 and not _cue.has("tremor%d" % int(_tremor_at)):
		_cue["tremor%d" % int(_tremor_at)] = true
		amb.shot("rockfall", -6.0, 0.55)
		SeamSounds.cough(self, -6.0)

## the lullaby: the canary sings in Shubin's hollow, cold blue-green lights drift out of the gas to its cage and go
## out there one by one, the old coat on its peg stirs; the seam sighs now and then
func _finale(c: CanvasItem) -> void:
	if String(_shown_bands.get(8, "")) != "done" or not J.has("hollow"):
		return
	var y := band_y(8)
	var hl: Dictionary = J.hollow
	var cp: Array = hl.c
	var ctr := Vector2(float(cp[0]), y + float(cp[1]))
	var cg: Array = J.cages.get("9", [ctr.x + 300.0, 200.0])
	var cage := Vector2(float(cg[0]), y + float(cg[1]) + 30.0)
	var sh := clampf(1.0 - (t - _tremor_at) / 2.0, 0.0, 1.0)
	_light(c, ctr, 300, Color(0.45, 0.95, 0.8, 0.12 + 0.05 * sin(t * 0.8) + 0.1 * sh))
	for j in 9:
		var u := fmod(t * 0.07 + j / 9.0, 1.0)
		var from := ctr + Vector2(sin(j * 2.3) * float(hl.get("rx", 300)) * 0.8, cos(j * 1.7) * float(hl.get("ry", 160)) * 0.6)
		var p := from.lerp(cage, u * u) + Vector2(sin(t * 0.9 + j) * 20.0 * (1.0 - u), 0)
		var al := sin(PI * u)
		_light(c, p, 50, Color(0.5, 1.0, 0.85, 0.6 * al))
		c.draw_circle(p, 5.0, Color(0.9, 1.0, 0.95, 0.95 * al))
	if J.has("coat"):
		var co: Array = J.coat
		_light(c, Vector2(float(co[0]), y + float(co[1])), 90, Color(0.4, 0.8, 0.7, 0.08 + 0.08 * sin(t * 0.5)))
	if _passed("lullaby", t, 9.0, 1.0) and _far(cage.y) > -14.0:
		SeamSounds.song(self, _far(cage.y) - 2.0)

## after a win the level's flint flies down into the depth it came from: black flint in white crusts and grey iron
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
	var from := Vector2(770, -position.y / scale.y + 40)
	var n_ore := mini(int(_react.ore), 10)
	var n_iron := mini(int(_react.iron), 8)
	for i in n_ore + n_iron:
		var u := (s - 0.4 - i * 0.09) / 0.9
		if u < 0.0 or u > 1.4:
			continue
		var iron := i >= n_ore
		var tgt := to + Vector2((i % 5 - 2) * 34 + sin(i * 2.3) * 10, (i % 3) * 8)
		var glow := Color(0.75, 0.8, 0.9) if iron else Color(0.95, 0.97, 1.0)
		if u <= 1.0:
			var e := u * u * (3.0 - 2.0 * u)
			var p := from.lerp(tgt, e) + Vector2(sin(i * 1.7) * 140 * sin(PI * u), -220 * sin(PI * u))
			c.draw_circle(p, 22.0, Color(glow, 0.22))
			_flint(c, p, 22.0, iron, i, t * (3.0 + (i % 3)))
		else:
			var f := (u - 1.0) / 0.4
			_light(c, tgt, 60 + 70 * f, Color(glow, 0.6 * (1.0 - f)))
			_flint(c, tgt + Vector2(0, -8), 22.0 * (1.0 - smoothstep(0.5, 1.0, f)), iron, i, 0.0)
		if _passed("ore%d" % i, u, 1.0, 1.0):
			amb.shot("coin", -12.0, 0.8 + (i % 4) * 0.05)

## a knobbly flint nodule (white crust, a glossy black broken face) or a lump of grey iron
func _flint(c: CanvasItem, at: Vector2, r: float, iron: bool, seed_: int, spin: float) -> void:
	if r < 1.0:
		return
	var pts := PackedVector2Array()
	var rim := PackedVector2Array()
	for j in 8:
		var a := spin + TAU * j / 8.0
		var rr := r * (0.7 + 0.3 * absf(sin(seed_ * 3.1 + j * 1.9)))
		pts.append(at + Vector2.from_angle(a) * rr)
		rim.append(at + Vector2.from_angle(a) * (rr + 5.0))
	c.draw_colored_polygon(rim, INK)
	if iron:
		c.draw_colored_polygon(pts, Color(0.36, 0.35, 0.37))
		return
	c.draw_colored_polygon(pts, Color(0.9, 0.88, 0.82))
	var face := PackedVector2Array()
	for j in 5:
		var a := spin + 0.4 + TAU * 0.5 * j / 4.0
		face.append(at + Vector2.from_angle(a) * r * 0.62)
	c.draw_colored_polygon(face, Color(0.1, 0.1, 0.12))
	c.draw_line(face[1], face[2], Color(0.6, 0.62, 0.7, 0.8), 1.5)

# ---------------------------------------------------------------- crews and sounds

func guide_db() -> float:
	return _far(guide_head().y + 60.0)

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
		var who := String(cr.work[0])
		var db := _far(float(b.y) + floor_of(int(b.d))) - k * 1.0 + (0.0 if k == sel else -4.0)
		if cr.has("hit"):
			if _passed("hit%d" % k, _crew_v(k, t), _loop(cr), _hit_at(cr)) and (k == sel or randf() < 0.15):
				SeamSounds.strike(self, who, db)
	SeamSounds.of(self).tick(self)
