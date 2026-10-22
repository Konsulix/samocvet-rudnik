// Shading for specimens, jewellery and machines. Variants are switched on with #defines
// (see SpecMat): FLAT faceted normals, TRANSP see-through, IRID oily rainbow film, growth
// striations, studio refraction and agate banding, DIRT the crystal turning into the rock it grew from.
// Vertex and per-instance colours multiply the base colour; all colours are linear.

#include "res://shaders/studio.gdshaderinc"

uniform vec3 albedo = vec3(1.0);
uniform float opacity = 1.0;
uniform float rough = 0.5;
uniform float metal = 0.0;
uniform vec3 emis = vec3(0.0);
uniform float coat = 0.0;
uniform float coat_rough = 0.05;
uniform float spec = 0.5;
uniform float grain = 0.0;
uniform float ir_k = 0.0;
uniform float rf_k = 0.0;
uniform float st_k = 0.0;
uniform float bd_k = 0.0;
uniform float d_h = -99.0;
uniform float d_a = 0.4;
uniform vec3 d_col = vec3(0.1);
uniform float d_fr = 0.0;
uniform float d_is = 0.0;
uniform float d_fb = 1.0;
// legendary effects, all of them alive (TIME): see SpecLegend
uniform float lava_k = 0.0;     // molten veins glowing in the rock
uniform float fluor_k = 0.0;    // every few seconds the lamps dim and the stone flares under ultraviolet
uniform vec3 fluor_col = vec3(0.3, 1.0, 0.2);
uniform float cham_k = 0.0;     // colour flows with the viewing angle and breathes slowly
uniform vec3 cham_col = vec3(0.6, 0.05, 0.15);
uniform float opal_k = 0.0;     // spectral flakes flashing in the body
uniform float star_k = 0.0;     // a night sky inside: twinkling stars, drifting nebula
uniform float kin_k = 0.0;      // kintsugi: veins of gold with a sliding gleam
uniform float heart_r = 0.0;    // a throbbing core of light deep inside (object space)
uniform vec3 heart_pos = vec3(0.0);
uniform vec3 heart_col = vec3(2.0, 1.6, 1.2);
uniform float oil_k = 0.0;      // dark lustrous stones: an oil-slick rainbow in their reflections
uniform float rough_var = 0.0;  // metals: polished bumps, dull hollows
uniform float d_ao = 0.0;       // rocks: vertex colour carries the shading of pits and ridges
// photo-scanned rock, laid on from three sides (no UVs needed)
uniform sampler2D scan_diff : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D scan_nrm : filter_linear_mipmap, repeat_enable;
uniform sampler2D scan_rough : filter_linear_mipmap, repeat_enable;
uniform float scan_k = 0.0;
uniform float scan_scale = 1.3;
#ifdef GLASS
uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform float frost_k = 0.0;    // milky clouds inside the body
uniform float smoke_k = 0.0;    // smoky veils drifting through it
uniform vec3 smoke_col = vec3(0.2, 0.15, 0.1);
uniform float thick = 1.0;      // how strongly it bends what is behind
uniform float g_seed = 0.0;
uniform float rim_k = 0.0;      // frosted silver along the real edges of the faces
uniform float holo_k = 0.0;     // broad holographic sheen in patches
#endif
varying vec3 v_bary;

varying vec3 v_op;
varying vec3 v_rp;
varying vec3 v_no;

