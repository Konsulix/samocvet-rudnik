// Lava from a lava stone (SpecLegend.lava) dripping onto its card (CardLava): drops swell under the stone, fall, splash
// on the brass ribbon between the stone and the info panel, spread along it, hang over its lower edge as a drip with a
// bead at its tip and cool - white-yellow, orange, red, then a dark crust whose cracks still glow - and after a while
// crumble away. One rect over the whole card; all lengths in the card's points. `glow` 1: the second pass, added
// light (the brass heating round each drop, the frame's red heat, the drops' halo); 0: the lava itself.

uniform int glow = 0;
uniform vec2 card = vec2(360.0, 640.0);
uniform float now = 0.0;
uniform float rim_top = 400.0;        // the ribbon's upper edge (the drops land on it)
uniform float rim_bot = 406.0;        // its lower edge (the drips hang off it)
uniform float rim_l = 30.0;           // its straight stretch
uniform float rim_r = 330.0;
uniform float heat = 0.3;             // the whole frame's heat (more drops, hotter)
uniform float frame_in = 9.0;         // the card's brass frame: this far in from its edge
// a drop: x, where it falls from (y), when it began, its size; and its own seed, drip length, drip offset, puddle width
uniform vec4 da[8];
uniform vec4 db[8];

const float FORM = 0.45;     // swelling under the stone
const float G = 1100.0;      // its fall, points/s²
const float COOL = 2.4;      // how fast it cools on the brass
const float KEEP = 15.0;     // the crust stays this long
const float GONE = 3.0;      // and crumbles away over this

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
	for (int k = 0; k < 3; k++) { s += a * noise(p); p = p * 2.07 + vec2(3.1, 7.7); a *= 0.5; }
	return s;
}
// the cracks of a cooling crust: the edges of cells
float cracks(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	float d1 = 8.0, d2 = 8.0;
	for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
		vec2 g = vec2(float(x), float(y));
		vec2 o = vec2(hash(i + g), hash(i + g + 17.3));
		float d = length(g + o - f);
		if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
	}
	return 1.0 - smoothstep(0.0, 0.06, d2 - d1);
}
float smin(float a, float b, float k) {
	float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
	return mix(b, a, h) - k * h * (1.0 - h);
}
// a tapered stroke from a (radius ra) to b (radius rb)
float taper(vec2 p, vec2 a, vec2 b, float ra, float rb) {
	vec2 pa = p - a, ba = b - a;
	float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-4), 0.0, 1.0);
	return length(pa - ba * h) - mix(ra, rb, h);
}
// the colour of lava by its heat (1 fresh .. 0 cold)
vec3 lava_col(float t) {
	vec3 c = mix(vec3(0.55, 0.05, 0.02), vec3(0.95, 0.22, 0.03), smoothstep(0.15, 0.45, t));
	c = mix(c, vec3(1.0, 0.58, 0.1), smoothstep(0.45, 0.72, t));
	return mix(c, vec3(1.0, 0.93, 0.62), smoothstep(0.78, 1.0, t));
}

