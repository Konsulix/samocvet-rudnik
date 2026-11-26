shader_type canvas_item;
// The jellyfish legend's info panel under water (CardJelly): over the panel's slate, under its words — the slate sunk in
// deep water: a blue-green dusk, the sun's caustics running over it (brighter up near the surface), rings spreading where
// it is touched, and the light of a jellyfish swimming over it pooling on it. Points: the panel's.

uniform vec2 rsize = vec2(360.0, 240.0);
uniform vec4 rip[4];          // ripples: x, y, age (s), on (0/1)
uniform vec4 jl[2];           // jellyfish over it: x, y, reach, strength
uniform vec3 jc0 : source_color = vec3(0.4, 0.9, 1.0);
uniform vec3 jc1 : source_color = vec3(1.0, 0.5, 0.9);
uniform float k = 1.0;        // how much (it comes in, fading)

float caustic(vec2 q, float t) {
	// (the classic interference of a few warped waves: thin bright lines meeting in a net; made for large
	// coordinates — on small ones every term blew up and the panel went one flat glare)
	vec2 p = mod(q, 6.28318) - 250.0;
	vec2 i = p;
	float c = 1.0;
	float inten = 0.005;
	for (int n = 0; n < 4; n++) {
		float tt = t * (1.0 - (3.5 / float(n + 1)));
		i = p + vec2(cos(tt - i.x) + sin(tt + i.y), sin(tt - i.y) + cos(tt + i.x));
		c += 1.0 / length(vec2(p.x / (sin(i.x + tt) / inten), p.y / (cos(i.y + tt) / inten)));
	}
	c /= 4.0;
	c = 1.17 - pow(c, 1.4);
	return clamp(pow(abs(c), 8.0), 0.0, 1.0);
}

void fragment() {
	vec2 p = UV * rsize;
	// the rings: each bends the water it runs through, and catches the light on its crest
	vec2 bend = vec2(0.0);
	float crest = 0.0;
	for (int n = 0; n < 4; n++) {
		if (rip[n].w < 0.5) continue;
		vec2 d = p - rip[n].xy;
		float dl = length(d);
		float r = rip[n].z * 140.0;
		float fade = exp(-rip[n].z * 1.6) * smoothstep(0.0, 0.08, rip[n].z);
		float w = sin((dl - r) / 3.5) * exp(-pow((dl - r) / 16.0, 2.0)) * fade;
		bend += normalize(d + vec2(0.001)) * w * 4.0;
		crest += max(w, 0.0);
	}
	vec2 q = (p + bend) / 40.0;
	float t = TIME * 0.32;
	float c = caustic(q, t) * 0.8 + caustic(q * 0.7 + 3.0, t * 0.8 + 1.0) * 0.5;
	// near the surface (the panel's top) the light is strong; deeper it dims
	float depth = 1.0 - smoothstep(0.0, rsize.y * 1.1, p.y);
	float light = c * (0.3 + 0.7 * depth) + crest * 1.4;
	// a jellyfish's glow pooling on the slate under it
	vec3 jlight = vec3(0.0);
	for (int n = 0; n < 2; n++) {
		if (jl[n].w <= 0.0) continue;
		float dd = length(p - jl[n].xy) / max(jl[n].z, 1.0);
		jlight += (n == 0 ? jc0 : jc1) * exp(-dd * dd * 2.2) * jl[n].w * (0.8 + 0.4 * c);
	}
	vec3 deep = vec3(0.005, 0.05, 0.075);
	vec3 shine = vec3(0.55, 0.92, 1.0);
	vec3 col = deep + shine * light * 0.9 + jlight * 0.55;
	float a = (0.46 + light * 0.3 + length(jlight) * 0.25) * k;
	COLOR = vec4(col, clamp(a, 0.0, 0.9));
}
