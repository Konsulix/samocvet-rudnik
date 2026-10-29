
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D bed : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D bed_n : filter_linear_mipmap, repeat_enable;
uniform sampler2D bed_h : filter_linear_mipmap, repeat_enable;
uniform vec3 tint = vec3(1.0);
varying float v_r;
void vertex() { v_r = UV2.x; }
void fragment() {
	float h = texture(bed_h, UV).r;
	// the cushion frays at its rim: only the tallest sprigs reach out there
	ALPHA = step(smoothstep(0.55, 1.0, v_r) * 1.05, h);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	vec3 c = texture(bed, UV).rgb * 2.2 * tint;
	ALBEDO = c * mix(0.55, 1.15, h);
	vec3 nn = texture(bed_n, UV).rgb * 2.0 - 1.0;
	NORMAL_MAP = vec3(nn.x * 0.5 + 0.5, nn.y * 0.5 + 0.5, 1.0);
	NORMAL_MAP_DEPTH = 1.4;
	ROUGHNESS = 0.8;
	SPECULAR = 0.25;
	BACKLIGHT = c * 0.6;
}
