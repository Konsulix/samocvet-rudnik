class_name WebView
extends MineView
## Spider Hollow (mine 6, the Tsuchigumo's - a mine of its own, outside the first arc's chain): an Edo-period silver mine
## like Iwami Ginzan in a steep valley of cedars, moss and mist, drawn like Old Adit (MineView) but laid out its own way
## (docs/mine-design.md §9, docs/mine6-tsuchigumo.md): a long stair of vermilion torii climbs the terraces past the
## miners' houses, the smelting hut, the silver store and the shrine; under the rope bridge the valley's cleft narrows
## into a CREVICE that goes on down the middle of the screen through every depth, webbed across, a rope ladder and the
## spider's own silver line hanging down it. Each depth is a hand-dug gallery on one side of the crevice and a small
## chamber with the niche on the other, a plank walkway between them. The life of the place is the RAIN and the WEBS:
## every 10-14 s a summer shower sweeps down the valley, the mist thickens, the water wheel runs faster, the dew on the
## webs flashes; at night fireflies. Signs of the spider: its line lowering out of the dark for a lamp, eight eyes far
## down the crevice, a wandering monk on the bridge whose shadow in the mist has eight legs, spiderlings over a wall.
## Pictures and coordinates: assets/mine/spider_hollow/ + mine.json (art/zone/export_mine6.py), source px of the
## 1536-wide stack: the sky, the surface, the section under it, the depth bands.

const WDIR := "res://assets/mine/spider_hollow/"
## the surface's places in drawing order (their pictures meet at soft edges)
const WPLACES := ["wheel", "houses", "shrine", "smelter", "kura", "bridge"]
## the depths whose job is built in the gallery itself: its stages are the band's pictures
const WBAND_JOBS := {7: "cocoons", 8: "lanterns", 9: "lair"}
const WSTAGES := ["clear", "step1", "step2", "done"]
const WEB_EYE := Color(1.0, 0.16, 0.1)

var _wb_fx: Node2D          # smoke (particles in the picture's own coordinates)
var _wb_smokes: Array = []  # [particles, the place it belongs to, the step from which it smokes]
var _wb_hold := {}          # depth -> when its crew's reaction began
var _rain_at := -100.0      # the last shower, and the next
var _next_rain := 4.0
var _rain_k := 1.0
var _wheel_a := 0.0         # the water wheel's turn
var _wb_flies: Array = []   # fireflies: [x, y, phase, speed]
var _wb_mist: Array = []    # mist banks drifting across: [y, speed, size, phase]

const RAIN_LEN := 7.0
## the ore basket on its rope down the crevice (from the bridge's rope): to the depth being dug and back up, heaped
var _bk_from := 0.0
var _bk_to := 0
var _bk_y := 0.0
var _bk_up := false
var _bk_sw := 0.0
const BK_V := 230.0         # source px a second along the rope
const BK_WAIT := 2.4
const LEG_LEN := 7.0        # the spider's leg out of the crevice

func _init() -> void:
	dir = WDIR

## the valley: the cave's breath under the rain and the cicadas (WebSounds' own loops)
func amb_beds() -> Array:
	return ["cave"]

func available_here() -> bool:
	return FileAccess.file_exists(WDIR + "mine.json")

func _ready() -> void:
	super()
	_wb_fx = Node2D.new()
	add_child(_wb_fx)
	move_child(_wb_fx, live.get_index())
	var r := RandomNumberGenerator.new()
	r.seed = 606
	for i in 26:
		_wb_flies.append([r.randf(), r.randf(), r.randf_range(0, TAU), r.randf_range(0.6, 1.4)])
	for i in 7:
		_wb_mist.append([r.randf(), r.randf_range(14.0, 30.0) * (1 if i % 2 else -1), r.randf_range(500, 900), r.randf()])

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
			if WBAND_JOBS.has(d):
				st = WSTAGES[clampi(int(steps.get(WBAND_JOBS[d], 0)), 0, 3)]
		var lived: bool = k <= open and k < wins.size() and int(wins[k]) >= 2 and J.crews.has(str(d))
		_bands.append({y = y0 + k * float(J.band), state = st, d = d, lived = lived, k = k})
	H = y0 + _bands.size() * float(J.band)
	if _set_area != a:
		_events = {}
		_next_event = 7.0
		_set_area = a
		_bk_from = t
		_bk_to = sel
	surf.texture = tex("surface.png")
	surf.scale = Vector2.ONE / K
	surf.material = null
	still.material = null
	if J.has("sway") and ResourceLoader.exists(dir + "web_mask.png"):
		var sm := ShaderMaterial.new()
		sm.shader = load("res://shaders/mine_sway_mask.gdshader")
		var sr: Array = J.sway.rect
		sm.set_shader_parameter("mask", tex("web_mask.png"))
		sm.set_shader_parameter("mask_rect", Vector4(float(sr[0]), float(sr[1]), float(sr[2]), float(sr[3])))
		sm.set_shader_parameter("amp", 4.0)
		sm.set_shader_parameter("to_mine", 1.0 / K)
		surf.material = sm
		var stm := sm.duplicate() as ShaderMaterial
		stm.set_shader_parameter("to_mine", 1.0)
		still.material = stm
	_changes()
	if not last_result.is_empty() and int(last_result.area) == a:
		var k := clampi(int(last_result.k), 0, _bands.size() - 1)
		var t0 := t + 0.7
		var v := _wb_crew_v(k, t0)
		var ln := _loop(J.crews.get(str(int(_bands[k].d)), {}))
		if ln > 0.0:
			t0 += (ceilf(v / ln) * ln - v) / CREW_FPS
		_wb_hold[k] = t0
		_react = {k = k, won = bool(last_result.won), t0 = t0, iron = int(last_result.iron), ore = int(last_result.ore)}
		if focus_y < 0: focus_y = band_y(k) + float(J.band) * 0.5
		last_result = {}
	_wb_setup_fx()
	_make_motes()
	_find_niches()
	still.queue_redraw()
	front.queue_redraw()

## what changed since the screen was last shown: new stages come in (ink, then colour), a newly opened level shows
## through a burst of dust and torn silk, the people of a level fade in after its second win
func _changes() -> void:
	var places := {}
	for p in WPLACES: places[p] = int(steps.get(p, 0))
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
	for p in WPLACES:
		var was := int(last.places.get(p, 0))
		var now := int(places[p])
		if now <= was:
			continue
		if focus_y < 0: focus_y = job_pos(p).y
		_shown_places[p] = was
		var at: Array = J.places[p]
		_reveal("place/%s_%d.png" % [p, now], Vector2(float(at[0]), float(at[1])), wait, func(): _shown_places[p] = now,
			"place/%s_%d.png" % [p, was] if was > 0 else "surface.png", p, WPLACES)
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
			_tremor_at = t + delay + 2.2      # the lair's rope is hung: the whole valley shudders
	for k in lived:
		if lived[k] and not bool(last.lived.get(k, false)):
			_appear[k] = t + wait
			if focus_y < 0: focus_y = band_y(int(k)) + float(J.band) * 0.5

func job_pos(id: String) -> Vector2:
	if J.place_box.has(id):
		var bx: Array = J.place_box[id]
		return Vector2((float(bx[0]) + float(bx[2])) / 2, (float(bx[1]) + float(bx[3])) / 2)
	for d in WBAND_JOBS:
		if WBAND_JOBS[d] == id:
			return Vector2(768, band_y(int(d) - 1) + 300)
	return Vector2(768, float(J.sky) + 900)

# ---------------------------------------------------------------- the still pictures

func _draw_still() -> void:
	var c := still
	for p in WPLACES:
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
			_put(c, bp, Vector2(0, float(b.y)))
	_draw_niches(c)
	# the joins: GPT's seam pieces (the rock and the crevice run on from one picture into the next)
	var cv: Array = J.crev
	for b in _bands:
		var sp := "seam/%d.png" % (int(b.k))
		if ResourceLoader.exists(dir + sp):
			var sz := _size(sp)
			_put(c, sp, Vector2(0, float(b.y) - sz.y * 0.5))
	# the crevice as one: a soft dark column down it, deeper the lower
	var top := _cut_top() + float(J.cut) * 0.3
	var cx := (float(cv[0]) + float(cv[1])) * 0.5
	var w := (float(cv[1]) - float(cv[0])) * 0.5
	c.draw_texture_rect(_glow, Rect2(cx - w, top, w * 2.0, H - top), false, Color(0.0, 0.02, 0.01, 0.3))
	_draw_bedrock(c)

## the rope ladder: from the foot of the one in the picture down the cleft and the crevice to the deepest open floor -
## two ropes and wooden rungs, sagging a little between the walkways
func _wb_ladder(c: CanvasItem) -> void:
	if ResourceLoader.exists(dir + "ladder.png"):
		var ld0: Array = J.ladder
		var cv0: Array = J.crev
		var tx := tex("ladder.png")
		var w := tx.get_size().x / K
		var seg := tx.get_size().y / K
		var x := float(cv0[0]) + 30.0
		var y := float(ld0[1]) + 380.0
		var bottom := band_y(open) + floor_of(open + 1)
		# from the foot of the ladder in the picture, slanting to the crevice's wall, then straight down
		var xs := float(ld0[0]) - w / 2
		var join := y + 260.0
		c.draw_set_transform(Vector2(xs, y), atan2(x - xs, 260.0) * -1.0, Vector2.ONE)
		c.draw_texture_rect_region(tx, Rect2(0, 0, w, Vector2(x - xs, 260.0).length()), Rect2(0, 0, tx.get_size().x, minf(tx.get_size().y, Vector2(x - xs, 260.0).length() * K)))
		c.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		y = join
		while y < bottom and y < _seen.y + 100.0:
			var h := minf(seg, bottom - y)
			if y + h > _seen.x - 100.0:
				c.draw_texture_rect_region(tx, Rect2(x, y, w, h), Rect2(0, 0, tx.get_size().x, h * K))
			y += seg
		return
	var ld: Array = J.ladder
	var cv: Array = J.crev
	var x0 := float(ld[0])
	var y0 := float(ld[1]) + 380.0
	var xl := float(cv[0]) + 26.0
	var bottom := band_y(open) + floor_of(open + 1)
	var pts_l := PackedVector2Array()
	var pts_r := PackedVector2Array()
	var y := y0
	var ink := Color(0.04, 0.035, 0.03)
	var rope := Color(0.42, 0.33, 0.22)
	while y <= bottom:
		var q := clampf((y - y0) / 260.0, 0.0, 1.0)
		var x := lerpf(x0, xl, q * q * (3.0 - 2.0 * q)) + 3.0 * sin(y * 0.004)
		pts_l.append(Vector2(x, y))
		pts_r.append(Vector2(x + 34.0, y))
		y += 20.0
	if pts_l.size() < 2:
		return
	for i in range(0, pts_l.size(), 2):
		c.draw_line(pts_l[i] + Vector2(-2, 0), pts_r[i] + Vector2(2, 0), ink, 7.0)
		c.draw_line(pts_l[i], pts_r[i], Color(0.36, 0.26, 0.16), 4.0)
	for pts in [pts_l, pts_r]:
		c.draw_polyline(pts, ink, 6.0)
		c.draw_polyline(pts, rope, 2.5)

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

