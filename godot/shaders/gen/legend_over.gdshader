shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_test_disabled, depth_draw_never;
uniform vec3 col = vec3(1.0);
uniform float speed = 7.0;
void fragment() {
	float run = pow(0.5 + 0.5 * sin(TIME * speed - COLOR.r * 14.0), 6.0);
	float flick = 0.6 + 0.4 * step(0.35, fract(sin(floor(TIME * 9.0) * 12.9898) * 43758.5));
	ALBEDO = col * (0.35 + 1.6 * run) * flick;
}
