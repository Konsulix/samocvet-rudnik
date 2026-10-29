shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never, shadows_disabled;
uniform vec3 col = vec3(1.0);
uniform float soft = 2.0;
uniform float swell = 0.5;
global uniform float heart_beat;
void fragment() {
	float f = pow(clamp(dot(normalize(NORMAL), VIEW), 0.0, 1.0), soft);
	ALBEDO = col * f * (1.0 - swell + swell * heart_beat);
}
