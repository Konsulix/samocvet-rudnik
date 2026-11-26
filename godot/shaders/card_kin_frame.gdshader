shader_type canvas_item;
// A kintsugi card while its block is broken off (CardKintsugi): the card as it was (a snapshot, behind the live stone)
// everywhere but the block — through the block's place the screen behind the card shows. The block (in the picture's
// points): straight across its top, rounded as the panel's brass ribbon at its top corners, the card's own corners below.

uniform vec2 psize = vec2(300.0, 500.0);   // the card, points
uniform vec4 block = vec4(0.0, 300.0, 300.0, 200.0);
uniform float rt = 29.0;
uniform float rb = 14.0;
// the card's frame down its sides is kept a way below the block's top, where the panel's brass ribbon comes down over it,
// fading out (24.11: the sides broke off at the block's top, short of the ribbon's ends)
uniform float side_w = 8.0;
uniform float side_down = 68.0;
uniform float side_fade = 22.0;
// (26.11) the card's own rounded corners: the snapshot's square corners held the rarity glow behind them
uniform float card_r = 12.0;

float sd_round(vec2 p, vec2 h, float r) {
	vec2 q = abs(p) - h + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 p = UV * psize - block.xy;
	float r = p.y < block.w * 0.5 ? rt : rb;
	float d = sd_round(p - block.zw * 0.5, block.zw * 0.5, r);
	float keep = smoothstep(-0.6, 0.6, d);
	vec2 pp = UV * psize;
	if (pp.x < side_w || pp.x > psize.x - side_w) {
		keep = max(keep, 1.0 - smoothstep(side_down - side_fade, side_down, pp.y - block.y));
	}
	keep *= 1.0 - smoothstep(-0.6, 0.6, sd_round(pp - psize * 0.5, psize * 0.5, card_r));
	COLOR = vec4(c.rgb, c.a * keep);
}
