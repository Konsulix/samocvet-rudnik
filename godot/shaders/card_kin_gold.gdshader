shader_type canvas_item;
// The gold of a kintsugi card's seams (CardKintsugi): each seam a raised bead of worked gold — dark in its edges,
// bright on its crest, a hot highlight along one flank, the hammered texture of the gold under it, a gleam running
// along all the seams now and then, sparks twinkling here and there. UV.y: across the bead (-1..1), or, for a drop
// where seams meet (vertex g = 1), UV is its own disc (-1..1). Vertex r: molten (1 white-hot .. 0 cool gold);
// b = 1: the molten glow round a seam (soft, wide); a: its fade. `cut` (x, y, w, h in the node's space, w > 0):
// nothing drawn inside it (the part of the card where another layer draws the seams).

uniform sampler2D gold_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 cut = vec4(0.0);

varying vec2 lp;

void vertex() {
	lp = VERTEX;
}

float h1(float x) {
	return fract(sin(x * 127.1 + 3.7) * 43758.5453);
}

void fragment() {
	vec4 vc = COLOR;
	vec2 q = UV;
	bool drop = vc.g > 0.5;
	float a = drop ? length(q) : abs(q.y);
	float inside = 0.0;
	if (cut.z > 0.0 && lp.x > cut.x && lp.y > cut.y && lp.x < cut.x + cut.z && lp.y < cut.y + cut.w) inside = 1.0;
	vec3 c;
	float alpha;
	if (vc.b > 0.5) {
		// the molten glow
		float g = pow(max(0.0, 1.0 - a), 2.0);
		c = vec3(1.0, 0.6, 0.2);
		alpha = g * vc.r * 0.6;
	} else {
		float h = sqrt(max(0.0, 1.0 - a * a));
		vec2 hp = drop ? q - vec2(-0.38, -0.38) : vec2(0.0, q.y + 0.4);
		float spec = exp(-dot(hp, hp) / 0.04);
		vec3 tex = texture(gold_tex, lp * 0.025).rgb;
		vec3 deep = vec3(0.22, 0.1, 0.01);
		vec3 mid = vec3(0.98, 0.66, 0.16);
		vec3 hi = vec3(1.0, 0.92, 0.6);
		c = mix(deep, mid, pow(h, 0.7)) * (0.65 + 0.7 * tex.r);
		c += hi * spec * 1.4;
		// a gleam running along every seam now and then
		float gx = fract((lp.x * 0.6 + lp.y * 0.4) / 300.0 - TIME * 0.18) * 300.0;
		c += vec3(1.0, 0.95, 0.8) * exp(-pow(gx - 24.0, 2.0) / 120.0) * h;
		// sparks twinkling
		float cell = floor((lp.x + lp.y * 1.7) / 11.0);
		float tw = h1(cell);
		c += vec3(1.0, 0.97, 0.85) * pow(max(0.0, sin(TIME * 1.7 + tw * 40.0)), 40.0) * step(0.75, tw) * h * 1.6;
		// its edge: a dark line where the gold meets the stone
		c *= mix(1.0, 0.3, smoothstep(0.72, 1.0, a));
		// molten: white-hot, cooling
		c = mix(c, vec3(1.0, 0.9, 0.62) * 1.25, vc.r);
		alpha = 1.0 - smoothstep(0.86, 1.0, a);
	}
	COLOR = vec4(c, alpha * vc.a * (1.0 - inside));
}
