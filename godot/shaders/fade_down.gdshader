shader_type canvas_item;
// a picture that sinks into what lies under it at the bottom: its alpha goes from 1 at `from` to 0 at `to` (UV.y)
// (MaidenCard's portrait into the window's slate)
uniform float from = 0.64;
uniform float to = 0.97;
void fragment() {
	COLOR = texture(TEXTURE, UV) * COLOR;
	COLOR.a *= 1.0 - smoothstep(from, to, UV.y);
}
