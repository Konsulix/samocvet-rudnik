shader_type spatial;
render_mode cull_disabled;
// The chameleon on its twig in the card's corner (CardChameleon). The scan is grey: it gives the light and dark —
// scales, skin folds, the casque — and the colour is laid here: a base colour, bands of a second across the body, the
// belly paler, the eye turrets ringed. A change of colour runs from the head to the tail as a wave (`wave` 0..1, the
// old colours behind it), its front flushing bright. It breathes (the flanks swell and ease) and its tail's curl
// tightens and eases. `ax` runs head to tail through `c0`; `s_lo..s_hi` the body's length along it.

uniform sampler2D tex_d : source_color, filter_linear_mipmap;
uniform vec3 main_a : source_color = vec3(0.1, 0.45, 0.12);
uniform vec3 pat_a : source_color = vec3(0.9, 0.75, 0.1);
uniform vec3 main_b : source_color = vec3(0.1, 0.45, 0.12);
uniform vec3 pat_b : source_color = vec3(0.9, 0.75, 0.1);
uniform float wave = 1.2;
uniform vec3 c0 = vec3(0.0);
uniform vec3 ax = vec3(0.0, -1.0, 0.0);
uniform vec3 side = vec3(1.0, 0.0, 0.0);
uniform float s_lo = -0.5;
uniform float s_hi = 0.5;
uniform float seed = 0.0;
// (its skeleton, on a skull: bone, the colour glowing through it from within — the bands along its spine)
uniform float bone = 0.0;
// the eye turrets: their centres and size; each turned on its own (yaw, pitch) — they roll each its own way, and both
// to what it is about to catch
uniform vec3 eye1 = vec3(0.0, -9.0, 0.0);
uniform vec3 eye2 = vec3(0.0, -9.0, 0.0);
uniform float eye_r = 0.03;
uniform vec2 rot1 = vec2(0.0);
uniform vec2 rot2 = vec2(0.0);

// the body's across: `lat` toward its flanks, `back` from its belly (the twig's side) up to its crest; `rad` its
// girth's radius about its line
uniform vec3 lat = vec3(0.0, 0.0, 1.0);
uniform vec3 back = vec3(1.0, 0.0, 0.0);
uniform float girth = 0.08;

// (25.11) the head turns about its neck: `head_dir` neck to snout, `head_up` to its casque; `head_rot` x — the turn
// about head_up (its snout toward or away from the viewer), y — the nod. What lies ahead of the neck turns whole, the
// skin of the neck stretching between
uniform vec3 neck = vec3(0.0, -9.0, 0.0);
uniform vec3 head_dir = vec3(-1.0, 0.0, 0.0);
uniform vec3 head_up = vec3(0.0, 1.0, 0.0);
uniform vec2 head_rot = vec2(0.0);
// a front leg lifted off the twig: from its shoulder `arm_a` to its hand `arm_b`, what lies along it turns about the
// shoulder (about `lat`) by `arm_lift`, more toward the hand
uniform vec3 arm_a = vec3(0.0, -9.0, 0.0);
uniform vec3 arm_b = vec3(0.0, -9.1, 0.0);
uniform float arm_lift = 0.0;
uniform float tail_curl = 0.0;   // the tail's curl opening (+) and closing (-)

varying float v_s;
varying float v_dv;
varying vec3 v_p;

