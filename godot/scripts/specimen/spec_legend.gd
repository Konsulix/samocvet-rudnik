class_name SpecLegend
extends RefCounted
## Legendary effects: every legendary find carries one, and all of them move, like a golden card.
## Some live in the shaders (lava veins, ultraviolet flashes, chameleon colour, a starry sky, opal fire,
## kintsugi gold); the rest are nodes built here (a beating heart of light, orbiting shards, frozen
## lightning, dripping lava). Turning parts are listed in the root's "anim" meta, which SpecView spins.

const FX := ["lava", "heart", "fluor", "levitate", "chameleon", "lightning", "starry", "opal", "kintsugi"]
const FX_N := {lava = "lava", heart = "star heart", fluor = "fluorescence", levitate = "levitation", chameleon = "chameleon",
	lightning = "frozen lightning", starry = "starry sky", opal = "opal fire", kintsugi = "kintsugi", dragonfire = "dragon fire",
	jellyfish = "jellyfish", discharge = "living lightning", awaken = "awakened", moon = "moon pearl"}
const FLUOR := [Color(0.35, 1.6, 0.25), Color(1.1, 0.3, 1.8), Color(0.3, 0.9, 2.0), Color(1.8, 0.9, 0.15)]
const CHAM := [Color(0.55, 0.04, 0.12), Color(0.1, 0.5, 0.15), Color(0.6, 0.35, 0.02), Color(0.15, 0.1, 0.6)]

const GLOW := "shader_type spatial;\nrender_mode unshaded, cull_disabled;\nuniform vec3 col = vec3(1.0);\nuniform float pulse = 0.0;\nuniform float speed = 3.0;\nvoid fragment() {\n\tfloat p = 1.0 - pulse + pulse * pow(0.5 + 0.5 * sin(TIME * speed + COLOR.r * 6.0), 3.0);\n\tALBEDO = col * p;\n}\n"

## the star heart: a soft additive ball whose edge fades out (a core, or a halo round it), beating
const HEART := "shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never, shadows_disabled;
uniform vec3 col = vec3(1.0);
uniform float soft = 2.0;
uniform float swell = 0.5;
global uniform float heart_beat;
void fragment() {
	float f = pow(clamp(dot(normalize(NORMAL), VIEW), 0.0, 1.0), soft);
	ALBEDO = col * f * (1.0 - swell + swell * heart_beat);
}
"
static var _heart_shader: Shader

static func heart_mat(c: Color, soft: float, swell: float) -> ShaderMaterial:
	if not _heart_shader:
		_heart_shader = ShaderFiles.get_shader("legend_heart", HEART)
	var m := ShaderMaterial.new()
	m.shader = _heart_shader
	m.set_shader_parameter("col", Vector3(c.r, c.g, c.b))
	m.set_shader_parameter("soft", soft)
	m.set_shader_parameter("swell", swell)
	m.render_priority = 100
	return m

## the heart's colour: the opposite hue to the crystal, fully saturated, so it never melts into the stone;
## a colourless crystal gets a deep crimson. Linear, HDR-bright but short of white.
static func heart_color(col: Color) -> Color:
	var c := col.linear_to_srgb()
	var hc := Color.from_hsv(fposmod(c.h + 0.5, 1.0), 0.92, 1.0) if c.s > 0.2 else Color.from_hsv(0.985, 0.9, 1.0)
	return hc.srgb_to_linear()

static var _glow_shader: Shader
static var _over_shader: Shader
const OVER := "shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_test_disabled, depth_draw_never;
uniform vec3 col = vec3(1.0);
uniform float speed = 7.0;
void fragment() {
	float run = pow(0.5 + 0.5 * sin(TIME * speed - COLOR.r * 14.0), 6.0);
	float flick = 0.6 + 0.4 * step(0.35, fract(sin(floor(TIME * 9.0) * 12.9898) * 43758.5));
	ALBEDO = col * (0.35 + 1.6 * run) * flick;
}
"

