
shader_type spatial;
render_mode cull_disabled;
uniform vec3 cap_a;
uniform vec3 cap_b;
uniform vec3 gill;
uniform vec3 stem;
uniform float cap_r = 0.4;
uniform float spots = 0.0;
uniform float gills_n = 40.0;
uniform float pores = 0.0;
uniform float glow = 0.0;
uniform float rough_cap = 0.5;
global uniform float fluor_uv;
varying vec3 v_op;
varying float v_reg;
float h3(vec3 p) { p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float vn(vec3 x) {
	vec3 i = floor(x), f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h3(i), h3(i + vec3(1, 0, 0)), f.x), mix(h3(i + vec3(0, 1, 0)), h3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(h3(i + vec3(0, 0, 1)), h3(i + vec3(1, 0, 1)), f.x), mix(h3(i + vec3(0, 1, 1)), h3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
void vertex() { v_op = VERTEX; v_reg = UV2.x; }
void fragment() {
	float capk = step(0.75, v_reg);
	float underk = step(0.25, v_reg) * (1.0 - capk);
	float stemk = 1.0 - capk - underk;
	float rr = length(v_op.xz);
	float ang = atan(v_op.z, v_op.x);
	// cap: dark centre to a paler rim, mottled, with raised white warts on the agaric
	vec3 cc = mix(cap_a, cap_b, smoothstep(0.15, 1.0, rr / cap_r)) * (0.82 + 0.3 * vn(v_op * 14.0));
	float wart = smoothstep(0.66, 0.72, vn(v_op * 15.0)) * spots;
	cc = mix(cc, vec3(0.94, 0.9, 0.82), wart);
	// underside: fine radial gills or a sponge of pores
	float g = 0.5 + 0.5 * sin(ang * gills_n);
	vec3 uc = gill * mix(1.0, mix(0.5, 1.0, smoothstep(0.15, 0.85, g)), step(1.0, gills_n));
	uc *= mix(1.0, 0.55 + 0.45 * smoothstep(0.35, 0.6, vn(v_op * 110.0)), pores);
	// stem: lengthwise fibres
	vec3 sc = stem * (0.82 + 0.25 * vn(vec3(v_op.x * 45.0, v_op.y * 5.0, v_op.z * 45.0)));
	vec3 c = sc * stemk + uc * underk + cc * capk;
	ALBEDO = c * COLOR.rgb;
	ROUGHNESS = mix(0.78, rough_cap, capk) - wart * 0.2;
	SPECULAR = 0.35;
	BACKLIGHT = c * 0.15;
	// mycena glow: the gills brightest, breathing slowly; brighter still when the room goes dark
	float br = (0.8 + 0.2 * sin(TIME * 1.3 + v_op.y * 4.0)) * (1.0 + fluor_uv * 1.5);
	EMISSION = glow * vec3(0.25, 0.95, 0.35) * (underk * 0.9 + capk * 0.3 + stemk * 0.15) * br;
}
