shader_type canvas_item;
// add.gdshader for a 3D layer rendered on black (CardJelly): its colour is the light, whatever the alpha its additive
// shaders left in it (they write their strength there for the inventory's see-through thumbnails: multiplied in again
// here it dimmed every faint glow twice — the jellyfish's halo went dark as it came out onto the card)
render_mode blend_add;

void fragment() {
	COLOR = vec4(texture(TEXTURE, UV).rgb * COLOR.rgb, 1.0);
}
