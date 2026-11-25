shader_type spatial;
// Native copper as Michigan gives it (SpecCopper): a lump under its weathered skin — velvety green malachite (some
// bluer chrysocolla), dark brown-black oxide, rusty-red cuprite, flecks of white calcite — and bright copper where the
// skin is worn through or the stone was sawn and polished.
//   COLOR.r — bare copper (1) or skin (0), decided on the CPU: the high, worn points of a float lump; its edge is made
//             ragged here
//   COLOR.g — a sawn and polished face (1): mirror copper with the grinder's fine scratches, white calcite caught in
//             it, a rind of cuprite and the green skin at its rim
//   COLOR.b — on a sawn face: how far in from its rim (0 at the rim .. 1 deep inside)
// Colours written as on screen (sRGB), lin() to linear.
#include "res://shaders/opal.gdshaderinc"
#include "res://shaders/studio.gdshaderinc"

uniform float seed = 0.0;
uniform float green_k = 1.0;    // how much of the skin is green malachite (else dark oxide)
uniform float blue_k = 0.25;    // chrysocolla's blue in the green
uniform float tarnish = 0.35;   // the bare copper browned (0 fresh rose-orange .. 1 chocolate)
uniform float calcite = 0.3;    // white calcite / quartz showing in the skin and the face
uniform float scratch = 1.0;    // the polish's fine scratches
uniform vec3 scratch_dir = vec3(1.0, 0.3, 0.0);
uniform float rind_w = 0.12;    // the cuprite rind's width on a sawn face
uniform float face_dull = 0.0;  // a softer polish (a pair of bookends: each half turned its own way to the lamps)

varying vec3 v_p;
varying vec4 v_c;

void vertex() {
	v_p = VERTEX;
	v_c = COLOR;
}

