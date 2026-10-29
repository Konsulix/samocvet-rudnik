class_name SeaView
extends MineView
## Whalebone Cove (mine 3, the Kraken's): an old whaling station on a sea cliff of the Norwegian coast turned into a mine of
## jet and shale, drawn like Old Adit (MineView) but laid out its own way (docs/mine-design.md §9): the station on the
## cliff top, the mine entered through a sea cave; under the waves the picture turns into a section through the coast AND
## the sea - the water seen from the side like an aquarium wall, a wreck on the sea bed - and the galleries run under the
## sea bed. The life of the place is the sea: the swell breaking on the cliff, the lighthouse's beam sweeping, and in the
## shaft the man engine (a long rod stroking up and down that the men ride). Home makes it for area 2 when its pictures
## exist (available_here) and talks to it as to MineView.
## Pictures and coordinates: assets/mine/whalebone_cove/ + mine.json (art/zone/export_mine3.py), source px of the
## 1536-wide stack: the sky, the surface, the sea in section, the depth bands.

const SDIR := "res://assets/mine/whalebone_cove/"
## the surface's places in drawing order (their pictures meet at soft edges)
const SPLACES := ["lighthouse", "chapel", "tryworks", "crane", "arch", "landing"]
## the depths whose job is built in the gallery itself: its stages are the band's pictures
const SBAND_JOBS := {4: "bulkhead", 8: "skeleton", 9: "grotto"}
const SSTAGES := ["clear", "step1", "step2", "done"]

var _waves: Sprite2D       # the waves at the foot of the cliff (cut from the picture, set moving by sea_water.gdshader)
var _deep: Sprite2D        # the sea in section
var _sfx: Node2D           # smoke, spray (particles in the picture's own coordinates)
var _smoke: Array = []     # the tryworks' chimney smoke emitters
var _hold := {}            # depth -> when its crew's reaction began: the crew's loop waits while it plays
var _swell_at := -100.0    # the last big wave that broke on the cliff
var _next_swell := 3.0
var _spray: Array = []     # [where, when, size] of the bursts of spray now flying
var _ink: Array = []       # the Kraken's ink: [centre, start]
var _storm := {}           # the lightning now playing: {kind, t0, bolts, pulses, seed, played}
var _next_storm := 14.0

func _init() -> void:
	dir = SDIR

func available_here() -> bool:
	return FileAccess.file_exists(SDIR + "mine.json")

func _ready() -> void:
	super()
	var wm := ShaderMaterial.new()
	wm.shader = load("res://shaders/sea_water.gdshader")
	_deep = Sprite2D.new()
	_deep.centered = false
	_deep.material = wm
	add_child(_deep)
	move_child(_deep, live.get_index())
	_waves = Sprite2D.new()
	_waves.centered = false
	_waves.material = wm.duplicate()
	add_child(_waves)
	move_child(_waves, live.get_index())
	_sfx = Node2D.new()
	add_child(_sfx)
	move_child(_sfx, front.get_index())

# ---------------------------------------------------------------- state

func _sea_top() -> float:
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
	var y0 := _sea_top() + float(J.sea)
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
		_next_event = 6.0
		_set_area = a
	surf.texture = tex("surface.png")
	surf.scale = Vector2.ONE / K
	surf.material = null
	still.material = null
	_changes()
	if not last_result.is_empty() and int(last_result.area) == a:
		var k := clampi(int(last_result.k), 0, _bands.size() - 1)
		var t0 := t + 0.7
		var v := _crew_v(k, t0)
		var ln := _loop(J.crews.get(str(int(_bands[k].d)), {}))
		t0 += (ceilf(v / ln) * ln - v) / CREW_FPS
		_hold[k] = t0
		_react = {k = k, won = bool(last_result.won), t0 = t0, iron = int(last_result.iron), ore = int(last_result.ore)}
		if focus_y < 0: focus_y = band_y(k) + float(J.band) * 0.5
		last_result = {}
	_setup_sea()
	_setup_smoke()
	_make_motes()
	_find_niches()
	still.queue_redraw()
	front.queue_redraw()

## what changed since the screen was last shown: new stages come in (ink, then colour), a newly opened level shows
## through the dust, the people of a level fade in after its second win
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
				_bursts.append([Vector2(180 + 250 * j, y + 330), t + wait + 0.2 + 0.12 * j])
		_reveal("band/d%d_%s.png" % [d, now], Vector2(0, y), delay, func(): _shown_bands[k] = now, "band/d%d_%s.png" % [d, was])
		if d == 9 and now == "done":
			_tremor_at = t + delay + 2.2      # the grotto is open: the sea breathes, the whole cliff shudders
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
			return Vector2(700, band_y(int(d) - 1) + 300)
	return Vector2(768, float(J.sky) + 900)

# ---------------------------------------------------------------- the still pictures

func _draw_still() -> void:
	var c := still
	for p in SPLACES:
		var s := int(_shown_places.get(p, 0))
		if s > 0:
			var at: Array = J.places[p]
			_put(c, "place/%s_%d.png" % [p, s], Vector2(float(at[0]), float(at[1])))
	_put(c, "sea.png", Vector2(0, _sea_top()))
	for b in _bands:
		var st := String(_shown_bands.get(int(b.k), b.state))
		_put(c, "band/d%d_%s.png" % [int(b.d), st], Vector2(0, float(b.y)))
	_draw_niches(c)
	for b in _bands:
		c.draw_texture_rect(_shade, Rect2(0, float(b.y), float(J.W), 44), false)
		c.draw_rect(Rect2(0, float(b.y) - 3, float(J.W), 6), Color(0.04, 0.045, 0.05))
	_draw_bedrock(c)
	_shaft_column(c)

## the shaft: one piece of timbered shaft repeated down the rock under the cave, from the section's top to the floor of
## the deepest open level (the closed ones below are solid rock)
func _shaft_column(c: CanvasItem) -> void:
	var sh: Dictionary = J.shaft
	var seg := _size("shaft.png")
	var x := float(sh.x)
	var y := float(sh.top)
	var bottom := band_y(open) + floor_of(open + 1) + 30.0
	var tx := tex("shaft.png")
	var y0 := y
	const FADE := 220.0      # its head comes out of the cliff's rock gradually, not cut off flat
	while y < bottom:
		var h := minf(seg.y, bottom - y)
		var off := 0.0
		while off < h:
			var sl := minf(h - off, 20.0 if y + off - y0 < FADE else h - off)
			var al := clampf((y + off - y0 + sl * 0.5) / FADE, 0.0, 1.0)
			c.draw_texture_rect_region(tx, Rect2(x, y + off, seg.x, sl), Rect2(0, off * K, seg.x * K, sl * K), Color(1, 1, 1, al * al))
			off += sl
		y += seg.y
	# its foot: a sump of black water
	c.draw_rect(Rect2(x + 10, bottom - 8, seg.x - 20, 14), Color(0.02, 0.04, 0.06, 0.9))

func _draw_shaft(_c: CanvasItem) -> void:
	pass

