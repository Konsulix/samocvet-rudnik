// Shading for specimens, jewellery and machines. Variants are switched on with #defines
// (see SpecMat): FLAT faceted normals, TRANSP see-through, IRID oily rainbow film, growth
// striations, studio refraction and agate banding, DIRT the crystal turning into the rock it grew from.
// Vertex and per-instance colours multiply the base colour; all colours are linear.

#include "res://shaders/studio.gdshaderinc"

uniform vec3 albedo = vec3(1.0);
uniform float opacity = 1.0;
uniform float rough = 0.5;
uniform float metal = 0.0;
uniform vec3 emis = vec3(0.0);
// (21.11) a living druse (SpecView._sprout): a crystal that exists only below grow_h (its own height, object y) — it
// fills up from the rock, a front of light at the top of what has grown, the fresh glass hot below it, its open
// inside glowing like a cut through molten stone
uniform float grow_on = 0.0;
uniform float grow_h = 0.0;
uniform float grow_w = 0.05;
uniform float grow_heat = 0.0;
uniform vec3 grow_col = vec3(1.0);
uniform float grow_r = 1.0;      // its girth: a thin needle first, swelling to its full width
uniform float grow_s = 0.0;      // >0: the front is no flat cut but a point of faces — six, each its own tilt (grow_fs)
uniform float grow_fs[6];
uniform float grow_rot = 0.0;
uniform float grow_step = 0.0;   // >0: it grew in layers this high — a line of light left at each, fading as it cools
// and the rock it comes from splitting open: glowing cracks drawn in the rock itself, out from each place
// (xyz in the rock's object space, w how far they have run)
uniform int gc_n = 0;
uniform vec4 gc_p[16];
uniform vec3 gc_col = vec3(1.0);
uniform float gc_k = 0.0;
uniform float coat = 0.0;
uniform float coat_rough = 0.05;
uniform float spec = 0.5;
uniform float grain = 0.0;
uniform float ir_k = 0.0;
uniform float rf_k = 0.0;
uniform float st_k = 0.0;
uniform float st_mode = 0.0;   // striations: 0 across the crystal (quartz), 1 along it (beryl, stibnite), 2 crossed face to face (pyrite)
uniform float bd_k = 0.0;
uniform float d_h = -99.0;
uniform float d_a = 0.4;
uniform vec3 d_col = vec3(0.1);
uniform float d_lim = 0.0;   // limonite: the milky band at the crystals' foot rusted, rusty runs up them
uniform float d_fr = 0.0;
uniform float d_is = 0.0;
uniform float d_fb = 1.0;
// legendary effects, all of them alive (TIME): see SpecLegend
uniform float lava_k = 0.0;     // molten veins glowing in the rock
uniform float fluor_k = 0.0;    // every few seconds the lamps dim and the crystal glows under ultraviolet
global uniform float fluor_uv;  // 0..1, how far into the ultraviolet flash we are (driven by Spec, in step with the lamps)
uniform vec3 fluor_col = vec3(0.3, 1.0, 0.2);
uniform float cham_k = 0.0;     // colour flows with the viewing angle and breathes slowly
uniform vec3 cham_col = vec3(0.6, 0.05, 0.15);
uniform float opal_k = 0.0;     // spectral flakes flashing in the body
uniform float star_k = 0.0;
// emerald's trapiche: six dark arms from a dark hexagonal core, through the whole length of the crystal (object space,
// along y): seen as a wheel in its flat end and as dark bands through its sides. trap_r: the crystal's radius
uniform float trap_k = 0.0;
// an enhydro (19.11): a pocket of water in the crystal and its gas bubble, found by the eye's ray bent in at the face
// (object space: the pocket an ellipsoid at enh_c with radii enh_r, the bubble a sphere enh_b.xyz radius enh_b.w)
uniform float enh_k = 0.0;
uniform vec3 enh_c = vec3(0.0);
uniform vec3 enh_r = vec3(0.1);
uniform vec4 enh_b = vec4(0.0, 0.0, 0.0, 0.03);
uniform float trap_r = 0.4;
uniform float trap_a = 0.5236;
uniform float dark_k = 0.0;
uniform float tint_k = 0.0;
uniform float deep_k = 0.0;      // with tint: a deeply coloured body (dioptase, vanadinite) — what comes through it is pressed under a ceiling, so it stays see-through yet never bright enough to wash out
uniform float parts_k = 0.0;     // clarity by parts (needs DIRT: the crystal's own tag in UV2.y): one crystal cloudy beside a gem-clear one, the root milky, the tip clear
uniform float tint_glow = 0.06; // with tint: the body's own light in its colour (sulphur's lemon glow)     // the body glows in its own colour rather than showing the room through it (garnet)     // a dark glass body (smoky quartz): darker where the light goes through more of it     // a night sky inside: twinkling stars, drifting nebula
uniform float alex_k = 0.0;      // alexandrite under a lamp: 0 its daylight colour (as built), 1 turned to alex_col (SpecView tap)
uniform vec3 alex_col = vec3(0.42, 0.012, 0.09);
uniform float alex_eye = 0.0;    // chrysoberyl's cat's eye: a thin line of light across the crystal's top, sliding over it as it turns
uniform vec2 alex_ew = vec2(0.03, 0.5);   // its half-width, how far it slides (model units)
uniform float alex_p = 0.0;      // alexandrite's pleochroism: its faces by their way to the crystal's axis — the top warm orange, the sides green to violet by turns, violet at a glance
uniform float kin_k = 0.0;      // kintsugi: veins of gold with a sliding gleam
uniform sampler2D gold_diff : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D gold_nrm : filter_linear_mipmap, repeat_enable;
uniform sampler2D gold_rough : filter_linear_mipmap, repeat_enable;
// native silver edging the crests of the host rock (the "silver rim" trait), a worked-silver texture
uniform float silv_k = 0.0;
uniform vec3 silv_col = vec3(1.0);   // the metal's tint: silver as it is; gold, copper (a boss's hoard)
uniform float silv_net = 0.0;       // >0: not along the ridges but a net of thin veins through the rock (a hoard's boulder)
uniform float micro_k = 0.0;        // fine pits and bumps over the rock, on top of its scan (a hoard's boulder)
uniform float aa_k = 0.0;           // >0: detail finer than a pixel fades out instead of flickering (a hoard's boulder, 18.11)
uniform float agate_k = 0.0;        // >0: a geode's rim band round a cave in the rock's face (the hoard); vertex green marks where it may be
uniform vec2 agate_c = vec2(0.0);   // the cave's middle, in rock coordinates (x, y; the face looks along +z)
uniform float agate_r[72];          // the cave's outline radius, angle by angle
uniform float band_in = 0.8;        // the band from this many outline radii...
uniform float band_out = 1.15;      // ...to this many
uniform vec3 agate_lo = vec3(0.035, 0.04, 0.05);   // the band's dark stripes (grey chalcedony; malachite for the Mistress)
uniform vec3 agate_hi = vec3(0.17, 0.18, 0.21);    // its light stripes
uniform vec3 agate_rind = vec3(0.16, 0.12, 0.1);   // the rind line at its outer edge
uniform vec3 agate_floor = vec3(0.3, 0.29, 0.3);   // the cave's floor under the crust
uniform sampler2D silver_diff : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D silver_nrm : filter_linear_mipmap, repeat_enable;
uniform sampler2D silver_rough : filter_linear_mipmap, repeat_enable;
uniform float heart_r = 0.0;    // a throbbing core of light deep inside (object space)
uniform vec3 heart_pos = vec3(0.0);
uniform vec3 heart_col = vec3(2.0, 1.6, 1.2);
global uniform float heart_beat;  // 0..1, a lub-dub heartbeat shared with the core, its halo and its light (Spec)
uniform float oil_k = 0.0;      // dark lustrous stones: an oil-slick rainbow in their reflections
uniform float peacock_k = 0.0;  // chalcopyrite: brass tarnished like a peacock's neck, in patches and whole faces (0.5 a little of it … 1.5 nearly all)
uniform float rough_var = 0.0;  // metals: polished bumps, dull hollows
uniform float d_ao = 0.0;       // rocks: vertex colour carries the shading of pits and ridges
// photo-scanned rock, laid on from three sides (no UVs needed)
uniform sampler2D scan_diff : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D scan_nrm : filter_linear_mipmap, repeat_enable;
uniform sampler2D scan_rough : filter_linear_mipmap, repeat_enable;
uniform float scan_k = 0.0;
uniform float scan_scale = 1.3;
#ifdef GLASS
uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform float frost_k = 0.0;    // milky clouds inside the body
uniform float smoke_k = 0.0;    // smoky veils drifting through it
uniform vec3 smoke_col = vec3(0.2, 0.15, 0.1);
uniform float thick = 1.0;      // how strongly it bends what is behind
uniform float g_seed = 0.0;
uniform float rim_k = 0.0;      // frosted silver along the real edges of the faces
uniform float holo_k = 0.0;     // broad holographic sheen in patches
#endif
varying vec3 v_bary;

