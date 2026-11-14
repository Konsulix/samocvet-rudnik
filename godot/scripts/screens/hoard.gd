class_name Hoard
extends SubViewportContainer
## The boss's reward: its hoard. A boulder of the mine's own rock (the specimen generator's, ROCK_OF) with nine closed
## geodes grown into it — knobbly rinds half sunk in the rock. Turn it with a finger, tap a geode to draw it out, crack
## the one you keep; the other eight stay in the rock. The Geologist's lens (gear, `lens`) lights the rarity of one
## geode per level: light of its rarity's colour through a seam in the rind. Hoard.pick(area) opens it on a card and
## returns the stone chosen.

signal selected(i: int)
signal picked(stone: Dictionary)

## how lucky each of the nine is (Stones.roll): one fine stone, a few good ones, the rest ordinary
const LUCK := [3.5, 2.6, 2.0, 1.6, 1.3, 1.1, 1.0, 0.9, 0.8]
const R_GEO := 0.29
## each mine's rock for its hoard (the specimen generator's kinds)
const ROCK_OF := {0: "slate", 1: "quartzite", 2: "limestone", 3: "lava", 4: "basalt", 5: "slate", 6: "ironstone", 7: "basalt"}

var stones := []
var geodes: Array[Node3D] = []
var dirs: Array[Vector3] = []
var normals: Array[Vector3] = []   # the rock's face under each geode: it is drawn out along it
var glows := []   # [light, phase] of the geodes the lens lights
var area_i := 0
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
	v.add_child(Ov.text("Turn it, pick one geode. The rest stay in the rock.", 13))
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
	area_i = area
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
	# (14.11) a boulder of the mine's own rock, as the specimen generator makes it (RockKit.rock, the rock material with
	# its scan), and nine closed geodes grown into it — knobbly rinds half sunk in the rock; the lens's ones glow faintly
	# through a seam in the rind in their rarity's colour. (Was a ball of serpentine wrapped in a coded serpent.)
	var r32 := Rng32.new(int(stones[0].id) % 1000003 + 11)
	var rtype: String = ROCK_OF.get(area_i, "basalt")
	var R := RockKit.rock(r32, rtype, "chunk", 40, 0.0)
	var rg: Geo = R.geo
	var rb := rg.aabb()
	var fit := 2.0 / maxf(rb.size.x, maxf(rb.size.y, rb.size.z))
	rg.translate(-rb.get_center().x, -rb.get_center().y, -rb.get_center().z)
	rg.scale(fit * 1.15, fit * 1.05, fit * 1.15)
	rg.rp = rg.v.duplicate()
	var rm := SpecMat.make({col = Color(1, 1, 1), rough = 0.95, grain = 0.35, ao = 1.0,
		dirt = {h = 99.0, a = 0.3, col = R.base, fr = 0.0, scan = int(RockKit.SCAN_OF[rtype])}})
	var rock_mi := SpecUtil.mesh(rg, rm, pivot)
	rock_mi.mesh = rg.to_mesh()
	# nine spots on its surface, apart from one another, not underneath
	var pts := RockKit.surf_pts(rock_mi, 400, r32, func(_p: Vector3, nn: Vector3) -> bool: return nn.y > -0.35, pivot)
	# (the rind as a geode's is: rough limestone-brown crust under a scan, fine knobs — not a pale fluffy ball)
	var rind := SpecMat.make({col = Color(1, 1, 1), rough = 0.95, grain = 0.4, ao = 1.0,
		dirt = {h = 99.0, a = 0.3, col = SpecMat.lin(0x6a5a46), fr = 0.0, scan = int(RockKit.SCAN_OF["limestone"])}})
	normals.clear()
	for q: Array in pts:
		if dirs.size() >= stones.size(): break
		var ok := true
		for d in dirs:
			if (d - (q[0] as Vector3)).length() < R_GEO * 2.3: ok = false
		if ok:
			dirs.append(q[0])
			normals.append(q[1])
	for i in stones.size():
		var g := Node3D.new()
		var at: Vector3 = dirs[i % dirs.size()]
		var nn: Vector3 = normals[i % normals.size()]
		g.position = at + nn * R_GEO * 0.2
		g.basis = Basis(SpecUtil.quat_to(Vector3.UP, nn)) * Basis(Vector3.UP, rng.randf() * TAU)
		pivot.add_child(g)
		# a closed geode: a lumpy cauliflower rind, a little flattened, every one its own
		var L := RockKit.lump(Rng32.new(i * 7919 + int(stones[i].id) % 1000), {r = R_GEO, sx = 1.0, sy = 0.88, sz = 0.95, wave = 0.05, k = 140.0,
			bumps = [[60, 0.18, 0.06], [160, 0.07, 0.025]], seg = 40})
		var gg: Geo = RockKit.tint_cav(L[0], L[1], 0.8)
		gg.rp = gg.v.duplicate()
		for vi in gg.rp.size(): gg.rp[vi] = gg.rp[vi] * 3.0 + Vector3(i * 1.7, 0, i * 2.3)
		var gm := SpecUtil.mesh(gg, rind, g)
		gm.mesh = gg.to_mesh()
		if lit.has(i):
			# what the lens shows: light of its rarity's colour through a hairline seam round the rind, breathing
			var rc := Data.rarity_color(int(lit[i]))
			var seam := SpecMat.make({col = rc.srgb_to_linear() * 0.2, rough = 0.6, emis = rc.srgb_to_linear() * 1.3})
			var ring := SpecUtil.mesh(Geo.torus(R_GEO * 0.86, R_GEO * 0.075, 6, 40).jitter(R_GEO * 0.03, 9.0, i), seam, g, Vector3(0, R_GEO * 0.05, 0), Basis(Vector3.RIGHT, PI / 2 + rng.randf_range(-0.5, 0.5)) * Basis(Vector3.UP, rng.randf() * TAU))
			ring.scale = Vector3(1.0, 1.0, 0.85)
			var glow := OmniLight3D.new()
			glow.light_color = rc
			glow.light_energy = 0.9
			glow.omni_range = 0.9
			glow.position = Vector3(0, R_GEO * 0.8, 0)
			g.add_child(glow)
			glows.append([glow, rng.randf() * TAU])
		geodes.append(g)
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
	var t := Time.get_ticks_msec() / 1000.0
	for gl: Array in glows:
		(gl[0] as OmniLight3D).light_energy = 0.7 + 0.35 * sin(t * 1.6 + float(gl[1]))
	for i in geodes.size():
		var g := geodes[i]
		var home: Vector3 = dirs[i % dirs.size()] + normals[i % normals.size()] * R_GEO * (1.0 if i == sel else 0.2)
		g.position = g.position.lerp(home, minf(1.0, dt * 10.0))
		var s := lerpf(g.scale.x, 1.15 if i == sel else 1.0, minf(1.0, dt * 10.0))
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

## the chosen one is drawn out of the hoard: it lifts towards you, then GeodeOpen cracks it on its own dark screen
func crack() -> void:
	if sel < 0 or _busy: return
	_busy = true
	var g := geodes[sel]
	Sfx.play("crack", 1)
	Sfx.buzz(20)
	var tw := create_tween().set_parallel()
	tw.tween_property(g, "scale", Vector3.ONE * 1.5, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(g, "position", g.position + normals[sel % normals.size()] * R_GEO * 1.2, 0.3)
	await tw.finished
	picked.emit(stones[sel])
