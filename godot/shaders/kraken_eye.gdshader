shader_type canvas_item;
// The Kraken's eye on his last board, alive: the picture with its pupil painted out (eye_blank.png,
// art/boss/eye_parts.py), and over it, on the picture's own pixel grid, a pupil drawn here - a cephalopod's dark
// horizontal slit in a darker ring - that darts about inside the eyeball (`look`), narrows and widens (`slit`), and
// lids of his hide that close over the eyeball from above and below (`lid`: 0 open .. 1 shut) for a squint, a blink or a
// flinch. The BoardView drives it all. The eyeball's shape is `ball` (a mask), its middle and half size `ball_c/ball_h`.

uniform sampler2D ball : filter_nearest;
uniform vec2 size = vec2(92.0, 92.0);      // the picture, px
uniform vec2 ball_c = vec2(46.5, 37.0);
uniform vec2 ball_h = vec2(19.5, 17.0);
uniform vec2 look = vec2(0.0);             // the pupil's offset from the middle, px
uniform vec2 slit = vec2(9.0, 2.0);        // the pupil's half width and half height, px
uniform float lid = 0.0;
uniform float glow = 1.0;                  // the iris' brightness
uniform vec3 pupil_col : source_color = vec3(0.02, 0.05, 0.06);
uniform vec3 ring_col : source_color = vec3(0.12, 0.35, 0.38);
uniform vec3 lid_col : source_color = vec3(0.36, 0.2, 0.22);
uniform vec3 lid_line : source_color = vec3(0.12, 0.05, 0.07);

void fragment() {
	vec4 tint = COLOR;      // the draw's own colour (its shadow is drawn black and see-through)
	vec4 c = texture(TEXTURE, UV);
	vec2 px = floor(UV * size) + 0.5;
	if (texture(ball, UV).r > 0.5) {
		c.rgb *= glow;
		vec2 q = (px - ball_c - look) / slit;
		float e = dot(q, q);
		// the pupil and a ring of darker iris round it, pixel-sharp
		if (e < 1.0) c.rgb = pupil_col;
		else if (e < 1.0 + 3.2 / max(slit.y, 1.0)) c.rgb = mix(c.rgb, ring_col, 0.7);
		// the lids: his hide closing in from above and below, a dark crease along their edge
		float open = ball_h.y * (1.0 - lid);
		float dy = abs(px.y - ball_c.y + (px.y < ball_c.y ? 1.0 : 0.0) * lid * 2.0);
		if (dy > open) c.rgb = lid_col * (0.75 + 0.25 * (1.0 - (dy - open) / max(ball_h.y, 1.0)));
		else if (dy > open - 1.0 && lid > 0.02) c.rgb = lid_line;
	}
	COLOR = c * tint;
}
