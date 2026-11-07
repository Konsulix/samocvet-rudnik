class_name BarrowView
extends MineView
## Deathless Barrow (mine 7, Koschei the Deathless's - a second mine of its own, outside the first arc's chain;
## docs/mine7-koschei.md): a Scythian barrow rising out of a dead steppe bog at sunset, dug by an archaeological
## expedition about 1912, a giant black oak in chains on its crown with the chest hanging from a bough. Drawn like
## Old Adit (MineView) but laid out its own way: no shaft and no crevice - every depth is one wide burial hall across the
## band, and the way down is a timber-propped stairwell that comes in from the top on one side of a hall and goes on
## down on the other (a serpentine). The life of the place is the HORSE WHIM and the WIND: the horse walks its circle,
## the sweep arm turns the drum, the basket comes up out of the robbers' hole heaped with earth; every 11-15 s a gust
## runs over the bog - the grass lies down, the chest swings on its chains, a dust devil crosses the far steppe (Koschei
## rides the whirlwind). The tale is dug down layer by layer: the oak's roots, the horses, the idols, the chest (broken
## open), the hare's warrens, the duck's lake, the egg, the hoard, the needle.
## Pictures and coordinates: assets/mine/deathless_barrow/ + mine.json (art/zone/export_mine7.py), source px of the
## 1536-wide stack: the sky, the surface, the section under it, the depth bands.

const KDIR := "res://assets/mine/deathless_barrow/"
## the surface's places in drawing order (their pictures meet at soft edges)
const KPLACES := ["idols", "well", "sieves", "finds", "camp", "gin"]
## the depths whose job is built in the hall itself: its stages are the band's pictures
const KBAND_JOBS := {7: "egg", 8: "hoard", 9: "needle"}
const KSTAGES := ["clear", "step1", "step2", "done"]
const KB_INK := Color(0.04, 0.03, 0.03)
const KB_WISP := Color(0.62, 1.0, 0.72)
const KB_COLD := Color(0.62, 0.82, 1.0)

var _kb_fx: Node2D          # smoke (particles in the picture's own coordinates)
var _kb_smokes: Array = []  # [particles, the place it belongs to, the step from which it smokes]
var _kb_hold := {}          # depth -> when its crew's reaction began
var _gust_at := -100.0      # the last gust of wind, and the next
var _next_gust := 5.0
var _gust_k := 1.0
var _gin_a := 0.0           # the whim's turn (radians), the horse goes round with it
var _gin_v := 0.0           # its speed now (it stops while the basket waits)
var _horse_right := true
var _kb_wisps: Array = []   # will-o'-the-wisps over the bog: [x, y, phase, speed]
var _kb_mist: Array = []    # mist banks over the bog: [y, speed, size, phase]
var _chest_a := 0.0         # the chest's swing on its chains (radians) and its speed
var _chest_v := 0.0
var _devil_x := -1.0        # the dust devil crossing the far steppe in a gust (source px), -1: none
var _devil_dir := 1.0

const GUST_LEN := 6.0
## the basket on the whim's rope: up out of the robbers' hole (while the horse walks), a wait at the top while it is
## emptied, back down (the horse walks the other way round), a wait at the bottom while it is filled
const BK_UP := 6.0
const BK_WAIT := 2.6
const BK_DEPTH := 300.0      # source px the basket goes down the hole

func _init() -> void:
	dir = KDIR

## the barrow: the cave's breath and the bog (KoscheiSounds' own loops)
func amb_beds() -> Array:
	return ["cave"]

func available_here() -> bool:
	return FileAccess.file_exists(KDIR + "mine.json")

func _ready() -> void:
	super()
	_kb_fx = Node2D.new()
	add_child(_kb_fx)
	move_child(_kb_fx, live.get_index())
	var r := RandomNumberGenerator.new()
	r.seed = 707
	for i in 18:
		_kb_wisps.append([r.randf(), r.randf(), r.randf_range(0, TAU), r.randf_range(0.5, 1.3)])
	for i in 6:
		_kb_mist.append([r.randf(), r.randf_range(10.0, 22.0) * (1 if i % 2 else -1), r.randf_range(380, 700), r.randf()])

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
			if KBAND_JOBS.has(d):
				st = KSTAGES[clampi(int(steps.get(KBAND_JOBS[d], 0)), 0, 3)]
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
		var cr: Dictionary = J.crews.get(str(int(_bands[k].d)), {})
		var v := _kb_crew_v(k, t0)
		var ln := _loop(cr) if not cr.is_empty() else 0.0
		if ln > 0.0:
			t0 += (ceilf(v / ln) * ln - v) / CREW_FPS
		_kb_hold[k] = t0
		_react = {k = k, won = bool(last_result.won), t0 = t0, iron = int(last_result.iron), ore = int(last_result.ore)}
		if focus_y < 0: focus_y = band_y(k) + float(J.band) * 0.5
		last_result = {}
	_kb_setup_fx()
	_make_motes()
	_find_niches()
	still.queue_redraw()
	front.queue_redraw()

## what changed since the screen was last shown: new stages come in (ink, then colour), a newly opened hall shows
## through a burst of earth and roots, the people of a depth fade in after its second win
func _changes() -> void:
	var places := {}
	for p in KPLACES: places[p] = int(steps.get(p, 0))
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
	for p in KPLACES:
		var was := int(last.places.get(p, 0))
		var now := int(places[p])
		if now <= was:
			continue
		if focus_y < 0: focus_y = job_pos(p).y
		_shown_places[p] = was
		var at: Array = J.places[p]
		_reveal("place/%s_%d.png" % [p, now], Vector2(float(at[0]), float(at[1])), wait, func(): _shown_places[p] = now,
			"place/%s_%d.png" % [p, was] if was > 0 else "surface.png", p, KPLACES)
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
		_reveal("band/d%d_%s.png" % [d, now], Vector2(0, y - _kb_over()), delay, func(): _shown_bands[k] = now, "band/d%d_%s.png" % [d, was])
		if d == 9 and now == "done":
			_tremor_at = t + delay + 2.2      # the needle's chains drawn taut: the whole barrow shudders
	for k in lived:
		if lived[k] and not bool(last.lived.get(k, false)):
			_appear[k] = t + wait
			if focus_y < 0: focus_y = band_y(int(k)) + float(J.band) * 0.5

func job_pos(id: String) -> Vector2:
	if J.place_box.has(id):
		var bx: Array = J.place_box[id]
		return Vector2((float(bx[0]) + float(bx[2])) / 2, (float(bx[1]) + float(bx[3])) / 2)
	for d in KBAND_JOBS:
		if KBAND_JOBS[d] == id:
			return Vector2(768, band_y(int(d) - 1) + 300)
	return Vector2(768, float(J.sky) + 900)

# ---------------------------------------------------------------- the still pictures

func _draw_still() -> void:
	var c := still
	for p in KPLACES:
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
			_put(c, bp, Vector2(0, float(b.y) - _kb_over()))
	_draw_niches(c)
	# no seams: each band picture reaches over the one above and fades in over it (export_mine7 OV)
	_draw_bedrock(c)

## how far each band picture reaches over its slot (it fades in over the band above)
func _kb_over() -> float:
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

## a depth's pedestal top in band rows ([x, y]), [0, 0] where the depth has none (Home's niche test)
func niche_spot(k: int) -> Array:
	return J.niches.get(str(k + 1), [0, 0])

func _kb_niche_at(k: int) -> Vector2:
	var nc: Array = J.niches[str(k + 1)]
	return Vector2(float(nc[0]), band_y(k) + float(nc[1]))

