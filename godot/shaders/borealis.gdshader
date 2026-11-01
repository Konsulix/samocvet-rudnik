shader_type spatial;
// The legendary "northern lights" (SpecPolar.borealis): a curtain of aurora hanging in a loose fold round the find,
// above it. Its folds drift sideways, the rays shimmer and run along the hem, pieces of curtain flare up and die
// away; green low down, violet at the top, a thin pink hem now and then. Additive: it is light, the stone and the
// dark show through it. The half of the curtain in front of the stone is dimmer, so the stone stays seen.
// UV.x — round the curtain (0..1), UV.y — up it (0 the hem, 1 the top).
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec3 center = vec3(0.0);
uniform float radius = 1.0;
uniform float seed = 0.0;
uniform float energy = 0.85;

varying float v_front;

float h1(float x) { return fract(sin(x * 127.1 + seed * 31.7) * 43758.5453); }
float n1(float x) {
	float i = floor(x), f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(h1(i), h1(i + 1.0), f);
}
float n2(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = h1(i.x + i.y * 57.0), b = h1(i.x + 1.0 + i.y * 57.0);
	float c = h1(i.x + (i.y + 1.0) * 57.0), d = h1(i.x + 1.0 + (i.y + 1.0) * 57.0);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	float a = UV.x * TAU;
	float y = UV.y;
	// the folds: slow big waves and quicker small ones drifting round, more at the top
	float fold = sin(a * 3.0 + TIME * 0.23 + seed) * 0.1 + sin(a * 7.0 - TIME * 0.41 + seed * 2.0) * 0.045
		+ (n1(UV.x * 18.0 + TIME * 0.3) - 0.5) * 0.06;
	vec2 d = normalize(VERTEX.xz - center.xz);
	VERTEX.xz += d * fold * radius * (0.6 + 0.6 * y);
	// the hem rises and falls like a slow breath along the curtain
	VERTEX.y += (n1(UV.x * 9.0 - TIME * 0.18) - 0.5) * radius * 0.3 * (1.0 - y * 0.4) + sin(a * 5.0 + TIME * 0.3) * radius * 0.06;
	vec4 vp = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec4 cp = MODELVIEW_MATRIX * vec4(center, 1.0);
	v_front = smoothstep(0.0, radius * 0.6, vp.z - cp.z);
}

void fragment() {
	float x = UV.x;
	float y = UV.y;
	// rays: soft vertical streaks, broad and fine together, flickering, blurring out higher up the curtain,
	// and a ripple of light running along the hem
	float fine = n2(vec2(x * 120.0, TIME * 0.9 + y * 1.5));
	float broad = n2(vec2(x * 34.0 + 7.0, y * 2.0 - TIME * 0.4));
	float rays = 0.45 + 0.55 * mix(fine * 0.5 + broad * 0.5, broad, y) * (0.5 + 0.5 * broad);
	float run = 0.8 + 0.4 * pow(0.5 + 0.5 * sin(x * 38.0 - TIME * 1.7), 4.0);
	// the curtain in pieces that flare and fade, melting into each other
	float piece = smoothstep(0.2, 0.85, n2(vec2(x * 5.0 - TIME * 0.05, TIME * 0.08)));
	piece *= 0.45 + 0.55 * smoothstep(0.1, 0.7, n2(vec2(x * 2.3 + 3.0, TIME * 0.05)));
	// the open ends of the ring fade out, nothing is cut off
	piece *= smoothstep(0.0, 0.14, x) * smoothstep(1.0, 0.86, x);
	// the top dissolves into long ragged tongues of light, not a straight line
	float tongue = n2(vec2(x * 22.0, TIME * 0.2)) * 0.5 + n2(vec2(x * 7.0 + 9.0, TIME * 0.11)) * 0.5;
	piece *= (1.0 - smoothstep(tongue * 0.5 + 0.15, tongue * 0.5 + 0.8, y)) * smoothstep(1.0, 0.72, y);
	// up the curtain: a hem that glows out of nothing (its line wanders), a long fade, violet rising at the top
	float hy = y - (n2(vec2(x * 15.0, TIME * 0.15)) - 0.5) * 0.12;
	float hem = smoothstep(-0.04, 0.3, hy) * smoothstep(-0.04, 0.3, hy);
	float green = hem * exp(-y * 2.6);
	float violet = smoothstep(0.25, 0.7, y) * (1.0 - smoothstep(0.75, 1.0, y)) * 0.55;
	float pink = smoothstep(0.0, 0.08, y) * (1.0 - smoothstep(0.1, 0.22, y)) * smoothstep(0.55, 0.85, n1(x * 7.0 + TIME * 0.1)) * 0.8;
	vec3 c = vec3(0.15, 1.0, 0.42) * green * run + vec3(0.55, 0.22, 1.0) * violet + vec3(1.0, 0.25, 0.5) * pink;
	c *= rays * piece * energy;
	// where the curtain turns away edge-on (the sides of the ring) it melts into the dark, no straight edge
	float edge = abs(dot(normalize(NORMAL), VIEW));
	c *= smoothstep(0.08, 0.6, edge);
	c *= mix(1.0, 0.35, v_front);
	ALBEDO = c;
}
