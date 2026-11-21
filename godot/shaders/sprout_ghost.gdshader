shader_type spatial;
// (21.11) a living druse: the outline a growing crystal leaves at each of its sizes — a phantom of light inside the
// glass, as growth zones are in real quartz (SpecView._sprout). Drawn over the glass (no depth test), its edges
// bright (the mesh's distances to the real edges, CUSTOM0), the faces a faint sheen at a glance
render_mode unshaded, blend_add, cull_disabled, depth_test_disabled, depth_draw_never, shadows_disabled;

uniform vec3 col = vec3(1.0);
uniform float k = 1.0;
varying vec4 vb;

void vertex() {
	vb = CUSTOM0;
}

void fragment() {
	float fr = pow(1.0 - abs(dot(normalize(NORMAL), VIEW)), 3.0);
	float e = 0.0;
	if (vb.w > 0.5) {
		float eb = min(vb.x, min(vb.y, vb.z));
		e = 1.0 - smoothstep(0.003, 0.018, eb);
	}
	ALBEDO = col * (e * 0.6 + fr * 0.28 + 0.03) * k;
}
