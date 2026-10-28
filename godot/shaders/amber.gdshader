shader_type spatial;
render_mode cull_back, depth_draw_always;
// Amber (SpecFlower): a polished pebble of clear resin. Light comes through it from behind: thin it is pale, thick
// it deepens (red, green, blue swallowed at their own rates — lemon, honey, cognac, cherry), so its rim glows bright
// and its middle burns deep. Inside, a march along the line of sight to the far side (or to what it holds — opaque,
// found by the depth buffer, so the insect shows dark against the glow): flow lines where the resin ran in layers,
// specks of bark and dust, small bubbles, milky clouds; sun spangles — flat disc cracks with radiating ridges that
// mirror the lamps in gold. The skin: polished glass-hard, or in patches a weathered crust, dull and crazed.

#include "res://shaders/opal.gdshaderinc"
#include "res://shaders/studio.gdshaderinc"

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform vec3 sigma = vec3(0.06, 0.5, 2.3);   // absorption of r, g, b per unit of the way through
uniform vec3 axes = vec3(1.0, 1.0, 0.6);      // the pebble as an ellipsoid, for the way through it
uniform float back_k = 0.85;                  // the light behind it
uniform float flow_k = 0.6;
uniform float debris_k = 0.6;
uniform float bubble_k = 0.5;
uniform float spangle_k = 0.0;
uniform float crust_k = 0.0;
uniform float cloud_k = 0.0;
uniform float dirt_k = 0.5;           // brown smoke of fine dirt
uniform float seed = 0.0;
uniform sampler2D crack_tex : source_color, filter_linear_mipmap, repeat_enable;   // a scan of crazed dry crust
uniform float crack_k = 0.0;

varying vec3 v_op;
varying vec3 v_cam;

void vertex() {
	v_op = VERTEX;
	v_cam = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
}

// where the ray leaves the ellipsoid
float exit_t(vec3 o, vec3 d) {
	vec3 oo = o / axes;
	vec3 dd = d / axes;
	float a = dot(dd, dd);
	float b = dot(oo, dd);
	float c = dot(oo, oo) - 1.0;
	float h = b * b - a * c;
	if (h < 0.0) return 0.0;
	return max(0.0, (-b + sqrt(h)) / a);
}

vec3 absorb(float t) {
	return exp(-sigma * t * 3.4);
}

