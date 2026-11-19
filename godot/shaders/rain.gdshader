shader_type canvas_item;
// Rain over a card (SpecView.Rain): falling streaks in four depths, drawn in screen space. Each depth is a lattice of
// columns, each column its own phase and speed; a drop is a thin streak, its head a little round and brightest, its
// tail fading upward (the motion blur rain is seen as); the far ones fine and dim and dense, the near ones fewer,
// wider, softer (out of focus). All slanted by a swaying gust. on: how much rain (0..1).

uniform float on = 0.0;
uniform float aspect = 1.0;   // height / width of the rect
uniform float seed = 0.0;

float h1(float x) { return fract(sin(x * 127.1 + seed * 13.7) * 43758.5453); }

float layer(vec2 uv, float cols, float speed, float len, float width, float blur, float dens, float t) {
	uv.x *= cols;
	float c = floor(uv.x);
	float fx = fract(uv.x);
	float r1 = h1(c), r2 = h1(c + 31.7), r3 = h1(c + 77.3);
	if (r3 > dens) return 0.0;
	// down the column: one drop per period, the period in screen heights
	float per = 1.0 + r2 * 1.2;
	float y = fract((uv.y - t * speed * (0.85 + 0.3 * r1)) / per + r1) * per;   // 0 at the head .. up the tail
	float x0 = 0.25 + 0.5 * r2;
	float dx = abs(fx - x0) * (1.0 / cols);   // in screen widths
	float core = 1.0 - smoothstep(width * 0.5, width * 0.5 + blur, dx);
	float tail = smoothstep(len, 0.0, y) * smoothstep(-0.004, 0.006, y);
	float head = smoothstep(width * 2.2 + blur, 0.0, length(vec2(dx, y * 0.45)));
	return max(core * tail * (0.35 + 0.65 * (1.0 - y / len)), head * 0.9);
}

void fragment() {
	float t = TIME;
	vec2 uv = UV;
	uv.y *= aspect;
	float gust = 0.13 + 0.05 * sin(t * 1.9);
	uv.x += uv.y * gust;   // slanted: lower down, the streaks have moved over
	float a = 0.0;
	a += layer(uv + vec2(0.11, 0.0), 90.0, 2.2, 0.06, 0.0012, 0.0008, 0.55, t) * 0.28;
	a += layer(uv + vec2(0.37, 0.3), 55.0, 2.7, 0.09, 0.0018, 0.0012, 0.5, t) * 0.42;
	a += layer(uv + vec2(0.73, 0.6), 28.0, 3.3, 0.14, 0.0028, 0.002, 0.45, t) * 0.6;
	a += layer(uv + vec2(0.29, 0.1), 9.0, 4.2, 0.26, 0.007, 0.008, 0.5, t) * 0.32;
	COLOR = vec4(vec3(0.85, 0.92, 1.0), clamp(a, 0.0, 1.0) * on);
}
