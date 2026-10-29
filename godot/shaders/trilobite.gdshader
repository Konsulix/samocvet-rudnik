shader_type spatial;
render_mode cull_disabled;
// Trilobites (SpecTrilobite):
//   part 0 — the shell: UV = the flat body position (across, along), UV2.x = along the body (0 snout .. 1 tail);
//            COLOR.r = on the axis, g = in a furrow, b = the glabella, a = 0 on the underside.
//            Granules (tubercles) in relief, worn shine on the high points, its rock left in the furrows;
//            pyrite has an iridescent tarnish in patches.
//   part 1 — an eye: UV = across it, up it. Schizochroal eyes are rows of separate lenses, each a little dome
//            tilted its own way, so as the find turns they catch the light one by one; others are smooth.
//   part 2 — the rock of a pedestal: the host rock's scan.

uniform int part = 0;
uniform vec3 base_col : source_color = vec3(0.5, 0.4, 0.3);
uniform vec3 dark_col : source_color = vec3(0.15, 0.1, 0.06);
uniform vec3 rock_col : source_color = vec3(0.5, 0.48, 0.45);
uniform float metal_k = 0.0;
uniform float rough_k = 0.5;
uniform float film_k = 0.0;
uniform float tub_k = 0.0;          // granules over the shell (1: phacops)
uniform float lens_on = 0.0;
uniform vec2 lens_n = vec2(13.0, 7.0);
uniform float dirt_k = 0.7;         // how much of its rock clings in the furrows
uniform float seed = 0.0;
uniform sampler2D rock_tex : source_color, filter_linear_mipmap, repeat_enable;
// a scan of stone over the shell (calcite, dark rock…): its lightness mottles the colour and roughens the relief
uniform sampler2D scan_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float scan_k = 0.5;
uniform float opal_k = 0.0;        // an opalized shell: precious opal's play of colour
uniform float opal_h = 0.3;
// legendary: roll (0 lying flat .. 1 rolled into a ball, bent here in the vertex shader so it can roll up live);
// glow_k a deep-sea glow running in waves down the body; eye_glow lit lenses; glow_col their colour
uniform float roll = 0.0;
uniform float glow_k = 0.0;
uniform float eye_glow = 0.0;
uniform vec3 glow_col : source_color = vec3(0.3, 0.7, 1.0);


varying vec3 v_op;
varying vec3 v_no;
varying vec3 v_cam;

#include "res://shaders/opal.gdshaderinc"

vec4 tri(sampler2D t, vec3 q, vec3 w) {
	return texture(t, q.yz) * w.x + texture(t, q.xz) * w.y + texture(t, q.xy) * w.z;
}

void vertex() {
	v_op = VERTEX;
	v_no = NORMAL;
	v_cam = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
	// rolling up, as SpecTrilobite._bend does it on the CPU: the pleurae curl down round the sides, the body round a
	// circle below it (written so it stays exact as the curl goes to nothing), the ball lifted to sit on the rock
	if (roll > 0.001) {
		float k = roll * 1.08;
		float R = 1.0 / (6.2832 * k * 0.93);
		float rs = R / 0.55;
		vec3 v = VERTEX;
		float ph = v.x / rs;
		float sp = sin(ph), cp = cos(ph), shp = sin(ph * 0.5);
		vec3 q = vec3(v.x * (abs(ph) > 1e-4 ? sp / ph : 1.0) + v.y * sp, v.y * cp - 2.0 * rs * shp * shp, v.z);
		float a = q.z / R;
		float sa = sin(a), ca = cos(a), sha = sin(a * 0.5);
		VERTEX = vec3(q.x, q.y * ca - 2.0 * R * sha * sha, q.z * (abs(a) > 1e-4 ? sa / a : 1.0) + q.y * sa);
		// (the ball hangs two radii below the back: lift it by that, so it rolls up on the rock, not into it)
		VERTEX.y += roll * (2.0 * R + 0.03);
		vec3 n = NORMAL;
		n = vec3(n.x * cp + n.y * sp, -n.x * sp + n.y * cp, n.z);
		NORMAL = vec3(n.x, n.y * ca - n.z * sa, n.y * sa + n.z * ca);
	}
}

