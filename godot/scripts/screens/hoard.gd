class_name Hoard
extends SubViewportContainer
## The boss's reward: its hoard, over the darkened screen. A column of the mine's own rock (the specimen generator's,
## ROCK_OF) veined along its ridges with the boss's own metal (VEIN_OF: the Serpent's gold), and nine almandine crystals
## grown out of it in the generator's glass. Turn it with a finger, tap a crystal to draw it out; the other eight stay in
## the rock. The Geologist's lens (gear, `lens`) lights the rarity of one per level: that crystal burns in its rarity's
## colour. Hoard.pick(area) shows it and returns the stone chosen.

signal selected(i: int)
signal picked(stone: Dictionary)

## how lucky each of the nine is (Stones.roll): one fine stone, a few good ones, the rest ordinary
const LUCK := [3.5, 2.6, 2.0, 1.6, 1.3, 1.1, 1.0, 0.9, 0.8]
const R_GEO := 0.29
const HALO: Shader = preload("res://shaders/fungi_halo.gdshader")
## each mine's rock for its hoard (the specimen generator's kinds)
## the metal running along the rock's ridges, each boss's own (the generator's silver rim, tinted): the Serpent's gold,
## the Mistress's copper, the sea's pale silver, the smith's red-hot iron...
const VEIN_OF := {0: Vector3(1.0, 0.58, 0.14), 1: Vector3(1.0, 0.42, 0.22), 2: Vector3(0.85, 0.95, 1.1), 3: Vector3(1.1, 0.32, 0.1),
	4: Vector3(0.9, 1.05, 1.2), 5: Vector3(1.0, 1.0, 1.0), 6: Vector3(1.1, 0.8, 0.5), 7: Vector3(0.7, 0.85, 1.25)}
const ROCK_OF := {0: "slate", 1: "quartzite", 2: "limestone", 3: "lava", 4: "basalt", 5: "slate", 6: "ironstone", 7: "basalt"}

var stones := []
var geodes: Array[Node3D] = []
var dirs: Array[Vector3] = []
var normals: Array[Vector3] = []   # the rock's face under each geode: it is drawn out along it
var sinks := []   # how deep each crystal sits in the rock (from barely to half sunk)
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

## over the darkened screen (no card): its name, the hoard turning large, a line on the lens, the button; awaits the
## choice and returns the stone
static func pick(area: int) -> Dictionary:
	var B: Dictionary = Data.AREAS[area].get("boss", {})
	var tree := Engine.get_main_loop() as SceneTree
	var layer := CanvasLayer.new()
	layer.layer = 15
	tree.root.add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(dim)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 10)
	v.modulate.a = 0.0
	layer.add_child(v)
	var t := UI.title("The hoard of %s" % String(B.get("n", "the boss")), 24)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var sub := Ov.text("Turn it, pick one crystal. The rest stay in the rock.", 14)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var h := Hoard.new()
	h.setup(area)
	var wrap := CenterContainer.new()
	wrap.add_child(h)
	v.add_child(wrap)
	var lv: int = int(Save.d.eq.get("lens", 0))
	var info := Ov.text("The Geologist's lens shows %d of them." % lv if lv else "A Geologist's lens (Machines → Gear) would show what lies inside.", 13, UI.GOLD if lv else UI.MUTED)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(320, 0)
	var iw := CenterContainer.new()
	iw.add_child(info)
	v.add_child(iw)
	var btn := Ov.btn("Pick a crystal", "gold", func(): h.crack(), false)
	btn.custom_minimum_size = Vector2(300, 54)
	var bw := CenterContainer.new()
	bw.add_child(btn)
	v.add_child(bw)
	h.selected.connect(func(i: int):
		btn.disabled = false
		btn.text = "Take this one" + (" · %s" % String(Data.RAR[h.lit[i]]) if h.lit.has(i) else ""))
	var tw := layer.create_tween().set_parallel()
	tw.tween_property(dim, "color:a", 0.93, 0.35)
	tw.tween_property(v, "modulate:a", 1.0, 0.35)
	var st: Dictionary = await h.picked
	layer.queue_free()
	return st

