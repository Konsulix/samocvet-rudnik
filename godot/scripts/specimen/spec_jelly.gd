class_name SpecJelly
extends RefCounted
## The legendary "jellyfish": three small glowing jellyfish drifting round the find on an imaginary sphere, each on
## its own tilted orbit. A bell with a scalloped rim that contracts and relaxes (a pulse, every jelly its own rhythm),
## frilly oral arms and long thin tentacles trailing behind, swaying. Drawn additive and unshaded: they glow, and
## the stone shows through them. All the motion is in the shader except the orbits (the view turns their pivots).

const U := preload("res://scripts/specimen/spec_util.gd")

const SHADER := "shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform vec3 col = vec3(0.4, 0.8, 1.0);
uniform float phase = 0.0;
uniform float speed = 0.6;     // beats per second
uniform int part = 0;          // 0 the bell, 1 an oral arm, 2 a tentacle, 3 the bell's inner layer, 4 its halo
uniform float seed = 0.0;      // each jelly's own crooked rim and skin
varying float v_d;
varying vec3 v_l;

float h3(vec3 p) { p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float vn(vec3 x) {
	vec3 i = floor(x), f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h3(i), h3(i + vec3(1, 0, 0)), f.x), mix(h3(i + vec3(0, 1, 0)), h3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(h3(i + vec3(0, 0, 1)), h3(i + vec3(1, 0, 1)), f.x), mix(h3(i + vec3(0, 1, 1)), h3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

// one swim stroke: a quick contraction (the first fifth), then a long slow relaxation
float beat(float u) {
	return u < 0.2 ? sin(u / 0.2 * 1.5708) : pow(1.0 - (u - 0.2) / 0.8, 2.0);
}
// how far ahead of its steady drift the jelly is: it shoots forward on the stroke, then glides and falls back
float surge(float u) {
	float e = 1.0 - pow(1.0 - min(u / 0.35, 1.0), 3.0);
	return e - u;
}

void vertex() {
	v_l = VERTEX;
	float u = fract(TIME * speed + phase);
	float c = beat(u);
	float sg = surge(u) * 0.55;
	if (part == 4) {
		VERTEX *= 1.0 + 0.06 * c;
	} else if (part == 0 || part == 3) {
		// the bell: the rim pulls in hard and the dome rises as it beats; the rim wavers, unevenly, like soft jelly
		float low = 1.0 - clamp(VERTEX.y / 0.62, 0.0, 1.0);
		float a = atan(VERTEX.z, VERTEX.x);
		float wob = (vn(vec3(a * 2.0, seed, TIME * 0.3)) - 0.5) * 0.12 + (vn(vec3(a * 6.0, seed + 3.0, TIME * 0.5)) - 0.5) * 0.05;
		VERTEX.xz *= (1.0 - 0.3 * c * low * low) * (1.0 + wob * low * low);
		VERTEX.y *= 1.0 + 0.14 * c;
		VERTEX.y += wob * low * low * 0.4;
	} else {
		float d = -VERTEX.y;
		// tentacle tips curl a little (tentacles are a bit stiffer near the bell)
		float curl = smoothstep(0.6, 1.0, d / max(UV.y, 0.01)) * (part == 2 ? 0.08 : 0.0);
		VERTEX.x += sin(d * 9.0 + seed) * curl;
		VERTEX.z += cos(d * 9.0 + seed) * curl;
		// trailing behind: pulled straight and long on the stroke, drifting open and curling in the glide,
		// a wave running down from the bell to the tips
		float open = 1.0 - 0.65 * c;
		float k = (part == 1 ? 0.14 : 0.22) * open;
		float w = TIME * 2.2 - d * 2.6 + phase * 6.0;
		VERTEX.x += sin(w) * k * d + sin(w * 1.7 + 1.0) * 0.03 * d;
		VERTEX.z += cos(w * 0.8 + 2.0) * k * d;
		VERTEX.xz *= mix(1.0, 0.55, c * exp(-d * 1.5));
		VERTEX.y -= c * 0.18 * d;
		if (part == 1) {
			// frilly arms: their edges ripple
			VERTEX.xz += vec2(sin(d * 14.0 + TIME * 3.0), cos(d * 11.0 + TIME * 2.4)) * 0.025;
		}
		v_d = d;
	}
	VERTEX.y += sg;
}

void fragment() {
	float fr = 1.0 - abs(dot(normalize(NORMAL), VIEW));
	float u = fract(TIME * speed + phase);
	float glow = 0.8 + 0.45 * beat(u);
	vec3 c;
	if (part == 0) {
		float r = length(v_l.xz) / 0.6;
		float a = atan(v_l.z, v_l.x);
		// four horseshoe gonads round the middle, brighter and warmer
		float gon = 0.0;
		for (int k = 0; k < 4; k++) {
			float ak = 0.785 + float(k) * 1.5708;
			vec2 cen = vec2(cos(ak), sin(ak)) * 0.2;
			float rr = length(v_l.xz / 0.6 - cen);
			gon = max(gon, exp(-pow((rr - 0.12) / 0.035, 2.0)) * smoothstep(0.0, 0.08, rr));
		}
		// radial canals from the middle to the rim, a ring canal at the rim
		// (soft and wavering, fading in from the middle: veins, not wheel spokes)
		float canals = pow(abs(cos(a * 8.0 + sin(r * 9.0) * 0.12)), 30.0) * smoothstep(0.3, 0.6, r) * (0.5 + 0.5 * vn(v_l * 12.0));
		float ring = exp(-pow((r - 0.93) / 0.03, 2.0));
		// the jelly itself: a faint grain, clear in the middle, bright at the edges seen side-on
		float grain = 0.75 + 0.5 * vn(v_l * 40.0);
		// little bulbs along the rim where the tentacles hang
		float bulbs = pow(max(0.0, cos(a * 12.0)), 8.0) * smoothstep(0.85, 0.98, r) * (1.0 - smoothstep(0.12, 0.2, v_l.y));
		vec3 warm = mix(col, vec3(1.4, 0.7, 0.9), 0.45);
		// skin: a fine net of soft cells, seen where the bell turns side-on, and a wet glint
		vec3 q = v_l * 34.0 + seed;
		vec3 cell = floor(q);
		float dm = 9.0;
		for (int z = -1; z <= 1; z++) for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
			vec3 g = cell + vec3(float(x), float(y), float(z));
			dm = min(dm, length(g + vec3(h3(g), h3(g + 3.0), h3(g + 7.0)) - q));
		}
		float skin = smoothstep(0.35, 0.75, dm);
		float glint = pow(max(0.0, dot(reflect(-VIEW, normalize(NORMAL)), normalize(vec3(-0.4, 0.8, 0.5)))), 24.0);
		float face = 1.0 - fr;
		c = col * (0.01 + 0.55 * pow(fr, 2.5) * (0.7 + 0.5 * skin)) * grain;
		c += vec3(1.0) * glint * 0.25;
		gon *= 1.0 + 1.4 * face * face;
		canals *= 1.0 + 1.8 * face * face;
		c += warm * gon * 0.45 + col * canals * 0.15 + col * ring * 0.35 + warm * bulbs * 0.5;
		c *= glow;
	} else if (part == 4) {
		// light scattered in the water round it: soft, uneven, drifting and flickering
		float f = abs(dot(normalize(NORMAL), VIEW));
		vec3 q = v_l * 2.5 + vec3(seed, TIME * 0.25, TIME * 0.17);
		float n = vn(q) * 0.6 + vn(q * 2.3 + 5.0) * 0.4;
		float flick = 0.85 + 0.15 * sin(TIME * 7.0 + seed) * sin(TIME * 3.1 + seed * 2.0);
		c = col * 0.09 * pow(f, 1.6) * smoothstep(0.25, 0.85, n) * flick * glow;
	} else if (part == 3) {
		// the inner layer, seen through the jelly: a softer, warmer glow, so the bell has a thickness
		c = mix(col, vec3(1.2, 0.8, 1.0), 0.3) * (0.03 + 0.22 * pow(fr, 1.6)) * glow;
	} else if (part == 1) {
		c = mix(col, vec3(1.3, 0.75, 0.95), 0.3) * (0.16 + 0.3 * fr) * exp(-v_d * 0.7) * glow * (0.7 + 0.5 * vn(v_l * 30.0));
	} else {
		// fine tentacles, beaded with stinging cells
		float beads = 0.8 + 0.25 * pow(0.5 + 0.5 * sin(v_d * 60.0), 4.0);
		// thicker and thinner along it
		beads *= 0.7 + 0.6 * vn(vec3(v_d * 5.0, seed + v_l.x * 30.0, 0.0));
		c = col * 0.35 * exp(-v_d * 0.8) * glow * beads;
	}
	ALBEDO = c;
}
"

static var _shader: Shader

static func material(c: Color, part: int, phase: float, speed: float, seed := 0.0) -> ShaderMaterial:
	if not _shader:
		_shader = ShaderFiles.get_shader("jelly", SHADER)
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("col", Vector3(c.r, c.g, c.b))
	m.set_shader_parameter("part", part)
	m.set_shader_parameter("phase", phase)
	m.set_shader_parameter("seed", seed)
	m.set_shader_parameter("speed", speed)
	m.render_priority = 100
	return m

## a ribbon hanging down from `top`, `len` long, `w` wide, twisting as it goes (a thin strip of quads)
static func _ribbon(top: Vector3, len: float, w: float, twist: float, n: int, rng: Rng32 = null) -> Geo:
	var g := Geo.new()
	var ph := rng.next() * 10.0 if rng else 0.0
	for i in n + 1:
		var t := float(i) / n
		var a := twist * t
		# tapering to the tip, swelling and thinning along the way
		var wv := 1.0 + 0.45 * sin(t * 13.0 + ph) * sin(t * 5.0 + ph * 0.7)
		var side := Vector3(cos(a), 0, sin(a)) * w * (1.0 - t * 0.8) * 0.5 * wv
		var p := top + Vector3(0, -len * t, 0)
		g.v.append(p - side)
		g.v.append(p + side)
		g.rp.append(Vector3(0, len, 0))
		g.rp.append(Vector3(0, len, 0))
		g.col.append(Color(1, 1, 1, 1))
		g.col.append(Color(1, 1, 1, 1))
	for i in n:
		var p0 := i * 2
		g.idx.append_array([p0, p0 + 1, p0 + 2, p0 + 2, p0 + 1, p0 + 3])
	return g

## one jellyfish, its bell's axis along +Y, one unit across
static func jelly(parent: Node3D, rng: Rng32, c: Color, phase: float) -> Node3D:
	var j := Node3D.new()
	parent.add_child(j)
	var speed := 0.5 + rng.next() * 0.25
	var bell := Geo.lathe([Vector2(0.0, 0.62), Vector2(0.15, 0.615), Vector2(0.28, 0.59), Vector2(0.38, 0.55), Vector2(0.46, 0.48),
		Vector2(0.52, 0.4), Vector2(0.56, 0.3), Vector2(0.59, 0.2), Vector2(0.6, 0.1), Vector2(0.6, 0.03), Vector2(0.56, 0.0),
		Vector2(0.45, 0.04), Vector2(0.25, 0.1), Vector2(0.0, 0.13)], 48)
	var sd := rng.next() * 50.0
	U.mesh(bell, material(c, 0, phase, speed, sd), j)
	# the subumbrella: a slightly smaller, thinner bell inside, so the jelly has a thickness
	var inner := Geo.lathe([Vector2(0.0, 0.5), Vector2(0.2, 0.48), Vector2(0.36, 0.42), Vector2(0.46, 0.3), Vector2(0.52, 0.15),
		Vector2(0.53, 0.05)], 40)
	U.mesh(inner, material(c, 3, phase, speed, sd), j)
	U.mesh(Geo.sphere(1.25, 24, 16), material(c, 4, phase, speed, sd), j, Vector3(0, 0.2, 0))
	# four frilly oral arms from the middle, a ring of fine tentacles from the rim
	for k in 4:
		var a := k * TAU / 4.0 + rng.next() * 0.4
		U.mesh(_ribbon(Vector3(cos(a), 0, sin(a)) * 0.08 + Vector3(0, 0.05, 0), 0.8 + rng.next() * 0.6, 0.1 + rng.next() * 0.08, 5.0 + rng.next() * 3.0, 20, rng),
			material(c, 1, phase, speed, sd), j)
	for k in 24:
		var a := k * TAU / 24.0
		# long and short ones, thick and fine
		var ln := (1.0 + rng.next() * 1.4) * (0.45 if rng.next() < 0.3 else 1.0)
		U.mesh(_ribbon(Vector3(cos(a), 0, sin(a)) * 0.55, ln, 0.008 + rng.next() * 0.012, 0.0, 24, rng), material(c, 2, phase, speed, sd + k), j)
	# not part of the stone: the studio frames the find without them (it sizes by the meshes that carry "geo")
	for m in j.get_children():
		m.remove_meta("geo")
	return j

const COLS := [Color(0.35, 0.85, 1.4), Color(1.3, 0.45, 1.1), Color(1.3, 0.85, 0.35), Color(0.5, 1.3, 0.7), Color(0.75, 0.6, 1.5)]

## three jellyfish on tilted orbits round the find (its box at the time), swimming bell first
static func swarm(root: Node3D, rng: Rng32) -> void:
	var bb := U.box_of(root)
	var c := bb.get_center()
	# close round it: the view frames the stone alone, so wider orbits would leave the picture
	var R := bb.size.length() * 0.4
	var hue0 := int(rng.next() * COLS.size())
	root.set_meta("dark", true)
	var n := 1 + int(rng.next() * 5)
	for k in n:
		# an outer pivot slowly tipping the orbit's plane, an inner one carrying the jelly round: it wanders the sphere
		var tilt := Node3D.new()
		tilt.position = c
		tilt.rotation = Vector3(rng.next() * TAU, rng.next() * TAU, rng.next() * TAU)
		root.add_child(tilt)
		var orbit := Node3D.new()
		orbit.rotation.y = k * TAU / n + rng.next() * 0.5
		tilt.add_child(orbit)
		var col: Color = COLS[(hue0 + k * 2) % COLS.size()]
		var j := jelly(orbit, rng, col, rng.next() * TAU)
		# one big jelly on a wider orbit (it passes near the eye and shows its detail), two small ones further in
		var big := k == 0
		var s := R * (0.27 if big else 0.13 + rng.next() * 0.04)
		var rr := R * (1.05 if big else 0.9 + rng.next() * 0.1)
		# at +X on the orbit, moving towards -Z as the pivot turns: the bell's top faces the way it swims
		j.transform = Transform3D(Basis(Vector3.RIGHT, -PI / 2) * Basis.from_scale(Vector3.ONE * s), Vector3(rr, 0, 0))
		# its own light: the stone takes its colour as it swims by
		var lt := OmniLight3D.new()
		lt.light_color = Color(col.r, col.g, col.b).clamp(Color(0, 0, 0), Color(1, 1, 1))
		lt.light_energy = (2.2 if big else 1.3) * (1.0 if n <= 2 else 2.5 / n)
		lt.omni_range = R * (1.5 if big else 1.0)
		lt.omni_attenuation = 1.5
		lt.position = Vector3(rr, 0, 0)
		orbit.add_child(lt)
		SpecLegend._anim(root, orbit, "y", 0.25 + rng.next() * 0.15)
		SpecLegend._anim(root, tilt, "x" if k % 2 == 0 else "z", 0.06 + rng.next() * 0.05)
