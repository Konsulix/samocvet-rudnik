// Petals and leaves built by SpecBloom (bouquets, little flowers, tree crowns). UV.x across the blade (-1..1), UV.y
// from its base (0) to its tip (1); COLOR = the instance's colour times the vertex shading.
// mode 0 petal: deeper at the base, paler to the tip, fine veins fanning out, a velvet sheen at grazing angles, lit
//   through faintly; mode 1 leaf: a midrib and side veins, glossy darker top, paler matte underside, a dry spot now
//   and then; mode 2 metal (gold petals): polished, the veins pressed in.
shader_type spatial;
render_mode cull_disabled;

uniform int mode = 0;
uniform vec3 metal_col : source_color = vec3(1.0, 0.74, 0.3);

float h1(float n) { return fract(sin(n * 127.1) * 43758.5453); }
float vn2(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = h1(i.x + i.y * 57.0), b = h1(i.x + 1.0 + i.y * 57.0), c = h1(i.x + (i.y + 1.0) * 57.0), d = h1(i.x + 1.0 + (i.y + 1.0) * 57.0);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

varying float iid;
void vertex() { iid = float(INSTANCE_ID); }

void fragment() {
	float x = UV.x, y = UV.y;
	float seed = h1(iid * 1.37) * 97.0;
	vec3 c = COLOR.rgb;
	float face = abs(dot(NORMAL, VIEW));
	float h = 0.0;
	if (mode == 1) {
		// leaf: a toothed edge, a midrib, side veins at an angle toward the tip and fine net veins between
		if (abs(x) > 0.9 + 0.1 * abs(sin(y * 46.0 + seed))) discard;
		float mid = 1.0 - smoothstep(0.0, 0.07, abs(x));
		float side = 1.0 - smoothstep(0.0, 0.08, abs(fract(y * 7.0 - abs(x) * 1.8 + 0.5) - 0.5));
		side *= smoothstep(0.05, 0.12, abs(x)) * (1.0 - smoothstep(0.8, 0.95, abs(x)));
		float net = 1.0 - smoothstep(0.0, 0.18, abs(vn2(UV * vec2(18.0, 30.0) + seed) - 0.5));
		float vein = max(mid, max(side * 0.8, net * 0.25));
		// each leaf its own shade; darker along the edge; a sheen band on the top
		vec3 top = c * (0.7 + 0.45 * h1(seed)) * (0.85 + 0.25 * vn2(UV * 9.0 + seed));
		top *= 1.0 - smoothstep(0.7, 0.9, abs(x)) * 0.3;
		top = mix(top, top * vec3(1.15, 1.2, 0.8), smoothstep(0.4, 1.0, y) * 0.4);
		top = mix(top, mix(top, vec3(0.45, 0.32, 0.12), 0.7), smoothstep(0.78, 0.85, vn2(UV * 3.0 + seed * 3.0)) * 0.6);
		vec3 under = top * 1.25 + vec3(0.03);
		c = FRONT_FACING ? top : under;
		c = mix(c, c * 1.5 + vec3(0.03, 0.035, 0.0), vein * 0.7);
		h = -vein * 1.2 + vn2(UV * 30.0) * 0.15 + (1.0 - abs(x)) * 0.4;
		ROUGHNESS = FRONT_FACING ? 0.5 : 0.85;
		SPECULAR = FRONT_FACING ? 0.2 : 0.05;
		BACKLIGHT = c * 0.12;
	} else {
		// petal: veins fanning from the base, deeper colour at the base, the tip paler, a darker thin rim
		float a = x / max(0.15, y + 0.15);
		float vein = 1.0 - smoothstep(0.0, 0.25, abs(fract(a * 7.0 + vn2(vec2(a * 3.0, y * 4.0 + seed)) * 0.6) - 0.5) * 2.0);
		vein *= smoothstep(0.05, 0.3, y);
		c *= mix(0.55, 1.12, smoothstep(0.0, 0.75, y));
		c *= 1.0 - vein * 0.18;
		c *= 1.0 - smoothstep(0.82, 1.0, abs(x)) * 0.25;
		c *= 0.9 + 0.2 * vn2(UV * vec2(4.0, 12.0) + seed);
		// velvet: a soft brightening toward the edges of the view
		c += c * pow(1.0 - face, 3.0) * 0.6;
		if (!FRONT_FACING) c *= 0.75;
		h = -vein * 0.5 + vn2(UV * vec2(40.0, 80.0)) * 0.15;
		if (mode == 2) {
			METALLIC = 1.0;
			c = metal_col * mix(0.6, 1.1, smoothstep(0.0, 0.7, y)) * (1.0 - vein * 0.25);
			ROUGHNESS = 0.22 + vn2(UV * 20.0) * 0.1;
			SPECULAR = 0.6;
		} else {
			ROUGHNESS = 0.82;
			SPECULAR = 0.12;
			BACKLIGHT = c * 0.15;
		}
	}
	ALBEDO = c;
	vec3 dpx = dFdx(VERTEX), dpy = dFdy(VERTEX);
	vec3 r1 = cross(dpy, NORMAL), r2 = cross(NORMAL, dpx);
	float det = dot(dpx, r1);
	vec3 rn = abs(det) * NORMAL - sign(det) * (dFdx(h) * r1 + dFdy(h) * r2) * 0.003;
	NORMAL = dot(rn, rn) > 1e-20 ? normalize(rn) : NORMAL;
}
