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

// an opal egg broken open (SpecimenBuilder._geode): COLOR.r of the face is how far out to the rind (0 the middle,
// 1 the rind). Layers follow the rind's outline as an agate's do — milky common opal, clear opal, a band of fire,
// milk again, the core all fire — the face either polished or a conchoidal break whose ripples catch the light;
// sunk a little under the rind, darker at its edge, as into the stone's depth
uniform float egg_on = 0.0;
uniform float egg_rough = 0.0;   // 0 polished .. 1 a raw conchoidal break
uniform vec3 egg_milk : source_color = vec3(0.62, 0.62, 0.6);

varying vec3 v_op;
varying float v_u;
varying vec3 v_cam;
varying vec3 v_no;

#include "res://shaders/opal.gdshaderinc"

void vertex() {
	v_op = VERTEX;
	v_no = NORMAL;
	v_u = COLOR.r;
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
	float fire_m = 1.0;
	float milk = 0.0;
	float edge_dark = 1.0;
	if (egg_on > 0.0) {
		// the layers, by distance in from the rind (wavering, as an agate's bands do)
		float w = 1.0 - v_u + (fbm(v_op * 3.0 + seed) - 0.5) * 0.09;
		float core = smoothstep(0.52, 0.62, w);
		float ring = smoothstep(0.24, 0.27, w) * (1.0 - smoothstep(0.34, 0.37, w));
		float ring2 = smoothstep(0.43, 0.45, w) * (1.0 - smoothstep(0.47, 0.49, w)) * 0.8;
		fire_m = max(core, max(ring, ring2));
		// milky common opal next to the rind and between the fire; clear opal (dark, seen into) the rest
		milk = (1.0 - smoothstep(0.08, 0.14, w)) + smoothstep(0.37, 0.39, w) * (1.0 - smoothstep(0.42, 0.44, w));
		milk = clamp(milk * (1.0 - fire_m), 0.0, 1.0);
		edge_dark = 0.45 + 0.55 * smoothstep(0.0, 0.2, w);
		// the break's surface: shallow conchoidal scoops — ripple rings round a few centres — over a soft unevenness
		float h = 0.0;
		for (int i = 0; i < 3; i++) {
			vec3 c = vec3(h3(vec3(seed, float(i), 1.0)), h3(vec3(seed, float(i), 2.0)), 0.0) - vec3(0.5, 0.5, 0.0);
			float r = length(v_op.xy - c.xy * 0.9);
			h += sin(r * (26.0 + float(i) * 9.0) - float(i)) * exp(-r * 1.6) * 0.5;
		}
		h = (h + (fbm(v_op * 5.0 + seed) - 0.5) * 1.2) * 0.008 * mix(0.15, 1.0, egg_rough);
		nm = bump(nm, v_op, h, 1.0);
	}
	float g;
	vec3 fire = opal_harl(v_op, vm, nm, fire_h, fire_spread, seed, flow_k * TIME, fire_scale, soft, g);
	fire *= fire_m;
	g *= fire_m;
	float m = fbm(v_op * fire_scale * 0.8 + seed + 70.0);
	vec3 bc;
	if (opal_body == 1) bc = mix(lin(vec3(0.42, 0.45, 0.50)), lin(vec3(0.58, 0.60, 0.64)), m);       // milky
	else if (opal_body == 2) bc = mix(lin(vec3(0.20, 0.24, 0.28)), lin(vec3(0.40, 0.44, 0.48)), m); // crystal
	else bc = mix(lin(vec3(0.015, 0.02, 0.05)), lin(vec3(0.05, 0.08, 0.16)), m);                  // black
	// (on a light body the fire is less glowing light, more colour: it would wash the milk to white)
	float lt = opal_body == 1 ? 1.0 : 0.0;
	// (deep colour, not pastel: the fire's light kept under what the tonemap whitens)
	bc = mix(bc, lin(egg_milk) * (0.85 + 0.3 * m), milk * 0.8);
	ALBEDO = (bc * (1.0 - clamp(g * 1.4, 0.0, 0.85)) + fire * mix(0.08, 0.75, lt)) * edge_dark;
	EMISSION = fire * mix(0.85, 0.6, lt) * (1.0 + 0.5 * flow_k) * edge_dark;
	if (egg_on > 0.0) NORMAL = normalize((VIEW_MATRIX * MODEL_MATRIX * vec4(nm, 0.0)).xyz);
	ROUGHNESS = mix(0.05, 0.16, egg_rough * egg_on);
	SPECULAR = 0.5;
	CLEARCOAT = 1.0;
	CLEARCOAT_ROUGHNESS = 0.03;
	// (milky: light passes into it)
	if (opal_body == 1) BACKLIGHT = vec3(0.35);
}
