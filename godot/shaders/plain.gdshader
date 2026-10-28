shader_type canvas_item;
// The colour as it is (texture × modulate), nothing more: the material of every CanvasItem without its own
// (UI._plain, BoardSprites.plain_material). It has to be our own shader — on the iPhone whatever the stock
// one draws after the first custom shader in a layer disappears — but it costs no more than the stock one.

void fragment() {
}
