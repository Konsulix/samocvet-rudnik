shader_type spatial;
// The film of a fossil leaf on its split slab (SpecFern): a frond of pinnules, ginkgo fans, dawn-redwood sprigs, a
// horsetail, a palm fan, Annularia's star whorls or a strip of scale-tree bark — and now and then a dragonfly or a little
// fish beside them — laid flat a hair above the stone. Flat in the mesh, in RELIEF here: every part has its own height
// (a domed pinnule with its veins pressed in, a creased palm segment, the cushions of the bark), and the normal follows
// it, so as the slab rocks the light rakes across the leaf and it comes up off the stone. The counterpart is the same
// relief turned inside out.
// UV.x runs along a blade from its base to its tip, UV.y across it (-1..1); UV2.x is how far along the whole plant (0 at
// its base), for the legendary wave; COLOR.r 1 = stem, COLOR.g a random per blade, COLOR.b the part (x10):
// 0 blade, 3 palm segment, 4 insect body, 5 fan (ginkgo, a fin, the tail), 7 bark (UV in cushion units), 8 wing, 9 fish.
// film: 0 carbon (glossy black on grey mudstone), 1 pyrite (gold, glittering), 2 silver (pale pyrophyllite on black
// shale), 3 iron (rusty orange on buff stone), 4 cast (the stone itself, only the relief), 5 kaolinite (chalk-white on a
// rusty nodule), 6 brown (Green River: dark brown on cream limestone), 7 nacre (the leaf turned to ammolite: plates of
// thin-film fire on a dark film), 8 opal (the leaf replaced by precious opal, its play of colour sliding as it turns).
render_mode cull_disabled;

uniform vec3 film_col : source_color = vec3(0.1, 0.09, 0.08);
uniform vec3 stone_col : source_color = vec3(0.55, 0.52, 0.48);
uniform int film = 0;
uniform float mould = 0.0;
uniform float spring = 0.0;    // the legendary "spring": light runs up the veins and the leaf greens as if alive
uniform float seed = 0.0;
uniform float relief = 1.0;
uniform float fire_h = 0.3;     // nacre and opal: the main colour of the fire (0 red .. 1 violet)

varying vec3 v_op;
varying vec3 v_cam;

#include "res://shaders/opal.gdshaderinc"

// the distance to the nearest cell wall of a jittered grid (a wing's net of veins)
float cells(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	float d1 = 9.0, d2 = 9.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 o = vec2(float(x), float(y));
			vec2 c = o + vec2(h3(vec3(i + o, 3.1)), h3(vec3(i + o, 7.7))) * 0.8 + 0.1;
			float d = length(c - f);
			if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
		}
	}
	return d2 - d1;
}
float line(float x, float w) { return 1.0 - smoothstep(0.0, w, abs(fract(x) - 0.5) * 2.0); }

void vertex() {
	v_op = VERTEX;
	v_cam = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
}

