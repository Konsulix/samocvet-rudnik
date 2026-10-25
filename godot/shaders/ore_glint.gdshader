shader_type canvas_item;
render_mode blend_add;
// The light of an ore-bearing stone (gem_kit.py renders it as <name>_<kind>_glow.png, white on black), added
// over the stone. The mine's own ore breathes: a slow swell, a flicker running along its veins. Iron (sparkle)
// flashes instead: now one cube face, now another catches the light. Every stone on its own rhythm.

uniform vec3 tint = vec3(1.0, 0.78, 0.36);
uniform float base = 0.12;      // the glow never quite goes out
uniform float swell = 0.45;     // how bright it gets at its peak
uniform float speed = 1.6;
uniform float sparkle = 0.0;    // 1: short flashes moving over the stone instead of a breath

// the stone's own number (GemNode puts it in the sprite's self_modulate.r): its rhythm and pattern stay with it
// while it falls or flies; a seed taken from the screen position made the ore jump about on a moving stone
varying float seed;

void vertex() {
	seed = COLOR.r * 61.7;
}

void fragment() {
	vec4 m = texture(TEXTURE, UV);
	float phase = seed;
	float slow = 0.5 + 0.5 * sin(TIME * speed + phase);
	// a ripple running along the stone, so the light seems to move through the veins
	float run = 0.5 + 0.5 * sin(TIME * speed * 2.3 + phase * 1.7 - (UV.x + UV.y) * 9.0);
	float k = base + swell * slow * slow * (0.55 + 0.45 * run);
	// a glint: a narrow band sweeping the stone every couple of seconds, so one cube after another flashes
	float sweep = fract(TIME * 0.45 + phase * 0.16);
	float band = 1.0 - smoothstep(0.0, 0.07, abs((UV.x * 0.6 + (1.0 - UV.y) * 0.4) - sweep * 1.6 + 0.3));
	k = mix(k, 0.35 + 1.4 * band, sparkle);
	COLOR = vec4(tint * m.r * k, m.a * COLOR.a);
}
