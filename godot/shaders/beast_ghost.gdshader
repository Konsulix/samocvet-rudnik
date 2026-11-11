// The beast's ghost (SpecBeastFx): the living head over the skull, made of cold light — a low-poly shell, each facet
// lit by how it turns from the eye (bright at the rim, faint face-on), a band of light sweeping it. It comes and goes:
// `show` (0..1) dissolves it in from the neck to the nose, a burning edge where it forms, and away again; at the neck
// it always thins out to nothing. UV.x: 0 at the neck .. 1 at the nose.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;
#include "res://shaders/opal.gdshaderinc"

uniform vec3 col : source_color = vec3(0.45, 0.9, 1.0);
uniform float show = 1.0;
uniform float seed = 0.0;

varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	// flat facets: each its own normal
	vec3 n = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	float fres = 1.0 - abs(dot(n, normalize(VIEW)));
	float u = UV.x;
	// dissolving in and out: noise over the shell, the threshold running from the neck to the nose
	float nz = fbm(lp * 6.0 + seed);
	float th = show * 1.35 - 0.2;
	float d = th - (u * 0.75 + nz * 0.5);
	float on = smoothstep(0.0, 0.06, d);
	float edge = smoothstep(0.0, 0.05, d) * (1.0 - smoothstep(0.05, 0.16, d));
	float sweep = pow(0.5 + 0.5 * sin(lp.y * 18.0 - TIME * 2.5 + seed), 12.0);
	float shimmer = 0.75 + 0.25 * sin(TIME * 3.0 + h3(floor(lp * 20.0)) * 20.0);
	vec3 c = col * (pow(fres, 2.2) * 1.4 + 0.05 + sweep * 0.25) * shimmer;
	c = c * on + mix(col, vec3(1.0), 0.6) * edge * 2.2;
	c *= smoothstep(0.0, 0.3, u);
	ALBEDO = c;
}
