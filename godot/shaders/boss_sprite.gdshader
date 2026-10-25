shader_type canvas_item;
// The boss on the 1-pt pixel grid (BossView): a pixel-art cross-fade from the last picture (an ordered-dither mask
// decides which pixels already show the new one) and the white hit flash. Pictures are the same size.

uniform sampler2D from_tex : source_color, filter_nearest;
uniform float fade = 1.0;     // 0: still the old picture, 1: the new one
uniform float flash = 0.0;    // 0..1 towards warm white, only where the boss is

const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void fragment() {
	// COLOR already holds the texture as the engine reads it (colour space right for an HDR canvas)
	vec4 c = COLOR;
	if (fade < 1.0) {
		ivec2 p = ivec2(UV * vec2(textureSize(TEXTURE, 0)));
		float th = (BAYER[(p.y % 4) * 4 + (p.x % 4)] + 0.5) / 16.0;
		if (th >= fade) c = texture(from_tex, UV);
	}
	c.rgb = mix(c.rgb, vec3(1.0, 0.98, 0.92), flash * step(0.5, c.a));
	COLOR = c;
}
