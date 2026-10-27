shader_type spatial;
render_mode cull_disabled;
// Petrified wood (SpecWood): a solid pattern in the trunk's own space — z along the trunk, xy across it — so the
// growth rings, rays and cracks on a polished face run on into the bark and the break.
// Per vertex: UV.x = the trunk's outline radius there (rings follow the outline), UV.y = its bark's thickness (0 where
// the bark is gone), COLOR.r = polish (1 polished, ~0.3 sawn, 0 broken or bark), COLOR.b = depth in the hollow heart.

uniform vec3 c_early : source_color = vec3(0.7, 0.45, 0.25);
uniform vec3 c_late : source_color = vec3(0.35, 0.15, 0.1);
uniform vec3 c_st1 : source_color = vec3(0.85, 0.7, 0.3);
uniform vec3 c_st2 : source_color = vec3(0.4, 0.25, 0.4);
uniform vec3 c_bark : source_color = vec3(0.2, 0.15, 0.12);
uniform float rings_n = 30.0;
uniform vec2 ecc = vec2(0.0);       // the pith, off the middle
uniform float seed = 0.0;
uniform vec4 ck[6];                 // radial cracks: angle, depth from the rim (share of the radius), width at the rim, seed
uniform int ck_n = 0;
uniform int ck_fill = 0;            // 0 open, 1 quartz, 2 opal
uniform float opal_k = 0.0;         // how much of the wood is opal
uniform float fire_h = 0.3;         // the opal's main colour on the wheel
uniform vec3 heart_col : source_color = vec3(0.6, 0.4, 0.8);
uniform float heart_r = 0.0;       // the hollow heart round the pith (0: none); its rim's lobes, as SpecWood._heart_r
uniform float heart_s = 0.0;
uniform float flow_k = 0.0;         // the legendary dragon fire: the opal's colours flow
uniform sampler2D bark_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float bark_k = 0.0;

