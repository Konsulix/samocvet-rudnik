shader_type canvas_item;
// A new stage of a place in the drawn mine coming in over the old one, the way it was drawn: first its ink lines
// spread over the old picture in patches, then the colour floods in behind them. p runs 0..1.

uniform float p = 0.0;

float hash(vec2 v) { return fract(sin(dot(v, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 v) {
	vec2 i = floor(v), f = fract(v);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec4 c = COLOR;   // the colour comes from COLOR, not a TEXTURE sample (that one came out darker)
	float n = noise(UV * vec2(9.0, 6.0)) * 0.65 + noise(UV * vec2(31.0, 23.0)) * 0.35;
	float lum = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	float ink = 1.0 - smoothstep(0.10, 0.28, lum);           // the drawing's dark lines
	float pi = clamp(p * 1.8, 0.0, 1.0);
	float pc = clamp(p * 1.6 - 0.55, 0.0, 1.0);
	float show_ink = smoothstep(n - 0.12, n + 0.02, pi * 1.15);
	float show_col = smoothstep(n - 0.18, n + 0.05, pc * 1.25);
	vec3 rgb = mix(c.rgb * 0.55, c.rgb, show_col);
	COLOR = vec4(rgb, c.a * max(ink * show_ink, show_col));
}
