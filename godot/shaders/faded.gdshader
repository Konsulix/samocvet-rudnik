shader_type canvas_item;
// A species the player no longer keeps, in the atlas: its stone drawn grey and dim, as a memory of it (playtest
// 31.10). The colour as plain.gdshader draws it, then washed to its brightness.

uniform float amount : hint_range(0.0, 1.0) = 1.0;
uniform float dim : hint_range(0.0, 1.0) = 0.7;

void fragment() {
	vec4 c = COLOR;
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	c.rgb = mix(c.rgb, vec3(l) * vec3(1.0, 0.98, 0.95) * dim, amount);
	COLOR = c;
}
