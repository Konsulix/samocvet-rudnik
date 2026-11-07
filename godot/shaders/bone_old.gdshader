// The bone shader as it was before 7.11 (everything worked out everywhere): kept only so the admin's "Skull speedups: off"
// can measure the old cost on a phone against the new (bone.gdshader). Same picture.
// A skull's bone (SpecSkull): pale, smooth, mottled with age, stained brown in patches and down in the pits, hairline
// cracks and the zigzag sutures of the vault, the pits going black, soil where crystals broke through.
// Vertex colour: r = how open (1) or deep in a pit (0), g = ridge height, b = soil.
// Model coordinates (the skull ~1.3 tall, centred, face toward +Z) place the sutures.
shader_type spatial;
render_mode cull_disabled;
#include "res://shaders/opal.gdshaderinc"

uniform vec3 bone_col : source_color = vec3(0.80, 0.74, 0.62);
uniform vec3 stain_col : source_color = vec3(0.50, 0.36, 0.20);
uniform vec3 pit_col : source_color = vec3(0.20, 0.13, 0.08);
uniform vec3 soil_col : source_color = vec3(0.17, 0.12, 0.08);
uniform float age = 0.5;      // 0 clean white bone .. 1 old, brown, cracked
uniform float crack_k = 0.6;  // how many hairline cracks
uniform float suture_k = 0.8;
uniform vec3 sut_shift = vec3(0.0);   // where this skull runs its sutures: sagittal x, coronal z, lambdoid z
uniform float gloss = 0.3;    // handled smooth (polished) .. chalky
uniform float seed = 0.0;
uniform float cav_k = 1.0;
uniform float wear = 0.0;
uniform int skin = 0;         // 0 bone, 1 gilt (gold leaf over part), 2 gold (cast in gold), 3 kintsugi (stone mosaic on gold seams), 4 nacre
uniform float skin_k = 0.5;   // gilt: how much is covered; nacre: how much of the bone has turned
uniform vec3 gilt_dir = vec3(1.0, 0.2, 0.3);   // gilt: the side it covers
uniform float fire = 0.33;
uniform vec3 metal_col = vec3(0.95, 0.68, 0.28);   // cast metal: gold, silver, copper
uniform float metal_rough = 0.16;
uniform vec3 patina_col = vec3(0.25, 0.55, 0.45); // in the pits: verdigris on copper, black tarnish on silver
uniform float patina_k = 0.0;    // nacre: the hue of its fire (as ammolite: red 0, green 0.33, blue 0.6, violet 0.75)     // ridges rubbed lighter (a dark skull still reads as bone)

varying vec3 mp;

void vertex() {
	mp = VERTEX;
}

// 3D cells: distance to the border between the two nearest
float cell_edge(vec3 q) {
	vec3 c = floor(q);
	float d1 = 9.0, d2 = 9.0;
	for (int z = -1; z <= 1; z++) for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
		vec3 g = c + vec3(float(x), float(y), float(z));
		vec3 pt = g + vec3(h3(g), h3(g + 17.0), h3(g + 31.0)) * 0.8 + 0.1;
		float d = distance(pt, q);
		if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
	}
	return d2 - d1;
}

// 3D cells: x distance to the border between the two nearest, y the nearest one's random
vec2 cell3(vec3 q) {
	vec3 c = floor(q);
	float d1 = 9.0, d2 = 9.0, id = 0.0;
	for (int z = -1; z <= 1; z++) for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
		vec3 g = c + vec3(float(x), float(y), float(z));
		vec3 pt = g + vec3(h3(g), h3(g + 17.0), h3(g + 31.0)) * 0.8 + 0.1;
		float d = distance(pt, q);
		if (d < d1) { d2 = d1; d1 = d; id = h3(g + 53.0); } else if (d < d2) { d2 = d; }
	}
	return vec2(d2 - d1, id);
}

// a suture: a fine zigzag line where the plates of the vault met, s = signed distance from its course
float suture(float s, vec3 q) {
	float zz = (vn(q * 70.0) - 0.5) * 0.03 + (vn(q * 18.0) - 0.5) * 0.025;
	return 1.0 - smoothstep(0.0025, 0.006, abs(s + zz));
}