func niche_at(p: Vector2) -> Dictionary:
	for k in _niche_want:
		var key := Spec.key_of(Spec.of_stone(_niche_want[k]))
		if not _niche_tex.has(key):
			continue
		var at := _kb_niche_at(k)
		var sz := _niche_size(_niche_tex[key])
		if Rect2(at.x - sz.x / 2 - 30, at.y - sz.y - 30, sz.x + 60, sz.y + 50).has_point(p):
			return _niche_want[k]
	return {}

## the stones on their pedestals: a soft shadow, an ink outline, the stone warmed by the niche's little lamp
func _draw_niches(c: CanvasItem) -> void:
	for k in _niche_want:
		var key := Spec.key_of(Spec.of_stone(_niche_want[k]))
		if not _niche_tex.has(key) or String(_shown_bands.get(k, "")) == "closed":
			continue
		var tx: Texture2D = _niche_tex[key]
		var at := _kb_niche_at(k)
		var sz := _niche_size(tx)
		var pos := Vector2(at.x - sz.x / 2, at.y - sz.y + 8)
		c.draw_texture_rect(_glow, Rect2(Vector2(at.x - sz.x * 0.6, at.y - 10), Vector2(sz.x * 1.2, 22)), false, Color(0.04, 0.03, 0.03, 0.6))
		for dv in [Vector2(-3, 0), Vector2(3, 0), Vector2(0, -3), Vector2(0, 3), Vector2(-2, -2), Vector2(2, 2), Vector2(-2, 2), Vector2(2, -2)]:
			c.draw_texture_rect(tx, Rect2(pos + dv, sz), false, Color(0.05, 0.04, 0.04, 1.0))
		c.draw_texture_rect(tx, Rect2(pos, sz), false, Color(1.0, 0.95, 0.88))

# ---------------------------------------------------------------- smoke (particles in the picture's coordinates)

func _kb_setup_fx() -> void:
	for ch in _kb_fx.get_children(): ch.queue_free()
	_kb_smokes = []
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
		p.direction = Vector2(0.3, -1)
		p.spread = 10
		p.gravity = Vector2(8, -2)        # the evening air off the bog: it rises, then drifts away to the right
		p.initial_velocity_min = 16 * k
		p.initial_velocity_max = 26 * k
		p.scale_amount_min = 0.5 * k
		p.scale_amount_max = 0.8 * k
		sc.add_point(Vector2(0, 0.5))
		sc.add_point(Vector2(1, 3.4))
		g.set_color(0, Color(0.7, 0.62, 0.62, 0.0))
		g.add_point(0.08, Color(0.62, 0.55, 0.56, 0.5))
		g.add_point(0.5, Color(0.42, 0.36, 0.4, 0.35))
		g.set_color(g.get_point_count() - 1, Color(0.36, 0.3, 0.36, 0.0))
		p.angular_velocity_min = -10
		p.angular_velocity_max = 10
		p.scale_amount_curve = sc
		p.color_ramp = g
		_kb_fx.add_child(p)
		_kb_smokes.append([p, String(spec.get("place", "")), int(spec.get("from", 0))])
	_kb_update_fx()

func _kb_update_fx() -> void:
	for s in _kb_smokes:
		var pl := String(s[1])
		(s[0] as CPUParticles2D).emitting = pl == "" or int(_shown_places.get(pl, 0)) >= int(s[2])

# ---------------------------------------------------------------- the wind, the whim, the clock

## how hard the wind blows `s` seconds after a gust began: it comes in over a second, holds, and dies away
func _gust(s: float) -> float:
	if s < 0.0 or s > GUST_LEN:
		return 0.0
	return clampf(s / 1.0, 0.0, 1.0) * clampf((GUST_LEN - s) / 2.5, 0.0, 1.0)

func _wind() -> float:
	return _gust(t - _gust_at) * _gust_k

## the night by the phone's clock: 0 at the painted sunset (all day), 1 at night (the sky darker, stars, more wisps)
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
		_kb_update_fx()
	if t > _next_gust:
		_next_gust = t + _rng.randf_range(11.0, 15.0) + GUST_LEN * 0.5
		_gust_at = t
		_gust_k = _rng.randf_range(0.7, 1.15)
		_devil_dir = -1.0 if _rng.randf() < 0.5 else 1.0
		_devil_x = 80.0 if _devil_dir > 0.0 else 900.0
		KoscheiSounds.gust(self, _far(float(J.sky) + 300.0))
	var wn := _wind()
	if _devil_x >= 0.0:
		_devil_x += _devil_dir * delta * 60.0
		if t - _gust_at > GUST_LEN + 1.0: _devil_x = -1.0
	# the whim turns while the basket travels, stands while it waits
	var ph := _kb_basket_phase()
	var want := 0.0
	if int(_shown_places.get("gin", 0)) >= 3:
		want = 0.55 if ph.x < 0.5 else 0.0
		if ph.x >= 0.5 and ph.x < 1.5 and false: want = 0.0
	_gin_v = move_toward(_gin_v, want * (1.0 if ph.y < 0.5 else -1.0), delta * 0.6)
	_gin_a += _gin_v * delta
	# the chest on its chains: a pendulum pushed by the wind (and hard by the "chest" event)
	var push := 0.35 * wn * sin(t * 1.7)
	if _events.has("chest"):
		var s := t - float(_events.chest)
		if s < 1.2: push += 2.2 * sin(s * 6.0)
	_chest_v += (-_chest_a * 3.2 + push - _chest_v * 0.35) * delta
	_chest_a += _chest_v * delta
	if surf.material is ShaderMaterial:
		var amp := 3.0 + 12.0 * wn
		(surf.material as ShaderMaterial).set_shader_parameter("amp", amp)
		if still.material is ShaderMaterial: (still.material as ShaderMaterial).set_shader_parameter("amp", amp)

## where the basket is in its trip: x 0 travelling, 1 waiting; y 0 going up, 1 going down. The basket's height out of
## the hole: 0 down in it, 1 up at the pulley
func _kb_basket_phase() -> Vector2:
	var cyc := BK_UP * 2.0 + BK_WAIT * 2.0
	var s := fmod(t, cyc)
	if s < BK_UP: return Vector2(0, 0)
	if s < BK_UP + BK_WAIT: return Vector2(1, 0)
	if s < BK_UP * 2.0 + BK_WAIT: return Vector2(0, 1)
	return Vector2(1, 1)

func _kb_basket_up() -> float:
	var cyc := BK_UP * 2.0 + BK_WAIT * 2.0
	var s := fmod(t, cyc)
	if s < BK_UP: return smoothstep(0.0, 1.0, s / BK_UP)
	if s < BK_UP + BK_WAIT: return 1.0
	if s < BK_UP * 2.0 + BK_WAIT: return 1.0 - smoothstep(0.0, 1.0, (s - BK_UP - BK_WAIT) / BK_UP)
	return 0.0

# ---------------------------------------------------------------- the whim

