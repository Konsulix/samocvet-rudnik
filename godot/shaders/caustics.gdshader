shader_type spatial;
// Sunlight through moving water, laid over a sea find (SpecSea.caustics): a copy of a mesh pushed a hair out along its
// normals, drawn additively — a bright wandering net of light on what faces up, gone on what faces down.
render_mode unshaded, blend_add, cull_back, depth_draw_never, shadows_disabled;

uniform vec3 tint : source_color = vec3(0.75, 0.92, 1.0);
uniform float strength = 0.35;
uniform float scale = 3.0;      // nets per unit (world)
uniform float push = 0.002;     // how far out along the normal (model units)
uniform vec3 sun = vec3(0.15, 1.0, 0.1);   // where the light comes down from (floor space)
uniform mat4 to_floor;          // this mesh's space -> the sea floor's (y up from the floor)

varying vec3 v_w;
varying vec3 v_n;

float h2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

// a net of light: cells whose points drift, bright along the edges between them
float net(vec2 q, float t) {
	vec2 c = floor(q);
	float d1 = 9.0, d2 = 9.0;
	for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
		vec2 g = c + vec2(float(x), float(y));
		float r = h2(g);
		vec2 pt = g + 0.5 + 0.38 * vec2(sin(t * (0.6 + r) + r * 6.28), cos(t * (0.5 + h2(g + 3.1)) + r * 4.0));
		float d = distance(pt, q);
		if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
	}
	return 1.0 - smoothstep(0.0, 0.09, d2 - d1);
}

void vertex() {
	VERTEX += NORMAL * push;
	v_w = (to_floor * vec4(VERTEX, 1.0)).xyz;
	v_n = normalize((to_floor * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 s = normalize(sun);
	// projected along the light: the net falls the same on a slope and a flat
	vec3 a = normalize(cross(s, vec3(0.0, 0.0, 1.0)) + vec3(0.0, 0.0, 0.001));
	vec3 b = cross(s, a);
	vec2 q = vec2(dot(v_w, a), dot(v_w, b)) * scale;
	float t = TIME;
	// two nets drifting apart: where they cross, the light pools brighter
	float c = net(q, t) * 0.55 + net(q * 1.37 + 5.0, t * 1.3) * 0.55;
	// patches of the surface are calmer: the net comes and goes across the find
	c *= 0.45 + 0.55 * smoothstep(0.2, 0.8, net(q * 0.21 + 11.0, t * 0.4));
	c = c * c * 1.5;
	float face = smoothstep(-0.1, 0.6, dot(v_n, s));
	ALBEDO = tint * c * strength * face;
}
