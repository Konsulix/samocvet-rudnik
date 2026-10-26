shader_type canvas_item;
// The pines on the ridge behind the mine sway a little in the night wind: only in the band of tree tops, more at the
// tops, and only where the picture is trees or sky (not the hut or the headframe in front of them).
// The shift is added to COLOR as a difference of two TEXTURE samples, so the picture keeps COLOR's tone.

uniform float top = 0.5;       // UV rows of the tree band
uniform float bottom = 0.7;
uniform float amp = 0.002;     // UV shift at the tree tops

void fragment() {
	float k = clamp((bottom - UV.y) / (bottom - top), 0.0, 1.0) * step(top - 0.04, UV.y) * step(UV.y, bottom);
	vec4 here = texture(TEXTURE, UV);
	float treeish = step(here.r, here.b + 0.10);
	float w = sin(TIME * 1.1 + UV.x * 38.0) * 0.6 + sin(TIME * 0.7 + UV.x * 11.0) * 0.4;
	vec2 uv = UV + vec2(amp * k * w * treeish, 0.0);
	COLOR.rgb += texture(TEXTURE, uv).rgb - here.rgb;
}
