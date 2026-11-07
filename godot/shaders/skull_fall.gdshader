// A little waterfall out of a skull's eye (SpecSkull._stream): a broad sheet of water racing down over the bone and
// the rock, and dropping straight down off their edges (SpecSkull._curtain). UV.x across (0..1), UV.y along it (skull units, downward); COLOR.a fades its
// end where it falls clear of everything. What makes it read as falling water, at a phone's size: long light streaks
// racing down (two layers at two speeds), white water where it breaks over the lip, the sides torn and fraying as it
// falls, the sheet wavering a little.
shader_type spatial;
render_mode cull_disabled, blend_mix, depth_draw_opaque;
#include "res://shaders/opal.gdshaderinc"

uniform float speed = 1.5;     // skull units a second
uniform float waver = 1.0;     // how much the sheet wavers (low where it lies on the bone: it would sink into it)
uniform vec3 deep : source_color = vec3(0.10, 0.24, 0.32);   // (clear and cool: milky white read as mucus)
uniform vec3 white : source_color = vec3(0.88, 0.95, 1.0);
uniform float body_a = 0.2;  // how much of the sheet is there between its streaks (wine is thick: you hardly see through it)
uniform float glow = 1.0;     // how much the streaks light up (wine: dark and glossy, not neon)
uniform bool tube = false;    // a round falling stream (SpecSkull._curtain): UV.x goes round it, its edges are where it turns away
uniform float spec = 0.5;     // its mirror (wine: less of the white studio on it, or it reads pink)

varying float fade;

void vertex() {
	fade = COLOR.a;
	// a waver across the sheet, growing as it falls
	float s = sin(UV.y * 18.0 - TIME * 7.0) * 0.5 + sin(UV.y * 31.0 - TIME * 11.0) * 0.3;
	VERTEX += NORMAL * s * 0.004 * waver * smoothstep(0.0, 0.15, UV.y);
}

void fragment() {
	float x = UV.x;
	float y = UV.y;
	float edge = min(x, 1.0 - x) * 2.0;
	if (tube) {
		// round the tube: the streaks mirrored about its middle (no seam at the back), its edges where it turns from view
		x = abs(x * 2.0 - 1.0);
		edge = clamp(abs(dot(NORMAL, VIEW)) * 1.6, 0.0, 1.0);
	}
	float t = TIME;
	// long streaks racing down, two layers at two speeds
	float s1 = vn(vec3(x * 9.0, (y - t * speed) * 1.6, 1.0));
	float s2 = vn(vec3(x * 17.0, (y - t * speed * 1.35) * 2.6, 5.0));
	float str = smoothstep(0.42, 0.85, s1 * 0.6 + s2 * 0.4);
	// the sides torn, more as it falls: the sheet breaking into strands
	float rag = vn(vec3(x * 5.0, (y - t * speed) * 6.0, 9.0));
	float body = smoothstep(0.0, 0.25 + rag * (0.25 + smoothstep(0.0, 0.4, y) * 0.35), edge);
	// white water breaking over the lip
	float lip = 1.0 - smoothstep(0.0, 0.06, y);
	float fres = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.0);
	vec3 c = mix(deep, white, clamp(str * 0.8 + lip * 0.3 + fres * 0.25, 0.0, 1.0));
	ALBEDO = c;
	ROUGHNESS = 0.08;
	SPECULAR = spec;
	EMISSION = white * (str * 0.4 + lip * 0.1) * glow;
	ALPHA = clamp(body_a + str * 0.6 + lip * 0.15 + fres * 0.25, 0.0, 0.92) * body * fade;
}
