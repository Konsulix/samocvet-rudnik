shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never, shadows_disabled;
uniform vec3 col = vec3(1.0);
uniform float soft = 2.0;
uniform float swell = 0.5;
global uniform float heart_beat;
void fragment() {
	float f = pow(clamp(dot(normalize(NORMAL), VIEW), 0.0, 1.0), soft);
	vec3 lit_c = col * f * (1.0 - swell + swell * heart_beat);
	// (26.11: a black ring round it on the inventory's see-through thumbnails) the light's strength in ALPHA: added
	// with an alpha of 1 the glow made its square opaque; the colour added comes out the same
	float lit_a = clamp(max(lit_c.r, max(lit_c.g, lit_c.b)), 0.0, 1.0);
	ALBEDO = lit_c / max(lit_a, 0.0001);
	ALPHA = lit_a;

}
