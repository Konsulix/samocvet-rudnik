// The wolf's moon (SpecBeastFx): a little moon, its seas and craters drawn here, lit from the side by a sun that goes
// round it (phase 0 new .. 0.5 full .. 1 new again); the dark part faintly earthlit, never black.
shader_type spatial;
render_mode unshaded, shadows_disabled;
#include "res://shaders/opal.gdshaderinc"

uniform float phase = 0.5;
uniform float seed = 0.0;

varying vec3 lp;

void vertex() {
	lp = normalize(VERTEX);
}

void fragment() {
	vec3 q = lp * 3.0 + seed;
	// seas: dark smooth patches; craters: rings with bright rays round the young ones
	float sea = smoothstep(0.48, 0.62, fbm(q * 0.9));
	vec3 base = mix(vec3(0.82, 0.83, 0.86), vec3(0.42, 0.44, 0.5), sea);
	vec2 cc = vec2(0.0);
	float crat = 0.0;
	for (int k = 0; k < 3; k++) {
		vec3 g = q * (2.5 + float(k) * 2.0);
		vec3 f = fract(g) - 0.5;
		float h = h3(floor(g) + float(k) * 7.0);
		float d = length(f);
		float rr = 0.18 + h * 0.2;
		crat += step(0.6, h) * (smoothstep(rr, rr * 0.8, d) * 0.25 - smoothstep(rr * 0.8, rr * 0.5, d) * 0.15);
	}
	base *= 1.0 + crat;
	base *= 0.85 + 0.3 * fbm(q * 6.0);
	// the sun goes round the moon in the view's plane: new (from behind) .. full (from the front)
	float a = phase * 6.2832;
	vec3 sun = normalize((VIEW_MATRIX * vec4(sin(a), 0.0, -cos(a), 0.0)).xyz);
	vec3 n = normalize(NORMAL);
	float lit = smoothstep(-0.08, 0.12, dot(n, sun));
	float limb = pow(max(dot(n, VIEW), 0.0), 0.35);
	ALBEDO = base * (lit * 1.25 + 0.06) * limb;
}
