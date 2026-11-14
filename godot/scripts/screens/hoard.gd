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
var sizes := []   # each crystal's size, of R_GEO (a big one leading its group, small ones round it)
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
		btn.disabled = i < 0
		if i < 0:
			btn.text = "Pick a crystal"
			return
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
	rg.scale(fit * 1.3, fit * 1.5, fit * 1.05)
	# (14.11, after a photo of a split boulder) not an egg: big flat break faces at all angles, as a block of rock
	# broken out of a cliff — the boulder cut by planes (everything past one pressed onto it), steep ones round its
	# sides, slanting ones at its top, its foot broken off unevenly; the scan and the noise of the rock keep the faces rough
	var cb0 := rg.aabb()
	var cs := Rng32.new(int(stones[0].id) % 1000003 + 77)
	var planes := []
	for k in 7:
		var a := TAU * float(k) / 7.0 + (cs.next() - 0.5) * 0.5
		var tilt := -0.08 + cs.next() * 0.25
		planes.append([Vector3(cos(a), tilt, sin(a)).normalized(), 0.42 + cs.next() * 0.12])
	# (its top: one broad slanting break and a smaller one, as on the photo — not a dome)
	planes.append([Vector3(cs.next() - 0.5, 1.6, cs.next() - 0.5).normalized(), 0.55])
	planes.append([Vector3(cs.next() * 2.0 - 1.0, 1.0, cs.next() * 2.0 - 1.0).normalized(), 0.52])
	# the foot: two slanting breaks under it, not one sawn plane
	planes.append([Vector3(cs.next() - 0.5, -1.0, cs.next() - 0.5).normalized(), 0.6])
	planes.append([Vector3(cs.next() - 0.5, -1.0, cs.next() - 0.5).normalized() * Vector3(1.4, 1.0, 1.4), 0.66])
	var ext := Vector3(cb0.size.x, cb0.size.y, cb0.size.z) * 0.5
	for pl: Array in planes:
		var n: Vector3 = (pl[0] as Vector3).normalized()
		var reach := absf(n.x) * ext.x + absf(n.y) * ext.y + absf(n.z) * ext.z
		var d := reach * float(pl[1])
		for vi in rg.v.size():
			var t := rg.v[vi].dot(n) - d
			if t > 0.0: rg.v[vi] -= n * t
	var fn := FastNoiseLite.new()
	fn.seed = int(stones[0].id) % 9973
	fn.frequency = 3.5
	fn.fractal_octaves = 3
	for vi in rg.v.size():
		var vv := rg.v[vi]
		rg.v[vi] = vv + Vector3(fn.get_noise_3dv(vv), fn.get_noise_3dv(vv + Vector3(9, 1, 3)), fn.get_noise_3dv(vv + Vector3(2, 7, 5))) * 0.016   # (stronger, it melted the flat breaks back into a potato)
		# (and a finer, sharper one: little lumps and pits the flat shading turns into facets, as on the photo)
		rg.v[vi] += Vector3(fn.get_noise_3dv(vv * 3.4 + Vector3(4, 4, 4)), fn.get_noise_3dv(vv * 3.4 + Vector3(1, 8, 2)), fn.get_noise_3dv(vv * 3.4 + Vector3(6, 3, 9))) * 0.008
	var cut := rg.aabb().position.y + rg.aabb().size.y * 0.12
	rg.rp = rg.v.duplicate()
	var rm := SpecMat.make({col = Color(1, 1, 1), rough = 0.95, grain = 0.35, ao = 1.0, flat = true, silv = 1.0, silv_net = 1.0, micro = 0.55, silv_col = VEIN_OF.get(area_i, Vector3.ONE),
		dirt = {h = 99.0, a = 0.3, col = R.base, fr = 0.0, scan = int(RockKit.SCAN_OF[rtype])}})
	var rock_mi := SpecUtil.mesh(rg, rm, pivot)
	rock_mi.mesh = rg.to_mesh()
	# nine spots on its surface, apart from one another, not underneath
	# (none near the foot: a crystal there hung below the column's flat base)
	var low := cut + R_GEO * 0.9
	# nine crystals spread over the rock, apart from one another, each its own size (grouping them as garnets grow read
	# as a mistake: the hoard is a game's chest, not an almandine specimen — it takes only the crystal's shape)
	var pts := RockKit.surf_pts(rock_mi, 900, r32, func(pp: Vector3, nn: Vector3) -> bool: return nn.y > -0.3 and pp.y > low, pivot)
	normals.clear()
	sizes.clear()
	var n_st := stones.size()
	var fits := func(at: Vector3, sz: float) -> bool:
		for k in dirs.size():
			if dirs[k].distance_to(at) < R_GEO * (sz + float(sizes[k])) * 1.05: return false
		return true
	for pass_i in 3:
		for q: Array in pts:
			if dirs.size() >= n_st: break
			var sz := (0.62 + rng.randf() * 0.5) * (1.0 - pass_i * 0.15)
			if fits.call(q[0], sz):
				dirs.append(q[0])
				normals.append(q[1])
				sizes.append(sz)
	# (14.11, the reward should feel like treasure) nine big almandine crystals grown out of the rock: the generator's
	# own glass (light bent through them, a rainbow film, a deep wine-red body glowing a little from within). The ones
	# the lens shows burn in their rarity's colour, a light of it on the rock round them
	var hulls := []   # [the crystal's faces as planes in the rock's space, the rock's normal there]
	sinks.clear()
	for i in stones.size(): sinks.append((0.2 + rng.randf() * 0.45) * float(sizes[i % sizes.size()]))   # (of its own size)
	for i in stones.size():
		var g := Node3D.new()
		var at: Vector3 = dirs[i % dirs.size()]
		var nn: Vector3 = normals[i % normals.size()]
		var axis := nn.lerp(Vector3.UP, 0.2).normalized()
		g.position = at - nn * R_GEO * sinks[i]
		g.basis = Basis(SpecUtil.quat_to(Vector3.UP, axis)) * Basis(Vector3.UP, rng.randf() * TAU)
		pivot.add_child(g)
		var cr := Rng32.new(i * 7919 + int(stones[i].id) % 1000)
		var col := SpecMat.lin(0x4a0e18)   # (a deep, muted wine-red: a bright one read as candy)
		var glow_k := 0.08
		# (detail: faces not quite flat, as a grown crystal's are — the glass ripples what shows through)
		var cg := RockKit.crystal("dodeca", cr, {h = 1.0, cA = col, cB = col, detail = 2})
		var cb := cg.aabb()
		# (each its own size, from a small one to a big one)
		var csz := R_GEO * 1.98 * float(sizes[i % sizes.size()]) / maxf(cb.size.x, maxf(cb.size.y, cb.size.z))
		cg.translate(-cb.get_center().x, -cb.position.y - cb.size.y * 0.25, -cb.get_center().z)
		cg.scale(csz, csz, csz)
		# (a garnet's own skin: fine growth lines across the faces, a little milky in patches, a softer rainbow — glass
		# polished smooth read as red plastic)
		var cm := SpecMat.make({col = Color(1, 1, 1), flat = true, glass = true, ir = 0.03, rf = 0.14, frost = 0.16, thick = 1.25,
			st = 1.0, st_mode = 2.0, grain = 0.15, seed = float(i * 13 % 97), prio = 2, tint_body = 1.0, tint_glow = glow_k, deep_body = 1.9})
		SpecUtil.mesh(cg, cm, g)
		var hc := g.transform * cg.aabb().get_center()
		var hr := 0.0
		for p in cg.v: hr = maxf(hr, (g.transform * p).distance_to(hc))
		hulls.append([_hull(cg, g.transform), nn, hc, hr])
		if lit.has(i):
			# what the lens shows: a soft halo of its rarity's colour round it and a little of that light on the rock, as
			# the glowing mycena's — the crystal itself stays a garnet
			var rc := Data.rarity_color(int(lit[i]))
			# a thin line of its light round its foot, where it comes out of the rock (as the geodes' seam glowed)
			var rcl := rc.srgb_to_linear()
			var seam := SpecMat.make({col = rcl * 0.2, rough = 0.6, emis = rcl * 1.6})
			var ring := SpecUtil.mesh(Geo.torus(cb.size.x * csz * 0.42, R_GEO * 0.05, 6, 40).jitter(R_GEO * 0.02, 9.0, i), seam, g, Vector3(0, R_GEO * (float(sinks[i]) + 0.04), 0), Basis(Vector3.RIGHT, PI / 2))
			ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var glow := OmniLight3D.new()
			glow.light_color = rc
			# (as the geodes' was: no haze over it, the light at its foot, close on the rock, pooling round it in the
			# rarity's colour)
			glow.light_energy = 1.6
			glow.omni_range = 0.75
			glow.omni_attenuation = 1.6
			glow.position = Vector3(0, R_GEO * (float(sinks[i]) + 0.25), 0)   # (just above the rock: sunk in it, it lit nothing)
			g.add_child(glow)
			glows.append([glow, rng.randf() * TAU])
		geodes.append(g)
	# (14.11) a socket in the rock in each crystal's own shape: the rock inside a crystal (a little wider) pressed down
	# along the rock's normal to the crystal's buried faces — a faceted pit with a dark gap round the crystal, and the
	# empty socket shows when the chosen one comes out
	var gap := R_GEO * 0.06
	# (the rock is coarse for a crystal's facets: round each crystal its triangles are split, twice)
	rg.to_soup()
	var n_soup := rg.v.size()
	for lv in 1:
		var reach_k := 1.12 if lv == 0 else 1.02
		var nv := PackedVector3Array()
		var nc := PackedColorArray()
		var hc_ok := rg.col.size() == rg.v.size()
		for k in range(0, rg.v.size(), 3):
			var a := rg.v[k]
			var b := rg.v[k + 1]
			var c := rg.v[k + 2]
			var mid := (a + b + c) / 3.0
			var near := false
			for hl: Array in hulls:
				if mid.distance_to(hl[2]) < float(hl[3]) * reach_k + gap: near = true
			var ca := rg.col[k] if hc_ok else Color.WHITE
			var cbb := rg.col[k + 1] if hc_ok else Color.WHITE
			var cc := rg.col[k + 2] if hc_ok else Color.WHITE
			if not near:
				nv.append_array([a, b, c])
				nc.append_array([ca, cbb, cc])
				continue
			var ab := (a + b) * 0.5
			var bc := (b + c) * 0.5
			var ac := (c + a) * 0.5
			nv.append_array([a, ab, ac, ab, b, bc, ac, bc, c, ab, bc, ac])
			var xab := ca.lerp(cbb, 0.5)
			var xbc := cbb.lerp(cc, 0.5)
			var xac := cc.lerp(ca, 0.5)
			nc.append_array([ca, xab, xac, xab, cbb, xbc, xac, xbc, cc, xab, xbc, xac])
		rg.v = nv
		rg.col = nc
	rg.bary = PackedVector3Array()
	rg.rp = rg.v.duplicate()
	var carved := 0
	var t_sock := Time.get_ticks_msec()
	# (the crystal pressed into the rock: rock inside it laid onto its nearest face that looks into the rock — the
	# rock hugs the crystal with no room round it, meeting it on the line where the two cross; a dark seam drawn round
	# that line on the rock outside)
	var eps := R_GEO * 0.01
	var seam_w := R_GEO * 0.09
	var has_col := rg.col.size() == rg.v.size()
	for vi in rg.v.size():
		var shade := 1.0
		for hl: Array in hulls:
			var x := rg.v[vi]
			if x.distance_to(hl[2]) > float(hl[3]) + seam_w: continue
			var up: Vector3 = hl[1]
			var far := -INF
			var best_d := -INF
			var best_n := Vector3.ZERO
			for pl: Array in hl[0]:
				var pn: Vector3 = pl[0]
				var dd := pn.dot(x) - float(pl[1])
				far = maxf(far, dd)
				if pn.dot(up) < 0.25 and dd > best_d:
					best_d = dd
					best_n = pn
			if far <= 0.0 and best_n != Vector3.ZERO:
				rg.v[vi] = x + best_n * (eps - best_d)
				carved += 1
				shade = minf(shade, 0.55)
			elif far > 0.0 and far < seam_w:
				shade = minf(shade, lerpf(0.45, 1.0, far / seam_w))
		if has_col and shade < 1.0:
			var c := rg.col[vi]
			rg.col[vi] = Color(c.r * shade, c.g, c.b, c.a)
	if OS.is_debug_build() and "hoard_sel" in OS.get_cmdline_user_args(): print("SOCKET carved %d of %d (soup %d), %d ms" % [carved, rg.v.size(), n_soup, Time.get_ticks_msec() - t_sock])
	# (the rock's pattern follows the carved surface: kept from before, it was stretched down the socket's walls)
	rg.rp = rg.v.duplicate()
	rock_mi.mesh = rg.to_mesh()
	if "hoard_sel" in OS.get_cmdline_user_args(): sel = 0   # (test: the first crystal out, its socket empty)
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
		(gl[0] as OmniLight3D).light_energy = 1.3 + 0.5 * sin(t * 1.6 + float(gl[1]))
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
		if (o + dir * t - c).length() < R_GEO * 1.35 * maxf(0.6, float(sizes[i % sizes.size()])):
			best = i
			best_t = t
	if best < 0: return
	# (the chosen one tapped again goes back into its socket)
	sel = -1 if best == sel else best
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

