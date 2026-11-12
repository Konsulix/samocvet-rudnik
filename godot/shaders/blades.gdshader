// Balls and fans of thin bladed crystals in one mesh (SpecForms.balls / fans: cavansite, erythrite). What keeps them
// from reading as cut paper: each blade is glass of its colour — deep where it is thick and seen face-on, light
// gathering in its thin tip and edges; every flat face a facet that flashes when it finds a studio lamp; fine lines
// along its length. COLOR: the blade's own colour, root to tip (already varied blade to blade);
// UV: across the blade (-1..1) and along it (0 root .. 1 tip), UV2.x: through its thickness.
shader_type spatial;
render_mode cull_back;
#include "res://shaders/opal.gdshaderinc"
#include "res://shaders/studio.gdshaderinc"

uniform vec3 thin_col = vec3(0.02, 0.2, 0.8);   // what the colour turns to where light comes through a thin edge
uniform float glow = 1.0;
uniform float gloss = 1.0;
uniform float pearl = 0.0;                      // a soft pale sheen over the faces (erythrite's pearly lustre)
varying vec3 v_t;

void vertex() {
	v_t = vec3(UV.x, UV.y, UV2.x);
}

void fragment() {
	vec3 n = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	if (dot(n, VIEW) < 0.0) n = -n;
	float along = clamp(v_t.y, 0.0, 1.0);
	// lines along the blade: low ribs across its width
	float c = v_t.x * 5.0 + sin(along * 7.0 + v_t.x * 3.0) * 0.15;
	float fine = 1.0 - smoothstep(0.2, 0.5, fwidth(c));
	float h = sin(c * 6.2832) * fine;
	vec3 dpx = dFdx(VERTEX), dpy = dFdy(VERTEX);
	vec3 r1 = cross(dpy, n), r2 = cross(n, dpx);
	float det = dot(dpx, r1);
	vec3 rn = abs(det) * n - sign(det) * (dFdx(h) * r1 + dFdy(h) * r2) * 0.0009;
	vec3 nb = dot(rn, rn) > 1e-20 ? normalize(rn) : n;
	float ndv = clamp(dot(nb, VIEW), 0.0, 1.0);
	vec3 base = COLOR.rgb;
	// thin places let light through: the tip, the two edges, any face seen at a glance
	float thin = clamp(smoothstep(0.5, 1.0, along) * 0.55 + smoothstep(0.55, 1.0, abs(v_t.x)) * 0.35 + pow(1.0 - ndv, 2.0) * 0.55, 0.0, 1.0);
	vec3 body = mix(base, thin_col * (0.5 + 0.5 * along), thin * 0.55 * glow);
	// the room in each facet
	vec3 nw = (INV_VIEW_MATRIX * vec4(nb, 0.0)).xyz;
	vec3 vw = (INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz;
	float lamp = clamp((studio(reflect(-vw, nw)).r - 0.102) / 0.9, 0.0, 1.0);
	float l3 = lamp * lamp * lamp;
	vec3 tintc = base / max(0.001, max(base.r, max(base.g, base.b)));
	ALBEDO = body * 0.22;
	METALLIC = 0.0;
	ROUGHNESS = mix(0.12, 0.3, pearl);
	SPECULAR = mix(0.6, 0.25, pearl);
	// (all of it kept low and pure: a bright colour, or one with a tenth of white in it, is a pastel on the screen)
	EMISSION = body * (0.2 + 0.55 * thin * glow) + tintc * (0.2 * l3 + 0.5 * l3 * l3 * l3) * gloss * (0.3 + 0.7 * along)
		+ vec3(1.0) * pow(lamp, 12.0) * 0.12 * gloss * along + thin_col * pow(1.0 - ndv, 1.5) * pearl * 0.12 * along;
	NORMAL = nb;
}
