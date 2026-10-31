shader_type canvas_item;
// The geode's rind lit from its cracks (GeodeOpen): the light inside spills out over the knobbly stone round each
// crack, its bright bumps catching more of it than its hollows, a tight hot glow by the crack and a wide soft one.
// `pts` - points along the cracks in the picture's UV, z how wide the crack is there (0..1); colour from COLOR.

uniform vec3 pts[64];
uniform int count = 0;
uniform vec4 light : source_color = vec4(1.0);
uniform float power = 0.0;
uniform float aspect = 1.0;     // the picture's width over its height: distances round, not stretched

void fragment() {
	vec4 c = COLOR;
	float near = 0.0;
	float far = 0.0;
	for (int i = 0; i < 64; i++) {
		if (i >= count) break;
		vec2 d = (UV - pts[i].xy) * vec2(aspect, 1.0);
		float r2 = dot(d, d);
		near += pts[i].z * exp(-r2 * 2600.0);
		far += pts[i].z * exp(-r2 * 260.0);
	}
	near = min(near, 2.2);
	far = min(far, 2.4);
	float lum = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	vec3 L = light.rgb * power;
	// the stone takes the colour (its own light multiplied) and gains it (the glow added), more on its bright bumps
	vec3 lit = c.rgb * (1.0 + L * (near * 0.8 + far * 0.35)) + L * (near * (0.08 + 0.45 * lum) + far * (0.02 + 0.16 * lum));
	c.rgb = mix(c.rgb, lit, c.a);
	COLOR = c;
}
