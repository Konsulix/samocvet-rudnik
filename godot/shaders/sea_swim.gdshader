// The sea's swimmers round a sea find (SpecReef): a scan or a model, its colour and relief baked (sea_prep.py), moved
// alive in the vertex shader, each by its own way of swimming (SpecReef.MODELS "anim"). Model space: one unit long
// along x, the head at +x, its back up +y, its sides ±z.
//   tail:  a wave runs BACK down the body, from the head to the tail (it is what pushes the water back and the body
//          on; run the other way it looks like swimming backwards), small at the head, least at `swim_from`, growing
//          to the tail tip; the body BENDS along it — each slice turned to the wave's slope, not slid sideways. Only
//          sideways: a fish's, a shark's, a sea reptile's tail beats left and right. `swim_f` beats a second (a big
//          animal's slow), `swim_k` waves along the body (an eel one or more, a shark under one, an ichthyosaur's stiff
//          body half of one); it beats in bursts and glides between (`glide`) — SpecReef.Swim moves it on by the same
//          beat, so far for each beat
//   flippers: everything out past the body's half width `flip_w` between flip_x0 and flip_x1 strokes up and down
//          about the body; the fore and hind pair (front of `flip_mid` or behind) a half beat apart, a plesiosaur's
//          rowing; the down stroke the stronger
//   neck:  past `neck_from` the neck sways side to side and the head nods (a plesiosaur looking about)
//   jaw:   the lower jaw (before the hinge `jaw_x`, `jaw_y`, under the mouth's line of slope `jaw_s`) turns on its hinge:
//          open now and then, shut else (`jaw_shut`: a model made gaping is shut first)
//   jet:   an octopus, mantle first: the mantle swells slowly and squeezes fast, the arms close together behind on
//          the squeeze and drift apart again (`swim_f` squeezes a second)
// `phase` puts each one on its own beat. `haze`: the far ones grey into the deep water with their distance from the
// eye (haze_min near, at haze_d0, to haze at haze_d1); `caust`: the surface's light wanders over their backs;
// `fade`: coming out of the deep or going into it, sifted away
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D tex_d : source_color, filter_linear_mipmap;
uniform sampler2D tex_n : hint_normal, filter_linear_mipmap;
uniform vec3 tint = vec3(1.0);
uniform float gain = 1.35;
uniform float sat = 1.15;
uniform float rough = 0.45;
uniform float haze = 0.0;
uniform float haze_min = 0.0;
uniform float haze_d0 = 10.0;
uniform float haze_d1 = 30.0;
uniform vec3 haze_col : source_color = vec3(0.07, 0.13, 0.16);
uniform float caust = 0.0;
uniform float fade = 1.0;
uniform float phase = 0.0;
uniform float swim = 0.05;
uniform float swim_f = 0.8;
uniform float swim_k = 1.2;
uniform float swim_from = 0.3;
uniform float swim_head = 0.12;   // (the head's share of the tail's swing: a swimming body yaws a little about its middle)
uniform float glide = 0.5;
uniform float flip = 0.0;
uniform float flip_w = 0.08;
uniform float flip_x0 = -0.5;
uniform float flip_x1 = 0.5;
uniform float flip_mid = 0.0;
uniform float flip_f = 0.5;
uniform float neck = 0.0;
uniform float neck_from = 0.0;
uniform float jaw = 0.0;        // (how far the jaw drops from shut, radians)
uniform float jaw_x = 0.4;      // (its hinge, side on)
uniform float jaw_y = 0.1;
uniform float jaw_s = 0.0;      // (the mouth's line from the hinge forward: its slope, dy/dx)
uniform float jaw_shut = 0.0;   // (a model made with its mouth open: the angle that shuts it)
uniform float jaw_fan = 0.0;    // (the gape's angle at rest, shared out as a fan shuts; 0: jaw_shut. A mouth cut open by sea_prep.py has none: 0.004)
uniform float jaw_ramp = 0.03;  // (so far before the hinge the jaw takes up its turn: a small head, less)
uniform float jaw_mask = 0.0;   // (1: the lower jaw is what the mesh's own colour marks red — a head kept whole, its teeth locking: sea_prep.py split_head)
uniform float inside_k = 0.85;  // (how far the inside of the mouth is painted inside_col; 0: the model has a mouth of its own)
uniform float relief = 1.0;     // (how much of the baked relief shows; 0: the mesh's own smooth normals)
uniform float jaw_up = 0.0;     // (with jaw_mask: the upper jaw lifts by this share of the lower one's drop — a gape wide enough to show the palate)
// the body laid along the way it came (SpecReef.Swim, a plesiosaur going by the eye): its line from the snout back —
// spine_n the snout's own place on it, spine1 and spine2 where the line is half a length and a whole length behind,
// all in the model's own space — and every slice of the body carried over to it. A turn then is the body following
// its head round, not a board swung about its end
uniform float spine_k = 0.0;
uniform vec3 spine_n = vec3(0.5, 0.15, 0.0);
uniform vec3 spine1 = vec3(0.0, 0.15, 0.0);
uniform vec3 spine2 = vec3(-0.5, 0.15, 0.0);
uniform float jaw_force = -1.0; // (0..1: held so far open — SpecReef.Swim's strike, tests; under 0 it opens by itself)
uniform float jet = 0.0;
uniform float swim_ph = 0.0;    // (the tail's beat run on by so much: SpecReef.Swim quickens it without a jump — a charge, a flight)
uniform float curve = 0.0;      // (the whole body bent in a bow, the tail swept most: a turn, a blow's whip — SpecReef.Swim)
uniform vec3 reach = vec3(0.0);   // (the head carried off by so much, the neck bending to it: x on, y up, z aside)
uniform vec2 eye = vec2(9.0);   // (the eye, side on: x along, y up; both eyes, either side)
uniform float eye_r = 0.008;
uniform float eye_paint = 0.0;     // (the eyes drawn here, both alike: a scan whose two eyes came out unlike — a plesiosaur's, one red, one orange)
uniform float paint_zc = 0.0;      // (the head's middle line there, and how far off it an eye begins: the eye is on the head's sides, not its crown)
uniform float paint_z0 = 0.0;
uniform vec3 inside_col : source_color = vec3(0.16, 0.03, 0.035);   // (the inside of the mouth: dark; a plesiosaur's, seen from within as it swallows the find, the pink of a palate)
uniform float blink_force = 0.0;   // (tests: shut the eyes)
varying vec3 v_mp;
varying vec3 v_wp;
varying vec3 v_wn;
varying vec2 v_jaw;   // (with jaw_mask: whose the vertex is — 1 the lower jaw's — and how far the mouth is open)