float h3(vec3 p) { p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float vn(vec3 x) {
	vec3 i = floor(x), f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h3(i), h3(i + vec3(1, 0, 0)), f.x), mix(h3(i + vec3(0, 1, 0)), h3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(h3(i + vec3(0, 0, 1)), h3(i + vec3(1, 0, 1)), f.x), mix(h3(i + vec3(0, 1, 1)), h3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

vec3 about(vec3 v, vec3 k, float a) {
	return v * cos(a) + cross(k, v) * sin(a) + k * dot(k, v) * (1.0 - cos(a));
}

mat3 turn(vec2 a) {
	float cy = cos(a.x), sy = sin(a.x), cp = cos(a.y), sp = sin(a.y);
	mat3 ry = mat3(vec3(cy, 0.0, -sy), vec3(0.0, 1.0, 0.0), vec3(sy, 0.0, cy));
	mat3 rx = mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, cp, sp), vec3(0.0, -sp, cp));
	return ry * rx;
}

void vertex() {
	// the eyes: what lies in a turret turns about its centre, easing out to the skin round it
	for (int k = 0; k < 2; k++) {
		vec3 ec = k == 0 ? eye1 : eye2;
		vec2 ea = k == 0 ? rot1 : rot2;
		vec3 de = VERTEX - ec;
		float w = 1.0 - smoothstep(eye_r * 0.75, eye_r * 1.2, length(de));
		if (w > 0.0) {
			mat3 m = turn(ea * w);
			VERTEX = ec + m * de;
			NORMAL = m * NORMAL;
		}
	}
	// the leg's own reach first (the head's turn leaves it be)
	vec3 ab = arm_b - arm_a;
	float al = length(ab);
	vec3 ad = ab / max(al, 0.001);
	vec3 da = VERTEX - arm_a;
	float at = dot(da, ad);
	float off = length(da - ad * clamp(at, 0.0, al * 1.25));
	float in_arm = (1.0 - smoothstep(0.034, 0.05, off)) * step(at, al * 1.3) * step(-0.02, at);
	// the head (its lower jaw too: the first cut left the jaw's rim behind as crumbs in the air)
	vec3 dh = VERTEX - neck;
	float hh = dot(dh, head_dir);
	float hu = dot(dh, head_up);
	float hw = smoothstep(-0.02, 0.035, hh) * smoothstep(-0.17, -0.14, hu) * (1.0 - smoothstep(0.22, 0.28, length(dh))) * (1.0 - in_arm);
	if (hw > 0.0) {
		vec3 hl = normalize(cross(head_dir, head_up));
		vec3 q = about(dh, head_up, head_rot.x * hw);
		q = about(q, hl, head_rot.y * hw);
		VERTEX = neck + q;
		NORMAL = about(about(NORMAL, head_up, head_rot.x * hw), hl, head_rot.y * hw);
	}
	float aw = smoothstep(0.02, 0.07, at) * in_arm;
	if (aw > 0.0 && arm_lift != 0.0) {
		VERTEX = arm_a + about(da, lat, arm_lift * aw);
		NORMAL = about(NORMAL, lat, arm_lift * aw);
	}
	vec3 d = VERTEX - c0;
	float along = dot(d, ax);
	float s = clamp((along - s_lo) / max(0.001, s_hi - s_lo), 0.0, 1.0);
	v_s = s;
	v_p = VERTEX;
	v_dv = dot(d - ax * along, back) / girth;
	// breathing: the middle of the body swells out from its line and eases back
	vec3 rad = d - ax * along;
	float mid = smoothstep(0.15, 0.35, s) * (1.0 - smoothstep(0.55, 0.72, s));
	VERTEX += rad * 0.05 * mid * (0.5 + 0.5 * sin(TIME * 1.9 + seed));
	// the tail: its curl tightens and eases, more toward its tip
	float tl = smoothstep(0.7, 1.0, s);
	VERTEX += side * tl * tl * (s_hi - s_lo) * 0.05 * sin(TIME * 0.8 + seed * 2.0);
	// and it swings out and back, slowly, as a tail feeling for a hold
	VERTEX += (back * 0.6 - ax * 0.4) * tl * tl * (s_hi - s_lo) * 0.09 * tail_curl;
}

void fragment() {
	vec3 sc = texture(tex_d, UV).rgb;
	float L = dot(sc, vec3(0.3, 0.59, 0.11));
	// the wave of a change: new colours ahead of the head... the front at `wave`, bright where it passes
	float nw = 1.0 - smoothstep(wave - 0.08, wave, v_s);
	float flush = exp(-pow((v_s - wave) / 0.05, 2.0)) * step(0.0, wave) * step(wave, 1.08);
	vec3 base = mix(main_a, main_b, nw);
	vec3 pat = mix(pat_a, pat_b, nw);
	// a real chameleon's pattern (25.11: "a wash with spots"): broad bars across the flanks, darker and lighter by
	// turns; a pale line along each flank, low down; the belly pale; the head and its casque a colour of their own;
	// fine speckles
	float n = vn(v_p * 14.0 + seed);
	float body = smoothstep(0.04, 0.14, v_s) * (1.0 - smoothstep(0.8, 0.92, v_s));
	float bar = sin(v_s * 26.0 + n * 1.6 + v_dv * 0.6) * 0.5 + 0.5;
	vec3 col = mix(base * 0.4, base * 1.3, smoothstep(0.3, 0.7, bar) * body + (1.0 - body) * 0.6);
	// the pale line low along the flank, a little wavy, broken now and then
	float line = exp(-pow((v_dv + 0.15 + (n - 0.5) * 0.2) / 0.2, 2.0)) * body * smoothstep(0.3, 0.6, vn(vec3(v_s * 30.0, seed, 1.0)) + 0.4);
	col = mix(col, pat * 1.15 + 0.04, clamp(line, 0.0, 1.0) * 0.85);
	// the belly
	col = mix(col, mix(pat, vec3(0.8, 0.78, 0.65), 0.4), smoothstep(-0.55, -0.95, v_dv) * 0.7);
	// the head: the pattern's colour, its casque edged darker
	float head = 1.0 - smoothstep(0.08, 0.16, v_s);
	col = mix(col, mix(pat, base, 0.35), head * 0.8);
	// speckles, of the bands' colour
	float spot = smoothstep(0.8, 0.9, vn(v_p * 48.0 + seed * 3.0)) * body;
	col = mix(col, pat, spot * 0.5);
	// the scan's light and dark carry the skin: its scales and folds
	col *= 0.12 + 1.05 * L * L * 1.6;
	col += pat * flush * 0.6;
	ALBEDO = col;
	ROUGHNESS = 0.45 - 0.15 * L;
	SPECULAR = 0.4;
	EMISSION = pat * flush * 0.5;
	if (bone > 0.5) {
		// bone, lit from within in the colour of the moment: brighter down its bands, a slow pulse running head to tail
		float pulse = 0.55 + 0.45 * sin(v_s * 9.0 - TIME * 2.2);
		ALBEDO = mix(vec3(0.78, 0.74, 0.66), base * 1.4, 0.55) * (0.6 + 0.4 * L);
		EMISSION = mix(base, pat, smoothstep(0.25, 0.75, bar) * 0.5) * (0.4 + 0.6 * pulse) * 2.6 + pat * flush * 2.5;
		ROUGHNESS = 0.6;
	}
}
