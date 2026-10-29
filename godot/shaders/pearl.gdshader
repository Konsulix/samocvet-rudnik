shader_type spatial;
render_mode cull_disabled;
// Pearls and their oyster (SpecPearl):
//   part 0 — the pearl: UV/UV2 unused, its direction from its middle is the vertex's rp (UV.xy + UV2.x).
//            A deep, soft body colour; the overtone floating over it (stronger towards the rim); orient — faint
//            rainbow sliding with the angle; luster — a crisp mirror for the lamps; circled pearls grooved; conch and
//            melo pearls shimmer with flame structure (silky flames that move as the pearl turns).
//            moon_k: the legendary moon pearl glows from within, clouds drifting through it.
//   part 1 — the oyster: UV.x = rho (growth rings from the hinge, 1 at the nacre's edge), UV.y = round the hinge,
//            UV2.x = 0 its back, 1 its inside. Inside: mother-of-pearl (iridescent, growth lines, the muscle scar),
//            then the lip (silver / gold / black), then the fringe of growth scales. Back: scaly growth lamellae and
//            pale rays over the dark shell.

uniform int part = 0;
uniform vec3 body_col : source_color = vec3(0.95, 0.93, 0.9);
uniform vec3 over_col : source_color = vec3(0.95, 0.78, 0.8);
uniform vec3 over2_col : source_color = vec3(0.95, 0.78, 0.8);
uniform float over_k = 0.4;
uniform float orient_k = 0.3;
uniform float flame_k = 0.0;
uniform float luster = 0.8;
uniform float circle_k = 0.0;
uniform float blister_k = 0.0;
uniform float moon_k = 0.0;
uniform vec3 lip_col : source_color = vec3(0.8, 0.8, 0.78);
uniform vec3 nacre_col : source_color = vec3(0.6, 0.6, 0.6);   // the mother-of-pearl's own grey (dark in a black-lip)
uniform vec3 back_col : source_color = vec3(0.4, 0.38, 0.32);
uniform float seed = 0.0;

varying vec3 v_op;
varying vec3 v_dir;

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
	v_dir = vec3(UV, UV2.x);
}

