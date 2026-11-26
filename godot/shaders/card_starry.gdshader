shader_type canvas_item;
// The starry sky's card (CardStarry): the info panel's slate is a night sky — deep blue-black, a band of the Milky Way
// across it, stars of three sizes twinkling, each in its own time; under the panel's words. One rect over the whole
// card, lengths in the card's points. (COLOR comes in already multiplied by the texture: written whole here.)

uniform vec2 card = vec2(360.0, 640.0);
uniform float frame_in = 7.0;
uniform float frame_r = 12.0;
uniform float rim_bot = 406.0;
uniform float t = 0.0;
uniform float seed = 0.0;
uniform float k = 1.0;

float h2(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
float vn(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1, 0)), u.x), mix(h2(i + vec2(0, 1)), h2(i + vec2(1, 1)), u.x), u.y);
}

// stars on a grid of `cell` points: a soft point in some cells, each twinkling in its own time
float stars(vec2 p, float cell, float many, float size) {
	vec2 q = p / cell + seed;
	vec2 c = floor(q);
	float r = h2(c + 3.0);
	vec2 at = vec2(h2(c + 7.0), h2(c + 11.0)) * 0.7 + 0.15;
	float d = length(fract(q) - at) * cell;
	float tw = 0.55 + 0.45 * sin(t * (0.7 + 2.4 * h2(c + 17.0)) + r * 40.0);
	return step(1.0 - many, r) * (1.0 - smoothstep(0.0, size, d)) * tw;
}

void fragment() {
	vec2 p = UV * card;
	vec2 cq = abs(p - card * 0.5) - card * 0.5 + frame_r;
	float e = -(length(max(cq, 0.0)) + min(max(cq.x, cq.y), 0.0) - frame_r);
	float inside = step(rim_bot, p.y) * smoothstep(0.0, 2.5, e - frame_in);
	// the night: deep blue, darker to the foot; the Milky Way a slanting band of faint cloud and star dust
	float down = clamp((p.y - rim_bot) / max(1.0, card.y - rim_bot), 0.0, 1.0);
	vec3 sky = mix(vec3(0.02, 0.035, 0.09), vec3(0.006, 0.01, 0.03), down);
	float across = dot(p - vec2(card.x * 0.5, rim_bot + (card.y - rim_bot) * 0.45), normalize(vec2(0.35, 1.0)));
	float way = exp(-pow(across / 38.0, 2.0)) * (0.45 + 0.75 * vn(p / 26.0 + seed));
	sky += vec3(0.1, 0.11, 0.17) * way * 0.55;
	float s = stars(p, 7.0, 0.16 + 0.3 * way, 0.9) * 0.55 + stars(p + 31.0, 15.0, 0.3, 1.5) * 0.85 + stars(p + 77.0, 41.0, 0.45, 2.3);
	vec3 col = sky + vec3(0.92, 0.95, 1.0) * s;
	COLOR = vec4(col, clamp(0.86 + s, 0.0, 1.0) * inside * k);
}
