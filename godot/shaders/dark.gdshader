shader_type canvas_item;
// The dark of an unlit gallery over the board (BoardModel.DARK). `mask` is a texel a cell (1 dark, 0 lit, in between
// while a cell is being lit) with a cell of margin, sampled smoothly so the dark is one body with a soft front, not a
// grid of squares. The stones stay faintly seen in it (one plans a way through), slow dust drifts in it, and where the
// light meets it the front glows warm, as lamplight on the rock - the way the light has to be carried on.
// Drawn as one rect over the grid; UV runs over the mask's texels.

uniform sampler2D mask : filter_linear;
uniform vec2 cells = vec2(11.0, 13.0);
uniform vec3 deep : source_color = vec3(0.015, 0.016, 0.03);
uniform vec3 warm : source_color = vec3(1.0, 0.62, 0.22);
uniform float depth = 0.64;      // how much of a stone's light the full dark takes

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) {
	float s = 0.0, a = 0.5;
	for (int k = 0; k < 4; k++) { s += a * noise(p); p = p * 2.03 + vec2(1.7, 9.2); a *= 0.5; }
	return s;
}
// the mask smoothed over a cell: four taps round the point
float field(vec2 uv) {
	vec2 e = 0.38 / cells;
	return 0.25 * (texture(mask, uv + vec2(e.x, e.y)).r + texture(mask, uv + vec2(-e.x, e.y)).r
		+ texture(mask, uv + vec2(e.x, -e.y)).r + texture(mask, uv + vec2(-e.x, -e.y)).r);
}

void fragment() {
	vec2 b = UV * cells;
	float t = TIME;
	float f = field(UV);
	// the front wavers a little, as a flame's light does
	float flick = 0.035 * sin(t * 7.3 + b.x * 1.7) + 0.025 * sin(t * 11.1 - b.y * 2.3);
	float v = f + (fbm(b * 1.7 + vec2(t * 0.05, -t * 0.03)) - 0.5) * 0.32 + flick;
	float dark = smoothstep(0.3, 0.62, v);
	// the warm glow on the near side of the front
	float front = smoothstep(0.08, 0.36, v) * (1.0 - smoothstep(0.36, 0.6, v));
	if (dark <= 0.001 && front <= 0.001) discard;
	// dust drifting slowly in the dark, catching what little light there is
	float dust = smoothstep(0.82, 0.95, fbm(b * 3.1 + vec2(t * 0.11, t * 0.07)));
	vec3 col = mix(deep, vec3(0.09, 0.08, 0.1), dust * 0.6);
	col = mix(col, warm * 0.55, front * 0.6);
	float a = dark * depth + front * 0.18;
	COLOR = vec4(col, clamp(a, 0.0, 0.92));
}
