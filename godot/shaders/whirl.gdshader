shader_type canvas_item;
// The Kraken's maelstrom (board 2): a square hole broken through the board, its water flowing in a whirlpool - not the
// picture turned whole. The water turns CLOCKWISE on screen, as the ring of stones round it goes, faster the nearer the
// middle (the foam draws out into spirals), and keeps flowing in towards the hole: two layers of the same water, each
// carried in and twisted over its own cycle, half a cycle apart, cross-faded so neither cycle's restart shows.
// The ragged edge of planks and rock stays still. And the light of the deep: a cold glow from the hole, slowly
// breathing, the foam near it lit, sparks of plankton drawn down the spiral.
// `flow` is the water's clock from the game (it runs faster for a moment when the ring goes round).

uniform float flow = 0.0;
// how far out the water reaches (in UV, as a half side of the square: beyond it the edge stands still)
uniform float inner = 0.4;
// the deep's light: the Kraken's eye colour
uniform vec3 glow : source_color = vec3(0.5, 0.88, 1.0);

vec2 sample_at(float r, float a) {
	return vec2(0.5) + vec2(cos(a), sin(a)) * r;
}

float hash(float n) {
	return fract(sin(n * 127.1) * 43758.5453);
}

void fragment() {
	vec2 d = UV - 0.5;
	float r = length(d);
	float a = atan(d.y, d.x);
	// the water, by its square-ish extent: 1 inside, 0 on the edge
	float sq = max(abs(d.x), abs(d.y));
	float water = 1.0 - smoothstep(inner - 0.07, inner, sq);
	// the whole pool turns slowly, the middle much faster. On screen (y down) a growing angle is clockwise: sampling
	// from a smaller angle carries the water that way
	float base = flow * 0.35;
	vec4 col = vec4(0.0);
	for (int i = 0; i < 2; i++) {
		float p = fract(flow * 0.11 + float(i) * 0.5);
		float w = smoothstep(0.0, 1.0, 1.0 - abs(2.0 * p - 1.0));
		// drawn from further out as the cycle goes on: the water seems to slide in; the hole and the rim do not move.
		// Small steps: the two layers stay alike, so their blend keeps the foam crisp
		float rr = r + r * max(inner - r, 0.0) / inner * p * 0.35;
		float twist = p * 1.2 / (r * 6.0 + 0.45);
		col += texture(TEXTURE, sample_at(rr, a - base - twist)) * w;
	}
	vec4 still = texture(TEXTURE, UV);
	vec4 moving = col;
	// the hole in the middle stays as drawn, black, and the water darkens into it
	moving = mix(texture(TEXTURE, sample_at(r, a - base)), moving, smoothstep(0.03, 0.08, r));
	moving.rgb *= mix(0.6, 1.0, smoothstep(0.04, 0.14, r));

	// the light of the deep, breathing: from the hole up through the water, the foam near it catching it
	float breath = 0.75 + 0.25 * sin(flow * 1.3) + 0.08 * sin(flow * 3.7);
	float core = exp(-r * r / 0.006) * breath;
	float haze = exp(-r * r / 0.035) * breath;
	float foam = smoothstep(0.45, 0.8, dot(moving.rgb, vec3(0.33)));
	moving.rgb += glow * (core * 1.1 + haze * 0.35 + foam * haze * 0.9);
	// sparks of plankton drawn down the spiral, clockwise, faint at the rim, bright as they near the hole
	float spark = 0.0;
	for (int k = 0; k < 22; k++) {
		float fk = float(k);
		float life = fract(flow * (0.07 + 0.04 * hash(fk)) + hash(fk + 7.0));
		float pr = inner * 0.95 * (1.0 - life);
		float pa = hash(fk + 3.0) * 6.2832 + life * (3.5 + 2.0 * hash(fk + 5.0));
		vec2 pp = vec2(cos(pa), sin(pa)) * pr;
		float dist = length(d - pp);
		spark += smoothstep(0.012, 0.0, dist) * smoothstep(0.0, 0.25, life) * (0.4 + life);
	}
	moving.rgb += glow * spark * 1.2;
	COLOR = mix(still, vec4(moving.rgb, still.a), water * step(0.01, still.a));
}
