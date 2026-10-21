shader_type sky;
// The studio as seen by reflections (softboxes in a dark room) and as seen by the camera
// (a dark void with a faint coloured haze behind the stone).

#include "res://shaders/studio.gdshaderinc"

uniform vec3 haze = vec3(0.2, 0.27, 0.33);
uniform float haze_k = 1.0;
// a real photographed studio (Poly Haven, CC0) for richer reflections, with our softboxes on top
uniform sampler2D hdri : filter_linear, repeat_enable;
uniform float hdri_k = 0.0;

void sky() {
	if (AT_CUBEMAP_PASS) {
		vec3 d = normalize(EYEDIR);
		vec2 uv = vec2(atan(d.x, -d.z) / 6.2831853 + 0.5, acos(clamp(d.y, -1.0, 1.0)) / 3.1415927);
		COLOR = mix(studio(d), studio(d) * 0.55 + texture(hdri, uv).rgb * 0.8, hdri_k);
	} else {
		vec2 uv = SCREEN_UV;
		float r = length(uv - vec2(0.5, 0.47)) / 0.7;
		vec3 c0 = vec3(0.0130, 0.0232, 0.0296);   // #1e2a31
		vec3 c1 = vec3(0.0040, 0.0070, 0.0091);   // #0d1418
		vec3 c2 = vec3(0.0009, 0.0015, 0.0018);   // #030506
		vec3 bg = r < 0.5 ? mix(c0, c1, r / 0.5) : mix(c1, c2, clamp((r - 0.5) / 0.5, 0.0, 1.0));
		float h = length(uv - vec2(0.5, 0.5)) / 0.62;
		float g = h < 0.4 ? mix(1.0, 0.35, h / 0.4) : mix(0.35, 0.0, clamp((h - 0.4) / 0.6, 0.0, 1.0));
		COLOR = bg + haze * g * haze_k;
	}
}
