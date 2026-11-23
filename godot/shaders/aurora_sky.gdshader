shader_type spatial;
// The night sky behind a stone with the northern lights (SpecPolar.borealis; SpecStudio.set_aurora): a card on the
// studio's camera, behind the stone, so the stone turns in front of it and the sky stays. Deep blue going to black,
// stars of three sizes twinkling, now and then one falling; over the upper part curtains of aurora — green hems with
// rays rising off them into violet, the folds drifting, pieces flaring and fading; low down a faint green glow on the
// horizon. All laid out on the screen (SCREEN_UV), whatever the camera does.
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform float k = 1.0;          // fades it in
uniform float seed = 0.0;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) {
	float s = 0.0, a = 0.5;
	for (int i = 0; i < 4; i++) { s += a * noise(p); p = p * 2.03 + vec2(1.7, 9.2); a *= 0.5; }
	return s;
}
// stars on a grid of cells, one at most to a cell: its own place, size and twinkle
vec3 stars(vec2 p, float cell, float big, float t) {
	vec2 c = floor(p / cell);
	vec2 f = p / cell - c;
	float h = hash(c + seed);
	if (h < 0.55) return vec3(0.0);
	vec2 at = vec2(hash(c + 3.1), hash(c + 7.7)) * 0.8 + 0.1;
	float d = length(f - at) * cell;
	float tw = 0.6 + 0.4 * sin(t * (1.5 + h * 3.0) + h * 40.0);
	float core = exp(-d * d / (big * big)) * tw;
	vec3 tint = mix(vec3(0.75, 0.85, 1.0), vec3(1.0, 0.92, 0.8), hash(c + 1.3));
	return tint * core * (0.5 + h);
}
// one ribbon of aurora, as in a photograph of it (23.11: one band along the top read as a strip of light): a broad
// sweep across the whole sky in big slow bends, here rising steeply, there sagging, its curve `c` changing slowly.
// Across the ribbon: a soft but clear lower edge, and above it the light rising in rays and dying away; along it, its
// width and brightness swell and thin, here and there it all but breaks. Mostly green, a little teal low, a faint
// violet at the top of its rays.
float ribbon_y(float x, float y0, float a1, float f1, float sh, float t) {
	return y0 + a1 * sin(x * f1 + sh + t * 0.035) + a1 * 0.45 * sin(x * f1 * 2.1 - sh * 1.3 - t * 0.05)
		+ (fbm(vec2(x * 1.3 + sh, t * 0.03)) - 0.5) * 0.08;
}
vec3 ribbon(vec2 uv, float y0, float a1, float f1, float sh, float t, float amp) {
	float x = uv.x;
	float c = ribbon_y(x, y0, a1, f1, sh, t);
	float slope = (ribbon_y(x + 0.01, y0, a1, f1, sh, t) - ribbon_y(x - 0.01, y0, a1, f1, sh, t)) / 0.02;
	// distance across the ribbon (its own normal): negative below its lower edge, positive up into it
	float across = (c - uv.y) / sqrt(1.0 + slope * slope);
	float wide = 0.06 + 0.09 * fbm(vec2(x * 1.7 + sh * 2.0, t * 0.04));
	float edge = smoothstep(-0.03, 0.006, across);
	float up = exp(-max(across, 0.0) / wide);
	if (edge * up < 0.003) return vec3(0.0);
	// the rays: streaks up the ribbon (across its line), broad and fine, drifting slowly along it
	float along = x * sqrt(1.0 + slope * slope);
	float broad = fbm(vec2(along * 18.0 + sh * 7.0 - t * 0.05, across * 3.0 + t * 0.1));
	float fine = noise(vec2(along * 110.0 + sh * 3.0, t * 0.5));
	float rays = 0.45 + 0.55 * smoothstep(0.25, 0.75, broad) * (0.8 + 0.2 * fine);
	// along it: swelling and thinning, near breaking here and there
	float body = 0.25 + 0.75 * smoothstep(0.2, 0.7, fbm(vec2(x * 1.9 + sh * 3.0 - t * 0.025, t * 0.03)));
	// the bright lower rim of the ribbon, as on the photograph
	float rim = exp(-pow(across / 0.012, 2.0)) * 0.6;
	// its colours (23.11: "more of its play of colour"): the find's own palette (pal) — its lower edge, its body and the
	// top of its rays; the top drifting along the ribbon between two of its shades, slowly; waves of brightness running
	// along it
	vec3 low, mid, top, top2;
	int pal = int(floor(hash(vec2(seed, 5.3)) * 4.0));
	if (pal == 0) { low = vec3(0.55, 1.0, 0.25); mid = vec3(0.12, 1.0, 0.42); top = vec3(0.5, 0.25, 1.0); top2 = vec3(0.2, 0.7, 1.0); }
	else if (pal == 1) { low = vec3(0.45, 1.0, 0.3); mid = vec3(0.1, 0.95, 0.5); top = vec3(1.0, 0.25, 0.65); top2 = vec3(0.6, 0.25, 1.0); }
	else if (pal == 2) { low = vec3(0.2, 1.0, 0.85); mid = vec3(0.1, 0.8, 0.95); top = vec3(0.35, 0.35, 1.0); top2 = vec3(0.8, 0.3, 1.0); }
	else { low = vec3(0.7, 1.0, 0.2); mid = vec3(0.2, 1.0, 0.35); top = vec3(1.0, 0.22, 0.15); top2 = vec3(1.0, 0.3, 0.6); }
	float drift = smoothstep(0.25, 0.75, noise(vec2(along * 2.2 + sh * 5.0 - t * 0.06, t * 0.04)));
	vec3 hi = mix(top, top2, drift);
	vec3 col = mix(low, mid, smoothstep(0.0, 0.035, across));
	col = mix(col, hi, smoothstep(wide * 0.6, wide * 1.6, across) * 0.9);
	float wave = 0.8 + 0.4 * pow(0.5 + 0.5 * sin(along * 7.0 - t * 0.55 + sh), 3.0);
	// the tops of the rays in the palette's colour, reaching higher than the green
	float crown = smoothstep(wide * 0.4, wide * 1.4, across) * exp(-max(across, 0.0) / (wide * 3.2)) * (0.4 + 0.6 * rays);
	return (col * (up * rays + rim) + hi * crown * 0.55) * edge * body * amp * wave;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float t = TIME;
	vec3 sky = mix(vec3(0.004, 0.008, 0.03), vec3(0.0, 0.002, 0.008), uv.y);
	// the horizon's faint green glow
	sky += vec3(0.008, 0.035, 0.02) * smoothstep(0.6, 1.0, uv.y) * (0.7 + 0.3 * noise(vec2(uv.x * 3.0, t * 0.1)));
	vec2 px = uv * vec2(VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, 1.0) * 600.0;
	sky += stars(px, 26.0, 0.9, t) * 0.8;
	sky += stars(px + 300.0, 58.0, 1.5, t) * 1.1;
	sky += stars(px + 700.0, 140.0, 2.4, t) * 1.6;
	// now and then (rarely) a falling star: a bright head with a halo, a long tail fading from white through pale blue,
	// a few sparks shed behind it; it flares as it burns out
	float cyc = floor(t / 11.0);
	float ft = fract(t / 11.0) * 11.0;
	if (hash(vec2(cyc, seed)) > 0.45 && ft < 1.1) {
		float u = ft / 1.1;
		float asp = VIEWPORT_SIZE.x / VIEWPORT_SIZE.y;
		vec2 a = vec2(hash(vec2(cyc, 1.0)) * 0.6 + 0.2, hash(vec2(cyc, 2.0)) * 0.18 + 0.05);
		vec2 dir = normalize(vec2((hash(vec2(cyc, 3.0)) > 0.5 ? 1.0 : -1.0) * 0.85, 0.45));
		vec2 head = a + dir * u * 0.5;
		vec2 q = (uv - head) * vec2(asp, 1.0);
		vec2 dd = normalize(dir * vec2(asp, 1.0));
		float along = dot(q, -dd);
		float across = abs(q.x * dd.y - q.y * dd.x);
		float life = smoothstep(0.0, 0.15, u) * (1.0 - smoothstep(0.8, 1.0, u));
		float flare = 1.0 + 1.5 * exp(-pow((u - 0.78) / 0.06, 2.0));
		float len = 0.16 * min(1.0, u * 3.0);
		float tl = clamp(along / max(len, 1e-4), 0.0, 1.0);
		float tail = step(0.0, along) * (1.0 - smoothstep(0.6, 1.0, tl)) * exp(-across * across / pow(0.0022 * (1.0 - tl * 0.7), 2.0));
		vec3 tcol = mix(vec3(1.0, 0.98, 0.92), vec3(0.45, 0.65, 1.0), tl);
		float headg = exp(-dot(q, q) / 0.00002) * 2.5 + exp(-dot(q, q) / 0.0004) * 0.35;
		float sparks = 0.0;
		for (int i = 0; i < 4; i++) {
			float si = float(i);
			float st = fract(u * 2.0 + si * 0.27);
			vec2 sp = head - dir * (0.03 + si * 0.025) + vec2(hash(vec2(cyc, si + 5.0)) - 0.5, hash(vec2(cyc, si + 9.0))) * 0.012 * st;
			vec2 sq = (uv - sp) * vec2(asp, 1.0);
			sparks += exp(-dot(sq, sq) / 0.000006) * (1.0 - st);
		}
		sky += (tcol * tail * 0.9 + vec3(1.0) * headg * flare + vec3(0.8, 0.9, 1.0) * sparks * 0.8) * life;
	}
	// the curtains: one high and broad, one lower and brighter, a third faint and far
	// three ribbons across the sky: a big one sweeping from high on one side down across the middle, a second bending
	// the other way lower, a faint third high up
	vec3 aur = ribbon(uv, 0.3, 0.16, 3.1, 0.0, t, 1.0) + ribbon(uv, 0.52, 0.12, 2.3, 3.7, t, 0.7)
		+ ribbon(uv, 0.14, 0.07, 4.2, 7.1, t, 0.45);
	// (lower down a little dimmer: the stone stands against it)
	aur *= 1.0 - 0.45 * smoothstep(0.55, 0.85, uv.y);
	aur = aur / (1.0 + aur * 0.6);
	ALBEDO = (sky + aur * 0.7) * k;
}