## glowing light drawn over the glass (not seen through it), so it keeps its brightness and blooms
static func over_mat(c: Color, speed := 7.0) -> ShaderMaterial:
	if not _over_shader:
		_over_shader = ShaderFiles.get_shader("legend_over", OVER)
	var m := ShaderMaterial.new()
	m.shader = _over_shader
	m.set_shader_parameter("col", Vector3(c.r, c.g, c.b))
	m.set_shader_parameter("speed", speed)
	m.render_priority = 100
	return m

static func shader_params(fx: String, rng_v: float) -> Dictionary:
	match fx:
		"fluor": return {fluor = 1.0, fluor_col = FLUOR[int(rng_v * FLUOR.size())]}
		"chameleon": return {cham = 1.0, cham_col = CHAM[int(rng_v * CHAM.size())]}
		"starry": return {star = 1.0}
		"opal": return {opal = 1.0}
		"kintsugi": return {kin = 1.0}
	return {}

## an unlit glowing material; pulse > 0 makes it throb (phase from the vertex/instance colour's red)
static func glow_mat(c: Color, pulse := 0.0, speed := 3.0) -> ShaderMaterial:
	if not _glow_shader:
		_glow_shader = ShaderFiles.get_shader("legend_glow", GLOW)
	var m := ShaderMaterial.new()
	m.shader = _glow_shader
	m.set_shader_parameter("col", Vector3(c.r, c.g, c.b))
	m.set_shader_parameter("pulse", pulse)
	m.set_shader_parameter("speed", speed)
	return m

static func _anim(root: Node3D, n: Node3D, ax: String, v: float) -> void:
	var a: Array = root.get_meta("anim", [])
	a.append([n, ax, v])
	root.set_meta("anim", a)

## a heart of light inside the main crystal: a throbbing core, a real light, sparks circling it
static func heart(root: Node3D, main: Node3D, rng: Rng32, col: Color) -> void:
	if not main: return
	var bb: AABB = (main.get_meta("geo") as Geo).aabb()
	var c := bb.get_center() + Vector3(0, bb.size.y * 0.05, 0)
	var r := minf(bb.size.x, bb.size.z) * 0.22
	var hc := heart_color(col)
	# a hot core, a wide halo round it; both additive with soft edges, both beating with the light
	SpecUtil.mesh(Geo.sphere(r, 24, 16), heart_mat(hc * 3.0, 1.2, 0.45), main, c)
	SpecUtil.mesh(Geo.sphere(r * 3.2, 24, 16), heart_mat(hc * 0.8, 2.6, 0.7), main, c)
	var light := OmniLight3D.new()
	light.light_color = hc.linear_to_srgb()
	light.light_energy = 2.0
	light.omni_range = bb.size.length() * 1.5
	light.position = c
	main.add_child(light)
	root.set_meta("heart_light", light)
	var orbit := Node3D.new()
	orbit.position = c
	main.add_child(orbit)
	for k in 14:
		var a := k / 14.0 * TAU
		var rr := r * (2.6 + rng.next() * 1.4)
		var p := Vector3(cos(a) * rr, (rng.next() - 0.5) * r * 3.0, sin(a) * rr)
		SpecUtil.mesh(Geo.sphere(r * (0.08 + rng.next() * 0.08), 6, 4), glow_mat(hc * 2.0, 0.7, 5.0 + rng.next() * 4.0), orbit, p)
	_anim(root, orbit, "y", 1.3)

## shards of the crystal drifting round it on slow orbits
static func levitate(root: Node3D, _mat: Material, rng: Rng32, habit: String, zcfg: Dictionary) -> void:
	# shards of clean glass: no rock clings to them
	var mat := SpecMat.make({col = Color(1, 1, 1), flat = true, glass = true, frost = 0.15, holo = 0.6, seed = rng.next() * 40.0, prio = 2})
	var bb := SpecUtil.box_of(root)
	var c := bb.get_center()
	var R := maxf(bb.size.x, bb.size.z) * 0.55 + 0.15
	for ring in 2:
		var orbit := Node3D.new()
		orbit.position = c
		orbit.rotation = Vector3((rng.next() - 0.5) * 0.6, 0, (rng.next() - 0.5) * 0.6)
		root.add_child(orbit)
		var n := 3 + int(rng.next() * 3)
		for k in n:
			var cfg := {h = 0.3 + rng.next() * 0.3, tip = null, detail = 1}
			cfg.merge(zcfg)
			var g := RockKit.crystal(habit, rng, cfg)
			var a := float(k) / n * TAU + rng.next() * 0.6
			var rr := R * (0.85 + ring * 0.35 + rng.next() * 0.15)
			var p := Vector3(cos(a) * rr, (rng.next() - 0.5) * bb.size.y * 0.5, sin(a) * rr)
			var s := 0.35 + rng.next() * 0.3
			SpecUtil.mesh(g, mat, orbit, p, SpecUtil.eul(rng.next() * 6, rng.next() * 6, rng.next() * 6) * Basis.from_scale(Vector3.ONE * s))
		_anim(root, orbit, "y", (0.35 + rng.next() * 0.25) * (1.0 if ring == 0 else -1.0))