func _wb_niche_at(k: int) -> Vector2:
	var nc: Array = J.niches[str(k + 1)]
	return Vector2(float(nc[0]), band_y(k) + float(nc[1]))

func niche_at(p: Vector2) -> Dictionary:
	for k in _niche_want:
		var key := Spec.key_of(Spec.of_stone(_niche_want[k]))
		if not _niche_tex.has(key):
			continue
		var at := _wb_niche_at(k)
		var sz := _niche_size(_niche_tex[key])
		if Rect2(at.x - sz.x / 2 - 30, at.y - sz.y - 30, sz.x + 60, sz.y + 50).has_point(p):
			return _niche_want[k]
	return {}

## the stones on their pedestals: a soft shadow, an ink outline, the stone warmed by the little shell lamp
func _draw_niches(c: CanvasItem) -> void:
	for k in _niche_want:
		var key := Spec.key_of(Spec.of_stone(_niche_want[k]))
		if not _niche_tex.has(key) or String(_shown_bands.get(k, "")) == "closed":
			continue
		var tx: Texture2D = _niche_tex[key]
		var at := _wb_niche_at(k)
		var sz := _niche_size(tx)
		var pos := Vector2(at.x - sz.x / 2, at.y - sz.y + 8)
		c.draw_texture_rect(_glow, Rect2(Vector2(at.x - sz.x * 0.6, at.y - 10), Vector2(sz.x * 1.2, 22)), false, Color(0.04, 0.05, 0.03, 0.6))
		for dv in [Vector2(-3, 0), Vector2(3, 0), Vector2(0, -3), Vector2(0, 3), Vector2(-2, -2), Vector2(2, 2), Vector2(-2, 2), Vector2(2, -2)]:
			c.draw_texture_rect(tx, Rect2(pos + dv, sz), false, Color(0.05, 0.06, 0.04, 1.0))
		c.draw_texture_rect(tx, Rect2(pos, sz), false, Color(1.0, 0.95, 0.85))

# ---------------------------------------------------------------- smoke (particles in the picture's coordinates)

func _wb_setup_fx() -> void:
	for ch in _wb_fx.get_children(): ch.queue_free()
	_wb_smokes = []
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
		p.amount = 18 if big else 10
		p.lifetime = 10.0 if big else 6.0
		p.preprocess = p.lifetime
		p.emission_sphere_radius = 8.0 * k
		p.direction = Vector2(-0.2, -1)
		p.spread = 10
		p.gravity = Vector2(-6, -3)        # the damp air: it rises slowly and hangs
		p.initial_velocity_min = 14 * k
		p.initial_velocity_max = 24 * k
		p.scale_amount_min = 0.5 * k
		p.scale_amount_max = 0.8 * k
		sc.add_point(Vector2(0, 0.5))
		sc.add_point(Vector2(1, 4.2 if big else 3.0))
		g.set_color(0, Color(0.85, 0.85, 0.8, 0.0))
		g.add_point(0.08, Color(0.6, 0.62, 0.6, 0.6) if big else Color(0.72, 0.74, 0.72, 0.45))
		g.add_point(0.5, Color(0.45, 0.48, 0.46, 0.4))
		g.set_color(g.get_point_count() - 1, Color(0.4, 0.43, 0.42, 0.0))
		p.angular_velocity_min = -10
		p.angular_velocity_max = 10
		p.scale_amount_curve = sc
		p.color_ramp = g
		_wb_fx.add_child(p)
		_wb_smokes.append([p, String(spec.get("place", "")), int(spec.get("from", 0))])
	_wb_update_fx()

func _wb_update_fx() -> void:
	for s in _wb_smokes:
		var pl := String(s[1])
		(s[0] as CPUParticles2D).emitting = pl == "" or int(_shown_places.get(pl, 0)) >= int(s[2])

# ---------------------------------------------------------------- the rain, the wheel, the clock

## how hard it rains `s` seconds after the shower began: it comes in over a second, holds, and thins away
func _rain(s: float) -> float:
	if s < 0.0 or s > RAIN_LEN:
		return 0.0
	return clampf(s / 1.2, 0.0, 1.0) * clampf((RAIN_LEN - s) / 2.5, 0.0, 1.0)

## the evening by the phone's clock: 0 by day (grey-green mist), 1 at night (fireflies, the lanterns brighter)
func _night() -> float:
	var dt := Time.get_datetime_dict_from_system()
	var h := float(dt.hour) + float(dt.minute) / 60.0
	if h >= 19.0 or h < 5.0: return 1.0
	if h >= 17.0: return (h - 17.0) / 2.0
	if h < 7.0: return 1.0 - (h - 5.0) / 2.0
	return 0.0

func _process(delta: float) -> void:
	super(delta)
	if not visible or J.is_empty():
		return
	if Engine.get_process_frames() % 20 == 0:
		_wb_update_fx()
	if t > _next_rain:
		_next_rain = t + _rng.randf_range(10.0, 14.0) + RAIN_LEN * 0.5
		_rain_at = t
		_rain_k = _rng.randf_range(0.7, 1.15)
	var rn := _rain(t - _rain_at) * _rain_k
	if int(_shown_places.get("wheel", 0)) >= 3:
		_wheel_a += delta * (0.35 + 0.35 * rn)
	_wb_basket_move()
	if surf.material is ShaderMaterial:
		var amp := 4.0 + 10.0 * rn
		(surf.material as ShaderMaterial).set_shader_parameter("amp", amp)
		if still.material is ShaderMaterial: (still.material as ShaderMaterial).set_shader_parameter("amp", amp)
	_bk_sw = 10.0 * sin(t * 0.9) + 14.0 * rn * sin(t * 2.3)

## the basket goes down to the walkway of the depth being dug, waits, comes up heaped with ore, waits at the bridge;
## now and then it serves another open depth; the spider's line can catch it on the way ("tug")
func _wb_basket_move() -> void:
	var top := _wb_rope_top().y + 120.0
	var to_y := band_y(_bk_to) + floor_of(_bk_to + 1) - 40.0
	var down := maxf(0.5, (to_y - top) / BK_V)
	if _events.has("tug"):
		_bk_from += get_process_delta_time()      # held while the line has it
	var s := t - _bk_from
	var cyc := down * 2.0 + BK_WAIT * 2.0
	if s > cyc:
		_bk_from = t
		_bk_to = sel if _rng.randf() < 0.6 else _rng.randi_range(0, open)
		s = 0.0
		to_y = band_y(_bk_to) + floor_of(_bk_to + 1) - 40.0
		down = maxf(0.5, (to_y - top) / BK_V)
	var y := top
	_bk_up = s >= down + BK_WAIT
	if s < down: y = lerpf(top, to_y, smoothstep(0.0, 1.0, s / down))
	elif s < down + BK_WAIT: y = to_y
	elif s < down * 2.0 + BK_WAIT: y = lerpf(to_y, top, smoothstep(0.0, 1.0, (s - down - BK_WAIT) / down))
	if _events.has("tug"):
		var q := t - float(_events.tug)
		y -= 110.0 * smoothstep(0.0, 1.0, clampf(q / 1.6, 0.0, 1.0)) * clampf((5.0 - q) / 1.2, 0.0, 1.0) + 8.0 * sin(q * 18.0) * clampf(2.0 - q, 0.0, 1.0)
	_bk_y = y

## a GPT rope repeated along a line (its drawing runs down its texture's y)
func _wb_rope(c: CanvasItem, a: Vector2, b: Vector2) -> void:
	var tx := tex("rope.png")
	var w := tx.get_size().x / K
	var seg := tx.get_size().y / K
	var d := b - a
	var ln := d.length()
	if ln < 1.0: return
	c.draw_set_transform(a, d.angle() - PI / 2, Vector2.ONE)
	var y := 0.0
	while y < ln:
		var h := minf(seg, ln - y)
		c.draw_texture_rect_region(tx, Rect2(-w / 2, y, w, h), Rect2(0, 0, tx.get_size().x, h * K))
		y += seg
	c.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

## where the basket's rope leaves the bridge: the windlass's drum once the bridge is built
func _wb_rope_top() -> Vector2:
	if J.has("winch") and int(_shown_places.get("bridge", 0)) >= 3:
		var wd: Array = J.winch.drum
		return Vector2(float(wd[0]), float(wd[1]))
	var th: Array = J.thread
	return Vector2(float(th[0]), float(th[1]))

## the windlass on the bridge and its winchman, cranking while the basket is on its way
var _crank := 0.0
func _wb_winch(c: CanvasItem) -> void:
	if not J.has("winch") or int(_shown_places.get("bridge", 0)) < 3 or not ResourceLoader.exists(dir + "winch.png"):
		return
	var w: Dictionary = J.winch
	var at: Array = w.at
	var sz := _size("winch.png")
	if float(at[1]) < _seen.x - 200.0 or float(at[1]) - 300.0 > _seen.y:
		return
	var moving := absf(_bk_y - _bk_prev) > 0.3
	_bk_prev = _bk_y
	if moving: _crank += get_process_delta_time() * 14.0
	_put(c, "winch.png", Vector2(float(at[0]) - sz.x / 2, float(at[1]) - sz.y))
	if _crew_ok("winchman"):
		var n := int(J.crew_n.winchman)
		var fr := "winchman/%02d.png" % (int(_crank) % n)
		var fs := _size(fr)
		var mx: Array = w.man
		_put(c, fr, Vector2(float(mx[0]) - fs.x / 2, float(mx[1]) - fs.y), bool(w.get("man_flip", true)))