## a convex crystal's faces as planes [normal, offset] in its parent's space (faces nearly alike merged, the outermost kept)
static func _hull(cg: Geo, xf: Transform3D) -> Array:
	var out := []
	var ctr := xf * cg.aabb().get_center()
	var soup := cg.idx.is_empty()
	for t in (cg.v.size() if soup else cg.idx.size()) / 3:
		var a := xf * cg.v[t * 3 if soup else cg.idx[t * 3]]
		var b := xf * cg.v[t * 3 + 1 if soup else cg.idx[t * 3 + 1]]
		var c := xf * cg.v[t * 3 + 2 if soup else cg.idx[t * 3 + 2]]
		var n := (b - a).cross(c - a)
		if n.length() < 1e-9: continue
		n = n.normalized()
		if n.dot(a - ctr) < 0.0: n = -n
		var d := n.dot(a)
		var found := false
		for pl: Array in out:
			if (pl[0] as Vector3).dot(n) > 0.97:
				pl[1] = maxf(float(pl[1]), d)
				found = true
				break
		if not found: out.append([n, d])
	# (closed all round by its box in its own axes: the crystal has no foot face, and an open hull took in the rock
	# all down the column under it)
	for ax: Vector3 in [xf.basis.x, -xf.basis.x, xf.basis.y, -xf.basis.y, xf.basis.z, -xf.basis.z]:
		var an := ax.normalized()
		var mx := -INF
		for p in cg.v: mx = maxf(mx, an.dot(xf * p))
		out.append([an, mx])
	return out
