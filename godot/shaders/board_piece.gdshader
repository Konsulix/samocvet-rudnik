shader_type spatial;
render_mode cull_back, depth_draw_always;
// Pieces on the board, in one of three looks (style): 0 frosted glass glowing from inside,
// 1 satin (soft, matte, like glazed ceramic or honed stone), 2 polished (crisp studio reflections).
// Real lighting does most of the work; each facet keeps its own tone so the shape reads from above.

#include "res://shaders/studio.gdshaderinc"

uniform vec3 col = vec3(0.8, 0.3, 0.3);
uniform int style = 0;
varying vec3 v_op;
varying vec3 v_wp;

float h1(vec3 p) { return fract(sin(dot(p, vec3(12.9898, 78.233, 45.164))) * 43758.5453); }
float vn(vec3 x) {
	vec3 i = floor(x), f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h1(i), h1(i + vec3(1, 0, 0)), f.x), mix(h1(i + vec3(0, 1, 0)), h1(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(h1(i + vec3(0, 0, 1)), h1(i + vec3(1, 0, 1)), f.x), mix(h1(i + vec3(0, 1, 1)), h1(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	v_op = VERTEX;
	v_wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 nw = (INV_VIEW_MATRIX * vec4(n, 0.0)).xyz;
	float fr = 1.0 - abs(dot(n, VIEW));
	float top = clamp(nw.y, 0.0, 1.0);
	if (style == 0) {
		// frosted glass: a soft light glowing from the core, frosted faces, a brighter rim
		float core = 1.0 - smoothstep(0.0, 0.42, length(v_op.xz));
		vec3 iw = (INV_VIEW_MATRIX * vec4(-VIEW, 0.0)).xyz;
		float thru = dot(studio(refract(iw, nw, 0.66)), vec3(0.33));
		// see-through: the tray shows faintly through the body, the core and rim stay solid
		ALBEDO = col * 0.55;
		ROUGHNESS = 0.18;
		SPECULAR = 0.5;
		EMISSION = col * (0.04 + 0.4 * core * core + 0.12 * thru) + mix(col, vec3(1.0), 0.5) * fr * 0.12;
		ALPHA = clamp(0.55 + 0.35 * core + 0.4 * fr, 0.0, 1.0);
	} else if (style == 1) {
		// satin: matte, a fine grain, gentle light on the upper facets
		float grain = vn(v_op * 90.0) * 0.06;
		ALBEDO = col * (0.85 + grain);
		ROUGHNESS = 0.6;
		SPECULAR = 0.3;
	} else {
		// polished: deep colour, mirror-crisp reflections of the softboxes
		ALBEDO = col * 0.6;
		ROUGHNESS = 0.08;
		SPECULAR = 0.55;
		CLEARCOAT = 1.0;
		CLEARCOAT_ROUGHNESS = 0.03;
	}
}
