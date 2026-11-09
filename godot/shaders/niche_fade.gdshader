// A find's picture in an achievement's niche (screens/awards.gd), like a stone in a niche of the mine wall: its
// silhouette feathered (the alpha blurred inward), its colours a little muted, a warm pool of lamplight behind it
// so even black obsidian reads on the dark slate. The pool fades out before the picture's own edges.
shader_type canvas_item;

uniform float feather = 0.045;   // how soft the silhouette, in shares of the picture
uniform vec4 lamp : source_color = vec4(1.0, 0.78, 0.5, 1.0);
uniform float lamp_a = 0.42;
uniform float grey = 0.0;   // 1: no longer kept, grey and dim as in the atlas (faded.gdshader)

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	float a = t.a * 0.2;
	for (int i = 0; i < 10; i++) {
		float ang = float(i) * 0.6283;
		a += texture(TEXTURE, UV + vec2(cos(ang), sin(ang)) * feather).a * 0.08;
	}
	float fa = t.a * smoothstep(0.25, 0.95, a);
	float l = dot(t.rgb, vec3(0.3, 0.55, 0.15));
	vec3 stone = mix(vec3(l), t.rgb, 0.88) * 1.05;
	stone = mix(stone, vec3(l) * vec3(1.0, 0.98, 0.95) * 0.7, grey);
	vec2 q = (UV - vec2(0.5, 0.55)) * vec2(1.0, 1.15);
	float g = (1.0 - smoothstep(0.0, 0.5, length(q))) * lamp_a * (1.0 - 0.6 * grey);
	float out_a = fa + g * (1.0 - fa);
	vec3 col = (stone * fa + lamp.rgb * g * (1.0 - fa)) / max(out_a, 0.001);
	COLOR = vec4(col, out_a * COLOR.a);
}