## lightning trapped inside the crystal: it strikes, flickers and strikes again along a new path
static func lightning(main: Node3D, rng: Rng32) -> void:
	if not main: return
	var bb: AABB = (main.get_meta("geo") as Geo).aabb()
	var g: Geo = main.get_meta("geo")
	var surf := PackedVector3Array()
	for i in range(0, g.v.size(), maxi(1, g.v.size() / 300)):
		if g.v[i].y > bb.position.y + bb.size.y * 0.2:
			surf.append(g.v[i])
	var bolt := SpecBolt.new()
	main.add_child(bolt)
	# a storm in the glass: the crystal turns smoky blue-violet so the lightning stands out
	if main is MeshInstance3D and (main as MeshInstance3D).material_override is ShaderMaterial:
		var gm := ((main as MeshInstance3D).material_override as ShaderMaterial).duplicate() as ShaderMaterial
		gm.set_shader_parameter("smoke_k", 1.0)
		gm.set_shader_parameter("smoke_col", Vector3(0.06, 0.07, 0.16))
		gm.set_shader_parameter("frost_k", 0.15)
		(main as MeshInstance3D).material_override = gm
		bolt.glass = gm
	bolt.setup(bb, int(rng.next() * 100000), Color(0.55, 0.65, 3.4), surf)

## lava: the rock's own material glows (shader); here drops of lava swell and fall from its underside,
## and embers rise
static func lava(root: Node3D, rock: MeshInstance3D) -> void:
	if not rock: return
	var g: Geo = rock.get_meta("geo")
	var bb := g.aabb()
	var low := PackedVector3Array()
	for p in g.v:
		if p.y < bb.position.y + bb.size.y * 0.3 and low.size() < 400:
			low.append(p)
	var drips := CPUParticles3D.new()
	drips.amount = 14
	drips.lifetime = 2.4
	drips.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINTS
	drips.emission_points = low
	drips.direction = Vector3.DOWN
	drips.spread = 5
	drips.gravity = Vector3(0, -1.6, 0)
	drips.initial_velocity_min = 0.0
	drips.initial_velocity_max = 0.05
	drips.local_coords = true
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.2))
	curve.add_point(Vector2(0.25, 1.0))
	curve.add_point(Vector2(1, 0.5))
	drips.scale_amount_curve = curve
	drips.scale_amount_min = 0.03
	drips.scale_amount_max = 0.05
	var dm := SphereMesh.new()
	dm.radius = 0.5
	dm.height = 1.6
	dm.material = glow_mat(Color(3.5, 1.1, 0.15))
	drips.mesh = dm
	root.add_child(drips)
	var embers := CPUParticles3D.new()
	embers.amount = 30
	embers.lifetime = 2.0
	embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	embers.emission_box_extents = bb.size * 0.45
	embers.position = bb.get_center()
	embers.direction = Vector3.UP
	embers.spread = 35
	embers.gravity = Vector3(0, 0.25, 0)
	embers.initial_velocity_min = 0.1
	embers.initial_velocity_max = 0.3
	embers.scale_amount_min = 0.008
	embers.scale_amount_max = 0.018
	embers.local_coords = true
	var em := SphereMesh.new()
	em.radius = 0.5
	em.height = 1.0
	em.radial_segments = 6
	em.rings = 3
	em.material = glow_mat(Color(4.0, 1.5, 0.3))
	embers.mesh = em
	root.add_child(embers)
