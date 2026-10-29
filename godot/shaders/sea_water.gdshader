shader_type canvas_item;
// The sea of Whalebone Cove (mine 3): a layer cut from the picture itself (the water and its foam, by a mask), drawn over it
// and set moving. mode 0 - the waves at the foot of the cliff: the colour is read a little aside and up/down in long
// rolling swells, the foam (bright pixels) flickers; `swell` lifts it all for a moment when a big wave breaks.
// mode 1 - the sea seen in section like an aquarium wall: a slow sway sideways that grows towards the sea bed's kelp,
// shafts of light from the top crawl across and fade with depth, dapples of light play under the surface.
// Lengths in texture px; the colour comes from the picture, COLOR's tone kept (the difference of two samples).

uniform int mode = 0;
uniform float amp = 3.0;
uniform float swell = 0.0;
uniform float rays = 1.0;
uniform float beam = 0.0;          // the lighthouse's beam sweeping over the water: 0..1 strength
uniform float beam_x = 0.5;        // where (0..1 of the layer's width)
uniform float flash = 0.0;         // a lightning flash lighting the water (0..1)

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec2 p = UV / px;
	vec4 here = texture(TEXTURE, UV);
	float t = TIME;
	vec2 d;
	if (mode == 0) {
		d = vec2(sin(p.y * 0.045 - t * 1.4 + p.x * 0.006) * 1.0 + sin(p.x * 0.013 + t * 0.7) * 0.6,
				 sin(p.x * 0.021 - t * 1.7) * 0.8 + sin(p.x * 0.05 + p.y * 0.03 + t * 2.3) * 0.35) * amp * (1.0 + swell);
	} else {
		float deep = UV.y;
		d = vec2((sin(p.y * 0.018 + t * 0.6) * 0.6 + sin(p.y * 0.05 - t * 0.9 + p.x * 0.004) * 0.4) * (0.4 + deep), 0.0) * amp;
	}
	vec4 c = texture(TEXTURE, UV + d * px);
	vec3 col = mix(here.rgb, c.rgb, c.a);
	if (mode == 0) {
		float lum = dot(col, vec3(0.33));
		float sp = sin(p.x * 0.19 + t * 3.1) * sin(p.y * 0.23 - t * 2.4 + p.x * 0.05);
		col += vec3(0.16, 0.2, 0.22) * smoothstep(0.45, 0.8, lum) * smoothstep(0.55, 1.0, sp);
		col *= 1.0 + 0.25 * swell * smoothstep(0.3, 0.7, lum);
	} else {
		float deep = UV.y;
		// shafts of light from the top, leaning, crawling slowly
		float r = sin((p.x + p.y * 0.42) * 0.012 + t * 0.15) * 0.5 + sin((p.x + p.y * 0.38) * 0.031 - t * 0.23) * 0.5;
		float shaft = smoothstep(0.35, 0.95, r) * pow(1.0 - deep, 1.6) * rays;
		col += vec3(0.05, 0.11, 0.13) * shaft;
		// dapples under the surface
		float dp = sin(p.x * 0.07 + sin(p.y * 0.05 + t) * 2.0 + t * 0.8) * sin(p.y * 0.09 - t * 1.1 + sin(p.x * 0.04) * 2.0);
		col += vec3(0.05, 0.09, 0.1) * smoothstep(0.6, 1.0, dp) * smoothstep(0.35, 0.0, deep);
		// the lighthouse's beam reaching down into the water as a pale cone
		float bx = abs(UV.x - beam_x - (UV.y) * 0.18);
		col += vec3(0.16, 0.15, 0.1) * beam * smoothstep(0.09, 0.0, bx) * pow(1.0 - deep, 2.2);
	}
	// a lightning flash: the water lit cold and pale for an instant, fading with depth in the section
	float fk = flash * (mode == 0 ? 1.0 : pow(1.0 - UV.y, 1.3));
	col = mix(col, col * 2.2 + vec3(0.07, 0.09, 0.13), fk);
	// COLOR already holds the picture (times the modulate): only the change is added, the tone stays
	COLOR.rgb += col - here.rgb;
}
