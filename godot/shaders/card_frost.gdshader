shader_type canvas_item;
// The frost bloom of a find out on its card (CardFrost): frost growing in from the rim, as frost creeps in from a window
// frame — rooted on the rim, its fronds reaching inward. A strip of frost grown from an edge (strip: GPT,
// art/frost_card/gen_strip.sh — rooted on its bottom edge, reaching up) is laid along each of a zone's four sides,
// turned so its roots are on that side; it is shown from the root outward as it grows, its reach wandering along the
// side, and thaws from the tips back. (22.11: a photo of frost revealed near the rim had fronds pointing anywhere —
// islands, tips toward the frame.) Two zones, each its own rim: the stone's frame (its oval kept clear) and the info
// panel. Drawn over the zone's ground, under what is on it.
render_mode blend_mix;
uniform sampler2D strip : filter_linear_mipmap, repeat_enable;
uniform vec2 card = vec2(360.0, 700.0);
uniform vec2 origin = vec2(0.0);
uniform vec2 rsize = vec2(360.0, 700.0);
uniform float grow = 0.0;    // 0..1: how far out the fronds have reached (1: the whole strip)
uniform float thaw = 0.0;
uniform float depth = 150.0; // how deep the strip runs in from the rim, points
uniform float zone = 0.0;    // 0: the stone's frame, 1: the info panel

float h11(float x) { return fract(sin(x * 127.1) * 43758.5453); }
float n1(float x) { float i = floor(x); float f = fract(x); f = f * f * (3.0 - 2.0 * f); return mix(h11(i), h11(i + 1.0), f); }
float h21(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float n2(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0)), f.x), f.y);
}

// one side: `a` along it, `d` in from it (points); salt — its own stretch of the strip and its own wander
float side(float a, float d, float salt) {
	float u = d / depth;
	// (no early return before the texture is read: a branch there broke the GPU's choice of the texture's blur along
	// the lines where another side's strip ends — the frost came out with square holes; the strip is masked after)
	float inside = step(0.0, u) * step(u, 1.0);
	float f = texture(strip, vec2(a / (depth * 2.1) + salt * 0.37, 1.0 - clamp(u, 0.0, 1.0))).r * inside;
	// (along the side the reach goes in waves: here long fronds, there only the rime on the rim)
	float n = n1(a / 85.0 + salt * 17.0) * 0.7 + n1(a / 31.0 + salt * 5.0) * 0.3;
	float reach = grow * (0.25 + 0.95 * n * n);
	// (the tips fade out ahead of the front, not cut off on a line)
	float shown = 1.0 - smoothstep(reach * 0.55, reach + 0.02, u);
	return f * shown;
}

void fragment() {
	vec2 lp = UV * rsize;
	vec2 zs = zone > 0.5 ? rsize : card;
	vec2 zp = zone > 0.5 ? lp : origin + lp;
	// the four sides, each with its roots on its own edge
	float fr = max(max(side(zp.x, zs.y - zp.y, 0.0), side(zs.x - zp.x, zp.y, 1.0)),
		max(side(zp.y, zp.x, 2.0), side(zs.y - zp.y, zs.x - zp.x, 3.0)));
	// the thaw: one for the whole zone, in patches (a soft noise over it), the inner frost first, the rim last
	// (22.11: each side thawing in bands along its own edge cut square holes where two sides met)
	float e = min(min(zp.x, zp.y), min(zs.x - zp.x, zs.y - zp.y)) / depth;
	float melt = (n2(zp / 55.0) * 0.6 + n2(zp / 19.0) * 0.4) * 0.5 + (1.0 - clamp(e, 0.0, 1.0)) * 0.35;
	fr *= 1.0 - smoothstep(melt - 0.12, melt + 0.04, thaw * 1.15);
	// the stone's oval stays clear
	if (zone < 0.5) {
		vec2 so = (origin + lp - card * vec2(0.5, 0.34)) / (card * vec2(0.36, 0.22));
		fr *= smoothstep(0.4, 1.4, dot(so, so));
	}
	vec3 col = mix(vec3(0.62, 0.76, 0.92), vec3(0.97, 0.99, 1.0), smoothstep(0.3, 0.9, fr));
	// single needles catching the light, one by one
	float h = h21(floor(lp / 6.0));
	float gl = step(0.985, h) * pow(0.5 + 0.5 * sin(TIME * 2.0 + h * 90.0), 16.0) * smoothstep(0.4, 0.8, fr);
	COLOR = vec4(min(col + vec3(gl), vec3(1.0)), clamp(fr * 0.72 + gl, 0.0, 1.0));
}
