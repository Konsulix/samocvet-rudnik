// Mushrooms from scans and models (SpecFungi, assets/specimen/fungi): each mesh wears the colour and the relief baked
// from the full scan (prototype/tools/mushrooms/shroom_prep.py). The instance colour tints one mushroom of a cluster a
// little apart from the next. `glow`: the glowing mycena — a pale mushroom whose cap gives the light (the gills under
// it brightest, the stem only a trace), breathing, brighter still when the room goes dark (the ultraviolet flash of a
// fluorescent find). The soft light round the cap is its own square (fungi_halo.gdshader).
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D tex_d : source_color, filter_linear_mipmap;
uniform sampler2D tex_n : hint_normal, filter_linear_mipmap;
uniform vec3 tint = vec3(1.0);
uniform float gain = 1.0;
uniform float sat = 1.0;
uniform float rough = 0.55;
uniform float glow = 0.0;
uniform vec3 glow_col = vec3(0.03, 0.6, 0.17);
uniform float cap_from = 0.62;   // (the cap: this far up the mushroom, of its height)
global uniform float fluor_uv;
varying vec3 v_op;
varying vec3 v_on;

void vertex() {
	v_op = VERTEX;
	v_on = NORMAL;
}

void fragment() {
	vec3 c = texture(tex_d, UV).rgb;
	float l = dot(c, vec3(0.3, 0.5, 0.2));
	c = mix(vec3(l), c, sat) * gain * tint * COLOR.rgb;
	ALBEDO = c;
	NORMAL_MAP = texture(tex_n, UV).rgb;
	ROUGHNESS = rough;
	SPECULAR = 0.35;
	// (thin flesh: a little of the light behind comes through)
	BACKLIGHT = c * 0.2;
	float under = smoothstep(0.15, -0.45, normalize(v_on).y);
	float cap = smoothstep(cap_from, cap_from + 0.26, v_op.y);
	float br = (0.8 + 0.2 * sin(TIME * 1.3 + v_op.y * 4.0)) * (1.0 + fluor_uv * 1.5);
	// (the hottest of it goes a little white, as a light does)
	vec3 gc = glow_col + vec3(0.1, 0.12, 0.1) * under * cap;
	EMISSION = glow * gc * mix(0.05, 0.5 + 0.5 * under, cap) * br * (0.45 + 0.55 * l);
}
