shader_type canvas_item;
// The pines of a mine sway a little in the night wind - and nothing else: unlike a colour test (which picked the
// dark blue-green of the picture and so moved huts, rock and the gloomy factory too) the trees are a mask of their own, in the
// mine's coordinates (source px). Where the mask is white the picture is read a few px aside; the shift is added to
// COLOR as a difference of two TEXTURE samples, so the picture keeps COLOR's tone.
// The mine's px come from the layer's own VERTEX (MODEL_MATRIX would give the screen: scrolled and scaled - with it the
// mask missed the trees, and the old colour test swayed half the screen): `to_mine` is the layer's px -> mine px, 1/K for
// the surface sprite (its texture px), 1 for a layer drawing in mine px - so the surface and that layer need two materials.

uniform sampler2D mask : filter_linear;
uniform vec4 mask_rect = vec4(0.0, 0.0, 1.0, 1.0);   // mine px: x, y, w, h
uniform float amp = 4.0;                             // mine px of sway at the tree tops
uniform float to_mine = 1.0;

varying vec2 world;

void vertex() {
	world = VERTEX * to_mine;
}

void fragment() {
	vec2 m = (world - mask_rect.xy) / mask_rect.zw;
	float k = 0.0;
	if (m.x >= 0.0 && m.x <= 1.0 && m.y >= 0.0 && m.y <= 1.0) k = texture(mask, m).r;
	vec4 here = texture(TEXTURE, UV);
	float w = sin(TIME * 1.1 + world.x * 0.025) * 0.6 + sin(TIME * 0.7 + world.x * 0.008) * 0.4;
	vec2 uv = UV + vec2(amp * k * w * TEXTURE_PIXEL_SIZE.x * 0.76, 0.0);
	COLOR.rgb += (texture(TEXTURE, uv).rgb - here.rgb) * k;
}
