shader_type canvas_item;
// The lightning of a find out on its card (CardBolt): the same discharge as SpecBolt's inside the stone — ribbons
// textured with real ragged filaments that jump to new ones a dozen times a second, an overexposed white core that
// frays and breaks, a violet-blue glow round it — only flat, on the card. Light added onto what is under it.
// UV.x: -1..1 across the ribbon, UV.y: the way along it; COLOR.r: a core ribbon (1) or a halo (0), COLOR.g: which
// branch, COLOR.a: how bright.
render_mode blend_add;
uniform sampler2D strands : filter_linear_mipmap, repeat_enable;
uniform vec3 glow_col = vec3(0.35, 0.6, 2.2);
uniform float fps = 16.0;
float hash(float n) { return fract(sin(n * 12.9898) * 43758.5453); }
void fragment() {
	vec4 vc = COLOR;
	float x = UV.x;
	float frame = floor(TIME * fps);
	float pick = floor(hash(vc.g * 91.7 + frame * 3.1) * 16.0);
	float off = hash(vc.g * 13.3 + frame * 7.7);
	float wob = 0.65 + 0.35 * sin(UV.y * 9.0 + vc.g * 40.0 + frame * 1.7) * sin(UV.y * 23.0 + frame);
	float fil = texture(strands, vec2((pick + 0.5 + x * 0.25) / 16.0, UV.y * 0.3 + off)).a;
	float edge = 1.0 - smoothstep(0.8, 1.0, abs(x));
	vec3 c;
	if (vc.r > 0.5) {
		float core = exp(-x * x / (0.012 * wob));
		c = vec3(5.0, 5.2, 6.0) * core * (0.75 + 0.5 * fil)
			+ glow_col * 1.4 * exp(-x * x * 9.0) * (0.6 + 0.6 * fil)
			+ glow_col * 0.5 * exp(-abs(x) * 3.5);
	} else {
		c = glow_col * 0.45 * pow(1.0 - abs(x), 3.0) * (0.7 + 0.5 * fil);
	}
	COLOR = vec4(min(c * edge * vc.a, vec3(1.0)), 1.0);
}
