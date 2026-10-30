shader_type canvas_item;
// Molten sulphur on Brontes' boards: a pool over each of its cells that runs into its neighbours, as the gas does
// (each cell a quad a little larger than the cell, COLOR.r = left 1 + right 2 + up 4 + down 8, over 15; the pool
// reaches out to meet them). The liquid is computed in board space, so it flows across cells without a seam: deep
// blood-orange where it is hottest, amber, a darker cooling skin drifting on it, bright yellow currents, a glossy
// rim lit from the top left, and the burning sulphur's blue flames licking over it here and there.

uniform float cell_px = 60.0;       // one cell, in pixels
uniform float overhang = 1.25;      // the quad's size, in cells
uniform vec3 deep : source_color = vec3(0.45, 0.07, 0.02);
uniform vec3 amber : source_color = vec3(0.93, 0.48, 0.07);
uniform vec3 hot : source_color = vec3(1.0, 0.86, 0.3);
uniform vec3 skin : source_color = vec3(0.24, 0.11, 0.04);
uniform vec3 flame : source_color = vec3(0.35, 0.55, 1.0);
uniform float speed = 0.22;

varying vec2 bpos;      // board position, in cells

void vertex() {
	bpos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy / cell_px;
}

// a hash without sin(): sin of large numbers loses precision on phones
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
	for (int k = 0; k < 4; k++) { s += a * noise(p); p = p * 2.03 + vec2(1.7, 9.2); a *= 0.5; }
	return s;
}
float box(vec2 p, vec2 h, float r) {
	vec2 q = abs(p) - h + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}
float smin(float a, float b, float k) {
	float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
	return mix(b, a, h) - k * h * (1.0 - h);
}

// the liquid's flow: warped noise drifting slowly downhill (down the board)
float flow(vec2 b, float t) {
	vec2 w = vec2(fbm(b * 1.1 + vec2(0.0, -t)), fbm(b * 1.1 + vec2(4.1, -t * 0.7)));
	return fbm(b * 1.8 + w * 1.6 + vec2(t * 0.2, -t * 0.9));
}

void fragment() {
	int m = int(COLOR.r * 15.0 + 0.5);
	bool L = (m & 1) != 0, R = (m & 2) != 0, U = (m & 4) != 0, D = (m & 8) != 0;
	vec2 p = (UV * 2.0 - 1.0) * overhang;
	if ((L && p.x < -1.0) || (R && p.x > 1.0) || (U && p.y < -1.0) || (D && p.y > 1.0)) discard;
	float W = 0.88;
	float d = box(p, vec2(W), 0.42);
	if (L) d = smin(d, box(p - vec2(-0.9, 0.0), vec2(0.9, W), 0.2), 0.3);
	if (R) d = smin(d, box(p - vec2(0.9, 0.0), vec2(0.9, W), 0.2), 0.3);
	if (U) d = smin(d, box(p - vec2(0.0, -0.9), vec2(W, 0.9), 0.2), 0.3);
	if (D) d = smin(d, box(p - vec2(0.0, 0.9), vec2(W, 0.9), 0.2), 0.3);
	float t = TIME * speed;
	// a slowly wobbling edge
	d += (fbm(bpos * 3.0 + vec2(t, -t)) - 0.5) * 0.28;
	float body = 1.0 - smoothstep(-0.06, 0.02, d);
	if (body <= 0.0) discard;
	float f = flow(bpos, t);
	vec3 col = mix(deep, amber, smoothstep(0.3, 0.62, f));
	// bright currents where the flow folds
	float cur = 1.0 - smoothstep(0.0, 0.07, abs(fbm(bpos * 2.6 + vec2(-t * 0.5, -t * 1.4)) - 0.5));
	col = mix(col, hot, cur * 0.85);
	// a darker skin cooling on top, broken by the currents
	float sk = smoothstep(0.56, 0.7, fbm(bpos * 3.4 + vec2(t * 0.3, -t * 0.5) + 11.0)) * (1.0 - cur);
	col = mix(col, skin, sk * 0.75);
	// glossy: the lamp at the top left glints off the swell of the surface, the far edge rims dark
	float toward = flow(bpos + vec2(-0.05, -0.05), t);
	float lit = clamp((f - toward) * 9.0, 0.0, 1.0);
	col += vec3(1.0, 0.92, 0.7) * lit * 0.35 * (1.0 - sk);
	float rim = smoothstep(-0.32, -0.04, d);
	col = mix(col, deep * 0.5, rim * 0.6);
	// the burning sulphur's blue flames: tongues rising off the surface, flickering in and out
	vec2 g = vec2(bpos.x * 3.0, bpos.y * 2.0 - TIME * 0.6);
	float fl = fbm(g + vec2(0.0, -TIME * 0.4));
	float live = smoothstep(0.55, 0.75, noise(floor(bpos * 1.5) + floor(TIME * 0.7)) * 0.4 + fbm(bpos * 0.8 + TIME * 0.15));
	float tongue = smoothstep(0.58, 0.8, fl) * live;
	col = mix(col, flame, tongue * 0.7);
	col += flame * tongue * 0.35;
	COLOR = vec4(col, body * 0.97);
}
