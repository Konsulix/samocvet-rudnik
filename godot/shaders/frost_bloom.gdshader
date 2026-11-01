shader_type spatial;
// The legendary "frost bloom" (SpecPolar.frost): a skin laid over every crystal, on which frost grows like on a
// winter window — feathery ferns creeping up from the foot of the stone, each spreading over its own face, a fine
// rime on the faces turned up, glints of ice — then holds, thaws away in wet patches and grows again, each stone
// in its own rhythm. Drawn over the crystal's own surface (its mesh again, pushed out a hair along the normals).
render_mode blend_mix, cull_back, depth_draw_never, shadows_disabled;

uniform float k = 3.0;         // pattern scale (1 / the stone's size)
uniform float lift = 0.003;    // how far the skin stands off the crystal
uniform float y0 = 0.0;        // the stone's foot and height, for frost creeping up from below
uniform float hgt = 1.0;
uniform float phase = 0.0;
uniform float period = 16.0;
uniform mat4 to_root = mat4(1.0);   // the crystal's space -> the find's: the frost stays on the stone as it turns

varying vec3 v_p;
varying vec3 v_n;

float h3(vec3 p) { p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float vn(vec3 x) {
	vec3 i = floor(x), f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h3(i), h3(i + vec3(1, 0, 0)), f.x), mix(h3(i + vec3(0, 1, 0)), h3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(h3(i + vec3(0, 0, 1)), h3(i + vec3(1, 0, 1)), f.x), mix(h3(i + vec3(0, 1, 1)), h3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	VERTEX += NORMAL * lift;
	v_p = (to_root * vec4(VERTEX, 1.0)).xyz;
	v_n = normalize((to_root * vec4(NORMAL, 0.0)).xyz);
}

float h2(vec2 c, float o) { return fract(sin(dot(c, vec2(127.1, 311.7)) + o * 74.7) * 43758.5453); }

// one spine of a fern: a tapering line from the seed along dir, with barbs leaning out towards its tip
float spine(vec2 d, vec2 dir, float L, float aa) {
	float u = dot(d, dir);
	if (u < 0.0 || u > L) return 0.0;
	float v = abs(d.x * dir.y - d.y * dir.x);
	float taper = 1.0 - u / L;
	float wd = 0.007 + 0.013 * taper + aa;
	float line = 1.0 - smoothstep(wd * 0.35, wd, v);
	// a faint breath of frost round the spine
	line = max(line, (1.0 - smoothstep(0.0, wd * 5.0, v)) * 0.22 * taper);
	// barbs start a little way out from the seed, longest in the middle of the spine, none at its tip
	float bl = L * 0.3 * taper * smoothstep(0.05, 0.25, u / L);
	if (v < bl) {
		float w = fract((u - v * 0.577) * 11.0);
		float dw = min(w, 1.0 - w) / 11.0;
		float bw = 0.003 + 0.003 * (1.0 - v / bl) + aa * 0.6;
		line = max(line, (1.0 - smoothstep(bw * 0.4, bw, dw)) * (1.0 - v / bl) * 0.75);
	}
	return line;
}

// hexagonal ice ferns on a face's plane: in each cell (most of them) a seed, six spines out from it at 60 deg;
// grow 0..1 is how far they have reached, the seeds high up on the stone start last
float ferns(vec2 p, float grow, float up) {
	vec2 ip = floor(p);
	float best = 0.0;
	float aa = fwidth(p.x) + fwidth(p.y);
	for (int i = -1; i <= 1; i++) {
		for (int j = -1; j <= 1; j++) {
			vec2 c = ip + vec2(float(i), float(j));
			if (h2(c, 9.0) < 0.45) continue;
			vec2 s = c + vec2(h2(c, 1.0), h2(c, 2.0)) * 0.8 + 0.1;
			float g = clamp(grow * 2.0 - h2(c, 3.0) * 0.35 - up * 0.75, 0.0, 1.0);
			if (g <= 0.0) continue;
			g = 1.0 - (1.0 - g) * (1.0 - g);
			float L = (0.5 + 0.55 * h2(c, 4.0)) * g;
			vec2 d = p - s;
			if (dot(d, d) > L * L) continue;
			// only the two spines either side of this point can reach it
			float rot = h2(c, 5.0) * 6.283;
			float sec = (atan(d.y, d.x) - rot) / 1.0472;
			float a0 = rot + floor(sec) * 1.0472;
			best = max(best, spine(d, vec2(cos(a0), sin(a0)), L, aa));
			best = max(best, spine(d, vec2(cos(a0 + 1.0472), sin(a0 + 1.0472)), L, aa));
		}
	}
	return best;
}

void fragment() {
	vec3 q = v_p * k;
	// the cycle: grow, hold, thaw
	float t = fract(TIME / period + phase);
	float grow = smoothstep(0.0, 0.5, t);
	float thaw = smoothstep(0.76, 0.98, t);
	float up = clamp((v_p.y - y0) / max(hgt, 0.001), 0.0, 1.0);
	// laid on along the face's main axis, so a fern runs on over the next face turned the same way instead of
	// breaking at every edge (the faces of a small crystal are smaller than a fern)
	vec3 n = v_n;
	vec3 an = abs(n);
	vec2 p2 = an.x > an.y && an.x > an.z ? q.zy : an.y > an.z ? q.xz + 0.5 : q.xy + 0.25;
	float fern = ferns(p2, grow, up);
	// the thaw eats it in patches, the top first, the lines thinning as they go
	float melt = vn(q * 2.2) * 0.7 + (1.0 - up) * 0.3;
	float keep = 1.0 - smoothstep(melt - 0.15, melt + 0.05, thaw * 1.15);
	fern *= keep;
	// a fine rime on the faces turned up, while the frost is out
	float rime = smoothstep(0.35, 0.9, n.y) * pow(vn(q * 18.0), 3.0) * grow * keep;
	float wet = thaw * (1.0 - keep);
	// glints: single ice needles catching the light, one by one, on the ferns
	vec3 cell = floor(q * 22.0);
	float gl = step(0.88, h3(cell)) * pow(0.5 + 0.5 * sin(TIME * 2.3 + h3(cell + 3.0) * 40.0), 12.0) * fern;
	ALBEDO = mix(vec3(0.72, 0.84, 0.97), vec3(0.95, 0.98, 1.0), fern);
	ROUGHNESS = mix(0.4, 0.08, wet);
	SPECULAR = 0.7;
	EMISSION = vec3(0.45, 0.65, 0.95) * fern * 0.1 + vec3(0.9, 0.97, 1.0) * gl * 2.0;
	// the ferns stand white, the crystal shows between them; where it has thawed, a wet sheen for a moment
	ALPHA = clamp(fern * 0.78 + rime * 0.25 + wet * 0.12 + gl, 0.0, 1.0);
}
