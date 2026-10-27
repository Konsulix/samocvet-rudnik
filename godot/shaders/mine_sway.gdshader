shader_type canvas_item;
// The pines on the slopes behind the mine sway a little in the night wind. Set on the surface sprite and on the layer
// that draws the places over it, so it works in the mine's own coordinates (source px), not the texture's: only in the
// band of the trees (top..bottom), more towards the tops, and only where the picture is dark blue-green (trees, sky),
// not the warm wood of the hut or the headframe. The shift is added to COLOR as a difference of two TEXTURE samples,
// so the picture keeps COLOR's tone.

uniform float top = 0.0;       // mine px: the tree band
uniform float bottom = 1000.0;
uniform float amp = 6.0;       // mine px of sway at the top of the band

varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	float k = clamp((bottom - world.y) / (bottom - top), 0.0, 1.0) * step(world.y, bottom);
	vec4 here = texture(TEXTURE, UV);
	float treeish = step(here.r, here.b + 0.08) * step(here.r + here.g + here.b, 1.4);
	float w = sin(TIME * 1.1 + world.x * 0.025) * 0.6 + sin(TIME * 0.7 + world.x * 0.008) * 0.4;
	// the shift in texture px: the sprite may be drawn scaled (1/K), TEXTURE_PIXEL_SIZE is per texture px
	vec2 uv = UV + vec2(amp * k * w * treeish * TEXTURE_PIXEL_SIZE.x * 0.76, 0.0);
	COLOR.rgb += (texture(TEXTURE, uv).rgb - here.rgb) * k;
}
