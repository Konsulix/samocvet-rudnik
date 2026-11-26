shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_test_disabled, depth_draw_never;
uniform vec3 col = vec3(1.0);
uniform float speed = 7.0;
void fragment() {
	float run = pow(0.5 + 0.5 * sin(TIME * speed - COLOR.r * 14.0), 6.0);
	float flick = 0.6 + 0.4 * step(0.35, fract(sin(floor(TIME * 9.0) * 12.9898) * 43758.5));
	vec3 lit_c = col * (0.35 + 1.6 * run) * flick;
	// (26.11: a black ring round it on the inventory's see-through thumbnails) the light's strength in ALPHA: added
	// with an alpha of 1 the glow made its square opaque; the colour added comes out the same
	float lit_a = clamp(max(lit_c.r, max(lit_c.g, lit_c.b)), 0.0, 1.0);
	ALBEDO = lit_c / max(lit_a, 0.0001);
	ALPHA = lit_a;

}