func _draw_cage(c: CanvasItem) -> void:
	if J.is_empty():
		return
	_man_engine(c)

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
		c.draw_texture_rect(_glow, Rect2(Vector2(at.x - sz.x * 0.6, at.y - 10), Vector2(sz.x * 1.2, 22)), false, Color(0.04, 0.06, 0.08, 0.6))
		for dv in [Vector2(-3, 0), Vector2(3, 0), Vector2(0, -3), Vector2(0, 3), Vector2(-2, -2), Vector2(2, 2), Vector2(-2, 2), Vector2(2, -2)]:
			c.draw_texture_rect(tx, Rect2(pos + dv, sz), false, Color(0.05, 0.06, 0.08, 1.0))
		c.draw_texture_rect(tx, Rect2(pos, sz), false, Color(1.0, 0.93, 0.84))

# ---------------------------------------------------------------- the sea and the smoke (nodes of their own)

func _setup_sea() -> void:
	var wv: Dictionary = J.waves
	_waves.texture = tex("waves.png")
	_waves.scale = Vector2.ONE / K
	_waves.position = Vector2(float(wv.at[0]), float(wv.at[1]))
	var m := _waves.material as ShaderMaterial
	m.set_shader_parameter("mode", 0)
	m.set_shader_parameter("amp", 3.0)
	var dp: Dictionary = J.deep
	_deep.texture = tex("deep.png")
	_deep.scale = Vector2.ONE / K
	_deep.position = Vector2(float(dp.at[0]), float(dp.at[1]))
	var dm := _deep.material as ShaderMaterial
	dm.set_shader_parameter("mode", 1)
	dm.set_shader_parameter("amp", 2.5)

func _setup_smoke() -> void:
	for ch in _sfx.get_children(): ch.queue_free()
	_smoke = []
	for s in J.smoke:
		var spec: Array = s           # x, y, size
		var p := CPUParticles2D.new()
		p.texture = tex("puff.png")
		p.amount = 30
		p.lifetime = 8.0
		p.preprocess = 8.0
		p.local_coords = true
		p.position = Vector2(float(spec[0]), float(spec[1]))
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = 10.0 * float(spec[2])
		p.direction = Vector2(-0.45, -1)        # the sea wind blows it inland, to the left
		p.spread = 12
		p.gravity = Vector2(-18, -5)
		p.initial_velocity_min = 24 * float(spec[2])
		p.initial_velocity_max = 40 * float(spec[2])
		p.angular_velocity_min = -12
		p.angular_velocity_max = 12
		p.scale_amount_min = 0.7 * float(spec[2])
		p.scale_amount_max = 1.1 * float(spec[2])
		var sc := Curve.new()
		sc.add_point(Vector2(0, 0.5))
		sc.add_point(Vector2(1, 3.4))
		p.scale_amount_curve = sc
		var g := Gradient.new()
		g.set_color(0, Color(1.0, 0.7, 0.45, 0.0))
		g.add_point(0.1, Color(0.85, 0.7, 0.6, 0.5))
		g.add_point(0.45, Color(0.38, 0.4, 0.44, 0.34))
		g.set_color(g.get_point_count() - 1, Color(0.22, 0.24, 0.28, 0.0))
		p.color_ramp = g
		_sfx.add_child(p)
		_smoke.append(p)
	_update_smoke()

func _update_smoke() -> void:
	for p in _smoke:
		(p as CPUParticles2D).emitting = int(_shown_places.get("tryworks", 0)) >= 2

# ---------------------------------------------------------------- the live layer

func _process(delta: float) -> void:
	super(delta)
	if not visible or J.is_empty():
		return
	front.queue_redraw()
	if Engine.get_process_frames() % 20 == 0:
		_update_smoke()
	# a big wave every 6-10 s: the spray bursts at the rocks and the foam brightens
	if t > _next_swell:
		_next_swell = t + _rng.randf_range(6.0, 10.0)
		_swell_at = t
		var sp: Array = J.spray
		var n := 2 + _rng.randi() % 2
		for i in n:
			var s: Array = sp[_rng.randi() % sp.size()]
			_spray.append([Vector2(float(s[0]), float(s[1])), t + i * 0.18, float(s[2])])
	var sw := clampf(1.0 - absf(t - _swell_at - 0.4) / 0.9, 0.0, 1.0)
	(_waves.material as ShaderMaterial).set_shader_parameter("swell", sw)
	var bm := _beam()
	var dm := _deep.material as ShaderMaterial
	# the beam lights the water while it points out to sea (to the left)
	dm.set_shader_parameter("beam", maxf(0.0, -bm.x) * float(int(_shown_places.get("lighthouse", 0)) >= 3))
	dm.set_shader_parameter("beam_x", 0.35)
	# the storm: now and then a bolt or a flicker of lightning (its flash lights the water too)
	if t > _next_storm and _storm.is_empty():
		_next_storm = t + _rng.randf_range(28.0, 50.0)
		_start_storm(["far", "far", "sheet", "near", "rod", "elmo"][_rng.randi() % 6])
	var fl := _storm_flash()
	var sk := String(_storm.get("kind", ""))
	dm.set_shader_parameter("flash", fl * (0.9 if sk == "near" else 0.4))
	(_waves.material as ShaderMaterial).set_shader_parameter("flash", fl * (1.0 if sk == "near" or sk == "rod" else 0.45))

## the lighthouse's lamp turns: seen from the side, its beam swings from pointing at us to the left (out to sea), back
## through us to the right; x: -1 left .. 1 right, y: how much it points at us (a flash at the lantern)
func _beam() -> Vector2:
	var a := t * TAU / 9.0
	return Vector2(sin(a), maxf(0.0, cos(a)))

func _draw_live() -> void:
	var c := live
	_lights(c)
	_surface_live(c)
	_sea_live(c)
	for b in _bands:
		if _band_seen(b): _band_live(c, b)
	_events_live(c)
	_storm_live(c)
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

func _lights(c: CanvasItem) -> void:
	for st in _stars:
		if float(st[1]) > float(J.sky) + 300:
			continue
		var v := 0.5 + 0.5 * sin(t * float(st[3]) + float(st[2]))
		if v > 0.6:
			c.draw_rect(Rect2(float(st[0]), float(st[1]), 3, 3), Color(0.8, 0.85, 1.0, v * 0.6))
	if J.has("moon"):
		var mo: Array = J.moon
		_light(c, Vector2(float(mo[0]), float(mo[1])), float(mo[2]) * 4.0, Color(0.75, 0.85, 1.0, 0.13 + 0.03 * sin(t * 0.5)))
	_maelstrom(c)
	var sl: Dictionary = J.surface_lamps
	var i := 0
	for place in sl:
		if place != "cave" and int(_shown_places.get(place, 0)) < 3:
			continue
		for l in sl[place]:
			i += 1
			var col := Color(1.0, 0.72, 0.35, 0.33)
			if l.size() > 3: col = Color(String(l[3]))
			col.a *= _flick(i)
			_light(c, Vector2(float(l[0]), float(l[1])), 70 * float(l[2]), col)
	for b in _bands:
		var k := int(b.k)
		if String(_shown_bands.get(k, b.state)) == "closed" or not _band_seen(b):
			continue
		for l in J.lamps.get(str(int(b.d)), []):
			_light(c, Vector2(float(l[0]), float(b.y) + float(l[1])), 150, Color(1.0, 0.7, 0.32, 0.26 * _flick(k * 3)))

