shader_type canvas_item;
// A shard of a kintsugi card's info panel (CardKintsugi): its face is the panel as it was (`front`, a snapshot of it),
// or — turned over — the card's back (`back`), mirrored as a card's back is. UV: the point's place in the panel
// (0..1); the panel's rounded shape cuts it. Vertex colour: r — 1 face up, 0 face down; b — its light (as it turns
// in the air); a — its fade.

uniform sampler2D front : filter_linear;
uniform sampler2D back : filter_linear_mipmap;
uniform vec2 psize = vec2(300.0, 200.0);   // the panel, points
uniform vec4 pin = vec4(0.0, 0.5, 1.0, 0.5); // the panel in the card: x, y, w, h (fractions of the card)
uniform float rt = 22.0;                   // the panel's top corners
uniform float rb = 15.0;                   // its bottom ones
uniform vec2 back_shift = vec2(0.0);       // the turned shards show the back's emblem: their group's middle on it

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
	vec4 c;
	if (vc.r > 0.5) {
		c = texture(front, UV);
	} else {
		vec2 q = pin.xy + UV * pin.zw;
		c = texture(back, vec2(1.0 - q.x, q.y) + back_shift);
	}
	c.rgb *= vc.b;
	COLOR = vec4(c.rgb, c.a * m * vc.a);
}
