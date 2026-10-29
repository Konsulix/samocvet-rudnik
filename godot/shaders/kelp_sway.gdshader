shader_type canvas_item;
// A stand of kelp cut out of Whalebone Cove's sea picture (art/zone/export_kelp.py; the painted kelp under it is covered
// with water in deep.png): it sways in the current - nothing at its foot (the layer's bottom row, on the sea bed), more and
// more towards the tips, and a slow wave runs up it, so the fronds bend instead of sliding. The layer is padded sideways.
// The colour comes from the texture read aside, COLOR's tone kept (the difference of two samples, as sea_water does).

uniform float amp = 18.0;      // texture px of sway at the tips
uniform float seed = 0.0;

void fragment() {
	float h = 1.0 - UV.y;
	float t = TIME;
	float off = amp * pow(h, 1.5) * (0.65 * sin(t * 0.55 + seed - h * 2.2) + 0.35 * sin(t * 1.25 + seed * 2.3 - h * 4.6));
	off += amp * 0.12 * h * sin(t * 2.1 + seed * 3.1 - h * 9.0);      // the fronds' own flutter
	vec4 here = texture(TEXTURE, UV);
	vec4 c = texture(TEXTURE, UV - vec2(off * TEXTURE_PIXEL_SIZE.x, 0.0));
	COLOR += c - here;
}