## far out on the horizon the Maelstrom turns: a flat spiral of foam, slow, a cold glow breathing in its eye
func _maelstrom(c: CanvasItem) -> void:
	if not J.has("maelstrom"):
		return
	var ms: Array = J.maelstrom
	var at := Vector2(float(ms[0]), float(ms[1]))
	var r := float(ms[2])
	_light(c, at, r * 0.5, Color(0.35, 0.95, 1.0, 0.10 + 0.06 * sin(t * 0.6)))
	c.draw_set_transform(at, 0.0, Vector2(1.0, 0.22))
	for i in 6:
		var rr := r * (0.25 + 0.14 * i)
		var a0 := -t * (0.5 - i * 0.05) + i * 1.3
		c.draw_arc(Vector2.ZERO, rr, a0, a0 + PI * 1.2, 24, Color(0.75, 0.88, 0.95, 0.16 - i * 0.018), 5.0 - i * 0.5)
	c.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

## the station alive: the lighthouse's beam, the furnace glow of the tryworks, the chapel's bell now and then, the
## crane's hook going down to the landing and up, the spray of the big waves, the people and the animals
func _surface_live(c: CanvasItem) -> void:
	var sky := float(J.sky)
	if int(_shown_places.get("lighthouse", 0)) >= 3:
		_lighthouse(c)
	var tw: Dictionary = J.tryworks
	if int(_shown_places.get("tryworks", 0)) >= 2:
		var dr: Array = tw.door
		_light(c, Vector2(float(dr[0]), float(dr[1])), 120, Color(1.0, 0.5, 0.15, 0.4 * _flick(31)))
	if int(_shown_places.get("chapel", 0)) >= 3:
		_chapel(c)
	if int(_shown_places.get("crane", 0)) >= 3:
		_crane(c)
	_spray_live(c)
	for a in J.life:
		var spec: Dictionary = a
		if (spec.has("place") and int(_shown_places.get(String(spec.place), 0)) < 3) or not _crew_ok(String(spec.name)):
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
	# gulls crossing the sky now and then, wings beating
	var u2 := fmod(t + 5.0, 21.0)
	if u2 < 7.0 and _crew_ok("gullfly"):
		for g in 2:
			var gx := 1700.0 - u2 * 300.0 - g * 140.0
			var gy := sky + 260.0 + g * 50.0 + 30.0 * sin(t * 0.9 + g)
			var gf := "gullfly/%02d.png" % ((int(t * 10) + g * 3) % int(J.crew_n.gullfly))
			_put(c, gf, Vector2(gx, gy) - _size(gf) / 2)

## the beam: a long soft cone from the lantern that swings out to the left, shrinks as it turns towards us (the lantern
## flares), and swings out to the right; a faint pool of it on the clouds
func _lighthouse(c: CanvasItem) -> void:
	var lh: Dictionary = J.lighthouse
	var at := Vector2(float(lh.lantern[0]), float(lh.lantern[1]))
	var bm := _beam()
	var ln := float(lh.len) * absf(bm.x)
	var dirx := signf(bm.x)
	if ln > 20.0:
		var bs := _size("beam.png")
		var sc := Vector2(ln / bs.x, (0.75 + 0.25 * (1.0 - absf(bm.x))) * float(lh.width) / bs.y)
		c.draw_set_transform(at, 0.0 if dirx > 0 else PI, sc)
		# out to sea (left) it shines; swung inland (right) it is mostly behind the hill and the station
		var k := 1.0 if dirx < 0 else 0.3
		c.draw_texture_rect(tex("beam.png"), Rect2(Vector2(0, -bs.y / 2), bs), false, Color(1.0, 0.92, 0.7, 0.55 * k * (0.4 + 0.6 * absf(bm.x))))
		c.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	_light(c, at, 60 + 140 * bm.y, Color(1.0, 0.88, 0.6, 0.35 + 0.5 * bm.y))

## the chapel: its windows glow; every 31 s its bell strikes three times (rings of light from the belfry)
const CHAPEL_CYCLE := 31.0
func _chapel(c: CanvasItem) -> void:
	var ch: Dictionary = J.chapel
	for w in ch.windows:
		var r: Array = w
		_light(c, Vector2(float(r[0]), float(r[1])), float(r[2]), Color(1.0, 0.7, 0.35, 0.22 * _flick(50)))
	var bp := Vector2(float(ch.bell[0]), float(ch.bell[1]))
	var v := fmod(t + 12.0, CHAPEL_CYCLE)
	for k in 3:
		var r := v - k * 1.7
		if r >= 0.0 and r < 1.7:
			var q := r / 1.7
			c.draw_arc(bp, 10.0 + q * 80.0, 0, TAU, 40, Color(1.0, 0.85, 0.55, 0.32 * (1.0 - q)), 2.0)
		if _passed("bell%d" % k, v, CHAPEL_CYCLE, k * 1.7):
			SeaSounds.bell(amb, _far(bp.y))

## the steam crane: its hook goes down on the rope to the landing, waits, and comes up with a net of jet and shale
const CRANE_CYCLE := 18.0
func _crane(c: CanvasItem) -> void:
	var cr: Dictionary = J.crane
	var tip := Vector2(float(cr.tip[0]), float(cr.tip[1]))
	var low := float(cr.low)
	var u := fmod(t, CRANE_CYCLE)
	var q := 0.0
	if u < 5.0: q = 0.5 - 0.5 * cos(PI * u / 5.0)
	elif u < 8.0: q = 1.0
	elif u < 13.0: q = 0.5 + 0.5 * cos(PI * (u - 8.0) / 5.0)
	var sway := sin(t * 1.3) * 4.0 * q
	var hook := Vector2(tip.x + sway, lerpf(tip.y + 40.0, low, q))
	var full := u >= 7.0 and u < 15.0
	c.draw_line(tip, hook, Color(0.06, 0.05, 0.04), 4.0)
	c.draw_line(tip, hook, Color(0.5, 0.42, 0.3), 1.6)
	# the hook
	c.draw_arc(hook + Vector2(0, 14), 10.0, -0.3, PI + 0.6, 10, Color(0.06, 0.05, 0.04), 6.0)
	c.draw_arc(hook + Vector2(0, 14), 10.0, -0.3, PI + 0.6, 10, Color(0.42, 0.4, 0.38), 2.5)
	if full:
		# a sling net heavy with lumps
		var nb := hook + Vector2(0, 28)
		var pts := PackedVector2Array([nb + Vector2(-26, 6), nb + Vector2(26, 6), nb + Vector2(20, 40), nb + Vector2(0, 50), nb + Vector2(-20, 40)])
		c.draw_colored_polygon(pts, Color(0.06, 0.06, 0.07))
		for j in 5:
			c.draw_circle(nb + Vector2(-15 + j * 7.5, 22 + (j % 2) * 9), 8.0, [Color(0.12, 0.12, 0.14), Color(0.3, 0.32, 0.36)][j % 2])
		c.draw_circle(nb + Vector2(-6, 18), 3.0, Color(0.7, 0.8, 0.95, 0.8))
		c.draw_line(hook + Vector2(0, 20), nb + Vector2(-24, 8), Color(0.45, 0.36, 0.24), 2.0)
		c.draw_line(hook + Vector2(0, 20), nb + Vector2(24, 8), Color(0.45, 0.36, 0.24), 2.0)
	if _passed("crane_dn", t, CRANE_CYCLE) or _passed("crane_up", t, CRANE_CYCLE, 8.0):
		amb.shot("winch_%d" % (randi() % 2), _far(tip.y) - 4.0, 0.9)

