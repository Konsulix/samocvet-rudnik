
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_test_disabled, depth_draw_never;
uniform sampler2D strands : filter_linear_mipmap, repeat_enable;
uniform vec3 glow_col = vec3(0.35, 0.6, 2.2);
uniform float flash = 1.0;
uniform float fps = 14.0;
float hash(float n) { return fract(sin(n * 12.9898) * 43758.5453); }
void vertex() {
	// UV.x: -1..1 across; UV.y: distance along the branch; UV2.x: half-width; NORMAL: segment direction
	vec3 dir = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 pv = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 side = normalize(cross(dir, normalize(-pv)));
	pv += side * UV.x * UV2.x;
	POSITION = PROJECTION_MATRIX * vec4(pv, 1.0);
}
void fragment() {
	float x = UV.x;
	float a = COLOR.a * flash;
	// COLOR.g: which branch; each branch picks a fresh filament every frame
	float frame = floor(TIME * fps);
	float pick = floor(hash(COLOR.g * 91.7 + frame * 3.1) * 16.0);
	float off = hash(COLOR.g * 13.3 + frame * 7.7);
	// the core: overexposed white, its thickness flickering along the channel; a violet-blue glow round it
	float wob = 0.65 + 0.35 * sin(UV.y * 9.0 + COLOR.g * 40.0 + frame * 1.7) * sin(UV.y * 23.0 + frame);
	// filament texture (CC0) breaks the core into strands and leaves ragged edges on the glow
	float fil = texture(strands, vec2((pick + 0.5 + x * 0.25) / 16.0, UV.y * 0.3 + off)).a;
	float edge = 1.0 - smoothstep(0.8, 1.0, abs(x));
	vec3 c;
	if (COLOR.r > 0.5) {
		float core = exp(-x * x / (0.012 * wob));
		c = vec3(5.0, 5.2, 6.0) * core * (0.75 + 0.5 * fil)
			+ glow_col * 1.4 * exp(-x * x * 9.0) * (0.6 + 0.6 * fil)
			+ glow_col * 0.5 * exp(-abs(x) * 3.5);
	} else {
		c = glow_col * 0.45 * pow(1.0 - abs(x), 3.0) * (0.7 + 0.5 * fil);
	}
	c *= edge;
	ALBEDO = c * a;
}
