shader_type canvas_item;
render_mode blend_add;
// The light of an ore-bearing stone's veins (gem_kit.py renders it as <name>_ore_glow.png, white on black),
// added over the stone and breathing: a slow swell, with a flicker running along the veins. Every stone on its
// own rhythm, taken from where it lies.

uniform vec3 tint = vec3(1.0, 0.78, 0.36);
uniform float base = 0.12;      // the glow never quite goes out
uniform float swell = 0.45;     // how bright it gets at its peak
uniform float speed = 1.6;

varying vec2 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 m = texture(TEXTURE, UV);
	float phase = wpos.x * 0.031 + wpos.y * 0.047;
	float slow = 0.5 + 0.5 * sin(TIME * speed + phase);
	// a ripple running along the stone, so the light seems to move through the veins
	float run = 0.5 + 0.5 * sin(TIME * speed * 2.3 + phase * 1.7 - (UV.x + UV.y) * 9.0);
	float k = base + swell * slow * slow * (0.55 + 0.45 * run);
	COLOR = vec4(tint * m.r * k, m.a * COLOR.a);
}