var _bk_prev := 0.0

## the basket: a hemp rope from the bridge, a deep woven basket swinging on it, heaped with grey ore and silver going up;
## while the spider's line has it, a glinting thread runs up from it into the dark
func _wb_basket(c: CanvasItem) -> void:
	var top := _wb_rope_top()
	var at := Vector2(top.x + _bk_sw * clampf((_bk_y - top.y) / 2500.0, 0.1, 1.0), _bk_y)
	if at.y < _seen.x - 200.0 or top.y > _seen.y + 200.0:
		return
	var ang := clampf(_bk_sw * 0.01, -0.15, 0.15)
	if ResourceLoader.exists(dir + "basket_full.png") and ResourceLoader.exists(dir + "rope.png"):
		var bt := tex("basket_full.png" if _bk_up else "basket_empty.png")
		var bs := _size("basket_full.png")
		var hook := at + Vector2(0, -bs.y * 0.5)
		_wb_rope(c, top, hook)
		c.draw_set_transform(at, ang, Vector2.ONE)
		c.draw_texture_rect(bt, Rect2(-bs / 2, bs), false)
		c.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		if _events.has("tug"):
			var q2 := t - float(_events.tug)
			var al2 := clampf(q2 / 0.5, 0.0, 1.0) * clampf((5.0 - q2) / 0.8, 0.0, 1.0)
			c.draw_line(at + Vector2(10, 30), Vector2(at.x + 30.0, at.y - 900.0), Color(0.9, 0.95, 1.0, 0.7 * al2), 1.8)
		return
	var ink := Color(0.04, 0.035, 0.03)
	c.draw_line(top, at + Vector2(0, -90), ink, 6.0)
	c.draw_line(top, at + Vector2(0, -90), Color(0.55, 0.45, 0.3), 2.8)
	c.draw_set_transform(at, ang, Vector2.ONE * 1.8)
	c.draw_line(Vector2(-26, -10), Vector2(0, -50), ink, 3.0)
	c.draw_line(Vector2(26, -10), Vector2(0, -50), ink, 3.0)
	c.draw_colored_polygon(PackedVector2Array([Vector2(-34, -14), Vector2(34, -14), Vector2(26, 34), Vector2(-26, 34)]), ink)
	c.draw_colored_polygon(PackedVector2Array([Vector2(-30, -10), Vector2(30, -10), Vector2(23, 30), Vector2(-23, 30)]), Color(0.52, 0.4, 0.22))
	for j in 4:
		var yy := -4.0 + j * 9.0
		c.draw_line(Vector2(-29 + j * 1.8, yy), Vector2(29 - j * 1.8, yy), Color(0.3, 0.22, 0.12), 2.0)
	for j in 6:
		var xx := -24.0 + j * 9.6
		c.draw_line(Vector2(xx, -9), Vector2(xx * 0.8, 29), Color(0.38, 0.28, 0.15, 0.8), 1.5)
	if _bk_up:
		for j in 6:
			var p := Vector2(-20 + j * 8, -15 - 5 * absf(sin(j * 1.9)))
			c.draw_circle(p, 7.5, ink)
			c.draw_circle(p, 6.0, Color(0.45, 0.47, 0.5) if j % 3 else Color(0.82, 0.86, 0.92))
			if j % 3 == 0: c.draw_circle(p + Vector2(-2, -2), 2.0, Color(1, 1, 1, 0.9))
	c.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	if _events.has("tug"):
		var q := t - float(_events.tug)
		var al := clampf(q / 0.5, 0.0, 1.0) * clampf((5.0 - q) / 0.8, 0.0, 1.0)
		c.draw_line(at + Vector2(10, 30), Vector2(at.x + 30.0, at.y - 900.0), Color(0.9, 0.95, 1.0, 0.7 * al), 1.8)
		_light(c, at + Vector2(10, 30), 20, Color(0.9, 0.97, 1.0, 0.5 * al))

# ---------------------------------------------------------------- lights

func _lights(c: CanvasItem) -> void:
	var rn := _rain(t - _rain_at) * _rain_k
	var nt := _night()
	var sl: Dictionary = J.surface_lamps
	var i := 0
	for place in sl:
		if place != "" and int(_shown_places.get(place, 0)) < 3:
			continue
		for l in sl[place]:
			i += 1
			var col := Color(1.0, 0.66, 0.3, (0.3 + 0.12 * nt) * _flick(i) * (1.0 - 0.25 * rn))
			_light(c, Vector2(float(l[0]), float(l[1])), 80 * float(l[2]), col)
	if int(_shown_places.get("smelter", 0)) >= 3 and J.has("furnace"):
		var fp: Array = J.furnace
		var br := 0.45 + 0.15 * sin(t * 2.3) + 0.1 * sin(t * 7.1)
		_light(c, Vector2(float(fp[0]), float(fp[1])), 120, Color(1.0, 0.45, 0.12, br))
		_light(c, Vector2(float(fp[0]), float(fp[1])), 40, Color(1.0, 0.8, 0.4, br))
	for b in _bands:
		var k := int(b.k)
		if String(_shown_bands.get(k, b.state)) == "closed" or not _band_seen(b):
			continue
		var ls: Array = J.lamps.get(str(int(b.d)), [])
		for j in ls.size():
			var l: Array = ls[j]
			_light(c, Vector2(float(l[0]), float(b.y) + float(l[1])), 140, Color(1.0, 0.68, 0.3, 0.26 * _flick(k * 3 + j)))

# ---------------------------------------------------------------- the surface alive

func _surface_live(c: CanvasItem) -> void:
	var sky := float(J.sky)
	_wb_wheel(c)
	_wb_falls(c)
	_wb_webs(c)
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
		if nm == "smelt24":
			# the rake's hot end and the furnace's glow on him
			_light(c, pos + Vector2(fs.x * (0.15 if flip else 0.85), fs.y * 0.45), 50, Color(1.0, 0.5, 0.15, 0.3 + 0.1 * sin(t * 3.0)))

## the water wheel: the face-on drawing turned on the picture's axle, squeezed into the picture's ellipse; it runs once
## the wheel is rebuilt, faster in the rain
func _wb_wheel(c: CanvasItem) -> void:
	if int(_shown_places.get("wheel", 0)) < 3 or not J.has("wheel") or not ResourceLoader.exists(dir + "wheel.png"):
		return
	var wh: Dictionary = J.wheel
	var at := Vector2(float(wh.at[0]), float(wh.at[1]))
	var tx := tex("wheel.png")
	var rx := float(wh.rx)
	var ry := float(wh.ry)
	c.draw_set_transform(at, 0.0, Vector2(rx / ry, 1.0))
	c.draw_set_transform_matrix(Transform2D(0.0, Vector2(rx / ry, 1.0), 0.0, at) * Transform2D(_wheel_a, Vector2.ZERO))
	c.draw_texture_rect(tx, Rect2(Vector2(-ry, -ry), Vector2(ry, ry) * 2.0), false)
	c.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	# the axle's wet hub catches the light
	c.draw_circle(at, 9.0, Color(0.05, 0.05, 0.04))
	c.draw_circle(at + Vector2(-2, -2), 3.0, Color(0.7, 0.75, 0.7, 0.6))

## falling water: bright threads sliding down each fall's box (the flume's only once the wheel is fed)
func _wb_falls(c: CanvasItem) -> void:
	var rn := _rain(t - _rain_at) * _rain_k
	var i := 0
	for f in J.falls:
		i += 1
		if i == 1 and int(_shown_places.get("wheel", 0)) < 3:
			continue
		var a: Array = f[0]
		var b: Array = f[1]
		var x0 := float(a[0])
		var x1 := float(b[0])
		var y0 := float(a[1])
		var y1 := float(b[1])
		for j in 14:
			var x := lerpf(x0, x1, fmod(j * 0.618, 1.0))
			var u := fmod(t * (0.9 + 0.3 * rn) + j * 0.37, 1.0)
			var y := lerpf(y0, y1, u)
			c.draw_line(Vector2(x, y), Vector2(x + 1.0, y + 40.0), Color(0.9, 0.97, 1.0, 0.35 * sin(PI * u)), 2.5)
		_light(c, Vector2((x0 + x1) * 0.5, y1), 70, Color(0.85, 0.95, 1.0, 0.08 + 0.06 * rn))

## the dew on the webs: beads of light running along each strand and round each web's spiral; brighter in the rain;
## when the spider stirs (the "web" event) every strand trembles and flashes
func _wb_webs(c: CanvasItem) -> void:
	var rn := _rain(t - _rain_at) * _rain_k
	var tr := 0.0
	if _events.has("web"):
		var s := t - float(_events.web)
		tr = sin(PI * clampf(s / 3.0, 0.0, 1.0))
	var wb: Dictionary = J.webs
	var i := 0
	for st_ in wb.strands:
		var st: Array = st_
		i += 1
		for j in 7:
			var u := fmod(t * 0.05 * (1.0 + 0.3 * sin(i)) + j / 7.0 + i * 0.13, 1.0)
			var f := u * (st.size() - 1)
			var i0 := mini(int(f), st.size() - 2)
			var pa: Array = st[i0]
			var pb: Array = st[i0 + 1]
			var p := Vector2(float(pa[0]), float(pa[1])).lerp(Vector2(float(pb[0]), float(pb[1])), f - i0)
			p.y += 3.0 * sin(t * 1.3 + i) + tr * 5.0 * sin(t * 30.0 + j)
			var g := (0.3 + 0.4 * rn + 0.6 * tr) * (0.5 + 0.5 * sin(t * 2.0 + j * 1.7 + i))
			if g > 0.05:
				_light(c, p, 16, Color(0.9, 0.97, 1.0, 0.4 * g))
				c.draw_circle(p, 2.2, Color(1, 1, 1, 0.8 * g))
	for h_ in wb.hubs:
		var h: Array = h_
		var at := Vector2(float(h[0]), float(h[1]))
		var r := float(h[2])
		for j in 10:
			var a := t * 0.12 + j * TAU / 10.0
			var rr := r * fmod(0.25 + j * 0.37 + t * 0.03, 1.0)
			var p := at + Vector2.from_angle(a) * rr + Vector2(0, tr * 4.0 * sin(t * 28.0 + j))
			var g := (0.35 + 0.4 * rn + 0.6 * tr) * (0.5 + 0.5 * sin(t * 1.6 + j))
			c.draw_circle(p, 2.0, Color(1, 1, 1, 0.75 * g))

