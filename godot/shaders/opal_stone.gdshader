shader_type spatial;
render_mode cull_disabled;
// Loose pieces set into wood (SpecWood driftwood):
//   mode 0 — chunks of precious opal: broken (flat conchoidal facets), clear or honey body with milky potch in
//            streaks and at the edges, its fire in depth (opal_play)
//   mode 1 — a crystal that glows from inside: amber, light welling up from a hot core through drifting clouds

#include "res://shaders/opal.gdshaderinc"

uniform int mode = 0;
uniform float seed = 0.0;
uniform int opal_body = 1;
uniform float fire_h = 0.1;
uniform float opal_spread = 0.35;
uniform float opal_scale = 4.0;
uniform vec3 glow_col : source_color = vec3(1.0, 0.55, 0.15);
uniform float flow_k = 0.0;

varying vec3 v_op;
varying vec3 v_cam;
varying vec3 v_no;

void vertex() {
	v_op = VERTEX;
	v_no = NORMAL;
	v_cam = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
}

void fragment() {
	vec3 p = v_op;
	vec3 vm = normalize(v_cam - v_op);
	// facets: the broken stone's flat faces (the face normal, not the smooth one)
	vec3 fn = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	if (dot(fn, NORMAL) < 0.0) fn = -fn;
	vec3 n = normalize(mix(NORMAL, fn, 0.7));
	float fres = pow(1.0 - clamp(dot(n, VIEW), 0.0, 1.0), 3.0);
	if (mode == 0) {
		float g;
		// broad flashes of fire in a clear body (crystal opal): soft clouds, few flakes, a few sparks
		vec3 fire = opal_play(p, vm, normalize(v_no), fire_h, opal_spread, seed, flow_k * TIME, opal_scale, 0.35, 0.4, g);
		vec3 body = opal_body_col(opal_body, p, seed);
		// light coming back out of the stone: brighter facing you, a warm glow in its depth
		float face = clamp(dot(n, VIEW), 0.0, 1.0);
		vec3 deep = body * (0.6 + 0.8 * fbm(p * 2.5 + seed + 8.0)) * (0.5 + 0.6 * face);
		// milky potch in streaks and clouds through it, thickest at the rims
		float potch = smoothstep(0.4, 0.66, fbm(p * 3.5 + seed + 3.0)) * 0.85 + fres * 0.5;
		potch = clamp(potch, 0.0, 0.9);
		vec3 milk = lin(vec3(0.86, 0.84, 0.8)) * (0.8 + 0.25 * fbm(p * 14.0));
		vec3 c = mix(deep + fire * 0.5, milk, potch);
		ALBEDO = c;
		EMISSION = (fire * 0.8 + deep * 0.12) * (1.0 - potch * 0.7) * (0.5 + flow_k * 0.4);
		ROUGHNESS = 0.06;
		CLEARCOAT = 1.0;
		CLEARCOAT_ROUGHNESS = 0.03;
		NORMAL = n;
	} else {
		// glowing crystal: dark amber skin, the light coming from inside — brightest where you look into it
		float core = fbm(p * 3.0 + vec3(0.0, TIME * 0.05, 0.0) + seed);
		float veil = fbm(p * 9.0 - vec3(TIME * 0.03, 0.0, 0.0) + seed + 4.0);
		float face = clamp(dot(n, VIEW), 0.0, 1.0);
		vec3 hot = lin(glow_col);
		vec3 c = hot * 0.25;
		ALBEDO = c;
		EMISSION = hot * (0.6 + 2.2 * smoothstep(0.35, 0.75, core)) * (0.55 + 0.45 * veil) * (0.4 + 0.8 * face)
			+ mix(hot, vec3(1.0, 0.95, 0.8), 0.5) * pow(smoothstep(0.6, 0.85, core * veil * 1.6), 2.0) * 2.0;
		ROUGHNESS = 0.08;
		CLEARCOAT = 1.0;
		CLEARCOAT_ROUGHNESS = 0.02;
		NORMAL = n;
	}
}
