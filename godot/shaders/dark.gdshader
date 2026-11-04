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
uniform float depth = 0.86;      // how much of a stone's light the full dark takes (the tray is light: deep, or it does not read)

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
// the mask cell by cell: inside a cell its own value, blending into the neighbour only in a thin band at the cell's
// edge - the dark keeps to the cells (a blurred mask spread a round blob over the frame and the background)
float field(vec2 uv) {
	vec2 b = uv * cells;
	vec2 c = floor(b) + 0.5;
	vec2 d = fract(b) - 0.5;
	vec2 f = sign(d) * max(abs(d) - 0.42, 0.0) / 0.08 * 0.5;   // 0 inside, out to the shared edge only in the last 8%
	return texture(mask, (c + f) / cells).r;
}

void fragment() {
	vec2 b = UV * cells;
	// the mask's margin repeats the edge cells: the dark stops at the board's edge, under the frame
	if (b.x < 1.0 || b.y < 1.0 || b.x > cells.x - 1.0 || b.y > cells.y - 1.0) discard;
	float t = TIME;
	float f = field(UV);
	// the front wavers a little, as a flame's light does
	float flick = 0.035 * sin(t * 7.3 + b.x * 1.7) + 0.025 * sin(t * 11.1 - b.y * 2.3);
	float v = f + flick * 0.15;
	float dark = smoothstep(0.3, 0.7, v);   // the cells are either dark or lit, the edge band is the fade
	// the warm glow on the near side of the front
	float front = smoothstep(0.05, 0.3, v) * (1.0 - smoothstep(0.3, 0.6, v));
	if (dark <= 0.001 && front <= 0.001) discard;
	// dust drifting slowly in the dark, catching what little light there is
	float dust = smoothstep(0.82, 0.95, fbm(b * 3.1 + vec2(t * 0.11, t * 0.07)));
	vec3 col = mix(deep, vec3(0.09, 0.08, 0.1), dust * 0.6);
	col = mix(col, warm * 0.55, front * 0.6);
	float a = dark * depth + front * 0.18;
	COLOR = vec4(col, clamp(a, 0.0, 0.92));
}
