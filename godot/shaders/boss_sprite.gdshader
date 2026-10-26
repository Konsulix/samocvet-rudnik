shader_type canvas_item;
// The boss on the 1-pt pixel grid (BossView): a pixel-art cross-fade from the last picture (an ordered-dither mask
// decides which pixels already show the new one) and the white hit flash. Pictures are the same size.
// Its bottom is cut flat to lie on the frame's top bar; where the board's top is cut away (a missing corner, beyond
// the board's sides) no bar hides that cut, so there the bottom sinks into the cave's dark and dithers away.

uniform sampler2D from_tex : source_color, filter_nearest;
uniform float fade = 1.0;     // 0: still the old picture, 1: the new one
uniform float flash = 0.0;    // 0..1 towards warm white, only where the boss is
uniform sampler2D exposed : filter_nearest;   // one row, a texel per column: 1 where no bar hides the bottom
uniform float sink_band = 0.0;                // how high above the bottom it starts to sink, in the picture's px

const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void fragment() {
	// COLOR already holds the texture as the engine reads it (colour space right for an HDR canvas)
	vec4 c = COLOR;
	if (fade < 1.0) {
		ivec2 p = ivec2(UV * vec2(textureSize(TEXTURE, 0)));
		float th = (BAYER[(p.y % 4) * 4 + (p.x % 4)] + 0.5) / 16.0;
		if (th >= fade) c = texture(from_tex, UV);
	}
	if (sink_band > 0.0) {
		vec2 sz = vec2(textureSize(TEXTURE, 0));
		ivec2 p = ivec2(UV * sz);
		float e = texture(exposed, vec2(UV.x, 0.5)).r;
		float t = clamp((UV.y * sz.y - (sz.y - sink_band)) / sink_band, 0.0, 1.0) * e;
		// first into shadow, the lower part also dithered away (the same 4x4 order as the dissolve)
		c.rgb *= 1.0 - 0.8 * smoothstep(0.0, 0.7, t);
		float th = (BAYER[(p.y % 4) * 4 + (p.x % 4)] + 0.5) / 16.0;
		if (th < (t - 0.45) / 0.55) c.a = 0.0;
	}
	c.rgb = mix(c.rgb, vec3(1.0, 0.98, 0.92), flash * step(0.5, c.a));
	COLOR = c;
}
