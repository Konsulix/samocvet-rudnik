shader_type canvas_item;
// FrostFronds' frost on a card: its texture holds the frost drawn by code (R its brightness, G the moment each bit of
// it appears, 0..1); here it is let in as it grows (g) — out along the fronds, tips last — with a soft glow round it
// from the texture's blurred levels, and single needles catching the light.
render_mode blend_mix;
uniform sampler2D tex : filter_linear_mipmap;
uniform float g = 0.0;

float h21(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec4 c = texture(tex, UV);
	float fr = c.r * (1.0 - smoothstep(g - 0.015, g, c.g));
	// the glow: the frost blurred (a coarser level), let in by its blurred moment
	vec4 b1 = textureLod(tex, UV, 3.0);
	vec4 b2 = textureLod(tex, UV, 4.5);
	float gl1 = b1.r * (1.0 - smoothstep(g - 0.05, g + 0.03, b1.g));
	float gl2 = b2.r * (1.0 - smoothstep(g - 0.08, g + 0.05, b2.g));
	float glow = gl1 * 0.55 + gl2 * 0.45;
	float h = h21(floor(UV * 400.0));
	float sp = step(0.992, h) * pow(0.5 + 0.5 * sin(TIME * 2.0 + h * 90.0), 16.0) * fr;
	vec3 col = mix(vec3(0.55, 0.7, 0.92), vec3(0.96, 0.99, 1.0), clamp(fr * 1.2, 0.0, 1.0));
	float a = clamp(fr * 0.95 + glow * 0.5 + sp, 0.0, 1.0);
	COLOR = vec4(min(col + vec3(sp), vec3(1.0)), a);
}
