shader_type canvas_item;
// Fire Horizon's molten metal (ForgeView: the crucibles, the metal over stones, the billets, their flakes and drops).
// Whatever is drawn hot - orange to yellow and bright - glows and flows: two layers of slow noise in board space drift
// through it, so the cracks of a metal skin breathe and run, the metal in a crucible churns and the cut end of a billet
// shimmers; cooler colours (clay, iron, the dull skin) are left as they are.

uniform float cell_px = 37.0;
uniform float glow = 1.0;

varying vec2 wpos;

float h2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1.0, 0.0)), f.x), mix(h2(i + vec2(0.0, 1.0)), h2(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 c = COLOR;
	float lum = dot(c.rgb, vec3(0.3, 0.55, 0.15));
	// hot: much more red than blue, and bright
	float hot = smoothstep(0.12, 0.42, c.r - c.b) * smoothstep(0.32, 0.72, lum);
	vec2 p = wpos / cell_px;
	float n1 = vn(p * 2.6 + vec2(TIME * 0.32, -TIME * 0.21));
	float n2 = vn(p * 6.5 - vec2(TIME * 0.47, TIME * 0.29));
	float n = n1 * 0.6 + n2 * 0.4;
	// a brighter vein crawling along the hot parts now and then
	float vein = smoothstep(0.62, 0.8, vn(p * 1.4 + vec2(-TIME * 0.18, TIME * 0.12)));
	float pulse = 0.55 + 0.75 * n + 0.6 * vein;
	vec3 emit = vec3(1.0, 0.58, 0.2) * hot * pulse * glow;
	c.rgb = c.rgb * (1.0 + hot * 0.3 * (n - 0.5)) + emit * 0.42;
	// the hottest spots go towards white
	c.rgb += vec3(1.0, 0.9, 0.6) * smoothstep(0.75, 1.0, hot * pulse) * 0.25 * glow;
	COLOR = c;
}