## the crevice's own: a web across it at every seam (they hide where the bands meet), the spider's silver line down its
## middle with dew sliding down it, mist; fireflies at night
func _wb_crevice(c: CanvasItem) -> void:
	var cv: Array = J.crev
	var x0 := float(cv[0])
	var x1 := float(cv[1])
	var tr := 0.0
	if _events.has("web"):
		tr = sin(PI * clampf((t - float(_events.web)) / 3.0, 0.0, 1.0))
	if _passed("finale_web", t, 1.0) and String(_shown_bands.get(8, "")) == "done":
		pass
	var fin := 1.0 if String(_shown_bands.get(8, "")) == "done" else 0.0
	for b in _bands:
		if not _band_seen(b) or int(b.k) == 0:
			continue
		pass
	# the line: from the rope in the picture straight down the middle to below the deepest open level
	var th: Array = J.thread
	var tx := (x0 + x1) * 0.5 + 18.0
	var ty0 := float(th[1]) + 120.0
	var ty1 := band_y(open) + float(J.band) * 1.2
	var sw := 6.0 * sin(t * 0.5)
	var seen0 := maxf(ty0, _seen.x - 50.0)
	var seen1 := minf(ty1, _seen.y + 50.0)
	if seen1 > seen0:
		var a := Vector2(lerpf(float(th[0]), tx, clampf((seen0 - ty0) / 300.0, 0.0, 1.0)) + sw * (seen0 - ty0) / maxf(1.0, ty1 - ty0), seen0)
		var b2 := Vector2(tx + sw * (seen1 - ty0) / maxf(1.0, ty1 - ty0), seen1)
		c.draw_line(a, b2, Color(0.85, 0.9, 0.95, 0.45), 1.6)
		for j in 4:
			var u := fmod(t * 0.12 + j * 0.25, 1.0)
			var y := lerpf(ty0, ty1, u)
			if y < seen0 or y > seen1: continue
			var p := Vector2(tx + sw * (y - ty0) / maxf(1.0, ty1 - ty0), y)
			_light(c, p, 18, Color(0.9, 0.97, 1.0, 0.45))
			c.draw_circle(p, 2.4, Color(1, 1, 1, 0.85))
	# fireflies at night over the stream, the houses' terrace and down the crevice
	var nt := _night()
	if nt > 0.05:
		for f_ in _wb_flies:
			var f: Array = f_
			var deep := float(f[0]) > 0.6
			var p: Vector2
			if deep:
				p = Vector2(lerpf(x0 + 10.0, x1 - 10.0, fmod(float(f[1]) + t * 0.01 * float(f[3]), 1.0)),
					_cut_top() + fmod(float(f[1]) * 3.0, 1.0) * float(J.cut) * 2.0)
			else:
				p = Vector2(fmod(float(f[0]) * 1.6, 1.0) * 1100.0 + 80.0 * sin(t * 0.3 * float(f[3]) + float(f[2])),
					float(J.sky) + 1000.0 + float(f[1]) * 700.0 + 40.0 * sin(t * 0.5 + float(f[2])))
			if p.y < _seen.x or p.y > _seen.y: continue
			var bl := maxf(0.0, sin(t * 1.3 * float(f[3]) + float(f[2]))) ** 3
			if bl > 0.05:
				_light(c, p, 26, Color(0.75, 1.0, 0.45, 0.5 * bl * nt))
				c.draw_circle(p, 2.0, Color(0.9, 1.0, 0.7, bl * nt))

## the web over one seam of the crevice: its own kind and size per depth (an orb web off centre, a torn one with its
## threads hanging, a sagging sheet, or only a few loose strands), swaying a little in the draught, trembling with the spider
func _wb_seam_web(c: CanvasItem, k: int, y: float, x0: float, x1: float, tr: float, fin: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919 * k + 13
	var kind: String = ["orb", "torn", "sheet", "orb", "strands", "torn", "sheet", "orb"][k % 8]
	var w := x1 - x0
	var sway := 3.0 * sin(t * 0.6 + k * 1.3)
	var shake := (tr * 4.0 + fin * 1.5) * sin(t * 26.0 + k)
	var col := Color(0.84, 0.88, 0.86, 0.38)
	var cy := y + rng.randf_range(-40.0, 30.0)
	match kind:
		"orb", "torn":
			var cen := Vector2(lerpf(x0, x1, rng.randf_range(0.3, 0.7)), cy) + Vector2(sway, shake)
			var n := rng.randi_range(7, 12)
			var reach := rng.randf_range(0.6, 1.0) * w * 0.55
			var rot := rng.randf_range(0.0, TAU)
			var spokes := PackedVector2Array()
			for j in n:
				var a := rot + TAU * j / n + rng.randf_range(-0.15, 0.15)
				var e := cen + Vector2.from_angle(a) * reach * rng.randf_range(0.75, 1.15)
				e.x = clampf(e.x, x0 + 4.0, x1 - 4.0)
				spokes.append(e)
				if kind == "torn" and rng.randf() < 0.3:
					# a broken spoke hangs down from the hub
					c.draw_line(cen, cen + Vector2(rng.randf_range(-10, 10) + sway * 2.0, rng.randf_range(30, 70)), col, 1.2)
				else:
					c.draw_line(cen, e, col, 1.3)
			var rings := rng.randi_range(4, 7)
			for ring in rings:
				var rr := 0.18 + ring * (0.8 / rings)
				var pts := PackedVector2Array()
				for j in n + 1:
					if kind == "torn" and rng.randf() < 0.25:
						if pts.size() > 1: c.draw_polyline(pts, Color(col, 0.3), 1.1)
						pts = PackedVector2Array()
						continue
					pts.append(cen.lerp(spokes[j % n], rr) + Vector2(0, 2.0 * rr * sin(j)))
				if pts.size() > 1: c.draw_polyline(pts, Color(col, 0.3), 1.1)
			var g := 0.5 + 0.5 * sin(t * 1.4 + k * 2.0)
			c.draw_circle(cen.lerp(spokes[int(t * 0.3 + k) % n], 0.55), 2.2, Color(1, 1, 1, 0.5 * g))
		"sheet":
			# a sagging hammock of silk between the walls, threads up to the rock above
			var pts := PackedVector2Array()
			var sag := rng.randf_range(30.0, 60.0)
			for j in 13:
				var q := j / 12.0
				pts.append(Vector2(lerpf(x0 + 6.0, x1 - 6.0, q) + sway * sin(PI * q), cy + sag * sin(PI * q) + shake * sin(PI * q)))
			for j in 4:
				var lo := pts.duplicate()
				for i in lo.size(): lo[i] += Vector2(0, -j * 7.0 * sin(PI * float(i) / 12.0))
				c.draw_polyline(lo, Color(col, 0.22 + 0.05 * j), 1.2)
			for j in 6:
				var pp := pts[2 + j * 2 % 10]
				c.draw_line(pp, Vector2(pp.x + rng.randf_range(-20, 20), cy - rng.randf_range(60, 120)), Color(col, 0.25), 1.0)
		"strands":
			for j in rng.randi_range(3, 5):
				var a := Vector2(x0 + 4.0, cy + rng.randf_range(-50, 50))
				var bpt := Vector2(x1 - 4.0, cy + rng.randf_range(-50, 50))
				var mid := (a + bpt) * 0.5 + Vector2(sway, rng.randf_range(10, 40) + shake)
				c.draw_polyline(PackedVector2Array([a, a.lerp(mid, 0.5) + Vector2(0, 6), mid, mid.lerp(bpt, 0.5) + Vector2(0, 6), bpt]), col, 1.2)

## mist banks drifting across the valley; thicker in the rain and towards evening
func _wb_mist_draw(c: CanvasItem) -> void:
	var rn := _rain(t - _rain_at) * _rain_k
	if J.has("stair_mist"):
		var line: Array = J.stair_mist
		var ps := _size("puff.png")
		for i in 9:
			var u := fposmod(t * 0.03 + i / 9.0, 1.0)
			var f := u * (line.size() - 1)
			var i0 := mini(int(f), line.size() - 2)
			var a: Array = line[i0]
			var b: Array = line[i0 + 1]
			var p := Vector2(float(a[0]), float(a[1])).lerp(Vector2(float(b[0]), float(b[1])), f - i0) + Vector2(25.0 * sin(i * 2.1 + t * 0.2), 0)
			var sc := 2.2 + 1.2 * sin(i * 1.7)
			c.draw_texture_rect(tex("puff.png"), Rect2(p - ps * sc / 2, ps * sc), false, Color(0.85, 0.9, 0.88, (0.16 + 0.08 * rn) * sin(PI * u)))
	var y_top := float(J.sky) + 300.0
	var y_bot := _cut_top() + float(J.cut)
	for m_ in _wb_mist:
		var m: Array = m_
		var y := lerpf(y_top, y_bot, float(m[0]))
		if y < _seen.x - 400 or y > _seen.y + 400: continue
		var x := fposmod(float(m[3]) * 2200.0 + t * float(m[1]), 2200.0) - 330.0
		var sz := float(m[2])
		c.draw_texture_rect(_glow, Rect2(x - sz, y - sz * 0.22, sz * 2.0, sz * 0.44), false, Color(0.8, 0.86, 0.84, 0.1 + 0.08 * rn))

## the rain: streaks falling onto the surfaces it lands on (the mask's points), each ending in a splash, some trickling on;
## down the crevice it falls on past the surface and fades into the dark
func _wb_rain2(c: CanvasItem, rn: float) -> void:
	var pts: Array = J.rain_pts
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var col := Color(0.84, 0.9, 0.92, 0.45 * rn)
	var n := int(140 * rn)
	for j in n:
		var p: Array = pts[rng.randi() % pts.size()]
		var land := Vector2(float(p[0]), float(p[1]))
		if land.y < _seen.x - 50.0 or land.y - 400.0 > _seen.y: continue
		var per := rng.randf_range(0.55, 0.8)
		var u := fposmod(t + rng.randf() * 7.0, per) / per
		var fall := 420.0
		if u < 0.8:
			var q := u / 0.8
			var head := land + Vector2(-0.18, -1.0) * fall * (1.0 - q)
			c.draw_line(head - Vector2(-0.18, -1.0) * 34.0 * -1.0, head, col, 1.6)
		else:
			var q := (u - 0.8) / 0.2
			c.draw_arc(land, 3.0 + 9.0 * q, PI * 1.05, PI * 1.95, 7, Color(col, col.a * (1.0 - q)), 1.4)
			c.draw_circle(land + Vector2(-5.0 * q, -6.0 * q * (1.0 - q) * 4.0), 1.4, Color(col, col.a * (1.0 - q)))
			c.draw_circle(land + Vector2(6.0 * q, -5.0 * q * (1.0 - q) * 4.0), 1.2, Color(col, col.a * (1.0 - q)))
			if j % 5 == 0:
				# it runs on down the rock a little
				c.draw_line(land, land + Vector2(0, 26.0 * q), Color(col, col.a * 0.8), 1.4)
	# down the crevice, through the section and on into the dark
	var cv: Array = J.crev
	var top := _cut_top() - 200.0
	var bot := _cut_top() + float(J.cut) + float(J.band) * 1.2
	for j in int(40 * rn):
		var x := rng.randf_range(float(cv[0]) + 20.0, float(cv[1]) - 20.0)
		var y := top + fposmod(rng.randf_range(0.0, 2000.0) + t * 1300.0, bot - top)
		if y < _seen.x or y > _seen.y: continue
		var f := 1.0 - clampf((y - _cut_top()) / (bot - _cut_top()), 0.0, 1.0)
		c.draw_line(Vector2(x, y), Vector2(x - 6.0, y + 30.0), Color(col, col.a * f), 1.4)

## mist in the crevice: soft clouds drifting up out of its dark, thicker in the rain
func _wb_crevice_mist(c: CanvasItem) -> void:
	var rn := _rain(t - _rain_at) * _rain_k
	var cv: Array = J.crev
	var ps := _size("puff.png")
	var top := _cut_top() - 150.0
	for b in _bands:
		if not _band_seen(b): continue
		for j in 4:
			var u := fposmod(t * 0.025 + j * 0.25 + int(b.k) * 0.13, 1.0)
			var x := lerpf(float(cv[0]) + 40.0, float(cv[1]) - 40.0, fposmod(j * 0.37 + int(b.k) * 0.29, 1.0)) + 30.0 * sin(t * 0.2 + j)
			var y := float(b.y) + float(J.band) * (1.0 - u)
			var sc := 2.4 + 1.2 * sin(j * 1.7 + int(b.k))
			c.draw_texture_rect(tex("puff.png"), Rect2(Vector2(x, y) - ps * sc / 2, ps * sc), false, Color(0.75, 0.82, 0.8, (0.1 + 0.08 * rn) * sin(PI * u)))
	for j in 5:
		var u := fposmod(t * 0.03 + j * 0.2, 1.0)
		var x := lerpf(float(cv[0]) - 40.0, float(cv[1]) + 40.0, fposmod(j * 0.41, 1.0))
		var y := top + float(J.cut) * (1.0 - u)
		if y < _seen.x - 300.0 or y > _seen.y + 300.0: continue
		var sc := 3.0 + 1.4 * sin(j * 2.3)
		c.draw_texture_rect(tex("puff.png"), Rect2(Vector2(x, y) - ps * sc / 2, ps * sc), false, Color(0.78, 0.85, 0.82, (0.12 + 0.1 * rn) * sin(PI * u)))

## a shower: grey streaks slanting down the screen where it is looked at, splashes on the terraces
func _wb_rain_draw(c: CanvasItem) -> void:
	var rn := _rain(t - _rain_at) * _rain_k
	if rn < 0.03:
		return
	if J.has("rain_pts"):
		_wb_rain2(c, rn)
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_rain_at * 10.0)
	var y0 := _seen.x
	var y1 := minf(_seen.y, _cut_top() + float(J.cut))
	if y1 <= y0:
		return
	c.draw_rect(Rect2(-200, y0, 1936, y1 - y0), Color(0.04, 0.06, 0.06, 0.16 * rn))
	for j in int(170 * rn):
		var x := rng.randf_range(-100, 1636)
		var sp := rng.randf_range(1400.0, 1900.0)
		var y := y0 + fposmod(rng.randf_range(0, 2000) + t * sp, y1 - y0 + 200.0) - 100.0
		var l := rng.randf_range(40.0, 80.0)
		c.draw_line(Vector2(x, y), Vector2(x - l * 0.18, y + l), Color(0.84, 0.9, 0.92, 0.42 * rn), rng.randf_range(1.4, 2.6))

