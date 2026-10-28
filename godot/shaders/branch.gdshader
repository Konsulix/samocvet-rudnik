shader_type spatial;
render_mode cull_disabled;
// Branching wood (SpecBranch): UV.x = along the branch in its own thicknesses, UV.y = round it (0..1), UV2.x = its
// radius; COLOR.r = 1 on a broken end, COLOR.g = the branch's random. Modes:
//   0 opal twig  — dark bark cracked into long plates (crocodile skin) along the branch; some plates are opal, set
//                  flush between raised ridges of bark, their fire bright on a dark body
//   1 driftwood  — silver-grey weathered wood, its grain twisting round the branch in grooves, long cracks, brown in
//                  the grooves; opal chunks are separate meshes
//   2 sand crust — the sand a fulgurite fused round itself: grains, dark specks

#include "res://shaders/opal.gdshaderinc"

uniform int mode = 0;
uniform float seed = 0.0;
uniform vec3 c_bark : source_color = vec3(0.32, 0.25, 0.2);
uniform vec3 c_light : source_color = vec3(0.6, 0.55, 0.5);
uniform vec3 c_end : source_color = vec3(0.62, 0.5, 0.36);   // the broken end's fresh wood
uniform float opal_k = 0.5;         // how many of the bark's plates are opal
uniform float fire_h = 0.4;
uniform float opal_spread = 0.4;
uniform int opal_body = 0;
uniform float opal_scale = 6.0;     // the fire's scale for this piece's size
uniform float twist = 0.25;         // the grain's twist round a branch (driftwood)
uniform float flow_k = 0.0;
uniform sampler2D bark_tex : source_color, filter_linear_mipmap, repeat_enable;   // a bark scan for the twig's plates
uniform float bark_k = 0.0;
uniform float hollow_opal = 0.0;
// scans: weathered side grain (driftwood, broken ends), sand (the fulgurite's crust)
uniform sampler2D fib_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D sand_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float scan_k = 0.8;
// fulgurite: the glass lining its bore, how frothy its crust is, and a fresh strike (the glass still glowing)
uniform vec3 c_glass : source_color = vec3(0.3, 0.33, 0.3);
uniform float froth_k = 0.0;
// driftwood's life: lichen rosettes on the crests, moss in the grooves, bark beetles' galleries, the sea (bleached,
// shipworm borings), foxfire glowing in the grooves, rust running down from an iron staple (rust_p, downwards rust_dir)
uniform float lichen_k = 0.0;
uniform float moss_k = 0.0;
uniform float gall_k = 0.0;
uniform float sea_k = 0.0;
uniform float fox_k = 0.0;
uniform float rust_k = 0.0;
uniform vec3 rust_p = vec3(0.0);
uniform vec3 rust_dir = vec3(0.0, -1.0, 0.0);
uniform float hot_k = 0.0;
float lum3(vec3 c) { return dot(c, vec3(0.3, 0.5, 0.2)); }    // driftwood: its hollow packed with broken opal (1) or just rotten wood (0)

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
	float u = UV.x;
	float a = UV.y;
	float r = max(UV2.x, 1e-3);
	float rid = COLOR.g * 37.0 + seed;
	vec2 cs = vec2(cos(a * 6.2832), sin(a * 6.2832));
	vec3 vm = normalize(v_cam - v_op);
	vec3 nm = normalize(v_no);
	vec3 n = NORMAL;
	if (!FRONT_FACING) n = -n;
	vec3 c;
	float ro = 0.85;
	float hgt = 0.0;
	float coat = 0.0;
	vec3 em = vec3(0.0);
	float bk = 0.006;   // how strong the relief is

	if (COLOR.r > 0.5) {
		// a broken end: pale fibrous wood, splintery
		float fib = vn(vec3(p * 140.0)) * 0.5 + vn(vec3(p * 40.0)) * 0.5;
		c = lin(c_end) * (0.7 + 0.45 * fib);
		if (mode == 1) {
			// driftwood's torn end grain: growth rings round the middle (UV2.x is the distance from it), cracks out
			// from the pith, greyed and dirty in the grooves
			float rr = UV2.x * 60.0 + (vn(vec3(p * 12.0)) - 0.5) * 1.5;
			float ring = smoothstep(0.65, 0.95, fract(rr));
			float chk = 1.0 - smoothstep(0.0, 0.06, abs(vn(vec3(a * 7.0, rid, 2.0)) - 0.5));
			c = mix(lin(c_end), lin(c_light) * 0.9, 0.35) * (0.75 + 0.35 * fib) * (1.0 - 0.3 * ring);
			c = mix(c, lin(c_bark) * 0.25, chk * 0.8);
			hgt = fib * 0.6 + ring * 0.5 - chk * 1.5;
			if (COLOR.a > 0.9) {
				// split along the grain (a long slant): pale fresh inner wood in streaks down its length, darker fibres
				vec2 fuv = vec2(u * 0.18, a * 1.5 + rid * 0.1);
				float sg = clamp(lum3(texture(fib_tex, fuv).rgb) / max(lum3(textureLod(fib_tex, fuv, 5.0).rgb), 0.03), 0.3, 1.9);
				float streak = vn(vec3(u * 1.2, a * 24.0, rid)) * 0.55 + vn(vec3(u * 3.0, a * 70.0, rid)) * 0.3 + vn(p * 90.0) * 0.15;
				c = mix(lin(vec3(0.64, 0.56, 0.45)), lin(c_light), 0.3) * (0.62 + 0.45 * streak) * (0.8 + 0.25 * sg);
				c = mix(c, lin(c_bark) * 0.35, smoothstep(0.7, 0.9, 1.0 - streak) * 0.5);
				hgt = streak * 1.2 + sg * 0.4;
			}
			bk = 0.004 * r * 10.0;
		}
		if (mode == 2) c = lin(c_light) * (0.75 + 0.3 * fib);
		if (mode != 1) hgt = fib;
	} else if (mode == 0) {
		// plates: long cells along the branch, 7 round it; the bark between them a raised ridge
		float N = 6.0;
		vec2 q = vec2(u * 0.62 + rid, a * N);
		q += (vec2(fbm(vec3(cs * 1.5, u * 0.3 + rid)), fbm(vec3(cs * 1.5, u * 0.3 + rid + 7.0))) - 0.5) * vec2(0.45, 0.5);
		vec3 cl = vor2w(q, N);
		float wr = 0.07 + 0.12 * vn(vec3(q * 2.0, rid));
		float ridge = 1.0 - smoothstep(wr, wr + 0.06, cl.y);
		// opal plates: some stretches of a branch carry them, some none
		float stretch = smoothstep(0.38, 0.55, fbm(vec3(u * 0.12, rid, 3.0)));
		float is_opal = step(cl.z, opal_k * mix(0.35, 1.3, stretch)) * (1.0 - ridge);
		// the bark plate: dark, scaly, fine cracks across
		float grit = vn(vec3(p * 260.0)) * 0.5 + vn(vec3(p * 90.0)) * 0.5;
		float scale = fbm(vec3(q * 3.0, rid + 11.0));
		vec3 bark = lin(c_bark) * (0.6 + 0.6 * scale) * (0.8 + 0.4 * grit);
		vec3 scan = texture(bark_tex, vec2(a * 2.0, u * 0.12 + rid)).rgb;
		float sl = dot(scan, vec3(0.3, 0.5, 0.2));
		bark = mix(bark, bark * (0.4 + 1.6 * sl) , bark_k);
		bark = mix(bark, lin(c_light) * 0.8, smoothstep(0.62, 0.8, fbm(vec3(q * 1.3, rid + 5.0))) * 0.5);
		// the ridges: fibrous bark, streaked along the branch
		float fib = vn(vec3(u * 3.0, cs * 14.0 + rid)) * 0.6 + vn(vec3(u * 9.0, cs * 40.0 + rid)) * 0.4;
		vec3 rc = mix(lin(c_bark) * 0.6, lin(c_light) * 0.85, fib) * (0.75 + 0.4 * grit);
		c = mix(bark, rc, ridge);
		hgt = ridge * (1.2 + fib * 0.8) + grit * 0.4 + scale * 0.5 - is_opal * 0.6 + sl * bark_k * 1.2;
		if (is_opal > 0.0) {
			float g;
			vec3 fire = opal_play(p, vm, nm, fire_h, opal_spread, rid, flow_k * TIME, opal_scale, 1.0, 1.0, g);
			// the opal's edge, where it meets the bark, is clouded and thin
			float edge = smoothstep(wr + 0.06, wr + 0.2, cl.y);
			vec3 body = opal_body_col(opal_body, p, rid);
			c = mix(rc, body + fire * 0.6, edge);
			em += fire * edge * (0.45 + flow_k * 0.4);
			ro = 0.08;
			coat = edge;
			hgt = -0.6 + grit * 0.05;
		}
		bk = 0.004 * r * 12.0;
	} else if (mode == 1) {
		// driftwood: silver-grey weathered wood. The mesh's fibre ridges (their height in COLOR.a) get pale crests and
		// brown crevices; fine fibre lines twist with them; long cracks; grit
		float crest = COLOR.a;
		float at = a * 6.2832 + u * twist * 0.1;
		float fl = vn(vec3(cos(at) * 70.0, sin(at) * 70.0, u * 0.35 + rid)) * 0.6 + vn(vec3(cos(at) * 180.0, sin(at) * 180.0, u * 0.8 + rid)) * 0.4;
		float crack = (1.0 - smoothstep(0.0, 0.035, abs(vn(vec3(cos(at) * 9.0, sin(at) * 9.0, u * 0.05 + rid + 5.0)) - 0.5)))
			* smoothstep(0.5, 0.65, fbm(vec3(u * 0.12, cs * 0.7 + rid + 9.0)));
		float grit = vn(vec3(p * 300.0)) * 0.5 + vn(vec3(p * 80.0)) * 0.5;
		float tone = fbm(vec3(u * 0.1, cs * 0.6 + rid + 4.0));
		// the scanned grain, running along the branch and twisting with it
		vec2 fuv = vec2(u * 0.18, a * 1.5 + u * twist * 0.016 + rid * 0.1);
		float sg = clamp(lum3(texture(fib_tex, fuv).rgb) / max(lum3(textureLod(fib_tex, fuv, 5.0).rgb), 0.03), 0.3, 1.9);
		fl = mix(fl, sg * 0.5, scan_k);
		vec3 scol = texture(fib_tex, fuv).rgb;
		c = lin(c_light) * (0.7 + 0.4 * tone) * (0.85 + 0.25 * grit) * (0.75 + 0.35 * fl);
		// the scan's own silver-grey and brown, over the crests
		c = mix(c, scol * (0.75 + 0.5 * tone) * 1.15, scan_k * 0.6);
		c = mix(lin(c_bark) * (0.22 + 0.25 * fl), c, smoothstep(0.3, 0.7, crest));
		// the crests worn pale and smooth, silver
		c *= 0.85 + 0.35 * smoothstep(0.6, 0.9, crest);
		c = mix(c, lin(c_bark) * 0.2, crack);
		hgt = fl * 0.8 - crack * 2.0 + grit * 0.3;
		ro = 0.9;
		bk = 0.004 * r * 10.0;
		// down in the hollow: darker, rotten brown, soft fibres
		float hol = COLOR.b;
		float fb = vn(vec3(u * 4.0, cs * 30.0 + rid)) * 0.6 + vn(vec3(p * 120.0)) * 0.4;
		c = mix(c, lin(c_bark) * (0.35 + 0.35 * fb), smoothstep(0.1, 0.6, hol));
		hgt = mix(hgt, fb, smoothstep(0.1, 0.6, hol));
		if (hollow_opal > 0.0 && hol > 0.25) {
			// packed opal: broken pieces side by side, each a flat facet of its own tilt, dirt and wood in the gaps;
			// clear body, milky potch in clouds, its fire in depth
			vec2 fq = vec2(u * 1.3, a * 9.0);
			vec3 fc = vor2w(fq + (vec2(vn(vec3(fq * 1.5, rid)), vn(vec3(fq * 1.5, rid + 4.0))) - 0.5) * 0.5, 9.0);
			float gap = 1.0 - smoothstep(0.012, 0.035, fc.y);
			float into = smoothstep(0.25, 0.45, hol);
			vec3 tilt = vec3(h3(vec3(fc.z * 91.0, 1.0, 2.0)), h3(vec3(fc.z * 37.0, 5.0, 1.0)), h3(vec3(fc.z * 53.0, 3.0, 7.0))) - 0.5;
			vec3 fn2 = normalize(n + tilt * 1.1);
			float g;
			vec3 q3 = p + tilt * 0.3;
			vec3 fire = opal_play(q3, vm, nm, fire_h, opal_spread, rid + fc.z * 10.0, flow_k * TIME, opal_scale, 0.35, 0.4, g);
			vec3 body = opal_body_col(opal_body, q3, rid);
			float face = clamp(dot(fn2, VIEW), 0.0, 1.0);
			vec3 deep = body * (0.6 + 0.8 * fbm(q3 * 6.0 + 8.0)) * (0.5 + 0.6 * face);
			float potch = clamp(smoothstep(0.55, 0.78, fbm(q3 * 9.0 + 3.0)) * 0.45, 0.0, 0.5);
			vec3 milk = lin(vec3(0.86, 0.84, 0.8)) * (0.8 + 0.25 * fbm(q3 * 30.0));
			vec3 oc = mix(deep + fire * 0.5, milk, potch);
			float w_op = into * (1.0 - gap);
			c = mix(c, oc, w_op);
			c = mix(c, lin(c_bark) * (0.4 + 0.3 * fb), into * gap);
			em += (fire * 0.9 + deep * 0.5) * (1.0 - potch * 0.7) * w_op * (0.6 + flow_k * 0.4);
			ro = mix(ro, 0.06, w_op);
			coat = w_op;
			n = normalize(mix(n, fn2, w_op));
			hgt = mix(hgt, -gap, into);
		}
		ro = 0.9;
		bk = 0.004 * r * 10.0;
		float outer = 1.0 - smoothstep(0.05, 0.25, hol);
		// the sea: bleached silver-white, bored by shipworm — round holes lined with white shell
		if (sea_k > 0.0) {
			c = mix(c, vec3(dot(c, vec3(0.3, 0.5, 0.2))) * 1.35 + vec3(0.04, 0.04, 0.035), sea_k * 0.55);
			vec3 sw = vor2(vec2(u * 2.6, a * 26.0) + rid * 3.0);
			float on = step(1.0 - sea_k * 0.45, sw.z) * outer;
			float hole = (1.0 - smoothstep(0.09, 0.12, sw.x)) * on;
			float lip = smoothstep(0.1, 0.13, sw.x) * (1.0 - smoothstep(0.15, 0.2, sw.x)) * on;
			c = mix(c, lin(vec3(0.9, 0.88, 0.82)), lip * 0.9);
			c = mix(c, lin(c_bark) * 0.08, hole);
			hgt += lip * 0.6 - hole * 2.0;
		}
		// bark beetles: under the bark that fell, the mother gallery along the grain, the larvae's galleries out from
		// it across, wavy, widening as they grew, each ending in a pupal chamber
		if (gall_k > 0.0) {
			vec2 gq = vec2(u * 0.55, a * 5.0 + rid);
			vec2 gc = floor(gq);
			vec2 gf = fract(gq);
			float on = step(1.0 - gall_k * 0.6, h3(vec3(gc, rid + 3.0))) * outer;
			float mainl = (1.0 - smoothstep(0.018, 0.04, abs(gf.y - 0.5 + 0.04 * sin(gf.x * 8.0 + gc.x)))) * step(0.12, gf.x) * step(gf.x, 0.88);
			float lane = floor(gf.x * 11.0);
			float k = fract(gf.x * 11.0);
			float side = abs(gf.y - 0.5);
			float reach = 0.18 + 0.27 * h3(vec3(lane, gc));
			float lw = 0.06 + 0.14 * side / 0.45;
			float lar = (1.0 - smoothstep(lw * 0.5, lw, abs(k - 0.5 + 0.18 * sin(side * 25.0 + lane * 1.7))))
				* step(0.03, side) * (1.0 - smoothstep(reach - 0.02, reach, side)) * step(0.12, gf.x) * step(gf.x, 0.88);
			float pupa = (1.0 - smoothstep(0.0, 0.03, abs(side - reach) + abs(k - 0.5) * 0.15)) * step(0.12, gf.x) * step(gf.x, 0.88);
			float gal = max(mainl, max(lar, pupa)) * on;
			c = mix(c, lin(c_bark) * 0.16, gal * 0.85);
			hgt -= gal * 1.3;
		}
		// lichen: rosettes on the crests, grey-green, some bright orange (Xanthoria) with little fruiting cups
		if (lichen_k > 0.0) {
			vec3 lc = vor2(vec2(u * 0.6, a * 7.0) + rid * 7.0);
			float pick = h3(vec3(lc.z * 91.0, rid, 4.0));
			float rr = 0.22 + 0.25 * h3(vec3(lc.z * 37.0, rid, 5.0));
			float edge = rr + (vn(vec3(u * 5.0, a * 50.0, rid)) - 0.5) * 0.18;
			float on = step(1.0 - lichen_k * 0.7, pick) * smoothstep(0.3, 0.55, crest) * outer;
			float lich = (1.0 - smoothstep(edge - 0.03, edge, lc.x)) * on;
			bool orange = h3(vec3(lc.z * 13.0, rid, 6.0)) < 0.35;
			vec3 lcol = orange ? lin(vec3(0.86, 0.5, 0.12)) : lin(vec3(0.6, 0.66, 0.52));
			float lobes = 0.8 + 0.3 * vn(vec3(u * 16.0, a * 140.0, rid));
			float cups = orange ? smoothstep(0.78, 0.88, vn(vec3(u * 22.0, a * 200.0, rid + 2.0))) : 0.0;
			c = mix(c, mix(lcol * lobes, lcol * 0.55, cups), lich);
			hgt += lich * (0.5 + cups * 0.6);
			ro = mix(ro, 0.95, lich);
		}
		// moss: velvet in the grooves and low places
		if (moss_k > 0.0) {
			float mz = smoothstep(0.45, 0.62, fbm(vec3(u * 0.5, cs * 1.5 + rid + 30.0)) + (0.5 - crest) * 0.6) * moss_k * outer;
			float pile = vn(vec3(p * 260.0)) * 0.6 + vn(vec3(p * 90.0)) * 0.4;
			c = mix(c, mix(lin(vec3(0.16, 0.24, 0.07)), lin(vec3(0.36, 0.44, 0.12)), pile), mz);
			hgt += mz * pile * 0.8;
			ro = mix(ro, 1.0, mz);
		}
		// rust from an old iron staple: a stain round it and streaks run down the wood
		if (rust_k > 0.0) {
			vec3 dv = p - rust_p;
			float along = dot(dv, rust_dir);
			float perp = length(dv - rust_dir * along);
			float wob = (vn(vec3(along * 20.0, rid, 3.0)) - 0.5) * 0.03;
			float streak = step(0.0, along) * exp(-along / (0.35 * rust_k)) * (1.0 - smoothstep(0.015, 0.05 + along * 0.12, perp + wob));
			float halo = exp(-length(dv) / 0.05);
			float rs = clamp(max(streak, halo), 0.0, 1.0);
			c = mix(c, lin(vec3(0.42, 0.17, 0.05)) * (0.7 + 0.5 * vn(p * 80.0)), rs * 0.85);
		}
		// foxfire: the rotting wood's fungus glows, cold green, in the grooves and the split, breathing slowly
		if (fox_k > 0.0) {
			float low = 1.0 - smoothstep(0.3, 0.7, crest);
			float patchy = smoothstep(0.3, 0.6, fbm(vec3(u * 0.4, cs * 2.0 + rid + 50.0)));
			float breath = 0.55 + 0.45 * sin(TIME * 0.7 + u * 0.35 + a * 6.2832);
			em += vec3(0.22, 1.0, 0.5) * fox_k * (low * patchy + smoothstep(0.1, 0.5, hol) * 0.5) * breath * 2.6;
		}
	} else if (COLOR.a > 0.9) {
		// the bore's lining: smooth glass, darker the deeper (COLOR.b), with little bubbles; still glowing after a
		// fresh strike, hottest deep in
		float dp = COLOR.b;
		float bub = smoothstep(0.75, 0.9, vn(p * 220.0));
		c = lin(c_glass) * (1.0 - 0.75 * dp) * (0.85 + 0.25 * vn(p * 40.0));
		c = mix(c, lin(c_glass) * 1.6 + 0.05, bub * 0.4);
		em += vec3(1.0, 0.42, 0.1) * hot_k * (0.5 + 1.5 * dp) * (0.8 + 0.4 * vn(p * 30.0 + TIME * 0.4));
		ro = 0.05;
		coat = 1.0;
		hgt = bub * 0.3;
		bk = 0.002 * r * 10.0;
	} else {
		// where a glass stretch runs, the crust is broken away: ragged edge, a thin rim of fused grains
		float gl = COLOR.b + (vn(vec3(p * 30.0)) - 0.5) * 0.5;
		if (gl > 0.5) discard;
		// sand crust: grains of several sizes, a few dark ones
		vec3 g1 = vec3(vn(p * 700.0), vn(p * 260.0), vn(p * 90.0));
		float grit = g1.x * 0.45 + g1.y * 0.35 + g1.z * 0.2;
		// real sand, scanned, wrapped round the tube
		vec2 suv = vec2(u * 0.35, a * 0.9 + rid * 0.1);
		vec3 sc = texture(sand_tex, suv).rgb;
		grit = mix(grit, clamp(lum3(sc) / max(lum3(textureLod(sand_tex, suv, 5.0).rgb), 0.03), 0.3, 1.8) * 0.55, scan_k);
		float dark = step(0.955, h3(floor(p * 420.0) + rid)) + step(0.985, h3(floor(p * 180.0) + rid)) * 0.7;
		dark = min(dark, 1.0);
		c = lin(c_light) * (0.7 + 0.45 * grit);
		c = mix(c, lin(c_bark) * 0.4, dark * 0.85);
		c *= 0.85 + 0.3 * fbm(p * 8.0 + rid);
		hgt = grit + dark * 0.3;
		ro = 0.95;
		bk = 0.004 * r * 22.0;
		// froth: the crust half melted to a foam of glass, round pits with glassy walls
		if (froth_k > 0.0) {
			vec3 vc = vor2(vec2(u * 2.2, a * 26.0) + rid);
			float pit = (1.0 - smoothstep(0.1, 0.3, vc.x)) * step(1.0 - froth_k * 0.8, vc.z);
			float wall = smoothstep(0.25, 0.32, vc.x) * (1.0 - smoothstep(0.32, 0.42, vc.x)) * step(1.0 - froth_k * 0.8, vc.z);
			c = mix(c, lin(c_glass) * 0.35, pit * 0.85);
			c = mix(c, mix(c, lin(c_glass), 0.5), wall * 0.6);
			ro = mix(ro, 0.15, max(pit, wall));
			hgt -= pit * 1.5;
		}
		// a fresh strike: the crust still hot by the glass
		em += vec3(1.0, 0.35, 0.08) * hot_k * smoothstep(0.25, 0.5, COLOR.b) * 0.6;
	}
	NORMAL = bump(n, VERTEX, hgt * bk, 1.0);
	ALBEDO = c;
	ROUGHNESS = ro;
	SPECULAR = mix(0.3, 0.5, coat);
	CLEARCOAT = coat * 0.9;
	CLEARCOAT_ROUGHNESS = 0.05;
	EMISSION = em;
}
