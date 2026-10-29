
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;
uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform sampler2D nrm : hint_normal, filter_linear_mipmap;
void fragment() {
	vec4 t = texture(tex, UV);
	ALBEDO = t.rgb * COLOR.rgb;
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = 0.4;
	NORMAL_MAP = texture(nrm, UV).rgb;
	ROUGHNESS = 0.72;
	SPECULAR = 0.3;
	BACKLIGHT = t.rgb * COLOR.rgb * 0.7;
}