## the horse whim: the horse walks its circle (smaller and darker on the far side, behind the post), the sweep arm runs
## from the post to its collar, the drum's rope stripes turn; drawn in two halves - what is behind the post, the post,
## what is in front
func _kb_gin(c: CanvasItem, front_half: bool) -> void:
	if int(_shown_places.get("gin", 0)) < 3 or not J.has("gin"):
		return
	var g: Dictionary = J.gin
	var cp: Array = g.c
	var ctr := Vector2(float(cp[0]), float(cp[1]))
	var rx := float(g.rx)
	var ry := float(g.ry)
	var near := sin(_gin_a) > 0.0       # the near half of the circle is the lower one on the picture
	if near == front_half:
		var hp := ctr + Vector2(cos(_gin_a) * rx, sin(_gin_a) * ry)
		var depth := 0.5 + 0.5 * sin(_gin_a)       # 0 far, 1 near
		var sc := lerpf(0.8, 1.0, depth)
		var dark := lerpf(0.6, 1.0, depth)
		# which way it walks: by where it was a moment ago (it turns round when the whim reverses)
		var dx := -sin(_gin_a) * _gin_v
		if absf(dx) > 0.002: _horse_right = dx > 0.0
		var fs := Vector2(185, 114) / K * sc
		var fr := ""
		if _crew_ok("horse"):
			var n := int(J.crew_n.horse)
			var u := _gin_a * float(g.get("steps", 30.0))
			fr = "horse/%02d.png" % (posmod(int(absf(u)), n))
			fs = _size(fr) * sc
		var pos := Vector2(hp.x - fs.x / 2, hp.y - fs.y + 6.0)
		# the arm: a squared timber from the post, at the height of the horse's back, to the swingletree behind its collar
		var h := fs.y * 0.52
		var post := Vector2(ctr.x, ctr.y - h * 1.05)
		var tip := Vector2(hp.x, hp.y - h)
		var wood := Color(0.44, 0.29, 0.17).darkened(0.3 * (1.0 - depth))
		c.draw_line(post, tip, KB_INK, 13.0 * sc)
		c.draw_line(post, tip, wood, 8.0 * sc)
		c.draw_line(post + Vector2(0, -2.5), tip + Vector2(0, -2.5), wood.lightened(0.25), 2.2 * sc)
		if fr != "":
			_put_scaled(c, fr, pos, fs, not _horse_right, 1.0, Color(dark, dark * 0.97, dark * 0.95))
	# the post and drum again over what goes round behind them
	if not front_half and g.has("front_at") and ResourceLoader.exists(dir + "gin_front.png"):
		var fa: Array = g.front_at
		_put(c, "gin_front.png", Vector2(float(fa[0]), float(fa[1])))

## the drum's rope turning: short dark coils sliding round the drum's face while the whim moves; the rope from the
## drum's side runs on to the pulleys as the picture has it, then down from the tripod into the hole to the basket
func _kb_drum(c: CanvasItem) -> void:
	if int(_shown_places.get("gin", 0)) < 3 or not J.has("gin"):
		return
	var g: Dictionary = J.gin
	var dr: Array = g.drum     # x, y (centre), w, h
	var dc := Vector2(float(dr[0]), float(dr[1]))
	var w := float(dr[2])
	var h := float(dr[3])
	for i in 6:
		var a := _gin_a * 2.0 + i * TAU / 6.0
		if cos(a) < 0.0: continue
		var x := dc.x + sin(a) * w * 0.5
		var al := cos(a)
		c.draw_line(Vector2(x, dc.y - h * 0.42), Vector2(x - 3.0, dc.y + h * 0.42), Color(0.12, 0.08, 0.04, 0.45 * al), 3.0)

func _kb_basket(c: CanvasItem) -> void:
	if not J.has("gin"):
		return
	var g: Dictionary = J.gin
	var pl: Array = g.pulley
	var top := Vector2(float(pl[0]), float(pl[1]))
	if top.y > _seen.y + 200.0 or top.y + BK_DEPTH < _seen.x - 200.0:
		return
	var built := int(_shown_places.get("gin", 0)) >= 3
	var up := _kb_basket_up() if built else 0.0
	var bottom := top.y + float(g.get("hang", 120.0)) + BK_DEPTH * (1.0 - up)
	var sw := 0.04 * sin(t * 1.3) + 0.06 * _wind() * sin(t * 2.7)
	var at := Vector2(top.x + sin(sw) * (bottom - top.y) * 0.5, bottom)
	if not built:
		return
	c.draw_line(top, at + Vector2(0, -34), KB_INK, 5.0)
	c.draw_line(top, at + Vector2(0, -34), Color(0.62, 0.48, 0.3), 2.4)
	var hole: Array = g.hole
	var hy := float(hole[1])
	# below the hole's lip the basket is in the dark: drawn darker, and not at all once it is well down
	var dk := clampf(1.0 - (bottom - hy) / 160.0, 0.0, 1.0) if bottom > hy else 1.0
	if dk <= 0.02:
		return
	c.draw_set_transform(at, sw * 0.6, Vector2.ONE * 1.6)
	var body := Color(0.55, 0.4, 0.22) * Color(dk, dk, dk)
	c.draw_line(Vector2(-22, -10), Vector2(0, -22), KB_INK, 2.5)
	c.draw_line(Vector2(22, -10), Vector2(0, -22), KB_INK, 2.5)
	c.draw_colored_polygon(PackedVector2Array([Vector2(-26, -12), Vector2(26, -12), Vector2(20, 26), Vector2(-20, 26)]), KB_INK)
	c.draw_colored_polygon(PackedVector2Array([Vector2(-23, -9), Vector2(23, -9), Vector2(17, 23), Vector2(-17, 23)]), body)
	for j in 3:
		var yy := -2.0 + j * 9.0
		c.draw_line(Vector2(-22 + j * 1.8, yy), Vector2(22 - j * 1.8, yy), Color(0.28, 0.2, 0.1, dk), 2.0)
	# heaped with black earth and a pale bone on the way up
	if _kb_basket_phase().y < 0.5 or up > 0.98:
		var earth := Color(0.16, 0.11, 0.09) * Color(dk, dk, dk)
		c.draw_colored_polygon(PackedVector2Array([Vector2(-22, -10), Vector2(-12, -20), Vector2(0, -24), Vector2(14, -19), Vector2(22, -10)]), earth)
		c.draw_line(Vector2(-6, -18), Vector2(10, -22), Color(0.86, 0.82, 0.7, dk), 3.0)
	c.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

## the chest: the picture's chest cut out and hung again, swinging on its chains under the bough
func _kb_chest(c: CanvasItem) -> void:
	if not J.has("chest") or not ResourceLoader.exists(dir + "chest.png"):
		return
	var ch: Dictionary = J.chest
	var an: Array = ch.anchor
	var anchor := Vector2(float(an[0]), float(an[1]))
	if anchor.y > _seen.y + 300.0 or anchor.y < _seen.x - 600.0:
		return
	var sz := _size("chest.png")
	var off: Array = ch.off       # the chest picture's top-left from the anchor (unswung)
	c.draw_set_transform(anchor, _chest_a, Vector2.ONE)
	c.draw_texture_rect(tex("chest.png"), Rect2(Vector2(float(off[0]), float(off[1])), sz), false)
	c.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

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
			var col := Color(1.0, 0.62, 0.28, (0.3 + 0.15 * nt) * _flick(i))
			_light(c, Vector2(float(l[0]), float(l[1])), 80 * float(l[2]), col)
	if J.has("fire") and int(_shown_places.get("camp", 0)) >= 3:
		var fp: Array = J.fire
		var br := 0.45 + 0.15 * sin(t * 2.3) + 0.1 * sin(t * 7.1) - 0.15 * _wind() * absf(sin(t * 9.0))
		_light(c, Vector2(float(fp[0]), float(fp[1])), 110, Color(1.0, 0.45, 0.12, br))
		_light(c, Vector2(float(fp[0]), float(fp[1])), 34, Color(1.0, 0.8, 0.4, br))
	for b in _bands:
		var k := int(b.k)
		if String(_shown_bands.get(k, b.state)) == "closed" or not _band_seen(b):
			continue
		var ls: Array = J.lamps.get(str(int(b.d)), [])
		for j in ls.size():
			var l: Array = ls[j]
			_light(c, Vector2(float(l[0]), float(b.y) + float(l[1])), 140, Color(1.0, 0.66, 0.3, 0.26 * _flick(k * 3 + j)))

