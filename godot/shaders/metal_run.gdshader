// Molten metal run down a skull and set (SpecSkull._drips): a broad tongue lying on the bone, thick and domed, swelling
// to a heavy lobe at its foot. UV.x across (0..1), UV.y along (skull units); COLOR.r: 0 at its head .. 1 at its foot.
// It must read against the skull cast in the same metal: polished where the skull is satin, a touch brighter and
// warmer, the frozen ripples of its flow across it, a dark crease where it meets the bone; `hot` (a rare one): not yet
// cold — its foot glows from inside and the glow breathes. The beads at the runs' ends use it too (no UV: COLOR.r 1).
shader_type spatial;
render_mode cull_back;
#include "res://shaders/opal.gdshaderinc"

uniform vec3 col = vec3(0.95, 0.68, 0.28);   // (raw, as the skull's own metal_col in bone.gdshader)
uniform float rough = 0.14;   // (polished all over it mirrored the dark studio and went black: a sheen, a little smoother than the skull)
uniform float phase = 0.0;
uniform float hot = 0.0;

void fragment() {
	float x = UV.x;
	float y = UV.y;
	float f = COLOR.r;
	// the frozen ripples of its flow: low ridges across the run, closer together where it slowed toward its foot
	float rip = sin(y * (45.0 + f * 30.0) + vn(vec3(x * 3.0, y * 10.0, phase)) * 3.0) * 0.5 + 0.5;
	float grain = fbm(vec3(x * 6.0, y * 30.0, phase));
	// a darker crease where it meets the bone (its silhouette, its edges)
	float rim = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.0);
	// fresh and bright down its middle, a dark crease all along where it meets the bone: that line is what makes a run
	// of gold read on a gold skull
	float edge = min(x, 1.0 - x) * 2.0;
	vec3 c = col * 1.25 * (0.92 + 0.08 * grain) * (1.0 - rim * 0.25);
	c *= mix(0.3, 1.0, smoothstep(0.0, 0.35, edge));
	ALBEDO = c;
	METALLIC = 1.0;
	ROUGHNESS = rough + rip * 0.03 + (1.0 - grain) * 0.03;
	vec3 dpx = dFdx(VERTEX), dpy = dFdy(VERTEX);
	float h = rip * 0.6 + grain * 0.4;
	vec3 r1 = cross(dpy, NORMAL), r2 = cross(NORMAL, dpx);
	float det = dot(dpx, r1);
	vec3 rn = abs(det) * NORMAL - sign(det) * (dFdx(h) * r1 + dFdy(h) * r2) * 0.0005;
	NORMAL = dot(rn, rn) > 1e-20 ? normalize(rn) : NORMAL;
	// still hot: the foot glows orange through the metal, breathing; the head already cold
	float glow = hot * smoothstep(0.45, 1.0, f) * (0.7 + 0.3 * sin(TIME * 1.3 + phase * 7.0 + y * 8.0));
	EMISSION = vec3(1.0, 0.36, 0.08) * glow * 1.6;
}