# ---------------------------------------------------------------- the live layer

func _draw_live() -> void:
	var c := live
	_lights(c)
	_wb_mist_draw(c)
	_surface_live(c)
	_wb_crevice(c)
	_wb_crevice_mist(c)
	_wb_basket(c)
	_wb_winch(c)
	for b in _bands:
		if _band_seen(b):
			_band_live(c, b)
			_wb_small_life(c, b)
	_wb_moths_surface(c)
	_wb_egret(c)
	_events_live(c)
	_wb_ladder(c)          # over the spider's leg: it comes up behind the ladder
	_wb_rain_draw(c)
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

## a level's life: its crew, the lamp boy's flame, the torch, the old man's pipe
func _band_live(c: CanvasItem, b: Dictionary) -> void:
	var k := int(b.k)
	var y := float(b.y)
	var st := String(_shown_bands.get(k, b.state))
	if st == "closed":
		return
	var d := int(b.d)
	var floor_y := y + floor_of(d)
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
	var fear := _wb_fear(k)
	if fear > 0.0 and rx == "":
		p = "%s/%02d.png" % [who, _drawing_at(cr, _wb_crew_v(k, float(_events.leg)))]
		sz = _size(p)
	var shy := Vector2((-1.0 if x < (float(J.crev[0]) + float(J.crev[1])) * 0.5 else 1.0) * 26.0 * fear + 2.0 * fear * sin(t * 40.0), 0)
	_put(c, p, Vector2(x - sz.x / 2, floor_y - sz.y + 4 + float(cr.get("dy", 0.0))) + shy, flip, al)
	var sgn := -1.0 if flip else 1.0
	if cr.has("lamp"):
		var lp: Array = cr.lamp
		_light(c, Vector2(x + float(lp[0]) * sgn, floor_y + float(lp[1])), 70, Color(1.0, 0.72, 0.35, 0.5 * al * _flick(k)))
	if cr.has("ember") and rx == "":
		var ep: Array = cr.ember
		var draw_ := fposmod(_wb_crew_v(k, t), _loop(cr)) / maxf(1.0, _loop(cr))
		_light(c, Vector2(x + float(ep[0]) * sgn, floor_y + float(ep[1])), 26, Color(1.0, 0.5, 0.15, (0.6 if draw_ < 0.25 else 0.2) * al))

# ---------------------------------------------------------------- small life (between the events, something always moves)

## a moth: two pale wings beating round a body, flying a loose loop round a light
func _wb_moth(c: CanvasItem, at: Vector2, seed_: int, warm: Color) -> void:
	var ph := seed_ * 1.37
	var sp := 0.9 + 0.25 * sin(seed_)
	var p := at + Vector2(sin(t * 1.3 * sp + ph) * 34.0 + sin(t * 3.1 + ph * 2.0) * 8.0, cos(t * 1.7 * sp + ph) * 22.0 + sin(t * 2.3 + ph) * 6.0)
	var beat := absf(sin(t * 26.0 + ph))
	var ink := Color(0.05, 0.04, 0.03, 0.9)
	var wing := Color(warm.lightened(0.5), 0.85)
	for sgn in [-1.0, 1.0]:
		var w := PackedVector2Array([p, p + Vector2(sgn * 8.0, -3.0 - 6.0 * beat), p + Vector2(sgn * 10.0, 3.0 - 2.0 * beat)])
		c.draw_colored_polygon(w, wing)
		c.draw_polyline(PackedVector2Array([w[0], w[1], w[2], w[0]]), ink, 1.0)
	c.draw_circle(p, 2.0, ink)

