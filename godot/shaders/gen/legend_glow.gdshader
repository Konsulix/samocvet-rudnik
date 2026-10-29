shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec3 col = vec3(1.0);
uniform float pulse = 0.0;
uniform float speed = 3.0;
void fragment() {
	float p = 1.0 - pulse + pulse * pow(0.5 + 0.5 * sin(TIME * speed + COLOR.r * 6.0), 3.0);
	ALBEDO = col * p;
}
