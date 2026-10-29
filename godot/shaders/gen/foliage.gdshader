
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;
uniform sampler2D tex : source_color, filter_linear_mipmap;
void fragment() {
	vec4 t = texture(tex, UV);
	ALBEDO = t.rgb * COLOR.rgb;
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = 0.45;
	ROUGHNESS = 0.75;
	SPECULAR = 0.25;
	// leaves face the sky more than the card does, so tufts shade softly like a cushion
	NORMAL = normalize(mix(NORMAL, (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz, 0.55));
	BACKLIGHT = t.rgb * COLOR.rgb * 0.8;
	// darker deep inside the tuft
	ALBEDO *= mix(0.35, 1.0, smoothstep(0.0, 0.7, 1.0 - UV.y));
}
