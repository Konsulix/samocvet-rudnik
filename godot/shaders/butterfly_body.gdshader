// A butterfly's body (SpecButterfly._body_mesh, one mesh): UV.x along the part, UV.y round it (0 the back), UV2.x the
// part — 0 abdomen, 1 thorax, 2 head, 3 legs, 4 antennae and tongue, 5 eyes, 6 a feathered antenna's comb.
// Furry: the hair is a fine noise pressed into the surface and a fringe of the fur's colour where the body turns away
// (as hair does, catching the light at the edge); the abdomen in rings, the eyes glossy and dark.
shader_type spatial;
render_mode cull_disabled;
#include "res://shaders/opal.gdshaderinc"

uniform vec3 c_body : source_color = vec3(0.06, 0.05, 0.05);
uniform vec3 c_fur : source_color = vec3(0.3, 0.25, 0.2);
uniform vec3 c_band : source_color = vec3(0.0);
uniform float band_k = 0.0;
uniform int pat = 0;        // 1 white dots (monarch), 2 skull on the back + stripe down the abdomen (death's-head)
uniform float hair = 0.7;

uniform float swing = 0.0;  // the abdomen swung up (+) or down from the waist (SpecButterfly.Fly)
uniform float waist = -0.04;

varying vec3 v_p;

void vertex() {
	v_p = VERTEX;
	// (the abdomen, and its fur, bend from the waist; legs and head stay)
	float d = max(0.0, waist - VERTEX.x);
	VERTEX.y += swing * d * d * 0.6;
}

void fragment() {
	float part = floor(UV2.x + 0.5);
	float u = UV.x;
	float a = UV.y;
	// round the body: 0 on the back, 1 underneath
	float back = 1.0 - abs(a * 2.0 - 1.0);
	back = 1.0 - back;
	vec3 c = c_body;
	float fur = 0.0;
	float rough = 0.85;
	float spec = 0.2;
	if (part == 7.0) {
		// the fur shell: tufts of hair, long and combed back along the body, the gaps cut away (fixed in the body's own
		// space, so they never crawl); thinner towards the tail
		// (fine round the body, long along it: strands, not blotches)
		float tuft = vn(vec3(u * 22.0, a * 240.0, 3.1)) * 0.7 + vn(vec3(u * 60.0, a * 520.0, 7.7)) * 0.3;
		if (tuft < 0.52 + (1.0 - u) * 0.12) discard;
		float d = clamp((tuft - 0.52) * 3.0, 0.0, 1.0);
		c = mix(c_body, c_fur, 0.45 + d * 0.55);
		fur = hair;
	} else if (part == 6.0) {
		// a feathered antenna: barbs combed out from the shaft, the gaps cut away
		float barb = fract(u * 34.0);
		if (barb > 0.5 && abs(a - 0.5) > 0.06) discard;
		c = mix(c_fur, c_body, 0.35);
	} else if (part == 5.0) {
		// the eyes: dark, glossy, faintly faceted
		c = vec3(0.025, 0.022, 0.02) + c_fur * 0.05;
		rough = 0.25;
		spec = 0.6;
	} else if (part == 4.0) {
		c = c_body * 0.8 + c_fur * 0.1;
		rough = 0.6;
	} else if (part == 3.0) {
		c = c_body * 1.1 + c_fur * 0.15;
		rough = 0.6;
	} else if (part == 0.0) {
		// the abdomen: six segments, a fine groove between, the band colour on every other one
		float r6 = fract(u * 6.0);
		float groove = smoothstep(0.0, 0.14, r6) * smoothstep(1.0, 0.86, r6);
		float alt = step(0.5, fract(u * 3.0));
		c = mix(c, c_band, alt * band_k);
		if (pat == 2) {
			// the death's-head: yellow side bands, a blue-grey stripe down the back
			c = mix(c, vec3(0.22, 0.26, 0.34), smoothstep(0.85, 0.95, back) * 0.9);
		}
		if (pat == 1) {
			// the monarch: a row of white dots down each side of the abdomen
			float d = length(vec2((fract(u * 6.0) - 0.5) * 3.2, (abs(a - 0.5) - 0.3) * 14.0));
			c = mix(c, vec3(0.85, 0.83, 0.78), smoothstep(0.5, 0.3, d) * step(0.15, u) * 0.85);
		}
		c *= 0.78 + 0.22 * groove;
		fur = hair * 0.55;
	} else {
		// the thorax and the head: densest fur
		fur = hair;
		if (pat == 1) {
			// white dots on the head and the thorax's sides
			float d = vn(vec3(u * 9.0, a * 14.0, part * 7.0));
			c = mix(c, vec3(0.88, 0.86, 0.8), smoothstep(0.78, 0.86, d) * (part == 2.0 ? 1.0 : smoothstep(0.55, 0.75, 1.0 - back)));
		}
		if (pat == 2 && part == 1.0) {
			// the skull: a pale mark on the back of the thorax — two dark eye holes in it
			vec2 q = vec2((u - 0.55) * 2.0, (a < 0.5 ? a : a - 1.0) * 6.0);
			float skull = smoothstep(0.75, 0.55, length(q * vec2(1.0, 0.9)));
			float eyes = smoothstep(0.2, 0.12, length(vec2(q.x - 0.05, abs(q.y) - 0.28)));
			c = mix(c, vec3(0.78, 0.66, 0.38), skull);
			c = mix(c, c_body * 0.6, eyes * skull);
		}
	}
	// the hair: fine strands pressed into the surface, colour varying strand to strand
	float strands = vn(v_p * 900.0) * 0.6 + vn(v_p * 2200.0) * 0.4;
	vec3 n = bump(NORMAL, VERTEX, strands * 0.0006 * fur, 1.0);
	c *= 1.0 - fur * 0.35 + strands * fur * 0.55;
	// the fringe of fur at the silhouette, catching the light
	float rim = pow(1.0 - clamp(abs(dot(n, VIEW)), 0.0, 1.0), 2.0);
	c = mix(c, c_fur, rim * fur * 0.85);
	ALBEDO = c * 0.85;
	NORMAL = n;
	ROUGHNESS = mix(rough, 1.0, fur);
	SPECULAR = spec * (1.0 - fur * 0.8);
	BACKLIGHT = c_fur * 0.25 * fur;
}