## the spray of the big waves breaking on the rocks: soft white puffs of foam thrown up and drifting off with the wind,
## and a scatter of drops falling back
func _spray_live(c: CanvasItem) -> void:
	var ps := _size("puff.png")
	for s in _spray.duplicate():
		var age := t - float(s[1])
		if age < 0.0:
			continue
		if age > 2.2:
			_spray.erase(s)
			continue
		var at: Vector2 = s[0]
		var k := float(s[2])
		if _passed("spray%d" % int(float(s[1]) * 10.0), age, 100.0):
			SeaSounds.crash(amb, _far(at.y))
		var up := 1.0 - exp(-age * 3.2)
		for j in 9:
			var dx := (j - 4) * 16.0 * k + sin(j * 2.7) * 10.0
			var p := at + Vector2(dx + age * 30.0 * (j - 4) / 4.0 - age * 24.0, -up * (90.0 + 50.0 * sin(j * 1.9 + 1.0)) * k)
			var sc := (0.32 + 0.6 * age) * k * (0.8 + 0.3 * sin(j * 3.1))
			var al := 0.4 * clampf(age / 0.12, 0.0, 1.0) * clampf(1.0 - age / 2.2, 0.0, 1.0)
			c.draw_texture_rect(tex("puff.png"), Rect2(p - ps * sc / 2, ps * sc), false, Color(0.92, 0.97, 1.0, al))
		for j in 16:
			var a := -PI / 2 + (j - 7.5) * 0.11
			var v := (230.0 + 90.0 * sin(j * 3.3)) * k
			var p := at + Vector2(cos(a) * v * age, sin(a) * v * age + 420.0 * age * age)
			var al := 0.85 * clampf(1.0 - age / 1.4, 0.0, 1.0)
			if al > 0.0:
				c.draw_circle(p, 2.5 + (j % 3), Color(0.9, 0.96, 1.0, al))

## the sea in section: herring shoals turning in the water, bubbles rising off the kelp and the wreck, the diver on
## the sea bed (once the crane can feed his air hose) with his hose up to the surface and his bubbles
func _sea_live(c: CanvasItem) -> void:
	var se: Dictionary = J.sea_life
	var y0 := _sea_top()
	if y0 - SEEN_PAD > _seen.y or y0 + float(J.sea) + SEEN_PAD < _seen.x:
		return
	# two shoals swimming slow loops across the water
	if _crew_ok("fish"):
		var fn := int(J.crew_n.fish)
		for sh in (se.shoals as Array).size():
			var sd: Array = se.shoals[sh]
			var per := float(sd[3])
			var u := fmod(t + sh * 11.0, per) / per
			var dirx := -1.0 if u < 0.5 else 1.0
			var cx := lerpf(float(sd[0]), float(sd[1]), 0.5 - 0.5 * cos(TAU * u))
			var cy := y0 + float(sd[2]) + 30.0 * sin(TAU * u * 2.0 + sh)
			for f in 9:
				var off := Vector2(sin(f * 2.7 + sh) * 70.0 + cos(t * 0.8 + f) * 8.0, cos(f * 1.9) * 34.0 + sin(t * 1.1 + f * 0.7) * 6.0)
				var fr := "fish/%02d.png" % ((int(t * 12) + f * 3) % fn)
				var fs := _size(fr) * (0.8 + 0.25 * sin(f * 1.3))
				var p := Vector2(cx, cy) + off
				if dirx > 0:
					c.draw_set_transform(p + Vector2(fs.x / 2, -fs.y / 2), 0, Vector2(-1, 1))
					c.draw_texture_rect(tex(fr), Rect2(Vector2.ZERO, fs), false, Color(0.75, 0.85, 0.95, 0.85))
					c.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
				else:
					c.draw_texture_rect(tex(fr), Rect2(p - fs / 2, fs), false, Color(0.75, 0.85, 0.95, 0.85))
	# bubbles from the sea bed
	for b in (se.bubbles as Array):
		var bp: Array = b
		for j in 6:
			var u := fmod(t * 0.22 + j / 6.0 + float(bp[0]) * 0.001, 1.0)
			var top := float(bp[2])
			var p := Vector2(float(bp[0]) + sin(u * 9.0 + j) * 8.0, y0 + float(bp[1]) - u * top)
			c.draw_arc(p, 3.0 + j % 3, 0, TAU, 10, Color(0.7, 0.9, 1.0, 0.5 * (1.0 - u)), 1.5)
	# the diver on the wreck; his air hose goes on from where it leaves his drawing, up through the water and out to
	# the pump on the landing, swaying with the sea
	if int(_shown_places.get("crane", 0)) >= 3 and _crew_ok("diver24"):
		var dv: Array = se.diver
		var dp := Vector2(float(dv[0]), y0 + float(dv[1]))
		var fi := int(t * 7) % int(J.crew_n.diver24)
		var fr := "diver24/%02d.png" % fi
		var ds := _size(fr)
		var topl := dp - Vector2(ds.x / 2, ds.y)
		var hs: Array = se.get("hose", [])
		var start := topl + Vector2(ds.x * (float(hs[fi]) if fi < hs.size() else 0.32), 1.0)
		var pump := Vector2(float(se.pump[0]), y0 + float(se.pump[1]))
		var ctrl := Vector2(start.x - 30.0, y0 + float(se.surface) + 120.0)
		var hose := PackedVector2Array()
		for j in 25:
			var q := j / 24.0
			var p := start.lerp(ctrl, q).lerp(ctrl.lerp(pump, q), q)
			# it sways under water, hangs straighter above it
			var under := clampf((p.y - (y0 + float(se.surface))) / 300.0, 0.0, 1.0)
			p.x += sin(q * 6.0 + t * 0.7) * 22.0 * sin(PI * q) * under
			hose.append(p)
		c.draw_polyline(hose, Color(0.05, 0.05, 0.05, 0.92), 6.0)
		c.draw_polyline(hose, Color(0.4, 0.31, 0.22, 0.92), 2.8)
		c.draw_texture_rect(tex(fr), Rect2(topl, ds), false, Color(0.72, 0.85, 0.92))
		var head := topl + Vector2(ds.x * 0.42, ds.y * 0.12)
		for j in 5:
			var u := fmod(t * 0.4 + j / 5.0, 1.0)
			var p := head + Vector2(sin(u * 7.0 + j) * 6.0, -u * (head.y - (y0 + float(se.surface))))
			c.draw_arc(p, 4.0 + 2.0 * u, 0, TAU, 10, Color(0.75, 0.92, 1.0, 0.55 * (1.0 - u)), 1.8)

