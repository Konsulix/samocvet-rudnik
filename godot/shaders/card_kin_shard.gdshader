shader_type canvas_item;
// A shard of a kintsugi card's broken block — its info panel, the panel's brass and the card's frame round it
// (CardKintsugi): its face is the block as it was (`front`, a snapshot of it), or — turned over — the card's back
// (`back`), mirrored as a card's back is. UV: the point's place in the block (0..1); the block's shape (straight
// across on top, the card's rounded corners below) cuts it. Vertex colour: r — 1 face up, 0 face down; b — its light
// (as it turns in the air); a — its fade. `cut` (x, y, w, h in the node's space, w > 0): nothing drawn inside it.

uniform sampler2D front : filter_linear;
uniform sampler2D back : filter_linear_mipmap;
uniform vec2 psize = vec2(300.0, 200.0);   // the block, points
uniform vec4 pin = vec4(0.0, 0.5, 1.0, 0.5); // the block in the card: x, y, w, h (fractions of the card)
uniform float rb = 14.0;                   // the card's bottom corners
uniform float rt = 29.0;                   // its top corners: round as the panel's brass ribbon
uniform vec2 card_sz = vec2(360.0, 640.0);  // the card, points
uniform float inset = 7.0;                  // the back's picture inside its brass frame (CardKintsugi: as on the back)
uniform vec4 cut = vec4(0.0);

float sd_round(vec2 p, vec2 h, float r) {
	vec2 q = abs(p) - h + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec4 vc = COLOR;
	vec2 p = UV * psize;
	float r = p.y < psize.y * 0.5 ? rt : rb;
	float d = sd_round(p - psize * 0.5, psize * 0.5, r);
	float m = 1.0 - smoothstep(-0.6, 0.6, d);
	// (by its home place in the block, not where the shard is drawn: VERTEX is the shard's own, before its turn)
	if (cut.z > 0.0 && p.x > cut.x && p.y > cut.y && p.x < cut.x + cut.z && p.y < cut.y + cut.w) m = 0.0;
	vec4 c;
	if (vc.r > 0.5) {
		c = texture(front, UV);
	} else {
		vec2 q = pin.xy + UV * pin.zw;
		// the back's picture where this bit of the card is on the back (mirrored, as a card's back is), as the back
		// lays it out inside its brass frame (24.11: a turned shard is a piece of the very back the card turns to)
		vec2 bp = vec2(1.0 - q.x, q.y) * card_sz;
		c = texture(back, clamp((bp - inset) / (card_sz - inset * 2.0), vec2(0.004), vec2(0.996)));
	}
	c.rgb *= vc.b;
	COLOR = vec4(c.rgb, c.a * m * vc.a);
}
