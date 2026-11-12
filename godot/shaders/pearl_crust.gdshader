// A crust of pearly bubbles in one mesh (SpecForms.grapes: smithsonite). Not plastic balls: the stone is translucent,
// so a bubble is deepest face-on and lights up round its rim where light comes through; its lustre is silk, a broad
// soft sheen broken into fine fibres, not one hard dot; its colour clouds a little and sinks in the creases between
// the bubbles. COLOR: the bubble's colour, already deeper where it meets its neighbours.
shader_type spatial;
render_mode cull_back;
#include "res://shaders/opal.gdshaderinc"
#include "res://shaders/studio.gdshaderinc"

uniform float seed = 0.0;
uniform float silk = 1.0;
varying vec3 v_op;

void vertex() {
	v_op = VERTEX;
}

void fragment() {
	vec3 n = normalize(NORMAL);
	// silk: the surface is a felt of fibres too fine to see, each tipping the light a little its own way
	vec3 gq = v_op * 46.0 + seed;
	vec3 gr = vec3(vn(gq), vn(gq + 3.1), vn(gq + 5.7)) - 0.5;
	// and it is pebbled: low swellings over every bubble, none a perfect ball
	vec3 pq = v_op * 15.0 + seed;
	vec3 pb = vec3(vn(pq), vn(pq + 4.3), vn(pq + 8.9)) - 0.5;
	n = normalize(n + pb * 0.4);
	vec3 nb = normalize(n + gr * 0.22 * silk);
	float ndv = clamp(dot(n, VIEW), 0.0, 1.0);
	vec3 base = COLOR.rgb;
	// clouds in the colour, a touch of the neighbouring hues
	float cl = fbm(v_op * 5.0 + seed);
	base *= 0.55 + 0.9 * cl * cl;
	float rim = pow(1.0 - ndv, 1.7);
	vec3 tintc = base / max(0.001, max(base.r, max(base.g, base.b)));
	// the room, soft: three looks at it through the fibres
	vec3 nw = (INV_VIEW_MATRIX * vec4(nb, 0.0)).xyz;
	vec3 n2 = (INV_VIEW_MATRIX * vec4(normalize(n + gr.yzx * 0.3 * silk), 0.0)).xyz;
	vec3 n3 = (INV_VIEW_MATRIX * vec4(normalize(n - gr.zxy * 0.3 * silk), 0.0)).xyz;
	vec3 vw = (INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz;
	float lamp = (studio(reflect(-vw, nw)).r + studio(reflect(-vw, n2)).r + studio(reflect(-vw, n3)).r) / 3.0;
	lamp = clamp((lamp - 0.102) / 0.9, 0.0, 1.0);
	// pearl: the sheen takes a faint second colour that slides with the angle
	vec3 sheen = mix(vec3(1.0), 0.5 + 0.5 * cos(6.2832 * (ndv * 0.9 + cl * 0.6 + vec3(0.0, 0.33, 0.67))), 0.28);
	ALBEDO = base * 0.3;
	METALLIC = 0.0;
	ROUGHNESS = 0.42;
	SPECULAR = 0.35;
	EMISSION = base * (0.14 + 0.5 * rim) + (tintc * 0.75 + 0.25) * sheen * lamp * lamp * 0.13;
	NORMAL = nb;
}