# ---------------------------------------------------------------- the sky, the bog, the wind

## the sun breathing behind its clouds, its long red path on the black water shivering; at night the sky darkens and
## stars come out over it
func _kb_sun(c: CanvasItem) -> void:
	if not J.has("sun"):
		return
	var sp: Array = J.sun
	var sun := Vector2(float(sp[0]), float(sp[1]))
	var nt := _night()
	if sun.y > _seen.y + 400.0:
		return
	_light(c, sun, 220, Color(1.0, 0.22, 0.12, (0.16 + 0.04 * sin(t * 0.7)) * (1.0 - 0.7 * nt)))
	if J.has("reflect"):
		var rf: Array = J.reflect      # x0, x1, y0, y1: the sun's path on the water
		var x0 := float(rf[0])
		var x1 := float(rf[1])
		var y0 := float(rf[2])
		var y1 := float(rf[3])
		var wn := _wind()
		for j in 22:
			var q := j / 21.0
			var y := lerpf(y0, y1, q)
			var w := lerpf(x1 - x0, (x1 - x0) * 1.6, q) * (0.35 + 0.35 * absf(sin(j * 2.3 + t * (0.8 + wn * 3.0))))
			var cx := (x0 + x1) * 0.5 + sin(j * 1.7 + t * 0.5) * 6.0
			var a := (0.18 + 0.2 * absf(sin(t * 1.3 + j * 0.9))) * (1.0 - 0.6 * nt)
			c.draw_line(Vector2(cx - w * 0.5, y), Vector2(cx + w * 0.5, y), Color(1.0, 0.3, 0.18, a), 2.5)
	if nt > 0.02:
		c.draw_rect(Rect2(0, 0, float(J.W), float(J.sky) + float(J.get("horizon", 600))), Color(0.03, 0.02, 0.06, 0.45 * nt))
		for s in _stars:
			var tw := 0.5 + 0.5 * sin(t * float(s[3]) + float(s[2]))
			c.draw_circle(Vector2(float(s[0]), float(s[1]) * 0.6), 1.6, Color(1, 0.95, 0.9, 0.7 * nt * tw))

## mist banks drifting over the bog, the will-o'-the-wisps hanging low over the water (more at night)
func _kb_bog(c: CanvasItem) -> void:
	if not J.has("bog"):
		return
	var bg: Array = J.bog          # x0, y0, x1, y1
	var x0 := float(bg[0])
	var y0 := float(bg[1])
	var x1 := float(bg[2])
	var y1 := float(bg[3])
	if y0 > _seen.y or y1 < _seen.x:
		return
	var nt := _night()
	var wn := _wind()
	var ps := _size("puff.png")
	for m in _kb_mist:
		var y := lerpf(y0, y1, float(m[0]))
		var w := float(m[2])
		var x := fposmod(float(m[3]) * (x1 - x0) + t * float(m[1]) * (1.0 + 2.0 * wn), (x1 - x0) + w) + x0 - w * 0.5
		for j in 5:
			var q := Vector2(x + (j - 2) * w * 0.22, y + sin(j * 1.9 + t * 0.2) * 12.0)
			var sc := Vector2(w * 0.32, 70.0) / ps
			c.draw_texture_rect(tex("puff.png"), Rect2(q - ps * sc / 2, ps * sc), false, Color(0.62, 0.55, 0.64, 0.13 + 0.05 * nt))
	var n := int(lerpf(5.0, float(_kb_wisps.size()), nt))
	for i in n:
		var wv: Array = _kb_wisps[i]
		var p := Vector2(lerpf(x0, x1, float(wv[0])), lerpf(y0 + 40.0, y1, float(wv[1])))
		p += Vector2(sin(t * 0.3 * float(wv[3]) + float(wv[2])) * 40.0, sin(t * 0.7 * float(wv[3]) + float(wv[2]) * 2.0) * 12.0)
		var on := 0.5 + 0.5 * sin(t * 0.9 * float(wv[3]) + float(wv[2]) * 3.0)
		on = on * on
		if on < 0.05: continue
		_light(c, p, 38, Color(KB_WISP, 0.32 * on))
		c.draw_circle(p, 4.0, Color(0.85, 1.0, 0.88, 0.75 * on))

## a gust: leaves and a feather or two blowing across the barrow, and the dust devil crossing the far steppe
func _kb_wind(c: CanvasItem) -> void:
	var wn := _wind()
	if wn <= 0.01:
		return
	var sky := float(J.sky)
	for i in 16:
		var u := fmod(t * 0.35 + i * 0.137, 1.0)
		var p := Vector2(lerpf(-60.0, 1600.0, u), sky + 200.0 + fmod(i * 431.0, 1300.0) + sin(t * 3.0 + i) * 40.0)
		var a := t * 6.0 + i
		var col := Color(0.32, 0.2, 0.12, 0.85 * wn) if i % 4 else Color(0.85, 0.82, 0.75, 0.8 * wn)
		c.draw_set_transform(p, a, Vector2.ONE)
		c.draw_colored_polygon(PackedVector2Array([Vector2(-7, 0), Vector2(0, -3), Vector2(7, 0), Vector2(0, 3)]), col)
		c.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	if _devil_x >= 0.0 and J.has("horizon"):
		var hy := sky + float(J.horizon)
		var base := Vector2(_devil_x, hy + 10.0)
		var ps := _size("puff.png")
		for j in 16:
			var q := j / 15.0
			var r := lerpf(10.0, 60.0, q)
			var a := t * 7.0 + j * 0.9
			var p := base + Vector2(cos(a) * r * 0.6 + sin(t * 1.3 + q * 3.0) * 14.0 * q, -q * 260.0)
			var sc := Vector2.ONE * lerpf(0.25, 0.9, q)
			c.draw_texture_rect(tex("puff.png"), Rect2(p - ps * sc / 2, ps * sc), false, Color(0.55, 0.36, 0.28, 0.28 * wn * (1.0 - q * 0.5)))

## ravens: a lone one crosses over the oak now and then; the "ravens" event is the flock - six or seven come in from
## the side, circle the oak's crown twice (the far side of the circle smaller and darker), and scatter away over the bog
func _kb_ravens(c: CanvasItem) -> void:
	if not J.has("oak") or not _crew_ok("ravenfly"):
		return
	var op: Array = J.oak
	var oak := Vector2(float(op[0]), float(op[1]))
	if oak.y > _seen.y + 300.0 or oak.y < _seen.x - 500.0:
		return
	var n := int(J.crew_n.ravenfly)
	# the lone raven: every 20 s it flies over from the bog to the oak and on
	var s := fmod(t + 3.0, 20.0)
	if s < 6.0:
		var u := s / 6.0
		var p := Vector2(lerpf(-60.0, 1600.0, u), oak.y - 120.0 - sin(u * PI) * 60.0)
		var fr := "ravenfly/%02d.png" % (int(t * 10.0) % n)
		var fs := _size(fr) * 1.2
		_light(c, p, fs.x * 0.9, Color(1.0, 0.45, 0.35, 0.15))
		_put_scaled(c, fr, p - fs / 2, fs, true)
	if not _events.has("ravens"):
		return
	var s2 := t - float(_events.ravens)
	for i in 7:
		var q := s2 - i * 0.18
		if q < 0.0: continue
		var a := q * 1.6 + i * TAU / 7.0
		var r := Vector2(300.0 + 40.0 * sin(i * 2.1), 70.0 + 14.0 * sin(i * 1.3))
		# coming in: the circle draws in from wide; going away: it opens out and up
		var come := clampf(q / 1.6, 0.0, 1.0)
		var go := clampf((q - 7.5) / 2.0, 0.0, 1.0)
		r *= lerpf(2.6, 1.0, come * come * (3.0 - 2.0 * come)) * (1.0 + 2.5 * go * go)
		var sky_c := oak + Vector2(0, -120.0)
		var p := sky_c + Vector2(cos(a) * r.x * 1.3, sin(a) * r.y - 30.0 * sin(q * 2.0 + i) - 200.0 * go * go)
		var near := 0.5 + 0.5 * sin(a)
		var fr := "ravenfly/%02d.png" % (int(t * 11.0 + i * 3) % n)
		var fs := _size(fr) * lerpf(1.1, 1.6, near)
		var dk := lerpf(0.55, 1.0, near)
		var al := clampf(q / 0.4, 0.0, 1.0) * clampf((10.0 - q) / 0.8, 0.0, 1.0)
		_light(c, p, fs.x * 0.9, Color(1.0, 0.45, 0.35, 0.18 * al))
		# flying left on the near half of the circle (the sheet faces left), right on the far half
		_put_scaled(c, fr, p - fs / 2, fs, sin(a) < 0.0, al, Color(dk, dk, dk))

