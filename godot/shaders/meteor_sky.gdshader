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
	// the meteors: each slot falls once in its own period, down and to the left — every one at its own slant, length
	// and brightness (26.11: all alike, a wave of five read as a pattern); one in a dozen a fireball: slower, thicker,
	// warm, flaring at its end. The shower comes in waves
	float wave = 0.35 + 0.65 * smoothstep(-0.2, 0.6, sin(TIME * 0.32 + seed));
	for (int i = 0; i < 9; i++) {
		float fi = float(i);
		float per = 2.1 + h1(fi * 3.7) * 3.4;
		float tt = TIME / per + h1(fi * 9.1);
		float n = floor(tt);
		float big = step(0.92, h1(n * 3.3 + fi * 1.7));
		float dur = mix(0.5 + 0.5 * h1(n * 6.1 + fi), 1.5, big);
		float u = fract(tt) * per / dur;
		if (u > 1.0 || (big < 0.5 && h1(n * 1.31 + fi) > wave)) continue;
		float sl = -0.55 + (h1(n * 4.7 + fi * 3.0) - 0.5) * 0.5;
		vec2 dir = normalize(vec2(sl, 1.0));
		vec2 nrm = vec2(dir.y, -dir.x);
		vec2 from = vec2((0.15 + 1.1 * h1(n * 7.3 + fi * 2.0)) * asp, -0.05 + 0.5 * h1(n * 5.1 + fi));
		float len = (0.2 + 0.45 * h1(n * 2.9 + fi * 5.0)) * mix(1.0, 1.5, big);
		float bright = mix(0.35 + 0.65 * h1(n * 8.3 + fi), 1.6, big);
		vec2 head = from + dir * len * u;
		vec2 rel = p - head;
		float along = -dot(rel, dir);                // behind the head: > 0
		float off = abs(dot(rel, nrm));
		float tail = (0.07 + 0.13 * h1(n + fi * 4.0)) * mix(1.0, 1.6, big);
		float wide = mix(0.0035, 0.008, big);
		float body = step(0.0, along) * (1.0 - smoothstep(0.0, tail, along)) * (1.0 - smoothstep(0.0, wide * (1.0 - along / tail) + 0.0008, off));
		float glow = exp(-dot(rel, rel) / mix(0.00008, 0.0004, big));
		float life = smoothstep(0.0, 0.12, u) * (1.0 - smoothstep(0.7, 1.0, u));
		// (a fireball flares as it dies)
		float burst = big * exp(-pow((u - 0.82) / 0.07, 2.0)) * exp(-dot(rel, rel) / 0.004) * 1.2;
		vec3 tint = mix(vec3(0.8, 0.88, 1.0), vec3(1.0, 0.85, 0.6), big);
		c += (tint * body * 0.9 + vec3(1.0) * glow * 1.4) * life * bright + tint * burst;
	}
	float a = clamp(max(c.r, max(c.g, c.b)), 0.0, 1.0);
	ALBEDO = c / max(a, 0.0001);
	ALPHA = a;
}