varying vec3 v_op;
varying float v_gd;   // a growing crystal: how far under its front (0 on the faces of growth)
varying vec3 v_rp;
varying vec3 v_no;
#ifdef DIRT
varying float v_zone;   // the crystal's own number, 0 when it has none (SpecimenBuilder._finish)
#endif

float h3(vec3 p) { p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float vn(vec3 x) {
	vec3 i = floor(x), f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h3(i), h3(i + vec3(1, 0, 0)), f.x), mix(h3(i + vec3(0, 1, 0)), h3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(h3(i + vec3(0, 0, 1)), h3(i + vec3(1, 0, 1)), f.x), mix(h3(i + vec3(0, 1, 1)), h3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
float fbm(vec3 p) { return vn(p) * 0.5 + vn(p * 2.03) * 0.25 + vn(p * 4.01) * 0.125 + vn(p * 8.02) * 0.0625; }
#ifdef GLASS
// what is behind, softened when the glass is milky
vec3 behind(vec2 uv, float r) {
	vec3 c = textureLod(screen_tex, uv, 0.0).rgb;
	if (r > 0.0004) {
		c += textureLod(screen_tex, uv + vec2(r, 0.0), 0.0).rgb + textureLod(screen_tex, uv - vec2(r, 0.0), 0.0).rgb;
		c += textureLod(screen_tex, uv + vec2(0.0, r), 0.0).rgb + textureLod(screen_tex, uv - vec2(0.0, r), 0.0).rgb;
		c += textureLod(screen_tex, uv + vec2(r, r) * 0.7, 0.0).rgb + textureLod(screen_tex, uv - vec2(r, r) * 0.7, 0.0).rgb;
		c += textureLod(screen_tex, uv + vec2(r, -r) * 0.7, 0.0).rgb + textureLod(screen_tex, uv - vec2(r, -r) * 0.7, 0.0).rgb;
		c /= 9.0;
	}
	return c;
}
#endif

void vertex() {
	if (grow_on > 0.0) {
		// a living druse's crystal grows: all of it above the front pressed down onto it — a solid stub with a flat face
		// of growth on top, the point forming as the front passes up through it (gone altogether below -999)
		float cap = grow_h;
		if (grow_s > 0.0) {
			float fm = 0.0;
			for (int i = 0; i < 6; i++) {
				float an = grow_rot + float(i) * 1.0472;
				fm = max(fm, dot(VERTEX.xz, vec2(cos(an), sin(an))) * grow_fs[i]);
			}
			cap = grow_h - grow_s * fm;
		}
		if (grow_h < -999.0) VERTEX = vec3(0.0);
		else VERTEX.y = min(VERTEX.y, cap);
		v_gd = cap - VERTEX.y;
		VERTEX.xz *= grow_r;
	}
	v_op = VERTEX;
	v_no = NORMAL;
	v_bary = CUSTOM0.xyz;
#ifdef DIRT
	v_rp = vec3(UV.x, UV.y, UV2.x);
	v_zone = UV2.y;
#endif
}

void fragment() {
	vec3 n = normalize(NORMAL);
#ifdef FLAT
	n = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	if (dot(n, VIEW) < 0.0) n = -n;
#endif
	float g_front = 0.0;
	float g_in = 0.0;
	if (grow_on > 0.0) {
		float gd = max(0.0, v_gd);
		// (the faces of growth: pressed flat, their own normals — each catches the light its own way)
		if (gd < grow_w * 0.25) {
			vec3 fc = cross(dFdx(VERTEX), dFdy(VERTEX));
			// (a squashed sliver has no face: keep its own normal, a NaN draws black)
			if (dot(fc, fc) > 1e-14) {
				vec3 fn = normalize(fc);
				if (dot(fn, VIEW) < 0.0) fn = -fn;
				n = fn;
			}
		}
		// the face of growth itself (pressed flat on the front) glows whole; just under it the fresh glass, fading down
		// (a ragged edge: the band's own width wavers)
		float gw = grow_w * (0.7 + 0.6 * fbm(v_op * 9.0 + 3.7));
		g_front = exp(-gd * gd / (gw * gw)) + exp(-gd / (grow_w * 4.0)) * 0.25;
		// (face by face: the ones turned to the eye bright, the others dimmer — the point reads as cut faces)
		if (gd < grow_w * 0.25) g_front *= 0.4 + 0.9 * pow(max(0.0, dot(n, VIEW)), 2.0);
		if (grow_step > 0.0) {
			// the layers it grew in: a thin line at each boundary, the fresh ones bright, all fading with its heat
			float lf = fract(v_op.y / grow_step + 0.5) - 0.5;
			float lw = 0.035 + 0.025 * fbm(v_op * 6.0);
			g_front += exp(-lf * lf / (lw * lw)) * (0.25 + 0.75 * exp(-gd / (grow_step * 2.0))) * grow_heat * 1.3;
		}
	}
	float g_web = 0.0;
	float g_core = 0.0;
	if (gc_n > 0) {
		// a net of thin wandering lines (the contours of noise), the finer ones weaker
		float w1 = 1.0 - smoothstep(0.0, 0.016, abs(fbm(v_op * 5.0 + 2.0) - 0.5));
		float w2 = 1.0 - smoothstep(0.0, 0.012, abs(fbm(v_op * 11.0 + 7.0) - 0.5));
		float reach = 0.0;
		float near = 0.0;
		for (int i = 0; i < 16; i++) {
			if (i >= gc_n) break;
			vec4 cp = gc_p[i];
			if (cp.w <= 0.0) continue;
			float d = length(v_op - cp.xyz) + (fbm(v_op * 4.0 + float(i)) - 0.5) * cp.w * 0.6;
			reach = max(reach, 1.0 - smoothstep(cp.w * 0.55, cp.w, d));
			near = max(near, 1.0 - smoothstep(0.0, cp.w * 0.3, d));
		}
		g_web = max(w1, w2 * 0.4 * reach) * reach * gc_k;
		g_core = near * gc_k;
	}
	vec3 base = albedo * COLOR.rgb;
	// alexandrite: lamplight turns its green to raspberry (its brightness kept: by the strongest channel)
	// (the change spreads across the stone from the lamp's side, the right of the card)
	float a_mx = max(base.r, max(base.g, base.b));
	if (alex_k > 0.0) {
		float ak = smoothstep(0.0, 1.0, alex_k * 1.8 - (1.0 - SCREEN_UV.x) * 0.8);
		base = mix(base, alex_col * (a_mx / max(max(alex_col.r, max(alex_col.g, alex_col.b)), 0.001)), ak);
	}
	vec3 a_eye = vec3(0.0);
	if (alex_eye > 0.0) {
		vec3 vm = normalize((inverse(MODEL_MATRIX) * vec4((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz, 0.0)).xyz);
		float up = smoothstep(0.25, 0.6, normalize(v_no).y);
		float d = (v_op.x + vm.x * alex_ew.y) / alex_ew.x;
		float band = exp(-d * d) * up;
		a_eye = mix(vec3(0.9, 0.85, 0.62), vec3(1.0, 0.62, 0.42), alex_k) * band * alex_eye * 1.8;
	}
	if (alex_p > 0.0) {
		vec3 nl = normalize(v_no);
		float ax = smoothstep(0.55, 0.95, abs(nl.y));
		float az = 0.5 + 0.5 * cos(atan(nl.z, nl.x) * 3.0);
		float gr = 1.0 - abs(dot(n, VIEW));
		base = mix(base, vec3(1.0, 0.5, 0.06) * a_mx, ax * 0.5 * alex_p);
		base = mix(base, vec3(0.62, 0.1, 0.75) * a_mx, (az * 0.12 + gr * 0.28) * (1.0 - ax) * alex_p);
	}
	vec3 tint0 = base;
	float a = opacity * COLOR.a;
	float r = rough;
	float m = metal;
	float cc = coat;
	float dirt = 0.0, frost = 0.0;
	float lim_s = 0.0;   // limonite rust on the crystal (d_lim), for the glass below
	vec3 lava_e = vec3(0.0);
	// ultraviolet flash: a few seconds of ordinary light, then the lamps dim and the crystal glows
	float uvk = fluor_k * fluor_uv;
	vec3 s_glow = vec3(0.0);   // the silver rim's glint (set inside DIRT, added to the emission below)
#ifdef DIRT
	// below a ragged line the crystal turns into the rock it grew from; just above it, milky and etched
	float edge = v_rp.y - (d_h + (fbm(v_rp * 4.0) - 0.47) * d_a + (fbm(v_rp * 1.7 + 3.0) - 0.5) * d_a * 0.9);
	dirt = 1.0 - smoothstep(-0.012, 0.012, edge);
	// islands of crust above the line, and windows where the crystal shows through below it
	dirt = max(dirt, smoothstep(0.64, 0.67, fbm(v_rp * 5.5 + 11.0)) * max(1.0 - smoothstep(0.0, 0.8, edge), d_is));
	dirt *= 1.0 - smoothstep(0.68, 0.71, fbm(v_rp * 6.0 + 21.0)) * smoothstep(-0.7, -0.08, edge);
	float rim = 1.0 - smoothstep(0.0, 0.05, abs(edge));
	frost = (1.0 - smoothstep(0.0, 0.3, edge)) * (1.0 - dirt) * 0.85 * d_fb;
	frost = max(frost, smoothstep(0.6, 0.72, fbm(v_rp * 2.6 + 7.0)) * d_fr);
	vec3 rk = d_col * (0.3 + 1.2 * fbm(v_rp * 26.0)) * (0.7 + 0.5 * vn(v_rp * 5.0));
	rk = mix(rk, vec3(0.3, 0.11, 0.035) * (0.6 + 0.8 * vn(v_rp * 30.0)), smoothstep(0.55, 0.8, vn(v_rp * 9.0 + 5.0)) * 0.45);
	// glittering mineral grains
	// (aa_k: how many pixels a unit of the rock spans — noise with a period under ~3 pixels fades instead of shimmering)
	float px_rp = length(fwidth(v_rp));
	float grains = smoothstep(0.86, 0.92, vn(v_rp * 70.0)) * 0.6 * mix(1.0, 1.0 - smoothstep(0.2, 0.45, px_rp * 70.0), aa_k);
	rk += vec3(0.55, 0.52, 0.48) * grains * 0.4;
	rk = mix(rk, rk * 1.7 + 0.04, rim * 0.6);
	float s_rough = 0.8;
	vec3 s_nv = n;
	if (scan_k > 0.0) {
		vec3 no = normalize(v_no);
		vec3 sp = v_rp * scan_scale;
		vec3 w = pow(abs(no), vec3(4.0));
		w /= (w.x + w.y + w.z);
		vec3 sd = texture(scan_diff, sp.zy).rgb * w.x + texture(scan_diff, sp.xz).rgb * w.y + texture(scan_diff, sp.xy).rgb * w.z;
		s_rough = texture(scan_rough, sp.zy).r * w.x + texture(scan_rough, sp.xz).r * w.y + texture(scan_rough, sp.xy).r * w.z;
		vec3 tx = texture(scan_nrm, sp.zy).xyz * 2.0 - 1.0;
		vec3 ty = texture(scan_nrm, sp.xz).xyz * 2.0 - 1.0;
		vec3 tz = texture(scan_nrm, sp.xy).xyz * 2.0 - 1.0;
		tx = vec3(tx.xy + no.zy, abs(tx.z) * no.x);
		ty = vec3(ty.xy + no.xz, abs(ty.z) * no.y);
		tz = vec3(tz.xy + no.xy, abs(tz.z) * no.z);
		vec3 ns = normalize(tx.zyx * w.x + ty.xzy * w.y + tz.xyz * w.z);
		// (20.11, "soapy rock" again and again) a detail layer: the same scan four times finer, turned, over the
		// first — close up (a card fills with a big rock) one scan texel spread over several pixels and the stone
		// went smooth as soap; the fine copy keeps grain and pits under the eye. Mipmapped: far off it averages away
		vec3 dp = v_rp * scan_scale * 4.3 + vec3(0.37, 0.71, 0.13);
		vec3 dd = texture(scan_diff, dp.zy).rgb * w.x + texture(scan_diff, dp.xz).rgb * w.y + texture(scan_diff, dp.xy).rgb * w.z;
		vec3 dx2 = texture(scan_nrm, dp.zy).xyz * 2.0 - 1.0;
		vec3 dy2 = texture(scan_nrm, dp.xz).xyz * 2.0 - 1.0;
		vec3 dz2 = texture(scan_nrm, dp.xy).xyz * 2.0 - 1.0;
		vec3 dn2 = vec3(dx2.xy, 0.0).zyx * w.x + vec3(dy2.x, 0.0, dy2.y) * w.y + vec3(dy2.xy * 0.0 + dz2.xy, 0.0) * w.z;
		ns = normalize(ns + dn2 * 0.55);
		float dl = dot(dd, vec3(0.3, 0.5, 0.2));
		sd *= 0.62 + 0.76 * dl / max(0.05, dot(sd, vec3(0.3, 0.5, 0.2)) * 0.5 + 0.25);
		s_nv = normalize((VIEW_MATRIX * MODEL_MATRIX * vec4(ns, 0.0)).xyz);
		if (dot(s_nv, VIEW) < 0.0) s_nv = -s_nv;
		// the scan gives the grain, the rock's own palette sets how dark and what colour it is
		vec3 tinted = mix(sd * 0.8, sd * d_col / 0.3, 0.75);
		tinted = pow(tinted, vec3(1.15));
		rk = mix(rk, tinted * (1.0 + rim * 0.5) + vec3(0.5, 0.48, 0.44) * grains * 0.25, scan_k);
	}
	rk *= mix(1.0, COLOR.r * 1.25, d_ao);
	if (lava_k > 0.0) {
		// molten rock: a black cooled crust split by veins of lava that throb and creep
		float hollow_r = smoothstep(0.35, 0.75, 1.0 - COLOR.r);
		float vein = 1.0 - smoothstep(0.0, 0.045, abs(fbm(v_rp * 3.2 + vec3(0.0, TIME * 0.04, 0.0)) - 0.5));
		float flow = 0.55 + 0.45 * sin(TIME * 2.2 + fbm(v_rp * 6.0 + TIME * 0.1) * 9.0);
		float heat = clamp(vein * 1.2 + hollow_r * 0.8, 0.0, 1.0) * flow;
		rk = mix(rk * 0.35, vec3(0.04, 0.02, 0.015), 0.5 * lava_k);
		lava_e = mix(vec3(2.2, 0.35, 0.03), vec3(4.0, 1.9, 0.35), heat * heat) * heat * lava_k * dirt;
	}
	vec3 f_col = vec3(0.86, 0.88, 0.9);
	if (d_lim > 0.0) {
		// limonite: the frosted foot rust-brown, and stains running up from it in streaks along the crystal
		f_col = mix(f_col, vec3(0.5, 0.2, 0.05) * (0.7 + 0.6 * fbm(v_rp * 18.0)), d_lim * 0.85);
		float stain = (1.0 - smoothstep(0.0, 0.55, edge)) * smoothstep(0.38, 0.66, fbm(v_rp * vec3(7.0, 1.3, 7.0) + 4.0)) * (1.0 - dirt);
		base = mix(base, vec3(0.42, 0.16, 0.04), stain * d_lim * 0.75);
		a = mix(a, 0.95, stain * d_lim * 0.5);
		r = mix(r, 0.6, stain * d_lim);
		lim_s = clamp(max(frost * 0.9, stain), 0.0, 1.0) * d_lim;
	}
	base = mix(base, f_col, frost * 0.5);
	a = mix(a, 0.96, frost * 0.55);
	base = mix(base, rk, dirt);
	a = mix(a, 1.0, dirt);
	r = mix(mix(r, 0.5, frost), mix(mix(0.82, 0.35, grains), s_rough, scan_k), dirt);
	float ag_on = 0.0;
	if (agate_k > 0.0) {
		// a geode's rim: pale chalcedony in fine bands round the cave, wavering, a dark rind line at its outer edge
		// the place across the band, pixel by pixel: how many outline radii out from the cave's middle
		vec2 dc = v_rp.xy - agate_c;
		float fa = mod(atan(dc.y, dc.x) / 6.2831853 * 72.0 + 72.0, 72.0);
		int b0 = int(floor(fa)) % 72;
		float rr = mix(agate_r[b0], agate_r[(b0 + 1) % 72], fract(fa));
		float t = (length(dc) / max(rr, 0.01) - band_in) / (band_out - band_in);
		ag_on = step(0.5, COLOR.g) * smoothstep(0.0, 0.04, t) * (1.0 - smoothstep(0.96, 1.0, t)) * agate_k * dirt;
		float w = t + (fbm(v_rp * 2.5 + 3.0) - 0.5) * 0.18;
		float st = 0.5 + 0.5 * sin(w * 15.0);
		float st2 = 0.5 + 0.5 * sin(w * 41.0 + 1.7);
		vec3 ag = mix(agate_lo, agate_hi, st * st);
		ag *= 0.7 + 0.45 * st2;
		ag = mix(ag, agate_hi * 1.7, smoothstep(0.92, 1.0, st) * 0.4);
		ag = mix(ag, agate_rind, smoothstep(0.8, 0.95, t));
		ag = mix(ag, agate_hi * 1.2, smoothstep(0.25, 0.0, t) * 0.6);
		base = mix(base, ag, ag_on);
		r = mix(r, 0.5, ag_on);
		// the cave's floor under its crust: milky, glittering — between the small crystals no dark rock shows
		float flo = step(0.5, COLOR.g) * (1.0 - smoothstep(-0.04, 0.02, t)) * agate_k * dirt;
		base = mix(base, agate_floor * (0.65 + 0.7 * vn(v_rp * 55.0)) * clamp(COLOR.r * 1.3, 0.35, 1.0), flo);   // (darker deeper in, as the cave's rock was)
		r = mix(r, 0.35, flo);
		ag_on = max(ag_on, flo);
	}
	m *= 1.0 - dirt;
	cc *= 1.0 - max(dirt, frost * 0.6);
	if (silv_k > 0.0) {
		// silver along the rock's ridges: vertex green carries how high a ridge stands, its contour is the rim;
		// ragged, broken in places, the worked-silver texture laid on from three sides
		float cr = COLOR.g + (fbm(v_rp * 9.0 + 4.0) - 0.5) * 0.06;
		// (wide enough and whole enough to read on a phone card)
		float sv = (1.0 - smoothstep(0.05, 0.09, abs(cr - 0.82))) * smoothstep(0.3, 0.4, vn(v_rp * 2.2 + 2.0));
		if (silv_net > 0.0) {
			// thin veins crossing the rock as a net, as quartz veins in a split boulder: the isolines of two
			// noises, a wider wandering one and finer ones branching off it, broken here and there
			float f1 = fbm(v_rp * 1.6 + 7.0) - 0.5;
			float f2 = fbm(v_rp * 3.4 + 13.0) - 0.5;
			float f3 = fbm(v_rp * 6.5 + 29.0) - 0.5;
			float v1 = 1.0 - smoothstep(0.003, 0.008, abs(f1));
			float v2 = 1.0 - smoothstep(0.002, 0.0055, abs(f2));
			float v3 = 1.0 - smoothstep(0.002, 0.006, abs(f3));
			if (aa_k > 0.0) {
				// (18.11) a vein thinner than a pixel broke into a dotted line that crawled as the rock turned: its
				// edge softened by a pixel's worth of the noise, and the vein dimmed by how much thinner than that it is
				float w1 = fwidth(f1), w2 = fwidth(f2), w3 = fwidth(f3);
				v1 = mix(v1, (1.0 - smoothstep(0.003 - w1, 0.008 + w1, abs(f1))) * min(1.0, 0.008 / max(w1 * 1.5, 1e-5)), aa_k);
				v2 = mix(v2, (1.0 - smoothstep(0.002 - w2, 0.0055 + w2, abs(f2))) * min(1.0, 0.0055 / max(w2 * 1.5, 1e-5)), aa_k);
				v3 = mix(v3, (1.0 - smoothstep(0.002 - w3, 0.006 + w3, abs(f3))) * min(1.0, 0.006 / max(w3 * 1.5, 1e-5)), aa_k);
			}
			sv = max(v1, max(v2 * smoothstep(0.45, 0.6, vn(v_rp * 3.0 + 1.0)), v3 * smoothstep(0.6, 0.72, vn(v_rp * 4.0 + 5.0))));
			sv *= smoothstep(0.22, 0.32, vn(v_rp * 5.0 + 3.0)) * silv_net;
		}
		sv *= dirt * silv_k * (1.0 - ag_on);
		if (sv > 0.0) {
			vec3 tp = v_rp * 4.0;
			vec3 w = pow(abs(normalize(v_no)), vec3(4.0));
			w /= (w.x + w.y + w.z);
			vec3 sd = texture(silver_diff, tp.zy).rgb * w.x + texture(silver_diff, tp.xz).rgb * w.y + texture(silver_diff, tp.xy).rgb * w.z;
			float sr = texture(silver_rough, tp.zy).r * w.x + texture(silver_rough, tp.xz).r * w.y + texture(silver_rough, tp.xy).r * w.z;
			vec3 tn = (texture(silver_nrm, tp.zy).xyz * w.x + texture(silver_nrm, tp.xz).xyz * w.y + texture(silver_nrm, tp.xy).xyz * w.z) * 2.0 - 1.0;
			base = mix(base, (sd * 1.05 + vec3(0.12)) * silv_col, sv);
			m = mix(m, 1.0, sv);
			r = mix(r, clamp(sr * 0.6, 0.06, 0.35), sv);
			// a cold glint of bright metal that the dark studio cannot swallow
			s_glow = vec3(0.16, 0.17, 0.19) * silv_col * sv * (0.5 + 0.5 * mix(vn(v_rp * 30.0), 0.5, aa_k * smoothstep(0.2, 0.45, length(fwidth(v_rp)) * 30.0)));
			n = normalize(mix(n, normalize(n + (VIEW_MATRIX * MODEL_MATRIX * vec4(tn.x, tn.y, 0.0, 0.0)).xyz * 0.5), sv));
		}
	}
	vec3 gp = v_rp * 38.0;
	n = normalize(n + (dirt * 1.1 * (1.0 - scan_k * 0.8) + frost * 0.25) * mix(1.0, 1.0 - smoothstep(0.2, 0.45, px_rp * 38.0), aa_k) * (vec3(vn(gp), vn(gp + 3.1), vn(gp + 5.7)) - 0.5));
	n = normalize(mix(n, s_nv, dirt * scan_k));
	if (micro_k > 0.0) {
		// fine pits and bumps: the normal tilted by two finer noises, the pits a little darker
		vec3 mp = v_rp * 26.0, mq = v_rp * 70.0;
		float k26 = mix(1.0, 1.0 - smoothstep(0.2, 0.45, px_rp * 26.0), aa_k);
		float k70 = mix(1.0, 1.0 - smoothstep(0.2, 0.45, px_rp * 70.0), aa_k);
		vec3 dn = (vec3(vn(mp), vn(mp + 3.1), vn(mp + 5.7)) - 0.5) * k26 + (vec3(vn(mq), vn(mq + 3.1), vn(mq + 5.7)) - 0.5) * 0.6 * k70;
		n = normalize(n + dn * micro_k * dirt * (1.0 - s_glow.r * 3.0));
		base *= mix(1.0, 0.72 + 0.5 * vn(mp + 9.0), micro_k * dirt * 0.6 * k26);
	}
#endif
	if (grain > 0.0) {
		vec3 gq = v_op * 60.0;
		n = normalize(n + grain * mix(1.0, 1.0 - smoothstep(0.2, 0.45, length(fwidth(v_op)) * 60.0), aa_k) * (vec3(vn(gq), vn(gq + 3.1), vn(gq + 5.7)) - 0.5));
	}
	if (aa_k > 0.0) {
		// (18.11) specular anti-aliasing: where the normal turns a lot from one pixel to the next (the rock's fine
		// relief, the scan, the metal's own relief) the highlight cannot be drawn sharp — it sparkled frame to frame.
		// The surface is made rougher by how much it turns under a pixel (Kaplanyan), the highlight spreads instead
		vec3 ndx = dFdx(n), ndy = dFdy(n);
		float nvar = 0.25 * (dot(ndx, ndx) + dot(ndy, ndy));
		if (isnan(nvar) || isinf(nvar)) nvar = 0.125;
		r = mix(r, sqrt(clamp(r * r + min(2.0 * nvar, 0.25), 0.0, 1.0)), aa_k);
	}
	vec3 e = emis + s_glow;
	vec3 e_ir = vec3(0.0);
#ifdef IRID
	float stb = sin(v_op.y * 70.0 + sin(v_op.x * 9.0 + v_op.z * 7.0) * 3.0) * sin(v_op.y * 23.0 + v_op.x * 5.0);
	if (st_mode > 0.5) {
		// the lines run along the crystal, or (pyrite) each face's at right angles to its neighbour's: the stripe
		// coordinate is taken along an axis lying in the face, the normal tipped along it
		vec3 fn = normalize(cross(dFdx(v_op), dFdy(v_op)) + vec3(1e-6));
		vec3 an = abs(fn);
		vec3 ax = st_mode > 1.5 ? (an.x >= an.y && an.x >= an.z ? vec3(0.0, 1.0, 0.0) : an.y >= an.z ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0))
			: normalize(cross(vec3(0.0, 1.0, 0.0), fn) + vec3(1e-4));
		vec3 tg = normalize(ax - fn * dot(ax, fn) + vec3(1e-5));
		float c = dot(v_op, ax);
		float sv = sin(c * 70.0 + sin(dot(v_op, fn.yzx) * 9.0) * 3.0) * sin(c * 23.0 + dot(v_op, fn.zxy) * 5.0);
		vec3 tv = (VIEW_MATRIX * (MODEL_MATRIX * vec4(tg, 0.0))).xyz;
		n = normalize(n + st_k * (1.0 - dirt) * tv * sv * 0.075);
	} else {
		n = normalize(n + st_k * (1.0 - dirt) * vec3(0.0, stb * 0.075, 0.0));
	}
	float clean = 1.0 - max(dirt, frost * 0.7);
	if (bd_k > 0.0) {
		// growth bands round the lump's middle: wavering, sharp-edged, some broad and some fine (malachite)
		float ph = length(v_op) * 140.0 + sin(v_op.x * 20.0) * 1.5 + (vn(v_op * 7.0) - 0.5) * 7.0;
		float w2 = 0.5 + 0.5 * sin(ph * 0.31 + 1.7);
		base *= 1.0 - bd_k * smoothstep(0.3, 0.7, 0.5 + 0.5 * sin(ph)) * (0.5 + 0.5 * w2);
	}
	float fr = 1.0 - abs(dot(n, VIEW));
	float hue = fr * 2.4 + sin(v_op.x * 9.0 + v_op.y * 5.0) * 0.35 + sin(v_op.z * 11.0 - v_op.y * 7.0) * 0.25;
	vec3 ir = 0.5 + 0.5 * cos(6.2832 * (hue + vec3(0.0, 0.33, 0.67)));
	float msk = smoothstep(0.15, 0.85, sin(v_op.y * 6.0 + v_op.x * 4.0 + v_op.z * 3.0) * 0.5 + 0.5);
	e_ir = ir * ir_k * clean * (ir_k > 1.5 ? 0.7 + 0.6 * fr : 0.2 + 0.8 * fr * fr) * (ir_k > 1.5 ? 1.0 : 0.35 + 0.65 * msk);
	if (rf_k > 0.0) {
		// the studio seen through the stone, each colour bent a little differently
		vec3 nw = (INV_VIEW_MATRIX * vec4(n, 0.0)).xyz;
		vec3 iw = (INV_VIEW_MATRIX * vec4(-VIEW, 0.0)).xyz;
		vec3 cr = vec3(studio(refract(iw, nw, 0.64)).r, studio(refract(iw, nw, 0.61)).g, studio(refract(iw, nw, 0.58)).b);
		e += cr * base * 1.3 * rf_k * clean / max(1.0, deep_k * deep_k * deep_k);
	}
#endif
#ifdef GLASS
	// real glass: the scene behind bent by the facets and split into colours, tinted by the body,
	// clouded where it grew milky, veiled with smoke, catching the studio lamps on its faces
	vec3 gq = v_op * 9.0 + g_seed;
	n = normalize(n + (vec3(vn(gq), vn(gq + 3.3), vn(gq + 7.1)) - 0.5) * 0.06);
	float cosv = abs(dot(n, VIEW));
	float edge_k = 1.0 - cosv;
	// eaten hollows: dark pockets ringed with frosted, etched glass
	float pit = clamp(1.0 - COLOR.a, 0.0, 1.0);
	frost = max(frost, smoothstep(0.05, 0.35, pit) * 0.4);
	float milk = clamp(smoothstep(0.52, 0.74, fbm(v_op * 2.6 + g_seed)) * frost_k + frost * 0.9, 0.0, 1.0);
	float part = 1.0;
#ifdef DIRT
	if (parts_k > 0.0 && v_zone > 0.0) {
		// clarity by parts, as crystals grow: each has its own share of cloud — most only at the root, clearing to a
		// gem tip; a few cloudy to the top; veils lying across some. And each a little deeper or paler than the next
		vec3 zq = v_rp * vec3(5.0, 3.0, 5.0) + v_zone * 53.0;
		float zy = v_rp.y + (fbm(zq) - 0.5) * 0.6;
		float lim = v_zone * v_zone * 1.1 - 0.08;
		float root = 1.0 - smoothstep(lim - 0.14, lim + 0.14, zy);
		float veil = smoothstep(0.56, 0.7, fbm(zq * 1.7 + 9.0)) * step(0.35, fract(v_zone * 5.3));
		milk = max(milk, clamp(root + veil * 0.6, 0.0, 1.0) * parts_k);
		part = 0.72 + 0.56 * fract(v_zone * 3.7);
	}
#endif
	float smoke = smoothstep(0.42, 0.78, fbm(v_op * 2.1 + g_seed + 17.0)) * smoke_k;
	vec2 bend = n.xy * (0.03 + 0.05 * thick) * (0.6 + edge_k);
	float split = 0.18 + 0.35 * edge_k;
	float blur = (0.002 + 0.012 * milk) * (0.5 + 0.5 * thick);
	vec2 uv = SCREEN_UV - bend;
	vec3 refr = vec3(behind(uv - bend * split, blur).r, behind(uv, blur).g, behind(uv + bend * split, blur).b);
	if (cham_k > 0.0) {
		// alexandrite-like: one colour face-on, another at a glance, the balance breathing over time
		float cm = clamp(edge_k * 1.6 + 0.25 * sin(TIME * 0.6 + v_op.y * 2.0), 0.0, 1.0);
		tint0 = mix(tint0, cham_col, cm * cham_k);
	}
	vec3 absorb = mix(vec3(1.0), tint0 / max(0.001, max(tint0.r, max(tint0.g, tint0.b))), clamp(0.35 + edge_k * 0.75, 0.0, 1.0));
	vec3 body = refr * absorb * mix(1.0, 0.75, edge_k);
	body *= 1.0 - dark_k * (0.5 + 0.45 * edge_k);
	if (tint_k > 0.0) {
		vec3 tb = tint0 / max(0.001, max(tint0.r, max(tint0.g, tint0.b)));
		float bl = dot(body, vec3(0.3, 0.5, 0.2)) * 1.6;
		// (deep: the light and dark of what is behind still show through — it reads as glass, not paint — but the
		// brightest of it stops short of where the tone curve turns a pure colour pastel; thin edges pass a little more)
		// (deep above 1: a lower ceiling still — the greens, which wash out soonest)
		float cl = 0.62 * part / max(1.0, deep_k * deep_k);
		bl = mix(bl, cl * bl / (0.4 + bl) + edge_k * edge_k * 0.26 * cl, min(deep_k, 1.0));
		body = mix(body, tb * (bl + tint_glow), tint_k);
	}
	if (cham_k > 0.0) {
		// the shifting colour has to carry the whole stone, not just tint what is seen through it: the body glows in
		// it (the rainbow film and the studio seen through the faces are dimmed below)
		vec3 tn = tint0 / max(0.001, max(tint0.r, max(tint0.g, tint0.b)));
		body = mix(body, dot(body, vec3(0.3, 0.5, 0.2)) * tn * 1.5 + tn * 0.05, 0.8 * cham_k);
	}
	float enh_dk = 0.0;   // how much of the face's own glare to take off over the pocket (it hid it)
	if (enh_k > 0.0) {
		// the ray from the eye, bent in at the face (glass ~1.55), meets the pocket: its wall dark where it turns away
		// (light leaves water for glass at a glance — the dark outline every fluid inclusion has), the water inside a
		// touch cooler and clearer; in it the bubble, its rim black (light bends off a bubble's edge), a spot of light
		// in it. Seen through the face, so it shifts and swims as the stone turns
		mat4 einv = inverse(MODEL_MATRIX);
		vec3 eo = (einv * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
		vec3 ed = normalize(v_op - eo);
		vec3 fn = normalize(v_no);
		if (dot(fn, ed) > 0.0) fn = -fn;
		vec3 rd = refract(ed, fn, 0.66);
		if (dot(rd, rd) < 1e-4) rd = ed;
		vec3 p = (v_op - enh_c) / enh_r;
		vec3 d = rd / enh_r;
		float A = dot(d, d), B = dot(p, d), C = dot(p, p) - 1.0;
		float disc = B * B - A * C;
		if (disc > 0.0) {
			float t0 = (-B - sqrt(disc)) / A;
			if (t0 > 0.0) {
				vec3 hp = v_op + rd * t0;
				vec3 en = normalize((hp - enh_c) / (enh_r * enh_r));
				float eg = 1.0 - abs(dot(en, rd));
				// the water is a lens: what is behind the crystal seen through it shifted and enlarged — the sign of a
				// liquid (a darker patch read as nothing). The pocket's own normal, as the screen sees it, pushes it
				vec3 env = (VIEW_MATRIX * MODEL_MATRIX * vec4(en, 0.0)).xyz;
				float thk = 1.0 - eg;
				vec2 luv = SCREEN_UV - bend + env.xy * vec2(-1.0, 1.0) * 0.07 * thk;
				vec3 lens = behind(luv, blur * 0.5) * absorb * vec3(0.92, 1.0, 1.06);
				body = mix(body, lens * 1.05, 0.9 * enh_k);
				// its wall: a thin dark line where it turns away, a faint bright lip just inside it
				float line = smoothstep(0.72, 0.95, eg);
				float lip = smoothstep(0.45, 0.72, eg) * (1.0 - line);
				body = body * (1.0 - 0.8 * line * enh_k) + vec3(0.06, 0.07, 0.08) * lip * enh_k;
				enh_dk = max(0.55, line) * enh_k;
				// the bubble, inside: the same ray on into the water
				vec3 bp = hp - enh_b.xyz;
				float bb2 = dot(bp, rd);
				float bc = dot(bp, bp) - enh_b.w * enh_b.w;
				float bd = bb2 * bb2 - bc;
				if (bd > 0.0 && -bb2 - sqrt(bd) > 0.0) {
					vec3 bh = hp + rd * (-bb2 - sqrt(bd));
					vec3 bn = normalize(bh - enh_b.xyz);
					float br = 1.0 - abs(dot(bn, rd));
					// (a soft rim, not a black ring — that read as an eyeball; the middle clear and bright)
					float brim = smoothstep(0.35, 0.9, br);
					float spot = pow(max(0.0, dot(bn, normalize(-rd + vec3(-0.3, 0.9, 0.0)))), 40.0);
					vec3 inb = body * 1.2 + vec3(0.03);
					body = mix(body, mix(inb, body * 0.15, brim), enh_k) + vec3(1.0) * spot * 1.6 * enh_k;
					enh_dk = max(enh_dk, max(0.5, brim) * enh_k);
				}
			}
		}
	}
	float trap = 0.0;
	if (trap_k > 0.0) {
		// the arms reach the faces, as a real trapiche's do: on the flat end a star round a dark core, on the sides dark
		// bands down the crystal where an arm meets the face; looked at from the face a little way in too (the eye goes
		// in a little bent), so the bands have depth and drift as the stone turns
		mat4 tinv = inverse(MODEL_MATRIX);
		vec3 to = (tinv * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
		vec3 td = normalize(v_op - to);
		for (int i = 0; i < 4; i++) {
			vec3 q = v_op + td * trap_r * (float(i) * 0.12);
			float rq = length(q.xz);
			float th = atan(q.z, q.x) - trap_a;
			float sect = 1.0471976;
			float dth = abs(mod(th + sect * 0.5, sect) - sect * 0.5);
			float side = rq * sin(dth);
			// arms widen outwards, ragged with the growth's own dust; a hexagonal dark core
			float w = trap_r * 0.1 + rq * 0.12 + (vn(q * 22.0) - 0.5) * trap_r * 0.05;
			float arm = 1.0 - smoothstep(w, w + trap_r * 0.04, side);
			float core = 1.0 - smoothstep(trap_r * 0.22, trap_r * 0.28, rq);
			trap = max(trap, max(arm, core) * (1.0 - float(i) * 0.18));
		}
		trap *= trap_k;
		body = mix(body, body * 0.05 + vec3(0.005, 0.007, 0.004), trap);
	}
	if (star_k > 0.0) {
		// a night sky trapped inside: a deep blue-black body, nebulae drifting, stars twinkling at three depths (the
		// near ones big, with a soft glow, a few with a cross of light) — strong enough to read on a phone card
		body = mix(body, body * vec3(0.03, 0.035, 0.09) + vec3(0.004, 0.006, 0.02), star_k * 0.92);
		vec3 sp = v_op + (INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz * 0.15;
		float neb = fbm(sp * 2.2 + vec3(TIME * 0.02, 0.0, TIME * 0.015));
		float neb2 = fbm(sp * 3.7 + vec3(-TIME * 0.015, TIME * 0.01, 4.0));
		body += mix(vec3(0.35, 0.06, 0.6), vec3(0.05, 0.4, 0.75), fbm(sp * 1.3)) * smoothstep(0.48, 0.85, neb) * star_k * 0.9;
		body += vec3(0.6, 0.12, 0.35) * smoothstep(0.62, 0.88, neb2) * star_k * 0.4;
		for (int L = 0; L < 3; L++) {
			float fl = float(L);
			vec3 q = sp * (11.0 + fl * 9.0) + fl * 7.0;
			vec3 cell = floor(q);
			float h = h3(cell);
			vec3 off = vec3(h3(cell + 3.1), h3(cell + 5.7), h3(cell + 9.3)) * 0.5 + 0.25;
			vec3 dv = fract(q) - off;
			float d = length(dv);
			float tw = 0.6 + 0.4 * sin(TIME * (1.5 + h * 4.0) + h * 40.0);
			float on = step(0.8 + fl * 0.04, h);
			float sz = (0.21 - fl * 0.05) * (0.7 + 0.6 * h3(cell + 1.7));
			float core = 1.0 - smoothstep(sz * 0.3, sz, d);
			float glow = exp(-d / (sz * 1.6)) * 0.35;
			// the brightest near stars throw a cross of light
			float cross = L == 0 && h > 0.95 ? exp(-abs(dv.x) / 0.02) * exp(-abs(dv.y) / 0.25) + exp(-abs(dv.y) / 0.02) * exp(-abs(dv.x) / 0.25) : 0.0;
			vec3 sc = mix(vec3(1.0, 0.92, 0.8), vec3(0.75, 0.85, 1.0), h3(cell + 2.3));
			body += sc * on * (core * 4.0 + glow + cross) * tw * star_k;
		}
	}
	if (opal_k > 0.0) {
		// play of colour (19.11): the harlequin of precious opal (opal.gdshaderinc opal_harl) — a mosaic of angular
		// patches through the body, each one colour, each flashing on as the face turns its way; patches meet
		// without a gap. (Were round spectral flakes on a grid: read as coloured dots, "strange little circles")
		vec3 oq = v_op * 7.0 + g_seed;
		oq += (vec3(vn(oq * 0.33), vn(oq * 0.33 + 5.0), vn(oq * 0.33 + 9.0)) - 0.5) * 1.3;
		vec3 oc = floor(oq);
		float od1 = 9.0, od2 = 9.0;
		vec3 oid = vec3(0.0);
		for (int z = -1; z <= 1; z++) for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
			vec3 g = oc + vec3(float(x), float(y), float(z));
			vec3 pt = g + vec3(h3(g), h3(g + 1.7), h3(g + 3.1)) * 0.85 + 0.075;
			float d = distance(pt, oq);
			if (d < od1) { od2 = od1; od1 = d; oid = g; } else if (d < od2) { od2 = d; }
		}
		float orr = h3(oid + 5.3);
		vec3 ogd = normalize(vec3(h3(oid + 11.0), h3(oid + 13.0), h3(oid + 17.0)) - 0.5);
		float oang = dot(n, ogd) + edge_k * 0.6;
		float olit = smoothstep(0.45, 0.95, sin(oang * 6.0 + orr * 20.0 + TIME * 0.15) * 0.5 + 0.5);
		float oband = 0.85 + 0.15 * sin(dot(oq, ogd) * 7.0 + oang * 10.0);
		float ohue = 0.62 + (orr - 0.5) * 0.9 + oang * 0.12;
		vec3 ocol = 0.5 + 0.5 * cos(6.2832 * (ohue + vec3(0.0, 0.33, 0.67)));
		ocol = ocol * ocol;   // (deep, not pastel)
		float oon = step(0.3, h3(oid + 23.0)) * smoothstep(0.0, 0.012, od2 - od1);
		body += ocol * olit * oband * oon * opal_k * 1.4;
	}
	// (a night sky inside clears the milk: it would wash the stars out)
	milk *= 1.0 - 0.85 * star_k;
	// (a deep-coloured body clouds in its own colour, not to white)
	vec3 tbm = tint0 / max(0.001, max(tint0.r, max(tint0.g, tint0.b)));
	float dpk = min(deep_k, 1.0) * step(0.001, tint_k);
	body = mix(body, mix(tint0 * 0.5 + vec3(0.22), tbm * 0.1 * part + tint0 * 0.06, dpk), milk * mix(0.75, 0.9, dpk));
	// limonite: the glass's milky foot and the runs up it rust-brown (the white milk would hide the stain)
	vec3 rust = vec3(0.24, 0.09, 0.02) * (0.7 + 0.6 * fbm(v_op * 14.0));
#ifdef DIRT
	// (and the cloudy root of the crystal: clarity by parts whitens it — rusted where it is near the foot)
	if (d_lim > 0.0) lim_s = max(lim_s, d_lim * milk * (1.0 - smoothstep(0.2, 1.1, edge)) * smoothstep(0.2, 0.5, fbm(v_op * 5.0 + 2.0) + 0.2));
	lim_s = clamp(lim_s * 2.0, 0.0, 1.0);
#endif
	body = mix(body, rust, lim_s * 0.95);
	body = mix(body, body * smoke_col * 2.0, smoke);
	// silver rims: the edges frost over into a bright, ragged, slightly metallic band
	float srim = 0.0;
	if (rim_k > 0.0) {
		float eb = min(v_bary.x, min(v_bary.y, v_bary.z));
		// ragged: in places the frost eats deep into the face, elsewhere it is a hairline
		float rw = 0.022 * (0.25 + 1.6 * smoothstep(0.3, 0.75, fbm(v_op * 6.0 + g_seed))) * rim_k;
		srim = (1.0 - smoothstep(rw * 0.1, rw * 1.4, eb + (vn(v_op * 90.0) - 0.5) * rw * 0.5)) * (1.0 - dirt);
		srim *= 0.7 + 0.5 * vn(v_op * 55.0);
		srim = clamp(srim, 0.0, 1.0);
	}
	// holographic sheen: wide rainbow gradients sweeping across some faces
	if (holo_k > 0.0) {
		float fr2 = 1.0 - cosv;
		float hh = dot(v_op, vec3(0.7, 1.1, 0.4)) * 0.9 + fr2 * 0.9 + vn(v_op * 0.9 + g_seed) * 1.4;
		vec3 holo = 0.5 + 0.5 * cos(6.2832 * (hh + vec3(0.0, 0.33, 0.67)));
		float hm = smoothstep(0.35, 0.7, vn(v_op * 1.2 + g_seed + 5.0) * 0.7 + vn(v_op * 2.3 + g_seed) * 0.3);
		body += holo * holo_k * hm * (0.35 + 0.65 * fr2) * (1.0 - milk * 0.5) * (1.0 - dirt) * (1.0 - 0.75 * star_k) * (1.0 - 0.8 * cham_k);
	}
	vec3 pitc = tint0 * 0.035 + vec3(0.004, 0.003, 0.006);
	float hollow = smoothstep(0.3, 0.7, pit) * (1.0 - dirt);
	body = mix(body, pitc, hollow);
	vec3 silver = vec3(0.85, 0.87, 0.9) * (0.6 + 0.6 * fbm(v_op * 40.0));
	body = mix(body, silver * 0.55, srim * 0.85);
	ALBEDO = mix(mix(mix(mix(tint0, rust, lim_s) * milk * mix(0.35, 0.62 / max(1.0, deep_k * deep_k * deep_k), dpk), silver, srim), pitc, hollow), base, dirt);
	METALLIC = srim * 0.65;
	ROUGHNESS = mix(mix(mix(mix(mix(0.02, 0.32, milk), 0.38, srim), 0.8, hollow), 0.85, lim_s), r, dirt);
	SPECULAR = mix(mix(0.6, 0.08, hollow), 0.02, lim_s);
	CLEARCOAT = 0.0;
	// the rainbow film only blooms in patches, as on real crystals
	float film = 0.12 + 0.88 * smoothstep(0.5, 0.72, fbm(v_op * 1.6 + g_seed + 5.0));
	if (heart_r > 0.0) {
		// how close the line of sight passes to the core: a glow seen through the whole thickness
		mat4 inv_m = inverse(MODEL_MATRIX);
		vec3 o = (inv_m * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
		vec3 dir = normalize((inv_m * vec4((INV_VIEW_MATRIX * vec4(-VIEW, 0.0)).xyz, 0.0)).xyz);
		vec3 hv = heart_pos - o;
		float dd = length(hv - dir * dot(hv, dir)) / heart_r;
		// a tight core and a wide aura that swells on every beat
		float core = exp(-dd * dd * 2.6) * (0.75 + 0.5 * heart_beat);
		float aura = exp(-dd * (1.1 - 0.35 * heart_beat)) * (0.18 + 0.3 * heart_beat);
		body += heart_col * (core + aura) * (1.0 - dirt);
	}
	if (kin_k > 0.0) {
		// kintsugi: cracks mended with worked gold. The seams are raised beads of real metal
		// (hammered, scratched, tarnished in the grooves) that swell where cracks meet.
		// cracks: the borders between irregular cells (voronoi F2 - F1), warped so they wander
		vec3 kq = v_op * 4.5 + g_seed + (vec3(vn(v_op * 2.5), vn(v_op * 2.5 + 7.0), vn(v_op * 2.5 + 13.0)) - 0.5) * 1.3;
		vec3 ci = floor(kq);
		float f1 = 9.0, f2 = 9.0;
		for (int i = -1; i <= 1; i++) for (int j = -1; j <= 1; j++) for (int l = -1; l <= 1; l++) {
			vec3 c = ci + vec3(float(i), float(j), float(l));
			vec3 pt = c + vec3(h3(c), h3(c + 17.0), h3(c + 31.0)) * 0.85;
			float dd = length(kq - pt);
			if (dd < f1) { f2 = f1; f1 = dd; } else if (dd < f2) { f2 = dd; }
		}
		float kn = (f2 - f1) * 0.5;
		float kw = fwidth(kn) * 1.2 + 0.035 * (0.6 + 0.8 * vn(v_op * 6.0));
		float d1 = kn / kw;
		// some stretches of crack were never mended
		float d = d1 + smoothstep(0.62, 0.8, vn(kq * 0.9 + 40.0)) * 3.0;
		float vk = 1.0 - smoothstep(0.75, 1.0, d);
		if (vk > 0.0) {
			// the bead's slope: across the seam the surface rises to a rounded crest
			// screen-space slope of the distance to the crack: the bead rises towards its centre line
			vec3 gv = normalize(vec3(dFdx(kn), dFdy(kn), 0.0) + 1e-6);
			float slope = clamp(d1, 0.0, 1.0);
			// triplanar worked-gold texture
			vec3 tp = v_op * 3.2;
			vec3 w = pow(abs(normalize(v_no)), vec3(4.0));
			w /= (w.x + w.y + w.z);
			vec3 gd = texture(gold_diff, tp.zy).rgb * w.x + texture(gold_diff, tp.xz).rgb * w.y + texture(gold_diff, tp.xy).rgb * w.z;
			float gr = texture(gold_rough, tp.zy).r * w.x + texture(gold_rough, tp.xz).r * w.y + texture(gold_rough, tp.xy).r * w.z;
			vec3 tn = (texture(gold_nrm, tp.zy).xyz * w.x + texture(gold_nrm, tp.xz).xyz * w.y + texture(gold_nrm, tp.xy).xyz * w.z) * 2.0 - 1.0;
			vec3 gn = normalize(n - gv * slope * 0.9);
			gn = normalize(gn + (VIEW_MATRIX * MODEL_MATRIX * vec4(tn.x, tn.y, 0.0, 0.0)).xyz * 0.5);
			// a glint sliding along the seams now and then
			float gleam = pow(0.5 + 0.5 * sin(dot(v_op, vec3(3.0, 5.0, 2.0)) * 1.5 - TIME * 1.8), 12.0);
			float k = vk * kin_k;
			body *= 1.0 - k;
			// the same gold as the native gold finds, with the worked texture's wear on top
			vec3 native_gold = vec3(0.87, 0.53, 0.08);
			ALBEDO = mix(ALBEDO, native_gold * (gd.r * 1.15), k);
			METALLIC = mix(METALLIC, 1.0, k);
			ROUGHNESS = mix(ROUGHNESS, clamp(gr * 0.9, 0.08, 0.6), k);
			SPECULAR = mix(SPECULAR, 0.5, k);
			n = normalize(mix(n, gn, k));
			body += vec3(1.6, 1.1, 0.45) * gleam * k * (1.0 - gr);
		}
	}
	// ultraviolet: the lamps go dark and the crystal lights up from within, a soft core that thickens
	// towards the silhouette (more glass to glow through there) and drifts slowly; kept below white
	// so the colour survives the tonemapper, the studio's bloom makes the halo
	float uvf = 1.0 - clamp(dot(n, VIEW), 0.0, 1.0);
	float uvn = fbm(v_op * 2.6 + vec3(0.0, TIME * 0.15, 0.0));
	vec3 uvc = fluor_col * 0.5 * (0.25 + 0.95 * uvn * uvn * 1.6) * (0.6 + 1.3 * uvf * uvf);
	body = mix(body, uvc, uvk);
	ALBEDO *= 1.0 - uvk * 0.9;
	SPECULAR *= 1.0 - uvk * 0.7;
	// a night sky inside: the faces' white studio glare and lit surface would grey it out, so they dim to a glint
	ALBEDO *= 1.0 - 0.85 * star_k * (1.0 - dirt);
	ALBEDO *= 1.0 - 0.9 * trap * (1.0 - dirt);
	ALBEDO *= 1.0 - 0.95 * enh_dk * (1.0 - dirt);
	SPECULAR *= 1.0 - 0.6 * enh_dk;
	SPECULAR *= 1.0 - 0.5 * trap;
	SPECULAR *= 1.0 - 0.7 * star_k * (1.0 - dirt);
	EMISSION = body * (1.0 - dirt) + ((e + e_ir * film * 0.25) * (1.0 - 0.85 * star_k) * (1.0 - 0.8 * cham_k)) * (1.0 - dirt * 0.8) * (1.0 - hollow * 0.92) + lava_e + a_eye;
	NORMAL = n;
	ALPHA = 1.0;
	if (grow_on > 0.0) {
		// the front, the hot fresh glass, and the inside seen through the open top: molten stone of its colour
		EMISSION += grow_col * (g_front * 1.6 + grow_heat * 0.15);
		ALBEDO *= 1.0 - min(1.0, g_front * 0.6);
	}
#elif defined(UNSHADED)
	ALBEDO = base + e + e_ir;
#else
	// opaque stones and metals. Eaten hollows (vertex alpha) go dark and dull.
	float o_pit = smoothstep(0.3, 0.75, 1.0 - COLOR.a) * (1.0 - dirt);
	float o_fr = 1.0 - abs(dot(n, VIEW));
	if (oil_k > 0.0) {
		// a dark crystal with an oily, rainbow sheen sliding over its faces
		float oh = fbm(v_op * 1.7 + 3.0) * 1.6 + o_fr * 1.3 + v_op.y * 0.4;
		vec3 oil = 0.5 + 0.5 * cos(6.2832 * (oh + vec3(0.0, 0.33, 0.67)));
		float om = smoothstep(0.55, 0.72, fbm(v_op * 1.1 + 9.0)) * (1.0 - dirt);
		base = mix(base, oil * 0.4, om * oil_k * 0.7);
		m = mix(m, 0.9, om * oil_k);
		e += oil * om * oil_k * (0.02 + 0.12 * o_fr * o_fr);
		// a cold sheen at grazing angles even where there is no rainbow
		e += vec3(0.05, 0.12, 0.13) * o_fr * o_fr * oil_k * (1.0 - om);
		// glinting scratches and chips along the faces
		float sc = smoothstep(0.82, 0.9, vn(v_op * vec3(4.0, 40.0, 4.0)));
		r = mix(r, 0.05, sc * 0.6);
	}
	if (peacock_k > 0.0) {
		// peacock ore: the brass keeps its gold where the film is thin, and elsewhere goes magenta, purple, deep blue,
		// teal — some faces wholly (one value to a flat face), others in patches. The film is on metal: it colours
		// what the face mirrors, so the colours stay deep where no lamp is and flare where one is
		// (the brass is the metal's colour alone: under the species' own brass in the vertices it came out orange —
		// only how light the vertex is stays)
		float pvl = clamp(max(COLOR.r, max(COLOR.g, COLOR.b)) * 1.6, 0.6, 1.0);
		base = mix(base, albedo * pvl, pow(1.0 - dirt, 3.0));
		vec3 pfn = normalize(cross(dFdx(v_op), dFdy(v_op)) + vec3(1e-6));
		float pf = dot(pfn, vec3(1.7, 2.3, 1.1));
		float plo = mix(0.64, 0.3, clamp(peacock_k - 0.5, 0.0, 1.0));
		float pm = smoothstep(plo, plo + 0.24, fbm(v_op * 1.1 + 9.0) * 0.7 + 0.3 * (0.5 + 0.5 * sin(pf * 5.0))) * (1.0 - dirt);
		// (the colour drifts slowly over a face and with the angle it is seen at, as a film's does)
		float ph = fract(vn(v_op * 0.9 + 3.0) * 0.9 + vn(v_op * 2.6 + 7.0) * 0.25 + pf * 0.21 + o_fr * 0.35);
		vec3 pc = ph < 0.2 ? mix(vec3(0.5, 0.3, 0.03), vec3(0.46, 0.02, 0.17), ph * 5.0)
			: ph < 0.45 ? mix(vec3(0.46, 0.02, 0.17), vec3(0.17, 0.02, 0.44), (ph - 0.2) * 4.0)
			: ph < 0.72 ? mix(vec3(0.17, 0.02, 0.44), vec3(0.02, 0.09, 0.5), (ph - 0.45) / 0.27)
			: ph < 0.88 ? mix(vec3(0.02, 0.09, 0.5), vec3(0.02, 0.3, 0.34), (ph - 0.72) / 0.16)
			: mix(vec3(0.02, 0.3, 0.34), vec3(0.5, 0.3, 0.03), (ph - 0.88) / 0.12);
		base = mix(base, pc, pm);
		m = mix(m, 1.0, pm);
		r = mix(r, r * 0.7, pm);
		e += pc * pm * (0.035 + 0.3 * o_fr * o_fr);
		// the clean brass: a little uneven, so a face is not one flat tone, and lit a little from itself (a dark
		// studio mirrored in gold reads as brown)
		float pg = fbm(v_op * 7.0 + 1.0);
		base *= mix(1.0, 0.78 + 0.34 * pg, 1.0 - pm);
		r = clamp(r + (pg - 0.5) * 0.2, 0.04, 1.0);
		e += base * (1.0 - pm) * (1.0 - dirt) * 0.11;
	}
	if (rough_var > 0.0) {
		r = clamp(r + (fbm(v_op * 18.0) - 0.5) * rough_var + (1.0 - COLOR.g) * rough_var, 0.04, 1.0);
	}
	base = mix(base, base * 0.08, o_pit);
	ALBEDO = base;
	METALLIC = m * (1.0 - o_pit * 0.7);
	ROUGHNESS = mix(r, 0.85, o_pit);
	SPECULAR = spec;
	CLEARCOAT = cc;
	CLEARCOAT_ROUGHNESS = coat_rough;
	// ultraviolet on an opaque mineral: a glow skin, brighter at the rim, none on the rock part (dirt)
	EMISSION = (e + e_ir) * (1.0 - o_pit) + lava_e + a_eye + fluor_col * uvk * (1.0 - dirt) * 0.45 * (0.7 + 0.8 * o_fr * o_fr);
	ALBEDO *= 1.0 - uvk * 0.9 * (1.0 - dirt);
	NORMAL = n;
	if (grow_on > 0.0) {
		EMISSION += grow_col * (g_front * 1.6 + grow_heat * 0.15);
		ALBEDO *= 1.0 - min(1.0, g_front * 0.6);
	}
	if (gc_n > 0) {
		// the rock split open: the cracks dark, then light from deep inside running up them; a glow welling at each place
		ALBEDO *= 1.0 - min(0.9, g_web * 0.9 + g_core * 0.4);
		EMISSION += gc_col * (g_web * 1.3 + g_core * g_core * 0.6);
	}
#endif
#if defined(TRANSP) && !defined(GLASS)
	ALPHA = a;
#endif
}
