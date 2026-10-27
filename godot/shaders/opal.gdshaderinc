// Noise helpers and precious opal, shared by the wood (shaders/wood.gdshader) and loose opal pieces.
// Colours are written as on screen (sRGB) and turned linear with lin().

float h3(vec3 p) { p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float vn(vec3 x) {
	vec3 i = floor(x), f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h3(i), h3(i + vec3(1, 0, 0)), f.x), mix(h3(i + vec3(0, 1, 0)), h3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(h3(i + vec3(0, 0, 1)), h3(i + vec3(1, 0, 1)), f.x), mix(h3(i + vec3(0, 1, 1)), h3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
float fbm(vec3 p) { return vn(p) * 0.5 + vn(p * 2.03) * 0.25 + vn(p * 4.01) * 0.125 + vn(p * 8.02) * 0.0625; }
vec3 lin(vec3 c) { return c * c * (c * 0.3 + 0.7); }
vec3 hue(float h) {
	vec3 c = clamp(abs(fract(h + vec3(1.0, 0.6667, 0.3333)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
	return c * c * (3.0 - 2.0 * c);
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
// the same, wrapping round: q.y in cells, period n cells (no seam where an angle jumps)
vec3 vor2w(vec2 q, float n) {
	vec2 c = floor(q);
	float d1 = 9.0, d2 = 9.0, id = 0.0;
	for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
		vec2 g = c + vec2(float(x), float(y));
		vec2 gw = vec2(g.x, mod(g.y, n));
		vec2 pt = g + vec2(h3(vec3(gw, 1.0)), h3(vec3(gw, 7.0))) * 0.8 + 0.1;
		float d = distance(pt, q);
		if (d < d1) { d2 = d1; d1 = d; id = h3(vec3(gw, 13.0)); } else if (d < d2) { d2 = d; }
	}
	return vec3(d1, d2 - d1, id);
}
// a bump from a height field, by fine screen derivatives
vec3 bump(vec3 n, vec3 pos, float h, float k) {
	vec3 dpx = dFdxFine(pos), dpy = dFdyFine(pos);
	float dhx = dFdxFine(h), dhy = dFdyFine(h);
	vec3 r1 = cross(dpy, n), r2 = cross(n, dpx);
	float det = dot(dpx, r1);
	vec3 g = sign(det) * (dhx * r1 + dhy * r2);
	return normalize(abs(det) * n - g * k);
}

// the opal's body under its fire: 0 dark (blue-black), 1 crystal (clear grey-blue), 2 honey (amber, fire-opal like)
vec3 opal_body_col(int body, vec3 p, float s) {
	float m = fbm(p * 3.0 + s + 70.0);
	if (body == 1) return mix(lin(vec3(0.24, 0.28, 0.33)), lin(vec3(0.5, 0.54, 0.58)), m);
	if (body == 2) return mix(lin(vec3(0.4, 0.18, 0.05)), lin(vec3(0.72, 0.42, 0.14)), m);
	return mix(lin(vec3(0.05, 0.08, 0.16)), lin(vec3(0.16, 0.24, 0.42)), m);
}

// the spectrum without the purples that join its ends: 0 red .. 1 violet (wraps)
vec3 spectral(float t) { return hue(fract(t) * 0.8); }

// Precious opal's play of colour at model point p, seen along v (model space, towards the eye), surface normal n:
// three layers at growing depth (shifted along the view: they slide over each other as the stone turns, which reads
// as depth). In each, wide soft clouds of colour whose hue drifts across them and with the angle, crisp little
// flakes of brighter colour inside the clouds (harlequin), every region lit only at some angles; over them pinfire
// sparks. fh: the main hue (0 red .. 1 violet); spread: how far the colours stray (0.5: the whole spectrum);
// s: a seed; t: time for a flowing (legendary) opal; k: its scale (bigger: smaller clouds); flk: how much of it is
// little crisp flakes (harlequin) rather than soft clouds; spk: how many pinfire sparks.
// Returns the light of the fire (add it over the body); glow: how bright it is.
vec3 opal_play(vec3 p, vec3 v, vec3 n, float fh, float spread, float s, float t, float k, float flk, float spk, out float glow) {
	float cosv = max(abs(dot(v, n)), 0.3);
	vec3 acc = vec3(0.0);
	float cover = 0.0;   // the nearer layers hide the deeper ones (adding them washed the colours out to white)
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		vec3 q = (p - v * (0.015 + 0.04 * fi) / cosv) * k + s + fi * 17.0;
		vec3 w = vec3(vn(q * 0.7), vn(q * 0.7 + 9.0), vn(q * 0.7 + 21.0)) - 0.5;
		float m = fbm(q * 1.1 + w * 1.6);
		float cloud = smoothstep(0.42, 0.62, m);
		float flake = smoothstep(0.56, 0.6, vn(q * (5.0 + fi * 2.0) + w * 3.0)) * smoothstep(0.45, 0.6, m);
		// each region throws its colour one way: lit only when seen from round that way
		vec3 gd = normalize(vec3(vn(q * 0.5 + 3.0), vn(q * 0.5 + 5.0), vn(q * 0.5 + 8.0)) - 0.5 + n * 0.25);
		float ang = dot(v, gd);
		float lit = 0.25 + 0.75 * smoothstep(0.2, 0.75, sin(ang * 6.0 + fi * 2.0 + t * 0.8) * 0.5 + 0.5);
		float h = fh + (fbm(q * 0.45 + 40.0) - 0.5) * spread * 6.0 + (vn(q * 1.6 + 60.0) - 0.5) * spread * 1.5 + ang * 0.2 + t * 0.05;
		vec3 col = spectral(h);
		float wt = clamp((cloud * 0.6 + flake * 0.9 * flk) * lit, 0.0, 1.0);
		acc += col * wt * (1.0 - cover) * (1.0 - 0.25 * fi) * 1.3;
		cover = min(1.0, cover + wt * 0.85);
	}
	// pinfire: tiny sparks, each flaring at its own angle
	// (in the clouds, mostly: a dark patch has few)
	vec3 sq = floor((p * k + s) * 70.0);
	float r = h3(sq + 3.0);
	float near = dot(acc, vec3(0.3, 0.5, 0.2));
	float sp = step(1.0 - 0.06 * spk - near * 0.08 * spk, r) * smoothstep(0.75, 1.0, sin(dot(v, vec3(r, h3(sq + 5.0), h3(sq + 9.0)) - 0.5) * 30.0 + r * 40.0 + t) * 0.5 + 0.5);
	acc += mix(spectral(fh + (h3(sq + 11.0) - 0.5) * spread * 4.0), vec3(1.0), 0.3) * sp * (0.6 + 1.4 * h3(sq + 13.0));
	glow = dot(acc, vec3(0.3, 0.5, 0.2));
	return acc;
}