void fragment() {
	vec3 q = mp + seed;
	float open = COLOR.r;
	float cav = 1.0 - open;
	float soil = COLOR.b;
	float big = fbm(q * 2.2);
	float mot = fbm(q * 9.0);
	vec3 c = bone_col * (0.92 + mot * 0.16);
	// age: yellowing, brown blotches and darker grain
	c = mix(c, c * vec3(0.93, 0.82, 0.64), age);
	float blot = smoothstep(0.42, 0.7, big + cav * 0.3 + (vn(q * 30.0) - 0.5) * 0.12) * (0.2 + age * 0.8);
	c = mix(c, stain_col * (0.7 + mot * 0.6), blot * 0.85);
	// weathering: soft streaks of grime running down, a few pits eaten into the surface (no even speckle)
	float streak = fbm(vec3(q.x * 9.0, q.y * 1.5, q.z * 9.0) + 3.0);
	c *= 1.0 - smoothstep(0.5, 0.75, streak) * (0.1 + age * 0.25);
	vec2 pc = cell3(q * 11.0);
	float pore = step(0.84, pc.y) * smoothstep(0.2, 0.34, pc.x) * smoothstep(0.5, 0.65, fbm(q * 2.0 + 21.0)) * (0.3 + age * 0.7);
	// down in the pits: brown, then black
	// (the walls of the sockets and the nose stay lit, browning inward; only the very bottom goes dark)
	c = mix(c, pit_col * (0.8 + mot * 0.5), smoothstep(0.2, 0.75, cav * cav_k) * 0.7);
	c *= mix(1.0, 0.25, smoothstep(0.6, 1.0, cav * cav_k));
	// hairline cracks, in patches
	float e = cell_edge(q * 3.2 + vec3(fbm(q * 5.0), fbm(q * 5.0 + 9.0), 0.0) * 0.8);
	float crack = (1.0 - smoothstep(0.0, 0.03, e)) * smoothstep(0.5, 0.62, fbm(q * 1.6 + 7.0)) * crack_k * (0.4 + age * 0.6) * open;
	// the sutures of the vault: sagittal down the middle, coronal across the front, lambdoid round the back
	float vault = smoothstep(0.12, 0.3, mp.y);
	float zc = 0.13 + sut_shift.y, zl = -0.36 + sut_shift.z;
	float sag = suture(mp.x - sut_shift.x - (vn(vec3(mp.z * 3.0, seed, 0.0)) - 0.5) * 0.03, q) * step(zl, mp.z) * step(mp.z, zc - mp.y * 0.05);
	float cor = suture(mp.z - zc + (0.66 - mp.y) * 0.18, q) * smoothstep(-0.05, 0.08, mp.y);
	float lam = suture(mp.z - zl - abs(mp.x) * 0.55 + (0.66 - mp.y) * 0.25, q) * smoothstep(-0.12, 0.0, mp.y);
	// fused here and there: the lines break off in places
	float fused = smoothstep(0.38, 0.55, fbm(q * 4.0 + 13.0));
	float sut = max(sag * vault, max(cor, lam)) * suture_k * open * fused;
	c = mix(c, pit_col * 0.7, max(crack, sut * 0.85));
	c = mix(c, pit_col * 0.5, pore * 0.7);
	// worn: the bone shows paler along its ridges and bumps
	c = mix(c, c * 2.2 + vec3(0.03), wear * smoothstep(0.55, 0.95, COLOR.g + (mot - 0.5) * 0.3) * open);
	// soil where crystals broke through
	c = mix(c, soil_col * (0.6 + mot * 0.8), soil);
	float rough = mix(0.45 + (1.0 - gloss) * 0.4, 1.0, max(cav, soil));
	// wet where water runs (vertex alpha below 1): darker, glossy, a little green slime in the wettest part
	float wet = 1.0 - COLOR.a;
	c = mix(c, c * 0.42, wet);
	c = mix(c, c * vec3(0.7, 0.9, 0.6), smoothstep(0.6, 1.0, wet) * smoothstep(0.4, 0.7, fbm(q * 14.0)) * 0.6);
	rough = mix(rough, 0.12, wet);
	float metal = 0.0;
	float spec = 0.3 * open;
	// a faint relief: the grain, the cracks and sutures sunk in
	float h = mot * 0.6 + fbm(q * 40.0) * 0.25 + fbm(q * 4.0) * 0.5 - max(crack, sut) * 0.7 - pore * 1.2 + soil * vn(q * 60.0) * 0.8;
	vec3 gold = vec3(0.95, 0.68, 0.28);
	float fr = 1.0 - abs(dot(NORMAL, VIEW));
	if (skin == 1) {
		// gold leaf over one side: a ragged, flaking edge, bone (worn dark) showing through cracks in the leaf
		float side = dot(normalize(mp + vec3(0.0, -0.1, 0.0)), normalize(gilt_dir)) + (fbm(q * 3.0) - 0.5) * 0.9 + (vn(q * 18.0) - 0.5) * 0.25;
		float thr = 0.85 - skin_k * 0.7;
		float leaf = smoothstep(0.0, 0.03, side - thr);
		// (the leaf is whole; only a thin band at its edge flakes)
		leaf *= 1.0 - smoothstep(0.62, 0.7, vn(q * 26.0)) * 0.9 * (1.0 - smoothstep(0.0, 0.06, side - thr));
		vec3 g = gold * (0.85 + 0.2 * fbm(q * 12.0)) * mix(1.0, 0.6, smoothstep(0.4, 1.0, cav));
		c = mix(c, g, leaf);
		metal = leaf * 0.95;
		rough = mix(rough, 0.32 + 0.08 * vn(q * 30.0), leaf);
		// the edge of the leaf stands a little proud of the bone
		h += (1.0 - smoothstep(0.0, 0.05, side - thr)) * leaf * 1.2;
		spec = mix(spec, 0.5, leaf);
		h += leaf * vn(q * 50.0) * 0.12;
	} else if (skin == 2) {
		// cast in gold: polished metal, darker deep in the pits, the old bone's detail just a ripple in it
		c = metal_col * mix(1.0, 0.45, cav) * (0.9 + 0.12 * mot);
		// tarnish / patina gathered in the hollows and seams
		float pat = clamp(smoothstep(0.25, 0.7, cav + (fbm(q * 7.0) - 0.5) * 0.5) + max(crack, sut) * 0.6, 0.0, 1.0) * patina_k;
		c = mix(c, patina_col * (0.8 + 0.4 * mot), pat);
		metal = 1.0 - pat * 0.9;
		rough = mix(metal_rough + cav * 0.25, 0.8, pat);
		spec = 0.5;
		h = mot * 0.15 - max(crack, sut) * 0.3;
	} else if (skin == 3) {
		// kintsugi: a mosaic of polished stone pieces — carnelian, opal, amethyst, moonstone — set in raised gold seams
		vec3 wq = q * 4.2 + vec3(fbm(q * 3.0), fbm(q * 3.0 + 5.0), fbm(q * 3.0 + 9.0)) * 0.6;
		vec2 cc = cell3(wq);
		float seam = 1.0 - smoothstep(0.03, 0.07, cc.x);
		float id = cc.y;
		vec3 st;
		if (id < 0.35) st = mix(vec3(0.22, 0.03, 0.03), vec3(0.55, 0.14, 0.08), fbm(q * 9.0 + id * 20.0));     // carnelian
		else if (id < 0.55) st = mix(vec3(0.62, 0.58, 0.62), vec3(0.4, 0.36, 0.44), fbm(q * 7.0 + id * 20.0));  // opal / moonstone
		else if (id < 0.75) st = mix(vec3(0.1, 0.05, 0.22), vec3(0.32, 0.18, 0.45), fbm(q * 8.0 + id * 20.0));  // amethyst
		else st = mix(vec3(0.5, 0.2, 0.14), vec3(0.75, 0.42, 0.32), fbm(q * 8.0 + id * 20.0));                  // rose / peach
		// play of colour: a rainbow sheen sliding with the view, strongest on the opals
		float play = (id >= 0.35 && id < 0.55 ? 0.8 : 0.0) * (0.3 + 0.7 * fr);
		vec3 rb = hue(fract(id * 3.0 + fr * 1.3 + fbm(q * 5.0) * 0.8));
		st = mix(st, st * 0.6 + rb * st * 1.4 + rb * 0.05, play * 0.5);
		// the stone's own figure: carnelian bands, moonstone cloud, amethyst zones
		st *= 0.75 + 0.5 * smoothstep(0.3, 0.7, fbm(q * 18.0 + id * 40.0));
		st *= 0.62;
		c = mix(st * mix(1.0, 0.5, cav), gold * (0.85 + 0.25 * vn(q * 40.0)), seam);
		metal = seam;
		rough = mix(0.5, 0.22, seam);
		spec = mix(0.18, 0.5, seam);
		h = seam * 0.9 + (1.0 - seam) * fbm(q * 30.0) * 0.08;
	} else if (skin == 4) {
		// nacre: the bone turned to mother-of-pearl in patches, as an ammonite's shell — a thin-film rainbow that
		// slides with the view, in plates with fine dark cracks between
		float k = smoothstep(0.62 - skin_k * 0.4, 0.7 - skin_k * 0.4, fbm(q * 2.4 + 11.0)) * open;
		vec2 pl = cell3(q * 5.0 + vec3(fbm(q * 4.0)) * 0.5);
		// each plate a little off the stone's own fire, sliding a step through the spectrum as it turns
		float th = fire + (pl.y - 0.5) * 0.22 + (fr - 0.3) * 0.35 + (fbm(q * 8.0) - 0.5) * 0.12;
		vec3 film = hue(fract(th));
		// a dark pearly ground, the fire flaring on the plates that catch the eye at the right angle
		float flare = pow(0.5 + 0.5 * sin((pl.y * 6.28) + fr * 7.0 + fbm(q * 3.0) * 4.0), 2.0);
		vec3 nac = vec3(0.07, 0.065, 0.075) * (0.7 + 0.6 * fbm(q * 14.0)) + film * film * (0.08 + 0.85 * flare) * (0.5 + 0.5 * fr);
		// the "dragon skin": fine dark cracks between the plates
		nac = mix(nac, nac * 0.25, (1.0 - smoothstep(0.0, 0.03, pl.x)) * 0.85);
		c = mix(c, nac, k);
		rough = mix(rough, 0.32, k);
		spec = mix(spec, 0.25, k);
		h += k * (pl.x * 0.4);
	}
	// the inside of the vault, seen through a break: dim bone
	if (!FRONT_FACING) c = c * vec3(0.32, 0.28, 0.24);
	ALBEDO = c;
	METALLIC = metal;
	ROUGHNESS = rough;
	SPECULAR = mix(spec, 0.7, wet * float(skin == 0 || skin == 4 || skin == 1));
	NORMAL = bump(NORMAL, VERTEX, h * 0.004, 1.0);
}
