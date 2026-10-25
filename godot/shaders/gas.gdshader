shader_type canvas_item;
// Pockets of toxic gas on the board. Every gas cell is drawn as a quad a little larger than the cell; its colour
// carries which neighbours are gas too (COLOR.r = left 1 + right 2 + up 4 + down 8, over 15), and the cloud
// stretches out to meet them, so gas cells side by side make one tunnel. The smoke is computed in board space, so it
// flows across cells without a seam. It is shaded like everything else on the board: its puffs lit from the top
// left, in shadow at the bottom right, thin enough for the stone tile to show through; a few bubbles rise in it.

uniform float cell_px = 60.0;       // one cell, in pixels
uniform float overhang = 1.3;       // the quad's size, in cells
uniform vec3 shade : source_color = vec3(0.07, 0.1, 0.02);
uniform vec3 body_col : source_color = vec3(0.36, 0.45, 0.1);
uniform vec3 lit : source_color = vec3(0.72, 0.8, 0.32);
uniform vec3 toxic : source_color = vec3(0.75, 1.0, 0.25);
uniform float speed = 0.16;

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

// how thick the smoke is at a board position: billowing puffs, drifting slowly
float smoke(vec2 b, float t) {
	vec2 w = vec2(fbm(b * 1.3 + vec2(0.0, t)), fbm(b * 1.3 + vec2(5.2, -t * 0.8)));
	return fbm(b * 2.0 + w * 1.8 + vec2(t * 0.5, -t * 0.7));
}

// signed distance to a rounded box (half size h, corner radius r), < 0 inside
float box(vec2 p, vec2 h, float r) {
	vec2 q = abs(p) - h + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}
// a smooth union: the inner corner of an elbow fills in with a soft curve
float smin(float a, float b, float k) {
	float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
	return mix(b, a, h) - k * h * (1.0 - h);
}

void fragment() {
	int m = int(COLOR.r * 15.0 + 0.5);
	bool L = (m & 1) != 0, R = (m & 2) != 0, U = (m & 4) != 0, D = (m & 8) != 0;
	// position in the cell, -1..1 across the cell itself; the quad overhangs it
	vec2 p = (UV * 2.0 - 1.0) * overhang;
	// the cloud: a rounded square in the cell, joined smoothly to a band running out to each gas neighbour. Across
	// a shared edge both cells draw the same band (|other axis| < W), so the tunnel continues without a step; the quad
	// stops exactly at that edge, and the neighbour draws the rest
	if ((L && p.x < -1.0) || (R && p.x > 1.0) || (U && p.y < -1.0) || (D && p.y > 1.0)) discard;
	float W = 0.86;
	float d = box(p, vec2(W), 0.35);
	if (L) d = smin(d, box(p - vec2(-0.9, 0.0), vec2(0.9, W), 0.2), 0.3);
	if (R) d = smin(d, box(p - vec2(0.9, 0.0), vec2(0.9, W), 0.2), 0.3);
	if (U) d = smin(d, box(p - vec2(0.0, -0.9), vec2(W, 0.9), 0.2), 0.3);
	if (D) d = smin(d, box(p - vec2(0.0, 0.9), vec2(W, 0.9), 0.2), 0.3);
	float t = TIME * speed;
	// a billowing, drifting rim
	d += (fbm(bpos * 2.4 + vec2(t * 1.2, -t)) - 0.5) * 0.6;
	float body = 1.0 - smoothstep(-0.35, 0.05, d);
	// the puffs, and their light: thicker towards the lamp than here means this side faces away from it
	float s = smoke(bpos, t);
	float toward = smoke(bpos + vec2(-0.06, -0.06), t);
	float light = clamp(0.5 + (s - toward) * 7.0, 0.0, 1.0);
	float dense = smoothstep(0.15, 0.65, s) * body;
	vec3 col = mix(shade, body_col, smoothstep(0.0, 0.6, dense));
	col = mix(col, lit, light * dense * 0.8);
	// thin poisonous threads glowing in the thickest smoke, slowly brightening and fading
	float vein = 1.0 - smoothstep(0.0, 0.05, abs(fbm(bpos * 3.2 + vec2(-t, t * 0.6)) - 0.5));
	col = mix(col, toxic, vein * dense * (0.5 + 0.5 * sin(TIME * 1.1 + bpos.x * 0.9 + bpos.y * 0.6)));
	// bubbles rising through the cloud
	vec2 g = vec2(bpos.x * 6.0, bpos.y * 3.0 + TIME * 0.35);
	vec2 gi = floor(g), gf = fract(g) - 0.5;
	float own = hash(gi + 7.0);
	float bub = own > 0.86 ? 1.0 - smoothstep(0.08, 0.16, length(gf * vec2(1.0, 2.0) + vec2(own - 0.93, 0.0) * 3.0)) : 0.0;
	col = mix(col, toxic, bub * body * 0.8);
	// thin enough that the tile shows through where the smoke thins out
	float a = body * (0.55 + 0.4 * smoothstep(0.1, 0.65, s)) + bub * body * 0.4;
	COLOR = vec4(col, clamp(a, 0.0, 0.92));
}
