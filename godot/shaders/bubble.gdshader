shader_type spatial;
// A rising bubble (SpecSea.Bubbles): only its bright rim and a pin of light, drawn additively — clear in the middle.
render_mode unshaded, blend_add, cull_back, depth_draw_never, shadows_disabled;

uniform vec3 tint : source_color = vec3(0.8, 0.92, 1.0);

void fragment() {
	float nv = abs(dot(normalize(NORMAL), VIEW));
	float rim = pow(1.0 - nv, 3.0);
	float pin = smoothstep(0.93, 0.99, dot(normalize(NORMAL), normalize(vec3(-0.4, 0.6, 0.7))));
	ALBEDO = tint * (rim * 0.9 + pin * 1.2);
	// (a see-through picture - the inventory's tiles: added with an alpha of 1, every pixel it covers became opaque,
	// a black shape round the light; the strength goes in ALPHA, the colour comes out the same - fungi_halo too)
	float lum_a = clamp(max(max(ALBEDO.r, ALBEDO.g), ALBEDO.b), 0.0, 1.0);
	ALPHA = lum_a;
	ALBEDO /= max(lum_a, 1e-4);
}
