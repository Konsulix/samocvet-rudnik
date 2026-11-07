// A flame on a skull (SpecSkullFx): Yaga's fire filling an eye socket, a candle's flame. A quad always facing the
// viewer, the flame drawn in it: a tongue licking upward, its edge torn by rising turbulence, a hot pale core, the tip
// fading to smoke; mode 1 — a soft round glow (an eye that watches, the light round a flame).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
#include "res://shaders/opal.gdshaderinc"

uniform vec3 col : source_color = vec3(0.35, 1.0, 0.4);
uniform float seed = 0.0;
uniform float speed = 1.0;
uniform int mode = 0;
uniform float power = 1.0;

void vertex() {
	// always facing the viewer, at the node's own scale
	float sc = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * sc, INV_VIEW_MATRIX[1] * sc, INV_VIEW_MATRIX[2] * sc, MODEL_MATRIX[3]);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float t = TIME * speed;
	if (mode == 1) {
		float d = length(p);
		float a = pow(max(0.0, 1.0 - d), 2.2) * (0.85 + 0.15 * sin(t * 3.0 + seed));
		ALBEDO = col * a * power;
		ALPHA = a;
	} else {
		float v = 1.0 - UV.y;   // 0 at the root .. 1 at the tip
		float x = p.x;
		// the tongue sways and is torn by turbulence rising through it
		x += (vn(vec3(v * 2.5 - t * 1.8, seed, 0.0)) - 0.5) * 0.5 * v;
		float n = fbm(vec3(p.x * 3.0, v * 4.0 - t * 3.2, seed));
		float w = 0.62 * pow(max(0.0, 1.0 - v), 0.55) * (0.7 + 0.6 * n);
		float body = smoothstep(w, w * 0.35, abs(x)) * smoothstep(0.0, 0.08, v);
		body *= 1.0 - smoothstep(0.45, 1.0, v + (n - 0.5) * 0.6);
		float core = smoothstep(w * 0.5, 0.0, abs(x)) * (1.0 - smoothstep(0.0, 0.45, v));
		vec3 c = mix(col, vec3(1.0, 0.97, 0.9), core * 0.8) * (1.3 - v * 0.6);
		ALBEDO = c * body * power * 1.6;
		ALPHA = body;
	}
}