## per depth: moths round its lamps, a small spider going up and down its own thread in the crevice, drops falling from
## the roof in a gallery, a moth caught in the crevice's web; the depth's own light (silver glints running along the
## quartz vein, ripples of lamplight on the lake, the green mushrooms breathing)
func _wb_small_life(c: CanvasItem, b: Dictionary) -> void:
	var k := int(b.k)
	var y := float(b.y)
	var d := int(b.d)
	if String(_shown_bands.get(k, b.state)) == "closed":
		return
	var ls: Array = J.lamps.get(str(d), [])
	for j in ls.size():
		if (k + j) % 2 == 1 and j > 0: continue
		var l: Array = ls[j]
		_wb_moth(c, Vector2(float(l[0]), y + float(l[1]) - 10.0), k * 11 + j, Color(1.0, 0.85, 0.6))
	var cv: Array = J.crev
	# the little spider on its thread: it lets itself down, hangs, climbs back
	var sx := float(cv[0]) + 40.0 + fposmod(k * 53.0, float(cv[1]) - float(cv[0]) - 80.0)
	var cyc := fposmod(t + k * 4.1, 14.0) / 14.0
	var dn := smoothstep(0.0, 0.35, cyc) * (1.0 - smoothstep(0.6, 1.0, cyc))
	var sy := y + 20.0 + dn * 300.0 + 4.0 * sin(t * 2.0 + k)
	c.draw_line(Vector2(sx, y), Vector2(sx, sy), Color(0.85, 0.9, 0.9, 0.5), 1.2)
	var ink := Color(0.03, 0.03, 0.03)
	c.draw_circle(Vector2(sx, sy + 4.0), 5.0, ink)
	c.draw_circle(Vector2(sx, sy - 2.0), 3.0, ink)
	for l in 4:
		var a := 0.3 + l * 0.42 + 0.15 * sin(t * 6.0 + l + k)
		c.draw_line(Vector2(sx, sy + 3.0), Vector2(sx + cos(a) * 11.0, sy + 3.0 + sin(a) * 9.0 - 4.0), ink, 1.4)
		c.draw_line(Vector2(sx, sy + 3.0), Vector2(sx - cos(a) * 11.0, sy + 3.0 + sin(a) * 9.0 - 4.0), ink, 1.4)
	# a moth caught in the web over this depth's seam: still, then a burst of flapping
	if k > 0 and k % 3 != 2:
		var mp := Vector2((float(cv[0]) + float(cv[1])) * 0.5 + 30.0 * sin(k * 2.2), y - 20.0)
		var fl := maxf(0.0, sin(t * 0.6 + k)) ** 6
		var beat := absf(sin(t * 30.0)) * fl
		for sgn in [-1.0, 1.0]:
			c.draw_colored_polygon(PackedVector2Array([mp, mp + Vector2(sgn * 10.0, -4.0 - 5.0 * beat), mp + Vector2(sgn * 11.0, 5.0)]), Color(0.85, 0.8, 0.68, 0.85))
		c.draw_circle(mp, 2.4, ink)
	# drops from the roof of the gallery, each falling to the floor and splashing
	var fy := y + floor_of(d)
	for j in mini(3, ls.size()):
		var lp: Array = ls[j]
		var dx := float(lp[0]) + (40.0 if j % 2 == 0 else -50.0)
		var per := 2.6 + j * 0.9
		var u := fposmod(t + j * 1.3 + k, per) / per
		var top := y + float(lp[1]) - 70.0
		if u < 0.5:
			var q := u / 0.5
			c.draw_circle(Vector2(dx, top + 4.0 * q), 2.0 + q, Color(0.8, 0.9, 0.95, 0.6 * q))
		elif u < 0.68:
			var q := (u - 0.5) / 0.18
			c.draw_line(Vector2(dx, lerpf(top, fy - 6.0, q * q)), Vector2(dx, lerpf(top, fy - 6.0, q * q) + 10.0), Color(0.85, 0.93, 1.0, 0.75), 2.5)
		elif u < 0.8:
			var q := (u - 0.68) / 0.12
			c.draw_arc(Vector2(dx, fy - 4.0), 4.0 + 12.0 * q, PI * 1.1, PI * 1.9, 8, Color(0.85, 0.93, 1.0, 0.6 * (1.0 - q)), 1.5)
	# the depth's own light
	var lx: Dictionary = J.get("light", {})
	if lx.has(str(d)):
		var L: Dictionary = lx[str(d)]
		match String(L.kind):
			"glints":
				var pts: Array = L.pts
				for i in pts.size():
					var g := maxf(0.0, sin(t * 1.1 - i * 0.7)) ** 8
					if g < 0.05: continue
					var gp := Vector2(float(pts[i][0]), y + float(pts[i][1]))
					_light(c, gp, 26, Color(0.85, 0.92, 1.0, 0.6 * g))
					c.draw_line(gp + Vector2(-8, 0) * g, gp + Vector2(8, 0) * g, Color(1, 1, 1, g), 1.5)
					c.draw_line(gp + Vector2(0, -8) * g, gp + Vector2(0, 8) * g, Color(1, 1, 1, g), 1.5)
			"water":
				var r: Array = L.rect
				for i in 18:
					var wx := lerpf(float(r[0]), float(r[2]), fmod(i * 0.618, 1.0))
					var wy := y + lerpf(float(r[1]), float(r[3]), fmod(i * 0.37, 1.0))
					var a := 0.5 + 0.5 * sin(t * 1.4 + i * 1.9)
					var ln := 18.0 + 14.0 * sin(i * 2.3)
					c.draw_line(Vector2(wx - ln + 6.0 * sin(t + i), wy), Vector2(wx + ln + 6.0 * sin(t + i), wy), Color(0.7, 0.95, 1.0, 0.22 * a), 2.0)
			"fungi":
				var pts: Array = L.pts
				for i in pts.size():
					var g := 0.5 + 0.5 * sin(t * 0.8 + i * 1.3)
					_light(c, Vector2(float(pts[i][0]), y + float(pts[i][1])), 60, Color(0.4, 1.0, 0.75, 0.22 * g))
			"warm":
				var pts: Array = L.pts
				for i in pts.size():
					_light(c, Vector2(float(pts[i][0]), y + float(pts[i][1])), 120, Color(L.get("col", "#ffb060"), 0.2 * _flick(k * 5 + i)))
	if lx.has(str(d)) and String(lx[str(d)].kind) == "warm" and d == 2:
		_wb_hall(c, y)
	if d == 6:
		_wb_lake(c, b)
	# the second dweller of the depth
	var c2: Dictionary = J.get("crews2", {})
	if c2.has(str(d)) and b.lived:
		var w: Dictionary = c2[str(d)]
		var nm := String(w.name)
		if _crew_ok(nm):
			var n := int(J.crew_n[nm])
			var fear := _wb_fear(k)
			var u := ((float(_events.leg) if fear > 0.0 else t) + k * 1.7) * float(w.get("fps", 9))
			var fr := "%s/%02d.png" % [nm, _drawing_at(w, u) if w.has("play") else int(u) % n]
			var sz := _size(fr)
			var shy := Vector2((-1.0 if float(w.x) < (float(J.crev[0]) + float(J.crev[1])) * 0.5 else 1.0) * 26.0 * fear + 2.0 * fear * sin(t * 43.0), 0)
			_put(c, fr, Vector2(float(w.x) - sz.x / 2, y + float(w.get("floor", floor_of(d))) - sz.y + 4.0) + shy, bool(w.get("flip", false)))

## 100 m: the shaft of daylight through the roof breathes, rays shift, dust and drops drift in it; the water runs along the
## bamboo channel, pours from its spout and rings out over the wet floor
func _wb_hall(c: CanvasItem, y: float) -> void:
	var H2: Dictionary = J.get("hall", {})
	if H2.is_empty(): return
	var sh: Array = H2.shaft          # top x0, x1, y; bottom x0, x1, y (band px)
	var br := 0.75 + 0.15 * sin(t * 0.7) + 0.1 * sin(t * 1.9)
	for i in 5:
		var q := (i + 0.5) / 5.0 + 0.04 * sin(t * 0.5 + i * 1.7)
		var x0 := lerpf(float(sh[0]), float(sh[1]), q)
		var x1 := lerpf(float(sh[3]), float(sh[4]), q)
		var a := 0.05 * br * (0.6 + 0.4 * sin(t * 1.3 + i * 2.1))
		var wdt := 22.0 + 10.0 * sin(i * 3.3)
		c.draw_polygon(PackedVector2Array([Vector2(x0 - wdt * 0.5, y + float(sh[2])), Vector2(x0 + wdt * 0.5, y + float(sh[2])),
			Vector2(x1 + wdt, y + float(sh[5])), Vector2(x1 - wdt, y + float(sh[5]))]),
			PackedColorArray([Color(0.9, 0.97, 0.95, a), Color(0.9, 0.97, 0.95, a), Color(0.9, 0.97, 0.95, 0.0), Color(0.9, 0.97, 0.95, 0.0)]))
	for i in 26:
		var u := fposmod(t * (0.04 + 0.02 * sin(i)) + i * 0.13, 1.0)
		var q := fposmod(i * 0.618, 1.0)
		var yy := lerpf(float(sh[2]), float(sh[5]), u)
		var xx := lerpf(lerpf(float(sh[0]), float(sh[1]), q), lerpf(float(sh[3]), float(sh[4]), q), u) + 10.0 * sin(t * 0.8 + i)
		c.draw_circle(Vector2(xx, y + yy), 2.0, Color(1.0, 1.0, 0.95, 0.55 * sin(PI * u)))
	_light(c, Vector2((float(sh[3]) + float(sh[4])) * 0.5, y + float(sh[5])), 160, Color(0.85, 0.95, 0.92, 0.12 * br))
	var ch: Array = H2.channel        # points along the channel, the last is the spout
	for i in 10:
		var u := fposmod(t * 0.6 + i * 0.1, 1.0)
		var f := u * (ch.size() - 1)
		var i0 := mini(int(f), ch.size() - 2)
		var a2: Array = ch[i0]
		var b2: Array = ch[i0 + 1]
		var p := Vector2(float(a2[0]), y + float(a2[1])).lerp(Vector2(float(b2[0]), y + float(b2[1])), f - i0)
		c.draw_line(p, p + Vector2(-10, 1), Color(0.85, 0.97, 1.0, 0.7), 2.0)
	var sp: Array = ch[ch.size() - 1]
	var pool: Array = H2.pool
	for i in 6:
		var u := fposmod(t * 1.6 + i / 6.0, 1.0)
		var p := Vector2(float(sp[0]) - 6.0 * u, y + lerpf(float(sp[1]), float(pool[1]), u * u))
		c.draw_line(p, p + Vector2(-1, 12), Color(0.85, 0.97, 1.0, 0.75), 2.5)
	for i in 4:
		var u := fposmod(t * 0.5 + i * 0.25, 1.0)
		var cx := float(pool[0]) + (i - 1.5) * 26.0 * float(i % 2)
		c.draw_set_transform(Vector2(cx, y + float(pool[1])), 0, Vector2(1.0, 0.3))
		c.draw_arc(Vector2.ZERO, 6.0 + 40.0 * u, 0, TAU, 20, Color(0.85, 0.97, 1.0, 0.45 * (1.0 - u)), 2.0)
		c.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

## 300 m: rings on the lake round the boat's pole and the fisher's net when they touch the water
func _wb_lake(c: CanvasItem, b: Dictionary) -> void:
	var lk: Dictionary = J.get("lake", {})
	if lk.is_empty() or not b.lived: return
	var y := float(b.y)
	for key in ["net", "pole"]:
		if not lk.has(key): continue
		var at: Array = lk[key]
		for i in 3:
			var u := fposmod(t * 0.45 + i / 3.0 + (0.5 if key == "pole" else 0.0), 1.0)
			c.draw_set_transform(Vector2(float(at[0]), y + float(at[1])), 0, Vector2(1.0, 0.28))
			c.draw_arc(Vector2.ZERO, 5.0 + 34.0 * u, 0, TAU, 20, Color(0.75, 0.97, 1.0, 0.5 * (1.0 - u)), 2.0)
			c.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

## moths round the lamps of the surface (at night more), now and then
func _wb_moths_surface(c: CanvasItem) -> void:
	var sl: Dictionary = J.surface_lamps
	var i := 0
	for place in sl:
		if place != "" and int(_shown_places.get(place, 0)) < 3:
			continue
		for l in sl[place]:
			i += 1
			if i % 3 != 0: continue
			var at := Vector2(float(l[0]), float(l[1]))
			if at.y < _seen.x - 100.0 or at.y > _seen.y + 100.0: continue
			_wb_moth(c, at, 100 + i, Color(1.0, 0.85, 0.6))

