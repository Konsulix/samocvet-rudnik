shader_type canvas_item;
render_mode blend_add;
// The sheen on a floating card turned in depth (CardLevitate): a soft broad band of light sliding over it as it turns,
// and the side turned to the light (up and left) a little brighter. Added over the card.

uniform vec2 tilt = vec2(0.0);

void fragment() {
	float band = exp(-pow((UV.x * 0.7 + UV.y * 0.5) - (0.6 + tilt.x * 6.0 - tilt.y * 4.0), 2.0) / 0.03);
	float side = clamp(-(UV.x - 0.5) * tilt.x * 4.0 - (UV.y - 0.5) * tilt.y * 4.0, 0.0, 0.2);
	COLOR = vec4(vec3(1.0, 0.96, 0.88) * (band * 0.07 + side * 0.25), 1.0);
}
