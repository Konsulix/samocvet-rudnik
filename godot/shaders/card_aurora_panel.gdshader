shader_type canvas_item;
// The info panel of a card whose stone has the northern lights (CardAurora): instead of its slate, the night — near
// black, a scatter of small stars twinkling, and the aurora's light on it from above: a soft green-violet glow down from
// its top edge, wavering as the curtains in the sky behind the stone move. Over the slate, under the words.

uniform vec2 rsize = vec2(340.0, 200.0);   // the panel, in points
uniform float k = 1.0;

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
float star(vec2 p, float cell, float r, float t) {
	vec2 c = floor(p / cell);
	vec2 f = p / cell - c;
	float h = hash(c + 4.2);
	if (h < 0.6) return 0.0;
	vec2 at = vec2(hash(c + 1.7), hash(c + 8.3)) * 0.8 + 0.1;
	float d = length(f - at) * cell;
	return exp(-d * d / (r * r)) * (0.55 + 0.45 * sin(t * (1.2 + h * 2.5) + h * 30.0)) * (0.4 + h);
}

void fragment() {
	vec2 p = UV * rsize;
	float t = TIME;
	vec3 c = mix(vec3(0.012, 0.016, 0.035), vec3(0.004, 0.005, 0.012), UV.y);
	c += vec3(0.75, 0.85, 1.0) * (star(p, 9.0, 0.45, t) * 0.5 + star(p + 50.0, 23.0, 0.8, t) * 0.8);
	// the aurora's light from above, in moving tongues
	float tongue = 0.5 + 0.5 * noise(vec2(p.x * 0.025 + t * 0.12, t * 0.07));
	float down = exp(-p.y / (38.0 + 22.0 * tongue));
	vec3 glow = mix(vec3(0.1, 0.9, 0.45), vec3(0.5, 0.25, 1.0), noise(vec2(p.x * 0.012 - t * 0.05, 3.0)));
	c += glow * down * 0.16 * (0.6 + 0.4 * tongue);
	COLOR = vec4(c, k);
}
