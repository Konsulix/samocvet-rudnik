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
	}
	NORMAL = bump(n, VERTEX, hgt * bk, 1.0);
	ALBEDO = c;
	ROUGHNESS = ro;
	SPECULAR = mix(0.3, 0.5, coat);
	CLEARCOAT = coat * 0.9;
	CLEARCOAT_ROUGHNESS = 0.05;
	EMISSION = em;
}
