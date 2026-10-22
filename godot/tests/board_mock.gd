extends Node
## A look test for the board, built from the specimen generator: a 3D basalt slab with shallow
## pockets, and in each pocket a small lying crystal in the generator's real glass. Six piece kinds,
## told apart by silhouette and colour; every piece is its own little crystal.
##   -- shot=user://mock.png after=3   palette=0|1

const COLS := [
	[Color("#e6ecf2"), "prism"],    # clear quartz: a lying hexagonal prism
	[Color("#9a63e8"), "octa"],     # violet: an octahedron, a diamond from above
	[Color("#f0a330"), "cube"],     # amber: a slightly tilted cube
	[Color("#2dbfa6"), "pebble"],   # teal: a tumbled, rounded stone
	[Color("#e2583b"), "tri"],      # coral: a trigonal pyramid
	[Color("#3d4452"), "tablet"],   # graphite: a hexagonal tablet
]
const R := 9
const C := 8

var vp: SubViewport

func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var cont := SubViewportContainer.new()
	cont.stretch = true
	cont.size = get_viewport().get_visible_rect().size
	add_child(cont)
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	cont.add_child(vp)
	set_meta("scan", int(args.get("scan", "3")))
	_studio()
	_slab()
	var rng := Rng32.new(int(args.get("seed", "5")))
	for r in R:
		for c in C:
			var t := int(rng.next() * COLS.size())
			_piece(t, Vector3(c - C / 2.0 + 0.5, 0, r - R / 2.0 + 0.5), rng)
	if args.has("shot"):
		await get_tree().create_timer(float(args.get("after", "3"))).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(args.shot)
		get_tree().quit()

func _studio() -> void:
	var env := Environment.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = preload("res://shaders/studio_sky.gdshader")
	sky_mat.set_shader_parameter("hdri", load("res://assets/hdri/studio_small_09_1k.hdr"))
	sky_mat.set_shader_parameter("hdri_k", 1.0)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.022, 0.026)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.2
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	env.ssao_enabled = false
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = R + 1.2
	cam.environment = env
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(0, 12, 0), Vector3.ZERO, Vector3(0, 0, -1))
	var key := DirectionalLight3D.new()
	key.light_color = Color("#fff0dc")
	key.light_energy = 1.5
	key.shadow_enabled = true
	key.shadow_blur = 2.5
	key.directional_shadow_max_distance = 30.0
	vp.add_child(key)
	key.look_at_from_position(Vector3(-4, 7, -5), Vector3.ZERO)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color("#8fb8ff")
	rim.light_energy = 0.6
	vp.add_child(rim)
	rim.look_at_from_position(Vector3(5, 3, 4), Vector3.ZERO)

## the tray: one basalt slab, a shallow pocket for every cell
func _slab() -> void:
	var g := Geo.box(C + 0.5, 0.4, R + 0.5).translate(0, -0.2, 0)
	g.subdivide(5)
	for i in g.v.size():
		var p := g.v[i]
		if p.y > -0.01:
			var cx := p.x + C / 2.0
			var cz := p.z + R / 2.0
			var fx := absf(fposmod(cx, 1.0) - 0.5)
			var fz := absf(fposmod(cz, 1.0) - 0.5)
			var inside: bool = cx > 0 and cx < C and cz > 0 and cz < R
			if inside and maxf(fx, fz) < 0.43:
				p.y -= 0.05
			g.v[i] = p
	g.col.resize(g.v.size())
	g.col.fill(Color(1, 1, 1))
	g.rp = g.v.duplicate()
	for i in g.rp.size(): g.rp[i] = g.rp[i] * 0.45
	var m := SpecMat.make({col = Color(1, 1, 1), rough = 0.85, flat = true,
		dirt = {h = 99.0, a = 0.3, col = SpecMat.lin(0x1c1e23), fr = 0.0, scan = int(get_meta("scan", 2))}})
	var mi := MeshInstance3D.new()
	mi.mesh = g.to_mesh()
	mi.material_override = m
	vp.add_child(mi)

func _piece(t: int, at: Vector3, rng: Rng32) -> void:
	var col: Color = (COLS[t][0] as Color).srgb_to_linear()
	var kind: String = COLS[t][1]
	var g: Geo
	var basis := Basis.IDENTITY
	match kind:
		"prism":
			g = RockKit.prism(rng, {sides = 6, w = 0.2, d = 0.2, h = 0.28, point = true, slope = 0.0, taper = 1.0, y0 = -0.36, detail = 1}, {cA = col, cB = col, zk = 0.0})
			basis = Basis(Vector3.BACK, PI / 2) * Basis(Vector3.UP, PI / 6)
			basis = Basis(Vector3.UP, PI / 2 + (rng.next() - 0.5) * 0.25) * basis
		"octa":
			g = Geo.octa(0.36).scale(0.85, 0.75, 1.0)
		"cube":
			g = Geo.box(0.5, 0.5, 0.5)
			basis = Basis(Vector3.UP, (rng.next() - 0.5) * 0.3) * Basis(Vector3.RIGHT, 0.12)
		"pebble":
			g = Geo.icosa(0.3, 2).scale(1.15, 0.55, 0.95)
		"tri":
			g = Geo.cone(0.4, 0.45, 3).translate(0, 0.0, 0)
			basis = Basis(Vector3.UP, PI + (rng.next() - 0.5) * 0.2)
		_:
			g = Geo.cylinder(0.3, 0.37, 0.18, 6)
			basis = Basis(Vector3.UP, (rng.next() - 0.5) * 0.3) * Basis(Vector3.RIGHT, 0.15)
	var k: float = {prism = 1.0, octa = 1.35, cube = 1.35, pebble = 1.35, tri = 1.9, tablet = 1.3}[kind]
	g.scale(k, k, k)
	g.to_soup()
	g.fill_color(col)
	g.mark_edges()
	g.subdivide(1)
	g.jitter(0.015, 5.0, int(rng.next() * 100000))
	# the generator's glass, with the stone's own colour glowing softly in its body
	var m := SpecMat.make({col = Color(1, 1, 1), flat = kind != "pebble", glass = true, frost = 0.25 + rng.next() * 0.15,
		holo = 0.08, thick = 1.4, seed = rng.next() * 50.0, prio = 2, emis = col * (0.04 if t == 5 else 0.16),
		smoke = 0.8 if t == 5 else 0.0, smoke_col = Color(0.05, 0.055, 0.07)})
	var mi := MeshInstance3D.new()
	mi.mesh = g.to_mesh()
	mi.material_override = m
	var bb := g.aabb()
	mi.transform = Transform3D(basis, at + Vector3(0, -0.05 - (basis * bb.position).y * 0.0 + 0.12, 0))
	vp.add_child(mi)
