shader_type canvas_item;
// The star heart's card (CardHeart): the stone is the card's heart. Thin vessels of light in the card's brass — its frame
// and the ribbon over the info panel — and on every beat (the stone's own lub-dub: Spec.beat) a wave of light runs out
// along them from the stone and dies away. One rect over the whole card, its light added; lengths in the card's points.
// (COLOR comes in already multiplied by the texture: written whole here, never multiplied again — 26.11's lesson.)
render_mode blend_add;

uniform vec2 card = vec2(360.0, 640.0);
uniform float frame_in = 7.0;         // the card's brass frame: this far in from its edge
uniform float frame_r = 12.0;         // its corners' radius
uniform float rim_top = 400.0;        // the ribbon over the info panel
uniform float rim_bot = 406.0;
uniform float rim_l = 30.0;
uniform float rim_r = 330.0;
uniform vec2 src = vec2(180.0, 220.0);    // the heart, on the card
uniform float t = 0.0;                // the beat's clock, s (Spec's)
uniform float speed = 900.0;          // the wave, points a second
uniform vec3 col : source_color = vec3(1.0, 0.25, 0.3);
uniform float k = 1.0;                // how much (it comes in)

const float PERIOD = 0.86;

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

// lub-dub: a strong beat, a softer echo, then rest (as Spec._process beats it)
float beat(float tt) {
	float h = fract(tt / PERIOD);
	return exp(-pow((h - 0.12) * 11.0, 2.0)) + 0.55 * exp(-pow((h - 0.36) * 11.0, 2.0));
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
	if (metal > 0.0) {
		// the vessels: thin lines wandering along the metal, a finer net between them; they hardly move
		vec2 q = p * 0.075;
		float n1 = fbm(q + vec2(t * 0.004, 0.0));
		float n2 = fbm(q * 2.4 + 5.0);
		float v1 = pow(1.0 - abs(2.0 * n1 - 1.0), 14.0);
		float v2 = pow(1.0 - abs(2.0 * n2 - 1.0), 22.0) * 0.55;
		float veins = max(v1, v2);
		// the wave: the beat as it was at the heart when it set out for here
		float d = length(p - src);
		float b = beat(t - d / speed);
		float far = 0.5 + 0.5 * exp(-d / 320.0);
		// between beats the vessels barely glow; on the wave they light, and the metal round them warms a little
		light = col * metal * far * (veins * (0.1 + 1.5 * b) + 0.07 * b * b);
		light += vec3(1.0) * metal * far * veins * b * b * 0.25;
	}
	COLOR = vec4(light * k, 1.0);
}
