shader_type canvas_item;
// A fingerprint left on the fluorescent stone's card (CardFluor), seen only while the stone glows: ridges winding round
// a whorl a little off the pad's middle, flattening to arches toward its foot, uneven, broken here and there, the
// pad's edge ragged where the finger pressed less. Its light added. (COLOR written whole: never × the texture again.)
render_mode blend_add;

uniform vec3 col : source_color = vec3(0.4, 1.0, 0.5);
uniform float k = 1.0;            // how much (the stone's glow)
uniform float seed = 0.0;
uniform float ridges = 15.0;      // how many across the pad

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

void fragment() {
	// the pad: x -1..1 across, y -1 (tip) .. 1 (foot), taller than wide by the rect's own shape
	vec2 p = (UV - 0.5) * 2.0;
	vec2 s = vec2(seed * 7.3, seed * 3.1);
	// the skin is never even: the whole pattern pulled about a little
	vec2 w = p + (vec2(noise(p * 2.2 + s), noise(p * 2.2 + s + 9.0)) - 0.5) * 0.22;
	// the whorl's core, off the middle
	vec2 c = vec2(0.08 + 0.1 * sin(seed), -0.12 + 0.1 * cos(seed * 1.7));
	vec2 d = (w - c) * vec2(1.0, 0.78);
	float r = length(d);
	float a = atan(d.y, d.x);
	// round the core the ridges are one spiral; further out, loops; toward the foot they flatten into arches
	float f = r + a / 6.28318 / ridges * 2.0 * (1.0 - smoothstep(0.0, 0.5, r));
	float arch = smoothstep(0.25, 1.0, w.y) * 0.75;
	f = mix(f, (w.y - c.y) * 0.9 + 0.12 * cos(w.x * 2.4), arch);
	float v = sin(f * ridges * 3.14159 + (noise(p * 5.0 + s) - 0.5) * 1.6);
	// a ridge, its width breathing along it; pores and breaks
	float wide = 0.05 + 0.3 * noise(p * 7.0 + s + 4.0);
	float ridge = smoothstep(-wide, wide + 0.25, v);
	ridge *= smoothstep(0.16, 0.3, noise(p * 13.0 + s + 2.0));
	ridge *= 0.55 + 0.45 * smoothstep(0.2, 0.7, noise(p * 3.0 + s + 6.0));
	// the pad's outline: an oval, ragged, fading where the finger pressed less
	float edge = length(p * vec2(1.0, 0.92)) + (noise(p * 4.0 + s + 12.0) - 0.5) * 0.3;
	float pad = 1.0 - smoothstep(0.72, 0.98, edge);
	float press = 0.6 + 0.4 * smoothstep(-0.9, 0.4, p.x * 0.6 - p.y * 0.3 + noise(p * 1.5 + s) - 0.5);
	vec3 light = col * ridge * pad * press * k;
	COLOR = vec4(light, 1.0);
}
