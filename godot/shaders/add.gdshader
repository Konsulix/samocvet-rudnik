shader_type canvas_item;
// Light added onto what is under it: flashes, sparks, fire, bolts and streaks glow without the screen's glow pass (off
// to spare the phone). One of our own shaders, as every CanvasItem's must be on the iPhone (see plain.gdshader).
render_mode blend_add;

void fragment() {
}