## an egret flies over the valley every half minute or so, low over the mist
func _wb_egret(c: CanvasItem) -> void:
	if not _crew_ok("egret"):
		return
	var per := 34.0
	var u := fposmod(t + 9.0, per) / 12.0
	if u > 1.0:
		return
	var sky := float(J.sky)
	var p := Vector2(lerpf(-160.0, 1700.0, u), sky + 520.0 - 220.0 * u + 30.0 * sin(u * 6.0))
	if p.y < _seen.x - 100.0 or p.y > _seen.y + 100.0:
		return
	var n := int(J.crew_n.egret)
	var fr := "egret/%02d.png" % (int(t * 10.0) % n)
	var sz := _size(fr)
	_put(c, fr, p - sz / 2)

# ---------------------------------------------------------------- the spider, about the place

func _tick_events() -> void:
	if force_event != "" and t > 0.5:
		_start_event(force_event)
		force_event = ""
	if t < _next_event:
		return
	_next_event = t + _rng.randf_range(10.0, 16.0)
	var pool := ["web", "eyes", "skitter", "tug"]
	if int(_shown_places.get("bridge", 0)) >= 3: pool.append_array(["monk", "monk"])
	for b in _bands:
		if bool(b.lived) and J.lamps.get(str(int(b.d)), []).size() > 0:
			pool.append("thread")
			break
	_start_event(pool[_rng.randi() % pool.size()])

func _start_event(ev: String) -> void:
	_events[ev] = t
	match ev:
		"leg":
			# out of the crevice beside the open walkway on the screen (the nearest to the middle)
			var pick := -1
			var best := 1e9
			var mid := lerpf(_seen.x, _seen.y, 0.55)
			for b in _bands:
				var k := int(b.k)
				if k > open or String(_shown_bands.get(k, "closed")) == "closed": continue
				var yy := band_y(k) + floor_of(k + 1)
				if yy > _seen.x + 80 and yy < _seen.y - 80 and absf(yy - mid) < best:
					best = absf(yy - mid)
					pick = k
			if pick < 0:
				_events.erase(ev)
				return
			_events["leg_k"] = pick
			WebSounds.skitter(self, _far(band_y(pick) + 300.0) + 4.0)
			get_tree().create_timer(2.2).timeout.connect(func(): WebSounds.tap(self, _far(band_y(pick) + 300.0)))
			get_tree().create_timer(2.9).timeout.connect(func(): WebSounds.tap(self, _far(band_y(pick) + 300.0)))
		"tug":
			WebSounds.skitter(self, _far(_bk_y) - 4.0)
		"web":
			WebSounds.skitter(self, _far(float(J.sky) + 300.0) - 6.0)
		"eyes":
			WebSounds.drone(self, _far(band_y(open) + float(J.band)))
		"skitter":
			# a stream of spiderlings over the wall of an open gallery (the one on the screen, if any)
			var cand: Array = []
			for b in _bands:
				if String(_shown_bands.get(int(b.k), "closed")) != "closed": cand.append(int(b.k))
			if cand.is_empty():
				_events.erase(ev)
				return
			var pick: int = cand[_rng.randi() % cand.size()]
			var mid := lerpf(_seen.x, _seen.y, 0.5)
			var best := 1e9
			for k in cand:
				var yy := band_y(k) + 300.0
				if yy > _seen.x and yy < _seen.y and absf(yy - mid) < best:
					best = absf(yy - mid)
					pick = k
			_events["skitter_k"] = pick
			WebSounds.skitter(self, _far(band_y(pick) + 300.0))
		"monk":
			get_tree().create_timer(0.8).timeout.connect(func(): WebSounds.jingle(self, _far(float((J.bridge.l as Array)[1]))))
		"thread":
			var cand: Array = []
			for b in _bands:
				if String(_shown_bands.get(int(b.k), "closed")) != "closed" and J.lamps.get(str(int(b.d)), []).size() > 0:
					cand.append(int(b.k))
			if cand.is_empty():
				_events.erase(ev)
				return
			var pick: int = cand[0]
			var mid := lerpf(_seen.x, _seen.y, 0.5)
			var best := 1e9
			for k in cand:
				var yy := band_y(k) + 300.0
				if absf(yy - mid) < best:
					best = absf(yy - mid)
					pick = k
			_events["thread_k"] = pick

func _events_live(c: CanvasItem) -> void:
	for ev in _events.keys():
		if String(ev).ends_with("_k"):
			continue
		var s := t - float(_events[ev])
		var done := false
		match ev:
			"web":
				done = s > 3.2
			"tug":
				done = s > 5.0
			"leg":
				if s > LEG_LEN + 0.8 or not _events.has("leg_k"): done = true
				else: _wb_leg(c, int(_events.leg_k), s)
			"eyes":
				# eight red eyes open far down the crevice, under the deepest open level, and go out one by one
				if s > 6.0: done = true
				else:
					var cv: Array = J.crev
					var cx := (float(cv[0]) + float(cv[1])) * 0.5
					var y := band_y(open) + float(J.band) * 1.05
					if open >= _bands.size() - 1: y = band_y(open) + float(J.band) * 0.55
					for i in 8:
						var row := 0 if i < 4 else 1
						var col_i := i % 4
						var p := Vector2(cx + (col_i - 1.5) * (16.0 + row * 6.0), y + row * 18.0 - absf(col_i - 1.5) * 4.0)
						var on := clampf((s - 0.3 - i * 0.08) / 0.5, 0.0, 1.0) * clampf((5.2 - s - (7 - i) * 0.1) / 0.6, 0.0, 1.0)
						if on <= 0.0: continue
						_light(c, p, 30, Color(WEB_EYE, 0.45 * on))
						c.draw_circle(p, 3.6 + row * 1.2, Color(1.0, 0.35, 0.25, on))
						c.draw_circle(p + Vector2(-1, -1), 1.2, Color(1, 0.9, 0.8, on))
			"skitter":
				# spiderlings: a dozen black dots with legs running along the gallery's back wall into a crack
				if s > 3.0 or not _events.has("skitter_k"): done = true
				else:
					var k := int(_events.skitter_k)
					var gx: Array = J.galleries.get(str(k + 1), [100, 600])
					var y := band_y(k) + floor_of(k + 1) - 210.0
					var left := float(gx[0]) < 600.0
					for i in 12:
						var u := clampf((s - i * 0.09) / 1.8, 0.0, 1.0)
						if u <= 0.0 or u >= 1.0: continue
						var x := lerpf(float(gx[1]) - 60.0, float(gx[0]) + 80.0, u) if left else lerpf(float(gx[0]) + 60.0, float(gx[1]) - 80.0, u)
						var p := Vector2(x + sin(i * 2.7) * 20.0, y + sin(i * 1.3) * 40.0 + 6.0 * sin(u * 40.0 + i))
						var ink := Color(0.04, 0.035, 0.03, 0.95)
						c.draw_circle(p, 3.2, ink)
						for l in 4:
							var a := 0.5 + l * 0.7 + 0.4 * sin(t * 30.0 + i + l)
							c.draw_line(p, p + Vector2(cos(a) * 6.0, sin(a) * 4.0), ink, 1.2)
							c.draw_line(p, p + Vector2(-cos(a) * 6.0, sin(a) * 4.0), ink, 1.2)
			"monk":
				# a wandering monk stands on the rope bridge in the mist; on the mist under the bridge his shadow has eight legs
				if s > 8.0 or not J.has("bridge"): done = true
				else:
					var br: Dictionary = J.bridge
					var l: Array = br.l
					var r: Array = br.r
					var at := Vector2(lerpf(float(l[0]), float(r[0]), 0.45), lerpf(float(l[1]), float(r[1]), 0.45) + float(br.sag))
					var al := clampf(s / 1.4, 0.0, 1.0) * clampf((8.0 - s) / 1.4, 0.0, 1.0)
					var n := maxi(1, int(J.crew_n.get("monk", 1)))
					var fr := "monk/%02d.png" % mini(int(s * 1.1), n - 1)
					if _crew_ok("monk"):
						var sz := _size(fr)
						_put(c, fr, Vector2(at.x - sz.x / 2, at.y - sz.y + 6.0), false, al)
						# the shadow on the mist below: a man's shape... and legs
						var sh := at + Vector2(-30.0, 170.0)
						var sa := 0.32 * al * clampf((s - 1.5) / 1.5, 0.0, 1.0)
						c.draw_texture_rect(_glow, Rect2(sh - Vector2(70, 46), Vector2(140, 92)), false, Color(0.0, 0.0, 0.0, sa * 1.4))
						for i in 8:
							var side := -1.0 if i < 4 else 1.0
							var j := i % 4
							var a := side * (0.4 + j * 0.32) + 0.06 * sin(t * 3.0 + i)
							var knee := sh + Vector2(side * (50.0 + j * 10.0), -30.0 + j * 14.0)
							var foot := knee + Vector2(side * 40.0 * cos(a * 0.4), 70.0 + j * 6.0)
							c.draw_line(sh, knee, Color(0, 0, 0, sa * 1.6), 7.0)
							c.draw_line(knee, foot, Color(0, 0, 0, sa * 1.6), 5.0)
			"thread":
				# the line comes down out of the dark of the crevice to a gallery's lamp, takes it, and draws it up
				if s > 7.0 or not _events.has("thread_k"): done = true
				else:
					var k := int(_events.thread_k)
					var ls: Array = J.lamps.get(str(k + 1), [])
					if ls.is_empty(): done = true
					else:
						var lp: Array = ls[0]
						var lamp := Vector2(float(lp[0]), band_y(k) + float(lp[1]))
						var top := Vector2(lamp.x + 20.0, band_y(k) - 40.0)
						var down := clampf(s / 2.0, 0.0, 1.0)
						var up := clampf((s - 3.0) / 3.0, 0.0, 1.0)
						var tip := top.lerp(lamp, down)
						tip.y -= up * up * 420.0
						tip.x += sin(s * 2.0) * 6.0 * up
						c.draw_line(top + Vector2(0, -400), tip, Color(0.9, 0.95, 1.0, 0.65), 1.6)
						if s > 2.0:
							# the lamp (a little paper lantern of its own, drawn here) hangs on the line, swinging, and goes up
							var sw := sin(s * 3.0) * 0.25 * up
							c.draw_set_transform(tip, sw, Vector2.ONE)
							c.draw_rect(Rect2(-9, 4, 18, 24), Color(0.05, 0.04, 0.03))
							c.draw_rect(Rect2(-7, 6, 14, 20), Color(1.0, 0.75, 0.4))
							c.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
							_light(c, tip + Vector2(0, 16), 70, Color(1.0, 0.7, 0.35, 0.45 * (1.0 - up * 0.7)))
						if _passed("thread_up", s, 100.0, 3.0):
							WebSounds.skitter(self, _far(lamp.y) - 8.0)
		if done:
			_events.erase(ev)
			_events.erase(ev + "_k")

