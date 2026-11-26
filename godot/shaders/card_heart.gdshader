shader_type canvas_item;
// The star heart's card (CardHeart): the stone is the card's heart. Vessels of light in the card's brass — its frame and
// the ribbon over the info panel — and over the panel's slate, always there, dimly lit; the heart's beat (the stone's
// own lub-dub: Spec.beat) gives them life — on every beat a wave of light runs out along them from the stone, and the
// light in them is driven on outward in spurts, as blood. One rect over the whole card, its light added; lengths in
// the card's points. (COLOR comes in already multiplied by the texture: written whole here, never multiplied again.)
render_mode blend_add;

uniform vec2 card = vec2(360.0, 640.0);
uniform float frame_in = 7.0;         // the card's brass frame: this far in from its edge
uniform float frame_r = 12.0;         // its corners' radius
uniform float rim_top = 400.0;        // the ribbon over the info panel
uniform float rim_bot = 406.0;
uniform float rim_l = 30.0;
uniform float rim_r = 330.0;
uniform vec2 src = vec2(180.0, 220.0);    // the heart, on the card
uniform float t = 0.0;                // a slow clock, s
uniform float speed = 520.0;          // the wave, points a second
uniform vec3 col : source_color = vec3(1.0, 0.25, 0.3);
uniform float k = 1.0;                // how much (it comes in)
// which piece: 0 over the card — its brass; 1 inside the info panel, over its slate and under its words: wider, fainter
// vessels branching down from the ribbon
uniform int part = 0;
// the beat as it has been: hist[0] `hoff` s ago, each next one 0.025 s earlier (the heart's pace changes — calm, racing
// — so the wave reads the beat's own past, not a formula)
uniform float hist[48];
uniform float hoff = 0.0;
uniform float flow = 0.0;             // how far the beats have driven the light on (it grows with every beat)

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) { return noise(p) * 0.6 + noise(p * 2.1 + 7.0) * 0.3 + noise(p * 4.3 + 3.0) * 0.1; }

// the beat `delay` s ago
float beat_ago(float delay) {
	float x = max(0.0, delay - hoff) / 0.025;
	int i = int(floor(x));
	if (i >= 47) return 0.0;
	return mix(hist[i], hist[i + 1], fract(x));
}

void fragment() {
	vec2 p = UV * card;
	vec2 cq = abs(p - card * 0.5) - card * 0.5 + frame_r;
	float e = -(length(max(cq, 0.0)) + min(max(cq.x, cq.y), 0.0) - frame_r);
	float brass = smoothstep(1.0, 2.0, e) * smoothstep(frame_in + 0.3, frame_in - 0.9, e);
	float ribbon = (1.0 - smoothstep(0.0, (rim_bot - rim_top) * 0.5 + 1.0, abs(p.y - (rim_top + rim_bot) * 0.5)))
		* step(rim_l - 24.0, p.x) * step(p.x, rim_r + 24.0);
	float metal = max(brass, ribbon);
	vec3 light = vec3(0.0);
	// the wave: the beat as it was at the heart when it set out for here
	float d = length(p - src);
	float b = beat_ago(d / speed);
	// the light in the vessels: denser and thinner along them, driven outward from the heart by each beat
	float ang = atan(p.y - src.y, p.x - src.x);
	float blood = noise(vec2(d * 0.03 - flow, ang * 2.2));
	blood = smoothstep(0.25, 0.8, blood);
	if (part == 1) {
		// the slate: a few main vessels running down from the ribbon, bending, a fine net between them; fainter than
		// the brass's, and fading toward the panel's foot — the words over them stay easy to read
		float inside = step(rim_bot, p.y) * smoothstep(0.0, 3.0, e - frame_in);
		if (inside > 0.0) {
			float down = p.y - rim_bot;
			vec2 q = vec2(p.x * 0.028 + fbm(vec2(p.y * 0.012, 3.0)) * 1.6, p.y * 0.006);
			float n1 = fbm(q + 11.0);
			float n2 = fbm(p * 0.05 + 2.0);
			float v1 = pow(1.0 - abs(2.0 * n1 - 1.0), 36.0);
			float v2 = pow(1.0 - abs(2.0 * n2 - 1.0), 30.0) * 0.4;
			float veins = max(v1, v2);
			float fade = 0.35 + 0.65 * exp(-down / 150.0);
			light = col * inside * fade * veins * (0.2 + 0.3 * blood + 0.85 * b);
			light += vec3(1.0) * inside * fade * veins * b * b * 0.12;
			// the slate itself takes a breath of the light under the ribbon
			light += col * inside * exp(-down / 26.0) * 0.1 * b;
		}
	} else if (metal > 0.0) {
		// the vessels: thin lines wandering along the metal, a finer net between them; they hardly move
		vec2 q = p * 0.075;
		float n1 = fbm(q + vec2(t * 0.004, 0.0));
		float n2 = fbm(q * 2.4 + 5.0);
		float v1 = pow(1.0 - abs(2.0 * n1 - 1.0), 14.0);
		float v2 = pow(1.0 - abs(2.0 * n2 - 1.0), 22.0) * 0.55;
		float veins = max(v1, v2);
		float far = 0.55 + 0.45 * exp(-d / 320.0);
		// always lit, dimly; the beat's wave lights them up, and the metal round them warms a little
		light = col * metal * far * (veins * (0.32 + 0.45 * blood + 1.25 * b) + 0.06 * b * b);
		light += vec3(1.0) * metal * far * veins * b * b * 0.22;
	}
	COLOR = vec4(light * k, 1.0);
}
