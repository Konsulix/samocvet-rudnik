shader_type canvas_item;
render_mode blend_add;
// Live touches drawn over a special's sprite (a quad the sprite's size; UV as the sprite's), added on top:
//   mode 0  a fuse's spark at `at`: a flickering star whose rays turn and change length
//   mode 1  the resonator's radar at `at` (radius `rad`): a sweeping beam with a fading trail, and blips that
//           light up as the beam passes them and fade until it comes round again
// Every piece on its own rhythm, taken from where it lies.

uniform int mode = 0;
uniform vec2 at = vec2(0.5);
uniform float rad = 0.2;

varying vec2 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xy;
}

float hash(float n) { return fract(sin(n) * 43758.5453); }

void fragment() {
	float phase = wpos.x * 0.031 + wpos.y * 0.047;
	vec2 d = UV - at;
	vec3 col = vec3(0.0);
	if (mode == 0) {
		// a burning fuse: a hot core, rays flickering about it
		float r = length(d);
		float t = TIME * 9.0 + phase * 10.0;
		float flick = 0.6 + 0.4 * sin(t) * sin(t * 1.7 + 1.3);
		float ang = atan(d.y, d.x) + TIME * 3.0;
		float rays = pow(abs(sin(ang * 3.5)), 18.0) * smoothstep(0.09 * flick, 0.0, r);
		float core = smoothstep(0.035, 0.0, r) * (0.7 + 0.3 * flick);
		col = vec3(1.0, 0.7, 0.25) * (rays * 1.4 + core * 1.6);
	} else {
		float r = length(d) / rad;
		if (r < 1.0) {
			float ang = atan(-d.y, d.x);                              // screen angle, counter-clockwise
			float beam = mod(TIME * 2.2 + phase * 7.0, 6.2832);       // where the beam points now
			float behind = mod(beam - ang, 6.2832);                   // how far the beam has passed this point
			float sweep = exp(-behind * 2.4) * (0.35 + 0.65 * smoothstep(0.0, 0.25, r));
			float edge = smoothstep(0.06, 0.0, behind) * 0.9;
			col = vec3(0.25, 0.95, 1.0) * (sweep * 1.0 + edge * 1.6);
			// three blips at fixed spots, each lit when the beam crosses it
			for (int k = 0; k < 3; k++) {
				float fk = float(k);
				float ba = hash(fk * 7.1 + 1.0) * 6.2832;
				float br = 0.3 + 0.55 * hash(fk * 3.7 + 2.0);
				vec2 bp = vec2(cos(ba), -sin(ba)) * br * rad;
				float since = mod(beam - ba, 6.2832);
				float glow = exp(-since * 0.8);
				float dot_ = smoothstep(0.045 * rad / 0.2, 0.0, length(d - bp));
				col += vec3(0.5, 1.0, 1.0) * dot_ * glow * 1.6;
			}
		}
	}
	COLOR = vec4(col, 1.0);
}
