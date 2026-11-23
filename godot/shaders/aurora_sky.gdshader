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
// one curtain: a hem wandering across the sky at height y0, rays rising off it
vec3 curtain(vec2 uv, float y0, float sh, float t, float amp) {
	float x = uv.x;
	float hem = y0 + 0.06 * sin(x * 3.1 + t * 0.21 + sh) + 0.035 * sin(x * 7.3 - t * 0.33 + sh * 2.0)
		+ (fbm(vec2(x * 4.0 + sh, t * 0.07)) - 0.5) * 0.08;
	float above = hem - uv.y;            // how far above the hem (the screen's y runs down)
	if (above < -0.03) return vec3(0.0);
	float rays = fbm(vec2(x * 55.0 + sh * 10.0, t * 0.5 + above * 3.0));
	rays = 0.35 + 0.65 * smoothstep(0.3, 0.8, rays);
	float fine = 0.75 + 0.25 * noise(vec2(x * 180.0, t * 1.4));
	float lift = smoothstep(-0.03, 0.02, above) * exp(-max(above, 0.0) * 6.5);
	float piece = smoothstep(0.25, 0.8, fbm(vec2(x * 2.2 + sh * 3.0 - t * 0.04, t * 0.05)));
	vec3 green = vec3(0.12, 1.0, 0.45);
	vec3 violet = vec3(0.55, 0.2, 1.0);
	vec3 pink = vec3(1.0, 0.3, 0.55);
	vec3 col = mix(green, violet, smoothstep(0.08, 0.32, above));
	col = mix(col, pink, smoothstep(-0.02, 0.0, above) * (1.0 - smoothstep(0.0, 0.025, above)) * 0.5);
	return col * lift * rays * fine * piece * amp;
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
	// now and then a falling star across the top
	float cyc = floor(t / 7.0);
	float ft = fract(t / 7.0);
	if (hash(vec2(cyc, seed)) > 0.4 && ft < 0.12) {
		vec2 a = vec2(hash(vec2(cyc, 1.0)) * 0.8 + 0.1, hash(vec2(cyc, 2.0)) * 0.25 + 0.03);
		vec2 dir = normalize(vec2(0.8, 0.35) * vec2(hash(vec2(cyc, 3.0)) > 0.5 ? 1.0 : -1.0, 1.0));
		vec2 head = a + dir * ft * 3.0;
		vec2 q = (uv - head) * vec2(VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, 1.0);
		float along = dot(q, -dir);
		float across = abs(q.x * dir.y - q.y * dir.x);
		float trail = smoothstep(0.0, 0.002, along) * (1.0 - smoothstep(0.0, 0.12, along)) * (1.0 - smoothstep(0.0, 0.0035, across));
		sky += vec3(0.9, 0.95, 1.0) * trail * (1.0 - ft / 0.12) * 1.5;
	}
	// the curtains: one high and broad, one lower and brighter, a third faint and far
	vec3 aur = curtain(uv, 0.34, 0.0, t, 1.0) + curtain(uv, 0.22, 3.7, t * 0.8, 0.6) + curtain(uv, 0.46, 7.1, t * 1.2, 0.3);
	// (the lower half of the window kept dark: the stone stands against the night)
	aur *= 1.0 - smoothstep(0.42, 0.62, uv.y);
	ALBEDO = (sky + aur * 0.45) * k;
}
