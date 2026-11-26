shader_type canvas_item;
// The opal fire's card (CardOpal): the info panel's slate is precious opal — a dark body with a mosaic of angular
// patches of colour in it (the harlequin of the stone itself), each patch throwing its colour one way: it lights only
// when the card is tilted that way (`tilt`: the phone's own lean — a little tilt and other patches flash, as a real
// opal turned in the fingers), a band of light rolling across with the tilt. `part` 0: the same fire, faint, in the
// card's brass, its light added there; 1: the slate, under the panel's words.
// (COLOR comes in already multiplied by the texture: written whole here.)

uniform int part = 1;
uniform vec2 card = vec2(360.0, 640.0);
uniform float frame_in = 7.0;
uniform float frame_r = 12.0;
uniform float rim_top = 400.0;
uniform float rim_bot = 406.0;
uniform float rim_l = 30.0;
uniform float rim_r = 330.0;
uniform vec2 tilt = vec2(0.0);        // the lean: x right, y toward the viewer (about -1..1)
uniform float seed = 0.0;
uniform float fh = 0.55;              // the fire's main hue (0 red .. 1 violet)
uniform float spread = 0.3;           // how far its colours stray
uniform float k = 1.0;                // how much (it comes in)

float h2(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
float vn(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1, 0)), u.x), mix(h2(i + vec2(0, 1)), h2(i + vec2(1, 1)), u.x), u.y);
}
vec3 hue(float h) {
	vec3 c = clamp(abs(fract(h + vec3(1.0, 0.6667, 0.3333)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
	return c * c * (3.0 - 2.0 * c);
}
// the spectrum without the purples that join its ends (as opal.gdshaderinc)
vec3 spectral(float t) { return hue((1.0 - abs(fract(t * 0.5) * 2.0 - 1.0)) * 0.8); }

// one layer of the mosaic at q: rgb the fire, a its strength
vec4 layer(vec2 q, vec3 lean, float salt) {
	// drawn out a little one way and bent: ribbons and wedges, not a honeycomb
	q += (vec2(vn(q * 0.35 + salt), vn(q * 0.35 + salt + 5.0)) - 0.5) * 1.5;
	vec2 c = floor(q);
	float d1 = 9.0, d2 = 9.0;
	vec2 id1 = vec2(0.0), id2 = vec2(0.0);
	for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
		vec2 g = c + vec2(float(x), float(y));
		vec2 pt = g + vec2(h2(g + salt), h2(g + salt + 1.7)) * 0.85 + 0.075;
		float d = distance(pt, q);
		if (d < d1) { d2 = d1; id2 = id1; d1 = d; id1 = g; } else if (d < d2) { d2 = d; id2 = g; }
	}
	vec4 acc = vec4(0.0);
	for (int n = 0; n < 2; n++) {
		vec2 id = n == 0 ? id1 : id2;
		// (neighbours often one patch: big flashes of no regular shape among the small ones)
		vec2 big = floor(id * 0.45);
		float r = h2(id + salt + 3.0) < 0.55 ? h2(big + salt + 9.0) : h2(id + salt + 5.3);
		// the way this patch throws its colour
		vec3 gd = normalize(vec3(h2(vec2(r, 1.0)) - 0.5, h2(vec2(r, 2.0)) - 0.5, 0.55));
		float ang = dot(lean, gd);
		float lit = smoothstep(0.3, 0.92, sin(ang * 11.0 + r * 40.0) * 0.5 + 0.5);
		// across the patch the colour and the light shift a little: not a flat tile
		float across = dot(q - id, gd.xy);
		float h = fh + (r - 0.5) * spread * 4.0 + ang * 0.35 + across * 0.08;
		float on = step(0.16, h2(id + salt + 23.0));
		float w = n == 0 ? 0.5 + 0.5 * clamp((d2 - d1) / 0.12, 0.0, 1.0) : 0.5 - 0.5 * clamp((d2 - d1) / 0.12, 0.0, 1.0);
		acc += vec4(spectral(h), 1.0) * lit * on * w * (0.8 + 0.2 * sin(across * 9.0 + ang * 8.0));
	}
	return acc;
}

void fragment() {
	vec2 p = UV * card;
	vec2 cq = abs(p - card * 0.5) - card * 0.5 + frame_r;
	float e = -(length(max(cq, 0.0)) + min(max(cq.x, cq.y), 0.0) - frame_r);
	vec3 lean = normalize(vec3(tilt.x, tilt.y, 0.75));
	// two layers at two depths: the deeper one slides under the upper as the card leans (it reads as depth)
	vec4 f1 = layer(p / 21.0 + seed, lean, 0.0);
	vec4 f2 = layer((p + tilt * 9.0) / 34.0 + seed + 40.0, lean, 17.0);
	vec3 fire = f1.rgb + f2.rgb * (1.0 - clamp(f1.a, 0.0, 1.0)) * 0.75;
	fire *= fire;        // (deep, not pastel)
	// the band of light that rolls across a turned opal
	float roll = dot(p - card * 0.5, normalize(vec2(0.8, 0.6))) / 150.0 - tilt.x * 2.4 - tilt.y * 1.6;
	float band = 0.55 + 0.75 * exp(-pow(sin(roll * 1.6), 2.0) * 6.0);
	// pinfire: a few tiny sparks, each at its own lean
	vec2 sp = p / 5.0 + seed;
	vec2 sq = floor(sp);
	float sr = h2(sq + 3.0);
	// (a soft point in its cell: the cell itself lit was a little square)
	float dot_ = 1.0 - smoothstep(0.0, 0.22, length(fract(sp) - 0.5 - (vec2(h2(sq + 7.0), h2(sq + 8.0)) - 0.5) * 0.5));
	float spark = step(0.975, sr) * dot_ * smoothstep(0.75, 1.0, sin(dot(lean.xy, vec2(sr, h2(sq + 5.0)) - 0.5) * 60.0 + sr * 50.0) * 0.5 + 0.5);
	if (part == 1) {
		float inside = step(rim_bot, p.y) * smoothstep(0.0, 2.5, e - frame_in);
		// the body: dark blue-black, clouded; the fire in it, dimmer toward the panel's foot — the words stay easy
		vec3 body = mix(vec3(0.012, 0.02, 0.05), vec3(0.03, 0.06, 0.11), vn(p / 60.0 + seed));
		float down = clamp((p.y - rim_bot) / max(1.0, card.y - rim_bot), 0.0, 1.0);
		vec3 col = body + fire * band * (0.95 - 0.3 * down) + vec3(1.0, 0.95, 0.9) * spark * 0.8;
		float a = clamp(0.62 + dot(fire, vec3(0.4)) * band, 0.0, 0.94) * inside * k;
		COLOR = vec4(col, a);
	} else {
		// the brass: only its sheen takes the colour — along the frame and the ribbon, added
		float brass = smoothstep(1.0, 2.0, e) * smoothstep(frame_in + 0.3, frame_in - 0.9, e);
		float ribbon = (1.0 - smoothstep(0.0, (rim_bot - rim_top) * 0.5 + 1.0, abs(p.y - (rim_top + rim_bot) * 0.5)))
			* step(rim_l - 24.0, p.x) * step(p.x, rim_r + 24.0);
		float metal = max(brass, ribbon);
		vec4 fb = layer(p / 13.0 + seed + 80.0, lean, 31.0);
		vec3 fbc = fb.rgb * fb.rgb;
		// (one shader, the usual blending: the light's strength is its alpha)
		vec3 L = (fbc * band * 0.6 + vec3(1.0) * spark * 0.3) * metal * k;
		float la = clamp(max(L.r, max(L.g, L.b)), 0.0, 1.0);
		COLOR = vec4(L / max(la, 0.0001), la * 0.8);
	}
}