void fragment() {
	vec2 p = UV * card;
	vec4 lava = vec4(0.0);    // the lava itself (mix)
	vec3 light = vec3(0.0);   // the light it gives (added)
	float hot_sum = 0.0;
	for (int i = 0; i < 8; i++) {
		vec4 A = da[i];
		vec4 B = db[i];
		if (A.z < -1.0) continue;
		float a = now - A.z;
		if (a < 0.0) continue;
		float sz = A.w;
		float x = A.x;
		float y0 = A.y;
		float fall = sqrt(2.0 * max(rim_top - y0 - sz, 1.0) / G);
		float land = FORM + fall;
		float d = 1e4;
		float t = 1.0;
		float fade = 1.0;
		if (a < FORM) {
			// swelling: a bead hanging under the stone, pulling longer before it lets go
			float k = smoothstep(0.0, FORM, a);
			d = taper(p, vec2(x, y0 - sz * 0.6), vec2(x, y0 + sz * (0.3 + 0.9 * k)), sz * 0.25, sz * (0.35 + 0.65 * k));
		} else if (a < land) {
			// falling: a teardrop, its tail streaming up behind it
			float u = a - FORM;
			float y = y0 + sz * 1.2 + 0.5 * G * u * u;
			float tail = min(sz * 1.5 + G * u * 0.03, sz * 6.0);
			d = taper(p, vec2(x, y), vec2(x, y - tail), sz * 0.95, sz * 0.12);
			light += vec3(1.0, 0.5, 0.1) * exp(-max(d, 0.0) / 5.0) * 0.55;
		} else {
			// on the brass: a puddle spreading along the ribbon, a drip hanging off its lower edge
			float s = a - land;
			t = exp(-s / COOL);
			fade = 1.0 - smoothstep(KEEP, KEEP + GONE, s);
			float w = B.w * (1.0 - exp(-s * 9.0)) + sz * 0.6;
			float h = sz * (0.55 + 0.6 * exp(-s * 2.5));
			float dx = (p.x - x) / w;
			// the puddle: a low dome over the ribbon's top, the lava covering the ribbon's face near its middle
			float prof = sqrt(max(0.0, 1.0 - dx * dx));
			float top_y = rim_top - h * pow(prof, 0.7) + noise(vec2(p.x * 0.4, B.x * 9.0)) * 1.2;
			float cover = rim_top + (rim_bot - rim_top) * (0.3 + 0.9 * smoothstep(1.0, 0.25, abs(dx)));
			float dp = max(max(top_y - p.y, p.y - cover), (abs(p.x - x) - w));
			// the drip: down from under the ribbon, a bead at its tip
			float L = B.y * (1.0 - exp(-max(s - 0.15, 0.0) * 1.1));
			float xd = x + B.z * w * 0.5;
			float wd = sz * 0.55;
			float dd = taper(p, vec2(xd, rim_bot - 1.0), vec2(xd, rim_bot + L), wd, wd * 0.42);
			float bead = length(p - vec2(xd, rim_bot + L + wd * 0.25)) - wd * (0.55 + 0.25 * exp(-s));
			d = smin(smin(dp, dd, 2.5), bead, 2.0);
			// it cools from its edges in, the drip's tip last (thinnest first, but the bead holds heat)
			float edge = clamp(-d / 3.0, 0.0, 1.0);
			t = clamp(t * (0.55 + 0.45 * edge) * (p.y > rim_bot ? 0.9 : 1.0), 0.0, 1.0);
			hot_sum += exp(-s / COOL);
			// the brass heating round it: along the ribbon, fading with the lava's heat
			float ribbon = 1.0 - smoothstep(0.0, (rim_bot - rim_top) * 0.9 + 2.0, abs(p.y - (rim_top + rim_bot) * 0.5));
			light += vec3(1.0, 0.3, 0.04) * ribbon * exp(-pow((p.x - x) / (w + 26.0), 2.0)) * exp(-s / (COOL * 1.6)) * 0.7 * fade;
			light += vec3(1.0, 0.42, 0.08) * exp(-max(d, 0.0) / 4.0) * exp(-s / COOL) * 0.5;
		}
		float in_l = 1.0 - smoothstep(-0.7, 0.7, d);
		if (in_l <= 0.0) continue;
		// the surface: hot lava rolls and glows; cooling, a crust forms with its cracks still lit
		float flow = fbm(p * 0.35 + vec2(B.x * 13.0, now * 0.6 * t));
		vec3 hot = lava_col(clamp(t * (0.8 + 0.4 * flow), 0.0, 1.0));
		// body: thicker is brighter, the thin edge darker and redder; a soft sheen near the top
		float thick = clamp(-d / 3.5, 0.0, 1.0);
		hot *= 0.6 + 0.5 * thick;
		hot += vec3(1.0, 0.85, 0.55) * smoothstep(0.5, 1.0, thick) * 0.25 * t;
		float crust_k = smoothstep(0.55, 0.12, t);
		float cr = cracks(p * 0.17 + B.x * 7.0);
		vec3 crust = mix(vec3(0.045, 0.035, 0.032), vec3(0.11, 0.085, 0.07), noise(p * 0.6));
		// a lit top edge on the crust (the light from the top left)
		crust += vec3(0.12, 0.1, 0.08) * smoothstep(-1.5, 0.0, d) * smoothstep(0.6, 0.0, -d);
		vec3 crack_col = lava_col(clamp(t * 2.2 + 0.1, 0.0, 0.7));
		vec3 col = mix(hot, mix(crust, crack_col, cr * smoothstep(0.02, 0.25, t)), crust_k);
		// a crust crumbles away: it breaks into bits at its edges first
		float alpha = in_l * fade;
		if (fade < 1.0) alpha *= step(1.0 - fade, noise(p * 0.7 + B.x * 3.0) * 0.8 + 0.2 + clamp(-d / 6.0, 0.0, 1.0) * 0.4);
		lava = mix(lava, vec4(col, 1.0), alpha);
		light += crack_col * cr * crust_k * smoothstep(0.02, 0.25, t) * in_l * 0.35 * fade;
	}
	if (glow == 1) {
		// the card's whole brass frame glowing red with the heat
		float e = min(min(p.x, card.x - p.x), min(p.y, card.y - p.y));
		float band = smoothstep(frame_in + 6.0, frame_in - 1.0, e) * smoothstep(-1.0, 2.0, e);
		float wav = 0.75 + 0.25 * sin(now * 1.3 + (p.x + p.y) * 0.02) + 0.15 * (noise(p * 0.05 + now * 0.3) - 0.5);
		float k = clamp(heat + hot_sum * 0.25, 0.0, 1.0);
		light += vec3(0.95, 0.16, 0.02) * band * k * wav * 0.6;
		// and the ribbon itself warming along its length
		float ribbon = 1.0 - smoothstep(0.0, (rim_bot - rim_top) + 2.0, abs(p.y - (rim_top + rim_bot) * 0.5));
		light += vec3(0.95, 0.2, 0.03) * ribbon * step(rim_l - 20.0, p.x) * step(p.x, rim_r + 20.0) * k * 0.3 * wav;
		COLOR = vec4(light, 1.0);
	} else {
		COLOR = lava;
	}
}
