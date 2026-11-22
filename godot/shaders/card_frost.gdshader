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
// not alike, side to side (22.11: "grow it asymmetrically"): each side (bottom, top, left, right) starts at its own
// moment of the growth (sd), grows at its own pace (ss), and spreads along the rim from its own point (sa, 0..1 along)
uniform vec4 sd = vec4(0.0);
uniform vec4 ss = vec4(1.0);
uniform vec4 sa = vec4(0.5);

float h11(float x) { return fract(sin(x * 127.1) * 43758.5453); }
float n1(float x) { float i = floor(x); float f = fract(x); f = f * f * (3.0 - 2.0 * f); return mix(h11(i), h11(i + 1.0), f); }
float h21(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float n2(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0)), f.x), f.y);
}

// one side: `a` along it, `d` in from it (points), `len` its length; i — which side (its own start, pace, spot)
// The frost shows as it grows ALONG its fronds (strip.g: how far a point is from the root along the frost, worked out
// from the picture), so the front runs out along each frond, the tips last — not on a line parallel to the rim
// (22.11: "rectangles in the growth" — fronts parallel to each side met at right angles).
float side(float a, float d, float len, float salt, float i0, float i1, float i2, float i3) {
	float u = d / depth;
	// (no early return before the texture is read: a branch there broke the GPU's choice of the texture's blur)
	// (the strip repeats along the rim, and so — the texture's own setting — up and down too: its blur near u = 1 drew
	// in the dense rime of its root row, a straight line at the strip's depth; the tips' end fades out before it)
	float inside = step(0.0, u) * (1.0 - smoothstep(0.82, 0.97, u));
	vec2 tx = texture(strip, vec2(a / (depth * 2.1) + salt * 0.37, 1.0 - clamp(u, 0.0, 1.0))).rg;
	float st = i0 * sd.x + i1 * sd.y + i2 * sd.z + i3 * sd.w;
	float sp = i0 * ss.x + i1 * ss.y + i2 * ss.z + i3 * ss.w;
	float at = i0 * sa.x + i1 * sa.y + i2 * sa.z + i3 * sa.w;
	float g = clamp((grow - st) / max(0.05, 1.0 - st), 0.0, 1.0) * sp;
	// spreading along the rim from its spot, and in waves along it: here long fronds, there only the rime
	float n = n1(a / 70.0 + salt * 17.0) * 0.65 + n1(a / 23.0 + salt * 5.0) * 0.35;
	float spread = clamp(g * 2.2 - abs(a / max(len, 1.0) - at) * 1.6, 0.0, 1.0);
	// the thaw is the growth backward, along the same fronds: the tips go first, the rime on the rim last
	// (22.11: thawing in patches of a value noise cut square holes — its cells show)
	float reach = spread * (0.35 + 0.75 * n) * 1.05 * (1.0 - thaw * (1.05 + 0.25 * n));
	float shown = 1.0 - smoothstep(reach - 0.08, reach, tx.g);
	return tx.r * shown * inside;
}

void fragment() {
	vec2 lp = UV * rsize;
	vec2 zs = zone > 0.5 ? rsize : card;
	vec2 zp = zone > 0.5 ? lp : origin + lp;
	// the four sides, each with its roots on its own edge
	float fr = max(max(side(zp.x, zs.y - zp.y, zs.x, 0.0, 1.0, 0.0, 0.0, 0.0), side(zs.x - zp.x, zp.y, zs.x, 1.0, 0.0, 1.0, 0.0, 0.0)),
		max(side(zp.y, zp.x, zs.y, 2.0, 0.0, 0.0, 1.0, 0.0), side(zs.y - zp.y, zs.x - zp.x, zs.y, 3.0, 0.0, 0.0, 0.0, 1.0)));
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