func setup(area: int) -> void:
	area_i = area
	custom_minimum_size = Vector2(360, 470)
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
	# (the stone card's own studio light: its sky to mirror in the facets, a warm key, a cold and a warm rim — the
	# crystals are its glass, and they only sparkle in that light; the backdrop stays clear over the dimmed screen)
	var env := Environment.new()
	env.sky = SpecStudio._shared_sky()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.5
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.1
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 0.9
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	cam.position = Vector3(0, 0.05, 7.0)
	cam.fov = 36
	vp.add_child(cam)
	for L: Array in [[Color("#fff0dc"), 1.6, Vector3(2.5, 3.5, 3)], [Color("#8fb8ff"), 1.5, Vector3(-3.5, 1.5, -2.5)],
			[Color("#ffc890"), 1.1, Vector3(3.5, 0.4, -3)], [Color(1, 1, 1), 0.3, Vector3(0, -2, 4)]]:
		var l := DirectionalLight3D.new()
		l.light_color = L[0]
		l.light_energy = L[1]
		vp.add_child(l)
		l.look_at_from_position(L[2], Vector3.ZERO)
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
	# (stood up as a column: taller than wide, the geodes up its sides)
	rg.scale(fit * 0.95, fit * 2.2, fit * 0.95)
	# (a column stands on a flat foot: its lower part cut level, the cut a little rough)
	var cb0 := rg.aabb()
	var cut := cb0.position.y + cb0.size.y * 0.24
	for vi in rg.v.size():
		var vv := rg.v[vi]
		if vv.y < cut:
			var spread := 1.0 + (cut - vv.y) / maxf(cb0.size.y, 0.01) * 0.6
			rg.v[vi] = Vector3(vv.x * spread, cut - 0.02 * sin(vv.x * 9.0 + vv.z * 7.0), vv.z * spread)
	rg.rp = rg.v.duplicate()
	var rm := SpecMat.make({col = Color(1, 1, 1), rough = 0.95, grain = 0.35, ao = 1.0, silv = 1.0, silv_col = VEIN_OF.get(area_i, Vector3.ONE),
		dirt = {h = 99.0, a = 0.3, col = R.base, fr = 0.0, scan = int(RockKit.SCAN_OF[rtype])}})
	var rock_mi := SpecUtil.mesh(rg, rm, pivot)
	rock_mi.mesh = rg.to_mesh()
	# nine spots on its surface, apart from one another, not underneath
	# (none near the foot: a crystal there hung below the column's flat base)
	var low := cut + R_GEO * 1.4
	var pts := RockKit.surf_pts(rock_mi, 500, r32, func(pp: Vector3, nn: Vector3) -> bool: return nn.y > -0.2 and pp.y > low, pivot)
	normals.clear()
	for q: Array in pts:
		if dirs.size() >= stones.size(): break
		var ok := true
		for d in dirs:
			if (d - (q[0] as Vector3)).length() < R_GEO * 2.1: ok = false
		if ok:
			dirs.append(q[0])
			normals.append(q[1])
	# (14.11, the reward should feel like treasure) nine big almandine crystals grown out of the rock: the generator's
	# own glass (light bent through them, a rainbow film, a deep wine-red body glowing a little from within). The ones
	# the lens shows burn in their rarity's colour, a light of it on the rock round them
	sinks.clear()
	for i in stones.size(): sinks.append(-0.1 + rng.randf() * 0.55)
	for i in stones.size():
		var g := Node3D.new()
		var at: Vector3 = dirs[i % dirs.size()]
		var nn: Vector3 = normals[i % normals.size()]
		var axis := nn.lerp(Vector3.UP, 0.35).normalized()
		g.position = at - nn * R_GEO * sinks[i]
		g.basis = Basis(SpecUtil.quat_to(Vector3.UP, axis)) * Basis(Vector3.UP, rng.randf() * TAU)
		pivot.add_child(g)
		var cr := Rng32.new(i * 7919 + int(stones[i].id) % 1000)
		var col := SpecMat.lin(0x8a1022)
		var glow_k := 0.18
		# (detail: faces not quite flat, as a grown crystal's are — the glass ripples what shows through)
		var cg := RockKit.crystal("dodeca", cr, {h = 1.0, cA = col, cB = col, detail = 2})
		var cb := cg.aabb()
		# (each its own size, from a small one to a big one)
		var csz := R_GEO * 2.2 * (0.65 + cr.next() * 0.7) / maxf(cb.size.x, maxf(cb.size.y, cb.size.z))
		cg.translate(-cb.get_center().x, -cb.position.y - cb.size.y * 0.25, -cb.get_center().z)
		cg.scale(csz, csz, csz)
		# (a garnet's own skin: fine growth lines across the faces, a little milky in patches, a softer rainbow — glass
		# polished smooth read as red plastic)
		var cm := SpecMat.make({col = Color(1, 1, 1), flat = true, glass = true, ir = 0.2, rf = 0.25, frost = 0.32, thick = 1.25,
			st = 1.0, st_mode = 2.0, grain = 0.25, seed = float(i * 13 % 97), prio = 2, tint_body = 0.75, tint_glow = glow_k, deep_body = 1.0})
		SpecUtil.mesh(cg, cm, g)
		if lit.has(i):
			# what the lens shows: a soft halo of its rarity's colour round it and a little of that light on the rock, as
			# the glowing mycena's — the crystal itself stays a garnet
			var rc := Data.rarity_color(int(lit[i]))
			var halo := MeshInstance3D.new()
			var q := QuadMesh.new()
			q.size = Vector2.ONE * R_GEO * 5.0
			halo.mesh = q
			var hm := ShaderMaterial.new()
			hm.shader = HALO
			hm.set_shader_parameter("col", Vector3(rc.r, rc.g, rc.b))
			hm.set_shader_parameter("power", 0.22)
			halo.material_override = hm
			halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			halo.position = Vector3(0, R_GEO * 0.45, 0)
			g.add_child(halo)
			var glow := OmniLight3D.new()
			glow.light_color = rc
			glow.light_energy = 0.9
			glow.omni_range = 0.9
			glow.position = Vector3(0, R_GEO * 0.9, 0)
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
		var home: Vector3 = dirs[i % dirs.size()] + normals[i % normals.size()] * R_GEO * (0.7 if i == sel else -sinks[i % sinks.size()])
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
