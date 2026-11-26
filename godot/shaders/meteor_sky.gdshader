shader_type spatial;
// A meteor shower behind a starry-sky stone (SpecStudio.set_meteors): a quad on the studio's camera, behind the find,
// its light added — far faint stars, and meteors falling aslant, each a bright head and a thin tail, a few a second at
// the shower's height, then a lull.
render_mode unshaded, blend_add, cull_disabled, shadows_disabled, depth_draw_never;

uniform float seed = 0.0;

float h1(float x) { return fract(sin(x * 127.1 + seed) * 43758.5453); }
float h2(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float asp = VIEWPORT_SIZE.x / VIEWPORT_SIZE.y;
	vec2 p = vec2(uv.x * asp, uv.y);
	vec3 c = vec3(0.0);
	// far stars, still and faint
	vec2 q = p * 46.0;
	vec2 cell = floor(q);
	float r = h2(cell + seed);
	float d = length(fract(q) - 0.5 - (vec2(h2(cell + 3.0), h2(cell + 7.0)) - 0.5) * 0.6);
	c += vec3(0.75, 0.82, 1.0) * step(0.9, r) * (1.0 - smoothstep(0.0, 0.11, d)) * (0.25 + 0.2 * sin(TIME * (1.0 + r * 3.0) + r * 30.0));
	// the meteors: each slot falls once in its own period, down and to the left
	vec2 dir = normalize(vec2(-0.55, 1.0));
	vec2 nrm = vec2(dir.y, -dir.x);
	// (the shower comes in waves)
	float wave = 0.35 + 0.65 * smoothstep(-0.2, 0.6, sin(TIME * 0.32 + seed));
	for (int i = 0; i < 9; i++) {
		float fi = float(i);
		float per = 2.1 + h1(fi * 3.7) * 3.4;
		float tt = TIME / per + h1(fi * 9.1);
		float n = floor(tt);
		float u = fract(tt) * per / 0.75;           // 0..1 over its 0.75 s of flight
		if (u > 1.0 || h1(n * 1.31 + fi) > wave) continue;
		vec2 from = vec2((0.15 + 1.1 * h1(n * 7.3 + fi * 2.0)) * asp, -0.05 + 0.5 * h1(n * 5.1 + fi));
		float len = 0.34 + 0.3 * h1(n * 2.9 + fi * 5.0);
		vec2 head = from + dir * len * u;
		vec2 rel = p - head;
		float along = -dot(rel, dir);                // behind the head: > 0
		float off = abs(dot(rel, nrm));
		float tail = 0.11 + 0.1 * h1(n + fi * 4.0);
		float body = step(0.0, along) * (1.0 - smoothstep(0.0, tail, along)) * (1.0 - smoothstep(0.0, 0.0035 * (1.0 - along / tail) + 0.0008, off));
		float glow = exp(-dot(rel, rel) / 0.00008);
		float life = smoothstep(0.0, 0.12, u) * (1.0 - smoothstep(0.7, 1.0, u));
		c += (vec3(0.8, 0.88, 1.0) * body * 0.9 + vec3(1.0) * glow * 1.4) * life;
	}
	float a = clamp(max(c.r, max(c.g, c.b)), 0.0, 1.0);
	ALBEDO = c / max(a, 0.0001);
	ALPHA = a;
}
