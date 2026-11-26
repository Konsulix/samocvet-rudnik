shader_type canvas_item;
// A floating card turned a few degrees in depth, in true perspective (CardLevitate): its picture (the card drawn in a
// SubViewport of its own, with `pad` of room round it) laid on a plane turned by `tilt` (x - about the upright axis,
// y - about the level one) and seen from in front; the side turned to the light (up and left) a little brighter, a
// soft band of light sliding over it as it turns.

uniform vec2 tilt = vec2(0.0);
uniform vec2 pad = vec2(0.08);         // the room round the card, of the picture
uniform float persp = 0.7;             // how strong the perspective, of the picture's width
uniform vec2 hole = vec2(0.0);         // > 0: a rounded hole this far in from the edges (of the picture), cut out
uniform float hole_r = 0.05;           // its corners (of the picture's width)
// (25.11) the rect drawn is bigger than the picture by this much each side (of the picture): turned, the side near the
// eye grows in perspective past the picture's own edges, and was cut off there
uniform vec2 grow = vec2(0.0);
// (26.11) the picture moved inside the rect by this much (of the rect): the card's float. A Control's own place is
// snapped to whole pixels — floating up and down by moving the Control went in little jerks
uniform vec2 shift = vec2(0.0);

float sd_round(vec2 p, vec2 h, float r) {
	vec2 q = abs(p) - h + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 asp = vec2(1.0, TEXTURE_PIXEL_SIZE.x / TEXTURE_PIXEL_SIZE.y);
	// this pixel on the turned plane, in units of the picture's width, its middle at 0
	vec2 q = (UV - shift - 0.5) * (1.0 + 2.0 * grow) * asp;
	vec2 sn = sin(tilt);
	vec2 cs = cos(tilt);
	// back onto the flat picture: a point of the plane at depth z = x sin(yaw) + y sin(pitch) is seen shrunk by
	// 1 / (1 + z k) towards the middle. Solved exactly (26.11: a few rounds of iteration did not settle near edge-on —
	// stretched stripes of the card stood beside it as it turned over): z = A / (1 - k A), A = sum(q sin / cos)
	vec2 csafe = max(abs(cs), vec2(0.0001)) * sign(cs + vec2(0.00001));
	float A = q.x * sn.x / csafe.x + q.y * sn.y / csafe.y;
	float den = 1.0 - persp * A;
	if (den <= 0.02) discard;          // (behind the eye's plane: nothing of the card is there)
	float zz = A / den;
	vec2 s = q * (1.0 + zz * persp) / csafe;
	vec2 uv = s / asp + 0.5;
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) discard;
	// four samples over the screen pixel's footprint: the picture is denser than the screen, read between its pixels
	vec2 dx = dFdx(uv) * 0.25, dy = dFdy(uv) * 0.25;
	vec4 c = (texture(TEXTURE, uv + dx + dy) + texture(TEXTURE, uv - dx + dy) + texture(TEXTURE, uv + dx - dy) + texture(TEXTURE, uv - dx - dy)) * 0.25;
	// light: the near side brighter, the far one a little darker; a band of light sliding as it turns (on the card only)
	float z = s.x * sn.x + s.y * sn.y;
	c.rgb *= 1.0 - clamp(z * 1.6, -0.12, 0.12);
	vec2 cu = (uv - pad) / (1.0 - pad * 2.0);
	float band = exp(-pow((cu.x * 0.7 + cu.y * 0.5) - (0.6 + tilt.x * 5.0 - tilt.y * 4.0), 2.0) / 0.03);
	c.rgb += vec3(1.0, 0.96, 0.88) * band * 0.06 * c.a;
	if (hole.x > 0.0) {
		vec2 hp = (uv - 0.5) * asp;
		c.a *= smoothstep(-0.003, 0.003, sd_round(hp, (0.5 - hole) * asp, hole_r));
	}
	COLOR = c;
}
