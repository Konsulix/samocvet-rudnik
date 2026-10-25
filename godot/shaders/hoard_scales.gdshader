shader_type spatial;
// The golden serpent's hide (Hoard): rows of overlapping scales laid along the body (UV.x along it, UV.y round it),
// each a rounded plate, bright in the middle, a dark groove at its rim; every so often a darker, ruddier scale.

uniform vec3 gold : source_color = vec3(0.86, 0.6, 0.2);
uniform vec3 deep : source_color = vec3(0.35, 0.18, 0.04);
uniform vec2 count = vec2(1.7, 9.0);   // scales per unit of UV.x (4 per boulder radius along), round

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	vec2 g = UV * count;
	float row = floor(g.y);
	g.x += mod(row, 2.0) * 0.5;
	vec2 c = fract(g) - vec2(0.5, 0.15);
	vec2 id = vec2(floor(g.x), row);
	// a scale: a rounded plate whose free edge faces the tail
	float d = length(c * vec2(1.0, 1.25));
	float plate = 1.0 - smoothstep(0.42, 0.55, d);
	float shade = mix(0.55, 1.15, plate) * (1.0 - 0.35 * c.y);
	vec3 col = mix(deep, gold, plate);
	col = mix(col, deep * 1.6, step(0.88, hash(id)) * 0.6);
	ALBEDO = col * shade;
	METALLIC = mix(0.6, 1.0, plate);
	ROUGHNESS = mix(0.7, 0.28, plate);
}
