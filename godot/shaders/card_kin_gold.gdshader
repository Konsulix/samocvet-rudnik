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
		// the bead's normal (screen: x right, y down, z to the viewer)
		vec3 n;
		if (drop) {
			n = vec3(q, sqrt(max(0.0, 1.0 - dot(q, q))));
		} else {
			float ang = q.x * 6.2832;
			vec2 across = vec2(cos(ang), sin(ang));
			float t = clamp(q.y, -1.0, 1.0);
			n = vec3(across * t, sqrt(max(0.0, 1.0 - t * t)));
		}
		vec2 tq = lp * 0.035;
		vec3 tn = texture(gold_nrm, tq).xyz * 2.0 - 1.0;
		float gr = texture(gold_rough, tq).r;
		vec3 gd = texture(gold_tex, tq).rgb;
		n = normalize(n + vec3(tn.x, -tn.y, 0.0) * 0.45);
		vec3 r = reflect(vec3(0.0, 0.0, -1.0), n);
		float sharp = mix(60.0, 8.0, clamp(gr * 1.2, 0.0, 1.0));
		// the studio in the gold
		// (its sky: light all round the front, as the studio's shared sky — the gold reads gold, not a dark mirror)
		float env = 0.42 + 0.35 * max(r.z, 0.0) - 0.25 * smoothstep(0.2, 0.9, r.y);
		env += 1.4 * lobe(r, vec3(-0.55, -0.75, 0.55), sharp * 0.35);  // the warm softbox up left
		env += 0.9 * lobe(r, vec3(0.9, -0.15, 0.4), sharp * 0.6);       // the cold strip light right
		env += 0.4 * lobe(r, vec3(0.0, -1.0, 0.2), 4.0);                // from above
		// a glint sliding along the seams now and then (as the stone's own: kin_k's gleam)
		float gx = fract((lp.x * 0.6 + lp.y * 0.4) / 320.0 - TIME * 0.16) * 320.0;
		env += 2.2 * exp(-pow(gx - 24.0, 2.0) / 140.0) * lobe(r, vec3(-0.2, -0.4, 0.9), 6.0);
		// sparks: a facet of the hammered gold catching a lamp, here and there
		float cell = floor((lp.x + lp.y * 1.7) / 9.0);
		float tw = h1(cell);
		env += 3.0 * pow(max(0.0, sin(TIME * 1.5 + tw * 40.0)), 50.0) * step(0.78, tw) * n.z;
		// metal: the reflection tinted by the gold itself (native gold, as the stone's, under the worked texture)
		vec3 gold = vec3(0.95, 0.66, 0.2) * (0.7 + 0.5 * gd.r);
		c = gold * env;
		c += vec3(1.0, 0.93, 0.75) * max(env - 1.3, 0.0) * 0.45;   // the brightest of a lamp goes whiter
		// where the gold meets the stone it dips under: a dark rim
		c *= mix(1.0, 0.35, smoothstep(0.8, 1.0, a));
		// molten: white-hot, cooling
		c = mix(c, vec3(1.0, 0.86, 0.55) * 1.3, vc.r);
		alpha = 1.0 - smoothstep(0.88, 1.0, a);
	}
	COLOR = vec4(c, alpha * vc.a * (1.0 - inside));
}