## the man engine: a long timber rod down the shaft, rocked up and down by the engine house above (once it works); a
## step on it every few yards, and here and there a miner riding it, stepping off at the fixed landings
const ME_PERIOD := 5.0
func _man_engine(c: CanvasItem) -> void:
	var on := int(_shown_places.get("tryworks", 0)) >= 3
	var sh: Dictionary = J.shaft
	var me: Dictionary = J.man_engine
	var x := float(me.x)
	var top := float(sh.top) + 140.0     # under the shaft's head, where it has come out of the rock
	var bottom := band_y(open) + floor_of(open + 1)
	if bottom < _seen.x - SEEN_PAD or top > _seen.y + SEEN_PAD:
		return
	var stroke := float(me.stroke)
	var u := fmod(t, ME_PERIOD) / ME_PERIOD
	var dy := 0.0
	if on:
		# up 40%, hold 10%, down 40%, hold 10%
		if u < 0.4: dy = -stroke * (0.5 - 0.5 * cos(PI * u / 0.4))
		elif u < 0.5: dy = -stroke
		elif u < 0.9: dy = -stroke * (0.5 + 0.5 * cos(PI * (u - 0.5) / 0.4))
	var wood := Color(0.36, 0.25, 0.15)
	var ink := Color(0.05, 0.04, 0.03)
	c.draw_line(Vector2(x, top - 10 + dy), Vector2(x, bottom + dy), ink, 30.0)
	c.draw_line(Vector2(x, top - 10 + dy), Vector2(x, bottom + dy), wood, 20.0)
	c.draw_line(Vector2(x - 5, top - 10 + dy), Vector2(x - 5, bottom + dy), Color(0.6, 0.44, 0.27), 5.0)
	var gap := float(me.gap)
	var y := top + gap * 0.5
	var i := 0
	while y < bottom - 20:
		var sy := y + dy
		if sy > _seen.x - 200 and sy < _seen.y + 200:
			# an iron strap and a step on the rod, a fixed landing on the shaft wall beside it
			c.draw_rect(Rect2(x - 16, sy - 12, 32, 9), Color(0.13, 0.13, 0.15))
			c.draw_rect(Rect2(x - 16, sy - 12, 32, 3), Color(0.45, 0.45, 0.48))
			c.draw_rect(Rect2(x + 8, sy - 2, 58, 14), ink)
			c.draw_rect(Rect2(x + 11, sy + 1, 52, 8), wood)
			c.draw_rect(Rect2(x - 72, y + 30, 58, 14), ink)
			c.draw_rect(Rect2(x - 69, y + 33, 52, 8), wood.darkened(0.2))
			# riders: one on every third step; on the way up the rod carries him
			if on and i % 3 == 1 and _crew_ok("riders"):
				var rf := "riders/%02d.png" % (i / 3 % int(J.crew_n.riders))
				var rs := _size(rf)
				# he faces the rod, his hand on its handle, standing on its step
				_put(c, rf, Vector2(x + 8, sy - rs.y + 3))
				_light(c, Vector2(x + rs.x * 0.45, sy - rs.y + 8), 34, Color(1.0, 0.75, 0.4, 0.45))
		y += gap
		i += 1
	if on and _passed("me_top", t, ME_PERIOD, ME_PERIOD * 0.4):
		amb.shot("copper/creak_%d" % (randi() % 3), -20.0 + _far((top + bottom) / 2), 0.7)

func _band_live(c: CanvasItem, b: Dictionary) -> void:
	var k := int(b.k)
	var y := float(b.y)
	var st := String(_shown_bands.get(k, b.state))
	if st == "closed":
		return
	var d := int(b.d)
	var floor_y := y + floor_of(d)
	# sea water dripping from the wet patches of the roof into the puddles drawn under them
	for dr in J.drips.get(str(d), []):
		var dd: Array = dr
		var per := 1.3 + fmod(float(dd[0]) * 0.013, 0.9)
		var u := fmod(t + float(dd[0]) * 0.07, per) / per
		var fall := float(dd[2]) - float(dd[1])
		if u < 0.55:
			var q := u / 0.55
			var p := Vector2(float(dd[0]), y + float(dd[1]) + fall * q * q)
			c.draw_line(p - Vector2(0, 6 + 10 * q), p, Color(0.6, 0.8, 0.9, 0.55), 2.5)
			c.draw_circle(p, 2.6, Color(0.75, 0.9, 1.0, 0.85))
		elif u < 0.8:
			var q := (u - 0.55) / 0.25
			var p := Vector2(float(dd[0]), y + float(dd[2]))
			c.draw_arc(p, 4.0 + 16.0 * q, PI, TAU, 10, Color(0.75, 0.9, 1.0, 0.6 * (1.0 - q)), 1.6)
	# the sea pouring through the roof where the bulkhead is not yet built: streaks running down the drawn stream, a splash
	if J.has("pours") and J.pours.has(str(d)) and st in ["clear", "step1"]:
		var pr: Array = J.pours[str(d)]
		var px := float(pr[0])
		var top := y + float(pr[1])
		var bot := y + float(pr[2])
		var wd := float(pr[3]) * (1.0 if st == "clear" else 0.6)
		for j in 9:
			var xx := px + (j - 4) * wd / 9.0
			var u := fmod(t * 1.6 + j * 0.37, 1.0)
			var l := 40.0 + 30.0 * sin(j * 1.3)
			var yy := lerpf(top, bot - l, u)
			c.draw_line(Vector2(xx, yy), Vector2(xx, yy + l), Color(0.85, 0.95, 1.0, 0.35), 3.0)
		for j in 7:
			var u := fmod(t * 1.3 + j / 7.0, 1.0)
			var a := PI + PI * (j + 0.5) / 7.0
			_light(c, Vector2(px, bot) + Vector2.from_angle(a) * (10.0 + 50.0 * u), 10, Color(0.85, 0.95, 1.0, 0.45 * (1.0 - u)))
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
	_put(c, p, Vector2(x - sz.x / 2, floor_y - sz.y + 4 + float(cr.get("dy", 0.0))), flip, al)
	if cr.has("lamp"):
		var lp: Array = cr.lamp
		_light(c, Vector2(x + float(lp[0]) * (-1.0 if flip else 1.0), floor_y + float(lp[1])), 60, Color(1.0, 0.75, 0.4, 0.45 * al * _flick(k)))

# ---------------------------------------------------------------- the Kraken about the place

func _tick_events() -> void:
	if force_event in STORMS and t > 0.5:
		_start_storm(force_event.trim_prefix("bolt_"))
		force_event = ""
	if force_event != "" and t > 0.5:
		_events[force_event] = t
		if force_event == "ink":
			_ink.append([_ink_at(), t])
		if force_event == "tip" and not (J.cracks as Array).is_empty():
			_events["tip_at"] = J.cracks[0]
		force_event = ""
	if t < _next_event:
		return
	_next_event = t + _rng.randf_range(10.0, 16.0)
	var pool := ["ink", "bubbles"]
	for cr in J.cracks:
		var k := int(cr.d) - 1
		if k <= open and String(_shown_bands.get(k, "closed")) != "closed":
			pool.append("tip")
			break
	if int(_shown_places.get("landing", 0)) >= 3:
		pool.append("compass")
	if open >= 6 and String(_shown_bands.get(6, "closed")) != "closed":
		pool.append("frost")      # the herald of the next mine, the frozen one: nobody here knows what it means
	var ev: String = pool[_rng.randi() % pool.size()]
	_events[ev] = t
	if ev == "ink":
		_ink.append([_ink_at(), t])
	if ev == "tip":
		var cand: Array = []
		for cr in J.cracks:
			if int(cr.d) - 1 <= open and String(_shown_bands.get(int(cr.d) - 1, "closed")) != "closed":
				cand.append(cr)
		_events["tip_at"] = cand[_rng.randi() % cand.size()]
		SeaSounds.squelch(amb, _far(band_y(int(_events.tip_at.d) - 1) + 300))