void fragment() {
	// the film is flat: its normal is the leaf's own up, turned to face the eye. Not trusted to the face's winding — the
	// counterpart is mirrored, and on iPhone (Metal) one of the two halves came out back-facing, lit from below, black.
	vec3 up = normalize((VIEW_MATRIX * (MODEL_MATRIX * vec4(0.0, 1.0, 0.0, 0.0))).xyz);
	vec3 n = dot(up, VIEW) < 0.0 ? -up : up;
	float stem = step(0.5, COLOR.r);
	int part = int(COLOR.b * 10.0 + 0.5);
	// (scale-tree bark is a trunk lying in the rock: its own round normal)
	if (part == 7) n = normalize(dot(NORMAL, VIEW) < 0.0 ? -NORMAL : NORMAL);
	float ay = abs(UV.y);
	float rnd = COLOR.g;
	// --- the relief: h the height (0..~1), marks the dark lines and spots drawn into the film, amp its height in model units
	float h = 0.0;
	float marks = 0.0;
	float amp = 0.004;
	float edge = 0.0;
	float wing = 0.0;
	if (stem > 0.5) {
		// a stem: round, with fine ribs along it (a horsetail's broad stem shows them well)
		h = sqrt(max(0.0, 1.0 - ay * ay)) * 0.85 + 0.08 * cos(UV.y * 9.0);
		marks = 0.15 * line(UV.y * 2.0 + 0.5, 0.25);
		amp = 0.005;
	} else if (part == 2) {
		// a whole pinna (Mazon Creek style): one ribbon, its margin cut into rounded lobes — the pinnules grown together —
		// each lobe domed with its own little midvein, the pinna's midrib pressed in down the middle
		float nl = max(COLOR.a * 64.0, 1.0);
		float lob = fract(UV.x * nl);
		float prof = 0.5 + 0.5 * pow(sin(3.14159 * lob), 0.6);
		if (ay > prof) discard;
		float yl = ay / prof;
		float mid = 1.0 - smoothstep(0.0, 0.1, ay);
		float lv = (1.0 - smoothstep(0.0, 0.06, abs(lob - 0.5 - 0.15 * yl))) * smoothstep(0.1, 0.25, ay) * (1.0 - smoothstep(0.8, 1.0, yl));
		float sinus = 1.0 - smoothstep(0.0, 0.08, min(lob, 1.0 - lob));
		h = sqrt(max(0.0, 1.0 - yl * yl)) * (0.55 + 0.25 * sin(3.14159 * lob)) - 0.35 * mid - 0.15 * sinus * yl;
		marks = max(mid * 0.9, max(lv * 0.6, sinus * smoothstep(0.3, 0.6, yl) * 0.5));
		edge = smoothstep(0.82, 1.0, yl) * 0.5;
		amp = 0.0035;
	} else if (part == 3) {
		// a palm segment: folded along its middle like a pleat, finely striate, the edges thin
		h = (1.0 - ay) * 0.9;
		marks = 0.3 * line(UV.y * 1.5 + 0.5, 0.15) + 0.25 * (1.0 - smoothstep(0.0, 0.06, ay));
		edge = smoothstep(0.85, 1.0, ay);
		amp = 0.009;
	} else if (part == 4) {
		// an insect's body: rounded, in rings
		h = sqrt(max(0.0, 1.0 - ay * ay)) * (0.7 + 0.3 * abs(sin(UV.x * 3.14159 * 9.0)));
		marks = 0.6 * (1.0 - smoothstep(0.0, 0.25, abs(sin(UV.x * 3.14159 * 9.0))));
		edge = smoothstep(0.7, 1.0, ay);
		amp = 0.005;
	} else if (part == 5) {
		// a fan (ginkgo, a fin, a fish's tail): its veins fork out from the stalk as fine ridges, the blade rising from it
		float fv = line(UV.y * (9.0 + UV.x * 9.0) + rnd, 0.3);
		h = 0.45 * smoothstep(0.0, 0.3, UV.x) + 0.3 * fv * smoothstep(0.05, 0.25, UV.x);
		marks = 0.6 * fv * smoothstep(0.08, 0.25, UV.x);
		edge = smoothstep(0.85, 1.0, UV.x) + smoothstep(0.92, 1.0, ay);
		amp = 0.0035;
	} else if (part == 7) {
		// scale-tree bark: spiral rows of diamond leaf-cushions, each domed and keeled, its leaf scar a little above the
		// middle, the grooves between them narrow, every cushion a little different
		vec2 p = UV;
		vec2 ab = vec2(p.x * 0.5 + p.y * 0.5, p.x * 0.5 - p.y * 0.5);
		vec2 f = fract(ab);
		vec2 id = floor(ab);
		float hc = h3(vec3(id, 1.0 + seed));
		vec2 q = abs(f - 0.5) * 2.0;
		float d = max(q.x, q.y) * (0.92 + 0.12 * hc);
		float keel = (1.0 - smoothstep(0.0, 0.05, abs(f.x - f.y))) * (1.0 - smoothstep(0.55, 0.85, d));
		vec2 sc = (f - vec2(0.62, 0.62));
		float sd = length(vec2(sc.x + sc.y, (sc.x - sc.y) * 1.8));
		float scar = 1.0 - smoothstep(0.1, 0.15, sd);
		h = (1.0 - pow(min(d, 1.0), 2.5)) * (0.7 + 0.35 * hc) + scar * 0.2 + keel * 0.12;
		marks = 0.9 * smoothstep(0.86, 0.98, d) + 0.6 * scar * (1.0 - smoothstep(0.04, 0.08, sd)) + 0.25 * keel;
		// the broken edge of the bark: thin and darker
		edge = smoothstep(0.82, 1.0, abs(UV2.x - 0.5) * 2.0) * 0.5;
		amp = 0.012;
	} else if (part == 8) {
		// a wing: a fine net of veins, the long veins along it, a dark stigma near the tip of the leading edge
		float net = 1.0 - smoothstep(0.0, 0.09, cells(vec2(UV.x * 20.0, UV.y * 5.0) + rnd * 7.0));
		float longv = line(UV.y * 2.5 + 0.25, 0.12) * smoothstep(0.0, 0.1, UV.x);
		// (the leading edge is UV.y -1, or +1 when the blade was laid the other way round: COLOR.a 0)
		float yl = COLOR.a > 0.5 ? UV.y : -UV.y;
		float stig = (1.0 - smoothstep(0.0, 0.05, abs(UV.x - 0.82))) * smoothstep(0.55, 0.75, -yl);
		h = 0.25 + 0.5 * max(net, longv) + 0.4 * smoothstep(0.75, 1.0, ay);
		marks = 0.55 * max(net, longv) + 0.9 * stig;
		edge = smoothstep(0.85, 1.0, ay) + smoothstep(0.93, 1.0, UV.x);
		wing = 1.0 - max(net, longv);
		amp = 0.0018;
	} else if (part == 9) {
		// a little fish on its side: a domed body, the backbone, ribs sweeping back, a head with its eye and gill cover
		float body = sqrt(max(0.0, 1.0 - ay * ay));
		float spine = (1.0 - smoothstep(0.0, 0.07, abs(UV.y + 0.05))) * smoothstep(0.2, 0.25, UV.x) * (1.0 - smoothstep(0.9, 0.98, UV.x));
		float ribs = line(UV.x * 26.0 + ay * 1.2, 0.3) * smoothstep(0.24, 0.3, UV.x) * (1.0 - smoothstep(0.62, 0.7, UV.x)) * smoothstep(0.1, 0.25, ay) * (1.0 - smoothstep(0.75, 0.9, ay));
		float vert = line(UV.x * 40.0, 0.4) * spine;
		float eye = length(vec2((UV.x - 0.075) * 5.0, UV.y + 0.1));
		float ring = 1.0 - smoothstep(0.0, 0.08, abs(eye - 0.22));
		float gill = 1.0 - smoothstep(0.0, 0.025, abs(UV.x - 0.2 - 0.04 * UV.y * UV.y));
		float scales = line(UV.x * 34.0 + ay * 2.0, 0.2) * line(UV.x * 34.0 - ay * 2.0, 0.2) * 0.4;
		h = body * 0.7 + 0.35 * spine + 0.18 * ribs + 0.2 * ring - 0.2 * step(eye, 0.16);
		marks = 0.7 * spine + 0.5 * ribs + 0.4 * vert + 0.8 * ring + 0.5 * gill + 0.2 * scales;
		edge = smoothstep(0.75, 1.0, ay);
		amp = 0.006;
	} else {
		// a pinnule, a needle, a horsetail leaf: domed, the midrib and the side veins pressed into it
		float mid = 1.0 - smoothstep(0.0, 0.12, ay);
		float side = (1.0 - smoothstep(0.0, 0.18, abs(fract(UV.x * 7.0 - ay * 1.6 + rnd * 3.0) - 0.5) * 2.0)) * smoothstep(0.08, 0.2, ay);
		h = sqrt(max(0.0, 1.0 - ay * ay)) * 0.75 - 0.4 * mid - 0.2 * side;
		marks = max(mid, side * 0.7);
		edge = smoothstep(0.82, 1.0, ay) * 0.5;
		amp = 0.004;
	}
	// a cast is nothing but its relief: give it more
	if (film == 4) amp *= 1.6;
	// the counterpart is the other side of the same print: what stood up is pressed in
	if (mould > 0.5) h = 1.0 - h;
	float hw = h * amp * relief * length(MODEL_MATRIX[1].xyz);
	// bump: tilt the normal by the height's slope on screen
	vec3 dpx = dFdx(VERTEX);
	vec3 dpy = dFdy(VERTEX);
	float dhx = dFdx(hw);
	float dhy = dFdy(hw);
	vec3 r1 = cross(dpy, n);
	vec3 r2 = cross(n, dpx);
	float det = dot(dpx, r1);
	if (abs(det) > 1e-12) {
		vec3 grad = sign(det) * (dhx * r1 + dhy * r2);
		vec3 nb = abs(det) * n - grad;
		if (dot(nb, nb) > 1e-20) n = normalize(nb);
	}
	NORMAL = n;

	float mott = vn(v_op * 90.0 + seed) * 0.6 + vn(v_op * 23.0 + seed) * 0.4;
	// hollows hold shadow, the high places catch light
	float cav = 0.84 + 0.16 * clamp(h, 0.0, 1.0);
	// bark is mostly carbon-darkened stone, its cushions deep
	if (part == 7) {
		cav = 0.55 + 0.45 * clamp(h, 0.0, 1.0);
		marks *= 1.3;
	}
	vec3 c = film_col;
	float metal = 0.0;
	float rough = 0.35;
	float spec = 0.5;
	float glit = 0.0;      // how much it sparkles, grain by grain
	// a grain of the film: its own little facet, tilted at random — when one turns to the eye it flashes
	vec3 cell = floor(v_op * 380.0) + seed;
	vec3 t1 = normalize(dpx - n * dot(dpx, n));
	vec3 t2 = cross(n, t1);
	vec3 fn = normalize(n + t1 * (h3(cell) - 0.5) * 0.9 + t2 * (h3(cell + 9.1) - 0.5) * 0.9);
	float flash = smoothstep(0.965, 0.995, dot(fn, VIEW));
	if (film == 0) {
		// carbon: glossy jet-black with a brown-bronze sheen, the veins a shade browner, the edges thickest and darkest
		c = film_col * (0.8 + 0.5 * mott) + vec3(0.06, 0.04, 0.02) * marks;
		rough = 0.42 + 0.2 * mott;
		spec = 0.4;
	} else if (film == 1) {
		// pyrite: brassy gold in tiny crystals that flash as the slab turns, darker veins, a rainbow tarnish here and there
		c = film_col * (0.75 + 0.4 * mott) * (1.0 - 0.3 * marks);
		float tar = smoothstep(0.55, 0.8, vn(v_op * 14.0 + seed + 3.0));
		c = mix(c, c * vec3(0.7, 0.8, 1.25), tar * 0.5);
		metal = 0.9;
		rough = 0.3;
		glit = 1.0;
		// (a dark studio leaves bare metal dull: the gold glows a little on its own)
		EMISSION = film_col * 0.07 * cav;
	} else if (film == 2) {
		// silver: pale, pearly, with a soft sheen across it, the veins whiter, a faint glitter of mica
		c = film_col * (0.82 + 0.25 * mott) + vec3(0.12) * marks;
		metal = 0.45;
		rough = 0.3;
		spec = 0.8;
		glit = 0.35;
	} else if (film == 3) {
		// iron: rusty orange to brown, darker veins, matte
		c = film_col * (0.7 + 0.5 * mott) * (1.0 - 0.35 * marks);
		rough = 0.75;
		spec = 0.3;
	} else if (film == 4) {
		// a cast: the stone itself, a shade warmer where the leaf lay, the lines of it drawn in shadow
		c = stone_col * (0.86 + 0.12 * mott) * vec3(1.02, 0.97, 0.9) * (1.0 - 0.25 * marks);
		if (part == 7) c *= vec3(0.62, 0.58, 0.54);
		rough = 0.7;
		spec = 0.4;
	} else if (film == 5) {
		// kaolinite: chalky white, faintly glittering, a little rust soaked into it
		c = film_col * (0.85 + 0.2 * mott) * (1.0 - 0.18 * marks);
		c = mix(c, vec3(0.75, 0.45, 0.22), 0.25 * smoothstep(0.5, 0.85, vn(v_op * 9.0 + seed)));
		rough = 0.6;
		spec = 0.45;
		glit = 0.25;
	} else if (film == 7) {
		// nacre: the leaf turned to ammolite - plates of thin-film fire, each its own colour, cracked between like
		// dragon scales; the colours slide with the angle and drift slowly
		vec3 pl = vor2(v_op.xz * 13.0 + seed);
		float crack = 1.0 - smoothstep(0.0, 0.04, pl.y);
		float th = fire_h + (pl.z - 0.5) * 0.35 + (fbm(v_op * 4.0 + seed) - 0.5) * 0.4 + (1.0 - abs(dot(n, VIEW))) * 0.9 + h * 0.15 + TIME * 0.015;
		vec3 fire = lin(spectral(th));
		c = mix(vec3(0.02, 0.015, 0.012), fire, 0.82) * (1.0 - 0.75 * crack) * (1.0 - 0.3 * marks);
		metal = 0.55;
		rough = 0.16;
		spec = 0.7;
		EMISSION = fire * 0.1 * (1.0 - crack);
	} else if (film == 8) {
		// opal: the leaf's shape in precious opal - a dark body, its fire in clouds and flakes that slide as it turns
		vec3 v = normalize(v_cam - v_op);
		float gl;
		vec3 fire = opal_play(v_op * 3.0, v, vec3(0.0, 1.0, 0.0), fire_h, 0.3, seed, TIME * 0.2, 1.6, 0.6, 1.0, gl);
		c = opal_body_col(0, v_op, seed) * (1.0 - 0.3 * marks) + fire * 0.45;
		rough = 0.1;
		spec = 0.6;
		EMISSION = fire * 0.25;
	} else {
		// Green River brown: a thin dark-brown film, thinner and warmer at its edges, the veins darker
		c = film_col * (0.75 + 0.45 * mott) * (1.0 - 0.3 * marks);
		c = mix(c, film_col * 1.9, 0.35 * edge);
		rough = 0.4;
		spec = 0.55;
	}
	c *= cav;
	if (film != 4) c *= 1.0 - edge * (film == 2 || film == 5 ? 0.45 : 0.4);
	if (film >= 7) EMISSION *= 1.0 - edge * 0.6;
	// a wing's membrane: a faint rainbow that shifts as it turns
	if (wing > 0.0) {
		float k = dot(n, VIEW) * 3.0 + UV.x * 2.0 + rnd * 4.0;
		vec3 rb = 0.5 + 0.5 * cos(6.2832 * (vec3(0.0, 0.33, 0.67) + k));
		c = mix(c, c * 0.6 + rb * 0.35 * (0.3 + 0.7 * max(max(c.r, c.g), c.b) + 0.3), 0.45 * wing);
		EMISSION += rb * 0.025 * wing;
	}
	if (mould > 0.5) {
		// the counterpart: what the leaf left on the other half — a duller, thinner print
		c = mix(c, c * 0.6 + stone_col * 0.25, 0.6);
		metal *= 0.5;
		rough = mix(rough, 0.6, 0.6);
		glit *= 0.4;
	}
	if (glit > 0.0) {
		vec3 gc = film == 1 ? vec3(1.0, 0.85, 0.5) : vec3(0.95, 0.95, 1.0);
		EMISSION += gc * flash * glit * 1.4;
		rough = mix(rough, 0.08, flash * glit);
	}
	ALBEDO = c;
	METALLIC = metal;
	ROUGHNESS = rough;
	SPECULAR = spec;
	if (spring > 0.0) {
		// light running up the plant from its base, again and again, through the veins; the film greens under it
		float w = fract(UV2.x * 1.3 - TIME * 0.22);
		float pulse = smoothstep(0.0, 0.08, w) * (1.0 - smoothstep(0.08, 0.35, w));
		float alive = 0.5 + 0.5 * sin(TIME * 0.6 + UV2.x * 3.0);
		ALBEDO = mix(ALBEDO, vec3(0.12, 0.32, 0.08), 0.35 * alive);
		EMISSION += vec3(0.45, 1.3, 0.35) * (pulse * (0.35 + 1.4 * marks + stem) + 0.06 * alive) * spring;
	}
}