void fragment() {
	vec3 n = normalize(NORMAL);
	if (!FRONT_FACING) n = -n;
	float nv = clamp(dot(n, VIEW), 0.0, 1.0);
	float fr = 1.0 - nv;
	vec3 c;
	float ro;
	float h = 0.0;
	vec3 em = vec3(0.0);
	if (part == 0) {
		vec3 d = normalize(v_dir + 1e-4);
		// the body: deep and soft, lighter where it faces the viewer (light comes back out of the nacre)
		c = body_col * (0.62 + 0.2 * nv);
		// overtone: a tint floating over the body, strongest towards the rim, in soft patches
		float patch = fbm(d * 1.6 + seed);
		vec3 ov = mix(over_col, over2_col, smoothstep(0.35, 0.65, patch));
		// (on a dark body the overtone tints it rather than painting over it)
		float dk = clamp(1.0 - dot(body_col, vec3(0.3, 0.5, 0.2)) * 1.6, 0.0, 1.0);
		vec3 tint = mix(ov * (0.55 + 0.5 * nv) + c * 0.2, c * ov * 2.6, dk);
		c = mix(c, tint, over_k * (0.45 + 0.3 * smoothstep(0.1, 0.8, fr)) * (0.5 + 0.7 * patch));
		// orient: a faint rainbow that slides with the angle
		// (in patches over the face, not a ring at the rim: a ring reads as a soap bubble)
		vec3 orc = hue(fr * 0.8 + fbm(d * 4.0 + seed + 3.0) * 1.2 + seed);
		c *= 1.0 + (orc - 0.5) * orient_k * 0.35 * smoothstep(0.4, 0.7, fbm(d * 3.0 + seed + 8.0)) * (1.0 - fr * 0.7);
		// flame structure (conch, melo): silky flames that flicker as the pearl turns
		if (flame_k > 0.0) {
			// fine wavy streaks, crossing, like watered silk
			vec3 w = d + (vec3(fbm(d * 3.0 + seed), fbm(d * 3.0 + seed + 5.0), 0.0) - 0.5) * 0.5;
			float s1 = pow(abs(sin(w.x * 38.0 + w.y * 9.0)), 6.0);
			float s2 = pow(abs(sin(w.z * 38.0 - w.y * 11.0)), 6.0);
			float sh = 0.5 + 0.5 * sin(dot(VIEW, n) * 7.0 + fbm(d * 5.0) * 8.0);
			// and the mottle the flames gather into (white clouds over the pink in the reference)
			float mott = smoothstep(0.5, 0.7, fbm(vec3(d.x * 5.0, d.y * 9.0, d.z * 5.0) + seed + 2.0));
			vec3 wd = d * 11.0 + (vec3(fbm(d * 4.0 + seed), fbm(d * 4.0 + seed + 3.0), fbm(d * 4.0 + seed + 6.0)) - 0.5) * 3.0;
			float fine = smoothstep(0.5, 0.75, fbm(wd));
			float flame = max(max(s1, s2) * 0.25, max(mott * 0.7, fine * 0.8)) * smoothstep(0.3, 0.55, fbm(d * 2.0 + seed + 9.0)) * (0.45 + 0.55 * sh);
			c = mix(c, vec3(1.0, 0.95, 0.92), flame * 0.65 * flame_k);
		}
		// circled pearls: grooves round them; the nacre's own faint rings and blemishes
		float rings = pow(abs(sin(d.y * 11.0)), 6.0) * circle_k;
		c *= 1.0 - rings * 0.25;
		float blem = smoothstep(0.82, 0.92, vn(d * 40.0 + seed)) * 0.5;
		c *= 1.0 - blem * 0.12;
		h = -rings * 0.004 + (fbm(d * 30.0) - 0.5) * 0.0015 * (1.3 - luster) - blem * 0.001;
		ro = mix(0.3, 0.07, luster);
		// a blister: where it meets the shell it is nacre like the shell
		c = mix(c, c * 0.85, blister_k * smoothstep(0.25, 0.0, d.y));
		// the moon pearl: a cold light in it, clouds drifting across
		if (moon_k > 0.0) {
			float cl = fbm(d * 2.2 + vec3(TIME * 0.06, TIME * 0.02, 0.0));
			float cl2 = fbm(d * 5.0 - vec3(0.0, TIME * 0.04, TIME * 0.03));
			vec3 mc = mix(vec3(0.75, 0.8, 0.95), vec3(1.0, 0.97, 0.88), cl);
			em = mc * (0.35 + 0.45 * smoothstep(0.35, 0.75, cl) - 0.3 * smoothstep(0.55, 0.8, cl2)) * moon_k * (0.6 + 0.4 * nv);
			c *= 1.0 - 0.4 * moon_k;
		}
		// what the reference pearls show: the rim greys (it mirrors the dark room), and a crisp window of light
		// near the top with a soft second one opposite — luster is how sharp they are
		c *= mix(1.0, 0.42, pow(fr, 1.2) * (0.4 + 0.6 * luster));
		vec3 rv = reflect(-VIEW, n);
		float win = pow(max(dot(rv, normalize(vec3(-0.45, 0.55, 0.7))), 0.0), mix(25.0, 260.0, luster));
		float win2 = pow(max(dot(rv, normalize(vec3(0.6, -0.3, 0.75))), 0.0), mix(10.0, 60.0, luster));
		em += vec3(1.0, 0.98, 0.95) * (win * (0.5 + 0.8 * luster) + win2 * 0.08) * (1.0 - moon_k * 0.5);
		ro = mix(ro, 0.55, pow(fr, 2.5));
		METALLIC = 0.0;
		SPECULAR = 0.45 * (1.0 - 0.6 * pow(fr, 2.0));
	} else {
		float rho = UV.x;
		float bt = UV.y;
		float inside = UV2.x;
		vec3 p = v_op;
		if (inside > 0.5) {
			// where the nacre ends: a wandering line inside the edge
			float nend = 0.7 + (fbm(vec3(bt * 9.0, 1.0, seed)) - 0.5) * 0.14;
			float nac = 1.0 - smoothstep(nend - 0.03, nend + 0.02, rho);
			// mother-of-pearl: growth lines, a film whose colours slide over it and with the angle
			// growth lines: faint, uneven, broken (not a fingerprint)
			float gl = smoothstep(0.6, 1.0, sin(rho * 60.0 + fbm(p * 5.0) * 9.0)) * fbm(p * 8.0 + 2.0);
			float fl = fbm(p * 2.2 + seed);
			vec3 film = hue(fl * 1.1 + fr * 0.7 + seed);
			// silvery, a little of the lip's colour soaking in towards the edge; colour only where the film is thick
			// (the reference shells: a mirror-like grey that takes the dark of the room, rainbow sheen running in bands
			// along the growth towards the edge, and in a few broad flashes)
			vec3 base = mix(nacre_col, lip_col * 0.7 + 0.04, smoothstep(0.35, 0.75, rho) * 0.4);
			float band = smoothstep(0.2, 0.9, sin(rho * 22.0 + fbm(p * 3.0 + seed) * 7.0) * 0.5 + 0.5) * smoothstep(0.25, 0.65, rho);
			float fk = max(smoothstep(0.4, 0.75, fbm(p * 1.6 + seed + 4.0)), band) * (0.55 + 0.45 * fr);
			// the sheen tints the nacre (on a dark black-lip it stays a dark sheen, not paint)
			vec3 mop = base * (0.82 + 0.25 * fbm(p * 12.0) - 0.1 * gl) * (1.0 + (film - 0.5) * 0.7 * fk);
			// the muscle scar: a dull, faintly coloured patch in the middle
			float scar = smoothstep(0.12, 0.06, length(vec2(rho - 0.5, (bt - 0.42) * 0.9)));
			mop = mix(mop, mop * vec3(0.9, 0.85, 0.75), scar * 0.6);
			// the lip: the oyster's own colour, deepest at the edge
			// the lip in thin layers, each a little paler at its edge, darker and more translucent-looking outward
			float layer = fract(rho * 34.0 + fbm(vec3(bt * 12.0, rho * 4.0, seed)) * 2.0);
			vec3 lip = lip_col * (0.4 + 0.45 * smoothstep(1.05, nend, rho)) * (0.85 + 0.25 * smoothstep(0.6, 1.0, layer)) * (1.0 + (film - 0.5) * 0.25);
			// the fringe of growth scales beyond: thin, brownish, translucent-looking
			vec3 fringe = back_col * (0.8 + 0.4 * fbm(p * 20.0));
			c = mix(lip, mop, nac);
			c = mix(c, fringe, smoothstep(1.0, 1.06, rho));
			ro = mix(0.3, 0.1, nac) + scar * 0.25;
			// (dielectric: its mirror stays white, as on the reference shells — a metal would tint the room's light)
			METALLIC = 0.12 * nac;
			SPECULAR = 0.7;
			ro = mix(ro, 0.75, smoothstep(1.0, 1.06, rho));
			h = gl * 0.0004 * nac + fbm(p * 40.0) * 0.0004 + (1.0 - nac) * smoothstep(0.6, 1.0, layer) * 0.0012;
		} else {
			// the back: scaly growth lamellae, pale rays, worn and chalky in places
			float lam = fract(rho * 26.0 + fbm(vec3(bt * 8.0, rho * 3.0, seed)) * 1.5);
			float ray = smoothstep(0.55, 0.9, sin(bt * 70.0 + fbm(p * 3.0) * 4.0)) * smoothstep(0.2, 0.5, rho);
			c = back_col * (0.6 + 0.5 * fbm(p * 7.0 + seed));
			c = mix(c, vec3(0.78, 0.74, 0.66), ray * 0.45);
			c = mix(c, vec3(0.7, 0.68, 0.62), smoothstep(0.55, 0.8, fbm(p * 2.5 + 3.0)) * 0.4);
			c *= 0.75 + 0.35 * lam;
			ro = 0.85;
			h = lam * 0.006 + fbm(p * 30.0) * 0.002;
			METALLIC = 0.0;
		}
	}
	NORMAL = bump(n, VERTEX, h, 1.0);
	ALBEDO = clamp(c, 0.0, 1.0);
	ROUGHNESS = ro;
	EMISSION = em;
}
