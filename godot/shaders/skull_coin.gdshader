// An obol on a skull's eye (SpecSkullFx._coins): an old struck coin — a raised rim, a ring of beads, an owl in the
// middle worn nearly smooth — gold or silver, rubbed bright on the high parts, dark and green in the hollows.
// Object space: the coin's flat faces are ±Y, its radius `rad`.
shader_type spatial;
#include "res://shaders/opal.gdshaderinc"

uniform vec3 metal_col : source_color = vec3(0.95, 0.72, 0.32);
uniform float rad = 0.05;
uniform float seed = 0.0;

varying vec3 op;
varying vec3 on;

void vertex() {
	op = VERTEX;
	on = NORMAL;
}

void fragment() {
	vec2 p = op.xz / rad;
	float r = length(p);
	float a = atan(p.y, p.x);
	float face = step(0.7, abs(on.y));
	// the relief: a rim, a ring of beads, the owl (a body, two big eyes) worn by hands
	float rim = smoothstep(0.82, 0.88, r);
	float beads = (1.0 - smoothstep(0.0, 0.05, abs(r - 0.74))) * step(0.5, fract(a * 9.0 / 3.1416 + seed));
	vec2 q = p * 1.6;
	float owl = smoothstep(0.62, 0.5, length(q * vec2(1.0, 0.8) - vec2(0.0, -0.15)));
	owl = max(owl, smoothstep(0.24, 0.18, length(q - vec2(-0.2, 0.32))));
	owl = max(owl, smoothstep(0.24, 0.18, length(q - vec2(0.2, 0.32))));
	float wear = fbm(vec3(p * 3.0, seed));
	float h = (max(rim, beads * 0.8) + owl * 0.7 * (0.6 + 0.4 * wear)) * face;
	// worn bright where it stands up, dark in the hollows, a little verdigris there
	vec3 c = metal_col * mix(0.45, 1.05, h);
	c = mix(c, vec3(0.2, 0.4, 0.33), (1.0 - h) * smoothstep(0.55, 0.8, wear) * 0.5 * face);
	ALBEDO = c;
	METALLIC = 1.0;
	ROUGHNESS = mix(0.55, 0.22, h);
	vec3 dpx = dFdx(VERTEX), dpy = dFdy(VERTEX);
	vec3 r1 = cross(dpy, NORMAL), r2 = cross(NORMAL, dpx);
	float det = dot(dpx, r1);
	vec3 rn = abs(det) * NORMAL - sign(det) * (dFdx(h) * r1 + dFdy(h) * r2) * 0.004;
	NORMAL = dot(rn, rn) > 1e-20 ? normalize(rn) : NORMAL;
}
