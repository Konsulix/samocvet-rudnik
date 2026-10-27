shader_type spatial;
render_mode cull_disabled;
// A petal of the flower held in clear stone (SpecFlower). UV.x = 0 at its base .. 1 at its tip, UV.y = -1 .. 1
// across it. Dark in the middle, a metallic sheen (bronze, copper...) towards its rims and tip, fine veins running
// out from the base and a darker midrib; glossy, a little light through it.

#include "res://shaders/opal.gdshaderinc"

uniform vec3 c_base : source_color = vec3(0.08, 0.06, 0.05);
uniform vec3 c_rim : source_color = vec3(0.72, 0.45, 0.22);
uniform float seed = 0.0;

varying vec3 v_op;

void vertex() {
	v_op = VERTEX;
}

void fragment() {
	float t = UV.x;
	float s = UV.y;
	float as_ = abs(s);
	// the sheen: from the rims in and from the tip down, uneven
	float n = fbm(vec3(t * 3.0, s * 2.0, seed));
	// a thin lit rim, and streaks of sheen running out along the petal from its base (the rest near black)
	float rim = smoothstep(0.78, 1.0, as_ + (n - 0.5) * 0.2) * 0.8;
	float streak = smoothstep(0.55, 0.85, vn(vec3(s * 3.5, t * 1.2, seed + 3.0))) * smoothstep(0.05, 0.3, t) * (1.0 - smoothstep(0.6, 0.95, t));
	rim = clamp(max(rim, streak * 0.75) * (0.7 + 0.6 * n), 0.0, 1.0);
	// veins: fine lines fanning out from the base, a midrib
	float vein = smoothstep(0.8, 0.97, abs(sin(s * (9.0 + 4.0 * t) + vn(vec3(t * 6.0, s * 4.0, seed)) * 1.5)));
	vein *= 1.0 - clamp(fwidth(s * 12.0), 0.0, 1.0);
	float rib = 1.0 - smoothstep(0.0, 0.07, as_);
	vec3 c = mix(lin(c_base), lin(c_rim), rim);
	c = mix(c, lin(c_rim) * 0.75, vein * 0.35 * (0.3 + rim));
	c *= 1.0 - rib * 0.4;
	c *= 0.9 + 0.2 * vn(vec3(t * 40.0, s * 12.0, seed));
	vec3 nn = NORMAL;
	if (!FRONT_FACING) nn = -nn;
	NORMAL = nn;
	ALBEDO = c;
	METALLIC = rim * 0.15;
	SPECULAR = 0.18;
	ROUGHNESS = mix(0.5, 0.32, rim);
	CLEARCOAT = 0.15;
	CLEARCOAT_ROUGHNESS = 0.2;
	BACKLIGHT = lin(c_rim) * 0.25 * rim;
}
