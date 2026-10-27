class_name KitBox
extends StyleBox
## A frame from the drawn UI kit (Kit), stretched to any size as a nine-patch: the corners stay as drawn, the
## edges and the middle tile. The pictures are drawn at about 3 px per point, so on a phone they stay sharp:
## the patch is laid out `s` times bigger and drawn scaled down.

var tex: Texture2D
var margin := Vector4.ZERO    # left, top, right, bottom: the corners, in the picture's pixels
var s := 3.0                  # picture pixels per point
var modulate := Color.WHITE
var tile := true              # the edges and the middle repeat (false: stretch)
## round ends (the capsule): never stretched upright; the whole picture is scaled to the height and only its middle
## stretches sideways, so the ends stay as drawn
var fit_h := false
## a round rivet in the middle of each short end (the green button, the title plate): this many picture pixels above
## and below the middle stay as drawn, and a taller plate grows the plain rim over and under the rivet instead
var pin := 0.0
## big panels (the window): the frame is hollow and the slate under it is this seamless tile, repeated at its own
## size, so a tall card does not stretch the stone into streaks; it starts `fill_inset` picture px in from the edge
var fill: Texture2D
var fill_inset := 24.0

func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	if tex == null:
		return
	var rs := RenderingServer
	if fill:
		rs.canvas_item_add_set_transform(to_canvas_item, Transform2D(0.0, Vector2.ONE / s, 0.0, rect.position))
		var inner := Rect2(Vector2(fill_inset, fill_inset), rect.size * s - Vector2(fill_inset, fill_inset) * 2)
		rs.canvas_item_set_default_texture_repeat(to_canvas_item, RenderingServer.CANVAS_ITEM_TEXTURE_REPEAT_ENABLED)
		rs.canvas_item_add_texture_rect(to_canvas_item, inner, fill.get_rid(), true, modulate)
	var th := float(tex.get_height())
	if pin > 0.0 and rect.size.y * s >= th:
		_pinned(to_canvas_item, rect)
		return
	var k := s
	var tl := Vector2(margin.x, margin.y)
	var br := Vector2(margin.z, margin.w)
	if (fit_h or pin > 0.0) and rect.size.y > 0.0:
		k = tex.get_height() / rect.size.y
		tl.y = 0.0
		br.y = 0.0
	rs.canvas_item_add_set_transform(to_canvas_item, Transform2D(0.0, Vector2.ONE / k, 0.0, rect.position))
	var mode := RenderingServer.NINE_PATCH_TILE_FIT if tile else RenderingServer.NINE_PATCH_STRETCH
	rs.canvas_item_add_nine_patch(to_canvas_item, Rect2(Vector2.ZERO, rect.size * k), Rect2(Vector2.ZERO, tex.get_size()), tex.get_rid(),
		tl, br, mode, mode, true, modulate)
	rs.canvas_item_add_set_transform(to_canvas_item, Transform2D.IDENTITY)

## the plate in two halves, each a nine-patch: the upper ends on the rivet's upper half, the lower starts with its
## lower half; only the rim between a corner and the rivet stretches
func _pinned(ci: RID, rect: Rect2) -> void:
	var rs := RenderingServer
	var w := float(tex.get_width())
	var h := float(tex.get_height())
	var mid := floorf(h / 2.0)
	var full := rect.size * s
	var top := floorf(full.y / 2.0)
	var mode := RenderingServer.NINE_PATCH_TILE_FIT if tile else RenderingServer.NINE_PATCH_STRETCH
	rs.canvas_item_add_set_transform(ci, Transform2D(0.0, Vector2.ONE / s, 0.0, rect.position))
	rs.canvas_item_add_nine_patch(ci, Rect2(0, 0, full.x, top), Rect2(0, 0, w, mid), tex.get_rid(),
		Vector2(margin.x, margin.y), Vector2(margin.z, pin), mode, mode, true, modulate)
	rs.canvas_item_add_nine_patch(ci, Rect2(0, top, full.x, full.y - top), Rect2(0, mid, w, h - mid), tex.get_rid(),
		Vector2(margin.x, pin), Vector2(margin.z, margin.w), mode, mode, true, modulate)
	rs.canvas_item_add_set_transform(ci, Transform2D.IDENTITY)