func _put_scaled(c: CanvasItem, path: String, pos: Vector2, sz: Vector2, flip: bool, al := 1.0, tint := Color.WHITE) -> void:
	var col := Color(tint, al)
	if not flip:
		c.draw_texture_rect(tex(path), Rect2(pos, sz), false, col)
		return
	c.draw_set_transform(pos + Vector2(sz.x, 0), 0, Vector2(-1, 1))
	c.draw_texture_rect(tex(path), Rect2(Vector2.ZERO, sz), false, col)
	c.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

# ---------------------------------------------------------------- the surface alive

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
		if nm == "cook24":
			_light(c, pos + Vector2(fs.x * (0.15 if flip else 0.85), fs.y * 0.55), 40, Color(1.0, 0.5, 0.15, 0.2 + 0.08 * sin(t * 3.0)))

## the hand out of the bog: it rises among the reeds, claws, and sinks back ("hand" event, and by itself at night)
func _kb_hand(c: CanvasItem, s: float) -> bool:
	if not J.has("hand") or not _crew_ok("hand"):
		return true
	var hp: Array = J.hand
	var at := Vector2(float(hp[0]), float(hp[1]))
	var n := int(J.crew_n.hand)
	var i := mini(int(s * 3.2), n - 1)
	var fr := "hand/%02d.png" % i
	var fs := _size(fr)
	var al := clampf(s / 0.6, 0.0, 1.0) * clampf((n / 3.2 + 0.4 - s) / 0.6, 0.0, 1.0)
	_put_scaled(c, fr, Vector2(at.x - fs.x / 2, at.y - fs.y), fs, false, al)
	# rings on the water round the wrist
	for j in 2:
		var q := fmod(s * 0.6 + j * 0.5, 1.0)
		c.draw_arc(at + Vector2(0, 2), 10.0 + 40.0 * q, 0, TAU, 24, Color(0.9, 0.5, 0.45, 0.35 * (1.0 - q) * al), 1.6)
	return s > n / 3.2 + 0.6

# ---------------------------------------------------------------- the depths

func _draw_live() -> void:
	var c := live
	_kb_sun(c)
	_lights(c)
	_kb_bog(c)
	_kb_chest(c)
	_kb_ravens(c)
	_kb_gin(c, false)
	_kb_drum(c)
	_surface_live(c)
	_kb_gin(c, true)
	_kb_basket(c)
	_kb_stair_lamp(c)
	for b in _bands:
		if _band_seen(b):
			_band_live(c, b)
			_kb_small_life(c, b)
	_events_live(c)
	_kb_wind(c)
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

## someone goes down the stairwell in the section with a lantern now and then: only his swinging light is seen in the
## dark shaft, step by step, until it is gone below
func _kb_stair_lamp(c: CanvasItem) -> void:
	if not J.has("stair"):
		return
	var pts: Array = J.stair
	var cyc := 22.0
	var s := fmod(t + 5.0, cyc)
	var go := 12.0
	if s > go:
		return
	var p0: Array = pts[0]
	var pl: Array = pts[pts.size() - 1]
	if float(pl[1]) < _seen.x - 200.0 or float(p0[1]) > _seen.y + 200.0:
		return
	var u := s / go * (pts.size() - 1)
	var i := mini(int(u), pts.size() - 2)
	var a: Array = pts[i]
	var b: Array = pts[i + 1]
	var p := Vector2(float(a[0]), float(a[1])).lerp(Vector2(float(b[0]), float(b[1])), u - i)
	p.y -= absf(sin(s * 5.0)) * 5.0                 # each step
	var al := clampf(s / 1.0, 0.0, 1.0) * clampf((go - s) / 1.5, 0.0, 1.0)
	var sw := sin(s * 3.3) * 6.0
	_light(c, p + Vector2(sw, 0), 120, Color(1.0, 0.62, 0.28, 0.35 * al))
	c.draw_line(p + Vector2(0, -18), p + Vector2(sw, 0), Color(0.05, 0.04, 0.03, al), 2.0)
	c.draw_rect(Rect2(p + Vector2(sw - 5, 0), Vector2(10, 13)), Color(0.05, 0.04, 0.03, al))
	c.draw_rect(Rect2(p + Vector2(sw - 3, 2), Vector2(6, 9)), Color(1.0, 0.82, 0.45, al))

## Koschei's eyes: in a dark knot of the oak, between its chains, two cold green slits open, look along the bog, close
func _kb_oak_eyes(c: CanvasItem, s: float) -> bool:
	if not J.has("oak_eyes"):
		return true
	var ey: Array = J.oak_eyes
	var open_ := clampf((s - 0.3) / 1.2, 0.0, 1.0) * clampf((5.2 - s) / 0.5, 0.0, 1.0)
	if s > 2.6 and s < 2.75: open_ *= 0.1          # a blink
	var look := sin(clampf((s - 1.5) / 2.5, 0.0, 1.0) * PI) * 2.5
	for e_ in ey:
		var e: Array = e_
		var p := Vector2(float(e[0]), float(e[1]))
		_light(c, p, 40, Color(KB_WISP, 0.35 * open_))
		var w := 9.0
		var h := 4.5 * open_
		var pts := PackedVector2Array()
		for j in 13:
			var a := TAU * j / 12.0
			pts.append(p + Vector2(cos(a) * w, sin(a) * h))
		if h > 0.4:
			c.draw_colored_polygon(pts, Color(0.75, 1.0, 0.65, 0.95))
			c.draw_line(p + Vector2(look, -h), p + Vector2(look, h), Color(0.02, 0.05, 0.02), 2.2)
	return s > 5.6

## a depth's life: its crew (and their reaction to the level), its second dweller
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
	# the second dweller (behind the crew)
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
		_light(c, Vector2(x + float(lp[0]) * sgn, floor_y + float(lp[1])), 70, Color(1.0, 0.72, 0.35, 0.5 * al * _flick(k)))

