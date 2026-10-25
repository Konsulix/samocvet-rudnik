class_name Hoard
extends SubViewportContainer
## The boss's reward: its hoard. A boulder of serpentine with gold veins on a scatter of gold, the golden serpent
## coiled round it (scaled hide, a lofted head with burning eyes), nine geodes — knobbly rinds with a crack full of
## crystals — and druses of quartz and pyrite cubes grown into the rock. Turn it with a finger, tap a geode to draw it out, crack the
## one you keep; the other eight stay with the serpent. The Geologist's lens (gear, `lens`) lights the rarity of one
## geode per level. Hoard.pick(area) opens it on a card and returns the stone chosen.

signal selected(i: int)
signal picked(stone: Dictionary)

## how lucky each of the nine is (Stones.roll): one fine stone, a few good ones, the rest ordinary
const LUCK := [3.5, 2.6, 2.0, 1.6, 1.3, 1.1, 1.0, 0.9, 0.8]
const R_GEO := 0.25

var stones := []
var geodes: Array[Node3D] = []
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
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	cam.position = Vector3(0, 0.05, 4.8)
	cam.fov = 36
	vp.add_child(cam)
	# the key from the top left, a warm rim of candle light from behind, a dim cool fill
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -32, 0)
	sun.light_energy = 1.4
	vp.add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-15, 160, 0)
	rim.light_color = Color(1.0, 0.62, 0.3)
	rim.light_energy = 1.1
	vp.add_child(rim)
	var fill := OmniLight3D.new()
	fill.position = Vector3(2.4, -1.2, 2.6)
	fill.light_color = Color(0.7, 0.75, 0.9)
	fill.light_energy = 0.35
	fill.omni_range = 8.0
	vp.add_child(fill)
	pivot.rotation = Vector3(0.3, 0.4, 0)
	vp.add_child(pivot)
	var sd := int(stones[0].id) % 997
	# the boulder: a hewn, lumpy ball of serpentine, big facets broken into smaller ones
	var rock := ShaderMaterial.new()
	rock.shader = preload("res://shaders/hoard_rock.gdshader")
	SpecUtil.mesh(Geo.icosa(1.0, 4).jitter(0.1, 1.5, sd).jitter(0.025, 6.0, sd + 1), rock, pivot)
	# the serpent coiled round it: one body, a thin tail at the foot, thick at the neck, the head raised and looking out
	var coil := []
	var turns := 1.55
	var segs := 120
	for k in segs + 1:
		var t := k / float(segs)
		var a := t * TAU * turns
		var y := lerpf(-0.88, 0.55, t)
		var rr := sqrt(maxf(0.0, 1.0 - y * y)) * 0.98 + 0.06 + 0.05 * t
		coil.append(Vector3(cos(a) * rr, y, sin(a) * rr))
	var tip: Vector3 = coil[-1]
	var up: Vector3 = tip.normalized()
	var tg: Vector3 = (coil[-1] - coil[-3]).normalized()
	var look := (tg * 0.85 + up * 0.4).normalized()
	for k in 5:
		var f := (k + 1) / 5.0
		coil.append(tip + up * 0.12 * f + look * 0.2 * f)
	var radii := []
	for k in coil.size():
		var t := minf(1.0, k / float(segs))
		radii.append(lerpf(0.012, 0.12, pow(smoothstep(0.0, 0.8, t), 0.8)))
	var hide := ShaderMaterial.new()
	hide.shader = preload("res://shaders/hoard_scales.gdshader")
	_tube(coil, radii, 12, hide)
	var gold := SpecMat.make({col = SpecMat.lin(0xd9a032), rough = 0.3, metal = 1.0})
	var bellyc := SpecMat.make({col = SpecMat.lin(0x9a6a24), rough = 0.4, metal = 0.85})
	# the head: lofted from sections — broad skull with heavy brows, tapering to the snout, the jaw a little open
	var neck: Vector3 = coil[-1]
	var fwd: Vector3 = (look + (neck - coil[-2]).normalized()).normalized()
	var side: Vector3 = fwd.cross(up).normalized()
	var top: Vector3 = side.cross(fwd).normalized()
	var K := 1.4   # the head a size up, so it reads at a glance
	_loft(neck - fwd * 0.06 * K, fwd, side, top, 0.42, K, [[0.11, 0.09, 0.0], [0.14, 0.1, 0.015], [0.13, 0.09, 0.015], [0.1, 0.07, 0.0],
		[0.075, 0.05, -0.008], [0.055, 0.04, -0.015], [0.03, 0.025, -0.02]], hide)
	var jaw_f: Vector3 = fwd.rotated(side, 0.25)
	_loft(neck - top * 0.06 * K, jaw_f, side, side.cross(jaw_f).normalized(), 0.34, K, [[0.09, 0.04, 0.0], [0.085, 0.035, 0.0],
		[0.065, 0.03, 0.0], [0.045, 0.022, 0.0], [0.025, 0.014, 0.0]], bellyc)
	var eye := SpecMat.make({col = SpecMat.lin(0x603000), rough = 0.15, emis = SpecMat.lin(0xffc030) * 2.2})
	var slit := SpecMat.make({col = SpecMat.lin(0x080400), rough = 0.4})
	for s in [-1.0, 1.0]:
		var e: Vector3 = neck + (fwd * 0.12 + top * 0.055 + side * s * 0.115) * K
		SpecUtil.mesh(Geo.sphere(0.03 * K, 12, 8), eye, pivot, e)
		var pu := SpecUtil.mesh(Geo.box(0.008 * K, 0.04 * K, 0.012 * K), slit, pivot, e + side * s * 0.026 * K)
		pu.basis = Basis(SpecUtil.quat_to(Vector3.UP, top))
		var brow := SpecUtil.mesh(Geo.sphere(1.0, 12, 8), gold, pivot, e + (top * 0.035 - fwd * 0.005) * K)
		brow.basis = Basis(side, fwd, top).scaled(Vector3(0.05, 0.075, 0.022) * K)
	# a beard of three heavy tendrils from the jaw
	for k in 3:
		var root: Vector3 = neck + (fwd * (0.2 - k * 0.05) - top * 0.1 + side * (k - 1) * 0.05) * K
		var pts := []
		var rs := []
		for j in 6:
			pts.append(root - Vector3.UP * j * 0.06 - fwd * j * 0.01 + side * sin(j * 1.4 + k * 2.0) * 0.025)
			rs.append(lerpf(0.016, 0.004, j / 5.0))
		_tube(pts, rs, 6, bellyc)
	# nine geodes where the coil is not, apart from one another: knobbly rinds, a crack full of crystals
	var cand := []
	var n := 90
	for i in n:
		var y := 1.0 - (i + 0.5) / n * 2.0
		var r := sqrt(1.0 - y * y)
		var a := i * 2.399963
		cand.append(Vector3(cos(a) * r, y, sin(a) * r))
	var near_coil := func(d: Vector3, lim: float) -> bool:
		for p: Vector3 in coil:
			if (p - d).length() < lim: return true
		return false
	for lim in [0.36, 0.28, 0.2]:
		for d: Vector3 in cand:
			if dirs.size() >= stones.size(): break
			if d.y < -0.6: continue
			var ok: bool = not near_coil.call(d, lim)
			for q in dirs:
				if (q - d).length() < 0.58: ok = false
			if ok: dirs.append(d)
	var shell := SpecMat.make({col = SpecMat.lin(0x6a5848), rough = 0.95})
	var lip := SpecMat.make({col = SpecMat.lin(0x120c08), rough = 0.9})
	var quartz := SpecMat.make({col = SpecMat.lin(0xd8d4e0), rough = 0.12, coat = 1.0, emis = SpecMat.lin(0x504860) * 0.3})
	for i in stones.size():
		var g := Node3D.new()
		g.position = dirs[i] * 0.97
		g.basis = Basis(SpecUtil.quat_to(Vector3.UP, dirs[i])) * Basis(Vector3.UP, rng.randf() * TAU)
		pivot.add_child(g)
		SpecUtil.mesh(Geo.icosa(R_GEO, 2).jitter(0.04, 5.0, i * 31 + 7), shell, g).scale = Vector3(1.0, 0.85, 1.0)
		# the crack: a dark lip round an opening at the top, crystals bristling out of it
		SpecUtil.mesh(Geo.torus(R_GEO * 0.5, R_GEO * 0.16, 8, 18), lip, g, Vector3(0, R_GEO * 0.66, 0), Basis(Vector3.RIGHT, PI / 2))
		SpecUtil.mesh(Geo.cylinder(R_GEO * 0.45, R_GEO * 0.3, R_GEO * 0.2, 14), lip, g, Vector3(0, R_GEO * 0.62, 0))
		var cm: Material = quartz
		if lit.has(i):
			# what the lens shows: the crystals in their rarity's colour, light pouring out of the crack
			var rc := Data.rarity_color(int(lit[i]))
			cm = SpecMat.make({col = rc.srgb_to_linear(), rough = 0.1, coat = 1.0, emis = rc.srgb_to_linear() * 1.1})
			var glow := OmniLight3D.new()
			glow.light_color = rc
			glow.light_energy = 1.6
			glow.omni_range = 0.8
			glow.position = Vector3(0, R_GEO * 1.4, 0)
			g.add_child(glow)
		for j in 6:
			var a := j / 6.0 * TAU + rng.randf() * 0.5
			var rr := R_GEO * (0.1 + 0.18 * (j % 3) / 2.0)
			var h := R_GEO * (0.45 + rng.randf() * 0.45)
			var dir := (Vector3.UP + Vector3(cos(a), 0, sin(a)) * (0.25 + rng.randf() * 0.35)).normalized()
			var c := SpecUtil.mesh(Geo.cone(R_GEO * 0.16, h, 6), cm, g, Vector3(cos(a) * rr, R_GEO * 0.55, sin(a) * rr) + dir * h * 0.5)
			c.basis = Basis(SpecUtil.quat_to(Vector3.UP, dir))
		geodes.append(g)
	# druses of white quartz and pyrite cubes grown into the rock
	var pyrite := SpecMat.make({col = SpecMat.lin(0xc0a058), rough = 0.22, metal = 0.95})
	var put := 0
	for d: Vector3 in cand:
		if put >= 10: break
		if near_coil.call(d, 0.22) or d in dirs: continue
		var far := true
		for q in dirs:
			if (q - d).length() < 0.38: far = false
		if not far or rng.randf() < 0.5: continue
		if put % 2 == 0:
			for j in 6:
				var dir := (d + Vector3(rng.randf() - 0.5, rng.randf() - 0.5, rng.randf() - 0.5) * 0.6).normalized()
				var h := 0.1 + rng.randf() * 0.14
				var c := SpecUtil.mesh(Geo.cone(0.038, h, 6), quartz, pivot, d * 0.97 + dir * h * 0.5 + (dir - d) * 0.05)
				c.basis = Basis(SpecUtil.quat_to(Vector3.UP, dir))
		else:
			var c := SpecUtil.mesh(Geo.box(0.12, 0.12, 0.12), pyrite, pivot, d * 1.0)
			c.rotation = Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)
		put += 1
	# gold spilling out at its foot: big nuggets half sunk in the rock round the bottom
	for k in 12:
		var a := k / 12.0 * TAU + rng.randf() * 0.4
		var y := -0.62 - rng.randf() * 0.25
		var r := sqrt(maxf(0.0, 1.0 - y * y))
		var d := Vector3(cos(a) * r, y, sin(a) * r)
		if near_coil.call(d, 0.16): continue
		SpecUtil.mesh(Geo.icosa(0.07 + rng.randf() * 0.06, 1).jitter(0.02, 8.0, k), gold, pivot, d * 1.0)
	# a soft shadow on the card under it, drawn with the stones' shader (the stock one draws nothing on iPhone)
	var shadow := Control.new()
	shadow.show_behind_parent = true
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.material = BoardSprites.plain_material()
	shadow.draw.connect(func():
		var S := custom_minimum_size
		for k in 6:
			var w := S.x * (0.4 - k * 0.04)
			shadow.draw_colored_polygon(GemArt.ellipse_pts(Vector2(S.x * 0.5, S.y * 0.86), w, w * 0.17, 0, 32), Color(0, 0, 0, 0.11)))
	add_child(shadow)

