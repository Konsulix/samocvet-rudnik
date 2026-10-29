shader_type canvas_item;
// The Kraken's maelstrom (board 2): a square hole broken through the board, its water flowing in a whirlpool - not the
// picture turned whole. The water turns faster the nearer the middle (the foam draws out into spirals) and keeps
// flowing in towards the hole: two layers of the same water, each carried in and twisted over its own cycle, half a
// cycle apart, cross-faded so neither cycle's restart shows. The ragged edge of planks and rock stays still.
// `flow` is the water's clock from the game (it runs faster for a moment when the ring goes round).

uniform float flow = 0.0;
// how far out the water reaches (in UV, as a half side of the square: beyond it the edge stands still)
uniform float inner = 0.4;

vec2 sample_at(float r, float a) {
	return vec2(0.5) + vec2(cos(a), sin(a)) * r;
}

void fragment() {
	vec2 d = UV - 0.5;
	float r = length(d);
	float a = atan(d.y, d.x);
	// the water, by its square-ish extent: 1 inside, 0 on the edge
	float sq = max(abs(d.x), abs(d.y));
	float water = 1.0 - smoothstep(inner - 0.07, inner, sq);
	// the whole pool turns slowly, the middle much faster
	float base = flow * 0.35;
	vec4 col = vec4(0.0);
	for (int i = 0; i < 2; i++) {
		float p = fract(flow * 0.11 + float(i) * 0.5);
		float w = smoothstep(0.0, 1.0, 1.0 - abs(2.0 * p - 1.0));
		// drawn from further out as the cycle goes on: the water seems to slide in; the hole and the rim do not move.
		// Small steps: the two layers stay alike, so their blend keeps the foam crisp
		float rr = r + r * max(inner - r, 0.0) / inner * p * 0.35;
		float twist = p * 1.2 / (r * 6.0 + 0.45);
		col += texture(TEXTURE, sample_at(rr, a + base + twist)) * w;
	}
	vec4 still = texture(TEXTURE, UV);
	vec4 moving = col;
	// the hole in the middle stays as drawn, black, and the water darkens into it
	moving = mix(texture(TEXTURE, sample_at(r, a + base)), moving, smoothstep(0.03, 0.08, r));
	moving.rgb *= mix(0.6, 1.0, smoothstep(0.04, 0.14, r));
	COLOR = mix(still, vec4(moving.rgb, still.a), water * step(0.01, still.a));
}
