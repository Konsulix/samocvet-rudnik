shader_type canvas_item;
// add.gdshader for a 3D layer rendered on black (CardJelly): its colour is the light, whatever its alpha.
// (26.11: COLOR comes into fragment() already multiplied by the texture — «texture × COLOR» squared the layer: its faint
// light, a jellyfish's halo, all but went, and beside the layer under the stone, drawn right, the halo jumped.)
render_mode blend_add;

void fragment() {
	COLOR = vec4(texture(TEXTURE, UV).rgb, 1.0);
}
