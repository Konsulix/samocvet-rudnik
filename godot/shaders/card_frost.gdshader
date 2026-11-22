shader_type canvas_item;
// The frost bloom of a find out on its card (CardFrost): frost ferns creeping over the card's glass from its rim inward,
// a wave with each bloom on the stone; a finger wipes it off, leaving a wet film with droplets that freezes over again.
// ferns.r: the frost (GPT, art/frost_card), .g: how dense it is round a point (its masses grow in first), .b: a slow noise
// (the front wanders); wipe.r: how wiped a point is (CardFrost paints it, and lets it fade as it refreezes).
render_mode blend_mix;
uniform sampler2D ferns : filter_linear_mipmap, repeat_enable;
uniform sampler2D wipe : filter_linear;
uniform vec2 card = vec2(360.0, 700.0);
uniform float grow = 0.0;
uniform float tile = 300.0;

float h21(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec2 p = UV * card;
	vec3 t = texture(ferns, p / tile).rgb;
	// the rim freezes first, the middle last; the front wanders, the dense masses of ferns run ahead of it
	// (by the depth from the rim in points; the stone, in its oval in the card's upper part, is kept clear)
	float e = min(min(min(p.x, p.y), min(card.x - p.x, card.y - p.y)) / 150.0, 1.0);
	vec2 so = (p - card * vec2(0.5, 0.34)) / (card * vec2(0.36, 0.22));
	float stone = max(0.0, 1.0 - dot(so, so));
	float front = grow * 1.2 - (e * 0.8 + t.b * 0.35 - t.g * 0.25 + stone * 0.9);
	float c = smoothstep(0.0, 0.18, front);
	float w = texture(wipe, UV).r;
	float keep = 1.0 - smoothstep(0.12, 0.65, w);
	// the crystals: the bright lines first, the fine ones filling in as it thickens; a matte rime between them
	float lines = smoothstep(0.66 - c * 0.2, 0.88 - c * 0.18, t.r) * smoothstep(-0.02, 0.06, front);
	float haze = c * 0.12 + smoothstep(0.15, 0.6, front) * 0.12;
	float fr = clamp(lines * 0.68 + haze, 0.0, 1.0) * keep;
	vec3 col = mix(vec3(0.6, 0.74, 0.9), vec3(0.96, 0.99, 1.0), lines);
	// single needles catching the light, one by one
	float h = h21(floor(p / 6.0));
	float gl = step(0.985, h) * pow(0.5 + 0.5 * sin(TIME * 2.0 + h * 90.0), 16.0) * lines * keep;
	// wiped: a cold wet film, droplets with a bright rim, until the frost grows back over it
	float wet = smoothstep(0.05, 0.4, w);
	vec2 dc = floor(p / 9.0);
	float dh = h21(dc + 3.1);
	vec2 dl = fract(p / 9.0) - 0.5 - (vec2(fract(dh * 7.0), fract(dh * 13.0)) - 0.5) * 0.45;
	float drop = step(0.55, dh) * (1.0 - smoothstep(0.1 + dh * 0.12, 0.17 + dh * 0.12, length(dl))) * wet;
	float rim = drop * smoothstep(0.0, 0.12, -dl.x - dl.y);
	float wa = wet * 0.1 + drop * 0.22 + rim * 0.55;
	vec3 wc = mix(vec3(0.55, 0.72, 0.95), vec3(1.0), rim);
	float fa = clamp(fr + gl, 0.0, 1.0);
	float a = fa + wa * (1.0 - fa);
	vec3 o = (col * fa + vec3(gl) + wc * wa * (1.0 - fa)) / max(a, 0.001);
	COLOR = vec4(min(o, vec3(1.0)), a);
}
