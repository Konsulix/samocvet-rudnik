shader_type canvas_item;
// A new stage of a place in the drawn mine coming in over the old one, the way it was drawn - and only where the
// picture really changes (the old stage is given as `prev`; where they agree the new one is simply there): first its
// ink lines spread in patches with a warm glowing edge, then the colour floods in behind them. p runs 0..1.

uniform float p = 0.0;
uniform sampler2D prev : filter_linear;
uniform vec4 prev_rect = vec4(0.0, 0.0, 1.0, 1.0);   // where this picture sits in `prev` (uv offset, uv scale)
uniform float has_prev = 0.0;

float hash(vec2 v) { return fract(sin(dot(v, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 v) {
	vec2 i = floor(v), f = fract(v);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec4 c = COLOR;   // the colour comes from COLOR, not a TEXTURE sample (that one came out darker)
	vec4 now_s = texture(TEXTURE, UV);
	vec4 was = texture(prev, prev_rect.xy + UV * prev_rect.zw);
	// how much this spot changes (blurred a little by sampling around, so a changed area reveals as one patch)
	float d = 0.0;
	for (int i = 0; i < 5; i++) {
		vec2 o = vec2(float(i % 3) - 1.0, float(i / 3) - 0.5) * 0.012;
		d = max(d, length(texture(TEXTURE, UV + o).rgb - texture(prev, prev_rect.xy + (UV + o) * prev_rect.zw).rgb));
	}
	float changed = has_prev > 0.5 ? smoothstep(0.06, 0.2, d) : 1.0;
	float n = noise(UV * vec2(9.0, 6.0)) * 0.65 + noise(UV * vec2(31.0, 23.0)) * 0.35;
	float lum = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	float ink = 1.0 - smoothstep(0.10, 0.28, lum);           // the drawing's dark lines
	float pi = clamp(p * 1.7, 0.0, 1.0);
	float pc = clamp(p * 1.5 - 0.5, 0.0, 1.0);
	float front_i = pi * 1.15 - n;
	float show_ink = smoothstep(-0.12, 0.02, front_i);
	float show_col = smoothstep(n - 0.18, n + 0.05, pc * 1.25);
	vec3 rgb = mix(c.rgb * 0.55, c.rgb, show_col);
	// a warm glow running along the edge where the ink is spreading
	float edge = exp(-pow(front_i * 14.0, 2.0)) * (1.0 - show_col) * step(0.001, p) * step(p, 0.98);
	rgb += vec3(1.0, 0.7, 0.3) * edge * 0.8;
	float a = max(max(ink * show_ink, show_col), edge * 0.6);
	// unchanged spots: the new picture is the old one, show it as it is
	COLOR = vec4(mix(c.rgb, rgb, changed), c.a * mix(1.0, a, changed));
}
