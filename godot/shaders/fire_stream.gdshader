shader_type canvas_item;
// Fire Horizon's acid stream (its own layer, cut from the picture: the picture's colour, alpha = the water of its bed).
// The water runs down: long soft streaks of light slide down it (value noise stretched along the fall, moving with
// TIME), darker runs between them, and the colour wobbles a little sideways; a few glints flash and go. `speed` in
// texture px a second.

uniform float speed = 40.0;
uniform float on = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec2 p = UV / px;
	float a = texture(TEXTURE, UV).a;
	if (a < 0.01) discard;
	float w = sin(p.y * 0.32 + TIME * 2.1) * 0.9 + sin(p.y * 0.13 - TIME * 1.3) * 0.6;
	vec3 src = texture(TEXTURE, UV + vec2(w * px.x, 0.0)).rgb;
	float run = TIME * speed;
	float f1 = vnoise(vec2(p.x * 0.30, (p.y - run) * 0.07));
	float f2 = vnoise(vec2(p.x * 0.55 + 7.0, (p.y - run * 1.6) * 0.12));
	float lit = smoothstep(0.62, 0.92, f1 * 0.65 + f2 * 0.35);
	float dark = smoothstep(0.38, 0.12, f1);
	vec3 col = src * (1.0 - 0.34 * dark) + vec3(0.78, 0.9, 0.84) * lit * 0.58;
	float g = hash(floor(vec2(p.x * 0.5, (p.y - run * 1.2) * 0.25)));
	col += vec3(0.9, 1.0, 0.95) * step(0.985, g) * 0.5 * (0.5 + 0.5 * sin(TIME * 9.0 + g * 40.0));
	COLOR = vec4(col, a * on * COLOR.a);
}
