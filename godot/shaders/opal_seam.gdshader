shader_type spatial;
// Precious opal in its ironstone (SpecimenBuilder._opal_seam): a patch or seam of opal, its body dark, milky or
// crystal, and the play of colour of the generator's own opal (opal.gdshaderinc) — soft drifting clouds of colour,
// harlequin flakes and pinfire, sliding over each other as the stone turns. Polished glassy.

uniform int opal_body = 0;     // 0 black, 1 white, 2 crystal
uniform float fire_h = 0.4;    // the main colour of its fire (0 red .. 1 violet)
uniform float fire_spread = 0.45;
uniform float fire_scale = 4.0;
uniform float seed = 0.0;
uniform float flow_k = 0.0;    // a legendary opal's colours flow

varying vec3 v_op;
varying vec3 v_cam;
varying vec3 v_no;

#include "res://shaders/opal.gdshaderinc"

void vertex() {
	v_op = VERTEX;
	v_no = NORMAL;
	v_cam = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
}

void fragment() {
	vec3 vm = normalize(v_cam - v_op);
	vec3 nm = normalize(v_no);
	float g;
	vec3 fire = opal_play(v_op, vm, nm, fire_h, fire_spread, seed, flow_k * TIME, fire_scale, 0.8, 1.0, g);
	vec3 bc = opal_body_col(opal_body, v_op * fire_scale, seed);
	// (the body only shows between the fire: a white body would wash it out)
	ALBEDO = bc * 0.45 * (1.0 - clamp(g * 1.5, 0.0, 0.8)) + fire * 0.25;
	EMISSION = fire * (1.1 + 0.5 * flow_k);
	ROUGHNESS = 0.06;
	SPECULAR = 0.5;
	CLEARCOAT = 1.0;
	CLEARCOAT_ROUGHNESS = 0.03;
}