## per depth, the life between the events: earth crumbs trickling from the roots (50 m), dust in the lamplight, the
## lake's rings and drifting feathers (300 m), cold glints over the egg's crystals (350 m), gold glints in the hoard
## (400 m), the needle breathing pale once it shows (450 m)
func _kb_small_life(c: CanvasItem, b: Dictionary) -> void:
	var k := int(b.k)
	var d := int(b.d)
	var y := float(b.y)
	var st := String(_shown_bands.get(k, b.state))
	if st == "closed":
		return
	var L: Dictionary = J.get("light", {}).get(str(d), {})
	# earth crumbs trickling down from the roof here and there
	for j in 3:
		var cyc := 3.0 + j * 1.3
		var s := fmod(t + j * 1.7 + k * 0.9, cyc)
		if s > 1.1: continue
		var x := 380.0 + fmod((k * 7 + j) * 337.0, 780.0)
		var y0 := y + 120.0
		var yy := y0 + 380.0 * s * s
		if yy > y + floor_of(d): continue
		c.draw_circle(Vector2(x, yy), 2.5, Color(0.18, 0.12, 0.09, 0.8))
		c.draw_circle(Vector2(x + 5, yy - 12), 1.8, Color(0.18, 0.12, 0.09, 0.6))
	if L.has("pts"):
		var kind := String(L.get("kind", "glint"))
		var col := Color(String(L.get("col", "#ffd88a")))
		var pts: Array = L.pts
		for j in pts.size():
			var pp: Array = pts[j]
			var p := Vector2(float(pp[0]), y + float(pp[1]))
			var on := maxf(0.0, sin(t * (0.9 + 0.3 * sin(j)) + j * 2.1))
			if kind == "glint":
				on = pow(on, 8.0)
				if on < 0.05: continue
				_light(c, p, 22, Color(col, 0.6 * on))
				c.draw_line(p - Vector2(7, 0) * on, p + Vector2(7, 0) * on, Color(1, 1, 1, 0.8 * on), 1.5)
				c.draw_line(p - Vector2(0, 7) * on, p + Vector2(0, 7) * on, Color(1, 1, 1, 0.8 * on), 1.5)
			elif kind == "ripple":
				var q := fmod(t * 0.4 + j * 0.37, 1.0)
				c.draw_arc(p, 6.0 + 50.0 * q, 0, TAU, 28, Color(col, 0.35 * (1.0 - q)), 1.6)
			elif kind == "breath":
				_light(c, p, float(L.get("r", 80)), Color(col, (0.12 + 0.12 * on)))
	# 150 m: now and then an idol's eyes glint in the lamplight, as if it looked round
	if L.has("eyes"):
		var ey: Array = L.eyes
		for j in ey.size():
			var e: Array = ey[j]
			var q := fmod(t * 0.13 + j * 0.37 + k * 0.1, 1.0)
			var on := pow(maxf(0.0, sin(q * TAU * 3.0)), 12.0) if q < 0.34 else 0.0
			if on < 0.05: continue
			var p := Vector2(float(e[0]), y + float(e[1]))
			for sx in [-7.0, 7.0]:
				_light(c, p + Vector2(sx, 0), 12, Color(1.0, 0.35, 0.2, 0.6 * on))
				c.draw_circle(p + Vector2(sx, 0), 2.2, Color(1.0, 0.75, 0.5, on))
	# 250 m: a pair of long ears comes up out of a burrow, twitches, and drops back
	if L.has("ears"):
		var er: Array = L.ears
		var cyc := 6.5
		var j0 := int(t / cyc + k) % er.size()
		var s2 := fmod(t, cyc)
		if s2 < 3.0:
			var e: Array = er[j0]
			var p := Vector2(float(e[0]), y + float(e[1]) + 14.0)
			var up := clampf(s2 / 0.4, 0.0, 1.0) * clampf((3.0 - s2) / 0.3, 0.0, 1.0)
			var tw := 0.12 * sin(t * 9.0) * float(s2 > 1.0 and s2 < 1.6)
			for sx in [-1.0, 1.0]:
				var base := p + Vector2(sx * 6.0, 0)
				var tip := base + Vector2(sx * 6.0 + tw * 30.0, -34.0 * up)
				var side := Vector2(4.0, 0)
				c.draw_colored_polygon(PackedVector2Array([base - side * 1.4, tip, base + side * 1.4]), KB_INK)
				c.draw_colored_polygon(PackedVector2Array([base - side, tip + Vector2(0, 3), base + side]), Color(0.42, 0.34, 0.27))
				c.draw_line(base + Vector2(0, -3), tip.lerp(base, 0.3), Color(0.8, 0.55, 0.5), 1.5)
	# 300 m: drops fall off the dripping roof into the lake, a ring where each lands
	if L.has("drips"):
		var dp: Array = L.drips
		for j in dp.size():
			var e: Array = dp[j]
			var cyc := 2.6 + j * 0.7
			var s3 := fmod(t + j * 1.1, cyc)
			var x := float(e[0])
			var y0 := y + float(e[1])
			var y1 := y + float(e[2])
			var fall := 0.55
			if s3 < 0.6:
				c.draw_circle(Vector2(x, y0 + 4.0 * s3), 2.0 + 2.0 * s3, Color(0.75, 0.85, 0.95, 0.8))
			elif s3 < 0.6 + fall:
				var u := (s3 - 0.6) / fall
				c.draw_line(Vector2(x, lerpf(y0, y1, u * u) - 8.0), Vector2(x, lerpf(y0, y1, u * u)), Color(0.8, 0.9, 1.0, 0.85), 2.0)
			else:
				var q := (s3 - 0.6 - fall) / 1.2
				if q < 1.0:
					c.draw_arc(Vector2(x, y1), 5.0 + 40.0 * q, 0, TAU, 24, Color(1.0, 0.75, 0.45, 0.45 * (1.0 - q)), 1.5)
	# 450 m: sparks rise from the braziers
	if L.has("embers"):
		var eb: Array = L.embers
		for j in eb.size():
			var e: Array = eb[j]
			for i in 6:
				var u := fmod(t * 0.45 + i / 6.0 + j * 0.3, 1.0)
				var p := Vector2(float(e[0]) + sin(t * 2.0 + i * 1.7) * 10.0 * u, y + float(e[1]) - 120.0 * u)
				c.draw_circle(p, 2.0 * (1.0 - u) + 0.5, Color(1.0, 0.6, 0.2, 0.9 * (1.0 - u)))
	if d == 6 and L.has("feathers"):
		var fz: Array = L.feathers
		for j in fz.size():
			var fp: Array = fz[j]
			var p := Vector2(float(fp[0]) + sin(t * 0.2 + j) * 30.0, y + float(fp[1]) + sin(t * 0.9 + j * 2.0) * 2.0)
			c.draw_set_transform(p, sin(t * 0.3 + j) * 0.4, Vector2.ONE)
			c.draw_colored_polygon(PackedVector2Array([Vector2(-9, 0), Vector2(0, -3), Vector2(9, 0), Vector2(0, 2)]), Color(0.92, 0.9, 0.85, 0.85))
			c.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

# ---------------------------------------------------------------- events (signs of Koschei)

## where an event happens (source px), for the admin's "Event:" buttons: Home glides there before it plays
func event_y(ev: String) -> float:
	match ev:
		"chest", "ravens":
			return float((J.chest.anchor as Array)[1]) + 120.0 if J.has("chest") else float(J.sky) + 300.0
		"eyes":
			return float((J.oak_eyes as Array)[0][1]) + 150.0 if J.has("oak_eyes") else float(J.sky) + 300.0
		"hand", "horse", "shadow":
			return float((J.hand as Array)[1]) - 200.0 if J.has("hand") else float(J.sky) + 900.0
		"hare":
			return band_y(4) + 300.0
		"duck":
			return band_y(5) + 300.0
		"egg":
			return band_y(6) + 300.0
		"coin":
			return band_y(7) + 300.0
	return -1.0

