// Bark on the little trees and roots of a skull (SpecSkull): a bark scan laid from three sides (Poly Haven, CC0), its
// height map pressed in as relief, tinted by the vertex colour so each tree has its own wood.
shader_type spatial;
render_mode cull_back;

uniform sampler2D bark_diff : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D bark_disp : filter_linear_mipmap, repeat_enable;
uniform float scale = 9.0;
uniform vec3 tint : source_color = vec3(1.0, 1.0, 1.0);

varying vec3 mp;
varying vec3 mn;

void vertex() {
	mp = VERTEX;
	mn = NORMAL;
}

void fragment() {
	vec3 w = pow(abs(normalize(mn)), vec3(4.0));
	w /= (w.x + w.y + w.z);
	vec3 q = mp * scale;
	vec3 d = texture(bark_diff, q.zy).rgb * w.x + texture(bark_diff, q.xz).rgb * w.y + texture(bark_diff, q.xy).rgb * w.z;
	float h = texture(bark_disp, q.zy).r * w.x + texture(bark_disp, q.xz).r * w.y + texture(bark_disp, q.xy).r * w.z;
	float lum = dot(d, vec3(0.33));
	// the scan's own colour (tinted a little per tree), the furrows deeper
	ALBEDO = d * tint * COLOR.rgb * mix(0.6, 1.05, h);
	ROUGHNESS = 0.92;
	SPECULAR = 0.15;
	vec3 dpx = dFdx(VERTEX), dpy = dFdy(VERTEX);
	float dhx = dFdx(h), dhy = dFdy(h);
	vec3 r1 = cross(dpy, NORMAL), r2 = cross(NORMAL, dpx);
	float det = dot(dpx, r1);
	vec3 g = sign(det) * (dhx * r1 + dhy * r2);
	vec3 rn = abs(det) * NORMAL - g * 0.012;
	NORMAL = dot(rn, rn) > 1e-20 ? normalize(rn) : NORMAL;
}