func _ink_at() -> Vector2:
	var se: Dictionary = J.sea_life
	var tn: Array = se.tentacle
	return Vector2(float(tn[0]) + 120.0, _sea_top() + float(tn[1]) - 260.0)

func _events_live(c: CanvasItem) -> void:
	for ev in _events.keys():
		if ev == "tip_at":
			continue
		var s := t - float(_events[ev])
		var done := false
		match ev:
			"ink":
				if s > 9.0: done = true
			"bubbles":
				# a great gout of bubbles from the deep, as if something below breathed out
				var tn: Array = J.sea_life.tentacle
				if s > 5.0: done = true
				else:
					for j in 26:
						var u := s / 5.0 + j * 0.031
						if u > 1.0: continue
						var p := Vector2(float(tn[0]) + sin(j * 2.3) * 60.0 + sin(u * 8.0 + j) * 10.0, _sea_top() + float(tn[1]) - 40.0 - u * float(J.sea_life.rise))
						c.draw_arc(p, 4.0 + (j % 4) * 2.5, 0, TAU, 12, Color(0.75, 0.95, 1.0, 0.6 * (1.0 - u)), 2.0)
			"tip":
				# a thin tentacle tip feels its way out of a wet crack in the gallery wall and slips back
				var cr: Dictionary = _events.get("tip_at", {})
				if cr.is_empty() or s > 3.2 or not _crew_ok("tip"): done = true
				else:
					var n := int(J.crew_n.tip)
					var fr := "tip/%02d.png" % mini(int(s / 3.2 * n), n - 1)
					var ts := _size(fr) * float(cr.get("s", 1.0))
					var at := Vector2(float(cr.at[0]), band_y(int(cr.d) - 1) + float(cr.at[1]))
					var flip := bool(cr.get("flip", false))
					c.draw_set_transform(at, 0.0, Vector2(-1 if flip else 1, 1))
					c.draw_texture_rect(tex(fr), Rect2(Vector2(0, -ts.y / 2), ts), false)
					c.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
			"frost":
				# a breath of frost on the wet wall of 350 m: white ferns grow out from a point, glitter, and melt to drops
				if s > 5.5: done = true
				else:
					_frost(c, Vector2(860, band_y(6) + 200), s)
			"compass":
				# the old whaler's compass needle swings round and round, a cold glint in its glass
				if s > 4.0: done = true
				else:
					for e in J.life:
						if String(e.name) == "guide24":
							var gp := Vector2(float(e.x) + 22.0, float(J.sky) + float(e.y) - 52.0)
							_light(c, gp, 26, Color(0.4, 1.0, 1.0, 0.6 * sin(PI * s / 4.0)))
							var na := t * 9.0
							c.draw_line(gp - Vector2.from_angle(na) * 6.0, gp + Vector2.from_angle(na) * 6.0, Color(0.9, 1.0, 1.0, 0.9), 2.0)
		if done:
			_events.erase(ev)
	# the ink: dark clouds blooming in the water, drifting and thinning
	for ik in _ink.duplicate():
		var s := t - float(ik[1])
		if s > 9.0:
			_ink.erase(ik)
			continue
		var at: Vector2 = ik[0]
		var grow := 1.0 - exp(-s * 0.9)
		var fade := clampf((9.0 - s) / 4.0, 0.0, 1.0)
		for j in 12:
			var a := j * 2.4
			var p := at + Vector2(cos(a), sin(a) * 0.6) * (40.0 + 150.0 * grow * (0.5 + 0.5 * sin(j * 1.7))) + Vector2(s * 12.0, -s * 6.0)
			_light(c, p, 70.0 + 110.0 * grow, Color(0.02, 0.01, 0.04, 0.55 * fade))

var _frost_pts: Array = []    # the frost's branches (made once): [from, to, the share of growth at which it starts]

func _frost(c: CanvasItem, at: Vector2, s: float) -> void:
	if _frost_pts.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		var tips: Array = []
		for k in 7:
			tips.append([Vector2.ZERO, rng.randf_range(0, TAU), 0.0, 0])
		while not tips.is_empty():
			var tp: Array = tips.pop_back()
			var p: Vector2 = tp[0]
			var a: float = tp[1]
			var g: float = tp[2]
			var depth: int = tp[3]
			var ln := rng.randf_range(16, 30) * (1.0 - depth * 0.18)
			var q := p + Vector2.from_angle(a) * ln
			_frost_pts.append([p, q, g])
			if depth < 4:
				tips.append([q, a + rng.randf_range(-0.25, 0.25), g + 0.17, depth + 1])
				if rng.randf() < 0.7:
					tips.append([q, a + (0.8 if rng.randf() < 0.5 else -0.8), g + 0.2, depth + 1])
	var grow := clampf(s / 2.0, 0.0, 1.0)
	var melt := clampf((s - 3.5) / 2.0, 0.0, 1.0)
	for f in _frost_pts:
		var g := clampf((grow - float(f[2])) / 0.17, 0.0, 1.0)
		if g <= 0.0:
			continue
		var a: Vector2 = at + f[0]
		var b: Vector2 = a.lerp(at + f[1], g)
		c.draw_line(a, b, Color(0.85, 0.95, 1.0, 0.85 * (1.0 - melt)), 2.5)
	_light(c, at, 70, Color(0.7, 0.9, 1.0, 0.3 * grow * (1.0 - melt)))
	if melt > 0.0:
		for j in 6:
			var p: Vector2 = at + Vector2(-50 + j * 20, 20 + melt * 90.0 * (0.6 + 0.4 * sin(j * 2.0)))
			c.draw_circle(p, 3.0, Color(0.75, 0.9, 1.0, 0.7 * (1.0 - melt)))

# ---------------------------------------------------------------- the storm

## test keys / the admin's buttons for each kind of lightning
const STORMS := ["bolt_far", "bolt_near", "sheet", "bolt_rod", "elmo"]
## each kind: how long it plays and its flashes [when, how bright]
const STORM := {
	"far": {len = 4.0, pulses = [[0.12, 0.55], [0.3, 0.35], [0.62, 0.3]]},
	"near": {len = 4.5, pulses = [[0.08, 1.0], [0.2, 0.55], [0.42, 0.95], [0.78, 0.45]]},
	"sheet": {len = 3.2, pulses = []},
	"rod": {len = 6.5, pulses = [[0.08, 0.95], [0.26, 0.5], [0.5, 0.85]]},
	"elmo": {len = 5.5, pulses = []},
}
const THUNDER_DELAY := {"far": 1.6, "near": 0.05, "rod": 0.05, "sheet": 0.9, "elmo": 1e9}

