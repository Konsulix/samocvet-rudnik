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
uniform float d_ao = 0.0;       // rocks: vertex colour carries the shading of pits and ridges
#ifdef GLASS
uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform float frost_k = 0.0;    // milky clouds inside the body
uniform float smoke_k = 0.0;    // smoky veils drifting through it
uniform vec3 smoke_col = vec3(0.2, 0.15, 0.1);
uniform float thick = 1.0;      // how strongly it bends what is behind
uniform float g_seed = 0.0;
#endif

varying vec3 v_op;
varying vec3 v_rp;

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
	float grains = smoothstep(0.8, 0.88, vn(v_rp * 70.0));
	rk += vec3(0.55, 0.52, 0.48) * grains * 0.4;
	rk = mix(rk, rk * 1.7 + 0.04, rim * 0.6);
	rk *= mix(1.0, COLOR.r * 1.25, d_ao);
	base = mix(base, vec3(0.86, 0.88, 0.9), frost * 0.5);
	a = mix(a, 0.96, frost * 0.55);
	base = mix(base, rk, dirt);
	a = mix(a, 1.0, dirt);
	r = mix(mix(r, 0.5, frost), mix(0.82, 0.35, grains), dirt);
	m *= 1.0 - dirt;
	cc *= 1.0 - max(dirt, frost * 0.6);
	vec3 gp = v_rp * 38.0;
	n = normalize(n + (dirt * 1.1 + frost * 0.25) * (vec3(vn(gp), vn(gp + 3.1), vn(gp + 5.7)) - 0.5));
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
	float milk = clamp(smoothstep(0.52, 0.74, fbm(v_op * 2.6 + g_seed)) * frost_k + frost * 0.9, 0.0, 1.0);
	float smoke = smoothstep(0.42, 0.78, fbm(v_op * 2.1 + g_seed + 17.0)) * smoke_k;
	vec2 bend = n.xy * (0.03 + 0.05 * thick) * (0.6 + edge_k);
	float split = 0.18 + 0.35 * edge_k;
	float blur = (0.002 + 0.012 * milk) * (0.5 + 0.5 * thick);
	vec2 uv = SCREEN_UV - bend;
	vec3 refr = vec3(behind(uv - bend * split, blur).r, behind(uv, blur).g, behind(uv + bend * split, blur).b);
	vec3 absorb = mix(vec3(1.0), tint0 / max(0.001, max(tint0.r, max(tint0.g, tint0.b))), clamp(0.35 + edge_k * 0.75, 0.0, 1.0));
	vec3 body = refr * absorb * mix(1.0, 0.75, edge_k);
	body = mix(body, tint0 * 0.5 + vec3(0.22), milk * 0.75);
	body = mix(body, body * smoke_col * 2.0, smoke);
	ALBEDO = mix(tint0 * milk * 0.35, base, dirt);
	METALLIC = 0.0;
	ROUGHNESS = mix(mix(0.02, 0.32, milk), r, dirt);
	SPECULAR = 0.6;
	CLEARCOAT = 0.0;
	// the rainbow film only blooms in patches, as on real crystals
	float film = 0.12 + 0.88 * smoothstep(0.5, 0.72, fbm(v_op * 1.6 + g_seed + 5.0));
	EMISSION = body * (1.0 - dirt) + (e + e_ir * film * 0.8) * (1.0 - dirt * 0.8);
	NORMAL = n;
	ALPHA = 1.0;
#elif defined(UNSHADED)
	ALBEDO = base + e + e_ir;
#else
	ALBEDO = base;
	METALLIC = m;
	ROUGHNESS = r;
	SPECULAR = spec;
	CLEARCOAT = cc;
	CLEARCOAT_ROUGHNESS = coat_rough;
	EMISSION = e + e_ir;
	NORMAL = n;
#endif
#if defined(TRANSP) && !defined(GLASS)
	ALPHA = a;
#endif
}
