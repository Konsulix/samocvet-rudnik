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

varying vec3 v_op;
varying vec3 v_no;

float h3(vec3 p) { p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float vn(vec3 x) {
	vec3 i = floor(x), f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h3(i), h3(i + vec3(1, 0, 0)), f.x), mix(h3(i + vec3(0, 1, 0)), h3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(h3(i + vec3(0, 0, 1)), h3(i + vec3(1, 0, 1)), f.x), mix(h3(i + vec3(0, 1, 1)), h3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
float fbm(vec3 p) { return vn(p) * 0.5 + vn(p * 2.03) * 0.25 + vn(p * 4.01) * 0.125 + vn(p * 8.02) * 0.0625; }
vec3 hue(float h) {
	vec3 c = clamp(abs(fract(h + vec3(1.0, 0.6667, 0.3333)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
	return c * c * (3.0 - 2.0 * c);
}
// cells: x = distance to the nearest centre, y = to the edge between cells, z = the cell's own random
vec3 vor2(vec2 q) {
	vec2 c = floor(q);
	float d1 = 9.0, d2 = 9.0, id = 0.0;
	for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
		vec2 g = c + vec2(float(x), float(y));
		vec2 pt = g + vec2(h3(vec3(g, 1.0)), h3(vec3(g, 7.0))) * 0.8 + 0.1;
		float d = distance(pt, q);
		if (d < d1) { d2 = d1; d1 = d; id = h3(vec3(g, 13.0)); } else if (d < d2) { d2 = d; }
	}
	return vec3(d1, d2 - d1, id);
}
vec3 bump(vec3 n, vec3 pos, float h, float k) {
	vec3 dpx = dFdxFine(pos), dpy = dFdyFine(pos);
	float dhx = dFdxFine(h), dhy = dFdyFine(h);
	vec3 r1 = cross(dpy, n), r2 = cross(n, dpx);
	float det = dot(dpx, r1);
	vec3 g = sign(det) * (dhx * r1 + dhy * r2);
	return normalize(abs(det) * n - g * k);
}
vec4 tri(sampler2D t, vec3 q, vec3 w) {
	return texture(t, q.yz) * w.x + texture(t, q.xz) * w.y + texture(t, q.xy) * w.z;
}

void vertex() {
	v_op = VERTEX;
	v_no = NORMAL;
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
		float lens = lens_on * (1.0 - smoothstep(0.86, 0.97, r)) * step(0.08, UV.y) * step(UV.y, 0.92);
		// each lens its own dome, tipped its own way: some face the lamp as the find turns, others go dark
		vec2 tilt = (vec2(id, h3(vec3(cell, seed + 3.0))) - 0.5) * 1.2;
		float dome = sqrt(max(0.0, 1.0 - r * r)) + dot(d, tilt) * 0.5;
		h = lens * dome * 0.0035;
		vec3 lc = mix(vec3(0.02, 0.016, 0.012), base_col * 0.4, 0.2) * (0.6 + 0.8 * id);
		vec3 rim = mix(dark_col, base_col, 0.6) * (0.75 + 0.3 * fbm(p * 120.0));
		c = mix(rim, lc, lens);
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
		vec3 gr = vor2(b * 95.0 + seed);
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
		h = tub * 0.0022 + grain * 0.0004 + (wear - 0.5) * 0.0006 + (sl - 0.4) * 0.0012 * scan_k - pits * 0.0005;
		// colour: darker down in the furrows, lighter and polished on the high points the rock wore
		c = mix(base_col, dark_col, furrow * 0.65);
		c *= 0.82 + 0.3 * fbm(vec3(b * 9.0, seed + 2.0));
		c *= mix(1.0, 0.45 + sl * 1.6, scan_k);
		c = mix(c, c * 0.6, pits * 0.6);
		float high = axis * (1.0 - furrow) * smoothstep(0.45, 0.75, wear);
		c = mix(c, c * 1.35 + 0.02, high * 0.5 + tub * 0.35);
		ro = rough_k * (1.0 - high * 0.4) * (0.85 + 0.3 * wear) * mix(1.0, 0.7 + sl, scan_k * 0.6);
		// pyrite: a tarnish in patches, blue and purple and gold
		float tar = film_k * smoothstep(0.45, 0.7, fbm(vec3(b * 6.0, seed + 9.0)));
		vec3 film = hue(0.55 + fbm(vec3(b * 14.0, seed)) * 0.5 + (1.0 - abs(dot(n, VIEW))) * 0.3);
		c = mix(c, c * 0.5 + film * length(c) * 0.7, tar);
		// its rock left in the furrows and round the edge, matt
		float dirt = dirt_k * smoothstep(0.55, 0.95, furrow + (fbm(vec3(b * 30.0, seed + 5.0)) - 0.5) * 0.7);
		// the underside (seen only through gaps): the shell's own dark
		c = mix(c, dark_col * 0.7, 1.0 - COLOR.a);
		vec3 tw = pow(abs(normalize(v_no)), vec3(4.0));
		tw /= tw.x + tw.y + tw.z;
		vec3 rc = rock_col * (0.6 + 0.8 * tri(rock_tex, p * 2.0, tw).rgb);
		c = mix(c, rc, dirt);
		ro = mix(ro, 0.95, dirt);
		me = mix(me, 0.0, dirt);
		NORMAL = bump(n, VERTEX, h, 1.0);
	}
	ALBEDO = c;
	ROUGHNESS = clamp(ro, 0.04, 1.0);
	METALLIC = me;
}