## a storm begins: its bolts are made once (from the clouds to where they strike, jagged, with branches)
func _start_storm(kind: String) -> void:
	var sd: Dictionary = J.storm
	var seed_ := _rng.randi()
	var bolts: Array = []
	var pulses: Array = (STORM[kind].pulses as Array).duplicate()
	match kind:
		"far":
			# far off over the sea: a bolt crawling from cloud to cloud in the sky left of the lighthouse, forking
			var rod := Vector2(float(sd.rod[0]), float(sd.rod[1]))
			var a := Vector2(_rng.randf_range(-20, 60), rod.y - _rng.randf_range(40, 120))
			var b := Vector2(rod.x - _rng.randf_range(120, 230), rod.y + _rng.randf_range(170, 280))
			bolts = _make_bolt(a, b, seed_, 1.3)
		"near":
			var at := Vector2(float(sd.near[0]), float(sd.near[1]))
			bolts = _make_bolt(Vector2(at.x + _rng.randf_range(220, 380), at.y - 1300), at, seed_, 1.0)
			_spray.append([at, t + 0.1, 1.7])
			_spray.append([at + Vector2(60, 10), t + 0.25, 1.2])
		"rod":
			var at := Vector2(float(sd.rod[0]), float(sd.rod[1]))
			# out of the cloud over the sea at the upper left, slanting into the lighthouse's rod
			bolts = _make_bolt(Vector2(at.x - _rng.randf_range(260, 460), at.y - _rng.randf_range(240, 340)), at, seed_, 0.9)
		"sheet":
			# flickers inside the clouds here and there, no bolt to be seen
			for i in 5:
				pulses.append([0.15 + i * 0.45 + _rng.randf_range(-0.1, 0.1), _rng.randf_range(0.3, 0.7)])
	_storm = {kind = kind, t0 = t, bolts = bolts, pulses = pulses, seed = seed_, played = {}}

## the brightness of the flash now (0..1): each pulse flares and dies in a few hundredths of a second
func _storm_flash() -> float:
	if _storm.is_empty():
		return 0.0
	var s := t - float(_storm.t0)
	var f := 0.0
	for p in _storm.pulses:
		var d := s - float(p[0])
		if d >= 0.0:
			f += float(p[1]) * exp(-d / 0.075)
	return clampf(f, 0.0, 1.0)

## a bolt from a to b: the main channel by midpoint displacement, then side branches forking off it downwards
func _make_bolt(a: Vector2, b: Vector2, seed_: int, k: float) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var main := _jag(a, b, rng, 0.2 * k)
	var out: Array = [main]
	for i in 3 + rng.randi() % 3:
		var j := rng.randi_range(int(main.size() * 0.15), int(main.size() * 0.7))
		var p := main[j]
		var dir := (b - a).normalized().rotated(rng.randf_range(0.35, 0.9) * (1.0 if rng.randf() < 0.5 else -1.0))
		var ln := (b - a).length() * rng.randf_range(0.15, 0.35)
		out.append(_jag(p, p + dir * ln, rng, 0.25))
	return out

func _jag(a: Vector2, b: Vector2, rng: RandomNumberGenerator, rough: float) -> PackedVector2Array:
	var pts: Array = [a, b]
	var off := (b - a).length() * rough
	for level in 6:
		var nx: Array = []
		for i in pts.size() - 1:
			var p: Vector2 = pts[i]
			var q: Vector2 = pts[i + 1]
			var m := (p + q) * 0.5 + (q - p).orthogonal().normalized() * rng.randf_range(-off, off)
			nx.append(p)
			nx.append(m)
		nx.append(pts[pts.size() - 1])
		pts = nx
		off *= 0.52
	return PackedVector2Array(pts)

func _storm_live(c: CanvasItem) -> void:
	if _storm.is_empty():
		return
	var kind := String(_storm.kind)
	var s := t - float(_storm.t0)
	var len_ := float(STORM[kind].len)
	if s > len_:
		_storm = {}
		return
	var f := _storm_flash()
	var sd: Dictionary = J.storm
	var sky := float(J.sky)
	var bolts: Array = _storm.bolts
	# the clouds lit from inside: big cold patches over the sky, the whole station washed pale by a near strike
	if f > 0.01:
		var rng := RandomNumberGenerator.new()
		rng.seed = int(_storm.seed) + int(s * 6.0)
		if kind == "near" or kind == "rod":
			# the station washed pale, the wash thinning out down the cliff (no edge across the waves)
			var bot := sky + float(J.surf) - 500.0
			c.draw_rect(Rect2(0, 0, float(J.W), bot), Color(0.72, 0.8, 1.0, 0.3 * f))
			for k in 10:
				c.draw_rect(Rect2(0, bot + k * 70.0, float(J.W), 70.0), Color(0.72, 0.8, 1.0, 0.3 * f * (1.0 - (k + 1) / 11.0)))
		if kind == "sheet" or kind == "far":
			# the clouds flicker as a whole, brightest high up
			var top := sky + 560.0
			for k in 8:
				c.draw_rect(Rect2(0, k * top / 8.0, float(J.W), top / 8.0), Color(0.6, 0.68, 1.0, (0.2 if kind == "sheet" else 0.1) * f * (1.0 - k / 9.0)))
		var bx := 600.0
		if not bolts.is_empty():
			var b0: PackedVector2Array = bolts[0]
			bx = b0[0].x
		for i in 4:
			var cx := rng.randf_range(0, float(J.W)) if kind == "sheet" else bx + rng.randf_range(-300, 300)
			var ka := 0.62 if kind == "sheet" else 0.42
			_light(c, Vector2(cx, rng.randf_range(sky - 100.0, sky + 520.0)), rng.randf_range(260, 520), Color(0.62, 0.7, 1.0, ka * f))
	# the bolt itself: grown down in a tenth of a second, bright while it flashes, then a fading violet trace
	var grow := clampf(s / 0.1, 0.0, 1.0)
	var trace := clampf(1.0 - (s - 0.85) / 0.5, 0.0, 1.0)
	for bi in bolts.size():
		var pts: PackedVector2Array = bolts[bi]
		var n := int(pts.size() * (grow if bi == 0 else clampf(s / 0.1 - 0.3, 0.0, 1.0)))
		if n < 2:
			continue
		var line := pts.slice(0, n)
		var w := 1.0 if bi == 0 else 0.55
		var on := maxf(f, 0.12 * trace)
		if on < 0.02:
			continue
		c.draw_polyline(line, Color(0.45, 0.5, 1.0, 0.2 * on), 44.0 * w)
		c.draw_polyline(line, Color(0.7, 0.8, 1.0, 0.55 * on), 18.0 * w)
		c.draw_polyline(line, Color(1.0, 1.0, 1.0, minf(1.0, on * 1.6)), 7.0 * w)
	if kind == "near":
		var at := Vector2(float(sd.near[0]), float(sd.near[1]))
		_light(c, at, 220, Color(0.75, 0.9, 1.0, 0.7 * f))
		# in the flash, for an instant, something vast shows under the water
		var tn: Array = J.sea_life.tentacle
		if f > 0.2 and _crew_ok("tentacle"):
			var fr := "tentacle/05.png"
			var ts := _size(fr) * 0.75
			var base := Vector2(float(tn[0]) + 380.0, _sea_top() + float(tn[1]) + 40.0)
			c.draw_texture_rect(tex(fr), Rect2(base - Vector2(ts.x / 2, ts.y), ts), false, Color(0.02, 0.03, 0.06, 0.55 * f))
	if kind == "rod":
		var at := Vector2(float(sd.rod[0]), float(sd.rod[1]))
		_light(c, at, 160, Color(0.8, 0.88, 1.0, 0.8 * f))
		# sparks run down the lighthouse's conductor and spill off the gallery rail
		for j in 10:
			var u := (s - 0.1 - j * 0.04) / 0.7
			if u < 0.0 or u > 1.0:
				continue
			var p := at + Vector2(sin(j * 2.3) * 6.0 + (j % 3 - 1) * 20.0 * u, u * 150.0 + 60.0 * u * u * (j % 2))
			c.draw_circle(p, 3.5 * (1.0 - u) + 1.0, Color(0.85, 0.92, 1.0, 1.0 - u))
	# St. Elmo's fire: blue-violet tongues on the tall points of the station after a strike on the rod, or alone in the
	# charged air before a storm
	if kind == "rod" or kind == "elmo":
		var e0 := 0.6 if kind == "rod" else 0.0
		var ek := clampf((s - e0) / 0.6, 0.0, 1.0) * clampf((len_ - s) / 1.0, 0.0, 1.0)
		if ek > 0.0:
			var i := 0
			for e in sd.elmo:
				var p := Vector2(float(e[0]), float(e[1]))
				var fl := ek * (0.6 + 0.4 * sin(t * 23.0 + i * 1.9) * sin(t * 7.0 + i))
				_light(c, p, 90, Color(0.5, 0.55, 1.0, 0.5 * fl))
				_light(c, p, 34, Color(0.8, 0.85, 1.0, 0.7 * fl))
				for j in 5:
					var hgt := 26.0 + 22.0 * absf(sin(t * 17.0 + j * 2.1 + i))
					var tip := p + Vector2(sin(t * 29.0 + j * 1.7 + i) * 9.0 + (j - 2) * 7.0, -hgt)
					var mid := p.lerp(tip, 0.5) + Vector2(sin(t * 41.0 + j) * 6.0, 0)
					c.draw_polyline(PackedVector2Array([p, mid, tip]), Color(0.55, 0.62, 1.0, 0.7 * fl), 6.0)
					c.draw_polyline(PackedVector2Array([p, mid, tip]), Color(0.92, 0.95, 1.0, 0.9 * fl), 2.4)
				i += 1
		if s >= e0 and not _storm.played.has("elmo"):
			_storm.played["elmo"] = true
			amb.shot("sea/elmo", -14.0 + _far(float(sd.rod[1])), randf_range(0.95, 1.05))
	# thunder: at once for a near strike, after the light's lead for a far one, a low roll for the sheet lightning
	if not _storm.played.has("thunder") and s >= float(THUNDER_DELAY[kind]):
		_storm.played["thunder"] = true
		var near := kind == "near" or kind == "rod"
		var snd := ("sea/thunder_near_%d" % (randi() % 2)) if near else ("sea/thunder_far_%d" % (randi() % 3))
		amb.shot(snd, maxf(-10.0, _far(sky + 400.0)) - (2.0 if near else 8.0), randf_range(0.92, 1.05))

