shader_type spatial;
// A rising bubble (SpecSea.Bubbles): only its bright rim and a pin of light, drawn additively — clear in the middle.
render_mode unshaded, blend_add, cull_back, depth_draw_never, shadows_disabled;

uniform vec3 tint : source_color = vec3(0.8, 0.92, 1.0);

void fragment() {
	float nv = abs(dot(normalize(NORMAL), VIEW));
	float rim = pow(1.0 - nv, 3.0);
	float pin = smoothstep(0.93, 0.99, dot(normalize(NORMAL), normalize(vec3(-0.4, 0.6, 0.7))));
	ALBEDO = tint * (rim * 0.9 + pin * 1.2);
}