void fragment() {
	vec3 p = v_p * 3.0 + seed * 7.13;
	// fine detail fades where its cells shrink under ~2 pixels (each octave by its own frequency: one fade for all let
	// the finest noise, a cell under a pixel, shimmer as the stone turned)
	float fw = length(fwidth(p));
	float aa = smoothstep(0.2, 0.45, fw * 5.5);
	float face = step(0.5, v_c.g);
	// the skin's edge round a window: ragged, the green eaten back unevenly
	float edge_n = fbm(p * 2.3) - 0.5;
	// (its edge a pixel or so soft: a hard one stair-stepped and crawled as the stone turned)
	float bv = v_c.r + edge_n * 0.22;
	float bw = max(0.03, fwidth(bv) * 0.9);
	float bare = smoothstep(0.5 - bw, 0.5 + bw, bv);
	bare = max(bare, face);
	// ---- the skin: velvet, near black-green, the bright malachite only in grains and specks; brown and brick-red
	// patches of oxide and cuprite; a little dirty calcite
	float big = fbm(p * 0.9);
	float mid = fbm(p * 3.1 + 11.0);
	float g1 = 1.0 - smoothstep(0.2, 0.45, fw * 38.0);
	float g2 = 1.0 - smoothstep(0.2, 0.45, fw * 90.0);
	float grain = 0.5 + (vn(p * 38.0) - 0.5) * 0.6 * g1 + (vn(p * 90.0) - 0.5) * 0.4 * g2;
	float green = smoothstep(0.55 - green_k * 0.35, 0.75 - green_k * 0.35, big + (mid - 0.5) * 0.45);
	vec3 deep = mix(lin(vec3(0.02, 0.06, 0.04)), lin(vec3(0.05, 0.16, 0.1)), smoothstep(0.3, 0.8, mid));
	deep = mix(deep, lin(vec3(0.04, 0.13, 0.13)), blue_k * smoothstep(0.55, 0.8, vn(p * 1.7 + 3.0)));
	// bright malachite: grains and little clusters of them
	float spk = smoothstep(0.58, 0.78, vn(p * 5.5 + 2.0) * 0.65 + grain * 0.5);
	spk = mix(spk, 0.25, aa);
	vec3 bright = mix(lin(vec3(0.1, 0.42, 0.24)), lin(vec3(0.14, 0.48, 0.44)), blue_k * vn(p * 2.2 + 8.0));
	vec3 mal = mix(deep, bright, spk * 0.85);
	vec3 oxide = mix(lin(vec3(0.04, 0.03, 0.025)), lin(vec3(0.13, 0.07, 0.04)), mid);
	oxide = mix(oxide, lin(vec3(0.24, 0.08, 0.04)), smoothstep(0.6, 0.78, vn(p * 2.6 + 5.0)) * 0.8);   // cuprite, brick-red
	vec3 skin = mix(oxide, mal, green);
	float wht = smoothstep(0.9 - calcite * 0.05, 0.93 - calcite * 0.05, vn(p * 6.5 + 19.0)) * (0.4 + grain * 0.5);
	skin = mix(skin, lin(vec3(0.42, 0.4, 0.35)) * (0.6 + mid * 0.4), wht);
	skin *= 0.6 + grain * 0.6;
	// crumbly: dark pits in it
	float pit = smoothstep(0.74, 0.88, vn(p * 24.0)) * (1.0 - smoothstep(0.2, 0.45, fw * 24.0));
	skin *= 1.0 - pit * 0.7;
	// a dark rim of oxide where the skin meets the copper
	float rim = (1.0 - abs(bare * 2.0 - 1.0)) * (1.0 - face);
	skin = mix(skin, lin(vec3(0.03, 0.02, 0.015)), rim * 0.7);
	// ---- the copper
	vec3 cu_fresh = lin(vec3(0.93, 0.52, 0.32));
	vec3 cu_brown = lin(vec3(0.55, 0.27, 0.15));
	float tn = smoothstep(0.3, 0.75, fbm(p * 1.2 + 31.0));
	vec3 cu = mix(cu_fresh, cu_brown, clamp(tarnish * (0.4 + tn), 0.0, 1.0));
	float cu_r = mix(0.2, 0.12, face);
	// the sawn face: the grinder's scratches, calcite and spongy pits caught in it, the cuprite rind at its rim
	float h = 0.0;
	if (face > 0.5) {
		vec3 sd = normalize(scratch_dir);
		float along = dot(v_p, sd);
		vec3 q = v_p - sd * along;
		float lines = vn(vec3(q * 110.0)) * 0.7 + vn(vec3(q * 31.0)) * 0.3;
		float aal = clamp(length(fwidth(q)) * 110.0 * 0.6, 0.0, 1.0);
		lines = mix(smoothstep(0.55, 0.95, lines), 0.3, aal);
		cu = mix(cu_fresh, cu_brown, clamp(0.3 + tarnish * 0.35 * (0.4 + tn), 0.0, 1.0)) * 0.66;
		// uneven polish: dull patches, dark oxide streaks dragged along by the grinder
		float dull = smoothstep(0.45, 0.75, fbm(p * 0.8 + 23.0));
		float streak = smoothstep(0.55, 0.8, fbm(vec3(along * 1.4, dot(q, vec3(7.0, 11.0, 5.0)) * 0.9, seed)));
		cu *= (0.85 + fbm(p * 0.7 + 23.0) * 0.3) * (1.0 - streak * 0.45);
		cu = mix(cu, cu_brown * 0.7, dull * 0.35);
		// (not a perfect mirror: facing the camera it would show only the dark room behind it)
		// (and soft enough that a softbox in it does not burn the copper white)
		cu_r = 0.3 + face_dull * 0.6 + dull * 0.18 + lines * 0.1 * scratch;
		cu *= 1.0 - lines * 0.08 * scratch;
		float inc = smoothstep(0.76, 0.8, fbm(p * 1.6 + 47.0)) * calcite * 1.6;
		float dark = smoothstep(0.86, 0.92, vn(p * 4.0 + 3.0));
		float r = v_c.b + (fbm(p * 3.5 + 9.0) - 0.5) * 0.12;
		float rindc = 1.0 - smoothstep(rind_w * 0.5, rind_w, r);
		float rinds = 1.0 - smoothstep(rind_w * 0.15, rind_w * 0.45, r);
		vec3 fc = cu;
		fc = mix(fc, lin(vec3(0.24, 0.05, 0.03)), rindc * 0.9);
		fc = mix(fc, mal * 0.8, rinds);
		fc = mix(fc, lin(vec3(0.82, 0.8, 0.74)), clamp(inc, 0.0, 1.0) * (1.0 - rindc));
		fc = mix(fc, lin(vec3(0.16, 0.08, 0.05)), dark * 0.7 * (1.0 - rindc));
		float metal = 1.0 - max(max(rindc * 0.85, rinds), max(clamp(inc, 0.0, 1.0), dark * 0.7));
		ALBEDO = fc;
		METALLIC = metal;
		// (the studio's softboxes, the big one behind the camera above all: a flat polished face turned to the viewer
		// mirrored the whole panel and burnt white — where its mirror looks into a panel (the same studio the sky draws)
		// the copper is darker)
		vec3 rw = normalize((INV_VIEW_MATRIX * vec4(reflect(-VIEW, NORMAL), 0.0)).xyz);
		float pan = smoothstep(0.25, 0.9, studio(rw).r);
		ALBEDO *= mix(1.0, 0.4, pan * metal);
		ROUGHNESS = mix(0.65, cu_r, metal);
		h = (1.0 - metal) * 0.002;
		// a hand-polished face is never quite flat: a gentle wave, so a lamp's highlight runs over it as a band and does
		// not light the whole face white at once
		h += (fbm(v_p * 1.6 + seed) - 0.5) * 0.012;
		NORMAL = bump(NORMAL, VERTEX, h, 1.0);
	} else {
		// worn windows: ground flat and smooth; next to the skin's step the copper is in its shade, dull and dark
		float lip = smoothstep(0.5, 0.72, v_c.r + edge_n * 0.1);
		vec3 cw = cu * mix(0.45, 1.0, lip);
		float hs = (grain * 0.009 + spk * 0.004 + mid * 0.006 - pit * 0.006) * (1.0 - bare);
		ALBEDO = mix(skin, cw, bare);
		METALLIC = bare;
		ROUGHNESS = mix(0.9, mix(0.45, cu_r + tn * 0.1, lip), bare);
		NORMAL = bump(NORMAL, VERTEX, hs, 1.0);
	}
}

// The lamps: Lambert and GGX as Godot's own, but the highlight capped — a flat polished face catches a lamp's highlight
// over all of it at once, and uncapped that burnt the copper white
void light() {
	float nl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * nl * (1.0 / PI);
	vec3 h = normalize(VIEW + LIGHT);
	float nh = clamp(dot(NORMAL, h), 0.0, 1.0);
	float a = max(ROUGHNESS * ROUGHNESS, 0.002);
	float a2 = a * a;
	float dd = nh * nh * (a2 - 1.0) + 1.0;
	float D = a2 / (PI * dd * dd);
	float vh = clamp(dot(VIEW, h), 0.0, 1.0);
	vec3 f0 = mix(vec3(0.04), ALBEDO, METALLIC);
	vec3 F = f0 + (1.0 - f0) * pow(1.0 - vh, 5.0);
	float spec = min(D * 0.25, mix(2.2, 0.5, step(0.5, v_c.g)));   // (the polished face lower still)
	SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * nl * spec * F;
}
