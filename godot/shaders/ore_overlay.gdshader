shader_type canvas_item;
// Ore drawn over any gem sprite, for gem sets that have no ore versions of their own (and to compare looks).
// The sprite is the gem's own texture; its alpha keeps the ore on the stone. Every stone on its own rhythm.
//   mode 0  the mine's ore: glowing golden veins with a dark seam, breathing
//   mode 1  iron: little dark steel cubes, a cold glint sweeping over them now and then

uniform int mode = 0;
uniform vec3 hot : source_color = vec3(1.0, 0.78, 0.32);
uniform vec3 cold : source_color = vec3(0.7, 0.88, 1.0);

varying vec2 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xy;
}

vec2 hash2(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.103, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}
float hash(vec2 p) { return hash2(p).x; }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
// distance to the nearest edge between Voronoi cells: thin lines that branch like cracks
float edges(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	float d1 = 9.0, d2 = 9.0;
	for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
		vec2 g = vec2(float(x), float(y));
		vec2 o = hash2(i + g);
		float d = length(g + o - f);
		if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
	}
	return d2 - d1;
}

void fragment() {
	vec4 gem = texture(TEXTURE, UV);
	float inside = smoothstep(0.6, 0.95, gem.a);
	// pull the ore in from the outline a little: it is in the stone, not on its rim
	float seed = wpos.x * 0.031 + wpos.y * 0.047;
	vec2 q = UV + vec2(fract(seed * 13.1), fract(seed * 7.7));
	vec3 col = gem.rgb;
	if (mode == 0) {
		vec2 w = q * 3.0 + vec2(noise(q * 4.0), noise(q * 4.0 + 7.0)) * 0.6;
		float e = edges(w);
		float where = smoothstep(0.3, 0.45, noise(q * 2.6 + 3.0));
		// thick enough to read on a stone a fifth of the sprite's size
		float core = (1.0 - smoothstep(0.08, 0.13, e)) * where * inside;
		float seam = (1.0 - smoothstep(0.13, 0.22, e)) * where * inside;
		float breath = 0.65 + 0.35 * sin(TIME * 1.6 + seed * 9.0);
		col = mix(col, vec3(0.03, 0.02, 0.01), seam * 0.7);
		col = mix(col, hot * (1.1 + 0.9 * breath), core);   // above 1: it blooms under the board's glow
	} else {
		// a few cubes: cells of a coarse grid, some holding one, its face lit from the top left
		vec2 g = q * 3.6;
		vec2 gi = floor(g), gf = fract(g) - 0.5;
		vec2 h = hash2(gi);
		float has = step(0.45, h.x) * inside;
		float a = h.y * 6.2832;
		mat2 rot = mat2(vec2(cos(a), -sin(a)), vec2(sin(a), cos(a)));
		vec2 p = rot * gf;
		float sz = 0.24 + 0.08 * h.y;
		float cube = (1.0 - smoothstep(sz, sz + 0.03, max(abs(p.x), abs(p.y)))) * has;
		float rim = (1.0 - smoothstep(sz + 0.03, sz + 0.08, max(abs(p.x), abs(p.y)))) * has;
		float face = clamp(0.75 - (p.x + p.y) * 1.4, 0.0, 1.0);     // lit towards the top left
		float sweep = fract(TIME * 0.45 + seed * 0.16);
		float glint = 1.0 - smoothstep(0.0, 0.08, abs(UV.x * 0.6 + (1.0 - UV.y) * 0.4 - sweep * 1.6 + 0.3));
		col = mix(col, vec3(0.02, 0.02, 0.025), rim * 0.8);
		col = mix(col, mix(vec3(0.2, 0.22, 0.26), cold * 1.4, face) + cold * glint * 1.4, cube);
	}
	COLOR = vec4(col, COLOR.a);   // COLOR already holds the texture times modulate: keep only its alpha
}
