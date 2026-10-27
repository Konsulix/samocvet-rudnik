shader_type spatial;
render_mode cull_disabled;
// Fossil shells (SpecFossil), drawn pixel by pixel from the shell's own coordinates rather than vertex colours:
//   part 0 — the shell: UV = (angle along the coil, angle round the tube), UV2.x = the coil's radius there.
//            Fine ribs in relief, grainy weathered surface with patina, the frilly suture lines where it wore,
//            and nacre: a thin film whose colours drift over the surface and with the angle, laid in plates
//            (the plates are decided on the CPU and passed as a small texture, so callouts point where they show)
//            with fine dark cracks between them. Muted and metallic, as on real ammolite and pyrite ammonites.
//   part 1 — the sawn, polished face: UV = (angle along the coil, 0 inner .. 1 outer edge of the turn), UV2.x radius.
//            S-curved cream chamber walls, the chambers filled (honey calcite with clouds of crystal, white calcite,
//            pyrite, banded agate, or dark amber set with chips of ammolite), the last chamber packed with rock.

uniform int part = 0;
uniform vec3 base_col : source_color = vec3(0.55, 0.42, 0.3);
uniform vec3 dark_col : source_color = vec3(0.2, 0.13, 0.08);
uniform float metal_k = 0.0;        // the bare shell: 0 chalky, ~0.7 pyrite
uniform float rough_k = 0.6;
uniform float film_all = 0.0;       // a faint film over the bare shell too (pyrite ammonites)
uniform float fire_h = 0.05;        // the nacre's main hue on the wheel: 0 red, 0.3 green, 0.6 blue, 0.76 violet
uniform float ribs_fine = 40.0;     // fine ribs per turn
uniform float rib_amp = 1.0;
uniform float b_log = 0.1;          // the spiral's growth: r = a e^(b th)
uniform float t_end = 20.0;         // the coil's last angle
uniform float body = 3.0;           // the body chamber's length (no chamber walls in it)
uniform float sept = 0.48;          // the angle between chamber walls
uniform float frill = 1.0;
uniform float tube_k = 0.3;         // the tube's half-width / the coil's radius
uniform float sut_k = 1.0;          // how much the suture lines show where there is no nacre
uniform sampler2D cells : filter_nearest;   // per plate: r = nacre (1) or bare (0), g = its hue offset, b/a = its centre
uniform vec2 cells_n = vec2(8.0, 8.0);
uniform vec2 plate_k = vec2(1.6, 0.7);      // plates per radian along the coil and round the tube
uniform float nacre_from = 3.7;     // no nacre on the innermost turn
uniform int fill = 0;               // the face: 0 calcite, 1 white, 2 pyrite, 3 agate, 4 ammolite chips
uniform vec3 rock_col : source_color = vec3(0.28, 0.26, 0.23);
uniform float broken = 0.0;
// a photo scan of stone (Poly Haven) laid over the bare shell from three sides, unlike any host rock
uniform sampler2D scan_diff : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D scan_rough : filter_linear_mipmap, repeat_enable;
uniform float scan_k = 0.0;
uniform float scan_tile = 1.6;         // a sawn shell's end is a fracture: how deep (radians) its ragged edge bites in

varying vec3 v_op;
varying vec3 v_cam;
varying vec3 v_no;

