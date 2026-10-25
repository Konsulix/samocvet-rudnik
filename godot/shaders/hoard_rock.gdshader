shader_type spatial;
// The boss's hoard: a boulder of dark serpentine, mottled green and black, run through with thin veins of gold
// that glow a little and breathe. Noise in the boulder's own space, so the pattern turns with it.

uniform vec3 dark : source_color = vec3(0.07, 0.11, 0.09);
uniform vec3 green : source_color = vec3(0.2, 0.32, 0.24);
uniform vec3 gold : source_color = vec3(1.0, 0.72, 0.28);
uniform float vein_w = 0.016;

varying vec3 op;

void vertex() {
	op = VERTEX;
}

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float s = 0.0;
	float a = 0.5;
	for (int k = 0; k < 4; k++) {
		s += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return s;
}

void fragment() {
	float n = fbm(op * 2.6);
	vec3 base = mix(dark, green, smoothstep(0.35, 0.7, n));
	base *= 0.8 + 0.4 * fbm(op * 9.0 + 3.0);
	// veins: where a second noise crosses its middle, thin and branching
	float v = abs(fbm(op * 3.4 + 7.0) - 0.5);
	float vein = 1.0 - smoothstep(vein_w * 0.4, vein_w, v);
	float breath = 0.75 + 0.25 * sin(TIME * 1.4 + op.y * 3.0);
	ALBEDO = mix(base, gold, vein);
	METALLIC = vein * 0.9;
	ROUGHNESS = mix(0.85, 0.3, vein);
	EMISSION = gold * vein * 0.45 * breath;
}
