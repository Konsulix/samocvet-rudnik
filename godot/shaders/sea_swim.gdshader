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
//   jaw:   the lower jaw (past `jaw_x`, under `jaw_y`) drops open now and then and snaps shut
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
uniform float jaw = 0.0;
uniform float jaw_x = 0.4;
uniform float jaw_y = 0.1;
uniform float jet = 0.0;
uniform vec2 eye = vec2(9.0);   // (the eye, side on: x along, y up; both eyes, either side)
uniform float eye_r = 0.008;
uniform float blink_force = 0.0;   // (tests: shut the eyes)
varying vec3 v_mp;
varying vec3 v_wp;
varying vec3 v_wn;

// how hard it is swimming now: a few strong beats, then a glide (the same in SpecReef.Swim.burst)
float burst(float t) {
	return mix(1.0 - glide, 1.0, smoothstep(-0.3, 0.7, sin(t * 0.42 + phase * 6.2831)));
}

// the body's sideways bend at x along it
float bend(float x, float tp, float b) {
	float w = (swim_from - x) / (swim_from + 0.5);
	float env = w > 0.0 ? w * w : swim_head * w * w / max(0.05, (0.5 - swim_from) * (0.5 - swim_from) / ((swim_from + 0.5) * (swim_from + 0.5)));
	return sin(tp + x * swim_k * 6.2831) * swim * b * (0.03 + env);
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
	float b = burst(t);
	float tp = t * 6.2831 * swim_f + phase * 6.2831;
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
	// the neck: its sway grows to the head
	if (neck > 0.0 && p.x > neck_from) {
		float n = (p.x - neck_from) / (0.5 - neck_from);
		n = n * n;
		VERTEX.z += sin(t * 0.55 + phase * 6.2831) * neck * n + sin(t * 1.3 + phase * 3.0) * neck * 0.25 * n;
		VERTEX.y += sin(t * 0.4 + phase * 5.0) * neck * 0.55 * n;
	}
	// the jaw: open a while every so often, then shut
	if (jaw > 0.0 && p.x > jaw_x) {
		float open = pow(max(0.0, sin(t * 0.62 + phase * 6.2831 + 1.0)), 4.0) * jaw;
		float low = smoothstep(jaw_y + 0.012, jaw_y - 0.012, p.y);
		VERTEX.y -= (p.x - jaw_x) * open * low;
	}
	// the octopus: the mantle (the head end, +x) fills slowly and squeezes fast; the arms (trailing, -x) are drawn
	// together by each squeeze, a little later the further down them, and drift apart again; their tips wave
	if (jet > 0.0) {
		float c = t * swim_f + phase;
		float arm = smoothstep(0.12, -0.45, p.x);
		float sq = squeeze(c - arm * 0.22);
		float mant = smoothstep(0.05, 0.3, p.x);
		VERTEX.yz = mix(VERTEX.yz, VERTEX.yz * (1.0 + jet * (0.9 - 1.6 * squeeze(c))), mant);
		VERTEX.yz *= 1.0 - arm * (0.25 + 0.5 * sq);
		VERTEX.x -= arm * sq * 0.08;
		VERTEX.y += sin(t * 1.3 + p.x * 9.0 + p.z * 14.0 + phase * 6.2831) * jet * 0.12 * arm * arm;
		VERTEX.z += sin(t * 1.1 + p.x * 7.0 + phase * 4.0) * jet * 0.12 * arm * arm;
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
		float lid = smoothstep(eye_r * 1.3, eye_r * 0.9, d) * shut;
		// (the lid: the skin's colour, the texture averaged wide — the eye itself is too small to tint it — and a dark
		// crease across its middle)
		vec3 skin = textureLod(tex_d, UV, 6.0).rgb;
		skin = mix(vec3(dot(skin, vec3(0.3, 0.5, 0.2))), skin, sat) * gain * tint;
		skin *= 1.15 - 0.35 * smoothstep(eye_r * 0.18, 0.0, abs(v_mp.y - eye.y));
		c = mix(c, skin, lid);
	}
	// the water between: the further off, the more of its colour — but the body keeps its light and shade (all one flat
	// colour it was a card cut out)
	float hz = haze > 0.0 ? mix(haze_min, haze, smoothstep(haze_d0, haze_d1, length(VERTEX))) : 0.0;
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
	ROUGHNESS = mix(rough, 0.85, hz);
	SPECULAR = 0.4 * (1.0 - hz * 0.6);
	EMISSION = e;
}
