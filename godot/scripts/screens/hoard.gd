class_name Hoard
extends SubViewportContainer
## The boss's reward: its hoard. A boulder of serpentine with gold veins, the golden serpent coiled round it, nine
## geodes and a few pyrite cubes grown into the rock. Turn it with a finger, tap a geode to draw it out, crack the
## one you keep; the other eight stay with the serpent. The Geologist's lens (gear, `lens`) lights the rarity of one
## geode per level. Hoard.pick(area) opens it on a card and returns the stone chosen.

signal selected(i: int)
signal picked(stone: Dictionary)

## how lucky each of the nine is (Stones.roll): one fine stone, a few good ones, the rest ordinary
const LUCK := [3.5, 2.6, 2.0, 1.6, 1.3, 1.1, 1.0, 0.9, 0.8]
const R_GEO := 0.22

var stones := []
var geodes: Array[MeshInstance3D] = []
var dirs: Array[Vector3] = []
var lit := {}           # geode index -> its rarity tier, for the ones the lens shows
var sel := -1
var pivot := Node3D.new()
var cam := Camera3D.new()
var _touched := false
var _down := false
var _moved := 0.0
var _vel := Vector2.ZERO
var _busy := false

## the card: the hoard turning, a line on the lens, the button; awaits the choice and returns the stone
static func pick(area: int) -> Dictionary:
	var B: Dictionary = Data.AREAS[area].get("boss", {})
	var v := Ov.card(360)
	v.add_child(UI.title("The hoard of %s" % String(B.get("n", "the boss")), 21))
	v.add_child(Ov.text("Turn it, pick one geode. The rest stay with the serpent.", 13))
	var h := Hoard.new()
	h.setup(area)
	var wrap := CenterContainer.new()
	wrap.add_child(h)
	v.add_child(wrap)
	var lv: int = int(Save.d.eq.get("lens", 0))
	var info := Ov.text("The Geologist's lens shows %d of them." % lv if lv else "A Geologist's lens (Machines → Gear) would show what lies inside.", 12, UI.GOLD if lv else UI.MUTED)
	v.add_child(info)
	var btn := Ov.btn("Pick a geode", "gold", func(): h.crack(), false)
	v.add_child(btn)
	h.selected.connect(func(i: int):
		btn.disabled = false
		btn.text = "Crack this geode" + (" · %s" % String(Data.RAR[h.lit[i]]) if h.lit.has(i) else ""))
	var st: Dictionary = await h.picked
	return st

func setup(area: int) -> void:
	custom_minimum_size = Vector2(320, 320)
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	for i in LUCK.size():
		stones.append(Stones.roll(Save.next_uid(), area, LUCK[i], Data.depths(area).size()))
	stones.shuffle()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(stones[0].id)
	var order := range(stones.size())
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = order[i]; order[i] = order[j]; order[j] = tmp
	for k in mini(int(Save.d.eq.get("lens", 0)), stones.size()):
		lit[order[k]] = int(stones[order[k]].tier)
	_build(rng)

