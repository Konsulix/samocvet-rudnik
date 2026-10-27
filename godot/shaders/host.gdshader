shader_type spatial;
render_mode cull_back, depth_draw_always;
// The clear stone holding an inclusion (SpecFlower): quartz like ice, or amber. What is behind is bent through it
// (no colour split: a lump, not a cut gem); inside, a march along the line of sight through the stone gathers what
// floats in it — ice-like fracture sheets and veils, air bubbles with bright rims, flow lines and specks of debris
// (amber) — stopping where the ray reaches the inclusion's sphere, so nothing behind it is drawn over it. The body
// tints with the way through it, and scatters light from within (amber glows). The skin: polished, frosted and
// chipped in places.

#include "res://shaders/opal.gdshaderinc"
#include "res://shaders/studio.gdshaderinc"

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform vec3 tint = vec3(0.95, 0.97, 0.98);   // linear; amber ~ (1.0, 0.45, 0.08)
uniform float absorb = 0.4;        // how fast the tint deepens with the distance travelled
uniform float frac_k = 0.6;        // fracture sheets
uniform float veil_k = 0.3;        // soft milky veils
uniform float bubble_k = 0.3;
uniform float flow_k = 0.0;        // amber's flow lines
uniform float debris_k = 0.0;
uniform float frost_k = 0.3;       // frosted skin in patches
uniform float bend_k = 0.6;
uniform float size = 1.0;          // the stone's radius in its own units
uniform float seed = 0.0;
uniform float glow_k = 0.0;        // light scattered inside the body
uniform vec3 frost_col = vec3(0.75, 0.77, 0.8);

varying vec3 v_op;
varying vec3 v_cam;

void vertex() {
	v_op = VERTEX;
	v_cam = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
}