## after a win the level's ore flies down into the depth it came from: lumps of jet (black, glassy) and of iron
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
	var w: Array = cr.get("work", ["", 600, ""])
	var to := Vector2(float(w[1]) if w.size() > 1 else 600.0, band_y(k) + floor_of(k + 1) - 40)
	var from := Vector2(1240, -position.y / scale.y + 40)
	var n_ore := mini(int(_react.ore), 10)
	var n_iron := mini(int(_react.iron), 8)
	for i in n_ore + n_iron:
		var u := (s - 0.4 - i * 0.09) / 0.9
		if u < 0.0 or u > 1.4:
			continue
		var iron := i >= n_ore
		var tgt := to + Vector2((i % 5 - 2) * 34 + sin(i * 2.3) * 10, (i % 3) * 8)
		var glow := Color(0.75, 0.85, 1.0) if iron else Color(0.5, 0.88, 1.0)
		if u <= 1.0:
			var e := u * u * (3.0 - 2.0 * u)
			var p := from.lerp(tgt, e) + Vector2(sin(i * 1.7) * 160 * sin(PI * u), -220 * sin(PI * u))
			c.draw_circle(p, 22.0, Color(glow, 0.22))
			_jet(c, p, 30.0, iron, i, t * (3.0 + (i % 3)))
		else:
			var f := (u - 1.0) / 0.4
			_light(c, tgt, 60 + 70 * f, Color(glow, 0.6 * (1.0 - f)))
			_jet(c, tgt + Vector2(0, -8), 30.0 * (1.0 - smoothstep(0.5, 1.0, f)), iron, i, 0.0)
		if _passed("ore%d" % i, u, 1.0, 1.0):
			amb.shot("coin", -10.0, 1.2 + (i % 4) * 0.05)

## a lump of jet: black glass with a sharp cold highlight, or a grey lump of iron ore with a dark cube
func _jet(c: CanvasItem, at: Vector2, r: float, iron: bool, seed_: int, spin: float) -> void:
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
	c.draw_colored_polygon(pts, Color(0.33, 0.34, 0.37) if iron else Color(0.07, 0.07, 0.09))
	if iron:
		c.draw_rect(Rect2(at + Vector2(0.0, -0.1) * r, Vector2(r, r) * 0.42), Color(0.16, 0.17, 0.2))
	else:
		c.draw_line(at + Vector2(-0.45, -0.3) * r, at + Vector2(0.1, -0.55) * r, Color(0.75, 0.88, 1.0, 0.9), 3.0)
		c.draw_circle(at + Vector2(-0.3, -0.4) * r, r * 0.12, Color(0.9, 0.95, 1.0))

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
		SeaSounds.deep(amb, -2.0)

## the grotto open: its black water breathes cyan from below, and the great eye in it opens and closes slowly
func _finale(c: CanvasItem) -> void:
	if String(_shown_bands.get(8, "")) != "done" or not J.has("hall"):
		return
	var y := band_y(8)
	var hl: Dictionary = J.hall
	var sh := clampf(1.0 - (t - _tremor_at) / 2.0, 0.0, 1.0)
	var g := 0.5 + 0.35 * sin(t * 0.9) + 0.5 * sh
	var wa: Array = hl.water
	_light(c, Vector2(float(wa[0]), y + float(wa[1])), float(wa[2]), Color(0.3, 0.9, 1.0, 0.22 * g))
	var ey: Array = hl.eye
	var open_ := clampf(0.5 + 0.5 * sin(t * 0.35), 0.0, 1.0) + sh
	_light(c, Vector2(float(ey[0]), y + float(ey[1])), 70, Color(0.7, 1.0, 0.9, 0.35 * open_))
	for i in 8:
		var u := fmod(t * 0.12 + i / 8.0, 1.0)
		var p := Vector2(float(wa[0]) + sin(i * 2.1 + t * 0.3) * float(wa[2]) * 0.5, y + float(wa[1]) + 30 - u * 220)
		_light(c, p, 12, Color(0.5, 1.0, 1.0, 0.6 * sin(PI * u)))

const REACT_S := 1.5

func _crew_v(k: int, at: float) -> float:
	var v := at * CREW_FPS + k * 7.0
	if _hold.has(k):
		v -= clampf(at - float(_hold[k]), 0.0, REACT_S) * CREW_FPS
	return v

func _crew_frame(cr: Dictionary, k: int) -> int:
	return _drawing_at(cr, _crew_v(k, t))

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
			SeaSounds.strike(amb, String(cr.work[0]), _far(float(b.y) + floor_of(int(b.d))) - k * 1.2 + (0.0 if k == sel else -4.0), 0.95 - k * 0.02)
	SeaSounds.of(self).tick(self)