func _build(rng: RandomNumberGenerator) -> void:
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.5, 0.45)
	env.ambient_light_energy = 0.65
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	cam.position = Vector3(0, 0, 4.3)
	cam.fov = 36
	vp.add_child(cam)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -32, 0)
	sun.light_energy = 1.35
	vp.add_child(sun)
	var fill := OmniLight3D.new()
	fill.position = Vector3(2.2, -1.2, 2.6)
	fill.light_color = Color(1.0, 0.75, 0.45)
	fill.light_energy = 0.7
	fill.omni_range = 8.0
	vp.add_child(fill)
	pivot.rotation = Vector3(0.35, 0.4, 0)
	vp.add_child(pivot)
	# the boulder: a hewn, lumpy ball of serpentine
	var rock := ShaderMaterial.new()
	rock.shader = preload("res://shaders/hoard_rock.gdshader")
	SpecUtil.mesh(Geo.icosa(1.0, 3).jitter(0.09, 1.6, int(stones[0].id) % 997), rock, pivot)
	# the serpent coiled round it, head up: a body of overlapping golden scales, thin at the tail, thick at the neck
	var coil := []
	var turns := 1.6
	var segs := 110
	for k in segs + 1:
		var t := k / float(segs)
		var a := t * TAU * turns
		var y := lerpf(-0.86, 0.62, t)
		var rr := sqrt(maxf(0.0, 1.0 - y * y)) * 0.98 + 0.04
		coil.append(Vector3(cos(a) * rr, y, sin(a) * rr))
	var gold := SpecMat.make({col = SpecMat.lin(0xd9a032), rough = 0.32, metal = 1.0})
	var belly := SpecMat.make({col = SpecMat.lin(0x8a5a18), rough = 0.45, metal = 0.8})
	var scale_geo := Geo.sphere(1.0, 10, 8)
	for k in coil.size():
		var t := k / float(segs)
		var r := lerpf(0.03, 0.105, smoothstep(0.0, 0.85, t))
		SpecUtil.mesh(scale_geo, belly if k % 7 == 3 else gold, pivot, coil[k]).scale = Vector3.ONE * r
	# the head lifts off the rock, looking out
	var tip: Vector3 = coil[-1]
	var tg: Vector3 = (coil[-1] - coil[-4]).normalized()
	var up: Vector3 = tip.normalized()
	var fwd := (tg + up * 0.6).normalized()
	var neck := tip + up * 0.06
	var head := SpecUtil.mesh(Geo.sphere(0.15, 18, 12), gold, pivot, neck + fwd * 0.12)
	head.basis = Basis(SpecUtil.quat_to(Vector3.FORWARD, fwd)).scaled(Vector3(0.95, 0.7, 1.5))
	var jaw := SpecUtil.mesh(Geo.sphere(0.1, 14, 10), belly, pivot, neck + fwd * 0.2 - up * 0.04)
	jaw.basis = Basis(SpecUtil.quat_to(Vector3.FORWARD, fwd)).scaled(Vector3(0.9, 0.5, 1.6))
	var eye := SpecMat.make({col = SpecMat.lin(0x400000), rough = 0.2, emis = SpecMat.lin(0xff3020) * 1.8})
	var side := fwd.cross(up).normalized()
	for s in [-1.0, 1.0]:
		SpecUtil.mesh(Geo.sphere(0.03, 8, 6), eye, pivot, neck + fwd * 0.17 + side * s * 0.085 + up * 0.06)
	# nine geodes where the coil is not, apart from one another
	var cand := []
	var n := 80
	for i in n:
		var y := 1.0 - (i + 0.5) / n * 2.0
		var r := sqrt(1.0 - y * y)
		var a := i * 2.399963
		cand.append(Vector3(cos(a) * r, y, sin(a) * r))
	var near_coil := func(d: Vector3, lim: float) -> bool:
		for p: Vector3 in coil:
			if (p - d).length() < lim: return true
		return false
	for lim in [0.34, 0.26, 0.18]:
		for d: Vector3 in cand:
			if dirs.size() >= stones.size(): break
			var ok: bool = not near_coil.call(d, lim)
			for q in dirs:
				if (q - d).length() < 0.55: ok = false
			if ok: dirs.append(d)
	var shell := SpecMat.make({col = SpecMat.lin(0x7d6b58), rough = 0.95})
	for i in stones.size():
		var mat: Material = shell
		if lit.has(i):
			var rc := Data.rarity_color(int(lit[i]))
			mat = SpecMat.make({col = SpecMat.lin(0x7d6b58), rough = 0.9, emis = rc.srgb_to_linear() * 0.55})
			var glow := OmniLight3D.new()
			glow.light_color = rc
			glow.light_energy = 1.2
			glow.omni_range = 0.7
			glow.position = dirs[i] * 1.3
			pivot.add_child(glow)
		var g := SpecUtil.mesh(Geo.icosa(R_GEO, 1).jitter(0.035, 5.0, i * 31 + 7), mat, pivot, dirs[i] * 0.97)
		g.rotation = Vector3(rng.randf() * TAU, rng.randf() * TAU, 0)
		geodes.append(g)
	# a few pyrite cubes grown into the rock
	var pyrite := SpecMat.make({col = SpecMat.lin(0xb8a060), rough = 0.25, metal = 0.9})
	var put := 0
	for d: Vector3 in cand:
		if put >= 7: break
		if near_coil.call(d, 0.2) or d in dirs: continue
		var far := true
		for q in dirs:
			if (q - d).length() < 0.4: far = false
		if not far or rng.randf() < 0.6: continue
		var c := SpecUtil.mesh(Geo.box(0.11, 0.11, 0.11), pyrite, pivot, d * 1.0)
		c.rotation = Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)
		put += 1

func _gui_input(e: InputEvent) -> void:
	if _busy: return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_down = true
			_touched = true
			_moved = 0.0
			_vel = Vector2.ZERO
		else:
			_down = false
			if _moved < 10.0: _pick(e.position)
		accept_event()
	elif e is InputEventMouseMotion and _down:
		var rel: Vector2 = e.relative
		_moved += rel.length()
		_vel = rel
		_turn(rel)
		accept_event()

func _turn(rel: Vector2) -> void:
	pivot.rotate(Vector3.UP, rel.x * 0.011)
	pivot.rotate(Vector3.RIGHT, rel.y * 0.011)

func _process(dt: float) -> void:
	if not _touched:
		pivot.rotate(Vector3.UP, 0.3 * dt)
	elif not _down and _vel.length() > 0.05:
		_vel *= 0.9
		_turn(_vel)
	for i in geodes.size():
		var out := 1.2 if i == sel else 0.97
		var g := geodes[i]
		g.position = g.position.lerp(dirs[i] * out, minf(1.0, dt * 10.0))
		var s := lerpf(g.scale.x, 1.25 if i == sel else 1.0, minf(1.0, dt * 10.0))
		if not _busy: g.scale = Vector3.ONE * s

## the geode under the finger: the nearest one the ray meets on the near side of the boulder
func _pick(at: Vector2) -> void:
	var o := cam.project_ray_origin(at)
	var dir := cam.project_ray_normal(at)
	var best := -1
	var best_t := INF
	for i in geodes.size():
		var c := geodes[i].global_position
		if (c - pivot.global_position).normalized().dot((cam.global_position - c).normalized()) < 0.05: continue
		var t := (c - o).dot(dir)
		if t < 0.0 or t > best_t: continue
		if (o + dir * t - c).length() < R_GEO * 1.35:
			best = i
			best_t = t
	if best < 0 or best == sel: return
	sel = best
	Sfx.play("click")
	Sfx.buzz(10)
	selected.emit(sel)

## the chosen one cracks: it shakes three times and bursts; the stone inside is the reward
func crack() -> void:
	if sel < 0 or _busy: return
	_busy = true
	var g := geodes[sel]
	var base := g.position
	for k in 3:
		Sfx.play("crack", k + 1)
		Sfx.buzz(20)
		var tw := create_tween()
		for q in 3:
			tw.tween_property(g, "position", base + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.03, 0.035)
		tw.tween_property(g, "position", base, 0.04)
		await tw.finished
		await get_tree().create_timer(0.18).timeout
	var tw2 := create_tween()
	tw2.tween_property(g, "scale", Vector3.ONE * 1.6, 0.12)
	tw2.tween_property(g, "scale", Vector3.ONE * 0.01, 0.1)
	await tw2.finished
	picked.emit(stones[sel])