var _pending_ev := ""
var _pending_at := 0.0
func _tick_events() -> void:
	# an event from the admin waits until the screen has glided to it
	if force_event != "":
		_pending_ev = force_event
		_pending_at = t + 0.9
		force_event = ""
	if _pending_ev != "" and t > _pending_at:
		_start_event(_pending_ev)
		_pending_ev = ""
	if t < _next_event:
		return
	_next_event = t + _rng.randf_range(10.0, 16.0)
	var pool := ["chest", "hand", "shadow", "eyes", "eyes", "ravens", "ravens"]
	if _night() > 0.5: pool.append("horse")
	for kk in [4, 5, 6, 7]:
		if open >= kk and String(_shown_bands.get(kk, "closed")) != "closed":
			pool.append(["hare", "duck", "egg", "coin"][kk - 4])
	_start_event(pool[_rng.randi() % pool.size()])

func _start_event(ev: String) -> void:
	_events[ev] = t
	match ev:
		"chest":
			KoscheiSounds.chain(self, _far(float((J.chest.anchor as Array)[1])) if J.has("chest") else -10.0)
		"hare":
			KoscheiSounds.scurry(self, _far(band_y(4) + 300.0))
		"duck":
			KoscheiSounds.wings(self, _far(band_y(5) + 300.0))
		"egg":
			KoscheiSounds.heart(self, _far(band_y(6) + 300.0))
		"coin":
			pass
		"hand":
			KoscheiSounds.squelch(self, _far(float((J.hand as Array)[1])) if J.has("hand") else -10.0)
		"horse":
			KoscheiSounds.gallop(self, _far(float(J.sky) + float(J.get("horizon", 600))))
		"shadow":
			pass
		"eyes":
			KoscheiSounds.groan(self, _far(float(J.sky) + 300.0) - 6.0)
		"ravens":
			KoscheiSounds.caw(self, _far(float((J.oak as Array)[1])) if J.has("oak") else -10.0)

func _events_live(c: CanvasItem) -> void:
	for ev in _events.keys():
		var s := t - float(_events[ev])
		var done := false
		match ev:
			"chest":
				# a hard swing (the pendulum does it), a rusty link drops and tumbles down into the grass
				done = s > 3.0
				if J.has("chest") and s < 2.4:
					var an: Array = J.chest.anchor
					var p := Vector2(float(an[0]) + 40.0 + s * 30.0, float(an[1]) + 60.0 + 260.0 * s * s)
					c.draw_set_transform(p, s * 9.0, Vector2.ONE)
					c.draw_rect(Rect2(-14, -8, 28, 16), KB_INK, false, 8.0)
					c.draw_rect(Rect2(-14, -8, 28, 16), Color(0.62, 0.3, 0.14), false, 4.0)
					c.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
			"hand":
				done = _kb_hand(c, s)
			"eyes":
				done = _kb_oak_eyes(c, s)
			"ravens":
				done = s > 11.5
			"shadow":
				# a long thin crowned shadow walks across the barrow's cut face - nobody casts it
				done = s > 9.0
				if J.has("cutface") and _crew_ok("shadow"):
					var cf: Array = J.cutface      # x0, x1, y (the feet)
					var u := clampf(s / 9.0, 0.0, 1.0)
					var x := lerpf(float(cf[0]), float(cf[1]), u)
					var n := int(J.crew_n.shadow)
					var fr := "shadow/%02d.png" % (int(s * 5.0) % n)
					var fs := _size(fr) * 1.0
					var al := clampf(s / 1.2, 0.0, 1.0) * clampf((9.0 - s) / 1.5, 0.0, 1.0) * 0.55
					# stretched long and slanting, as a shadow at sunset
					c.draw_set_transform(Vector2(x, float(cf[2])), 0.0, Vector2(1.0, 1.0))
					c.draw_set_transform_matrix(Transform2D(Vector2(1.7, 0.0), Vector2(-0.3, 1.25), Vector2(x, float(cf[2]))))
					c.draw_texture_rect(tex(fr), Rect2(Vector2(-fs.x / 2, -fs.y), fs), false, Color(0.0, 0.0, 0.02, al))
					c.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
			"horse":
				# Koschei's bony horse gallops along the far horizon in silhouette, eyes burning pale
				done = s > 7.0
				if J.has("horizon") and _crew_ok("bonehorse"):
					var hy := float(J.sky) + float(J.horizon)
					var u := clampf(s / 7.0, 0.0, 1.0)
					var x := lerpf(-120.0, 640.0, u)
					var n := int(J.crew_n.bonehorse)
					var fr := "bonehorse/%02d.png" % (int(s * 12.0) % n)
					var fs := _size(fr)
					# it fades out before the barrow's flank: gone behind it
					var al := clampf(s / 0.8, 0.0, 1.0) * clampf((7.0 - s) / 1.8, 0.0, 1.0)
					_put_scaled(c, fr, Vector2(x - fs.x / 2, hy - fs.y + 6.0), fs, false, al)
					_light(c, Vector2(x + fs.x * 0.35, hy - fs.y * 0.8), 18, Color(KB_COLD, 0.6 * al))
			"hare":
				# a big hare bolts out of a burrow, across the warrens' floor in long bounds, into another
				done = s > 3.2
				if _crew_ok("hare") and open >= 4:
					var y := band_y(4) + floor_of(5)
					var gx: Array = J.galleries.get("5", [330, 1200])
					var u := clampf(s / 2.6, 0.0, 1.0)
					var x := lerpf(float(gx[0]) + 80.0, float(gx[1]) - 80.0, u)
					var n := int(J.crew_n.hare)
					var fr := "hare/%02d.png" % (int(s * 14.0) % n)
					var fs := _size(fr)
					var al := clampf(s / 0.2, 0.0, 1.0) * clampf((3.0 - s) / 0.3, 0.0, 1.0)
					_put_scaled(c, fr, Vector2(x - fs.x / 2, y - fs.y - absf(sin(s * 14.0 * PI / 4.0)) * 20.0), fs, false, al)
			"duck":
				# a duck bursts up off the lake, circles under the roof and is gone into the dark of the stairwell
				done = s > 4.0
				if _crew_ok("duck") and open >= 5:
					var y := band_y(5)
					var u := clampf(s / 4.0, 0.0, 1.0)
					var ctr := Vector2(768, y + 300)
					var a := PI * 0.9 + u * TAU * 0.85
					var p := ctr + Vector2(cos(a) * 420.0, sin(a) * 110.0 - 60.0 * u)
					var n := int(J.crew_n.duck)
					var fr := "duck/%02d.png" % (int(s * 14.0) % n)
					var fs := _size(fr)
					var al := clampf(s / 0.3, 0.0, 1.0) * clampf((4.0 - s) / 0.5, 0.0, 1.0)
					_put_scaled(c, fr, p - fs / 2, fs, -sin(a) < 0.0, al)
					# a feather left drifting down
					if s > 0.5:
						var fp := ctr + Vector2(-380.0, -40.0 + (s - 0.5) * 50.0) + Vector2(sin(s * 2.0) * 20.0, 0)
						c.draw_colored_polygon(PackedVector2Array([fp + Vector2(-8, 0), fp + Vector2(0, -3), fp + Vector2(8, 0), fp + Vector2(0, 2)]), Color(0.95, 0.93, 0.88, 0.9 * al))
			"egg":
				# a cold light runs over the egg cavern's crystals, like a heart beating inside the stone
				done = s > 3.0
				if open >= 6 and J.has("egg"):
					var eg: Array = J.egg      # cx, cy, rx, ry (band px)
					var ctr := Vector2(float(eg[0]), band_y(6) + float(eg[1]))
					for j in 2:
						var q := clampf((s - j * 0.45) / 1.4, 0.0, 1.0)
						if q <= 0.0 or q >= 1.0: continue
						var r := Vector2(float(eg[2]), float(eg[3])) * q
						var pts := PackedVector2Array()
						for i in 33:
							var a := TAU * i / 32.0
							pts.append(ctr + Vector2(cos(a) * r.x, sin(a) * r.y))
						c.draw_polyline(pts, Color(KB_COLD, 0.5 * (1.0 - q)), 6.0)
					_light(c, ctr, 260, Color(KB_COLD, 0.2 * sin(PI * clampf(s / 3.0, 0.0, 1.0))))
			"coin":
				# a gold coin rolls over the hoard's floor by itself and drops into a crack; far below, a clink
				done = s > 3.0
				if open >= 7:
					var y := band_y(7) + floor_of(8) - 8.0
					var x := 560.0 + s * 160.0
					if s < 2.2:
						_light(c, Vector2(x, y), 40, Color(1.0, 0.8, 0.3, 0.4))
						c.draw_circle(Vector2(x, y), 15.0, KB_INK)
						c.draw_circle(Vector2(x, y), 12.0, Color(0.95, 0.75, 0.25))
						c.draw_line(Vector2(x, y) + Vector2.from_angle(s * 12.0) * 6.0, Vector2(x, y) - Vector2.from_angle(s * 12.0) * 6.0, Color(0.6, 0.4, 0.1), 1.5)
					if _passed("coin_drop", s, 100.0, 2.2):
						amb.shot("coin", _far(y) - 6.0, 0.8)
						get_tree().create_timer(0.9).timeout.connect(func(): amb.shot("coin", _far(y) - 16.0, 0.6))
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
		amp = 6.0 * (1.0 - s / 1.6)
	position.x = sin(t * 47.0) * amp * scale.x
	if s >= 0.0 and s < 0.05 and not _cue.has("tremor%d" % int(_tremor_at)):
		_cue["tremor%d" % int(_tremor_at)] = true
		amb.shot("rockfall", -4.0, 0.55)
		KoscheiSounds.groan(self, -4.0)