// how hard it is swimming now: a few strong beats, then a glide (the same in SpecReef.Swim.burst)
float burst(float t) {
	return mix(1.0 - glide, 1.0, smoothstep(-0.3, 0.7, sin(t * 0.42 + phase * 6.2831)));
}

// the body's sideways bend at x along it
float bend(float x, float tp, float b) {
	float w = (swim_from - x) / (swim_from + 0.5);
	float env = w > 0.0 ? w * w : swim_head * w * w / max(0.05, (0.5 - swim_from) * (0.5 - swim_from) / ((swim_from + 0.5) * (swim_from + 0.5)));
	return sin(tp + x * swim_k * 6.2831) * swim * b * (0.03 + env) + curve * ((x - 0.15) * (x - 0.15) - 0.05);
}

// an octopus's squeeze: 0 slack, up fast to 1, slowly back (the same in SpecReef.Swim.squeeze)
float squeeze(float c) {
	c = fract(c);
	return smoothstep(0.0, 0.14, c) * (1.0 - smoothstep(0.22, 0.85, c));
}

void vertex() {
	vec3 p = VERTEX;
	v_mp = p;
	float t = TIME;
	// the jaw, first (in the body's own rest, before anything bends it): the lower jaw — all before the hinge and under
	// the mouth's line — turns on its hinge. A turn, not a slide: slid down, the chin's skin only stretched. What lies
	// in the gape between the jaws (a tongue, the mouth's lining) turns by its share, as a fan shuts. Shut most of the
	// time (a model made gaping is shut by jaw_shut), open a while every so often
	v_jaw = vec2(0.0);
	if (jaw_mask > 0.0) v_jaw = vec2(COLOR.r, max(0.0, jaw_force >= 0.0 ? jaw_force : pow(max(0.0, sin(t * 0.62 + phase * 6.2831 + 1.0)), 4.0)));
	if (jaw > 0.0 || jaw_shut > 0.0) {
		vec2 d = p.xy - vec2(jaw_x, jaw_y);
		if (d.x > 0.0) {
			float w = clamp((atan(jaw_s) - atan(d.y, d.x)) / (jaw_fan > 0.0 ? jaw_fan : max(jaw_shut, 0.004)), 0.0, 1.0) * smoothstep(0.0, jaw_ramp, d.x);
			float up = 0.0;
			if (jaw_mask > 0.0) {
				float lower = step(0.5, COLOR.r);
				w = lower * smoothstep(0.0, jaw_ramp, d.x);
				up = (1.0 - lower) * smoothstep(0.0, 0.012, d.x);
			}
			float open = jaw_force >= 0.0 ? jaw_force : pow(max(0.0, sin(t * 0.62 + phase * 6.2831 + 1.0)), 4.0);
			float a = (jaw * open - jaw_shut * (1.0 - open)) * w - jaw * max(open, 0.0) * jaw_up * up;
			float ca = cos(a), sa = sin(a);
			p.xy = vec2(jaw_x + d.x * ca + d.y * sa, jaw_y - d.x * sa + d.y * ca);
			VERTEX = p;
		}
	}
	float b = burst(t);
	float tp = t * 6.2831 * swim_f + phase * 6.2831 + swim_ph;
	if (jet <= 0.0) {
		// the tail: the spine a wave, every slice of the body set square to it
		float z0 = bend(p.x, tp, b);
		float sl = (bend(p.x + 0.01, tp, b) - bend(p.x - 0.01, tp, b)) / 0.02;
		float inv = inversesqrt(1.0 + sl * sl);
		VERTEX.x = p.x - p.z * sl * inv;
		VERTEX.z = z0 + p.z * inv;
		NORMAL = normalize(vec3(NORMAL.x * inv - NORMAL.z * sl * inv, NORMAL.y, NORMAL.x * sl * inv + NORMAL.z * inv));
	}
	// the flippers, rowing
	float side = abs(p.z) - flip_w;
	if (flip > 0.0 && side > 0.0 && p.x > flip_x0 && p.x < flip_x1) {
		float fp = t * 6.2831 * flip_f + phase * 6.2831 + (p.x > flip_mid ? 0.0 : 3.1416);
		// (a stroke: fast and strong down, slow back up)
		float s = sin(fp) + 0.35 * sin(2.0 * fp);
		VERTEX.y += s * side * flip * (0.6 + 0.4 * b);
		// and swept back a little as it strokes
		VERTEX.x -= abs(s) * side * flip * 0.25;
	}
	// the neck: its sway grows to the head; `reach` carries the head off where SpecReef.Swim sends it (a strike)
	if ((neck > 0.0 || dot(reach, reach) > 0.0) && p.x > neck_from) {
		float n = (p.x - neck_from) / (0.5 - neck_from);
		n = n * n;
		VERTEX.z += sin(t * 0.55 + phase * 6.2831) * neck * n + sin(t * 1.3 + phase * 3.0) * neck * 0.25 * n;
		VERTEX.y += sin(t * 0.4 + phase * 5.0) * neck * 0.55 * n;
		VERTEX += reach * n;
	}
	// the octopus (a scan of one laid out flat, its arms a fan on the table): the mantle (the head end, +x) fills
	// slowly and squeezes fast; the fan of arms is rolled round the body's line into a skirt trailing behind, which
	// each squeeze gathers — a little later the further down the arms — and lets spread again; waves run down the
	// arms, and they twist a little
	if (jet > 0.0) {
		float c = t * swim_f + phase;
		float arm = smoothstep(0.08, -0.15, p.x);
		float tip = smoothstep(0.05, -0.45, p.x);
		float sq = squeeze(c - tip * 0.25);
		float mant = smoothstep(0.08, 0.25, p.x);
		// (the mantle lay flat on the table: filled out again, taller)
		VERTEX.yz = vec2(0.09, 0.0) + (p.yz - vec2(0.09, 0.0)) * vec2(1.0 + mant * 0.8, 1.0) * (1.0 + mant * jet * (1.0 - 2.2 * squeeze(c)));
		float rad = 0.085 * (1.0 + (0.45 - 1.05 * sq) * tip);
		float phi = p.z / 0.085 * 0.95 + sin(t * 0.7 + p.x * 5.0 + phase * 6.2831) * 0.3 * tip;
		float rr = rad + (p.y - 0.035) + sin(t * 2.0 + p.x * 16.0 + phi * 2.0 + phase * 6.2831) * 0.018 * tip;
		vec2 skirt = vec2(0.02 + rr * cos(phi), rr * sin(phi));
		VERTEX.yz = mix(VERTEX.yz, skirt, arm);
		VERTEX.x -= tip * sq * 0.05;
		float na = phi * arm;
		NORMAL = normalize(vec3(NORMAL.x, NORMAL.y * cos(na) - NORMAL.z * sin(na), NORMAL.y * sin(na) + NORMAL.z * cos(na)));
	}
	if (spine_k > 0.0) {
		float u = clamp(spine_n.x - VERTEX.x, 0.0, 1.25);
		vec3 on = spine_n * (2.0 * (u - 0.5) * (u - 1.0)) + spine1 * (-4.0 * u * (u - 1.0)) + spine2 * (2.0 * u * (u - 0.5));
		VERTEX += (on - (spine_n - vec3(u, 0.0, 0.0))) * spine_k;
	}
	v_wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wn = normalize(mat3(MODEL_MATRIX) * NORMAL);
}

