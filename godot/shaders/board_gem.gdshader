shader_type spatial;
render_mode cull_back;
// Stones on the board: the generator's glass without its expensive screen reads. The studio's softboxes
// are seen bent through each facet (fake refraction, split into colours), every facet catches a slightly
// different depth of colour, a holographic sheen drifts in patches and a slow glint sweeps the tray.

#include "res://shaders/studio.gdshaderinc"

uniform vec3 col_c = vec3(0.8, 0.1, 0.2);   // body
uniform vec3 col_d = vec3(0.3, 0.02, 0.06); // depth
uniform vec3 col_l = vec3(1.0, 0.7, 0.75);  // light through thin parts
uniform float milky = 0.0;                   // moonstone: a soft blue glow floating under the surface
uniform float holo = 0.35;
uniform float glint = 1.0;

varying vec3 v_op;
varying vec3 v_wp;

float h1(vec3 p) { return fract(sin(dot(p, vec3(12.9898, 78.233, 45.164))) * 43758.5453); }

void vertex() {
	v_op = VERTEX;
	v_wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 nw = (INV_VIEW_MATRIX * vec4(n, 0.0)).xyz;
	vec3 iw = (INV_VIEW_MATRIX * vec4(-VIEW, 0.0)).xyz;
	// each facet gets its own depth of colour, so the cut reads even in flat light
	float facet = h1(floor(nw * 7.0));
	// the studio seen through the stone, a little dispersion at the edges
	vec3 r0 = refract(iw, nw, 0.62);
	vec3 thru = vec3(studio(refract(iw, nw, 0.64)).r, studio(r0).g, studio(refract(iw, nw, 0.6)).b);
	float lum = dot(thru, vec3(0.33));
	// deep colour in most facets; the light coming through only lifts it, tinted by the stone
	vec3 body = mix(col_d * 0.6, col_c, pow(facet, 1.3) * 0.85);
	body += col_c * smoothstep(0.3, 1.0, lum) * 0.55;
	body = mix(body, col_l, smoothstep(0.85, 1.0, lum) * 0.35);
	// fire: pure spectral sparks in a few facets
	float fire = smoothstep(0.82, 0.97, facet) * smoothstep(0.4, 0.9, lum);
	vec3 spec = 0.5 + 0.5 * cos(6.2832 * (facet * 3.0 + TIME * 0.15 + vec3(0.0, 0.33, 0.67)));
	body += spec * fire * 0.9;
	// holographic sheen in soft patches, as on the specimens
	float fr = 1.0 - abs(dot(n, VIEW));
	float hp = smoothstep(0.45, 0.75, fract(sin(dot(floor(v_op * 6.0), vec3(3.1, 7.7, 1.3))) * 91.7) * 0.4 + 0.5 * (0.5 + 0.5 * sin(v_op.x * 9.0 + v_op.z * 7.0)));
	vec3 hc = 0.5 + 0.5 * cos(6.2832 * (fr * 1.4 + v_op.x * 2.0 + vec3(0.0, 0.33, 0.67)));
	body += hc * hp * holo * (0.12 + 0.5 * fr);
	// moonstone: milky body with a blue light drifting inside
	if (milky > 0.0) {
		float glow = pow(clamp(dot(nw, normalize(vec3(sin(TIME * 0.4), 1.2, cos(TIME * 0.4)))), 0.0, 1.0), 6.0);
		body = mix(body, vec3(0.75, 0.8, 0.88), milky * 0.6) + vec3(0.25, 0.45, 1.0) * glow * milky * 0.9;
	}
	// a slow diagonal glint sweeping the whole tray
	float sweep = fract((v_wp.x * 0.6 + v_wp.z) / 14.0 - TIME * 0.12);
	float band = 1.0 - smoothstep(0.0, 0.02, abs(sweep - 0.5));
	body += vec3(0.9) * band * glint * (0.3 + 0.7 * facet);
	ALBEDO = col_d * 0.15;
	ROUGHNESS = 0.05;
	SPECULAR = 0.5;
	METALLIC = 0.0;
	EMISSION = body * 0.75;
}