void fragment() {
	vec3 n = NORMAL;
	vec3 d = normalize(v_op - v_cam);
	// how far the ray goes inside: through the stone (a chord of its rough ball), or to the inclusion's sphere
	// the inclusion is opaque, already in the depth buffer: where the ray meets it (nothing there: the far plane, 0)
	float dz = textureLod(depth_tex, SCREEN_UV, 0.0).r;
	vec4 vp = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, dz, 1.0);
	vp.xyz /= vp.w;
	float ms = length(MODEL_MATRIX[0].xyz);
	float t_hit = dz > 1e-6 ? distance(vp.xyz, VERTEX) / ms : 99.0;
	float bs_ = dot(v_op, d);
	float chord = 2.0 * sqrt(max(0.0, size * size * 1.1 - (dot(v_op, v_op) - bs_ * bs_)));
	float t_max = min(t_hit, min(chord, size * 2.2));
	// the march: front to back
	vec3 acc = vec3(0.0);
	float tr = 1.0;
	vec3 path = vec3(1.0);
	const int N = 24;
	float st = size * 2.2 / float(N);
	float jit = 0.5;
	vec3 fdir = normalize(vec3(0.3, 1.0, 0.2));
	for (int i = 0; i < N; i++) {
		float t = (float(i) + jit) * st;
		if (t > min(chord, size * 2.2)) break;
		// nothing behind the inclusion shows
		float past = 1.0 - step(t_hit, t);
		vec3 q = v_op + d * t;
		// still inside the lump? (a soft fade near its skin, from the rough ball the stone was made from)
		float inside = 1.0 - smoothstep(size * 0.95, size * 1.25, length(q));
		if (inside <= 0.0) break;
		// colour deepens with the way travelled
		path *= exp(-(vec3(1.0) - tint) * absorb * st * 3.0);
		float sheet = 0.0;
		float veil = smoothstep(0.62, 0.85, fbm(q * 1.4 / size + seed + 50.0)) * veil_k;
		// bubbles: in some cells a small sphere; its rim catches the light
		vec3 bq = q * 7.0 / size + seed;
		vec3 bc = floor(bq);
		float bh = h3(bc + 1.7);
		float bub = 0.0;
		if (bh > 1.0 - 0.35 * bubble_k) {
			vec3 cen = bc + 0.3 + 0.4 * vec3(h3(bc + 3.0), h3(bc + 5.0), h3(bc + 7.0));
			float rr = 0.06 + 0.12 * h3(bc + 9.0);
			float dd = length(bq - cen);
			bub = (1.0 - smoothstep(rr * 0.6, rr, dd)) * smoothstep(rr * 0.35, rr * 0.9, dd);
		}
		// amber: flow lines (the resin ran in layers) and dark specks of bark and dust
		float flow = 0.0;
		if (flow_k > 0.0) {
			float fb = abs(fract(dot(q / size, fdir) * 3.5 + fbm(q * 1.4 / size + seed) * 1.6) - 0.5);
			flow = (1.0 - smoothstep(0.0, 0.025, fb)) * flow_k * smoothstep(0.4, 0.6, vn(q * 1.5 / size + seed + 20.0));
		}
		float deb = step(1.0 - 0.02 * debris_k, h3(floor(q * 34.0 / size) + seed)) * debris_k;
		vec3 c_sheet = mix(vec3(0.9, 0.92, 0.95), tint * 1.2, 0.3) * path;
		float a = clamp(sheet * frac_k * 0.4 + veil * 0.08 + bub * 0.6 + flow * 0.12, 0.0, 0.9) * inside * past;
		vec3 c = c_sheet * (sheet + veil * 0.7 + flow * 0.5) / max(sheet + veil + flow, 0.001);
		c = mix(c, vec3(1.0) * path, bub);
		acc += tr * a * c;
		tr *= 1.0 - a;
		// debris: dark, absorbing
		tr *= 1.0 - deb * 0.8 * inside;
	}
	// fractures: a few flat cracks through the stone, each a ragged disc; seen face-on almost nothing, at a glance a
	// bright milky sheet with a thin-film rainbow — the way cracks in ice and quartz flash as the stone turns
	vec3 crack_c = vec3(0.0);
	float crack_a = 0.0;
	for (int k = 0; k < 6; k++) {
		if (float(k) >= frac_k * 7.0) break;
		vec3 hk = vec3(h3(vec3(float(k), seed, 1.0)), h3(vec3(float(k), seed, 2.0)), h3(vec3(float(k), seed, 3.0)));
		vec3 pn = normalize(hk - 0.5);
		vec3 pc = (vec3(h3(vec3(float(k), seed, 4.0)), h3(vec3(float(k), seed, 5.0)), h3(vec3(float(k), seed, 6.0))) - 0.5) * size * 1.1;
		float dn = dot(pn, d);
		if (abs(dn) < 1e-3) continue;
		float tk = dot(pc - v_op, pn) / dn;
		if (tk < 0.0 || tk > min(t_hit, chord)) continue;
		vec3 pk = v_op + d * tk;
		vec3 rel = pk - pc;
		float rk = size * (0.35 + 0.35 * h3(vec3(float(k), seed, 7.0)));
		float edge = length(rel) / rk + (fbm(pk * 4.0 / size + float(k)) - 0.5) * 0.9;
		float inside_k = 1.0 - smoothstep(0.8, 1.0, edge);
		if (inside_k <= 0.0) continue;
		float glance = pow(1.0 - abs(dn), 2.0);
		// within the crack: feathery growth lines, patches where it is open and silvery
		float feather = 0.55 + 0.45 * smoothstep(0.3, 0.7, vn(pk * 9.0 / size + float(k)));
		vec3 film = mix(vec3(1.0), hue(fract(dot(rel, vec3(3.0, 2.0, 1.0)) / size + glance)) * 1.2, 0.25);
		float ak = inside_k * (0.06 + 0.55 * glance) * feather;
		crack_c += (1.0 - crack_a) * ak * film * path;
		crack_a += (1.0 - crack_a) * ak;
	}
	acc = acc * (1.0 - crack_a) + crack_c;
	tr *= 1.0 - crack_a;
	// what is behind (or the inclusion), bent by the skin, tinted by the way travelled (to the inclusion, or right
	// through: past where the march stopped, the tint keeps deepening)
	vec2 bend = n.xy * 0.05 * bend_k * (1.2 - abs(dot(n, VIEW)));
	vec3 behind = textureLod(screen_tex, SCREEN_UV - bend, 0.0).rgb;
	float rest = max(0.0, min(t_hit, chord) - min(t_hit, float(N) * st));
	path *= exp(-(vec3(1.0) - tint) * absorb * rest * 3.0);
	vec3 body = behind * path * tr + acc;
	// light scattered within the body: thick parts glow in its colour
	// (in front of the inclusion only the part before it glows, so it shows dark against the glowing body)
	float thick_v = min(chord, t_hit) / (2.0 * size);
	body += tint * glow_k * thick_v * (0.6 + 0.6 * fbm(v_op * 2.0 / size + seed + 60.0)) * 0.35;
	// the skin: polished, with frosted patches where it was chipped and rolled
	float fr = pow(1.0 - clamp(dot(n, VIEW), 0.0, 1.0), 3.0);
	float frost = smoothstep(0.58, 0.72, fbm(v_op * 3.0 / size + seed + 11.0)) * frost_k;
	vec3 wn = (INV_VIEW_MATRIX * vec4(n, 0.0)).xyz;
	vec3 wv = (INV_VIEW_MATRIX * vec4(-VIEW, 0.0)).xyz;
	vec3 refl = studio(reflect(wv, wn));
	body = mix(body, frost_col * (0.6 + 0.4 * fbm(v_op * 30.0 / size)), frost * 0.6);
	ALBEDO = vec3(0.0);
	// the reflection at a glance takes the body's colour a little (resin is not clear glass)
	EMISSION = body + refl * mix(vec3(1.0), tint, 0.5) * (0.04 + 0.45 * fr) * (1.0 - frost * 0.7);
	ROUGHNESS = mix(0.04, 0.45, frost);
	SPECULAR = 0.6;
	NORMAL = normalize(n + (vec3(vn(v_op * 14.0), vn(v_op * 14.0 + 3.3), vn(v_op * 14.0 + 7.1)) - 0.5) * frost * 0.4);
}
