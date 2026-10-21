// The photo studio the specimens sit in: a dark room lit by five big white softboxes.
// Used by the sky (for reflections and ambient light) and by clear crystals (for refraction),
// so both see exactly the same lamps. Same panels as the prototype's PMREM studio.

float sb_panel(vec3 d, vec3 c, vec2 sz) {
	vec3 ch = normalize(c);
	float dn = dot(d, ch);
	if (dn <= 0.0) return 0.0;
	vec3 p = d * (length(c) / dn) - c;
	vec3 z = -ch;
	vec3 up = abs(z.y) > 0.99 ? vec3(0.0, 0.0, 1.0) : vec3(0.0, 1.0, 0.0);
	vec3 x = normalize(cross(up, z));
	vec3 y = cross(z, x);
	vec2 q = abs(vec2(dot(p, x), dot(p, y))) - sz * 0.5;
	return 1.0 - smoothstep(-0.18, 0.18, max(q.x, q.y));
}

vec3 studio(vec3 d) {
	float k = sb_panel(d, vec3(0.0, 4.9, 0.0), vec2(6.0, 6.0))
		+ sb_panel(d, vec3(-4.9, 1.2, 1.0), vec2(4.0, 3.0))
		+ sb_panel(d, vec3(4.9, 2.0, -1.0), vec2(3.0, 4.0))
		+ sb_panel(d, vec3(0.0, 1.0, 4.9), vec2(6.0, 2.5))
		+ sb_panel(d, vec3(1.0, -1.0, -4.9), vec2(4.0, 2.0));
	return mix(vec3(0.102, 0.110, 0.118), vec3(1.0), clamp(k, 0.0, 1.0));
}
