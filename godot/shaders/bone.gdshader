// A skull's bone (SpecSkull): pale, smooth, mottled with age, stained brown in patches and down in the pits, hairline
// cracks and the zigzag sutures of the vault, the pits going black, soil where crystals broke through.
// Vertex colour: r = how open (1) or deep in a pit (0), g = ridge height, b = soil.
// Model coordinates (the skull ~1.3 tall, centred, face toward +Z) place the sutures.
// (cost on a phone: the heavy parts — the cells of the cracks, pores and nacre plates, the sutures' noise — are worked
// out only where they can show, and the mosaic and the cast metal skip the bone they paint over; the picture is the
// same pixel for pixel as when everything was worked out everywhere.)
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
uniform int skin = 0;         // 0 bone, 1 gilt (gold leaf over part), 2 gold (cast in gold), 3 kintsugi (stone mosaic on gold seams), 4 nacre,
                              // 5 agate (banded), 6 opal, 7 pyrite, 8 geode (black crust, a druse where it broke)
uniform float deathless = 0.0;   // the legend "deathless": light running along the cracks and sutures, as if they healed
uniform vec3 life_col = vec3(0.45, 1.0, 0.75);
uniform float skin_k = 0.5;   // gilt: how much is covered; nacre: how much of the bone has turned
uniform vec3 gilt_dir = vec3(1.0, 0.2, 0.3);   // gilt: the side it covers
uniform float fire = 0.33;
uniform vec3 metal_col = vec3(0.95, 0.68, 0.28);   // cast metal: gold, silver, copper
uniform float metal_rough = 0.16;
uniform vec3 patina_col = vec3(0.25, 0.55, 0.45); // in the pits: verdigris on copper, black tarnish on silver
uniform vec3 wet_col = vec3(1.0);   // what wet bone turns (a scarlet spring stains it red)
uniform float patina_k = 0.0;    // nacre: the hue of its fire (as ammolite: red 0, green 0.33, blue 0.6, violet 0.75)     // ridges rubbed lighter (a dark skull still reads as bone)

uniform int mosaic_pal = 0;   // kintsugi: 0 carnelian, opal, amethyst, peach; 1 lapis, turquoise, labradorite, chrysocolla
uniform int agate_pal = 0;    // agate: 0 cream, carnelian, rust, smoke; 1 rhodochrosite pinks with grey and white
uniform vec3 druse_col : source_color = vec3(0.45, 0.85, 0.3);   // skin 10: the sugar druse's colour
uniform float lava = 0.0;         // a beast's legend: the bone dark basalt, lava breathing in its cracks
uniform float ember = 0.0;        // a beast's legend: phoenix feathers smouldering
uniform float ember_flare = 0.0;  // ... and flaring up once a round
uniform float burn_front = 2.0;   // phoenix: feathers placed past this (0 the back of the head .. 1 the nose) have burnt
uniform float regrow_front = -1.0; // ... and those placed before this have grown again
uniform int feather_pal = 0;  // skin 9: 0 magpie, 1 starling, 2 pheasant, 3 peacock, 4 owl
// skin 9: how far the feathers reach — a feather grows where fe_field() of its place is over fe_t (SpecSkull._feather_cover
// picks fe_t so that a share feather_k of the head is covered); the head's box: fe_c, fe_s
uniform vec3 fe_c = vec3(0.0);
uniform vec3 fe_s = vec3(1.0);
uniform float fe_t = -10.0;
uniform float fe_ph = 0.0;
// (skin 9: feathers — an iridescent cloak of overlapping feathers; skin 10: a sugar druse crusting the bone in patches)

varying vec3 mp;
varying vec3 mn;

