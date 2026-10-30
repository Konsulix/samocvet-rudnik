shader_type canvas_item;
// The Kraken's eye on his last board, alive: the picture with its pupil painted out (eye_blank.png,
// art/boss/eye_parts.py), and over it, on the picture's own pixel grid, a pupil drawn here - a cephalopod's dark slit in
// a darker ring - that darts about inside the eyeball (`look`), grows a little when hit (`slit`), and lids of his hide that
// close over the eyeball (`lid`: 0 open .. 1 shut). The slit and the lids lie along the eye's own tilt (`tilt`, as the
// picture's pupil was drawn); the lids' edges are curved like the eyeball's, the upper one comes down further than the
// lower comes up, they are shaded (lighter away from the edge, a dark crease on it) and the upper casts a shadow on the
// eyeball. The BoardView drives it all. The eyeball's shape is `ball` (a mask), its middle and half size `ball_c/ball_h`.

uniform sampler2D ball : filter_nearest;
uniform vec2 size = vec2(92.0, 92.0);      // the picture, px
uniform vec2 ball_c = vec2(46.5, 37.0);
uniform vec2 ball_h = vec2(19.5, 17.0);
uniform float tilt = 0.3;                  // the eye's tilt, radians (down to the right)
uniform vec2 look = vec2(0.0);             // the pupil's offset from the middle, px, along / across the tilt
uniform vec2 slit = vec2(11.0, 3.0);       // the pupil's half width and half height, px
uniform float lid = 0.0;
uniform float glow = 1.0;                  // the iris' brightness
uniform vec3 pupil_col : source_color = vec3(0.02, 0.05, 0.06);
uniform vec3 ring_col : source_color = vec3(0.12, 0.35, 0.38);
uniform vec3 lid_light : source_color = vec3(0.58, 0.36, 0.31);
uniform vec3 lid_mid : source_color = vec3(0.36, 0.22, 0.2);
uniform vec3 lid_line : source_color = vec3(0.11, 0.07, 0.075);

// the draw's own colour (its shadow is drawn black and see-through): from the vertex - COLOR in fragment() already has
// the texture in it, and multiplying by that squared the picture's colours (it went dark)
varying vec4 tint;
void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 px = floor(UV * size) + 0.5;
	if (texture(ball, UV).r > 0.5) {
		c.rgb *= glow;
		// along the eye (u) and across it (v), turned with its tilt
		vec2 d = px - ball_c;
		vec2 uv = vec2(cos(tilt) * d.x + sin(tilt) * d.y, -sin(tilt) * d.x + cos(tilt) * d.y);
		vec2 q = (uv - look) / slit;
		float e = dot(q, q);
		// the pupil and a ring of darker iris round it, pixel-sharp
		if (e < 1.0) c.rgb = pupil_col;
		else if (e < 1.0 + 3.2 / max(slit.y, 1.0)) c.rgb = mix(c.rgb, ring_col, 0.7);
		if (lid > 0.005) {
			// the eyeball's own half height at this point along it, a little more so an open lid is out of sight
			float half_u = max(ball_h.x, ball_h.y) * 1.08;
			float ev = max(ball_h.x, ball_h.y) * 1.1 * sqrt(max(0.0, 1.0 - (uv.x * uv.x) / (half_u * half_u)));
			// they meet a little below the middle: the upper lid travels further
			float meet = ev * 0.25;
			float top = mix(-ev - 1.0, meet, lid);
			float bot = mix(ev + 1.0, meet, lid);
			if (uv.y < top) {
				float k = clamp((top - uv.y) / max(ev, 1.0), 0.0, 1.0);
				c.rgb = uv.y > top - 1.0 ? lid_line : mix(lid_mid, lid_light, smoothstep(0.1, 0.8, k));
			} else if (uv.y > bot) {
				float k = clamp((uv.y - bot) / max(ev, 1.0), 0.0, 1.0);
				c.rgb = uv.y < bot + 1.0 ? lid_line : mix(lid_mid * 0.85, lid_mid, smoothstep(0.1, 0.8, k));
			} else if (uv.y < top + 2.5) {
				// the upper lid's shadow on the eyeball
				c.rgb *= 0.55;
			}
		}
	}
	COLOR = c * tint;
}
