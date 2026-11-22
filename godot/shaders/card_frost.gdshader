shader_type canvas_item;
// The frost bloom of a find out on its card (CardFrost): frost ferns creeping over the card's slate from its rim
// inward with each bloom on the stone, and thawing with it. Only the card's ground frosts: this is drawn in two pieces
// laid under what is on the card (over the stone's frame, under its name; over the info panel's slate, under its words
// and buttons) — one pattern across both, laid out in the card's own space (origin, rsize: this piece in it).
// ferns.r: the frost (GPT, art/frost_card), .g: how dense it is round a point (its masses grow in first), .b: a slow
// noise (the front wanders, the thaw eats it in patches).
render_mode blend_mix;
uniform sampler2D ferns : filter_linear_mipmap, repeat_enable;
uniform vec2 card = vec2(360.0, 700.0);
uniform vec2 origin = vec2(0.0);
uniform vec2 rsize = vec2(360.0, 700.0);
uniform float grow = 0.0;
uniform float thaw = 0.0;
uniform float tile = 300.0;

float h21(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec2 p = origin + UV * rsize;
	vec3 t = texture(ferns, p / tile).rgb;
	// the rim freezes first (by the depth from it, in points), the stone's oval in the card's upper part not at all;
	// the front wanders, the dense masses of ferns run ahead of it
	float e = min(min(min(p.x, p.y), min(card.x - p.x, card.y - p.y)) / 150.0, 1.0);
	vec2 so = (p - card * vec2(0.5, 0.34)) / (card * vec2(0.36, 0.22));
	float stone = max(0.0, 1.0 - dot(so, so));
	float front = grow * 1.2 - (e * 0.8 + t.b * 0.35 - t.g * 0.25 + stone * 0.9);
	float c = smoothstep(0.0, 0.18, front);
	// the thaw eats it in patches, the inner edge first
	float melt = t.b * 0.7 + (1.0 - e) * 0.6;
	float keep = 1.0 - smoothstep(melt - 0.15, melt + 0.05, thaw * 1.3);
	// the crystals: the bright lines first, the fine ones filling in as it thickens; a little rime between them
	float lines = smoothstep(0.66 - c * 0.2, 0.88 - c * 0.18, t.r) * smoothstep(-0.02, 0.06, front);
	float haze = c * 0.1 + smoothstep(0.15, 0.6, front) * 0.1;
	float fr = clamp(lines * 0.72 + haze, 0.0, 1.0) * keep;
	vec3 col = mix(vec3(0.6, 0.74, 0.9), vec3(0.96, 0.99, 1.0), lines);
	// single needles catching the light, one by one
	float h = h21(floor(p / 6.0));
	float gl = step(0.985, h) * pow(0.5 + 0.5 * sin(TIME * 2.0 + h * 90.0), 16.0) * lines * keep;
	COLOR = vec4(min(col + vec3(gl), vec3(1.0)), clamp(fr + gl, 0.0, 1.0));
}