## a tube along points with a radius at each (tapering ends closed by their own thinness), UV.x along, UV.y round
func _tube(pts: Array, radii: Array, around: int, mat: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nrm := Vector3.UP
	var length := 0.0
	var rings := []
	for k in pts.size():
		var a: Vector3 = pts[maxi(k - 1, 0)]
		var b: Vector3 = pts[mini(k + 1, pts.size() - 1)]
		var tgt := (b - a).normalized()
		nrm = (nrm - tgt * nrm.dot(tgt)).normalized()
		if nrm.length_squared() < 0.5: nrm = tgt.cross(Vector3.RIGHT).normalized()
		var bi := tgt.cross(nrm)
		if k > 0: length += (pts[k] - pts[k - 1]).length()
		var ring := []
		for q in around + 1:
			var ang := q / float(around) * TAU
			var dir := nrm * cos(ang) + bi * sin(ang)
			ring.append([pts[k] + dir * float(radii[k]), dir, Vector2(length * 4.0, q / float(around))])
		rings.append(ring)
	for k in rings.size() - 1:
		for q in around:
			var quad := [rings[k][q], rings[k + 1][q], rings[k + 1][q + 1], rings[k][q], rings[k + 1][q + 1], rings[k][q + 1]]
			for v in quad:
				st.set_normal(v[1])
				st.set_uv(v[2])
				st.add_vertex(v[0])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	pivot.add_child(mi)

## a closed form lofted along `fwd` from sections [half width, half height, rise], smooth, flatter on top
func _loft(at: Vector3, fwd: Vector3, side: Vector3, top: Vector3, length: float, k: float, prof: Array, mat: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 14
	var rings := []
	for j in prof.size():
		var w: float = prof[j][0] * k
		var h: float = prof[j][1] * k
		var c := at + fwd * (j / float(prof.size() - 1) * length * k) + top * float(prof[j][2]) * k
		var ring := []
		for q in n + 1:
			var a := q / float(n) * TAU
			var y := sin(a) * (0.75 if sin(a) > 0.0 else 1.0)
			ring.append(c + side * cos(a) * w + top * y * h)
		rings.append(ring)
	for j in rings.size() - 1:
		for q in n:
			for v in [rings[j][q], rings[j][q + 1], rings[j + 1][q + 1], rings[j][q], rings[j + 1][q + 1], rings[j + 1][q]]:
				st.set_uv(Vector2(q / float(n), j / float(prof.size())))
				st.add_vertex(v)
	# the two ends shut
	for e in [0, rings.size() - 1]:
		var c := Vector3.ZERO
		for v in rings[e]: c += v
		c /= rings[e].size()
		for q in n:
			var tri := [c, rings[e][q], rings[e][q + 1]] if e == 0 else [c, rings[e][q + 1], rings[e][q]]
			for v in tri:
				st.set_uv(Vector2(0.5, 0.5))
				st.add_vertex(v)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	pivot.add_child(mi)

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
