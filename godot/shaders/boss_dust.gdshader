shader_type canvas_item;
// Rock dust where the beaten boss' head hits the coils (BossView): puffs grow, drift up and out and thin away,
// drawn on the same 1-pt grid as the boss and thinned by an ordered dither, so they stay pixel art.

uniform vec2 rect_size = vec2(330.0, 220.0);   // the rect, in grid pixels
uniform vec2 origin = vec2(155.0, 121.0);      // where the head landed
uniform float age = 100.0;                      // in 1/8 s since the hit; large: nothing
uniform int count = 22;

const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
// the dust's four tones, dark to light (colour uniforms: the engine puts them in the canvas' colour space)
uniform vec4 dust0 : source_color = vec4(0.376, 0.314, 0.235, 1.0);
uniform vec4 dust1 : source_color = vec4(0.51, 0.431, 0.329, 1.0);
uniform vec4 dust2 : source_color = vec4(0.659, 0.573, 0.447, 1.0);
uniform vec4 dust3 : source_color = vec4(0.784, 0.714, 0.588, 1.0);

float h1(float n) { return fract(sin(n * 127.1) * 43758.5453); }

void fragment() {
	vec2 p = floor(UV * rect_size) + 0.5;
	ivec2 ip = ivec2(p);
	float th = (BAYER[(ip.y % 4) * 4 + (ip.x % 4)] + 0.5) / 16.0;
	vec4 col = vec4(0.0);
	for (int i = 0; i < count; i++) {
		float f = float(i) + 1.0;
		float ox = origin.x + mix(-75.0, 75.0, h1(f * 1.3));
		float oy = origin.y + mix(-6.0, 6.0, h1(f * 2.1));
		float vx = (ox - origin.x) * 0.05 + mix(-0.6, 0.6, h1(f * 3.7));
		float vy = -mix(0.4, 1.1, h1(f * 4.9));
		float r = 5.0 + age * mix(1.2, 2.0, h1(f * 5.3));
		float life = 1.0 - age / mix(16.0, 24.0, h1(f * 6.1));
		if (life <= 0.0) continue;
		vec2 c = vec2(ox + vx * age, oy + vy * age);
		float d = length(vec2(p.x - c.x, (p.y - c.y) * 1.3)) / max(r, 1.0);
		if (d < 1.0 && th < life * (1.5 - d)) {
			int shade = int(clamp((1.0 - d) * 3.0 + (p.y - c.y) / -r, 0.0, 3.0));
			col = shade == 0 ? dust0 : shade == 1 ? dust1 : shade == 2 ? dust2 : dust3;
		}
	}
	COLOR = col;
}
