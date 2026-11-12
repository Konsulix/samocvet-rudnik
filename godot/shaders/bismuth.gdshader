// Bismuth's hopper crystals (SpecForms.staircase): mirror-bright metal under a skin of oxide whose thickness is its
// colour — gold, rose, violet, blue, teal, green — sliding a little as the crystal turns. What makes it metal and not
// painted blocks: the lines it grew by (square rings following the edges of a terrace, layers up a wall), some
// stretches ribbed and others smooth as a mirror, and the studio's lamps mirrored in every face that looks at one.
// CUSTOM0.xyz: the place in its own crystal (x, z -1..1 across the square, y up in half-widths);
// UV.x: film thickness in turns of the colour wheel, UV.y: shade (deep in a funnel), UV2.x: the crystal's size beside the first.
shader_type spatial;
render_mode cull_back;
#include "res://shaders/opal.gdshaderinc"
#include "res://shaders/studio.gdshaderinc"

uniform float seed = 0.0;
uniform float lines = 1.0;
varying vec3 v_lp;
varying vec3 v_fm;

void vertex() {
	v_lp = CUSTOM0.xyz;
	v_fm = vec3(UV.x, UV.y, UV2.x);
}

vec3 film(float t) {
	float x = fract(t) * 6.0;
	// (kept low: a bright pure colour comes out of the tone curve as a pastel)
	// (and pure: in linear light a tenth of the other channels is already a third of them on the screen)
	vec3 a = vec3(0.50, 0.23, 0.008), b = vec3(0.48, 0.010, 0.11), c = vec3(0.17, 0.010, 0.48);
	vec3 d = vec3(0.006, 0.055, 0.52), e = vec3(0.004, 0.26, 0.27), f = vec3(0.035, 0.30, 0.010);
	if (x < 1.0) return mix(a, b, x);
	if (x < 2.0) return mix(b, c, x - 1.0);
	if (x < 3.0) return mix(c, d, x - 2.0);
	if (x < 4.0) return mix(d, e, x - 3.0);
	if (x < 5.0) return mix(e, f, x - 4.0);
	return mix(f, a, x - 5.0);
}

void fragment() {
	vec3 n = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	if (dot(n, VIEW) < 0.0) n = -n;
	vec3 lp = v_lp;
	vec3 ln = normalize(cross(dFdx(lp), dFdy(lp)) + vec3(1e-7));
	float top = smoothstep(0.55, 0.8, abs(ln.y));
	float sz = mix(1.0, v_fm.z, 0.6);
	// growth lines: square rings following a terrace's edges; up a wall, the layers it was laid down in
	float ring = max(abs(lp.x), abs(lp.z));
	float wob = vn(lp * 3.0 + seed) * 0.6 + vn(lp * 9.0 + seed) * 0.25;
	float c = mix(lp.y * 15.0 * sz + wob * 0.45, ring * 21.0 * sz + wob * 0.6, top);
	// (too fine to draw: they fade rather than shimmer)
	float fine = 1.0 - smoothstep(0.22, 0.5, fwidth(c));
	float l1 = sin(c * 6.2832);
	float l2 = sin(c * 6.2832 * 0.27 + 1.3 + wob * 2.0);
	// some stretches ribbed, others smooth as a mirror
	float ribbed = smoothstep(0.3, 0.62, vn(lp * 2.1 + seed + 7.0));
	float h = (l1 * 0.55 * fine + l2 * 0.45) * (0.25 + 0.75 * ribbed) * lines;
	vec3 dpx = dFdx(VERTEX), dpy = dFdy(VERTEX);
	vec3 r1 = cross(dpy, n), r2 = cross(n, dpx);
	float det = dot(dpx, r1);
	vec3 rn = abs(det) * n - sign(det) * (dFdx(h) * r1 + dFdy(h) * r2) * 0.0013;
	vec3 nb = dot(rn, rn) > 1e-20 ? normalize(rn) : n;
	float ndv = clamp(dot(nb, VIEW), 0.0, 1.0);
	// the film: thicker by broad turns over a face, banded along the growth lines, shifting with the angle of view
	float t = v_fm.x + (1.0 - ndv) * 0.2 + (fbm(lp * 1.7 + seed) - 0.5) * 0.16 + l2 * 0.018 * lines + sin(c * 0.42) * 0.03;
	vec3 fc = film(t);
	// bare silver-pink metal shows through on the sharpest ribs
	vec3 mc = mix(vec3(0.34, 0.3, 0.32), fc, 1.0 - 0.16 * fine * ribbed * smoothstep(0.6, 1.0, l1) * lines);
	float shade = 0.5 + 0.5 * v_fm.y;
	// light: all softboxes at once light every face alike and it reads as painted plastic. A mirror shows one thing at
	// a time — so one key lamp (up, to the left, before it) flares in the faces whose mirror finds it, all the parallel
	// terraces of a crystal at once; the studio is only a dim fill; a face that finds neither is deep and dark
	vec3 nw = (INV_VIEW_MATRIX * vec4(nb, 0.0)).xyz;
	vec3 vw = (INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz;
	vec3 rd = reflect(-vw, nw);
	float fill = clamp((studio(rd).r - 0.102) / 0.9, 0.0, 1.0);
	float key = max(dot(rd, normalize(vec3(-0.45, 0.8, 0.4))), 0.0);
	float flare = pow(key, 5.0);
	// (a tree of it shows mostly the risers of its steps: a second, lower lamp beside the viewer finds those)
	float key2 = max(dot(rd, normalize(vec3(-0.35, 0.3, 0.9))), 0.0);
	float lit = 0.15 + 0.34 * fill + 1.2 * flare + 0.75 * pow(key2, 4.0) + pow(1.0 - ndv, 3.0) * 0.16;
	lit = min(lit, 1.12);
	// grooves between the ribs hold shadow, their crests catch light
	lit *= 1.0 + 0.3 * l1 * fine * ribbed * lines + 0.12 * l2 * lines;
	ALBEDO = mc * 0.06 * shade;
	METALLIC = 0.0;
	ROUGHNESS = 0.14 + 0.2 * ribbed * (0.5 + 0.5 * l1 * fine);
	SPECULAR = 0.45;
	// (in the heart of the flare the metal goes towards white, as polished metal does)
	EMISSION = (mc * lit + vec3(0.9, 0.86, 0.8) * pow(key, 40.0) * 0.3) * shade;
	NORMAL = nb;
}
