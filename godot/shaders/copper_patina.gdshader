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

uniform float seed = 0.0;
uniform float green_k = 1.0;    // how much of the skin is green malachite (else dark oxide)
uniform float blue_k = 0.25;    // chrysocolla's blue in the green
uniform float tarnish = 0.35;   // the bare copper browned (0 fresh rose-orange .. 1 chocolate)
uniform float calcite = 0.3;    // white calcite / quartz showing in the skin and the face
uniform float scratch = 1.0;    // the polish's fine scratches
uniform vec3 scratch_dir = vec3(1.0, 0.3, 0.0);
uniform float rind_w = 0.12;    // the cuprite rind's width on a sawn face

varying vec3 v_p;
varying vec4 v_c;

void vertex() {
	v_p = VERTEX;
	v_c = COLOR;
}

void fragment() {
	vec3 p = v_p * 3.0 + seed * 7.13;
	float aa = clamp(length(fwidth(v_p)) * 40.0, 0.0, 1.0);   // fine detail fades where it would shimmer
	float face = step(0.5, v_c.g);
	// the skin's edge round a window: ragged, the green eaten back unevenly
	float edge_n = fbm(p * 2.3) - 0.5;
	float bare = smoothstep(0.47, 0.53, v_c.r + edge_n * 0.22);
	bare = max(bare, face);
	// ---- the skin
	float big = fbm(p * 0.9);
	float mid = fbm(p * 3.1 + 11.0);
	float grain = mix(vn(p * 38.0) * 0.6 + vn(p * 90.0) * 0.4, 0.5, aa);
	float green = smoothstep(0.62 - green_k * 0.5, 0.78 - green_k * 0.5, big + (mid - 0.5) * 0.45);
	vec3 mal = mix(lin(vec3(0.03, 0.13, 0.08)), lin(vec3(0.12, 0.42, 0.25)), smoothstep(0.25, 0.85, mid * 0.6 + grain * 0.5));
	mal = mix(mal, lin(vec3(0.1, 0.38, 0.38)), blue_k * smoothstep(0.55, 0.8, vn(p * 1.7 + 3.0)));
	vec3 oxide = mix(lin(vec3(0.09, 0.06, 0.05)), lin(vec3(0.23, 0.12, 0.08)), mid);
	oxide = mix(oxide, lin(vec3(0.34, 0.1, 0.07)), smoothstep(0.62, 0.8, vn(p * 2.6 + 5.0)) * 0.7);   // cuprite red
	vec3 skin = mix(oxide, mal, green);
	float wht = smoothstep(0.84 - calcite * 0.08, 0.88 - calcite * 0.08, vn(p * 3.2 + 19.0)) * (0.5 + grain * 0.4);
	skin = mix(skin, lin(vec3(0.7, 0.68, 0.62)) * (0.7 + mid * 0.3), wht);
	skin *= 0.65 + grain * 0.55;
	// the skin is velvet, crumbly: a fine grainy relief, dark pits
	float pit = smoothstep(0.78, 0.9, mix(vn(p * 24.0), 0.0, aa));
	skin *= 1.0 - pit * 0.6;
	// a dark rim of oxide where the skin meets the copper
	float rim = (1.0 - abs(bare * 2.0 - 1.0)) * (1.0 - face);
	skin = mix(skin, lin(vec3(0.08, 0.05, 0.04)), rim * 0.6);
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
		float lines = vn(vec3(q * 260.0));
		float aal = clamp(length(fwidth(q)) * 260.0 * 0.6, 0.0, 1.0);
		lines = mix(smoothstep(0.55, 0.95, lines), 0.3, aal);
		cu = mix(cu_fresh, cu_brown, clamp(tarnish * 0.35 * (0.4 + tn), 0.0, 1.0));
		cu *= 0.8 + fbm(p * 0.7 + 23.0) * 0.4;
		// (not a perfect mirror: facing the camera it would show only the dark room behind it)
		cu_r = 0.2 + lines * 0.05 * scratch;
		cu *= 1.0 - lines * 0.03 * scratch;
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
		ROUGHNESS = mix(0.65, cu_r, metal);
		h = (1.0 - metal) * 0.002;
		NORMAL = bump(NORMAL, VERTEX, h, 1.0);
	} else {
		// worn windows: smooth, a gentle ripple of the hammering ice; the skin grainy
		float hs = (grain * 0.006 + mid * 0.004 - pit * 0.004) * (1.0 - bare) + vn(p * 6.0) * 0.0015 * bare;
		ALBEDO = mix(skin, cu, bare);
		METALLIC = bare;
		ROUGHNESS = mix(0.82, cu_r + tn * 0.08, bare);
		NORMAL = bump(NORMAL, VERTEX, hs, 1.0);
	}
}