float h2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

// a net of light (as shaders/caustics.gdshader): cells whose points drift, bright along the edges between them
float net(vec2 q, float t) {
	vec2 c = floor(q);
	float d1 = 9.0, d2 = 9.0;
	for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
		vec2 g = c + vec2(float(x), float(y));
		float r = h2(g);
		vec2 pt = g + 0.5 + 0.38 * vec2(sin(t * (0.6 + r) + r * 6.28), cos(t * (0.5 + h2(g + 3.1)) + r * 4.0));
		float d = distance(pt, q);
		if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
	}
	return 1.0 - smoothstep(0.0, 0.12, d2 - d1);
}

void fragment() {
	if (fade < 0.999) {
		// (sifted, not blended: it stays solid, sorted by depth as the rest)
		float dn = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
		if (dn > fade) discard;
	}
	vec3 c = texture(tex_d, UV).rgb;
	float l = dot(c, vec3(0.3, 0.5, 0.2));
	c = mix(vec3(l), c, sat) * gain * tint;
	// a blink every few seconds, now and then twice: the lid is the skin round the eye (the texture, blurred)
	if (eye.x < 5.0) {
		float f = fract(TIME * 0.21 + phase * 3.7);
		float shut = 1.0 - smoothstep(0.0, 0.02, abs(f - 0.5));
		shut = max(shut, (1.0 - smoothstep(0.0, 0.02, abs(f - 0.56))) * step(0.5, fract(phase * 7.3 + floor(TIME * 0.21 + phase * 3.7) * 0.37)));
		shut = max(shut, blink_force);
		float d = length(v_mp.xy - eye);
		float on_side = eye_paint > 0.0 ? smoothstep(paint_z0 * 0.6, paint_z0, abs(v_mp.z - paint_zc)) : 1.0;
		if (eye_paint > 0.0) {
			// the skin round it first (the scan's own eye patch painted out), then an amber eye with a slit of a pupil
			vec3 round_it = textureLod(tex_d, UV, 5.0).rgb;
			round_it = vec3(dot(round_it, vec3(0.3, 0.5, 0.2))) * vec3(0.9, 0.96, 1.0) * gain * tint * 0.8;
			c = mix(c, round_it, eye_paint * on_side * smoothstep(eye_r * 4.4, eye_r * 2.9, length((v_mp.xy - eye - vec2(0.0, eye_r * 0.6)) * vec2(1.0, 1.25))));
			// (and whatever of the scan's red is left about the eyes, wherever it lies on either side: to plain skin)
			float box = smoothstep(eye_r * 5.0, eye_r * 3.5, abs(v_mp.x - eye.x)) * smoothstep(eye.y - eye_r * 2.2, eye.y - eye_r * 1.4, v_mp.y);
			float red = smoothstep(1.25, 1.7, c.r / max(c.g, 0.02));
			c = mix(c, vec3(dot(c, vec3(0.3, 0.5, 0.2))) * vec3(0.9, 0.96, 1.0) * 0.75, eye_paint * box * red);
			vec2 ed = (v_mp.xy - eye) / eye_r;
			vec3 iris = mix(vec3(0.62, 0.36, 0.06), vec3(0.2, 0.08, 0.015), smoothstep(0.3, 1.0, length(ed)));
			iris = mix(iris, vec3(0.01), smoothstep(0.34, 0.18, abs(ed.x)) * smoothstep(0.95, 0.7, abs(ed.y)));
			iris += vec3(0.6) * smoothstep(0.2, 0.05, length(ed - vec2(0.3, 0.35)));
			c = mix(c, iris, eye_paint * on_side * smoothstep(1.1, 0.9, length(ed)));
			c = mix(c, vec3(0.02), eye_paint * on_side * smoothstep(0.14, 0.0, abs(length(ed) - 1.05)));
		}
		float lid = smoothstep(eye_r * 1.3, eye_r * 0.9, d) * shut * on_side;
		// (the lid: the skin's colour, the texture averaged wide — the eye itself is too small to tint it — and a dark
		// crease across its middle)
		vec3 skin = textureLod(tex_d, UV, 6.0).rgb;
		// (only its lightness: averaged so wide the texture brings in what lies beside the eye on its sheet — a
		// plesiosaur's red gums, another patch for the other eye — and the two lids came out red and orange)
		skin = vec3(dot(skin, vec3(0.3, 0.5, 0.2))) * vec3(0.92, 0.97, 1.0) * gain * tint;
		skin *= 1.15 - 0.35 * smoothstep(eye_r * 0.18, 0.0, abs(v_mp.y - eye.y));
		c = mix(c, skin, lid);
	}
	// (the inside of an open mouth, where the model has none: the far cheek seen from within — dark, red)
	// (not at the eyes' height where the eyes are drawn: a plesiosaur's scan has its skin inside out round one eye, and
	// that eye came out a red patch)
	if (!FRONT_FACING && jaw > 0.0 && v_mp.x > jaw_x && !(eye_paint > 0.0 && length(v_mp.xy - eye) < eye_r * 3.2)) {
		// (a palate is not one flat colour: ridges across it, darker to the throat)
		float ridge = 0.85 + 0.15 * sin(v_mp.x * 900.0);
		c = mix(c, inside_col * ridge * mix(0.45, 1.0, smoothstep(jaw_x, jaw_x + 0.03, v_mp.x)), inside_k);
	}
	// (a mouth wide open: the skin from jaw to jaw at its back is drawn out thin — a pillar of smeared texture; it is
	// the dark of the throat instead)
	if (jaw_mask > 0.0) {
		float span = 1.0 - abs(2.0 * v_jaw.x - 1.0);
		c = mix(c, vec3(0.05, 0.008, 0.012), smoothstep(0.03, 0.35, span) * clamp(v_jaw.y * 1.6, 0.0, 1.0));
	}
	// the water between: the further off, the more of its colour — but the body keeps its light and shade (all one flat
	// colour it was a card cut out)
	float hz = haze > 0.0 ? mix(haze_min, haze, smoothstep(haze_d0, haze_d1, length(VERTEX))) : 0.0;
	// (come close — a plesiosaur's head at the find — there is little water between)
	hz *= clamp(length(VERTEX) / haze_d0, 0.3, 1.0);
	vec3 e = haze_col * hz * 0.45;
	if (caust > 0.0) {
		// the light from the surface: the back lit, the belly in its own shade, a net of light wandering over the back
		float up = normalize(v_wn).y * (FRONT_FACING ? 1.0 : -1.0);
		c *= mix(0.5, 1.2, smoothstep(-0.7, 0.7, up));
		vec2 q = v_wp.xz * 0.42 + v_wp.y * 0.1;
		float n = net(q, TIME * 0.7) * 0.6 + net(q * 1.43 + 5.0, TIME * 0.9) * 0.5;
		e += vec3(0.55, 0.85, 1.0) * n * n * caust * smoothstep(0.05, 0.75, up) * (1.0 - hz * 0.5);
	}
	ALBEDO = mix(c, haze_col, hz);
	NORMAL_MAP = FRONT_FACING ? texture(tex_n, UV).rgb : vec3(0.5, 0.5, 1.0);
	NORMAL_MAP_DEPTH = relief;
	ROUGHNESS = mix(rough, 0.85, hz);
	SPECULAR = 0.4 * (1.0 - hz * 0.6);
	EMISSION = e;
}
