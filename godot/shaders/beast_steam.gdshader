// The beast's breath (SpecBeastFx): one mesh of soft puffs, each quad at the nose (VERTEX), its corner in UV2, its own
// phase in COLOR. Every 4 s the beast breathes out: the puffs leave in the first third of the breath one after another,
// drift out along dir, rise and swell, thin and fade; then it draws breath and none come.
shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled;
#include "res://shaders/opal.gdshaderinc"

uniform vec3 dir = vec3(0.0, 0.25, 1.0);
uniform float reach = 0.4;
uniform float size = 0.08;

varying float age;
varying vec2 cor;
varying float seed;

void vertex() {
	float ph = fract(TIME / 4.0);
	float born = COLOR.r * 0.3;
	age = (ph - born) / 0.7;
	vec3 c = VERTEX;
	float a = clamp(age, 0.0, 1.0);
	vec3 side = normalize(cross(dir, vec3(0.0, 1.0, 0.0)) + vec3(1e-4));
	c += dir * reach * (1.0 - pow(1.0 - a, 2.0)) + vec3(0.0, a * a * reach * 0.35, 0.0)
		+ side * (COLOR.g - 0.5) * reach * 0.5 * a + vec3(0.0, (COLOR.b - 0.5) * reach * 0.2 * a, 0.0);
	float sc = length(MODEL_MATRIX[0].xyz);
	vec4 vc = MODELVIEW_MATRIX * vec4(c, 1.0);
	vc.xy += UV2 * size * sc * (0.35 + 1.5 * a);
	POSITION = PROJECTION_MATRIX * vc;
	cor = UV2;
	seed = COLOR.r * 40.0 + COLOR.g * 13.0;
}

void fragment() {
	float d = length(cor);
	float n = fbm(vec3(cor * 1.6 + seed, TIME * 0.4));
	float a = smoothstep(1.0, 0.1, d + (n - 0.5) * 0.9) * (0.6 + 0.8 * fbm(vec3(cor * 3.0 + seed * 2.0, TIME * 0.6)));
	float life = step(0.0, age) * (1.0 - smoothstep(0.35, 1.0, age)) * smoothstep(0.0, 0.08, age);
	ALBEDO = vec3(0.86, 0.88, 0.9);
	ALPHA = clamp(a * life * 0.24, 0.0, 1.0);
}
