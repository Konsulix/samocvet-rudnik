shader_type canvas_item;
render_mode blend_add;
// Proval's aurora (IceView): slow curtains of pale cyan and violet light drifting over the polar night sky, only where
// the sky shows (the mask: white where the picture is sky, cut out by export_mine5.py), so the mountain and the roofs
// stay in front of it. `k` is how strong it is now (stronger at night by the phone's clock, flaring with a gust).
uniform sampler2D mask : filter_linear;
uniform float k = 1.0;
uniform float t = 0.0;

float h1(float x) { return fract(sin(x * 127.1) * 43758.5453); }
float vn(float x) { float i = floor(x); float f = fract(x); f = f * f * (3.0 - 2.0 * f); return mix(h1(i), h1(i + 1.0), f); }

void fragment() {
	vec2 uv = UV;
	float m = texture(mask, uv).r;
	// three curtains, each a folded band: its x wavers with height and time, its brightness rays up and down it
	vec3 col = vec3(0.0);
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		float fold = 0.08 * sin(uv.y * 5.0 + t * (0.13 + fi * 0.05) + fi * 2.1) + 0.05 * sin(uv.y * 13.0 - t * 0.21 + fi);
		float cx = 0.18 + fi * 0.32 + 0.06 * sin(t * 0.05 + fi * 1.7) + fold;
		float d = abs(uv.x - cx);
		float band = exp(-d * d / (0.0016 + 0.0012 * fi));
		float rays = 0.55 + 0.45 * vn(uv.x * 60.0 + t * 0.6 + fi * 9.0);
		// bright at its lower hem, fading upwards
		float hem = smoothstep(0.0, 0.25, uv.y) * (1.0 - smoothstep(0.55, 1.0, uv.y));
		float a = band * rays * hem * (0.6 + 0.4 * sin(t * 0.3 + fi * 2.4));
		vec3 c = mix(vec3(0.35, 0.95, 1.0), vec3(0.62, 0.42, 1.0), smoothstep(0.1, 0.6, 1.0 - uv.y) * (0.5 + 0.5 * sin(fi * 2.0 + t * 0.07)));
		col += c * a;
	}
	COLOR = vec4(col * m * k * 0.55, 1.0);
}
