shader_type spatial;
// The plate of matrix under a prepared trilobite (SpecTrilobite._plate): as on the Moroccan pieces, a maze of pale
// wormy ridges the air-pen left standing, darker scooped hollows between them. UV = the flat position, COLOR.r = how close under the body (a soft contact
// shadow is drawn there: the plate takes no shadow maps — on a big flat plate they broke into flickering blotches).
render_mode shadows_disabled, cull_disabled;

uniform vec3 rock_col : source_color = vec3(0.55, 0.53, 0.5);
uniform float seed = 0.0;
uniform int mode = 0;        // 0 a carved plate of matrix, 1 rippled sea sand (SpecPearl), 2 a concretion's split face (SpecTrilobite)

varying vec3 v_op;

float h3(vec3 p) { p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float vn(vec3 x) {
	vec3 i = floor(x), f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h3(i), h3(i + vec3(1, 0, 0)), f.x), mix(h3(i + vec3(0, 1, 0)), h3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(h3(i + vec3(0, 0, 1)), h3(i + vec3(1, 0, 1)), f.x), mix(h3(i + vec3(0, 1, 1)), h3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
float fbm(vec3 p) { return vn(p) * 0.5 + vn(p * 2.03) * 0.25 + vn(p * 4.01) * 0.125 + vn(p * 8.02) * 0.0625; }
vec3 vor2(vec2 q) {
	vec2 c = floor(q);
	float d1 = 9.0, d2 = 9.0, id = 0.0;
	for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
		vec2 g = c + vec2(float(x), float(y));
		vec2 pt = g + vec2(h3(vec3(g, 1.0)), h3(vec3(g, 7.0))) * 0.8 + 0.1;
		float d = distance(pt, q);
		if (d < d1) { d2 = d1; d1 = d; id = h3(vec3(g, 13.0)); } else if (d < d2) { d2 = d; }
	}
	return vec3(d1, d2 - d1, id);
}
vec3 bump(vec3 n, vec3 pos, float h, float k) {
	vec3 dpx = dFdxFine(pos), dpy = dFdyFine(pos);
	float dhx = dFdxFine(h), dhy = dFdyFine(h);
	vec3 r1 = cross(dpy, n), r2 = cross(n, dpx);
	float det = dot(dpx, r1);
	vec3 g = sign(det) * (dhx * r1 + dhy * r2);
	return normalize(abs(det) * n - g * k);
}

void vertex() {
	v_op = VERTEX;
}

void fragment() {
	vec3 n = normalize(NORMAL);
	if (!FRONT_FACING) n = -n;
	vec2 q = vec2(UV.x * 26.0, UV.y * 16.0) + (vec2(fbm(vec3(UV * 9.0, seed)), fbm(vec3(UV * 9.0, seed + 4.0))) - 0.5) * 3.2;
	vec3 cv = vor2(q);
	// ridges: the edges between scoops, broken here and there so they wander rather than close into cells
	float ridge = (1.0 - smoothstep(0.03, 0.2, cv.y)) * smoothstep(0.25, 0.5, fbm(vec3(q * 0.9, seed + 7.0)));
	float scoop = smoothstep(0.0, 0.55, cv.x);
	float h = (ridge * 0.7 - scoop * 0.4) * 0.004 + vn(v_op * 160.0) * 0.0005;
	vec3 c = rock_col * (0.55 + 0.6 * ridge + 0.1 * cv.z - 0.12 * scoop) * (0.88 + 0.2 * fbm(v_op * 8.0));
	if (mode == 1) {
		// sea sand: long soft ripples, a scatter of grains and bits of shell
		float rp = sin(UV.x * 24.0 + UV.y * 6.0 + fbm(vec3(UV * 1.5, seed)) * 4.0);
		rp = rp * 0.5 + 0.5;
		rp = rp * rp - 0.5;
		float gr = vn(v_op * 260.0);
		float shell = smoothstep(0.9, 0.95, vn(v_op * 40.0 + seed));
		h = rp * 0.0012 + gr * 0.0005;
		c = rock_col * (0.92 + 0.08 * rp + 0.14 * gr) * (0.9 + 0.18 * fbm(v_op * 5.0));
		c = mix(c, vec3(0.92, 0.88, 0.82), shell * 0.7);
	} else if (mode == 2) {
		// a concretion's split face: rings of iron-stained mud round its middle, and septarian veins of yellow calcite
		float r = length(UV * vec2(1.0, 1.35));
		float band = sin(r * 38.0 + fbm(vec3(UV * 4.0, seed)) * 4.0) * 0.5 + 0.5;
		vec3 vq = vor2(UV * 7.0 + (vec2(fbm(vec3(UV * 3.0, seed + 2.0)), fbm(vec3(UV * 3.0, seed + 5.0))) - 0.5) * 1.5);
		float vein = (1.0 - smoothstep(0.0, 0.05, vq.y)) * smoothstep(0.55, 0.15, r);
		c = rock_col * (0.55 + 0.5 * band) * (0.85 + 0.3 * fbm(v_op * 30.0));
		c = mix(c, c * vec3(0.55, 0.42, 0.32), smoothstep(0.75, 0.95, band) * 0.7);   // dark iron rings
		c = mix(c, c * vec3(1.15, 1.0, 0.85), smoothstep(0.2, 0.0, r) * 0.3);
		c = mix(c, vec3(0.86, 0.66, 0.28), vein * 0.85);
		h = band * 0.0008 + vn(v_op * 200.0) * 0.0004 - vein * 0.001;
		// the mould: where the trilobite lay (COLOR.g), the impression darker in its hollows
		c = mix(c, c * 0.42, COLOR.g);
		// the mould's rim: a fine pale line where the shell parted from the rock
		c = mix(c, vec3(0.8, 0.72, 0.6), smoothstep(0.05, 0.3, COLOR.g) * (1.0 - smoothstep(0.3, 0.6, COLOR.g)) * 0.5);
	}
	// the contact shadow under and round the body
	c *= 1.0 - 0.6 * COLOR.r;
	NORMAL = bump(n, VERTEX, h, 1.0);
	ALBEDO = c;
	ROUGHNESS = 0.93;
	SPECULAR = 0.3;
}