uniform int opal_body = 0;          // 0 dark, 1 crystal, 2 honey
uniform float opal_spread = 0.3;    // how far its colours stray from fire_h

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
	vec3 p = v_op;
	float R = max(UV.x, 1e-3);
	float bt = UV.y;
	float rl = length(p.xy);
	float rel = rl / R;
	float ga = atan(p.y, p.x);
	// rings: about the pith, which slides to the outline's middle towards the bark, so the outer rings follow it
	vec2 q = p.xy - ecc * (1.0 - clamp(rel, 0.0, 1.0));
	float phi = atan(q.y, q.x);
	vec3 dir = vec3(cos(phi), sin(phi), p.z * 0.6);
	float u = length(q) / R;
	vec2 cs = vec2(cos(phi), sin(phi));
	float wob = (fbm(dir * 1.6 + seed) - 0.5) * 0.09 + (vn(vec3(cs * 4.0, p.z * 2.0 + seed + 3.0)) - 0.5) * 0.025;
	float x = (u + wob) * rings_n;
	// some years wide, some narrow
	x += (fbm(vec3(x * 0.13, seed, 1.0)) - 0.5) * 3.0;
	float f = fract(x);
	float yr = floor(x);
	// earlywood light, darkening through the year to a thin dark latewood line, then light again
	float late = pow(f, 3.0) * (1.0 - smoothstep(0.94, 1.0, f));
	float aa = clamp(fwidth(x) * 1.2, 0.0, 1.0);
	late = mix(late, 0.28, aa);
	float yv = h3(vec3(yr, seed, 5.0));
	vec3 early = lin(c_early) * (0.8 + 0.4 * yv);
	vec3 c = mix(early, lin(c_late) * 0.6, late * 0.95);
	// the minerals that stained it: big blotches across the rings, partly following them
	float st = fbm(p * 1.3 + seed) * 0.65 + vn(vec3(x * 0.11, cs * 0.6 + seed + 9.0)) * 0.35;
	float st2 = fbm(p * 2.4 + seed + 11.0) * 0.7 + vn(vec3(x * 0.2, p.z, seed + 2.0)) * 0.3;
	c = mix(c, lin(c_st1) * (0.8 + 0.4 * (1.0 - late)), smoothstep(0.48, 0.66, st) * 0.85);
	c = mix(c, lin(c_st2) * (0.7 + 0.3 * (1.0 - late)), smoothstep(0.52, 0.7, st2) * 0.8);
	// manganese: black specks and smudges; chalcedony: milky, greyer zones where the colour thinned out
	float mn = fbm(p * 5.0 + seed + 17.0);
	c *= 1.0 - smoothstep(0.6, 0.72, mn) * 0.75;
	float milk = smoothstep(0.55, 0.72, fbm(p * 1.8 + seed + 23.0));
	float lum = dot(c, vec3(0.3, 0.5, 0.2));
	c = mix(c, vec3(lum) * 1.15 + 0.03, milk * 0.5);
	// not as saturated as paint: stone
	c = mix(vec3(dot(c, vec3(0.3, 0.5, 0.2))), c, 0.8);
	// the cells: fine dots across the grain, fine streaks along it; rays: short light lines out from the pith
	float cell = vn(vec3(p.xy * 150.0, p.z * 9.0));
	float ray = smoothstep(0.72, 0.9, vn(vec3(cs * R * 9.0, u * 7.0 + p.z * 6.0 + seed)));
	c *= 0.88 + 0.22 * cell;
	c = mix(c, lin(c_st1), ray * 0.25 * (1.0 - aa));
	float ro = 0.6;
	float hgt = late * 0.3 + cell * 0.15;   // relief where it is not polished
	float metal = 0.0;
	vec3 em = vec3(0.0);
	float coat = 0.0;

	// opal in place of the wood: the wood broken into chunks, opal filling the gaps between them — narrow seams when
	// there is little, wide pools with whole chunks gone to opal when there is much. Where wood meets opal, a dark rim
	float bk = step(1.0 - bt, rel) * step(0.002, bt);
	vec3 vm = normalize(v_cam - v_op);
	vec3 nm = normalize(v_no);
	float fr = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float om = 0.0;
	vec3 opal_c = vec3(0.0);
	float opal_g = 0.0;
	float relief = 0.0;
	if (opal_k > 0.0) {
		// where opal took the wood: (a) shakes — the wood split along a few of its growth rings, opal in long arcs;
		// (b) splits running in from the rim and out from the heart; (c) pools where the wood rotted away, mostly
		// in the outer wood. Each is measured twice, the second time wider: the band between is the wood's edge,
		// browned and worn, standing a little proud of the polished opal
		float o1 = 0.0, o2 = 0.0;
		for (int k = 0; k < 3; k++) {
			float fk = float(k);
			float rk = 0.32 + 0.2 * fk + (h3(vec3(fk, seed, 8.0)) - 0.5) * 0.12;
			float wob2 = (fbm(vec3(cs * 2.0, p.z * 0.5 + seed + fk * 5.0)) - 0.5) * 0.14;
			float dist = abs(u + wob2 - rk);
			float arc = smoothstep(0.4, 0.55, vn(vec3(cs * 1.6 + fk * 3.0, p.z * 0.5 + seed)));
			float w = opal_k * 0.1 * (0.25 + 1.3 * fbm(vec3(cs * 4.0, fk + seed))) * arc;
			o1 = max(o1, 1.0 - smoothstep(w * 0.6, w + 0.003, dist));
			o2 = max(o2, (1.0 - smoothstep(w + 0.01, w + 0.035, dist)) * step(0.001, arc));
		}
		for (int k = 0; k < 5; k++) {
			float fk = float(k);
			float ak = h3(vec3(fk, seed, 11.0)) * 6.2832 + (vn(vec3(u * 4.0, fk, seed)) - 0.5) * 0.5;
			float fromrim = step(0.5, h3(vec3(fk, seed, 12.0)));
			float reach = 0.3 + 0.5 * h3(vec3(fk, seed, 13.0));
			float along = fromrim > 0.5 ? smoothstep(1.0 - reach, 1.0 - reach + 0.15, u) : 1.0 - smoothstep(reach - 0.15, reach, u);
			float da = abs(mod(phi - ak + 3.14159, 6.28318) - 3.14159) * max(u, 0.05);
			float w = opal_k * 0.05 * (fromrim > 0.5 ? u : 1.0 - u * 0.7) * along;
			o1 = max(o1, 1.0 - smoothstep(w * 0.6, w + 0.003, da));
			o2 = max(o2, (1.0 - smoothstep(w + 0.01, w + 0.035, da)) * step(0.001, along));
		}
		// pools gather on one side, where the log lay in the wet
		vec2 side = vec2(cos(seed * 3.7), sin(seed * 3.7));
		float pn = fbm(vec3(cs * 1.3, u * 2.5 + p.z * 0.3) + seed + 40.0) + u * 0.12 + dot(cs, side) * u * 0.16;
		float th = 0.8 - opal_k * 0.28;
		o1 = max(o1, smoothstep(th, th + 0.012, pn));
		o2 = max(o2, smoothstep(th - 0.03, th - 0.01, pn));
		om = o1 * (1.0 - bk);
		float rim = clamp(o2 - o1, 0.0, 1.0) * (1.0 - bk);
		// the edge: browned, the rings showing darker in it
		c = mix(c, mix(lin(c_late) * 0.45, lin(c_st2) * 0.5, 0.4) * (0.7 + 0.5 * late), rim * 0.85);
		relief = (1.0 - om) * 0.8 + rim * 0.4;
		if (om > 0.0) {
			opal_c = opal_play(p, vm, nm, fire_h, opal_spread, seed, flow_k * TIME, 2.4, 1.0, 1.0, opal_g);
			vec3 body = opal_body_col(opal_body, p, seed);
			// on a light body the fire shows less (it is washed out by the milk), on a dark one it glows
			float on_dark = opal_body == 0 ? 1.0 : 0.4;
			c = mix(c, body + opal_c * 0.5 * on_dark, om);
			em += opal_c * om * (0.45 * on_dark + flow_k * 0.4);
			ro = mix(ro, 0.06, om);
		}
	}

	// radial cracks from the rim inward, healed with quartz or opal, or open
	float crack = 0.0, halo = 0.0, ckid = 0.0;
	for (int k = 0; k < 6; k++) {
		if (k >= ck_n) break;
		vec4 cv = ck[k];
		if (rel > 1.0 - cv.y && rel < 1.02) {
			float t = (1.0 - rel) / cv.y;
			float a = cv.x + 0.06 * sin(rel * 11.0 + cv.w) + (vn(vec3(rel * 7.0, p.z * 1.5, cv.w)) - 0.5) * 0.1;
			float da = abs(mod(ga - a + 3.14159, 6.28318) - 3.14159) * rl;
			float wd = cv.z * pow(1.0 - t, 1.3) * (0.6 + 0.8 * vn(vec3(rel * 30.0, p.z * 5.0, cv.w)));
			float cr = 1.0 - smoothstep(wd * 0.55, wd + 0.002, da);
			if (cr > crack) { crack = cr; ckid = cv.w; }
			halo = max(halo, (1.0 - smoothstep(wd, wd * 3.0 + 0.01, da)) * (1.0 - t));
		}
	}
	// the iron that seeped along a crack stains the wood beside it
	c = mix(c, lin(c_st2) * 0.6, halo * 0.35);

	// the bark: a dark band on the rim, flaky across, fissured along the trunk; a light thin line where the wood starts
	float cam = (1.0 - smoothstep(0.0, 0.006, abs(rel - (1.0 - bt)))) * step(0.002, bt);
	if (bk > 0.0) {
		// ridges and furrows running along the trunk: deep sharp-bottomed furrows (ridged noise), the ridges broken
		// across into blocks, a fine grit over all
		float fis = fbm(vec3(cs * R * 10.0, p.z * 0.8 + rel * 14.0) + seed);
		float furrow = 1.0 - smoothstep(0.0, 0.09, abs(fis - 0.5));
		float cross_ = vn(vec3(cs * R * 4.0, p.z * 7.0 + seed + 60.0));
		float ridge = (1.0 - furrow) * smoothstep(0.15, 0.3, cross_);
		float grit = vn(vec3(p.xy * 90.0, p.z * 90.0)) * 0.6 + vn(vec3(p.xy * 220.0, p.z * 220.0)) * 0.4;
		float flake = vn(vec3(cs * R * 26.0, p.z * 14.0 + rel * 60.0));
		vec3 top = mix(lin(c_bark) * 1.5, lin(vec3(0.5, 0.48, 0.44)), 0.3);
		vec3 bc = mix(lin(c_bark) * 0.3, top, ridge) * (0.75 + 0.45 * grit) * (0.9 + 0.2 * flake);
		// on the outside (not a cut face), a real bark's scan over it
		if (COLOR.g < 0.5 && bark_k > 0.0) {
			vec3 scan = texture(bark_tex, vec2(phi / 6.2832 * 4.0, p.z * 1.6 + seed)).rgb;
			float sl = dot(scan, vec3(0.3, 0.5, 0.2));
			bc = mix(bc, lin(c_bark) * (0.9 + 3.2 * sl) * mix(vec3(1.0), scan / max(sl, 0.01), 0.35), bark_k);
			ridge = mix(ridge, sl * 1.6, bark_k);
		}
		bc = mix(bc, lin(c_st1) * 0.45, smoothstep(0.62, 0.8, fbm(p * 3.0 + seed + 4.0)) * 0.35);
		c = bc;
		ro = 0.92;
		hgt = ridge * 1.2 + grit * 0.5 + flake * 0.3;
		crack = 0.0;
	}
	c = mix(c, lin(c_st1) * 1.05, cam * 0.5);
	if (COLOR.r < 0.1 && bk < 0.5 && COLOR.g < 0.5) {
		float fib = vn(vec3(p.xy * 45.0, p.z * 2.5)) * 0.6 + vn(vec3(p.xy * 110.0, p.z * 5.0)) * 0.4;
		c = mix(vec3(dot(c, vec3(0.3, 0.5, 0.2))), c, 0.6) * (0.65 + 0.35 * fib);
		hgt += fib * 1.2;
	}

	if (crack > 0.0) {
		vec3 cc;
		if (ck_fill == 1) {
			// milky white quartz, grains catching the light
			vec3 gr = vor2(vec2(ga * rl * 260.0, rel * 260.0) + ckid);
			cc = lin(vec3(0.9, 0.89, 0.86)) * (0.75 + 0.35 * gr.z) * mix(0.6, 1.0, smoothstep(0.0, 0.08, gr.y));
			ro = mix(ro, 0.2, crack);
		} else if (ck_fill == 2) {
			float fl;
			vec3 oc = opal_play(p, vm, nm, fire_h, opal_spread, seed + 4.0, flow_k * TIME, 4.0, 1.0, 1.0, fl);
			cc = opal_body_col(opal_body, p, seed) + oc * 0.75;
			em += oc * crack * (0.3 + flow_k * 0.5);
			ro = mix(ro, 0.1, crack);
		} else {
			cc = lin(c_late) * 0.08;
			ro = mix(ro, 0.95, crack);
			hgt -= crack * 1.5;
		}
		c = mix(c, cc, crack);
	}

	// the hollow heart: a rind of milky chalcedony, then a crust of little crystals going dark into the hollow
	// the heart's rim drawn exactly (the mesh's bowl only gives the depth): t < 1 inside
	float hd = COLOR.b;
	float ht = 9.0;
	if (heart_r > 0.0 && COLOR.r > 0.9) {
		vec2 hq = p.xy - ecc;
		float a = atan(hq.y, hq.x);
		ht = length(hq) / (heart_r * (1.0 + 0.12 * sin(3.0 * a + heart_s) + 0.08 * sin(5.0 * a + heart_s * 1.7) + 0.04 * sin(9.0 * a + heart_s * 2.3)));
	}
	if (ht < 1.0) {
		// the rind: bands of chalcedony round the rim, flat with the face; then the crystals going down
		float rind = smoothstep(0.84, 0.87, ht);
		vec3 cc = vor2(vec2(p.x * 140.0 + p.z * 60.0, p.y * 140.0 - p.z * 50.0));
		vec3 big = vor2(vec2(p.x * 45.0, p.y * 45.0 + p.z * 30.0));
		float sh = (0.55 + 0.45 * cc.z) * mix(0.35, 1.0, smoothstep(0.0, 0.08, cc.y)) * (0.85 + 0.3 * big.z);
		vec3 crys = lin(heart_col) * sh * mix(1.0, 0.35, smoothstep(0.3, 1.0, hd));
		vec3 rc = mix(lin(vec3(0.8, 0.78, 0.74)), lin(c_st1), 0.25) * (0.8 + 0.2 * sin(ht * 140.0)) * mix(1.0, 0.75, smoothstep(0.97, 1.0, ht));
		c = mix(crys, rc, rind);
		ro = 0.2;
		hgt = sh * (1.0 - rind) * 0.6;
	}

	float pol = COLOR.r;
	vec3 n = NORMAL;
	if (!FRONT_FACING) n = -n;
	if (pol > 0.9 && ht >= 0.86) {
		// polished: glassy, a faint relief only where the bark is
		ro = mix(ro, mix(0.3, 0.06, om), 1.0 - bk);
		coat = (1.0 - bk) * mix(0.4, 1.0, om);
		NORMAL = bump(n, VERTEX, hgt * 0.0015 * bk + relief * 0.0018, 1.0);
	} else if (ht < 0.86) {
		// the heart's crystals: each little face catching the light its own way
		NORMAL = bump(n, VERTEX, hgt * 0.004, 1.0);
	} else if (pol > 0.2 && pol < 0.9) {
		// the sawn back: matte, with the saw's faint arcs
		float saw = sin((p.x * 0.8 + p.y * 0.2 + length(p.xy - vec2(3.0, 0.0))) * 160.0) * 0.5 + 0.5;
		ro = mix(ro, 0.55, 1.0 - bk);
		NORMAL = bump(n, VERTEX, (hgt * 0.4 + saw * 0.3) * 0.002, 1.0);
	} else {
		// broken, or bark: rough relief
		float fr2 = fbm(p * 9.0 + seed) + fbm(p * 30.0) * 0.4;
		ro = max(ro, 0.55);
		NORMAL = bump(n, VERTEX, (hgt + fr2 * (1.0 - bk)) * 0.006, 1.0);
	}
	ALBEDO = c;
	SPECULAR = mix(0.5, 0.2, bk);
	ROUGHNESS = clamp(ro, 0.05, 1.0);
	METALLIC = metal;
	CLEARCOAT = coat * 0.8;
	CLEARCOAT_ROUGHNESS = 0.05;
	EMISSION = em;
}