void fragment() {
	vec3 n = normalize(NORMAL);
	if (!FRONT_FACING) n = -n;
	vec3 p = v_op;
	vec3 c;
	float ro = rough_k;
	float me = metal_k;
	float h = 0.0;
	if (part == 1) {
		// the eye: a palpebral rim of shell, then the lenses in staggered rows
		vec2 q = vec2(UV.x * lens_n.x, UV.y * lens_n.y);
		q.x += step(1.0, mod(floor(q.y), 2.0)) * 0.5;
		vec2 cell = floor(q);
		vec2 d = (fract(q) - 0.5) * 2.0;
		float r = length(d);
		float id = h3(vec3(cell, seed));
		// lenses on the eye's outer side only; round its back and its foot plain shell
		float side = smoothstep(0.27, 0.32, UV.x) * smoothstep(0.73, 0.68, UV.x) * smoothstep(0.12, 0.22, UV.y) * smoothstep(0.98, 0.9, UV.y);
		float lens = lens_on * (1.0 - smoothstep(0.82, 0.97, r)) * side;
		// each lens its own dome, tipped its own way: some face the lamp as the find turns, others go dark
		vec2 tilt = (vec2(id, h3(vec3(cell, seed + 3.0))) - 0.5) * 1.2;
		float dome = sqrt(max(0.0, 1.0 - r * r)) + dot(d, tilt) * 0.5;
		h = lens * dome * 0.0035;
		vec3 lc = mix(vec3(0.02, 0.016, 0.012), base_col * 0.4, 0.2) * (0.6 + 0.8 * id);
		vec3 rim = mix(dark_col, base_col, 0.6) * (0.75 + 0.3 * fbm(p * 120.0));
		c = mix(rim, lc, lens);
		// no lids to blink: now and then a ripple of light runs across the lenses instead, front to back
		float ph = fract(TIME * 0.17 + seed * 0.13);
		float band = exp(-pow((UV.x - mix(0.22, 0.78, ph * 1.7)) / 0.045, 2.0)) * step(ph, 0.6);
		c = mix(c, vec3(0.95, 0.85, 0.62), band * lens * 0.7);
		if (lens_on < 0.5) c = mix(base_col * 0.35, vec3(0.03), 0.6);   // a smooth eye: dark and glossy
		ro = mix(rough_k, 0.06, max(lens, 1.0 - lens_on));
		me = mix(metal_k, 0.0, lens);
		NORMAL = bump(n, VERTEX, h, 1.0);
	} else if (part == 2) {
		vec3 tw = pow(abs(normalize(v_no)), vec3(4.0));
		tw /= tw.x + tw.y + tw.z;
		vec3 sc = tri(rock_tex, p * 1.7, tw).rgb;
		c = rock_col * (0.55 + 0.7 * sc) * (0.8 + 0.3 * fbm(p * 30.0));
		ro = 0.92;
		me = 0.0;
		h = fbm(p * 45.0) * 0.004 + vn(p * 140.0) * 0.001;
		NORMAL = bump(n, VERTEX, h, 1.0);
	} else {
		vec2 b = UV;
		float axis = COLOR.r;
		float furrow = COLOR.g;
		float glab = COLOR.b;
		// granules: dense on the glabella, scattered over the rest by kind
		vec3 gr = vor2(b * mix(95.0, 70.0, glab) + seed);
		float gk = max(glab, tub_k * 0.6) * tub_k;
		float tub = (1.0 - smoothstep(0.15, 0.42, gr.x)) * gk * step(0.25, gr.z);
		vec3 fine = vor2(b * 260.0 + seed * 3.0);
		float grain = (1.0 - smoothstep(0.1, 0.4, fine.x)) * 0.35;
		float wear = fbm(vec3(b * 18.0, seed));
		vec3 tw0 = pow(abs(normalize(v_no)), vec3(4.0));
		tw0 /= tw0.x + tw0.y + tw0.z;
		vec3 sc = tri(scan_tex, p * 2.4 + seed, tw0).rgb;
		float sl = dot(sc, vec3(0.3, 0.5, 0.2));
		float pits = smoothstep(0.75, 0.9, vn(vec3(b * 140.0, seed))) * (1.0 - tub);
		h = tub * 0.0035 + grain * 0.0004 + (wear - 0.5) * 0.0006 + (sl - 0.4) * 0.0012 * scan_k - pits * 0.0005;
		// colour: darker down in the furrows, lighter and polished on the high points the rock wore
		c = mix(base_col, dark_col, furrow * 0.65);
		c *= 0.82 + 0.3 * fbm(vec3(b * 9.0, seed + 2.0));
		c *= mix(1.0, 0.45 + sl * 1.6, scan_k);
		c = mix(c, c * 0.6, pits * 0.6);
		float high = axis * (1.0 - furrow) * smoothstep(0.45, 0.75, wear);
		c = mix(c, c * 1.35 + 0.02, high * 0.5 + tub * 0.35);
		ro = rough_k * (1.0 - high * 0.4) * (0.85 + 0.3 * wear) * mix(1.0, 0.7 + sl, scan_k * 0.6);
		// pyrite is never a polished ball: crystal grain (each tiny facet tipped its own way), limonite rust in
		// patches, dull where it weathered
		if (metal_k > 0.5) {
			vec3 cg = vor2(b * 160.0 + seed);
			h += (cg.z - 0.5) * 0.0014 + (1.0 - smoothstep(0.0, 0.08, cg.y)) * -0.0006;
			float rust = smoothstep(0.52, 0.72, fbm(vec3(b * 4.0, seed + 20.0))) * (0.6 + 0.4 * fbm(vec3(b * 30.0, seed)));
			c = mix(c, vec3(0.26, 0.14, 0.06) * (0.7 + 0.6 * fbm(vec3(b * 40.0, seed + 3.0))), rust * 0.85);
			ro = mix(ro * (0.8 + 0.6 * cg.z), 0.85, rust);
			me = mix(me, 0.1, rust);
			c *= 0.85 + 0.3 * cg.z;
		}
		// pyrite: a tarnish in patches, blue and purple and gold
		float tar = film_k * smoothstep(0.45, 0.7, fbm(vec3(b * 6.0, seed + 9.0)));
		vec3 film = hue(0.55 + fbm(vec3(b * 14.0, seed)) * 0.5 + (1.0 - abs(dot(n, VIEW))) * 0.3);
		c = mix(c, c * 0.5 + film * length(c) * 0.7, tar);
		// its rock left in the furrows and round the edge, matt
		float dirt = dirt_k * smoothstep(0.55, 0.95, furrow + (fbm(vec3(b * 30.0, seed + 5.0)) - 0.5) * 0.7);
		// the underside (COLOR.a 0) and the patches where the shell flaked off (0.6): the rock that filled it
		vec3 fill = rock_col * (0.45 + 0.6 * fbm(vec3(b * 22.0, seed + 31.0)));
		float gone = max(1.0 - step(0.3, COLOR.a), smoothstep(0.95, 0.7, COLOR.a));
		c = mix(c, fill * mix(1.0, 1.25, step(0.3, COLOR.a)), gone);
		ro = mix(ro, 0.9, gone);
		me = mix(me, 0.0, gone);
		vec3 tw = pow(abs(normalize(v_no)), vec3(4.0));
		tw /= tw.x + tw.y + tw.z;
		vec3 rc = rock_col * (0.6 + 0.8 * tri(rock_tex, p * 2.0, tw).rgb);
		c = mix(c, rc, dirt);
		ro = mix(ro, 0.95, dirt);
		me = mix(me, 0.0, dirt);
		// opal: the shell gone to precious opal, its fire over a dark body, glossy (the furrows keep their rock)
		if (opal_k > 0.0) {
			float glow;
			vec3 fire = opal_play(p * 3.0, normalize(v_cam - p), normalize(v_no), opal_h, 0.45, seed, 0.0, 2.5, 0.7, 1.0, glow);
			c = mix(c, c * 0.6 + fire * 0.7, opal_k * (1.0 - dirt));
			ro = mix(ro, 0.12, opal_k * (1.0 - dirt));
		}
		NORMAL = bump(n, VERTEX, h, 1.0);
		// the deep-sea glow: the shell stays itself, and rows of little photophores along its lobes light up one by
		// one in a slow wave from head to tail, each on its own delay, the axis's brighter; between waves they smoulder
		if (glow_k > 0.0) {
			vec2 q = vec2(b.x * 18.0, UV2.x * 24.0);
			vec2 cell = floor(q);
			vec2 fq = fract(q) - 0.5;
			float hid = h3(vec3(cell, seed + 41.0));
			fq += (vec2(h3(vec3(cell, seed + 5.0)), h3(vec3(cell, seed + 9.0))) - 0.5) * 0.35;
			float pt = (1.0 - smoothstep(0.1, 0.24, length(fq))) * step(0.42, hid) * (1.0 - smoothstep(0.35, 0.6, furrow));
			float halo = (1.0 - smoothstep(0.15, 0.5, length(fq))) * step(0.42, hid) * 0.25;
			float wave = pow(max(0.0, sin(UV2.x * 7.0 - TIME * 1.4 + hid * 1.8)), 10.0);
			float lit = 0.12 + 1.6 * wave * (0.6 + 0.4 * axis);
			EMISSION = glow_col * glow_k * (pt + halo) * lit * (1.0 - step(0.3, 1.0 - COLOR.a));
			c *= 0.7;
		}
	}
	if (part == 1 && eye_glow > 0.0) {
		EMISSION = glow_col * eye_glow * (0.35 + 0.65 * smoothstep(0.2, 0.9, 1.0 - h * 280.0)) * (0.75 + 0.25 * sin(TIME * 2.3));
	}
	ALBEDO = c;
	ROUGHNESS = clamp(ro, 0.04, 1.0);
	METALLIC = me;
}
