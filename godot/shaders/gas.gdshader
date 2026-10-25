shader_type canvas_item;
// Pockets of toxic gas on the board. Every gas cell is drawn as a quad a little larger than the cell; its colour
// carries which neighbours are gas too (COLOR.r = left 1 + right 2 + up 4 + down 8, over 15), and the cloud
// stretches out to meet them, so gas cells side by side make one tunnel. The smoke itself is computed in board space,
// so it flows across cells without a seam: slow domain-warped noise, glowing at its heart, ragged at its rim.

uniform float cell_px = 60.0;       // one cell, in pixels
uniform float overhang = 1.3;       // the quad's size, in cells
uniform vec3 deep : source_color = vec3(0.02, 0.16, 0.03);
uniform vec3 mid : source_color = vec3(0.3, 0.72, 0.08);
uniform vec3 hot : source_color = vec3(0.78, 1.0, 0.3);
uniform float speed = 0.22;

varying vec2 bpos;      // board position, in cells

void vertex() {
	bpos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy / cell_px;
}

// a hash without sin(): sin of large numbers loses precision on phones and the smoke turns blocky
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

void fragment() {
	int m = int(COLOR.r * 15.0 + 0.5);
	bool L = (m & 1) != 0, R = (m & 2) != 0, U = (m & 4) != 0, D = (m & 8) != 0;
	// position in the cell, -1..1 across the cell itself; the quad overhangs it
	vec2 p = (UV * 2.0 - 1.0) * overhang;
	// the cloud's box: a rounded square inside the cell, pushed out to the cell's edge (and past it) towards gas neighbours
	// towards a gas neighbour the box runs well past the cell's edge (its rounded corner out of sight), and the
	// quad stops exactly at that edge: the neighbour draws the rest, the same smoke, so no seam and no overlap
	if ((L && p.x < -1.0) || (R && p.x > 1.0) || (U && p.y < -1.0) || (D && p.y > 1.0)) discard;
	float lo_x = L ? -1.6 : -0.78, hi_x = R ? 1.6 : 0.78;
	float lo_y = U ? -1.6 : -0.78, hi_y = D ? 1.6 : 0.78;
	vec2 c = vec2(lo_x + hi_x, lo_y + hi_y) * 0.5;
	vec2 h = vec2(hi_x - lo_x, hi_y - lo_y) * 0.5;
	vec2 q = abs(p - c) - h + 0.3;
	float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - 0.3;     // < 0 inside
	// a ragged, drifting rim
	float t = TIME * speed;
	float rim = fbm(bpos * 2.6 + vec2(t * 1.3, -t));
	d += (rim - 0.5) * 0.55;
	float body = 1.0 - smoothstep(-0.25, 0.05, d);
	// the smoke: noise warped by noise, flowing slowly
	vec2 w = vec2(fbm(bpos * 1.4 + vec2(0.0, t)), fbm(bpos * 1.4 + vec2(5.2, -t * 0.8)));
	float s = fbm(bpos * 1.8 + w * 2.2 + vec2(t * 0.6, t * 0.3));
	float swirl = smoothstep(0.2, 0.9, s);
	// brighter where the cloud is thickest
	float core = smoothstep(0.0, -0.7, d);
	vec3 col = mix(deep, mid, swirl);
	col = mix(col, hot, swirl * swirl * (0.35 + 0.65 * core) * (0.75 + 0.25 * sin(TIME * 1.3 + bpos.x * 0.7 + bpos.y)));
	float a = body * (0.68 + 0.3 * swirl);
	COLOR = vec4(col, a);
}
