shader_type spatial;
render_mode cull_back;
// (26.11) The chameleon's tongue (CardChameleon): wet pink flesh — a faint groove along its top, fine papillae as a
// bumpy sheen, wet streaks catching the light along its length, a darker sticky club at its tip (`tip` 1). UV.x runs
// root to tip, UV.y round it. `ghost` 1: its skeleton's tongue, a glow of the colour of the moment (`glow_col`).

uniform float tip = 0.0;
uniform float ghost = 0.0;
uniform vec3 glow_col : source_color = vec3(0.3, 0.9, 0.5);

float h2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn2(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1, 0)), f.x), mix(h2(i + vec2(0, 1)), h2(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec2 uv = UV;
	// papillae: fine bumps, round its girth and along it
	vec2 pu = vec2(uv.x * 90.0, uv.y * 22.0);
	float pap = vn2(pu) * 0.6 + vn2(pu * 2.3) * 0.4;
	// the groove along its top (uv.y 0 / 1 meet there)
	float gr = exp(-pow(min(uv.y, 1.0 - uv.y) / 0.06, 2.0));
	vec3 flesh = mix(vec3(0.6, 0.16, 0.24), vec3(0.75, 0.3, 0.36), smoothstep(0.3, 0.8, pap) * 0.6);
	flesh = mix(flesh, vec3(0.38, 0.08, 0.14), gr * 0.5);
	flesh = mix(flesh, vec3(0.5, 0.1, 0.18), tip);
	// wet: streaks along it where the light catches, mirror smooth there
	float wet = smoothstep(0.45, 0.8, vn2(vec2(uv.x * 6.0, uv.y * 3.0) + 5.0));
	ALBEDO = flesh;
	ROUGHNESS = mix(0.32, 0.04, max(wet, tip * 0.7)) + pap * 0.06;
	SPECULAR = 0.55;
	CLEARCOAT = 0.6;
	CLEARCOAT_ROUGHNESS = 0.08;
	// the bumps tilt the light a little
	vec2 dp = vec2(dFdx(pap), dFdy(pap));
	NORMAL = normalize(NORMAL + vec3(dp * 2.5, 0.0) * (1.0 - tip * 0.6));
	BACKLIGHT = flesh * 0.2;
	if (ghost > 0.5) {
		ALBEDO = glow_col * 0.15;
		EMISSION = glow_col * (1.1 + 0.6 * pap + 0.8 * tip);
		ROUGHNESS = 0.3;
	}
}
