// Fireflies round a skull or living in it (SpecSkullFx._fireflies): one mesh of many little quads, each vertex at its
// firefly's home (VERTEX), its corner in UV2, its own phase and pace in COLOR. Each drifts in slow loops about its home
// and blinks on and off in its own rhythm; drawn facing the viewer, a soft point of light with a warm core.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec3 col : source_color = vec3(0.75, 1.0, 0.35);
uniform float size = 0.012;
uniform float roam = 0.08;

varying float blink;
varying vec2 cor;

void vertex() {
	vec3 c = VERTEX;
	float ph = COLOR.r * 6.2832;
	float sp = 0.5 + COLOR.g;
	c += vec3(sin(TIME * 0.7 * sp + ph), sin(TIME * 0.53 * sp + ph * 1.7) * 0.6, cos(TIME * 0.61 * sp + ph * 2.3)) * roam * (0.5 + COLOR.b);
	blink = pow(0.5 + 0.5 * sin(TIME * (1.2 + COLOR.b * 2.0) + ph * 3.0), 5.0);
	float sc = length(MODEL_MATRIX[0].xyz);
	vec4 vc = MODELVIEW_MATRIX * vec4(c, 1.0);
	vc.xy += UV2 * size * sc * (0.55 + 0.6 * blink);
	POSITION = PROJECTION_MATRIX * vc;
	cor = UV2;
}

void fragment() {
	float d = length(cor);
	float a = pow(max(0.0, 1.0 - d), 2.5);
	float core = pow(max(0.0, 1.0 - d * 2.5), 2.0);
	ALBEDO = (col * a * 1.6 + vec3(1.0, 1.0, 0.85) * core) * (0.35 + blink * 1.4);
	ALPHA = a;
}
