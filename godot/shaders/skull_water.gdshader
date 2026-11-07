// A stream running over a skull (SpecSkull._sheet): a domed sheet of clear water; UV.x across (0..1), UV.y along it.
// Mostly see-through — the bone shows through, darkened and wet; the lamps glint on a gently rippling surface that
// slides downstream; long soft threads of light run down it; a little white water where it wells out.
shader_type spatial;
render_mode cull_back, blend_mix, depth_draw_opaque;
#include "res://shaders/opal.gdshaderinc"

void fragment() {
	float x = UV.x;
	float y = UV.y;
	float edge = min(x, 1.0 - x) * 2.0;
	float t = TIME;
	float sp = 0.6 + edge * 0.8;
	// long, soft ripples sliding down (low frequency: no glitter)
	float rip = fbm(vec3(x * 2.5, y * 9.0 - t * sp * 1.4, 0.0));
	float thread = smoothstep(0.55, 0.85, fbm(vec3(x * 5.0, y * 2.2 - t * sp * 1.8, 4.0))) * edge;
	float foam = smoothstep(0.5, 0.7, fbm(vec3(x * 6.0, y * 14.0 - t * 2.5, 9.0))) * (1.0 - smoothstep(0.0, 0.06, y));
	vec3 c = mix(vec3(0.04, 0.06, 0.07), vec3(0.8, 0.88, 0.95), thread * 0.6 + foam * 0.8);
	ALBEDO = c;
	ALPHA = clamp(0.42 + thread * 0.4 + foam * 0.6 + pow(1.0 - abs(dot(NORMAL, VIEW)), 2.0) * 0.4, 0.0, 0.92) * smoothstep(0.0, 0.25, edge);
	vec3 dx = dFdx(VERTEX), dy = dFdy(VERTEX);
	float h = rip;
	vec3 r1 = cross(dy, NORMAL), r2 = cross(NORMAL, dx);
	float det = dot(dx, r1);
	vec3 rn = abs(det) * NORMAL - sign(det) * (dFdx(h) * r1 + dFdy(h) * r2) * 0.0015;
	NORMAL = dot(rn, rn) > 1e-20 ? normalize(rn) : NORMAL;
	ROUGHNESS = 0.06;
	SPECULAR = 0.9;
	EMISSION = vec3(0.6, 0.75, 0.85) * thread * 0.05;
}
