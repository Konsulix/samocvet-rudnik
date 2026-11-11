// A butterfly model's wings and body given a surface (SpecButterfly._scales): the model's own painted picture, and over
// it what a real wing has — rows of tiny overlapping scales (a fine relief, each catching the light a little
// differently: they glitter as the wing moves), the powder's soft unevenness, a velvet sheen toward the edge of sight,
// a little light through the wing. The scales fade out where they get finer than a pixel (no shimmer of moiré).
shader_type spatial;
render_mode cull_disabled;
#include "res://shaders/opal.gdshaderinc"

uniform sampler2D tex : source_color, filter_linear_mipmap_anisotropic;
uniform float cut = 0.5;

void fragment() {
	vec4 c = texture(tex, UV);
	if (c.a < cut) discard;
	// rows of scales, each row half a scale along from the last
	vec2 s = UV * vec2(300.0, 420.0);
	float row = floor(s.y);
	s.x += mod(row, 2.0) * 0.5;
	vec2 cell = floor(s);
	vec2 f = fract(s) - vec2(0.5, 0.35);
	float d = length(f * vec2(1.0, 0.75));
	float fw = max(fwidth(s.x), fwidth(s.y));
	float seen = clamp(1.3 - fw * 0.9, 0.0, 1.0);
	float scale = smoothstep(0.6, 0.15, d) * seen;
	float id = h3(vec3(cell, 3.0));
	// the powder: soft patches a little lighter and darker, and the grain of it
	float powder = fbm(vec3(UV * 46.0, 1.0));
	float grain = vn(vec3(UV * 520.0, 7.0));
	float fr = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.2);
	vec3 col = c.rgb * (0.86 + 0.24 * powder) * (0.94 + 0.12 * grain * seen);
	// each scale tilted its own way: some catch the light as the wing turns
	float glint = pow(0.5 + 0.5 * sin(id * 40.0 + fr * 9.0 + dot(NORMAL, vec3(3.0, 5.0, 2.0)) * 6.0), 10.0) * seen;
	col += c.rgb * (0.35 * fr + 0.5 * glint) + vec3(0.06) * glint;
	ALBEDO = col;
	ROUGHNESS = mix(0.72, 0.42, scale * (0.5 + 0.5 * id));
	SPECULAR = 0.35;
	BACKLIGHT = c.rgb * 0.3;
	NORMAL = bump(NORMAL, VERTEX, (scale * (0.6 + 0.4 * id) + powder * 0.5) * 0.0012, 1.0);
}