float h3(vec3 p) { p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float vn(vec3 x) {
	vec3 i = floor(x), f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h3(i), h3(i + vec3(1, 0, 0)), f.x), mix(h3(i + vec3(0, 1, 0)), h3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(h3(i + vec3(0, 0, 1)), h3(i + vec3(1, 0, 1)), f.x), mix(h3(i + vec3(0, 1, 1)), h3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
float fbm(vec3 p) { return vn(p) * 0.5 + vn(p * 2.03) * 0.25 + vn(p * 4.01) * 0.125 + vn(p * 8.02) * 0.0625; }
#ifdef GLASS
// what is behind, softened when the glass is milky
vec3 behind(vec2 uv, float r) {
	vec3 c = textureLod(screen_tex, uv, 0.0).rgb;
	if (r > 0.0004) {
		c += textureLod(screen_tex, uv + vec2(r, 0.0), 0.0).rgb + textureLod(screen_tex, uv - vec2(r, 0.0), 0.0).rgb;
		c += textureLod(screen_tex, uv + vec2(0.0, r), 0.0).rgb + textureLod(screen_tex, uv - vec2(0.0, r), 0.0).rgb;
		c += textureLod(screen_tex, uv + vec2(r, r) * 0.7, 0.0).rgb + textureLod(screen_tex, uv - vec2(r, r) * 0.7, 0.0).rgb;
		c += textureLod(screen_tex, uv + vec2(r, -r) * 0.7, 0.0).rgb + textureLod(screen_tex, uv - vec2(r, -r) * 0.7, 0.0).rgb;
		c /= 9.0;
	}
	return c;
}
#endif

void vertex() {
	v_op = VERTEX;
	v_no = NORMAL;
	v_bary = CUSTOM0.xyz;
#ifdef DIRT
	v_rp = vec3(UV.x, UV.y, UV2.x);
#endif
}

void fragment() {
	vec3 n = normalize(NORMAL);
#ifdef FLAT
	n = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	if (dot(n, VIEW) < 0.0) n = -n;
#endif
	vec3 base = albedo * COLOR.rgb;
	vec3 tint0 = base;
	float a = opacity * COLOR.a;
	float r = rough;
	float m = metal;
	float cc = coat;
	float dirt = 0.0, frost = 0.0;
	vec3 lava_e = vec3(0.0);
	// ultraviolet flash: a few seconds of ordinary light, then the lamps dim and the stone glows
	float uv_ph = fract(TIME / 7.0 + fract(v_op.x * 0.0) );
	float uvk = fluor_k * smoothstep(0.55, 0.6, uv_ph) * (1.0 - smoothstep(0.88, 0.95, uv_ph));
#ifdef DIRT
	// below a ragged line the crystal turns into the rock it grew from; just above it, milky and etched
	float edge = v_rp.y - (d_h + (fbm(v_rp * 4.0) - 0.47) * d_a + (fbm(v_rp * 1.7 + 3.0) - 0.5) * d_a * 0.9);
	dirt = 1.0 - smoothstep(-0.012, 0.012, edge);
	// islands of crust above the line, and windows where the crystal shows through below it
	dirt = max(dirt, smoothstep(0.64, 0.67, fbm(v_rp * 5.5 + 11.0)) * max(1.0 - smoothstep(0.0, 0.8, edge), d_is));
	dirt *= 1.0 - smoothstep(0.68, 0.71, fbm(v_rp * 6.0 + 21.0)) * smoothstep(-0.7, -0.08, edge);
	float rim = 1.0 - smoothstep(0.0, 0.05, abs(edge));
	frost = (1.0 - smoothstep(0.0, 0.3, edge)) * (1.0 - dirt) * 0.85 * d_fb;
	frost = max(frost, smoothstep(0.6, 0.72, fbm(v_rp * 2.6 + 7.0)) * d_fr);
	vec3 rk = d_col * (0.3 + 1.2 * fbm(v_rp * 26.0)) * (0.7 + 0.5 * vn(v_rp * 5.0));
	rk = mix(rk, vec3(0.3, 0.11, 0.035) * (0.6 + 0.8 * vn(v_rp * 30.0)), smoothstep(0.55, 0.8, vn(v_rp * 9.0 + 5.0)) * 0.45);
	// glittering mineral grains
	float grains = smoothstep(0.86, 0.92, vn(v_rp * 70.0)) * 0.6;
	rk += vec3(0.55, 0.52, 0.48) * grains * 0.4;
	rk = mix(rk, rk * 1.7 + 0.04, rim * 0.6);
	float s_rough = 0.8;
	vec3 s_nv = n;
	if (scan_k > 0.0) {
		vec3 no = normalize(v_no);
		vec3 sp = v_rp * scan_scale;
		vec3 w = pow(abs(no), vec3(4.0));
		w /= (w.x + w.y + w.z);
		vec3 sd = texture(scan_diff, sp.zy).rgb * w.x + texture(scan_diff, sp.xz).rgb * w.y + texture(scan_diff, sp.xy).rgb * w.z;
		s_rough = texture(scan_rough, sp.zy).r * w.x + texture(scan_rough, sp.xz).r * w.y + texture(scan_rough, sp.xy).r * w.z;
		vec3 tx = texture(scan_nrm, sp.zy).xyz * 2.0 - 1.0;
		vec3 ty = texture(scan_nrm, sp.xz).xyz * 2.0 - 1.0;
		vec3 tz = texture(scan_nrm, sp.xy).xyz * 2.0 - 1.0;
		tx = vec3(tx.xy + no.zy, abs(tx.z) * no.x);
		ty = vec3(ty.xy + no.xz, abs(ty.z) * no.y);
		tz = vec3(tz.xy + no.xy, abs(tz.z) * no.z);
		vec3 ns = normalize(tx.zyx * w.x + ty.xzy * w.y + tz.xyz * w.z);
		s_nv = normalize((VIEW_MATRIX * MODEL_MATRIX * vec4(ns, 0.0)).xyz);
		if (dot(s_nv, VIEW) < 0.0) s_nv = -s_nv;
		// the scan gives the grain, the rock's own palette sets how dark and what colour it is
		vec3 tinted = mix(sd * 0.8, sd * d_col / 0.3, 0.75);
		tinted = pow(tinted, vec3(1.15));
		rk = mix(rk, tinted * (1.0 + rim * 0.5) + vec3(0.5, 0.48, 0.44) * grains * 0.25, scan_k);
	}
	rk *= mix(1.0, COLOR.r * 1.25, d_ao);
	if (lava_k > 0.0) {
		// molten rock: a black cooled crust split by veins of lava that throb and creep
		float hollow_r = smoothstep(0.35, 0.75, 1.0 - COLOR.r);
		float vein = 1.0 - smoothstep(0.0, 0.045, abs(fbm(v_rp * 3.2 + vec3(0.0, TIME * 0.04, 0.0)) - 0.5));
		float flow = 0.55 + 0.45 * sin(TIME * 2.2 + fbm(v_rp * 6.0 + TIME * 0.1) * 9.0);
		float heat = clamp(vein * 1.2 + hollow_r * 0.8, 0.0, 1.0) * flow;
		rk = mix(rk * 0.35, vec3(0.04, 0.02, 0.015), 0.5 * lava_k);
		lava_e = mix(vec3(2.2, 0.35, 0.03), vec3(4.0, 1.9, 0.35), heat * heat) * heat * lava_k * dirt;
	}
	base = mix(base, vec3(0.86, 0.88, 0.9), frost * 0.5);
	a = mix(a, 0.96, frost * 0.55);
	base = mix(base, rk, dirt);
	a = mix(a, 1.0, dirt);
	r = mix(mix(r, 0.5, frost), mix(mix(0.82, 0.35, grains), s_rough, scan_k), dirt);
	m *= 1.0 - dirt;
	cc *= 1.0 - max(dirt, frost * 0.6);
	vec3 gp = v_rp * 38.0;
	n = normalize(n + (dirt * 1.1 * (1.0 - scan_k * 0.8) + frost * 0.25) * (vec3(vn(gp), vn(gp + 3.1), vn(gp + 5.7)) - 0.5));
	n = normalize(mix(n, s_nv, dirt * scan_k));
#endif
	if (grain > 0.0) {
		vec3 gq = v_op * 60.0;
		n = normalize(n + grain * (vec3(vn(gq), vn(gq + 3.1), vn(gq + 5.7)) - 0.5));
	}
	vec3 e = emis;
	vec3 e_ir = vec3(0.0);
#ifdef IRID
	float stb = sin(v_op.y * 70.0 + sin(v_op.x * 9.0 + v_op.z * 7.0) * 3.0) * sin(v_op.y * 23.0 + v_op.x * 5.0);
	n = normalize(n + st_k * (1.0 - dirt) * vec3(0.0, stb * 0.075, 0.0));
	float clean = 1.0 - max(dirt, frost * 0.7);
	if (bd_k > 0.0) base *= 1.0 - bd_k * (0.5 + 0.5 * sin(length(v_op) * 140.0 + sin(v_op.x * 20.0) * 1.5));
	float fr = 1.0 - abs(dot(n, VIEW));
	float hue = fr * 2.4 + sin(v_op.x * 9.0 + v_op.y * 5.0) * 0.35 + sin(v_op.z * 11.0 - v_op.y * 7.0) * 0.25;
	vec3 ir = 0.5 + 0.5 * cos(6.2832 * (hue + vec3(0.0, 0.33, 0.67)));
	float msk = smoothstep(0.15, 0.85, sin(v_op.y * 6.0 + v_op.x * 4.0 + v_op.z * 3.0) * 0.5 + 0.5);
	e_ir = ir * ir_k * clean * (ir_k > 1.5 ? 0.7 + 0.6 * fr : 0.2 + 0.8 * fr * fr) * (ir_k > 1.5 ? 1.0 : 0.35 + 0.65 * msk);
	if (rf_k > 0.0) {
		// the studio seen through the stone, each colour bent a little differently
		vec3 nw = (INV_VIEW_MATRIX * vec4(n, 0.0)).xyz;
		vec3 iw = (INV_VIEW_MATRIX * vec4(-VIEW, 0.0)).xyz;
		vec3 cr = vec3(studio(refract(iw, nw, 0.64)).r, studio(refract(iw, nw, 0.61)).g, studio(refract(iw, nw, 0.58)).b);
		e += cr * base * 1.3 * rf_k * clean;
	}
#endif
#ifdef GLASS
	// real glass: the scene behind bent by the facets and split into colours, tinted by the body,
	// clouded where it grew milky, veiled with smoke, catching the studio lamps on its faces
	vec3 gq = v_op * 9.0 + g_seed;
	n = normalize(n + (vec3(vn(gq), vn(gq + 3.3), vn(gq + 7.1)) - 0.5) * 0.06);
	float cosv = abs(dot(n, VIEW));
	float edge_k = 1.0 - cosv;
	// eaten hollows: dark pockets ringed with frosted, etched glass
	float pit = clamp(1.0 - COLOR.a, 0.0, 1.0);
	frost = max(frost, smoothstep(0.05, 0.35, pit) * 0.4);
	float milk = clamp(smoothstep(0.52, 0.74, fbm(v_op * 2.6 + g_seed)) * frost_k + frost * 0.9, 0.0, 1.0);
	float smoke = smoothstep(0.42, 0.78, fbm(v_op * 2.1 + g_seed + 17.0)) * smoke_k;
	vec2 bend = n.xy * (0.03 + 0.05 * thick) * (0.6 + edge_k);
	float split = 0.18 + 0.35 * edge_k;
	float blur = (0.002 + 0.012 * milk) * (0.5 + 0.5 * thick);
	vec2 uv = SCREEN_UV - bend;
	vec3 refr = vec3(behind(uv - bend * split, blur).r, behind(uv, blur).g, behind(uv + bend * split, blur).b);
	if (cham_k > 0.0) {
		// alexandrite-like: one colour face-on, another at a glance, the balance breathing over time
		float cm = clamp(edge_k * 1.6 + 0.25 * sin(TIME * 0.6 + v_op.y * 2.0), 0.0, 1.0);
		tint0 = mix(tint0, cham_col, cm * cham_k);
	}
	vec3 absorb = mix(vec3(1.0), tint0 / max(0.001, max(tint0.r, max(tint0.g, tint0.b))), clamp(0.35 + edge_k * 0.75, 0.0, 1.0));
	vec3 body = refr * absorb * mix(1.0, 0.75, edge_k);
	if (star_k > 0.0) {
		// a night sky trapped inside: deep blue body, nebula drifting, stars twinkling at two depths
		body = mix(body, body * vec3(0.05, 0.06, 0.14), star_k * 0.85);
		vec3 sp = v_op + (INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz * 0.15;
		float neb = fbm(sp * 2.2 + vec3(TIME * 0.02, 0.0, TIME * 0.015));
		body += mix(vec3(0.25, 0.05, 0.45), vec3(0.05, 0.35, 0.6), fbm(sp * 1.3)) * smoothstep(0.45, 0.8, neb) * star_k * 0.9;
		for (int L = 0; L < 2; L++) {
			vec3 q = sp * (28.0 + float(L) * 19.0) + float(L) * 7.0;
			vec3 cell = floor(q);
			float h = h3(cell);
			float d = length(fract(q) - 0.5);
			float tw = 0.5 + 0.5 * sin(TIME * (2.0 + h * 5.0) + h * 40.0);
			body += vec3(1.6, 1.5, 1.3) * step(0.93, h) * (1.0 - smoothstep(0.05, 0.16, d)) * tw * star_k * 2.5;
		}
	}
	if (opal_k > 0.0) {
		// play of colour: flakes that flash pure spectral colours as the stone turns
		vec3 q = v_op * 11.0;
		vec3 cell = floor(q);
		float h = h3(cell);
		float fl = smoothstep(0.55, 1.0, sin(h * 37.0 + TIME * 1.4 + edge_k * 7.0) * 0.5 + 0.5);
		vec3 sc = 0.5 + 0.5 * cos(6.2832 * (h * 3.0 + edge_k + TIME * 0.05 + vec3(0.0, 0.33, 0.67)));
		body += sc * fl * opal_k * 1.6 * (1.0 - smoothstep(0.35, 0.5, length(fract(q) - 0.5)));
	}
	body = mix(body, tint0 * 0.5 + vec3(0.22), milk * 0.75);
	body = mix(body, body * smoke_col * 2.0, smoke);
	// silver rims: the edges frost over into a bright, ragged, slightly metallic band
	float srim = 0.0;
	if (rim_k > 0.0) {
		float eb = min(v_bary.x, min(v_bary.y, v_bary.z));
		// ragged: in places the frost eats deep into the face, elsewhere it is a hairline
		float rw = 0.022 * (0.25 + 1.6 * smoothstep(0.3, 0.75, fbm(v_op * 6.0 + g_seed))) * rim_k;
		srim = (1.0 - smoothstep(rw * 0.1, rw * 1.4, eb + (vn(v_op * 90.0) - 0.5) * rw * 0.5)) * (1.0 - dirt);
		srim *= 0.7 + 0.5 * vn(v_op * 55.0);
		srim = clamp(srim, 0.0, 1.0);
	}
	// holographic sheen: wide rainbow gradients sweeping across some faces
	if (holo_k > 0.0) {
		float fr2 = 1.0 - cosv;
		float hh = dot(v_op, vec3(0.7, 1.1, 0.4)) * 0.9 + fr2 * 0.9 + vn(v_op * 0.9 + g_seed) * 1.4;
		vec3 holo = 0.5 + 0.5 * cos(6.2832 * (hh + vec3(0.0, 0.33, 0.67)));
		float hm = smoothstep(0.35, 0.7, vn(v_op * 1.2 + g_seed + 5.0) * 0.7 + vn(v_op * 2.3 + g_seed) * 0.3);
		body += holo * holo_k * hm * (0.35 + 0.65 * fr2) * (1.0 - milk * 0.5) * (1.0 - dirt);
	}
	vec3 pitc = tint0 * 0.035 + vec3(0.004, 0.003, 0.006);
	float hollow = smoothstep(0.3, 0.7, pit) * (1.0 - dirt);
	body = mix(body, pitc, hollow);
	vec3 silver = vec3(0.85, 0.87, 0.9) * (0.6 + 0.6 * fbm(v_op * 40.0));
	body = mix(body, silver * 0.55, srim * 0.85);
	ALBEDO = mix(mix(mix(tint0 * milk * 0.35, silver, srim), pitc, hollow), base, dirt);
	METALLIC = srim * 0.65;
	ROUGHNESS = mix(mix(mix(mix(0.02, 0.32, milk), 0.38, srim), 0.8, hollow), r, dirt);
	SPECULAR = mix(0.6, 0.08, hollow);
	CLEARCOAT = 0.0;
	// the rainbow film only blooms in patches, as on real crystals
	float film = 0.12 + 0.88 * smoothstep(0.5, 0.72, fbm(v_op * 1.6 + g_seed + 5.0));
	if (heart_r > 0.0) {
		// how close the line of sight passes to the core: a glow seen through the whole thickness
		mat4 inv_m = inverse(MODEL_MATRIX);
		vec3 o = (inv_m * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
		vec3 dir = normalize((inv_m * vec4((INV_VIEW_MATRIX * vec4(-VIEW, 0.0)).xyz, 0.0)).xyz);
		vec3 hv = heart_pos - o;
		float dd = length(hv - dir * dot(hv, dir)) / heart_r;
		float beat = 0.7 + 0.3 * pow(0.5 + 0.5 * sin(TIME * 2.6), 4.0);
		body += heart_col * (exp(-dd * dd * 2.2) * 1.4 + exp(-dd * 0.9) * 0.25) * beat * (1.0 - dirt);
	}
	if (kin_k > 0.0) {
		// kintsugi: thin veins of gold over the faces, a gleam sliding along them
		// lines of even width: the zero-crossings of a noise, widened by how fast it changes on screen
		float kn = fbm(v_op * 7.0 + g_seed) - 0.5;
		float kw = fwidth(kn) * 2.5 + 0.014;
		float vk = 1.0 - smoothstep(kw * 0.5, kw, abs(kn));
		float gleam = pow(0.5 + 0.5 * sin(dot(v_op, vec3(3.0, 5.0, 2.0)) - TIME * 2.5), 6.0);
		vec3 gold = vec3(1.0, 0.52, 0.1);
		body = mix(body, gold * (0.45 + 1.8 * gleam), vk * kin_k);
		ALBEDO = mix(ALBEDO, gold, vk * kin_k);
		METALLIC = max(METALLIC, vk * kin_k);
		ROUGHNESS = mix(ROUGHNESS, 0.15, vk * kin_k);
	}
	// ultraviolet: the stone drowns in its own glow while the lamps go dark
	body = mix(body, fluor_col * (1.2 + 0.8 * fbm(v_op * 4.0 + TIME * 0.3)) * (1.0 - milk * 0.3), uvk);
	ALBEDO *= 1.0 - uvk * 0.85;
	EMISSION = body * (1.0 - dirt) + (e + e_ir * film * 0.25) * (1.0 - dirt * 0.8) * (1.0 - hollow * 0.92) + lava_e;
	NORMAL = n;
	ALPHA = 1.0;
#elif defined(UNSHADED)
	ALBEDO = base + e + e_ir;
#else
	// opaque stones and metals. Eaten hollows (vertex alpha) go dark and dull.
	float o_pit = smoothstep(0.3, 0.75, 1.0 - COLOR.a) * (1.0 - dirt);
	float o_fr = 1.0 - abs(dot(n, VIEW));
	if (oil_k > 0.0) {
		// a dark crystal with an oily, rainbow sheen sliding over its faces
		float oh = fbm(v_op * 1.7 + 3.0) * 1.6 + o_fr * 1.3 + v_op.y * 0.4;
		vec3 oil = 0.5 + 0.5 * cos(6.2832 * (oh + vec3(0.0, 0.33, 0.67)));
		float om = smoothstep(0.55, 0.72, fbm(v_op * 1.1 + 9.0)) * (1.0 - dirt);
		base = mix(base, oil * 0.4, om * oil_k * 0.7);
		m = mix(m, 0.9, om * oil_k);
		e += oil * om * oil_k * (0.02 + 0.12 * o_fr * o_fr);
		// a cold sheen at grazing angles even where there is no rainbow
		e += vec3(0.05, 0.12, 0.13) * o_fr * o_fr * oil_k * (1.0 - om);
		// glinting scratches and chips along the faces
		float sc = smoothstep(0.82, 0.9, vn(v_op * vec3(4.0, 40.0, 4.0)));
		r = mix(r, 0.05, sc * 0.6);
	}
	if (rough_var > 0.0) {
		r = clamp(r + (fbm(v_op * 18.0) - 0.5) * rough_var + (1.0 - COLOR.g) * rough_var, 0.04, 1.0);
	}
	base = mix(base, base * 0.08, o_pit);
	ALBEDO = base;
	METALLIC = m * (1.0 - o_pit * 0.7);
	ROUGHNESS = mix(r, 0.85, o_pit);
	SPECULAR = spec;
	CLEARCOAT = cc;
	CLEARCOAT_ROUGHNESS = coat_rough;
	EMISSION = (e + e_ir) * (1.0 - o_pit) + lava_e + fluor_col * uvk * 1.4;
	ALBEDO *= 1.0 - uvk * 0.85;
	NORMAL = n;
#endif
#if defined(TRANSP) && !defined(GLASS)
	ALPHA = a;
#endif
}
