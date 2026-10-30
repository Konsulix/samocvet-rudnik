shader_type canvas_item;
// The Kraken's ink over the board: one cloud field over the whole grid, not cell by cell. `mask` is the board's ink, a
// texel a cell (1 just spilled, ~0.55 on its last move, 0 none) with a cell of margin round it, sampled smoothly - so
// inked cells next to each other melt into one blot and its outline rounds off between the cell centres. Noise eats
// the rim into wisps and curls the ink in itself: dark folds with a faint cold sheen on the curls catching the light
// from the top left. Dense enough to hide the stones; on its last move the blot shrinks and breaks into wisps.
// Drawn as one rect over the grid; UV runs over the mask's texels.

uniform sampler2D mask : filter_linear;
uniform vec2 cells = vec2(9.0, 10.0);      // the mask's size, in cells (margin included)
uniform vec3 deep : source_color = vec3(0.01, 0.01, 0.025);
uniform vec3 body_col : source_color = vec3(0.045, 0.04, 0.09);
uniform vec3 sheen : source_color = vec3(0.2, 0.22, 0.34);
uniform vec3 glint : source_color = vec3(0.5, 0.88, 1.0);
uniform float speed = 0.1;

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
// ink curling in water: the position swirled twice by slow noise, so its folds roll over each other
float ink(vec2 b, float t) {
	vec2 q = vec2(fbm(b * 1.1 + vec2(0.0, t)), fbm(b * 1.1 + vec2(4.7, -t * 0.7)));
	vec2 r = vec2(fbm(b * 1.6 + q * 2.4 + vec2(1.3, t * 0.6)), fbm(b * 1.6 + q * 2.4 + vec2(8.1, -t * 0.5)));
	return fbm(b * 1.9 + r * 2.2);
}
// the mask smoothed over a cell (bilinear alone keeps the cell grid in it): four taps round the point
float field(vec2 uv) {
	vec2 e = 0.35 / cells;
	return 0.25 * (texture(mask, uv + vec2(e.x, e.y)).r + texture(mask, uv + vec2(-e.x, e.y)).r
		+ texture(mask, uv + vec2(e.x, -e.y)).r + texture(mask, uv + vec2(-e.x, -e.y)).r);
}

void fragment() {
	vec2 b = UV * cells;                    // board position, in cells
	float t = TIME * speed;
	float s = ink(b, t);
	float f = field(UV);
	// the blot: the smoothed mask, its rim eaten by noise and by the ink's own folds
	float v = f + (fbm(b * 2.3 + vec2(t, -t * 1.3)) - 0.5) * 0.45 + (s - 0.5) * 0.3;
	float body = smoothstep(0.36, 0.5, v);
	if (body <= 0.0) discard;
	float toward = ink(b + vec2(-0.05, -0.05), t);
	float light = clamp(0.5 + (s - toward) * 8.0, 0.0, 1.0);
	float fold = smoothstep(0.35, 0.7, s);
	vec3 col = mix(deep, body_col, fold);
	col = mix(col, sheen, light * light * fold * 0.4);
	// a thin cold glint along the crests of the folds, as on oil, slowly coming and going
	float crest = 1.0 - smoothstep(0.0, 0.02, abs(s - 0.6));
	col = mix(col, glint, crest * light * 0.3 * (0.6 + 0.4 * sin(TIME * 0.9 + b.x * 1.3 - b.y)));
	// thinner only right at the rim, where it frays
	COLOR = vec4(col, body * mix(0.75, 0.97, smoothstep(0.5, 0.62, v)));
}