void fragment() {
	vec3 n = NORMAL;
	vec3 d = normalize(v_op - v_cam);
	float ms = length(MODEL_MATRIX[0].xyz);
	float dz = textureLod(depth_tex, SCREEN_UV, 0.0).r;
	vec4 vp = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, dz, 1.0);
	vp.xyz /= vp.w;
	float t_hit = dz > 1e-6 ? distance(vp.xyz, VERTEX) / ms : 99.0;
	float chord = exit_t(v_op, d);
	bool held = t_hit < chord;
	float t_end = min(t_hit, chord);
	float rad = max(axes.x, axes.y);

	// ---- inside, front to back
	vec3 acc = vec3(0.0);
	float tr = 1.0;
	const int N = 20;
	float st = t_end / float(N);
	vec3 fdir = normalize(vec3(0.35, 1.0, 0.25) + (vec3(h3(vec3(seed)), h3(vec3(seed + 1.0)), h3(vec3(seed + 2.0))) - 0.5));
	vec3 glow = vec3(1.0, 0.82, 0.5);   // light scattered by the resin itself
	for (int i = 0; i < N; i++) {
		float t = (float(i) + 0.5) * st;
		vec3 q = (v_op + d * t) / rad;
		vec3 T = absorb(t);
		// flow lines: thin sheets where one run of resin lay over the last, wavy, in stretches
		float fb = abs(fract(dot(q, fdir) * 2.6 + fbm(q * 1.2 + seed) * 1.5) - 0.5);
		float flow = (1.0 - smoothstep(0.0, 0.035, fb)) * smoothstep(0.35, 0.65, vn(q * 1.4 + seed + 20.0)) * flow_k;
		// milky clouds (bubbles too fine to see one by one)
		float cloud = smoothstep(0.5, 0.75, fbm(q * 1.6 + seed + 40.0)) * cloud_k;
		float a = clamp(flow * 0.04 + cloud * 0.08, 0.0, 0.8);
		acc += tr * a * mix(glow, vec3(1.0, 0.95, 0.85), cloud) * T * back_k * 0.6;
		tr *= 1.0 - a;
		// brown smoke: fine organic dirt clouded round in wisps
		float dirt = smoothstep(0.58, 0.8, fbm(q * vec3(1.4, 2.2, 1.4) + seed + 90.0)) * dirt_k;
		acc += tr * dirt * 0.15 * vec3(0.12, 0.05, 0.015) * T;
		tr *= 1.0 - dirt * 0.2;
		// specks of bark and dust: in a few cells a small dark grain, some of them flakes
		vec3 cq = q * 16.0 + seed;
		vec3 cc = floor(cq);
		float hc = h3(cc + 0.7);
		if (hc > 1.0 - 0.05 * debris_k) {
			vec3 cen = cc + 0.25 + 0.5 * vec3(h3(cc + 3.1), h3(cc + 5.3), h3(cc + 7.7));
			float rr = 0.08 + 0.22 * pow(h3(cc + 9.9), 3.0);
			float sp = 1.0 - smoothstep(rr * 0.6, rr, length((cq - cen) * vec3(1.0, 1.0, 2.5)));
			acc += tr * sp * vec3(0.05, 0.025, 0.01) * T;
			tr *= 1.0 - sp * 0.92;
		}
		// bubbles: small, bright at their rims
		vec3 bq = q * 10.0 + seed + 13.0;
		vec3 bc = floor(bq);
		if (h3(bc + 1.7) > 1.0 - 0.05 * bubble_k) {
			vec3 cen = bc + 0.3 + 0.4 * vec3(h3(bc + 3.0), h3(bc + 5.0), h3(bc + 7.0));
			float rr = 0.05 + 0.14 * pow(h3(bc + 9.0), 2.0);
			float dd = length(bq - cen);
			float rim = (1.0 - smoothstep(rr * 0.75, rr, dd)) * smoothstep(rr * 0.4, rr * 0.9, dd);
			acc += tr * rim * vec3(1.0, 0.9, 0.7) * T * 0.9;
			tr *= 1.0 - rim * 0.5;
		}
	}

	// ---- sun spangles: flat disc cracks, near-parallel, each mirroring the lamps in gold; radiating ridges
	vec3 sp_c = vec3(0.0);
	float sp_a = 0.0;
	if (spangle_k > 0.0) {
		vec3 base_n = normalize(vec3(h3(vec3(seed, 1.0, 0.0)), h3(vec3(seed, 2.0, 0.0)), h3(vec3(seed, 3.0, 0.0))) - 0.5);
		vec3 wd = (INV_VIEW_MATRIX * vec4(0.0, 0.0, -1.0, 0.0)).xyz;
		for (int k = 0; k < 16; k++) {
			float fk = float(k);
			vec3 hk = vec3(h3(vec3(fk, seed, 4.0)), h3(vec3(fk, seed, 5.0)), h3(vec3(fk, seed, 6.0)));
			vec3 pn = normalize(base_n + (hk - 0.5) * 0.5);
			vec3 pc = (vec3(h3(vec3(fk, seed, 7.0)), h3(vec3(fk, seed, 8.0)), h3(vec3(fk, seed, 9.0))) - 0.5) * axes * 1.3;
			float dn = dot(pn, d);
			if (abs(dn) < 1e-3) continue;
			float tk = dot(pc - v_op, pn) / dn;
			if (tk < 0.0 || tk > t_end) continue;
			vec3 rel = v_op + d * tk - pc;
			float rk = rad * (0.03 + 0.06 * h3(vec3(fk, seed, 10.0)));
			float rr = length(rel) / rk;
			// the disc: ragged rim, ridges running out from its middle
			vec3 ax = normalize(cross(pn, abs(pn.y) < 0.9 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0)));
			float ang = atan(dot(rel, cross(pn, ax)), dot(rel, ax));
			float edge = rr + (vn(vec3(ang * 2.0, fk, seed)) - 0.5) * 0.35;
			float ins = 1.0 - smoothstep(0.85, 1.0, edge);
			if (ins <= 0.0) continue;
			float ridge = 0.55 + 0.45 * abs(sin(ang * (9.0 + fk) + vn(vec3(rr * 4.0, fk, seed)) * 2.0));
			// what the disc mirrors: the studio's lamps, seen in its own colour
			vec3 m_dir = (MODEL_MATRIX * vec4(reflect(d, dn > 0.0 ? -pn : pn), 0.0)).xyz;
			vec3 lamp = studio(normalize(m_dir));
			vec3 gold = vec3(1.0, 0.55, 0.12);
			vec3 c = gold * (0.12 + 1.6 * lamp.r * ridge) * absorb(tk);
			float ak = ins * (0.55 + 0.4 * ridge) * spangle_k;
			sp_c += (1.0 - sp_a) * ak * c;
			sp_a += (1.0 - sp_a) * ak;
		}
	}
	// hairline cracks: the rims of larger stress fractures, thin curved lines catching the light
	for (int k = 0; k < 5; k++) {
		float fk = float(k) + 20.0;
		vec3 pn = normalize(vec3(h3(vec3(fk, seed, 4.0)), h3(vec3(fk, seed, 5.0)), h3(vec3(fk, seed, 6.0))) - 0.5);
		vec3 pc = (vec3(h3(vec3(fk, seed, 7.0)), h3(vec3(fk, seed, 8.0)), h3(vec3(fk, seed, 9.0))) - 0.5) * axes;
		float dn = dot(pn, d);
		if (abs(dn) < 1e-3) continue;
		float tk = dot(pc - v_op, pn) / dn;
		if (tk < 0.0 || tk > t_end) continue;
		vec3 rel = v_op + d * tk - pc;
		float rk = rad * (0.3 + 0.4 * h3(vec3(fk, seed, 10.0)));
		float e = length(rel) / rk + (fbm(rel * 3.0 / rad + fk) - 0.5) * 0.5;
		float line = (1.0 - smoothstep(0.0, 0.012 / max(abs(dn), 0.2), abs(e - 1.0))) * step(0.35, vn(rel * 4.0 / rad + fk));
		float al = line * 0.3;
		sp_c += (1.0 - sp_a) * al * vec3(1.0, 0.85, 0.5) * absorb(tk) * 0.6;
		sp_a += (1.0 - sp_a) * al;
	}
	acc = acc * (1.0 - sp_a) + sp_c;
	tr *= 1.0 - sp_a;

	// ---- what is at the end of the way: what the stone holds, or the light behind it
	vec3 back;
	vec2 bend = n.xy * 0.04 * (1.2 - abs(dot(n, VIEW)));
	if (held) {
		back = textureLod(screen_tex, SCREEN_UV - bend, 0.0).rgb * absorb(t_hit + 0.5) * 0.3;
	} else {
		// the far side: the ray bends in at the skin, crosses, bends out again (or is turned back inside, when it
		// meets the far skin too slant) — and sees the studio's lamps, warped by the stone, dimmed by the way through
		vec3 nm = normalize((inverse(MODEL_MATRIX) * vec4((INV_VIEW_MATRIX * vec4(n, 0.0)).xyz, 0.0)).xyz);
		vec3 dn_in = refract(d, nm, 1.0 / 1.54);
		if (dot(dn_in, dn_in) < 1e-4) dn_in = d;
		float te = exit_t(v_op, dn_in);
		vec3 pe = v_op + dn_in * te;
		vec3 ne = normalize(pe / (axes * axes));
		vec3 dout = refract(dn_in, -ne, 1.54);
		float tir = 0.0;
		if (dot(dout, dout) < 1e-4) { dout = reflect(dn_in, -ne); tir = 1.0; }
		vec3 wdo = normalize((MODEL_MATRIX * vec4(dout, 0.0)).xyz);
		// the lamps a little soft: a few rays round the way out
		vec3 ta = normalize(cross(wdo, vec3(0.0, 1.0, 0.1)));
		vec3 tb = cross(wdo, ta);
		float lamp = (studio(wdo).r + studio(normalize(wdo + ta * 0.18)).r + studio(normalize(wdo - ta * 0.18)).r
			+ studio(normalize(wdo + tb * 0.18)).r + studio(normalize(wdo - tb * 0.18)).r) * 0.2;
		float way = te + tir * chord * 0.6;
		back = vec3(1.0, 0.86, 0.6) * (back_k * 0.3 + lamp * back_k * 1.0) * absorb(way) * (0.4 + 1.1 * fbm(v_op * 1.3 / rad + seed + 60.0));
	}
	vec3 body = back * tr + acc;
	// light caught inside bouncing off the far skin brightens the rim
	float cv = clamp(dot(n, VIEW), 0.0, 1.0);
	body += vec3(1.0, 0.7, 0.3) * absorb(chord * 0.5 + 0.1) * pow(1.0 - cv, 2.0) * 0.35;

	// ---- the skin
	vec3 wn = (INV_VIEW_MATRIX * vec4(n, 0.0)).xyz;
	vec3 wv = (INV_VIEW_MATRIX * vec4(-VIEW, 0.0)).xyz;
	vec3 refl = studio(reflect(wv, wn));
	float fr = 0.04 + 0.96 * pow(1.0 - cv, 5.0);
	// weathered crust in patches: dull red-brown, crazed with fine cracks, opaque where thick
	float crust = 0.0;
	vec3 crust_c = vec3(0.0);
	if (crust_k > 0.0) {
		vec3 cp = v_op / rad;
		// left on all round, but the face has been polished through it: a window with a ragged edge
		vec3 nmc = normalize((inverse(MODEL_MATRIX) * vec4((INV_VIEW_MATRIX * vec4(n, 0.0)).xyz, 0.0)).xyz);
		float cn = nmc.z - (0.4 + crust_k * 0.5) + (fbm(cp * 2.2 + seed + 70.0) - 0.5) * 0.7;
		crust = 1.0 - smoothstep(-0.02, 0.06, cn);
		vec3 cell = vor2(vec2(dot(cp, vec3(1.0, 0.2, 0.0)), dot(cp, vec3(0.0, 0.9, 0.4))) * 16.0 + seed);
		float craze = (1.0 - smoothstep(0.0, 0.04, cell.y)) * 0.7;
		if (crack_k > 0.0) {
			// the scanned crazing, seen from the side it faces most
			vec3 an = abs(nmc);
			vec2 cuv = (an.z > an.x && an.z > an.y ? cp.xy : (an.x > an.y ? cp.yz : cp.xz)) * 0.9 + seed * 0.1;
			float cl = dot(texture(crack_tex, cuv).rgb, vec3(0.3, 0.5, 0.2)) / max(dot(textureLod(crack_tex, cuv, 5.0).rgb, vec3(0.3, 0.5, 0.2)), 0.03);
			craze = mix(craze, (1.0 - smoothstep(0.55, 0.85, cl)) * 0.9, crack_k);
		}
		crust_c = mix(vec3(0.07, 0.025, 0.008), vec3(0.18, 0.07, 0.02), vn(cp * 5.0 + seed)) * (1.0 - craze * 0.6);
	}
	ALBEDO = crust_c * crust;
	EMISSION = (body + refl * fr * 1.1) * (1.0 - crust) + body * crust * 0.12;
	ROUGHNESS = mix(0.04, 0.8, crust);
	SPECULAR = mix(0.5, 0.2, crust);
}