void vertex() {
	mp = VERTEX;
	mn = NORMAL;
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
// (the zigzag moves the line by under 0.028 and it is gone 0.006 from it: farther off it is zero, no noise needed)
float suture(float s, vec3 q) {
	if (abs(s) > 0.04) return 0.0;
	float zz = (vn(q * 70.0) - 0.5) * 0.03 + (vn(q * 18.0) - 0.5) * 0.025;
	return 1.0 - smoothstep(0.0025, 0.006, abs(s + zz));
}

// where on the head feathers grow first: the crown and the back of the head, forward and down from there, a ragged
// edge (the same formula in SpecSkull.fe_field)
// where a feather sits from the back of the head (0) to the nose (1): the phoenix burns and regrows by it
float fe_pz(vec3 p) {
	return clamp((p.z - fe_c.z) / fe_s.z + 0.5, 0.0, 1.0);
}

float fe_field(vec3 p) {
	vec3 u = (p - fe_c) / fe_s;
	return u.y - u.z * 0.6 - abs(u.x) * 0.25 + 0.1 * sin(u.x * 9.0 + fe_ph) + 0.09 * sin(u.z * 11.0 + fe_ph * 1.7)
		+ 0.07 * sin(u.y * 15.0 + u.x * 5.0 + fe_ph * 2.3);
}

void fragment() {
	vec3 q = mp + seed;
	float open = COLOR.r;
	float cav = 1.0 - open;
	float soil = COLOR.b;
	float wet = 1.0 - COLOR.a;
	float fr = 1.0 - abs(dot(NORMAL, VIEW));
	vec3 gold = vec3(0.95, 0.68, 0.28);
	vec3 c;
	float rough;
	float metal = 0.0;
	float spec;
	float h;
	float glowline = 0.0;
	float feather_rim = 0.0;
	vec3 emis = vec3(0.0);
	if (skin == 3) {
		// kintsugi: a mosaic of polished stone pieces — carnelian, opal, amethyst, moonstone — set in raised gold seams
		vec3 wq = q * (mosaic_pal == 1 ? 3.1 : 4.2) + vec3(fbm(q * 3.0), fbm(q * 3.0 + 5.0), fbm(q * 3.0 + 9.0)) * 0.6;
		vec2 cc = cell3(wq);
		float seam = 1.0 - smoothstep(0.03, 0.07, cc.x);
		float id = cc.y;
		vec3 st;
		if (id < 0.35) st = mix(vec3(0.22, 0.03, 0.03), vec3(0.55, 0.14, 0.08), fbm(q * 9.0 + id * 20.0));     // carnelian
		else if (id < 0.55) st = mix(vec3(0.62, 0.58, 0.62), vec3(0.4, 0.36, 0.44), fbm(q * 7.0 + id * 20.0));  // opal / moonstone
		else if (id < 0.75) st = mix(vec3(0.1, 0.05, 0.22), vec3(0.32, 0.18, 0.45), fbm(q * 8.0 + id * 20.0));  // amethyst
		else st = mix(vec3(0.5, 0.2, 0.14), vec3(0.75, 0.42, 0.32), fbm(q * 8.0 + id * 20.0));                  // rose / peach
		if (mosaic_pal == 1) {
			float f9 = fbm(q * 9.0 + id * 20.0);
			if (id < 0.4) {
				// lapis: deep ultramarine, white calcite streaks, gold pyrite flecks
				st = mix(vec3(0.03, 0.06, 0.32), vec3(0.1, 0.2, 0.62), f9);
				st = mix(st, vec3(0.7, 0.74, 0.8), smoothstep(0.62, 0.72, fbm(q * vec3(4.0, 22.0, 4.0) + id * 9.0)) * 0.6);
				st = mix(st, gold * 1.2, step(0.86, vn(q * 70.0 + id * 30.0)) * 0.9);
			} else if (id < 0.68) {
				// turquoise: sky blue-green, a web of dark matrix
				st = mix(vec3(0.12, 0.5, 0.52), vec3(0.32, 0.72, 0.7), f9);
				st = mix(st, vec3(0.16, 0.1, 0.06), (1.0 - smoothstep(0.0, 0.05, cell3(q * 14.0 + id * 7.0).x)) * 0.8);
			} else if (id < 0.86) {
				// labradorite: grey stone, a blue-teal flash that comes and goes as it turns
				float lf = pow(0.5 + 0.5 * sin(id * 40.0 + fr * 8.0 + fbm(q * 4.0) * 5.0), 3.0);
				st = mix(vec3(0.16, 0.18, 0.2) * (0.7 + 0.6 * f9), vec3(0.1, 0.45, 0.75), lf * 0.85);
			} else {
				// chrysocolla: teal with darker blue
				st = mix(vec3(0.02, 0.3, 0.36), vec3(0.08, 0.5, 0.55), f9);
			}
		}
		// play of colour: a rainbow sheen sliding with the view, strongest on the opals
		float play = (mosaic_pal == 0 && id >= 0.35 && id < 0.55 ? 0.8 : 0.0) * (0.3 + 0.7 * fr);
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
	} else {
		float mot = fbm(q * 9.0);
		// hairline cracks, in patches (the cells only inside a patch)
		float crack = 0.0;
		float cpatch = smoothstep(0.5, 0.62, fbm(q * 1.6 + 7.0));
		if (cpatch * crack_k * open > 0.0) {
			float e = cell_edge(q * 3.2 + vec3(fbm(q * 5.0), fbm(q * 5.0 + 9.0), 0.0) * 0.8);
			crack = (1.0 - smoothstep(0.0, 0.03, e)) * cpatch * crack_k * (0.4 + age * 0.6) * open;
		}
		// the sutures of the vault: sagittal down the middle, coronal across the front, lambdoid round the back
		float sut = 0.0;
		if (suture_k * open > 0.0) {
			float vault = smoothstep(0.12, 0.3, mp.y);
			float zc = 0.13 + sut_shift.y, zl = -0.36 + sut_shift.z;
			float sag = 0.0;
			if (mp.z >= zl && mp.z <= zc - mp.y * 0.05)
				sag = suture(mp.x - sut_shift.x - (vn(vec3(mp.z * 3.0, seed, 0.0)) - 0.5) * 0.03, q);
			float cor = suture(mp.z - zc + (0.66 - mp.y) * 0.18, q) * smoothstep(-0.05, 0.08, mp.y);
			float lam = suture(mp.z - zl - abs(mp.x) * 0.55 + (0.66 - mp.y) * 0.25, q) * smoothstep(-0.12, 0.0, mp.y);
			float line = max(sag * vault, max(cor, lam));
			// fused here and there: the lines break off in places
			if (line > 0.0) sut = line * suture_k * open * smoothstep(0.38, 0.55, fbm(q * 4.0 + 13.0));
		}
		glowline = max(crack, sut);
		if (skin == 2) {
			// cast in gold: polished metal, darker deep in the pits, the old bone's detail just a ripple in it
			c = metal_col * mix(1.0, 0.45, cav) * (0.9 + 0.12 * mot);
			// tarnish / patina gathered in the hollows and seams
			float pat = clamp(smoothstep(0.25, 0.7, cav + (fbm(q * 7.0) - 0.5) * 0.5) + max(crack, sut) * 0.6, 0.0, 1.0) * patina_k;
			c = mix(c, patina_col * (0.8 + 0.4 * mot), pat);
			metal = 1.0 - pat * 0.9;
			rough = mix(metal_rough + cav * 0.25, 0.8, pat);
			spec = 0.5;
			h = mot * 0.15 - max(crack, sut) * 0.3;
		} else {
			float big = fbm(q * 2.2);
			c = bone_col * (0.92 + mot * 0.16);
			// age: yellowing, brown blotches and darker grain
			c = mix(c, c * vec3(0.93, 0.82, 0.64), age);
			float blot = smoothstep(0.42, 0.7, big + cav * 0.3 + (vn(q * 30.0) - 0.5) * 0.12) * (0.2 + age * 0.8);
			c = mix(c, stain_col * (0.7 + mot * 0.6), blot * 0.85);
			// weathering: soft streaks of grime running down, a few pits eaten into the surface (no even speckle)
			float streak = fbm(vec3(q.x * 9.0, q.y * 1.5, q.z * 9.0) + 3.0);
			c *= 1.0 - smoothstep(0.5, 0.75, streak) * (0.1 + age * 0.25);
			// pores (the cells only where pores can be)
			float pore = 0.0;
			float pm = smoothstep(0.5, 0.65, fbm(q * 2.0 + 21.0));
			if (pm > 0.0) {
				vec2 pc = cell3(q * 11.0);
				pore = step(0.84, pc.y) * smoothstep(0.2, 0.34, pc.x) * pm * (0.3 + age * 0.7);
			}
			// down in the pits: brown, then black
			// (the walls of the sockets and the nose stay lit, browning inward; only the very bottom goes dark)
			c = mix(c, pit_col * (0.8 + mot * 0.5), smoothstep(0.2, 0.75, cav * cav_k) * 0.7);
			c *= mix(1.0, 0.25, smoothstep(0.6, 1.0, cav * cav_k));
			c = mix(c, pit_col * 0.7, max(crack, sut * 0.85));
			c = mix(c, pit_col * 0.5, pore * 0.7);
			// worn: the bone shows paler along its ridges and bumps
			c = mix(c, c * 2.2 + vec3(0.03), wear * smoothstep(0.55, 0.95, COLOR.g + (mot - 0.5) * 0.3) * open);
			// soil where crystals broke through
			c = mix(c, soil_col * (0.6 + mot * 0.8), soil);
			rough = mix(0.45 + (1.0 - gloss) * 0.4, 1.0, max(cav, soil));
			// wet where water runs (vertex alpha below 1): darker, glossy, a little green slime in the wettest part
			c = mix(c, c * 0.42 * wet_col, wet);
			if (wet > 0.6) c = mix(c, c * vec3(0.7, 0.9, 0.6), smoothstep(0.6, 1.0, wet) * smoothstep(0.4, 0.7, fbm(q * 14.0)) * 0.6);
			rough = mix(rough, 0.12, wet);
			spec = 0.3 * open;
			// a faint relief: the grain, the cracks and sutures sunk in
			float f4 = fbm(q * 4.0);
			h = mot * 0.6 + fbm(q * 40.0) * 0.25 + f4 * 0.5 - max(crack, sut) * 0.7 - pore * 1.2 + soil * vn(q * 60.0) * 0.8;
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
			} else if (skin == 4) {
				// nacre: the bone turned to mother-of-pearl in patches, as an ammonite's shell — a thin-film rainbow that
				// slides with the view, in plates with fine dark cracks between (the plates only where it has turned)
				float k = smoothstep(0.62 - skin_k * 0.4, 0.7 - skin_k * 0.4, fbm(q * 2.4 + 11.0)) * open;
				if (k > 0.0) {
					vec2 pl = cell3(q * 5.0 + vec3(f4) * 0.5);
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
			} else if (skin == 5) {
				// agate: the bone turned to banded chalcedony — bands following the head's shape, warped, cream, honey,
				// rust and smoke, polished, a little translucent at the thin edges
				float t = length(mp * vec3(1.0, 1.15, 0.95)) * 34.0 + fbm(q * 1.8) * 7.0 + fbm(q * 6.0) * 1.2;
				float bnd = fract(t);
				float sel = fract(floor(t) * 0.618 + skin_k);
				// four colours of band: cream, carnelian, rust-brown, smoke
				vec3 ag = sel < 0.3 ? vec3(0.86, 0.78, 0.62) : sel < 0.55 ? vec3(0.78, 0.3, 0.08) : sel < 0.8 ? vec3(0.38, 0.19, 0.08) : vec3(0.42, 0.45, 0.5);
				if (agate_pal == 1) ag = sel < 0.35 ? vec3(0.78, 0.16, 0.38) : sel < 0.55 ? vec3(0.95, 0.45, 0.6) : sel < 0.72 ? vec3(0.36, 0.33, 0.42) : sel < 0.84 ? vec3(0.92, 0.88, 0.9) : vec3(0.55, 0.06, 0.24);
				// (stone, not plastic: muted, fine growth lines inside each band, a waxy translucent milkiness that
				// varies, crystal grain, a few pale quartz-filled hollows)
				ag = mix(ag, agate_pal == 1 ? vec3(0.8, 0.6, 0.66) : vec3(0.62, 0.55, 0.47), agate_pal == 1 ? 0.12 : 0.25);
				ag *= 0.8 + 0.25 * smoothstep(0.1, 0.9, bnd) + (sin(t * 38.0) * 0.5 + 0.5) * 0.08;
				ag = mix(ag, vec3(0.88, 0.84, 0.76), (1.0 - smoothstep(0.0, 0.05, bnd)) * 0.55);
				ag = mix(ag, ag * 1.25 + vec3(0.05), smoothstep(0.45, 0.8, fbm(q * 4.0 + 3.0)) * 0.35);
				ag *= 0.88 + 0.24 * vn(q * 120.0);
				c = mix(ag * mix(1.0, 0.55, cav), pit_col * 0.5, max(crack, sut) * 0.5);
				rough = mix(0.34, 0.7, cav) + vn(q * 40.0) * 0.12;
				spec = 0.32;
				h = bnd * 0.25 + vn(q * 90.0) * 0.25 - max(crack, sut) * 0.4;
			} else if (skin == 6) {
				// opal: the bone become precious opal — a dark body, play of colour in patches that flash and change as
				// it turns (pinfire small, harlequin larger), the pits dull potch
				vec2 pl = cell3(q * 9.0 + vec3(f4) * 0.6);
				vec2 pl2 = cell3(q * 3.5 + 7.0);
				float th = pl.y * 0.9 + pl2.y * 0.5 + fr * 1.4 + skin_k;
				vec3 film = hue(fract(th));
				float flash = pow(0.5 + 0.5 * sin(pl.y * 40.0 + fr * 9.0 + pl2.y * 6.0), 6.0);
				vec3 body = vec3(0.03, 0.035, 0.05) * (0.8 + 0.4 * fbm(q * 5.0));
				vec3 op = body + film * film * (0.02 + 1.2 * flash);
				c = mix(op, vec3(0.32, 0.3, 0.28) * (0.8 + 0.4 * mot), smoothstep(0.35, 0.8, cav));
				rough = mix(0.08, 0.6, cav);
				spec = 0.6;
				h = pl.x * 0.25 - max(crack, sut) * 0.3;
			} else if (skin == 7) {
				// pyrite: the bone replaced by fool's gold — brassy metal in fine grains, little cube faces catching
				// the light, rust-brown limonite in the pits and patches
				vec2 gr = cell3(q * 26.0);
				float face = step(0.6, fract(gr.y * 7.0 + fr * 2.0));
				vec3 py = vec3(0.72, 0.58, 0.26) * (0.7 + 0.45 * gr.y) * (0.85 + 0.3 * face) * (1.0 - (1.0 - smoothstep(0.0, 0.06, gr.x)) * 0.5);
				float lim = clamp(smoothstep(0.55, 0.8, fbm(q * 3.5 + 4.0)) + smoothstep(0.3, 0.8, cav), 0.0, 1.0);
				c = mix(py, vec3(0.36, 0.2, 0.08) * (0.7 + 0.5 * mot), lim);
				metal = 1.0 - lim;
				rough = mix(0.28 - face * 0.12, 0.9, lim);
				spec = 0.5;
				h = gr.x * 0.4 - max(crack, sut) * 0.4 + lim * 0.3;
			} else if (skin == 8) {
				// a geode: the skull in a black basalt crust, pocked with gas holes; where the crust broke away, a druse of
				// tiny violet crystals sparkles (each cell a facet tilted its own way)
				// (where the crust broke: the builder's own mask, in UV.x — the same places as the pits and crystals)
				float brk = smoothstep(0.35, 0.6, UV.x);
				vec2 ves = cell3(q * 14.0);
				vec3 crust = vec3(0.016, 0.015, 0.014) * (0.7 + 0.6 * fbm(q * 10.0));   // (linear: near black)
				crust *= 1.0 - smoothstep(0.75, 0.95, ves.y) * smoothstep(0.35, 0.05, length(vec2(ves.x)) ) * 0.0 + 0.0;
				crust *= 0.85 + 0.3 * fbm(q * 30.0);
				// (down in the pit, under the crystals: dark, a dull violet, a spark here and there — the crystals do the rest)
				vec2 dz = cell3(q * 40.0);
				float glint = pow(0.5 + 0.5 * sin(dz.y * 60.0 + fr * 14.0), 16.0) * step(0.7, dz.y);
				vec3 dru = vec3(0.05, 0.02, 0.09) * (0.6 + 0.8 * fbm(q * 18.0)) + vec3(0.7, 0.6, 1.0) * glint * 0.5;
				// a white chalcedony rim where the crust broke
				float rim = smoothstep(0.24, 0.34, UV.x) * (1.0 - brk);
				c = mix(mix(crust, vec3(0.75, 0.73, 0.78), rim), dru, brk);
				rough = mix(0.95, 0.12, brk);
				spec = mix(0.15, 0.7, brk);
				h = mix(fbm(q * 18.0) * 0.4, fbm(q * 30.0) * 0.4, brk) + rim * 0.4;
			}
		}
	}
	if (skin == 9) {
		// feathers: a cloak of small contour feathers growing from the snout back over the head, as on a bird — each
		// a soft rounded vane on a shaft, the one in front lying over the root of the one behind (only tips show), its
		// edge frayed, a shadow where the next lies over it. Matte barbs; the gloss (magpie, starling, peacock) only
		// shows as the head turns. Grown in 3D cells round the head (no projection, no seams): each cell's feather is
		// laid along the surface, pointing back
		vec3 n0 = normalize(mn);
		vec3 back = vec3(0.0, 0.0, -1.0);
		vec3 F = back - n0 * dot(back, n0);
		// (on the back of the head and the snout tip, where "back" is along the normal: pointing down instead)
		vec3 F2 = vec3(0.0, -1.0, 0.0) - n0 * dot(vec3(0.0, -1.0, 0.0), n0);
		F = normalize(mix(F2, F, smoothstep(0.15, 0.45, length(F))) + vec3(1e-4));
		vec3 S = cross(n0, F);
		float sc = 9.5;
		vec3 fq = mp * sc + vec3(fbm(q * 2.2), fbm(q * 2.2 + 4.0), fbm(q * 2.2 + 8.0)) * 0.5;
		vec3 base = floor(fq);
		float L = 1.5;          // a feather's length and width, in cells (centred on its cell's point: within reach of the search)
		float W = 1.05;
		float top = -1e9;
		vec2 loc = vec2(0.0, 0.0);
		float fid = 0.0;
		float fe_fire = 0.0;
		float fe_fresh = 0.0;
		for (int z = -1; z <= 1; z++) for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
			vec3 g = base + vec3(float(x), float(y), float(z));
			vec3 cen = g + vec3(h3(g), h3(g + 17.0), h3(g + 31.0)) * 0.8 + 0.1;
			vec3 d = fq - cen;
			float k = 0.8 + 0.4 * h3(g + 5.0);
			float ly = dot(d, F) / (L * k) + 0.5;
			float lx = (dot(d, S) / (W * 0.5 * k) + (h3(g + 9.0) - 0.5) * 0.5 * ly);
			float r = lx * lx + (ly - 0.5) * (ly - 0.5) * 4.0;
			// (the one whose root is furthest forward lies on top)
			float front = dot(cen, -F) + h3(g + 3.0) * 0.4;
			// (only feathers rooted where the cloak reaches: its edge runs feather by feather)
			// (the phoenix: a feather catching fire shrinks as it burns; one growing again swells to its size)
			float pz = fe_pz(cen / sc);
			float gone = step(burn_front, pz) * (1.0 - step(pz, regrow_front));
			float catching = burn_front < 1.5 && regrow_front < -0.5 ? clamp((pz - (burn_front - 0.16)) / 0.16, 0.0, 1.0) : 0.0;
			float grow = regrow_front > -0.5 && pz < regrow_front ? clamp((regrow_front - pz) / 0.22, 0.0, 1.0) : 1.0;
			float rmax = gone > 0.5 ? 0.0 : (1.0 - catching * 0.55) * (0.2 + 0.8 * grow);
			if (r < rmax && front > top && fe_field(cen / sc) > fe_t) { top = front; loc = vec2(lx, ly); fid = h3(g + 41.0); fe_fire = catching; fe_fresh = 1.0 - grow; }
		}
		// where a feather in front ends over this one: a soft shadow under its edge
		float shade = 1.0;
		for (int z = -1; z <= 1; z++) for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
			vec3 g = base + vec3(float(x), float(y), float(z));
			vec3 cen = g + vec3(h3(g), h3(g + 17.0), h3(g + 31.0)) * 0.8 + 0.1;
			float front = dot(cen, -F) + h3(g + 3.0) * 0.4;
			if (front <= top + 0.001 || fe_field(cen / sc) <= fe_t) continue;
			float pz2 = fe_pz(cen / sc);
			if (step(burn_front, pz2) * (1.0 - step(pz2, regrow_front)) > 0.5) continue;
			vec3 d = fq - cen;
			float k = 0.8 + 0.4 * h3(g + 5.0);
			float ly = dot(d, F) / (L * k) + 0.5;
			float lx = (dot(d, S) / (W * 0.5 * k) + (h3(g + 9.0) - 0.5) * 0.5 * ly);
			float r = lx * lx + (ly - 0.5) * (ly - 0.5) * 4.0;
			if (ly > 0.4) shade = min(shade, smoothstep(1.0, 1.7, r));
		}
		{
			float lx = loc.x;
			float ly = loc.y;
			float r = sqrt(lx * lx + (ly - 0.5) * (ly - 0.5) * 4.0);
			// a frayed edge: splits in the vane, the barbs parting near the tip
			float ang = atan(lx, ly - 0.5);
			float fray = vn(vec3(ang * 5.0, fid * 40.0, 0.0)) * 0.22 + vn(vec3(ang * 17.0, fid * 40.0, 3.0)) * 0.1;
			float inside = 1.0 - smoothstep(0.82 - fray, 1.0 - fray * 0.6, r);
			float shaft = 1.0 - smoothstep(0.03, 0.08, abs(lx));
			// barbs: fine lines angled back from the shaft, faded out where they get finer than a pixel (no moiré)
			float bph = (ly * 2.3 - abs(lx) * 0.55) * 26.0;
			float bw = fwidth(bph);
			float barb = mix(0.5, 0.5 + 0.5 * sin(bph * 6.2832), clamp(1.6 - bw * 1.6, 0.0, 1.0));
			// the downy root, pale and fluffy, where it shows
			float down = 1.0 - smoothstep(0.08, 0.3, ly);
			vec3 dark;
			vec3 tip;
			vec3 gl;
			float gk;
			float t = fid;
			if (feather_pal == 0) {
				// magpie: blue-black, green to violet gloss
				dark = vec3(0.016, 0.018, 0.024); tip = dark; gl = hue(fract(0.42 + fr * 0.3 + t * 0.06)); gk = 0.55;
			} else if (feather_pal == 1) {
				// starling: black, purple and green gloss, a buff spot at each tip
				dark = vec3(0.015, 0.012, 0.016); tip = vec3(0.38, 0.28, 0.15); gl = hue(fract(0.72 + fr * 0.28 + t * 0.08)); gk = 0.4;
			} else if (feather_pal == 2) {
				// pheasant: burnished copper, each feather edged in a dark scallop, a gold-green gloss
				dark = mix(vec3(0.11, 0.025, 0.006), vec3(0.17, 0.05, 0.01), t); tip = vec3(0.01, 0.007, 0.005); gl = vec3(0.5, 0.45, 0.1); gk = 0.3;
			} else if (feather_pal == 3) {
				// peacock: deep teal and blue, a bronze-green gloss
				dark = mix(vec3(0.0, 0.025, 0.035), vec3(0.004, 0.012, 0.05), t); tip = dark; gl = hue(fract(0.48 + fr * 0.2 + t * 0.05)); gk = 0.6;
			} else {
				// an owl's: tawny, barred dark, pale-edged; no gloss
				dark = mix(vec3(0.045, 0.022, 0.009), vec3(0.085, 0.045, 0.02), t); tip = vec3(0.24, 0.19, 0.12); gl = vec3(0.0); gk = 0.0;
			}
			vec3 fe = dark * (0.7 + 0.6 * barb);
			if (feather_pal == 4) {
				float bar = smoothstep(0.45, 0.6, 0.5 + 0.5 * sin(ly * 16.0 + fid * 6.0 + abs(lx) * 3.0));
				fe = mix(fe, vec3(0.012, 0.008, 0.005), bar * 0.85);
				fe = mix(fe, tip, smoothstep(0.82, 0.97, r) * 0.6);
			} else if (feather_pal == 1) {
				// a small V-shaped spot just inside the tip
				float spot = 1.0 - smoothstep(0.05, 0.12, length(vec2(lx * 0.8, ly - 0.86 + abs(lx) * 0.25)));
				fe = mix(fe, tip * (0.8 + 0.3 * barb), spot);
			} else if (feather_pal == 2) {
				fe = mix(fe, tip, smoothstep(0.62, 0.8, r));
			}
			// the gloss: only on the vane, strongest as it turns from the eye, combed along the barbs
			float gloss_a = gk * (0.12 + 0.88 * smoothstep(0.05, 0.75, fr)) * (0.55 + 0.45 * barb) * (1.0 - smoothstep(0.75, 1.0, r));
			// (each feather lies at its own slant: catches the light on its own — what makes plumage read as feathers)
			gloss_a *= 0.3 + 1.4 * h3(vec3(fid * 91.0, 2.0, 5.0));
			fe += gl * gloss_a * 0.16;
			// the shaft: a fine pale line down the middle, gone toward the tip
			fe = mix(fe, dark * 1.8 + vec3(0.03, 0.028, 0.025), shaft * 0.55 * (1.0 - smoothstep(0.55, 0.9, ly)));
			fe = mix(fe, mix(dark, vec3(0.2, 0.19, 0.17), 0.3), down * 0.25 * shade);
			// the shadow of the feather in front, and the edge itself a touch darker
			fe *= mix(0.4, 1.0, shade) * mix(0.72, 1.0, inside);
			// (no feather here: bare bone, a little shadow where the cloak's edge lies over it)
			float cover = top > -1e8 ? 1.0 : 0.0;
			c *= mix(1.0, 0.55, (1.0 - shade) * (1.0 - cover));
			c = mix(c, fe, cover);
			rough = mix(rough, 0.62 - gk * 0.15, cover);
			spec = mix(spec, 0.16, cover);
			metal = mix(metal, 0.0, cover);
			// each feather a gentle bulge rising toward its tip, the barbs a fine grain, a step down under the next
			h = mix(h, ly * 0.9 * inside + (1.0 - r * r) * 0.5 + barb * 0.12 - shaft * 0.1 - (1.0 - shade) * 0.6, cover);
			feather_rim = cover;
			if (ember > 0.0) {
				// phoenix: embers along each feather's edge and shaft, in slow waves running back over the head
				float wave = 0.5 + 0.5 * sin(TIME * 1.4 - mp.z * 9.0 + fid * 4.0);
				float edge = smoothstep(0.7, 0.98, r) + shaft * 0.6;
				vec3 hot = mix(vec3(1.0, 0.3, 0.05), vec3(1.0, 0.75, 0.25), wave);
				emis += hot * cover * ember * (edge * (0.4 + 1.6 * pow(wave, 3.0)) + 0.08 + ember_flare * 1.2 * (0.3 + edge));
				c = mix(c, c * 0.5, ember * cover * 0.4);
				// catching fire: the whole feather blazes, white-hot at its edge, and shrivels
				emis += mix(vec3(1.0, 0.45, 0.08), vec3(1.0, 0.9, 0.6), fe_fire) * cover * fe_fire * (1.4 + 2.0 * smoothstep(0.5, 1.0, r));
				// a feather just grown: pale gold, glowing softly as it unfurls
				emis += vec3(1.0, 0.6, 0.22) * cover * fe_fresh * 0.3;
				// where the feathers have burnt away: charred bone, embers creeping in its pits
				if (cover < 0.5 && burn_front < 1.5) {
					float burnt = 1.0 - step(fe_pz(mp), burn_front);
					float coal = smoothstep(0.55, 0.85, fbm(q * 9.0 + vec3(0.0, TIME * 0.3, 0.0)));
					c = mix(c, vec3(0.03, 0.025, 0.02), burnt * 0.9);
					emis += vec3(1.0, 0.35, 0.05) * burnt * coal * (0.6 + cav * 1.4);
				}
			}
		}
	}
	if (skin == 10) {
		// a sugar druse: tiny crystal faces crowded over the bone in big patches, each catching the light at its own
		// angle (they twinkle as the find sways), paler at the rim of a patch, bone between
		float cov = smoothstep(0.5, 0.56, fbm(q * 1.4 + 6.0) * 0.6 + skin_k * 0.5 + cav * 0.2);
		vec2 g1 = cell3(q * 70.0);
		vec2 g2 = cell3(q * 24.0 + 3.0);
		float tw = pow(0.5 + 0.5 * sin(g1.y * 90.0 + fr * 22.0 + g2.y * 9.0), 14.0);
		vec3 dr = druse_col * (0.35 + 0.65 * g1.y) * (0.75 + 0.5 * g2.y);
		dr = mix(dr, vec3(0.9), (1.0 - smoothstep(0.0, 0.06, g1.x)) * 0.25);
		dr += druse_col * tw * 0.9 + vec3(tw * 0.4);
		float rim = smoothstep(0.5, 0.56, fbm(q * 1.4 + 6.0) * 0.6 + skin_k * 0.5 + cav * 0.2) - smoothstep(0.56, 0.62, fbm(q * 1.4 + 6.0) * 0.6 + skin_k * 0.5 + cav * 0.2);
		dr = mix(dr, vec3(0.85, 0.88, 0.85), rim * 0.4);
		c = mix(c, dr, cov);
		rough = mix(rough, 0.12, cov);
		spec = mix(spec, 0.75, cov);
		h = mix(h, g1.x * 2.0 + g2.x * 1.2 + 0.8, cov);
	}
	if (lava > 0.0) {
		// basalt: the bone gone dark and rough; lava in a net of cracks, brighter in the deep ones, breathing slowly
		vec3 lq = q * 4.5 + vec3(fbm(q * 3.0), fbm(q * 3.0 + 5.0), fbm(q * 3.0 + 9.0)) * 0.7;
		float e = cell_edge(lq);
		float e2 = cell_edge(lq * 2.3 + 4.0);
		float crack = (1.0 - smoothstep(0.0, 0.08, e)) + (1.0 - smoothstep(0.0, 0.05, e2)) * 0.5;
		crack = clamp(crack + cav * 0.6 * step(0.5, crack), 0.0, 1.0);
		float flow = 0.55 + 0.45 * sin(TIME * 1.2 - q.y * 6.0 + fbm(q * 2.0) * 6.0);
		vec3 basalt = vec3(0.035, 0.032, 0.03) * (0.7 + 0.6 * fbm(q * 14.0));
		c = mix(c, basalt, lava);
		c = mix(c, vec3(0.3, 0.05, 0.01), crack * lava);
		rough = mix(rough, 0.85, lava);
		spec = mix(spec, 0.25, lava);
		metal = mix(metal, 0.0, lava);
		emis += mix(vec3(1.0, 0.25, 0.03), vec3(1.0, 0.7, 0.2), crack * flow) * crack * lava * (1.2 + 2.2 * flow);
		h = mix(h, -crack * 1.5 + fbm(q * 14.0) * 0.6, lava);
	}
	// a stone skull wet where water runs: darker and glossy too (its skin painted over the bone's own wetness)
	if (skin >= 5 && skin < 9) {
		c = mix(c, c * 0.5 * wet_col, wet);
		rough = mix(rough, 0.1, wet);
	}
	// the inside of the vault, seen through a break: dim bone
	if (!FRONT_FACING) c = c * vec3(0.32, 0.28, 0.24);
	ALBEDO = c;
	// deathless: light runs over the cracks and sutures in slow waves, as if they were healing
	EMISSION = emis;
	if (deathless > 0.0) {
		float wave = 0.4 + 0.6 * pow(0.5 + 0.5 * sin(TIME * 0.9 - mp.y * 7.0 + mp.x * 3.0), 3.0);
		EMISSION += life_col * glowline * wave * deathless * 6.0;
	}
	METALLIC = metal;
	ROUGHNESS = rough;
	SPECULAR = mix(spec, 0.7, wet * float(skin == 0 || skin == 4 || skin == 1 || skin >= 5));
	NORMAL = bump(NORMAL, VERTEX, h * 0.004, 1.0);
	// (feathers: a soft velvet sheen at the silhouette, as plumage has)
	RIM = feather_rim * 0.25;
	RIM_TINT = 0.6;
}
