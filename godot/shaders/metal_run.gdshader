// A run of molten metal on a skull (SpecSkull._drips): the same domed sheet as the water (UV.x across, UV.y along),
// but opaque polished metal, swelling toward its lower end; a slow glint creeps down it as if it still flowed.
shader_type spatial;
render_mode cull_back;
#include "res://shaders/opal.gdshaderinc"

uniform vec3 col = vec3(0.95, 0.68, 0.28);   // (raw, as the skull's own metal_col in bone.gdshader: the same gold)
uniform float rough = 0.16;
uniform float phase = 0.0;

void fragment() {
	// (on a tube: no UV — the glint runs by height, in the skull's space)
	float y = -VERTEX.y;
	float glint = smoothstep(0.88, 1.0, sin(y * 60.0 - TIME * 1.4 + phase) * 0.5 + 0.5);
	float x = 0.5;
	// a darker crease where the run meets the skull (its silhouette edge), so it reads on the same metal
	float rim = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.0);
	ALBEDO = col * (0.85 + 0.15 * fbm(vec3(x * 4.0, y * 20.0, phase))) * (1.0 - rim * 0.55);
	METALLIC = 1.0;
	ROUGHNESS = rough * (1.0 - glint * 0.6);
	EMISSION = col * glint * 0.25;
}
