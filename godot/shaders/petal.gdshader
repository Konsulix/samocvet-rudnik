shader_type spatial;
render_mode cull_disabled;
// A petal (or a leaf) of a flower held in stone (SpecFlower). UV.x = 0 at its base .. 1 at its tip, UV.y = -1 .. 1
// across it. Its own colour, an "eye" of another colour at the base, a sheen (bronze, copper, pale) on its rims and in
// streaks, fine veins fanning out from the base, a midrib; spots or stripes on some. A leaf: green, its veins
// branching off the midrib.

#include "res://shaders/opal.gdshaderinc"

uniform vec3 c_base : source_color = vec3(0.08, 0.06, 0.05);
uniform vec3 c_rim : source_color = vec3(0.72, 0.45, 0.22);
uniform vec3 c_eye : source_color = vec3(0.08, 0.06, 0.05);
uniform float eye_k = 0.0;     // how far up the petal the eye reaches
uniform float spots = 0.0;
uniform float stripes = 0.0;
uniform float leaf = 0.0;
uniform float sheen = 1.0;     // how strong the rim sheen is
uniform float seed = 0.0;

void fragment() {
	float t = UV.x;
	float s = UV.y;
	float as_ = abs(s);
	float n = fbm(vec3(t * 3.0, s * 2.0, seed));
	vec3 c;
	float rimv = 0.0;
	if (leaf > 0.5) {
		// a leaf: darker towards its middle, side veins branching off the midrib towards the tip
		float sv = abs(fract(t * 7.0 - as_ * 1.8) - 0.5);
		float vein = (1.0 - smoothstep(0.02, 0.06, sv)) * (1.0 - as_ * 0.6);
		vein *= 1.0 - clamp(fwidth(t * 7.0) * 1.5, 0.0, 1.0);
		float rib = 1.0 - smoothstep(0.0, 0.06, as_);
		c = lin(c_base) * (0.75 + 0.4 * n) * (1.0 - 0.25 * as_);
		c = mix(c, lin(c_rim), max(vein * 0.4, rib * 0.6));
	} else {
		// the sheen: a lit rim and streaks running out along the petal
		float rim = smoothstep(0.78, 1.0, as_ + (n - 0.5) * 0.2) * 0.8;
		float streak = smoothstep(0.55, 0.85, vn(vec3(s * 3.5, t * 1.2, seed + 3.0))) * smoothstep(0.05, 0.3, t) * (1.0 - smoothstep(0.6, 0.95, t));
		rimv = clamp(max(rim, streak * 0.75) * (0.7 + 0.6 * n), 0.0, 1.0) * sheen;
		// veins fanning out from the base, a midrib
		float vein = smoothstep(0.8, 0.97, abs(sin(s * (9.0 + 4.0 * t) + vn(vec3(t * 6.0, s * 4.0, seed)) * 1.5)));
		vein *= 1.0 - clamp(fwidth(s * 12.0), 0.0, 1.0);
		float rib = 1.0 - smoothstep(0.0, 0.07, as_);
		c = lin(c_base) * (0.85 + 0.3 * n);
		// the eye at the base, its edge ragged
		float eye = 1.0 - smoothstep(eye_k - 0.08, eye_k + 0.08, t + (vn(vec3(s * 6.0, t * 4.0, seed + 7.0)) - 0.5) * 0.15);
		c = mix(c, lin(c_eye), eye * step(0.01, eye_k));
		c = mix(c, lin(c_rim), rimv);
		c = mix(c, mix(lin(c_rim), lin(c_eye), 0.5) * 0.8, vein * 0.3 * (0.3 + rimv));
		// spots near the base, stripes along the veins
		vec3 sp = vor2(vec2(s * 5.0, t * 9.0) + seed);
		float spot = (1.0 - smoothstep(0.12, 0.2, sp.x)) * step(0.45, sp.z) * (1.0 - smoothstep(0.3, 0.7, t)) * spots;
		c = mix(c, lin(c_eye) * 0.6, spot);
		float stripe = smoothstep(0.6, 0.9, abs(sin(s * 7.0 + n))) * (1.0 - smoothstep(0.5, 0.9, t)) * stripes;
		c = mix(c, lin(c_eye), stripe * 0.7);
		c *= 1.0 - rib * 0.3;
	}
	c *= 0.92 + 0.16 * vn(vec3(t * 40.0, s * 12.0, seed));
	vec3 nn = NORMAL;
	if (!FRONT_FACING) nn = -nn;
	NORMAL = nn;
	ALBEDO = c;
	METALLIC = rimv * 0.15;
	SPECULAR = 0.2;
	ROUGHNESS = mix(0.5, 0.32, rimv);
	CLEARCOAT = 0.15;
	CLEARCOAT_ROUGHNESS = 0.2;
	BACKLIGHT = mix(lin(c_base), lin(c_rim), rimv) * 0.3;
}
