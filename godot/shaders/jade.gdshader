shader_type spatial;
// Jadeite (SpecimenBuilder._jade): a polished pebble grown into rough rock, its pattern solid in the stone's own space,
// pixel by pixel — patches and soft veins of colour through a paler (or deeper) body, a granular sugar of interlocking
// grains under the polish; waxy, lit from within, glowing brighter where it is thin at the edges.

uniform vec3 c_base : source_color = vec3(0.3, 0.6, 0.35);
uniform vec3 c_patch : source_color = vec3(0.2, 0.7, 0.3);
uniform vec3 c_vein : source_color = vec3(0.08, 0.35, 0.15);
uniform float patch_k = 0.4;    // how much of it the patches cover
uniform float vein_k = 0.5;
uniform float glow_k = 0.35;    // the light from within
uniform float seed = 0.0;
uniform float scale = 1.0;      // the pattern's size (in the pebble's own units)

varying vec3 v_op;

float h3(vec3 p) { p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float vn(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h3(i), h3(i + vec3(1, 0, 0)), f.x), mix(h3(i + vec3(0, 1, 0)), h3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(h3(i + vec3(0, 0, 1)), h3(i + vec3(1, 0, 1)), f.x), mix(h3(i + vec3(0, 1, 1)), h3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
float fbm(vec3 p) { return vn(p) * 0.5 + vn(p * 2.03 + 7.1) * 0.25 + vn(p * 4.01 + 3.3) * 0.125 + vn(p * 8.03 + 1.7) * 0.0625; }
// the grains: distance to the nearest cell point, and that cell's id
vec2 grains(vec3 p) {
	vec3 n = floor(p);
	vec3 f = fract(p);
	float md = 8.0;
	float id = 0.0;
	for (int k = -1; k <= 1; k++) for (int j = -1; j <= 1; j++) for (int i = -1; i <= 1; i++) {
		vec3 g = vec3(float(i), float(j), float(k));
		vec3 o = vec3(h3(n + g + 1.3), h3(n + g + 7.7), h3(n + g + 3.1));
		float d = length(g + o - f);
		if (d < md) { md = d; id = h3(n + g + 11.0); }
	}
	return vec2(md, id);
}

void vertex() {
	v_op = VERTEX;
}

void fragment() {
	vec3 p = v_op * scale + seed;
	// patches: soft-edged clouds of colour, warped so they run in streaks
	vec3 w = p + vec3(fbm(p * 1.3), fbm(p * 1.3 + 5.2), fbm(p * 1.3 + 9.7)) * 1.4;
	float pt = smoothstep(0.62 - patch_k * 0.35, 0.7 - patch_k * 0.35, fbm(w * 1.8));
	// veins: thin wandering lines of the deep colour
	float vl = 1.0 - smoothstep(0.0, 0.05, abs(fbm(w * 2.6 + 3.0) - 0.5));
	vec3 col = mix(c_base, c_patch, pt);
	col = mix(col, c_vein, vl * vein_k * 0.8);
	// the granular texture under the polish: each grain a touch lighter or darker, its boundary faintly seen
	vec2 gr = grains(p * 22.0);
	col *= 0.9 + 0.2 * gr.y;
	col *= 1.0 - 0.12 * (1.0 - smoothstep(0.0, 0.18, abs(gr.x - 0.6)));
	ALBEDO = col * 0.75;
	// waxy and lit from within; brighter where the light passes through the thin rounded edge
	float fr = 1.0 - clamp(dot(normalize(NORMAL), VIEW), 0.0, 1.0);
	EMISSION = col * glow_k * (0.6 + 1.2 * fr * fr);
	ROUGHNESS = 0.22;
	SPECULAR = 0.5;
	CLEARCOAT = 0.9;
	CLEARCOAT_ROUGHNESS = 0.05;
	BACKLIGHT = col * 0.5;
}
