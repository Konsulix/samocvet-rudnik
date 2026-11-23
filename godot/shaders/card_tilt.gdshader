shader_type canvas_item;
// A floating card turned a few degrees in depth, in true perspective (CardLevitate): its picture (the card drawn in a
// SubViewport of its own, with `pad` of room round it) laid on a plane turned by `tilt` (x - about the upright axis,
// y - about the level one) and seen from in front; the side turned to the light (up and left) a little brighter, a
// soft band of light sliding over it as it turns.

uniform vec2 tilt = vec2(0.0);
uniform vec2 pad = vec2(0.08);         // the room round the card, of the picture
uniform float persp = 0.7;             // how strong the perspective, of the picture's width

void fragment() {
	vec2 asp = vec2(1.0, TEXTURE_PIXEL_SIZE.x / TEXTURE_PIXEL_SIZE.y);
	// this pixel on the turned plane, in units of the picture's width, its middle at 0
	vec2 q = (UV - 0.5) * asp;
	vec2 sn = sin(tilt);
	vec2 cs = cos(tilt);
	// back onto the flat picture: a point of the plane at depth z = x sin(yaw) + y sin(pitch) is seen shrunk by
	// 1 / (1 + z k) towards the middle; a few rounds of the inverse
	vec2 s = q;
	for (int i = 0; i < 4; i++) {
		float z = s.x * sn.x + s.y * sn.y;
		s = q * (1.0 + z * persp) / cs;
	}
	vec2 uv = s / asp + 0.5;
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) discard;
	vec4 c = texture(TEXTURE, uv);
	// light: the near side brighter, the far one a little darker; a band of light sliding as it turns (on the card only)
	float z = s.x * sn.x + s.y * sn.y;
	c.rgb *= 1.0 - clamp(z * 1.6, -0.12, 0.12);
	vec2 cu = (uv - pad) / (1.0 - pad * 2.0);
	float band = exp(-pow((cu.x * 0.7 + cu.y * 0.5) - (0.6 + tilt.x * 5.0 - tilt.y * 4.0), 2.0) / 0.03);
	c.rgb += vec3(1.0, 0.96, 0.88) * band * 0.06 * c.a;
	COLOR = c;
}
