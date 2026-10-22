class_name SpecLegend
extends RefCounted
## Legendary effects: every legendary find carries one, and all of them move, like a golden card.
## Some live in the shaders (lava veins, ultraviolet flashes, chameleon colour, a starry sky, opal fire,
## kintsugi gold); the rest are nodes built here (a beating heart of light, orbiting shards, frozen
## lightning, dripping lava). Turning parts are listed in the root's "anim" meta, which SpecView spins.

const FX := ["lava", "heart", "fluor", "levitate", "chameleon", "lightning", "starry", "opal", "kintsugi"]
const FX_N := {lava = "лава", heart = "сердце звезды", fluor = "флуоресценция", levitate = "левитация", chameleon = "хамелеон",
	lightning = "застывшая молния", starry = "звёздное небо", opal = "опаловый огонь", kintsugi = "кинцуги"}
const FLUOR := [Color(0.35, 1.6, 0.25), Color(1.1, 0.3, 1.8), Color(0.3, 0.9, 2.0), Color(1.8, 0.9, 0.15)]
const CHAM := [Color(0.55, 0.04, 0.12), Color(0.1, 0.5, 0.15), Color(0.6, 0.35, 0.02), Color(0.15, 0.1, 0.6)]

const GLOW := "shader_type spatial;\nrender_mode unshaded, cull_disabled;\nuniform vec3 col = vec3(1.0);\nuniform float pulse = 0.0;\nuniform float speed = 3.0;\nvoid fragment() {\n\tfloat p = 1.0 - pulse + pulse * pow(0.5 + 0.5 * sin(TIME * speed + COLOR.r * 6.0), 3.0);\n\tALBEDO = col * p;\n}\n"

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
		_over_shader = Shader.new()
		_over_shader.code = OVER
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
		_glow_shader = Shader.new()
		_glow_shader.code = GLOW
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
	var hot := Color(col.r * 2.5 + 1.0, col.g * 2.5 + 0.9, col.b * 2.5 + 0.7)
	SpecUtil.mesh(Geo.sphere(r, 16, 12), glow_mat(hot, 0.6, 2.6), main, c)
	SpecUtil.mesh(Geo.sphere(r * 1.9, 16, 12), glow_mat(hot * 0.25, 0.8, 2.6), main, c)
	var light := OmniLight3D.new()
	light.light_color = Color(col.r * 0.5 + 0.5, col.g * 0.5 + 0.5, col.b * 0.5 + 0.5)
	light.light_energy = 2.5
	light.omni_range = bb.size.length() * 1.5
	light.position = c
	main.add_child(light)
	var orbit := Node3D.new()
	orbit.position = c
	main.add_child(orbit)
	for k in 14:
		var a := k / 14.0 * TAU
		var rr := r * (2.6 + rng.next() * 1.4)
		var p := Vector3(cos(a) * rr, (rng.next() - 0.5) * r * 3.0, sin(a) * rr)
		SpecUtil.mesh(Geo.sphere(r * (0.08 + rng.next() * 0.08), 6, 4), glow_mat(hot * 1.2, 0.7, 5.0 + rng.next() * 4.0), orbit, p)
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

## a branching crack of light frozen inside the crystal, pulses running along it
static func lightning(main: Node3D, rng: Rng32) -> void:
	if not main: return
	var bb: AABB = (main.get_meta("geo") as Geo).aabb()
	var segs := []
	var grow := func(fn: Callable, p: Vector3, d: Vector3, n: int, w: float, depth: int) -> void:
		var q := p
		for i in n:
			var nd := (d + Vector3(rng.next() - 0.5, rng.next() - 0.5, rng.next() - 0.5) * 0.9).normalized()
			var e := q + nd * bb.size.y * 0.06
			e = e.clamp(bb.position + bb.size * 0.15, bb.end - bb.size * 0.15)
			segs.append([q, e, w, float(i) / n])
			if depth > 0 and rng.next() < 0.18:
				fn.call(fn, e, (nd + Vector3(rng.next() - 0.5, 0, rng.next() - 0.5)).normalized(), n / 2, w * 0.6, depth - 1)
			q = e
	var start := bb.position + Vector3(bb.size.x * 0.5, bb.size.y * 0.15, bb.size.z * 0.5)
	grow.call(grow, start, Vector3.UP, 13, 0.045 * minf(bb.size.x, bb.size.z), 2)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = Geo.cylinder(1, 1, 1, 5).translate(0, 0.5, 0).to_mesh()
	mm.instance_count = segs.size()
	for i in segs.size():
		var a: Vector3 = segs[i][0]
		var b: Vector3 = segs[i][1]
		var w: float = segs[i][2]
		mm.set_instance_transform(i, Transform3D(Basis(SpecUtil.quat_to(Vector3.UP, (b - a).normalized())) * Basis.from_scale(Vector3(w, a.distance_to(b), w)), a))
		mm.set_instance_color(i, Color(segs[i][3], 0, 0))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = over_mat(Color(0.45, 0.9, 2.6))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	main.add_child(mi)

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
