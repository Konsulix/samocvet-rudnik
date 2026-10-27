shader_type spatial;
render_mode cull_disabled;
// An insect's wing (SpecFlower insects), drawn opaque so the stone round it can see it: the membrane is mostly
// left out pixel by pixel (dithered), so it reads as see-through; its veins stay, dark; where the membrane is drawn
// it has the thin-film sheen of a real wing. UV.x = 0 at the root .. 1 at the tip, UV.y = -1 .. 1 across.

#include "res://shaders/opal.gdshaderinc"

uniform vec3 c_vein : source_color = vec3(0.12, 0.09, 0.06);
uniform float membrane = 0.35;    // how much of the membrane is drawn
uniform float seed = 0.0;

void fragment() {
	float t = UV.x;
	float s = UV.y;
	// veins: a few running out from the root, branching, and cross-veins between them
	float lv = abs(fract(s * 2.6 + t * 0.6 + vn(vec3(t * 3.0, s * 2.0, seed)) * 0.5) - 0.5);
	float vein = 1.0 - smoothstep(0.02, 0.05, lv);
	float cross_ = 1.0 - smoothstep(0.015, 0.04, abs(fract(t * 6.0 + s * 0.8) - 0.5));
	cross_ *= step(0.55, vn(vec3(t * 12.0, s * 6.0, seed + 3.0)));
	float edge = smoothstep(0.85, 0.97, abs(s)) + smoothstep(0.9, 1.0, t);
	vein = clamp(max(max(vein * (1.0 - t * 0.4), cross_ * 0.8), edge), 0.0, 1.0);
	float keep = vein > 0.4 ? 1.0 : membrane;
	if (h3(vec3(FRAGCOORD.xy, seed)) > keep) discard;
	float fr = 1.0 - abs(dot(NORMAL, VIEW));
	vec3 film = hue(fract(t * 0.6 + s * 0.3 + fr * 0.9 + seed * 0.1)) * 0.5 + 0.35;
	ALBEDO = mix(film * 0.55, lin(c_vein), smoothstep(0.3, 0.6, vein));
	ROUGHNESS = 0.2;
	SPECULAR = 0.6;
}
