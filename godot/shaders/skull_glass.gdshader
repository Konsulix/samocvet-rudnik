// A glass skull (SpecSkull, skin "glass"): clear, the flowers inside seen through it; thick at the rims (fresnel),
// a faint cool tint, sharp highlights, the back faces drawn too, dimmer, so the far wall of the head shows.
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque;

uniform vec3 tint : source_color = vec3(0.86, 0.92, 0.98);

void fragment() {
	float fr = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.2);
	float pit = 1.0 - COLOR.r;
	ALBEDO = tint * (0.6 + 0.4 * fr);
	ALPHA = clamp(0.06 + fr * 0.75 + pit * 0.25, 0.0, 0.92) * (FRONT_FACING ? 1.0 : 0.55);
	ROUGHNESS = 0.04;
	SPECULAR = 0.9;
	RIM = 0.4;
	RIM_TINT = 0.2;
}