float h3(vec3 p) { p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float vn(vec3 x) {
	vec3 i = floor(x), f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h3(i), h3(i + vec3(1, 0, 0)), f.x), mix(h3(i + vec3(0, 1, 0)), h3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(h3(i + vec3(0, 0, 1)), h3(i + vec3(1, 0, 1)), f.x), mix(h3(i + vec3(0, 1, 1)), h3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
float fbm(vec3 p) { return vn(p) * 0.5 + vn(p * 2.03) * 0.25 + vn(p * 4.01) * 0.125 + vn(p * 8.02) * 0.0625; }

// colours below are written as on screen (sRGB); the shader works in linear
vec3 lin(vec3 c) { return c * c * (c * 0.3 + 0.7); }

// a plain hue wheel, softened
vec3 hue(float h) {
	vec3 c = clamp(abs(fract(h + vec3(1.0, 0.6667, 0.3333)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
	return c * c * (3.0 - 2.0 * c);
}

// the colour of a thin film at a spot: hues drift over the surface and slide with the angle
vec3 film(vec3 p, float fr, float off) {
	float h = fire_h + off + (fbm(p * 2.2 + 7.0) - 0.5) * 0.5 + (vn(p * 7.0) - 0.5) * 0.16 + fr * 0.25;
	vec3 c = hue(h);
	float l = dot(c, vec3(0.3, 0.5, 0.2));
	// the film is uneven: thin and dark in places, bright in others
	return mix(vec3(l), c, 0.6) * (0.45 + 0.6 * fbm(p * 5.0 + 1.0));
}

// cells: x = distance to the nearest centre, y = distance to the edge between cells, z = the cell's own random
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

// a fine network of cracks (the dragon skin over ammolite): 0 on a crack, 1 away from it
float cracks(vec2 q) {
	return smoothstep(0.015, 0.06, vor2(q).y);
}

// a texture laid from three sides by the surface's facing (no seams, no stretching on a coiled tube)
vec4 tri(sampler2D t, vec3 q, vec3 w) {
	return texture(t, q.yz) * w.x + texture(t, q.xz) * w.y + texture(t, q.xy) * w.z;
}

// a bump from a height field, by screen derivatives (fine ones: the coarse kind steps in 2x2 blocks up close)
vec3 bump(vec3 n, vec3 pos, float h, float k) {
	vec3 dpx = dFdxFine(pos), dpy = dFdyFine(pos);
	float dhx = dFdxFine(h), dhy = dFdyFine(h);
	vec3 r1 = cross(dpy, n), r2 = cross(n, dpx);
	float det = dot(dpx, r1);
	vec3 g = sign(det) * (dhx * r1 + dhy * r2);
	return normalize(abs(det) * n - g * k);
}

void vertex() {
	v_op = VERTEX;
	v_no = NORMAL;
	v_cam = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
}

// distance (in object units) from (th) to the nearest chamber wall, wiggled by w; far inside the body chamber
float septum(float th, float w, float r) {
	if (th > t_end - body) return 9.0;
	float k = floor((th - w) / sept + 0.5);
	return abs(th - w - k * sept) * r;
}

// a point of the cut's plane in spiral terms: x = the angle along the coil, y = 0 inner .. 1 outer edge of that turn,
// z = the turn's outer radius there. Works anywhere in the plane, so a ray inside the stone can ask what it passes
vec3 spiral(vec2 q) {
	float r = max(length(q), 1e-5);
	float phi = atan(q.y, q.x);
	float a = exp(-b_log * t_end);
	float s = log(r / a) / b_log;
	float th = phi + 6.2832 * ceil((s - phi) / 6.2832);
	float ro = a * exp(b_log * th);
	float ri = ro * exp(-b_log * 6.2832);
	return vec3(th, (r - ri) / max(ro - ri, 1e-5), ro);
}

// the chamber walls' S-curve at t
float wall_w(float th, float t) {
	return (0.30 * (1.0 - t) * (1.0 - t) - 0.11 * sin(3.1416 * t) + 0.02 * sin(t * 11.0 + th * 0.7) * frill) * tube_k * 2.2;
}

// how much of a chamber wall (or the shell's wall) there is at (th, t) of a turn of outer radius r; soft (0..1)
// widens and blurs it, as a wall seen deep down through the calcite
float wall_at(float th, float t, float r, float soft) {
	float d = septum(th, wall_w(th, t), r);
	float dw = min(t, 1.0 - t) * r * tube_k * 2.0;
	float ww = (0.008 * r + 0.002) * (1.0 + soft * soft * 14.0);
	return max(1.0 - smoothstep(ww * (0.5 - soft * 0.45), ww, d), 1.0 - smoothstep(ww * (0.4 - soft * 0.35), ww * 1.1, dw)) * (1.0 - soft * 0.7);
}

// the plate under (th, ph): x = its nacre (0/1), y = its hue offset, z = distance to the crack round it,
// w = how far inside the nacre (the nearest bare plate's centre minus the nearest nacre one's: < 0 off it) — so the
// film fades only where it really ends, not between two plates that both kept it
vec4 plate(vec2 q) {
	vec2 c = floor(q);
	float d1 = 9.0, d2 = 9.0, dn = 9.0, db = 9.0;
	vec2 info = vec2(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = c + vec2(float(x), float(y));
			vec4 t = texelFetch(cells, ivec2(clamp(g + 1.0, vec2(0.0), cells_n - 1.0)), 0);
			vec2 p = g + 0.15 + 0.7 * t.ba;
			float d = distance(p, q);
			if (t.r > 0.5) dn = min(dn, d); else db = min(db, d);
			if (d < d1) { d2 = d1; d1 = d; info = t.rg; }
			else if (d < d2) { d2 = d; }
		}
	}
	return vec4(info, d2 - d1, db - dn);
}

// the ragged end of a broken shell, at x (0 the inner edge of the turn .. 1 the outer); the same line on the face
// and on the shell behind it, so their edges meet
float bite(float x) {
	return broken * (0.15 + 0.9 * fbm(vec3(x * 3.0, 3.7, 1.3)) + 0.12 * vn(vec3(x * 14.0, 1.1, 0.0)));
}

void fragment() {
	vec3 n = normalize(NORMAL);
	// the inside of the shell, or the break that closes a sawn one (vertex alpha 0): the stone that filled it
	bool inside = !FRONT_FACING || COLOR.a < 0.5;
	if (!FRONT_FACING) n = -n;
	float fr = 1.0 - abs(dot(n, VIEW));
	float r = UV2.x;
	vec3 p = v_op;
	if (part == 0) {
		float th = UV.x;
		float ph = UV.y;
		if (broken > 0.0 && th > t_end - bite(cos(ph) * 0.5 + 0.5)) discard;
		float outer = smoothstep(-0.3, 0.7, cos(ph));
		// fine ribs, splitting in two towards the outer edge; growth lines between them; pits and wear
		// each rib a little its own — spacing and strength wander — and the ribs fade where they get finer than a pixel
		float rph = th * ribs_fine + sin(ph * 1.5) * 0.8 + (vn(vec3(th * 2.5, 0.3, 0.0)) - 0.5) * 2.5;
		float rf = 0.5 + 0.5 * sin(rph);
		float rf2 = 0.5 + 0.5 * sin(rph * 2.0 + 1.3);
		// (one rib is 2 pi of rph: fade once a rib is narrower than about three pixels)
		float fine_k = 1.0 - smoothstep(1.6, 3.0, fwidth(rph));
		rf = mix(0.5, rf, fine_k * (0.75 + 0.5 * vn(vec3(th * 6.0, 1.7, 0.0))));
		rf2 = mix(0.5, rf2, fine_k * fine_k);
		// stone, not clay: ribs worn flat in patches, mottled in a few tones, crystal grains of calcite that glint,
		// hairline cracks, pits, rust in places
		float wear = fbm(p * 6.0);
		float worn = smoothstep(0.35, 0.75, fbm(p * 1.8 + 5.0));
		float rib = mix(rf, max(rf, rf2 * 0.8), outer) * rib_amp * (1.0 - worn * 0.65);
		float pits = smoothstep(0.78, 0.9, vn(p * 55.0)) * smoothstep(0.45, 0.7, fbm(p * 4.0 + 2.0));
		vec2 gq = vec2(p.x * 47.0 + p.z * 23.0, p.y * 47.0 - p.z * 31.0);
		vec3 grain = vor2(gq);
		vec3 hair = vor2(vec2(p.x * 6.0 - p.z * 4.0, p.y * 6.0 + p.z * 5.0) + (vn(p * 14.0) - 0.5) * 0.6);
		float crack = (1.0 - smoothstep(0.0, 0.02, hair.y)) * smoothstep(0.45, 0.6, h3(vec3(floor(hair.zz * 9.0), 3.0)));
		// close up the stone has a fine texture of its own: pores, a sandy grain, the odd glinting crystal
		float micro = fbm(p * 140.0);
		float pore = smoothstep(0.72, 0.9, vn(p * 260.0));
		// the scanned stone: its colour, veins and roughness; its lightness pressed in as relief
		vec3 tw = pow(abs(normalize(v_no)), vec3(4.0));
		tw /= tw.x + tw.y + tw.z;
		vec3 sc = tri(scan_diff, p * scan_tile, tw).rgb;
		float sr = tri(scan_rough, p * scan_tile, tw).r;
		float sl = dot(sc, vec3(0.3, 0.5, 0.2));
		float h = rib * 0.9 * (0.4 + 0.6 * outer) + wear * 0.35 - pits * 0.25 - crack * 0.3 + (grain.z - 0.5) * 0.08
			+ (micro - 0.5) * 0.22 - pore * 0.12 + (sl - 0.3) * 0.9 * scan_k;
		vec3 c = mix(dark_col, base_col, 0.4 + 0.6 * rib * (0.6 + 0.4 * wear));
		float mott = fbm(p * 3.0 + 4.0);
		c *= 0.7 + 0.6 * mott;
		c = mix(c, c * vec3(0.8, 0.82, 0.85), smoothstep(0.45, 0.62, fbm(p * 9.0 + 2.0)) * 0.55);
		c = mix(c, c * vec3(1.2, 0.85, 0.6), smoothstep(0.6, 0.78, fbm(p * 2.2 + 11.0)) * 0.45);
		c *= 0.88 + 0.24 * grain.z;
		c = mix(c, c * 1.25, (1.0 - smoothstep(0.0, 0.05, grain.y)) * 0.25);
		// the scan takes over the colour, shaded by the ribs and the wear like the stone it stands for
		c = mix(c, sc * (0.55 + 0.6 * rib * (0.6 + 0.4 * wear)) * (0.8 + 0.4 * mott), scan_k);
		c *= 0.82 + 0.36 * micro;
		c = mix(c, c * 0.55, pore * 0.7);
		c = mix(c, mix(c, dark_col, 0.5), pits * 0.45);
		c = mix(c, dark_col * 0.45, crack * 0.6);
		// suture lines where the shell wore through, lacy
		float w = (sin(ph * 9.0) * 0.06 + sin(ph * 23.0 + th) * 0.03 * frill + cos(ph) * 0.12 + (vn(vec3(th * 4.0, ph * 6.0, 0.0)) - 0.5) * 0.05 * frill) * tube_k;
		float d = septum(th, w, r);
		float line = (1.0 - smoothstep(0.003, 0.009, d / max(r, 0.05))) * sut_k;
		c = mix(c, mix(dark_col * 0.6, vec3(0.85, 0.8, 0.7), 0.25), line * 0.85);
		float m = metal_k;
		// a few calcite grains catch the light like little mirrors; worn patches are smoother
		float ro = rough_k * (0.75 + 0.35 * wear) * (1.0 - worn * 0.25);
		ro = mix(ro, sr * 1.1, scan_k * 0.7);
		ro = mix(ro, 0.12, step(0.86, grain.z) * 0.8);
		ro = mix(ro, 0.1, step(0.975, vn(p * 210.0)) * 0.7);
		// a faint film over the bare metal shell
		c = mix(c, film(p, fr, 0.0) * length(c) * 1.2, film_all * (0.4 + 0.6 * outer));
		// nacre plates
		// where the nacre kept: the plates (decided on the CPU), their edges ragged where the film flaked off
		vec2 q = vec2(th * plate_k.x, ph * plate_k.y);
		vec4 pl = plate(q + (vec2(vn(p * 7.0), vn(p * 7.0 + 3.0)) - 0.5) * 0.55);
		// the film thins out towards its edge and flakes off in islands, rather than ending on a line
		float edge = pl.w + (fbm(p * 26.0 + 3.0) - 0.5) * 0.35 + (vn(p * 70.0) - 0.5) * 0.08;
		float on = step(nacre_from, th) * smoothstep(-0.05, 0.3, edge);
		// over it a finer network of cracks, smaller on the inner turns
		float ck = cracks(vec2(th * plate_k.x * 4.0, ph * plate_k.y * 3.0) + (vn(p * 20.0) - 0.5) * 0.3);
		vec3 fc = film(p, fr, (pl.y - 0.5) * 0.12);
		fc *= 0.8 + 0.3 * vn(p * 55.0 + pl.y * 9.0);
		vec3 nc = mix(dark_col * 0.5, fc, 0.85);
		nc = mix(mix(dark_col * 0.35, nc, ck), nc, 1.0 - on);   // the cracks only where the film is whole
		c = mix(c, nc, on);
		// the film turns metallic only where it is whole: half metal over a dull edge would read as a dark rim
		float mk = on * on * on;
		m = mix(m, mix(0.2, 0.85, ck), mk);
		ro = mix(ro, mix(0.75, 0.2 + wear * 0.12, ck), mk);
		float hn = (rib * 0.25 + wear * 0.15 + ck * 0.25) * 0.6;
		vec3 nb = bump(n, VERTEX, mix(h, hn, on) * 0.01 * (0.4 + r), 1.0);
		// a chip knocked off: the stone under the weathered skin shows, paler, rough, without its film
		float chipd = (1.0 - COLOR.r) * step(0.5, COLOR.a);
		if (chipd > 0.0) {
			vec3 fresh = mix(base_col * 1.05, sc * 1.12, scan_k) * (0.75 + 0.35 * fbm(p * 60.0));
			c = mix(c, fresh, chipd);
			m = mix(m, 0.0, chipd);
			ro = mix(ro, 0.85, chipd);
		}
		// seen from inside — through a broken end — the shell is not hollow: it is the stone that filled the chambers,
		// broken across, rough and grainy
		// (a whole shell — it has a body chamber — shows the same mud on the inside of its tube, deep in the aperture)
		if (inside && ((COLOR.a > 0.1 && COLOR.a < 0.5) || (body > 0.0 && !FRONT_FACING))) {
			// a whole shell's aperture, packed with the dark mud it lay in: dull, gritty, darker deeper in
			vec3 gi = vor2(vec2(p.x * 40.0 + p.z * 21.0, p.y * 40.0 - p.z * 19.0));
			c = rock_col * (0.5 + 0.5 * gi.z) * (0.7 + 0.5 * fbm(p * 18.0));
			m = 0.0;
			ro = 0.9;
			nb = bump(n, VERTEX, (gi.z + fbm(p * 25.0)) * 0.004, 1.0);
		} else if (inside) {
			// the break's own flat surface (the fan of triangles closing the tube would show as a star otherwise),
			// and grains laid out so they never smear, whichever way it faces
			n = normalize(cross(dFdxFine(VERTEX), dFdyFine(VERTEX)));
			if (dot(n, VIEW) < 0.0) n = -n;
			vec3 gi = vor2(vec2(p.x * 30.0 + p.z * 21.0, p.y * 30.0 - p.z * 19.0 + p.x * 7.0));
			vec3 fc = fill == 2 ? lin(vec3(0.62, 0.52, 0.26)) : fill == 3 ? lin(vec3(0.5, 0.55, 0.6))
				: fill == 1 ? lin(vec3(0.72, 0.68, 0.6)) : fill == 4 ? lin(vec3(0.34, 0.2, 0.09)) : lin(vec3(0.55, 0.36, 0.17));
			c = fc * (0.55 + 0.45 * gi.z) * (0.75 + 0.4 * fbm(p * 12.0));
			c *= 1.0 - (1.0 - smoothstep(0.0, 0.05, gi.y)) * 0.35;
			m = fill == 2 ? 0.8 : 0.0;
			ro = 0.55 + 0.3 * gi.z;
			nb = bump(n, VERTEX, (gi.z + fbm(p * 20.0)) * 0.004, 1.0);
		}
		ALBEDO = c;
		METALLIC = m;
		ROUGHNESS = clamp(ro, 0.05, 1.0);
		NORMAL = nb;
	} else {
		float th = UV.x;
		float t = UV.y;
		if (broken > 0.0 && th > t_end - bite(t)) discard;
		// chamber walls: S-curved, bowing back from the inner edge and forward at the outer
		float w = (0.30 * (1.0 - t) * (1.0 - t) - 0.11 * sin(3.1416 * t) + 0.02 * sin(t * 11.0 + th * 0.7) * frill) * tube_k * 2.2;
		float d = septum(th, w, r);
		float band = r * tube_k * 2.0;
		// past the outer edge (the strip that reaches over the ribs) there is no wall line: it is just more filling
		float dw = (t > 1.0 ? 1.0 : min(t, 1.0 - t)) * band;
		float wall_w = 0.008 * r + 0.002;
		float wall = max(1.0 - smoothstep(wall_w * 0.5, wall_w, d), 1.0 - smoothstep(wall_w * 0.4, wall_w * 1.1, dw));
		// across the chamber: 0 at one wall, 1 at the next; how deep into the coil (inner turns pale, outer dark)
		float across = fract((th - w) / sept + 0.5);
		float dist = min(d, dw) / max(band, 0.01);
		float turn = clamp(th / t_end, 0.0, 1.0);
		vec3 c;
		float m = 0.0;
		float ro = 0.14;
		float cl = fbm(p * 7.0 + 3.0);
		// coarse grains of calcite, each a shade of its own, faint bright cleavage between them
		vec3 gr = vor2(p.xy * 24.0 + (vec2(vn(p * 16.0), vn(p * 16.0 + 4.0)) - 0.5) * 0.5);
		float cleave = 1.0 - smoothstep(0.0, 0.035, gr.y);
		// white crystal grown into the middle of the chambers, a sparkle in it
		float frost = smoothstep(0.55, 0.95, fbm(p * 9.0 + 9.0) * 0.75 + smoothstep(0.05, 0.35, dist) * 0.4) * (0.6 + 0.4 * fbm(p * 30.0));
		float spark = smoothstep(0.82, 0.95, vn(p * 140.0));
		if (th > t_end - body) {
			c = rock_col * (0.7 + 0.5 * fbm(p * 25.0)) * (0.85 + 0.3 * vn(p * 120.0));
			ro = 0.4;
		} else if (fill == 0 || fill == 1) {
			// clear calcite under a polish, seen INTO: the ray bends in at the surface and runs down through the
			// stone; at each step it asks the spiral where it is, so the chamber walls show going down into the depth
			// (and shift as the stone turns), the amber deepens and reddens the further the light travels, and clouds
			// of white crystal hang at different depths
			vec3 vdir = normalize(v_cam - p);
			vec3 into = refract(-vdir, vec3(0.0, 0.0, 1.0), 0.66);
			float depth = r * tube_k * 1.3;
			vec3 pale = fill == 0 ? lin(vec3(0.9, 0.72, 0.45)) : lin(vec3(0.9, 0.88, 0.82));
			vec3 deep = fill == 0 ? lin(vec3(0.4, 0.25, 0.11)) : lin(vec3(0.55, 0.52, 0.46));
			vec3 haze = lin(vec3(0.9, 0.84, 0.74));
			vec3 acc = vec3(0.0);
			float tr = 1.0;
			// many steps and walls blurring with depth: soft sheets going down, no grain to shimmer as it turns
			// the steps wander with a smooth noise over the face (not a per-pixel hash, which shimmers as it turns):
			// the copies of a wall going down smear into one soft, uneven shadow instead of a stack of lines
			float jn = fbm(p * 38.0 + 5.0);
			for (int k = 0; k < 10; k++) {
				float sk = clamp((float(k) + jn * 1.0 + (fbm(p * 70.0 + float(k) * 3.1) - 0.5) * 1.2) / 10.0, 0.0, 1.0);
				vec3 q = p + into * depth * sk / max(-into.z, 0.3);
				// the deeper, the more each wall's place wanders: down there it is only a vague, blotchy shadow
				vec3 sq = spiral(q.xy);
				sq.x += (fbm(q * 9.0 + float(k) * 1.7) - 0.5) * 0.9 * sk * sk;
				sq.y += (fbm(q * 7.0 + 4.0 + float(k)) - 0.5) * 0.6 * sk * sk;
				if (sq.x > t_end) {
					// past the broken end: nothing more to see in there
					acc += tr * deep * 0.15;
					tr = 0.0;
					break;
				}
				// how blurred a wall is down there wanders too
				float wq = wall_at(sq.x, sq.y, sq.z, clamp(sk * (0.7 + 0.8 * vn(q * 25.0)), 0.0, 1.0));
				float tq = clamp(sq.x / t_end, 0.0, 1.0);
				vec3 bodyc = mix(pale, deep, clamp(pow(tq, 1.3) * 1.1 + sk * 0.35, 0.0, 1.0));
				float cl_q = smoothstep(0.5, 0.85, fbm(q * 7.0 + 9.0)) * 0.55;
				// a wall down there, lit through the calcite: pale, but tinted by what lies above it
				vec3 here = mix(bodyc, haze, cl_q * 0.6);
				// deeper layers: darker and fainter, step by step — the near ones clear, the far ones barely there
				float near = pow(1.0 - sk, 2.2);
				here = mix(here, lin(vec3(0.85, 0.78, 0.62)), wq) * mix(0.25, 1.0, near);
				float a = mix(0.1 + cl_q * 0.16, 0.05 + 0.45 * near, wq);
				acc += tr * a * here;
				tr *= 1.0 - a;
			}
			c = acc + tr * deep * 0.25;
			c *= 0.97 + 0.06 * gr.z;
			c = mix(c, c * 1.15 + 0.01, cleave * 0.05);
			c *= 1.5;   // the face's own darkening below is for opaque fills
			ro = 0.06;
		} else if (fill == 2) {
			// pyrite: packed little crystals, each a facet catching the light, dark seams between
			vec3 pg = vor2(p.xy * 60.0);
			c = mix(lin(vec3(0.45, 0.37, 0.16)), lin(vec3(0.9, 0.78, 0.45)), pg.z);
			c *= 1.0 - (1.0 - smoothstep(0.0, 0.06, pg.y)) * 0.6;
			m = 0.9;
			ro = 0.18 + 0.25 * (1.0 - pg.z);
		} else if (fill == 3) {
			// chalcedony: grey-blue, a few fine bands only along the walls, sparkling drusy quartz in the middle
			float bands = (0.5 + 0.5 * sin(dist * 160.0 + cl * 3.0)) * (1.0 - smoothstep(0.03, 0.16, dist));
			c = mix(lin(vec3(0.42, 0.47, 0.53)), lin(vec3(0.66, 0.7, 0.74)), cl * 0.6 + bands * 0.4);
			c = mix(c, lin(vec3(0.88, 0.9, 0.92)), frost * 0.7 * (0.6 + 0.4 * spark));
			ro = mix(0.12, 0.3, frost);
		} else {
			// dark amber packed with angular chips of ammolite, each its own colour, thin amber seams between
			c = mix(lin(vec3(0.3, 0.16, 0.06)), lin(vec3(0.5, 0.3, 0.12)), cl);
			vec2 q = p.xy * 11.0 + (vec2(vn(p * 30.0), vn(p * 30.0 + 2.0)) - 0.5) * 0.25;
			vec2 ci = floor(q);
			float d1 = 9.0, d2 = 9.0, ch = 0.0;
			for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
				vec2 g = ci + vec2(float(x), float(y));
				vec2 cp = g + vec2(h3(vec3(g, 2.0)), h3(vec3(g, 5.0))) * 0.8 + 0.1;
				float dd = distance(cp, q);
				if (dd < d1) { d2 = d1; d1 = dd; ch = h3(vec3(g, 11.0)); } else if (dd < d2) { d2 = dd; }
			}
			float chip = step(0.12, ch) * smoothstep(0.03, 0.09, d2 - d1) * smoothstep(0.04, 0.14, dist);
			vec3 fc = film(p, fr, (ch - 0.5) * 0.7) * (0.6 + 0.5 * vn(p * 70.0));
			c = mix(c, fc, chip * 0.85);
			m = chip * 0.75;
		}
		// the studio light is strong on a flat polished face: keep it as dark and deep as a real one looks
		vec3 wc = lin(vec3(0.9, 0.86, 0.76)) * (0.85 + 0.2 * vn(p * 60.0));
		c = mix(c * 0.55, wc * 0.7, wall);
		NORMAL = bump(n, VERTEX, wall * 0.0025 * (0.3 + r), 1.0);
		ALBEDO = c;
		METALLIC = m * (1.0 - wall);
		ROUGHNESS = ro;
		CLEARCOAT = 0.7;
		CLEARCOAT_ROUGHNESS = 0.05;
	}
}
