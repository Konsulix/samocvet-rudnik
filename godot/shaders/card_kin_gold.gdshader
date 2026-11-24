shader_type canvas_item;
// The gold of a kintsugi card's seams (CardKintsugi) — the same gold as in the stone's own seams (spec.gdshaderinc
// kin_k): native gold under worked-gold textures, a metal that shows its surroundings. Here the surroundings are the
// stone's studio — a dark room, a big warm softbox up left, a cold strip light right, a dim light from above — and the
// surface is a rounded bead across the seam (UV.y −1..1; its direction across on screen is UV.x, as a turn 0..1), or,
// where seams meet (vertex g = 1), a drop (UV its own disc −1..1); the gold's hammered relief (gold_nrm) tilts it.
// Vertex r: molten (1 white-hot .. 0 cool); b = 1: the molten glow round a seam (soft, wide); a: its fade.
// `cut` (x, y, w, h in the node's space, w > 0): nothing drawn inside it (another layer draws the seams there).

uniform sampler2D gold_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D gold_nrm : filter_linear_mipmap, repeat_enable;
uniform sampler2D gold_rough : filter_linear_mipmap, repeat_enable;
uniform vec4 cut = vec4(0.0);

varying vec2 lp;

void vertex() {
	lp = VERTEX;
}

float h1(float x) {
	return fract(sin(x * 127.1 + 3.7) * 43758.5453);
}

// a light seen in the mirror of the gold: a soft lobe round its direction, sharper on smoother gold
float lobe(vec3 r, vec3 l, float k) {
	return pow(max(dot(r, normalize(l)), 0.0), k);
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
		c = vec3(1.0, 0.55, 0.15);
		alpha = g * vc.r * 0.65;
	} else {
		// the gold of the stone's own seams (spec.gdshaderinc kin_k), 24.11 ("piping with knobs, as the mines' ore"):
		// native gold under the worked-gold texture, a metal lit by the studio's key from up left; a low crest across
		// the seam (its normal tips across it towards its edges), the hammered relief on it; crisp edges, no dark rim
		vec3 n;
		if (drop) {
			n = vec3(q * 0.5, 1.0);
		} else {
			float ang = q.x * 6.2832;
			vec2 across = vec2(cos(ang), sin(ang));
			float t = clamp(q.y, -1.0, 1.0);
			n = vec3(across * t * 0.8, 1.0);
		}
		vec2 tq = lp * 0.05;
		vec3 tn = texture(gold_nrm, tq).xyz * 2.0 - 1.0;
		float gr = texture(gold_rough, tq).r;
		vec3 gd = texture(gold_tex, tq).rgb;
		n = normalize(normalize(n) + vec3(tn.x, -tn.y, 0.0) * 0.5);
		vec3 L = normalize(vec3(-0.55, -0.7, 0.55));
		vec3 r = reflect(vec3(0.0, 0.0, -1.0), n);
		float dif = max(dot(n, L), 0.0);
		float rough = clamp(gr * 0.9, 0.08, 0.6);
		float spec = pow(max(dot(r, L), 0.0), mix(60.0, 6.0, rough)) * (1.2 - rough);
		float fill = pow(max(dot(r, normalize(vec3(0.8, -0.2, 0.55))), 0.0), 8.0) * 0.35;
		// native gold (the stone's 0.87, 0.53, 0.08 in linear light), worn by the worked texture
		vec3 gold = vec3(0.94, 0.75, 0.30) * (gd.r * 1.15);
		c = gold * (0.42 + 0.72 * dif) + gold * (spec * 1.3 + fill) + vec3(1.0, 0.95, 0.8) * spec * 0.35;
		// a glint sliding along the seams now and then (the stone's gleam)
		float gx = fract((lp.x * 0.6 + lp.y * 0.4) / 320.0 - TIME * 0.16) * 320.0;
		c += vec3(1.0, 0.85, 0.5) * exp(-pow(gx - 24.0, 2.0) / 160.0) * 0.5 * (1.0 - gr);
		// molten: white-hot, cooling
		c = mix(c, vec3(1.0, 0.86, 0.55) * 1.3, vc.r);
		float aa = max(fwidth(a), 0.02);
		alpha = 1.0 - smoothstep(1.0 - aa * 1.5, 1.0, a);
	}
	COLOR = vec4(c, alpha * vc.a * (1.0 - inside));
}
