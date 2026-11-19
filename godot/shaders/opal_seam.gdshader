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
uniform float band_face = 0.0;   // 1: the stone broken along the seam — the opal is all the face beyond the plane
uniform vec3 band2_n = vec3(0.0, 1.0, 0.0);
uniform float band2_d = 9.0;

// an opal egg broken open (SpecimenBuilder._geode): COLOR.r of the face is how far out to the rind (0 the middle,
// 1 the rind). Layers follow the rind's outline as an agate's do — milky common opal, clear opal, a band of fire,
// milk again, the core all fire — the face either polished or a conchoidal break whose ripples catch the light;
// sunk a little under the rind, darker at its edge, as into the stone's depth
uniform float egg_on = 0.0;
uniform float egg_rough = 0.0;   // 0 polished .. 1 a raw conchoidal break
uniform vec3 egg_milk : source_color = vec3(0.62, 0.62, 0.6);
uniform float egg_pocket = 0.0;  // a pocket in its heart: COLOR.r under this is its bowl (no fire, its crystals over it)
uniform float egg_glow = 0.0;    // a light inside it: the core glows
uniform float egg_crack = 0.0;   // crazed (a careless dig): a net of fine cracks over the face
uniform float wet = 0.0;         // wetted (a tap on the card): the milk clears, the fire flares, the face goes glassy

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
		// (19.11, "just a belt": one even band round the stone) the seam swells into lenses and pinches out to
		// nothing along its way, wanders more; thin veinlets run off it through the stone, branching, and short
		// patches of opal fill cracks here and there — as a boulder opal's face shows them
		float wv = (fbm(v_op * 2.2 + seed) - 0.5) * band_w * 4.0;
		float pinch = smoothstep(0.3, 0.62, fbm(v_op * 1.3 + seed + 9.0));
		float th = band_w * (0.15 + 1.7 * pinch);
		float d1 = abs(dot(v_op, band_n) - band_d + wv);
		float d2 = abs(dot(v_op, band2_n) - band2_d + wv * 0.7);
		// the veinlets: thin crooked lines (where noise crosses its middle), only in part of the stone
		float vl = abs(fbm(v_op * 3.4 + seed + 40.0) - 0.5);
		float vk = smoothstep(0.45, 0.65, fbm(v_op * 0.9 + seed + 60.0));
		float lens = smoothstep(0.7, 0.76, fbm(v_op * 2.6 + seed + 80.0));
		if (band_face > 0.0) {
			// the broken face: opal over it, its edge ragged, islands of ironstone left in it
			float into = dot(v_op, band_n) - band_d + (fbm(v_op * 3.0 + seed) - 0.5) * band_w * 3.0;
			float isl = fbm(v_op * 4.0 + seed + 20.0);
			if (into < -band_w * 0.6 || isl > 0.68) discard;
		} else if (d1 > th && d2 > th * 0.5 && !(vl < band_w * 0.22 * vk) && lens < 0.5) discard;
	}
	vec3 vm = normalize(v_cam - v_op);
	vec3 nm = normalize(v_no);
	float fire_m = 1.0;
	float crack = 0.0;
	float milk = 0.0;
	float edge_dark = 1.0;
	if (egg_on > 0.0) {
		// the layers, by distance in from the rind (wavering, as an agate's bands do) — soft, no drawn lines: a haze
		// of common opal by the rind that the fire glows up through from deeper down, a brighter ring of fire, the
		// core all fire. (Thin bands with hard edges read as a contour map)
		float w = 1.0 - v_u + (fbm(v_op * 2.4 + seed) - 0.5) * 0.12;
		// a wide haze by the rind; then clear opal, dark, with a glowing ring of fire in it; the core all fire
		float ring = exp(-pow((w - 0.4) / 0.05, 2.0));
		fire_m = clamp(0.22 + 0.78 * smoothstep(0.54, 0.68, w) + ring * 0.85, 0.0, 1.0);
		milk = 1.0 - smoothstep(0.17, 0.3, w);
		edge_dark = 0.55 + 0.45 * smoothstep(0.0, 0.25, w);
		// wet, hydrophane opal clears: its haze goes, the fire comes up through all of it
		milk *= 1.0 - wet * 0.95;
		fire_m = mix(fire_m, 1.0, wet * 0.8);
		if (egg_pocket > 0.0) {
			float pk = 1.0 - smoothstep(egg_pocket * 0.95, egg_pocket * 1.15, v_u);
			fire_m *= 1.0 - pk;
			milk *= 1.0 - pk;
			edge_dark *= 1.0 - pk * 0.6;
		}
		// the break's surface: shallow conchoidal scoops — ripple rings round a few centres — over a soft unevenness
		// (the scoops and steps of the break are in the mesh; here only the fine ripple of a raw break)
		float h = 0.0;
		for (int i = 0; i < 3; i++) {
			vec3 c = vec3(h3(vec3(seed, float(i), 1.0)), h3(vec3(seed, float(i), 2.0)), 0.0) - vec3(0.5, 0.5, 0.0);
			float r = length(v_op.xy - c.xy * 0.9);
			h += sin(r * (40.0 + float(i) * 11.0) - float(i)) * exp(-r * 2.0) * 0.5;
		}
		h = (h + (fbm(v_op * 7.0 + seed) - 0.5)) * 0.003 * egg_rough * (1.0 - wet * 0.8);
		// a film of water over it, trembling
		h += sin(v_op.x * 60.0 + TIME * 3.0) * sin(v_op.y * 55.0 - TIME * 2.4) * 0.0005 * wet;
		if (egg_crack > 0.0) {
			// crazing: the edges of cells over the face, in patches (more of the face the worse), a dark hairline
			// with a bright lip that catches the light
			vec3 cz = vor2(v_op.xy * 11.0 + seed);
			float on = smoothstep(0.75 - egg_crack * 0.6, 0.8 - egg_crack * 0.6, fbm(v_op * 1.8 + seed + 90.0) + 0.2);
			float ln = (1.0 - smoothstep(0.0, 0.025 + egg_crack * 0.02, cz.y)) * on;
			crack = ln;
			h -= ln * 0.002;
		}
		nm = bump(nm, v_op, h, 1.0);
	}
	if (band_on > 0.0) {
		// the boulder's face is a break, not glass: a fine unevenness its glints catch on (flat, it read as soap)
		float hb = (fbm(v_op * 9.0 + seed) - 0.5) * 0.004 + (vn(v_op * 30.0 + seed) - 0.5) * 0.0012;
		nm = bump(nm, v_op, hb, 1.0);
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
	bc = mix(bc, lin(egg_milk) * (0.85 + 0.3 * m), milk * 0.85);
	ALBEDO = (bc * (1.0 - clamp(g * 1.4, 0.0, 0.85)) + fire * mix(0.08, 0.75, lt)) * edge_dark * (1.0 - crack * 0.75) + vec3(0.25) * crack * 0.3;
	fire *= 1.0 - crack * 0.8;
	EMISSION = fire * mix(0.85, 0.6, lt) * (1.0 + 0.5 * flow_k + wet * 1.1) * edge_dark;
	if (egg_on > 0.0 && wet > 0.01) {
		// water running down the face in thin rivulets, catching the light (the face's own "down": -y in its plane)
		float wob = (fbm(v_op * 4.0 + seed) - 0.5) * 0.35;
		float lane = abs(fract((v_op.x + wob) * 5.0) - 0.5);
		float lid = floor((v_op.x + wob) * 5.0);
		float run = fract(v_op.y * 1.6 + TIME * 0.7 + h3(vec3(lid, seed, 3.0)) * 7.0);
		// (a few short glistening runs, not lines over the whole face — those read as scratches)
		float riv = (1.0 - smoothstep(0.03, 0.12, lane)) * smoothstep(0.0, 0.15, run) * (1.0 - smoothstep(0.3, 0.45, run)) * step(0.45, h3(vec3(lid, seed, 9.0)));
		EMISSION += vec3(0.55, 0.62, 0.7) * riv * wet * 0.22;
	}
	if (egg_on > 0.0 && egg_glow > 0.0) {
		// the light inside: the core glows of its own, pulsing slowly
		float core = smoothstep(0.75, 0.2, v_u);
		EMISSION += (fire * 1.4 + spectral(fire_h) * 0.25) * core * egg_glow * (0.85 + 0.15 * sin(TIME * 1.3));
	}
	if (egg_on > 0.0 || band_on > 0.0) NORMAL = normalize((VIEW_MATRIX * MODEL_MATRIX * vec4(nm, 0.0)).xyz);
	ROUGHNESS = mix(mix(0.05, 0.16, egg_rough * egg_on), 0.02, wet);
	SPECULAR = 0.5;
	CLEARCOAT = 1.0;
	CLEARCOAT_ROUGHNESS = 0.03;
	// (milky: light passes into it)
	if (opal_body == 1) BACKLIGHT = vec3(0.35);
}
