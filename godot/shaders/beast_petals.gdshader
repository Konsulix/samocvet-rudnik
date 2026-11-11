// Blossoming horns' petals on the wind (SpecBeastFx): one mesh of quads, each born at a flower (VERTEX), its corner in
// UV2, its own phase in COLOR; each falls away from the horns, swinging and tumbling, and fades; `shed` says how many
// are falling now (a few always, a shower when the blossom drops).
shader_type spatial;
render_mode cull_disabled, shadows_disabled;

uniform vec3 col : source_color = vec3(1.0, 0.82, 0.88);
uniform vec3 col2 : source_color = vec3(0.95, 0.45, 0.62);
uniform float fall = 1.0;
uniform float shed = 0.3;

varying float life;
varying vec2 cor;
varying float tint;

void vertex() {
	float ph = COLOR.r * 6.2832;
	float f = fract(TIME * (0.12 + COLOR.g * 0.1) + COLOR.r);
	vec3 c = VERTEX;
	c += vec3(sin(f * 7.0 + ph) * 0.12 + f * 0.25 * (COLOR.b - 0.5), -f * fall, f * 0.18 + cos(f * 5.0 + ph) * 0.08);
	// a petal tumbles: its quad turned about the view's axis and squashed as it rolls
	float spin = f * 9.0 + ph;
	vec2 q = UV2 * vec2(1.0, 0.6);
	q = mat2(vec2(cos(spin), sin(spin)), vec2(-sin(spin), cos(spin))) * q;
	q.x *= 0.35 + 0.65 * abs(cos(f * 6.0 + ph));
	float sc = length(MODEL_MATRIX[0].xyz);
	vec4 vc = MODELVIEW_MATRIX * vec4(c, 1.0);
	vc.xy += q * 0.03 * sc;
	POSITION = PROJECTION_MATRIX * vc;
	cor = UV2;
	// (only `shed` of them falling at a time: the rest wait, unseen)
	life = step(COLOR.a * 0.0 + fract(COLOR.r * 7.31), shed) * smoothstep(0.0, 0.05, f) * (1.0 - smoothstep(0.75, 1.0, f));
	tint = COLOR.b;
}

void fragment() {
	// a petal: an oval with a notch at its tip
	vec2 p = cor;
	float d = length(vec2(p.x * 1.0, (p.y + 0.1) * 0.75));
	float notch = smoothstep(0.08, 0.0, abs(p.x)) * step(0.6, p.y);
	float a = smoothstep(1.0, 0.85, d) * (1.0 - notch);
	if (a * life < 0.5) discard;
	ALBEDO = mix(col, col2, tint * 0.5 + (1.0 - d) * 0.3);
	ROUGHNESS = 0.6;
	BACKLIGHT = col * 0.5;
}
