shader_type spatial;
// (21.11) a living druse: the outline a growing crystal leaves at each of its sizes — a phantom of light inside the
// glass, as growth zones are in real quartz (SpecView._sprout). Drawn over the glass (no depth test). Not a wireframe
// (it read as a hologram): a veil over its faces — milky in drifts, thicker at a glance, its edges only a little
// brighter (the mesh's distances to the real edges, CUSTOM0)
render_mode unshaded, blend_add, cull_disabled, depth_test_disabled, depth_draw_never, shadows_disabled;

uniform vec3 col = vec3(1.0);
uniform float k = 1.0;
varying vec4 vb;
varying vec3 vp;

float h3(vec3 p) { p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float vn(vec3 x) {
	vec3 i = floor(x), f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h3(i), h3(i + vec3(1, 0, 0)), f.x), mix(h3(i + vec3(0, 1, 0)), h3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(h3(i + vec3(0, 0, 1)), h3(i + vec3(1, 0, 1)), f.x), mix(h3(i + vec3(0, 1, 1)), h3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	vb = CUSTOM0;
	vp = VERTEX;
}

void fragment() {
	float fr = pow(1.0 - abs(dot(normalize(NORMAL), VIEW)), 3.0);
	float e = 0.0;
	if (vb.w > 0.5) {
		float eb = min(vb.x, min(vb.y, vb.z));
		e = 1.0 - smoothstep(0.004, 0.03, eb);
	}
	float milk = 0.35 + 0.9 * smoothstep(0.3, 0.75, vn(vp * 9.0 + 2.0) * 0.6 + vn(vp * 23.0) * 0.4);
	ALBEDO = col * (milk * (0.09 + fr * 0.3) + e * 0.12) * k;
	// (a see-through picture - the inventory's tiles: added with an alpha of 1, every pixel it covers became opaque,
	// a black shape round the light; the strength goes in ALPHA, the colour comes out the same - fungi_halo too)
	float lum_a = clamp(max(max(ALBEDO.r, ALBEDO.g), ALBEDO.b), 0.0, 1.0);
	ALPHA = lum_a;
	ALBEDO /= max(lum_a, 1e-4);
}
