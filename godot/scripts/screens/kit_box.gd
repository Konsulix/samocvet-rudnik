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
## long plates and big cards: their middle is drawn seamless (art/ui_kit/seam_mid.py) and repeats along these axes
## instead of stretching (a 310 pt button stretched its face 3x into streaks)
var tile_x := false
var tile_y := false
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
	_nine(to_canvas_item, Rect2(Vector2.ZERO, rect.size * k), Rect2(Vector2.ZERO, tex.get_size()), tl, br, tile_x or tile, tile_y or tile)
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
	rs.canvas_item_add_set_transform(ci, Transform2D(0.0, Vector2.ONE / s, 0.0, rect.position))
	# (the server's nine-patch here, as before 19.11: its own way with margins over the half's height is what draws the
	# rivet's halves; _nine drew the title plate in two strips with a gap)
	rs.canvas_item_add_nine_patch(ci, Rect2(0, 0, full.x, top), Rect2(0, 0, w, mid), tex.get_rid(),
		Vector2(margin.x, margin.y), Vector2(margin.z, pin), _mode(tile_x), RenderingServer.NINE_PATCH_STRETCH, true, modulate)
	rs.canvas_item_add_nine_patch(ci, Rect2(0, top, full.x, full.y - top), Rect2(0, mid, w, h - mid), tex.get_rid(),
		Vector2(margin.x, pin), Vector2(margin.z, margin.w), _mode(tile_x), RenderingServer.NINE_PATCH_STRETCH, true, modulate)
	rs.canvas_item_add_set_transform(ci, Transform2D.IDENTITY)

## (19.11) the nine-patch drawn piece by piece, each piece's picture clamped to its own region (clip_uv): the
## server's nine-patch, tiling the middle, sampled across the region's edge — the frame's dark outline bled into
## every tile's edge, dark stripes down the green button and along a card's right and bottom on the phone
func _nine(ci: RID, dst: Rect2, src: Rect2, tl: Vector2, br: Vector2, tx: bool, ty: bool) -> void:
	var rs := RenderingServer
	# (margins wider than the picture or the box shrink to fit, as the server's nine-patch does: a half-plate's rim and
	# rivet margins together overran its height, its middle row came out negative and was dropped — a gap)
	for ax in 2:
		var sum := tl[ax] + br[ax]
		var room := minf(src.size[ax], dst.size[ax])
		if sum > room and sum > 0.0:
			tl[ax] *= room / sum
			br[ax] *= room / sum
	var sx := [src.position.x, src.position.x + tl.x, src.end.x - br.x, src.end.x]
	var sy := [src.position.y, src.position.y + tl.y, src.end.y - br.y, src.end.y]
	var dx := [dst.position.x, dst.position.x + tl.x, dst.end.x - br.x, dst.end.x]
	var dy := [dst.position.y, dst.position.y + tl.y, dst.end.y - br.y, dst.end.y]
	for j in 3:
		for i in 3:
			var s_r := Rect2(sx[i], sy[j], sx[i + 1] - sx[i], sy[j + 1] - sy[j])
			var d_r := Rect2(dx[i], dy[j], dx[i + 1] - dx[i], dy[j + 1] - dy[j])
			if s_r.size.x <= 0.0 or s_r.size.y <= 0.0 or d_r.size.x <= 0.0 or d_r.size.y <= 0.0: continue
			# the middle column / row repeat along (a whole number of tiles, each stretched a little to fit)
			var nx := maxi(1, roundi(d_r.size.x / s_r.size.x)) if (i == 1 and tx) else 1
			var ny := maxi(1, roundi(d_r.size.y / s_r.size.y)) if (j == 1 and ty) else 1
			var tw := d_r.size.x / nx
			var thh := d_r.size.y / ny
			for b in ny:
				for a in nx:
					rs.canvas_item_add_texture_rect_region(ci, Rect2(d_r.position.x + a * tw, d_r.position.y + b * thh, tw, thh), tex.get_rid(), s_r, modulate, false, true)

func _mode(along: bool) -> RenderingServer.NinePatchAxisMode:
	return RenderingServer.NINE_PATCH_TILE_FIT if along or tile else RenderingServer.NINE_PATCH_STRETCH
