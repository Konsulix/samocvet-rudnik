shader_type spatial;
// Precious opal (SpecimenBuilder._opal_seam and its kin): a seam or patch in ironstone, a black opal's polished face,
// a milky "jelly" opal — its body black, white-milky or crystal, its fire the harlequin of opal.gdshaderinc
// (opal_harl: angular patches each one colour, flashing on and off as the stone turns). Polished glassy.
// (19.11: was the soft cloud fire of opal_play, at a small scale — read as noise, "acid stickers")

uniform int opal_body = 0;     // 0 black, 1 white (milky), 2 crystal
uniform float fire_h = 0.62;   // the leading colour of its fire (0 red .. 1 violet)
uniform float fire_spread = 0.25;
uniform float fire_scale = 4.0;
uniform float soft = 0.0;      // 0 crisp harlequin .. 1 soft blobs (jelly)
uniform float seed = 0.0;
uniform float flow_k = 0.0;    // a legendary opal's colours flow
// a vein through the rock (boulder opal): this mesh is the rock's own skin, a hair outside it; only a band of it
// shows — where a wavy layer of opal (plane band_n·p = band_d, half-thick band_w, pinching and swelling) meets the
// surface — so the vein runs over the stone as it would where the stone broke across it. 0: the whole mesh
uniform float band_on = 0.0;
uniform vec3 band_n = vec3(0.0, 1.0, 0.0);
uniform float band_d = 0.0;
uniform float band_w = 0.05;
uniform vec3 band2_n = vec3(0.0, 1.0, 0.0);
uniform float band2_d = 9.0;

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
	if (band_on > 0.0) {
		float wv = (fbm(v_op * 2.2 + seed) - 0.5) * band_w * 3.0;
		float th = band_w * (0.35 + 1.1 * fbm(v_op * 1.6 + seed + 9.0));
		float d1 = abs(dot(v_op, band_n) - band_d + wv);
		float d2 = abs(dot(v_op, band2_n) - band2_d + wv * 0.7);
		if (d1 > th && d2 > th * 0.6) discard;
	}
	vec3 vm = normalize(v_cam - v_op);
	vec3 nm = normalize(v_no);
	float g;
	vec3 fire = opal_harl(v_op, vm, nm, fire_h, fire_spread, seed, flow_k * TIME, fire_scale, soft, g);
	float m = fbm(v_op * fire_scale * 0.8 + seed + 70.0);
	vec3 bc;
	if (opal_body == 1) bc = mix(lin(vec3(0.42, 0.45, 0.50)), lin(vec3(0.58, 0.60, 0.64)), m);       // milky
	else if (opal_body == 2) bc = mix(lin(vec3(0.20, 0.24, 0.28)), lin(vec3(0.40, 0.44, 0.48)), m); // crystal
	else bc = mix(lin(vec3(0.015, 0.02, 0.05)), lin(vec3(0.05, 0.08, 0.16)), m);                  // black
	// (on a light body the fire is less glowing light, more colour: it would wash the milk to white)
	float lt = opal_body == 1 ? 1.0 : 0.0;
	// (deep colour, not pastel: the fire's light kept under what the tonemap whitens)
	ALBEDO = bc * (1.0 - clamp(g * 1.4, 0.0, 0.85)) + fire * mix(0.08, 0.75, lt);
	EMISSION = fire * mix(0.85, 0.6, lt) * (1.0 + 0.5 * flow_k);
	ROUGHNESS = 0.05;
	SPECULAR = 0.5;
	CLEARCOAT = 1.0;
	CLEARCOAT_ROUGHNESS = 0.03;
	// (milky: light passes into it)
	if (opal_body == 1) BACKLIGHT = vec3(0.35);
}