## the needle found: it burns cold in its shell, the twelve chains thrum taut, the wisps of the bog are drawn down to
## it (pale motes rising up the stairwells), the barrow shudders now and then
func _finale(c: CanvasItem) -> void:
	if String(_shown_bands.get(8, "")) != "done" or not J.has("needle"):
		return
	var y := band_y(8)
	var nd: Dictionary = J.needle
	var cp: Array = nd.c
	var ctr := Vector2(float(cp[0]), y + float(cp[1]))
	var sh := clampf(1.0 - (t - _tremor_at) / 2.0, 0.0, 1.0)
	var br := 0.55 + 0.25 * sin(t * 1.3) + 0.4 * sh
	_light(c, ctr, 240, Color(KB_COLD, 0.22 * br))
	_light(c, ctr, 60, Color(0.9, 0.97, 1.0, 0.5 * br))
	var len := float(nd.get("len", 120))
	c.draw_line(ctr + Vector2(0, -len * 0.5), ctr + Vector2(0, len * 0.5), Color(0.95, 0.98, 1.0, 0.6 * br), 3.0)
	for a_ in nd.get("chains", []):
		var an: Array = a_
		var to := Vector2(float(an[0]), y + float(an[1]))
		var mid := ctr.lerp(to, 0.5) + Vector2(0, 3.0 * sin(t * 40.0 + to.x) * sh)
		c.draw_polyline(PackedVector2Array([ctr, mid, to]), Color(KB_COLD, 0.18 * br), 2.0)
	for j in 10:
		var u := fmod(t * 0.15 + j / 10.0, 1.0)
		var p := ctr + Vector2(sin(j * 2.3 + t * 0.4) * 300.0 * (1.0 - u), -260.0 + u * 260.0)
		_light(c, p, 26, Color(KB_WISP, 0.4 * sin(PI * u)))
	if _passed("needle_hum", t, 7.0, 0.0) and _far(ctr.y) > -12.0:
		KoscheiSounds.drone(self, _far(ctr.y) - 6.0)

## after a win the level's bones fly down into the depth they came from: pale bones and grey iron in arcs
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
		var glow := Color(0.75, 0.8, 0.9) if iron else Color(0.95, 0.92, 0.85)
		if u <= 1.0:
			var e := u * u * (3.0 - 2.0 * u)
			var p := from.lerp(tgt, e) + Vector2(sin(i * 1.7) * 140 * sin(PI * u), -220 * sin(PI * u))
			c.draw_circle(p, 22.0, Color(glow, 0.22))
			_kb_bone(c, p, 26.0, iron, i, t * (3.0 + (i % 3)))
		else:
			var f := (u - 1.0) / 0.4
			_light(c, tgt, 60 + 70 * f, Color(glow, 0.6 * (1.0 - f)))
			_kb_bone(c, tgt + Vector2(0, -8), 26.0 * (1.0 - smoothstep(0.5, 1.0, f)), iron, i, 0.0)
		if _passed("ore%d" % i, u, 1.0, 1.0):
			amb.shot("coin", -12.0, 0.8 + (i % 4) * 0.05)

## a pale bone (a knob at each end) or a lump of grey iron
func _kb_bone(c: CanvasItem, at: Vector2, r: float, iron: bool, seed_: int, spin: float) -> void:
	if r < 1.0:
		return
	if iron:
		var pts := PackedVector2Array()
		var rim := PackedVector2Array()
		for j in 7:
			var a := spin + TAU * j / 7.0
			var rr := r * (0.7 + 0.3 * absf(sin(seed_ * 3.1 + j * 1.9)))
			pts.append(at + Vector2.from_angle(a) * rr)
			rim.append(at + Vector2.from_angle(a) * (rr + 5.0))
		c.draw_colored_polygon(rim, KB_INK)
		c.draw_colored_polygon(pts, Color(0.36, 0.35, 0.37))
		return
	var ax := Vector2.from_angle(spin) * r * 0.75
	var bone := Color(0.9, 0.86, 0.74)
	c.draw_line(at - ax, at + ax, KB_INK, r * 0.55)
	for e in [at - ax, at + ax]:
		var side := Vector2(-ax.y, ax.x).normalized() * r * 0.22
		c.draw_circle(e + side, r * 0.3, KB_INK)
		c.draw_circle(e - side, r * 0.3, KB_INK)
	c.draw_line(at - ax, at + ax, bone, r * 0.35)
	for e in [at - ax, at + ax]:
		var side := Vector2(-ax.y, ax.x).normalized() * r * 0.22
		c.draw_circle(e + side, r * 0.22, bone)
		c.draw_circle(e - side, r * 0.22, bone)

# ---------------------------------------------------------------- crews and sounds

## how loud the blind singer is (his place on the screen)
func guide_db() -> float:
	return _far(guide_head().y + 60.0)

func _kb_crew_v(k: int, at: float) -> float:
	var v := at * CREW_FPS + k * 7.0
	if _kb_hold.has(k):
		v -= clampf(at - float(_kb_hold[k]), 0.0, REACT_LEN) * CREW_FPS
	return v

func _crew_frame(cr: Dictionary, k: int) -> int:
	return _drawing_at(cr, _kb_crew_v(k, t))

func _kb_hit_at(cr: Dictionary) -> float:
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
			if _passed("hit%d" % k, _kb_crew_v(k, t), _loop(cr), _kb_hit_at(cr)) and (k == sel or randf() < 0.15):
				KoscheiSounds.strike(self, who, db)
	KoscheiSounds.of(self).tick(self)