## how much the people of depth k are frightened now (the leg out at their walkway): 0..1
func _wb_fear(k: int) -> float:
	if not _events.has("leg") or int(_events.get("leg_k", -1)) != k:
		return 0.0
	var s := t - float(_events.leg)
	return clampf((s - 0.6) / 0.4, 0.0, 1.0) * clampf((LEG_LEN + 0.8 - s) / 0.8, 0.0, 1.0)

## a spider's leg, huge, out of the crevice's dark below a walkway: it comes up slowly, reaches over the planks towards the
## gallery, the claw taps twice on the floor, it feels about, and pulls back fast into the dark. One straight drawing
## (cyc_leg_strip) bent at two knees; its base stays in the dark, only as much as is out is drawn
func _wb_leg(c: CanvasItem, k: int, s: float) -> void:
	if not ResourceLoader.exists(dir + "leg_strip.png"):
		return
	var cv: Array = J.crev
	var d := k + 1
	var gx: Array = J.galleries.get(str(d), [100, 600])
	var dir := -1.0 if float(gx[0]) < 600.0 else 1.0           # towards the gallery's side
	var fl := band_y(k) + floor_of(d)
	var base := Vector2((float(cv[0]) + float(cv[1])) * 0.5 - dir * 30.0, fl + 110.0)
	var tx := tex("leg_strip.png")
	var full := 640.0
	var hw := full * float(tx.get_height()) / float(tx.get_width()) * 0.5 * 1.25
	var out := 0.0
	if s < 2.0: out = 1.0 - pow(1.0 - s / 2.0, 2.5)
	elif s < LEG_LEN - 0.5: out = 1.0
	else: out = pow(1.0 - (s - LEG_LEN + 0.5) / 0.5, 2.0)
	var vis := full * out
	if vis < 4.0 or s > LEG_LEN:
		return
	# the knees: up and out, over, down onto the floor; the claw taps at 2.2 s and 2.9 s, feels about after
	var tap := exp(-pow((s - 2.2) * 7.0, 2.0)) + exp(-pow((s - 2.9) * 7.0, 2.0))
	var feel := 0.25 * sin(s * 2.1) * clampf(s - 3.2, 0.0, 1.0)
	var a1 := -1.45 + 0.05 * sin(s * 1.3)
	var a2 := -0.55 + feel * 0.5
	var a3 := 0.9 - 0.5 * tap + feel
	var pts := Bend.chain(base, vis, 36, func(q: float) -> float:
		var a := a3
		if q < 0.36: a = a1
		elif q < 0.40: a = lerpf(a1, a2, (q - 0.36) / 0.04)
		elif q < 0.70: a = a2
		elif q < 0.74: a = lerpf(a2, a3, (q - 0.70) / 0.04)
		return a if dir > 0.0 else PI - a)
	Bend.draw(c, pts, func(q: float) -> float: return hw * (1.0 - 0.45 * q), tx, 1.0 - vis / full, 1.0, dir < 0.0,
		func(q: float) -> Color: var v := lerpf(0.12, 0.66, smoothstep(0.0, 0.4, q + (1.0 - vis / full))); return Color(v, v * 1.03, v))
	# the walkway in front of it again (its base stays below the planks, in the crevice's dark)
	var wp := "walk/d%d.png" % d
	if ResourceLoader.exists(WDIR + wp):
		_put(c, wp, Vector2(float(cv[0]) - 40.0, fl - 40.0))

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
		WebSounds.groan(self, -4.0)

## the lair open: eight red eyes over its mouth burn steady and breathe, cold mist rolls out of the mouth over the floor,
## the shimenawa rope sways, the webs across the crevice hum taut, the valley shudders now and then
func _finale(c: CanvasItem) -> void:
	if String(_shown_bands.get(8, "")) != "done" or not J.has("lair"):
		return
	var y := band_y(8)
	var lr: Dictionary = J.lair
	var sh := clampf(1.0 - (t - _tremor_at) / 2.0, 0.0, 1.0)
	var br := 0.55 + 0.25 * sin(t * 1.1) + 0.4 * sh
	var i := 0
	for e_ in lr.eyes:
		var e: Array = e_
		var p := Vector2(float(e[0]), y + float(e[1]))
		var blink := 0.2 if fmod(t + i * 0.37, 7.0) < 0.15 else 1.0
		_light(c, p, 46, Color(WEB_EYE, 0.38 * br * blink))
		c.draw_circle(p, 6.0, Color(1.0, 0.3, 0.2, 0.85 * br * blink))
		c.draw_circle(p + Vector2(-2, -2), 1.8, Color(1, 0.9, 0.8, 0.9 * blink))
		i += 1
	var mo: Array = lr.mouth
	var mp := Vector2(float(mo[0]), y + float(mo[1]))
	_light(c, mp, 160, Color(0.6, 0.0, 0.0, 0.18 + 0.1 * sh))
	var ps := _size("puff.png")
	for j in 10:
		var u := fmod(t * 0.12 + j / 10.0, 1.0)
		var side := -1.0 if j % 2 else 1.0
		var q := mp + Vector2(side * u * 380.0, 120.0 - u * 20.0 + sin(j * 2.1) * 10.0)
		var sc := 0.6 + 1.6 * u
		c.draw_texture_rect(tex("puff.png"), Rect2(q - ps * sc / 2, ps * sc), false, Color(0.85, 0.9, 0.88, 0.22 * sin(PI * u)))
	if _passed("lair_breath", t, 7.0, 0.0) and _far(mp.y) > -12.0:
		WebSounds.drone(self, _far(mp.y) - 6.0)

## after a win the level's silver flies down into the depth it came from: bright lumps of native silver and wire, grey iron
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
		var glow := Color(0.75, 0.8, 0.9) if iron else Color(0.85, 0.92, 1.0)
		if u <= 1.0:
			var e := u * u * (3.0 - 2.0 * u)
			var p := from.lerp(tgt, e) + Vector2(sin(i * 1.7) * 140 * sin(PI * u), -220 * sin(PI * u))
			c.draw_circle(p, 22.0, Color(glow, 0.22))
			_wb_lump(c, p, 26.0, iron, i, t * (3.0 + (i % 3)))
		else:
			var f := (u - 1.0) / 0.4
			_light(c, tgt, 60 + 70 * f, Color(glow, 0.6 * (1.0 - f)))
			_wb_lump(c, tgt + Vector2(0, -8), 26.0 * (1.0 - smoothstep(0.5, 1.0, f)), iron, i, 0.0)
		if _passed("ore%d" % i, u, 1.0, 1.0):
			amb.shot("coin", -10.0, 1.3 + (i % 4) * 0.05)

## a lump of native silver (bright, a curl of wire) or of grey iron ore
func _wb_lump(c: CanvasItem, at: Vector2, r: float, iron: bool, seed_: int, spin: float) -> void:
	if r < 1.0:
		return
	var pts := PackedVector2Array()
	var rim := PackedVector2Array()
	for j in 7:
		var a := spin + TAU * j / 7.0
		var rr := r * (0.7 + 0.3 * absf(sin(seed_ * 3.1 + j * 1.9)))
		pts.append(at + Vector2.from_angle(a) * rr)
		rim.append(at + Vector2.from_angle(a) * (rr + 5.0))
	c.draw_colored_polygon(rim, Color(0.02, 0.02, 0.03))
	c.draw_colored_polygon(pts, Color(0.36, 0.35, 0.37) if iron else Color(0.62, 0.66, 0.72))
	if iron:
		c.draw_rect(Rect2(at + Vector2(0.0, -0.1) * r, Vector2(r, r) * 0.42), Color(0.18, 0.18, 0.21))
	else:
		c.draw_colored_polygon(PackedVector2Array([at, pts[0], pts[1]]), Color(0.92, 0.95, 1.0))
		c.draw_colored_polygon(PackedVector2Array([at, pts[3], pts[4]]), Color(0.3, 0.32, 0.36))
		# a curl of wire silver standing off it
		var wp := PackedVector2Array()
		for j in 9:
			var a := spin * 0.5 + j * 0.7
			wp.append(at + Vector2(cos(a), sin(a)) * r * (0.3 + j * 0.09) + Vector2(0, -r * 0.4))
		c.draw_polyline(wp, Color(0.02, 0.02, 0.03), 4.0)
		c.draw_polyline(wp, Color(0.9, 0.94, 1.0), 2.0)

# ---------------------------------------------------------------- crews and sounds

func _wb_crew_v(k: int, at: float) -> float:
	var v := at * CREW_FPS + k * 7.0
	if _wb_hold.has(k):
		v -= clampf(at - float(_wb_hold[k]), 0.0, REACT_LEN) * CREW_FPS
	return v

func _crew_frame(cr: Dictionary, k: int) -> int:
	return _drawing_at(cr, _wb_crew_v(k, t))

func _wb_hit_at(cr: Dictionary) -> float:
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
			if _passed("hit%d" % k, _wb_crew_v(k, t), _loop(cr), _wb_hit_at(cr)) and (k == sel or randf() < 0.15):
				WebSounds.strike(self, who, db)
		elif who in ["bellows24", "nun24"]:
			# the bellows breathe twice a loop, the nun's bell rings once
			var n := 2.0 if who == "bellows24" else 1.0
			if _passed("hit%d" % k, _wb_crew_v(k, t) * n, _loop(cr), 2.0) and (k == sel or randf() < 0.2):
				WebSounds.strike(self, who, db)
	WebSounds.of(self).tick(self)
